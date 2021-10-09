' //////////////////////////////////////////////////////////////////////
' TITLE: projectile_demo_001.spin - demos projectile motion, gravity, wind
' effects, collision, and how to make it all work. User moves a "base" turret
' around and fires projectiles with realistic physics models.
'
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 
' VERSION 1.0
' CONTROLS: Use the game pad <RIGHT>/<LEFT> dpad controls to move base turret
' <START> to fire a projectile, <SELECT> to toggle thru information display modes
' and finally <UP>/<DOWN> to control the kinetic energy or initial velocity
' of the projectile. Also, try playing around with the "PHYSICS MODELING PARAMETERS"
' found at the end of the constants section 
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x            ' enable external clock and pll times 4
  _xinfreq = 10_000_000 + 0000        ' set frequency to 10 MHZ plus some error
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
  ' button ids/bit masks
  ' NES bit encodings general for state bits
  NES_RIGHT  = %00000001
  NES_LEFT   = %00000010
  NES_DOWN   = %00000100
  NES_UP     = %00001000
  NES_START  = %00010000
  NES_SELECT = %00100000
  NES_B      = %01000000
  NES_A      = %10000000

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

  ' color constant's to make setting colors for parallax graphics setup easier
  COL_Black       = %0000_0010
  COL_DarkGrey    = %0000_0011
  COL_Grey        = %0000_0100
  COL_LightGrey   = %0000_0101
  COL_BrightGrey  = %0000_0110
  COL_White       = %0000_0111 

  COL_PowerBlue   = %0000_1_100 
  COL_Blue        = %0001_1_100
  COL_SkyBlue     = %0010_1_100
  COL_AquaMarine  = %0011_1_100
  COL_LightGreen  = %0100_1_100
  COL_Green       = %0101_1_100
  COL_GreenYellow = %0110_1_100
  COL_Yellow      = %0111_1_100
  COL_Gold        = %1000_1_100
  COL_Orange      = %1001_1_100
  COL_Red         = %1010_1_100
  COL_VioletRed   = %1011_1_100
  COL_Pink        = %1100_1_100
  COL_Magenta     = %1101_1_100
  COL_Violet      = %1110_1_100
  COL_Purple      = %1111_1_100

  ' each palette entry is a LONG arranged like so: color 3 | color 2 | color 1 | color 0
  COLOR_0 = (COL_Black  << 0)
  COLOR_1 = (COL_Red    << 8)
  COLOR_2 = (COL_Green  << 16)
  COLOR_3 = (COL_Blue   << 24)  

  ' PHYSICS MODELING PARAMETERS -- 

  ' projectile constants
  NUM_PROJS       = 10    ' number of projectiles in the simulation
  PROJ_MASS       = 4     ' larger the mass, slower the projectile, smaller the mass faster the projectile from 1..10 integer

  GRAVITY  = (-1 << 14)   ' fixed point number in 16.16 format for gravity downward
  WIND     = (0 << 13)    ' fixed point number in 16.16 format for wind horizontally 
  FRICTION = 200          ' 255 is nearly no energy lost, 0 is all energy lost
  EPSILON  = $400         ' very small fixed point number squared, that represents "0" for determining when the ball has stopped moving
 


'//////////////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ///////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

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

  long random_var                                         ' global random variable
  long curr_count                                         ' saves counter  

  long base_x, base_y, base_yoff                          ' position of base
  long turret_x, turret_y                                 ' position of turret
  long turret_angle                                       ' turret firing angle         
  long turret_power                                       ' controls initial velocity of projectile

  long vertex_buffer[65]                                  ' used to buffer vertices for transforms, up to 32 vertices can be in the meshes

  long proj_state[NUM_PROJS]                              ' state, position, velocity of projectile (low on memory, so only one)
  long proj_x[NUM_PROJS], proj_y[NUM_PROJS]
  long proj_xv[NUM_PROJS], proj_yv[NUM_PROJS]

  byte string_buffer[65]                                  ' buffers strings

  byte display_mode                                       ' 0=no info, 1=velocity magnitudes, 2=display connectors, 3=magnitudes and connectors

  byte fire_debounce                                      ' debounce fire button
  byte display_debounce                                   ' debounce display select mode 

