' /////////////////////////////////////////////////////////////////////////////
' TITLE: PACMAN_TILE_DEMO_002.SPIN
'
' DESCRIPTION: Tile engine demo of making a pacman like game field with tile based
' player character than moves around, notice eyes on ghost as the ghost changes
' direction.
'
' VERSION: x.x
' AUTHOR: Andre' LaMothe
' LAST MODIFIED:
' COMMENTS:
'
' CONTROLS: Uses gamepad, use DPAD to move ghost around and eat dots and pills and
' pretty much everything else! No collision detection...yet
'//////////////////////////////////////////////////////////////////////////////

'//////////////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ///////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x       ' enable external clock range 5-10MHz and pll times 8
  _xinfreq = 10_000_000 + 3000   ' set frequency to 10 MHZ plus some error due to XTAL (1000-5000 usually works)
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
long x, y, tx, ty, index, dir, tile_map_index           ' demo working vars
long ghost_tx, ghost_ty, ghost_dir                      ' position of ghost in tilespace and direction

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
ghost_tx  := 4                    ' set tile location of ghost to center of screen
ghost_ty  := 6                    ' about (4,6)
ghost_dir := GHOST_TILE_LEFT      ' start ghost out with eyes to left
                       
' set up tile and sprite engine data before starting it, so no ugly startup
' points ptrs to actual memory storage for tile engine
tile_map_base_ptr_parm        := @pitfall_demo_tilemap
tile_bitmaps_base_ptr_parm    := @tile_bitmaps
tile_palettes_base_ptr_parm   := @pitfall_tile_palette_map

' these control the sprite engine, all 0 for now, no sprites
tile_map_sprite_cntrl_parm    := $00_00 ' 0 sprites, tile map set to 0=16 tiles wide, 1=32 tiles, 2=64 tiles, etc.
tile_sprite_tbl_base_ptr_parm := 0 
tile_status_bits_parm         := 0

' launch a COG with ASM video driver
gfx.start(@tile_map_base_ptr_parm)

' enter main event loop...
repeat while 1
  
  ' main even loop code here...

  ' draw the ghost tile by overwriting the screen tile word destructively, both
  ' the palette index and the tile index
  ' note the add of "ghost_dir", this modifies the tiles, so we can see the ghost
  ' turn right, left, up, down as he moves.
 
  ' test if player is trying to move ghost, if so write a blank tile at current location
  ' overwriting tile index and palette
  ' then move ghost
  if (game_pad.button(NES0_RIGHT))
    ' clear tile
    tile_map2[ghost_tx + ghost_ty << 4] := $03_00  
    ' move ghost
    ghost_tx++
    ' set eye direction, which affects tile selected during rendering.
    ghost_dir := GHOST_TILE_RIGHT
 
  if (game_pad.button(NES0_LEFT))
    ' clear tile
    tile_map2[ghost_tx + ghost_ty << 4] := $03_00  
    ' move ghost
    ghost_tx--
    ' set eye direction, which affects tile selected during rendering.
    ghost_dir := GHOST_TILE_LEFT

  if (game_pad.button(NES0_UP))
    ' clear tile
    tile_map2[ghost_tx + ghost_ty << 4] := $03_00  
    ' move ghost                             
    ghost_ty--
    ' set eye direction, which affects tile selected during rendering.
    ghost_dir := GHOST_TILE_UP
 
  if (game_pad.button(NES0_DOWN))
    ' clear tile
    tile_map2[ghost_tx + ghost_ty << 4] := $03_00  
    ' move ghost
    ghost_ty++
    ' set eye direction, which affects tile selected during rendering.
    ghost_dir := GHOST_TILE_DOWN

  ' bounds check ghost, keep it on screen, use SPIN operators for bounds testing
  ghost_tx <#= 9 ' if (ghost_tx > 9) then ghost_tx = 9
  ghost_tx #>= 0 ' if (ghost_tx < 0) then ghost_tx = 0  

  ghost_ty <#= 11 ' if (ghost_ty > 11) then ghost_tx = 11
  ghost_ty #>= 0  ' if (ghost_ty < 0) then ghost_ty = 0  

  ' draw ghost down
  tile_map2[ghost_tx + ghost_ty << 4] := $03_04 + ghost_dir

  ' delay a moment, otherwise everything will blur!
  repeat 20_000
    
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



