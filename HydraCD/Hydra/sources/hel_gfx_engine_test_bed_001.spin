' /////////////////////////////////////////////////////////////////////////////
' VERSION: x.x
' AUTHOR: Andre' LaMothe
' LAST MODIFIED:
' COMMENTS:

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

  ' debugger printing constants
  ASCII_LF        = $0A 
  ASCII_CR        = $0D
  ASCII_ESC       = $1B
  ASCII_LB        = $5B ' [ 
  ASCII_SPACE     = $20 ' space

'//////////////////////////////////////////////////////////////////////////////
' VARS SECTION ////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

VAR


' begin parameter list ////////////////////////////////////////////////////////
' tile engine data structure pointers (can be changed in real-time by app!)
long tile_map_base_ptr_parm                             ' base address of the tile map
long tile_bitmaps_base_ptr_parm                         ' base address of the tile bitmaps
long tile_palettes_base_ptr_parm                        ' base address of the palettes

long tile_map_sprite_cntrl_parm                         ' pointer to the value that holds various "control" values for the tile map/sprite engine
                                                        ' currently, encodes width of map, and number of sprites to process up to 8 in following format
                                                        ' $xx_xx_ss_ww, xx is don't care/unused
                                                        ' ss = number of sprites to process 1..8
                                                        ' ww = the number of "screens" or multiples of 16 that the tile map is
                                                        ' eg. 0 would be 16 wide (standard), 1 would be 32 tiles, 2 would be 64 tiles, etc.
                                                        ' this allows multiscreen width playfields and thus large horizontal/vertical scrolling games
                                                        ' note that the final size is always a power of 2 multiple of 16

long tile_sprite_tbl_base_ptr_parm                      ' base address of sprite table


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


' these are temporary for the debugger interface, 4 LONGs accessed as bytes depending on what they are
long debug_status_parm                               ' this is the status of the debugger print, 0-ready for input, 1-busy
long debug_string_parm                               ' 4 characters, space filled for blanks
long debug_value_parm                                ' 8 hex digits will print out
long debug_pos_parm                                  ' position to print the string at, $00_00_yy_xx


' end parameter list ///////////////////////////////////////////////////////////

byte sbuffer[80] ' string buffer for printing

long x,y, index, dir, ghost_palette

'//////////////////////////////////////////////////////////////////////////////
'OBJS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

OBJ

game_pad :      "gamepad_drv_001.spin"
serial :        "FullDuplex_serial_drv_010.spin"   
gfx:            "HEL_GFX_ENGINE_040.SPIN"

'//////////////////////////////////////////////////////////////////////////////
'PUBS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////


' COG INTERPRETER STARTS HERE...@ THE FIRST PUB

PUB Start
' This is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

' initialize position of player
x := 160/2
y := 192/2

' star the game pad driver
game_pad.start

' start the serial debugger
serial.start(31, 30, 9600) ' receive pin, transmit pin, baud rate
serial.txstring(@debug_clearscreen_string)
serial.txstring(@debug_home_string)
serial.txstring(@debug_title_string)   


' points ptrs to actual memory storage for tile engine
tile_map_base_ptr_parm        := @tile_maps
tile_bitmaps_base_ptr_parm    := @tile_bitmaps
tile_palettes_base_ptr_parm   := @palette_map
tile_map_sprite_cntrl_parm    := $00_00_05_01 ' set for 5 sprites and width 32 tiles (2 screens wide), 0 = 16 tiles, 1 = 32 tiles, 2 = 64 tiles, 3 = 128 tiles, etc.
tile_sprite_tbl_base_ptr_parm := @sprite_tbl[0] 
tile_status_bits_parm         := 0

' enable/initialize a sprite
sprite_tbl[0] := $10_10_00_01     ' sprite 0 state: y=xx, x=$xx, z=$xx, enabled/disabled
sprite_tbl[1] := @sprite_bitmap_0 ' sprite 0 bitmap ptr

sprite_tbl[2] := $10_20_00_01     ' sprite 1 state: y=xx, x=$xx, z=$xx, enabled/disabled
sprite_tbl[3] := @sprite_bitmap_0 ' sprite 1 bitmap ptr

sprite_tbl[4] := $10_30_00_01     ' sprite 2 state: y=xx, x=$xx, z=$xx, enabled/disabled
sprite_tbl[5] := @sprite_bitmap_0 ' sprite 2 bitmap ptr
                                           
sprite_tbl[6] := $10_40_00_01     ' sprite 3 state: y=xx, x=$xx, z=$xx, enabled/disabled
sprite_tbl[7] := @sprite_bitmap_0 ' sprite 3 bitmap ptr


