' //////////////////////////////////////////////////////////////////////
' Ball Buster - breakout clone          
' AUTHOR: JT Cook
' LAST MODIFIED: 3.09.06
' VERSION 0.5
' 
' Use the mouse or gamepad to control the paddle, 10 levels
' Uses COG driver
' Uses Nick's sound driver
' Uses Andre's gamepad driver
' Int_to_String PUB from Colin's Liner demo
' new for 0.5 - fixed a bug where if you spin the mouse to left,player would jump to right,
'               added a short delay after you beat a level and a short tune
' new for 0.4 - adjusted ball physics, added 5 levels, added sound, used Colin's graphics
'               driver and new graphics with it, and added game over text.
' The code may look odd because it was adapted from the parallax drivers with the messed
'    up coord system.
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x          ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000      ' set frequency to 10 MHZ plus some error    
  _stack   = 64                     ' stack
  _memstart = $10                   ' memory starts $10 in!!! (this took 2 headaches to figure out)

                                                                                                                        

  ' sound stuff
  FREQ_INIT = 500
  FREQ_DELTA_INIT = -1
  FREQ_MAX = 800
  FREQ_MIN = 200
  SHAPE_INIT = snd#SHAPE_SINE
  
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
' | Last
long  cop_obj[obj_total_size]       ' 12 sprite positions
long Number_Tiles[10]
' -----------------------------------------------------------------------------


VAR
  'sound variables
  long freq, freq_delta
  long shape
' -----------------------------------------------------------------------------
' Game variables
  long t2, t3 'tile modifier
  'score
  long score
  ' paddle location
  byte player_x, player_y, PaddleYDie
  ' ball location
  byte ball_x, ball_y
  byte ball_bounce
  ' playing field
  byte brick_loop, brick_draw_loop, brick_draw_x,brick_draw_y
  word brick_type
  byte brick_wall[65]
  byte Men  ' players remaining
  byte Game_Sound 'sound effect
'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

OBJ                                                                                                                                                          
  cop   : "cop_drv_010x.spin"      ' instantiate a cop object - Color Co Processor
  snd   : "NS_sound_drv_040.spin"  'Sound driver
  tiles : "bbuster_tiles_001.spin" ' data object. (128x128 block of sprites)
  map   : "bbuster_map_001.spin"   ' data object. (16x14 tile map)
  mouse : "mouse_iso_010.spin"     ' instantiate a mouse object
  logic : "JTC_B_B_Logic_005.spin" 'Game logic
  gamepad: "gamepad_drv_001.spin"  'Gamepad driver
