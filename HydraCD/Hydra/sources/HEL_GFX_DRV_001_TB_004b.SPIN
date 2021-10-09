' /////////////////////////////////////////////////////////////////////////////
' HEL_GFX_DRV_001_TB_004.SPIN 
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
  ASCII_LF = $0A 
  ASCII_CR = $0D
  ASCII_ESC = $1B
  ASCII_LB  = $5B ' [ 
  ASCII_SPACE = $20 ' space

'//////////////////////////////////////////////////////////////////////////////
' VARS SECTION ////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

VAR


' begin parameter list ////////////////////////////////////////////////////////
' tile engine data structure pointers (can be changed in real-time by app!)
long tile_map_base_ptr_parm                             ' base address of the tile map
long tile_bitmaps_base_ptr_parm                         ' base address of the tile bitmaps
long tile_palettes_base_ptr_parm                        ' base address of the palettes
long tile_map_width_parm                                ' value for tile map width
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

game_pad : "gamepad_drv_001.spin"
serial : "FullDuplex_serial_drv_010.spin"   

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
tile_map_width_parm           := 1 ' set for width 32 tiles (2 screens wide), 0 = 16 tiles, 1 = 32 tiles, 2 = 64 tiles, 3 = 128 tiles, etc.
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


sprite_tbl[8] := $00_50_00_00     ' sprite 4 state: y=xx, x=$xx, z=$xx, enabled/disabled
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
cognew(@HEL_GFX_Driver_Entry, @tile_map_base_ptr_parm)


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

' /////////////////////////////////////////////////////////////////////////////
' ASSEMBLY LANGUAGE HEL_GFX_DRIVER Version 4.0
' Engine Design
' Engine 4 Design Notes
' Status: in progress
' 
' Specs:
' - 160x192 visible screen, 256x192 logical
' - 16x12 tile map (logical) 10x12 (physical), each entry 2 bytes, format: [palette index:tile index]
' - 16x16 bitmap tiles, 4 colors each, array of 16 LONGs, each LONG represents 16 pixels, 64 bytes each tile
' - Course scrolling, horizontal and vertical, playfield width 16, 32, 64, 128, etc.
' - 8 sprites, 16x16 each, they use the tile palette under for color
' - only 4 sprites can exist on a single scanline, the engine will stop rendering once this limit is reached on any line
' 
' Features:
' - Sprites plus screen clipping 
' - Multiple tile maps 256
' - Multiple palettes 256
' - Bitmaps 256
' - All assets base pointers passed to engine each frame, thus "on the fly" changes can be made
' - Supports page flipping, double buffering by design.
' - Engine passes back vertical region and hsync/vsync status as well as current line
' /////////////////////////////////////////////////////////////////////////////


CON

  FNTSC         = 3_579_545      ' NTSC color clock frequency in HZ
  LNTSC         = (227*16)       ' NTSC color cycles per line (220-227) * 16
  SNTSC         = (67*16)        ' NTSC color cycles per sync (39-44) * 16
  VNTSC         = (LNTSC-SNTSC)  ' NTSC color cycles per active video * 16
  PNTSC256      = (VNTSC/10)     ' NTSC color cycles per "compressed/expanded" on screen pixel
                                 ' allows us to put more or less pixels on the screen, but
                                 ' remember NTSC is 227 visible pixels -- period, so when we display more
                                 ' than 227 per line then we are getting chroma distortion on pixel boundaries
                                 ' a more recommended method for cleaner graphics is about 160-176 pixels horizontally
                                 ' this way you don't overdrive the chroma bandwidth which limits colors to 227
                                 ' color clocks per screen
                                 ' currently set for 16, 16 wide tiles per line


  VIDEO_PINMASK    = %0000_0111     ' vcfg S = pinmask  (pin31 ->0000_0111<-pin24), only want lower 3-bits
  VIDEO_PINGROUP   = 3              ' vcfg D = pingroup (Hydra uses group 3, pins 24-31)
  VIDEO_SETUP      = %0_10_1_01_000 ' vcfg I = controls overall setting, we want baseband video on bottom nibble, 2-bit color, enable chroma on broadcast & baseband
  VIDEO_CNTR_SETUP = %00001_111     ' pll internal routed to Video, PHSx+=FRQx (mode 1) + pll(16x)
                                    ' needn't set D,S fields since they set pin A/B I/Os, but mode 1 is internal, thus irrelvant

' format of tile_status_bits_parm, only the Vsync status bit is updated
'
' byte 3 (unused)|byte 2 (line)|   byte 1 (tile postion)    |                     byte 0 (sync and region)      |
'|x x x x x x x x| line 8-bits | row 4 bits | column 4-bits |x x x x | region 2-bits | hsync 1-bit | vsync 1-bit|
'   b31..b24         b23..b16      b15..b12     b11..b8                    b3..b2          b1            b0
' Region 0=Top Overscan, 1=Active Video, 2=Bottom Overscan, 3=Vsync
' NOTE: In this version of the tile engine only VSYNC and REGION are valid 

  ' tile engine status bits/masks
  TSB_VSYNC                     = %0000_00_01    ' Vsync 
  TSB_HSYNC                     = %0000_00_10    ' Hsync 

  ' regions indicate which parts of the vertical scan the raster is in, useful to time all rendering during the total blanking period which
  ' is any region other than "01"
  TSB_REGION_MASK               = %0000_11_00    ' region status bits bitmask

  TSB_REGION_TOP_OVERSCAN       = %0000_00_00    ' top overscan region (00)
  TSB_REGION_ACTIVE_VIDEO       = %0000_01_00    ' active video region (01)
  TSB_REGION_BOTT_OVERSCAN      = %0000_10_00    ' bottom overscan region (10)
  TSB_REGION_VSYNC              = %0000_11_00    ' vsync region (replicated in vsync bit)                                                

  
  ' register indexes
  CLKFREQ_REG = 0                ' register address of global clock frequency

  ' debuging stuff
  DEBUG_LED_PORT_MASK = $00000001 ' debug LED is on I/O P0


DAT
                org $000  ' set the code emission for COG add $000