'//////////////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION //////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////
OBJ
  tv    : "tv_drv_010.spin"          ' instantiate a tv object
  gr    : "graphics_drv_010.spin"    ' instantiate a graphics object
  gp    : "gamepad_drv_001.spin"     ' instantiate gamepad object
  
'//////////////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS ////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

PUB start | i, j, k, dx, dy, x, y, w, h, sinrot, cosrot, pindex

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  'init colors, each tile has same 4 colors
  repeat i from 0 to 64
    colors[i] := COLOR_3 | COLOR_2 | COLOR_1 | COLOR_0
    
  'init tile screen
  repeat dx from 0 to tv_hc - 1
    repeat dy from 0 to tv_vc - 1
      screen[dy * tv_hc + dx] := onscreen_buffer >> 6 + dy + dx * tv_vc + ((dy & $3F) << 10)

  'start and setup graphics 256x192, with orgin (0,0) at bottom left of screen,
  ' simulating quadrant I of a cartesian coordinate system
  gr.start
  gr.setup(X_TILES, Y_TILES, 0, 0, offscreen_buffer)

  ' initialize random variable
  random_var := cnt*171732
  random_var := ?random_var

  ' set up base and turret
  base_x       := SCREEN_WIDTH/2
  base_y       := 15
  turret_angle := ANG_90
  turret_power := 10

  ' reset vars for debounce
  display_debounce := 0
  fire_debounce    := 0

  ' set information display to off
  display_mode     := 0
    
  ' star the game pad driver (will need it later)
  gp.start

  ' BEGIN GAME LOOP ///////////////////////////////////////////////////////////

  ' infinite loop
  repeat while TRUE

    curr_count := cnt ' save current count
   
    'clear the offscreen buffer
     gr.clear
   
  ' INPUT SECTION /////////////////////////////////////////////////////////////
    ' move base
    if (gp.button(NES0_RIGHT) and base_x < SCREEN_WIDTH)
      base_x+=2
    
    if (gp.button(NES0_LEFT) and base_x > 0)
      base_x-=2

    ' rotate turret
    if (gp.button(NES0_A))
      if (turret_angle > ANG_0)
        turret_angle -= ANG_10
    
    if (gp.button(NES0_B))
      if (turret_angle < ANG_180)
        turret_angle += ANG_10



    ' is user trying to fire projectile?
    if (gp.button(NES0_START) and fire_debounce == 0)
      ' debounce fire button
      fire_debounce := 1
                
      ' find an available project
      repeat i from 0 to NUM_PROJS-1
        if (proj_state[i] == 0)
          ' initialize the projectile
          proj_state[i] := 1 ' set to active
           
          ' compute initial position base/turret position, convert to fixed point as well
          proj_x[i] := base_x               << 16 ' since turret is mounted at base_x, base_y and projectile would start its trajectory at this interface 
          proj_y[i] := (base_y + base_yoff) << 16     
           
          ' now compute initial trajectory (note sin/cos already in fixed point format)
          proj_xv[i] := (turret_power+(11-PROJ_MASS))*SinCos(COS, turret_angle) 
          proj_yv[i] := (turret_power+(11-PROJ_MASS))*SinCos(SIN, turret_angle)     
          quit
    elseif (gp.button(NES0_START)==0) ' debounce fire button
      fire_debounce := 0 

    ' test for display mode change?
    if (gp.button(NES0_SELECT) and display_debounce == 0)
      ' debounce select button
      display_debounce := 1
      ' advance display mode
      if (++display_mode > 3)
        display_mode := 0
      
    elseif (gp.button(NES0_SELECT)==0) ' debounce select button
      display_debounce := 0 

     
    ' PHYSICS SIMULATION SECTION ////////////////////////////////////////////

    ' projectile physics
    repeat i from 0 to NUM_PROJS-1
      ' process each projectile
      if (proj_state[i] == 1)
       
        ' apply acceleration of gravity to y component of velocity
        proj_yv[i] := proj_yv[i] + GRAVITY
       
        ' apply accleration due to wind force to x component of velocity
        proj_xv[i] := proj_xv[i] + WIND
       
        ' apply velocity to projectile
        proj_x[i] := proj_x[i] + proj_xv[i]
        proj_y[i] := proj_y[i] + proj_yv[i]
       
        ' test for collisions with walls, every collision absorbs some percentage of the energy, that is decreases the momentum of the ball
        ' this is due to the inelastic collision, and heat that is produced to deform the ball and friction of the surfaces, this way the ball will
        ' come to rest, thus step 1 is to compute the collision, then step 2 is to decrease the velocity a bit
        if ((proj_x[i] => SCREEN_WIDTH << 16) or (proj_x[i] =< 0))
          ' reflect ball
          proj_xv[i] := -proj_xv[i]
       
          ' apply velocity to projectile
          proj_x[i] := proj_x[i] + proj_xv[i]
          proj_y[i] := proj_y[i] + proj_yv[i]
        
          ' now model energy loss due to collision, all of it will be lumped into "FRICTION"
          proj_xv[i] := (proj_xv[i] * FRICTION) ~> 8
          proj_yv[i] := (proj_yv[i] * FRICTION) ~> 8        
       
        if ((proj_y[i] => SCREEN_HEIGHT << 16) or (proj_y[i] =< (PROJ_MASS << 16)))
          ' reflect ball
          proj_yv[i] := -proj_yv[i]
       
          ' apply velocity to projectile
          proj_x[i] := proj_x[i] + proj_xv[i]
          proj_y[i] := proj_y[i] + proj_yv[i]
       
          ' now model energy loss due to collision, all of it will be lumped into "FRICTION"
          proj_xv[i] := (proj_xv[i] * FRICTION) ~> 8
          proj_yv[i] := (proj_yv[i] * FRICTION) ~> 8        
       
        ' test for "dead ball", we need to compute the magnitude of the velocity is 0 AND the ball is at rest at bottom of screen
        if ( ||(proj_y[i] ~> 16) =< PROJ_MASS and (((proj_xv[i]~>8 * proj_xv[i]~>8) + (proj_yv[i]~>8 * proj_yv[i]~>8)) < EPSILON) )  
          proj_state[i] := 0
       
    ' RENDERING SECTION (render to offscreen buffer always/////////////////////

    ' set color for grid
    gr.colorwidth(2,0)
      
    ' draw reference grid
    repeat y from 0 to SCREEN_HEIGHT step 16
      gr.plot(0, y)
      gr.line(SCREEN_WIDTH-1, y)    

    repeat x from 0 to SCREEN_WIDTH step 16
      gr.plot(x, 0)
      gr.line(x, SCREEN_HEIGHT-1)    

    ' set color bounding box 
    gr.colorwidth(1,0)
    ' draw bounding collision rectangle
    gr.plot(0,0)
    gr.line(SCREEN_WIDTH-1, 0)
    gr.line(SCREEN_WIDTH-1, SCREEN_HEIGHT-1)
    gr.line(0, SCREEN_HEIGHT-1)
    gr.line(0,0)

    ' draw projectiles

    repeat i from 0 to NUM_PROJS-1
      if (proj_state[i] == 1)
        gr.colorwidth(1,0)
        gr.arc(proj_x[i] ~> 16, proj_y[i] ~> 16, PROJ_MASS,PROJ_MASS, ANG_0, ANG_45, 9, 2)

    ' draw connectors
    if (display_mode == 2 or display_mode == 3)
      gr.plot(base_x, base_y)
      repeat i from 0 to NUM_PROJS-1
        if (proj_state[i] == 1)
          gr.line(proj_x[i] ~> 16, proj_y[i] ~> 16)

    ' draw base and turret (note turret is drawn relative to base, so objects stay linked in motion)
    ' also note modulation of y-position of hover base using sinusoid, again illustrating the concept of relative coordinate systems
    base_yoff := SinCos(SIN, ((cnt >> 13) & $1FFF) ) ~> 14

    Draw_Polymesh(@base_poly, 3,   base_x, base_y + base_yoff, 2, ANG_0)
    Draw_Polymesh(@turret_poly, 1, base_x, base_y + base_yoff, 2, turret_angle)

    ' print velocity magnitudes    
    if (display_mode == 1 or display_mode == 3)
      gr.textmode(2,1,5,3)
      gr.colorwidth(3,0)
      repeat i from 0 to NUM_PROJS-1
        if (proj_state[i] == 1)
          ItoHex(((proj_xv[i]~>8 * proj_xv[i]~>8) + (proj_yv[i]~>8 * proj_yv[i]~>8)), @string_buffer)
          gr.text(8, 8+i*10, @string_buffer)
    
            
    'copy bitmap to display offscreen -> onscreen
    gr.copy(onscreen_buffer)

    ' synchronize to frame rate would go here...
    'waitcnt(cnt + 666_666)

     ' END RENDERING SECTION ///////////////////////////////////////////////////

  ' END MAIN GAME LOOP REPEAT BLOCK ///////////////////////////////////////////

