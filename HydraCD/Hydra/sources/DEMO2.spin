'' Racer Demo 05-07-06 
'' JT Cook
'' Based on Remi's graphic drivers which have been hacked apart for the road effect and
''   my own sprite routines. 
'' Second release - horizontal sprite screen clipping, sprite scaling, objects on the side
''  of the road, new original graphics
'' First release has road and sprites working(only one drawn right now). I "borrowed" the
''   car graphic from another racing game.
''
'' The main program has a lot of calculations to place sprites and posistion the road. All
''   of this is done in SPIN, so this slows the program down, because of this sometimes
''   sprite data may become messed up for a frame since the sprite data may change between
''   scanlines.
'' There is a bug in road calculation routines(Calc_Skew) that will slows the main program
''   down, but I haven't looked into that. Also for this version I "borrowed" and the car
''   graphic from another racing game.
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
xxx1                   = SCANLINE_BUFFER-8
xxx2                   = SCANLINE_BUFFER-12
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
'up to -76
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
  word road_offset[road_scanlines] 'road angle that adjusts perspective, add or subtract each road
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
  'game sprites(for game engine, not rendering engine)
  byte sprite_road_val[16]    'sprite value on the road
  byte sprite_scl_val[16]     'sprite value for which scanline to check in LUT
  byte sprite_road_side[16]   'which side of road sprite is on (0-left, 1-right)
  long track_event_cnt        'event counter for track
  long next_track_event       'number for next event on track
  byte track_event            'the part of the track the player is on
OBJ

  tv    : "rem_tv_014.spin"               ' tv driver 256 pixel scanline
'  tv    : "rem_tv_014_low.spin"           ' tv driver 128 pixels scanline
  gfx   : "Racer_gfx_engine_004.spin"     ' graphics driver


PUB start      | i, j, k, kk, dx, dy, pp, pq, rr, numx, numchr
  DIRA[0] := 1
  outa[0] := 0

  longfill(@colors, $02020205, 1)
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

  repeat kk from 2 to 15
   sprite_graphic[kk]:=@racer000 
   sprite_x_olen[kk]:=64
   sprite_y_olen[kk]:=64
   sprite_x_len[kk]:=64
   sprite_y_len[kk]:=64
   sprite_x[kk]:=50   'place sprite off screen
   sprite_y[kk]:=200   'place all sprites off screen
   Calc_Sprite(kk)

  'sign sprite
  sprite_graphic[2]:=@racer000 + (128*64)
  sprite_x_olen[2]:=32
  sprite_y_olen[2]:=32
  sprite_graphic[5]:=@racer000 + (128*64)
  sprite_x_olen[5]:=32
  sprite_y_olen[5]:=32

  
  curve_depth:=80 ' how far into the turn the road is
  curve_direction:=0 'which side road will curve to 0-left, 1-right
  next_track_event:= 3000 'travel until next track event
  track_event_cnt:= 0 'current distance traveled
  track_event:=0  'starting event  

  'test roadside sprites
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
   
  'setup player sprite
  sprite_graphic[1]:=@racer000 + 64 
  sprite_x[1]:=(255 + 128 - (car_length /2))
  sprite_y[1]:=141
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
  ' Start of main loop here
  repeat
    repeat while tv_status == 1
    repeat while tv_status == 2

    'input
   ' Read both gamepad
   
    temp1 := NES_Read_Gamepad
    if((temp1 & NES0_RIGHT) <> 0)
     if(road_x_off<506)
      road_x_off += 3
        
    if((temp1 & NES0_LEFT) <> 0)
     if(road_x_off>3)
        road_x_off -= 3      

    if((temp1 & NES0_DOWN) <> 0)
      car_speed_long-=1
      if(car_speed_long<1)
         car_speed_long+=10
         if(car_speed>0)
          car_speed-=1

    if((temp1 & NES0_UP) <> 0)
      car_speed_long+=1
      if(car_speed_long>10)
         car_speed_long-=10
         if(car_speed<10)
           car_speed+=1