' /////////////////////////////////////////////////////////////////////////////
' Entry point and Parameter Interface
' /////////////////////////////////////////////////////////////////////////////
{

there are 4 parameters in this engine, listed in order below
tile engine data structure pointers (can be changed in real-time by app!)
input parms

long tile_map_base_ptr_parm      ' parm 0: pointer to tile map (16x12 array, row major, 2-bytes per entry)
long tile_bitmaps_base_ptr_parm  ' parm 1: pointer to the base of the bitmap data, each 16x16, that is, 32 longs each
long tile_palettes_base_ptr_parm ' parm 2: pointer to the base of the palettes array, each palette 1 long, or 4 bytes.
long tile_map_width_parm         ' parm 3: pointer to the value that holds the number of "screens" or multiples of 16 that the tile map is
                                 ' eg. 0 would be 16 wide (standard), 1 would be 32 tiles, 2 would be 64 tiles, etc.
                                 ' this allows multiscreen width playfields and thus large horizontal/vertical scrolling games
                                 ' note that the final size is always a power of 2 times 16

long tile_sprite_tbl_base_ptr_parm  ' parm 4: pointer to the base of the "sprite table", the sprite table consists of 2 LONGs per sprite
                                    ' the LONGs are in the format "state", "bitmap pointer"

real-time engine status variables, these are updated in real time by the
tile engine itself, so they can be monitored outside in SPIN/ASM by game
output parms

long tile_status_bits_parm      ' parm 4: pointer to status word - vsync, hsync, etc.

 format of tile_status_bits_parm, only the Vsync status bit is updated

 byte 3 (unused)|byte 2 (line)|   byte 1 (tile postion)    |                     byte 0 (sync and region)      |
|x x x x x x x x| line 8-bits | row 4 bits | column 4-bits |x x x x | region 2-bits | hsync 1-bit | vsync 1-bit|
   b31..b24         b23..b16      b15..b12     b11..b8                    b3..b2          b1            b0
 Region 0=Top Overscan, 1=Active Video, 2=Bottom Overscan, 3=Vsync
 NOTE: In this version of the tile engine only VSYNC and REGION are valid 

format of a tile map:

DAT

tile_map0     ' 16x12 WORDS each, (0..191 WORDs, 384 bytes per tile map) 2-BYTE tiles (msb)[palette_index | tile_index](lsb)
              ' 16x12 tile map, each tile is 2 bytes, there are a total of 64 tiles possible, and thus 64 palettes              
              ' column     0      1      2      3      4      5      6      7      8      9     10     11     12     13     14     15
              word      $01_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$02_01 ' row 0
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 4
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 5
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 6
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 7
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 8
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 9
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_01 ' row 11

Example: upper right corner tile @ (15, 0) value is $02_01, this means use palette 2 and tile bitmap 1.
Note: 1. you can have as many tile maps as you wish there is no limit, they can represent rooms, etc.
      2. if you use "mappy" tool then you must make some changes tothe mapwin.ini file, they are:

      maptype="LW1H1A1-0" <--this results in 1 byte per entry, and the format is a binary single array in the format
      importskip=0        <---use dumb import, don't modify anything, just bring the tiles into the tool from your bitmap
      
      width, height,
      index 0, index 1, ..... index 15,
      index 16, index 1, ..... index 31,
      .
      .      
      index 176, index 177, ..... index 191

      as one single byte stream of course.

Format of a single bitmap that represents a tile:

              ' tile bitmap memory, each tile 16x16 pixels, or 1 LONG by 16,
              ' 64-bytes each, also, note that they are mirrored right to left
              ' since the VSU streams from low to high bits, so your art must
              ' be reflected, we could remedy this in the engine, but for fun
              ' I leave it as a challenge in the art, since many engines have
              ' this same artifact

DAT

tile_bitmap   long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile data
              long      %%0_0_0_0_0_1_1_1_1_1_1_0_0_0_0_0
              long      %%0_0_0_1_1_1_1_1_1_1_1_1_1_0_0_0
              long      %%0_0_0_1_1_1_1_1_1_1_1_1_1_0_0_0
              long      %%0_0_1_2_2_2_2_1_1_2_2_2_2_1_0_0
              long      %%0_0_1_2_2_2_2_1_1_2_2_2_2_1_0_0
              long      %%0_0_1_2_2_3_3_1_1_2_2_3_3_1_0_0
              long      %%0_0_1_2_2_3_3_1_1_2_2_3_3_1_0_0
              long      %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              long      %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              long      %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_0_0
              long      %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_1_0
              long      %%0_0_1_1_0_0_1_1_1_1_0_0_1_1_1_0
              long      %%0_0_1_1_0_0_1_1_1_1_0_0_1_1_1_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

Example: this particular bitmap definition is a collection of concentric squares that use color 3,2,1 and fill with color 0,
Note: you may have up to 256 tiles


Format of palette array, each palette has 4 entries, each 1 byte, when a tile is defined in the tile map it has both an index
to the tile bitmap (0..255) as well as an index to the "palette" to use (0..255), below is an example of 4 palette entries

DAT

palette_map   ' 4 palettes for only now, palette memory (1..255) LONGs, each palette 4-BYTEs

              long $5C_5B_5A_02 ' palette 0
              long $0C_0B_0A_02 ' palette 1
              long $CC_CB_CA_02 ' paleete 2
              long $0C_0B_0A_02 ' palette 3

Note: each of the 8-bit values represents the color, luma, and chroma enable for the color as defined by the VSU hardware

Format of sprite table


DAT

              ' sprite 0 header
sprite_tbl    long $00_00_00_00  ' state/control word: y,x,z,state, enabled, x=$50, y=$60
              long $00_00_00_00  ' bitmap ptr

              ' sprite 1 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr
              .
              .
              .
              ' sprite 7 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

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
currently NONE of the special control bits in the state/control are implemented, only ENABLED works, they are
for future expansion and experimentation.  

}

HEL_GFX_Driver_Entry

              ' VCFG: setup Video Configuration register and 3-bit TV DAC pins to outputs
                        
              movs    vcfg, #VIDEO_PINMASK              ' vcfg S = pinmask  (pin31 ->0000_0111<-pin24), only want lower 3-bits
              movd    vcfg, #VIDEO_PINGROUP             ' vcfg D = pingroup (Hydra uses group 3, pins 24-31)
              movi    vcfg, #VIDEO_SETUP                ' vcfg I = controls overall setting, we want baseband video on bottom nibble, 2-bit color, enable chroma on broadcast & baseband
              or      dira, tvport_mask                 ' set DAC pins to output 24, 25, 26

              ' CTRA: setup Frequency to Drive Video                        
              movi    ctra, #VIDEO_CNTR_SETUP           ' pll internal routed to Video, PHSx+=FRQx (mode 1) + pll(16x)
                                                        ' needn't set D,S fields since they set pin A/B I/Os, but mode 1 is internal, thus irrelvant

              ' compute the value to place in FREQ such that the final counter
              ' output is NTSC and the PLL output is 16*NTSC
              mov     r1, v_freq                        ' r1 <- TV color burst frequency in Hz, eg. 3_579_545                                            
              rdlong  r2, #CLKFREQ_REG                  ' r2 <- CLKFREQ is register 0, eg. 80_000_000
              call    #Dividefract                      ' perform r3 = 2^32 * r1 / r2
              mov     frqa, r3                          ' set frequency for counter such that bit 31 is toggling at a rate of the color burst (2x actually)
                                                        ' which means that the freq number added at a rate of CLKFREQ (usually 80.000 Mhz) results in a
                                                        ' pll output of the color burst, this is further multiplied by 16 as the final PLL output
                                                        ' thus giving the chroma hardware the clock rate of 16X color burst which is what we want :)
  

              mov       r0, par                         ' copy boot parameter value and read in parameters from main memory, must be on LONG boundary
              add       r0, #20                         ' status bit is 5 longs out or 20 bytes
              mov       tile_status_bits_ptr, r0        ' ptr to status bits, so tile engine can pass out status of tile engine in real time

{
              ' DEBUG RETRIEVE PARMS //////////////////////////////////////////////////////////////////////////////////
              mov       r0, par
              add       r0, #24
              mov       debug_status_ptr, r0
              add       r0, #4

              mov       debug_string_ptr, r0
              add       r0, #4

              mov       debug_value_ptr, r0
              add       r0, #4

              mov       debug_pos_ptr, r0
              add       r0, #4
              ' END DEBUG RETRIEVE PARMS //////////////////////////////////////////////////////////////////////////////
}