Pub Draw_Polymesh(pmesh_ptr, col, world_x, world_y, scale, rot) | x0,y0, xtmp, ytmp, xtrans, ytrans, vi, num_verts, cosrot, sinrot
' this function draws a polygon mesh
' pmesh_ptr        - ptr to polygon mesh in proper format
' col              - color to draw in
' world_x, world_y - world_coordinates to draw at (screen coords in this case)
' scale            - scaling factor to scale all vertices, integer 1,2,3,4...
' rot              - rotation angle to rotate mesh ANG_0..ANG_360

  ' extract num verts
  num_verts := long[pmesh_ptr][0]

  ' copy vertices to vertex_buffer for processing, in general, you don't want to transform original meshes, they will degrade after time...
  longmove(@vertex_buffer, pmesh_ptr, num_verts*2+1)

  ' set color
  gr.colorwidth(col, 0)


  ' to save time, don't perform rotation if rot == 0 
  if (rot <> 0)
    ' perform transformations with rotation, thus, for each point scale, rotate, translate to world coords 
    repeat vi from 0 to num_verts-1 
  
      ' transform each point in mesh
      xtrans := vertex_buffer[1 + vi << 1]*scale
      ytrans := vertex_buffer[2 + vi << 1]*scale

      ' perform rotation, if we were doing a lot of transforms we would implement a matrix system
      cosrot := SinCos(COS, rot)
      sinrot := SinCos(SIN, rot)    

      ' finally translate to world position and store back into vertex buffer
      vertex_buffer[1 + vi << 1] := ((xtrans*cosrot - ytrans*sinrot) ~>16) + world_x
      vertex_buffer[2 + vi << 1] := ((xtrans*sinrot + ytrans*cosrot) ~>16) + world_y      
  else
    ' rotation angle must be 0, thus use simflied transforms
    repeat vi from 0 to num_verts-1 
      ' transform each point in mesh
      vertex_buffer[1 + vi << 1]:= vertex_buffer[1 + vi << 1]*scale + world_x
      vertex_buffer[2 + vi << 1]:= vertex_buffer[2 + vi << 1]*scale + world_y

  ' now draw mesh
  gr.plot(vertex_buffer[1], vertex_buffer[2])
  repeat vi from 1 to num_verts-1  
    gr.line(vertex_buffer[1 + vi << 1], vertex_buffer[2 + vi << 1])
  gr.line(vertex_buffer[1], vertex_buffer[2])


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

PUB ItoHex(value, sbuffer) | index
' convert 
repeat index from 0 to 7
  byte[sbuffer][index] := hex_table[ (value >> (28-index*4)) & $F ]

' null terminate the string
byte[sbuffer][8] := 0

' end ItoHex 

' ///////////////////////////////////////////////////////////////////////

'//////////////////////////////////////////////////////////////////////////////
' DATA SECTION ////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

DAT

' polygon meshes for base and turret
' format #vertices, vertex list in x,y pairs
' eg.  n, x0,y0, x1,y1, ...xn-1,yn-1 

base_poly     long      9, 0,0, 2,0, 3,-2, 7,-3, 9,-5, -9,-5, -7,-3, -3,-2, -2,0
turret_poly   long      4, -1,1, 7,1, 7,-1, -1,-1

hex_table     byte    "0123456789ABCDEF"

text          byte "this is a test",0


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
                        long    55_250_000      'broadcast on channel 2 VHF, each channel is 6 MHz above the previous
                        long    0               'auralcog