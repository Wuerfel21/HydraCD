' //////////////////////////////////////////////////////////////////////
' Simple polygon rendering demo with translation and double buffering
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 5.15.06
' VERSION 1.1
' 256x192, 4 colors, bitmapped, quadrant I, mapped to screen, (0,0) at
' lower bottom left
' Use gamepad to move around, must be plugged in.
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
  OFFSCREEN_BUFFER  = $2000           ' offscreen buffer, unused in this template
  ONSCREEN_BUFFER   = $5000           ' onscreen buffer

  ' size of graphics tile map
  X_TILES           = 16
  Y_TILES           = 12
  
  SCREEN_WIDTH      = 256
  SCREEN_HEIGHT     = 192 

  ' polygon scaling factor
  PSCALE            = 10

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

  ' nes gamepad vars
  long nes_buttons

  ' position of ship
  long ship_x, ship_y

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

PUB start | i, dx, dy, x, y

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  'init colors, each tile has same 4 colors, (note color_1 and color_2 are flipped due to bit flipping in graphics driver) 
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

  ' start NES game pad task to read gamepad values
  gpad.start

  ' start ship at center of screen
  ship_x := SCREEN_WIDTH/2
  ship_y := SCREEN_HEIGHT/2

  ' BEGIN GAME LOOP ///////////////////////////////////////////////////////////

  ' infinite loop
  repeat while TRUE

    'clear the offscreen buffer
    gr.clear

    ' INPUT SECTION ///////////////////////////////////////////////////////////

    ' get nes controller button
    nes_buttons := gpad.read       

    ' move ship
    if (nes_buttons & NES_RIGHT)
      ship_x += 5
    else
    if (nes_buttons & NES_LEFT)
      ship_x -= 5
            
    if (nes_buttons & NES_UP)
      ship_y += 5
    else
    if (nes_buttons & NES_DOWN)
      ship_y -= 5

   
    ' RENDERING SECTION (render to offscreen buffer always/////////////////////
    
    ' render graphics directly to screen, replace this with your code
    Draw_Polygon2(@fighter_poly, 12, 1, ship_x, ship_y )

    'copy bitmap to display offscreen -> onscreen
    gr.copy(onscreen_buffer)

    ' END RENDERING SECTION ///////////////////////////////////////////////////

  ' END MAIN GAME LOOP REPEAT BLOCK ///////////////////////////////////////////

' FUNCTIONS ///////////////////////////////////////////////////////////////////

PUB Draw_Polygon2(vertex_list_ptr, num_vertices, color, x0, y0) | v_index
' draws the sent polygon, totally unoptimized, no error detection
' vertex_list_ptr = pointer to WORD array of x,y vertex pairs
' num_vertices    = number of vertices in polygon
' color           = color to render in 0..3
' x0, y0          = x,y translation factors

  ' step 1: set color
  gr.colorwidth(color, 0)

  ' notice the pointer casting to byte and the sign extension ~ operator
  ' step 2: plot starting point
  gr.plot(~byte[vertex_list_ptr][0]+x0, ~byte[vertex_list_ptr][1]+y0) 

  ' step 3: draw remaining polygon edges
  repeat v_index from 1 to num_vertices-1
    gr.line(~byte[vertex_list_ptr][2*v_index + 0]+x0, ~byte[vertex_list_ptr][2*v_index + 1]+y0)

  ' step 4: close polygon by drawing back to starting vertex
  gr.line(~byte[vertex_list_ptr][0]+x0, ~byte[vertex_list_ptr][1]+y0) 


'//////////////////////////////////////////////////////////////////////////////
' DATA SECTION ////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

DAT

' TV PARAMETERS FOR DRIVER ////////////////////////////////////////////////////

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

' Polygon definition for space ship, array of (x,y) pairs, each representing a vertex
' 2 bytes per vertex, allows vertices to be -128 to +127
' notice they are scaled by PSCALE
fighter_poly            byte    0*PSCALE,4*PSCALE             ' vertex 0
                        byte    1*PSCALE,0*PSCALE             ' vertex 1
                        byte    3*PSCALE,-1*PSCALE            ' vertex 2
                        byte    4*PSCALE,0*PSCALE             ' vertex 3
                        byte    4*PSCALE,-1*PSCALE            ' vertex 4
                        byte    3*PSCALE,-2*PSCALE            ' vertex 5
                        byte    0*PSCALE,-3*PSCALE            ' vertex 6
                        byte    -3*PSCALE,-2*PSCALE           ' vertex 7
                        byte    -4*PSCALE,-1*PSCALE           ' vertex 8
                        byte    -4*PSCALE,0*PSCALE            ' vertex 9
                        byte    -3*PSCALE,-1*PSCALE           ' vertex 10
                        byte    -1*PSCALE,0*PSCALE            ' vertex 11


                                                