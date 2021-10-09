' //////////////////////////////////////////////////////////////////////
' VECTOR_SCROLL_DEMO_001.SPIN - Basic vector scrolling demo of mountainscape
' World coordinates (0,0) to (2559, 191), 10 screens
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 7.20.06
' VERSION 1.0
' 256x192, 4 colors, bitmapped, quadrant I, mapped to screen, (0,0) at
' lower bottom left
'
' CONTROLS: Use gamepad to move right and left. Notice the helicopter!
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

  ' NES bit encodings for NES gamepad 0
  NES0_RIGHT  = %00000000_00000001
  NES0_LEFT   = %00000000_00000010
  NES0_DOWN   = %00000000_00000100
  NES0_UP     = %00000000_00001000
  NES0_START  = %00000000_00010000
  NES0_SELECT = %00000000_00100000
  NES0_B      = %00000000_01000000
  NES0_A      = %00000000_10000000

  ' NES bit encodings for NES gamepad 1
  NES1_RIGHT  = %00000001_00000000
  NES1_LEFT   = %00000010_00000000
  NES1_DOWN   = %00000100_00000000
  NES1_UP     = %00001000_00000000
  NES1_START  = %00010000_00000000
  NES1_SELECT = %00100000_00000000
  NES1_B      = %01000000_00000000
  NES1_A      = %10000000_00000000

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


  long num_vectors                                      ' number of vectors in list
  long vbase_offset, vcolor, vx0, vy0, vx1, vy1         ' used to cache each vector
  long view_x, view_y                                   ' lower left hand point of viewport
  long screen_x0, screen_y0, screen_x1, screen_y1       ' screen mapped coords
  
'//////////////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION //////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////
OBJ
  tv    : "tv_drv_010.spin"          ' instantiate a tv object
  gr    : "graphics_drv_010.spin"    ' instantiate a graphics object
  gp    : "gamepad_drv_001.spin"     ' instantiate game pad object

'//////////////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS ////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

PUB start | i, dx, dy, x, y, index, vrendered, heli_blade_width 

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

  ' start and setup graphics 256x192, with orgin (0,0) at bottom left of screen,
  ' simulating quadrant I of a cartesian coordinate system
  gr.start
  gr.setup(X_TILES, Y_TILES, 0, 0, offscreen_buffer)

  ' start up gamepad
  gp.start
  
  ' BEGIN GAME LOOP ///////////////////////////////////////////////////////////

  ' initialize everything...
  num_vectors := terrain_vector_list[0] ' retrieve number of vectors in list to support dynamic updates
  view_x      := 0 ' starting position of viewport                  
  view_y      := 0

  ' initialize helicoptor blade width to 46
  heli_blade_width := 5
  dx := 7
  
  ' infinite loop
  repeat while TRUE
   
    'clear the offscreen buffer
     gr.clear

    ' INPUT CONTROL

    ' test for viewport scroll
    if (gp.button(NES0_RIGHT) and view_x < 2560 - SCREEN_WIDTH)
      view_x += 10

    if (gp.button(NES0_LEFT) and view_x > 0)
      view_x -= 10

    ' animate the helicopter by going into the display list and manually updating the "blade" line segment index 24 of display list
    ' WORD 2, 334,87, 380,87
    if (heli_blade_width > 30 or heli_blade_width < 2) 
      dx := -dx
    heli_blade_width += dx

    ' update vector display list
    terrain_vector_list[1+24*5 + 1] := 357-heli_blade_width
    terrain_vector_list[1+24*5 + 3] := 357+heli_blade_width
    ' end animation of helicopter

    ' RENDERING SECTION (render to offscreen buffer always/////////////////////

    gr.textmode(2,1,5,2)
    gr.colorwidth(2,0)
   
    ' draw score and num players
    gr.text(10, 190, @INFO_STRING)

    vrendered := 0 ' reset number of vectors rendered

    ' process vector display list
    repeat index from 0 to num_vectors
      ' do a bit of pre-computation, let's make this fast!
      ' extract vector line segment properties, format[color,x1,y1,x2,y2,]
      ' also, invert y-axis to match parallax reference driver's (0,0) origin
      vbase_offset := 1 + index*5 ' pre-compute 
      vcolor := terrain_vector_list[vbase_offset + 0] ' color at offset 0
      vx0    := terrain_vector_list[vbase_offset + 1] ' first point at offset 1,2
      vy0    := SCREEN_HEIGHT - terrain_vector_list[vbase_offset + 2] - 1      
      vx1    := terrain_vector_list[vbase_offset + 3] ' second point at offset 3,4      
      vy1    := SCREEN_HEIGHT - terrain_vector_list[vbase_offset + 4] -1

      ' now we have the line, clip to viewport

      ' is this line segment partially or wholly within viewport? (no need to test y since they are ALWAYS within viewport)
      if ( (vx0 => view_x) and (vx0 < view_x+SCREEN_WIDTH) or (vx1 => view_x) and (vx1 < view_x+SCREEN_WIDTH) ) 
        ' line segment is within viewport, map it to screen coords and render      
        screen_x0 := vx0 - view_x
        screen_y0 := vy0 - view_y
                       
        screen_x1 := vx1 - view_x
        screen_y1 := vy1 - view_y
              
        gr.colorwidth(vcolor,0)
        gr.plot(screen_x0,screen_y0)
        gr.line(screen_x1,screen_y1)

        ' show user how many vectors are rendered 
        gr.colorwidth(3,0)
        gr.plot(10+vrendered*4, 175)
        vrendered++

     'copy bitmap to display offscreen -> onscreen
    gr.copy(onscreen_buffer)

    ' synchronize to frame rate would go here...
    repeat 100

    ' END RENDERING SECTION ///////////////////////////////////////////////////

  ' END MAIN GAME LOOP REPEAT BLOCK ///////////////////////////////////////////

