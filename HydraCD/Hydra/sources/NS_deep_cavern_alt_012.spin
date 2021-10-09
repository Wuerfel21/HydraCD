' //////////////////////////////////////////////////////////////////////
' Deep Cavern (Alternate Car Track Version)                          
' AUTHOR: Nick Sabalausky
' LAST MODIFIED: 2.2.06
' VERSION 1.2
'
' Gamepad code is taken from asteroids_demo_013 by Andre' LaMothe
'
' To play:
'   Move left and right with the gamepad or the arrow keys.
'
' Summary of changes:
'  - Clock is now 80MHz
'  - Added keyboard input
'  - Graphical improvements
'  - Optimizations
'
' Detailed Change Log
' --------------------
' v1.2 (2.2.06):
' - Optimized DrawCavern()
' - Added keyboard input
' - Graphical improvements
'
' v1.1 (2.2.06):
' - Replaced random function with ? operator
' - Changed clock from 40MHz to 80MHz
' - Add outline to walls
' - Optimized playfield rendering by drawing the "hole" instead of the walls
' - Renamed Draw_Walls() to DrawCavern() to reflect new method of rendering
'
' To do
' ------
' - Separate gamepad handling into an external object
' - Title screen with "Press Start"
' - Seed randomizer with data from user input (tie to "Press Start")
' - Add audio
' - Score
' - Collisions
' - Adjust colors
' - Change position and speed to use fixed-point math
' - Interpret new random wall X position to be relative previous X position
' - Vector-based player
' - Sync to vertical retrace
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x            ' enable external clock and pll times 4
  _xinfreq = 10_000_000 + 0000        ' set frequency to 10 MHZ plus some error for xtals that are not exact add 1000-5000 usually works
  _stack = ($3000 + $3000 + 64) >> 2  ' accomodate display memory and stack   

  ' graphics driver and screen constants
  PARAMCOUNT        = 14        
  OFFSCREEN_BUFFER  = $2000           ' offscreen buffer
  ONSCREEN_BUFFER   = $5000           ' onscreen buffer

  X_TILES           = 16
  Y_TILES           = 12
  
  SCREEN_WIDTH      = 256
  SCREEN_HEIGHT     = 192 

  SCREEN_LEFT   = -SCREEN_WIDTH/2
  SCREEN_RIGHT  = (SCREEN_WIDTH/2)-1
  SCREEN_BOTTOM = -SCREEN_HEIGHT/2
  SCREEN_TOP    = (SCREEN_HEIGHT/2)-1

  ' NES bit encodings
  NES_RIGHT  = %00000001
  NES_LEFT   = %00000010
  NES_DOWN   = %00000100
  NES_UP     = %00001000
  NES_START  = %00010000
  NES_SELECT = %00100000
  NES_B      = %01000000
  NES_A      = %10000000

  ' control keys
  KB_LEFT_ARROW  = $C0
  KB_RIGHT_ARROW = $C1
  KB_UP_ARROW    = $C2
  KB_DOWN_ARROW  = $C3
  KB_ESC         = $CB
  KB_SPACE       = $20
  KB_ENTER       = $0D

  ' player  
  PLAYER_START_X = 0
  PLAYER_START_Y = 80

  ' cavern playfield
  NUM_WALL_SEGMENTS     = 10  ' number of vertical segments per screen that make up the walls
  CAVERN_WIDTH          = 60
  WALL_SEGMENT_HEIGHT   = SCREEN_HEIGHT / (NUM_WALL_SEGMENTS-2)
  VIRTUAL_SCREEN_HEIGHT = SCREEN_HEIGHT + (WALL_SEGMENT_HEIGHT*2)

  ' graphics driver constants
  PIXEL_SHAPE_ROUND  = $00
  PIXEL_SHAPE_SQUARE = $10

  ' colors
  BORDER_COLOR         = 2
  CAVERN_COLOR         = 1
  CAVERN_OUTLINE_COLOR = 3
  DEPTH_LINE_COLOR     = 2
  GATE_COLOR           = 3

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
  
  ' nes gamepad vars
  long nes_buttons

  ' random stuff
  long rand
  
  ' player
  long player_x, player_y

  ' cavern playfield
  long wall_segment_x[NUM_WALL_SEGMENTS]
  byte top_wall_segment
  byte is_wall_segment_odd   ' Alternates between true and false when a wall segment is passed
  long top_wall_segment_y

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

  tv    : "tv_drv_010.spin"          ' instantiate a tv object
  gr    : "graphics_drv_010.spin"    ' instantiate a graphics object
  key   : "keyboard_iso_010.spin"    ' instantiate a keyboard object       