{                             
    if((temp1 & NES0_B) <> 0)
     sprite_road_val[2]+=2
     if(curve_depth<79)
       curve_depth+=2

    if((temp1 & NES0_A) <> 0)
      if(curve_depth>1)
       curve_depth-=2
}       

   ' Check_Debug_Input     'debug stuff
    Run_Track             ' handle track events
    Calc_Road_Sprites(2)  ' calc sprite movement with the road
    Calc_Road_Sprites(3)  ' calc sprite movement with the road
    Calc_Road_Sprites(4)  ' calc sprite movement with the road
    Calc_Road_Sprites(5)  ' calc sprite movement with the road
    Calc_Road_Sprites(6)  ' calc sprite movement with the road            
    Calc_Skew(road_x_off) ' calc road angle perspective
'end of main
'---------------------------------------------
PUB Run_Track
    track_event_cnt+=car_speed  'advance on track
    if(track_event_cnt => next_track_event) 'advance to next track event
      track_event_cnt -= next_track_event
      track_event+=1
      if(track_event==1)
         curve_depth:=0 ' how far into the turn the road is
         curve_direction:=0 'which side road will curve to 0-left, 1-right
         next_track_event:=500
      if(track_event==2)
         curve_depth:=80
         next_track_event:=3000
      if(track_event==3)
         curve_depth:=0
         curve_direction:=1
         next_track_event:=500
      if(track_event>3)
         curve_depth:=80
         next_track_event:=3000
         track_event:=0
PUB Check_Debug_Input 
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

PUB Calc_Road_Sprites(sp_number) | kk, temps1, temp_scan_l
   sprite_road_val[sp_number]+=car_speed   'move object forward with speed
   'we need to reset sprite
   if(sprite_road_val[sp_number]>205)       'if object goes past visible screen(behind)
    sprite_road_val[sp_number]-=205  'grab remainder
    'start it at far end of track
    sprite_road_val[sp_number]:= byte[@road_depth_sp] + sprite_road_val[sp_number]
   temps1:=sprite_road_val[sp_number]        'grab where object is on screen track
   'find the scanline to place the sprite on
   repeat kk from 0 to road_scanlines-1
     if(temps1 => byte[@road_depth_sp + kk])
       temp_scan_l:=kk
   'use lookup to match road scanline number to find the horizontal and verticle
   'size to scale the sprite
   sprite_x_len[sp_number]:= byte[@road_gfx +(temp_scan_l*7+2)] /2 
   sprite_y_len[sp_number]:=sprite_x_len[sp_number]
   'choose side of road to place sprite
   if(sprite_road_side[sp_number]==0)
     sprite_x[sp_number]:= byte[@road_spite_lut_l +temp_scan_l] - sprite_x_len[sp_number]
   else
     sprite_x[sp_number]:= word[@road_spite_lut_r +(temp_scan_l<<1)]      
   'skew sprite along with road prespective
   sprite_x[sp_number]+= road_offset[temp_scan_l] 
   'after finding road scanline, push up sprite so bottom of sprite is on the scanline
   sprite_y[sp_number]:=temp_scan_l + 120 - sprite_y_len[sp_number]
   Calc_Sprite(sp_number)
       

