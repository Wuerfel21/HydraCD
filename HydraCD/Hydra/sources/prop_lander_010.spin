' //////////////////////////////////////////////////////////////////////
' EXPERIMENTAL LUNAR LANDER DEMO PROGRAM 
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 5.10.06
' VERSION 1.0
' COMMENTS: 
'
' CONTROLS: gamepad (must be plugged in)
'
' //////////////////////////////////////////////////////////////////////


'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal1 + pll8x              ' enable external clock and pll times 4
  _xinfreq = 10_000_000 + 0000          ' set frequency to 10 MHZ plus some error
  _stack = ($2400 + $2400 + $100) >> 2  'accomodate display memory and stack

  ' graphics driver and screen constants
  PARAMCOUNT        = 14        
  OFFSCREEN_BUFFER  = $3800           ' offscreen buffer
  ONSCREEN_BUFFER   = $5C00           ' onscreen buffer

  ' size of graphics tile map
  X_TILES           = 12
  Y_TILES           = 12
  
  SCREEN_WIDTH      = 192
  SCREEN_HEIGHT     = 192 

  ' text position constants  
  HUD_X_POS       = -SCREEN_WIDTH/2 + 10
  HUD_Y_POS       = SCREEN_HEIGHT/2 - 1*14

  LANDERS_X_POS       = SCREEN_WIDTH/2 - 12/2*12
  LANDERS_Y_POS       = SCREEN_HEIGHT/2 - 1*14

  ' lander physics model
  MAX_LANDER_VEL      = 15
  GRAVITY             = $0000_0100 ' 2^-4

  ' angular constants to make object declarations easier
  ANG_0    = $0000
  ANG_360  = $2000
  ANG_240  = ($2000*2/3)
  ANG_180  = ($2000/2)
  ANG_120  = ($2000/3)
  ANG_90   = ($2000/4)
  ANG_60   = ($2000/6)
  ANG_45   = ($2000/8)
  ANG_30   = ($2000/12)
  ANG_22_5 = ($2000/16)
  ANG_15   = ($2000/24)
  ANG_10   = ($2000/36)
  ANG_5    = ($2000/72)

  ' constants for math functions
  SIN      = 0
  COS      = 1

  ' game states
  GAME_STATE_INIT      = 0
  GAME_STATE_MENU      = 1
  GAME_STATE_START     = 2
  GAME_STATE_RUN       = 3

  ' game object states
  OBJECT_STATE_DEAD    = $00_01
  OBJECT_STATE_ALIVE   = $00_02
  OBJECT_STATE_DYING   = $00_04
  OBJECT_STATE_FROZEN  = $00_08

  ' control interface
  THRUST_BUTTON_ID = 1
  FIRE_BUTTON_ID   = 0

  ' control keys
  KB_LEFT_ARROW  = $C0
  KB_RIGHT_ARROW = $C1
  KB_UP_ARROW    = $C2
  KB_DOWN_ARROW  = $C3
  KB_ESC         = $CB
  KB_SPACE       = $20
  KB_ENTER       = $0D

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

  word  screen[x_tiles * y_tiles] ' storage for screen tile map
  long  colors[64]                ' color look up table

  ' player's lander all in fixed point 16.16
  long lander_state
  long lander_x
  long lander_y

  long lander_wp_x      ' whole part
  long lander_wp_y

  long lander_dp_x      ' decimal part
  long lander_dp_y

  long lander_dx
  long lander_dy
  long lander_angle
  long lander_left

  ' game state variables
  word game_state 
  word game_counter1
  word game_counter2

  ' random stuff
  byte random_counter

  ' string/key stuff
  byte sbuffer[9]
  byte curr_key
  byte temp_key 
  long data

  ' nes gamepad vars
  long nes_buttons

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

  tv    : "tv_drv_010.spin"        ' instantiate a tv object
  gr    : "graphics_drv_010.spin"  ' instantiate a graphics object
  mouse : "mouse_iso_010.spin"     ' instantiate a mouse object
  key   : "keyboard_iso_010.spin"       ' instantiate a mouse object      
      
'///////////////////////////////////////////////////////////////////////
' EXPORT PUBLICS  //////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB start | i, j, base, base2, dx, dy, x, y, x2, y2, last_cos, last_sin

