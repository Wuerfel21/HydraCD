' //////////////////////////////////////////////////////////////////////
' 'HydraIsAlive' Demo :-) Last minute request demo.
' AUTHOR: Colin Phillips
' LAST MODIFIED: 1.15.06
' VERSION 0.1
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x          ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000      ' set frequency to 10 MHZ plus some error    
  _stack   = 64                     ' stack
  _memstart = $10                   ' memory starts $10 in!!! (this took 2 headaches to figure out)
  
' COP HEADER ------------------------------------------------------------------

  obj_n         = 24                ' Number of Objects
  obj_size      = 6                 ' registers per object.
  obj_total_size = obj_n*obj_size   ' Total Number of registers (LONGS)
  OBJ_OFFSET_X  = 0
  OBJ_OFFSET_Y  = 1
  OBJ_OFFSET_W  = 2
  OBJ_OFFSET_H  = 3
  OBJ_OFFSET_I  = 4
  OBJ_OFFSET_M  = 5

  #0, h_cop_status, h_cop_control, h_cop_debug, h_cop_phase0, h_cop_monitor0, h_cop_monitor1, h_cop_config, h_cop_vram, h_cop_tile, h_cop_panx, h_cop_pany, h_cop_bgcolor, h_cop_obj

' -----------------------------------------------------------------------------

' COPSND HEADER ---------------------------------------------------------------

  audio_freq = 11025
  system_rate = 80_000_000/11025                          '7256
  channel_data = $0                                       ' offsetted by data_start
  channel_len = 0                                         ' Status 0 off, N length in samples.
  channel_cnt = 1
  channel_volume = 2
  channel_freq = 3
  channel_phase = 4
  channel_venv = 5
  channel_fenv = 6
  channel_tick = 7                                        ' internal counter
  channel_size = 8
  max_channels = 4
  ' special frequency bit masks
  FRQ_WHITENOISE = $80000000

' -----------------------------------------------------------------------------


  FRAMERATE = 60                ' 60FPS!!!

  
'///////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

' COP HEADER ------------------------------------------------------------------

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

' -----------------------------------------------------------------------------

' COPSND HEADER ---------------------------------------------------------------

VAR

long  copsnd_len                                        ' Status 0 off, N length in samples.
long  copsnd_cnt
long  copsnd_volume
long  copsnd_freq
long  copsnd_phase
long  copsnd_venv
long  copsnd_fenv
long  copsnd_tick                                       ' internal counter

' -----------------------------------------------------------------------------

long bar_color
long amp
long x_ball[16]
long y_ball[16]

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

OBJ
  cop   : "cop_drv_010x.spin"        ' instantiate a cop object - Color Co Processor
  copsnd : "copsnd_drv_001.spin"     ' instantiate a copsnd object - Sound Co Processor                                                                   
  tiles : "CP_HIADEMO_TILES_001.spin" ' data object. (128x128 block of sprites)
  map   : "CP_HIADEMO_MAP_001.spin" ' data object. (16x14 tile map)
  
'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB Start | x, y, t, c, cd, a, b, d, i, j, n, dir, anim, frame, f1, f2, mx,my
' this is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

  copsnd.start(@copsnd_len)

  ' setup cop engine params.
  cop.setup(tiles.data,128,128, $f0, map.data)
  'cop.setup(tiles.data,16,512, $f0, map.data)
  ' start cop engine
  cop.start(@cop_status)    

  'repeat while TRUE
  
  frame := 0
  f1 := 0
  f2 := 0

  ' BARS
  bar_color := $08080808
  UpdateBars(bar_color)
  cop_bgcolor := $00000000
  cop_pany := 4
  amp := 128

  repeat t from 0 to 15
    x_ball[t] := 128
    y_ball[t] := 128