'///////////////////////////////////////////////////////////////////////
' GLOBAL INITIALIZATION ///////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB start | i, dx, dy, rotation

  'start keyboard on pingroup 
  key.start(3)

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)
  
  repeat i from 0 to 64
    colors[i] := $00001010 * (i+4) & $F + $FB060C02

  'init tile screen
  repeat dx from 0 to tv_hc - 1
    repeat dy from 0 to tv_vc - 1
      screen[dy * tv_hc + dx] := onscreen_buffer >> 6 + dy + dx * tv_vc + ((dy & $3F) << 10)

  'start and setup graphics
  gr.start
  gr.setup(X_TILES, Y_TILES, 128, 96, offscreen_buffer)

  'seed random counter
  rand := 21

  'set player's initial position
  player_x := PLAYER_START_X
  player_y := PLAYER_START_Y

  top_wall_segment := 0
  top_wall_segment_y := CONSTANT(SCREEN_HEIGHT/2)

  repeat i from 0 to CONSTANT(NUM_WALL_SEGMENTS-1)
    wall_segment_x[i] := 0   -(CAVERN_WIDTH/2)

'///////////////////////////////////////////////////////////////////////
' MAIN LOOP              ///////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

  repeat while TRUE
    gr.clear

    ' draw walls of cavern
    DrawCavern
  
    ' draw player
    gr.width(CONSTANT(PIXEL_SHAPE_SQUARE + 0))
    gr.pix(player_x, player_y, 0, @player_pix)

    'copy bitmap to display
    gr.copy(onscreen_buffer)

    ' move walls
    top_wall_segment_y +=1
    if(top_wall_segment_y - SCREEN_TOP > WALL_SEGMENT_HEIGHT)
      top_wall_segment_y -= WALL_SEGMENT_HEIGHT
      not is_wall_segment_odd

      wall_segment_x[top_wall_segment] := (?rand & $07) * 10 '   0 to 70
      wall_segment_x[top_wall_segment] -= 35                 ' -35 to 35
      wall_segment_x[top_wall_segment] -= CONSTANT(CAVERN_WIDTH/2)

      top_wall_segment++
      if(top_wall_segment == NUM_WALL_SEGMENTS)
        top_wall_segment := 0

      ' end if top_wall_segment wrapped
    ' end if top_wall_segment_x wrapped

    ' move player
    nes_buttons := NES_Read_Gamepad
    if((nes_buttons & NES_RIGHT) or (-key.keystate(KB_RIGHT_ARROW)))
      player_x += 1
    if((nes_buttons & NES_LEFT) or (-key.keystate(KB_LEFT_ARROW)))
      player_x -= 1

  ' end of main loop

' //////////////////////////////////////////////////////////////////

