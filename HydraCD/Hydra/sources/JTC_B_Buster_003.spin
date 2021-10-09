' //////////////////////////////////////////////////////////////////////
' Ball Buster - breakout clone          
' AUTHOR: JT Cook
' LAST MODIFIED: 2.14.06
' VERSION 0.3
' moved most of the gameplay to JTC_B_Buster_Logic in asm
'
' Use the mouse or the control the paddle
' Template based on Nick's sound demo code
' Int_to_String PUB from Colin's Liner demo
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll4x            ' enable external clock and pll times 4
  _xinfreq = 10_000_000 + 0000        ' set frequency to 10 MHZ plus some error for xtals that are not exact add 1000-5000 usually works
  _stack = ($3000 + $3000 +18 ) >> 2 ' accomodate display memory and stack    

  ' graphics driver and screen constants
  PARAMCOUNT        = 14        
  OFFSCREEN_BUFFER  = $2000           ' offscreen buffer
  ONSCREEN_BUFFER   = $5000           ' onscreen buffer

  X_TILES           = 16
  Y_TILES           = 12
  
  SCREEN_WIDTH      = 256
  SCREEN_HEIGHT     = 192   

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
  long  colors[18]                ' color look up table  
  'score
  long score
  ' paddle location
  byte player_x, player_y
  ' ball location
  byte ball_x, ball_y
  byte ball_bounce
  ' playing field
  byte brick_draw_x, brick_draw_y, brick_loop, brick_draw_loop
  byte brick_wall[65]
  byte Men 
'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

  tv    : "tv_drv_010.spin"          ' instantiate a tv object
  gr    : "JTC_graphics_drv_010.spin" ' instantiate a graphics object
  mouse : "mouse_iso_010.spin"       ' instantiate a mouse object
  logic : "JTC_B_B_Logic_003.spin" 'Game logic

'///////////////////////////////////////////////////////////////////////
' GLOBAL INITIALIZATION ///////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB start | i, dx, dy, rotation

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)                                      

  'setup color map and palette
  repeat i from 0 to 12
    ' $33221100   $(Color 3)(Color 2)(Color 1)(Color 0)
    colors[i] := $071E1D02
  'init tile screen
 
    colors[13] := $07DDDB02 ' brick rows 1&2
    colors[14] := $077D7B02 ' brick rows 3&4
    colors[15] := $071D1B02 ' brick rows 5&6
    colors[16] := $07BDAB02 ' brick rows 7&8

    colors[12] := $07050402 ' player paddle
  ' color table for screen rows (0-11)

  repeat dx from 0 to tv_hc - 1
    repeat dy from 0 to tv_vc - 1
      screen[dy * tv_hc + dx] := onscreen_buffer >> 6 + dy + dx * tv_vc + ((dy & $3F) << 10)
  ' color table for bricks in playfield (13-16)
  repeat dy from 2 to 5
     repeat dx from 1 to 8
        i:=dy+11              
        screen[dy * tv_hc + dx] := onscreen_buffer >> 6 + dy + dx * tv_vc + ((dy+11 & $3F) << 10)
  ' color table for player paddle (12)
  repeat dx from 1 to 8
            screen[11 * tv_hc + dx] := onscreen_buffer >> 6 + 11 + dx * tv_vc + ((12 & $3F) << 10)
  'start and setup graphics
  gr.start
  gr.setup(X_TILES, Y_TILES, 128, 96, offscreen_buffer)
  'start mouse on pingroup 2 (Hydra mouse port)
  mouse.start(2)
  ' start logic cog
  logic.start
  ' feed the addresses of variables to logic cog
  logic.Get_Mem_Address(@player_x,@player_y,@ball_x,@ball_y,@ball_bounce, @score, @brick_wall)
  ' set player's initial position
  player_x := 50
  player_y := 8
  ball_x := 50
  ball_y :=16
  ball_bounce:=3
  men:=0
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
    'move player
    player_x += mouse.delta_x
    if(ball_bounce==6)
       draw_bricks
       ball_bounce:=0
       update_score
       ball_y:=20
    if(ball_bounce==0)
     if((mouse.button(0)&1) <> 0) ' mouse button to release ball
      ball_bounce:=1
    if(ball_bounce==2)  'if a player hit a brick
      'draw_bricks
      erase_one_brick
      update_score
      ball_bounce:=1
    if(ball_bounce==3) ' start screen
      gr.textmode(2,2,6,5)
      gr.colorwidth(3,2)
      gr.text(-50,-10,@start_title1)
      gr.text(-50,-40,@start_title2)
      gr.colorwidth(0,0)
      ball_bounce:=4
      Men:=3
      score:=0
      logic.Load_Level_(0)
      draw_bricks
    if(ball_bounce==4)
      if((mouse.button(0)&1) <> 0) ' mouse button to start
         gr.colorwidth(0,0)
         gr.box(-80,-50,60,50)
         ball_bounce:=0
         update_score
    if(ball_bounce==5)  ' lose a life
       if(Men<1)     ' if no more lives, game over
        ball_bounce:=3
       else           'else start ball on paddle
        Men-=1
        ball_bounce:=0
        update_score
    logic.Game_Loop ' Do game logic
  ' end of main loop
