' /////////////////////////////////////////////////////////////////////////////
' TITLE: tracking_demo_001.spin - tracking techniques demo
'
' DESCRIPTION: This demo shows off the basic deterministic chasing and evasion
' algorithm
'
' VERSION: 1.0
' AUTHOR: Andre' LaMothe
' LAST MODIFIED:
' COMMENTS:
'
' CONTROLS: Gamepad, use the dpad to control the player, the alien robot will
' start by chasing the player, use the <START> button on the gamepad to toggle
' between chase and evade modes of logic
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

  ' ai modes
  AI_MODE_CHASE = 0
  AI_MODE_EVADE = 1
  
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

long tile_map_base_addr                                 ' pointer to tile maps

' player variables
long player_x, player_y                                 ' position
long player_frame, player_frame_counter                 ' used for animation

' alien variable
long alien_x, alien_y                                   ' position
long alien_frame, alien_frame_counter                   ' used for animation

' AI stuff
long ai_mode

long random_var                                         ' global random variable    

'//////////////////////////////////////////////////////////////////////////////
'OBJS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

OBJ

game_pad :      "gamepad_drv_001.spin"
gfx:            "HEL_GFX_ENGINE_040.SPIN"
tile_data:      "invaders_tile_data2.spin" 


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
tile_map_sprite_cntrl_parm    := $02_01 ' 2 sprites, tile map set to 0=16 tiles wide, 1=32 tiles, 2=64 tiles, etc.
tile_sprite_tbl_base_ptr_parm := @sprite_tbl[0] ' point to sprite data table 
tile_status_bits_parm         := 0

' initialize scrolling vars
scroll_x := 0
scroll_y := 0

' initialize random variable
random_var := cnt*171732
random_var := ?random_var

' initialize player and alien
player_x                        := 80                                                                                                
player_y                        := 128         
player_frame                    := 0
player_frame_counter            := 0    

alien_x                         := Rand_Range(0, 10*16)
alien_y                         := Rand_Range(0, 12*16)        
alien_frame                     := 1
alien_frame_counter             := 0                  

' start demo off in chase mode
ai_mode                         := AI_MODE_CHASE

' enable/initialize a sprites player 0, alien 1
sprite_tbl[0] := player_y << 24 | player_x << 16 | $01              ' sprite 0 state: y=xx, x=$xx, z=$xx, enabled/disabled
sprite_tbl[1] := tile_data.sprite_bitmaps + (player_frame*128)      ' sprite 0 bitmap ptr

sprite_tbl[2] := alien_y << 24 | alien_x << 16 | $01                ' sprite 1 state: y=xx, x=$xx, z=$xx, enabled/disabled
sprite_tbl[3] := tile_data.sprite_bitmaps + (alien_frame*128)+256   ' sprite 1 bitmap ptr

' launch a COG with ASM video driver
gfx.start(@tile_map_base_ptr_parm)