' Tilemap based on file "pitfall_demo_map_04.map", dimensions 16x12
' 50 bitmap tiles extracted from bitmap tile set "pitfall_tiles_work_04.bmp"
pitfall_demo_tilemap    WORD
              WORD      $00_00, $01_01, $02_02, $03_03, $04_04, $00_00, $00_00, $00_00, $00_00, $00_00, $00_00, $00_00, $00_00, $00_00, $00_00, $00_00 ' Row 0
              WORD      $05_05, $06_06, $07_07, $08_08, $07_07, $07_07, $00_00, $00_00, $00_00, $00_00, $00_00, $00_00, $00_00, $00_00, $00_00, $00_00 ' Row 1
              WORD      $09_09, $0A_0A, $0B_0B, $0B_0B, $0B_0B, $0C_0C, $0D_0D, $0E_0E, $0F_0F, $10_10, $11_11, $12_12, $13_13, $14_14, $15_15, $16_16 ' Row 2
              WORD      $17_17, $18_18, $0B_0B, $0B_0B, $0B_0B, $0B_0B, $19_19, $0B_0B, $0B_0B, $0B_0B, $0B_0B, $1A_1A, $0B_0B, $0B_0B, $1B_1B, $0B_0B ' Row 3
              WORD      $1C_1C, $1D_1D, $0B_0B, $0B_0B, $0B_0B, $0B_0B, $1E_1E, $0B_0B, $0B_0B, $0B_0B, $0B_0B, $1F_1F, $0B_0B, $0B_0B, $20_20, $0B_0B ' Row 4
              WORD      $21_21, $21_21, $21_21, $21_21, $22_22, $21_21, $21_21, $21_21, $21_21, $21_21, $21_21, $21_21, $21_21, $21_21, $21_21, $21_21 ' Row 5
              WORD      $21_21, $23_23, $21_21, $21_21, $21_21, $21_21, $21_21, $21_21, $23_23, $21_21, $24_24, $25_25, $26_26, $27_27, $28_28, $23_23 ' Row 6
              WORD      $29_29, $2A_2A, $2B_2B, $2B_2B, $2B_2B, $2B_2B, $2B_2B, $2B_2B, $2A_2A, $2B_2B, $2B_2B, $2B_2B, $2B_2B, $2B_2B, $2B_2B, $2A_2A ' Row 7
              WORD      $29_29, $2C_2C, $2B_2B, $2B_2B, $2B_2B, $2B_2B, $2B_2B, $2B_2B, $2C_2C, $2B_2B, $2B_2B, $2B_2B, $2B_2B, $2B_2B, $2B_2B, $2C_2C ' Row 8
              WORD      $29_29, $2D_2D, $2B_2B, $2B_2B, $2B_2B, $2B_2B, $2B_2B, $2B_2B, $2D_2D, $2B_2B, $2B_2B, $2B_2B, $2E_2E, $2B_2B, $2B_2B, $2D_2D ' Row 9
              WORD      $2F_2F, $2F_2F, $2F_2F, $2F_2F, $30_30, $2F_2F, $2F_2F, $2F_2F, $2F_2F, $30_30, $2F_2F, $2F_2F, $2F_2F, $2F_2F, $2F_2F, $2F_2F ' Row 10
              WORD      $31_31, $2B_2B, $2B_2B, $2B_2B, $2A_2A, $2B_2B, $2B_2B, $2B_2B, $2B_2B, $2A_2A, $2B_2B, $2B_2B, $2B_2B, $2B_2B, $2B_2B, $2E_2E ' Row 11





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

tile_bitmaps 
              ' tile bitmap memory, each tile 16x16 pixels, or 1 LONG by 16,
              ' 64-bytes each, also, note that they are mirrored right to left
              ' since the VSU streams from low to high bits, so your art must
              ' be reflected, we could remedy this in the engine, but for fun
              ' I leave it as a challenge in the art, since many engines have
              ' this same artifact
              ' for this demo, only 4 tile bitmaps defined


' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(9, 2), size=(16, 16), palette index=(0)
pitfall_tile_tx9_ty2_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(1, 8), size=(16, 16), palette index=(1)
pitfall_tile_tx1_ty8_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_2_2_2_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_2_2_2_2_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_2_2_2_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_2_2_2_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_2_2_2_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_2_2_2_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_2_2_2_1_1_1_1_1_1
              LONG %%1_1_1_1_1_2_2_2_2_2_2_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(9, 8), size=(16, 16), palette index=(2)
pitfall_tile_tx9_ty8_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_2_2_2_2_2_2_1_1_1_1_1
              LONG %%1_1_1_2_2_2_1_1_1_1_2_2_3_1_1_1
              LONG %%1_1_1_2_2_2_1_1_1_1_2_2_2_1_1_1
              LONG %%1_1_1_2_2_2_1_1_1_1_2_2_2_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_2_2_1_1_1_1_1
              LONG %%1_1_1_2_2_2_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_1_1_1_1_1_2_2_1_1_1
              LONG %%1_1_1_1_1_2_2_2_2_2_2_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(6, 8), size=(16, 16), palette index=(3)
pitfall_tile_tx6_ty8_bitmap    LONG
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_1_1_1_1_1_1_0_0_0_0_0
              LONG %%0_0_0_3_1_0_0_0_0_0_1_1_1_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_1_1_1_0_0_0
              LONG %%0_0_0_0_0_1_1_1_1_1_1_1_1_0_0_0
              LONG %%0_0_0_1_1_1_0_0_0_0_1_1_1_0_0_0
              LONG %%0_0_0_1_1_1_0_0_0_0_1_1_1_0_0_0
              LONG %%0_0_0_1_1_1_0_0_0_0_1_1_1_0_0_0
              LONG %%0_0_0_0_0_1_1_1_1_1_1_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(7, 8), size=(16, 16), palette index=(4)
pitfall_tile_tx7_ty8_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_2_2_2_1_1_1_1
              LONG %%1_1_1_2_2_1_1_1_1_1_1_2_1_1_1_1
              LONG %%1_1_1_1_2_2_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_2_2_2_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(13, 8), size=(16, 16), palette index=(5)
pitfall_tile_tx13_ty8_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_1_2_1_2_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_1_2_1_2_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_1_2_1_2_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_1_2_1_2_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_1_2_1_2_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_1_2_1_2_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_1_2_1_2_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_1_2_1_2_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(2, 8), size=(16, 16), palette index=(6)
pitfall_tile_tx2_ty8_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_2_2_2_2_2_2_1_1_1_1_1
              LONG %%1_1_1_2_2_2_1_1_1_1_1_2_2_1_1_1
              LONG %%1_1_1_2_2_2_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_2_2_2_2_2_2_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_2_2_2_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(0, 8), size=(16, 16), palette index=(7)
pitfall_tile_tx0_ty8_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_2_2_2_2_2_2_1_1_1_1_1
              LONG %%1_1_1_2_2_2_1_1_1_1_2_2_2_1_1_1
              LONG %%1_1_1_2_2_2_1_1_1_1_2_2_2_1_1_1
              LONG %%1_1_1_2_2_2_1_1_1_1_2_2_2_1_1_1
              LONG %%1_1_1_2_2_2_1_1_1_1_2_2_2_1_1_1
              LONG %%1_1_1_2_2_2_1_1_1_1_2_2_2_1_1_1
              LONG %%1_1_1_2_2_2_1_1_1_1_2_2_2_1_1_1
              LONG %%1_1_1_1_1_2_2_2_2_2_2_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(10, 8), size=(16, 16), palette index=(8)
