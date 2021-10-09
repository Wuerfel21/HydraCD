'' Racer Demo 4-8-06 
'' JT Cook
'' Based on Remi's graphic drivers which have been hacked apart for the road effect and
''   my own sprite routines. 
'' This is the first release. It has sprites working(only one drawn right now).
'' Up and down are gas and brake. Left and right drive left and right.
'' There is a bug in road calculation routines(Calc_Skew) that will slows the main program
''   down, but I haven't looked into that. Also for this version I "borrowed" and the car
''   graphic from Outrun.
'' My next step is to add sprite scaling. If worse comes to worse, I may drop the resolution
''   down to 128 horizontal pixels.
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
xxx5                   = SCANLINE_BUFFER-24 '
xxx6                   = SCANLINE_BUFFER-28   
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
  byte car_speed          'how fast the car is moving
  long car_speed_long     'larger scale for car speed
  'sprite stuff
  byte sprite_x[16]       'sprite location on screen
  byte sprite_y[16]
  byte sprite_x_len[16]   'length of the sprite in pixels
  byte sprite_y_len[16]   'height of sprite in pixels
  byte sprite_x_scale[16] 'size in pixels of scaled sprite
  byte sprite_y_scale[16]
  
OBJ

  tv    : "rem_tv_014.spin"             ' tv driver
  gfx   : "Racer_gfx_engine_002.spin"     ' graphic driver


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
  long[spin_sprite_adr]:= @test_sprite_ 'address for graphic data for sprite
  ' Boot requested number of rendering cogs:
  ' cog_total values are:
  ' 1 = Unnacceptable: screen will flicker horrendously
  ' 2 = No sprite, i.e.: just enough cpu power to render the tilemap
  ' 3 = Couple of sprites.
  ' 4 = A lot of sprites.
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

  repeat kk from 0 to 15
   sprite_x_len[kk]:=56 'stress test
   sprite_y_len[kk]:=38 'stress test
   sprite_x[kk]:=(kk*16)-16   'stress test
   sprite_y[kk]:=150    'stress test

  sprite_x[1]:=100
  sprite_y[1]:=150
  sprite_x_len[1]:=56
  sprite_y_len[1]:=38
   
  road_x_off:=255 'start with road centered

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
     ' sprite_x[1] += 1
     if(road_x_off<506)
      road_x_off += 3      
    if((temp1 & NES0_LEFT) <> 0)
      'sprite_x[1] -= 1
     if(road_x_off>3)
       road_x_off -= 3      
    if((temp1 & NES0_DOWN) <> 0)
      car_speed_long-=1
      if(car_speed_long<1)
         car_speed_long+=10
         if(car_speed>0)
          car_speed-=1
          
'      if(car_speed_long<1)
'        car_speed_long:=0
      'sprite_y[1] += 1
    if((temp1 & NES0_UP) <> 0)
      car_speed_long+=1
      if(car_speed_long>10)
         car_speed_long-=10
         if(car_speed<10)
           car_speed+=1
         
      'sprite_y[1] -= 1       

    Calc_Skew(road_x_off) ' calc road angle perspective

