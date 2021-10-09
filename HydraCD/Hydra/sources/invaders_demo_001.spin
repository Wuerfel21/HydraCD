' /////////////////////////////////////////////////////////////////////////////
' TITLE: INVADERS_DEMO_001.SPIN - Sub-tile animation demo. 
'
' DESCRIPTION: This program loads a 32x12 tile world, the first 10x12 tiles contain
' the gamefield while the last 8 columns of the world contain all the tiles for reference.
' The program shows off the technique where within the confines of the tile artwork
' objects are animated and moved simulating smooth sub-tile or pixel accurate
' motion in this case, the player's ship has 4 sets of tiles, each set contains
' two tile blocks that make up the the image, however, the trick is that WITHIN
' the tile artwork the player's ship is moved 4 pixels at a time, then when all
' 4 sets of tile artwork have been cycled thru the player's ship is moved
' an entire course tile and the process repeats, thus making the ship look like its
' moving at 4 pixels at a time. The downside is the extra tiles needed to support
' the technique, but with it games can have very smooth animation and still be tile
' based. The downside is that motion becomes more complex as does collision detection. 
'
' VERSION: 1.0
' AUTHOR: Andre' LaMothe
' LAST MODIFIED:
' COMMENTS:
'
' CONTROLS: Gamepad, right left moves player back and forth, hold down SELECT
' and right and left to scroll playfield. All the way to the right is all the
' tile artwork tucked away!

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

  ' base tile index for ship tiles, left to right, top to bottom, 8 tiles per 4 frame sub-tile motion with two
  ' rows; row 0 flame on, row 1 flame off
  SHIP_TILE_INDEX_BASE = $38

  
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
long ship_x, ship_y                                     ' position of ship
long ship_sub_x                                         ' sub tile x of ship
long ship_anim_count                                    ' counter for animation to take place
long ship_anim_frame                                    ' frame of animation (0 or 1) flames, no flames :)

long curr_count                                         ' saves counter

long tile_map_base_addr         ' pointer to tile map base addr to make access easy

'//////////////////////////////////////////////////////////////////////////////
'OBJS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

OBJ

game_pad :      "gamepad_drv_001.spin"
gfx:            "HEL_GFX_ENGINE_040.SPIN"
tile_data:      "invaders_tile_data.spin" 

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

' these control the sprite engine, all 0 for now, no sprites, map 32 wide
tile_map_sprite_cntrl_parm    := $00_01 ' 0 sprites, tile map set to 0=16 tiles wide, 1=32 tiles, 2=64 tiles, etc.
tile_sprite_tbl_base_ptr_parm := 0 
tile_status_bits_parm         := 0

' initialize scrolling vars
scroll_x := 0
scroll_y := 0

' initialize player vars
ship_x     := 4
ship_sub_x := 0
ship_y     := 11

' launch a COG with ASM video driver
gfx.start(@tile_map_base_ptr_parm)

' enter main event loop...
repeat while 1
  
  ' main even loop code here...
  curr_count := cnt ' save current counter value

  ' test for scroll
  if ((game_pad.button(NES0_RIGHT) and game_pad.button(NES0_SELECT)) and scroll_x < 32-10)
      scroll_x++

  if ((game_pad.button(NES0_LEFT) and game_pad.button(NES0_SELECT)) and scroll_x > 0)
      scroll_x--

  ' test for player movement right?
  if (game_pad.button(NES0_RIGHT) and not game_pad.button(NES0_SELECT))
    ' erase ship first
    WORD[tile_map_base_addr][ship_x     + ship_y*32] := $01_01 ' this is the "black" tile
    WORD[tile_map_base_addr][(ship_x+1) + ship_y*32] := $01_01 ' this is the "black" tile
  
    ' move player within tiles right, but first test if hitting edge?
    if (not (ship_x == 7 and ship_sub_x == 3))    
      if (++ship_sub_x > 3)
        ' reset sub-tile and move whole tile
        ship_sub_x := 0
        ship_x++

  ' test for player movement left?       
  if (game_pad.button(NES0_LEFT) and not game_pad.button(NES0_SELECT))
    ' erase ship first
    WORD[tile_map_base_addr][ship_x     + ship_y*32] := $01_01 ' this is the "black" tile
    WORD[tile_map_base_addr][(ship_x+1) + ship_y*32] := $01_01 ' this is the "black" tile
      
    ' move player within tiles left, but first test if hiting edge?
    if (not (ship_x == 1 and ship_sub_x == 0))
      if (--ship_sub_x < 0)
        ' reset sub-tile and move whole tile
        ship_sub_x := 3
        ship_x--

  ' update animation of flame!
  if (++ship_anim_count > 1)
    ' reset flame and frame
    ship_anim_count := 0
    if ( (ship_anim_frame+=8) > 8)
      ship_anim_frame := 0
       
  ' draw player always, pay attention to how tiles are addressed and how the animation is performed by adding the offset to the 2nd row of tiles
  WORD[tile_map_base_addr][ship_x     + ship_y*32] := (SHIP_TILE_INDEX_BASE + ship_sub_x*2 + ship_anim_frame)     << 8 | (SHIP_TILE_INDEX_BASE + ship_sub_x*2 + ship_anim_frame) 
  WORD[tile_map_base_addr][(ship_x+1) + ship_y*32] := (SHIP_TILE_INDEX_BASE + ship_sub_x*2 + 1 + ship_anim_frame) << 8 | (SHIP_TILE_INDEX_BASE + ship_sub_x*2 + 1 + ship_anim_frame)

  ' update tile base memory pointer
  tile_map_base_ptr_parm := tile_data.tile_maps + scroll_x*2

   ' lock frame rate to 15-30 frames to slow this down
  waitcnt(cnt + 3*666_666)
      
  ' return back to repeat main event loop...

' parent COG will terminate now...if it gets to this point


'//////////////////////////////////////////////////////////////////////////////
'DAT SECTION //////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////
              