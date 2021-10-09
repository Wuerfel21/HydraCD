' //////////////////////////////////////////////////////////////////////
' COP test (tv-graphics engine)         
' AUTHOR: Colin Phillips
' LAST MODIFIED: 1.29.06
' VERSION 0.6
'
' DESCRIPTION:
' 6 sprites moving around the screen + 1 16x256 sprite controlled by mouse.
' 16 different sprites shown                               
'
' NOTES:
' - small fix, added frequency divider. you can now fudge the frequency
' - fixed debugled bug
' - added overscans
' - added sprite
' - fixed sprite glitch where top line's last quad pixel flashed.
' - have multiple sprites 7 sprites Total, 3 on same scanline Max.
' - added waitvsync/current scanline code. (cop_status)
' - tile data in a seperate file, uses XGSBMP to produce sprites :-)
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
  cop   : "cop_drv_006.spin"          ' instantiate a cop object
  key   : "keyboard_iso_010.spin"    ' instantiate a keyboard object
  mouse : "mouse_iso_010.spin"       ' instantiate a mouse object  
  tiles : "tiles.spin"               ' data object.
  
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

  cop.colormodify(tiles.data, 4096, $f0) ' invert phase
  
cop_obj[obj_size*0 + OBJ_OFFSET_X] := 64
cop_obj[obj_size*0 + OBJ_OFFSET_Y] := 64
cop_obj[obj_size*0 + OBJ_OFFSET_W] := (16+3)/4
cop_obj[obj_size*0 + OBJ_OFFSET_H] := 256-1
cop_obj[obj_size*0 + OBJ_OFFSET_I] := tiles.data '@SPRITE_ADDR '+256
  
count_dir := $04000000

mousex := 0
mousey := 0

frame := 0
'sit in infinite loop.

repeat while TRUE
  cop_debug := $80000000 + Sin(frame<<2)<<15
                    
  mousex := mousex + mouse.delta_x #> 0 <# 255-16
  mousey := mousey - mouse.delta_y #> 0 <# 224
  cop_obj[4*0 + OBJ_OFFSET_X] := mousex
  cop_obj[4*0 + OBJ_OFFSET_Y] := mousey

  repeat i from 1 to obj_n-1
    cop_obj[obj_size*i + OBJ_OFFSET_X] := 128 + Sin(i*37 + (frame<<2))>>10 ' 0..64
    cop_obj[obj_size*i + OBJ_OFFSET_Y] := (112 + Sin(64 + i*29 + (frame))>>10)&255 ' 0..64
    cop_obj[obj_size*i + OBJ_OFFSET_W] := (16+3)/4
    cop_obj[obj_size*i + OBJ_OFFSET_H] := 16-1
    cop_obj[obj_size*i + OBJ_OFFSET_I] := tiles.data + 256*(i+(frame>>8)&7)

' sync to 60FPS :-)
  cop.waitvsync ' waits until end of VSYNC+New Frame processing (i.e. updating of cop_obj data to cog, so we're safe)
  
  frame++

'///////////////////////////////////////////////////////////////////////////////
PUB Sin(x) : y | t
' y = sine(x)
t := x&63
if(x&64)
  t^=63
  
y := WORD[$E000 + t<<6]

if(x&128)
  y := -y