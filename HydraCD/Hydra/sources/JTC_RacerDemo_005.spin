'' Racer Demo 06-16-06 
'' JT Cook
'' Based on Remi's graphic drivers which were torn apart to add my own road, background,
'' string text and sprite rendering routines
'' Int_to_String routines for clock and MPH from Colin's Liner demo
'' Controls - Left and Right steer, B-brake, A-gas, Start-pause, Select-unpause
'' Third release - Added background graphic which scrolls horizontally, turns come in and
''  leave smoother, added turning frames for car sprite, added row of text at the top of
''  of the screen using the built in font, turns have force, and the road side sprites
''  are drawn with correct priority.  
'' Second release - horizontal sprite screen clipping, sprite scaling, objects on the side
''  of the road, new original graphics
'' First release has road and sprites working(only one drawn right now). I "borrowed" the
''   car graphic from another racing game.
'' - Notes
'' There is a bug between the bottom of the background graphic and top of the road where it
''   messes up sprites(road scanline renders quicker than bg graphic scanline and messes
''   up order that the sprite scanlines should be drawn)(Note: I have placed a temp fix to
''   make road rendering take more time to match bg rendering time)
'' The main program has a lot of calculations to place sprites and posistion the road. All
''   of this is done in SPIN, so this slows the program down, because of this sometimes
''   sprite data may become messed up for a frame since the sprite data may change between
''   scanlines. The work around I used for this is to buffer the sprite info and at the
''   start of a new frame the data is copied over all at once.
'' There is a bug with the sprites where the right side is clipped too much at times, also
''   clipping the sprites on the right side of the screen is a little buggy

CON

  _clkmode = xtal1 + pll8x  ' ?
  _xinfreq = 10_000_000 + 0000 ' Set to 10Mhz and add 5000 to fix crystal imperfection of hydra prototype
  '_stack = ($300 - 200) >> 2           'accomodate display memory and stack
  _memstart = $10                   ' memory starts $10 in!!! (this took 2 headaches to figure out)

  paramcount = 14
  SCANLINE_BUFFER = $7F00
' constants            
request_scanline       = SCANLINE_BUFFER-4
update_ok              = SCANLINE_BUFFER-8
text_adr               = SCANLINE_BUFFER-12
xxx3                   = SCANLINE_BUFFER-16 
xxx4                   = SCANLINE_BUFFER-20 
spin_sprite_y_pxl      = SCANLINE_BUFFER-24 'Used for drawing height of sprite
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

  sprite_buff_off = 7 'offset for sprite calcuation buffer
  car_length = 58  'length of car sprite in pixels '56
  car_height = 39  'height of car sprite in pixels
  sprite_l_64 = 64 'length of sprite in pixels
  sprite_h_64 = 64 'height of sprite in pixels
  road_scanlines = 80 'how many scanlines the road makes up
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

  long temp1

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
  byte curve_lut[road_scanlines] 'pre-calc'd curve in the road for turns
  byte curve_depth ' how far into the turn the road is
  byte curve_direction 'which side road will curve to 0-left, 1-right
  byte car_speed          'how fast the car is moving
  long car_speed_long     'larger scale for car speed
  'sprite stuff
  long sprite_graphic[16] 'address for sprite
  long sprite_x_scale[16] 'size in pixels of scaled sprite
  long sprite_y_scale[16]
  long sprite_x[16]       'sprite location on screen(this is long because 255 = pixel 0)
  long sprite_x_clip[16]  'pixels to clip off when moving sprite off screen
  byte sprite_y[16]
  byte sprite_x_len[16]   'length of the sprite in pixels
  byte sprite_y_len[16]   'height of sprite in pixels
  long sprite_y_pxl[16]   'used for drawing height of sprite
  byte sprite_x_olen[16]  'actual pixel length of graphic(size before scaling)
  byte sprite_y_olen[16]  'actual pixel height of graphic(size before scaling)
  byte comp_car_speed[8]  ' speed of a sprite object
  'game sprites(for game engine, not rendering engine)
  byte road_prior_side        'tool for alternating objects on the side of the road
  long road_left_sprite_a     'address for graphic for left side of road
  long road_rght_sprite_a     'address for graphic for right side of road
  byte road_left_sprite_s     'size of sprite on left side of road
  byte road_rght_sprite_s     'size of sprite on right side of road
  byte sprite_road_val[16]    'sprite value on the road
  byte sprite_scl_val[16]     'sprite value for which scanline to check in LUT
  byte sprite_road_side[16]   'which side of road sprite is on (0-left, 1-right)
  byte sprite_size[16]        'size of sprite(0-small,1-tall,2-large)
  long track_event_cnt        'event counter for track(larger value)
  long track_event_num        'event counter for track(smaller value for events)  
  long next_track_event       'number for next event on track
  byte turn_cnt               'counter for turns
  byte max_turn               'how deep the turn will go
  byte e_e_turn               'enter exit a turn
                              '0 - do not adjust turn, 1 - enter turn, 2 - exit turn
  byte track_event            'the part of the track the player is on
  long vsync_update           'ok to update game during vsync?
  byte Game_Timer             'shows how much time is remaining
  byte Game_Timer_Tic         'how long until game timer is changed
  byte Pause                  'Pause toggle
  byte Deep_Sprite            'this is the farthest sprite, make sprite lowest priority
OBJ

  tv    : "rem_tv_014.spin"               ' tv driver 256 pixel scanline
  gfx   : "Racer_gfx_engine_005.spin"     ' graphics driver


PUB start      | i, j, k, kk, dx, dy, pp, pq, rr, numx, numchr
  DIRA[0] := 1
  outa[0] := 0

  longfill(@colors, $02020205, 1) 'set the border in right most values
  long[text_adr]:= @Test_Text
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
  long[spin_sprite_y_pxl]:= @sprite_y_pxl 'used for drawing height of sprite  
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
  'setup in game timer
  Game_Timer:=99
  Game_Timer_Tic:=0
  Display_Clock(Game_Timer)
  'background graphic
  sprite_graphic[0]:= @racer_bg000  
  sprite_x[0]:=0 'background graphic offset

  curve_depth:=80 ' how far into the turn the road is
  e_e_turn:=0 '0-don't change, 1-enter turn, 2-exit turn
  curve_direction:=0 'which side road will curve to 0-left, 1-right
  next_track_event:= 0 'travel until next track event
  track_event_cnt:= 0 'current distance traveled
  track_event:=0  'starting event  

  'roadside sprites setup
  sprite_road_val[2]:= 0
  sprite_road_side[2]:=0 
  sprite_road_val[3]:=41
  sprite_road_side[3]:=1 
  sprite_road_val[4]:=82
  sprite_road_side[4]:=0 
  sprite_road_val[5]:=123
  sprite_road_side[5]:=1
  sprite_road_val[6]:=164
  sprite_road_side[6]:=0
  'tree   @racer_bg000 + CONSTANT((64*64) +32 )
  'sign   @racer_bg000 + CONSTANT(64*64)
  'cart   @racer_bg000 + CONSTANT((64*96)+32)
  'addresses for graphic objects on side of road
  road_left_sprite_a:= @racer_bg000 + CONSTANT((64*64) +32 )'left side of road
  'road_rght_sprite_a:= @racer_bg000 + CONSTANT(64*64)   'right side of road
  road_rght_sprite_a:= @racer_bg000 + CONSTANT((64*96)+32)   'right side of road   

  'setup player sprite
  sprite_graphic[1]:=@racer_car000 
  sprite_x[1]:=(255 + 128 - (car_length /2))
  sprite_y[1]:=141 -4
  sprite_x_olen[1]:=64
  sprite_y_olen[1]:=64
  sprite_x_len[1]:=64
  sprite_y_len[1]:=64
  Calc_Sprite(1)
  
  road_x_off:=255 'start with road centered

  ' Load precalc'd curve LUT 
  repeat kk from 0 to road_scanlines-1     
     curve_lut[kk]:=byte[@Curve_PreCalc+kk]
  ' Load precalc'd depth buffer  
  repeat kk from 0 to road_scanlines-1     
     road_depth[kk]:=byte[@Depth_PreCalc+kk]   
  Calc_Skew(road_x_off) ' calc road angle perspective 'run through everything once 

  'setup default values for sprites
  repeat kk from 2 to 7
   sprite_graphic[kk]:=0 'fill default with nothing
   sprite_x_olen[kk]:=32
   sprite_y_olen[kk]:=32
   sprite_x_olen[kk+sprite_buff_off]:=sprite_x_olen[kk]  'for temp buffer
   sprite_y_olen[kk+sprite_buff_off]:=sprite_y_olen[kk]  'for temp buffer
   sprite_road_val[kk+sprite_buff_off]:=sprite_road_val[kk] 'for temp buffer
   sprite_road_side[kk+sprite_buff_off]:= sprite_road_side[kk] 'for temp buffer
   sprite_graphic[kk+sprite_buff_off]:=sprite_graphic[kk] 'for temp buffer
   sprite_x[kk]:=50   'place sprite off screen
   sprite_y[kk]:=200   'place all sprites off screen
   comp_car_speed[kk]:=0 'stationary object
   sprite_size[kk]:=0 'set size of sprite

  comp_car_speed[7]:=6
  sprite_road_side[7+sprite_buff_off]:=3
  
  Deep_Sprite:=2   
  ' Start of main loop here
  repeat
    repeat while tv_status == 1
    repeat while tv_status == 2
    Main_Loop
    'Check_Debug_Input     'debug stuff
'end of main
'---------------------------------------------
PUB Main_Loop
    'input
   ' Read both gamepad
    temp1 := NES_Read_Gamepad
    if((temp1 & NES0_START) <> 0)
       Pause:=1 'turn on pause
    if((temp1 & NES0_SELECT) <> 0)
       Pause:=0 'turn off pause
    if(Pause<1) 'check if game is paused or not   
     sprite_graphic[1]:=@racer_car000
     if((temp1 & NES0_RIGHT) <> 0)
      sprite_graphic[1]:=@racer_car000 + CONSTANT(64*128)
      road_x_off += car_speed
     if((temp1 & NES0_LEFT) <> 0)
      sprite_graphic[1]:=@racer_car000 + CONSTANT(64*64)
      road_x_off -= car_speed      

     if((temp1 & NES0_B) <> 0)
      car_speed_long-=2
      if(car_speed_long<1)
         car_speed_long+=10
         if(car_speed>0)
          car_speed-=2

     if((temp1 & NES0_A) <> 0)
      car_speed_long+=2
      if(car_speed_long>10)
         car_speed_long-=10
         if(car_speed<10)
           car_speed+=2
     Run_Track             ' handle track events
     if(road_x_off>435)
       road_x_off:=435
     if(road_x_off<75)
       road_x_off:=75
     Grab_Buffer_Spr       'copy sprite and road offset values from previous frame
                           ' and copy to this frame(so it doesn't update info the middle
                           ' of the screen and have a sprite cut in half with new data
     Calc_Skew(road_x_off) ' calc road angle perspective
     Calc_Road_Sprites(2)  ' calc sprite movement with the road
     Calc_Road_Sprites(3)  ' calc sprite movement with the road
     Calc_Road_Sprites(4)  ' calc sprite movement with the road
     Calc_Road_Sprites(5)  ' calc sprite movement with the road
     Calc_Road_Sprites(6)  ' calc sprite movement with the road
    ' Calc_Road_Sprites(7)  ' calc sprite movement with the road(computer car)                   
     Display_Speed(car_speed*10) 'show how fast car is going
     Run_Game_Clock  'handle timer in game     