'---------------------------------------------
PUB Calc_Skew(RoadOff) | k,kk,pp, swing, curve_calc
' Calculate the skewed road angle(road perspective illusion)
' make road heigh 64 pixels so you can bit shift length against it
' road x offset / 64 = how many x pixels to 1 y pixel
'used for line angle on road perspective RoadLine_X is how many X pixels for every
'Y pixel(x100 to get decimal); RoadLine_X_Cntr is the counter to tell how many pixels
'we are currently at(advance another pixel or not?)
  RoadLine_X:=RoadOff 'x offset we are caclulating from
  if(RoadOff>254)
    swing:=1  'subtract
    RoadLine_X:=RoadLine_X - 255
  else
    RoadLine_X:=255-RoadLine_X
    swing:=0  'add
  curve_calc := curve_depth 'grab current curve depth    
  road_x_cntr := 255 'reset pixel counter 255 is the center
  road_x_cntr -= 23  'center road
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
  repeat kk from 0 to road_scanlines-1
    road_depth[kk]+=car_speed   'scroll the road
    if(road_depth[kk]>79)
       road_depth[kk]-=80
      
    RoadLine_X_Cntr+=RoadLine_X 'counter for skewing road
    'if counter is greater than 99, then we indent a pixel
    repeat while (RoadLine_X_Cntr > 99)
      if(swing==0)     'adjust skewing of pixel
         road_x_cntr+=1 
      else
          road_x_cntr-=1 
      RoadLine_X_Cntr-=100 'subtract from counter
    k:=road_x_cntr 'grab perspective skew
    if(curve_calc<80)
     if(curve_direction) 
       k+=curve_lut[curve_calc]  'add in curve for turn(if there is one)
     else
       k-=curve_lut[curve_calc]  'add in curve for turn(if there is one)
     curve_calc+=1
    road_offset[kk]:=k 'add x offset

PUB Calc_Sprite(sprite_numb)
'calc scaled size of sprite
  sprite_x_scale[sprite_numb] := sprite_x_olen[sprite_numb] *512 / sprite_x_len[sprite_numb]
  sprite_y_scale[sprite_numb] := sprite_y_olen[sprite_numb] *512 / sprite_y_len[sprite_numb]
'check clipping on left side of screen
  if(sprite_x[sprite_numb]<255) 'moves off left of screen, clip sprite
      sprite_x_clip[sprite_numb]:= (256 - sprite_x[sprite_numb]) * sprite_x_scale[sprite_numb]
  else
    sprite_x_clip[sprite_numb]:=0

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

' palette for road  (keep road same color?)
' grass, road, grass
'road_pal byte $5b,$BB, $4, $5, $4, $BB, $5b
'         byte $6c,$5, $3, $3, $3, $5, $6c
road_pal byte $5b, $5, $4, $4, $4,  $5, $5b
         byte $6c,$BB, $4, $5, $4, $BB, $6c
'precalc LUT for depth of road (for alternating colors)
'Road depth data
Depth_PreCalc
BYTE   0 , 46 , 29 , 13 ,  1 , 70 , 60 , 51 , 44 , 36 , 31 , 25 , 19 , 15 , 10 ,  6 ,  3
BYTE 79 , 76 , 73 , 70 , 67 , 64 , 62 , 60 , 57 , 56 , 54 , 51 , 50 , 48 , 46 , 45 , 43 
BYTE 42 , 40 , 39 , 38 , 36 , 35 , 34 , 33 , 31 , 31 , 29 , 28 , 27 , 26 , 25 , 24 , 24
BYTE 22 , 22 , 20 , 20 , 19 , 18 , 17 , 16 , 15 , 15 , 14 , 13 , 12 , 12 , 11 , 10 ,  9
BYTE 9 ,  8 ,  7 ,  6 ,  6 ,  5 ,  4 ,  4 ,  3 ,  2 ,  1 ,  1 ,  0

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
  