pitfall_tile_tx10_ty8_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_2_2_2_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_2_2_2_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_2_2_2_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_2_2_2_2_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(0, 1), size=(16, 16), palette index=(9)
pitfall_tile_tx0_ty1_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_0_0_0_0_0_0_0
              LONG %%1_1_1_1_1_1_1_1_1_0_0_0_0_0_0_0
              LONG %%2_0_0_2_2_2_0_0_0_0_0_0_0_0_0_0
              LONG %%2_2_2_2_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%2_2_2_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%2_2_2_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%2_2_2_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%2_2_2_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%2_2_3_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%2_2_2_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%2_2_2_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%2_2_2_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%2_2_2_0_0_0_0_0_0_0_0_0_0_0_0_0

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(1, 1), size=(16, 16), palette index=(10)
pitfall_tile_tx1_ty1_bitmap    LONG
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%0_0_0_0_0_0_2_2_2_2_2_2_2_2_2_2
              LONG %%0_0_0_0_0_0_2_2_2_2_2_2_2_2_2_2
              LONG %%0_0_0_0_0_0_0_0_0_1_0_0_2_2_2_2
              LONG %%0_0_0_0_0_0_0_0_0_1_0_0_2_2_2_2
              LONG %%0_0_0_0_0_0_0_0_0_1_1_1_0_0_1_1
              LONG %%0_0_0_0_0_0_0_0_0_0_1_1_1_1_1_1
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_1_1_3_1
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_1_1_1_1
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_1_1_1_1
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_1_1_1_1
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_1_1_1_1
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_1_1_1_1
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_1_1_1_1
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_1_1_1_1
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(8, 2), size=(16, 16), palette index=(11)
pitfall_tile_tx8_ty2_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(3, 1), size=(16, 16), palette index=(12)
pitfall_tile_tx3_ty1_bitmap    LONG
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_1_1_1_1
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_1_1_1_1
              LONG %%2_2_2_2_2_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_2_2_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(4, 1), size=(16, 16), palette index=(13)
pitfall_tile_tx4_ty1_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%0_0_0_0_0_2_2_2_1_1_1_1_1_1_1_1
              LONG %%0_0_0_0_0_0_3_2_1_1_1_1_1_1_1_1
              LONG %%0_0_0_0_0_0_0_0_2_2_3_2_2_2_2_0
              LONG %%0_0_0_0_0_0_0_0_2_2_2_2_2_2_2_0
              LONG %%0_0_0_0_0_0_0_0_2_2_2_2_2_2_2_0
              LONG %%0_0_0_0_0_0_0_0_2_2_2_2_2_2_2_0
              LONG %%0_0_0_0_0_0_0_0_2_2_2_2_2_2_3_0
              LONG %%0_0_0_0_0_0_0_0_2_2_2_2_2_2_2_0
              LONG %%0_0_0_0_0_0_0_0_2_2_2_2_2_2_2_0
              LONG %%0_0_0_0_0_0_0_0_2_2_2_2_2_2_2_0
              LONG %%0_0_0_0_0_0_0_0_2_2_2_2_2_2_2_0

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(5, 1), size=(16, 16), palette index=(14)
pitfall_tile_tx5_ty1_bitmap    LONG
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%1_1_1_1_1_2_2_2_2_2_2_2_2_2_2_2
              LONG %%1_1_1_1_1_2_2_2_2_2_2_2_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(6, 1), size=(16, 16), palette index=(15)
pitfall_tile_tx6_ty1_bitmap    LONG
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_1_1_1_1_1_1_1_1
              LONG %%2_2_2_2_2_2_2_2_1_1_1_1_1_1_1_1
              LONG %%2_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(8, 1), size=(16, 16), palette index=(16)
pitfall_tile_tx8_ty1_bitmap    LONG
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%2_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(9, 1), size=(16, 16), palette index=(17)
pitfall_tile_tx9_ty1_bitmap    LONG
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_2_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(10, 1), size=(16, 16), palette index=(18)
pitfall_tile_tx10_ty1_bitmap    LONG
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_2_2_2
              LONG %%0_0_0_0_0_2_2_2_2_2_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_3_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_3_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(11, 1), size=(16, 16), palette index=(19)