Next_Frame    ' start of new frame of 262 scanlines
              ' 26 top overscan
              ' 192 active vide
              ' 26 bottom overscan
              ' 18 vertical sync

              ' all this "work" from the beginning of next_frame to top_overscan_lines should be moved into the blanking period,
              ' right now its impinging upon the 60 Hz cycle
                      
              ' read run-time parameters from main memory, user can change these values every frame
              mov       r0, par                         ' copy boot parameter value and read in parameters from main memory, must be on LONG boundary
              rdlong    tile_map_base_ptr, r0           ' base ptr to tile map itself
              add       r0, #4
              rdlong    tile_bitmaps_base_ptr, r0       ' base pointer to array of 16x16 bitmaps, each 64 bytes
              add       r0, #4
              rdlong    tile_palettes_base_ptr, r0      ' base pointer to array of palettes, each palette 4 bytes / 1 long
              add       r0, #4
              rdlong    tile_map_width, r0              ' value of tile map width 0=16, 1=32, 2=64, etc.
              add       r0, #4
              rdlong    tile_sprite_tbl_base_ptr, r0    ' base pointer to sprite table


              ' read the sprite table into the local COG memory sprite table cache /////////////////////////////////////////////////////
              mov       r1, tile_sprite_tbl_base_ptr    ' r1 = tile_sprite_tbl_base_ptr, byte ptr, main memory
              mov       r2, #sprite_table_cache         ' r2 = @sprite_table_cache, long ptr, cog memory

              mov       r3, #16                          ' 16 Longs to copy from main memory to cog memory to fill the sprite table cache, 8 sprites, each sprite 2 longs
Sprite_Table_Cache_Loop

              movd      Write_Cache, r2                 ' overwrite destination on rdlong instruction
              nop                                       ' wait for pre-fetch, so we don't execute self modifying code too quickly
Write_Cache   rdlong    0, r1                           ' *r2 = *r1                
              add       r1, #4                          ' r1+=4, move to next LONG, byte addressing in main memory
              add       r2, #1                          ' r2++, move to next LONG, long addressing in COG memory
              djnz      r3, #Sprite_Table_Cache_Loop    ' if (--r3 > 0) then loop

              ' at this point the sprite table has been cached locally for fast algorithm processing, we do this each frame since the sprite table data
              ' can change at any time, but of course any sprite table change made on a per scanline basis won't occur, but SPIN isn't fast enough to do
              ' this however, later if this engine code were controlled by another COG in asm then that feature might be necessary

              ' reset tile engine status bits for next pass
              mov       r0, #0                          ' clear out status bits for next frame, 0 means region top overscan, vsync FALSE
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory

' /////////////////////////////////////////////////////////////////////////////
Top_Overscan_Scanlines

              mov       r0, #TSB_REGION_TOP_OVERSCAN    ' set region to top overscan 
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory

              mov     r1, #26                           ' set # of scanlines

' Horizontal Scanline Loop (r1 itterations)
:Next_Scanline
        
              ' HSYNC 10.9us (Horizontal Sync) including color burst
              mov     vscl, v_shsync                    ' set the video scale register such that 16 serial pixels takes 39 color clocks (the total time of the hsync and burst)
              waitvid v_chsync, v_phsync                ' send out the pixels and the colors, the pixels are 0,1,2,3 that index into the colors, the colors are blank, sync, burst
                                                        ' we use them to create the hsync pulse itself

              ' set hsync output status bit and set region
              mov       r0, #TSB_REGION_TOP_OVERSCAN | TSB_HSYNC ' set region to top overscan and set hsync 
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory

              ' do work.... here
              
              ' HVIS 52.6us (Visible Scanline) draw 16 huge pixels
              mov     vscl, v_shvis                     ' set up the video scale so the entire visible scan is composed of 16 huge pixels
              waitvid v_choverscan , v_phoverscan       ' draw 16 pixels with red and blues

              mov       r0, #TSB_REGION_TOP_OVERSCAN    ' set region to top overscan and reset hsync 
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory

              ' do "work".... here, nothing for now, but tons of time for image processing, etc.
              
              djnz    r1, #:Next_Scanline               ' are we done with the scanlines yet?

' /////////////////////////////////////////////////////////////////////////////
Active_Scanlines

              mov       r0, #TSB_REGION_ACTIVE_VIDEO    ' set region to active video
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory

              mov     r1, #0                            ' reset scanline counter r1, in this case we count up

' Horizontal Scanline Loop (r1 iterations)
Active_Scanline_Loop

              ' set hsync output status bit and set region and active line
              mov       r0, r1
              shl       r0, #16                                     ' set the current line                        
              or        r0, #TSB_REGION_ACTIVE_VIDEO | TSB_HSYNC    ' set region to active video reset hsync 
              wrlong    r0, tile_status_bits_ptr                    ' write out status bits to main memory

        
              ' HSYNC typically 10.9us (Horizontal Sync) including color burst expanded to 67 color clocks, so entire Hsync is now 18.7uS
              ' or 1497 clocks or ~360 instructions at 80.000 Mhz of processing, we can do a quite a bit in this time before each scanline is rendered
              mov     vscl, v_shsync                    ' set the video scale register such that 16 serial pixels takes 39( or 51, 67, whatever its set at) color clocks (the total time of the hsync and burst)
              waitvid v_chsync, v_phsync                ' send out the pixels and the colors, the pixels are 0,1,2,3 that index into the colors, the colors are blank, sync, burst
                                                        ' we use them to create the hsync pulse itself
                       
' /////////////////////////////////////////////////////////////////////////////

              ' this next section retrives the tile index, palette index for each tile and draws a single line of video composed of 1 sub
              ' scan line of each tile, the opportunity here is to realize that each tile accessed 16 times, once for each video line, thus
              ' the tile indexes and palettes themselves could be "cached" to save time, however, the added complexity is not needed yet
              ' but the next version will cache the data, so we can have more time per pixel block to do crazy stuff :)

              mov     vscl, v_spixel                    ' set up video scale register for 16 pixels at a time


              ' first process all the sprites on this scanline ////////////////////////////////////////////////////////
              ' new code...
              ' sprite_state for reference
              ' Long 0 - state / control bits
              ' |      Byte 3       |       Byte 2      |       Byte 1      |       Byte 0      |
              ' | y7 y y y y y y y0 | x7 x x x x x x x0 | z7 z z z z z z z0 | s7 s s s s s s s0 |
              '      y - pos              x - pos                z-pos           state bits


              ' r1 is holding scanline, other than that all working registers are available
              mov       r2, #5                        ' the more sprites to process, the more time it takes to render them, BUT, simply
                                                      ' looping thru them takes time, so as you increase the total number of sprites then
                                                      ' you loose processing per line, here's a table that breaks it down
                                                      '
                                                      ' Total Sprites           Sprites per line before "fuzzy"
                                                      '     12                        2                 (cache will need to be increased)
                                                      '      8                        3
                                                      '      5                        4


              mov       sprite_num_active_cntr, #4    ' max number of sprite to process per line, if we use them up, then exit out, or else!, not implemented yet
              mov       r3, #sprite_table_cache       ' r3 = @sprite_table_cache, local cog memory

              ' clear scanline buffers out, no memory fill!!!!!
              ' first clear out 12 LONGs of scanline bitmap buffer since only 10 tiles are visible, plus 1 extra on either side
              mov sprite_scanline_bitmap+0,  #0
              mov sprite_scanline_bitmap+1,  #0
              mov sprite_scanline_bitmap+2,  #0
              mov sprite_scanline_bitmap+3,  #0
              mov sprite_scanline_bitmap+4,  #0                                  
              mov sprite_scanline_bitmap+5,  #0
              mov sprite_scanline_bitmap+6,  #0
              mov sprite_scanline_bitmap+7,  #0
              mov sprite_scanline_bitmap+8,  #0
              mov sprite_scanline_bitmap+9,  #0
              mov sprite_scanline_bitmap+10, #0
              mov sprite_scanline_bitmap+11, #0