sprite_tbl[8] := $10_50_00_01     ' sprite 4 state: y=xx, x=$xx, z=$xx, enabled/disabled
sprite_tbl[9] := @sprite_bitmap_0 ' sprite 4 bitmap ptr

sprite_tbl[10] := $40_20_00_00     ' sprite 5 state: y=xx, x=$xx, z=$xx, enabled/disabled
sprite_tbl[11] := @sprite_bitmap_0 ' sprite 5 bitmap ptr

sprite_tbl[12] := $40_40_00_00     ' sprite 6 state: y=xx, x=$xx, z=$xx, enabled/disabled
sprite_tbl[13] := @sprite_bitmap_0 ' sprite 6 bitmap ptr

sprite_tbl[14] := $80_60_00_00     ' sprite 7 state: y=xx, x=$xx, z=$xx, enabled/disabled
sprite_tbl[15] := @sprite_bitmap_0 ' sprite 7 bitmap ptr



' set up debugger stuff
debug_status_parm   := $00000000                            
debug_string_parm   := $4F_4C_45_48                            
debug_value_parm    := $12345678                            
debug_pos_parm      := $00000000                          

' launch a COG with ASM video driver
' cognew(@HEL_GFX_Driver_Entry, @tile_map_base_ptr_parm)

gfx.start(@tile_map_base_ptr_parm)

repeat while 1

  'tile_map0[(x+y<<5)] := $00_00
  ' move
  if (game_pad.button(NES0_RIGHT))
    x+=2
    if (game_pad.button(NES0_SELECT))
      tile_map_base_ptr_parm += 2
    dir := 1
    ' test for maze collision
'    if ((tile_map0[(x+y<<5)] & $00_FF) == 3)
'      x--
       
  if (game_pad.button(NES0_LEFT))
     x-=2
    if (game_pad.button(NES0_SELECT))
      tile_map_base_ptr_parm -= 2
    dir := 0
    ' test for maze collision
'    if ((tile_map0[(x+y<<5)] & $00_FF) == 3)
'      x++

  if (game_pad.button(NES0_DOWN))
    y+=2
    if (game_pad.button(NES0_SELECT))
      tile_map_base_ptr_parm += 64

    dir := 3
    ' test for maze collision
 '   if ((tile_map0[(x+y<<5)] & $00_FF) == 3)
'      y--

  if (game_pad.button(NES0_UP))
    y-=2
    if (game_pad.button(NES0_SELECT))
      tile_map_base_ptr_parm -= 64
    dir := 2
    ' test for maze collision
 '   if ((tile_map0[(x+y<<5)] & $00_FF) == 3)
'      y++


  if (game_pad.button(NES0_START))
    repeat 10_000
    if (tile_map_base_ptr_parm == @tile_map0)
      tile_map_base_ptr_parm := @tile_map1
    else
      tile_map_base_ptr_parm := @tile_map0


  if (game_pad.button(NES0_SELECT))

    repeat 10_000
    if (++ghost_palette > 3)
        ghost_palette := 0


  ' draw, wait another vsync
  'tile_map0[(x+y<<5)] := ($01_00 + ghost_palette << 8) + ($00_06 + dir)

  
  repeat while ((tile_status_bits_parm & $01) == $01)
  repeat while ((tile_status_bits_parm & $01) == $00)

'  repeat while ((tile_status_bits_parm & $01) == $01)
'  repeat while ((tile_status_bits_parm & $01) == $00)

'  repeat while ((tile_status_bits_parm & $01) == $01)
'  repeat while ((tile_status_bits_parm & $01) == $00)

  sprite_tbl[0] := (y << 24) + (x << 16) + (0 << 8) + ($01)
   

  repeat 1_000

  Debugger_Print_Watch(debug_pos_parm, debug_string_parm, debug_value_parm)


    
  ' return back to repeat main event loop...

' parent COG will terminate now...if it gets to this point



PUB Debugger_Print_Watch(watch_pos, watch_string, watch_value) | cx, cy
' this functions prints the watch_string then next to it the watch_value in hex digits on the VT100 terminal
' connected to the serial port via the USB connection
' parms
'
' watch_pos    - holds the x,y in following format $00_00_yy_xx
' watch_string - holds 4 ASCII text digits for the watch label in format $aa_aa_aa_aa
' watch_value  - holds the actual 32-bit value of the watch in hex digit format $h_h_h_h_h_h_h_h_h

' extract printing location
cx := watch_pos.byte[0]
cy := watch_pos.byte[1]

