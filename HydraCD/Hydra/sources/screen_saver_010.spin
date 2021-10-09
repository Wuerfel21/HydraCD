' //////////////////////////////////////////////////////////////////////
' Screen save demo to show use of lines, code intentionally unoptimized
' to make easy to understand, try optimizing all the logic to use loops
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 5.15.06
' VERSION 1.0
' 256x192, 4 colors, bitmapped, quadrant I, mapped to screen, (0,0) at
' lower bottom left
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
  OFFSCREEN_BUFFER  = $2000           ' offscreen buffer, unused in this template
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

  COL_Blue       = %0000_1_101 
  COL_Blue2      = %0001_1_101
  COL_Purple     = %0010_1_101
  COL_Magenta    = %0011_1_101
  COL_Magenta2   = %0100_1_101
  COL_Red        = %0101_1_101
  COL_Orange     = %0110_1_101
  COL_Brown      = %0111_1_101
  COL_Yellow     = %1000_1_101
  COL_YelGrn     = %1001_1_101
  COL_Green      = %1010_1_101
  COL_Green2     = %1011_1_101
  COL_Green3     = %1100_1_101
  COL_Cyan       = %1101_1_101
  COL_Cyan2      = %1110_1_101
  COL_Cyan3      = %1111_1_101

  ' each palette entry is a LONG arranged like so: color 3 | color 2 | color 1 | color 0
  ' note color 1 and color 2 are reversed due to the reverse of bits in the graphics driver
  ' graphics routines "10"<->"01", 00 and 11 reversed are the same
  COLOR_0 = (COL_Black  << 0)
  COLOR_1 = (COL_Red    << 16)
  COLOR_2 = (COL_Green  << 8)
  COLOR_3 = (COL_Blue   << 24)  


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

  word px[4], py[4]   ' holds line endpoints for draw and erase lines
  word vx[4], vy[4]   ' holds line endpoints velocities 
  long  eraser_count  ' counts when the eraser should turn on

'//////////////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION //////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////
OBJ
  tv    : "tv_drv_010.spin"          ' instantiate a tv object
  gr    : "graphics_drv_010.spin"    ' instantiate a graphics object

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
  'simulating quadrant I of a cartesian coordinate system
  ' notice that the setup call uses the PRIMARY onscreen video buffer, so all graphics
  ' will show immediately on the screen, this is convenient for simple demos where we don't need animation
  gr.start
  gr.setup(X_TILES, Y_TILES, 0, 0, onscreen_buffer)

  ' clear eraser counter
  eraser_count := 0

  ' BEGIN GAME LOOP ///////////////////////////////////////////////////////////

  ' infinite loop
  repeat while TRUE
   
    ' RENDERING SECTION (render to offscreen buffer always/////////////////////

    ' based on function of line state select a color
    gr.colorwidth(1+(eraser_count / 20) // 3,0)

    ' draw the current line
    gr.plot(plines[0], plines[1])
    gr.line(plines[2], plines[3])

    ' move the endpoints
    plines[0] += vlines[0]
    plines[1] += vlines[1]      

    plines[2] += vlines[2]
    plines[3] += vlines[3]      
  
    ' test for out of bounds
    if (plines[0] > 255)
      vlines[0] := -vlines[0]
      plines[0] += vlines[0]

    if (plines[2] > 255)
      vlines[2] := -vlines[2]
      plines[2] += vlines[2]
  
    if (plines[1] > 191)
      vlines[1] := -vlines[1]
      plines[1] += vlines[1]

    if (plines[3] > 191)
      vlines[3] := -vlines[3]
      plines[3] += vlines[3]

    ' should we start erasing?
    if (++eraser_count > 100)
      ' begin erase code
      gr.colorwidth(0,0)
      gr.plot(plines[4], plines[5])
      gr.line(plines[6], plines[7])

      ' move the endpoints
      plines[4] += vlines[4]
      plines[5] += vlines[5]      

      plines[6] += vlines[6]
      plines[7] += vlines[7]      

      ' test for out of bounds
      if (plines[4] > 255)
        vlines[4] := -vlines[4]
        plines[4] += vlines[4]

      if (plines[6] > 255)
        vlines[6] := -vlines[6]
        plines[6] += vlines[6]
  
      if (plines[5] > 191)
        vlines[5] := -vlines[5]
        plines[5] += vlines[5]

      if (plines[7] > 191)
        vlines[7] := -vlines[7]
        plines[7] += vlines[7]
      ' end erase code

      ' add a time delay with a little flair
      repeat i from 0 to 100 + 3*(eraser_count // 10)

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

' data structure is array of points, each point is in x,y form, each line needs two points
plines                  word 10,3 ' line 1, endpoint 1
                        word 50,60' line 1, endpoint 2
                        
                        word 10,3 ' line 2, endpoint 1
                        word 50,60' line 2, endpoint 2

'data structure is an array of velocity vectors in vx, vy form, each pair of numbers used to translate a point
vlines                  word    1,2   ' line 1, endpoint 1 velocity
                        word    -3,5  ' line 1, endpoint 2 velocity

                        word    1,2   ' line 2, endpoint 1 velocity
                        word    -3,5  ' line 2, endpoint 2 velocity
                                                                                                  