'              mov sprite_scanline_bitmap+12, #0                                  
'              mov sprite_scanline_bitmap+13, #0
'              mov sprite_scanline_bitmap+14, #0
'              mov sprite_scanline_bitmap+15, #0

              ' now clear out the scanline mask buffer (Set to $FFFFFFFF)
              mov sprite_scanline_mask+0,  MAX_INT
              mov sprite_scanline_mask+1,  MAX_INT
              mov sprite_scanline_mask+2,  MAX_INT
              mov sprite_scanline_mask+3,  MAX_INT
              mov sprite_scanline_mask+4,  MAX_INT                                  
              mov sprite_scanline_mask+5,  MAX_INT
              mov sprite_scanline_mask+6,  MAX_INT
              mov sprite_scanline_mask+7,  MAX_INT
              mov sprite_scanline_mask+8,  MAX_INT
              mov sprite_scanline_mask+9,  MAX_INT
              mov sprite_scanline_mask+10, MAX_INT
              mov sprite_scanline_mask+11, MAX_INT
 '             mov sprite_scanline_mask+12, MAX_INT                                  
'              mov sprite_scanline_mask+13, MAX_INT
'              mov sprite_scanline_mask+14, MAX_INT
'              mov sprite_scanline_mask+15, MAX_INT

              mov       r7, r1  ' copy scanline # into r7
              add       r7, #16 ' add 16 to support sprite clipping 
                                ' r1 holds "real" scanline, r7 holds offset scanline by 16

Sprite_Processing_Loop

              ' extract the nth sprite state/ptr from sprite_table_cache

              movs      Read_State, r3                ' r3 is pointing at sprite record's offset 0 field for nth sprite - the state/control word
              add       r3, #1                        ' advance to ptr field of sprite record, plus give self modify time to complete                            
Read_State    mov       sprite_state, 0               ' read the sprite_state out of this sprites record              

              ' next read the sprite pointer in preparation for processing algorithm, eventhough we may pass on it
              movs      Read_Ptr, r3                 ' r3 is pointing at sprite records offset 1 field for nth sprite - the bitmap pointer
              add       r3, #1                       ' advance to ptr field of sprite record, plus give self modify time to complete                         
Read_Ptr      mov       sprite_bitmap_ptr, 0         ' read the sprite_bitmap_ptr out of this sprite record

               
              ' at this point, we have encoded sprite_state, sprite_x, sprite_y and r3 pointing to NEXT sprite record, r2 is the sprite index, r1 is scanline
              ' we can continue to perform calcs, but at this point might as well see if this sprite is even on this scanline            

              ' test if sprite is enabled, if so process, else jump to next sprite
              test      sprite_state, #%00000001        wc, wz ' test enabled bit?
         if_z jmp       #Next_Sprite                   ' this sprite is disabled, ignore!                   

              ' else sprite is enabled, continue processing....

              ' at this point we have everything, we can start interogating...
              ' copy the sprite_state into x,y since they are encoded within
              mov       sprite_x, sprite_state        ' x is encoded in 2nd byte of state
              shr       sprite_x, #16                 ' now yx are in lower 16-bits
              and       sprite_x, #$FF                ' mask lower byte which is x position               
              
              mov       sprite_y, sprite_state        ' y is encoded in 3rd byte of state
              shr       sprite_y, #24                 ' now y is in lower 8-bits


               ' if sprite intersects current scanline then process it...
              mov       r4, sprite_y                  ' r4 = sprite_y
              add       r4, #16                       ' r4 = sprite_y+16, bottom of sprite since sprite is 16x16 pixels


              ' perform bounds test
Test_Sprite_Top
              cmp       r7, sprite_y               wc, wz  ' compare scanline to sprite_y, if (scanline >= sprite_y) then test bottom, (r7 is used though which is r1+16 to support sprite clip at top of screen)
        if_ae jmp       #Test_Sprite_Bottom                ' compare scanline to sprite_y+16                            
              jmp       #Next_Sprite                       ' scanline not within sprite process next sprite


Test_Sprite_Bottom
              cmp       r7, r4                     wc, wz  ' compare scanline to sprite_y+16, (r7 is used though which is r1+16 to support sprite clip at top of screen)
        if_ae jmp       #Next_Sprite                       ' if (scanline >= sprite_y+16) then sprite is NOT on this scanline, process next sprite                                            



        
              ' else, sprite IS on this scanline, here comes the really icky part...extracting the sprite's data and mask


              ' first compute the sprite tile and offset
              mov       sprite_tile_x, sprite_x         ' compute tile offset, or 16 pixel boundary
              shr       sprite_tile_x, #4               ' sprite_tile_x = sprite_x/16

              mov       sprite_offset_x, sprite_x       ' compute pixel offset to shift sprite data within tile
              and       sprite_offset_x, #$0F           ' sprite_offset_x = sprite_x mod 16

              ' compute the row of the sprite we need to render, that is the (current line - sprite_y), this would fail if we hadn't already determined
              ' the current scanline is intersecting the sprite at some y
              mov       r5, r7                          ' r1 holds current scanline (r7 is used though which is r1+16 to support sprite clip at top of screen)
              sub       r5, sprite_y                    ' r5 = r1 - sprite_y, equals dy or intersection row from 0-15


                            
              ' retrieve row of sprite from bitmap
                            
              shl       r5, #2                          ' r5 = (r1 - sprite_y)*4, 1 long per line, 4 bytes per long, byte offset from top of sprite
              add       r5, sprite_bitmap_ptr           ' r5 = sprite_bitmap_ptr + (r1 - sprite_y)*4, ptr to long that holds bitmap line


              ' read 16 pixels / 32-bit data row of sprite from memory into local bitmap buffer
              rdlong    sprite_bitmap_buffer, r5        ' sprite_bitmap_buffer[0] = mm[r5] = mm[sprite_bitmap_ptr + (r1 - sprite_y)*4]
              mov       sprite_bitmap_buffer+1, #0      ' sprite_bitmap_buffer[1] = 0


              ' get mask from memory.... rather than construct it, it is precomputed by us, and exists 16 longs after the bitmap itself, or 64 bytes down
              ' the mask is an AND stencil 00's where the sprite data will go, 11 where the sprite is transparent
              ' when ANDed with the target data, it makes a "hole" where the sprite will go and thus we can OR in the sprite data later
              ' however, the mask data is first POSITIVE (inverted) until we are done shifting it then we need to invert it before use 
              add       r5, #16*4              
              rdlong    sprite_mask_buffer, r5        ' sprite_mask_buffer[0] = mm[r5] = mm[sprite_bitmap_ptr + (r1 - sprite_y)*4 + 16]                         
              mov       sprite_mask_buffer+1, #0      ' sprite_mask_buffer[1] = $00000000


              ' now we have the sprite's 16 pixels in sprite_bitmap_buffer[0] and
              ' and the positive sprite mask in sprite_mask_buffer[0]
              ' now we need to shift these both to make them pixel accurate based on the offset of the sprite within a tile


              ' both the bitmap and the mask are 16-pixels or 32-bits wide, however, because the bitmap and the mask can straddle a tile boundary,
              ' that is a sprite can be anywhere we need to shift both the bitmap and the mask to the left low -> high over a tile boundary, or
              ' in other words a 64-bit shift, this is difficult due to the carry out, etc. and we can't afford to use a loop thus, we must
              ' be clever and break the shift into two 32-bit shifts
              '
              ' Initial bitmap
              '    sprite_bitmap_buffer+1     |    sprite_bitmap_buffer
              ' 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 | b b b b b b b b b b b b b b b b | 
              '                               |        <---- sprite_offset_x*2
              ' Initial mask 
              '    sprite_mask_buffer+1     |    sprite_mask_buffer
              ' 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 | m m m m m m m m m m m m m m m m | 
              '                               |        <---- sprite_offset_x*2
              '
              'The shift operation for both bitmap and mask is same, thus we can generalize, the trick is to copy the bitmap into both the low and high LONG
              ' of the result, then we shift the low long LEFT shift_offset_x*2 times, this places it perfectly, then we shift the copy to the RIGHT
              ' 32 - shift_offset_x*2 times and presto, we have performed a 64-bit shift with two 32-bit shifts. HOWEVER, there is a problem, the Pchip
              ' so in the special case of shift_offset_x == 0 then we simply jump out and don't do any shifting
              '
              
              cmp       sprite_offset_x, #0     wz, wc
        if_z  jmp       #Sprite_No_Shift                                        ' if (sprite_offset_x ==0 ) then jump out...                                      