'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB Start | frame, f1, f2, NewPaddleY, NewPaddleX, SoundFall, NewBallY, Text_Status, Text_Timer, New_Button, Mouse_Move
' this is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file
  'start sound driver
  snd.start(7) 'always Pin 7 on Hydra
  freq := FREQ_INIT
  freq_delta := FREQ_DELTA_INIT
  shape := SHAPE_INIT
  
  ' setup cop engine params.
  cop.setup(tiles.data,128,128, $f0, map.data)
  ' start cop engine
  cop.start(@cop_status)
  frame := 0
  f1 := 0
  f2 := 0
  'start mouse on pingroup 2 (Hydra mouse port)
  mouse.start(2)
  ' start logic cog
  logic.start
  ' start gamepad cog
  gamepad.start
  ' feed the addresses of variables to logic cog
  logic.Get_Mem_Address(@player_x,@player_y,@ball_x,@ball_y,@ball_bounce, @score, @brick_wall, @Game_Sound)
  ' set player's initial position
  player_x := 50
  player_y := 0
  ball_x := 50
  ball_y :=16
  ball_bounce:=3
  men:=0
  draw_bricks
  cop_pany :=-8 ' scroll Y tiled background
  cop_debug:= 0
  update_score 'draw score
  repeat while TRUE

    cop.newframe                                                
    'sprites
    cop.sprite(player_x+8,NewPaddleY,32,10,80,0) 'player paddle
    cop.sprite(ball_x+7,NewBallY,8,8,64,0) 'ball graphic
    'game over text
    if(Text_Status==2)
     cop.sprite(48,136,79,7,0,65) 'hit button
    if(Text_Status==3)
     cop.sprite(48,136,79,7,0,73) ' game over
    'input
    gamepad.read 'read input from gamepad
    if(gamepad.button(NES0_LEFT))
      player_x -= 3
    if(gamepad.button(NES0_RIGHT))
      player_x += 3
    player_x += mouse.delta_x 'move player with mouse
    if(player_x>200)  'if you spin the ball too much to the left it will
       player_x:=0    'underflow and jump to the other side. This prevents that.
    'state loop
    if(ball_bounce==6) 'new level
       ball_bounce:=8
       draw_bricks
       update_score
       SoundFall:=60 'delay timer
    if(ball_bounce==8) 'delay before new level
       if(SoundFall==60) 'short tune
          snd.PlaySoundFM(0, snd#SHAPE_SINE, snd#NOTE_G3, 1500)
       if(SoundFall==52)
          snd.PlaySoundFM(0, snd#SHAPE_SINE, snd#NOTE_G3, 1500)
       if(SoundFall==44)
          snd.PlaySoundFM(0, snd#SHAPE_SINE, snd#NOTE_D4, 6000)
       SoundFall-=1
       if(SoundFall<1)
         Logic.Load_Level_
         ball_bounce:=0
         draw_bricks
         ball_y:=20
    if(ball_bounce==0)
     if((mouse.button(0)&1) <> 0) ' mouse button to release ball
      ball_bounce:=1
     if(gamepad.button(NES0_B))
      ball_bounce:=1
     if(gamepad.button(NES0_A))
      ball_bounce:=1
    if(ball_bounce==2)  'if a player hit a brick
      draw_bricks
      update_score
      ball_bounce:=1
    if(ball_bounce==3) ' start screen
      Text_Status:=2
      ball_bounce:=4
      Men:=3
      score:=0
      logic.New_Level_
      draw_bricks
    if(ball_bounce==4)
      if(Text_Status>0)  'if game over, show that screen
      Text_Timer+=1
        if(Text_Timer>60)
           Text_Timer:=0
           if(Text_Status==2)
              Text_Status:=3
           else
              Text_Status:=2
      if((mouse.button(0)&1) <> 0) ' mouse button to start
          New_Button:=1
      if(gamepad.button(NES0_A))
          New_Button:=1
      if(gamepad.button(NES0_B))
          New_Button:=1
      if(New_Button==1)
         Text_Status:=0
         ball_bounce:=0
         New_Button:=0
         update_score
    if(ball_bounce==5)  ' lose a life
        ball_bounce:=7
        PaddleYDie:=NewPaddleY
        SoundFall:=800
        Ball_Y:=30     ' move ball away from paddle
        NewBallY:=239  ' move ball off screen
    if(ball_bounce==7) ' death animation, drop off screen
        PaddleYDie+=2
        NewPaddleY:=PaddleYDie
        SoundFall-=50
        snd.PlaySoundFM(0, snd#SHAPE_SINE, SoundFall, 300) 'Falling sound
        if(PaddleYDie>240)
          if(Men<1)  ' if no more lives, game over
            ball_bounce:=3
          else        'else start ball on paddle
            Men-=1
            ball_bounce:=0
          update_score
    logic.Game_Loop ' Do game logic
    if(ball_bounce <> 7)
         NewPaddleY:= 200-player_y
         NewBallY:= 203-ball_y
    Play_Sound 'Play sound effect in que(if there is one)
    'wait vsync and advance a frame
    cop.waitvsync

' /////////////////////////////////////////////////////////////////////////////
PUB draw_lives   'update how many players are remaining
   t2:=map.data 
   t2+=11<<1
   t2+=9*(32)
   brick_draw_y:=1
   repeat brick_draw_x from 0 to 3
     if(brick_draw_y=<men)
        WORD[t2]:=64      'if there are players remaining, draw balls
        brick_draw_y+=1
     else
        WORD[t2] :=10352 'if not, draw black
     t2+=2
' /////////////////////////////////////////////////////////////////////////////
PUB draw_bricks ' update playfield tiles
   brick_draw_loop:=0
   t3:=6144 'start at bottom set of brick tiles
   repeat brick_draw_y from 3 to 0
      repeat brick_draw_x from 0 to 7 

        if(brick_wall[brick_draw_loop]==1)
           brick_type:=32
        if(brick_wall[brick_draw_loop]==0)
           brick_type:=48

        if(brick_wall[brick_draw_loop+8]==1)          
           if(brick_type==32)
             brick_type:=0
           else
             brick_type:=16             
        'update tilemap         
        t2 :=map.data
        t2 += (brick_draw_x<<1)+2
        t2+=(brick_draw_y<<5)+96
        'brick_type:=0
        WORD[t2] :=brick_type+t3
        brick_draw_loop+=1
      t3-=2048 'next set of bricks
      brick_draw_loop+=8
' /////////////////////////////////////////////////////////////////////////////
PUB Play_Sound
  'snd.PlaySoundFM(channel, shape,freq, time)
  'snd#SHAPE_SINE,snd#SHAPE_SQUARE,snd#SHAPE_TRIANGLE, snd#SHAPE_NOISE
  if(Game_Sound==1)
    'snd.PlaySoundFM(0, snd#SHAPE_TRIANGLE, 200, 300) 'Hit bricks
    snd.PlaySoundFM(0, snd#SHAPE_SINE, 800, 300) 'Hit bricks
    Game_Sound:=0
  if(Game_Sound==2)
    snd.PlaySoundFM(0, snd#SHAPE_SINE, 600, 300) 'Hit walls
    Game_Sound:=0
  if(Game_Sound==3)
    snd.PlaySoundFM(0, snd#SHAPE_SINE, 200, 300) 'Hit paddle
    Game_Sound:=0
' //////////////////////////////////////////////////////////////////
PUB update_score | t, tmap
   draw_lives
   'convert number to string
   Int_To_String(@Str_Score, score)
   'grab tilemap data
   t2:=map.data 
   t2+=10<<1 'x location
   t2+=11*(32) 'y location
   'update tile map with score
   repeat t from 0 to 5
      tmap:=BYTE[@Str_Score+t]<<2
      WORD[t2]:=LONG[@Num_Tiles +tmap] 'map tile
      t2+=2
' //////////////////////////////////////////////////////////////////
PUB Int_To_String(str, i) | t
' does an sprintf(str, "%05d", i); job
str+=4
repeat t from 0 to 4
  BYTE[str] := (i // 10)
  i/=10
  str--                                               
  
' /////////////////////////////////////////////////////////////////////////////      

DAT
Num_Tiles  '0-9 graphic tile locations
        LONG   8272,8288,8304,10240,10256,10272,10288,10304,10320, 10336
Str_Score
        BYTE 0,0,0,0,0,0,0