PUB DrawCavern | i, x1, y1, x2, y2, x3, y3, x4, y4, wall_segment, next_wall_segment, left_line_length, right_line_length

  ' These don't have to be calculated each iteration.
  ' They can be updated by just subtracting WALL_SEGMENT_HEIGHT.
  y1 := top_wall_segment_y
  y2 := top_wall_segment_y + WALL_SEGMENT_HEIGHT

  ' draw border
{
  gr.colorwidth(BORDER_COLOR, CONSTANT(PIXEL_SHAPE_SQUARE + 0))
  gr.plot(SCREEN_LEFT,  SCREEN_TOP)
  gr.line(SCREEN_RIGHT, SCREEN_TOP)
  gr.line(SCREEN_RIGHT, SCREEN_BOTTOM)
  gr.line(SCREEN_LEFT,  SCREEN_BOTTOM)
  gr.line(SCREEN_LEFT,  SCREEN_TOP)
}
  gr.colorwidth(BORDER_COLOR, CONSTANT(PIXEL_SHAPE_SQUARE + 0))
  gr.plot(SCREEN_LEFT,  SCREEN_TOP)
  gr.line(SCREEN_LEFT,  SCREEN_BOTTOM)
  gr.plot(SCREEN_RIGHT, SCREEN_TOP)
  gr.line(SCREEN_RIGHT, SCREEN_BOTTOM)


  ' draw wall segments from top to bottom 
  repeat i from 0 to NUM_WALL_SEGMENTS-2

    wall_segment := (top_wall_segment + i) // NUM_WALL_SEGMENTS
    next_wall_segment := (wall_segment + 1) // NUM_WALL_SEGMENTS

    ' set up coordinates for left wall (coordinates are clockwise from 1 to 4 starting with bottom-left)
    x1 := wall_segment_x[next_wall_segment]
    y1 -= WALL_SEGMENT_HEIGHT

    x2 := wall_segment_x[wall_segment]
    y2 -= WALL_SEGMENT_HEIGHT

    x3 := x2 + CAVERN_WIDTH
    y3 := y2

    x4 := x1 + CAVERN_WIDTH
    y4 := y1

    ' draw cavern
    gr.color(CAVERN_COLOR)
    gr.tri(x1, y1, x2, y2, x3, y3)
    gr.tri(x1, y1, x3, y3, x4, y4)

    ' set colorwidth for cavern outline
    gr.colorwidth(CAVERN_OUTLINE_COLOR, CONSTANT(PIXEL_SHAPE_SQUARE + 1))

    ' draw left cavern outline
    gr.plot(x1, y1)
    gr.line(x2, y2)

    ' draw right cavern outline
    gr.plot(x3, y3)
    gr.line(x4, y4)

    ' on every other wall segment...
'    if((i ^ is_wall_segment_odd) & 1)

    ' set colorwidth for depth lines
'    gr.colorwidth(DEPTH_LINE_COLOR, CONSTANT(PIXEL_SHAPE_ROUND + 0))
{
    ' draw left depth lines
    gr.plot(SCREEN_LEFT, y1)
    gr.line(x1, y1)                                    'horizontal line
    gr.plot(SCREEN_LEFT + ((x1 - SCREEN_LEFT)>>1), y1)
    gr.line(SCREEN_LEFT + ((x2 - SCREEN_LEFT)>>1), y2) 'connecting line

    ' draw right depth lines
    gr.plot(SCREEN_RIGHT, y4)
    gr.line(x4, y4)                                      'horizontal line
    gr.plot(SCREEN_RIGHT - ((SCREEN_RIGHT - x4)>>1), y4)
    gr.line(SCREEN_RIGHT - ((SCREEN_RIGHT - x3)>>1), y3) 'connecting line
}  


    ' draw outer depth lines
    gr.colorwidth(DEPTH_LINE_COLOR, CONSTANT(PIXEL_SHAPE_ROUND + 0))
    gr.plot(SCREEN_LEFT, y1)  'left
    gr.line(SCREEN_LEFT + ((x1 - SCREEN_LEFT)>>2), y1) 'horizontal line
    gr.line(SCREEN_LEFT + ((x2 - SCREEN_LEFT)>>2), y2) 'connecting line
    gr.plot(SCREEN_RIGHT, y4)  'right
    gr.line(SCREEN_RIGHT - ((SCREEN_RIGHT - x4)>>2), y4) 'horizontal line
    gr.line(SCREEN_RIGHT - ((SCREEN_RIGHT - x3)>>2), y3) 'connecting line

    ' draw gates
    gr.colorwidth(GATE_COLOR, CONSTANT(PIXEL_SHAPE_ROUND + 0))
    gr.plot(x4, y4)
    gr.line(x4 - 3, y4 + 17)
    gr.line(x4 - 15, y4 + 20)

    gr.line(x1 + 15, y1 + 20)
    gr.line(x1 + 3, y1 + 17)
    gr.line(x1, y1)