Sprite_Do_Shift
              mov       r6, sprite_offset_x                                     ' we need to perform a 64-bit shift, do in two parts...
              shl       r6, #1                                                  ' r6 = sprite_offset_x*2 (the number of bits to shift rather than pixels)
              mov       r0, #32                                                 ' again another 64-bit shift is needed
              sub       r0, r6                                                  ' r0 = 32 - sprite_offset_x*2          

              mov       sprite_bitmap_buffer+1, sprite_bitmap_buffer            ' copy sprite bitmap buffer
              shl       sprite_bitmap_buffer, r6                                ' shift 16 pixels to the left via two seperate shifts
              shr       sprite_bitmap_buffer+1, r0                                                      
              
              mov       sprite_mask_buffer+1, sprite_mask_buffer                ' copy sprite mask buffer
              shl       sprite_mask_buffer, r6                                  ' shift 16 pixels to the left via two seperate shifts
              shr       sprite_mask_buffer+1, r0                                                      

Sprite_No_Shift

              ' ok, now that the mask shift operation is complete we can invert the mask to a NEGATIVE, we needed to keep in POSTIVE form
              ' since shift operations shift in 0's not 1's, and the shifting would alter our mask erroneously

              xor       sprite_mask_buffer, MAX_INT
              xor       sprite_mask_buffer+1, MAX_INT

              ' and now merge the final data into the screen sized scanline buffers!!! Its about time!

Sprite_Merge_Data

              ' step 1: AND the mask into scanline bitmap buffer and overwrite any pixels that are already there and make a "hole" for new sprite data              

              ' sprite_scanline_bitmap[sprite_tile_x]   &= sprite_mask_buffer[0]
              ' sprite_scanline_bitmap[sprite_tile_x+1] &= sprite_mask_buffer[1]

              mov       r0, #sprite_scanline_bitmap     ' r0 = @sprite_scanline_bitmap
              add       r0, sprite_tile_x               ' r0 = @sprite_scanline_bitmap + sprite_tile_x
              movd      :Write0, r0                     ' modify destination address of the AND opcode downstream to hold address in r0
              nop                                       ' wait for pre-fetch, so we don't execute self modifying code too quickly                                       
:Write0       and       0, sprite_mask_buffer           ' AND the mask against the scanline buffer

              add       r0, #1                          ' r0 = @sprite_scanline_bitmap + sprite_tile_x + 1
              movd      :Write1, r0                     ' modify destination address of the AND opcode downstream to hold address in r0
              nop                                       ' wait for pre-fetch, so we don't execute self modifying code too quickly
:Write1       and       0, sprite_mask_buffer+1         ' AND the mask against the scanline buffer

              ' step 2: now write the bitmap bits into the scanline buffer by ORing the source data from sprite into the scanline buffer

              ' sprite_scanline_bitmap[sprite_x]   |= sprite_bitmap_buffer[0]
              ' sprite_scanline_bitmap[sprite_x+1] |= sprite_bitmap_buffer[1]        

              mov       r0, #sprite_scanline_bitmap     ' r0 = @sprite_scanline_bitmap
              add       r0, sprite_tile_x               ' r0 = @sprite_scanline_bitmap + sprite_tile_x
              movd      :Write2, r0                     ' modify destination address of the OR opcode downstream to hold address in r0
              nop                                       ' wait for pre-fetch, so we don't execute self modifying code too quickly
:Write2       or       0, sprite_bitmap_buffer          ' OR the bitmap data into the scanline buffer (in the hole created by mask, so color bits dont get yucky)

              add       r0, #1                          ' r0 = @sprite_scanline_bitmap + sprite_tile_x + 1
              movd      :Write3, r0                     ' modify destination address of the OR opcode downstream to hold address in r0
              nop                                       ' wait for pre-fetch, so we don't execute self modifying code too quickly                        
:Write3       or       0, sprite_bitmap_buffer+1        ' OR the bitmap data into the scanline buffer (in the hole created by mask, so color bits dont get yucky)

              
              ' step 3: now write the mask to the scanline mask buffer, so it can be used to make a "hole" in the tiles to write the sprite data into
              ' and       sprite_scanline_mask[sprite_tile_x],   sprite_mask_buffer[0]
              ' and       sprite_scanline_mask[sprite_tile_x+1], sprite_mask_buffer[1]

              mov       r0, #sprite_scanline_mask       ' r0 = @sprite_scanline_mask
              add       r0, sprite_tile_x               ' r0 = @sprite_scanline_mask + sprite_tile_x
              movd      :Write4, r0                     ' modify destination address of the AND opcode downstream to hold address in r0
              nop                                       ' wait for pre-fetch, so we don't execute self modifying code too quickly
:Write4       and       0, sprite_mask_buffer       

              add       r0, #1                          ' r0 = @sprite_scanline_mask+ sprite_tile_x + 1
              movd      :Write5, r0                     ' modify destination address of the AND opcode downstream to hold address in r0
              nop                                       ' wait for pre-fetch, so we don't execute self modifying code too quickly
:Write5       and       0, sprite_mask_buffer+1       

              ' at this point the sprite data has been written into the scanline buffer as well as the mask been written to the mask scanline buffer
              ' when this loop finishes then the sprite_scaline_bitmap will hold the entire scanline of the sprite data and the scanline mask will
              ' hold the AND mask to AND into the destination tile data to make a "hole" for the sprite data

{
              ' DEBUG PRINT ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
              wrlong    debug_string, debug_string_ptr
              wrlong    sprite_scanline_bitmap, debug_value_ptr
Debug_Break   jmp       #Debug_Break
              ' END DEBUG PRINT ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
debug_string         byte    "ssb0"
Debug_End

}

Next_Sprite

              djnz      r2, #Sprite_Processing_Loop ' if (--r2 > 0) the loop