pitfall_tile_tx11_ty1_bitmap    LONG
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_2_2_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_2_2_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(12, 1), size=(16, 16), palette index=(20)
pitfall_tile_tx12_ty1_bitmap    LONG
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(13, 1), size=(16, 16), palette index=(21)
pitfall_tile_tx13_ty1_bitmap    LONG
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_2_0_0_1_0_0_0_0
              LONG %%2_2_2_2_2_2_2_2_2_0_0_1_0_0_0_0
              LONG %%1_1_1_0_1_1_1_0_0_1_1_1_0_0_0_0
              LONG %%0_1_1_1_1_1_1_1_1_1_1_0_0_0_0_0
              LONG %%0_0_0_1_1_1_1_1_1_0_0_0_0_0_0_0
              LONG %%0_0_0_1_1_1_1_1_1_0_0_0_0_0_0_0
              LONG %%0_0_0_1_1_1_1_1_1_0_0_0_0_0_0_0
              LONG %%0_0_0_1_1_1_1_1_1_0_0_0_0_0_0_0
              LONG %%0_0_0_1_1_1_1_1_1_0_0_0_0_0_0_0
              LONG %%0_0_0_1_1_1_1_1_1_0_0_0_0_0_0_0
              LONG %%0_0_0_1_1_1_1_1_1_0_0_0_0_0_0_0
              LONG %%0_0_0_1_1_1_3_1_1_0_0_0_0_0_0_0
              LONG %%0_0_0_1_1_1_1_1_1_0_0_0_0_0_0_0

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(14, 1), size=(16, 16), palette index=(22)
pitfall_tile_tx14_ty1_bitmap    LONG
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%1_1_1_1_1_1_2_2_2_2_2_2_2_2_2_2
              LONG %%1_1_1_1_1_1_2_2_2_2_2_2_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_3
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(0, 2), size=(16, 16), palette index=(23)
pitfall_tile_tx0_ty2_bitmap    LONG
              LONG %%2_2_0_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_0_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_0_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_0_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(1, 2), size=(16, 16), palette index=(24)
pitfall_tile_tx1_ty2_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_0_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_0_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_0
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_0_2

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(4, 2), size=(16, 16), palette index=(25)
pitfall_tile_tx4_ty2_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_0_2_2_2_2_2_0_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_0_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_0_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_0_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_0_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_0_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_0_2_2_2_2_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(10, 2), size=(16, 16), palette index=(26)
pitfall_tile_tx10_ty2_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_0_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_0_2_1_1_1
              LONG %%1_1_1_1_1_1_1_0_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(13, 2), size=(16, 16), palette index=(27)
pitfall_tile_tx13_ty2_bitmap    LONG
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_0_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_0_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_0_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_0_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(0, 3), size=(16, 16), palette index=(28)
pitfall_tile_tx0_ty3_bitmap    LONG
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%0_2_0_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_0_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_0_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_0_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_0_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_0_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(1, 3), size=(16, 16), palette index=(29)
pitfall_tile_tx1_ty3_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_0_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_0_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_0_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_0_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_0_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_2_2_2_2

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(4, 3), size=(16, 16), palette index=(30)
pitfall_tile_tx4_ty3_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_0_2_0_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_0_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_0_2_2_0_2_1
              LONG %%1_1_1_1_1_1_1_1_2_0_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_0_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_0_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_0_2_1
              LONG %%1_1_1_1_1_1_1_1_2_0_2_2_2_2_2_1
              LONG %%1_1_1_1_1_1_1_1_0_2_2_2_2_0_2_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_2_2_2_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(10, 3), size=(16, 16), palette index=(31)
