' //////////////////////////////////////////////////////////////////////
' Ball Buster - breakout clone          
' AUTHOR: JT Cook
' LAST MODIFIED: 1.31.06
' VERSION 0.1
' Use the mouse or the gamepad to control the paddle
' Gamepad code and Rand function from Andre's asteroids demo
' Template based on Nick's Deep Cavern code
' Int_to_String PUB from Colin's Liner demo
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll4x            ' enable external clock and pll times 4
  _xinfreq = 10_000_000 + 0000        ' set frequency to 10 MHZ plus some error for xtals that are not exact add 1000-5000 usually works
  _stack = ($3000 + $3000 + 64) >> 2  ' accomodate display memory and stack   

  ' graphics driver and screen constants
  PARAMCOUNT        = 14        
  OFFSCREEN_BUFFER  = $2000           ' offscreen buffer
  ONSCREEN_BUFFER   = $5000           ' onscreen buffer

  X_TILES           = 16
  Y_TILES           = 12
  
  SCREEN_WIDTH      = 256
  SCREEN_HEIGHT     = 192 

  ' NES bit encodings
  NES_RIGHT  = %00000001
  NES_LEFT   = %00000010
  NES_DOWN   = %00000100
  NES_UP     = %00001000
  NES_START  = %00010000
  NES_SELECT = %00100000
  NES_B      = %01000000
  NES_A      = %10000000
  

'///////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

VAR

  long  tv_status     '0/1/2 = off/visible/invisible           read-only
  long  tv_enable     '0/? = off/on                            write-only
  long  tv_pins       '%ppmmm = pins                           write-only
  long  tv_mode       '%ccinp = chroma,interlace,ntsc/pal,swap write-only
  long  tv_screen     'pointer to screen (words)               write-only
  long  tv_colors     'pointer to colors (longs)               write-only               
  long  tv_hc         'horizontal cells                        write-only
  long  tv_vc         'vertical cells                          write-only
  long  tv_hx         'horizontal cell expansion               write-only
  long  tv_vx         'vertical cell expansion                 write-only
  long  tv_ho         'horizontal offset                       write-only
  long  tv_vo         'vertical offset                         write-only
  long  tv_broadcast  'broadcast frequency (Hz)                write-only
  long  tv_auralcog   'aural fm cog                            write-only

  word  screen[X_TILES * Y_TILES] ' storage for screen tile map
  long  colors[64]                ' color look up table
  
  ' nes gamepad vars
  long nes_buttons

  ' random stuff
  byte random_counter
  
  ' paddle location
  long player_x, player_y
  ' ball location
  long ball_x, ball_y, ball_x_check, ball_y_check, brick_check
  ' ball direction
  long ball_x_dir, ball_y_dir
  ' playing field
  byte brick_wall[8*8]
  long brick_draw_x, brick_draw_y
  byte brick_draw_loop, brick_loop
  


'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

  tv    : "tv_drv_010.spin"          ' instantiate a tv object
  gr    : "graphics_drv_010.spin"    ' instantiate a graphics object
  mouse : "mouse_iso_010.spin"       ' instantiate a mouse object

'///////////////////////////////////////////////////////////////////////
' GLOBAL INITIALIZATION ///////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB start | i, dx, dy, rotation

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)
  
  repeat i from 0 to 64
    ' $33221100   $(Color 3)(Color 2)(Color 1)(Color 0)
    colors[i] := $077C2B02
'   colors[i] := $07050302 ' black and white
  'init tile screen

  repeat dx from 0 to tv_hc - 1
    repeat dy from 0 to tv_vc - 1
      screen[dy * tv_hc + dx] := onscreen_buffer >> 6 + dy + dx * tv_vc + ((dy & $3F) << 10)
    
  'start and setup graphics
  gr.start
  gr.setup(X_TILES, Y_TILES, 128, 96, offscreen_buffer)
  'start mouse on pingroup 2 (Hydra mouse port)
  mouse.start(2)
  ' seed random counter
  random_counter := 17
  ' set player's initial position
  player_x := 100
  player_y := 8
  ' set initial ball location
  ball_x := 100
  ball_y := 80
  ball_x_dir := -1
  ball_y_dir := -1
  ' fill brick 8x8 brick wall
  repeat brick_loop from 0 to 64
    brick_wall[brick_loop]:=1
  ' draws the background
  draw_background
'///////////////////////////////////////////////////////////////////////
' MAIN LOOP              ///////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
  repeat while TRUE
  
    ' draw sprites
    gr.pix(player_x-128, player_y-96, 0, @player_pix)
    gr.pix(ball_x-128,ball_y-96,0,@ball_pix)
    'copy bitmap to display
    gr.copy(onscreen_buffer)
    ' erase sprites
    gr.box(ball_x-128,ball_y-96,4,4)
    gr.box(player_x-128,player_y-96,32,8)

    ' move player
    nes_buttons := NES_Read_Gamepad
    if((nes_buttons & NES_RIGHT) <> 0)
      player_x += 1
    if((nes_buttons & NES_LEFT) <> 0)
      player_x -= 1
    ' get mouse input
    player_x += mouse.delta_x