Tile_Map_Processor

              ' end processing sprites on scanline sprite buffer and mask are ready to go! /////////////////////////////


              ' select proper sub-tile row address
              mov       r2, r1                          ' r1 holds current video line of active video (0..191)
              and       r2, #$0F                        ' r2 = r1 mod 16, this is the sub-row in the tile we want to render, or the LONG index we need to offset the tile memory by

              ' access main memory can get the bitmap data
              shl       r2, #2                          ' r2 = r2*4, convert to BYTE based row offset of pixels
              add       r2, tile_bitmaps_base_ptr       ' r2 = tile_bitmaps_base_ptr + r2
                                                                                
              ' compute tile index itself for left edge of tile row, inner loop will index across as the scanline is rendered
              ' new code is needed here to support scrolling horizontally, we need to be able to tell the engine that a tile row has MORE than
              ' 16 tiles per row, so that when it access the next tile row down, it calculates properly, so this nice power of 2 math has to be
              ' revisited, however, we are going to constrain that the tiles per row must be a power of 2 multiple of 16 at least, so we don't have to use
              ' complex division yet, trying to keep each engine simple... so the playfield widths are 16, 32, 64, 128, 256 (max), thus the
              ' only thing we need to add is a shift to the mask operation that performs the (line/16) * 16, since now the 16 could be 16, 32, 64, 128, etc.

              ' new code with support for playfields 16, 32, 64, 128... in size which then allows scrolling to be supported (course scrolling of course :)
              mov       tile_map_index_ptr, r1                ' r1 = line, copy it 
              and       tile_map_index_ptr, #$1F0             ' tile_map_index_ptr = [(r1 / 16) * 16..256], this is the starting tile index for a row, 0, 16, 32, ...
              shl       tile_map_index_ptr, tile_map_width    

              shl       tile_map_index_ptr, #1                ' tile_map_index_ptr = tile_index*2, since each tile is 2 bytes, we need to convert index to byte address
              add       tile_map_index_ptr, tile_map_base_ptr ' tile_map_index_ptr = [(r1 / 16) * 16..256] + tile_map_base_ptr, this is a byte address in main memory now

              ' at this point we have everything we need for the pixels rendering aspect of the 16 tiles that will be rendered, the inner loop logic will
              ' retrieve the time map indexes, and access the 16 pixels that make up each row of each tile, BUT we need to get the palette(s)
              ' for each tile as well, each tile has its own palette, but the palette will change each group of 16-pixels across the screen since
              ' each 16-pixels represents a single line from a different tile

              ' we could cache all the palettes into the local cache, but for fun let's just read them out of main memory during the inner loop
                  
              ' render the 16 tile lines (10 on screen only), r2 is holding proper row address, but we need to add base of actual tile we want rendered
              mov       r4, #1                  ' r4 = tile_index, offset to 1, so we can index into scanline buffer one tile to the right which makes
                                                ' the sprites able to scan off the left edge

Pixel_Render_Loop

              ' read next tile index and palette index from main memory
              rdword    tile_map_word, tile_map_index_ptr
              
              ' retrieve 16-pixels of current row from proper bitmap referenced by tile
              mov       r3, tile_map_word
              and       r3, #$FF                        ' mask off upper 8-bits they hold the palette index, we aren't interested in
              shl       r3, #6                          ' r3 = tile_map_index*64 (bytes per tile)
              add       r3, r2                          ' r3 = tile_map_index*64 + tile_bitmaps_base_ptr + video_line mod 16
              rdlong    r3, r3                          ' r3 = main_memory[r3], retrieve 32 bits of pixel data
                                                        ' 16 clocks until hub comes around, try and be ready, move a couple instructions that aesthically
                                                        ' should be in one place between the hub reads to maximize processing/memory bandwith
                                                        
              ' at this point we can bring in the sprite data and mask data, we need to first mask the current pixels with AND mask to make a hole
              ' then simply OR the sprite scanline data into the tile data to make the "composition" 
              ' v_pixels_buffer = (v_pixels_buffer & sprite_scanline_mask[r4=tile_index] ) | sprite_scanline_bitmap[r4=tile_index] 

              mov       r0, #sprite_scanline_mask       ' r0 = @sprite_scanline_mask
              add       r0, r4                          ' r0 = @sprite_scanline_mask + tile_index (0..15), long address
              movs      :ReadMask, r0                   ' modify source operand in mov instruction downstream
              nop                                       ' give self modify a moment to catch up...later put something here useful other than NOP
:ReadMask     mov       sprite_mask_buffer, 0           ' sprite_mask_buffer = sprite_scanline_mask[tile_index]              

              mov       r0, #sprite_scanline_bitmap     ' r0 = @sprite_scanline_bitmap
              add       r0, r4                          ' r0 = @sprite_scanline_bimtap + tile_index (0..15), long address
              movs      :ReadBitmap, r0                 ' modify source operand in mov instruction downstream
              nop                                       ' give self modify a moment to catch up...later put something here useful other than NOP
:ReadBitmap   mov       sprite_bitmap_buffer, 0         ' sprite_bitmap_buffer = sprite_scanline_bitmap[tile_index]              

              ' now merge sprite bitmap with tile bitmap
              and       r3, sprite_mask_buffer          ' AND mask first with tile pixel data in r3
              or        r3, sprite_bitmap_buffer        ' OR bitmap data into pixels

              mov       v_pixels_buffer, r3             ' r3 holds pixels now, copy to pixel out buffer

              ' retrieve palette for current tile
              mov       r5, tile_map_word
              shr       r5, #8                          ' r5 now holds the palette index and we shifted out the tile index into oblivion
              shl       r5, #2                          ' multiple by 4, since there ar 4-bytes per palette entry
                                                        ' r5 = palette_map_index*4
              add       r5, tile_palettes_base_ptr      ' r5 = palette_map_base_ptr +palette_map_index*4

              ' this line moved from top of loop to eat time after previous memory read!
              add       tile_map_index_ptr, #2          ' advance pointer 2 bytes to next tile map index entry, for next pass

              rdlong    v_colors_buffer, r5             ' read the palette data into the buffer

              
              'draw the pixels with the selected palette
              waitvid   v_colors_buffer, v_pixels_buffer

              ' reset hsync output status bit and set region and active line
              ' this code is NOT needed, can be commented out for more time in inner pixel processing loop

              mov       r0, r1
              shl       r0, #16                         ' set the current line                        
              or        r0, #TSB_REGION_ACTIVE_VIDEO    ' set region to active video reset hsync 
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory


              add       r4, #1                          ' r4++
              cmp       r4, #11                 wc, wz
     if_ne    jmp       #Pixel_Render_Loop              ' loop until we draw 16 tiles (single pixel row of each)
                                                        ' actually only 10 are viewable, so we loop until a net of 10

' /////////////////////////////////////////////////////////////////////////////

              add       r1, #1                          
              cmp       r1, #192                  wc, wz
        if_b  jmp       #Active_Scanline_Loop          ' if ++r1 (current line) < 192 then loop
        
' /////////////////////////////////////////////////////////////////////////////

Bottom_Overscan_Scanlines

              mov       r0, #TSB_REGION_BOTT_OVERSCAN   ' set region to bottom overscan
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory

              mov       r1, #26                         ' set # of scanlines

' Horizontal Scanline Loop (r1 itterations)
:Next_Scanline


              ' HSYNC 10.9us (Horizontal Sync) including color burst
              mov       vscl, v_shsync                  ' set the video scale register such that 16 serial pixels takes 39 color clocks (the total time of the hsync and burst)
              waitvid   v_chsync, v_phsync              ' send out the pixels and the colors, the pixels are 0,1,2,3 that index into the colors, the colors are blank, sync, burst
                                                        ' we use them to create the hsync pulse itself
              ' set hsync output status bit and set region
              mov       r0, #TSB_REGION_BOTT_OVERSCAN | TSB_HSYNC ' set region to bottom overscan and set hsync 
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory


              ' HVIS 52.6us (Visible Scanline) draw 16 huge pixels that represent an entire line of video
              mov       vscl, v_shvis                   ' set up the video scale so the entire visible scan is composed of 16 huge pixels
              waitvid   v_choverscan , v_phoverscan     ' draw 16 pixels with red and blues

              ' reset hsync output status bit and set region
              mov       r0, #TSB_REGION_BOTT_OVERSCAN   ' set region to bottom overscan and reset hsync 
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory

              ' do "work".... here, nothing for now, but tons of time for image processing, etc.

              djnz      r1, #:Next_Scanline             ' are we done with the scanlines yet?

