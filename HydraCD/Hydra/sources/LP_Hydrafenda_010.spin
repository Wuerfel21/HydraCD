' //////////////////////////////////////////////////////////////////////
' Hydra-fenda                           
' AUTHOR: Lorenzo Phillips
' LAST MODIFIED: 2.10.06
' VERSION 1.0
' //////////////////////////////////////////////////////////////////////
'
' To play:
'   Move left, right, up, or down with the arrow keys on the keyboard.
'
' Summary of changes:
'  - 
'
' *** Detailed Change Log ***
' ---------------------------
' v1.0 (2.10.06):
' - Made the scrolling seamless in both directions (i.e., world-wrap).
' - Extended the landscape to the left of the screen for a complete world.
' - Added player bounds.  Once a bound is reached, the landscape scrolls.
' - Added game titles (i.e., Score, Hi-Score, and Ships)---NO SCORE YET!
' - Added gravity to pull player back to the center if not thrusting.
'
'
' *** To-Do List ***
' ------------------
' - Add a scrolling star field.
' - Add some particles for player thrusting.
' - Add gamepad control.
' - Add content for top titles (actual score, hi-score, etc.).
'
'
' *** Way Down the Road ***
' --------------------------
' - Draw a better player ship (use vector graphics).
' - Add enemies throughout the world.
' - Only draw the visible landscape instead entire landscape each time.
' - Fix code to get around memory constraints.
'
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x            ' enable external clock and pll times 8 (80MHz)
  _xinfreq = 10_000_000 + 0000        ' set frequency to 10 MHZ plus some error
  _stack = ($3000 + $3000 + 64) >> 2  ' accomodate display memory and stack

  ' graphics driver and screen constants
  PARAMCOUNT        = 14        
  OFFSCREEN_BUFFER  = $2000           ' offscreen buffer
  ONSCREEN_BUFFER   = $5000           ' onscreen buffer

  ' size of graphics tile map
  X_TILES           = 16
  Y_TILES           = 12
  
  ' window dimensions
  SCREEN_WIDTH      = 256
  SCREEN_HEIGHT     = 192

  ' text position constants
  SCORE_X_POS       = -SCREEN_WIDTH/2 + 10
  SCORE_Y_POS       = SCREEN_HEIGHT/2 - 1*14
  HISCORE_X_POS     = -SCREEN_WIDTH/2 + 94
  HISCORE_Y_POS     = SCREEN_HEIGHT/2 - 1*14
  SHIPS_X_POS       = SCREEN_WIDTH/2 - 10/2*12
  SHIPS_Y_POS       = SCREEN_HEIGHT/2 - 1*14

  ' star field
  NUM_STARS         = 250

  ' player starting constants
  PLAYER_START_X    = 0
  PLAYER_START_Y    = -20
  PLAYER_VEL        = 15

  ' control keys
  KB_LEFT_ARROW     = $C0
  KB_RIGHT_ARROW    = $C1
  KB_UP_ARROW       = $C2
  KB_DOWN_ARROW     = $C3
  KB_ESC            = $CB
  KB_SPACE          = $20
  KB_ENTER          = $0D

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

  byte counter              ' used for the landscape array.
  byte star_count           ' used for the starfield array.
  byte box_x, box_y         ' used to draw a box around the playing field.
  long land_x, land_y       ' used for the landscape.
  long player_x, player_y   ' used to move the player.
  byte stars[NUM_STARS]     ' used to create a star field.
  
'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ
  tv    : "tv_drv_010.spin"          ' instantiate a tv object
  gr    : "LP_graphics_drv_010.spin" ' instantiate a graphics object
  key   : "keyboard_iso_010.spin"    ' instantiate a keyboard object

