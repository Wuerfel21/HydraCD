' /////////////////////////////////////////////////////////////////////////////
' TITLE: PACMAN_TILE_DEMO_004.SPIN
'
' DESCRIPTION: Tile engine demo of making a pacman like game field with sprite based
' player character that moves around.
'
' VERSION: x.x
' AUTHOR: Andre' LaMothe
' LAST MODIFIED:
' COMMENTS:
'
' CONTROLS: Uses gamepad, use DPAD to move ghost around, notice ghost doesn't affect
' playfield graphics since its a "sprite".
'
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

  ' ghost animation constants
  GHOST_TILE_LEFT  = 0
  GHOST_TILE_RIGHT = 1
  GHOST_TILE_UP    = 2
  GHOST_TILE_DOWN  = 3
  
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
long x, y, tx, ty, index, dir, tile_map_index, test_tile' demo working vars
long ghost_x, ghost_y                                   ' position of ghost
long old_ghost_x, old_ghost_y                           ' holds last position of ghost                        

'//////////////////////////////////////////////////////////////////////////////
'OBJS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

OBJ

game_pad :      "gamepad_drv_001.spin"
gfx:            "HEL_GFX_ENGINE_040.SPIN"

'//////////////////////////////////////////////////////////////////////////////
'PUBS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

' COG INTERPRETER STARTS HERE...@ THE FIRST PUB

PUB Start
' This is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

' star the game pad driver
game_pad.start

' initialize all vars
ghost_x  := 160/2                    ' set sprite location of ghost to center of screen
ghost_y  := 192/2                    
                       
' points ptrs to actual memory storage for tile engine
tile_map_base_ptr_parm        := @tile_map2
tile_bitmaps_base_ptr_parm    := @tile_bitmaps
tile_palettes_base_ptr_parm   := @palette_map
tile_map_sprite_cntrl_parm    := $00_00_01_00 ' set for 1 sprites and width 16 tiles (1 screens wide), 0 = 16 tiles, 1 = 32 tiles, 2 = 64 tiles, 3 = 128 tiles, etc.
tile_sprite_tbl_base_ptr_parm := @sprite_tbl[0] 
tile_status_bits_parm         := 0

' enable/initialize a sprite
sprite_tbl[0] := $70_50_00_01     ' sprite 0 state: y=xx, x=$xx, z=$xx, enabled/disabled
sprite_tbl[1] := @sprite_bitmap_0 ' sprite 0 bitmap ptr

' launch a COG with ASM video driver
gfx.start(@tile_map_base_ptr_parm)

' enter main event loop...
repeat while 1
  ' main even loop code here...

  ' move the sprite
  if (game_pad.button(NES0_RIGHT))
    ghost_x+=2
  if (game_pad.button(NES0_LEFT))
    ghost_x-=2
  if (game_pad.button(NES0_DOWN))
    ghost_y+=2
  if (game_pad.button(NES0_UP))
    ghost_y-=2

  ' now update the sprite record 0 to reflect new position, sprite will update on next frame
  sprite_tbl[0] := (ghost_y << 24) + (ghost_x << 16) + (0 << 8) + ($01)            

  ' delay a little bit, so you can see the sprite, they are VERY fast!!!
  repeat 5000

  ' return back to repeat main event loop...

' parent COG will terminate now...if it gets to this point


'//////////////////////////////////////////////////////////////////////////////
'DAT SECTION //////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////


DAT

tile_maps     ' you place all your 16x12 tile maps here, you can have as many as you like, in real-time simply re-point the
              ' tile_map_base_ptr_parm to any time map and within 1 frame the tile map will update
              ' the engine only renders 10x12 of the tiles on the physical screen, the other 6 columns allow you some "scroll room"

              ' 16x12 WORDS each, (0..191 WORDs, 384 bytes per tile map) 2-BYTE tiles (msb)[palette_index | tile_index](lsb)
              ' 16x12 tile map, each tile is 2 bytes, there are a total of 64 tiles possible, and thus 64 palettes
              '
              ' <---------------------------visible on screen-------------------------------->|<------ to right of screen ---------->|              
              ' column     0      1      2      3      4      5      6      7      8      9   | 10     11     12     13     14     15