' /////////////////////////////////////////////////////////////////////////////
Vsync_Pulse

              ' VSYNC Pulse (Vertical Sync)
              ' 18 scanlines: 6 'high syncs', 6 'low syncs', and finally another 6 'high syncs'
              ' refer to NTSC spec, but this makes up the equalization pulses needed for a vsync

              mov       r0, #TSB_VSYNC | TSB_REGION_VSYNC ' set region to vsync as well 
              wrlong    r0, tile_status_bits_ptr          ' write out vertical sync status bit to main memory

              call      #Vsync_High
              call      #Vsync_Low
              call      #Vsync_High
                        
              jmp       #Next_Frame                     ' that's it, do it a googleplex times...
                        
'//////////////////////////////////////////////////////////////////////////////
' SUB-ROUTINES VARIABLE DECLARATIONS
'//////////////////////////////////////////////////////////////////////////////

' /////////////////////////////////////////////////////////////////////////////
' vsync_high: Generate 'HIGH' vsync signal for 6 horizontal lines.
Vsync_High              
                               
              mov       r1, #6
                        
              ' HSYNC 10.9us (Horizontal Sync)
:Vsync_Loop   mov       vscl, v_shsync
              waitvid   v_chsync, v_pvsync_high_1

              ' do "work".... here, nothing for now, but tons of time for image processing, etc.

              ' HVIS 52.6us (Visible Scanline)
              mov       vscl, v_shvis
              waitvid   v_chsync, v_pvsync_high_2

              ' do "work".... here, nothing for now, but tons of time for image processing, etc.
              djnz      r1, #:Vsync_Loop

Vsync_High_Ret
              ret

' /////////////////////////////////////////////////////////////////////////////
' vsync_low: Generate 'LOW' vsync signal for 6 horizontal lines.
Vsync_Low
                               
              mov       r1, #6
                        
              ' HSYNC 10.9us (Horizontal Sync)
:Vsync_Loop   mov       vscl, v_shsync
              waitvid   v_chsync, v_pvsync_low_1

              ' do "work".... here, nothing for now, but tons of time for image processing, etc.

              ' HVIS 52.6us (Visible Scanline)
              mov       vscl, v_shvis
              waitvid   v_chsync, v_pvsync_low_2

              ' do "work".... here, nothing for now, but tons of time for image processing, etc.

              djnz      r1, #:Vsync_Loop
Vsync_Low_Ret
              ret

' /////////////////////////////////////////////////////////////////////////////
' Calculates 2^32 * r1/r2, result stored in r3, r1 must be less that r2, that is, r1 < r2
' the results of the division are a binary weighted 32-bit fractional number where each bit
' is equal to the following weights:
' MSB (31)    30    29 ..... 0
'      1/2   1/4   1/8      1/2^32
Dividefract                                     
              mov       r0,#32+1                        ' 32 iterations, are we done yet?
:Loop         cmpsub    r1,r2           wc              ' does divisor divide into dividend?
              rcl       r3,#1                           ' rotate carry into result
              shl       r1,#1                           ' shift dividend over
              djnz      r0,#:Loop                       ' done with division yet?

Dividefract_Ret
              ret                                       ' return to caller with result in r3

'//////////////////////////////////////////////////////////////////////////////
' VARIABLE DECLARATIONS
'//////////////////////////////////////////////////////////////////////////////

' // DEBUGGER STUFF ///////////////////////////////////////////////////////////

{
' DEBUGGER LOCALS /////////////////////////////////////////////////////////////////////////////////////////////////////
' debugger locals, pointers back to storage in main memory, so we can alter them from ASM
debug_status_ptr     long    $0
debug_string_ptr     long    $0                       
debug_value_ptr      long    $0                       
debug_pos_ptr        long    $0                        
debug_value          long    $1234ABCD
' END DEBUGGER LOCALS /////////////////////////////////////////////////////////////////////////////////////////////////
}


' general purpose registers

r0            long      $0                             
r1            long      $0
r2            long      $0
r3            long      $0
r4            long      $0
r5            long      $0
r6            long      $0
r7            long      $0

line          long      $0                      ' current video line, not used currently

MAX_INT       long      $FFFFFFFF               ' largest integer also -1 in 2's complement
ZERO          long      $00000000
                                           
' tv output DAC port bit mask
tvport_mask   long      %0000_0111 << 24        ' Hydra DAC is on bits 24, 25, 26

' output buffers to hold colors and pixels, start them off with "test" data
                        '3  2  1  0   <- color indexes
v_pixels_buffer long    %%1111222233330000
v_colors_buffer long    $5C_CC_0C_03            ' 3-RED | 2-GREEN | 1-BLUE | 0-BLACK

' pixel VSCL value for 256 visible pixels per line (clocks per pixel 8 bits | clocks per frame 12 bits )
v_spixel      long      ((PNTSC256 >> 4) << 12) + PNTSC256


' hsync VSCL value (clocks per pixel 8 bits | clocks per frame 12 bits )
v_shsync      long      ((SNTSC >> 4) << 12) + SNTSC

' hsync colors (4, 8-bit values, each represent a color in the format chroma shift, chroma modulatation enable, luma | C3 C2 C1 C0 | M | L2 L1 L0 |
                        '3  2  1  0   <- color indexes
v_chsync      long      $00_00_02_8A ' SYNC (3) / SYNC (2) / BLACKER THAN BLACK (1) / COLOR BURST (0)

' hsync pixels
                        ' BP|BURST |BW|    SYNC     |FP| <- Key BP = Back Porch, Burst = Color Burst, BW = Breezway, FP = Front Porch
v_phsync      long      %%1_0_0_0_0_1_2_2_2_2_2_2_2_1_1_1

' active video values
v_shvis       long      ((VNTSC >> 4) << 12) + VNTSC

' the colors used, 4 of them always
                        'red, color 3 | dark blue, color 2 | blue, color 1 | light blue, color 0
v_chvis       long      $5A_0A_0B_0C            ' each 2-bit pixel below references one of these 4 colors, (msb) 3,2,1,0 (lsb)

' the pixel pattern                             
v_phvis       long      %%3210_0123_3333_3333   ' 16-pixels, read low to high is rendered left to right, 2 bits per pixel
                                                ' the numbers 0,1,2,3 indicate the "colors" to use for the pixels, the colors
                                                ' are defined by a single byte each with represents the chroma shift, modulation,
                                                ' and luma
' the colors used, 4 of them always
                        'grey, color 3 | dark grey, color 2 | blue, color 1 | black, color 0
v_choverscan  long      $06_04_0C_02            ' each 2-bit pixel below references one of these 4 colors, (msb) 3,2,1,0 (lsb)

' the pixel pattern
v_phoverscan  long      %%0000_0000_0000_0000   ' 16-pixels, read low to high is rendered left to right, 2 bits per pixel
                                                ' the numbers 0,1,2,3 indicate the "colors" to use for the pixels, the colors
                                                ' are defined by a single byte each with represents the chroma shift, modulation,
                                                ' and luma, always uses palette color 0

' vsync pulses 6x High, 6x Low, 6x High
' the vertical sync pulse according to the NTSC spec should be composed of a series
' of pulses called the pre-equalization, serration pulses (the VSYNC pulse itself), and the post-equalization pulses
' there are 6 pulses of each, and they more or less inverted HSYNC, followed by 6 HSYNC pulses, followed by 6 more inverted HSYNC pulses.
' this keeps the horizontal timing circutry locked as well as allows the 60 Hz VSYNC filter to catch the "vsync" event.
' the values 1,2 index into "colors" that represent sync and blacker than black.
' so the definitions below help with generated the "high" and "low" dominate HSYNC timed pulses which are combined
' to generated the actual VSYNC pulse, refer to NTSC documentation for more details.
                                