'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB start | i, dx, dy, x, y

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

  'start and setup graphics 256x192, with orgin (0,0) at center of screen
  gr.start
  gr.setup(X_TILES, Y_TILES, SCREEN_WIDTH/2, SCREEN_HEIGHT/2, offscreen_buffer)

  ' start the keyboard on pingroup
  key.start(3)

  ' BEGIN GAME LOOP ////////////////////////////////////////////////////
  ' ////////////////////////////////////////////////////////////////////
  ' INITIALIZATION
  ' ////////////////////////////////////////////////////////////////////

  ' initialize variables for the box around playing field.
  box_x   := SCREEN_WIDTH/2
  box_y   := SCREEN_HEIGHT/2

  ' set player's initial position and initialize velocity variables.
  player_x  := PLAYER_START_X
  player_y  := PLAYER_START_Y

  ' initialize the landscape variables
  counter := 0
  land_x := SCREEN_WIDTH/2*3
  land_y := -90

  ' initialize the landscape
  Draw_Landscape (-land_x, land_y, counter)

  ' initialize the starfield
  Draw_Stars (x, y)

  ' ////////////////////////////////////////////////////////////////////
  ' MAIN GAME LOOP
  ' ////////////////////////////////////////////////////////////////////

  repeat while TRUE

    ' clear the screen
    gr.clear      

    '///////////////////////////////////////////////////////////////////
    ' INPUT BEGIN
    '///////////////////////////////////////////////////////////////////

    ' move player on x-axis
    if (key.keystate(KB_LEFT_ARROW))
      player_x -= 3
    elseif (key.keystate(KB_RIGHT_ARROW))
      player_x += 3

    ' move player on the y-axis.
    if (key.keystate(KB_UP_ARROW))
      player_y += 3
    elseif (key.keystate(KB_DOWN_ARROW))
      player_y -= 3

    '///////////////////////////////////////////////////////////////////
    ' ANIMATION BEGIN
    '///////////////////////////////////////////////////////////////////

    ' if left/right arrow keys are not being pressed, then apply gravity
    ' and pull the player back to the center of the screen.
    if (player_x > 0)
      player_x -= 1
    elseif (player_x < 0)
      player_x += 1

    ' check player boundary for it's invisible box---if player hits
    ' the boundary, then scroll the landscape.
    if (player_x < -40)
      player_x := -40
      land_x -= 3
    elseif (player_x > 40)
      player_x := 40
      land_x += 3

    ' check the y-axis boundaries
    if (player_y > 55)
      player_y := 55
    elseif (player_y < -95)
      player_y := -95
      
    ' check to see if we have reached the world's boundaries.
    if (land_x > 260*2-133)
      land_x := SCREEN_WIDTH/2
    elseif (land_x < SCREEN_WIDTH/2)
      land_x := 260*2-133

    '///////////////////////////////////////////////////////////////////
    ' RENDERING SECTION BEGIN (render to offscreen buffer always////////
    '///////////////////////////////////////////////////////////////////

    ' draw top-text
    gr.textmode(2, 1, 5, 3)
    gr.colorwidth(2, 0)
    gr.text(SCORE_X_POS, SCORE_Y_POS, @score_string)
    gr.text(HISCORE_X_POS, HISCORE_Y_POS, @hiscore_string)
    gr.text(SHIPS_X_POS, SHIPS_Y_POS, @ships_string)

    ' draw box around playing field.
    gr.colorwidth(1,0)
    gr.plot(-box_x, -box_y)
    gr.line(box_x-1, -box_y)
    gr.line(box_x-1, box_y-32)
    gr.line(-box_x, box_y-32)
    gr.line(-box_x, -box_y)

    ' re-draw the landscape with the updated coords.
    Draw_Landscape (land_x, land_y, counter)

    ' move stars: they don't actually move yet.
    Move_Stars

    ' draw player on the screen (currently using Nick's pix)
    gr.pix(player_x, player_y, 0, @player_pix)

    'copy bitmap to display offscreen -> onscreen
    gr.copy(onscreen_buffer)

    ' synchronize to frame rate would go here...

    ' END RENDERING SECTION ///////////////////////////////////////////////
  ' END MAIN GAME LOOP REPEAT BLOCK //////////////////////////////////

PUB Draw_Landscape (local_x, local_y, local_counter)
  ' plot the pixel for the starting point of drawing the terrain
  ' (based on Andre's Lunar)
  gr.plot(-local_x, local_y)

  repeat local_counter from 0 to 26*2-1           ' loop through the established array
    gr.line(-local_x + local_counter*10, local_y) ' draw line based on array coords.
    local_y += terrain[local_counter]             ' update y with the coords from the terrain array.

PUB Draw_Stars (star_x, star_y)
  ' draw stars
  star_count := -128

  repeat while star_count < NUM_STARS
    stars[star_count] := ?star_x + 260*3
    stars[star_count+1] := ?star_y//-SCREEN_HEIGHT/2
    stars[star_count+2] := 2
    star_count += 3
  
PUB Move_Stars
  ' move stars
  star_count := -128

  repeat while star_count < NUM_STARS
    gr.color(stars[star_count+2])
    ' The next 2 lines are not correct.  It should only take one line to to populate the entire universe with stars.
    ' Work on fixing this section of the code.
    gr.plot(stars[star_count], stars[star_count+1]-25) ' draw stars on the right-hand side.
    gr.plot(-stars[star_count], stars[star_count+1]-25) ' draw stars on the left-hand side.
    'stars[star_count] := stars[star_count] + stars[star_count+2] ' movement not used yet, due to issues with star code.

    ' check to see if we have reached the world's boundaries.
    if (stars[star_count] > 128)
      stars[star_count] := SCREEN_WIDTH/2+stars[star_count]
    elseif (stars[star_count] < 0)
      stars[star_count] := SCREEN_WIDTH/2-stars[star_count]

    ' increment the counter.
    star_count += 3       

PUB Draw_Enemies
  ' not fully implemented yet, but will be used to insert enemy craft throughout the game universe.

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
                        long    55_250_000      'broadcast on channel 2 VHF, each channel is 6 MHz above the previous
                        long    0               'auralcog

' TERRAIN //////////////////////////////////////////////////////////////
terrain                 long 0, 10, -10, 5, -3, 15, -18, 3, -3, 3, -3, 6, -2, 4, -2, 0, 12, -18, 8, -8, 12, -8, 10, -13, 0, 0 ' screen 0, 26 vertices (begin)
                        'long 10, -10, 5, -3, 15, -20, 3, -3, 3, -3, 6, -2, 4, -2, 0, 12, -18, 8, -8, 12, -8, 10, -10, 0, 0, 0 ' screen 1, 26 vertices
                        'long 10, -10, 5, -3, 15, -20, 12, -12, 3, -3, 6, -2, 4, -2, 0, 12, -18, 8, -8, 12, -8, 10, -10, 0, 0, 0 ' screen 2, 26 vertices
                        long 0, 10, -10, 5, -3, 15, -18, 3, -3, 3, -3, 6, -2, 4, -2, 0, 12, -18, 8, -8, 12, -8, 10, -13, 0, 0 ' screen 3, 26 vertices (end)

' PLAYER ///////////////////////////////////////////////////////////////
player_pix
                        byte 2, 8, 0, 0
                        word %%00000011,%%11000000
                        word %%00000101,%%10100000
                        word %%00000111,%%11100000
                        word %%00000001,%%10000000
                        word %%00010110,%%01011000
                        word %%00001100,%%00110000
                        word %%00000010,%%01000000
                        word %%00000011,%%11000000

' STRING STORAGE ///////////////////////////////////////////////////////
score_string            byte "Score",0
hiscore_string          byte "Hi-Score", 0
ships_string            byte "Ships",0