PUB Grab_Buffer_Spr | n,nn
' All the sprite values are held in a buffer while they are calculated, then for the next
' frame they moved all at once to reduce visual artifacts in sprites. This also handles
' priority so the farthest sprites will be rendered first and drawn over by the closest
' sprites
  n:=Deep_Sprite  'grab the farthest sprite
  repeat nn from 6 to 2  'work backwards since the last sprite is drawn first
   sprite_graphic[nn]:=sprite_graphic[n+sprite_buff_off]
   sprite_x[nn]:=sprite_x[n+sprite_buff_off] 
   sprite_y[nn]:=sprite_y[n+sprite_buff_off]
   sprite_x_len[nn]:=sprite_x_len[n+sprite_buff_off]
   sprite_y_len[nn]:=sprite_y_len[n+sprite_buff_off]
   sprite_x_scale[nn] := sprite_x_scale[n+sprite_buff_off]
   sprite_y_scale[nn] := sprite_y_scale[n+sprite_buff_off]
   sprite_x_clip[nn] := sprite_x_clip[n+sprite_buff_off]
   n+=1                  'advance to next nearest sprite
   if(n>6)
    n-=5
  'buffer for computer car
 {
  nn:=2
  n:=7
  sprite_graphic[nn]:=sprite_graphic[n+sprite_buff_off]
  sprite_x[nn]:=sprite_x[n+sprite_buff_off] 
  sprite_y[nn]:=sprite_y[n+sprite_buff_off]
  sprite_x_len[nn]:=sprite_x_len[n+sprite_buff_off]
  sprite_y_len[nn]:=sprite_y_len[n+sprite_buff_off]
  sprite_x_scale[nn] := sprite_x_scale[n+sprite_buff_off]
  sprite_y_scale[nn] := sprite_y_scale[n+sprite_buff_off]
  sprite_x_clip[nn] := sprite_x_clip[n+sprite_buff_off]
}    
  'grab buffer for road
  repeat nn from 0 to road_scanlines-1
   road_offset[nn]:=road_offset[nn+road_scanlines]  'road perspective           
PUB Run_Track | sel_event  , nn,n2,n3, temp_obj_1, temp_obj_2, temp_obj
'0-straight, 1-enter left turn, 2-exit left turn, 3-enter right turn, 4-exit right turn, 99-reset
    track_event_cnt+=car_speed  'advance on track
    if(track_event_cnt>10)
      track_event_cnt-=10 'reset large counter
      track_event_num+=1  'advance small counter
      if(track_event_num => next_track_event) 'advance to next track event
       track_event_num -= next_track_event
       track_event+=1
       sel_event:=BYTE[@Road_Course+track_event<<1] 'read event
       'reset track to start
       if(sel_event>98) 
         track_event:=0
         sel_event:=BYTE[@Road_Course+track_event]
       'no change
       if(sel_event==0) 
         next_track_event:=30
       'enter left hand turn
       if(sel_event==1) 
         sprite_road_val[0]:=0 'reset location on road
         e_e_turn:=1 '0-don't change, 1-enter turn, 2-exit turn
         curve_direction:=0 'which side road will curve to 0-left, 1-right
         next_track_event:=5000
       'exit left hand turn
       if(sel_event==2) 
         e_e_turn:=2 '0-don't change, 1-enter turn, 2-exit turn
         sprite_road_val[0]:=0 'reset location on road
         next_track_event:=30000
       'enter right hand turn
       if(sel_event==3) 
         sprite_road_val[0]:=0 'reset location on road
         e_e_turn:=1 '0-don't change, 1-enter turn, 2-exit turn
         curve_direction:=1 'which side road will curve to 0-left, 1-right
         next_track_event:=5000
       'exit right hand turn
       if(sel_event==4)  
         sprite_road_val[0]:=0 'reset location on road         
         e_e_turn:=2 '0-don't change, 1-enter turn, 2-exit turn
         next_track_event:=3000
       'find which road side sprites should be on the road
       temp_obj:=BYTE[@Road_Course+track_event<<1+1] 'roadside objects
       'road side objects 0-nothing, 1-tree, 2-sign, 3-cart
       temp_obj_1:=temp_obj
       temp_obj_2:=temp_obj
       temp_obj_1 >>= 4 'grab left side object
       temp_obj_2 &= $0F 'mask off left side object
       repeat n2 from 0 to 1
         if(temp_obj_1==0)
           nn:=0 'nothing
         if(temp_obj_1==1) 'tree
           nn:=@racer_bg000 + CONSTANT((64*64) +32 )
           n3:= 1 'size
         if(temp_obj_1==2) 'sign
           nn:=@racer_bg000 + CONSTANT(64*64)
           n3:=1 'size
         if(temp_obj_1==3) 'cart
           nn:=@racer_bg000 + CONSTANT((64*96)+32)
           n3:=0 'size
         if(n2==0)
          road_left_sprite_a:=nn
          road_left_sprite_s:=n3
          temp_obj_1:=temp_obj_2
         else
          road_rght_sprite_a:=nn
          road_rght_sprite_s:=n3 
    'handle turn force
    if(curve_depth<78) 'make sure we are in a turn
     turn_cnt += car_speed  'grab how far we are on the track
     repeat until turn_cnt <9       
       turn_cnt -=9
       if(curve_direction==0) 'left hand turn
        road_x_off+=(80-curve_depth)>>3   'force of push depending on depth of turn
       else                   'right hand turn
        road_x_off-=(80-curve_depth)>>3   'force of push depending on depth of turn

    'scroll background to turns
    nn:=80-curve_depth  'find how deep curve is
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
    if(e_e_turn==1) 'enter turn
         Calc_EE_Turn
         curve_depth:=79 - sprite_y_len[0]
         if(curve_depth<2)                  
          e_e_turn:=0 'completely in turn
          next_track_event:=0 'move to next event
    if(e_e_turn==2) 'exit turn
         Calc_EE_Turn
         curve_depth:= sprite_y_len[0]
         if(curve_depth>78)                  
          e_e_turn:=0 'completely out of turn
          next_track_event:=0 'move to next event          

PUB Calc_EE_Turn | kk, temps1, temp_scan_l, temp_road_val      
   'caclulating enter/exit turn
   temp_road_val:= sprite_road_val[0] 'road value for turn
   temp_road_val+=car_speed   'move object forward with speed

   'find the scanline to place the sprite on
   repeat kk from 0 to  road_scanlines-1
     if(temp_road_val => byte[@road_depth_sp + kk])
       temp_scan_l:=kk
   'write road value
   sprite_road_val[0]:=temp_road_val
   'find value of turn
   sprite_y_len[0]:= temp_scan_l    

'---------------------------------------------           
PUB Calc_Road_Sprites(sp_number) | kk, temps1, temp_scan_l, temp_road_val
   sp_number+=7 'place all sprite info a temp buffer
   temp_road_val:= sprite_road_val[sp_number]
    temp_road_val+=car_speed   'move object forward with speed
   'computer controlled car
 {
   if(sp_number> CONSTANT(6+7))   
    temp_road_val-=comp_car_speed[sp_number-7] ' move sprite up and down road(or not at all)
    'reset car if it drives off in distance or is passed
    if(temp_road_val<0)
     temp_road_val+=205
    if(temp_road_val>205)
     temp_road_val-=205
    'debug
    sprite_graphic[sp_number]:=@racer_bg000 + CONSTANT((64*96))
   'road side stationary sprite
   else
}   
   'if the object drives off into the horizon, move it up closer on the road
    'we need to reset sprite
    if(temp_road_val>205)       'if object goes past visible screen(behind)
     temp_road_val-=190'move back to far end of road this is 190 instead of 205
                      'because beyond 190 sprites are too small to be rendered          
    'start it at far end of track
     temp_road_val:= byte[@road_depth_sp] + temp_road_val
     Deep_Sprite:=sp_number-7 'set this as the farthest sprite
     'make sure we evenly divide road side objects
     if(road_prior_side==0) 'if last newest object was on left side of road
      road_prior_side:=1   'make newest on right side of road
      sprite_graphic[sp_number]:=road_rght_sprite_a  'assign the correct graphic to new object
      sprite_size[sp_number-7]:=road_rght_sprite_s 'grab size of sprite
     else
      road_prior_side:=0
      sprite_graphic[sp_number]:=road_left_sprite_a 'assign the correct graphic to new object     
      sprite_size[sp_number-7]:=road_left_sprite_s 'size of sprite
     sprite_road_side[sp_number]:=road_prior_side 'switch road side object
   repeat kk from 0 to road_scanlines-1
     if(temp_road_val => byte[@road_depth_sp + kk])
       temp_scan_l:=kk
   sprite_road_val[sp_number]:=temp_road_val
   'use lookup to match road scanline number to find the horizontal and verticle
   'size to scale the sprite
   
   sprite_y_len[sp_number]:= byte[@road_gfx +(temp_scan_l*7+2)]  
   sprite_x_len[sp_number]:=sprite_y_len[sp_number]
   if(sprite_size[sp_number-7]==0) 'if smaller sprite, half the size
    sprite_y_len[sp_number]>>=1
   if(sprite_size[sp_number-7]<2)'if smaller sprite, half the size
    sprite_x_len[sp_number]>>=1
   'choose side of road to place sprite
   if(sprite_road_side[sp_number]==0) 'left side of road
     sprite_x[sp_number]:= byte[@road_spite_lut_l +temp_scan_l] - sprite_x_len[sp_number]
   if(sprite_road_side[sp_number]==1) 'right side of road
    sprite_x[sp_number]:= word[@road_spite_lut_r +(temp_scan_l<<1)]      
   if(sprite_road_side[sp_number]==2) 'left side on road
     sprite_x[sp_number]:= byte[@road_spite_lut_l +temp_scan_l] + sprite_x_len[sp_number] >>1
     sprite_x[sp_number]+= byte[@road_gfx +(temp_scan_l *7 +1)]
   if(sprite_road_side[sp_number]==3) 'left side on road
     sprite_x[sp_number]:= word[@road_spite_lut_r +(temp_scan_l<<1)] - sprite_x_len[sp_number]
     sprite_x[sp_number]-= byte[@road_gfx +(temp_scan_l *7 +1)] + sprite_x_len[sp_number]>>1      
   'skew sprite along with road prespective
   sprite_x[sp_number]+= road_offset[temp_scan_l+road_scanlines] 
   'after finding road scanline, push up sprite so bottom of sprite is on the scanline
   if(sprite_graphic[sp_number]==0) 'if there is no sprite
    sprite_y[sp_number]:=210 'push sprite off screen
   else  'else find the scanline to place the sprite on 
    sprite_y[sp_number]:=temp_scan_l + 120 - sprite_y_len[sp_number]
   Calc_Sprite(sp_number)


PUB Calc_Skew(RoadOff) | k,kk,pp, curve_calc, pixel_indent
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
  curve_calc := curve_depth 'grab current curve depth    
  road_x_cntr := CONSTANT(255 - 23)'reset pixel counter 255 is the center, 23  - center road
  RoadLine_X_Cntr := 0 'reset counter
  ' multiply by 100 to give percision (100 = 1.00 pixels) 
  ' multiply by 100, use bit shifting (64 + 32 + 4 = 100)
  k := RoadLine_X << 2  '*4
  pp := RoadLine_X << 5 '*32
  kk := RoadLine_X << 6 '*64
  RoadLine_X:= kk + pp + k
  RoadLine_X>>=6 ' divide by 64  (we are counting from 64 scanlines)
  'now we have a pixel value to add for every scanline

  ' run through all road scanlines
  repeat kk from 0 to CONSTANT(road_scanlines-1)
    road_depth[kk]+=car_speed   'scroll the road
    if(road_depth[kk]>79)
       road_depth[kk]-=80
      
    RoadLine_X_Cntr+=RoadLine_X 'counter for skewing road
    'if counter is greater than 99, then we indent a pixel
    repeat while (RoadLine_X_Cntr > 99)
      road_x_cntr+=pixel_indent
      RoadLine_X_Cntr-=100 'subtract from counter
    k:=road_x_cntr 'grab perspective skew
    if(curve_calc<80)
     if(curve_direction) 
       k+=curve_lut[curve_calc]  'add in curve for turn(if there is one)
     else
       k-=curve_lut[curve_calc]  'add in curve for turn(if there is one)
     curve_calc+=1
    road_offset[kk+road_scanlines]:=k 'add x offset

PUB Calc_Sprite(sprite_numb)
'calc scaled size of sprite
  sprite_x_scale[sprite_numb] := sprite_x_olen[sprite_numb] *512 / sprite_x_len[sprite_numb]
  sprite_y_scale[sprite_numb] := sprite_y_olen[sprite_numb] *512 / sprite_y_len[sprite_numb]
