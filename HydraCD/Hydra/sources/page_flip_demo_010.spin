' //////////////////////////////////////////////////////////////////////
' Page flipping demo
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 5.15.06
' VERSION 1.0
' 256x192, 4 colors, bitmapped, quadrant I, mapped to screen, (0,0) at
' lower bottom left
' Use game pad to control it, wait for imagery to draw...
' then press right or left to switch from page to page
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
  PAGE0_BUFFER      = $2000           ' page 0 video buffer
  PAGE1_BUFFER      = $5000           ' page 1 video buffer

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
  ' note color 1 and color 2 are reversed due to the reverse of bits in the graphics driver
  ' graphics routines "10"<->"01", 00 and 11 reversed are the same
  COLOR_0 = (COL_Black    << 0)
  COLOR_1 = (%1110_1_010  << 8)
  COLOR_2 = (%1110_1_011  << 16)
  COLOR_3 = (%1110_1_100  << 24)  

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

PUB start | i, dx, dy, dz, x, y, z, x0, y0, z0, xs, ys, zs, scale, color, rand

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  'init colors, each tile has same 4 colors 
  repeat i from 0 to 64
    colors[i] := COLOR_3 | COLOR_2 | COLOR_1 | COLOR_0

  ' seed random number
  rand := 256460984

  ' start NES game pad task to read gamepad values
  gpad.start

  ' call the new set page function
  Set_Video_Page(PAGE0_BUFFER)

  'start and setup graphics 256x192, with orgin (0,0) at bottom left of screen,
  'simulating quadrant I of a cartesian coordinate system
  ' notice that the setup call uses the PRIMARY onscreen video buffer, so all graphics
  ' will show immediately on the screen, this is convenient for simple demos where we don't need animation
  gr.start
  gr.setup(X_TILES, Y_TILES, 0, 0, PAGE0_BUFFER)

  ' BEGIN GAME LOOP ///////////////////////////////////////////////////////////

  ' out of the main loop simply render into page 0 and page 1 our images
  ' page 0 - kaledioscope of stars

  ' set graphics engine to render into page 0 
  gr.setup(X_TILES, Y_TILES, 0, 0, PAGE0_BUFFER)

  ' kaledioscope
  repeat i from 0 to 1000
    ' select random color and position for star
    color := 1 +(color + (?rand & $8FFFFFFF)) // 3
    x := ?rand // (SCREEN_WIDTH/2)
    y := ?rand // SCREEN_HEIGHT
    ' render star
    gr.colorwidth(color, 0)
    gr.plot(x + SCREEN_WIDTH/2,y)
    gr.plot(SCREEN_WIDTH/2 - x,y) 
 
    
  ' now page 1 - 3D sphere  
  ' set graphics engine to render into page 1 
  gr.setup(X_TILES, Y_TILES, 0, 0, PAGE1_BUFFER)

  ' set visible page to page 1
  Set_Video_Page(PAGE1_BUFFER)

    ' draw 3 random spheres
    repeat i from 0 to 2
      x0 := (?rand & $FFF) // SCREEN_WIDTH
      y0 := (?rand & $FFF) // SCREEN_HEIGHT
      scale := (?rand & $F) // 4 + 2

      rand *= rand
      
      repeat x from -100 to 100 step 3
        repeat y from -100 to 100 step 3
          z := ^^(x*x + y*y + 400)
          ' colorize using shades based on z
          gr.colorwidth(1 + (z >> 5), 0)
          ' perform perspective transform, screen mapping, and translation      
          xs := x0 + scale*((x << 24)/(z << 18))/3
          ys := y0 + scale*((y << 24)/(z << 18))/3
          ' plot the 3D funtion z=f(x,y)
          gr.plot(xs, ys)

    
  ' infinite loop flip back and forth between pages...
  repeat while TRUE
    ' get nes controller button
    nes_buttons := gpad.read       

    ' right put up page 1
    if (nes_buttons & NES_RIGHT)
      Set_Video_Page(PAGE0_BUFFER)
      
    else ' left put up page 2
    if (nes_buttons & NES_LEFT)
      Set_Video_Page(PAGE1_BUFFER)

    repeat 1000
   
    ' END RENDERING SECTION ///////////////////////////////////////////////////

  ' END MAIN GAME LOOP REPEAT BLOCK ///////////////////////////////////////////

' /////////////////////////////////////////////////////////////////////////////
' FUNCTIONS ///////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

PUB Set_Video_Page(page_address) | dx, dy    
' init tile screen with sent page address
  repeat dx from 0 to tv_hc - 1
    repeat dy from 0 to tv_vc - 1
      screen[dy * tv_hc + dx] := page_address >> 6 + dy + dx * tv_vc + ((dy & $3F) << 10)


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