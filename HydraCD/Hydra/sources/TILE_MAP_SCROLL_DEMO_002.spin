' /////////////////////////////////////////////////////////////////////////////
' TITLE: TILE_MAP_SCROLL_DEMO_002.SPIN - Large tile map demo
'
' DESCRIPTION: This demo is a test platform/template that simply starts up the tile
' engine and then imports a mappy map exported out by the MAP2SPIN.EXE|CPP tool.
' The tile map is 64x12 and supports full X-Y scrolling, this version of the demo
' moves one the scorpions at the bottom of the screen right and left using
' a simple finite state machine and two frames of animation per cycle per
' direction, also supports tile collision with "wall" tile
'
' VERSION: 1.0
' AUTHOR: Andre' LaMothe
' LAST MODIFIED:
' COMMENTS:
'
' CONTROLS: Gamepad, right left scrolls image back and forth

'//////////////////////////////////////////////////////////////////////////////

'//////////////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ///////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x       ' enable external clock range 5-10MHz and pll times 8
  _xinfreq = 10_000_000 + 0000   ' set frequency to 10 MHZ plus some error due to XTAL (1000-5000 usually works)
  _stack   = 128                 ' accomodate display memory and stack

  ' button ids/bit masks
  ' NES bit encodings general for state bits
  NES_RIGHT  = %00000001
  NES_LEFT   = %00000010
  NES_DOWN   = %00000100
  NES_UP     = %00001000
  NES_START  = %00010000
  NES_SELECT = %00100000
  NES_B      = %01000000
  NES_A      = %10000000

  ' NES bit encodings for NES gamepad 0
  NES0_RIGHT  = %00000000_00000001
  NES0_LEFT   = %00000000_00000010
  NES0_DOWN   = %00000000_00000100
  NES0_UP     = %00000000_00001000
  NES0_START  = %00000000_00010000
  NES0_SELECT = %00000000_00100000
  NES0_B      = %00000000_01000000
  NES0_A      = %00000000_10000000

  ' NES bit encodings for NES gamepad 1
  NES1_RIGHT  = %00000001_00000000
  NES1_LEFT   = %00000010_00000000
  NES1_DOWN   = %00000100_00000000
  NES1_UP     = %00001000_00000000
  NES1_START  = %00010000_00000000
  NES1_SELECT = %00100000_00000000
  NES1_B      = %01000000_00000000
  NES1_A      = %10000000_00000000

  ' color constant's to make setting colors for parallax graphics setup easier
  COL_Black       = %0000_0010
  COL_DarkGrey    = %0000_0011
  COL_Grey        = %0000_0100
  COL_LightGrey   = %0000_0101
  COL_BrightGrey  = %0000_0110
  COL_White       = %0000_0111 

  ' colors are in reverse order from parallax drivers, or in order 0-360 phase lag from 0 = Blue, on NTSC color wheel
  ' so code $0 = 0 degrees, $F = 360 degrees, more intuitive mapping, and is 1:1 with actual hardware
  COL_PowerBlue   = %1111_1_100 
  COL_Blue        = %1110_1_100
  COL_SkyBlue     = %1101_1_100
  COL_AquaMarine  = %1100_1_100
  COL_LightGreen  = %1011_1_100
  COL_Green       = %1010_1_100
  COL_GreenYellow = %1001_1_100
  COL_Yellow      = %1000_1_100
  COL_Gold        = %0111_1_100
  COL_Orange      = %0110_1_100
  COL_Red         = %0101_1_100
  COL_VioletRed   = %0100_1_100
  COL_Pink        = %0011_1_100
  COL_Magenta     = %0010_1_100
  COL_Violet      = %0001_1_100
  COL_Purple      = %0000_1_100

  ' scorpion animation states
  SCORP_STATE_WALKING   = 0
  SCORP_STATE_IDLE      = 1

  SCORP_RIGHT           = 0  ' directions as well as tile index for animation frames
  SCORP_LEFT            = 2

  ' use the wall tile for collision
  SCORP_WALL_TILE_INDEX = $35_35 ' this is tile palette|index of the "wall" tile located at (7,2) in tile bitmap artwork.
                                 ' To find index look in "pitfall_tile_data2.spin" for tile exported tile(7,2) then count
                                 ' which tile it is from the top, i.e, read the index.  WARNING! This can change during export in
                                 ' MAP2SPIN if bitmaps change and usage changes, so re-check if you re-export tile data                           
  