' build up string
sbuffer[0] := ASCII_CR
sbuffer[1] := ASCII_LF

' copy text
bytemove(@sbuffer[2], @watch_string, 4)

' add equals
sbuffer[6] := $3D ' = character 

' now convert watch_value to hex string
repeat index from 0 to 7
  sbuffer[index+7] := hex_table[ (watch_value >> (28-index*4)) & $F ]

' null terminate the string
sbuffer[15] := 0

' print the results out to the VT100 terminal
serial.txstring(@sbuffer)

' end Debugger_Print 



DAT

hex_table     byte    "0123456789ABCDEF"      


tile_maps     ' you place all your 16x12 tile maps here, you can have as many as you like, in real-time simply re-point the
              ' tile_map_base_ptr_parm to any time map and within 1 frame the tile map will update
              ' the engine only renders 10x12 of the tiles on the physical screen, the other 6 columns allow you some "scroll room"

              ' 16x12 WORDS each, (0..191 WORDs, 384 bytes per tile map) 2-BYTE tiles (msb)[palette_index | tile_index](lsb)
              ' 16x12 tile map, each tile is 2 bytes, there are a total of 64 tiles possible, and thus 64 palettes              
              ' column     0      1      2      3      4      5      6      7      8      9     10     11     12     13     14     15
{
tile_map0     word      $00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03 ' row 0
              word      $00_03,$00_00,$00_00,$00_00,$00_00,$00_00,$00_03,$00_00,$00_00,$00_03,$00_00,$00_00,$00_00,$00_00,$00_00,$00_03 ' row 1
              word      $00_03,$00_00,$00_03,$00_03,$00_03,$00_00,$00_03,$00_00,$00_00,$00_03,$00_00,$00_03,$00_03,$00_03,$00_00,$00_03 ' row 2
              word      $00_03,$00_00,$00_03,$00_00,$00_03,$00_00,$00_03,$00_00,$00_00,$00_03,$00_00,$00_03,$00_00,$00_03,$00_00,$00_03 ' row 3
              word      $00_03,$00_00,$00_03,$00_03,$00_03,$00_00,$00_03,$00_03,$00_03,$00_03,$00_00,$00_03,$00_03,$00_03,$00_00,$00_03 ' row 4
              word      $00_03,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_03 ' row 5
              word      $00_03,$00_00,$00_03,$00_03,$00_03,$00_00,$00_03,$00_03,$00_03,$00_03,$00_00,$00_03,$00_03,$00_03,$00_00,$00_03 ' row 6
              word      $00_03,$00_00,$00_00,$00_00,$00_03,$00_00,$00_03,$00_03,$00_03,$00_03,$00_00,$00_03,$00_00,$00_00,$00_00,$00_03 ' row 7
              word      $00_03,$00_00,$00_03,$00_00,$00_03,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_03,$00_00,$00_03,$00_00,$00_03 ' row 8
              word      $00_03,$00_00,$00_03,$00_00,$00_03,$00_00,$00_03,$00_03,$00_03,$00_03,$00_00,$00_03,$00_00,$00_03,$00_00,$00_03 ' row 9
              word      $00_03,$00_00,$00_03,$00_00,$00_00,$00_00,$00_03,$00_00,$00_00,$00_03,$00_00,$00_00,$00_00,$00_03,$00_00,$00_03 ' row 10
              word      $00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03 ' row 11
}