' just the maze
tile_map0     word      $00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01 ' row 0
              word      $00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $00_01,$00_00,$01_01,$01_01,$01_01,$00_00,$01_01,$01_01,$00_00,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $00_01,$00_00,$01_01,$00_00,$00_00,$00_00,$00_00,$01_01,$00_00,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $00_01,$00_00,$01_01,$00_00,$00_00,$00_00,$00_00,$01_01,$00_00,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 4
              word      $00_01,$00_00,$01_01,$01_01,$00_00,$01_01,$01_01,$01_01,$00_00,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 5
              word      $00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 6
              word      $00_01,$00_00,$01_01,$00_00,$01_01,$01_01,$00_00,$01_01,$00_00,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 7
              word      $00_01,$00_00,$01_01,$00_00,$00_00,$01_01,$00_00,$01_01,$00_00,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 8
              word      $00_01,$00_00,$01_01,$01_01,$00_00,$01_01,$00_00,$01_01,$00_00,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 9
              word      $00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01 ' row 11

' maze plus dots
tile_map1     word      $00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01 ' row 0
              word      $00_01,$00_02,$00_02,$00_02,$00_02,$00_02,$00_02,$00_02,$00_02,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $00_01,$00_02,$01_01,$01_01,$01_01,$00_02,$01_01,$01_01,$00_02,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $00_01,$00_02,$01_01,$00_02,$00_02,$00_02,$00_02,$01_01,$00_02,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $00_01,$00_02,$01_01,$00_02,$00_02,$00_02,$00_02,$01_01,$00_02,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 4
              word      $00_01,$00_02,$01_01,$01_01,$00_02,$01_01,$01_01,$01_01,$00_02,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 5
              word      $00_01,$00_02,$00_02,$00_02,$00_02,$00_02,$00_02,$00_02,$00_02,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 6
              word      $00_01,$00_02,$01_01,$00_02,$01_01,$01_01,$00_02,$01_01,$00_02,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 7
              word      $00_01,$00_02,$01_01,$00_02,$00_02,$01_01,$00_02,$01_01,$00_02,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 8
              word      $00_01,$00_02,$01_01,$01_01,$00_02,$01_01,$00_02,$01_01,$00_02,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 9
              word      $00_01,$00_02,$00_02,$00_02,$00_02,$00_02,$00_02,$00_02,$00_02,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01 ' row 11

' maze plus powerpills
tile_map2     word      $00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01 ' row 0
              word      $00_01,$00_03,$00_02,$00_02,$00_02,$00_02,$00_02,$00_02,$00_03,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $00_01,$00_02,$01_01,$01_01,$01_01,$00_02,$01_01,$01_01,$00_02,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $00_01,$00_02,$01_01,$00_02,$00_02,$00_02,$00_02,$01_01,$00_02,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $00_01,$00_02,$01_01,$00_02,$00_02,$00_02,$00_02,$01_01,$00_02,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 4
              word      $00_01,$00_02,$01_01,$01_01,$00_02,$01_01,$01_01,$01_01,$00_02,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 5
              word      $00_01,$00_02,$00_02,$00_02,$00_02,$00_02,$00_02,$00_02,$00_02,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 6
              word      $00_01,$00_02,$01_01,$00_02,$01_01,$01_01,$00_02,$01_01,$00_02,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 7
              word      $00_01,$00_02,$01_01,$00_02,$00_02,$01_01,$00_02,$01_01,$00_02,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 8
              word      $00_01,$00_02,$01_01,$01_01,$00_02,$01_01,$00_02,$01_01,$00_02,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 9
              word      $00_01,$00_03,$00_02,$00_02,$00_02,$00_02,$00_02,$00_02,$00_03,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01 ' row 11



' /////////////////////////////////////////////////////////////////////////////

tile_bitmaps long
              ' tile bitmap memory, each tile 16x16 pixels, or 1 LONG by 16,
              ' 64-bytes each, also, note that they are mirrored right to left
              ' since the VSU streams from low to high bits, so your art must
              ' be reflected, we could remedy this in the engine, but for fun
              ' I leave it as a challenge in the art, since many engines have
              ' this same artifact
              ' for this demo, only 4 tile bitmaps defined

              ' empty tile
              ' palette black, blue, gray, white
tile_blank    long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

             ' box segment