' //////////////////////////////////////////////////////////////////

PUB NES_Read_Gamepad : nes_bits        |  i

' //////////////////////////////////////////////////////////////////
' NES Game Paddle Read
' //////////////////////////////////////////////////////////////////       
' reads both gamepads in parallel encodes 8-bits for each in format
' right game pad #1 [15..8] : left game pad #0 [7..0]
'
' set I/O ports to proper direction
' P3 = JOY_CLK      (4)
' P4 = JOY_SH/LDn   (5) 
' P5 = JOY_DATAOUT0 (6)
' P6 = JOY_DATAOUT1 (7)
' NES Bit Encoding
'
' RIGHT  = %00000001
' LEFT   = %00000010
' DOWN   = %00000100
' UP     = %00001000
' START  = %00010000
' SELECT = %00100000
' B      = %01000000
' A      = %10000000

' step 1: set I/Os
DIRA [3] := 1 ' output
DIRA [4] := 1 ' output
DIRA [5] := 0 ' input
DIRA [6] := 0 ' input

' step 2: set clock and latch to 0
OUTA [3] := 0 ' JOY_CLK = 0
OUTA [4] := 0 ' JOY_SH/LDn = 0
'Delay(1)

' step 3: set latch to 1
OUTA [4] := 1 ' JOY_SH/LDn = 1
'Delay(1)

' step 4: set latch to 0
OUTA [4] := 0 ' JOY_SH/LDn = 0

' step 5: read first bit of each game pad

' data is now ready to shift out
' first bit is ready 
nes_bits := 0

' left controller
nes_bits := INA[5] | (INA[6] << 8)

' step 7: read next 7 bits
repeat i from 0 to 6
 OUTA [3] := 1 ' JOY_CLK = 1
 'Delay(1)             
 OUTA [3] := 0 ' JOY_CLK = 0
 nes_bits := (nes_bits << 1)
 nes_bits := nes_bits | INA[5] | (INA[6] << 8)

 'Delay(1)             
' invert bits to make positive logic
nes_bits := (!nes_bits & $FFFF)

' //////////////////////////////////////////////////////////////////
' End NES Game Paddle Read
' //////////////////////////////////////////////////////////////////       

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
                        long    55_250_000      'broadcast
                        long    0               'auralcog

player_vec
                        word $4000 + $2000*270/360
                        word 10

                        word $8000 + $2000*0/360
                        word 5

'                        word $8000 + $2000*90/360
'                        word 5

'                        word $8000 + $2000*45/360
'                        word 15

'                        word $8000 + $2000*45/360
'                        word 25

'                        word $8000 + $2000*45/360
'                        word 15

                        word 0

player_pix
                                                byte 2, 8, 0, 0
{
                                                word %%00000011,%%11000000
                                                word %%00000101,%%10100000
                                                word %%00000111,%%11100000
                                                word %%00000001,%%10000000
                                                word %%00010110,%%01011000
                                                word %%00001100,%%00110000
                                                word %%00000010,%%01000000
                                                word %%00000011,%%11000000
}
                                                word %%00000022,%%22000000
                                                word %%00000202,%%20200000
                                                word %%00000222,%%22200000
                                                word %%00000002,%%20000000
                                                word %%00020220,%%02022000
                                                word %%00002200,%%00220000
                                                word %%00000020,%%02000000
                                                word %%00000022,%%22000000
{
                                                word %%00000033,%%33000000
                                                word %%00000303,%%30300000
                                                word %%00000333,%%33300000
                                                word %%00000003,%%30000000
                                                word %%00030330,%%03033000
                                                word %%00003300,%%00330000
                                                word %%00000030,%%03000000
                                                word %%00000033,%%33000000
}