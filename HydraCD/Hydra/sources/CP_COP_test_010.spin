' //////////////////////////////////////////////////////////////////////
' COP test (tv-graphics engine)         
' AUTHOR: Colin Phillips
' LAST MODIFIED: 1.3.06
' VERSION 1.0
'
' DESCRIPTION:
' 32 sprites on screen + Map & plain black background layer (scroll up).
' Mouse Controlled.
'
' NOTES:
' - small fix, added frequency divider. you can now fudge the frequency
' - fixed debugled bug
' - added overscans
' - added sprite
' - fixed sprite glitch where top line's last quad pixel flashed.
' - have multiple sprites 7 sprites Total, 3 on same scanline Max.
' - added waitvsync/current scanline code. (cop_status)
' - 0.6: tile data in a seperate file, uses XGSBMP to produce sprites :-)
' - 0.7: Alternating Cogs added, With runtime correction Syncing code.
' - 0.7: full transparancy added (sprites properly perform AND & OR masking, but is a CPU intensive algorithm)
' - 0.7: 20 sprites now (note: limitation here is the memory organisation not speed),
' around 7 on the same scanline lower than expected, due to the full transparancy added
' - 0.8: 32 sprites now, Automatic horizontal scanline limiter added
' - 0.8: Upgraded COG SYNC, and Added Chroma SYNC
' - 1.0: Moved setup code (syncing)to end to save runtime memory space (for scanline/obj)
' cleaner initialization, no sprites are rendered until 30 frames take place. which helps
' with the setup phase (many times the sprites crashed the process)
' - 1.0: Added some SPIN HLL functions for setting up sprites (Note HLL is SO SLOW!!!)
' - 1.0: Fixed Top Clipping (ASM), Left & Right Clipping are SPIN code.
' - 1.0: Changed 'scanline timeout' code to check on every quad pixel, instead of per sprite.
' enabling me to reduce the scanline timeout safety margin.
' - 1.0: Added map engine, added vertical scroll + background color changer.
' - 1.0: Upgraded XGSBMP to support basic creation of tile maps.
' Note: there is some sort of bug which gets it out of sync (the screen goes B/W and flashes a semi-scrambled picture)
' i believe this to be somewhere, where there is a process which on the offchance exceeds
' it's WAITVID. Perhaps in the sprite scanline preparation.
' Also there is some sort of bug in that it doesn't sync up the chroma and you get a clean pic but in B/W
' This is likely that sometimes it doesnt get the chroma synced by 30 frames, probably also due
' to the cog's not getting synced by 30 frames. chroma sync, depends on cog sync.
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x          ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000      ' set frequency to 10 MHZ plus some error    
  _stack   = 1024                   ' stack

  obj_n         = 32 '40            ' Number of Objects
  obj_size      = 5                 ' registers per object.
  obj_total_size = obj_n*obj_size   ' Total Number of registers (LONGS)
  OBJ_OFFSET_X  = 0
  OBJ_OFFSET_Y  = 1
  OBJ_OFFSET_W  = 2
  OBJ_OFFSET_H  = 3
  OBJ_OFFSET_I  = 4
  
'///////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

VAR

long  cop_status
long  cop_control
long  cop_debug
long  cop_phase0
long  cop_monitor0
long  cop_monitor1
long  cop_config
long  cop_vram
long  cop_tile
long  cop_panx
long  cop_pany
long  cop_bgcolor
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
long t0
long frame_load

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

OBJ
  cop   : "cop_drv_010.spin"         ' instantiate a cop object
  key   : "keyboard_iso_010.spin"    ' instantiate a keyboard object
  mouse : "mouse_iso_010.spin"       ' instantiate a mouse object  
  tiles : "cp_cop_tiles_002.spin"    ' data object. (128x128 block of random sprites)
  map   : "cp_cop_map_001.spin"      ' data object. (16x32 tile map)
  
'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB Start | x, y, i, frame, x1, x2
' this is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

  ' setup cop engine params.
  cop.setup(tiles.data,128,128, $f0, map.data)
  ' start cop engine
  cop.start(@cop_status)
  
  'start keyboard on pingroup 3 
  key.start(3)

  'start mouse on pingroup 2 (Hydra mouse port)
  mouse.start(2)

  button_hist[0] := 0
  button_hist[1] := 0
  button_cooldown := 0

  mousex := 256/2
  mousey := 224/2

  frame := 0
'sit in infinite loop.

  x:= 16

  cop_bgcolor+=$00000000

repeat while TRUE

' /////////////////////////////////////////////////////////////////////////////
' /// MAIN LOOP ///////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

  ' Make Debug LED change.
  cop_debug := $80000000 + Sin(frame<<2)<<15

  ' Mouse
  button_hist[0] := (button_hist[0]<<1 | mouse.button(0)&1)
  button_hist[1] := (button_hist[1]<<1 | mouse.button(1)&1)

  mousex := mousex + mouse.delta_x '|> 0 <| 256-16
  mousey := mousey - mouse.delta_y '|> 8 <| 224-24

  cop_pany := mousey

  cop.newframe

  if(button_cooldown)
    button_cooldown--
  else
    if(button_hist[0]&3==%01) ' L-Click-Down (i.e. previously 0 UP, now 1 DOWN)
      button_cooldown := 5
      x-=4                    ' 5 frame cooldown (stops accidental double clicks)
    if(button_hist[1]&3==%01) ' R-Click-Down (i.e. previously 0 UP, now 1 DOWN)
      button_cooldown := 5                              ' 5 frame cooldown (stops accidental double clicks)
      x+=4
      
  cop.sprite(mousex,mousey,64, 64, 0, 0)
    
  repeat i from 0 to 30
    cop.sprite(120 + (120*Sin(i<<3 + (3*frame)))~>16, 104 + (104*Sin(64 + i<<3 + frame))~>16, 16,32, 80,32)
  
  'Int_To_String(frame_load, 16, 16)
  
' sync to 60FPS :-)
  frame_load := cop_status                              ' record scanline at end of frame (measure frame 'load')
  cop.waitvsync  
  
  frame++

' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

PUB Int_To_String(i, x, y) | n

' does an sprintf(str, "%08lX", i); job
repeat n from 7 to 0
  cop.sprite(x+(n<<4), y, 16, 16, 0, (i&15)<<4)
  i>>=4

PUB Sin(x) : y | t
' y = sin(x)
t := x&63
if(x&64)
  t^=63

y := WORD[$E000 | t<<6]

if(x&128)
  y := -y