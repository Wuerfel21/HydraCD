' //////////////////////////////////////////////////////////////////////
' Color rotation demo, creates 3D trench effect
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 5.15.06
' VERSION 1.0
' 256x192, 4 colors, bitmapped, quadrant I, mapped to screen, (0,0) at
' lower bottom left
' Use the gamepad up/down to speed up/slow down the color rotation
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
  COLOR_2 = (COL_Red    << 16)
  COLOR_3 = (COL_White  << 24)  


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

  long palette[4]                  ' used to shadows colors

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

PUB start | i, dx, dy, x, y, y_inv ,t, temp_color, rotation_rate

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  'init colors, each tile has same 4 colors
  palette[0] := COL_Black  
  palette[1] := COL_Violet
  palette[2] := COL_Violet
  palette[3] := COL_White   
   
  repeat i from 0 to 63
    colors[i] := (palette[3] << 24) | (palette[2] << 16)  | (palette[1] << 8) | (palette[0] << 0)
    
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

    ' start NES game pad task to read gamepad values
  gpad.start

  ' initialize rotation rate
  rotation_rate := 90_000
  
  ' BEGIN GAME LOOP ///////////////////////////////////////////////////////////

  ' infinite loop
  repeat while TRUE
   
    ' RENDERING SECTION (render to offscreen buffer always/////////////////////

    ' set pen attributes, first parm color, second parm size
    gr.colorwidth(3,0)
      
    ' render graphics directly to screen, replace this with your code
    repeat y from 0 to SCREEN_HEIGHT/2
      gr.colorwidth(1 + (y/(25 - y/5)) // 3, 0)

      ' draw pseudo-3D trench
      y_inv := SCREEN_HEIGHT/2 - y
      gr.plot(0,y)
      gr.line(SCREEN_WIDTH/2 - y_inv/1 - 10, y)
      gr.line(SCREEN_WIDTH/2 - y_inv/3 - 10, y - 2*y_inv)
      gr.line(SCREEN_WIDTH/2 + 5*y_inv/1 - 10, y - y_inv/5)
      gr.line( (SCREEN_WIDTH/2 + y_inv/3 + 10) , y + 5*y_inv) 
      
    ' rotate colors  
    repeat while TRUE

      ' get nes controller buttons to change rate
      nes_buttons := gpad.read       

      if (nes_buttons & NES_DOWN)
        rotation_rate += 100
      else
      if (nes_buttons & NES_UP)
        rotation_rate -= 100

    ' the 4 colors are located in palette, we are going to rotate 3->2->1->3
      temp_color := palette[1] ' save this for a moment
      palette[1] := palette[2]
      palette[2] := palette[3]
      palette[3] := temp_color              

    ' now write color palette back into screen colors array, so tiles use them
      repeat i from 0 to 63
        colors[i] := (palette[3] << 24) | (palette[2] << 16)  | (palette[1] << 8) | (palette[0] << 0)

      ' delay a moment
      waitcnt(cnt + rotation_rate)


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