'//////////////////////////////////////////////////////////////////////////////
' VARS SECTION ////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

VAR

' begin parameter list ////////////////////////////////////////////////////////
' tile engine data structure pointers (can be changed in real-time by app!)
long tile_map_base_ptr_parm       ' base address of the tile map
long tile_bitmaps_base_ptr_parm   ' base address of the tile bitmaps
long tile_palettes_base_ptr_parm  ' base address of the palettes

long tile_map_sprite_cntrl_parm   ' pointer to the value that holds various "control" values for the tile map/sprite engine
                                  ' currently, encodes width of map, and number of sprites to process up to 8 in following format
                                  ' $xx_xx_ss_ww, xx is don't care/unused
                                  ' ss = number of sprites to process 1..8
                                  ' ww = the number of "screens" or multiples of 16 that the tile map is
                                  ' eg. 0 would be 16 wide (standard), 1 would be 32 tiles, 2 would be 64 tiles, etc.
                                  ' this allows multiscreen width playfields and thus large horizontal/vertical scrolling games
                                  ' note that the final size is always a power of 2 multiple of 16

long tile_sprite_tbl_base_ptr_parm ' base address of sprite table


' real-time engine status variables, these are updated in real time by the
' tile engine itself, so they can be monitored outside in SPIN/ASM by game
long tile_status_bits_parm      ' vsync, hsync, etc.

' format of tile_status_bits_parm, only the Vsync status bit is updated
'
' byte 3 (unused)|byte 2 (line)|   byte 1 (tile postion)    |                     byte 0 (sync and region)      |
'|x x x x x x x x| line 8-bits | row 4 bits | column 4-bits |x x x x | region 2-bits | hsync 1-bit | vsync 1-bit|
'   b31..b24         b23..b16      b15..b12     b11..b8                    b3..b2          b1            b0
' Region 0=Top Overscan, 1=Active Video, 2=Bottom Overscan, 3=Vsync
' NOTE: In this version of the tile engine only VSYNC and REGION are valid 

' end parameter list ///////////////////////////////////////////////////////////

byte sbuffer[80]                                        ' string buffer for printing
long x, y, tx, ty, index, dir, tile_map_index           ' demo working vars
long scroll_x, scroll_y                                 ' scrolling vars
long curr_count                                         ' saves counter

' scorpion animation vars
long scorp_state                ' state of scorpion's animation state machine
long scorp_state_count          ' used to count state machine transitions
long scorp_x, scorp_y           ' position of scorpion
long scorp_anim_count           ' when to perform animation cycle
long scorp_dir                  ' direction of scorpion
long scorp_frame_index          ' animation frame index

long tile_map_base_addr         ' pointer to tile map base addr to make access easy

long random                     ' random #

'//////////////////////////////////////////////////////////////////////////////
'OBJS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

OBJ

game_pad :      "gamepad_drv_001.spin"
gfx:            "HEL_GFX_ENGINE_040.SPIN"

tile_data:      "pitfall_tile_data2.spin" ' <----- MODIFY THIS LINE BY INSERTING YOUR OWN MAP2SPIN OUTPUT FILE HERE!!!!!

'//////////////////////////////////////////////////////////////////////////////
'PUBS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

' COG INTERPRETER STARTS HERE...@ THE FIRST PUB

PUB Start 
' This is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

' star the game pad driver (will need it later)
game_pad.start

' set up tile and sprite engine data before starting it, so no ugly startup
' points ptrs to actual memory storage for tile engine
' point everything to the "tile_data" object's data which are retrieved by "getter" functions
tile_map_base_ptr_parm        := tile_data.tile_maps
tile_map_base_addr            := tile_data.tile_maps   ' copy into here so a single ptr is pointing to tile map data (makes animation easier) 
tile_bitmaps_base_ptr_parm    := tile_data.tile_bitmaps
tile_palettes_base_ptr_parm   := tile_data.tile_palette_map

