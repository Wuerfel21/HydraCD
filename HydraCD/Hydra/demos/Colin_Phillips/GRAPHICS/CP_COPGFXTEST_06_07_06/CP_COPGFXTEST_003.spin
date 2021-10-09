' //////////////////////////////////////////////////////////////////////
' CopGFX Test                           
' AUTHOR: Colin Phillips
' LAST MODIFIED: 6.07.06
' VERSION 0.3
'
' DESCRIPTION:
' CopGFX - 2nd graphics engine test.
'
' Use Controller Pad:
' D-Pad to pan around map.
' Select/Start to rotate view.
' A/B to zoom in/out.
' (sprites not added yet)
'
' Modifying sprites/map:
'
' The sprites are stored in 'cp_copgfx_tiles_001.bmp', a 128x128 image with 64 16x16 sprites inside.
' They can simply be modified using any image editing software. In order to convert the .BMP file into a .SPIN
' compilable file. Execute the 'cp_copgfx_doit.bat' batch file which will perform the conversion of the 'cp_copgfx_tiles_001.bmp'
' file into 'cp_copgfx_tiles_001.spin'.
'
' The map is stored in 'cp_copgfx_map_001.fmp', a MAPPY format. In order to modify you'll need to
' download MappyWin32 V1.4.11 or higher/compatible version - You can download MAPPY at http://www.tilemap.co.uk/
' In order to convert the Map into .SPIN. First you must export the map as a .MAR (Map Array) format using
' Mappy. Then execute the 'cp_copgfx_doit.bat' batch file which will perform the conversion of the 'cp_copgfx_map_001.mar' file
' into 'cp_copgfx_map_001.spin'. Ready to be compiled
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x          ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000      ' set frequency to 10 MHZ plus some error    
  _memstart = $10                   ' memory starts $10 in!!! (this took 2 headaches to figure out)

  #0, h_copgfx_status, h_copgfx_vram, h_copgfx_map, h_copgfx_bg0_s, h_copgfx_bg0_h, h_copgfx_bg0_v, h_copgfx_bg0_dh, h_copgfx_bg0_dv  
  copgfx_obj_n  = 24                ' Number of Objects
  copgfx_obj_size = 6               ' bytes per object.
  copgfx_obj_total_size = copgfx_obj_n*copgfx_obj_size  ' Total Number of bytes
  COPGFX_OBJ_OFFSET_X = 0           ' 8-bit: X position
  COPGFX_OBJ_OFFSET_Y = 1           ' 8-bit: Y position
  COPGFX_OBJ_OFFSET_W = 2           ' 8-bit: Width
  COPGFX_OBJ_OFFSET_H = 3           ' 8-bit: Height
  COPGFX_OBJ_OFFSET_I = 4           ' 16-bit: Bitmap Address

  ' BUTTON encodings (same as NES Controller)
  KEY_RIGHT  = %00000001
  KEY_LEFT   = %00000010
  KEY_DOWN   = %00000100
  KEY_UP     = %00001000
  KEY_START  = %00010000
  KEY_SELECT = %00100000
  KEY_B      = %01000000
  KEY_A      = %10000000
  

'///////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

VAR

LONG copgfx_status
LONG copgfx_vram
LONG copgfx_map
LONG copgfx_bg0_s                   ' start position
LONG copgfx_bg0_h                   ' horizontal vector (s+=h per pixel)
LONG copgfx_bg0_v                   ' vertical vector (s+=v per line)
LONG copgfx_bg0_dh                  ' horizontal vector delta (h+=dh per pixel)
LONG copgfx_bg0_dv                  ' vertical vector delta (v+=dv per line)

LONG copgfx_obj[copgfx_obj_total_size]                  ' sprite attributes.

BYTE map_data[4096]

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

OBJ
  copgfx : "copgfx_drv_003.spin"                        ' instantiate a copgfx object.
  tiles : "cp_copgfx_tiles_001.spin"                    ' tiles
  map   : "cp_copgfx_map_001.spin"                      ' map
  