'128x128  graphics data
racer000 long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$6A696800,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$0000696A,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02000000,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$00000002,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$68000000,$6A6A6A69,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$696A6A6A,$00006869,$696A0000,$00696969,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01010200,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$00020101,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$69000000,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$00686A6A,$6A6A6800,$696A6A6A,$68696800,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01010102,$00000000,$00000000,$05050100,$00010505,$00000000,$00000000,$02010101,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$6A690000,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$686A6968,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00010102,$00000000,$00000000,$05050100,$00010505,$00000000,$00000000,$02010100,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$6A6A0000,$6A6A6A6A,$6A6A696A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$006A6A6A,$00000000,$00000000,$00000000,$00000000,$00000000,$02000000,$00000101,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01010000,$00000002,$00000000,$00000000,$00000000
        long $00000000,$00000000,$6A690000,$6868696A,$6A6A6A69,$6A696A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$00696A6A,$00000000,$00000000,$00000000,$00000000,$00000000,$02000000,$00000101,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01010000,$00000002,$00000000,$00000000,$00000000,$00000000,$00000000,$68000000,$69696969,$6A6A6A69,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$686A6A6A,$00000000,$00000000,$00000000,$00000000,$00000000,$01000000,$03030201,$02030303,$00000000,$00000000,$00000000,$00000000,$03030302,$01020303,$00000001,$00000000,$00000000,$00000000
        long $00000000,$6A680000,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A69,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$00006869,$00000000,$00000000,$00000000,$00000000,$01020000,$03030301,$03030303,$00000002,$00000000,$00000000,$02000000,$03030303,$01030303,$00000201,$00000000,$00000000,$00000000,$00000000,$6A6A6800,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A696A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$006A6A6A,$00000000,$00000000,$00000000,$00000000,$01020000,$01030302,$03030101,$00000003,$00000000,$00000000,$03000000,$01010303,$02030301,$00000201,$00000000,$00000000,$00000000
        long $00000000,$6A6A6A00,$6A6A6A6A,$696A6A6A,$696A6A69,$6A6A6A6A,$6A6A6A6A,$6969696A,$696A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A69,$6A6A6A6A,$6A6A6A6A,$686A6A6A,$00000000,$00000000,$00000000,$00000000,$01010000,$01020302,$03020101,$00000203,$00000000,$00000000,$03020000,$01010203,$02030201,$00000101,$00000000,$00000000,$00000000,$68680000,$6A6A6A68,$6A6A6A6A,$6A6A6A69,$6A6A6969,$6A6A6A6A,$6A6A6A6A,$6A69696A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$00006868,$00000000,$00000000,$19191919,$02010019,$01010303,$03010101,$01010303,$01010101,$01010101,$03030101,$01010103,$03030101,$19000102,$19191919,$00000000,$00000000
        long $6A6A6800,$6A6A6A6A,$6A6A6A69,$696A6A6A,$6A696A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A69,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$00686A6A,$00000000,$19000000,$05050505,$02011919,$01010303,$03010101,$58580303,$58585858,$58585858,$03035858,$01010103,$03030101,$19190102,$05050505,$00000019,$00000000,$6A6A6A68,$696A6A6A,$6A6A6A69,$6A6A6969,$6A696A69,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$696A6A6A,$6A6A6A6A,$6A6A6A6A,$686A6A6A,$00000000,$19000000,$05050505,$02011919,$01010303,$02010101,$01010303,$01010101,$01010101,$03030101,$01010102,$03030101,$19190102,$05050505,$00000019,$00000000
        long $6A6A6A68,$696A6A6A,$6A6A6A6A,$6A6A6969,$696A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A69,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$686A6A6A,$00000000,$00000000,$19191919,$02011919,$01010303,$02010101,$01010303,$01010101,$01010101,$03030101,$01010102,$03030101,$19190102,$19191919,$00000000,$00000000,$6A6A696A,$6A6A6A6A,$6A6A6A6A,$6A6A6969,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$696A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$00000000,$00000000,$01010000,$02010101,$01010303,$02010101,$01010303,$01010101,$01010101,$03030101,$01010102,$03030101,$01010102,$00000101,$00000000,$00000000
        long $696A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$696A6A6A,$6A6A6A6A,$6A6A6969,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$00000000,$00000000,$01010119,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$19010101,$00000000,$00000000,$6A6A6A6A,$6A696A69,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A69,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$00000000,$19190000,$01191919,$01010101,$19190101,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$01011919,$01010101,$19191901,$00001919,$00000000
        long $6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A696A6A,$6A6A6A6A,$696A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$00000000,$19191900,$01011919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$19190101,$00191919,$00000000,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A696A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$00000000,$19191919,$19010119,$19191919,$19191919,$3B2A2A19,$033B3B3B,$03030303,$03030303,$3B3B3B03,$192A2A3B,$19191919,$19191919,$19010119,$19191919,$00000000
        long $6A6A696A,$6A6A6A69,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$19000000,$19191919,$19190119,$19191919,$3B3B2A19,$033B3B3B,$C9C9C903,$C9C9C9C9,$C9C9C9C9,$03C9C9C9,$3B3B3B03,$192A3B3B,$19191919,$19011919,$19191919,$00000019,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6969,$6A6A6A6A,$696A6A6A,$696A696A,$696A6A6A,$6A6A6969,$6A6A6A6A,$6A6A6A6A,$19190000,$19191919,$19191901,$3B2A1919,$2A2A3B3B,$3B2A2A2A,$0303033B,$C9C9C903,$03C9C9C9,$3B030303,$2A2A2A3B,$3B3B2A2A,$19192A3B,$01191919,$19191919,$00001919
        long $6A6A6A6A,$6A6A6A6A,$69696A6A,$6A6A6969,$6A6A6A6A,$6A6A6A69,$6A6A6A6A,$6A69696A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A69,$6A6A6A6A,$6A6A6969,$6A6A6A6A,$6A696A6A,$19190000,$01010101,$2A010101,$2A3B3B3B,$2A2A2A2A,$2A2A2A2A,$3B3B3B2A,$3B3B3B3B,$3B3B3B3B,$2A3B3B3B,$2A2A2A2A,$2A2A2A2A,$3B3B3B2A,$0101012A,$01010101,$00001919,$696A6A6A,$6A6A6A6A,$69696A6A,$6A6A6969,$6A6A6A6A,$6A696969,$6A6A6A6A,$6A69696A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$69696A69,$6A696A6A,$6A6A6A69,$6A6A6A6A,$6A6A6A6A,$01191900,$0101C9C9,$01010101,$2A190101,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$0101192A,$01010101,$C9C90101,$00191901
        long $6A6A6A6A,$6A6A696A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$69696969,$6A6A696A,$6969696A,$6A6A6A69,$6A6A6A6A,$6A6A6A6A,$6A69696A,$69696A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$C9011900,$01C9BABA,$C99B9BC9,$01030301,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$01030301,$C99B9BC9,$BABAC901,$001901C9,$696A6969,$6969696A,$6A696969,$6A6A6A6A,$6A6A6A6A,$6A696969,$6A6A6A6A,$69696A6A,$6A6A6969,$6A6A6A6A,$6A6A6A69,$6A696A6A,$6A6A696A,$6A6A6A6A,$6A6A6A6A,$6A6A696A,$C9011919,$01C9BABA,$9B9B9B9B,$03040403,$19191901,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$01191919,$03040403,$9B9B9B9B,$BABAC901,$191901C9
        long $6A6A6A6A,$69696969,$6A696A69,$69696A6A,$69696A6A,$696A6969,$6A6A6A6A,$6969696A,$6A696969,$6A6A6A69,$6A6A6A69,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$01011919,$0101C9C9,$C99B9BC9,$03040403,$19190101,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$01011919,$03040403,$C99B9BC9,$C9C90101,$19190101,$69696969,$6A6A696A,$6A6A6A69,$6969696A,$69696969,$6A6A6969,$6A6A6A6A,$69696969,$69696868,$6A6A6A69,$6A696969,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$01191919,$01010101,$01010101,$01030301,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01010101,$01030301,$01010101,$01010101,$19191901
        long $69696969,$6A6A696A,$6969696A,$6A6A6969,$69696A6A,$696A6A69,$6A6A696A,$696A6A69,$69696969,$6A6A6A69,$6A6A696A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A696A,$2A2A2A19,$19191919,$2A2A2A2A,$2A2A2A2A,$1919192A,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$2A191919,$2A2A2A2A,$2A2A2A2A,$19191919,$192A2A2A,$69696969,$6A6A6969,$69696969,$6969696A,$696A6A69,$696A6969,$6A6A6969,$6A6A6A69,$69696969,$69696A69,$6A6A696A,$6A6A6A69,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$2A2A2A19,$2A2A2A2A,$3B3B3B2A,$2A3B3B3B,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$3B3B3B2A,$2A3B3B3B,$2A2A2A2A,$192A2A2A
        long $69696969,$69696969,$6A696969,$6969696A,$696A6A69,$69696969,$6A6A6A69,$6A6A6A6A,$6969696A,$6A6A6A69,$6A6A6A6A,$6A6A6A69,$6A6A696A,$6A6A6A6A,$6A6A696A,$6A6A6A6A,$2A191919,$3B3B2A2A,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$3B3B3B3B,$2A2A3B3B,$1919192A,$69696969,$69696969,$69696969,$6A696969,$696A6A6A,$69696A69,$69696A69,$6A6A6A6A,$6A69696A,$6A6A6A6A,$69696A69,$6A6A6A6A,$6A69696A,$696A6A6A,$696A6A69,$6A6A6A69,$19191919,$2A2A1919,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$1919192A,$19191919,$19191919,$2A191919,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$19192A2A,$19191919
        long $6969696A,$69696969,$68696969,$696A6969,$69696969,$69696969,$69696A69,$6A6A6A6A,$6A6A6A6A,$696A6A6A,$6A696A69,$6A69696A,$696A696A,$6A696A69,$69696969,$6A6A6A69,$19191919,$19191919,$2A2A2A19,$2A2A2A2A,$2A2A2A2A,$19191919,$18181818,$18181818,$18181818,$18181818,$19191919,$2A2A2A2A,$2A2A2A2A,$192A2A2A,$19191919,$19191919,$6A69696A,$696A6969,$69696969,$6A696969,$69696A6A,$696A6A69,$69696969,$6A6A6A69,$6A6A6A69,$696A6A6A,$6A6A6A69,$6A696A6A,$6A6A6969,$6A6A6A69,$6A696969,$6A6A6A6A,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$18181818,$18181818,$18181818,$18181818,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919
        long $6A6A696A,$696A6A69,$69696969,$69696969,$6A696969,$69696969,$69696969,$6A696969,$6A6A696A,$696A6A6A,$6A6A6969,$6A696969,$696A6969,$69696969,$69696969,$6A6A6A6A,$19191918,$19191919,$19191919,$19191919,$19191919,$19191919,$19191918,$19191919,$19191919,$18191919,$19191919,$19191919,$19191919,$19191919,$19191919,$18191919,$69696A69,$69696969,$69696969,$69696969,$69696969,$69696969,$696A696A,$6A696968,$6A6A6A6A,$6A6A6A6A,$696A6A6A,$69696969,$69696969,$6969696A,$6A6A6A6A,$6A6A6A6A,$19181818,$19191919,$19191919,$19191919,$19191919,$19191919,$19191918,$19191919,$19191919,$18191919,$19191919,$19191919,$19191919,$19191919,$19191919,$18181819
        long $69696969,$69696969,$69696969,$69696969,$69696869,$69696969,$6A696969,$6A696968,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$6969696A,$6A696969,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$18181818,$19191918,$19191919,$19191919,$19191919,$19191919,$19191918,$19191919,$19191919,$18191919,$19191919,$19191919,$19191919,$19191919,$18191919,$18181818,$69696969,$6A69696A,$6969696A,$696A6969,$69696A69,$69696969,$69696969,$69696869,$69696969,$6A6A6A69,$6A6A6A6A,$69696A6A,$6A6A6A69,$6A6A6A6A,$6A6A6A6A,$696A6A6A,$18181818,$18181818,$18181818,$18181818,$18181818,$18181818,$19191918,$19191919,$19191919,$18191919,$18181818,$18181818,$18181818,$18181818,$18181818,$18181818
        long $69696969,$696A6A6A,$69696A6A,$69696969,$69696969,$68696969,$69696968,$69686969,$69696969,$6A6A6969,$6A6A6A6A,$696A6A6A,$6A6A6A6A,$6A6A6A6A,$6A6A6A6A,$69696A6A,$18181802,$18181818,$18181818,$18181818,$18181818,$18181818,$2A2A2A18,$2A2A2A2A,$2A2A2A2A,$182A2A2A,$18181818,$18181818,$18181818,$18181818,$18181818,$02181818,$6A696969,$6969696A,$6A696969,$69696969,$69696969,$69696969,$69696968,$69686969,$69696969,$6A696969,$696A6A6A,$696A6A6A,$6A6A6A6A,$6A6A6A6A,$6A69696A,$696A6A69,$18181802,$18181818,$18181818,$18181818,$18181818,$18181818,$18181818,$18181818,$18181818,$18181818,$18181818,$18181818,$18181818,$18181818,$18181818,$02181818
        long $6A6A6969,$696A696A,$69696969,$68696969,$69696969,$69696969,$69696969,$68696969,$69696969,$69696969,$6A696969,$6969696A,$6A6A6A69,$6A6A6A6A,$696A6A69,$69696969,$18181802,$18181818,$19191818,$19191919,$18181819,$18181818,$18181818,$18181818,$18181818,$18181818,$18181818,$19181818,$19191919,$18181919,$18181818,$02181818,$69696969,$69696969,$69696969,$69696969,$69696969,$69696969,$69696969,$69686969,$6A696969,$696A6969,$69696969,$69696969,$69696969,$69696969,$6969696A,$69686969,$18180101,$18181818,$022A1918,$02030303,$5858192A,$58585858,$58585858,$58585858,$58585858,$58585858,$58585858,$2A195858,$03030302,$18192A02,$18181818,$01011818
        long $69696969,$69696969,$69696969,$69696969,$69696969,$69696969,$69696969,$69696869,$69696969,$69696A69,$69696968,$696A6969,$696A6A69,$69696969,$69696969,$69696969,$18020202,$18181818,$03022A19,$03585858,$2A2A1902,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$2A2A2A2A,$02192A2A,$58585803,$192A0203,$18181818,$02020218,$696A6969,$69696969,$69696969,$68686969,$68696968,$69696968,$69696969,$69696969,$696A6969,$69696969,$69696969,$69696969,$69696969,$6A696969,$69696969,$6A6A6A69,$01010202,$02020102,$03020158,$03585858,$19192A02,$19191919,$19191919,$19191919,$19191919,$19191919,$19191919,$022A1919,$58585803,$58010203,$02010202,$02020101
        long $69696969,$69696969,$69696969,$69696969,$68686868,$68686868,$69696969,$68696869,$69696968,$69696969,$69696969,$69696969,$69696969,$69696969,$6969696A,$6A6A6969,$01010202,$01010202,$02015848,$02030303,$58580101,$58585858,$58585858,$58585858,$58585858,$58585858,$58585858,$01015858,$03030302,$48580102,$02020101,$02020101,$69696969,$69696969,$69696869,$69696969,$68686969,$69696968,$69696969,$68696968,$69696868,$69696969,$68686969,$69696969,$69696969,$6A696969,$6A696A69,$6A696A69,$01580202,$02580102,$01580101,$01020202,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02020201,$01015801,$02015802,$02025801
        long $69696968,$69696969,$69686969,$69696869,$69696969,$68696968,$68686869,$68686868,$69686868,$68696969,$69696868,$696A6969,$69696969,$69696969,$6A696969,$6A6A6A6A,$02020202,$02015801,$00585801,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01585800,$01580102,$02020202,$69696968,$69696969,$68686969,$69686969,$68696969,$68686868,$68686868,$68686868,$69696868,$68686869,$69696969,$69696969,$69686969,$6A696969,$6A6A6969,$686A6A69,$01020200,$01010101,$00000101,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01010000,$01010101,$00020201
        long $69696800,$69696969,$68696969,$69696968,$69696969,$68686969,$69696969,$68686868,$69686868,$69686868,$69696868,$69696969,$69696969,$69696969,$69696969,$00686A6A,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$69696800,$69696969,$68696969,$69696968,$69696868,$69696969,$69696969,$68686969,$69686868,$69686868,$69696969,$69696969,$69696969,$69696969,$6A696969,$00686969,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $69680000,$69696969,$69696869,$68686868,$69696869,$69696969,$69686969,$69696969,$69696869,$69696969,$69696969,$69696969,$69696969,$69696969,$69696969,$00686969,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$68000000,$69696969,$69696969,$68686969,$68686868,$68686868,$69696868,$69696869,$69686969,$69696969,$69696969,$69696969,$69696969,$69696969,$69696969,$0000686A,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $68000000,$69696969,$69696969,$69696969,$68686868,$69696969,$A8A9A868,$A9A8A8A8,$A9A899A9,$69696969,$68686868,$68686968,$69696968,$69696969,$69696969,$00000068,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$69696968,$69696969,$69696969,$68696969,$68686868,$A8A88848,$A9A8A8A8,$A899A9A9,$684801AA,$68686868,$68696968,$68696969,$69696968,$68696969,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$69696800,$69696969,$69686869,$69686969,$68686869,$A8484868,$A8A999A8,$A8A8A9A8,$69A9A8A9,$69696968,$69696969,$69686868,$69696969,$00686869,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$68680000,$69696868,$68686869,$68686968,$68696868,$A8016969,$A8A8A8A8,$A8A8A8A8,$48A8A8A8,$68686868,$68686868,$68686868,$68686868,$00000068,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$68000000,$68686868,$68686868,$68696868,$A888A868,$A8A8A8A8,$A8A8A8A8,$0088A8A8,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$68680000,$68686868,$68686868,$A8886868,$A8A8A8A8,$A8A8A8A8,$0000A8A8,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$A8000000,$A8A8A8A8,$A8A8A8A8,$0000A8A8,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$A8000000,$A8A8A8A8,$A8A8A8A8,$0000A8A8,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$A8000000,$A8A8A8A8,$A8A8A8A8,$0000A8A8,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02020202,$02020202,$02020202,$02020202,$A8020202,$A8A8A8A8,$A8A8A8A8,$0202A8A8,$02020202,$02020202,$02020202,$00000202,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$02020000,$02020202,$02020202,$02020202,$02020202,$A8020202,$A8A8A8A8,$A8A8A8A8,$0202A8A8,$02020202,$02020202,$02020202,$02020202,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00000202,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $02050505,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02050505,$05020505,$05050502,$02020502,$02050502,$05050202,$05020205,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $02050505,$05020505,$05050502,$05020502,$02050205,$05020505,$02050502,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02050505,$05020505,$02050205,$05020505,$02050205,$05020505,$02050502,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $02050505,$05020202,$05020505,$05020505,$02050205,$05050202,$02020202,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02050505,$05020505,$05020505,$05020505,$02050205,$05020505,$02050502,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $02050505,$05020505,$05020505,$02020505,$02050502,$05020505,$02050502,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02050505,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$05050505,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$04040400,$00000000,$00000000,$00000000,$00000000,$00040404,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$04040400,$00000000,$00000000,$00000000,$00000000,$00040404,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$04040400,$00000000,$00000000,$00000000,$00000000,$00040404,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$04040402,$02020202,$02020202,$02020202,$02020202,$02040404,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $02020000,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00000002,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02020202,$02020202,$02020202,$02020202,$02020202,$02020202,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000