'//////////////////////////////////////////////////////////////////////////////
' DATA SECTION ////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

DAT

' mountainscape vector list each record consists of a the number of vectors followed by the vector list (line segments)
' each vector is in the form - [color,x1,y1,x2,y2,], thus the list looks like
' number of vectors "n" ' 1 WORD
' V0[color,x1,y1,x2,y2,]
' V1[color,x1,y1,x2,y2,]
' ...
' Vn[color,x1,y1,x2,y2,]
' world coordinates are (0,0) to (2559, 191)

terrain_vector_list WORD 126 ' there are 126 vectors in list

' start mountain terrain
WORD 1, 0,191, 38,139           ' vector 0
WORD 1, 38,139, 82,171
WORD 1, 82,171, 122,88
WORD 1, 122,88, 135,115
WORD 1, 135,115, 153,84
WORD 1, 153,84, 195,160
WORD 1, 195,160, 202,132
WORD 1, 202,132, 233,162
WORD 1, 233,162, 262,129
WORD 1, 262,129, 297,161
WORD 1, 297,161, 313,137
WORD 1, 313,137, 333,141
WORD 1, 333,141, 345,125
WORD 1, 345,125, 337,108
WORD 1, 337,108, 376,108

' hellicopter geometry
WORD 2, 321,93, 369,93
WORD 2, 369,93, 374,98
WORD 2, 374,98, 374,102
WORD 2, 374,102, 371,103
WORD 2, 371,103, 358,103
WORD 2, 358,103, 352,97
WORD 2, 352,97, 321,94
WORD 2, 323,90, 323,97
WORD 2, 357,87, 357,93

WORD 2, 334,87, 380,87          ' helicopter blade, update in real-time to animate :)

WORD 2, 359,104, 358,105
WORD 2, 368,104, 369,105
WORD 2, 355,106, 373,106

' continue mountain terrain
WORD 1, 376,108, 412,166
WORD 1, 412,166, 439,162
WORD 1, 439,162, 458,168
WORD 1, 458,168, 479,161
WORD 1, 479,161, 500,169
WORD 1, 500,169, 529,136
WORD 1, 529,136, 564,146
WORD 1, 564,146, 583,102
WORD 1, 583,102, 567,57
WORD 1, 567,57,  603,101
WORD 1, 603,101, 601,131
WORD 1, 601,131, 628,156
WORD 1, 628,156, 645,116
WORD 1, 645,116, 661,92
WORD 1, 661,92, 688,77
WORD 1, 688,77, 707, 112


' hole in mountain
WORD 1, 676,98, 699,113
WORD 1, 699,113, 691,137
WORD 1, 691,137, 663,116
WORD 1, 663,116, 676,98