'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB Start | x, y, i, n, dir, anim, frame, t, temp_s, scale, spread_v, spread_dv
' this is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

  copgfx_map := map.data '@map_data
  copgfx_vram := tiles.data
  copgfx.start(@copgfx_status)

  repeat i from 0 to 4095
    map_data[i] := 16

  repeat x from 0 to 63
    map_data[x] := 17
    map_data[x*64] := 17
    map_data[x+63*64] := 17
    map_data[x*64+63] := 17

  repeat x from 0 to 63
    map_data[x*65] := 21

  ' Initial Vectors Orthognal View origin (0,0)
  copgfx_bg0_s := $0000_0000
  copgfx_bg0_h := $0000_0040 '60
  copgfx_bg0_v := $0040_0000                               
  copgfx_bg0_dh := $0000_0000
  copgfx_bg0_dv := $0000_0000                              
  scale := $40
  frame := 0
  dir := 0
  
  ' Interactive panning/rotating/zooming of map...
  
  repeat while TRUE

    ' NES Controllers (two player inputs)
    i := NES_Read_Gamepad
    if(i&$00ff == $00ff) ' controller 0 not plugged in, pretend all buttons are unpressed.
      i&=$ff00
    if(i&$ff00 == $ff00) ' controller 1 not plugged in, pretend all buttons are unpressed.
      i&=$00ff

    if(i&KEY_UP)
      temp_s -= $0040_0000
    if(i&KEY_DOWN)
      temp_s += $0040_0000
    if(i&KEY_LEFT)
      temp_s -= $0000_0040
    if(i&KEY_RIGHT)
      temp_s += $0000_0040
    if(i&KEY_B)
      scale -= 1
    if(i&KEY_A)
      scale += 1
    if(i&KEY_SELECT)
      dir -= 4096
    if(i&KEY_START)
      dir += 4096

    copgfx_bg0_h := GetVect((dir~>8)+2048,scale)
    copgfx_bg0_v := GetVect((dir~>8),scale)

    copgfx_bg0_s := temp_s
    copgfx_bg0_s -= copgfx_bg0_h * 80
    copgfx_bg0_s -= copgfx_bg0_v * 112
  
    copgfx.waitvsync

  ' Automatic fancy rotozooming effect...
  
  repeat while TRUE
  
    ' Adjust Scale and Direction as a function of time.
    t := $200 + ($1f0*Sin(frame*4))~>16
    't := $80
    dir += 4096 + (3072*Sin(frame))~>16
    
    copgfx_bg0_h := GetVect((dir~>8)+2048,t)
    copgfx_bg0_v := GetVect((dir~>8),(t*160)~>8)
    ' Center View
    copgfx_bg0_s := $0800_0800
'   copgfx_bg0_s += $0100 * 64
'   copgfx_bg0_s += $0100_0000 * 64
    copgfx_bg0_s -= copgfx_bg0_h * 80
    copgfx_bg0_s -= copgfx_bg0_v * 112

    frame+=8
    copgfx.waitvsync
    

' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

PUB Sin(x) : y | t
' y = sin(x)
t := x&2047  ' 63
if(x&2048) ' 64
  t^=2047 ' 63

y := WORD[$E000 | t<<1]

if(x&4096) ' 128
  y := -y

PUB GetVect(a,d) : v | x,y
' returns a 32-bit composite vector angle a, magnitude d.
x := (Sin(a)*d)~>16
y := (Sin(a+2048)*d)~>16 '64

v := y<<16 | x&$ffff

' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////


PUB NES_Read_Gamepad : nes_bits        |  i

' //////////////////////////////////////////////////////////////////
' NES Game Paddle Read
' //////////////////////////////////////////////////////////////////       
' reads both gamepads in parallel encodes 8-bits for each in format
' right game pad #1 [15..8] : left game pad #0 [7..0]
'
' set I/O ports to proper direction
' P3 = JOY_CLK      (4)
' P4 = JOY_SH/LDn   (5) 
' P5 = JOY_DATAOUT0 (6)
' P6 = JOY_DATAOUT1 (7)
' NES Bit Encoding
'
' RIGHT  = %00000001
' LEFT   = %00000010
' DOWN   = %00000100
' UP     = %00001000
' START  = %00010000
' SELECT = %00100000
' B      = %01000000
' A      = %10000000

' step 1: set I/Os
DIRA [3] := 1 ' output
DIRA [4] := 1 ' output
DIRA [5] := 0 ' input
DIRA [6] := 0 ' input

' step 2: set clock and latch to 0
OUTA [3] := 0 ' JOY_CLK = 0
OUTA [4] := 0 ' JOY_SH/LDn = 0
'Delay(1)

' step 3: set latch to 1
OUTA [4] := 1 ' JOY_SH/LDn = 1
'Delay(1)

' step 4: set latch to 0
OUTA [4] := 0 ' JOY_SH/LDn = 0

' step 5: read first bit of each game pad

' data is now ready to shift out
' first bit is ready 
nes_bits := 0

' left controller
nes_bits := INA[5] | (INA[6] << 8)

' step 7: read next 7 bits
repeat i from 0 to 6
 OUTA [3] := 1 ' JOY_CLK = 1
 'Delay(1)             
 OUTA [3] := 0 ' JOY_CLK = 0
 nes_bits := (nes_bits << 1)
 nes_bits := nes_bits | INA[5] | (INA[6] << 8)

 'Delay(1)             
' invert bits to make positive logic
nes_bits := (!nes_bits & $FFFF)

' //////////////////////////////////////////////////////////////////
' End NES Game Paddle Read
' //////////////////////////////////////////////////////////////////