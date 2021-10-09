' //////////////////////////////////////////////////////////////////////
' Basic graphics template
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 5.15.06
' VERSION 1.0
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
  ' simulating quadrant I of a cartesian coordinate system
  gr.start
  gr.setup(X_TILES, Y_TILES, 0, 0, offscreen_buffer)

  ' BEGIN GAME LOOP ///////////////////////////////////////////////////////////

  ' infinite loop
  repeat while TRUE
   
    'clear the offscreen buffer
     gr.clear

    ' RENDERING SECTION (render to offscreen buffer always/////////////////////

    ' set pen attributes, color 1, size 0
    gr.colorwidth(3,0)
      
    ' plot the pixel
    repeat x from 0 to 10
      gr.plot(x, 0)

    'copy bitmap to display offscreen -> onscreen
    gr.copy(onscreen_buffer)

    ' synchronize to frame rate would go here...

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