' //////////////////////////////////////////////////////////////////
PUB draw_background
  gr.clear
  ' draw border
   gr.colorwidth(1,14)
   gr.box(-128,-92,160,188)
   gr.color(2)
   gr.box(-124,-92,152,186)
   gr.color(3)
   gr.box(-120,-92,144,184)
   gr.colorwidth(0,0)
   gr.box(-112,-92,128,181)
  ' draw title text  
    gr.textmode(2,2,6,5)
    gr.colorwidth(3,2)
    gr.text(66,78,@game_title1)
    gr.text(72,58,@game_title2)
    update_score
  ' draw playfield
    draw_bricks
' //////////////////////////////////////////////////////////////////
PUB update_score
    gr.color(0)
    gr.box(50, -33, 35, 6)
    gr.colorwidth(1,14)
    gr.box(48, -8, 48, 26)
    gr.textmode(1,1,6,5)
    gr.colorwidth(3,0)
    'score text
    Int_To_String(@value_string, score)
    gr.text(72,10,@score_text)
    gr.text(72,-1,@value_string)    
    'players remaining
    repeat brick_draw_y from 0 to men
     if(brick_draw_y>0)
       gr.pix(52+(brick_draw_y*8), -32,0, @ball_pix)
    gr.colorwidth(0,0)
    'set box color

' //////////////////////////////////////////////////////////////////
PUB erase_one_brick
  brick_draw_loop:=0
    repeat brick_draw_y from 0 to 56 step 8
     repeat brick_draw_x from 0 to 112 step 16
      if(brick_draw_loop==brick_wall[64])
        gr.box(brick_draw_x-112,brick_draw_y,16,8)
      brick_draw_loop++
' //////////////////////////////////////////////////////////////////
PUB draw_bricks  
    ' draw play field
    brick_draw_loop := 0
    repeat brick_draw_y from 0 to 56 step 8
     repeat brick_draw_x from 0 to 112 step 16
      if(brick_wall[brick_draw_loop]==1)
        gr.pix(brick_draw_x-112,brick_draw_y,0,@brick_pix)
      else
        gr.box(brick_draw_x-112,brick_draw_y,16,8)
      if(brick_draw_loop<64)
      brick_draw_loop ++

' //////////////////////////////////////////////////////////////////
PUB Int_To_String(str, i) | t

' does an sprintf(str, "%05d", i); job
str+=4
repeat t from 0 to 4
  BYTE[str] := 48+(i // 10)
  i/=10
  str--

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
        word %%01333333,%%00000000,%%00000000,%%33333310
        word %%13322332,%%11121111,%%11112111,%%23333331
        word %%33233321,%%11211233,%%33211211,%%12333333
        word %%33233311,%%11113333,%%33331111,%%11333333
        word %%33333311,%%11133211,%%11233111,%%11333233
        word %%33333321,%%11111111,%%11111111,%%12333233
        word %%13333332,%%11111222,%%22211111,%%23322331
        word %%01333333,%%00000000,%%00000000,%%33333310

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

game_title1             byte " BALL",0           'text
game_title2             byte "BUSTER",0          'text
score_text              byte "SCORE",0           'text
start_title1            byte "PRESS",0           'text
start_title2            byte "START",0           'text
value_string            byte "00000",0