'end of main
'---------------------------------------------
PUB Calc_Skew(RoadOff) | k,kk,pp, swing
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

    road_offset[kk]:=road_x_cntr 'add x offset

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
'debug test sprite
test_sprite2
byte $5,$5,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$5,$5
byte $5,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$5
byte $0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
byte $0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
byte $0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
byte $0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
byte $5,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$5
byte $5,$5,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$5,$5
test_sprite
byte $0,$0,$5,$5,$5,$5,$0,$0,$0,$0,$5,$5,$5,$5,$0,$0
byte $0,$5,$5,$6c,$5,$5,$5,$0,$0,$5,$5,$5,$5,$5,$5,$0
byte $5,$5,$5,$6c,$5,$5,$5,$5,$5,$5,$5,$5,$5,$5,$5,$5
byte $5,$5,$5,$6c,$5,$5,$5,$5,$5,$5,$5,$5,$5,$5,$5,$5
byte $5,$5,$5,$5,$5,$5,$5,$5,$5,$5,$5,$5,$5,$5,$5,$5
byte $5,$5,$5,$5,$5,$5,$5,$5,$5,$5,$5,$5,$5,$5,$5,$5
byte $0,$5,$5,$5,$5,$5,$5,$0,$0,$5,$5,$5,$5,$5,$5,$0
byte $0,$0,$5,$5,$5,$5,$0,$0,$0,$0,$5,$5,$5,$5,$0,$0
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
test_sprite_
' Dimensions: 64x39
                        byte    $00, $00, $00, $05, $49, $49, $49, $05, $05, $49, $49, $49, $05, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $49, $49, $49
                        byte    $05, $05, $05, $49, $49, $49, $49, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $49, $49, $03, $49, $49, $49, $49, $49, $03, $03, $49, $49, $00, $00
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $00, $49, $49, $03, $49
                        byte    $49, $49, $49, $49, $03, $49, $49, $49, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $49, $03, $49, $49, $49, $49, $03, $03, $49, $c9, $c9, $c9, $c9, $c9, $c9
                        byte    $c9, $c9, $c9, $c9, $c9, $c9, $c9, $c9, $c9, $c9, $c9, $c9, $c9, $c9, $c9, $c9
                        byte    $c9, $c9, $c9, $c9, $c9, $c9, $c9, $c9, $c9, $c9, $c9, $c9, $49, $49, $49, $49
                        byte    $03, $03, $03, $49, $49, $49, $49, $49, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $49, $49, $49, $49, $c9, $c9, $c9, $c9, $c9, $c9, $c9, $c9, $c9, $aa, $aa
                        byte    $aa, $c9, $c9, $c9, $aa, $aa, $c9, $aa, $aa, $aa, $c9, $aa, $aa, $c9, $c9, $aa
                        byte    $aa, $aa, $aa, $c9, $aa, $aa, $aa, $aa, $c9, $c9, $aa, $c9, $c9, $c9, $c9, $c9
                        byte    $c9, $49, $49, $05, $49, $49, $49, $49, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $49, $49, $c9, $c9, $c9, $c9, $aa, $aa, $aa, $aa, $49, $aa, $aa, $aa, $aa
                        byte    $c9, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $c9, $aa, $aa, $aa, $aa, $c9, $aa
                        byte    $aa, $aa, $aa, $aa, $c9, $c9, $aa, $aa, $aa, $aa, $aa, $c9, $aa, $aa, $aa, $aa
                        byte    $c9, $c9, $c9, $c9, $c9, $05, $05, $49, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $49, $c9, $c9, $aa, $aa, $aa, $aa, $aa, $c9, $aa, $aa, $c9, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $aa, $aa, $aa, $c9
                        byte    $c9, $aa, $c9, $aa, $c9, $c9, $c9, $49, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $49, $c9, $aa, $c9, $aa, $aa, $aa, $aa, $aa, $c9, $c9, $49, $4b, $4b, $49
                        byte    $4b, $4b, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $4b, $4b, $49, $4b, $4b, $aa, $aa, $aa
                        byte    $aa, $aa, $c9, $aa, $aa, $c9, $c9, $c9, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $aa, $aa, $c9, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $c9, $4b, $49, $49, $4b
                        byte    $49, $49, $4b, $49, $49, $49, $49, $05, $05, $05, $05, $05, $05, $05, $05, $05
                        byte    $05, $05, $49, $49, $49, $49, $49, $4b, $49, $49, $4b, $49, $49, $4b, $aa, $aa
                        byte    $aa, $aa, $aa, $aa, $c9, $c9, $c9, $c9, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $03, $49, $49, $03
                        byte    $49, $49, $03, $49, $49, $49, $49, $05, $05, $49, $05, $49, $49, $05, $49, $05
                        byte    $49, $05, $49, $49, $49, $49, $49, $03, $49, $49, $03, $49, $49, $03, $aa, $aa
                        byte    $aa, $aa, $aa, $aa, $aa, $aa, $aa, $c9, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $49, $05, $05, $49
                        byte    $05, $05, $ab, $ab, $aa, $aa, $c9, $05, $05, $49, $05, $05, $05, $05, $05, $05
                        byte    $49, $05, $c9, $c9, $aa, $aa, $aa, $49, $05, $05, $49, $05, $05, $49, $aa, $aa
                        byte    $aa, $aa, $aa, $aa, $aa, $aa, $aa, $c9, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $aa, $aa, $aa, $ab, $aa, $aa, $aa, $ab, $aa, $aa, $aa, $aa, $aa, $ab, $ab, $ab
                        byte    $aa, $aa, $aa, $aa, $aa, $c9, $c9, $05, $49, $05, $49, $05, $49, $05, $49, $05
                        byte    $49, $05, $c9, $c9, $aa, $aa, $aa, $ab, $ab, $ab, $aa, $aa, $aa, $aa, $aa, $ab
                        byte    $ab, $ab, $aa, $aa, $ab, $aa, $aa, $c9, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $ab, $ab, $aa, $aa, $aa, $aa, $aa, $ab, $ab, $ab, $ab, $ac, $ac, $04, $ac, $ac
                        byte    $ac, $ab, $ab, $ab, $aa, $aa, $c9, $05, $05, $05, $05, $05, $05, $05, $05, $05
                        byte    $05, $05, $c9, $c9, $aa, $aa, $aa, $ab, $ab, $ab, $aa, $ab, $aa, $aa, $aa, $aa
                        byte    $aa, $aa, $aa, $aa, $aa, $aa, $aa, $c9, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $04, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $ab, $ab, $ac, $ac, $04, $ac, $04, $04
                        byte    $ab, $ab, $aa, $aa, $aa, $aa, $aa, $ab, $aa, $aa, $aa, $aa, $aa, $ab, $aa, $ab
                        byte    $ab, $ab, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $ab, $ab, $ab, $aa, $ab
                        byte    $ab, $aa, $aa, $aa, $aa, $ab, $ab, $c9, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $05, $05, $05, $ab, $ac, $04, $04, $aa, $aa, $aa, $ab, $ab, $04, $04, $ab, $04
                        byte    $ac, $04, $04, $04, $ac, $ac, $ac, $ac, $04, $04, $04, $04, $05, $aa, $04, $04
                        byte    $04, $04, $04, $04, $ac, $ab, $ab, $ac, $04, $04, $04, $04, $ac, $ac, $ab, $ab
                        byte    $ab, $ab, $ac, $ac, $04, $04, $04, $ab, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $05, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $49, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $05, $49, $05, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $aa, $aa, $aa
                        byte    $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $49, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $05, $05, $05, $05, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $aa, $aa, $aa
                        byte    $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $aa, $aa, $aa, $8c, $8c, $8c, $8c, $8c, $05, $05, $05, $05, $49, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $05, $49, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $05, $05, $05
                        byte    $05, $8c, $8c, $8c, $8c, $8c, $aa, $aa, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $aa, $aa, $aa, $8c, $8c, $8c, $8c, $8c, $05, $05, $05, $05, $49, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $05, $05, $49, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $05, $05, $05
                        byte    $05, $8c, $8c, $8c, $8c, $8c, $aa, $aa, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $ab, $aa, $aa, $aa, $ab, $aa, $aa, $ac, $aa, $ab, $ab, $aa, $aa, $ab, $aa, $aa
                        byte    $ab, $ab, $ac, $ac, $ab, $ab, $ab, $ab, $ab, $aa, $aa, $aa, $aa, $aa, $aa, $ab
                        byte    $ab, $ab, $ab, $ab, $aa, $ab, $aa, $aa, $ac, $ac, $aa, $aa, $ab, $ab, $ab, $aa
                        byte    $ab, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $ab, $aa, $aa, $aa, $ab, $aa, $aa, $ac, $aa, $ab, $ab, $aa, $aa, $ab, $aa, $aa
                        byte    $ab, $ab, $ac, $ac, $ab, $ab, $ab, $ab, $ab, $aa, $aa, $aa, $aa, $aa, $aa, $ab
                        byte    $ab, $ab, $ab, $ab, $aa, $ab, $aa, $aa, $ac, $ac, $aa, $aa, $ab, $ab, $ab, $aa
                        byte    $ab, $aa, $aa, $aa, $aa, $aa, $aa, $ac, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $ab, $ab, $ac, $ac, $04, $ac, $ac, $ac, $ac, $ac, $ac, $ac, $04, $04, $04
                        byte    $04, $04, $ab, $ab, $ac, $04, $04, $04, $05, $05, $05, $05, $aa, $04, $04, $04
                        byte    $04, $ac, $04, $04, $04, $04, $ac, $ab, $ab, $ab, $05, $05, $05, $05, $04, $04
                        byte    $04, $ac, $ac, $04, $05, $04, $04, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $04, $04, $ab, $ab, $04, $04, $ab, $ab, $ab, $aa, $aa, $ab, $ac, $ac, $ac
                        byte    $ac, $04, $04, $04, $ac, $ac, $04, $ac, $04, $04, $ac, $ac, $ac, $ac, $ab, $aa
                        byte    $aa, $aa, $aa, $ab, $ab, $ac, $ac, $aa, $aa, $aa, $aa, $aa, $ab, $ab, $ab, $aa
                        byte    $ac, $04, $05, $ac, $05, $05, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $04, $ac, $ac, $ac, $ab, $04, $04, $aa, $49, $49, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49
                        byte    $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $49, $ab, $ab, $ac, $04
                        byte    $04, $05, $05, $05, $04, $04, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $04, $04, $ac, $ac, $04, $aa, $49, $49, $49, $49
                        byte    $ac, $04, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa
                        byte    $aa, $aa, $aa, $aa, $aa, $ac, $04, $05, $49, $49, $49, $ab, $ab, $ab, $ac, $ac
                        byte    $05, $05, $ab, $ab, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $04, $ac, $04, $05, $ac, $aa, $aa, $03
                        byte    $03, $03, $4b, $4b, $4b, $4b, $4b, $4b, $4b, $4b, $03, $03, $03, $03, $03, $03
                        byte    $03, $03, $49, $49, $49, $49, $49, $49, $49, $49, $03, $03, $aa, $aa, $ab, $04
                        byte    $ab, $aa, $aa, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $04, $04, $04, $04, $04, $1b, $1b
                        byte    $1a, $1a, $1b, $1b, $1b, $1a, $1a, $1b, $04, $04, $05, $05, $05, $05, $05, $05
                        byte    $05, $04, $ea, $8c, $04, $04, $04, $ea, $04, $03, $05, $05, $ab, $ab, $ab, $05
                        byte    $04, $ab, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $04, $04, $04, $04, $1b
                        byte    $1b, $1b, $1b, $1b, $1b, $1b, $1b, $1b, $04, $05, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $8c, $8c, $8c, $8c, $04, $8c, $8c, $05, $00, $00, $00, $aa, $aa, $ab
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $aa, $00, $00, $00
                        byte    $00, $00, $00, $04, $04, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $8c, $8c, $8c, $8c, $8c, $8c, $8c, $8c, $8c, $00, $00, $00, $c9, $aa, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $aa, $aa, $00, $00
                        byte    $00, $00, $00, $02, $02, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $8c, $8c, $8c, $8c, $8c, $8c, $8c, $8c, $8c, $00, $00, $00, $aa, $ab, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $aa, $aa, $00, $00
                        byte    $00, $00, $02, $02, $02, $02, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $8c, $8c, $8c, $8c, $8c, $8c, $8c, $8c, $8c, $00, $00, $aa, $aa, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $aa, $00
                        byte    $00, $04, $02, $02, $ab, $02, $04, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $8c, $8c, $8c, $8c, $8c, $8c, $8c, $8c, $00, $aa, $aa, $aa, $aa, $aa
                        byte    $aa, $aa, $aa, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $ab, $05, $05, $05, $aa, $aa, $ac, $00, $aa, $aa
                        byte    $00, $02, $02, $02, $02, $02, $02, $00, $00, $00, $49, $05, $05, $05, $05, $49
                        byte    $00, $00, $8c, $8c, $8c, $8c, $8c, $8c, $8c, $00, $00, $aa, $ab, $ab, $ab, $ab
                        byte    $05, $05, $05, $aa, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $ab, $05, $05, $05, $aa, $ab, $00, $00, $aa, $aa
                        byte    $00, $02, $02, $02, $02, $ab, $ab, $00, $00, $00, $49, $05, $05, $05, $05, $49
                        byte    $00, $00, $8c, $8c, $8c, $8c, $8c, $8c, $00, $00, $aa, $aa, $00, $00, $00, $ab
                        byte    $05, $05, $05, $ac, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $ac, $ab, $ab, $ab, $00, $00, $00, $00, $aa
                        byte    $aa, $02, $02, $02, $02, $ab, $ab, $00, $00, $00, $00, $00, $49, $49, $00, $00
                        byte    $00, $00, $8c, $8c, $8c, $8c, $8c, $8c, $00, $aa, $aa, $ab, $00, $00, $00, $00
                        byte    $ac, $04, $04, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $ab
                        byte    $aa, $02, $02, $02, $ab, $02, $ab, $aa, $aa, $aa, $aa, $c9, $aa, $c9, $c9, $aa
                        byte    $aa, $aa, $aa, $8c, $8c, $8c, $8c, $8c, $c9, $c9, $aa, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $ab, $ab, $02, $02, $ab, $ab, $aa, $aa, $ab, $ab, $aa, $aa, $ab, $ab, $ab, $aa
                        byte    $aa, $aa, $aa, $aa, $8c, $8c, $8c, $aa, $aa, $ab, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $02, $ab, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00