'   if((nes_buttons & NES_DOWN) <> 0)
'     player_y -= 1
'   if((nes_buttons & NES_UP) <> 0)
'     player_y += 1

    ' sets player limits
    if (player_x > 144-32)
      player_x := 144-32
    if (player_x < 16)
      player_x := 16
      
    ' check colision with paddle and ball
    if(player_x < ball_x+3)
      if(player_x+32 > ball_x)
        if(player_y+7 < ball_y+3)
          if(player_y+8 > ball_y)
             ball_y_dir :=1

    ' check colision with ball and brick
    repeat brick_loop from 0 to 3
      ball_x_check:=ball_x-16
      ball_y_check:=ball_y-4    
      if(brick_loop==0) ' check top of ball
       ball_x_check += 1
      elseif(brick_loop==1) ' check bottom of ball
       ball_x_check += 1
       ball_y_check -= 4
      elseif(brick_loop==2) ' check left of ball
       ball_y_check -= 1
      else '(brick_loop==3) ' check right of ball
       ball_y_check -= 1
       ball_x_check += 3      
      ' check the wall and find x/y coords for brick wall
      if(ball_y_check > 88)
        ball_y_check -= 88
        ball_y_check /= 8
        ball_x_check /= 16
        'make sure we are in the limits of the blocks
        if(ball_x_check < 8)
          if(ball_y_check < 8)      
             brick_check:= ball_y_check * 8 + ball_x_check
             if(brick_wall[brick_check]==1) 'if block is solid
               brick_wall[brick_check]:=0  ' break it
               if(brick_loop==0) ' top of ball
                 ball_y_dir:= -1
               if(brick_loop==1) ' bottom of ball
                 ball_y_dir:= 1
               if(brick_loop==2) ' left of ball
                 ball_x_dir := 1
               if(brick_loop==3) ' right of ball
                 ball_x_dir:= -1
               draw_bricks ' redraw playfield
                 
    ' move ball
    ball_x += ball_x_dir
    ball_y += ball_y_dir
    
    ' check limits on ball
    if(ball_y > 191-4-8)
      ball_y_dir :=-1
    if(ball_y < 0 )
      ball_y := 80
    if(ball_x > 143-4)
      ball_x_dir := -1
    if(ball_x < 17)
      ball_x_dir := 1


  ' end of main loop
' //////////////////////////////////////////////////////////////////
PUB draw_background
  gr.clear
  ' draw playfield
  draw_bricks
  ' draw border
  repeat brick_draw_loop from 0 to 192-16 step 8
    gr.pix(0-128,brick_draw_loop-96,0,@border_side_pix)
    gr.pix(144-128,brick_draw_loop-96,0,@border_side_pix)
  repeat brick_draw_loop from 16 to 144-16 step 16
    gr.pix(brick_draw_loop-128, 192-96-8,0,@border_top_pix)
    gr.pix(0-128,192-96-8,0,@border_corner_pix)
    gr.pix(159-128,192-96-8,4,@border_corner_pix)
  ' draw title text
    gr.textmode(2,2,6,5)
    gr.colorwidth(3,1)
    gr.text(194-128,170-92,@game_title1)
    gr.text(200-128,150-92,@game_title2)
    'score text
    gr.colorwidth(1,14)
    gr.box(48, -8, 48, 26)
    gr.textmode(1,1,6,5)
    gr.colorwidth(3,0)
    Int_To_String(@value_string, ball_x_check)
    gr.text(72,10,@score_text)
    gr.text(72,-1,@value_string)

    'set box color
    gr.colorwidth(0,0)
' //////////////////////////////////////////////////////////////////
PUB draw_bricks  
    ' draw play field
    brick_draw_loop := 0
    repeat brick_draw_y from 0 to 56 step 8
     repeat brick_draw_x from -112 to 0 step 16
      if(brick_wall[brick_draw_loop]==1)
        gr.pix(brick_draw_x,brick_draw_y,0,@brick_pix)
      else
        gr.box(brick_draw_x,brick_draw_y,16,8)
      brick_draw_loop ++

' //////////////////////////////////////////////////////////////////
PUB Int_To_String(str, i) | t

