' //////////////////////////////////////////////////////////////////////
' EXPERIMENTAL PARALLAXAROIDS DEMO PROGRAM 
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 1.9.06
' VERSION 1.4 with glowing led
' COMMENTS: use mouse to rotate ship, only input for now, collision 
' needed, out of memory currently, reorganization needed.
'
' CONTROLS: mouse only supported
'
' Left mouse button fire
' Right mouse button thrust
'
' //////////////////////////////////////////////////////////////////////


'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll4x            ' enable external clock and pll times 4
  _xinfreq = 10_000_000 + 0000        ' set frequency to 10 MHZ plus some error for xtals that are not exact add 1000-5000 usually works
  _stack = ($3000 + $3000 + 64) >> 2 'accomodate display memory and stack

  ' graphics driver and screen constants
  PARAMCOUNT        = 14        
  OFFSCREEN_BUFFER  = $2000           ' offscreen buffer
  ONSCREEN_BUFFER   = $5000           ' onscreen buffer

  ' size of graphics tile map
  X_TILES           = 16
  Y_TILES           = 12
  
  SCREEN_WIDTH      = 256
  SCREEN_HEIGHT     = 192 

  ' text position constants  
  SCORE_X_POS       = -SCREEN_WIDTH/2 + 10
  SCORE_Y_POS       = SCREEN_HEIGHT/2 - 1*14

  HISCORE_X_POS     = -24
  HISCORE_Y_POS     = SCREEN_HEIGHT/2 - 1*14

  SHIPS_X_POS       = SCREEN_WIDTH/2 - 10/2*12
  SHIPS_Y_POS       = SCREEN_HEIGHT/2 - 1*14

  ' ship physics model
  MAX_SHIP_VEL      = 170      

  ' asteroids defines
  NUM_ASTEROIDS     = 6 ' total number of asteroids in game

  ' data structure simulation with indices

  ASTEROID_DS_STATE_INDEX   = 0 ' long, state
  ASTEROID_DS_X_INDEX       = 1 ' long, x position
  ASTEROID_DS_Y_INDEX       = 2 ' long, y position
  ASTEROID_DS_DX_INDEX      = 3 ' long, dx velocity
  ASTEROID_DS_DY_INDEX      = 4 ' long, dy velocity
  ASTEROID_DS_SIZE_INDEX    = 5 ' long, size
 
  ASTEROIDS_DS_LONG_SIZE    = 8 ' 6 longs per asteroid data record

  ' particles defines, used for projectiles as well as explosions
  NUM_PARTICLES             = 3  ' total number of particles in game

  ' data structure simulation with indices

  PARTICLE_DS_TYPE_STATE_INDEX  = 0 ' word, type and state information upper 8-bits type, lower 8-bits state [type7:0|state7:0]
  PARTICLE_DS_X_INDEX           = 1 ' word, x position
  PARTICLE_DS_Y_INDEX           = 2 ' word, y position
  PARTICLE_DS_DX_INDEX          = 3 ' word, dx velocity
  PARTICLE_DS_DY_INDEX          = 4 ' word, dy velocity
  PARTICLE_DS_COUNTER_INDEX     = 5 ' word, used to countdown lifetime

  PARTICLES_DS_WORD_SIZE        = 6 ' 6 longs per particle data record

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

  ' particle types
  PARTICLE_TYPE_NULL            = $00_00 ' lower 8 bits hold state
  PARTICLE_TYPE_SHRAPNEL        = $01_00 ' lower 8 bits hold state
  PARTICLE_TYPE_PLAYER_MISSILE  = $02_00 ' lower 8 bits hold state
  PARTICLE_TYPE_ENEMY_MISSILE   = $04_00 ' lower 8 bits hold state

  ' control interface
  THRUST_BUTTON_ID = 1
  FIRE_BUTTON_ID   = 0

'///////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

VAR

  long  mousex, mousey ' holds mouse x,y position

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

  long  glow_rate     ' glowing led value

  word  screen[x_tiles * y_tiles] ' storage for screen tile map
  long  colors[64]                ' color look up table

  ' player's ship
  long ship_state
  long ship_x
  long ship_y
  long ship_dx
  long ship_dy
  long ship_angle
  long ships_left

  ' asteroids
  long asteroids[ASTEROIDS_DS_LONG_SIZE*NUM_ASTEROIDS]

  ' particles
  word particles[PARTICLES_DS_WORD_SIZE*NUM_PARTICLES]

  ' game state variables
  word game_state 
  word game_counter1
  word game_counter2

  ' active asteroids
  byte num_active_asteroids

  ' random stuff
  byte random_counter