'///////////////////////////////////////////////////////////////////////
 ' GLOBAL INITIALIZATION ///////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

  'start keyboard on pingroup 
  key.start(3)

  'start mouse on pingroup 
  mouse.start(2)

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  'init colors
  repeat i from 0 to 64
    colors[i] := $00001010 * (i+4) & $F + $FB060C02

  'init tile screen
  repeat dx from 0 to tv_hc - 1
    repeat dy from 0 to tv_vc - 1
      screen[dy * tv_hc + dx] := onscreen_buffer >> 6 + dy + dx * tv_vc + ((dy & $3F) << 10)

  ' reset game state 
  game_state     := GAME_STATE_INIT

  'start and setup graphics
  gr.start
  gr.setup(12, 12, 96, 96, offscreen_buffer)

 ' BEGIN GAME LOOP ////////////////////////////////////////////////////

  repeat 
   ' MASTER GAME STATE MACHINE ////////////////////////////////////////

    case game_state
      GAME_STATE_INIT: ' this state initializes all GAME related vas

        ' seed random counter
        random_counter := 17
 
        'initialize player's ship
        lander_state := OBJECT_STATE_ALIVE
        lander_x     := 0
        lander_y     := 0 
        lander_dx    := 0
        lander_dy    := 0
        lander_angle := ANG_90
        lander_left := 3
   
        ' initialize game state counters
        game_counter1  := 0
        game_counter2  := 0

        ' set initial state to menu
        game_state := GAME_STATE_MENU

      GAME_STATE_START: ' the game is ready to start, do any housekeeping and run

        game_state := GAME_STATE_MENU

      GAME_STATE_RUN, GAME_STATE_MENU: ' the game is running...

        'clear bitmap
        gr.clear

        ' INPUT SECTION //////////////////////////////////////////////////////

        ' get nes controller buttons (right stick)
        nes_buttons := NES_Read_Gamepad

        if (game_state == GAME_STATE_RUN)
          ' run state code begins --------------------------------------------
          ' get change in direction
          lander_angle := lander_angle - mouse.delta_x << 5

          if (nes_buttons & NES_RIGHT)
            lander_angle -= ANG_10
          else
          if (nes_buttons & NES_LEFT)
            lander_angle += ANG_10

          ' bounds test ship angle
          if (lander_angle > ANG_360)
            lander_angle -= ANG_360
          elseif (lander_angle < 0) 
            lander_angle +=ANG_360

           ' end game state run block ------------------------------------------  

        ' END INPUT SECTION ///////////////////////////////////////////////////
 
        '  ANIMATION SECTION ///////////////////////////////////////////////////
        
        ' apply thrust model if thruster is down
        if (game_state == GAME_STATE_RUN)
          ' run state code block begins ---------------------------------------
          if (nes_buttons & NES_B)
            lander_dx += (last_cos := SinCos(COS, lander_angle) ~> 6 )
            lander_dy += (last_sin := SinCos(SIN, lander_angle) ~> 6 )

          ' add gravity
          lander_dy -= GRAVITY

          ' scale down x,y, cache result for later computation
          x := lander_dx ~> 16
          y := lander_dy ~> 16

          ' test for maximum magnitude of thrust
          if ((x*x + y*y) > MAX_LANDER_VEL)
            ' slow ship down
            lander_dx -= (lander_dx ~> 8)
            lander_dy -= (lander_dy ~> 8)

          ' move player
          lander_x += (lander_dx)
          lander_y += (lander_dy)

          ' cache whole parts
          lander_wp_x := lander_x ~> 16
          lander_wp_y := lander_y ~> 16

          ' screen bounds test for player
          if (lander_wp_x > SCREEN_WIDTH/2)
            lander_x -= (SCREEN_WIDTH << 16)
          elseif (lander_wp_x < -SCREEN_WIDTH/2)
            lander_x += (SCREEN_WIDTH << 16)

          if (lander_wp_y > SCREEN_HEIGHT/2)
            lander_y -= (SCREEN_HEIGHT << 16)
          elseif (lander_wp_y < -SCREEN_HEIGHT/2)
            lander_y += (SCREEN_HEIGHT << 16)

          ' run state code block ends -------------------------------------------

        ' test for state transition to run
        if (game_state == GAME_STATE_MENU)
          ' menu game state block begins ----------------------------------------
          if (nes_buttons & NES_START)
            game_state := GAME_STATE_RUN

          ' menu game state block ends ------------------------------------------

 
        ' END ANIMATION SECTION ////////////////////////////////////////////////
    
        ' RENDERING SECTION ////////////////////////////////////////////////////

        'draw text
        gr.textmode(2,1,5,3)
        gr.colorwidth(2,0)
   
        ' draw score and num players
        gr.text(HUD_X_POS, HUD_Y_POS, @hud_string)
        gr.text(LANDERS_X_POS, LANDERS_Y_POS, @landers_string)

       ' draw vector objects

       ' draw mountain, static for now
        gr.colorwidth(1,0)
        gr.plot(-96, -96)
        y := -80
        repeat i from 0 to 19
          gr.line(-96 + i*10,y)
          ' update y
          y += mountain_scape[i]
       
       ' draw player last

       if (game_state == GAME_STATE_RUN)
         ' first draw thruster
         if ( (nes_buttons & NES_B) and (Rand & $01))
           gr.colorwidth(2,0)
           gr.plot(lander_wp_x, lander_wp_y)
           gr.line(lander_wp_x - (last_cos ~> 8), lander_wp_y - (last_sin ~> 8) )

         ' now ship
         gr.colorwidth(1,0)
         gr.vec(lander_wp_x, lander_wp_y, $0020, lander_angle, @lander_model)

       ' draw players ships left
       gr.colorwidth(3,0)
       repeat i from 0 to lander_left
         gr.vec(LANDERS_X_POS + i << 3 + 4, LANDERS_Y_POS - 4, $0012, $2000 >> 2, @lander_model)

       ' draw start game text
       if (game_state == GAME_STATE_MENU and (++game_counter2 & $8))
         gr.textmode(3,1,6,5)
         gr.colorwidth(2,0)
         if (game_counter2 > 100)
           gr.text(0,0,@start_string)
         else
           gr.text(0,0,@title_string)

       'copy bitmap to display
       gr.copy(onscreen_buffer)

       ' END RENDERING SECTION ///////////////////////////////////////////////

  ' END MAIN GAME LOOP REPEAT BLOCK //////////////////////////////////