pitfall_tile_tx10_ty3_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_0_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_0_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_0_2_2_2_0_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_0_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_0_2_2_2_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(13, 3), size=(16, 16), palette index=(32)
pitfall_tile_tx13_ty3_bitmap    LONG
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_0_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_0_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_0_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%1_1_1_2_2_2_2_2_2_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(0, 5), size=(16, 16), palette index=(33)
pitfall_tile_tx0_ty5_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(5, 0), size=(16, 16), palette index=(34)
pitfall_tile_tx5_ty0_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_2_2_2_2_1_1_1_1
              LONG %%1_1_1_1_1_1_2_2_2_1_1_2_2_2_1_1
              LONG %%1_1_1_1_1_1_2_2_1_1_1_1_2_2_1_1
              LONG %%1_1_1_1_1_1_1_1_2_1_1_1_2_2_1_1
              LONG %%1_1_1_2_1_1_1_1_1_1_1_1_2_2_1_1
              LONG %%1_1_1_2_2_2_1_1_1_1_1_2_2_2_1_1
              LONG %%1_1_1_1_1_1_2_2_2_2_2_2_2_2_1_1
              LONG %%1_1_1_1_1_1_2_2_2_2_2_2_1_1_1_1
              LONG %%1_2_2_1_2_2_2_2_2_2_2_1_1_1_1_1
              LONG %%1_1_1_2_1_1_1_1_2_2_2_1_1_1_1_1
              LONG %%1_2_2_1_2_2_1_1_1_1_1_1_2_2_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(3, 2), size=(16, 16), palette index=(35)
pitfall_tile_tx3_ty2_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(0, 7), size=(16, 16), palette index=(36)
pitfall_tile_tx0_ty7_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_2_1_1_1_1_1_1_1
              LONG %%2_2_2_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(1, 7), size=(16, 16), palette index=(37)
pitfall_tile_tx1_ty7_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_2_2_2_1_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_1_1_1_1
              LONG %%1_1_1_1_1_1_2_2_2_2_2_2_1_1_1_1
              LONG %%3_3_3_3_3_2_2_2_2_3_1_2_1_1_1_1
              LONG %%3_2_2_2_2_2_2_2_2_3_3_3_3_3_3_3
              LONG %%3_2_3_2_2_2_3_3_2_3_3_3_3_3_3_3
              LONG %%2_2_2_2_2_2_2_3_3_3_3_3_3_3_3_3
              LONG %%2_2_2_2_3_3_2_3_3_3_3_3_3_3_3_3
              LONG %%2_2_2_2_3_3_3_3_3_3_3_3_3_3_3_3
              LONG %%2_2_2_2_3_2_2_2_3_2_2_2_2_2_1_1
              LONG %%1_2_2_2_2_2_2_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(2, 7), size=(16, 16), palette index=(38)
pitfall_tile_tx2_ty7_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%2_2_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(5, 7), size=(16, 16), palette index=(39)
pitfall_tile_tx5_ty7_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_2_2_2_1_1_1_1
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_1_1_1_1
              LONG %%1_1_1_1_1_1_2_2_2_2_2_2_1_1_1_1
              LONG %%1_1_1_1_1_2_2_2_2_3_3_2_3_3_3_3
              LONG %%3_2_2_2_2_2_2_2_2_3_3_3_3_3_3_3
              LONG %%3_2_3_2_2_2_3_3_2_3_3_3_3_3_3_3
              LONG %%2_2_2_2_2_2_2_3_3_3_3_3_3_3_3_3
              LONG %%2_2_2_2_3_3_2_3_3_3_3_3_3_3_3_3
              LONG %%2_2_2_2_3_3_3_3_3_3_3_3_3_3_3_3
              LONG %%2_2_2_2_3_2_2_2_3_2_2_2_2_2_3_3
              LONG %%1_2_2_2_2_2_2_2_2_2_2_2_2_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(6, 7), size=(16, 16), palette index=(40)