' these control the sprite engine, all 0 for now, no sprites
tile_map_sprite_cntrl_parm    := $00_02 ' 0 sprites, tile map set to 2=64 tiles wide, 1=32 tiles, 2=64 tiles, etc.
tile_sprite_tbl_base_ptr_parm := 0      ' maps can always be any height >= 12 rows
tile_status_bits_parm         := 0

' initialize scrolling vars
scroll_x := 0
scroll_y := 0

' initialize scorpion animation vars
scorp_state            := SCORP_STATE_WALKING    ' state of scorpion's animation state machine
scorp_state_count      := 10                  ' used to count state machine transitions
scorp_x                := 7
scorp_y                := 9                   ' position of scorpion
scorp_anim_count       := 0                   ' when to perform animation cycle
scorp_dir              := SCORP_LEFT          ' direction of scorpion
scorp_frame_index      := 0                   ' animation frame index

' random stuff
random := cnt * 17213421

' launch a COG with ASM video driver
gfx.start(@tile_map_base_ptr_parm)

' enter main event loop...
repeat while 1
  
  ' main even loop code here...
  curr_count := cnt ' save current counter value

  ' test for scroll
  if (game_pad.button(NES0_RIGHT) and scroll_x < 54)
      scroll_x++

  if (game_pad.button(NES0_LEFT) and scroll_x > 0)
      scroll_x--

  if (game_pad.button(NES0_UP) and scroll_y > 0)
      scroll_y--

  if (game_pad.button(NES0_DOWN) and scroll_y < 12)
      scroll_y++

  ' animate scorpion
  ' is it time to update scorpion?
  if (++scorp_anim_count > 5)
    ' reset counter
    scorp_anim_count := 0

    ' process animation
    case scorp_state    
      
      SCORP_STATE_WALKING:
        ' move
        if (scorp_dir == SCORP_RIGHT)
          WORD[tile_map_base_addr][scorp_x + scorp_y*64] := $36_36 ' write black tile (erase)
        
          scorp_x++ ' move scorpion

          ' test for wall collision
          if ( WORD[tile_map_base_addr][scorp_x + scorp_y*64] == SCORP_WALL_TILE_INDEX) 
             scorp_x--
             scorp_dir := SCORP_LEFT                     
         
        else
          WORD[tile_map_base_addr][scorp_x + scorp_y*64] := $36_36 ' write black tile (erase)  

          scorp_x-- ' move scorpion

          ' test for wall collision
          if ( WORD[tile_map_base_addr][scorp_x + scorp_y*64] == SCORP_WALL_TILE_INDEX) 
             scorp_x++
             scorp_dir := SCORP_RIGHT                     

        ' animate 
        if (++scorp_frame_index => 2)
            scorp_frame_index := 0          

      SCORP_STATE_IDLE:
        ' do nothing or do something cool?

    ' update state counter
    if (--scorp_state_count =< 0)
      ' select new state, direction, and counter values
      scorp_state_count := ((?random) & $F) + 10
      scorp_dir         := ((?random) & $01)*2           
      scorp_state       := ((?random) & $01)

  ' draw scorpion, notice palette index is same as tile index, tile entry format: [palette_index | tile_index]
  WORD[tile_map_base_addr][scorp_x + scorp_y*64] := scorp_anim_lookup[scorp_frame_index + scorp_dir]<<8 + scorp_anim_lookup[scorp_frame_index + scorp_dir]
 
  ' update tile base memory pointer taking scroll_x and scroll_y into consideration
  tile_map_base_ptr_parm := tile_map_base_addr + (scroll_x + scroll_y*64)*2

   ' lock frame rate to 3-6 frames to slow this down
  waitcnt(cnt + 5*666_666)
      
  ' return back to repeat main event loop...

' parent COG will terminate now...if it gets to this point


'//////////////////////////////////////////////////////////////////////////////
'DAT SECTION //////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

' animation lookup table, contains the tile indices that represent the animation
' frames of the scorpion, two to the right: 57,62 and two to the left: 64,61
' with this table they can be looked up as 0,1,2,3 nicely
DAT

scorp_anim_lookup               byte          57,62,64,61              