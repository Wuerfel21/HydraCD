' //////////////////////////////////////////////////////////////////////
' TITLE: SPACE_DEMO_001.SPIN - friction, gravity demo based on parallaxaroids 
'
' DESCRIPTION:This demo illustrates the use of basic physics modeling to control
' a space craft. The player uses the mouses to navigate and fire thrusters which
' accelerates the ship at a specific rate. Additionally, every frame "friction"
' is applied to the ship which slows it down (yes their IS friction in space! :)
' Finally, there are 3 black holes or gravity wells which cause the ship to accelerate
' toward them, the force generating the acceleration is the standard two body mass
' model based on F = (G*M1*M2)/r^2.
' Finally, the demo makes heavy use of fixed point 16.16 and 24.8 math, so its a bit
' hard to tell what's going on in some cases since there is a lot of scaling and shifting
' occuring, but read the comments to get the general idea. In a system with floating point
' support built in with types, this modeling would be 10x cleaner. 
'
' AUTHOR: Andre' LaMothe
' LAST MODIFIED:
' VERSION 1.0
'
' CONTROLS: mouse only supported, move to rotate, Right mouse button thrust,
' left button toggles asteroids field visibility
'
' //////////////////////////////////////////////////////////////////////


'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x            ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000        ' set frequency to 10 MHZ plus some error for xtals that are not exact add 1000-5000 usually works
  _stack = ($3000 + $3000 + 64) >> 2  ' accomodate display memory and stack

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

  ' game states
  GAME_STATE_INIT      = 0
  GAME_STATE_MENU      = 1
  GAME_STATE_START     = 2
  GAME_STATE_RUN       = 3

  ' asteroids defines
  NUM_ASTEROIDS     = 5 ' total number of asteroids in game

  ' data structure simulation with indices
  ASTEROID_DS_STATE_INDEX   = 0 ' long, state
  ASTEROID_DS_X_INDEX       = 1 ' long, x position
  ASTEROID_DS_Y_INDEX       = 2 ' long, y position
  ASTEROID_DS_DX_INDEX      = 3 ' long, dx velocity
  ASTEROID_DS_DY_INDEX      = 4 ' long, dy velocity
  ASTEROID_DS_SIZE_INDEX    = 5 ' long, size
 
  ASTEROIDS_DS_LONG_SIZE    = 8 ' 6 longs per asteroid data record

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

  ' game object states
  OBJECT_STATE_DEAD    = $00_01
  OBJECT_STATE_ALIVE   = $00_02
  OBJECT_STATE_DYING   = $00_04
  OBJECT_STATE_FROZEN  = $00_08

  ' control interface
  THRUST_BUTTON_ID = 1
  FIRE_BUTTON_ID   = 0

  ' physical modeling constants
  SPACE_FRICTION                = 6   ' from 0 to 15, 0 is infinite friction, 15 is 0.000001 approximately
  NUM_BLACK_HOLES               = 3
  GRAVITATIONAL_CONSTANT        = 1   ' use to make gravity field more or less intense
  MAX_SHIP_VEL                  = 15  ' maximum velocity of player's ship            

  NUM_TRAILERS                  = 15

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

  word  screen[x_tiles * y_tiles] ' storage for screen tile map
  long  colors[64]                ' color look up table

  ' player's ship
  long ship_state
  long ship_x, ship_y
  long ship_dx, ship_dy
  long ship_angle
  long ships_left
  long thrust_dx, thrust_dy 
  long friction_dx, friction_dy
  long bforce_dx, bforce_dy 

  ' asteroids
  long asteroids[ASTEROIDS_DS_LONG_SIZE*NUM_ASTEROIDS]

  long asteroids_vis_toggle                               ' used to toggle visibility of asteroids
  long num_active_asteroids                               ' active asteroids

  long random_var                                         ' global random variable
  long curr_count                                         ' saves counter  

  byte fire_debounce                                     ' button debounce

  word trailers_x[NUM_TRAILERS], trailers_y[NUM_TRAILERS]  ' trailer storage
  byte active_trailers                                   ' number of active trailers 
  
'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

  tv    : "tv_drv_010.spin"          ' instantiate a tv object
  gr    : "graphics_drv_010.spin"    ' instantiate a graphics object
  mouse : "mouse_iso_010.spin"       ' instantiate a mouse object

