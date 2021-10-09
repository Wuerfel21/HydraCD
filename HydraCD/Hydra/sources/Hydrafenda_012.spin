' //////////////////////////////////////////////////////////////////////
' Hydrafenda 1.2
' AUTHOR: Lorenzo Phillips
' LAST MODIFIED: 1.27.06
' VERSION 1.2
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll4x            ' enable external clock and pll times 4
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

  ' player starting position
  PLAYER_START_X = 0
  PLAYER_START_Y = -20

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

  byte counter
  byte box_x, box_y     ' used to draw a box around the playing field.
  long land_x, land_y     ' used for the landscape.
  long player_x, player_y ' used to move the player.
  
'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ
  tv    : "tv_drv_010.spin"          ' instantiate a tv object
  gr    : "graphics_drv_010.spin"    ' instantiate a graphics object
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
  ' initialize for box/window around playing field--this will be changed back
  ' to the original playing field box later, but for now I'm using it to test
  ' setting up my scrolling window properly.
  
  ' initialize some variables.
  x       := SCREEN_WIDTH/2
  y       := SCREEN_HEIGHT/2
  box_x   := x - 1
  box_y   := y

  ' set player's initial position.
  player_x := PLAYER_START_X
  player_y := PLAYER_START_Y

  ' initialize the variables
  counter := 0
  land_x := 127
  land_y := -90


{

  ' plot the pixel for the starting point of drawing the terrain
  ' (based on Andre's Lunar)
  gr.plot(-land_x, -90)


  ' draw the terrain
  land_y := -90 ' set initial y value
  repeat counter from 0 to 50 ' loop through the established array
    gr.line(-land_x + counter*10, land_y) ' draw line based on array coords.
    land_y += terrain[counter] ' update y with the coords from the terrain array.
}

  ' ////////////////////////////////////////////////////////////////////
  ' MAIN LOOP
  ' ////////////////////////////////////////////////////////////////////
  repeat while TRUE

    ' clear the screen
    gr.clear

    '///////////////////////////////////////////////////////////////////
    ' INPUT BEGIN
    '///////////////////////////////////////////////////////////////////
    if (key.keystate(KB_LEFT_ARROW))
      land_x -= 1
    elseif (key.keystate(KB_RIGHT_ARROW))
      land_x += 1
    elseif (key.keystate(KB_UP_ARROW))
      ++player_y
    elseif (key.keystate(KB_DOWN_ARROW))
      --player_y
      
    ' wrap terrain
    if (land_x > 260*3-129)
        land_x := 127
              
    '///////////////////////////////////////////////////////////////////
    ' ANIMATION BEGIN
    '///////////////////////////////////////////////////////////////////
    ' boundary check for x-axis for the player
    'if (land_x > SCREEN_WIDTH/2)
      'land_x := -SCREEN_WIDTH/2 - 6
    'elseif (land_x < -SCREEN_WIDTH/2 - 6)
      'land_x := SCREEN_WIDTH/2

    ' boundary check for y-axis for the player
    if (player_y > SCREEN_HEIGHT/2 - 1)
      player_y := -SCREEN_HEIGHT/2
    elseif (player_y < -SCREEN_HEIGHT/2 - 1)
      player_y := SCREEN_HEIGHT/2

    '///////////////////////////////////////////////////////////////////
    ' RENDERING SECTION BEGIN (render to offscreen buffer always////////
    '///////////////////////////////////////////////////////////////////

    ' draw box around playing field.
    gr.colorwidth(1,0)
    gr.plot(-box_x, -box_y)
    gr.line(box_x, -box_y)
    gr.line(box_x, box_y-32)
    gr.line(-box_x, box_y-32)
    gr.line(-box_x, -box_y)

    ' draw player on the screen (currently using Nick's pix)
    gr.pix(player_x, player_y, 0, @player_pix)

    ' plot the pixel for the starting point of drawing the terrain
    ' (based on Andre's Lunar)
    gr.plot(-land_x, -90)

    ' draw the terrain
    land_y := -90 ' set initial y value

    repeat counter from 0 to 26*3-1         ' loop through the established array
      gr.line(-land_x + counter*10, land_y) ' draw line based on array coords.
      land_y += terrain[counter]            ' update y with the coords from the terrain array.

    'copy bitmap to display offscreen -> onscreen
    gr.copy(onscreen_buffer)

    ' synchronize to frame rate would go here...

    ' END RENDERING SECTION ///////////////////////////////////////////////
  ' END MAIN GAME LOOP REPEAT BLOCK //////////////////////////////////

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
terrain                 long 0, 10, -10, 5, -3, 15, -20, 3, -3, 3, -3, 6, -2, 4, -2, 0, 12, -18, 8, -8, 12, -8, 10, -10, 0,0 ' screen 0, 26 vertices
                        long 10, -10, 5, -3, 15, -20, 3, -3, 3, -3, 6, -2, 4, -2, 0, 12, -18, 8, -8, 12, -8, 10, -10, 0, 0,0 ' screen 1 , 26 vertices
                        long 0, 10, -10, 5, -3, 15, -20, 3, -3, 3, -3, 6, -2, 4, -2, 0, 12, -18, 8, -8, 12, -8, 10, -10, 0,0 ' screen 0 , 26 vertices

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