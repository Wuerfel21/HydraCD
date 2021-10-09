'' X-Racer 08-03-06 
'' JT Cook - www.avalondreams.com
'' "Floor it" Song by John Wedgeworth - www.thejcwexperiment.com  
'' Graphic drivers based on Remi's demos, which were then stripped down and rebuilt for
'' my needs. Also uses Nick's sound driver v5.1 and Int_to_String routines from Colin's demo
''
'' Controls - Left and Right steer, B-brake, A-gas, Start-pause, Select-toggle music
''
'' Scoring - You receive 1000 points for every car you pass and you receive points for just
''           driving. So the farther you go, the more points you receive.
''
'' Fifth release - included computer cars in priority check for drawing sprites, car now
''  covers more ground when turning,fix a small bug with track handler, added music created
''  for the game,volume for computer cars is lower the farther away they are from the player,
''  modified how road side objects are randomized, car bounces and make sounds when you drive
''  off road, when you enter a turn it now "scales" down, added acceleration model, fixed
''  some bugs in the sprite rendering routines, improved turn force physics, tweaked graphics,
''  ramped up frequency for car engine to give it higher reving sound, cars slows down more
''  when it hits a computer car so you can't plow through it at higher speeds
'' Forth release - slowed down how quickly a turn appears and disappers, added sound, added
''  quick intro screen, added computer controlled car, better turn force physics, added
''  music(turned off by default because it is a placeholder)
'' Third release - Added background graphic which scrolls horizontally, turns come in and
''  leave smoother, added turning frames for car sprite, added row of text at the top of
''  of the screen using the built in font, turns have force, and the road side sprites
''  are drawn with correct priority.  
'' Second release - horizontal sprite screen clipping, sprite scaling, objects on the side
''  of the road, new original graphics
'' First release has road and sprites working(only one drawn right now). I "borrowed" the
''   car graphic from another racing game.
'' - Notes
'' The main program has a lot of calculations to place sprites and posistion the road. All
''   of this is done in SPIN, so this slows the program down, because of this sometimes
''   sprite data may become messed up for a frame since the sprite data may change between
''   scanlines. The work around I used for this is to buffer the sprite info and at the
''   start of a new frame the data is copied over all at once.
'' There is a bug with the sprites where the right side is clipped too much at times, also
''   clipping the sprites on the right side of the screen is a little buggy
'' Sound stuff
''PlaySoundFM(arg_channel, arg_shape, arg_freq, arg_duration, arg_volume, arg_amp_env) | offset     
''Play sound forever -> CONSTANT(snd#DURATION_INFINITE | (snd#SAMPLE_RATE>>1))
''snd#SHAPE_SINE,snd#SHAPE_SQUARE,snd#SHAPE_TRIANGLE, snd#SHAPE_NOISE
''------------------------------------------------------
'' TODO List
''[ ] Turns come in with too slow?
''[ ] Fix problem with game speeding up/slowing down when no cars on screen

CON

  _clkmode = xtal1 + pll8x  ' ?
  _xinfreq = 10_000_000 + 0_000 ' Set to 10Mhz and add 5000 to fix crystal imperfection of hydra prototype
  _stack = (106) 'the game will break if there is less than 106 longs free
  _memstart = $10                   ' memory starts $10 in!!! (this took 2 headaches to figure out)

  paramcount = 14
  SCANLINE_BUFFER = $7F00
' constants            
request_scanline       = SCANLINE_BUFFER-4
update_ok              = SCANLINE_BUFFER-8
text_adr               = SCANLINE_BUFFER-12
xxx3                   = SCANLINE_BUFFER-16 
xxx4                   = SCANLINE_BUFFER-20 
spin_sprite_y_pxl      = SCANLINE_BUFFER-24 'no longer used
spin_sprite_x_clip     = SCANLINE_BUFFER-28 'pixels to clip off when moving sprite off screen    
spin_roadgfx_adr       = SCANLINE_BUFFER-32 'graphic of road
spin_road_depth_adr    = SCANLINE_BUFFER-36 'road divider/depth buffer
framecount_adr         = SCANLINE_BUFFER-40
spin_roadoffset_adr    = SCANLINE_BUFFER-44 'values for skewing road
spin_roadpal_adr       = SCANLINE_BUFFER-48 'palette for road
'sprie values
spin_sprite_x_adr      = SCANLINE_BUFFER-52 'x position of sprite
spin_sprite_y_adr      = SCANLINE_BUFFER-56 'y position of sprite
spin_sprite_x_len_adr  = SCANLINE_BUFFER-60 'x length of sprite
spin_sprite_y_len_adr  = SCANLINE_BUFFER-64 'y length of sprite
spin_sprite_x_scl_adr  = SCANLINE_BUFFER-68 'horizontal scaled size of sprite
spin_sprite_y_scl_adr  = SCANLINE_BUFFER-72 'verticle scaled size of sprite
spin_sprite_adr        = SCANLINE_BUFFER-76 'address for sprite graphic data 

sprite_buff_off = 5 'offset for sprite calcuation buffer
car_length = 58  'length of car sprite in pixels '56
car_height = 39  'height of car sprite in pixels
sprite_l_64 = 64 'length of sprite in pixels
sprite_h_64 = 64 'height of sprite in pixels
road_scanlines = 80 'how many scanlines the road makes up
course_length = 70   'how long the track is until we get more time
extra_time = 60      'how time is added after player passes checkpoing

engine_vol_m_0 = 75  'volume for car engine when music is on
engine_vol_m_1 = 50  'volume for car engine when music is on

max_car_speed = 10   'max speed car can go

 ' NES bit encodings for NES gamepad 0
  NES0_RIGHT  = %00000000_00000001
  NES0_LEFT   = %00000000_00000010
  NES0_DOWN   = %00000000_00000100
  NES0_UP     = %00000000_00001000
  NES0_START  = %00000000_00010000
  NES0_SELECT = %00000000_00100000
  NES0_B      = %00000000_01000000
  NES0_A      = %00000000_10000000


VAR
  long tv_status      '0/1/2 = off/visible/invisible           read-only
  long tv_enable      '0/? = off/on                            write-only
  long tv_pins        '%ppmmm = pins                           write-only
  long tv_mode        '%ccinp = chroma,interlace,ntsc/pal,swap write-only
  long tv_screen      'pointer to screen (words)               write-only
  long tv_colors      'pointer to colors (longs)               write-only               
  long tv_hc          'horizontal cells                        write-only
  long tv_vc          'vertical cells                          write-only
  long tv_hx          'horizontal cell expansion               write-only
  long tv_vx          'vertical cell expansion                 write-only
  long tv_ho          'horizontal offset                       write-only
  long tv_vo          'vertical offset                         write-only
  long tv_broadcast   'broadcast frequency (Hz)                write-only
  long tv_auralcog    'aural fm cog                            write-only

  long joypad'grab value from controller

' random stuff
  long rand

  ' param for rem_engine:
  long cog_number
  long cog_total  
  long colors[1]

  long RoadLine_X, RoadLine_X_Cntr  'used for skewing road
  word road_x_cntr ' pixel counter
  word road_x_off  ' x offset counter from controller
  word road_offset[road_scanlines<<1] 'road angle that adjusts perspective, add or subtract each road
                                   'scanline to give perspective illusion
  byte road_depth[road_scanlines] 'depth buffer for road
  byte curve_depth ' how far into the turn the road is
  byte curve_direction 'which side road will curve to 0-left, 1-right
  'car speed variables
  byte car_MPH                'how fast it shows the car going
  byte car_MPH_timer          'timer until next speed increase
  byte car_MPH_index          'tells which index we are at for MPH
  byte car_speed              'how fast car is going in the game
 ' byte car_speed          'how fast the car is moving
 ' long car_speed_long     'larger scale for car speed
  byte car_turn        'how far car turns
  'sprite stuff
  long sprite_graphic[12] 'address for sprite
  long sprite_x_scale[12] 'size in pixels of scaled sprite
  long sprite_y_scale[12]
  long sprite_x[12]       'sprite location on screen(this is long because 255 = pixel 0)
  long sprite_x_clip[12]  'pixels to clip off when moving sprite off screen
  byte sprite_y[12]
  byte sprite_x_len[12]   'length of the sprite in pixels
  byte sprite_y_len[12]   'height of sprite in pixels
  byte sprite_x_olen[12]  'actual pixel length of graphic(size before scaling)
  byte sprite_y_olen[12]  'actual pixel height of graphic(size before scaling)
  byte comp_car_speed[8]  ' speed of a sprite object
  'game sprites(for game engine, not rendering engine)
  byte road_prior_side        'tool for alternating objects on the side of the road
  long road_left_sprite_a     'address for graphic for left side of road
  long road_rght_sprite_a     'address for graphic for right side of road
  byte road_left_sprite_s     'size of sprite on left side of road
  byte road_rght_sprite_s     'size of sprite on right side of road
  byte sprite_road_val[12]    'sprite value on the road
  byte sprite_scl_val[12]     'sprite value for which scanline to check in LUT
  byte sprite_road_side[12]   'which side of road sprite is on (0-left, 1-right)
  byte sprite_size[12]        'size of sprite(0-small,1-tall,2-large)
  long track_event_cnt        'event counter for track(larger value)
  long track_event_num        'event counter for track(smaller value for events)  
  long next_track_event       'number for next event on track
  byte turn_cnt               'counter for turns
  byte max_turn               'how deep the turn will go
  byte e_e_turn               'enter exit a turn
                              '0 - do not adjust turn, 1 - enter turn, 2 - exit turn
  word C_Car_Dist[2]          'how far out computer car is
  byte Game_Timer             'shows how much time is remaining
  byte Game_Timer_Tic         'how long until game timer is changed
  byte Pause                  'Pause toggle
  byte Deep_Sprite            'this is the farthest sprite, make sprite lowest priority
  byte crash_value            'for handling when the player crashes
  byte Bounce_Var[3]          'variables for bouncing car when driving on grass
  byte crash_var[3]           'variable for handling crash stuff
  byte Game_State             'game state
  byte Flag_Out[2]            'should we check for the Flag and give more time?
  byte Random_Var[4]          'variables for random track creators
  long PScore                 'Player's score
  'song variables
  byte current_note[2]            'which note is being played
  word time_note[2]               'how much time until next note
  byte music_vol[2]              'volume of channel
  byte m_repeat_num[2]            'how many times a part of a tune is repeating
  long music_adr[2]              'address where song is at
  byte Music_Toggle              'toggle music on or off 
OBJ

  tv    : "rem_tv_014.spin"               ' tv driver 256 pixel scanline
  gfx   : "XRacer_GFX_Engine_010.spin"    ' graphics engine
  snd   : "JTC_NS_snd_drv.spin"           ' Sound driver
PUB start      | i,ii,iii
  DIRA[0] := 1
  outa[0] := 0

  longfill(@colors, $02020202, 1) 'set the border in rightmost two hex digits  
  long[spin_roadgfx_adr] := @road_gfx
  long[spin_roadoffset_adr] := @road_offset
  long[spin_roadpal_adr] := @road_pal
  long[spin_road_depth_adr] := @road_depth
  long[spin_sprite_x_adr]:= @sprite_x  'x position of sprite
  long[spin_sprite_y_adr]:= @sprite_y 'y position of sprite
  long[spin_sprite_x_len_adr]:= @sprite_x_len 'x length of sprite
  long[spin_sprite_y_len_adr]:= @sprite_y_len 'y length of sprite
  long[spin_sprite_x_scl_adr]:= @sprite_x_scale 'horizontal scaled size of sprite
  long[spin_sprite_y_scl_adr]:= @sprite_y_scale 'verticle scaled size of sprite
  long[spin_sprite_adr]:= @sprite_graphic 'address for graphic data for sprite
  long[spin_sprite_x_clip]:= @sprite_x_clip 'pixels to clip off when moving sprite off screen
  ' Boot requested number of rendering cogs:
  ' If you don't provide enough rendering cogs to draw the sprites, you might see missing sprite horizontal lines
  ' and the debug LED will light up to indicate you need more rendering cogs, or less sprite on the same line, or
  ' horizontally smaller sprites.  
  cog_total := 5
  cog_number := 0
  repeat
    gfx.start(@cog_number)
    repeat 10000 ' Allow some time for previous cog to boot up before setting 'cog_number' again
    cog_number++
  until cog_number == cog_total  
 
  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_colors := @colors
  tv.start(@tv_status)
  'start sound driver
  snd.start(7)

  'background graphic
  sprite_graphic[0]:= @racer_bg000

  ' Load precalc'd depth buffer  
  repeat i from 0 to CONSTANT(road_scanlines-1)     
     road_depth[i]:=byte[@Depth_PreCalc+i]   

  curve_depth:=CONSTANT(road_scanlines-1) ' how far into the turn the road is
  road_x_off:=255 'start with road centered

'debug
{
  'setup player sprite
  sprite_graphic[1]:=CONSTANT(@racer_bg000 + (64*128)+32+16) 
  sprite_x[1]:=constant(255+ 100)
  sprite_y[1]:=50
  sprite_x_olen[1]:=32
  sprite_y_olen[1]:=32
  sprite_x_len[1]:=32
  sprite_y_len[1]:=32
  Calc_Sprite(1)
  long[text_adr]:= @HUD_Text
}

  ' Start of main loop here
  repeat
    repeat while tv_status == 1
    repeat while tv_status == 2
'{   
    if(Game_State==0) 'game over, reset all the values
      'stop engine sounds
      repeat i from 0 to 3 
        snd.StopSound(i)
      Display_Score(PScore)  'registers player score      
      Game_Timer:=1          'clear timer for toggle between
      Game_Timer_Tic:=1      '  start text and last score
      car_speed:=0
      Game_State:=1   'now that everything is reset, just hang until someone hits start
      Calc_Skew(road_x_off) ' calc road angle perspective 'run through everything once
      Grab_Buffer_Spr 'move buffered info from track
      repeat i from 1 to 7
        sprite_y[i]:=200 'move all sprites off screen
      'zooming title graphic logo sprite
      sprite_graphic[1]:=CONSTANT(@racer_bg000 + (64*160 +4)+16)'+16 needs to be added when
                                                                'address is included in CONSTANT
      sprite_x_olen[1]:=CONSTANT(64-8)
      sprite_y_olen[1]:=7
      ii:=0
      iii:=0 'direction of zoomer     
    if(Game_State==1)'wait until someone hits start
      'intro graphic that zooms in and out
      if(iii==0)
       ii+=1
       if(ii>30)
        iii:=1
      else
       ii-=1
       if(ii<5)
        iii:=0
      i:=31-ii
      'place, size intro graphic
      sprite_y[1]:= (byte[@road_gfx +(i*7+2)] >> 1) + 60
      sprite_x[1]:= byte[@road_gfx +(ii*7)] +240
      sprite_y_len[1]:= byte[@road_gfx +(ii*7+2)]
      sprite_x_len[1]:=sprite_y_len[1]<<1 + byte[@road_gfx +(ii*7+3)]
      Calc_Sprite(1)
     'switch between press start and score
      Game_Timer-=1
      if(Game_Timer<1)
        Game_Timer:=CONSTANT(60*2)    'time for switching between score and press start
        if(Game_Timer_Tic==0)
           Game_Timer_Tic:=1  'toggle press start
           long[text_adr]:= @Start_Text 'start text
        else
           Game_Timer_Tic:=0
           long[text_adr]:= @Score_Text 'last score
     'seed randomizer
      rand+=1
     'if player hits start, start a new game
      joypad := NES_Read_Gamepad
      if((joypad & NES0_START) <> 0) 'wait until player lets go of pause
       repeat while ((joypad & NES0_START) <> 0)
              joypad := NES_Read_Gamepad
       NewGame     
       Game_State:=5                                   
    if(Game_State==2) 
      Main_Loop     
    if(Game_State>2)
      Start_Race
'}
{   'Debug
    'input
   ' Read both gamepad
    'repeat i from 0 to 10_000
    ' i:=i
    joypad := NES_Read_Gamepad
    if((joypad & NES0_RIGHT) <> 0)
      sprite_x[1]+=1
     Calc_Sprite(1)
        
    if((joypad & NES0_LEFT) <> 0)
      sprite_x[1]-=1
      Calc_Sprite(1)
                             
    if((joypad & NES0_DOWN) <> 0)
       sprite_y[1] += 1

    if((joypad & NES0_UP) <> 0)
      sprite_y[1] -= 1       

    if((joypad & NES0_B) <> 0)
     sprite_x_len[1]-= 1
     sprite_y_len[1]-= 1
      Calc_Sprite(1)     

    if((joypad & NES0_A) <> 0)
     sprite_x_len[1]+= 1
     sprite_y_len[1]+= 1
      Calc_Sprite(1)
    Display_Speed(sprite_y[1])
}      
'end of main
PUB NewGame |  k, kk

' Reset everything for a new game

  'reset music properties
  time_note[0]:=10   'this always needs to start at 10
  current_note[0]:=0
  music_vol[0]:=255
  m_repeat_num[0]:=0  
  music_adr[0]:=@Music

  time_note[1]:=10  'this always needs to start at 10
  current_note[1]:=0
  music_vol[1]:=255
  m_repeat_num[1]:=0
  music_adr[1]:=@Music2
  'setup speed
  car_MPH:=0
  Calc_Speed
  Music_Toggle:=1 'toggle music on  
  'text for HUD
  long[text_adr]:= @HUD_Text
  PScore:=0  'reset player score
  'setup in game timer
  Game_Timer:=99
  Game_Timer_Tic:=30
  Display_Clock(Game_Timer)
  sprite_x[0]:=0 'background graphic offset
  curve_depth:=CONSTANT(road_scanlines-1) ' how far into the turn the road is
  e_e_turn:=0 '0-don't change, 1-enter turn, 2-exit turn
  next_track_event:= 0 'travel until next track event
  track_event_cnt:= 0 'current distance traveled
  crash_value:=0  'make sure car doesn't start in a crash
  'roadside sprites setup
  sprite_road_val[2]:= 30
  sprite_road_val[3]:=73
  sprite_road_val[4]:=114
  sprite_road_val[5]:=158

  'setup player sprite
  sprite_graphic[1]:=@racer_car000 
  sprite_x[1]:=CONSTANT(255 + 128 - (car_length /2)+1)
  sprite_y[1]:=CONSTANT(141 -4)
  sprite_x_olen[1]:=64
  sprite_y_olen[1]:=49
  sprite_x_len[1]:=64
  sprite_y_len[1]:=49
  Calc_Sprite(1)
  Random_Var[0]:=0 'reset random track value
  Random_Var[3]:=0 'reset how far we have driven on track 
  road_x_off:=255 'start with road centered

   'setup default values for sprites
  repeat kk from 2 to 6
   sprite_graphic[kk]:=0 'fill default with nothing
   sprite_x_olen[kk]:=32
   sprite_y_olen[kk]:=32
   sprite_x_olen[kk+sprite_buff_off]:=sprite_x_olen[kk]  'for temp buffer
   sprite_y_olen[kk+sprite_buff_off]:=sprite_y_olen[kk]  'for temp buffer
   sprite_road_val[kk+sprite_buff_off]:=sprite_road_val[kk] 'for temp buffer
   sprite_road_side[kk+sprite_buff_off]:= sprite_road_side[kk] 'for temp buffer
   sprite_graphic[kk+sprite_buff_off]:=sprite_graphic[kk] 'for temp buffer
   sprite_x[kk+sprite_buff_off]:=50   'place sprite off screen
   sprite_y[kk+sprite_buff_off]:=200   'place all sprites off screen
   comp_car_speed[kk]:=0 'stationary object
   sprite_size[kk]:=0 'set size of sprite
  'computer controlled car variables
  New_Comp_Car(CONSTANT(6+sprite_buff_off))
                                                                             
  'find farthest sprite  
  Deep_Sprite:=2
  Display_Speed(0) 'update MPH
  Calc_Skew(road_x_off) ' calc road angle perspective 'run through everything once
  Grab_Buffer_Spr 'update road values from buffer 
   
 'engine sound
  snd.PlaySoundFM(0, snd#SHAPE_NOISE, 300,CONSTANT(snd#DURATION_INFINITE),engine_vol_m_0 , $FFFF_FFFF)
  snd.PlaySoundFM(1, snd#SHAPE_TRIANGLE, 300,CONSTANT(snd#DURATION_INFINITE),engine_vol_m_1 , $2457_9DEF)
  'computer car engine sound
  snd.PlaySoundFM(2, snd#SHAPE_TRIANGLE, 1,CONSTANT(snd#DURATION_INFINITE),180, $FFFF_FFFF)
  snd.PlaySoundFM(3, snd#SHAPE_NOISE, 1,CONSTANT(snd#DURATION_INFINITE),100, $FFFF_FFFF)
'---------------------------------------------
PUB Main_Loop  | n
    'input
   ' Read both gamepad
    joypad := NES_Read_Gamepad
    if((joypad & NES0_START) <> 0)
       repeat while ((joypad & NES0_START) <> 0)
        joypad := NES_Read_Gamepad
       'Toggle Pause
       if(Pause==0)
         Pause:=1
         'turn off engine sounds
         repeat n from 0 to 3 
           snd.SetFreq(n, 1)
       else
         Pause:=0  
    if((joypad & NES0_SELECT) <> 0)
       repeat while ((joypad & NES0_SELECT) <> 0)
        joypad := NES_Read_Gamepad
       'Toggle Music
       if(Music_Toggle==0)
         Music_Toggle:=1
         snd.SetVolume(0, engine_vol_m_0)  'lower volume if there is music for engine
         snd.SetVolume(1, engine_vol_m_1)         
       else
         Music_Toggle:=0
         snd.SetVolume(0, 100) 'raise volume if there is no music for engine
         snd.SetVolume(1, 50)          
    if(Pause<1) 'check if game is paused or not   
     if(crash_value==0) 'car has not crashed
      sprite_graphic[1]:=@racer_car000
      car_turn:=0      
      if((joypad & NES0_RIGHT) <> 0)
       sprite_graphic[1]:=CONSTANT(@racer_car000 + (64*100) + 16)
       car_turn:=car_speed <<1
       road_x_off += car_turn
      if((joypad & NES0_LEFT) <> 0)
       sprite_graphic[1]:=CONSTANT(@racer_car000 + (64*50) + 16)
       car_turn:=car_speed <<1
       road_x_off -= car_turn

      if((joypad & NES0_B) <> 0) 'Brake
       if(car_MPH>3)
        car_MPH-=3
       else
        car_MPH:=0
       Calc_Speed
     if((joypad & NES0_A) <> 0) 'Gas
       if(car_MPH<120)
        car_MPH_index+=1
        if(car_MPH_index>car_MPH_timer)
         car_MPH_index-=car_MPH_timer
         car_MPH+=3
         if(car_MPH>120)
          car_MPH:=120
         Calc_Speed
     if(crash_value==1)
      Handle_Crash 'car has crashed into roadside obj, handle the event for it    
     if(crash_value==2)
      Do_Car_Car_Hit 'car crashed into another car
    ' handle track events         
     Run_Track            
    'set limits on track
     road_x_off<#=435
     road_x_off#>=75
    'when car drives off road, bounce it a bit
     if(road_x_off<156)
      Bounce_Var[1]:=1
     elseif(road_x_off>350)
      Bounce_Var[1]:=1
     else
      Bounce_Var[1]:=0
      Bounce_Var[0]:=0   'if we are on road, lower car
     if(Bounce_Var[1]==1)
      if(Car_Speed>0)
       if(Bounce_Var[0]==0) 'if car is down
         Bounce_Var[0]:=1    '"push" it up
         snd.PlaySoundFM(5, snd#SHAPE_NOISE, 700, 500,255, $2457_9DEF) 'grass sound
       else                 'else
         Bounce_Var[0]:=0    'put car down

     'set height of car
     if(Bounce_Var[0]==0)
        sprite_y[1]:=CONSTANT(141 -4)
     else
        sprite_y[1]:=CONSTANT(141 -5)
            
     Grab_Buffer_Spr       'copy sprite and road offset values from previous frame
                           ' and copy to this frame(so it doesn't update info the middle
                           ' of the screen and have a sprite cut in half with new data
     Calc_Skew(road_x_off) ' calc road angle perspective
     Calc_Road_Sprites(2)  ' calc sprite movement with the road
     Calc_Road_Sprites(3)  ' calc sprite movement with the road
     Calc_Road_Sprites(4)  ' calc sprite movement with the road
     Calc_Road_Sprites(5)  ' calc sprite movement with the road
     Calc_Road_Sprites(6)  ' calc sprite movement with the road(computer car)
     PScore+=Car_Speed     'add scrore for just driving
     if(crash_value<>1)    'car has not crashed
      Check_Car_Hit        'do colision detection
     Display_Speed(car_MPH) 'show how fast car is going
     Run_Game_Clock  'handle timer in game
     'engine sound
     if(C_Car_Dist[0]>240) 'if car is on screen
      snd.SetFreq(2, (C_Car_Dist[0]>>1)+50)
      snd.SetFreq(3, (C_Car_Dist[0]>>1))
      snd.SetVolume(2, C_Car_Dist[0]-150)
      snd.SetVolume(3, C_Car_Dist[0]-230)            
     else  'turn off computer car sound
      snd.SetFreq(2, 1)
      snd.SetFreq(3, 1)
     'engine sound for player car        
     snd.SetFreq(0, (car_speed*120)+300)
     snd.SetFreq(1, (car_speed*40))    
     if(Music_Toggle)
        PlaySong(0) 'music
        PlaySong(1) 'music        
              
PUB Start_Race
'timer before race starts
 Game_Timer_Tic+=1
 if(Game_Timer_Tic>60)
  Game_Timer_Tic:=0
  Game_State-=1
  if(Game_State==4)
   snd.PlaySoundFM(4, snd#SHAPE_SQUARE, 300, 4000,255, $FFFF_FFFF) 
  if(Game_State==3)
   snd.PlaySoundFM(4, snd#SHAPE_SQUARE, 300, 4000,255, $FFFF_FFFF)
  if(Game_State==2)
   snd.PlaySoundFM(4, snd#SHAPE_SQUARE, 500, 8000,255, $FFFF_FFFF)
PUB Handle_Crash | n, nn
'handle the player car crashing into a road side object
 'first come to a complete stop
' car_MPH_timer:=0
 car_MPH:=0
 Calc_Speed
 'move car to the center of the road
 if(road_x_off>260)
    road_x_off-=5
    sprite_x[1]+=5
 elseif(road_x_off<250)
    road_x_off+=5
    sprite_x[1]-=5
    Calc_Sprite(1)
 else    'car is back in the center of the road, resume driving
    crash_value:=0
    sprite_x[1]:= CONSTANT(255 + 128 - (car_length /2)+1) 
PUB Do_Car_Car_Hit
' action for player hitting a car
  snd.PlaySoundFM(4, snd#SHAPE_SINE, 800, 500,200, $2457_9DEF) 'skidding 
  if(crash_var[1]==0) 'swing left
   road_x_off-=crash_var[2]
  else 'swing right
   road_x_off+=crash_var[2]
  crash_var[0]-=1
  if(crash_var[0]<1)
   crash_value:=0
PUB Check_Car_Hit | n, nn, _sprite_y, _sprite_x_l, _sprite_x_r
'Check the colision detection between player car and other objects
 nn:=Deep_Sprite +sprite_buff_off'grab the farthest sprite
 nn-=1           'get the closest sprite
 if(nn<CONSTANT(2+sprite_buff_off)) 'make sure we don't go out of bounderies
  nn+=4

  'check the checkpoint flag
 if(Flag_Out[0]==nn) 'is this the flag?
   if(sprite_y[1]+20 =< sprite_y[nn]+sprite_y_len[nn])
      Flag_Out[0]:=0   'reset flag flag
      Flag_Out[1]:=0
      snd.PlaySoundFM(5, snd#SHAPE_SQUARE, 500, 10000,255, $2457_9DEF) 'extra time
      Game_Timer+=extra_time 'add time for passing checkpoint
      Game_Timer_Tic:=30 'reset small timer so timer is added right away    
 'find where the sprite is drawn at on the screen
 repeat n from 1 to 2
  if(n==2)'check computer car
    nn:=CONSTANT(6+sprite_buff_off) 
  _sprite_y:=sprite_y[nn]
  _sprite_y+=sprite_y_len[nn]
  _sprite_x_l:=sprite_x[nn]
  _sprite_x_r:=_sprite_x_l + sprite_x_len[nn]


   'compare the player sprite and object sprite to see if they hit
  if(sprite_y[1]+30 < _sprite_y)
    if(sprite_y[1]+sprite_y_len[1] > _sprite_y)
     if(sprite_x[1]+10 < _sprite_x_r)
      if(sprite_x[1]+sprite_x_len[1]-10 > _sprite_x_l)
       snd.PlaySoundFM(5, snd#SHAPE_NOISE, 500, 3000,255, $2457_9DEF) 'hit an object
       if(n==2)
        crash_var[0]:=constant(6*2) 'countdown for slide
        if(crash_value<>2)'if we hit a car already, don't change speed 
         crash_var[2]:=car_speed 'how fast we will swing to the side
         'slow down car to speed slower than what car was hit was going
         car_MPH:=(comp_car_speed[6] * 110) /14  
         Calc_Speed         
        'find which side of the car we hit we are on
        if(sprite_x[1] > _sprite_x_l)
         crash_var[1]:=1 'swing to the right
         sprite_graphic[1]:=CONSTANT(@racer_car000 + (64*50) + 16)
        else
         crash_var[1]:=0'swing to the left
         sprite_graphic[1]:=CONSTANT(@racer_car000 + (64*100) + 16)
       crash_value:=n 'handle the car crashing
PUB Grab_Buffer_Spr | n,nn,n2, temp_car_y
' All the sprite values are held in a buffer while they are calculated, then for the next
' frame they moved all at once to reduce visual artifacts in sprites. This also handles
' priority so the farthest sprites will be rendered first and drawn over by the closest
' sprites
  n:=Deep_Sprite + sprite_buff_off 'grab the farthest sprite
  temp_car_y:=sprite_road_val[CONSTANT(6+sprite_buff_off)]
  repeat nn from 6 to 2  'work backwards since the last sprite is drawn first
   if(temp_car_y<sprite_road_val[n])   
    n2:=CONSTANT(6+sprite_buff_off)
    sprite_graphic[nn]:=sprite_graphic[n2]
    sprite_x[nn]:=sprite_x[n2] 
    sprite_y[nn]:=sprite_y[n2]
    sprite_x_len[nn]:=sprite_x_len[n2]
    sprite_y_len[nn]:=sprite_y_len[n2]
    sprite_x_scale[nn] := sprite_x_scale[n2]
    sprite_y_scale[nn] := sprite_y_scale[n2]
    sprite_x_clip[nn] := sprite_x_clip[n2]
    temp_car_y:=255 'reset this var
   else
    if(nn==3)     'this check is to see if we have hit all the road side objects without
     if(temp_car_y<255) 'yet including the computer controlled car
      temp_car_y:=0 'if we haven't shown computer car sprite, show it
    sprite_graphic[nn]:=sprite_graphic[n]
    sprite_x[nn]:=sprite_x[n] 
    sprite_y[nn]:=sprite_y[n]
    sprite_x_len[nn]:=sprite_x_len[n]
    sprite_y_len[nn]:=sprite_y_len[n]
    sprite_x_scale[nn] := sprite_x_scale[n]
    sprite_y_scale[nn] := sprite_y_scale[n]
    sprite_x_clip[nn] := sprite_x_clip[n]
    n+=1                  'advance to next nearest sprite
    if(n>CONSTANT(5+sprite_buff_off))
     n-=4    

  'grab buffer for road
  repeat nn from 0 to CONSTANT(road_scanlines-1 -8) '-8 because those scanlines aren't on screen
   road_offset[nn]:=road_offset[nn+road_scanlines]  'road perspective
PUB Random_Track | Road_Obj, track_len 
'Random track creator
'road side sprites  (built out of 2 hex digits, one for left side, one for right side)
'objects 0-nothing, 1-tree, 2-sign, 3-cart
  'handle roadside objects
  Road_Obj:=0
  repeat while Road_Obj<1  'make sure road is always populated
   'road side sprites are grabbed by a weighted list of trees and signs more common than
   'cart and nothing
   Road_Obj:=BYTE[@Road_Obj_Spr+ (?rand & $07)]   'grab left road side object   
   Road_Obj<<=4           'shift object
   Road_Obj+=BYTE[@Road_Obj_Spr+ (?rand & $07)]   'grab right road side object
   Random_Var[2]:=Road_Obj
'0-no change shortest,1-short, 2-medium, 3-long
'4-enter small left turn, 6-enter full left turn
'5-enter small right turn, 7-enter full right turn
'8-exit turn, 99-end of track, reset
  'handle track events  
  if(Random_Var[0]==0) 'if we are not in a turn
   'did we pass the check point?  
   if(Random_Var[3]>course_length) 'length around track
     Random_Var[3]-=CONSTANT(course_length-1) 'reset track
     Random_Var[1]:=99 'bring out the checkard flags
     track_len:=2 'length of track
   'grab track event
   else
    Random_Var[1]:=(?rand & $07)
    track_len:=Random_Var[1]+1 'grab value of track traveled
    if(Random_Var[1]>3) 'we are entering a turn
     Random_Var[0]:=1  'set it to turn
     track_len:=2 'grab value of track traveled      
  elseif(Random_Var[0]==1) 'entered a turn
   Random_Var[0]:=2 'move to next stage
   Road_Obj:=(?rand & $02) 'grab length of turn(0-2, 3 is too long)
   if(Random_Var[1]>5) 'if we are in a full turn, cover more track since we have to slow down
    track_len:=((Road_Obj+1)<<1)  
   else
    track_len:=Road_Obj+1
   Random_Var[1]:=Road_Obj         
  else
   Random_Var[0]:=0 'move out of turn
   Random_Var[1]:=8 'exit turn
   track_len:=2 'grab value of track traveled
  Random_Var[3]+=track_len 'add to track counter                 
PUB Run_Track | sel_event  ,n, nn,n2,n3, temp_obj_1, temp_obj_2, temp_obj
'0-straight, 1-enter left turn, 2-exit left turn, 3-enter right turn, 4-exit right turn, 99-reset
    track_event_cnt+=car_speed  'advance on track
    repeat while track_event_cnt>CONSTANT(max_car_speed-1)
      track_event_cnt-=max_car_speed 'reset large counter
      track_event_num+=1  'advance small counter
      if(track_event_num > next_track_event) 'advance to next track event
       track_event_num:=1 'reset event counter for next event
       Random_Track  'randomize next track value             
       sel_event:=Random_Var[1] 'grab next track value
       'reset track to start
       if(sel_event==99) 
         next_track_event:=30
         temp_obj:=$44 'set the road side objects for checkpoint flags
         Flag_Out[1]:=1
       'no change
       if(sel_event==0) 
         next_track_event:=30
       if(sel_event==1) 
         next_track_event:=60
       if(sel_event==2) 
         next_track_event:=120
       if(sel_event==3) 
         next_track_event:=240                          
       'enter left hand turn small
       if(sel_event==4) 
         sprite_road_val[0]:=0 'reset location on road
         e_e_turn:=1 '0-don't change, 1-enter turn, 2-exit turn
         curve_direction:=0 'which side road will curve to 0-left, 1-right
         next_track_event:=5000
         sprite_x_clip[0]:=40 'small turn
       'enter right hand turn small
       if(sel_event==5) 
         sprite_road_val[0]:=0 'reset location on road
         e_e_turn:=1 '0-don't change, 1-enter turn, 2-exit turn
         curve_direction:=1 'which side road will curve to 0-left, 1-right
         sprite_x_clip[0]:=40 'small turn
         next_track_event:=5000
       'enter left hand turn full
       if(sel_event==6) 
         sprite_road_val[0]:=0 'reset location on road
         e_e_turn:=1 '0-don't change, 1-enter turn, 2-exit turn
         curve_direction:=0 'which side road will curve to 0-left, 1-right
         sprite_x_clip[0]:=2 'full turn
         next_track_event:=5000
       'enter right hand turn full
       if(sel_event==7) 
         sprite_road_val[0]:=0 'reset location on road
         e_e_turn:=1 '0-don't change, 1-enter turn, 2-exit turn
         curve_direction:=1 'which side road will curve to 0-left, 1-right
         sprite_x_clip[0]:=2 'full turn
         next_track_event:=5000         
       'exit  turn
       if(sel_event==8) 
         e_e_turn:=2 '0-don't change, 1-enter turn, 2-exit turn
         sprite_road_val[0]:=0 'reset location on road
         next_track_event:=5000

       'find which road side sprites should be on the road
       if(sel_event<>99)
         temp_obj:=Random_Var[2] 'grab randomly generated road side objects     
       'road side objects 0-nothing, 1-tree, 2-sign, 3-cart
       temp_obj_1:=temp_obj
       temp_obj_2:=temp_obj
       temp_obj_1 >>= 4 'grab left side object
       temp_obj_2 &= $0F 'mask off left side object
       repeat n2 from 0 to 1
         if(temp_obj_1==0)
           nn:=0 'nothing
         if(temp_obj_1==1) 'tree
           nn:=CONSTANT(@racer_bg000 + (64*64) +32 + 16)
           n3:= 1 'size
         if(temp_obj_1==2) 'sign
           nn:=CONSTANT(@racer_bg000 + (64*64) + 16)
           n3:=1 'size
         if(temp_obj_1==3) 'cart
           nn:=CONSTANT(@racer_bg000 + (64*96)+32 + 16)
           n3:=0 'size
         if(temp_obj_1==4) 'flag
           nn:=CONSTANT(@racer_bg000 + (64*96) + 16)
           n3:=1 'size           
         if(n2==0)
          road_left_sprite_a:=nn
          road_left_sprite_s:=n3
          temp_obj_1:=temp_obj_2
         else
          road_rght_sprite_a:=nn
          road_rght_sprite_s:=n3 

    'handle turn force
    ' (max speed = 10)*(max turn = 80)= max turn force is 800
    ' (max speed w/o skidding = 5.5) * (max turn = 80) = turn force w/o losing ground is 440
    if(curve_depth<78) 'make sure we are in a turn
     nn:=road_scanlines-curve_depth 'grab degree of turn

             ' turn * speed / speed of turn    '( 80*6 ) = 480
             '                                 turn*speed*turn speed /480
     nn*=car_speed * car_speed<<1
     nn/=480
     if(car_turn>0)  'if we lose ground in turn
      if(nn>car_turn) 
        snd.PlaySoundFM(4, snd#SHAPE_SINE, 800, 500,200, $2457_9DEF) 'skidding
     if(curve_direction==0) 'left hand turn
        road_x_off+=nn   'force of push depending on depth of turn
     else                   'right hand turn
        road_x_off-=nn   'force of push depending on depth of turn

                  
    'scroll background to turns
    nn:=road_scanlines-curve_depth  'find how deep curve is
    nn/=20              'divide it by 20 to make it into one of 4 values
    nn*=car_speed       'multiply by speed of car
    if(curve_direction==1) 'right hand turn
     sprite_x[0]+=nn >>2
     if(sprite_x[0]>63)
      sprite_x[0]-=64
    else                  'left hand turn
     sprite_x[0]-=nn >>2 
     if(sprite_x[0]<0)
      sprite_x[0]+=64      

    'handle entering/exitint turns
    'Calc_EE_Turn writes to sprite_y_len[0]
    'sprite_x_clip[0] tells how far the turn is to go  
    if(e_e_turn==1) 'enter turn
         Calc_EE_Turn
          curve_depth:=(64- sprite_y_len[0]) +15
         'curve_depth:=sprite_y_len[0] 
         'if(curve_depth<2)
         if(curve_depth<sprite_x_clip[0]) 'grab how far turn will go and check it
          e_e_turn:=0 'completely in turn
          next_track_event:=0 'move to next event
    elseif(e_e_turn==2) 'exit turn
         Calc_EE_Turn
         curve_depth:= sprite_y_len[0] + sprite_x_clip[0]
         if(curve_depth>78)                  
          e_e_turn:=0 'completely out of turn
          next_track_event:=0 'move to next event

PUB Calc_EE_Turn | kk, temps1, temp_scan_l, temp_road_val      
   'caclulating enter/exit turn

   sprite_x_len[0]+=car_speed 'advance track
   repeat while sprite_x_len[0]>1
    sprite_x_len[0]-=2       'reset track counter
    sprite_road_val[0]+=1    'scroll down turn
   'find the scanline to place the turn on
   temp_scan_l:=Grab_S_Line(sprite_road_val[0])
   'find value of turn
   sprite_y_len[0]:= temp_scan_l    
'---------------------------------------------           
PUB New_Comp_Car(sp_number) | kk, temps1,temps2, temp_scan_l, temp_road_val
'we are going to give the computer car new random values
     C_Car_Dist[0]:=(?rand & $64)+100 'how far off in distance car is
     sprite_road_side[sp_number]:=((?rand & $07)>>2) +2 'randomly choose a lane
     kk:=((?rand & $07)>>2) 'randomly choose a car graphic
     if(kk==0)
       sprite_graphic[sp_number]:=CONSTANT(@racer_bg000 + (64*128)+16)
     else
       sprite_graphic[sp_number]:=CONSTANT(@racer_bg000 + (64*128)+32+16)
     comp_car_speed[sp_number-sprite_buff_off]:=((?rand & $08)>>1) +3 'randomly choose speed

PUB Calc_Road_Sprites(sp_number) | kk, temps1,temps2, temp_scan_l, temp_road_val
'runs calculations for all of the sprites(excluding player car) like size of sprite,
'location on road and also calculates movement of sprites(ie road objects come forward the
'more the player drives down the road, drives the computer cars)
   sp_number+=sprite_buff_off 'place all sprite info a temp buffer
   'computer controlled car
   if(sp_number> CONSTANT(5+sprite_buff_off))   
     C_Car_Dist[0]+=car_speed
     C_Car_Dist[0]-=comp_car_speed[sp_number-sprite_buff_off]
     if(C_Car_Dist[0]<15) 'is car off in distance?
        New_Comp_Car(sp_number)'grab new car values
     if(C_Car_Dist[0]>CONSTANT(205+200))'did we pass the car?
        PScore+=1000           'add score for passing car
        New_Comp_Car(sp_number)'grab new car values
     temp_road_val:=10 'set default roadvalue for car
     if(C_Car_Dist[0]>200)  'is car in view?
       temp_road_val:=C_Car_Dist[0]-200
   'road side stationary sprites
   else
    temp_road_val:= sprite_road_val[sp_number]  'grab current value 
    temp_road_val+=car_speed   'move object forward with speed
    'if the object drives off into the horizon, move it up closer on the road
    'we need to reset sprite
    if(temp_road_val>200) 'if we drive past object, move back to far end of road
     temp_road_val-=170  '170 instead of 200 because sprites become too small to render
                         'too far out                                                      
    'start it at far end of track
     temp_road_val:= byte[@road_depth_sp] + temp_road_val
     Deep_Sprite:=sp_number-sprite_buff_off 'set this as the farthest sprite
     'make sure we evenly divide road side objects
     if(road_prior_side==0) 'if last newest object was on left side of road
      road_prior_side:=1   'make newest on right side of road
      sprite_graphic[sp_number]:=road_rght_sprite_a  'assign the correct graphic to new object
      sprite_size[sp_number-sprite_buff_off]:=road_rght_sprite_s 'grab size of sprite
     else
      road_prior_side:=0
      sprite_graphic[sp_number]:=road_left_sprite_a 'assign the correct graphic to new object     
      sprite_size[sp_number-sprite_buff_off]:=road_left_sprite_s 'size of sprite
     sprite_road_side[sp_number]:=road_prior_side 'switch road side object
     'if we have the checkpoint flag
     if(Flag_Out[1]==1) 'is the flag out?
      if(Flag_Out[0]==0)'is this the first flag?
        Flag_Out[0]:=sp_number 'set the flag to look for it
   'find the scanline value for object
   temp_scan_l:=Grab_S_Line(temp_road_val)    
   sprite_road_val[sp_number]:=temp_road_val
   'use lookup to match road scanline number to find the horizontal and verticle
   'size to scale the sprite
   sprite_y_len[sp_number]:= byte[@road_gfx +(temp_scan_l*7+2)]  
   sprite_x_len[sp_number]:=sprite_y_len[sp_number]
   if(sprite_size[sp_number-sprite_buff_off]==0) 'if smaller sprite, half the size
    sprite_y_len[sp_number]>>=1
   if(sprite_size[sp_number-sprite_buff_off]<2)'if smaller sprite, half the size
    sprite_x_len[sp_number]>>=1
   'choose side of road to place sprite
   if(sprite_road_side[sp_number]==0) 'left side of road
     sprite_x[sp_number]:= byte[@road_sprite_lut_l +temp_scan_l] - sprite_x_len[sp_number]
   if(sprite_road_side[sp_number]==1) 'right side of road
    sprite_x[sp_number]:= byte[@road_sprite_lut_r +(temp_scan_l)]+100      
   if(sprite_road_side[sp_number]==2) 'left side on road
     sprite_x[sp_number]:= byte[@road_sprite_lut_l +temp_scan_l] + sprite_x_len[sp_number] >>1
     sprite_x[sp_number]+= byte[@road_gfx +(temp_scan_l *7 +1)]
   if(sprite_road_side[sp_number]==3) 'left side on road
     sprite_x[sp_number]:= byte[@road_sprite_lut_r +(temp_scan_l)]+100 - sprite_x_len[sp_number]
     sprite_x[sp_number]-= byte[@road_gfx +(temp_scan_l *7 +1)] + sprite_x_len[sp_number]>>1      
   'skew sprite along with road prespective
   sprite_x[sp_number]+= road_offset[temp_scan_l+road_scanlines] 
   'after finding road scanline, push up sprite so bottom of sprite is on the scanline
   if(sprite_graphic[sp_number]==0) 'if there is no sprite
    sprite_y[sp_number]:=210 'push sprite off screen
   else  'else find the scanline to place the sprite on 
    sprite_y[sp_number]:=temp_scan_l + 120 - sprite_y_len[sp_number]
   Calc_Sprite(sp_number)

PUB Grab_S_Line (Value) | temps1, temps2, temp_scan_l, kk 
   temps1:=0
   'divide this into forths so we aren't searching the entire list
   if(Value>byte[@road_depth_sp+20])
     temps1:=20
   if(Value>byte[@road_depth_sp+40])
     temps1:=40
   if(Value>byte[@road_depth_sp+60])
     temps1:=60
   temps2:=CONSTANT(road_scanlines-1)     
   repeat kk from temps1 to temps2
     if(Value => byte[@road_depth_sp + kk])
       temp_scan_l:=kk
     else 'if no more matches found, stop looking
       temps2:=temps1
   return temp_scan_l    
PUB Calc_Skew(RoadOff) | k,kk,pp, curve_calc, pixel_indent, curve_adv,p
' Calculate the skewed road angle(road perspective illusion)
' make road heigh 64 pixels so you can bit shift length against it
' road x offset / 64 = how many x pixels to 1 y pixel
'used for line angle on road perspective RoadLine_X is how many X pixels for every
'Y pixel(x100 to get decimal); RoadLine_X_Cntr is the counter to tell how many pixels
'we are currently at(advance another pixel or not?)
  RoadLine_X:=RoadOff 'x offset we are caclulating from
  if(RoadOff>254)
    RoadLine_X:=RoadLine_X - 255
    pixel_indent:=-1  'subtract
  else
    RoadLine_X:=255-RoadLine_X
    pixel_indent:=1 'add

  'the turns are handled in two ways
  ' the first way is entering a turn, this is down by taking the turn and 'scaling' it
  '  down the road to give the appearance of it approaching
  ' the second way is exiting the turn
  '  instead of scaling the road up, the calculated curve is just scrolled up
  if(curve_depth<80) 'check to see if we are even in a turn
   if(e_e_turn==1) 'entering turn
      curve_calc:=sprite_x_clip[0] 'grab depth of turn
   else 'exiting a turn or in a turn
     curve_calc:=curve_depth
   p:=CONSTANT(80<<3)/(80-curve_depth) 'calc multiple that we scale or scroll turn
   curve_adv:= curve_calc<<3 'grab current curve depth
  else
   curve_calc:=80

  road_x_cntr := CONSTANT(255 - 23)'reset pixel counter 255 is the center, 23  - center road
  RoadLine_X_Cntr := 0 'reset counter
  ' multiply by 128 to give percision (128 = 1.00 pixels) 
'  RoadLine_X:=RoadLine_X<<7 '*128
'  RoadLine_X>>=6 ' divide by 64  (we are counting from 64 scanlines)
  RoadLine_X<<=1  'this is the same as *128 then /64 
  'now we have a pixel value to add for every scanline

  ' run through all road scanlines
  repeat kk from 0 to CONSTANT(road_scanlines-1-8)'subtract 8 since those aren't on screen
    road_depth[kk]+=car_speed   'scroll the road
    if(road_depth[kk]>79)
       road_depth[kk]-=80
      
    RoadLine_X_Cntr+=RoadLine_X 'counter for skewing road

    pp:=RoadLine_X_Cntr>>7
    'choose the direction of road
    if(pixel_indent>0)
       road_x_cntr+=pp
    else
       road_x_cntr-=pp
    pp<<=7
    RoadLine_X_Cntr:=RoadLine_X_Cntr-pp

    k:=road_x_cntr 'grab perspective skew
    if(curve_calc<80)
     if(curve_direction) 
       k+=byte[@Curve_PreCalc+curve_calc] 'add in curve for turn(if there is one)
     else
       k-=byte[@Curve_PreCalc+curve_calc]  'add in curve for turn(if there is one)
     curve_adv+=p  
     curve_calc:=curve_adv>>3
    road_offset[kk+road_scanlines]:=k 'add x offset

PUB Calc_Sprite(sprite_numb)
'calc scaled size of sprite
  sprite_x_scale[sprite_numb] := (sprite_x_olen[sprite_numb] <<9) / sprite_x_len[sprite_numb]
  sprite_y_scale[sprite_numb] := (sprite_y_olen[sprite_numb] <<9) / sprite_y_len[sprite_numb]
'check clipping on left side of screen
  if(sprite_x[sprite_numb]<255) 'moves off left of screen, clip sprite
      sprite_x_clip[sprite_numb]:= (255 - sprite_x[sprite_numb]) * sprite_x_scale[sprite_numb]
  else
    sprite_x_clip[sprite_numb]:=0

PUB Display_Clock(i) | t, str
' does an sprintf(str, "%05d", i); job
str:=1
repeat t from 0 to 1
  BYTE [@HUD_Text+5+str] := 48+(i // 10)
  i/=10
  str--
PUB Display_Speed(i) | t, str
' does an sprintf(str, "%05d", i); job
str:=2
repeat t from 0 to 2
  BYTE [@HUD_Text+9+str] := 48+(i // 10)
  i/=10
  str--
PUB Display_Score(i) | t, str
' does an sprintf(str, "%05d", i); job
str:=8
repeat t from 0 to 8
  BYTE [@Score_Text+7+str] := 48+(i // 10)
  i/=10
  str--  
PUB  Run_Game_Clock
  Game_Timer_Tic+=1
  if(Game_Timer_Tic>30)
   Game_Timer_Tic:=0
   if(Game_Timer<7) 'warning beeps for low time
      snd.PlaySoundFM(5, snd#SHAPE_SQUARE, 500, 1000,255, $2457_9DEF) 'low timer beep   
   if(Game_Timer<1)
      snd.PlaySoundFM(5, snd#SHAPE_SQUARE, 100, 10000,255, $2457_9DEF) 'times up
      Game_State:=0 'game over, get out of game loop      
      'Game_Timer:=99 debug
   else   
    Game_Timer-=1
   Display_Clock(Game_Timer)
PUB PlaySong(num) | n, nn, nnn, S_Note, S_Time, S_Note_Time, s_freq,s_length, M_adr
'  current_note[4] 'which note is being played
'  time_note[4] 'how much time until next note
   M_adr:=music_adr[num]    'grab address for where song is located
   time_note[num]-=10        'count down the clock
   if(time_note[num]<10)     'if it is at zero, grab next note
    S_Note:=byte[M_adr+current_note[num]] 'grab note
    if(S_Note==254) 'repeat $notes to step back, times to repeat
     S_Note_Time:=byte[M_adr+(current_note[num]+1)]
     if(m_repeat_num[num]<(S_Note_Time & $0F)) 'find out if we still repeat
       m_repeat_num[num]+=1
       current_note[num]-=(S_Note_Time>>3) 'grab how many notes we drop back
     else
      m_repeat_num[num]:=0    'reset repeating note
      current_note[num]+=2    'move to next note
     S_Note:=byte[M_adr+current_note[num]] 'grab note
    if(S_Note==255) 'if at the end of the song, start song over
     current_note[num]:=0
     S_Note:=byte[M_adr+current_note[num]] 'grab first note         
    'grab second byte for length of note and time until next note 
    S_Note_Time:=byte[M_adr+(current_note[num]+1)]
    'grab time until next note
    n:=S_Note_Time & $0F 'mask off upper 4 bits
    time_note[num]+=WORD[@TN_Notes+(n<<1)]  'grab how long until next note is played
    'find out time of note
    n:=S_Note_Time >> 4 'cut off lower 4 bits    
    s_length:=WORD[@T_Notes+(n<<1)] 'find out how long a note is    
    'load note freq
    s_freq:=word[@M_Notes+(S_Note<<1)]
    'advance to next note
    current_note[num]+=2    
    'if note is not a rest, play note
    if(s_freq>0)
     'notes   $1357_DDEF $2457_9DEF $FFFF_FFFF
     if(num==0)
      snd.PlaySoundFM(6, snd#SHAPE_TRIANGLE, s_freq, s_length,music_vol[num], $1357_DDEF)
      'snd.PlaySoundFM(7, snd#SHAPE_SQUARE, s_freq, s_length,(music_vol[num]>>1), $1357_DDEF)
     else
      s_freq>>=1
      snd.PlaySoundFM(8, snd#SHAPE_TRIANGLE, s_freq, s_length,music_vol[num], $1357_DDEF)
{
PUB Get_Speed
         car_MPH:=BYTE[@C_MPH+car_MPH_index<<1]
         car_MPH_timer+=BYTE[@C_MPH+car_MPH_index<<1+1]
         car_speed:=car_MPH/9
}    
PUB Calc_Speed |  z
  z:=0 'reset variable (this needs to be done due to memory leak)
  
  repeat while car_MPH < byte[@C_MPH +z]  'run through list to find variable
    z+=2
         
  car_MPH_Timer:=byte[@C_MPH +z+1]   'grab timer to tell game when to ramp up speed again
  car_speed:=Car_MPH/11              'grab game speed
         
PUB NES_Read_Gamepad : nes_bits   |       i
  DIRA [3] := 1 ' output
  DIRA [4] := 1 ' output
  DIRA [5] := 0 ' input
  DIRA [6] := 0 ' input

  OUTA [3] := 0 ' JOY_CLK = 0
  OUTA [4] := 0 ' JOY_SH/LDn = 0
  OUTA [4] := 1 ' JOY_SH/LDn = 1
  OUTA [4] := 0 ' JOY_SH/LDn = 0
  nes_bits := 0
  nes_bits := INA[5] | (INA[6] << 8)

  repeat i from 0 to 6
    OUTA [3] := 1 ' JOY_CLK = 1
    OUTA [3] := 0 ' JOY_CLK = 0
    nes_bits := (nes_bits << 1)
    nes_bits := nes_bits | INA[5] | (INA[6] << 8)

  nes_bits := (!nes_bits & $FFFF)

DAT
tvparams                long    0               'status
                        long    1               'enable
                        long    %011_0000       'pins
                        long    %0000           'mode
                        long    0               'screen
                        long    0               'colors
                        long    16              'hc
                        long    12              'vc
                        long    10              'hx
                        long    1               'vx
                        long    0               'ho
                        long    0               'vo
                        long    60_000_000'_xinfreq<<4  'broadcast
                        long    0               'auralcog


' /////////////////////////////////////////////////////////////////////////////
' GLOBAL REGISTERS ////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        org                     $1e0

r0                      long                    $0
r1                      long                    $0
r2                      long                    $0
r3                      long                    $0
r4                      long                    $0
r5                      long                    $0
r6                      long                    $0
r7                      long                    $0

' /////////////////////////////////////////////////////////////////////////////
' LOADER REGISTERS ////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        org                     $1c0                        
__loader_return         res                     7
__loader_call           res                     6
__loader_execute

                        org                     $1e0                            ' general registers 1e0-1ef
__loader_registers
__g0                    res                     1 ' g0..g7 : Global COG Registers
__g1                    res                     1
__g2                    res                     1
__g3                    res                     1
__g4                    res                     1
__g5                    res                     1
__g6                    res                     1
__g7                    res                     1
__t0                    res                     1
__t1                    res                     1
__t2                    res                     1
__loader_ret            res                     1
__loader_stack          res                     1
__loader_page           res                     1
__loader_size           res                     1
__loader_jmp            res                     1

' //////////////////////////////////////////////////////////////////////////
' HUB VARIABLES ////////////////////////////////////////////////////////////
' //////////////////////////////////////////////////////////////////////////

org

'starting with middle C
M_Notes 'music notes
'    0  1   2   3   4   5   6   7 , 8 , 9  , 10,  11, 12
' rest, C , D , E , F , G , A , B , C2, D2 , E2,  F2, G2
word 0,262,294,330,349,392,440,494,523, 587, 659, 698, 784
T_Notes 'length of note 0-whole, 1-half, 2-quarter, 3-eight
word 16_000, 8_000, 4_000,2_000
 TN_Notes ' length of time until next note
'                                            3/4 total timing
'     0    1    2    3    4|  5   6   7  8    9
word 560, 280, 140,  70, 35, 420,210,105,52, 455
'Music format
'1st byte is the note, 255 starts song over, 254 repeats a set defined in next
'   byte divided into two nibbles ($notes to drop back|times that it is repeated)
'2nd byte is broken up into two nibbles ($length of note|time until next note)
Music 'track 1
'3/4 timing
' (9)  D      A      G     A   |(10)D    D     A      C2     D2   |(11)D    A      G     A 
byte 2,$22, 6,$22, 5,$27, 6,$33, 2,$33, 2,$33, 6,$22, 8,$27, 9,$33, 2,$22, 6,$22, 5,$27, 6,$33
'(12)   D       D     A      G     E  |(13)D      A     G      A  |(14) D    D     A      C2     D2 
byte 2,$33, 2,$33, 6,$22, 5,$27, 3,$33, 2,$22, 6,$22, 5,$27, 6,$33, 2,$33, 2,$33, 6,$22, 8,$27, 9,$33
'(15)  D       A      G     A  |(16)D      D     A      G     E  
byte 2,$22, 6,$22, 5,$27, 6,$33, 2,$33, 2,$33, 6,$22, 5,$27, 3,$33
'4/4 timing
'(17)  D       D     D      D      C      D      D     D      D
byte 2,$23, 2,$23, 2,$23, 2,$44, 1,$27, 2,$23, 2,$23, 2,$34, 2,$34
'(18)  D       D     D      D      E      C      C      C  
byte 2,$23, 2,$23, 2,$23, 2,$44, 3,$27, 1,$23, 1,$23, 1,$23
'(19) D      C      D      D      C     D     D       D      D
byte 2,$23, 1,$23, 2,$23, 2,$44, 1,$27, 2,$23, 2,$23, 2,$34, 2,$34
'(20)  D      D      D      D      E     C       C      C
byte 2,$23, 2,$23, 2,$23, 2,$44, 3,$27, 1,$23, 1,$23, 1,$23
'(21) A       G      A      A      G      A      A      A    A
byte 6,$23, 5,$23, 6,$23, 6,$44, 5,$27, 6,$23, 6,$23, 6,$34, 6,$34
'(22)   A    A       A      A      B      G      G      G      G
byte 6,$23, 6,$23, 6,$23, 6,$44, 7,$27, 5,$23, 5,$23, 5,$34, 5,$34
'start over
byte 255

Music2 'track 2
' 3/4   G   |   G     G      r  |  A   |   A     A     r   |  G   |  G      G      r   |   A  |  A      
byte  5,$19, 5,$22, 5,$21, 0,$44, 6,$19, 6,$22, 6,$11,0,$44, 5,$19, 5,$22, 5,$21, 0,$44, 6,$19, 6,$19
 '4/4(17) D      C     D       D      C     D       D      D      D
byte  2,$23, 1,$23, 2,$23, 2,$34, 1,$27, 2,$23, 2,$23, 2,$34, 2,$34
'repeat
byte 254,$95
' 3/4   G   |  F2      G2       r |  A   |   A     A     r   |  G   |   F2    G2        r  |   A  |   A      
byte  5,$19, 11,$22, 12,$21, 0,$44, 6,$19, 6,$22, 6,$11,0,$44, 5,$19, 11,$22, 12,$21, 0,$44, 6,$19, 6,$19
 '4/4(17) D      C     D       D      C     D       D      D      D
byte  2,$23, 1,$23, 2,$23, 2,$34, 1,$27, 2,$23, 2,$23, 2,$34, 2,$34
'repeat
byte 254,$95
'start over
byte 255

C_MPH 'speed look up table
'byte 3,3, 22,4, 40,5, 58,5, 77,6, 92,7, 101,8
byte 200,15, 101,7, 92,6, 77,5, 58,4, 32,3, 3,2, 0,1

HUD_Text
'text'1234567890123456' 16 bytes               
byte "Time:xx  xxx mph"
Start_Text
'text'1234567890123456' 16 bytes
byte "  Press Start!  "
Score_Text
'text'1234567890123456' 16 bytes
byte "Score: xxxxxxxxx"

Road_Obj_Spr 'weighted list for roadside objects
byte 1,1,1,2,2,3,0,0

' palette for road  (keep road same color?)
' grass, road, grass  (old sky is $1C)
'road_pal byte $5b,$BB, $4, $5, $4, $BB, $5b
'         byte $6c,$5, $3, $3, $3, $5, $6c
road_pal byte $5b, $5, $4, $4, $4,  $5, $5b
         byte $6c,$BB, $4, $5, $4, $BB, $6c
'precalc LUT for depth of road (for alternating colors)
'Road depth data
Depth_PreCalc
BYTE 46 , 29 , 13 ,  1 , 70 , 60 , 51 , 44 , 36 , 31 , 25 , 19 , 15 , 10 ,  6 ,  3
BYTE 79 , 76 , 73 , 70 , 67 , 64 , 62 , 60 , 57 , 56 , 54 , 51 , 50 , 48 , 46 , 45 , 43 
BYTE 42 , 40 , 39 , 38 , 36 , 35 , 34 , 33 , 31 , 31 , 29 , 28 , 27 , 26 , 25 , 24 , 24
BYTE 22 , 22 , 20 , 20 , 19 , 18 , 17 , 16 , 15 , 15 , 14 , 13 , 12 , 12 , 11 , 10 ,  9
BYTE 9 ,  8 ,  7 ,  6 ,  6 ,  5 ,  4 ,  4 ,  3 ,  2 ,  1 ,  1 ,  0, 0

'Pre-calc'd curve in the road
Curve_PreCalc
BYTE 132 ,128 ,124 ,120 ,116 ,113 ,109 ,105 ,102 , 98 , 95 , 92 , 88 , 85 , 82 , 79  
BYTE  76 , 73 , 70 , 67 , 64 , 62 , 59 , 56 , 54 , 51 , 49 , 46 , 44 , 42 , 40 , 38  
BYTE  36 , 34 , 32 , 30 , 28 , 26 , 25 , 23 , 21 , 20 , 18 , 17 , 16 , 15 , 13 , 12  
BYTE  11 , 10 ,  9 ,  8 ,  7 ,  6 ,  6 ,  5 ,  4 ,  4 ,  3 ,  3 ,  2 ,  2 ,  1 ,  1  
BYTE   1 ,  1 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0  

'Road depth graphic LUT (for scaline sprites)
road_depth_sp
BYTE   0 , 17 , 33 , 45 , 56 , 66 , 75 , 82 , 90 , 95 ,101 ,107 ,111 ,116 ,120 ,123  
BYTE 127 ,130 ,133 ,136 ,139 ,142 ,144 ,146 ,149 ,150 ,152 ,155 ,156 ,158 ,160 ,161  
BYTE 163 ,164 ,166 ,167 ,168 ,170 ,171 ,172 ,173 ,175 ,175 ,177 ,178 ,179 ,180 ,181  
BYTE 182 ,182 ,184 ,184 ,186 ,186 ,187 ,188 ,189 ,190 ,191 ,191 ,192 ,193 ,194 ,194  
BYTE 195 ,196 ,197 ,197 ,198 ,199 ,200 ,200 ,201 ,202 ,202 ,203 ,204 ,205 ,205 ,206

'LUT to place sprites on sides of road
'left side of road
road_sprite_lut_l 
BYTE 149 ,147 ,145 ,143 ,141 ,139 ,137 ,135 ,134 ,132 ,130 ,128 ,126 ,124 ,122 ,120  
BYTE 119 ,117 ,115 ,113 ,111 ,109 ,107 ,105 ,104 ,102 ,100 , 98 , 96 , 94 , 92 , 90  
BYTE  89 , 87 , 85 , 83 , 81 , 79 , 77 , 75 , 74 , 72 , 70 , 68 , 66 , 64 , 62 , 60  
BYTE  59 , 57 , 55 , 53 , 51 , 49 , 47 , 45 , 44 , 42 , 40 , 38 , 36 , 34 , 32 , 30  
BYTE  29 , 27 , 25 , 23 , 21 , 19 , 17 , 15 , 14 , 12 , 10 ,  8 ,  6 ,  4 ,  2 ,  0  
'right side of road
road_sprite_lut_r
'add 100 to each value
BYTE 058 ,060 ,062 ,064 ,066 ,068 ,070 ,072 ,073 ,075 ,077 ,079 ,081 ,083 ,085 ,087  
BYTE 088 ,090 ,092 ,094 ,096 ,098 ,100 ,102 ,103 ,105 ,107 ,109 ,111 ,113 ,115 ,117  
BYTE 118 ,120 ,122 ,124 ,126 ,128 ,130 ,132 ,133 ,135 ,137 ,139 ,141 ,143 ,145 ,147  
BYTE 148 ,150 ,152 ,154 ,156 ,158 ,160 ,162 ,163 ,165 ,167 ,169 ,171 ,173 ,175 ,177  
BYTE 178 ,180 ,182 ,184 ,186 ,188 ,190 ,192 ,193 ,195 ,197 ,199 ,201 ,203 ,205 ,207

' lookup table for the road, 6 bytes perscanline
'index:  length in pixels, uses road_pal to find correct color
'Road runlength graphic LUT
road_gfx
BYTE 149 ,  1 ,  3 ,  1 ,  3 ,  1 ,255 
BYTE 147 ,  1 ,  5 ,  1 ,  5 ,  1 ,255 
BYTE 145 ,  1 ,  7 ,  1 ,  7 ,  1 ,255 
BYTE 143 ,  1 ,  9 ,  1 ,  9 ,  1 ,255 
BYTE 141 ,  2 , 10 ,  1 , 10 ,  2 ,255 
BYTE 139 ,  2 , 12 ,  1 , 12 ,  2 ,255 
BYTE 137 ,  2 , 14 ,  1 , 14 ,  2 ,255 
BYTE 135 ,  2 , 16 ,  1 , 16 ,  2 ,255 
BYTE 134 ,  2 , 17 ,  1 , 17 ,  2 ,255 
BYTE 132 ,  3 , 18 ,  1 , 18 ,  3 ,255 
BYTE 130 ,  3 , 20 ,  1 , 20 ,  3 ,255 
BYTE 128 ,  3 , 22 ,  1 , 22 ,  3 ,255 
BYTE 126 ,  3 , 24 ,  1 , 24 ,  3 ,255 
BYTE 124 ,  3 , 26 ,  1 , 26 ,  3 ,255 
BYTE 122 ,  4 , 27 ,  1 , 27 ,  4 ,255 
BYTE 120 ,  4 , 29 ,  1 , 29 ,  4 ,255 
BYTE 119 ,  4 , 30 ,  1 , 30 ,  4 ,255 
BYTE 117 ,  4 , 32 ,  1 , 32 ,  4 ,255 
BYTE 115 ,  4 , 34 ,  1 , 34 ,  4 ,255 
BYTE 113 ,  5 , 34 ,  3 , 34 ,  5 ,255 
BYTE 111 ,  5 , 36 ,  3 , 36 ,  5 ,255 
BYTE 109 ,  5 , 38 ,  3 , 38 ,  5 ,255 
BYTE 107 ,  5 , 40 ,  3 , 40 ,  5 ,255 
BYTE 105 ,  5 , 42 ,  3 , 42 ,  5 ,255 
BYTE 104 ,  6 , 42 ,  3 , 42 ,  6 ,255 
BYTE 102 ,  6 , 44 ,  3 , 44 ,  6 ,255 
BYTE 100 ,  6 , 46 ,  3 , 46 ,  6 ,255 
BYTE  98 ,  6 , 48 ,  3 , 48 ,  6 ,255 
BYTE  96 ,  6 , 50 ,  3 , 50 ,  6 ,255 
BYTE  94 ,  7 , 51 ,  3 , 51 ,  7 ,255 
BYTE  92 ,  7 , 53 ,  3 , 53 ,  7 ,255 
BYTE  90 ,  7 , 55 ,  3 , 55 ,  7 ,255 
BYTE  89 ,  7 , 56 ,  3 , 56 ,  7 ,255 
BYTE  87 ,  7 , 58 ,  3 , 58 ,  7 ,255 
BYTE  85 ,  8 , 59 ,  3 , 59 ,  8 ,255 
BYTE  83 ,  8 , 61 ,  3 , 61 ,  8 ,255 
BYTE  81 ,  8 , 63 ,  3 , 63 ,  8 ,255 
BYTE  79 ,  8 , 65 ,  3 , 65 ,  8 ,255 
BYTE  77 ,  8 , 67 ,  3 , 67 ,  8 ,255 
BYTE  75 ,  9 , 67 ,  5 , 67 ,  9 ,255 
BYTE  74 ,  9 , 68 ,  5 , 68 ,  9 ,255 
BYTE  72 ,  9 , 70 ,  5 , 70 ,  9 ,255 
BYTE  70 ,  9 , 72 ,  5 , 72 ,  9 ,255 
BYTE  68 ,  9 , 74 ,  5 , 74 ,  9 ,255 
BYTE  66 , 10 , 75 ,  5 , 75 , 10 ,255 
BYTE  64 , 10 , 77 ,  5 , 77 , 10 ,255 
BYTE  62 , 10 , 79 ,  5 , 79 , 10 ,255 
BYTE  60 , 10 , 81 ,  5 , 81 , 10 ,255 
BYTE  59 , 10 , 82 ,  5 , 82 , 10 ,255 
BYTE  57 , 11 , 83 ,  5 , 83 , 11 ,255 
BYTE  55 , 11 , 85 ,  5 , 85 , 11 ,255 
BYTE  53 , 11 , 87 ,  5 , 87 , 11 ,255 
BYTE  51 , 11 , 89 ,  5 , 89 , 11 ,255 
BYTE  49 , 11 , 91 ,  5 , 91 , 11 ,255 
BYTE  47 , 12 , 92 ,  5 , 92 , 12 ,255 
BYTE  45 , 12 , 94 ,  5 , 94 , 12 ,255 
BYTE  44 , 12 , 95 ,  5 , 95 , 12 ,255 
BYTE  42 , 12 , 97 ,  5 , 97 , 12 ,255 
BYTE  40 , 12 , 99 ,  5 , 99 , 12 ,255 
BYTE  38 , 13 , 99 ,  7 , 99 , 13 ,255 
BYTE  36 , 13 ,101 ,  7 ,101 , 13 ,255 
BYTE  34 , 13 ,103 ,  7 ,103 , 13 ,255 
BYTE  32 , 13 ,105 ,  7 ,105 , 13 ,255 
BYTE  30 , 13 ,107 ,  7 ,107 , 13 ,255 
BYTE  29 , 14 ,107 ,  7 ,107 , 14 ,255 
BYTE  27 , 14 ,109 ,  7 ,109 , 14 ,255 
BYTE  25 , 14 ,111 ,  7 ,111 , 14 ,255 
BYTE  23 , 14 ,113 ,  7 ,113 , 14 ,255 
BYTE  21 , 14 ,115 ,  7 ,115 , 14 ,255 
BYTE  19 , 15 ,116 ,  7 ,116 , 15 ,255 
BYTE  17 , 15 ,118 ,  7 ,118 , 15 ,255 
BYTE  15 , 15 ,120 ,  7 ,120 , 15 ,255 
BYTE  14 , 15 ,121 ,  7 ,121 , 15 ,255 
BYTE  12 , 15 ,123 ,  7 ,123 , 15 ,255 
BYTE  10 , 16 ,124 ,  7 ,124 , 16 ,255 
BYTE   8 , 16 ,126 ,  7 ,126 , 16 ,255 
BYTE   6 , 16 ,128 ,  7 ,128 , 16 ,255 
BYTE   4 , 16 ,130 ,  7 ,130 , 16 ,255 
BYTE   2 , 16 ,132 ,  7 ,132 , 16 ,255 
BYTE   0 , 17 ,132 ,  9 ,132 , 17 ,255  

'64*150 car sprite graphics

racer_car000 long $00000000,$00000000,$00000000,$00000000,$02000000,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$00000002,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01010200,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$00020101,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$AA010102,$0000AAAA,$00000000,$05050100,$00010505,$00000000,$BBB90000,$020101BB,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$AAAA0102,$00AAAAAA,$00000000,$05050100,$00010505,$00000000,$BBBBB900,$0201BBBB,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$02000000,$ABAA0101,$00AAAAAA,$00000000,$00000000,$00000000,$00000000,$BBBBB900,$0101BBB9,$00000002,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02000000,$ABAB0101,$00AAAAAB,$00000000,$00000000,$00000000,$00000000,$BBBBB900,$0101B9BB,$00000002,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$01000000,$AAAC0001,$00ACABAB,$00000000,$00000000,$00000000,$00000000,$BBBBBBB9,$01B9BBBB,$00000001,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01020000,$AB000001,$0000AAAB,$00000000,$00000000,$00000000,$00000000,$BBBBBBB9,$01B9BBBB,$00000201,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$01020000,$AC000000,$0000ACAC,$00000000,$00000000,$00000000,$00000000,$BBB9BBB9,$00BBBBBB,$00000201,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01010000,$0303026B,$02030303,$0000006B,$00000000,$00000000,$00000000,$BBBBB9B9,$00B9BBBB,$00000101,$00000000,$00000000,$00000000
        long $00000000,$00000000,$2A2A2A2A,$6B01002A,$0303036B,$03030303,$01016B02,$00000000,$00000000,$02010101,$B9B9B903,$AC03B9B9,$2A000101,$2A2A2A2A,$00000000,$00000000,$00000000,$2A000000,$05050505,$6B012A2A,$01030302,$03030101,$586B6B03,$01010101,$01010101,$03AC5858,$01010303,$02030301,$2A2A01AC,$05050505,$0000002A,$00000000
        long $00000000,$2A000000,$05050505,$6B012A2A,$01020302,$03020101,$016B0203,$58585858,$58585858,$0302AC01,$01010203,$02030201,$2A2A01AC,$05050505,$0000002A,$00000000,$00000000,$00000000,$2A2A2A2A,$02012A2A,$01010303,$03010101,$6B6B0303,$01010101,$01010101,$0303AC01,$01010103,$03030101,$2A2AAC02,$2A2A2A2A,$00000000,$00000000
        long $00000000,$00000000,$01010000,$02010101,$01010303,$03010101,$6B6B0303,$01010101,$01010101,$0303AC01,$01010103,$03030101,$0101AC02,$00000101,$00000000,$00000000,$00000000,$00000000,$0101012A,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$2A010101,$00000000,$00000000
        long $00000000,$2A2A0000,$012A2A2A,$01010101,$2A2A0101,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$01012A2A,$01010101,$2A2A2A01,$00002A2A,$00000000,$00000000,$2A2A2A00,$01012A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A0101,$002A2A2A,$00000000
        long $00000000,$2A2A2A2A,$2A01012A,$2A2A2A2A,$2A2A2A2A,$3C3B3B2A,$033C3C3C,$03030303,$03030303,$3C3C3C03,$2A3B3B3C,$2A2A2A2A,$2A2A2A2A,$2A01012A,$2A2A2A2A,$00000000,$2A000000,$2A2A2A2A,$2A2A012A,$2A2A2A2A,$3C3C3B2A,$033C3C3C,$C9C9C903,$C9C9C9C9,$C9C9C9C9,$03C9C9C9,$3C3C3C03,$2A3B3C3C,$2A2A2A2A,$2A012A2A,$2A2A2A2A,$0000002A
        long $2A2A0000,$2A2A2A2A,$2A2A2A01,$3C3B2A2A,$3B3B3C3C,$3C3B3B3B,$0303033C,$C9C9C903,$03C9C9C9,$3C030303,$3B3B3B3C,$3C3C3B3B,$2A2A3B3C,$012A2A2A,$2A2A2A2A,$00002A2A,$2A2A0000,$01010101,$3B010101,$3B3C3C3C,$3B3B3B3B,$3B3B3B3B,$3C3C3C3B,$3C3C3C3C,$3C3C3C3C,$3B3C3C3C,$3B3B3B3B,$3B3B3B3B,$3C3C3C3B,$0101013B,$01010101,$00002A2A
        long $012A2A00,$0101C9C9,$01010101,$3B2A0101,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$01012A3B,$01010101,$C9C90101,$002A2A01,$C9012A00,$01C9BABA,$C99B9BC9,$01030301,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$01030301,$C99B9BC9,$BABAC901,$002A01C9
        long $C9012A2A,$01C9BABA,$9B9B9B9B,$03040403,$2A2A2A01,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$012A2A2A,$03040403,$9B9B9B9B,$BABAC901,$2A2A01C9,$01012A2A,$0101C9C9,$C99B9BC9,$03040403,$2A2A0101,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$01012A2A,$03040403,$C99B9BC9,$C9C90101,$2A2A0101
        long $012A2A2A,$01010101,$01010101,$01030301,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01030301,$01010101,$01010101,$2A2A2A01,$3B3B3B2A,$2A2A2A2A,$3B3B3B3B,$3B3B3B3B,$2A2A2A3B,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$3B2A2A2A,$3B3B3B3B,$3B3B3B3B,$2A2A2A2A,$2A3B3B3B
        long $3B3B3B2A,$3B3B3B3B,$3C3C3C3B,$3B3C3C3C,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3C3C3C3B,$3B3C3C3C,$3B3B3B3B,$2A3B3B3B,$3B2A2A2A,$3C3C3B3B,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3B3B3C3C,$2A2A2A3B
        long $2A2A2A2A,$3B3B2A2A,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$2A2A2A3B,$2A2A2A2A,$2A2A2A2A,$3B2A2A2A,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$2A2A3B3B,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$3B3B3B2A,$3B3B3B3B,$3B3B3B3B,$2A2A2A2A,$19191919,$19191919,$19191919,$19191919,$2A2A2A2A,$3B3B3B3B,$3B3B3B3B,$2A3B3B3B,$2A2A2A2A,$2A2A2A2A
        long $2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$19191919,$19191919,$19191919,$19191919,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A19,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A19,$2A2A2A2A,$2A2A2A2A,$192A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$192A2A2A
        long $2A191919,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A19,$2A2A2A2A,$2A2A2A2A,$192A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$1919192A,$19191919,$2A2A2A19,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A19,$2A2A2A2A,$2A2A2A2A,$192A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$192A2A2A,$19191919
        long $19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$2A2A2A19,$2A2A2A2A,$2A2A2A2A,$192A2A2A,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191901,$19191919,$19191919,$19191919,$19191919,$19191919,$3B3B3B19,$3B3B3B3B,$3B3B3B3B,$193B3B3B,$19191919,$19191919,$19191919,$19191919,$19191919,$01191919
        long $19191901,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$01191919,$19191901,$19191919,$2A2A1919,$2A2A2A2A,$1919192A,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$2A191919,$2A2A2A2A,$19192A2A,$19191919,$01191919
        long $19190101,$19191919,$023B2A19,$02030303,$58582A3B,$58585858,$58585858,$58585858,$58585858,$58585858,$58585858,$3B2A5858,$03030302,$192A3B02,$19191919,$01011919,$19010101,$19191919,$03023B2A,$03585858,$3B3B2A02,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$022A3B3B,$58585803,$2A3B0203,$19191919,$01010119
        long $01010101,$01010101,$03020158,$03585858,$2A2A3B02,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$023B2A2A,$58585803,$58010203,$01010101,$01010101,$01010101,$01010101,$02015848,$02030303,$58580101,$58585858,$58585858,$58585858,$58585858,$58585858,$58585858,$01015858,$03030302,$48580102,$01010101,$01010101
        long $01010101,$01010101,$01580101,$01020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020201,$01015801,$01010101,$01010101,$01010101,$01010101,$02585801,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$01585802,$01010101,$01010101
        long $01010102,$01010101,$02020101,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$01010202,$01010101,$02010101,$02020200,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00020202
        long $00000000,$02020200,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00020202,$00000000,$00000000,$00000000,$00000000,$00000000,$02000000,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00000002,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$01020000,$01010101,$01010101,$01010101,$01010101,$01010101,$00000002,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01010102,$01010101,$01010101,$01010101,$01010101,$01010101,$00020101,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$02000000,$00010158,$00000000,$05AAAAAA,$01050505,$00000000,$00000000,$02010101,$B9000000,$0000BBBB,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01020000,$00000101,$AA000000,$AAAAAAAA,$01050505,$00000000,$00000000,$01010000,$BBB90002,$00BBBBBB,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$58020000,$00000001,$AA000000,$AAAAAAAB,$00000000,$00000000,$00000000,$01000000,$BBB90201,$00B9BBBB,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01010200,$00000000,$AB000000,$AAAAABAB,$00000000,$00000000,$00000000,$01000000,$BBB90101,$00BBBBBB,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$01010200,$00000000,$AC000000,$ACABABAA,$00000000,$00000000,$00000000,$00000000,$BBBBB901,$B9BBBBBB,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02010102,$00000000,$00000000,$00AAABAB,$00000000,$00000000,$00000000,$00000000,$BBBBB901,$B9BBBBBB,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00010102,$00000000,$00000000,$00ACACAC,$00000000,$00000000,$00000000,$00000000,$BBBBB900,$BBBBBBB9,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00010101,$AAAA0000,$03026B00,$03030303,$00006B02,$00000000,$00000000,$00000000,$B9B9B900,$B9BBBBBB,$00000000,$00000000,$00000000,$00000000
        long $2A2A0000,$002A2A2A,$00010101,$ACAC0101,$03036B6B,$03030303,$006B0203,$01010000,$01010101,$AC010101,$B9B90302,$03B9B9B9,$00002A2A,$00000000,$00000000,$00000000,$05052A00,$2A2A0505,$01000101,$ACAC0201,$0303026B,$01010103,$016B0303,$58580101,$58585858,$ACAC5858,$03030303,$03010101,$002A0502,$00000000,$00000000,$00000000
        long $05052A00,$2A2A0505,$01000101,$6B580102,$0303026B,$01010102,$6B020302,$01015858,$01010101,$02ACAA01,$02030303,$02010101,$002A0502,$00000000,$00000000,$00000000,$2A2A0000,$2A2A2A2A,$01010101,$6A580102,$03030302,$01010101,$6B030301,$01010101,$01010101,$03ACAC01,$01030303,$01010101,$00000203,$00000000,$00000000,$00000000
        long $00000000,$192A0000,$01010101,$01580102,$03030302,$01010101,$6B030301,$01010101,$01010101,$03ACAC01,$01030303,$01010101,$00000203,$00000000,$00000000,$00000000,$00000000,$012A2A2A,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$00010101,$00000000,$00000000,$00000000
        long $2A2A0000,$012A2A2A,$01010101,$01010101,$01010101,$2A2A0101,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$012A2A2A,$01010101,$00000001,$00000000,$00000000,$2A2A2A00,$192A2A2A,$2A010101,$2A2A2A2A,$2A01012A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A012A2A,$0000002A,$00000000
        long $3B3B3B2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$01012A2A,$2A2A2A2A,$2A2A2A2A,$3B3B2A2A,$3C3C3C3C,$03030303,$03030303,$3C3C3C03,$2A2A3B3B,$012A2A2A,$002A2A01,$00000000,$3C3C3C3B,$2A3B3B3B,$2A2A2A2A,$2A2A2A2A,$012A2A2A,$2A2A2A01,$3B3B2A2A,$3C3C3C3C,$C9C90303,$C9C9C9C9,$C9C9C9C9,$03C9C9C9,$3C3C3C3C,$2A2A3B3C,$2A2A012A,$00000000
        long $3C3B3B2A,$3B3C3C3C,$3B3B3B3B,$2A2A2A3B,$2A2A2A2A,$2A2A2A01,$3C3C3C3B,$3B3B3B3B,$03033C3C,$C9C90303,$C9C9C9C9,$3C0303C9,$3B3B3B3B,$3B3C3C3B,$2A012A2A,$00000019,$3B2A2A2A,$3C3C3C3B,$3C3C3C3C,$012A3B3C,$01010101,$3C3B0101,$3B3B3B3C,$3B3B3B3B,$3C3C3B3B,$3C3C3C3C,$3C3C3C3C,$3B3C3C3C,$3B3B3B3B,$3C3B3B3B,$192A3B3C,$00000101
        long $2A2A2A2A,$3C3C3B2A,$3C3C3C3C,$01013B3C,$01C9C901,$01010101,$19010101,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$2A3B3B3B,$01010101,$00C90101,$2A2A192A,$3C3C3B2A,$3C3C3C3C,$01013B3B,$C9BABAC9,$9B9BC901,$030301C9,$3B2A2A01,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$013B3B3B,$9BC90103,$00BAC9C9
        long $2A2A2A19,$3C3B3B2A,$3B3B3C3C,$01012A2A,$C9BABAC9,$9B9B9B01,$0404039B,$2A2A0103,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$03012A2A,$9B9B0304,$00BAC99B,$2A2A2A01,$3B2A192A,$2A2A3B3B,$012A2A2A,$01C9C901,$9B9BC901,$040403C9,$2A2A0103,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$03012A2A,$9B9B0304,$00C901C9
        long $2A2A2A01,$3B01192A,$2A2A2A3B,$2A2A2A2A,$01010101,$01010101,$03030101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$9BC90103,$002A1919,$2A2A1901,$3B01012A,$3B3B3B3B,$2A2A2A3B,$3B3B3B2A,$3B3B3B3B,$3B3B3B3B,$2A2A3B3B,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$3B3B3B3B,$3B3B3B3B,$2A2A3B3B
        long $19191901,$2A01032A,$3B3B2A2A,$3B3B3B3B,$3C3C3B3B,$3C3C3C3C,$3C3C3C3C,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3C3C3B3B,$3C3C3C3C,$3B3B3B3B,$19190101,$01031919,$2A2A2A2A,$3C3B3B3B,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C
        long $19190101,$01051919,$2A2A2A2A,$3B2A2A2A,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$3B3B2A2A,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$19010101,$03050119,$2A2A2A2A,$2A2A2A2A,$3B3B2A2A,$3B3B3B3B,$3B3B3B3B,$2A3B3B3B,$2A2A2A2A,$19191919,$19191919,$19191919,$2A191919,$3B3B2A2A,$3B3B3B3B,$2A2A2A3B
        long $19010101,$03050119,$2A2A2A01,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$19191919,$19191919,$19191919,$2A191919,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$01010101,$05050119,$2A2A1948,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A19,$2A2A2A2A,$2A2A2A2A,$2A192A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A
        long $01010100,$05050119,$19191901,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A19,$2A2A2A2A,$2A2A2A2A,$2A192A2A,$2A2A2A2A,$2A2A2A2A,$19192A2A,$01010100,$05050101,$19191901,$2A2A1919,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A19,$2A2A2A2A,$2A2A2A2A,$19192A2A,$19191919,$19191919,$19191919
        long $02020000,$05050102,$19191901,$19191919,$2A2A1919,$2A2A2A2A,$192A2A2A,$19191919,$19191919,$2A2A2A19,$3B2A2A2A,$3B3B3B3B,$19193B3B,$19191919,$19191919,$19191919,$02000000,$05050102,$19190101,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$3B3B3B19,$193B3B3B,$19191919,$19191919,$2A191919,$192A2A2A,$01191919
        long $00000000,$05050102,$19190101,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$022A1919,$2A2A0303,$00011919,$00000000,$05050100,$19190101,$19191919,$19191919,$2A191919,$2A2A2A2A,$582A2A2A,$58585858,$58585858,$58585858,$3B3B5858,$3B3B3B3B,$03022A19,$2A035858,$00000001
        long $00000000,$05050100,$19010101,$19191919,$19191919,$3B2A1919,$03030302,$3B2A0203,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$2A2A3B3B,$2A2A2A2A,$4803023B,$02035858,$00000000,$00000000,$05030100,$01010101,$19010101,$19191919,$023B2A29,$58585803,$3B020358,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$01012A2A,$01010101,$03020101,$01020303,$00000000
        long $00000000,$03030100,$01010101,$01010101,$01010101,$02010101,$58585803,$01020358,$01010101,$01010101,$01010101,$02020101,$01010101,$01010101,$02010101,$00000000,$00000000,$03010100,$01010101,$01010101,$02020202,$01020202,$03030302,$02010203,$02020202,$02020202,$02020202,$02020202,$01010101,$01010101,$02020101,$00000000
        long $00000000,$01010000,$01010101,$01010101,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$01010102,$01010101,$02020201,$00000000,$00000000,$01010000,$01010101,$01010101,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00020202,$00000000
        long $00000000,$01000000,$01010101,$02010101,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00000202,$00000000,$00000000,$00000000,$02020200,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00000202,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00020202,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02000000,$01010101,$01010101,$01010101,$01010101,$01010101,$00000201,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01010200,$01010101,$01010101,$01010101,$01010101,$01010101,$02010101,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$AAAA0000,$000000AA,$01010102,$00000000,$00000000,$05050501,$BBBBB905,$00000000,$58010100,$00000002,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$AAAAAA00,$0200AAAA,$00000101,$00000000,$00000000,$05050501,$BBBBBBB9,$000000BB,$01010000,$00000201,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$AAABAA00,$0102AAAA,$00000001,$00000000,$00000000,$00000000,$BBB9BBB9,$000000BB,$01000000,$00000258,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$ABABAB00,$0102AAAA,$00000001,$00000000,$00000000,$00000000,$BBBBBBB9,$000000B9,$00000000,$00020101,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$ABAAAC00,$0102ACAB,$00000000,$00000000,$00000000,$B9000000,$BBBBBBBB,$0000B9BB,$00000000,$00020101,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$ABAB0000,$010102AA,$00000000,$00000000,$00000000,$B9000000,$BBBBBBBB,$0000B9BB,$00000000,$02010102,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$ACAC0000,$010101AC,$00000000,$00000000,$00000000,$B9000000,$BBBBBBB9,$0000BBBB,$00000000,$02010100,$00000000,$00000000,$00000000,$00000000,$00000000,$6B000000,$03030302,$6B020303,$00000000,$00000000,$00000000,$B9000000,$BBBBBBBB,$0000B9BB,$00000000,$01010100,$00000000,$00000000
        long $00000000,$00000000,$00000000,$6B6B0000,$03030303,$02030303,$0101016B,$01010101,$00000101,$03020000,$B9B9B9B9,$ACAC03B9,$01010101,$01010100,$2A2A2A00,$00002A2A,$00000000,$00000000,$00000000,$026B2A00,$01010103,$03030303,$02026B6B,$58580202,$01015858,$03030101,$03010101,$AC020303,$015858AC,$01010001,$05052A2A,$002A0505
        long $00000000,$00000000,$00000000,$026B2A00,$01010102,$03030302,$016B6B02,$01020101,$58580101,$02030258,$02010101,$AC020303,$580101AC,$01010001,$05052A2A,$002A0505,$00000000,$00000000,$00000000,$03020000,$01010101,$03030301,$6B6B6B03,$01020101,$01010101,$01030301,$01010101,$02030303,$0101ACAC,$01010101,$2A2A2A2A,$00002A2A
        long $00000000,$00000000,$00000000,$03020000,$01010101,$03030301,$6B6B0103,$01020101,$01010101,$01030301,$01010101,$02030303,$0101ACAC,$01010101,$00002A19,$00000000,$00000000,$00000000,$00000000,$01010100,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$2A2A2A01,$00000000
        long $00000000,$00000000,$01000000,$01010101,$2A2A2A01,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$01012A2A,$01010101,$01010101,$01010101,$2A2A2A01,$00002A2A,$00000000,$2A000000,$2A2A012A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A01012A,$2A2A2A2A,$0101012A,$2A2A2A19,$002A2A2A
        long $00000000,$012A2A00,$2A2A2A01,$3B3B2A2A,$033C3C3C,$03030303,$03030303,$3C3C3C3C,$2A2A3B3B,$2A2A2A2A,$2A2A2A2A,$2A2A0101,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A3B3B3B,$00000000,$2A012A2A,$3C3B2A2A,$3C3C3C3C,$C9C9C903,$C9C9C9C9,$C9C9C9C9,$0303C9C9,$3C3C3C3C,$2A2A3B3B,$012A2A2A,$2A2A2A01,$2A2A2A2A,$2A2A2A2A,$3B3B3B2A,$3B3C3C3C
        long $19000000,$2A2A012A,$3B3C3C3B,$3B3B3B3B,$C903033C,$C9C9C9C9,$0303C9C9,$3C3C0303,$3B3B3B3B,$3B3C3C3C,$012A2A2A,$2A2A2A2A,$3B2A2A2A,$3B3B3B3B,$3C3C3C3B,$2A3B3B3C,$01010000,$3C3B2A19,$3B3B3B3C,$3B3B3B3B,$3C3C3C3B,$3C3C3C3C,$3C3C3C3C,$3B3B3C3C,$3B3B3B3B,$3C3B3B3B,$01013B3C,$01010101,$3C3B2A01,$3C3C3C3C,$3B3C3C3C,$2A2A2A3B
        long $0101C900,$01010101,$3B3B3B2A,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$01010119,$01010101,$01C9C901,$3C3B0101,$3C3C3C3C,$2A3B3C3C,$2A2A2A2A,$C9C9BA00,$0301C99B,$3B3B3B01,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$012A2A3B,$C9010303,$01C99B9B,$C9BABAC9,$3B3B0101,$3C3C3C3C,$2A3B3C3C,$2A192A2A
        long $9BC9BA00,$04039B9B,$2A2A0103,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$03012A2A,$9B030404,$019B9B9B,$C9BABAC9,$2A2A0101,$3C3C3B3B,$2A3B3B3C,$192A2A2A,$C901C900,$04039B9B,$2A2A0103,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$03012A2A,$C9030404,$01C99B9B,$01C9C901,$2A2A2A01,$3B3B2A2A,$2A192A3B,$012A2A2A
        long $19192A00,$0301C99B,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010303,$01010101,$01010101,$2A2A2A2A,$3B2A2A2A,$2A19013B,$012A2A2A,$3B3B2A2A,$3B3B3B3B,$3B3B3B3B,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$3B3B2A2A,$3B3B3B3B,$3B3B3B3B,$2A3B3B3B,$3B2A2A2A,$3B3B3B3B,$2A01013B,$01192A2A
        long $3B3B3B3B,$3C3C3C3C,$3B3B3C3C,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3C3C3C3C,$3C3C3C3C,$3B3B3C3C,$3B3B3B3B,$2A2A3B3B,$2A03012A,$01191919,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3B3B3B3C,$2A2A2A2A,$1903012A,$01191919
        long $3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$2A2A3B3B,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$2A2A2A3B,$2A2A2A2A,$1905012A,$01191919,$3B2A2A2A,$3B3B3B3B,$2A2A3B3B,$1919192A,$19191919,$19191919,$19191919,$2A2A2A2A,$3B3B3B2A,$3B3B3B3B,$3B3B3B3B,$2A2A3B3B,$2A2A2A2A,$2A2A2A2A,$0105032A,$01011919
        long $2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$1919192A,$19191919,$19191919,$19191919,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$012A2A2A,$01050301,$01011919,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A192A,$2A2A2A2A,$2A2A2A2A,$192A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$48192A2A,$01050548,$01010119
        long $2A2A1919,$2A2A2A2A,$2A2A2A2A,$2A2A192A,$2A2A2A2A,$2A2A2A2A,$192A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$01191919,$01050501,$01010119,$19191919,$19191919,$19191919,$2A2A1919,$2A2A2A2A,$2A2A2A2A,$192A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$19192A2A,$01191919,$01050501,$01010101
        long $19191919,$19191919,$19191919,$3B3B1919,$3B3B3B3B,$2A2A2A3B,$192A2A2A,$19191919,$19191919,$2A2A2A19,$2A2A2A2A,$19192A2A,$19191919,$01191919,$01050501,$00020202,$19191901,$2A2A2A19,$1919192A,$19191919,$19191919,$3B3B3B19,$193B3B3B,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$01011919,$01050501,$00000202
        long $19190100,$03032A2A,$19192A02,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$01011919,$01050501,$00000002,$01000000,$5858032A,$192A0203,$3B3B3B3B,$58583B3B,$58585858,$58585858,$58585858,$2A2A2A58,$2A2A2A2A,$1919192A,$19191919,$19191919,$01011919,$01050501,$00000000
        long $00000000,$58580302,$3B020348,$2A2A2A2A,$3B3B2A2A,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$03022A3B,$02030303,$19192A3B,$19191919,$19191919,$01010119,$01050501,$00000000,$00000000,$03030201,$01010203,$01010101,$2A2A0101,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$5803023B,$03585858,$292A3B02,$19191919,$01010119,$01010101,$01030501,$00000000
        long $00000000,$01010102,$01010101,$01010101,$01010202,$01010101,$01010101,$01010101,$58030201,$03585858,$01010102,$01010101,$01010101,$01010101,$01030301,$00000000,$00000000,$01010202,$01010101,$01010101,$02020202,$02020202,$02020202,$02020202,$03020102,$02030303,$02020201,$02020202,$01010101,$01010101,$01010301,$00000000
        long $00000000,$01020202,$01010101,$02010101,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$01010101,$01010101,$00010101,$00000000,$00000000,$02020200,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$01010101,$01010101,$00010101,$00000000
        long $00000000,$02020000,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$01010102,$01010101,$00000101,$00000000,$00000000,$00000000,$00000000,$02020000,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00020202,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$02020200,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000

'64x168  graphics data(background, sign and tree sprites)

racer_bg000 long $2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2B2B2B2B,$2B2B2B2B,$048CFC03,$03045CEC,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B
        long $2A2A2A2A,$0404032A,$05050404,$03040505,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$032A2A2A,$05050504,$05050505,$04050505,$2A2A2AFC,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A
        long $0404032B,$05050505,$05050505,$05050505,$2B2B8C04,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$05040404,$05050505,$05050505,$05050505,$2AFC0505,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A
        long $05050404,$05050505,$05050505,$05050505,$03040505,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$042B2B2B,$05050504,$05050505,$05050505,$05050505,$03FC0505,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$8CFC2B2B
        long $05040405,$04050505,$05050505,$05050505,$7C04FC04,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$042A2A2A,$04040404,$05040405,$05050505,$04050505,$2B040404,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$042B2B2B
        long $04040505,$04040404,$05050505,$04050505,$2B2B0404,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$FC2B2B2B,$0505048C,$04040404,$04050404,$2B050505,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B
        long $0504042B,$04040405,$05040404,$2B2B0505,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$04042B2B,$04040404,$2B040404,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B
        long $2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$FC052B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$0505FC2B,$2B2B8C05,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B
        long $2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$0403032B,$05050505,$05050505,$2B2BFC04,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$04042B03,$05FC0404,$05050505,$8C040505,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B
        long $2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$042B2B2B,$048CFC04,$05050505,$04050505,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$3B2B032B,$3B3C2C3B,$2B2B2B2B,$042BFC2B,$05040404,$05050505,$04050505,$2B04FC04,$2B2B2B2B,$04FC2B2B,$2B2B2B2B
        long $2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$042B2B03,$04040404,$047C3B04,$7C04047C,$05050504,$05050505,$05050505,$04050405,$2B2B2B04,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$7C3C042B,$05050404,$04040404,$04050505,$05050504,$05050505,$05050505,$04050505,$04050505,$2B2B2B04,$2B2B2B2B
        long $3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3B3C3C3C,$04040404,$04040405,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$0404FC05,$3C3C3C04,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$04048C3B,$05040404,$04040505,$05050504,$05050505,$05050505,$05050505,$05050505,$05050405,$2B2B0405
        long $2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$0404042B,$05050404,$04050505,$05050504,$05050405,$05050505,$05050505,$05050505,$05040505,$2B040405,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$0404FC3C,$05040505,$04040504,$04040404,$05040404,$05050505,$05050505,$05050505,$04040505,$04050404
        long $2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$04042B2B,$04040404,$04040404,$040404FC,$05050504,$05050505,$05050505,$05050505,$04050505,$05050404,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$04050404,$3CFC0504,$3C3C3C3C,$048C3C3C,$FC0404FC,$3C3C048C,$04048C3C,$05040504,$05050505,$05050505,$05050505,$05050505,$04040404
        long $3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$05050505,$8C050505,$3C3C5C04,$3C3CFC3C,$3C047C04,$3C3C3C3C,$045C04FC,$04040404,$05050505,$05040505,$05050505,$04040405,$04040404,$2B2B2B2B,$2B2B2B2B,$042B2B2B,$05050505,$05050505,$2B040505,$2B2B2B2B,$2B2BFC2B,$5C2B2B2B,$FC8CFC8C,$04047C04,$05040504,$05050505,$8CFC0404,$FC040504,$2B2B2B04
        long $3C3C3C3C,$3C8CFC3C,$040404FC,$05050504,$05050505,$04050505,$3C3C3CFC,$3C3C3C3C,$3C3C3C8C,$7CFC5C04,$040404FC,$04040404,$04040405,$3C3C3CFC,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$043C3C3C,$04040404,$05050504,$05050505,$05050505,$04040405,$3C043C7C,$3CFC3C3C,$FC7C04FC,$FC7CFC8C,$FCEC048C,$045C048C,$3C3C3C04,$3C3C3C3C,$3C3C3C3C
        long $3C3C3C3C,$0404043C,$04040405,$05050504,$05050505,$05050505,$04040405,$3C3C3CFC,$3C7C045C,$7A7A7A6C,$7A7A7A7A,$5C046B6B,$EC04EC04,$3C3CFC7C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$7CFC7C3C,$04050504,$04050404,$05050505,$05050505,$05050505,$047C3C04,$7A7A6CFC,$7A7A7A7A,$7A7A7A7A,$6B6B7A7A,$5C6B7A6B,$7C048C04,$3C3C3C04,$3C3C3C3C
        long $3C3C3C3C,$3C3C3C3C,$04040404,$04040404,$05050404,$05050505,$04050405,$7A5C04FC,$7A7A7A7A,$7A7A7A7A,$7A7A7A7A,$7A7A7A7A,$7A7A7A7A,$045CFC6B,$3C3C5CEC,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$040404FC,$04040404,$04040404,$04050505,$7C040404,$7A7A7A6C,$7A7A7A7A,$7A7A7A7A,$7A7A7A7A,$7A7A7A7A,$7A7A697A,$046B7A7A,$04050404,$3C3C3C3C
        long $3C3C3C3C,$043C3C3C,$037C0404,$8CFC5A03,$05040504,$FC040404,$7A69695B,$7A7A7A7A,$7A7A697A,$7A7A7A7A,$697A7A7A,$7A7A7A69,$7A696969,$7A7A7A7A,$0505056B,$3C3C3C04,$3C3C3C3C,$3C3C3C3C,$6B696969,$6B7A6B03,$8CFC6B7A,$69697CFC,$7A7A7A7A,$7A7A7A7A,$7A7A7A7A,$697A7A7A,$69696969,$69696969,$69696969,$7A7A7A69,$04FC7A7A,$3C3C3C04
        long $3C3C3C3C,$6B7A033C,$6B6B7A6B,$6B7A7A7A,$7A697A6B,$7A7A7A69,$697A697A,$7A69697A,$7A7A7A7A,$7979797A,$69697979,$69796969,$69797979,$7A7A6969,$7A7A7A7A,$3C3C3C3C,$3C3C3C3C,$6B7A6969,$6B6B7A6B,$7A6B6B6B,$7A7A7A7A,$7A7A7A7A,$7A69697A,$69697A7A,$7A7A7A7A,$6969697A,$69697979,$69696969,$69797979,$7A7A6969,$7A7A7A7A,$3C3C697A
        long $697A6B69,$6B6B7A69,$6B6B6B6B,$6B6B6B6B,$7A7A7A69,$7A7A6B6B,$7A697A7A,$7A7A6969,$697A7A7A,$69696969,$69696969,$69696969,$69696969,$69696969,$6B6B6B7A,$69697A7A,$6B69697A,$6B6B7A6B,$7A7A6B6B,$796B6B6B,$7A7A6969,$7A696B7A,$7A7A7A69,$696B6B69,$69697A7A,$69696969,$69696969,$69696969,$69696969,$69696969,$6B6B6B6B,$7A7A7A6B
        long $6B6B7A7A,$6B6B6B7A,$6B6B6B6B,$6B6B6B6B,$6B6B6969,$697A697A,$69696969,$7A697A6B,$69696969,$69696969,$69696969,$69696969,$69696969,$69696969,$6B7A7A7A,$7A6B6B7A,$7A7A697A,$6B6B6B6B,$6B6B6B6B,$6B6B7A6B,$697A6969,$697A7A69,$6B6B6969,$6B6B7A7A,$69697A6B,$69696969,$69697969,$69696969,$69696969,$69696969,$6B7A6969,$7A6B7A6B
        long $7A7A7A69,$6B6B6B7A,$6B696B6B,$6B7A7A6B,$7A69697A,$69696969,$6969697A,$7A7A7A7A,$69697A7A,$69696969,$69696969,$69696969,$7A7A7A69,$7A6B6B6B,$7A69697A,$7A7A6B7A,$697A6969,$7A6B7A7A,$697A696B,$6B697A69,$696B6969,$7A7A697A,$69697A69,$7A697A6B,$6B6B6B7A,$69697A6B,$69696969,$6B6B6B69,$6B6B6B6B,$6B6B6B6B,$7A7A6B6B,$6B7A6B6B
        long $7A7A7A7A,$7A7A6B6B,$69696B6B,$6969697A,$7A6B6B7A,$6B6B6B6B,$7A7A6B7A,$6B7A7A7A,$7A7A7A6B,$6B6B7A6B,$6B7A6B7A,$7A6B6B7A,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$796B6B6B,$7A696B7A,$7A7A7A7A,$69696969,$7A7A697A,$6B7A7A7A,$7A6B6B6B,$6B7A7A7A,$6B7A6B6B,$6B697A7A,$6B7A7A7A,$7A696B7A,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B7A6B6B
        long $6B6B697A,$6B6B696B,$7A697A69,$7A7A7A69,$7A6B6B6B,$7A6B6B69,$6B6B7A6B,$6B6B6B6B,$6B6B6B6B,$7A7A7A6B,$6B6B6B6B,$6B6B6B7A,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$7A6B6B6B,$6B7A6B7A,$7A696B6B,$7A6B7A7A,$6B7A7A7A,$7A69697A,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B
        long $7A7A7A6B,$7A7A7A7A,$7A7A697A,$6B6B7A6B,$6B6B7A6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$69696B6B,$6B6B6B7A,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$7A7A6B6B,$7A7A6B6B,$69697A6B,$7A7A6969,$696B6B6B,$6B6B6B6B,$7A6B7A6B,$69696969,$69696969,$6B6B6B7A,$6969696B,$69697969,$7A6B7A69,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B
        long $7A6B6B6B,$7A697A6B,$6B7A6B7A,$6B6B6B6B,$6B6B6B6B,$7A7A6B6B,$79696969,$69697969,$69696969,$7A7A7A69,$7A6B7A7A,$697A697A,$6B6B6B6B,$6B6B6B7A,$6B6B6B6B,$7A6B6B6B,$6B6B6B6B,$6B6B7A6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$7A7A7A6B,$6969697A,$69696B69,$7A7A6B6B,$69697A7A,$7A7A7A7A,$7A697A7A,$69697A7A,$7A696969,$6B6B6B7A,$6B6B6B6B
        long $6B7A6B6B,$697A6B7A,$6B6B6B69,$6B6B6B69,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$69697A7A,$6B6B6B69,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$7A7A7A6B,$7A69697A,$6C6C6B69,$6B696B6B,$69696B7A,$6B7A6969,$7A6B6B6B,$7A696B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B69,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$7A7A6C6B
        long $6969696B,$69696B7A,$7A6B697A,$796B7A7A,$697A6969,$6B6B6B6B,$6B7A7A6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$7A69696B,$7A6C6B6B,$6B6B6B6B,$6B7A7A6B,$7969697A,$79696979,$69696969,$6B6B6969,$697A6B7A,$69696B69,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B696B69,$6B6B696B,$7A6C7979,$7A797A79
        long $7A6B6B6B,$7A6B697A,$79696B79,$69696B7A,$7A697969,$7A69697A,$6B6B6B6B,$7A696B7A,$69696B7A,$7A7A6B7A,$696B696B,$6B69696B,$6B6B6B6B,$6C696B6B,$7979796B,$79797979,$6B69696B,$7A6B6B6B,$7A6C6C79,$697A7A7A,$696B6969,$7A7A696B,$6B6B6B6B,$797A7A6B,$697A6C69,$7A69697A,$696B6B7A,$6B6B6969,$6B6B6B6B,$696B6B6B,$7979796B,$7A797979
        long $7A696B79,$7A7A7A6B,$6B6C6B7A,$696B6B6B,$696B7979,$6B6B6B79,$7A6B6B6B,$697A697A,$69697A69,$6C6B6969,$6B6C6C6C,$6B696969,$6B696B69,$6B6B6B6B,$79797969,$69797979,$6B6B6979,$79797A6B,$69696B7A,$69797969,$79797979,$696B696B,$696B6B79,$6B79697A,$6B6B6B6B,$6B6B797A,$6B6C6C6B,$797A796B,$6B6B6979,$796B6B6B,$79797979,$79797979
        long $6B696969,$6B6B7A69,$797A7979,$79797969,$79797979,$79796969,$6B6B7979,$79696B79,$6B696B6B,$696B6C6B,$697A6969,$6B6B6C69,$6B6B6B6B,$796B6C69,$79797979,$79797979,$69696969,$7A696969,$796B7969,$6B697A6B,$6B6B6C6B,$7979696B,$6B7A7979,$79796B69,$6B796969,$696C6B6B,$6B6C6B6B,$6B79696B,$6B6B6B6B,$7979696B,$79797979,$79797979
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$69696900,$69696969,$00000069,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$69690069,$6A690069,$6B6B6B6A,$6B6B6B6B,$69696A6B,$00006969,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$6A6A6969,$6B6A696A,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$00696A6B,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$6B6A6A69,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$696A6A6B,$00006969,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$69690000,$6B6B6B6A,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$696A6B6B,$00000069,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$6A696900,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6A,$6A6B6B6B,$6A6B6A6B,$00696969
        long $05050300,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$00030505,$6A6A6969,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6A6A6B6B,$6B6B6A6B,$6969696A,$05050503,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$03050505,$6B6A6969,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6A6B,$696A6B6B
        long $05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$6B6B6A69,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6A6B,$6B6B6B6B,$6B6B6B6B,$696A6A6A,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$6B6B6B69,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6A6B6B,$6B6B6B6B,$696B6B6B
        long $04050505,$03030304,$02020202,$02020202,$02020202,$03020202,$04040303,$05050505,$6B6B6B69,$6B6B6A6B,$6B6B6B6B,$6A6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$696A6B6B,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$6B6B6B6A,$6B6A6A6B,$6B6B6A6A,$6B6B6B6B,$6B6B6B6A,$6B6B6A6A,$6B6A6A6B,$6A6B6B6B
        long $05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$6B6B6B6A,$6B6B6B6B,$6A6B6B6A,$6A6B6B6B,$6B6B6B6A,$6B6B6A6A,$6A6A6B6B,$696B6B6A,$02040505,$04020404,$04050402,$02020402,$02040302,$05030202,$03020203,$05050505,$6B6B6B69,$6B6B6B6B,$6A6A6B6B,$696A6A6B,$6B6B6A6A,$6A6A6A6B,$6A6B6B6A,$696A6B6B
        long $02040505,$04020404,$03050302,$04020402,$02040203,$04020404,$02040402,$05050504,$6B6B6A69,$6B6B6B6B,$6B6B6A6B,$6A6A6A6A,$6A6B6A6B,$6A6B6A6B,$6A6A6B6A,$696A6A6B,$02040505,$04020404,$02030203,$04020403,$02040204,$04020404,$02040402,$05050504,$6A6B6969,$6B6A6B6B,$6A6A6B6B,$6B6A6B6B,$6A6A6B6B,$6B6B6A6A,$6A6A6A6A,$696A6A6A
        long $02040505,$04020202,$03020305,$04020405,$02040204,$04030202,$02020202,$05050504,$6A6A6A69,$6A6B6A6B,$6A6B6B6A,$6A6B6B6B,$6A6A6A6B,$6B6A6A6B,$6A6A6A6A,$6A6A6A6B,$02040505,$04020404,$04020405,$04020405,$02040203,$04020404,$02040402,$05050504,$6B6B6B69,$6A6A6B6A,$6B6B6A6A,$6B6B6B6B,$6B6B696A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A
        long $02040505,$04020404,$04020405,$02020405,$02040302,$04020404,$02040402,$05050504,$6B6B6B6A,$6A6B6B6B,$6B6B6B6A,$6A6A6A6B,$6A6A6A6A,$6A6A6A6A,$6B6A6A6B,$696A6B6A,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$6B6A6A6A,$6B6B6B6B,$6B6B6B6B,$6A6A6A6A,$696A6A69,$6A6A6A6A,$6A6A6A6A,$6A696B6A
        long $05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$6B6A6A69,$6A6A6A6A,$6A6A6A6A,$6A6A6A6B,$6A6A6A69,$6A6A6A6A,$6A6A6A6A,$696A6A6A,$04050505,$03030304,$02020202,$02020202,$02020202,$03020202,$04040303,$05050505,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6B6A6A,$6A6A6A6A,$696A696A,$6A6A6A69,$696A6A6A
        long $05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$6A6A6A69,$6A6A6A6A,$6A696A6A,$696A6A6A,$6A6A696A,$6A69696A,$6A6A6A6A,$69696A6A,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$6A6B6A6A,$6A696A6A,$6A6A6A6A,$696A6A69,$69696969,$6A6A6969,$6A696A69,$6969696A
        long $05050503,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$03050505,$6A6A6A69,$6A6A6A6A,$6A6A6A6A,$69696969,$6A6A6A69,$696A6A6A,$6A6A696A,$00696969,$05050300,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$00030505,$6A6A6900,$6A6A6A6A,$6A6A6A6A,$6A696A6A,$696A6A6A,$69696969,$696A6A69,$00006969
        long $00000000,$03030300,$00000000,$00000000,$00000000,$00000000,$00030303,$00000000,$69690000,$6A6A696A,$6969696A,$AA99AA69,$69AAAAAA,$6A6A6969,$69696969,$00006969,$00000000,$04030400,$00000000,$00000000,$00000000,$00000000,$00040304,$00000000,$69000000,$69696969,$69696969,$AAAAAAAA,$6A69AAAA,$6969696A,$69696969,$00000069
        long $00000000,$04040400,$00000000,$00000000,$00000000,$00000000,$00040404,$00000000,$00000000,$00000000,$00000000,$AAAAAA00,$6999AAAA,$69696969,$00000069,$00000000,$00000000,$04040402,$02020202,$02020202,$02020202,$02020202,$02040404,$00000000,$00000000,$00000000,$00000000,$AAAAAA00,$0000AA99,$00000000,$00000000,$00000000
        long $02020000,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00000002,$00000000,$02020200,$02020202,$AAAA9902,$0202AA99,$02020202,$02020202,$00000000,$00000000,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00000000,$00000000,$02020200,$02020202,$02020202,$02020202,$02020202,$02020202,$00000000
        long $00000000,$00000000,$00000200,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$C9000000,$CACACACA,$CABABBAB,$CACACACA,$00000000,$00000000,$00000000,$00020100,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$CAC90000,$CACA03CA,$ABCACACA,$CACABABB,$C9CABACA,$000000BA
        long $00000000,$00000000,$02010100,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$C9000000,$CACACACA,$CACACA03,$ABCACABA,$CACACABB,$C8C9CACA,$0000BAC9,$00000000,$00000000,$01010101,$00000001,$00000000,$00000000,$00000000,$00000000,$00000000,$CACAC900,$CABACACA,$CACACA03,$BBABCABA,$CACACABA,$C8C8C9CA,$00BAC9C8
        long $00000000,$00000000,$01010101,$00010101,$00000000,$00000000,$00000000,$00000000,$00000000,$CACACAC9,$03CABACA,$BACACACA,$CABBABCA,$CACACACA,$C8C8C8C9,$BAC9C8C8,$00000000,$00000000,$01010301,$01030101,$00000001,$00000000,$00000000,$00000000,$C9000000,$CABACACA,$CA03CACA,$BACACACA,$CABABBAB,$C9CACACA,$0000C8C8,$C9000000
        long $00000000,$01000000,$01030502,$05050201,$01010205,$00000000,$00000000,$00000000,$CACACA00,$CACABACA,$CACA03CA,$C9C9C9C9,$C9C9C9C9,$C9C9C9C9,$0000C8C8,$00000000,$00000000,$01000000,$03050505,$05050501,$01050505,$00010101,$00000000,$00000000,$C9C9C900,$C8C9C9C9,$C9C8C8C8,$000000C8,$00AAAA00,$00000000,$0000C8C9,$00000000
        long $00000000,$02010000,$05050505,$05050205,$01020505,$01010101,$00000001,$00000000,$00000000,$00000000,$C9000000,$AA0000C8,$AAAAAAAA,$000000AA,$0000C8C9,$00000000,$00000000,$01010000,$05050502,$02010105,$01010505,$03010101,$00010103,$00000000,$00000000,$00000000,$C9000000,$000000C8,$98ACAB98,$00000000,$0000C8C9,$00000000
        long $00000000,$01010000,$05020101,$01010102,$01010301,$05030101,$02050505,$00000001,$00000000,$00000000,$C9000000,$000000C8,$98ABAC98,$00000000,$0000C8C9,$00000000,$00000000,$03010100,$03010101,$01010101,$05050501,$05030305,$05050505,$00010102,$00000000,$00000000,$C9000000,$3B3900C8,$3B3B3B3B,$0099BC3B,$0000C8C9,$00000000
        long $00000000,$05050100,$01010103,$01030505,$05050501,$02010505,$05050505,$01020505,$00000000,$00000000,$C9000000,$3B3B39C8,$3B3BAB8A,$9A003948,$0000C8C9,$00000000,$00000000,$05050100,$05010305,$05050505,$05050503,$01010205,$05050502,$00010205,$00000000,$00000000,$C9000000,$993B39C8,$989999A8,$AC78CA02,$0000C8C9,$00000000
        long $00000000,$05050101,$05030505,$05050505,$03010101,$01010105,$05020101,$00000102,$00000000,$00000000,$C9000000,$999900CB,$999AAA99,$9B9A9B00,$0000C89C,$00000000,$00000000,$05020101,$01020505,$05050503,$01010101,$01010102,$01010101,$00000001,$00000000,$00000000,$DC9B049B,$B8AAABCB,$88A8ABA9,$BABAC9AC,$0000C89C,$00000000
        long $01000000,$02010001,$01020505,$03010101,$01010101,$02050501,$01010101,$00000000,$00000000,$CC000000,$02DC0C03,$A8A9B9CA,$B8C8BAB8,$BAAAAAB9,$CACABBBA,$0000CACA,$01000000,$01000001,$01010101,$05010101,$01010305,$05050501,$01010103,$00000000,$00000000,$EC000000,$E81BECCC,$DBDCDC48,$BAC898D8,$B9C8B8B8,$CACA9CBA,$000000CA
        long $01000000,$00000001,$01010100,$05010101,$05050505,$05050503,$00010505,$00000000,$00000000,$CA000000,$CA99CACA,$CA0202C8,$A90202D9,$AB9CBAB9,$CACACAB9,$00000004,$01010000,$00000001,$01000000,$05010101,$05050505,$05050301,$00010305,$00000000,$00000000,$89890000,$02AB0202,$5A028B02,$BA020102,$BAC9A9D8,$CBCACACA,$00000005
        long $01010000,$00000000,$00000000,$01010100,$02050503,$03010101,$00000105,$00000000,$00000000,$99AC8B00,$999AD899,$49498A02,$5A020201,$CACB8B9C,$0403CACA,$00000005,$01010000,$00000000,$00000000,$00000000,$01010101,$01010101,$00000101,$00000000,$00000000,$8C998A00,$BAAABAB9,$9B99599A,$DA01999A,$8C9B8C8C,$040503CB,$00000005
        long $01010000,$00000000,$00000000,$00000000,$01010000,$01010101,$00000101,$00000000,$00000000,$A98C0000,$AAB8B9B8,$A9A888AA,$9B9A9A00,$8C8CAAAA,$04050405,$00000005,$00010100,$00000000,$00000000,$00000000,$00000000,$01010101,$00000101,$00000000,$00000000,$8C980000,$A8A9B9A9,$A89AA999,$8AA99CAA,$8CA88C8C,$04050405,$00000005
        long $00010100,$00000000,$00000000,$00000000,$00000000,$01010000,$00000101,$00000000,$00000000,$01000000,$B8B8B801,$8CA9B8A8,$AAAA9CB8,$048CA9AA,$04050405,$00000005,$00010100,$00000000,$00000000,$00000000,$00000000,$01000000,$00000001,$00000000,$00000000,$00000000,$B8AACA01,$A9010401,$8CA9AAA9,$04AAB8AA,$04050405,$00000003
        long $00010100,$00000000,$00000000,$00000000,$00000000,$00000000,$00000001,$00000000,$00000000,$00000000,$B8C90489,$99030403,$02B8A88C,$0499A999,$03050405,$00000000,$00000100,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02020200,$04030402,$04030403,$04AA0403,$04039A03,$AB030405,$00000000
        long $00000101,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02000000,$02020202,$02AB0202,$04030402,$04030403,$04030403,$ABAA0305,$00000002,$02020101,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02020000,$02AB0202,$02020202,$04020202,$04030403,$AB02AA03,$00000002
        long $02020101,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00000000,$00000000,$00000000,$02020202,$02020202,$02020202,$04AA0202,$020202AA,$00000000,$00020101,$00000000,$00000000,$00000000,$02020200,$02020202,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02020202,$AB020202,$00020202,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$02000000,$05050503,$05050505,$05050505,$03050505,$00000002,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$03000000,$03030303,$03030303,$03030303,$03030303,$00000003,$00000000,$00000000,$BBC90000,$BBBBBBBB,$BBBBBBBB,$BBBBBBBB,$BBBBBBBB,$0000C9BB,$00000000
        long $00000000,$03020000,$00010100,$01010000,$00000101,$00010100,$00000203,$00000000,$00000000,$CACABB00,$C9C9C9C9,$C9C9C9C9,$C9C9C9C9,$C9C9C9C9,$00BBCACA,$00000000,$00000000,$02030000,$01010101,$00000000,$00000000,$01010101,$00000302,$00000000,$00000000,$C9CACABB,$00000000,$01010000,$00000101,$00000000,$BBCACAC9,$00000000
        long $00000000,$00030000,$01010101,$00000001,$01000000,$01010101,$00000300,$00000000,$00000000,$00C9CACA,$01010101,$00000000,$00000000,$01010101,$CACAC900,$00000000,$00000000,$01020200,$01010101,$01010101,$01010101,$01010101,$00020201,$00000000,$00000000,$0100C9CA,$01010101,$00000001,$01000000,$01010101,$CAC90001,$00000000
        long $00000000,$01010302,$01010101,$01010101,$01010101,$01010101,$02030101,$00000000,$BB000000,$010000CA,$01010101,$00000001,$01000000,$01010101,$CA000001,$000000BB,$00000000,$01010302,$01010101,$01010101,$01010101,$01010101,$02030101,$00000000,$CA000000,$010100CA,$01010101,$00000001,$01000000,$01010101,$CA000101,$000000CA
        long $00000000,$01010302,$01010101,$01010101,$01010101,$01010101,$02030101,$00000000,$CA000000,$010100CA,$01010101,$00010101,$01010100,$01010101,$CA000101,$000000CA,$00000000,$02020302,$02020202,$02020202,$02020202,$02020202,$02030202,$00000000,$CA000000,$010101CA,$01010101,$01010101,$01010101,$01010101,$CA010101,$000000CA
        long $02000000,$04050503,$04040404,$04040404,$04040404,$04040404,$03050504,$00000002,$CABBBB00,$0101C9CA,$01010101,$01010101,$01010101,$01010101,$CAC90101,$00BBBBCA,$05050200,$05030505,$05050505,$05050505,$05050505,$05050505,$05050305,$00020505,$CA0505BB,$CACACAC9,$BBBBBBBB,$BBBBBBBB,$BBBBBBBB,$BBBBBBBB,$C9CACACA,$BB0505CA
        long $05040402,$05050305,$05050505,$05050505,$05050505,$05050505,$05030505,$02040405,$01BBBBCA,$CACAC901,$BBCACACA,$BBBBBBBB,$BBBBBBBB,$CACACABB,$01C9CACA,$CABBBB01,$04C9C903,$05050305,$05050505,$05050505,$05050505,$05050505,$05030505,$03C9C904,$C901C900,$C9C901C9,$CACACACA,$CACACACA,$CACACACA,$CACACACA,$C901C9C9,$00C901C9
        long $04BAC903,$05050503,$05050505,$05050505,$05050505,$05050505,$03050505,$03C9BA04,$BA01CA00,$0101C9C9,$BBCABBC9,$05050503,$03050505,$C9BBCABB,$C9C90101,$00CA01BA,$04BABA03,$05050503,$05050505,$04050505,$05050504,$05050505,$03050505,$03BABA04,$BA01CA00,$01C9BABA,$BBBBC9CA,$05050503,$03050505,$CAC9BBBB,$BABAC901,$00CA01BA
        long $04AABAC9,$05050503,$05050505,$04050505,$05050504,$05050505,$03050505,$C9BAAA04,$01C9CABB,$BB010101,$BBBBC9CA,$05050303,$03030505,$CAC9BBBB,$010101BB,$BBCAC901,$04AABABA,$05050503,$05050505,$05050505,$05050505,$05050505,$03050505,$BABAAA04,$BBBBCACA,$CABBBBBB,$BBC9CACA,$BBBBBBBB,$BBBBBBBB,$CACAC9BB,$BBBBBBCA,$CACABBBB
        long $04AABAAA,$04040203,$04040404,$04040404,$04040404,$04040404,$03020404,$AABAAA04,$BBBBCACA,$CACABBBB,$C9CACACA,$C9C9C9C9,$C9C9C9C9,$CACACAC9,$BBBBCACA,$CACABBBB,$03040403,$05050402,$04050505,$03030303,$03030303,$05050504,$02040505,$03040403,$BBCACACA,$BBBBBBBB,$CACACACA,$CACACACA,$CACACACA,$CACACACA,$BBBBBBBB,$CACACABB
        long $02040402,$04040404,$03040404,$04040404,$04040404,$04040403,$04040404,$02040402,$C9CACACA,$C9C9C9C9,$C9C9C9C9,$C9C9C9C9,$C9C9C9C9,$C9C9C9C9,$C9C9C9C9,$CACACAC9,$03030303,$03030303,$02030303,$04040404,$04040404,$03030302,$03030303,$03030303,$C9C9CACA,$C9C9C9C9,$CAC9C9C9,$CACACACA,$CACACACA,$C9C9C9CA,$C9C9C9C9,$CACAC9C9
        long $02020202,$02020202,$01020202,$04040404,$04040404,$02020201,$02020202,$02020202,$C9C9CACA,$CACACAC9,$CACACACA,$CACACACA,$CACACACA,$CACACACA,$C9CACACA,$CACAC9C9,$02020201,$02020202,$02020202,$01010101,$01010101,$02020202,$02020202,$01020202,$C9C9CACA,$050503CA,$02030505,$02020202,$02020202,$05050302,$CA030505,$CACAC9C9
        long $01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$C9CACAC9,$03030303,$03030303,$03030303,$03030303,$03030303,$03030303,$C9CACAC9,$03030303,$03030303,$03030303,$03030303,$03030303,$03030303,$03030303,$03030303,$C9CACAC9,$03030302,$03030303,$03030303,$03030303,$03030303,$02030303,$C9CACAC9
        long $03030302,$03030303,$03030303,$03030303,$03030303,$03030303,$03030303,$02030303,$C9CACAC9,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$C9CACAC9,$04040102,$04040404,$04040404,$04040404,$04040404,$04040404,$04040404,$02010404,$01010102,$02010101,$02020202,$02020202,$02020202,$02020202,$01010102,$02010101
        long $01010102,$01010101,$02020202,$02020202,$02020202,$02020202,$01010101,$02010101,$01010102,$02010101,$02020202,$02020202,$02020202,$02020202,$01010102,$02010101,$01010200,$02010101,$02020202,$02020202,$02020202,$02020202,$01010102,$00020101,$01010200,$02020101,$02020202,$02020202,$02020202,$02020202,$01010202,$00020101
        long $000000BB,$CABBBBCA,$CABBBBCA,$00000000,$00000000,$BBBBBBCA,$00CABBBB,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$000000CA,$CABBBBCA,$CABBBBCA,$00000000,$00000000,$CABBBBCA,$CABBBBCA,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$BBBBCA00,$00CABBBB,$00000000,$00000000,$CABBBBCA,$CABBBBCA,$BBBBCA00,$00CABBBB,$BBBBCA00,$00CABBBB,$BBBBCA00,$00CABBBB,$BBBBBBCA,$00CABBBB,$00000000,$00000000,$BBCA0000,$0000CABB,$BBBBBBCA,$CABBBBBB,$BBBBBBCA,$00CABBBB,$00000000,$CABBBBCA,$CABBBBCA,$00000000,$CABBBBCA,$CABBBBCA,$CABBBBCA,$CABBBBCA,$00000000
        long $00000000,$BBBBCA00,$00CABBBB,$00000000,$00000000,$BBBBBBCA,$0000CABB,$BBBBCA00,$CABBBBBB,$CABBBBCA,$00000000,$BBBBBBCA,$CABBBBBB,$CABBBBCA,$00000000,$00000000,$00000000,$CABBBBCA,$CABBBBCA,$00000000,$00000000,$CABBBBCA,$00CABBBB,$CABBBBCA,$CABBBBCA,$CABBBBCA,$00000000,$CABBBBCA,$00000000,$CABBBBCA,$00000000,$00000000
        long $00000000,$CABBBBCA,$CABBBBCA,$00000000,$00000000,$CABBBBCA,$CABBBBCA,$BBBBCA00,$CABBBBBB,$BBBBCA00,$00CABBBB,$BBBBCA00,$00CABBBB,$CABBBBCA,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000