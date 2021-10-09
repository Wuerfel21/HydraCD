' //////////////////////////////////////////////////////////////////////
' COP test (tv-graphics engine)         
' AUTHOR: Colin Phillips
' LAST MODIFIED: 1.28.06
' VERSION 0.5
'
' DESCRIPTION:
' 6 sprites moving around the screen + 1 sprite controlled by mouse.
' 4 different tiles shown.                                 
'
' NOTES:
' - small fix, added frequency divider. you can now fudge the frequency
' - fixed debugled bug
' - added overscans
' - added sprite
' - fixed sprite glitch where top line's last quad pixel flashed.
' - have multiple sprites 7 sprites Total, 3 on same scanline Max.
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x          ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000      ' set frequency to 10 MHZ plus some error    
  _stack   = 40 + 256               ' accomodate display memory and stack

  obj_n         = 7                 ' Number of Objects
  obj_size      = 5                 ' registers per object.
  obj_total_size = obj_n*obj_size   ' Total Number of registers (LONGS)
  OBJ_OFFSET_X  = 0
  OBJ_OFFSET_Y  = 1
  OBJ_OFFSET_W  = 2
  OBJ_OFFSET_H  = 3
  OBJ_OFFSET_I  = 4
  VRAM_ADDR = $4000                 ' Video RAM (Sprite data)
  
'///////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

VAR

long  blink_stack[20]               ' allocate 20 longs for the task stack
long  cop_status
long  cop_control
long  cop_debug
' |
' |
' LAST
long  cop_obj[obj_total_size]       ' 12 sprite positions

long  count_dir
long  count2_dir

long  mousex, mousey              ' holds mouse x,y absolute position

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

OBJ
  cop   : "cop_drv_005.spin"          ' instantiate a cop object
  key   : "keyboard_iso_010.spin"    ' instantiate a keyboard object
  mouse : "mouse_iso_010.spin"       ' instantiate a mouse object

'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB Start | x, y, i, frame
' this is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

  'start keyboard on pingroup 3 
  key.start(3)

  'start mouse on pingroup 2 (Hydra mouse port)
  mouse.start(2)

  'start cop
  cop_debug := $0

  cop.start(@cop_status)

cop_obj[obj_size*0 + OBJ_OFFSET_X] := 64
cop_obj[obj_size*0 + OBJ_OFFSET_Y] := 64
cop_obj[obj_size*0 + OBJ_OFFSET_W] := (16+3)/4
cop_obj[obj_size*0 + OBJ_OFFSET_H] := 16-1
cop_obj[obj_size*0 + OBJ_OFFSET_I] := VRAM_ADDR+0

cop_obj[obj_size*1 + OBJ_OFFSET_X] := 96
cop_obj[obj_size*1 + OBJ_OFFSET_Y] := 40
cop_obj[obj_size*1 + OBJ_OFFSET_W] := (16+3)/4
cop_obj[obj_size*1 + OBJ_OFFSET_H] := 16-1
cop_obj[obj_size*1 + OBJ_OFFSET_I] := VRAM_ADDR+256

cop_obj[obj_size*2 + OBJ_OFFSET_X] := 150
cop_obj[obj_size*2 + OBJ_OFFSET_Y] := 50
cop_obj[obj_size*2 + OBJ_OFFSET_W] := (16+3)/4
cop_obj[obj_size*2 + OBJ_OFFSET_H] := 16-1
cop_obj[obj_size*2 + OBJ_OFFSET_I] := VRAM_ADDR+512

'repeat i from 0 to obj_n-1
' cop_obj[obj_size*i + OBJ_OFFSET_X] := 128
' cop_obj[obj_size*i + OBJ_OFFSET_Y] := i*16
' cop_obj[obj_size*i + OBJ_OFFSET_W] := (16+3)/4
' cop_obj[obj_size*i + OBJ_OFFSET_H] := 16-1
' cop_obj[obj_size*i + OBJ_OFFSET_I] := VRAM_ADDR+256*(i&3)
  
  
count_dir := $00040000

' MAKE SOME SPRITE DATA

repeat y from 0 to 15
  LONG[VRAM_ADDR+y*16] := $3A2A1A0A
  LONG[VRAM_ADDR+y*16+4] := $7A6A5A4A
  LONG[VRAM_ADDR+y*16+8] := $BAAA9A8A
  LONG[VRAM_ADDR+y*16+12] := $FAEADACA
  
  LONG[VRAM_ADDR+256+y*16] := $0
  LONG[VRAM_ADDR+256+y*16+4] := $0
  LONG[VRAM_ADDR+256+y*16+8] := $0
  LONG[VRAM_ADDR+256+y*16+12] := $0

  LONG[VRAM_ADDR+512+y*16] := $BAAA9A8A
  LONG[VRAM_ADDR+512+y*16+4] := $BAAA9A8A
  LONG[VRAM_ADDR+512+y*16+8] := $BAAA9A8A
  LONG[VRAM_ADDR+512+y*16+12] := $BAAA9A8A

  LONG[VRAM_ADDR+768+y*16] := $CBDBEBFB
  LONG[VRAM_ADDR+768+y*16+4] := $8B9BABBB
  LONG[VRAM_ADDR+768+y*16+8] := $4B5B6B7B
  LONG[VRAM_ADDR+768+y*16+12] := $0B1B2B3B

repeat x from 0 to 15
  Sprite_Pixel(0, x,0, $05)
  Sprite_Pixel(0, x,15, $05)
  Sprite_Pixel(0, 0,x, $05)
  Sprite_Pixel(0, 15,x, $05)

  Sprite_Pixel(1, x,0, $05)
  Sprite_Pixel(1, x,15, $05)
  Sprite_Pixel(1, 0,x, $05)
  Sprite_Pixel(1, 15,x, $05)
  Sprite_Pixel(1, x,x, $8C)

mousex := 0
mousey := 0

frame := 0
'sit in infinite loop, that is do not release COG 0
repeat while TRUE
  cop_debug+=count_dir
  if(cop_debug==0)
    count_dir := -count_dir
                    
  mousex := mousex + mouse.delta_x #> 0 <# 255-16
  mousey := mousey - mouse.delta_y #> 0 <# 224
  cop_obj[4*0 + OBJ_OFFSET_X] := mousex
  cop_obj[4*0 + OBJ_OFFSET_Y] := mousey
  repeat i from 1 to obj_n-1
' i := 2
    cop_obj[obj_size*i + OBJ_OFFSET_X] := 128 + Sine(i*37 + (frame)>>3)>>10 ' 0..64
    cop_obj[obj_size*i + OBJ_OFFSET_Y] := (112 + Sine(64 + i*29 + (frame)>>3)>>10)&255 ' 0..64
    cop_obj[obj_size*i + OBJ_OFFSET_W] := (16+3)/4
    cop_obj[obj_size*i + OBJ_OFFSET_H] := 16-1
    cop_obj[obj_size*i + OBJ_OFFSET_I] := VRAM_ADDR+256*(i&3)

  frame++

'///////////////////////////////////////////////////////////////////////////////
PUB Sine(x) : y | t
' y = sine(x)
t := x&63
if(x&64)
  t^=63
  
y := WORD[$E000 + t<<6]

if(x&128)
  y := -y

'///////////////////////////////////////////////////////////////////////////////
PUB Sprite_Pixel(i, x,y,c) | mask

BYTE[VRAM_ADDR+i*256+y*16+x] := c