'check clipping on left side of screen
  if(sprite_x[sprite_numb]<255) 'moves off left of screen, clip sprite
      sprite_x_clip[sprite_numb]:= (256 - sprite_x[sprite_numb]) * sprite_x_scale[sprite_numb]
  else
    sprite_x_clip[sprite_numb]:=0
PUB Check_Debug_Input 
{
    'input
   ' Read both gamepad
    temp1 := NES_Read_Gamepad
    if((temp1 & NES0_RIGHT) <> 0)
      sprite_x[1]+=1
     Calc_Sprite(1)
        
    if((temp1 & NES0_LEFT) <> 0)
      sprite_x[1]-=1
      Calc_Sprite(1)
                             
    if((temp1 & NES0_DOWN) <> 0)
       sprite_y[1] += 1

    if((temp1 & NES0_UP) <> 0)
      sprite_y[1] -= 1       

    if((temp1 & NES0_B) <> 0)
     sprite_x_len[1]-= 1
     sprite_y_len[1]-= 1
      Calc_Sprite(1)     

    if((temp1 & NES0_A) <> 0)
     sprite_x_len[1]+= 1
     sprite_y_len[1]+= 1
      Calc_Sprite(1)         
}
PUB Display_Clock(i) | t, str
' does an sprintf(str, "%05d", i); job
str:=1
repeat t from 0 to 1
  BYTE [@Test_Text+5+str] := 48+(i // 10)
  i/=10
  str--
PUB Display_Speed(i) | t, str
' does an sprintf(str, "%05d", i); job
str:=2
repeat t from 0 to 2
  BYTE [@Test_Text+9+str] := 48+(i // 10)
  i/=10
  str--
PUB  Run_Game_Clock
  Game_Timer_Tic+=1
  if(Game_Timer_Tic>30)
   Game_Timer_Tic:=0
   Game_Timer-=1
   if(Game_Timer<0)
      Game_Timer:=99
   Display_Clock(Game_Timer)        
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
Test_Text
'text'1234567890123456' 16 bytes               
byte "Time:xx  xxx mph"
'byte "Hydra Racer Demo"

'byte 1 - course, byte 2 - side objects
 'course
'0-no change, 1-enter left turn, 2-exit left turn, 3-enter right turn, 4-exit right turn, 99-reset
'road side  (built out of 2 hex digits, one for left side, one for right side)
'objects 0-nothing, 1-tree, 2-sign, 3-cart
Road_Course
BYTE 0,$13, 1,$02, 0,$12, 2,$11, 0,$13, 0,$12, 0,$01, 3,$11 ,0,$20, 4,$11, 99
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
road_spite_lut_l 
BYTE 149 ,147 ,145 ,143 ,141 ,139 ,137 ,135 ,134 ,132 ,130 ,128 ,126 ,124 ,122 ,120  
BYTE 119 ,117 ,115 ,113 ,111 ,109 ,107 ,105 ,104 ,102 ,100 , 98 , 96 , 94 , 92 , 90  
BYTE  89 , 87 , 85 , 83 , 81 , 79 , 77 , 75 , 74 , 72 , 70 , 68 , 66 , 64 , 62 , 60  
BYTE  59 , 57 , 55 , 53 , 51 , 49 , 47 , 45 , 44 , 42 , 40 , 38 , 36 , 34 , 32 , 30  
BYTE  29 , 27 , 25 , 23 , 21 , 19 , 17 , 15 , 14 , 12 , 10 ,  8 ,  6 ,  4 ,  2 ,  0  
'right side of road
road_spite_lut_r
WORD 158 ,160 ,162 ,164 ,166 ,168 ,170 ,172 ,173 ,175 ,177 ,179 ,181 ,183 ,185 ,187  
WORD 188 ,190 ,192 ,194 ,196 ,198 ,200 ,202 ,203 ,205 ,207 ,209 ,211 ,213 ,215 ,217  
WORD 218 ,220 ,222 ,224 ,226 ,228 ,230 ,232 ,233 ,235 ,237 ,239 ,241 ,243 ,245 ,247  
WORD 248 ,250 ,252 ,254 ,256 ,258 ,260 ,262 ,263 ,265 ,267 ,269 ,271 ,273 ,275 ,277  
WORD 278 ,280 ,282 ,284 ,286 ,288 ,290 ,292 ,293 ,295 ,297 ,299 ,301 ,303 ,305 ,307

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
  
'64x192  graphics data(background, sign and tree sprites)

racer_bg000 long $2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B
        long $2B2B2B2B,$2B2B2B2B,$048CFC2B,$2B045CEC,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$04042B2B,$04040404,$2B040404,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B
        long $2B2B2B2B,$05050505,$05050505,$04050505,$2B2B2BFC,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$052B2B2B,$05050505,$05050505,$05050505,$2B2B8C04,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B
        long $05040404,$05050505,$05050505,$05050505,$2BFC0505,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$05042B2B,$05050505,$05050505,$05050505,$2B040505,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B
        long $05050404,$05050505,$05050505,$05050505,$2BFC0505,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$FC052B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$8CFC2B2B,$05050504,$05050505,$05050505,$05050505,$7C04FC04,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$0505FC2B,$2B2B8C05,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$042B2B2B
        long $05050505,$05050505,$05050505,$04050505,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$0403032B,$05050505,$05050505,$2B2BFC04,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$042B2B2B,$05050505,$05050505,$05050505,$04050505,$2B2B0404,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$04042B03,$05FC0404,$05050505,$8C040505,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$FC2B2B2B
        long $0505048C,$05050505,$05050505,$2B050505,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$042B2B2B,$048CFC04,$05050505,$04050505,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$0504042B,$05050505,$05050505,$2B2B0505,$2B2B2B2B,$3B2B032B,$3B3C2C3B,$2B2B2B2B,$042BFC2B,$05040404,$05050505,$04050505,$2B04FC04,$2B2B2B2B,$04FC2B2B,$2B2B2B2B
        long $04042B2B,$04040404,$2B040404,$2B2B2B2B,$2B2B2B2B,$042B2B03,$04040404,$047C3B04,$7C04047C,$05050504,$05050505,$05050505,$04050405,$2B2B2B04,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$7C3C042B,$05050404,$04040404,$04050505,$05050504,$05050505,$05050505,$04050505,$04050505,$2B2B2B04,$2B2B2B2B
        long $2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$3B2B2B2B,$04040404,$04040405,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$0404FC05,$2B2B2B04,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$04048C3B,$05040404,$04040505,$05050504,$05050505,$05050505,$05050505,$05050505,$05050405,$2B2B0405
        long $2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$0404042B,$05050404,$04050505,$05050504,$05050405,$05050505,$05050505,$05050505,$05040505,$2B040405,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$0404FC2B,$05040505,$04040504,$04040404,$05040404,$05050505,$05050505,$05050505,$04040505,$04050404
        long $2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$04042B2B,$04040404,$04040404,$040404FC,$05050504,$05050505,$05050505,$05050505,$04050505,$05050404,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$04050404,$2BFC0504,$2B2B2B2B,$048C2B2B,$FC0404FC,$2B2B048C,$04048C2B,$05040504,$05050505,$05050505,$05050505,$05050505,$04040404
        long $2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$05050505,$8C050505,$2B2B5C04,$2B2BFC2B,$2B047C04,$2B2B2B2B,$045C04FC,$04040404,$05050505,$05040505,$05050505,$04040405,$04040404,$2B2B2B2B,$2B2B2B2B,$042B2B2B,$05050505,$05050505,$2B040505,$2B2B2B2B,$2B2BFC2B,$5C2B2B2B,$FC8CFC8C,$04047C04,$05040504,$05050505,$8CFC0404,$FC040504,$2B2B2B04
        long $2B2B2B2B,$2B8CFC2B,$040404FC,$05050504,$05050505,$04050505,$2B2B2BFC,$2B2B2B2B,$2B2B2B8C,$7CFC5C04,$040404FC,$04040404,$04040405,$2B2B2BFC,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$042B2B2B,$04040404,$05050504,$05050505,$05050505,$04040405,$2B042B7C,$2BFC2B2B,$FC7C04FC,$FC7CFC8C,$FCEC048C,$045C048C,$2B2B2B04,$2B2B2B2B,$2B2B2B2B
        long $2B2B2B2B,$0404042B,$04040405,$05050504,$05050505,$05050505,$04040405,$2B2B2BFC,$2B7C045C,$7A7A7A6C,$7A7A7A7A,$5C046B6B,$EC04EC04,$2B2BFC7C,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$7CFC7C2B,$04050504,$04050404,$05050505,$05050505,$05050505,$047C2B04,$7A7A6CFC,$7A7A7A7A,$7A7A7A7A,$6B6B7A7A,$5C6B7A6B,$7C048C04,$2B2B2B04,$2B2B2B2B
        long $2B2B2B2B,$2B2B2B2B,$04040404,$04040404,$05050404,$05050505,$04050405,$7A5C04FC,$7A7A7A7A,$7A7A7A7A,$7A7A7A7A,$7A7A7A7A,$7A7A7A7A,$045CFC6B,$2B2B5CEC,$2B2B2B2B,$2B2B2B2B,$2B2B2B2B,$040404FC,$04040404,$04040404,$04050505,$7C040404,$7A7A7A6C,$7A7A7A7A,$7A7A7A7A,$7A7A7A7A,$7A7A7A7A,$7A7A697A,$046B7A7A,$04050404,$2B2B2B2B
        long $2B2B2B2B,$042B2B2B,$037C0404,$8CFC5A03,$05040504,$FC040404,$7A69695B,$7A7A7A7A,$7A7A697A,$7A7A7A7A,$697A7A7A,$7A7A7A69,$7A696969,$7A7A7A7A,$0505056B,$2B2B2B04,$2B2B2B2B,$2B2B2B2B,$6B696969,$6B7A6B03,$8CFC6B7A,$69697CFC,$7A7A7A7A,$7A7A7A7A,$7A7A7A7A,$697A7A7A,$69696969,$69696969,$69696969,$7A7A7A69,$04FC7A7A,$2B2B2B04
        long $2B2B2B2B,$6B7A032B,$6B6B7A6B,$6B7A7A7A,$7A697A6B,$7A7A7A69,$697A697A,$7A69697A,$7A7A7A7A,$7979797A,$69697979,$69796969,$69797979,$7A7A6969,$7A7A7A7A,$2B2B2B2B,$2B2B2B2B,$6B7A6969,$6B6B7A6B,$7A6B6B6B,$7A7A7A7A,$7A7A7A7A,$7A69697A,$69697A7A,$7A7A7A7A,$6969697A,$69697979,$69696969,$69797979,$7A7A6969,$7A7A7A7A,$2B2B697A
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
        long $79796979,$69697979,$7979796B,$69697969,$6B6C6B6B,$7A796C6B,$69697A6B,$79796B69,$79797979,$79797969,$79696B69,$79797979,$6B697979,$79797979,$79797979,$79797979,$79797969,$7A796969,$6B696B69,$6B6B7979,$6C7A6969,$7A7A696B,$6B796B6B,$696B6969,$79797969,$69696969,$79797979,$79797979,$79797979,$79797969,$79797979,$79797979
        long $7979696B,$69696979,$796B7A69,$6B6B6979,$7A69697A,$69696B69,$7A796969,$6969696B,$6969796B,$69697969,$79796969,$79697969,$79797979,$79797979,$79797979,$79797979,$79796B69,$6B6B7A69,$7979796B,$69696C6B,$69696B6B,$696B6B7A,$7A6B6B6B,$6969697A,$79796969,$79797979,$79797969,$79697979,$79797979,$79797979,$79797979,$79797979
        long $79697A79,$6C6B6C6B,$6979696C,$796B696B,$7A6B6B69,$6B797969,$7A7A6B69,$6979797A,$7979796B,$79797969,$7979797A,$79797979,$79797979,$79797979,$79797979,$79797979,$696B6B6B,$6C6B6B69,$7979696C,$7979696B,$69796979,$79797979,$7A796B69,$79796979,$79797979,$79797969,$79697979,$69697979,$6C6C6C6C,$69696969,$6C6C7A7A,$79797969
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$6A6A6A00,$6A6A6A6A,$0000006A,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$6A6A0069,$6A69006A,$6B6B6B6B,$6B6B6B6B,$6A6A6B6B,$00006A6A,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$6B6B6A69,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$006A6B6B,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$6B6A6B6A,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6A6B6B6B,$00006A6A,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$6A690000,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6A6B6B6B,$0000006A,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$6B6A6900,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6A,$6A6B6B6B,$6B6B6A6B,$0069696A
        long $05050300,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$00030505,$6B6A6A6A,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6A6A6B6B,$6A6B6A6B,$696A6A6B,$05050503,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$03050505,$6B6B6A6A,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6A6B,$6A6B6B6B
        long $05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$6B6B6B6A,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6A6B,$6B6B6B6B,$6B6B6B6B,$6A6B6A6A,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$6B6B6B6A,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6A6B6B,$6B6B6B6B,$6A6B6B6B
        long $04050505,$03030304,$02020202,$02020202,$02020202,$03020202,$04040303,$05050505,$6B6B6B6A,$6B6B6A6B,$6B6B6B6B,$6A6B6B6B,$6B6B6B6B,$6B6B6B6B,$6B6B6B6B,$6A6B6B6B,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$6B6B6B6B,$6B6A6A6B,$6B6B6A6A,$6B6B6B6B,$6B6B6B6A,$6B6B6A6A,$6B6A6A6B,$6B6B6B6B
        long $05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$6B6B6B6B,$6B6B6B6B,$6A6B6B6A,$6A6B6B6B,$6B6B6B6A,$6B6B6A6A,$6A6A6B6B,$6A6B6B6A,$02040505,$04020404,$04050402,$02020402,$02040302,$05030202,$03020203,$05050505,$6B6B6B6A,$6B6B6B6B,$6A6A6B6B,$696A6A6B,$6B6B6A6A,$6A6A6A6B,$6A6B6B6A,$6A6A6B6B
        long $02040505,$04020404,$03050302,$04020402,$02040203,$04020404,$02040402,$05050504,$6B6B6B6A,$6B6B6B6B,$6B6B6A6B,$6A6A6A6A,$6A6B6A6B,$6A6B6A6B,$6A6A6B6A,$6A6A6A6B,$02040505,$04020404,$02030203,$04020403,$02040204,$04020404,$02040402,$05050504,$6A6B6A6A,$6B6A6B6B,$6A6A6B6B,$6B6A6B6B,$6A6A6B6B,$6B6B6A6A,$6A6A6A6A,$6A6A6A6A
        long $02040505,$04020202,$03020305,$04020405,$02040204,$04030202,$02020202,$05050504,$6A6A6B6A,$6A6B6A6B,$6A6B6B6A,$6A6B6B6B,$6A6A6A6B,$6B6A6A6B,$6A6A6A6A,$6B6A6A6B,$02040505,$04020404,$04020405,$04020405,$02040203,$04020404,$02040402,$05050504,$6B6B6B6A,$6A6A6B6A,$6B6B6A6A,$6B6B6B6B,$6B6B696A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A
        long $02040505,$04020404,$04020405,$02020405,$02040302,$04020404,$02040402,$05050504,$6B6B6B6B,$6A6B6B6B,$6B6B6B6A,$6A6A6A6B,$6A6A6A6A,$6A6A6A6A,$6B6A6A6B,$6A6A6B6A,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$6B6A6A6B,$6B6B6B6B,$6B6B6B6B,$6A6A6A6A,$696A6A69,$6A6A6A6A,$6A6A6A6A,$6A6A6B6A
        long $05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$6B6A6A69,$6A6A6A6A,$6A6A6A6A,$6A6A6A6B,$6A6A6A69,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$04050505,$03030304,$02020202,$02020202,$02020202,$03020202,$04040303,$05050505,$6A6A6A6B,$6A6A6A6A,$6A6A6A6A,$6A6B6A6A,$6A6A6A6A,$696A696A,$6A6A6A69,$6A6B6A6A
        long $05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$6A6A6A6A,$6A6A6A6A,$6A696A6A,$696A6A6A,$6A6A696A,$6A69696A,$6A6A6A6A,$6A6A6A6A,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$6A6B6A6B,$6A696A6A,$6A6A6A6A,$696A6A69,$69696969,$6A6A6969,$6A696A69,$696A6A6A
        long $05050503,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$03050505,$6A6A6A69,$6A6A6A6A,$6A6A6A6A,$69696969,$6A6A6A69,$696A6A6A,$6A6A696A,$006A6A6A,$05050300,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$00030505,$6A6A6B00,$6A6A6A6A,$6A6A6A6A,$6A696A6A,$696A6A6A,$69696969,$6A6A6A69,$00006A6A
        long $00000000,$03030300,$00000000,$00000000,$00000000,$00000000,$00030303,$00000000,$6A6A0000,$6A6A696A,$6969696A,$AA99AA69,$69AAAAAA,$6A6A6969,$6A6A6A6A,$0000696A,$00000000,$04030400,$00000000,$00000000,$00000000,$00000000,$00040304,$00000000,$69000000,$69696969,$69696969,$AAAAAAAA,$6A69AAAA,$6969696A,$696A6A69,$00000069
        long $00000000,$04040400,$00000000,$00000000,$00000000,$00000000,$00040404,$00000000,$00000000,$00000000,$00000000,$AAAAAA00,$6999AAAA,$69696969,$00000069,$00000000,$00000000,$04040402,$02020202,$02020202,$02020202,$02020202,$02040404,$00000000,$00000000,$00000000,$00000000,$AAAAAA00,$0000AA99,$00000000,$00000000,$00000000
        long $02020000,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00000002,$00000000,$02020200,$02020202,$AAAA9902,$0202AA99,$02020202,$02020202,$00000000,$00000000,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00000000,$00000000,$02020200,$02020202,$02020202,$02020202,$02020202,$02020202,$00000000
        long $00000000,$02000000,$05050503,$05050505,$05050505,$03050505,$00000002,$00000000,$00000000,$00000000,$00000000,$C9000000,$CACACACA,$CABABBAB,$CACACACA,$00000000,$00000000,$03000000,$03030303,$03030303,$03030303,$03030303,$00000003,$00000000,$00000000,$00000000,$CAC90000,$CACA03CA,$ABCACACA,$CACABABB,$C9CABACA,$000000BA
        long $00000000,$03020000,$00000101,$00000000,$00000000,$01010000,$00000203,$00000000,$00000000,$C9000000,$CACACACA,$CACACA03,$ABCACABA,$CACACABB,$C8C9CACA,$0000BAC9,$00000000,$02030000,$00010101,$00000000,$00000000,$01010100,$00000302,$00000000,$00000000,$CACAC900,$CABACACA,$CACACA03,$BBABCABA,$CACACABA,$C8C8C9CA,$00BAC9C8
        long $00000000,$01030000,$01010101,$01010101,$01010101,$01010101,$00000301,$00000000,$00000000,$CACACAC9,$03CABACA,$BACACACA,$CABBABCA,$CACACACA,$C8C8C8C9,$BAC9C8C8,$00000000,$01020200,$01010101,$01010101,$01010101,$01010101,$00020201,$00000000,$C9000000,$CABACACA,$CA03CACA,$BACACACA,$CABABBAB,$C9CACACA,$0000C8C8,$C9000000
        long $00000000,$01010302,$01010101,$01010101,$01010101,$01010101,$02030101,$00000000,$CACACA00,$CACABACA,$CACA03CA,$C9C9C9C9,$C9C9C9C9,$C9C9C9C9,$0000C8C8,$00000000,$00000000,$02020302,$02020202,$02020202,$02020202,$02020202,$02030202,$00000000,$C9C9C900,$C8C9C9C9,$C9C8C8C8,$000000C8,$00AAAA00,$00000000,$0000C8C9,$00000000
        long $02000000,$04050503,$04040404,$04040404,$04040404,$04040404,$03050504,$00000002,$00000000,$00000000,$C9000000,$AA0000C8,$AAAAAAAA,$000000AA,$0000C8C9,$00000000,$02000000,$05040505,$05050505,$05050505,$05050505,$05050505,$05050405,$00000002,$00000000,$00000000,$C9000000,$000000C8,$98ACAB98,$00000000,$0000C8C9,$00000000
        long $05020000,$05030405,$05050505,$05050505,$05050505,$05050505,$05040305,$00000205,$00000000,$00000000,$C9000000,$000000C8,$98ABAC98,$00000000,$0000C8C9,$00000000,$05050200,$05050305,$05050505,$05050505,$05050505,$05050505,$05030505,$00020505,$00000000,$00000000,$C9000000,$3B3900C8,$3B3B3B3B,$0099BC3B,$0000C8C9,$00000000
        long $05050302,$05050305,$05050505,$05050505,$05050505,$05050505,$05030505,$02030505,$00000000,$00000000,$C9000000,$3B3B39C8,$3B3BAB8A,$9A003948,$0000C8C9,$00000000,$05040403,$05050305,$05050505,$05050505,$05050505,$05050505,$05030505,$03040405,$00000000,$00000000,$C9000000,$993B39C8,$989999A8,$AC78CA02,$0000C8C9,$00000000
        long $04C9C903,$05050305,$05050505,$05050505,$05050505,$05050505,$05030505,$03C9C904,$00000000,$00000000,$C9000000,$999900CB,$999AAA99,$9B9A9B00,$0000C89C,$00000000,$04C9C903,$04040304,$04040404,$04040404,$04040404,$04040404,$04030404,$03C9C904,$00000000,$00000000,$DC9B049B,$B8AAABCB,$88A8ABA9,$BABAC9AC,$0000C89C,$00000000
        long $04BAC903,$05050503,$05050505,$05050505,$05050505,$05050505,$03050505,$03C9BA04,$00000000,$CC000000,$02DC0C03,$A8A9B9CA,$B8C8BAB8,$BAAAAAB9,$CACABBBA,$0000CACA,$04BABA03,$05050503,$05050505,$04050505,$05050504,$05050505,$03050505,$03BABA04,$00000000,$EC000000,$E81BECCC,$DBDCDC48,$BAC898D8,$B9C8B8B8,$CACA9CBA,$000000CA
        long $04AABAC9,$05050503,$05050505,$04050505,$05050504,$05050505,$03050505,$C9BAAA04,$00000000,$CA000000,$CA99CACA,$CA0202C8,$A90202D9,$AB9CBAB9,$CACACAB9,$00000004,$04AABABA,$05050503,$05050505,$05050505,$05050505,$05050505,$03050505,$BABAAA04,$00000000,$89890000,$02AB0202,$5A028B02,$BA020102,$BAC9A9D8,$CBCACACA,$00000005
        long $04AABAAA,$04040203,$04040404,$04040404,$04040404,$04040404,$03020404,$AABAAA04,$00000000,$99AC8B00,$999AD899,$49498A02,$5A020201,$CACB8B9C,$0403CACA,$00000005,$03040403,$05050402,$04050505,$03030303,$03030303,$05050504,$02040505,$03040403,$00000000,$8C998A00,$BAAABAB9,$9B99599A,$DA01999A,$8C9B8C8C,$040503CB,$00000005
        long $02040402,$04040404,$03040404,$04040404,$04040404,$04040403,$04040404,$02040402,$00000000,$A98C0000,$AAB8B9B8,$A9A888AA,$9B9A9A00,$8C8CAAAA,$04050405,$00000005,$03030303,$03030303,$02030303,$04040404,$04040404,$03030302,$03030303,$03030303,$00000000,$8C980000,$A8A9B9A9,$A89AA999,$8AA99CAA,$8CA88C8C,$04050405,$00000005
        long $02020202,$02020202,$01020202,$04040404,$04040404,$02020201,$02020202,$02020202,$00000000,$01000000,$B8B8B801,$8CA9B8A8,$AAAA9CB8,$048CA9AA,$04050405,$00000005,$02020201,$02020202,$02020202,$01010101,$01010101,$02020202,$02020202,$01020202,$00000000,$00000000,$B8AACA01,$A9010401,$8CA9AAA9,$04AAB8AA,$04050405,$00000003
        long $01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$00000000,$00000000,$B8C90489,$99030403,$02B8A88C,$0499A999,$03050405,$00000000,$03030303,$03030303,$03030303,$03030303,$03030303,$03030303,$03030303,$03030303,$00000000,$02020200,$04030402,$04030403,$04AA0403,$04039A03,$AB030405,$00000000
        long $03030302,$03030303,$03030303,$03030303,$03030303,$03030303,$03030303,$02030303,$02000000,$02020202,$02AB0202,$04030402,$04030403,$04030403,$ABAA0305,$00000002,$04040102,$04040404,$04040404,$04040404,$04040404,$04040404,$04040404,$02010404,$00000000,$02020000,$02AB0202,$02020202,$04020202,$04030403,$AB02AA03,$00000002
        long $01010102,$01010101,$02020202,$02020202,$02020202,$02020202,$01010101,$02010101,$00000000,$00000000,$02020202,$02020202,$02020202,$04AA0202,$020202AA,$00000000,$01010200,$02010101,$02020202,$02020202,$02020202,$02020202,$01010102,$00020101,$00000000,$00000000,$00000000,$00000000,$02020202,$AB020202,$00020202,$00000000
        long $08080808,$18181818,$28282828,$38383838,$58484848,$68585858,$78686868,$88787878,$98988888,$A8A89898,$B8B8A8A8,$C8C8B8B8,$D8D8D8C8,$E8E8E8D8,$F8F8F8E8,$010101F8,$08080808,$18181818,$28282828,$38383838,$58484848,$68585858,$78686868,$88787878,$98988888,$A8A89898,$B8B8A8A8,$C8C8B8B8,$D8D8D8C8,$E8E8E8D8,$F8F8F8E8,$010101F8
        long $08080808,$18181818,$28282828,$38383838,$58484848,$68585858,$78686868,$88787878,$98988888,$A8A89898,$B8B8A8A8,$C8C8B8B8,$D8D8D8C8,$E8E8E8D8,$F8F8F8E8,$010101F8,$08080808,$18181818,$28282828,$38383838,$58484848,$68585858,$78686868,$88787878,$98988888,$A8A89898,$B8B8A8A8,$C8C8B8B8,$D8D8D8C8,$E8E8E8D8,$F8F8F8E8,$010101F8
        long $08080808,$18181818,$28282828,$38383838,$58484848,$68585858,$78686868,$88787878,$98988888,$A8A89898,$B8B8A8A8,$C8C8B8B8,$D8D8D8C8,$E8E8E8D8,$F8F8F8E8,$010101F8,$08080808,$18181818,$28282828,$38383838,$58484848,$68585858,$78686868,$88787878,$98988888,$A8A89898,$B8B8A8A8,$C8C8B8B8,$D8D8D8C8,$E8E8E8D8,$F8F8F8E8,$010101F8
        long $08080808,$18181818,$28282828,$38383838,$58484848,$68585858,$78686868,$88787878,$98988888,$A8A89898,$B8B8A8A8,$C8C8B8B8,$D8D8D8C8,$E8E8E8D8,$F8F8F8E8,$010101F8,$08080808,$18181818,$28282828,$38383838,$58484848,$68585858,$78686868,$88787878,$98988888,$A8A89898,$B8B8A8A8,$C8C8B8B8,$D8D8D8C8,$E8E8E8D8,$F8F8F8E8,$010101F8
        long $08080808,$18181818,$28282828,$38383838,$58484848,$68585858,$78686868,$88787878,$98988888,$A8A89898,$B8B8A8A8,$C8C8B8B8,$D8D8D8C8,$E8E8E8D8,$F8F8F8E8,$010101F8,$08080808,$18181818,$28282828,$38383838,$58484848,$68585858,$78686868,$88787878,$98988888,$A8A89898,$B8B8A8A8,$C8C8B8B8,$D8D8D8C8,$E8E8E8D8,$F8F8F8E8,$010101F8
        long $08080808,$18181818,$28282828,$38383838,$58484848,$68585858,$78686868,$88787878,$98988888,$A8A89898,$B8B8A8A8,$C8C8B8B8,$D8D8D8C8,$E8E8E8D8,$F8F8F8E8,$010101F8,$08080808,$18181818,$28282828,$38383838,$58484848,$68585858,$78686868,$88787878,$98988888,$A8A89898,$B8B8A8A8,$C8C8B8B8,$D8D8D8C8,$E8E8E8D8,$F8F8F8E8,$010101F8
        long $09090909,$19191919,$29292929,$39393939,$59494949,$69595959,$79696969,$89797979,$99998989,$A9A99999,$B9B9A9A9,$C9C9B9B9,$D9D9D9C9,$E9E9E9D9,$F9F9F9E9,$020202F9,$09090909,$19191919,$29292929,$39393939,$59494949,$69595959,$79696969,$89797979,$99998989,$A9A99999,$B9B9A9A9,$C9C9B9B9,$D9D9D9C9,$E9E9E9D9,$F9F9F9E9,$020202F9
        long $09090909,$19191919,$29292929,$39393939,$59494949,$69595959,$79696969,$89797979,$99998989,$A9A99999,$B9B9A9A9,$C9C9B9B9,$D9D9D9C9,$E9E9E9D9,$F9F9F9E9,$020202F9,$09090909,$19191919,$29292929,$39393939,$59494949,$69595959,$79696969,$89797979,$99998989,$A9A99999,$B9B9A9A9,$C9C9B9B9,$D9D9D9C9,$E9E9E9D9,$F9F9F9E9,$020202F9
        long $09090909,$19191919,$29292929,$39393939,$59494949,$69595959,$79696969,$89797979,$99998989,$A9A99999,$B9B9A9A9,$C9C9B9B9,$D9D9D9C9,$E9E9E9D9,$F9F9F9E9,$020202F9,$09090909,$19191919,$29292929,$39393939,$59494949,$69595959,$79696969,$89797979,$99998989,$A9A99999,$B9B9A9A9,$C9C9B9B9,$D9D9D9C9,$E9E9E9D9,$F9F9F9E9,$020202F9
        long $09090909,$19191919,$29292929,$39393939,$59494949,$69595959,$79696969,$89797979,$99998989,$A9A99999,$B9B9A9A9,$C9C9B9B9,$D9D9D9C9,$E9E9E9D9,$F9F9F9E9,$020202F9,$09090909,$19191919,$29292929,$39393939,$59494949,$69595959,$79696969,$89797979,$99998989,$A9A99999,$B9B9A9A9,$C9C9B9B9,$D9D9D9C9,$E9E9E9D9,$F9F9F9E9,$020202F9
        long $09090909,$19191919,$29292929,$39393939,$59494949,$69595959,$79696969,$89797979,$99998989,$A9A99999,$B9B9A9A9,$C9C9B9B9,$D9D9D9C9,$E9E9E9D9,$F9F9F9E9,$020202F9,$09090909,$19191919,$29292929,$39393939,$59494949,$69595959,$79696969,$89797979,$99998989,$A9A99999,$B9B9A9A9,$C9C9B9B9,$D9D9D9C9,$E9E9E9D9,$F9F9F9E9,$020202F9
        long $09090909,$19191919,$29292929,$39393939,$59494949,$69595959,$79696969,$89797979,$99998989,$A9A99999,$B9B9A9A9,$C9C9B9B9,$D9D9D9C9,$E9E9E9D9,$F9F9F9E9,$020202F9,$09090909,$19191919,$29292929,$39393939,$59494949,$69595959,$79696969,$89797979,$99998989,$A9A99999,$B9B9A9A9,$C9C9B9B9,$D9D9D9C9,$E9E9E9D9,$F9F9F9E9,$020202F9
        long $09090909,$19191919,$29292929,$39393939,$59494949,$69595959,$79696969,$89797979,$99998989,$A9A99999,$B9B9A9A9,$C9C9B9B9,$D9D9D9C9,$E9E9E9D9,$F9F9F9E9,$020202F9,$0A0A0A0A,$1A1A1A1A,$2A2A2A2A,$3A3A3A3A,$5A4A4A4A,$6A5A5A5A,$7A6A6A6A,$8A7A7A7A,$9A9A8A8A,$AAAA9A9A,$BABAAAAA,$CACABABA,$DADADACA,$EAEAEADA,$FAFAFAEA,$030303FA
        long $0A0A0A0A,$1A1A1A1A,$2A2A2A2A,$3A3A3A3A,$5A4A4A4A,$6A5A5A5A,$7A6A6A6A,$8A7A7A7A,$9A9A8A8A,$AAAA9A9A,$BABAAAAA,$CACABABA,$DADADACA,$EAEAEADA,$FAFAFAEA,$030303FA,$0A0A0A0A,$1A1A1A1A,$2A2A2A2A,$3A3A3A3A,$5A4A4A4A,$6A5A5A5A,$7A6A6A6A,$8A7A7A7A,$9A9A8A8A,$AAAA9A9A,$BABAAAAA,$CACABABA,$DADADACA,$EAEAEADA,$FAFAFAEA,$030303FA
        long $0A0A0A0A,$1A1A1A1A,$2A2A2A2A,$3A3A3A3A,$5A4A4A4A,$6A5A5A5A,$7A6A6A6A,$8A7A7A7A,$9A9A8A8A,$AAAA9A9A,$BABAAAAA,$CACABABA,$DADADACA,$EAEAEADA,$FAFAFAEA,$030303FA,$0A0A0A0A,$1A1A1A1A,$2A2A2A2A,$3A3A3A3A,$5A4A4A4A,$6A5A5A5A,$7A6A6A6A,$8A7A7A7A,$9A9A8A8A,$AAAA9A9A,$BABAAAAA,$CACABABA,$DADADACA,$EAEAEADA,$FAFAFAEA,$030303FA
        long $0A0A0A0A,$1A1A1A1A,$2A2A2A2A,$3A3A3A3A,$5A4A4A4A,$6A5A5A5A,$7A6A6A6A,$8A7A7A7A,$9A9A8A8A,$AAAA9A9A,$BABAAAAA,$CACABABA,$DADADACA,$EAEAEADA,$FAFAFAEA,$030303FA,$0A0A0A0A,$1A1A1A1A,$2A2A2A2A,$3A3A3A3A,$5A4A4A4A,$6A5A5A5A,$7A6A6A6A,$8A7A7A7A,$9A9A8A8A,$AAAA9A9A,$BABAAAAA,$CACABABA,$DADADACA,$EAEAEADA,$FAFAFAEA,$030303FA
        long $0A0A0A0A,$1A1A1A1A,$2A2A2A2A,$3A3A3A3A,$5A4A4A4A,$6A5A5A5A,$7A6A6A6A,$8A7A7A7A,$9A9A8A8A,$AAAA9A9A,$BABAAAAA,$CACABABA,$DADADACA,$EAEAEADA,$FAFAFAEA,$030303FA,$0A0A0A0A,$1A1A1A1A,$2A2A2A2A,$3A3A3A3A,$5A4A4A4A,$6A5A5A5A,$7A6A6A6A,$8A7A7A7A,$9A9A8A8A,$AAAA9A9A,$BABAAAAA,$CACABABA,$DADADACA,$EAEAEADA,$FAFAFAEA,$030303FA
        long $0A0A0A0A,$1A1A1A1A,$2A2A2A2A,$3A3A3A3A,$5A4A4A4A,$6A5A5A5A,$7A6A6A6A,$8A7A7A7A,$9A9A8A8A,$AAAA9A9A,$BABAAAAA,$CACABABA,$DADADACA,$EAEAEADA,$FAFAFAEA,$030303FA,$0A0A0A0A,$1A1A1A1A,$2A2A2A2A,$3A3A3A3A,$5A4A4A4A,$6A5A5A5A,$7A6A6A6A,$8A7A7A7A,$9A9A8A8A,$AAAA9A9A,$BABAAAAA,$CACABABA,$DADADACA,$EAEAEADA,$FAFAFAEA,$030303FA
        long $0A0A0A0A,$1A1A1A1A,$2A2A2A2A,$3A3A3A3A,$5A4A4A4A,$6A5A5A5A,$7A6A6A6A,$8A7A7A7A,$9A9A8A8A,$AAAA9A9A,$BABAAAAA,$CACABABA,$DADADACA,$EAEAEADA,$FAFAFAEA,$030303FA,$0A0A0A0A,$1A1A1A1A,$2A2A2A2A,$3A3A3A3A,$5A4A4A4A,$6A5A5A5A,$7A6A6A6A,$8A7A7A7A,$9A9A8A8A,$AAAA9A9A,$BABAAAAA,$CACABABA,$DADADACA,$EAEAEADA,$FAFAFAEA,$030303FA
        long $0B0B0B0B,$1B1B1B1B,$2B2B2B2B,$3B3B3B3B,$5B4B4B4B,$6B5B5B5B,$7B6B6B6B,$8B7B7B7B,$9B9B8B8B,$ABAB9B9B,$BBBBABAB,$CBCBBBBB,$DBDBDBCB,$EBEBEBDB,$FBFBFBEB,$040404FB,$0B0B0B0B,$1B1B1B1B,$2B2B2B2B,$3B3B3B3B,$5B4B4B4B,$6B5B5B5B,$7B6B6B6B,$8B7B7B7B,$9B9B8B8B,$ABAB9B9B,$BBBBABAB,$CBCBBBBB,$DBDBDBCB,$EBEBEBDB,$FBFBFBEB,$040404FB
        long $0B0B0B0B,$1B1B1B1B,$2B2B2B2B,$3B3B3B3B,$5B4B4B4B,$6B5B5B5B,$7B6B6B6B,$8B7B7B7B,$9B9B8B8B,$ABAB9B9B,$BBBBABAB,$CBCBBBBB,$DBDBDBCB,$EBEBEBDB,$FBFBFBEB,$040404FB,$0B0B0B0B,$1B1B1B1B,$2B2B2B2B,$3B3B3B3B,$5B4B4B4B,$6B5B5B5B,$7B6B6B6B,$8B7B7B7B,$9B9B8B8B,$ABAB9B9B,$BBBBABAB,$CBCBBBBB,$DBDBDBCB,$EBEBEBDB,$FBFBFBEB,$040404FB
        long $0B0B0B0B,$1B1B1B1B,$2B2B2B2B,$3B3B3B3B,$5B4B4B4B,$6B5B5B5B,$7B6B6B6B,$8B7B7B7B,$9B9B8B8B,$ABAB9B9B,$BBBBABAB,$CBCBBBBB,$DBDBDBCB,$EBEBEBDB,$FBFBFBEB,$040404FB,$0B0B0B0B,$1B1B1B1B,$2B2B2B2B,$3B3B3B3B,$5B4B4B4B,$6B5B5B5B,$7B6B6B6B,$8B7B7B7B,$9B9B8B8B,$ABAB9B9B,$BBBBABAB,$CBCBBBBB,$DBDBDBCB,$EBEBEBDB,$FBFBFBEB,$040404FB
        long $0B0B0B0B,$1B1B1B1B,$2B2B2B2B,$3B3B3B3B,$5B4B4B4B,$6B5B5B5B,$7B6B6B6B,$8B7B7B7B,$9B9B8B8B,$ABAB9B9B,$BBBBABAB,$CBCBBBBB,$DBDBDBCB,$EBEBEBDB,$FBFBFBEB,$040404FB,$0B0B0B0B,$1B1B1B1B,$2B2B2B2B,$3B3B3B3B,$5B4B4B4B,$6B5B5B5B,$7B6B6B6B,$8B7B7B7B,$9B9B8B8B,$ABAB9B9B,$BBBBABAB,$CBCBBBBB,$DBDBDBCB,$EBEBEBDB,$FBFBFBEB,$040404FB
        long $0B0B0B0B,$1B1B1B1B,$2B2B2B2B,$3B3B3B3B,$5B4B4B4B,$6B5B5B5B,$7B6B6B6B,$8B7B7B7B,$9B9B8B8B,$ABAB9B9B,$BBBBABAB,$CBCBBBBB,$DBDBDBCB,$EBEBEBDB,$FBFBFBEB,$040404FB,$0B0B0B0B,$1B1B1B1B,$2B2B2B2B,$3B3B3B3B,$5B4B4B4B,$6B5B5B5B,$7B6B6B6B,$8B7B7B7B,$9B9B8B8B,$ABAB9B9B,$BBBBABAB,$CBCBBBBB,$DBDBDBCB,$EBEBEBDB,$FBFBFBEB,$040404FB
        long $0B0B0B0B,$1B1B1B1B,$2B2B2B2B,$3B3B3B3B,$5B4B4B4B,$6B5B5B5B,$7B6B6B6B,$8B7B7B7B,$9B9B8B8B,$ABAB9B9B,$BBBBABAB,$CBCBBBBB,$DBDBDBCB,$EBEBEBDB,$FBFBFBEB,$040404FB,$0B0B0B0B,$1B1B1B1B,$2B2B2B2B,$3B3B3B3B,$5B4B4B4B,$6B5B5B5B,$7B6B6B6B,$8B7B7B7B,$9B9B8B8B,$ABAB9B9B,$BBBBABAB,$CBCBBBBB,$DBDBDBCB,$EBEBEBDB,$FBFBFBEB,$040404FB
        long $0B0B0B0B,$1B1B1B1B,$2B2B2B2B,$3B3B3B3B,$5B4B4B4B,$6B5B5B5B,$7B6B6B6B,$8B7B7B7B,$9B9B8B8B,$ABAB9B9B,$BBBBABAB,$CBCBBBBB,$DBDBDBCB,$EBEBEBDB,$FBFBFBEB,$040404FB,$0C0C0C0C,$1C1C1C1C,$2C2C2C2C,$3C3C3C3C,$5C4C4C4C,$6C5C5C5C,$7C6C6C6C,$8C7C7C7C,$9C9C8C8C,$ACAC9C9C,$BCBCACAC,$CCCCBCBC,$DCDCDCCC,$ECECECDC,$FCFCFCEC,$050505FC
        long $0C0C0C0C,$1C1C1C1C,$2C2C2C2C,$3C3C3C3C,$5C4C4C4C,$6C5C5C5C,$7C6C6C6C,$8C7C7C7C,$9C9C8C8C,$ACAC9C9C,$BCBCACAC,$CCCCBCBC,$DCDCDCCC,$ECECECDC,$FCFCFCEC,$050505FC,$0C0C0C0C,$1C1C1C1C,$2C2C2C2C,$3C3C3C3C,$5C4C4C4C,$6C5C5C5C,$7C6C6C6C,$8C7C7C7C,$9C9C8C8C,$ACAC9C9C,$BCBCACAC,$CCCCBCBC,$DCDCDCCC,$ECECECDC,$FCFCFCEC,$050505FC
        long $0C0C0C0C,$1C1C1C1C,$2C2C2C2C,$3C3C3C3C,$5C4C4C4C,$6C5C5C5C,$7C6C6C6C,$8C7C7C7C,$9C9C8C8C,$ACAC9C9C,$BCBCACAC,$CCCCBCBC,$DCDCDCCC,$ECECECDC,$FCFCFCEC,$050505FC,$0C0C0C0C,$1C1C1C1C,$2C2C2C2C,$3C3C3C3C,$5C4C4C4C,$6C5C5C5C,$7C6C6C6C,$8C7C7C7C,$9C9C8C8C,$ACAC9C9C,$BCBCACAC,$CCCCBCBC,$DCDCDCCC,$ECECECDC,$FCFCFCEC,$050505FC
        long $0C0C0C0C,$1C1C1C1C,$2C2C2C2C,$3C3C3C3C,$5C4C4C4C,$6C5C5C5C,$7C6C6C6C,$8C7C7C7C,$9C9C8C8C,$ACAC9C9C,$BCBCACAC,$CCCCBCBC,$DCDCDCCC,$ECECECDC,$FCFCFCEC,$050505FC,$0C0C0C0C,$1C1C1C1C,$2C2C2C2C,$3C3C3C3C,$5C4C4C4C,$6C5C5C5C,$7C6C6C6C,$8C7C7C7C,$9C9C8C8C,$ACAC9C9C,$BCBCACAC,$CCCCBCBC,$DCDCDCCC,$ECECECDC,$FCFCFCEC,$050505FC
        long $0C0C0C0C,$1C1C1C1C,$2C2C2C2C,$3C3C3C3C,$5C4C4C4C,$6C5C5C5C,$7C6C6C6C,$8C7C7C7C,$9C9C8C8C,$ACAC9C9C,$BCBCACAC,$CCCCBCBC,$DCDCDCCC,$ECECECDC,$FCFCFCEC,$050505FC,$0C0C0C0C,$1C1C1C1C,$2C2C2C2C,$3C3C3C3C,$5C4C4C4C,$6C5C5C5C,$7C6C6C6C,$8C7C7C7C,$9C9C8C8C,$ACAC9C9C,$BCBCACAC,$CCCCBCBC,$DCDCDCCC,$ECECECDC,$FCFCFCEC,$050505FC
        long $0C0C0C0C,$1C1C1C1C,$2C2C2C2C,$3C3C3C3C,$5C4C4C4C,$6C5C5C5C,$7C6C6C6C,$8C7C7C7C,$9C9C8C8C,$ACAC9C9C,$BCBCACAC,$CCCCBCBC,$DCDCDCCC,$ECECECDC,$FCFCFCEC,$050505FC,$0C0C0C0C,$1C1C1C1C,$2C2C2C2C,$3C3C3C3C,$5C4C4C4C,$6C5C5C5C,$7C6C6C6C,$8C7C7C7C,$9C9C8C8C,$ACAC9C9C,$BCBCACAC,$CCCCBCBC,$DCDCDCCC,$ECECECDC,$FCFCFCEC,$050505FC
        long $0C0C0C0C,$1C1C1C1C,$2C2C2C2C,$3C3C3C3C,$5C4C4C4C,$6C5C5C5C,$7C6C6C6C,$8C7C7C7C,$9C9C8C8C,$ACAC9C9C,$BCBCACAC,$CCCCBCBC,$DCDCDCCC,$ECECECDC,$FCFCFCEC,$050505FC,$0C0C0C0C,$1C1C1C1C,$2C2C2C2C,$3C3C3C3C,$5C4C4C4C,$6C5C5C5C,$7C6C6C6C,$8C7C7C7C,$9C9C8C8C,$ACAC9C9C,$BCBCACAC,$CCCCBCBC,$DCDCDCCC,$ECECECDC,$FCFCFCEC,$050505FC

'64*192 car sprite graphics

racer_car000 long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02000000,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$00000002,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$01010200,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$00020101,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$AA010102,$0000AAAA,$00000000,$05050100,$00010505,$00000000,$BBB90000,$020101BB,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$AAAA0102,$00AAAAAA,$00000000,$05050100,$00010505,$00000000,$BBBBB900,$0201BBBB,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02000000,$ABAA0101,$00AAAAAA,$00000000,$00000000,$00000000,$00000000,$BBBBB900,$0101BBB9,$00000002,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$02000000,$ABAB0101,$00AAAAAB,$00000000,$00000000,$00000000,$00000000,$BBBBB900,$0101B9BB,$00000002,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01000000,$AAAC0001,$00ACABAB,$00000000,$00000000,$00000000,$00000000,$BBBBBBB9,$01B9BBBB,$00000001,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$01020000,$AB000001,$0000AAAB,$00000000,$00000000,$00000000,$00000000,$BBBBBBB9,$01B9BBBB,$00000201,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01020000,$AC000000,$0000ACAC,$00000000,$00000000,$00000000,$00000000,$BBB9BBB9,$00BBBBBB,$00000201,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$01010000,$0303026B,$02030303,$0000006B,$00000000,$00000000,$00000000,$BBBBB9B9,$00B9BBBB,$00000101,$00000000,$00000000,$00000000,$00000000,$00000000,$2A2A2A2A,$6B01002A,$0303036B,$03030303,$01016B02,$00000000,$00000000,$02010101,$B9B9B903,$AC03B9B9,$2A000101,$2A2A2A2A,$00000000,$00000000
        long $00000000,$2A000000,$05050505,$6B012A2A,$01030302,$03030101,$586B6B03,$01010101,$01010101,$03AC5858,$01010303,$02030301,$2A2A01AC,$05050505,$0000002A,$00000000,$00000000,$2A000000,$05050505,$6B012A2A,$01020302,$03020101,$016B0203,$58585858,$58585858,$0302AC01,$01010203,$02030201,$2A2A01AC,$05050505,$0000002A,$00000000
        long $00000000,$00000000,$2A2A2A2A,$02012A2A,$01010303,$03010101,$6B6B0303,$01010101,$01010101,$0303AC01,$01010103,$03030101,$2A2AAC02,$2A2A2A2A,$00000000,$00000000,$00000000,$00000000,$01010000,$02010101,$01010303,$03010101,$6B6B0303,$01010101,$01010101,$0303AC01,$01010103,$03030101,$0101AC02,$00000101,$00000000,$00000000
        long $00000000,$00000000,$0101012A,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$2A010101,$00000000,$00000000,$00000000,$2A2A0000,$012A2A2A,$01010101,$2A2A0101,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$01012A2A,$01010101,$2A2A2A01,$00002A2A,$00000000
        long $00000000,$2A2A2A00,$01012A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A0101,$002A2A2A,$00000000,$00000000,$2A2A2A2A,$2A01012A,$2A2A2A2A,$2A2A2A2A,$3C3B3B2A,$033C3C3C,$03030303,$03030303,$3C3C3C03,$2A3B3B3C,$2A2A2A2A,$2A2A2A2A,$2A01012A,$2A2A2A2A,$00000000
        long $2A000000,$2A2A2A2A,$2A2A012A,$2A2A2A2A,$3C3C3B2A,$033C3C3C,$C9C9C903,$C9C9C9C9,$C9C9C9C9,$03C9C9C9,$3C3C3C03,$2A3B3C3C,$2A2A2A2A,$2A012A2A,$2A2A2A2A,$0000002A,$2A2A0000,$2A2A2A2A,$2A2A2A01,$3C3B2A2A,$3B3B3C3C,$3C3B3B3B,$0303033C,$C9C9C903,$03C9C9C9,$3C030303,$3B3B3B3C,$3C3C3B3B,$2A2A3B3C,$012A2A2A,$2A2A2A2A,$00002A2A
        long $2A2A0000,$01010101,$3B010101,$3B3C3C3C,$3B3B3B3B,$3B3B3B3B,$3C3C3C3B,$3C3C3C3C,$3C3C3C3C,$3B3C3C3C,$3B3B3B3B,$3B3B3B3B,$3C3C3C3B,$0101013B,$01010101,$00002A2A,$012A2A00,$0101C9C9,$01010101,$3B2A0101,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$01012A3B,$01010101,$C9C90101,$002A2A01
        long $C9012A00,$01C9BABA,$C99B9BC9,$01030301,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$01030301,$C99B9BC9,$BABAC901,$002A01C9,$C9012A2A,$01C9BABA,$9B9B9B9B,$03040403,$2A2A2A01,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$012A2A2A,$03040403,$9B9B9B9B,$BABAC901,$2A2A01C9
        long $01012A2A,$0101C9C9,$C99B9BC9,$03040403,$2A2A0101,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$01012A2A,$03040403,$C99B9BC9,$C9C90101,$2A2A0101,$012A2A2A,$01010101,$01010101,$01030301,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01030301,$01010101,$01010101,$2A2A2A01
        long $3B3B3B2A,$2A2A2A2A,$3B3B3B3B,$3B3B3B3B,$2A2A2A3B,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$3B2A2A2A,$3B3B3B3B,$3B3B3B3B,$2A2A2A2A,$2A3B3B3B,$3B3B3B2A,$3B3B3B3B,$3C3C3C3B,$3B3C3C3C,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3C3C3C3B,$3B3C3C3C,$3B3B3B3B,$2A3B3B3B
        long $3B2A2A2A,$3C3C3B3B,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3B3B3C3C,$2A2A2A3B,$2A2A2A2A,$3B3B2A2A,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$2A2A2A3B,$2A2A2A2A,$2A2A2A2A,$3B2A2A2A,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$2A2A3B3B,$2A2A2A2A
        long $2A2A2A2A,$2A2A2A2A,$3B3B3B2A,$3B3B3B3B,$3B3B3B3B,$2A2A2A2A,$19191919,$19191919,$19191919,$19191919,$2A2A2A2A,$3B3B3B3B,$3B3B3B3B,$2A3B3B3B,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$19191919,$19191919,$19191919,$19191919,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A
        long $2A2A2A19,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A19,$2A2A2A2A,$2A2A2A2A,$192A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$192A2A2A,$2A191919,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A19,$2A2A2A2A,$2A2A2A2A,$192A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$1919192A
        long $19191919,$2A2A2A19,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A19,$2A2A2A2A,$2A2A2A2A,$192A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$192A2A2A,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$2A2A2A19,$2A2A2A2A,$2A2A2A2A,$192A2A2A,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919
        long $19191901,$19191919,$19191919,$19191919,$19191919,$19191919,$3B3B3B19,$3B3B3B3B,$3B3B3B3B,$193B3B3B,$19191919,$19191919,$19191919,$19191919,$19191919,$01191919,$19191901,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$01191919
        long $19191901,$19191919,$2A2A1919,$2A2A2A2A,$1919192A,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$2A191919,$2A2A2A2A,$19192A2A,$19191919,$01191919,$19190101,$19191919,$023B2A19,$02030303,$58582A3B,$58585858,$58585858,$58585858,$58585858,$58585858,$58585858,$3B2A5858,$03030302,$192A3B02,$19191919,$01011919
        long $19010101,$19191919,$03023B2A,$03585858,$3B3B2A02,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$022A3B3B,$58585803,$2A3B0203,$19191919,$01010119,$01010101,$01010101,$03020158,$03585858,$2A2A3B02,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$023B2A2A,$58585803,$58010203,$01010101,$01010101
        long $01010101,$01010101,$02015848,$02030303,$58580101,$58585858,$58585858,$58585858,$58585858,$58585858,$58585858,$01015858,$03030302,$48580102,$01010101,$01010101,$01010101,$01010101,$01580101,$01020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020201,$01015801,$01010101,$01010101
        long $01010101,$01010101,$02585801,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$01585802,$01010101,$01010101,$01010102,$01010101,$02020101,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$01010202,$01010101,$02010101
        long $02020200,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00020202,$00000000,$02020200,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00020202,$00000000
        long $00000000,$00000000,$00000000,$00000000,$02000000,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00000002,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000005,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$05000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01020000,$01010101,$01010101,$01010101,$01010101,$01010101,$00000002,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$01010102,$01010101,$01010101,$01010101,$01010101,$01010101,$00020101,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02000000,$00010158,$00000000,$05AAAAAA,$01050505,$00000000,$00000000,$02010101,$B9000000,$0000BBBB,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$01020000,$00000101,$AA000000,$AAAAAAAA,$01050505,$00000000,$00000000,$01010000,$BBB90002,$00BBBBBB,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$58020000,$00000001,$AA000000,$AAAAAAAB,$00000000,$00000000,$00000000,$01000000,$BBB90201,$00B9BBBB,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$01010200,$00000000,$AB000000,$AAAAABAB,$00000000,$00000000,$00000000,$01000000,$BBB90101,$00BBBBBB,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01010200,$00000000,$AC000000,$ACABABAA,$00000000,$00000000,$00000000,$00000000,$BBBBB901,$B9BBBBBB,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$02010102,$00000000,$00000000,$00AAABAB,$00000000,$00000000,$00000000,$00000000,$BBBBB901,$B9BBBBBB,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00010102,$00000000,$00000000,$00ACACAC,$00000000,$00000000,$00000000,$00000000,$BBBBB900,$BBBBBBB9,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00010101,$AAAA0000,$03026B00,$03030303,$00006B02,$00000000,$00000000,$00000000,$B9B9B900,$B9BBBBBB,$00000000,$00000000,$00000000,$00000000,$2A2A0000,$002A2A2A,$00010101,$ACAC0101,$03036B6B,$03030303,$006B0203,$01010000,$01010101,$AC010101,$B9B90302,$03B9B9B9,$00002A2A,$00000000,$00000000,$00000000
        long $05052A00,$2A2A0505,$01000101,$ACAC0201,$0303026B,$01010103,$016B0303,$58580101,$58585858,$ACAC5858,$03030303,$03010101,$002A0502,$00000000,$00000000,$00000000,$05052A00,$2A2A0505,$01000101,$6B580102,$0303026B,$01010102,$6B020302,$01015858,$01010101,$02ACAA01,$02030303,$02010101,$002A0502,$00000000,$00000000,$00000000
        long $2A2A0000,$2A2A2A2A,$01010101,$6A580102,$03030302,$01010101,$6B030301,$01010101,$01010101,$03ACAC01,$01030303,$01010101,$00000203,$00000000,$00000000,$00000000,$00000000,$192A0000,$01010101,$01580102,$03030302,$01010101,$6B030301,$01010101,$01010101,$03ACAC01,$01030303,$01010101,$00000203,$00000000,$00000000,$00000000
        long $00000000,$012A2A2A,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$00010101,$00000000,$00000000,$00000000,$2A2A0000,$012A2A2A,$01010101,$01010101,$01010101,$2A2A0101,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$012A2A2A,$01010101,$00000001,$00000000,$00000000
        long $2A2A2A00,$192A2A2A,$2A010101,$2A2A2A2A,$2A01012A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A012A2A,$0000002A,$00000000,$3B3B3B2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$01012A2A,$2A2A2A2A,$2A2A2A2A,$3B3B2A2A,$3C3C3C3C,$03030303,$03030303,$3C3C3C03,$2A2A3B3B,$012A2A2A,$002A2A01,$00000000
        long $3C3C3C3B,$2A3B3B3B,$2A2A2A2A,$2A2A2A2A,$012A2A2A,$2A2A2A01,$3B3B2A2A,$3C3C3C3C,$C9C90303,$C9C9C9C9,$C9C9C9C9,$03C9C9C9,$3C3C3C3C,$2A2A3B3C,$2A2A012A,$00000000,$3C3B3B2A,$3B3C3C3C,$3B3B3B3B,$2A2A2A3B,$2A2A2A2A,$2A2A2A01,$3C3C3C3B,$3B3B3B3B,$03033C3C,$C9C90303,$C9C9C9C9,$3C0303C9,$3B3B3B3B,$3B3C3C3B,$2A012A2A,$00000019
        long $3B2A2A2A,$3C3C3C3B,$3C3C3C3C,$012A3B3C,$01010101,$3C3B0101,$3B3B3B3C,$3B3B3B3B,$3C3C3B3B,$3C3C3C3C,$3C3C3C3C,$3B3C3C3C,$3B3B3B3B,$3C3B3B3B,$192A3B3C,$00000101,$2A2A2A2A,$3C3C3B2A,$3C3C3C3C,$01013B3C,$01C9C901,$01010101,$19010101,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$2A3B3B3B,$01010101,$00C90101
        long $2A2A192A,$3C3C3B2A,$3C3C3C3C,$01013B3B,$C9BABAC9,$9B9BC901,$030301C9,$3B2A2A01,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$013B3B3B,$9BC90103,$00BAC9C9,$2A2A2A19,$3C3B3B2A,$3B3B3C3C,$01012A2A,$C9BABAC9,$9B9B9B01,$0404039B,$2A2A0103,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$03012A2A,$9B9B0304,$00BAC99B
        long $2A2A2A01,$3B2A192A,$2A2A3B3B,$012A2A2A,$01C9C901,$9B9BC901,$040403C9,$2A2A0103,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$03012A2A,$9B9B0304,$00C901C9,$2A2A2A01,$3B01192A,$2A2A2A3B,$2A2A2A2A,$01010101,$01010101,$03030101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$9BC90103,$002A1919
        long $2A2A1901,$3B01012A,$3B3B3B3B,$2A2A2A3B,$3B3B3B2A,$3B3B3B3B,$3B3B3B3B,$2A2A3B3B,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$3B3B3B3B,$3B3B3B3B,$2A2A3B3B,$19191901,$2A01032A,$3B3B2A2A,$3B3B3B3B,$3C3C3B3B,$3C3C3C3C,$3C3C3C3C,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3C3C3B3B,$3C3C3C3C,$3B3B3B3B
        long $19190101,$01031919,$2A2A2A2A,$3C3B3B3B,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$19190101,$01051919,$2A2A2A2A,$3B2A2A2A,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$3B3B2A2A,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B
        long $19010101,$03050119,$2A2A2A2A,$2A2A2A2A,$3B3B2A2A,$3B3B3B3B,$3B3B3B3B,$2A3B3B3B,$2A2A2A2A,$19191919,$19191919,$19191919,$2A191919,$3B3B2A2A,$3B3B3B3B,$2A2A2A3B,$19010101,$03050119,$2A2A2A01,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$19191919,$19191919,$19191919,$2A191919,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A
        long $01010101,$05050119,$2A2A1948,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A19,$2A2A2A2A,$2A2A2A2A,$2A192A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$01010100,$05050119,$19191901,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A19,$2A2A2A2A,$2A2A2A2A,$2A192A2A,$2A2A2A2A,$2A2A2A2A,$19192A2A
        long $01010100,$05050101,$19191901,$2A2A1919,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A19,$2A2A2A2A,$2A2A2A2A,$19192A2A,$19191919,$19191919,$19191919,$02020000,$05050102,$19191901,$19191919,$2A2A1919,$2A2A2A2A,$192A2A2A,$19191919,$19191919,$2A2A2A19,$3B2A2A2A,$3B3B3B3B,$19193B3B,$19191919,$19191919,$19191919
        long $02000000,$05050102,$19190101,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$3B3B3B19,$193B3B3B,$19191919,$19191919,$2A191919,$192A2A2A,$01191919,$00000000,$05050102,$19190101,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$022A1919,$2A2A0303,$00011919
        long $00000000,$05050100,$19190101,$19191919,$19191919,$2A191919,$2A2A2A2A,$582A2A2A,$58585858,$58585858,$58585858,$3B3B5858,$3B3B3B3B,$03022A19,$2A035858,$00000001,$00000000,$05050100,$19010101,$19191919,$19191919,$3B2A1919,$03030302,$3B2A0203,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$2A2A3B3B,$2A2A2A2A,$4803023B,$02035858,$00000000
        long $00000000,$05030100,$01010101,$19010101,$19191919,$023B2A29,$58585803,$3B020358,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$01012A2A,$01010101,$03020101,$01020303,$00000000,$00000000,$03030100,$01010101,$01010101,$01010101,$02010101,$58585803,$01020358,$01010101,$01010101,$01010101,$02020101,$01010101,$01010101,$02010101,$00000000
        long $00000000,$03010100,$01010101,$01010101,$02020202,$01020202,$03030302,$02010203,$02020202,$02020202,$02020202,$02020202,$01010101,$01010101,$02020101,$00000000,$00000000,$01010000,$01010101,$01010101,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$01010102,$01010101,$02020201,$00000000
        long $00000000,$01010000,$01010101,$01010101,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00020202,$00000000,$00000000,$01000000,$01010101,$02010101,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00000202,$00000000
        long $00000000,$00000000,$02020200,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00000202,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00020202,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000005,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$05000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02000000,$01010101,$01010101,$01010101,$01010101,$01010101,$00000201,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01010200,$01010101,$01010101,$01010101,$01010101,$01010101,$02010101,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$AAAA0000,$000000AA,$01010102,$00000000,$00000000,$05050501,$BBBBB905,$00000000,$58010100,$00000002,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$AAAAAA00,$0200AAAA,$00000101,$00000000,$00000000,$05050501,$BBBBBBB9,$000000BB,$01010000,$00000201,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$AAABAA00,$0102AAAA,$00000001,$00000000,$00000000,$00000000,$BBB9BBB9,$000000BB,$01000000,$00000258,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$ABABAB00,$0102AAAA,$00000001,$00000000,$00000000,$00000000,$BBBBBBB9,$000000B9,$00000000,$00020101,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$ABAAAC00,$0102ACAB,$00000000,$00000000,$00000000,$B9000000,$BBBBBBBB,$0000B9BB,$00000000,$00020101,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$ABAB0000,$010102AA,$00000000,$00000000,$00000000,$B9000000,$BBBBBBBB,$0000B9BB,$00000000,$02010102,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$ACAC0000,$010101AC,$00000000,$00000000,$00000000,$B9000000,$BBBBBBB9,$0000BBBB,$00000000,$02010100,$00000000,$00000000
        long $00000000,$00000000,$00000000,$6B000000,$03030302,$6B020303,$00000000,$00000000,$00000000,$B9000000,$BBBBBBBB,$0000B9BB,$00000000,$01010100,$00000000,$00000000,$00000000,$00000000,$00000000,$6B6B0000,$03030303,$02030303,$0101016B,$01010101,$00000101,$03020000,$B9B9B9B9,$ACAC03B9,$01010101,$01010100,$2A2A2A00,$00002A2A
        long $00000000,$00000000,$00000000,$026B2A00,$01010103,$03030303,$02026B6B,$58580202,$01015858,$03030101,$03010101,$AC020303,$015858AC,$01010001,$05052A2A,$002A0505,$00000000,$00000000,$00000000,$026B2A00,$01010102,$03030302,$016B6B02,$01020101,$58580101,$02030258,$02010101,$AC020303,$580101AC,$01010001,$05052A2A,$002A0505
        long $00000000,$00000000,$00000000,$03020000,$01010101,$03030301,$6B6B6B03,$01020101,$01010101,$01030301,$01010101,$02030303,$0101ACAC,$01010101,$2A2A2A2A,$00002A2A,$00000000,$00000000,$00000000,$03020000,$01010101,$03030301,$6B6B0103,$01020101,$01010101,$01030301,$01010101,$02030303,$0101ACAC,$01010101,$00002A19,$00000000
        long $00000000,$00000000,$00000000,$01010100,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$2A2A2A01,$00000000,$00000000,$00000000,$01000000,$01010101,$2A2A2A01,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$01012A2A,$01010101,$01010101,$01010101,$2A2A2A01,$00002A2A
        long $00000000,$2A000000,$2A2A012A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A01012A,$2A2A2A2A,$0101012A,$2A2A2A19,$002A2A2A,$00000000,$012A2A00,$2A2A2A01,$3B3B2A2A,$033C3C3C,$03030303,$03030303,$3C3C3C3C,$2A2A3B3B,$2A2A2A2A,$2A2A2A2A,$2A2A0101,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A3B3B3B
        long $00000000,$2A012A2A,$3C3B2A2A,$3C3C3C3C,$C9C9C903,$C9C9C9C9,$C9C9C9C9,$0303C9C9,$3C3C3C3C,$2A2A3B3B,$012A2A2A,$2A2A2A01,$2A2A2A2A,$2A2A2A2A,$3B3B3B2A,$3B3C3C3C,$19000000,$2A2A012A,$3B3C3C3B,$3B3B3B3B,$C903033C,$C9C9C9C9,$0303C9C9,$3C3C0303,$3B3B3B3B,$3B3C3C3C,$012A2A2A,$2A2A2A2A,$3B2A2A2A,$3B3B3B3B,$3C3C3C3B,$2A3B3B3C
        long $01010000,$3C3B2A19,$3B3B3B3C,$3B3B3B3B,$3C3C3C3B,$3C3C3C3C,$3C3C3C3C,$3B3B3C3C,$3B3B3B3B,$3C3B3B3B,$01013B3C,$01010101,$3C3B2A01,$3C3C3C3C,$3B3C3C3C,$2A2A2A3B,$0101C900,$01010101,$3B3B3B2A,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$01010119,$01010101,$01C9C901,$3C3B0101,$3C3C3C3C,$2A3B3C3C,$2A2A2A2A
        long $C9C9BA00,$0301C99B,$3B3B3B01,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$012A2A3B,$C9010303,$01C99B9B,$C9BABAC9,$3B3B0101,$3C3C3C3C,$2A3B3C3C,$2A192A2A,$9BC9BA00,$04039B9B,$2A2A0103,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$03012A2A,$9B030404,$019B9B9B,$C9BABAC9,$2A2A0101,$3C3C3B3B,$2A3B3B3C,$192A2A2A
        long $C901C900,$04039B9B,$2A2A0103,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$03012A2A,$C9030404,$01C99B9B,$01C9C901,$2A2A2A01,$3B3B2A2A,$2A192A3B,$012A2A2A,$19192A00,$0301C99B,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010303,$01010101,$01010101,$2A2A2A2A,$3B2A2A2A,$2A19013B,$012A2A2A
        long $3B3B2A2A,$3B3B3B3B,$3B3B3B3B,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$3B3B2A2A,$3B3B3B3B,$3B3B3B3B,$2A3B3B3B,$3B2A2A2A,$3B3B3B3B,$2A01013B,$01192A2A,$3B3B3B3B,$3C3C3C3C,$3B3B3C3C,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3C3C3C3C,$3C3C3C3C,$3B3B3C3C,$3B3B3B3B,$2A2A3B3B,$2A03012A,$01191919
        long $3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3C3C3C3C,$3B3B3B3C,$2A2A2A2A,$1903012A,$01191919,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$2A2A3B3B,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$2A2A2A3B,$2A2A2A2A,$1905012A,$01191919
        long $3B2A2A2A,$3B3B3B3B,$2A2A3B3B,$1919192A,$19191919,$19191919,$19191919,$2A2A2A2A,$3B3B3B2A,$3B3B3B3B,$3B3B3B3B,$2A2A3B3B,$2A2A2A2A,$2A2A2A2A,$0105032A,$01011919,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$1919192A,$19191919,$19191919,$19191919,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$012A2A2A,$01050301,$01011919
        long $2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A192A,$2A2A2A2A,$2A2A2A2A,$192A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$48192A2A,$01050548,$01010119,$2A2A1919,$2A2A2A2A,$2A2A2A2A,$2A2A192A,$2A2A2A2A,$2A2A2A2A,$192A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$01191919,$01050501,$01010119
        long $19191919,$19191919,$19191919,$2A2A1919,$2A2A2A2A,$2A2A2A2A,$192A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$19192A2A,$01191919,$01050501,$01010101,$19191919,$19191919,$19191919,$3B3B1919,$3B3B3B3B,$2A2A2A3B,$192A2A2A,$19191919,$19191919,$2A2A2A19,$2A2A2A2A,$19192A2A,$19191919,$01191919,$01050501,$00020202
        long $19191901,$2A2A2A19,$1919192A,$19191919,$19191919,$3B3B3B19,$193B3B3B,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$01011919,$01050501,$00000202,$19190100,$03032A2A,$19192A02,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$01011919,$01050501,$00000002
        long $01000000,$5858032A,$192A0203,$3B3B3B3B,$58583B3B,$58585858,$58585858,$58585858,$2A2A2A58,$2A2A2A2A,$1919192A,$19191919,$19191919,$01011919,$01050501,$00000000,$00000000,$58580302,$3B020348,$2A2A2A2A,$3B3B2A2A,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$03022A3B,$02030303,$19192A3B,$19191919,$19191919,$01010119,$01050501,$00000000
        long $00000000,$03030201,$01010203,$01010101,$2A2A0101,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$5803023B,$03585858,$292A3B02,$19191919,$01010119,$01010101,$01030501,$00000000,$00000000,$01010102,$01010101,$01010101,$01010202,$01010101,$01010101,$01010101,$58030201,$03585858,$01010102,$01010101,$01010101,$01010101,$01030301,$00000000
        long $00000000,$01010202,$01010101,$01010101,$02020202,$02020202,$02020202,$02020202,$03020102,$02030303,$02020201,$02020202,$01010101,$01010101,$01010301,$00000000,$00000000,$01020202,$01010101,$02010101,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$01010101,$01010101,$00010101,$00000000
        long $00000000,$02020200,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$01010101,$01010101,$00010101,$00000000,$00000000,$02020000,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$01010102,$01010101,$00000101,$00000000
        long $00000000,$00000000,$00000000,$02020000,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00020202,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02020200,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000005,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$05000000