'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

  tv    : "tv_drv_010.spin"          ' instantiate a tv object
  gr    : "graphics_drv_010.spin"    ' instantiate a graphics object
  mouse : "mouse_iso_010.spin"       ' instantiate a mouse object
  glow  : "glow_led_001.spin"        ' glowing led object

'///////////////////////////////////////////////////////////////////////
' EXPORT PUBLICS  //////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB start | i, j, base, base2, dx, dy, x, y, x2, y2, last_cos, last_sin

'///////////////////////////////////////////////////////////////////////
 ' GLOBAL INITIALIZATION ///////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
  'start mouse
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
  gr.setup(16, 12, 128, 96, offscreen_buffer)

  glow_rate := $00000800
  glow.start(@glow_rate)


 ' BEGIN GAME LOOP ////////////////////////////////////////////////////

  repeat 
   ' MASTER GAME STATE MACHINE ////////////////////////////////////////

    case game_state
      GAME_STATE_INIT: ' this state initializes all GAME related vas

        ' seed random counter
        random_counter := 17
 
        'initialize player's ship
        ship_state := OBJECT_STATE_ALIVE
        ship_x     := 0
        ship_y     := 0 
        ship_dx    := 0
        ship_dy    := 0
        ship_angle := ANG_90
        ships_left := 3

        ' set number of asteroids to 0
        num_active_asteroids := 0

        ' initialize asteroids (all of them for now)
        repeat i from 0 to NUM_ASTEROIDS-1  
          base := i*ASTEROIDS_DS_LONG_SIZE     
          asteroids[base+ASTEROID_DS_STATE_INDEX  ] := OBJECT_STATE_ALIVE
          asteroids[base+ASTEROID_DS_X_INDEX      ] := -128+Rand
          asteroids[base+ASTEROID_DS_Y_INDEX      ] := -128+Rand
          asteroids[base+ASTEROID_DS_DX_INDEX     ] := -2 + Rand >> 5
          asteroids[base+ASTEROID_DS_DY_INDEX     ] := -2 + Rand >> 5
          asteroids[base+ASTEROID_DS_SIZE_INDEX   ] := 20 + Rand >> 3
          num_active_asteroids++

        ' initialize particles
        repeat i from 0 to NUM_PARTICLES-1
          base := i*PARTICLES_DS_WORD_SIZE     
          particles[base+PARTICLE_DS_TYPE_STATE_INDEX ] := PARTICLE_TYPE_NULL | OBJECT_STATE_DEAD
          particles[base+PARTICLE_DS_X_INDEX          ] := 0
          particles[base+PARTICLE_DS_Y_INDEX          ] := 0
          particles[base+PARTICLE_DS_DX_INDEX         ] := 0
          particles[base+PARTICLE_DS_DY_INDEX         ] := 0
          particles[base+PARTICLE_DS_COUNTER_INDEX    ] := 0
     
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

        if (game_state == GAME_STATE_RUN)
          ' run state code begins --------------------------------------------
          ' get change in direction
          ship_angle := ship_angle - mouse.delta_x << 5

          ' bounds test ship angle
          if (ship_angle > ANG_360)
            ship_angle -= ANG_360
          elseif (ship_angle < 0) 
            ship_angle +=ANG_360


          ' test for fire button
          if (mouse.button(FIRE_BUTTON_ID))
            ' find an available particle and use it as a projectile
            repeat i from 0 to NUM_PARTICLES-1
              base := i*PARTICLES_DS_WORD_SIZE     
              ' is this particle available for use?
              if (particles[base+PARTICLE_DS_TYPE_STATE_INDEX] & OBJECT_STATE_DEAD )
                ' start particle up              
                particles[base+PARTICLE_DS_TYPE_STATE_INDEX ] := PARTICLE_TYPE_PLAYER_MISSILE | OBJECT_STATE_ALIVE
                particles[base+PARTICLE_DS_X_INDEX          ] := ship_x
                particles[base+PARTICLE_DS_Y_INDEX          ] := ship_y
                particles[base+PARTICLE_DS_DX_INDEX         ] := SinCos(COS, ship_angle) ~> 13
                particles[base+PARTICLE_DS_DY_INDEX         ] := SinCos(SIN, ship_angle) ~> 13
                particles[base+PARTICLE_DS_COUNTER_INDEX    ] := 28
               
                ' break out of repeat loop
                quit
 
          ' end game state run block ------------------------------------------  

        ' END INPUT SECTION ///////////////////////////////////////////////////

        '  ANIMATION SECTION ///////////////////////////////////////////////////
        
        ' apply thrust model if thruster is down
        if (game_state == GAME_STATE_RUN)
          ' run state code block begins ---------------------------------------
          if (mouse.button(THRUST_BUTTON_ID))
            ship_dx += (last_cos := SinCos(COS, ship_angle) << 1 )
            ship_dy += (last_sin := SinCos(SIN, ship_angle) << 1 )

          ' scale down x,y, cache result for later computation
          x := ship_dx ~> 16
          y := ship_dy ~> 16

          ' test for maximum magnitude of thrust
          if ((x*x + y*y) > MAX_SHIP_VEL)
            ' slow ship down
            ship_dx -= (last_cos)
            ship_dy -= (last_sin)

          ' move player
          ship_x += (ship_dx ~> 17)
          ship_y += (ship_dy ~> 17)

          ' screen bounds test for player
          if (ship_x > SCREEN_WIDTH/2)
            ship_x -= SCREEN_WIDTH
          elseif (ship_x < -SCREEN_WIDTH/2)
            ship_x += SCREEN_WIDTH

          if (ship_y > SCREEN_HEIGHT/2)
            ship_y -= SCREEN_HEIGHT
          elseif (ship_y < -SCREEN_HEIGHT/2)
            ship_y += SCREEN_HEIGHT

          ' run state code block ends -------------------------------------------

        ' test for state transition to run
        if (game_state == GAME_STATE_MENU)
          ' menu game state block begins ----------------------------------------
          if (mouse.button(FIRE_BUTTON_ID))
            game_state := GAME_STATE_RUN

          ' menu game state block ends ------------------------------------------

        ' move asteroids
        gr.colorwidth(1,0)
        repeat i from 0 to NUM_ASTEROIDS-1
          base := i*ASTEROIDS_DS_LONG_SIZE
          x := asteroids[base + ASTEROID_DS_X_INDEX] += asteroids[base + ASTEROID_DS_DX_INDEX]
          y := asteroids[base + ASTEROID_DS_Y_INDEX] += asteroids[base + ASTEROID_DS_DY_INDEX]

          ' test for screen boundaries
          if (x > SCREEN_WIDTH/2 )
            asteroids[i*ASTEROIDS_DS_LONG_SIZE + ASTEROID_DS_X_INDEX] := -SCREEN_WIDTH/2
          elseif (x < -SCREEN_WIDTH/2 )
            asteroids[i*ASTEROIDS_DS_LONG_SIZE + ASTEROID_DS_X_INDEX] := SCREEN_WIDTH/2             

          if (y > SCREEN_HEIGHT/2 )
            asteroids[i*ASTEROIDS_DS_LONG_SIZE + ASTEROID_DS_Y_INDEX] := -SCREEN_HEIGHT/2
          elseif (y < -SCREEN_HEIGHT/2 )
            asteroids[i*ASTEROIDS_DS_LONG_SIZE + ASTEROID_DS_Y_INDEX] := SCREEN_HEIGHT/2             
       

        ' END ANIMATION SECTION ////////////////////////////////////////////////
    
        ' RENDERING SECTION ////////////////////////////////////////////////////

        'draw text
        gr.textmode(2,1,5,3)
        gr.colorwidth(2,0)
   
        ' draw score and num players
        gr.text(SCORE_X_POS, SCORE_Y_POS, @score_string)
        gr.text(HISCORE_X_POS, HISCORE_Y_POS, @hiscore_string)
        gr.text(SHIPS_X_POS, SHIPS_Y_POS, @ships_string)

       ' draw vector objects

       ' draw asteroids
       gr.colorwidth(1,0)
       repeat i from 0 to NUM_ASTEROIDS-1
         base := i*ASTEROIDS_DS_LONG_SIZE
         dx := asteroids[base + ASTEROID_DS_X_INDEX]
         dy := asteroids[base + ASTEROID_DS_Y_INDEX]
         gr.vec(dx, dy, asteroids[base + ASTEROID_DS_SIZE_INDEX], base << 8, @asteroid_large)

       ' draw player last

       if (game_state == GAME_STATE_RUN)
         ' first draw thruster
         if (mouse.button(THRUST_BUTTON_ID) and (Rand & $01))
           gr.colorwidth(2,0)
           gr.plot(ship_x, ship_y)
           gr.line(ship_x - (last_cos ~> 15), ship_y - (last_sin ~> 15) )

         ' now ship
         gr.colorwidth(1,0)
         gr.vec(ship_x,ship_y, $0020, ship_angle, @player_ship)

       ' draw players ships left
       gr.colorwidth(3,0)
       repeat i from 0 to ships_left
         gr.vec(SHIPS_X_POS + i << 3 + 4, SHIPS_Y_POS - 4, $0012, $2000 >> 2, @player_ship)

       ' draw particles
       gr.colorwidth(2,0)
       repeat i from 0 to NUM_PARTICLES-1
         base := i*PARTICLES_DS_WORD_SIZE
         if ( not (particles[base+PARTICLE_DS_TYPE_STATE_INDEX] & OBJECT_STATE_DEAD ) )
           x := ~~particles[base+PARTICLE_DS_X_INDEX]
           y := ~~particles[base+PARTICLE_DS_Y_INDEX]

           ' ??? merge movement of particle for now BAD coding, should be in animation section
           ' but not enough memory
           particles[base+PARTICLE_DS_X_INDEX] += particles[base+PARTICLE_DS_DX_INDEX]
           particles[base+PARTICLE_DS_Y_INDEX] += particles[base+PARTICLE_DS_DY_INDEX]

           gr.plot(x,y)
           ' test for end of particle
           if (--particles[base+PARTICLE_DS_COUNTER_INDEX] < 1)
             particles[base+PARTICLE_DS_TYPE_STATE_INDEX] := PARTICLE_TYPE_NULL | OBJECT_STATE_DEAD

       ' draw start game text
       if (game_state == GAME_STATE_MENU and (++game_counter2 & $8))
         gr.textmode(3,1,6,5)
         gr.colorwidth(2,0)
         if (game_counter2 > 100)
           gr.text(0,0,@start_string)
         else
           gr.text(0,0,@parallax_string)

       'copy bitmap to display
       gr.copy(onscreen_buffer)

       ' synchronize to frame rate would go here...

       ' END RENDERING SECTION ///////////////////////////////////////////////

  ' END MAIN GAME LOOP REPEAT BLOCK //////////////////////////////////