pitfall_tile_tx6_ty7_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_2_2_2
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_2_2_2
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%1_1_1_1_1_1_1_2_2_2_2_2_2_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_2_2_2
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(7, 2), size=(16, 16), palette index=(41)
pitfall_tile_tx7_ty2_bitmap    LONG
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%1_1_1_1_3_1_1_1_1_1_1_3_1_1_1_1
              LONG %%1_1_1_1_3_1_1_1_1_1_1_3_1_1_1_1
              LONG %%1_1_1_1_3_1_1_1_1_1_1_3_1_1_1_1
              LONG %%1_1_1_1_3_1_1_1_1_1_1_3_1_1_1_1
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%1_1_1_1_1_1_1_3_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_3_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_3_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_3_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_3_1_1_1_1_1_1_1_1
              LONG %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              LONG %%1_1_3_1_1_1_1_1_1_3_1_1_1_1_1_1
              LONG %%1_1_3_1_1_1_1_1_1_3_1_1_1_1_1_1
              LONG %%1_1_3_1_1_1_1_1_1_3_1_1_1_1_1_1
              LONG %%1_1_3_1_1_1_1_1_1_3_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(6, 3), size=(16, 16), palette index=(42)
pitfall_tile_tx6_ty3_bitmap    LONG
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_2_1_1_1_1_1_1_1_1_1_1_2_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_2_1_1_1_1_1_1_1_1_1_1_2_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_2_1_1_1_1_1_1_1_1_1_1_2_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(0, 0), size=(16, 16), palette index=(43)
pitfall_tile_tx0_ty0_bitmap    LONG
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(7, 3), size=(16, 16), palette index=(44)
pitfall_tile_tx7_ty3_bitmap    LONG
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_2_1_1_1_1_1_1_1_1_1_1_2_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_2_1_1_1_1_1_1_1_1_1_1_2_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_2_1_1_1_1_1_1_1_1_1_1_2_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(8, 3), size=(16, 16), palette index=(45)
pitfall_tile_tx8_ty3_bitmap    LONG
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_2_1_1_1_1_1_1_1_1_1_1_2_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_2_1_1_1_1_1_1_1_1_1_1_2_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_2_1_1_1_1_1_1_1_1_1_1_2_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(3, 0), size=(16, 16), palette index=(46)
pitfall_tile_tx3_ty0_bitmap    LONG
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_1_1_1_1_0_0_0_0_0_0_0
              LONG %%0_0_0_1_1_1_0_0_1_1_0_0_0_0_0_0
              LONG %%0_0_1_1_0_0_0_1_1_1_0_0_0_0_0_0
              LONG %%0_0_1_1_0_0_1_1_1_0_0_0_0_0_0_0
              LONG %%0_0_1_1_1_0_0_0_0_0_0_1_1_0_0_0
              LONG %%0_0_0_1_1_1_1_1_1_1_1_0_0_0_0_0
              LONG %%0_0_0_0_1_1_1_1_1_1_0_0_0_0_0_0
              LONG %%0_0_0_0_0_1_1_1_1_1_1_1_0_0_0_0
              LONG %%0_0_0_0_0_0_1_1_0_0_0_1_1_0_0_0
              LONG %%0_0_0_0_1_1_0_0_0_1_1_0_1_1_0_0

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(5, 3), size=(16, 16), palette index=(47)
pitfall_tile_tx5_ty3_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(5, 2), size=(16, 16), palette index=(48)
pitfall_tile_tx5_ty2_bitmap    LONG
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

' Extracted from file "pitfall_tiles_work_04.bmp" at tile=(4, 0), size=(16, 16), palette index=(49)
pitfall_tile_tx4_ty0_bitmap    LONG
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              LONG %%0_0_0_0_1_1_1_1_0_0_0_0_0_0_0_0
              LONG %%0_0_1_1_1_0_0_1_1_1_0_0_0_0_0_0
              LONG %%0_0_1_1_0_0_0_0_1_1_0_0_0_0_0_0
              LONG %%0_0_1_1_0_0_0_1_0_0_0_0_0_0_0_0
              LONG %%0_0_1_1_0_0_0_0_0_0_0_0_1_0_0_0
              LONG %%0_0_1_1_1_0_0_0_0_0_1_1_1_0_0_0
              LONG %%0_0_1_1_1_1_1_1_1_1_0_0_0_0_0_0
              LONG %%0_0_0_0_1_1_1_1_1_1_0_0_0_0_0_0
              LONG %%0_0_0_0_0_1_1_1_1_1_1_1_0_1_1_0
              LONG %%0_0_0_0_0_1_1_1_0_0_0_0_1_0_0_0
              LONG %%0_0_1_1_0_0_0_0_0_0_1_1_0_1_1_0

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