tile_box      long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1 ' tile 1
              long      %%1_0_0_0_0_0_0_0_0_0_0_0_0_0_0_1
              long      %%1_0_0_0_0_0_0_0_0_0_0_0_0_0_0_1
              long      %%1_0_0_0_0_0_0_0_0_0_0_0_0_0_0_1
              long      %%1_0_0_0_0_0_0_0_0_0_0_0_0_0_0_1
              long      %%1_0_0_0_0_0_0_0_0_0_0_0_0_0_0_1
              long      %%1_0_0_0_0_0_0_0_0_0_0_0_0_0_0_1
              long      %%1_0_0_0_0_0_0_0_0_0_0_0_0_0_0_1
              long      %%1_0_0_0_0_0_0_0_0_0_0_0_0_0_0_1
              long      %%1_0_0_0_0_0_0_0_0_0_0_0_0_0_0_1
              long      %%1_0_0_0_0_0_0_0_0_0_0_0_0_0_0_1
              long      %%1_0_0_0_0_0_0_0_0_0_0_0_0_0_0_1
              long      %%1_0_0_0_0_0_0_0_0_0_0_0_0_0_0_1
              long      %%1_0_0_0_0_0_0_0_0_0_0_0_0_0_0_1
              long      %%1_0_0_0_0_0_0_0_0_0_0_0_0_0_0_1
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

              ' standard dot
tile_dot      long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 2
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_3_3_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_3_3_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

              ' power up pill
tile_powerup  long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 3
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_2_2_2_3_3_0_0_0_0_0_0
              long      %%0_0_0_0_2_2_2_2_2_3_3_0_0_0_0_0
              long      %%0_0_0_2_2_2_2_2_2_2_3_3_0_0_0_0
              long      %%0_0_0_2_2_2_2_2_2_2_3_3_0_0_0_0
              long      %%0_0_0_2_2_2_2_2_2_2_2_2_0_0_0_0
              long      %%0_0_0_2_2_2_2_2_2_2_2_2_0_0_0_0
              long      %%0_0_0_0_2_2_2_2_2_2_2_0_0_0_0_0
              long      %%0_0_0_0_0_2_2_2_2_2_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

              ' a ghost with eyes to left
tile_ghost_lt long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 4
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_2_2_2_2_2_2_0_0_0_0_0
              long      %%0_0_0_2_2_2_2_2_2_2_2_2_2_0_0_0
              long      %%0_0_0_2_2_2_2_2_2_2_2_2_2_0_0_0
              long      %%0_0_2_3_3_3_3_2_2_3_3_3_3_2_0_0
              long      %%0_0_2_3_3_3_3_2_2_3_3_3_3_2_0_0
              long      %%0_0_2_3_3_1_1_2_2_3_3_1_1_2_0_0
              long      %%0_0_2_3_3_1_1_2_2_3_3_1_1_2_0_0
              long      %%0_0_2_2_2_2_2_2_2_2_2_2_2_2_0_0
              long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_2_0
              long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_2_0
              long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_2_0
              long      %%0_2_2_0_0_2_2_0_0_2_2_0_0_2_2_0
              long      %%0_2_2_0_0_2_2_0_0_2_2_0_0_2_2_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0


              ' a ghost with eyes to right
tile_ghost_rt long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 5
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_2_2_2_2_2_2_0_0_0_0_0
              long      %%0_0_0_2_2_2_2_2_2_2_2_2_2_0_0_0
              long      %%0_0_0_2_2_2_2_2_2_2_2_2_2_0_0_0
              long      %%0_0_2_3_3_3_3_2_2_3_3_3_3_2_0_0
              long      %%0_0_2_3_3_3_3_2_2_3_3_3_3_2_0_0
              long      %%0_0_2_1_1_3_3_2_2_1_1_3_3_2_0_0
              long      %%0_0_2_1_1_3_3_2_2_1_1_3_3_2_0_0
              long      %%0_0_2_2_2_2_2_2_2_2_2_2_2_2_0_0
              long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_2_0
              long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_2_0
              long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_2_0
              long      %%0_2_2_0_0_2_2_0_0_2_2_0_0_2_2_0
              long      %%0_2_2_0_0_2_2_0_0_2_2_0_0_2_2_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0


              ' a ghost with eyes up
tile_ghost_up long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 6
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_2_2_2_2_2_2_0_0_0_0_0
              long      %%0_0_0_2_2_2_2_2_2_2_2_2_2_0_0_0
              long      %%0_0_0_2_2_2_2_2_2_2_2_2_2_0_0_0
              long      %%0_0_2_3_3_1_1_2_2_3_3_1_1_2_0_0
              long      %%0_0_2_3_3_1_1_2_2_3_3_1_1_2_0_0
              long      %%0_0_2_3_3_3_3_2_2_3_3_3_3_2_0_0
              long      %%0_0_2_3_3_3_3_2_2_3_3_3_3_2_0_0
              long      %%0_0_2_2_2_2_2_2_2_2_2_2_2_2_0_0
              long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_2_0
              long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_2_0
              long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_2_0
              long      %%0_2_2_0_0_2_2_0_0_2_2_0_0_2_2_0
              long      %%0_2_2_0_0_2_2_0_0_2_2_0_0_2_2_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

              ' a ghost with eyes down