' ////////////////////////////////////////////////////////////////////

PUB Plot_Pixel(x, y, video_buffer, color)               | video_offset, pixel_value
  ' plot pixel calculation using BYTE aligned calcs 192x192 bitmap, 12x12 tiles
  video_offset := video_buffer + (x >> 4) * (192*4) + ((x & %1111) >> 2) + (y << 2)

 ' read pixel group from memory
  pixel_value := byte[video_offset]

  ' mask AND out target bits, so color mixing doesn't occur
  pixel_value := pixel_value & !(%00000011 << ((x & %11) << 1))
  
  ' OR color with pixel value
  pixel_value := pixel_value | (color << ((x & %11) << 1))

  ' write pixel back to memory
  byte[video_offset] := pixel_value
 
' ////////////////////////////////////////////////////////////////////

PUB Plot_Pixel2(x, y, video_buffer, color)              | video_offset, pixel_value
  ' plot pixel calculation using LONG aligned calcs 192x192 bitmap, 12x12 tiles
  video_offset := (video_buffer >> 2) + (x >> 4) * (192) + y

  ' read pixel group from memory
  pixel_value := long[0][video_offset]
      
  ' mask AND out target bits, so color mixing doesn't occur
  pixel_value := pixel_value & !(%11 << ((x & %1111) << 1))

  ' OR color with pixel value
  pixel_value := pixel_value | (color << ((x & %1111) << 1))

  ' write pixel back to memory
  long[0][video_offset] := pixel_value

    
' ////////////////////////////////////////////////////////////////////

PUB Rand : retval
  random_counter := (1 + random_counter ^ random_counter << 6 ^ random_counter << 2 ^ random_counter << 7)
  retval := random_counter

' ////////////////////////////////////////////////////////////////////

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

PUB Delay (count)      | i, x, y, z
  ' delay count times inner loop length
  repeat  i from  0 to count

' ////////////////////////////////////////////////////////////////////

PUB SinCos(op, angle): xy
  if (op==COS)
    angle+=$800   

  if angle & $1000 
    if angle & $800
      -angle
    angle |= $7000
    xy := -word[angle << 1]
  else
    if angle & $800
      -angle
    angle |= $7000
    xy := word[angle << 1]

' //////////////////////////////////////////////////////////////////////


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

' POLYGON OBJECTS ///////////////////////////////////////////////////////

lander_model            word    $4000+ANG_0             
                        word    50

                        word    $8000+ANG_120
                        word    50

                        word    $8000+ANG_180
                        word    10

                        word    $8000+ANG_240
                        word    50

                        word    $8000+ANG_0
                        word    50

                        word    0

' STRING STORAGE //////////////////////////////////////////////////////

hex_table               byte    "0123456789ABCDEF"
hud_string              byte    "Readouts",0            'text
landers_string          byte    "Landers",0             'text
start_string            byte    "PRESS START",0         'text
title_string            byte    "Mars Lander",0         'text

' MOUNTAIN SCAPE delta Y positions for cheesy mountains!
mountain_scape          long 0, 10,3,5,-10,-2,15,20,10,-40, 0,0, 15, 10,3, -30, -10, 5, 6, 10,-20


'///////////////////////////////////////////////////////////////////////
' WORK AREA SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////