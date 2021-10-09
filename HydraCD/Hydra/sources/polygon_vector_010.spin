' //////////////////////////////////////////////////////////////////////
' Polygon Drawing Demo - Draws a single polygon based on the vector sprite
' and moves it around on the screen
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 1.4.06
' VERSION 1.0
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x            ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000        ' set frequency to 10 MHZ plus some error
  _stack = ($3000 + $3000 + 64) >> 2  'accomodate display memory and stack

  ' graphics driver and screen constants
  PARAMCOUNT        = 14        
  OFFSCREEN_BUFFER  = $2000           ' offscreen buffer
  ONSCREEN_BUFFER   = $5000           ' onscreen buffer

  ' size of graphics tile map
  X_TILES           = 16
  Y_TILES           = 12
  
  SCREEN_WIDTH      = 256
  SCREEN_HEIGHT     = 192 

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

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ
  tv    : "tv_drv_010.spin"          ' instantiate a tv object
  gr    : "graphics_drv_010.spin"    ' instantiate a graphics object

'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB start | i, dx, dy, x, y, color, rotation

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

  'start and setup graphics 256x192, with orgin (0,0) at bottom left of screen
  gr.start
  gr.setup(X_TILES, Y_TILES, SCREEN_WIDTH/2, SCREEN_HEIGHT/2, offscreen_buffer)

  ' BEGIN GAME LOOP ////////////////////////////////////////////////////

  ' initialize postion of asteroid
  x := 0
  y := 0

  ' set pen attributes
  gr.colorwidth(1, 0)

  ' infinite loop
  repeat while TRUE
   
    'clear the offscreen buffer
     gr.clear

    ' RENDERING SECTION (render to offscreen buffer always//////////////

    ' draw asteroid polygon at $100 = 1x scale with slowly incrementing  rotation angle
    gr.vec(x, y, $100, rotation, @asteroid_large)

    ' animate asteroid
    rotation := (rotation+=4 // ANG_360)

    ' translate asteroid
    if (++x > SCREEN_WIDTH/2)
       x -= SCREEN_WIDTH
    
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
asteroid_large          

                        word    $4000+$2000*45/360      ' vertex 0
                        word    8*2

                        word    $8000+$2000*63/360      ' vertex 1
                        word    4*2

                        word    $8000+$2000*108/360     ' vertex 2
                        word    6*2

                        word    $8000+$2000*147/360     ' vertex 3
                        word    7*2

                        word    $8000+$2000*206/360     ' vertex 4
                        word    4*2

                        word    $8000+$2000*213/360     ' vertex 5
                        word    7*2

                        word    $8000+$2000*243/360     ' vertex 6
                        word    9*2

                        word    $8000+$2000*296/360     ' vertex 7
                        word    4*2

                        word    $8000+$2000*303/360     ' vertex 8
                        word    7*2

                        word    $8000+$2000*348/360     ' vertex 9
                        word    10*2

                        word    $8000+$2000*45/360      ' vertex 0
                        word    8*2

                        word    0                       ' terminates vector sprite
                     