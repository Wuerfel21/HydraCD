' //////////////////////////////////////////////////////////////////////
' Bouncing balls (squares :) in region demo
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 5.15.06
' VERSION 2.0
' 256x192, 4 colors, bitmapped, quadrant I, mapped to screen, (0,0) at
' lower bottom left
' Use game pad arrow keys to resize boundary
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

  ' ball and containment box constants
  NUM_BALLS         = 40  ' number of active balls to render
  SIZEOFBALL_RECORD = 4   ' size of each ball record [x,y, dx, dy]  
  BOX_SIZE_2        = 4   ' size of box/2            
  RESIZE_INC        = 4   ' rate to resize


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
  
  long  balls[NUM_BALLS * SIZEOFBALL_RECORD] ' balls records [x,y] format
  
  long  screen_min_x, screen_max_x, screen_min_y, screen_max_y

  long  counter

'//////////////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION //////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////
OBJ
  tv    : "tv_drv_010.spin"          ' instantiate a tv object
  gr    : "graphics_drv_010.spin"    ' instantiate a graphics object
  gpad  : "gamepad_drv_001.spin"     ' gamepad driver
  
'//////////////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS ////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

PUB start | i, dx, dy, x, y, x_index, y_index, dx_index, dy_index, rand, nes_buttons, resize

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

  ' start game pads
  gpad.start
  
  ' initialize simulation
  screen_min_x := 0
  screen_max_x := SCREEN_WIDTH-1
  screen_min_y := 0
  screen_max_y := SCREEN_HEIGHT-1 

  ' seed random number
  rand := 3983432841
  
  repeat i from 0 to (NUM_BALLS - 1)
    ' cache x,y indices for fast computation
    x_index  := i*SIZEOFBALL_RECORD
    y_index  := x_index + 1
    dx_index := x_index + 2
    dy_index := x_index + 3            
         
    balls[x_index] := (?rand & $FFF) // (screen_max_x-1) 
    balls[y_index] := (?rand & $FFF) // (screen_max_y-1)       
    balls[dx_index]:= -5 + (?rand & $F) // 10 
    balls[dy_index]:= -5 + (?rand & $F) // 10
        

  ' BEGIN GAME LOOP ///////////////////////////////////////////////////////////

  ' infinite loop
  repeat while TRUE

    'clear the offscreen buffer
     gr.clear

    ' get nes controller button
    nes_buttons := gpad.read       
    resize := 0
    
    ' resize boundary
    if (nes_buttons & NES_RIGHT)
      resize := 1
      screen_max_x+=RESIZE_INC
      screen_min_x-=RESIZE_INC
      if (screen_max_x => SCREEN_WIDTH-1)
        screen_max_x-=RESIZE_INC
        screen_min_x+=RESIZE_INC
          
    if (nes_buttons & NES_LEFT)
      resize := 1
      screen_max_x-=RESIZE_INC
      screen_min_x+=RESIZE_INC
      if (screen_max_x =< SCREEN_WIDTH/2)
        screen_max_x+=RESIZE_INC
        screen_min_x-=RESIZE_INC

    if (nes_buttons & NES_UP)
      resize := 1
      screen_max_y+=RESIZE_INC
      screen_min_y-=RESIZE_INC
      if (screen_max_y => SCREEN_HEIGHT-1)
        screen_max_y-=RESIZE_INC
        screen_min_y+=RESIZE_INC
          
    if (nes_buttons & NES_DOWN)
      resize := 1
      screen_max_y-=RESIZE_INC
      screen_min_y+=RESIZE_INC
      if (screen_max_y =< SCREEN_HEIGHT/2)
        screen_max_y+=RESIZE_INC
        screen_min_y-=RESIZE_INC

    ' move all the balls
    repeat i from 0 to (NUM_BALLS - 1)
      ' cache x,y indices for fast computation
      x_index  := i*SIZEOFBALL_RECORD
      y_index  := x_index + 1
      dx_index := x_index + 2
      dy_index := x_index + 3            
  
      ' translate ball
      balls[x_index] += balls[dx_index]
      balls[y_index] += balls[dy_index]       
    
      ' test for collision with walls (note: could use threshold operators, but too cryptic for debugging)
      if ( (balls[x_index] => screen_max_x-1) or (balls[x_index] =< screen_min_x) )
        balls[dx_index] := -balls[dx_index]         
        balls[x_index] += balls[dx_index]        
  
      if (( balls[y_index] => screen_max_y-1) or (balls[y_index] =< screen_min_y) )
        balls[dy_index] := -balls[dy_index]         
        balls[y_index] += balls[dy_index]

      ' test for containment breach caused by resize
      if (resize == 1)
        ' test x components
        if (balls[x_index] => screen_max_x-1)
            balls[x_index] := screen_max_x-1
        else
        if (balls[x_index] =< screen_min_x )           
            balls[x_index] := screen_min_x-1

        ' test y components
        if (balls[y_index] => screen_max_y-1)
            balls[y_index] := screen_max_y-1
        else
        if (balls[y_index] =< screen_min_y )           
            balls[y_index] := screen_min_y-1

    ' RENDERING SECTION (render to offscreen buffer always/////////////////////

    ' set pen attributes, first parm color, second parm size
      
    ' render graphics to offscreen buffer for "presentation" by the copy() function
    ' first render the boundary of containment field
    gr.colorwidth(2,0)

    gr.plot(screen_min_x, screen_min_y)
    gr.line(screen_max_x, screen_min_y)
    gr.line(screen_max_x, screen_max_y)
    gr.line(screen_min_x, screen_max_y)
    gr.line(screen_min_x, screen_min_y)

    ' now render the balls
    gr.colorwidth(1,0)
    
    repeat i from 0 to (NUM_BALLS - 1)
      ' cache x,y for fast computation
      x := balls[i*SIZEOFBALL_RECORD]
      y := balls[i*SIZEOFBALL_RECORD + 1]

      ' draw a box manually for speed
      gr.plot(x - BOX_SIZE_2,y)
      gr.line(x + BOX_SIZE_2,y)       
      gr.line(x + BOX_SIZE_2,y + BOX_SIZE_2)      
      gr.line(x - BOX_SIZE_2,y + BOX_SIZE_2)
      gr.line(x - BOX_SIZE_2,y)

    'copy bitmap to display offscreen -> onscreen
    gr.copy(onscreen_buffer)

    ' synchronize to roughly 60 FPS (if it can hold it)
     waitcnt(cnt + 666_666)

    ' END RENDERING SECTION ///////////////////////////////////////////////////

  ' END MAIN GAME LOOP REPEAT BLOCK ///////////////////////////////////////////

'//////////////////////////////////////////////////////////////////////////////
' DATA SECTION ////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

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