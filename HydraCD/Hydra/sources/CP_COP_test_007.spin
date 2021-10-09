' //////////////////////////////////////////////////////////////////////
' COP test (tv-graphics engine)         
' AUTHOR: Colin Phillips
' LAST MODIFIED: 1.30.06
' VERSION 0.7
'
' DESCRIPTION:
' 19 sprites moving around the screen + 1 16x16 sprite controlled by mouse.
' Press Left and Right mouse buttons to cycle through the sprites.
' Cogs are synchronized to the clock, however the PHSA register on the cogs
' is not synchronized, therefore you'll sometimes get B/W, interesting...
' so by randomly loading it or by bringing in lines 238-250
' in the cop_drv_007. and then running the program, clicking the mouse buttons
' will let you change the PHSA register of cog 0 there should be a way to get
' around this problem, without needing the cogs synchronized... perhaps it's the other HSYNCS (non visible-active)
' since they're both drawn together (on both cogs). TV's might be fussy here.
' Anyway this is it for now.
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
' - Alternating Cogs added, With runtime correction Syncing code.
' - full transparancy added (sprites properly perform AND & OR masking, but is a CPU intensive algorithm)
' - 20 sprites now (note: limitation here is the memory organisation not speed),
' around 7 on the same scanline lower than expected, due to the full transparancy added
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x          ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 3000      ' set frequency to 10 MHZ plus some error    
  _stack   = 40 + 256               ' accomodate display memory and stack

  obj_n         = 20                ' Number of Objects
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
long  h_cop_phase0
long  h_cop_monitor0
long  h_cop_monitor1
' |
' |
' LAST
long  cop_obj[obj_total_size]       ' 12 sprite positions

long  count_dir
long  count2_dir

long  mousex, mousey              ' holds mouse x,y absolute position
long  mouse_sprite_no
long  particle_sprite_no
byte button_hist[2]             ' button history
byte button_cooldown


'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

OBJ
  cop   : "cop_drv_007.spin"         ' instantiate a cop object
  key   : "keyboard_iso_010.spin"    ' instantiate a keyboard object
  mouse : "mouse_iso_010.spin"       ' instantiate a mouse object  
  tiles : "cp_cop_tiles_001.spin"    ' data object. (16 sprites)
  
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

  button_hist[0] := 0
  button_hist[1] := 0
  button_cooldown := 0

  'start cop engine
  cop_debug := $0
  cop.start(@cop_status)

  cop.colormodify(tiles.data, 4096, $f0) ' invert phase

  mouse_sprite_no := 5
  particle_sprite_no := 1
  
  count_dir := $04000000

  mousex := 256/2
  mousey := 224/2

  frame := 0
'sit in infinite loop.

repeat while TRUE

' /////////////////////////////////////////////////////////////////////////////
' /// MAIN LOOP ///////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

  cop_debug := $80000000 + Sin(frame<<2)<<15

  ' OBJ #0 : Mouse position

  ' Mouse (mapped onto NES buttons)
  button_hist[0] := (button_hist[0]<<1 | mouse.button(0)&1)
  button_hist[1] := (button_hist[1]<<1 | mouse.button(1)&1)

  ' Control COP phases (ASM code removed now)
  'cop_control := mouse.button(0)&1
  'cop_control |= (mouse.button(1)&1)<<1 

  mousex := mousex + mouse.delta_x #> 0 <# 256-16
  mousey := mousey - mouse.delta_y #> 8 <# 224-24
  cop_obj[obj_size*(obj_n-1) + OBJ_OFFSET_X] := mousex
  cop_obj[obj_size*(obj_n-1) + OBJ_OFFSET_Y] := mousey
  cop_obj[obj_size*(obj_n-1) + OBJ_OFFSET_W] := (16+3)/4
  cop_obj[obj_size*(obj_n-1) + OBJ_OFFSET_H] := 16-1
  cop_obj[obj_size*(obj_n-1) + OBJ_OFFSET_I] := tiles.data + 256*mouse_sprite_no

  cop_control := 0
  if(button_cooldown)
    button_cooldown--
  else
    if(button_hist[0]&3==%01) ' L-Click-Down (i.e. previously 0 UP, now 1 DOWN)
      mouse_sprite_no := (mouse_sprite_no+1)&15
      cop_control := 1
      button_cooldown := 5                              ' 5 frame cooldown (stops accidental double clicks)
    if(button_hist[1]&3==%01) ' R-Click-Down (i.e. previously 0 UP, now 1 DOWN)
      particle_sprite_no := (particle_sprite_no+1)&15
      cop_control := 2
      button_cooldown := 5                              ' 5 frame cooldown (stops accidental double clicks)

  ' 'Particle' sprites moving around the screen on a sinus wave.
  repeat i from 0 to obj_n-2
    cop_obj[obj_size*i + OBJ_OFFSET_X] := 128 + Sin(i*37 + (frame<<1))>>10 ' 0..64
    cop_obj[obj_size*i + OBJ_OFFSET_Y] := (112 + Sin(64 + i*29 + (frame))>>10)&255 ' 0..64
    cop_obj[obj_size*i + OBJ_OFFSET_W] := (16+3)/4
    cop_obj[obj_size*i + OBJ_OFFSET_H] := 16-1
    cop_obj[obj_size*i + OBJ_OFFSET_I] := tiles.data + 256*particle_sprite_no

  x := 10000 + (h_cop_monitor0>>4-h_cop_monitor1>>4)
  
' sync to 60FPS :-)
  cop.waitvsync
  
  frame++

' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

PUB Int_To_String(i) | x

' does an sprintf(str, "%05d", i); job
repeat x from 4 to 0
  cop_obj[obj_size*(1+x) + OBJ_OFFSET_I] := tiles.data + 256*(i // 10)
  cop_obj[obj_size*(1+x) + OBJ_OFFSET_X] := 16+16*x
  cop_obj[obj_size*(1+x) + OBJ_OFFSET_Y] := 32+16 '+8*x
  cop_obj[obj_size*(1+x) + OBJ_OFFSET_W] := (16+3)/4
  cop_obj[obj_size*(1+x) + OBJ_OFFSET_H] := 16-1
  i/=10


PUB Sin(x) : y | t
' y = sine(x)
t := x&63
if(x&64)
  t^=63
  
y := WORD[$E000 + t<<6]

if(x&128)
  y := -y

DAT

buffer                  LONG                    $0, $0, $0, $0