tile_map0     word      $00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03, $00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03 ' row 0
              word      $01_03,$00_00,$00_00,$00_00,$00_00,$00_00,$00_03,$00_00,$00_00,$00_03,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00, $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_03,$00_00,$00_00,$00_03,$00_00,$00_00,$00_00,$00_00,$00_00,$00_03 ' row 1
              word      $02_03,$00_00,$00_03,$00_03,$00_03,$00_00,$00_03,$00_00,$00_00,$00_03,$00_00,$00_03,$00_03,$00_03,$00_00,$00_00, $00_00,$00_00,$00_03,$00_03,$00_03,$00_00,$00_03,$00_00,$00_00,$00_03,$00_00,$00_03,$00_03,$00_03,$00_00,$00_03 ' row 2
              word      $03_03,$00_00,$00_03,$00_00,$00_03,$00_00,$00_03,$00_00,$00_00,$00_03,$00_00,$00_03,$00_00,$00_03,$00_00,$00_00, $00_00,$00_00,$00_03,$00_00,$00_03,$00_00,$00_03,$00_00,$00_00,$00_03,$00_00,$00_03,$00_00,$00_03,$00_00,$00_03 ' row 3
              word      $04_03,$00_00,$00_03,$00_03,$00_03,$00_00,$00_03,$00_03,$00_03,$00_03,$00_00,$00_03,$00_03,$00_03,$00_00,$00_00, $00_00,$00_00,$00_03,$00_03,$00_03,$00_00,$00_03,$00_03,$00_03,$00_03,$00_00,$00_03,$00_03,$00_03,$00_00,$00_03 ' row 4
              word      $05_03,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00, $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_03 ' row 5
              word      $06_03,$00_00,$00_03,$00_03,$00_03,$00_00,$00_03,$00_03,$00_03,$00_03,$00_00,$00_03,$00_03,$00_03,$00_00,$00_00, $00_00,$00_00,$00_03,$00_03,$00_03,$00_00,$00_03,$00_03,$00_03,$00_03,$00_00,$00_03,$00_03,$00_03,$00_00,$00_03 ' row 6
              word      $07_03,$00_00,$00_00,$00_00,$00_03,$00_00,$00_03,$00_03,$00_03,$00_03,$00_00,$00_03,$00_00,$00_00,$00_00,$00_00, $00_00,$00_00,$00_00,$00_00,$00_03,$00_00,$00_03,$00_03,$00_03,$00_03,$00_00,$00_03,$00_00,$00_00,$00_00,$00_03 ' row 7
              word      $08_03,$00_00,$00_03,$00_00,$00_03,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_03,$00_00,$00_03,$00_00,$00_00, $00_00,$00_00,$00_03,$00_00,$00_03,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_03,$00_00,$00_03,$00_00,$00_03 ' row 8
              word      $09_03,$00_00,$00_03,$00_00,$00_03,$00_00,$00_03,$00_03,$00_03,$00_03,$00_00,$00_03,$00_00,$00_03,$00_00,$00_00, $00_00,$00_00,$00_03,$00_00,$00_03,$00_00,$00_03,$00_03,$00_03,$00_03,$00_00,$00_03,$00_00,$00_03,$00_00,$00_03 ' row 9
              word      $0a_03,$00_00,$00_03,$00_00,$00_00,$00_00,$00_03,$00_00,$00_00,$00_03,$00_00,$00_00,$00_00,$00_03,$00_00,$00_00, $00_00,$00_00,$00_03,$00_00,$00_00,$00_00,$00_03,$00_00,$00_00,$00_03,$00_00,$00_00,$00_00,$00_03,$00_00,$00_03 ' row 10
              word      $0b_03,$0c_03,$0d_03,$0e_03,$0f_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_00, $00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03 ' row 11