' ////////////////////////////////////////////////////////////////////

PUB Rand : retval
  random_counter := (1 + random_counter ^ random_counter << 6 ^ random_counter << 2 ^ random_counter << 7)
  retval := random_counter

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

player_ship             word    $4000+ANG_0             
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
asteroid_large          

                        word    $4000+$2000*45/360      ' vertex 0
                        word    8*8

                        word    $8000+$2000*63/360      ' vertex 1
                        word    4*8

                        word    $8000+$2000*108/360     ' vertex 2
                        word    6*8

                        word    $8000+$2000*147/360     ' vertex 3
                        word    7*8

                        word    $8000+$2000*206/360     ' vertex 4
                        word    4*8

                        word    $8000+$2000*213/360     ' vertex 5
                        word    7*8

                        word    $8000+$2000*243/360     ' vertex 6
                        word    9*8

                        word    $8000+$2000*296/360     ' vertex 7
                        word    4*8

                        word    $8000+$2000*303/360     ' vertex 8
                        word    7*8

                        word    $8000+$2000*348/360     ' vertex 9
                        word    10*8

                        word    $8000+$2000*45/360      ' vertex 0
                        word    8*8

                        word    0

' STRING STORAGE //////////////////////////////////////////////////////

score_string            byte    "Score",0               'text
hiscore_string          byte    "High",0                'text
ships_string            byte    "Ships",0               'text
start_string            byte    "PRESS START",0         'text
parallax_string         byte    "PaRaLLaXaRoiDs",0      'text