v_pvsync_high_1         long    %%1_1_1_1_1_1_1_1_1_1_1_2_2_2_1_1  
v_pvsync_high_2         long    %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
                                
v_pvsync_low_1          long    %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_1_1
v_pvsync_low_2          long    %%1_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
  
v_freq                  long    FNTSC

' tile engine locals
tile_row                long    $0              ' row 0-15 of tile being rendered
video_line              long    $0              ' current video line
tile_map_ptr            long    $0              ' ptr to tile map
tile_cache_ptr          long    $0              ' ptr to tile cache (future expansion)
palette_cache_ptr       long    $0              ' ptr to palette cache (future expansion)
tile_map_index          long    $0              ' current tile index of tile being processed
tile_map_index_ptr      long    $0              ' pointer to record holding current tile index and tile palette index
tile_map_word           long    $0              ' tile map words holds a single tile map record which contains the tile index and palette index
tile_palette_index      long    $0              ' index of palette to use for tile 

' sprite locals to help process each sprite
sprite_x                long    $0              ' logical/physical x position of sprite
sprite_y                long    $0              ' logical/physical y position of sprite
sprite_state            long    $0              ' state field of sprite record
sprite_bitmap_ptr       long    $0              ' bitmap ptr field of sprite record
sprite_tile_x           long    $0              ' tile offset sprite is within 0..15
sprite_offset_x         long    $0              ' pixel within tile sprite is within 0..15
sprite_num_active_cntr  long    $0              ' number of active sprites counter, used to throttle processing per line

' tile engine passed parameters
tile_map_base_ptr               long    $0      ' ptr to base of tile map
tile_bitmaps_base_ptr           long    $0      ' ptr to base of tile bitmaps
tile_palettes_base_ptr          long    $0      ' ptr to base of palettes
tile_map_width                  long    $0      ' width of tile map in powers of 2 times base width encoded as integer 0..n
tile_sprite_tbl_base_ptr        long    $0      ' ptr to base of sprite table
tile_status_bits_ptr            long    $0      ' ptr to status word engine writes its state to


' local COG cache/buffer memories (future expansion)

' sprite table cache 16 LONGs, each entry is 2 LONGs, LONG 0 is the state/control, LONG 1 is the ptr to the bitmap in main memory
' the sprite table is copied each frame from the main memory to the local cache, so hub access can be minimized during rendering algorithms
' the only downside is that sprites are updated only at a rate of 60 FPS max, however, if this become as issue we can always refresh the
' cache EVERY line as well --
sprite_table_cache      long $0,$0 ' sprite 0: state/bitmap ptr
                        long $0,$0 ' sprite 1: state/bitmap ptr
                        long $0,$0 ' sprite 2: state/bitmap ptr
                        long $0,$0 ' sprite 3: state/bitmap ptr

                        long $0,$0 ' sprite 4: state/bitmap ptr
                        long $0,$0 ' sprite 5: state/bitmap ptr
                        long $0,$0 ' sprite 6: state/bitmap ptr
                        long $0,$0 ' sprite 7: state/bitmap ptr                                                                        

' these scanline buffers hold an entire scanline of data for the sprite and the mask for the scanline to overlay into tile memory

sprite_scanline_bitmap  long $0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0    ' this buffers and entire scanline, primary for the sprite overlay algorithm 
sprite_scanline_mask    long $0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0    ' this is the scanline "mask" for the sprite data, used to make a "hole",
                                                                                ' so where the sprite data will be OR'ed in, its the union off all the masks
                                                                                ' for each sprite that is on the current line

' these buffers are used to generate a single sprites slice bitmap and slice mask and allow a shifting operation to position it sub-tile accurate
' then these buffers are used to write into the main scanline buffers that hold the sprite bitmap and mask data
sprite_bitmap_buffer    long $0, $0
sprite_mask_buffer      long $0, $0

sprite_test_mask        long $0

' END ASM /////////////////////////////////////////////////////////////////////

' WORK AREA ///////////////////////////////////////////////////////////////////
{


' memory to memory copy from main memory to cog memory using self modifying code
:Tile_Copy_To_Cache_Loop

              movd    :read, tile_cache_ptr             ' self modify destination operand of the "rdlong" opcode with the destination of read pointer
              nop
:read         rdlong  0, tile_map_ptr
              add     r2, #4                            ' main memory add 4 to get to next LONG, always BYTE addresses
              add     r3, #1                            ' r2 pointing to COG memory always LONG addresses
              djnz    r4, #:Tile_Copy_To_Cache_Loop
                                                                               
' // DEBUGGER STUFF ///////////////////////////////////////////////////////////

              mov       r0, par                         ' copy boot parameter value and read in debug parameters from main memory
              add       r0, #24
              mov       debug_status_ptr, r0            ' read in debug_status_ptr
              add       r0, #4
              mov       debug_string_ptr, r0            ' read in the debug_string_ptr           
              add       r0, #4
              mov       debug_value_ptr, r0             ' read in the debug_value_ptr          
              add       r0, #4
              mov       debug_pos_ptr, r0               ' read in the debug_pos_ptr        

              ' request a print out ///////////////////////////////////////////
              mov       r0, debug_value 
              wrlong    r0, debug_value_ptr             ' mm[debug_value_ptr] = r0

              mov       r0, debug_string 
              wrlong    r0, debug_string_ptr            ' mm[debug_string_ptr] = r0

              ' set status to 1, so outside picks up and prints debug value
              mov       r0, #1
              wrlong    r0, debug_status_ptr
              ' end request to print //////////////////////////////////////////

' // END DEBUGGER STUFF ///////////////////////////////////////////////////////



              ' now build up mask, complex operation...

              mov       sprite_test_mask,    #%11       ' lower two bits are 1's, these are used to test each 2-bit color/pixel in source bitmap row
              mov       sprite_test_mask+1,  #0
              mov       sprite_mask_buffer,  #0         ' clear out the mask buffer, this will hold the results of the mask construction 
              mov       sprite_mask_buffer+1,#0

              ' now construct mask, must scan every 2-bit color pair

              mov       r6, #16                         ' 16 iterations, loop counter              

Build_Sprite_Mask


              test      sprite_bitmap_buffer, sprite_test_mask    wc, wz  ' results = sprite_bitmap_buffer AND sprite_test_mask              
        if_z  jmp       #No_Sprite_Pixels                                 ' if results of AND are 0, then there are no sprite pixels at this position

              ' else we need to add these positions to the master mask
              or        sprite_mask_buffer, sprite_test_mask   ' sprite_mask_buffer = sprite_mask_buffer | sprite_test_mask

No_Sprite_Pixels              

              shl       sprite_test_mask, #2            ' shift the test mask over 2-bits to next color pixel 
                        
              djnz      r6, #Build_Sprite_Mask          ' if (--r6 > 0) then loop...






              ' bitmap/mask shift algorithm
              mov       r6, sprite_offset_x      wz     ' shift bitmap and mask sprite_offset_x times...
        if_z  jmp       #Sprite_Merge_Data              ' if sprite_offset_x = 0 then jmp out             

              shl       r6, #1                          ' mult by 2, since 2 bits per pixel
Sprite_Shift_Loop

              ' shift the sprite bitmap and mask by 2 bits per pixel
              shl       sprite_bitmap_buffer, #1        ' shift low word
              rcl       sprite_bitmap_buffer+1, #1      ' capture carry, rotate upper word

              shl       sprite_mask_buffer, #1          ' shift low word
              rcl       sprite_mask_buffer+1, #1        ' capture carry, rotate upper word

              djnz      r6, #Sprite_Shift_Loop          ' while (--r6 > 0) loop...



}
' END WORK AREA ///////////////////////////////////////////////////////////////