tile_map1     word      $00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_00, $00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03 ' row 0
              word      $00_03,$00_05,$00_04,$00_04,$00_04,$00_04,$00_03,$00_04,$00_04,$00_03,$00_04,$00_04,$00_04,$00_04,$00_05,$00_00, $00_00,$00_05,$00_04,$00_04,$00_04,$00_04,$00_03,$00_04,$00_04,$00_03,$00_04,$00_04,$00_04,$00_04,$00_05,$00_03 ' row 1
              word      $00_03,$00_04,$00_03,$00_03,$00_03,$00_04,$00_03,$00_04,$00_04,$00_03,$00_04,$00_03,$00_03,$00_03,$00_04,$00_00, $00_00,$00_04,$00_03,$00_03,$00_03,$00_04,$00_03,$00_04,$00_04,$00_03,$00_04,$00_03,$00_03,$00_03,$00_04,$00_03 ' row 2
              word      $00_03,$00_04,$00_03,$00_04,$00_03,$00_04,$00_03,$00_04,$00_04,$00_03,$00_04,$00_03,$00_04,$00_03,$00_04,$00_00, $00_00,$00_04,$00_03,$00_04,$00_03,$00_04,$00_03,$00_04,$00_04,$00_03,$00_04,$00_03,$00_04,$00_03,$00_04,$00_03 ' row 3
              word      $00_03,$00_04,$00_03,$00_03,$00_03,$00_04,$00_03,$00_03,$00_03,$00_03,$00_04,$00_03,$00_03,$00_03,$00_04,$00_00, $00_00,$00_04,$00_03,$00_03,$00_03,$00_04,$00_03,$00_03,$00_03,$00_03,$00_04,$00_03,$00_03,$00_03,$00_04,$00_03 ' row 4
              word      $00_03,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_00, $00_00,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_03 ' row 5
              word      $00_03,$00_04,$00_03,$00_03,$00_03,$00_04,$00_03,$00_03,$00_03,$00_03,$00_04,$00_03,$00_03,$00_03,$00_04,$00_00, $00_00,$00_04,$00_03,$00_03,$00_03,$00_04,$00_03,$00_03,$00_03,$00_03,$00_04,$00_03,$00_03,$00_03,$00_04,$00_03 ' row 6
              word      $00_03,$00_04,$00_04,$00_04,$00_03,$00_04,$00_03,$00_03,$00_03,$00_03,$00_04,$00_03,$00_04,$00_04,$00_04,$00_00, $00_00,$00_04,$00_04,$00_04,$00_03,$00_04,$00_03,$00_03,$00_03,$00_03,$00_04,$00_03,$00_04,$00_04,$00_04,$00_03 ' row 7
              word      $00_03,$00_04,$00_03,$00_04,$00_03,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_03,$00_04,$00_03,$00_04,$00_00, $00_00,$00_04,$00_03,$00_04,$00_03,$00_04,$00_04,$00_04,$00_04,$00_04,$00_04,$00_03,$00_04,$00_03,$00_04,$00_03 ' row 8
              word      $00_03,$00_04,$00_03,$00_04,$00_03,$00_04,$00_03,$00_03,$00_03,$00_03,$00_04,$00_03,$00_04,$00_03,$00_04,$00_00, $00_00,$00_04,$00_03,$00_04,$00_03,$00_04,$00_03,$00_03,$00_03,$00_03,$00_04,$00_03,$00_04,$00_03,$00_04,$00_03 ' row 9
              word      $00_03,$00_05,$00_03,$00_04,$00_04,$00_04,$00_03,$00_04,$00_04,$00_03,$00_04,$00_04,$00_04,$00_03,$00_05,$00_00, $00_00,$00_05,$00_03,$00_04,$00_04,$00_04,$00_03,$00_04,$00_04,$00_03,$00_04,$00_04,$00_04,$00_03,$00_05,$00_03 ' row 10
              word      $00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03, $00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03,$00_03 ' row 11 


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

             ' box segment version 0
              ' palette black, blue, gray, white              
tile_box_0    long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 1
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

             ' box segment version 1
              ' palette black, blue, gray, white              
tile_box_1    long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 2
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


             ' box segment version 2
              ' palette black, blue, gray, white              
tile_box_2    long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1 ' tile 3
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
              ' palette black, blue, gray, white
tile_dot      long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 4
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_2_2_3_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_2_2_2_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_2_2_2_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

              ' power up pill
              ' palette black, blue, gray, white
tile_powerup  long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 5
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
              ' palette black, blue, ghost color, white
tile_ghost_lt long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 6
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
              ' palette black, blue, ghost color, white
tile_ghost_rt long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 7
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
              ' palette black, blue, ghost color, white
tile_ghost_up long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 8
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
              ' palette black, blue, ghost color, white
tile_ghost_dn long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 9
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
palette_map   long $07_5C_0C_02 ' palette 0 - background and wall tiles
              long $07_0C_1C_02 ' palette 0 - background and wall tiles
              long $07_0C_2C_02 ' palette 0 - background and wall tiles
              long $07_0C_3C_02 ' palette 0 - background and wall tiles
              long $07_0C_4C_02 ' palette 0 - background and wall tiles
              long $07_0C_5C_02 ' palette 0 - background and wall tiles
              long $07_0C_6C_02 ' palette 0 - background and wall tiles
              long $07_0C_7C_02 ' palette 0 - background and wall tiles
              long $07_0C_8C_02 ' palette 0 - background and wall tiles
              long $07_0C_9C_02 ' palette 0 - background and wall tiles
              long $07_0C_aC_02 ' palette 0 - background and wall tiles
              long $07_0C_bC_02 ' palette 0 - background and wall tiles
              long $07_0C_cC_02 ' palette 0 - background and wall tiles
              long $07_0C_dC_02 ' palette 0 - background and wall tiles
              long $07_0C_eC_02 ' palette 0 - background and wall tiles
              long $07_0C_fC_02 ' palette 0 - background and wall tiles


' ///////////////////////////////////////////////////////////////////////////////

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


' DEBUGGER STRINGS ////////////////////////////////////////////////////////////

DAT

debug_clearscreen_string        byte ASCII_ESC,ASCII_LB, $30+$02, $41+$09, $00
debug_home_string               byte ASCII_ESC,ASCII_LB, $41+$07, $00   
debug_title_string              byte "Hydra Debugger Initializing (C) Nurve Networks LLC 20XX", ASCII_CR, ASCII_LF, $00 ' $0D carriage return, $0A line feed 