' does an sprintf(str, "%05d", i); job
str+=4
repeat t from 0 to 4
  BYTE[str] := 48+(i // 10)
  i/=10
  str--

' //////////////////////////////////////////////////////////////////
PUB NES_Read_Gamepad : nes_bits        |  i

' //////////////////////////////////////////////////////////////////
' NES Game Paddle Read
' //////////////////////////////////////////////////////////////////       
' reads both gamepads in parallel encodes 8-bits for each in format
' right game pad #1 [15..8] : left game pad #0 [7..0]
'
' set I/O ports to proper direction
' P3 = JOY_CLK      (4)
' P4 = JOY_SH/LDn   (5) 
' P5 = JOY_DATAOUT0 (6)
' P6 = JOY_DATAOUT1 (7)
' NES Bit Encoding
'
' RIGHT  = %00000001
' LEFT   = %00000010
' DOWN   = %00000100
' UP     = %00001000
' START  = %00010000
' SELECT = %00100000
' B      = %01000000
' A      = %10000000

' step 1: set I/Os
DIRA [3] := 1 ' output
DIRA [4] := 1 ' output
DIRA [5] := 0 ' input
DIRA [6] := 0 ' input

' step 2: set clock and latch to 0
OUTA [3] := 0 ' JOY_CLK = 0
OUTA [4] := 0 ' JOY_SH/LDn = 0
'Delay(1)

' step 3: set latch to 1
OUTA [4] := 1 ' JOY_SH/LDn = 1
'Delay(1)

' step 4: set latch to 0
OUTA [4] := 0 ' JOY_SH/LDn = 0

' step 5: read first bit of each game pad

' data is now ready to shift out
' first bit is ready 
nes_bits := 0

' left controller
nes_bits := INA[5] | (INA[6] << 8)

' step 7: read next 7 bits
repeat i from 0 to 6
 OUTA [3] := 1 ' JOY_CLK = 1
 'Delay(1)             
 OUTA [3] := 0 ' JOY_CLK = 0
 nes_bits := (nes_bits << 1)
 nes_bits := nes_bits | INA[5] | (INA[6] << 8)

 'Delay(1)             
' invert bits to make positive logic
nes_bits := (!nes_bits & $FFFF)

' //////////////////////////////////////////////////////////////////
' End NES Game Paddle Read
' //////////////////////////////////////////////////////////////////       

' ////////////////////////////////////////////////////////////////////

PUB Rand : retval
  random_counter := (1 + random_counter ^ random_counter << 6 ^ random_counter << 2 ^ random_counter << 7)
  retval := random_counter

'///////////////////////////////////////////////////////////////////////
' DATA SECTION /////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

DAT

' TV PARAMETERS FOR DRIVER /////////////////////////////////////////////

tvparams                long    0               'status
                        long    1               'enable
                        long    %011_0000       'pins
                        long    %0000           'mode
                        long    0               'screen
                        long    0               'colors
                        long    x_tiles         'hc
                        long    y_tiles         'vc
                        long    10              'hx timing stretch
                        long    1               'vx
                        long    0               'ho
                        long    0               'vo
                        long    55_250_000      'broadcast
                        long    0               'auralcog


player_pix
        byte 4, 8, 0, 0
        word %%00333333,%%00000000,%%00000000,%%33333300
        word %%03333331,%%11111111,%%11111111,%%13333330
        word %%33333311,%%11111233,%%33211111,%%11333333
        word %%33333311,%%11113333,%%33331111,%%11333333
        word %%33333311,%%11133211,%%11233111,%%11333333
        word %%33333311,%%11111111,%%11111111,%%11333333
        word %%03333331,%%11111111,%%11111111,%%13333330
        word %%00333333,%%00000000,%%00000000,%%33333300

ball_pix
        byte 1,4,0,0
        word %%03300000
        word %%33330000
        word %%33330000
        word %%03300000
       
brick_pix
        byte 2,8,0,0
        word %%33333333,%%33333333
        word %%32222222,%%22222221
        word %%32223333,%%33332221
        word %%32223222,%%22212221
        word %%32223222,%%22212221
        word %%32221111,%%11112221
        word %%32222222,%%22222221
        word %%11111111,%%11111111
border_side_pix
        byte 2,8,0,0
        word %%11112233,%%33221111
        word %%11112233,%%33221111
        word %%11112233,%%33221111
        word %%11112233,%%33221111
        word %%11112233,%%33221111
        word %%11112233,%%33221111
        word %%11112233,%%33221111
        word %%11112233,%%33221111
border_top_pix
        byte 2,8,0,0
        word %%11111111,%%11111111
        word %%11111111,%%11111111
        word %%22222222,%%22222222
        word %%33333333,%%33333333
        word %%33333333,%%33333333
        word %%22222222,%%22222222
        word %%11111111,%%11111111
        word %%11111111,%%11111111
border_corner_pix
        byte 2,8,0,0
        word %%00001111,%%11111111
        word %%00111111,%%11111111
        word %%01111122,%%22222222
        word %%01111223,%%33333333
        word %%11112233,%%33333333
        word %%11112233,%%33322222
        word %%11112233,%%33221111
        word %%11112233,%%33221111
game_title1             byte " Ball",0           'text
game_title2             byte "Buster",0          'text
score_text              byte "Score",0           'text
value_string            byte    "00000",0        'text