' HitTile(0,8)
  cop_debug:= 0
  
  repeat while TRUE

    cop.newframe

    t := frame
    f1+= 40 + (13*Sin(t))~>16
    f2+= 57 + (12*Sin(t))~>16

    amp := 16
    cop_pany := 4 + (amp*Sin(frame<<2))~>16

    i := (f1>>3)
    j := (f2>>3)
      x := 120 + (120*Sin(i))~>16
      y := 104 + (104*Sin(j))~>16

    t := 15
    x_ball[t] := x    
    y_ball[t] := y

    if((frame&15)==0)
      FadeTile

    cop_debug:= (128-4+cop_pany<<3 #> 0 <# 255)<<24     ' c) Tie to bouncing map.
    
    'cop_debug:= (208-y)<<24                            ' b) Tie to leading ball.
    
    'if(cop_debug<>0)                                   ' a)Tie to hit
    ' cop_debug-=$20000000
    
    b := HitTile((x-8+8)>>4,(y+cop_pany+8)>>4)
    if(b)
      PlayNote(b-1)
    ' cop_debug:= $e0000000                             ' a) Tie to hit
    
    repeat t from 0 to 14
      cop.sprite(x_ball[t],y_ball[t],16,16,48,0)
      x_ball[t] := (x_ball[t]+x_ball[t+1])~>1
      y_ball[t] := (y_ball[t]+y_ball[t+1])~>1

    cop.sprite(x_ball[15],y_ball[15],16,16,48,0)    
    
    t := map.data+CONSTANT(16*2)
    if((frame&1)==0)
      c := 16
    else
      c := 32
    repeat x from 0 to 15
      WORD[t] := c
      t+=2
    t+=CONSTANT(16*2*11)
    repeat x from 0 to 15
      WORD[t] := c
      t+=2

    if(frame&63==0)
      bar_color^=$40404040
      UpdateBars(bar_color)    
      
    
    cop.waitvsync
    frame++


' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

PUB PlayNote(b)

LONG[@g_notelut+channel_freq<<2] := 512 + b<<8

longmove(@copsnd_len, @g_notelut, 8)
      
PUB FadeTile | t,c,x,y

repeat y from 6 to 8

  t := map.data
  t+= y<<5

  repeat x from 0 to 15
    c := WORD[t]
    if((c>>11)>1) ' only lit HYDRA type letters
      c-= CONSTANT((128<<4)*1)                            ' drop down by a line
      WORD[t] := c
    t+=2
    
PUB HitTile(x,y) : b | t, c, d

if(x>15)
  RETURN
if(y>15)
  RETURN
b := 0
t := map.data
t+= y<<5 | x<<1
c := WORD[t]
d := c>>11
if(d>0 and d<4) ' only HYDRA type letters except full lit (1,2,3)
  c&= 127
  c|= CONSTANT((128<<4)*4)
  WORD[t] := c
  b := x+1

PUB Sin(x) : y | t
' y = sin(x)
t := x&63
if(x&64)
  t^=63

y := WORD[$E000 | t<<6]

if(x&128)
  y := -y

PUB UpdateBars(c) | t, cd, x, y
t := tiles.data+16
cd := $01010101
repeat y from 0 to 15      
  LONG[t] := c
  LONG[t+4] := c
  LONG[t+8] := c
  LONG[t+12] := c
  if((y&1)==1)
    if((y&8)==8)
      c-= cd
    else
      c+= cd
  t+=128


t := tiles.data+32
cd := $01010101
repeat y from 0 to 15
    LONG[t] := c
    LONG[t+4] := c
    LONG[t+8] := c
    LONG[t+12] := c
  if((y&1)==0)
    if((y&8)==8)
      c-= cd
    else
      c+= cd
  t+=128


DAT


g_notelut

                        ' Base Note
                        long                    11025 ' LENGTH
                        long                    0       ' CNT
                        long                    32<<8   ' VOL
                        long                    768     ' FREQ
                        long                    0       ' PHASE
                        long                    $248cffc '$36cc963 ' VOL ENV.
                        long                    $0000000 ' FREQ ENV.
                        long                    0       ' TICK