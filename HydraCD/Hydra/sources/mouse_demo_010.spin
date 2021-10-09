' //////////////////////////////////////////////////////////////////////
' Mouse Demo  - Demos the mouse and moves a little tie fighter cursor
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 1.5.06
' VERSION 1.0
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

  long  mousex, mousey            ' holds mouse x,y absolute position
         
'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ
  tv    : "tv_drv_010.spin"          ' instantiate a tv object
  gr    : "graphics_drv_010.spin"    ' instantiate a graphics object
  mouse : "mouse_iso_010.spin"       ' instantiate a mouse object
  
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

  'start mouse on pingroup 2 (Hydra mouse port)
  mouse.start(2)
  ' initialize mouse postion
  mousex := 0
  mousey := 0

  ' BEGIN GAME LOOP ////////////////////////////////////////////////////

  ' infinite loop
  repeat while TRUE
   
    'clear the offscreen buffer
     gr.clear

    ' INPUT SECTION ////////////////////////////////////////////////////
    ' update mouse position with current delta (remember mouse works in deltas)
    ' for fun notice the creepy syntax at the end? these are the "bounds" operators!
    mousex := mousex + mouse.delta_x #> -128 <# 127
    mousey := mousey + mouse.delta_y #> -96 <# 95
 
    ' RENDERING SECTION (render to offscreen buffer always//////////////
         
    'draw mouse cursor
    gr.colorwidth(1,0)

    ' test for mouse buttons to change bitmap rendered
    if mouse.button(0) ' left button
       ' draw tie fighter with left wing retracted at x,y with rotation angle 0
       gr.pix(mousex, mousey, 0, @tie_left_bitmap)
    elseif mouse.button(1) ' right button
       ' draw tie fighter with right wing retracted at x,y with rotation angle 0
       gr.pix(mousex, mousey, 0, @tie_right_bitmap)
    else
       ' draw tie fighter with normal wing configuration at x,y with rotation angle 0
       gr.pix(mousex, mousey, 0, @tie_normal_bitmap)

    'copy bitmap to display offscreen -> onscreen
    gr.copy(onscreen_buffer)

    ' synchronize to frame rate would go here...

    ' END RENDERING SECTION ////////////////////////////////////////////

  ' END MAIN GAME LOOP REPEAT BLOCK ////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' DATA SECTION /////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

DAT

' TV PARAMETERS FOR DRIVER /////////////////////////////////////////////

tvparams  long    0               'status
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

'' Pixel sprite definition:
''
''    word                          ' This is need to WORD align the data structure
''    byte    xwords, ywords        ' x,y dimensions expressed as WORDsexpress dimensions and center, define pixels
''    byte    xorigin, yorigin      ' Center of pixel sprite  
''    word    %%xxxxxxxx,%%xxxxxxxx ' Now comes the data in row major WORD form...
''    word    %%xxxxxxxx,%%xxxxxxxx
''    word    %%xxxxxxxx,%%xxxxxxxx

' bitmaps for mouse cursor

tie_normal_bitmap     word                           ' tie fighter in normal wing configuration
                      byte    2,8,3,3                ' 2 words wide (8 pixels) x 8 words high (8 lines), 8x8 sprite
                      word    %%01000000,%%00000010      
                      word    %%10000000,%%00000001
                      word    %%10000111,%%11100001
                      word    %%11111111,%%11111111
                      word    %%11111111,%%11111111
                      word    %%10000111,%%11100001
                      word    %%10000000,%%00000001
                      word    %%01000000,%%00000010

tie_left_bitmap       word                           ' tie fighter with left wing retracted configuration
                      byte    2,8,3,3                ' 2 words wide (8 pixels) x 8 words high (8 lines), 8x8 sprite
                      word    %%00000000,%%00000010      
                      word    %%01100000,%%00000001
                      word    %%10000111,%%11100001
                      word    %%11111111,%%11111111
                      word    %%11111111,%%11111111
                      word    %%10000111,%%11100001
                      word    %%01100000,%%00000001
                      word    %%00000000,%%00000010


tie_right_bitmap      word                           ' tie fighter with right wing retracted configuration
                      byte    2,8,3,3                ' 2 words wide (8 pixels) x 8 words high (8 lines), 8x8 sprite
                      word    %%01000000,%%00000000      
                      word    %%10000000,%%00000110
                      word    %%10000111,%%11100001
                      word    %%11111111,%%11111111
                      word    %%11111111,%%11111111
                      word    %%10000111,%%11100001
                      word    %%10000000,%%00000110
                      word    %%01000000,%%00000000









                  