' continue mountain terrain
WORD 1, 707,112, 703,136
WORD 1, 703, 136, 723, 163
WORD 1, 723, 163, 751,120
WORD 1, 751, 120, 776, 117
WORD 1, 776, 117, 805, 69
WORD 1, 805, 69, 809, 80
WORD 1, 809, 80, 814, 69
WORD 1, 814, 69, 824,88
WORD 1, 824, 88, 828, 75
WORD 1, 828,75, 845,98
WORD 1, 845,98, 885, 118
WORD 1, 885, 118, 918, 154
WORD 1, 918, 154, 960, 153
WORD 1, 960, 153, 991,167

' traffic control tower
WORD 2, 1009, 166, 1007, 117
WORD 2, 1020, 166, 1020, 117
WORD 2, 1000, 116, 1026, 116
WORD 2, 1026, 116, 1035, 107 
WORD 2, 1035, 107, 993, 107
WORD 2, 993, 107, 1000, 116

' continue mountain terrain
WORD 1, 991,167, 1133, 167
WORD 1, 1133, 167, 1202, 62
WORD 1, 1202, 62, 1248, 118 
WORD 1, 1248, 118, 1266, 101
WORD 1, 1266, 101, 1337, 168
WORD 1, 1337, 168, 1361, 102
WORD 1, 1361, 102, 1385, 162 
WORD 1, 1385, 162, 1397, 123
WORD 1, 1397, 123, 1417, 119
WORD 1,  1417, 119, 1426, 88
WORD 1, 1426, 88, 1418, 75 
WORD 1, 1418, 75, 1407, 80
WORD 1, 1407, 80, 1387, 73
WORD 1, 1387, 73, 1403, 60
WORD 1, 1403, 60, 1436, 54
WORD 1, 1436, 54, 1457, 77 
WORD 1, 1457, 77, 1474, 65
WORD 1, 1474, 65, 1480, 83
WORD 1, 1480, 83, 1473, 100
WORD 1, 1473, 100, 1525, 151
WORD 1, 1525, 151, 1549, 128
WORD 1, 1549, 128, 1576, 150
WORD 1, 1576, 150, 1587, 133
WORD 1, 1587, 133, 1637, 184
WORD 1, 1637, 184, 1661, 159
WORD 1, 1661, 159, 1681, 186
WORD 1, 1681, 186, 1697, 172
WORD 1, 1697, 172, 1713, 184 
WORD 1, 1713, 184, 1744, 162 
WORD 1, 1744, 162, 1763, 183
WORD 1, 1763, 183, 1780, 172
WORD 1, 1780, 172, 1794, 180
WORD 1, 1794, 180, 1833, 126
WORD 1, 1833, 126, 1852, 154
WORD 1, 1852, 154, 1894, 96
WORD 1, 1894, 96, 1936, 146
WORD 1, 1936, 146, 1970, 103 
WORD 1, 1970, 103, 2009, 141
WORD 1, 2009, 141, 2034, 113
WORD 1, 2034, 113, 2111, 169
WORD 1, 2111, 169, 2151, 113
WORD 1, 2151, 113, 2190, 143
WORD 1, 2190, 143, 2220, 117
WORD 1, 2220, 117, 2232, 138
WORD 1, 2232, 138, 2248, 93
WORD 1, 2248, 93, 2266, 174
WORD 1, 2266, 174, 2273,160
WORD 1, 2273,160, 2293, 173
WORD 1, 2293, 173, 2313, 152
WORD 1, 2313, 152, 2350, 180
WORD 1, 2350, 180, 2394, 122
WORD 1, 2394, 122, 2441, 180 

' pyramid flats
WORD 1, 2350, 180, 2441, 180
WORD 1, 2386, 133, 2403, 133

WORD 1, 2441, 180, 2483, 152
WORD 1, 2483, 152, 2496, 169
WORD 1, 2496, 169, 2513, 131 
WORD 1, 2513, 131, 2559, 191    ' vector 125

WORD -1 ' terminator just in case

' STRING TABLE /////////////////////////////////////////////////////////

INFO_STRING       byte "HYDRA VECTOR SCROLL DEMO", 0


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


                        