' /////////////////////////////////////////////////////////////////////////////

              ' palette memory (1..255 palettes) each palette 4-BYTEs or 1-LONG
              ' pacman ish palette needs 4 colors in each palette to have certain properties
              ' color 0 - used for black
              ' color 1 - used for walls (unless, ghost will cross a wall, we can reuse this color for the ghost if we need 2 colors for ghost, or have multiple colored walls)
              ' color 2 - used for ghost color (can change possibly tile to tile)
              ' color 3 - white


' 50 palettes extracted from file "pitfall_tiles_work_04.bmp" using palette color map 0
pitfall_tile_palette_map    LONG
              LONG $07_06_9A_02 ' palette index 0
              LONG $07_07_9A_02 ' palette index 1
              LONG $07_1E_9A_02 ' palette index 2
              LONG $1E_07_07_9A ' palette index 3
              LONG $07_07_9A_02 ' palette index 4
              LONG $07_07_9A_02 ' palette index 5
              LONG $07_07_9A_02 ' palette index 6
              LONG $07_07_9A_02 ' palette index 7
              LONG $07_07_9A_02 ' palette index 8
              LONG $02_7A_9A_9C ' palette index 9
              LONG $02_9A_7A_9C ' palette index 10
              LONG $07_06_9C_02 ' palette index 11
              LONG $07_9A_9C_02 ' palette index 12
              LONG $02_7A_9A_9C ' palette index 13
              LONG $07_9A_9C_02 ' palette index 14
              LONG $07_9A_9C_02 ' palette index 15
              LONG $07_9A_9C_02 ' palette index 16
              LONG $07_9A_9C_02 ' palette index 17
              LONG $02_7A_9C_9A ' palette index 18
              LONG $07_9A_9C_02 ' palette index 19
              LONG $07_9A_9C_02 ' palette index 20
              LONG $02_9A_7A_9C ' palette index 21
              LONG $7A_9A_9C_02 ' palette index 22
              LONG $02_7A_9C_02 ' palette index 23
              LONG $02_7A_9C_02 ' palette index 24
              LONG $02_7A_9C_02 ' palette index 25
              LONG $02_7A_9C_02 ' palette index 26
              LONG $02_7A_9C_02 ' palette index 27
              LONG $02_7A_9C_02 ' palette index 28
              LONG $02_7A_9C_02 ' palette index 29
              LONG $02_7A_9C_02 ' palette index 30
              LONG $02_7A_9C_02 ' palette index 31
              LONG $02_7A_9C_02 ' palette index 32
              LONG $07_06_6C_02 ' palette index 33
              LONG $07_07_6C_02 ' palette index 34
              LONG $07_06_6C_02 ' palette index 35
              LONG $07_DB_6C_02 ' palette index 36
              LONG $DB_9A_6C_02 ' palette index 37
              LONG $07_DB_6C_02 ' palette index 38
              LONG $DB_9A_6C_02 ' palette index 39
              LONG $07_DB_6C_02 ' palette index 40
              LONG $4A_04_4B_02 ' palette index 41
              LONG $07_07_5A_02 ' palette index 42
              LONG $07_06_04_02 ' palette index 43
              LONG $07_07_5A_02 ' palette index 44
              LONG $07_07_5A_02 ' palette index 45
              LONG $07_06_07_02 ' palette index 46
              LONG $07_06_5B_02 ' palette index 47
              LONG $07_06_5B_02 ' palette index 48
              LONG $07_06_07_02 ' palette index 49
              
' some pacman palettes...              
palette_map   long $07_5C_0C_02 ' palette 0 - background and wall tiles, 0-black, 1-blue, 2-red, 3-white
              long $07_5C_BC_02 ' palette 1 - background and wall tiles, 0-black, 1-green, 2-red, 3-white
              long $07_2C_0C_02 ' palette 2 - background and wall tiles, 0-black, 1-green, 2-voilet, 3-white
              LONG $DB_9A_6C_02 ' palette index 0
              