' enter main event loop...
repeat while 1
  
  ' main even loop code here...
  curr_count := cnt ' save current counter value

  ' test player movement first?
  if (game_pad.button(NES0_RIGHT))
    player_x+=2
  elseif (game_pad.button(NES0_LEFT))
    player_x-=2
      
  if (game_pad.button(NES0_UP))
    player_y-=2
  elseif (game_pad.button(NES0_DOWN))
    player_y+=2

  ' test for ai mode change 
  if (game_pad.button(NES0_START))
    repeat while game_pad.button(NES0_START) ' let use release button first
    if (ai_mode == AI_MODE_EVADE)
      ai_mode := AI_MODE_CHASE
    else
      ai_mode := AI_MODE_EVADE  

  ' update animation frames
  if (++player_frame_counter > 15)
    player_frame_counter := 0 
    if (++player_frame > 1)
      player_frame := 0

  if (++alien_frame_counter > 15)
    alien_frame_counter := 0
    if (++alien_frame > 1)
      alien_frame := 0

  ' now test ai mode and apply ai method
  if (ai_mode == AI_MODE_CHASE)
    ' begin chase ai
    if (player_x > alien_x)
      alien_x++
    elseif (player_x < alien_x)
      alien_x--

    if (player_y > alien_y)
      alien_y++
    elseif (player_y < alien_y)
      alien_y--
  else
    ' begin evade ai
    if (player_x > alien_x)
      alien_x--
    elseif (player_x < alien_x)
      alien_x++

    if (player_y > alien_y)
      alien_y--
    elseif (player_y < alien_y)
      alien_y++
  
  ' draw the player and enemy
  sprite_tbl[0] := player_y << 24 | player_x << 16 | $01              ' sprite 0 state: y=xx, x=$xx, z=$xx, enabled/disabled
  sprite_tbl[1] := tile_data.sprite_bitmaps + (player_frame*128)      ' sprite 0 bitmap ptr

  sprite_tbl[2] := alien_y << 24 | alien_x << 16 | $01                ' sprite 1 state: y=xx, x=$xx, z=$xx, enabled/disabled
  sprite_tbl[3] := tile_data.sprite_bitmaps + (alien_frame*128)+256   ' sprite 1 bitmap ptr

  ' update tile base memory pointer
  tile_map_base_ptr_parm := tile_map_base_addr + scroll_x*2

   ' lock frame rate to 15-30 frames to slow this down
  waitcnt(cnt + 2*666_666)
      
  ' return back to repeat main event loop...

' parent COG will terminate now...if it gets to this point

' /////////////////////////////////////////////////////////////////////////////

Pub Rand_Range(rstart, rend) : r_delta
' returns a random number from [rstart to rend] inclusive
r_delta := rend - rstart + 1

result := rstart + ((?random_var & $7FFFFFFF) // r_delta)

return result

'//////////////////////////////////////////////////////////////////////////////
'DAT SECTION //////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////


DAT

' animation lookup tables

' format {number of frames in sequence, sequence...}
animation_frames        LONG   7, 0,1,2,3,3,2,1 

' list of translation factors for each frame of animation, must have same number of entries as "animation_frames"
animation_translation   LONG      2,2,2,3,3,2,0

{
 each sprite is composed of a 2 LONGs, the first is a control/state LONG (broken into 4 bytes), followed by a LONG ptr to the bitmap data
 the format of the control/state LONG

Header format:

Long 0 - state / control bits

|      Byte 3       |       Byte 2      |       Byte 1      |       Byte 0      |
| y7 y y y y y y y0 | x7 x x x x x x x0 | z7 z z z z z z z0 | s7 s s s s s s s0 |
     y - pos              x - pos                z-pos         state/control bits

State/Control bits

Enabled         %00_000_0_0_1
Mirrorx         %00_000_0_1_0
Mirrory         %00_000_1_0_0
Scale1x         %00_000_0_0_0
Scale2x         %00_001_0_0_0
Scale4x         %00_010_0_0_0
Scale8x         %00_100_0_0_0
Raster_OP       %xx_000_0_0_0

The 2nd long is simply a pointer to the bitmap data, can be any 16x16 palettized bitmap, tile, sprite, whatever.
However, sprites have NO palette, they "use" the palette of the tile(s) that they are rendered onto, so beware...  
}


' sprite table, 8 sprites, 2 LONGs per sprite, 8 LONGs total length
              ' sprite 0 header
sprite_tbl    long $00_00_00_00  ' state/control word: y,x,z,state, enabled, x=$50, y=$60
              long $00_00_00_00  ' bitmap ptr

              ' sprite 1 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 2 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 3 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 4 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 5 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 6 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 7 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr


' end sprite table

' sprite bitmap table
' each bitmap is 16x16 pixels, 1 long x 16 longs
' bitmaps are reflected left to right, so keep that in mind
' they are numbered for reference only and any bitmap can be assigned to any sprite thru the use of the
' sprite pointer in the sprite header, this allows easy animation without data movement
' additionally, each sprite needs a "mask" to help the rendering engine, computation of the mask is
' too time sensitive, thus the mask must follow immediately after the sprite
              