'///////////////////////////////////////////////////////////////////////
' EXPORT PUBLICS  //////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB start | i, j, base, base2, dx, dy, x, y, x2, y2, length, f, v, a, r, r_squared

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

  'start and setup graphics
  gr.start
  gr.setup(16, 12, 128, 96, offscreen_buffer)

  ' initialize random variable
  random_var := cnt*171732
  random_var := ?random_var
 
   'initialize player's ship
  ship_state := OBJECT_STATE_ALIVE
  ship_x     := 0   
  ship_y     := -80 << 16 
  ship_dx    := 0
  ship_dy    := 0
  ship_angle := ANG_90
  ships_left := 3
  active_trailers := 0
 
  ' set number of asteroids to 0
  num_active_asteroids := 0

  ' set to visible
  asteroids_vis_toggle := 1
 
  ' initialize asteroids (all of them for now)
  repeat i from 0 to NUM_ASTEROIDS-1  
    base := i*ASTEROIDS_DS_LONG_SIZE     
    asteroids[base+ASTEROID_DS_STATE_INDEX  ] := OBJECT_STATE_ALIVE
    asteroids[base+ASTEROID_DS_X_INDEX      ] := Rand_Range(-128, 128)
    asteroids[base+ASTEROID_DS_Y_INDEX      ] := Rand_Range(-128, 128)
    asteroids[base+ASTEROID_DS_DX_INDEX     ] := Rand_Range(-2, 2)
    asteroids[base+ASTEROID_DS_DY_INDEX     ] := Rand_Range(-2, 2)
    asteroids[base+ASTEROID_DS_SIZE_INDEX   ] := Rand_Range(20, 50)
    num_active_asteroids++
  
  ' BEGIN GAME LOOP ////////////////////////////////////////////////////
  repeat
    ' main even loop code here...
    curr_count := cnt ' save current counter value
     
    'clear bitmap
    gr.clear
     
    ' INPUT SECTION //////////////////////////////////////////////////////
 
    ' get change in direction
    ship_angle := ship_angle - mouse.delta_x << 5
 
    ' bounds test ship angle
    if (ship_angle > ANG_360)
      ship_angle -= ANG_360
    elseif (ship_angle < 0) 
      ship_angle +=ANG_360

    ' test if user wants to toggle visibility of asteroids field
    if (mouse.button(FIRE_BUTTON_ID) and fire_debounce == 0)
        asteroids_vis_toggle := -asteroids_vis_toggle
        fire_debounce := 1
    elseif (!mouse.button(FIRE_BUTTON_ID))
        fire_debounce := 0
        
 
    ' END INPUT SECTION ///////////////////////////////////////////////////////
 
    '  ANIMATION SECTION //////////////////////////////////////////////////////

    ' PHYSICS MODEL BEGINS HERE ///////////////////////////////////////////////
     
    ' all calculations for ship thrust and position model are performed in fixed point math  
    if (mouse.button(THRUST_BUTTON_ID))
      ' compute thrust vector, scale down cos/sin a bit to slow ship's acceleration
      thrust_dx := SinCos(COS, ship_angle) ~> 1
      thrust_dy := SinCos(SIN, ship_angle) ~> 1

      ' apply thrust to ships current velocity
      ship_dx += thrust_dx
      ship_dy += thrust_dy
 
    ' apply friction model, always in opposite direction of velocity
    ' frictional force is proportional to velocity, use power of 2 math to save time
    friction_dx := -ship_dx ~> SPACE_FRICTION
    friction_dy := -ship_dy ~> SPACE_FRICTION    

    ' apply the friction against the ships current velocity
    ship_dx += friction_dx
    ship_dy += friction_dy    

    ' now compute the acceleration toward the black hole, model based on F = (G*M1*M2)/r^2
    ' in other words, the force is equal to the product of the two masses times some constant G divided
    ' by the distance between the masses squared. Thus, we more or less need to accelerate the ship
    ' toward the black hole(s) proportional to some lumped constant divided by the distance to the black
    ' hole squared...
    ' sum the accelerations up (resulting in velocity changes to the ship)
    repeat i from 0 to NUM_BLACK_HOLES-1
      ' compute each force direction vector d(dx ,dy) toward the black hole, so we can compute its length 
      dx := (black_x[i]) - (ship_x ~> 16)
      dy := (black_y[i]) - (ship_y ~> 16)
      r_squared  := (dx*dx + dy*dy) ' no need to compute length r, when we are going to use r^2 in a moment 
       
      ' now compute the actual force itself, which is proportional to accel which in this sim will be used to change velocity each frame
      f := ((GRAVITATIONAL_CONSTANT * black_gravity[i]) << 9 ) / r_squared  
     
      ' f can be thought of as acceleration since its proportional to mass which is virtual and can be assumed to be 1
      ' thus we can use it to create a velocity vector toward the black hole now in the direction of of the vector d(dx, dy)
      dx := dx << 16 ' convert to fixed point
      dy := dy << 16 

      ' compute length of d which is just r, careful to compute fixed point values properly
      r := (^^(r_squared << 16)) ' square root operation turns 16.16 into 24.8

      ' normalize the vector and scale by force magnityde 
      dx := f*((dx / r) << 8)
      dy := f*((dy / r) << 8)

      ' update velocity with acceleration due to black hole
      ship_dx += dx ~> 3 
      ship_dy += dy ~> 3 

    ' clamp maximum velocity, otherwise ship will get going light speed due to black holes when the distance approaches 0!
    dx := (ship_dx ~> 16)
    dy := (ship_dy ~> 16)    
    
    ' test if ship velocity greater than threshold
    v := ^^(dx*dx + dy*dy)

    ' perform comparison (to squared max, to make math easier)
    if (v > MAX_SHIP_VEL)
      ' scale velocity vector back approx 1/8th
      ship_dx := MAX_SHIP_VEL*(ship_dx  / v)            
      ship_dy := MAX_SHIP_VEL*(ship_dy  / v)
    
    ' finally apply the velocity to the position of the ship
    ship_x += ship_dx 
    ship_y += ship_dy
 
    ' screen bounds test for player
    if (ship_x > (SCREEN_WIDTH/2)<< 16)
      ship_x -= SCREEN_WIDTH<<16
    elseif (ship_x < (-SCREEN_WIDTH/2)<<16)
      ship_x += SCREEN_WIDTH<<16
 
    if (ship_y > (SCREEN_HEIGHT/2)<<16)
      ship_y -= SCREEN_HEIGHT<<16
    elseif (ship_y < (-SCREEN_HEIGHT/2)<<16)
      ship_y += SCREEN_HEIGHT<<16


    ' PHYSICS MODEL END HERE //////////////////////////////////////////////////

 
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
    if (asteroids_vis_toggle == 1)
      repeat i from 0 to NUM_ASTEROIDS-1
        base := i*ASTEROIDS_DS_LONG_SIZE
        dx := asteroids[base + ASTEROID_DS_X_INDEX]
        dy := asteroids[base + ASTEROID_DS_Y_INDEX]
        gr.vec(dx, dy, asteroids[base + ASTEROID_DS_SIZE_INDEX], base << 8, @asteroid_large)
       
    ' draw player last
    ' extract whole parts of fixed point position to save time in parameters
    x := ship_x ~> 16
    y := ship_y ~> 16    
    
    ' first draw thruster
    if (mouse.button(THRUST_BUTTON_ID) and (?random_var & $01))
      gr.colorwidth(2,0)
      gr.plot(x, y)
      gr.line(x - (thrust_dx ~> 13), y - (thrust_dy ~> 13) )
     
    ' now ship
    gr.colorwidth(1,0)
    gr.vec(x, y, $0020, ship_angle, @player_ship)

    ' now trailers
    if (active_trailers < NUM_TRAILERS-1)
      ' insert trailer into list
      trailers_x[active_trailers] := ship_x ~> 16
      trailers_y[active_trailers] := ship_y ~> 16
      active_trailers++
    else
      ' out of space discard oldest trailer
      wordmove(@trailers_x[0], @trailers_x[1], NUM_TRAILERS-1)
      wordmove(@trailers_y[0], @trailers_y[1], NUM_TRAILERS-1)      
      ' insert trailer at end
      trailers_x[active_trailers] := ship_x ~> 16
      trailers_y[active_trailers] := ship_y ~> 16

    ' draw trailers
    repeat i from 0 to NUM_TRAILERS-1
      gr.plot(~~trailers_x[i], ~~trailers_y[i])
     
    ' draw players ships left
    gr.colorwidth(3,0)
    repeat i from 0 to ships_left
      gr.vec(SHIPS_X_POS + i << 3 + 4, SHIPS_Y_POS - 4, $0012, $2000 >> 2, @player_ship)

    ' draw black holes
    gr.colorwidth(2,0)
 
    repeat i from 0 to NUM_BLACK_HOLES-1
      x := black_x[i]
      y := black_y[i]
      length := black_gravity[i]
      repeat 10
        gr.plot(x,y)
        gr.line(x + Rand_Range(-length,length), y + Rand_Range(-length,length) )

    ' END ANIMATION SECTION ////////////////////////////////////////////////
     
    'copy bitmap to display
    gr.copy(onscreen_buffer)
     
    ' lock frame rate to 15-30 frames to slow this down
    waitcnt(cnt + 666_666)

  ' END MAIN GAME LOOP REPEAT BLOCK //////////////////////////////////

' ////////////////////////////////////////////////////////////////////

Pub Rand_Range(rstart, rend) : r_delta
' returns a random number from [rstart to rend] inclusive
r_delta := rend - rstart + 1
result := rstart + ((?random_var & $7FFFFFFF) // r_delta)

return result

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


' BLACK HOLES ///////////////////////////////////////////////////////////

' black hole initialization
black_x                  long 20,  80, -90 ' x position of each black hole
black_y                  long 50, -60, -10 ' y position of each black hole
black_gravity            long  8,  4,  2   ' single value that is "lumped" parameter that relates to the final "pull"
                                           ' of the black hole relative to the ship's constant mass

' STRING STORAGE //////////////////////////////////////////////////////

score_string            byte    "Score",0               'text
hiscore_string          byte    "High",0                'text
ships_string            byte    "Ships",0               'text


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