tile_ghost_dn long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 7
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_2_2_2_2_2_2_0_0_0_0_0
              long      %%0_0_0_2_2_2_2_2_2_2_2_2_2_0_0_0
              long      %%0_0_0_2_2_2_2_2_2_2_2_2_2_0_0_0
              long      %%0_0_2_3_3_3_3_2_2_3_3_3_3_2_0_0
              long      %%0_0_2_3_3_3_3_2_2_3_3_3_3_2_0_0
              long      %%0_0_2_1_1_3_3_2_2_1_1_3_3_2_0_0
              long      %%0_0_2_1_1_1_3_2_2_1_1_1_3_2_0_0
              long      %%0_0_2_2_2_2_2_2_2_2_2_2_2_2_0_0
              long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_2_0
              long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_2_0                                                       
              long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_2_0
              long      %%0_2_2_0_0_2_2_0_0_2_2_0_0_2_2_0
              long      %%0_2_2_0_0_2_2_0_0_2_2_0_0_2_2_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

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

sprite_bitmaps          long

                      ' bitmap for sprite use, uses the palette of the tile its rendered into
sprite_bitmap_0         long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_2_2_2_2_2_2_0_0_0_0_0
                        long      %%0_0_0_2_2_2_2_2_2_2_2_2_2_0_0_0
                        long      %%0_0_0_2_2_2_2_2_2_2_2_2_2_0_0_0
                        long      %%0_0_2_3_3_3_3_2_2_3_3_3_3_2_0_0
                        long      %%0_0_2_3_3_3_3_2_2_3_3_3_3_2_0_0
                        long      %%0_0_2_1_1_3_3_2_2_1_1_3_3_2_0_0
                        long      %%0_0_2_1_1_3_3_2_2_1_1_3_3_2_0_0
                        long      %%0_0_2_2_2_2_2_2_2_2_2_2_2_2_0_0
                        long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_2_0
                        long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_2_0
                        long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_2_0
                        long      %%0_2_2_0_0_2_2_0_0_2_2_0_0_2_2_0
                        long      %%0_2_2_0_0_2_2_0_0_2_2_0_0_2_2_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

' the mask needs to be a NEGATIVE of the bitmap, basically a "stencil" where we are going to write the sprite into, all the values are 0 (mask) or 3 (write thru)
' however, the algorithm needs a POSITIVE to make some of the shifting easier, so we only need to apply the rule to each pixel of the bitmap:
' if (p_source == 0) p_dest = 0, else p_dest = 3
sprite_bitmap_mask_0    long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_3_3_3_0_0_0_0_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_0_0_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_0_0_0
                        long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
                        long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
                        long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
                        long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
                        long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
                        long      %%0_3_3_3_3_3_3_3_3_3_3_3_3_3_3_0
                        long      %%0_3_3_3_3_3_3_3_3_3_3_3_3_3_3_0
                        long      %%0_3_3_3_3_3_3_3_3_3_3_3_3_3_3_0
                        long      %%0_3_3_0_0_3_3_0_0_3_3_0_0_3_3_0
                        long      %%0_3_3_0_0_3_3_0_0_3_3_0_0_3_3_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

' /////////////////////////////////////////////////////////////////////////////

              ' palette memory (1..255 palettes) each palette 4-BYTEs or 1-LONG
              ' pacman ish palette needs 4 colors in each palette to have certain properties
              ' color 0 - used for black
              ' color 1 - used for walls (unless, ghost will cross a wall, we can reuse this color for the ghost if we need 2 colors for ghost, or have multiple colored walls)
              ' color 2 - used for ghost color (can change possibly tile to tile)
              ' color 3 - white
{
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
}

' some pacman palettes...              
palette_map   long $07_3C_AC_02 ' palette 0 - background and wall tiles, 0-black, 1-pink, 2-red, 3-white
              long $07_3C_7C_02 ' palette 1 - background and wall tiles, 0-black, 1-green, 2-red, 3-white


              