' //////////////////////////////////////////////////////////////////////
' COP test (tv-graphics engine)         
' AUTHOR: Colin Phillips
' LAST MODIFIED: 1.26.06
' VERSION 0.4
'
' DESCRIPTION:
' Produces a 256 color Sprite on the scanline :-)
' Note colors are offseted by $02020202 that is for Black you use color $00
' instead of $02
'
' NOTES:
' - small fix, added frequency divider. you can now fudge the frequency
' - fixed debugled bug
' - added overscans
' - added sprite
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x          ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 3000      ' set frequency to 10 MHZ plus some error    
  _stack   = 40                     ' accomodate display memory and stack

  obj_n         = 12                ' Number of Objects
  obj_size      = 4                 ' register per object.
  obj_total_size = obj_n*obj_size   ' Total Number of registers (LONGS)
  OBJ_OFFSET_X  = 0
  OBJ_OFFSET_Y  = 1
  OBJ_OFFSET_W  = 2
  OBJ_OFFSET_H  = 3
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
  cop   : "cop_drv_004.spin"          ' instantiate a cop object
  key   : "keyboard_iso_010.spin"    ' instantiate a keyboard object
  mouse : "mouse_iso_010.spin"       ' instantiate a mouse object

'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB Start | x, y, frame
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

count_dir := $00040000

cop_obj[4*0 + OBJ_OFFSET_X] := 64
cop_obj[4*0 + OBJ_OFFSET_Y] := 64
cop_obj[4*0 + OBJ_OFFSET_W] := (16+3)/4
cop_obj[4*0 + OBJ_OFFSET_H] := 16-1

repeat y from 0 to 16
  LONG[VRAM_ADDR+y*16] := $3A2A1A0A
  LONG[VRAM_ADDR+y*16+4] := $7A6A5A4A
  LONG[VRAM_ADDR+y*16+8] := $BAAA9A8A
  LONG[VRAM_ADDR+y*16+12] := $FAEADACA

repeat x from 0 to 16
  Sprite_Pixel(0, x,0, $05)
  Sprite_Pixel(0, x,15, $05)
  Sprite_Pixel(0, 0,x, $05)
  Sprite_Pixel(0, 15,x, $05)

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
  frame++

'///////////////////////////////////////////////////////////////////////////////
PUB Sprite_Pixel(t, x,y,c) | mask

BYTE[VRAM_ADDR+t*256+y*16+x] := c

'///////////////////////////////////////////////////////////////////////////////  
PUB Blink(rate)
' this is the parallel function, it simple blinks the debug LED on the
' hydra, note is must set the direction output and then falls into
' an infinite loop and turns the LED on / off with a delay count.
' the interesting thing to realize is that the "rate" is sent as a parm
' when we launch the COG, so there will be 2 COGs running this SAME
' infinite loop, but each with a differnet blink rate, the results
' will be a blinking light that has both one constant blink rate
' with another super-imposed on it

DIRA[0] := 1                                             

repeat while TRUE
  OUTA[0] := !OUTA[0]
  waitcnt(CNT + rate)