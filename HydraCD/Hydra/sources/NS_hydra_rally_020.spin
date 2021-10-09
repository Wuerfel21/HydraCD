{///////////////////////////////////////////////////////////////////////
Hydra Rally
AUTHOR: Nick Sabalausky
LAST MODIFIED: 2.14.06
VERSION 2.0

Gamepad code is taken from asteroids_demo_013 by Andre' LaMothe

To play:
  Move left and right with the gamepad or the arrow keys,
  but stay on the track!

Detailed Change Log
--------------------
v2.0 (2.14.06):
- Merged original version of racer (NS_deep_cavern_alt_013.spin)
  with newest version of Deep Cavern (NS_deep_cavern_020.spin)
- Reversed direction of scrolling

To do
------
- Psuedo-3D Perspective on Gates
- Separate gamepad handling into an external object
- Title screen with "Press Start"
- Seed randomizer with data from user input (tie to "Press Start")
- Score
- Change position and speed to use fixed-point math
- Interpret new random wall X position to be relative previous X position
- Vector-based player
- Recode in ASM

///////////////////////////////////////////////////////////////////////}

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
  PLAYER_START_X   = 0
  PLAYER_START_Y   = SCREEN_BOTTOM-55
  PLAYER_RESPAWN_Y = SCREEN_BOTTOM-8
  PLAYER_NORMAL_Y  = -60

  ' track playfield
  NUM_WALL_SEGMENTS     = 10  ' number of vertical segments per screen that make up the walls
  TRACK_WIDTH           = 60
  WALL_SEGMENT_HEIGHT   = SCREEN_HEIGHT / (NUM_WALL_SEGMENTS-2)
  VIRTUAL_SCREEN_HEIGHT = SCREEN_HEIGHT + (WALL_SEGMENT_HEIGHT*2)

  ' colors
  BORDER_COLOR        = 2
  TRACK_COLOR         = 1
  TRACK_OUTLINE_COLOR = 3
  GATE_COLOR          = 3

  ' sound
  DROPIN_FREQ_START = 350
  DROPIN_FREQ_END   = 625
  DROPIN_FREQ_DELTA = 3

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
  long player_img_ptr

  ' temps
  long dist_from_top, dist_from_left, offscreen_offset, color_under_player

  ' track playfield
  long wall_segment_x[NUM_WALL_SEGMENTS]
  long top_wall_segment

  long top_wall_segment_y

  ' sound
  long dropin_freq   'current frequency of "drop in" sound

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

  tv    : "tv_drv_010.spin"                       'TV Driver
  gr    : "NS_graphics_drv_small_010.spin"        'Graphics Driver
  key   : "NS_keyboard_drv_keyconstants_010.spin" 'Keyboard Driver
  snd   : "NS_sound_drv_040.spin"                 'Sound Driver

'///////////////////////////////////////////////////////////////////////
' GLOBAL INITIALIZATION ///////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB start | i, dx, dy

  'start sound driver
  snd.start(7)

  'start keyboard on pingroup 
  key.start(3)

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)
  
  longmove(@colors, @color_data, 12)

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
    wall_segment_x[i] := CONSTANT(-TRACK_WIDTH/2)

  player_img_ptr := @player_pix

  'play "drop in" sound effect
  snd.PlaySoundFM(0, snd#SHAPE_NOISE, DROPIN_FREQ_START, snd#DURATION_INFINITE)
  dropin_freq := DROPIN_FREQ_START

'///////////////////////////////////////////////////////////////////////
' MAIN LOOP              ///////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

  repeat while TRUE
    gr.clear

    DrawTrack

    'copy bitmap to display
    'repeat while tv_status == 1 
    'repeat while tv_status == 2
    gr.copy(onscreen_buffer)

    'move walls
    if((player_img_ptr == @player_dead_pix) and (player_y < CONSTANT(SCREEN_BOTTOM-8)))
      top_wall_segment_y -= 4
    else
      top_wall_segment_y -= 1

    if(top_wall_segment_y - SCREEN_TOP < 0)
      top_wall_segment_y += WALL_SEGMENT_HEIGHT

      top_wall_segment--
      if(top_wall_segment == -1)
        top_wall_segment := CONSTANT(NUM_WALL_SEGMENTS-1)

      if(player_img_ptr <> @player_dead_pix)  'player alive
        wall_segment_x[top_wall_segment] := ((?rand & $07) * 10) - CONSTANT(35 + TRACK_WIDTH/2)
      else                                    'player dead
        wall_segment_x[top_wall_segment] := CONSTANT(-TRACK_WIDTH/2)

      ' end if top_wall_segment wrapped
    ' end if top_wall_segment_x wrapped

    ' move player
    if(player_img_ptr == @player_dead_pix) 'player dead

      'update y
      if(player_y > PLAYER_START_Y)
        player_y--  'stay on wall

        if(player_y =< CONSTANT(SCREEN_BOTTOM-14) and dropin_freq == 0)
          'start playing "drop in" sound effect
          snd.PlaySoundFM(0, snd#SHAPE_NOISE, CONSTANT(DROPIN_FREQ_START-50), snd#DURATION_INFINITE)
          dropin_freq := DROPIN_FREQ_START
      else
        'respawn player
        player_x := PLAYER_START_X
        player_y := PLAYER_RESPAWN_Y
        player_img_ptr := @player_pix

    else                                   'player alive

      'update y
      if(player_y < PLAYER_NORMAL_Y)
        player_y++

      'update_x
      nes_buttons := NES_Read_Gamepad
      if((nes_buttons <> $FFFF and nes_buttons & NES_RIGHT) or (-key.keystate(KB_RIGHT_ARROW)))
        player_x += 1
      if((nes_buttons <> $FFFF and nes_buttons & NES_LEFT) or (-key.keystate(KB_LEFT_ARROW)))
        player_x -= 1

    'update "drop in" sound effect
    if(dropin_freq <> 0)
      if(dropin_freq => DROPIN_FREQ_END)
        dropin_freq := 0
        snd.StopSound(0)
      else
        dropin_freq += DROPIN_FREQ_DELTA
        snd.SetFreq(0, dropin_freq)

  ' end of main loop

' //////////////////////////////////////////////////////////////////

PUB DrawTrack | i, x1, y1, x2, y2, x3, y3, x4, y4, wall_segment, next_wall_segment, left_line_length, right_line_length

  ' These don't have to be calculated each iteration.
  ' They can be updated by just subtracting WALL_SEGMENT_HEIGHT.
  y1 := top_wall_segment_y
  y2 := top_wall_segment_y + WALL_SEGMENT_HEIGHT

  ' draw wall segments from top to bottom 
  repeat i from 0 to NUM_WALL_SEGMENTS-2

    wall_segment := (top_wall_segment + i) // NUM_WALL_SEGMENTS
    next_wall_segment := (wall_segment + 1) // NUM_WALL_SEGMENTS

    ' set up coordinates for left wall (coordinates are clockwise from 1 to 4 starting with bottom-left)
    x1 := wall_segment_x[next_wall_segment]
    y1 -= WALL_SEGMENT_HEIGHT

    x2 := wall_segment_x[wall_segment]
    y2 -= WALL_SEGMENT_HEIGHT

    x3 := x2 + TRACK_WIDTH
    y3 := y2

    x4 := x1 + TRACK_WIDTH
    y4 := y1

    ' draw track
    gr.color(TRACK_COLOR)
    gr.tri(x1, y1, x2, y2, x3, y3)
    gr.tri(x1, y1, x3, y3, x4, y4)

    ' set colorwidth for track outline
    gr.colorwidth(TRACK_OUTLINE_COLOR, $11)

    ' draw left track outline
    gr.plot(x1, y1)
    gr.line(x2, y2)

    ' draw right track outline
    gr.plot(x3, y3)
    gr.line(x4, y4)

  gr.finish

  'check for collision with wall (by checking pixel color)
  if((player_img_ptr <> @player_dead_pix) and (player_y > CONSTANT(SCREEN_BOTTOM+1)))
    
    dist_from_top      := SCREEN_HEIGHT - (player_y + CONSTANT((SCREEN_HEIGHT/2)-1) )
    dist_from_left     := player_x + CONSTANT(SCREEN_WIDTH/2)
    offscreen_offset   := dist_from_top + ((dist_from_left>>4)<<7) + ((dist_from_left>>4)<<6)
    color_under_player := ((LONG[OFFSCREEN_BUFFER][offscreen_offset] >> ((dist_from_left & $0F) << 1)) & %11)
    if(color_under_player <> TRACK_COLOR and color_under_player <> GATE_COLOR)
      snd.PlaySoundFM(0, snd#SHAPE_TRIANGLE, 200, CONSTANT(snd#SAMPLE_RATE/3))
      dropin_freq := 0
      player_img_ptr := @player_dead_pix

  'draw player
  gr.width($10)
  gr.pix(player_x, player_y, 0, player_img_ptr)


  y1 := top_wall_segment_y
  y2 := top_wall_segment_y + WALL_SEGMENT_HEIGHT
  
  ' draw wall segments from top to bottom 
  gr.colorwidth(GATE_COLOR, $10)
  repeat i from 0 to NUM_WALL_SEGMENTS-2

    wall_segment := (top_wall_segment + i) // NUM_WALL_SEGMENTS
    next_wall_segment := (wall_segment + 1) // NUM_WALL_SEGMENTS

    ' set up coordinates for left wall (coordinates are clockwise from 1 to 4 starting with bottom-left)
    x1 := wall_segment_x[next_wall_segment]
    y1 -= WALL_SEGMENT_HEIGHT

    x2 := wall_segment_x[wall_segment]
    y2 -= WALL_SEGMENT_HEIGHT

    x3 := x2 + TRACK_WIDTH
    y3 := y2

    x4 := x1 + TRACK_WIDTH
    y4 := y1
    
    ' draw gates
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

color_data
                        long $BB06026D
                        long $BB06026C
                        long $BB06026D
                        long $BB06026C
                        long $BB06026D
                        long $BB06026C
                        long $BB06026D
                        long $BB06026C
                        long $BB06026D
                        long $BB06026C
                        long $BB06026D
                        long $BB06026C

player_pix
                                                byte 2, 12, 8, 6
                                                word %%00000002,%%20000000
                                                word %%00002202,%%20220000
                                                word %%00002222,%%22220000
                                                word %%00002202,%%20220000

                                                word %%00000002,%%20000000
                                                word %%00000002,%%20000000
                                                word %%00000022,%%22000000
                                                word %%00000022,%%22000000

                                                word %%00022022,%%22022000
                                                word %%00022222,%%22222000
                                                word %%00022022,%%22022000
                                                word %%00000022,%%22000000

player_dead_pix
                                                byte 2, 12, 8, 6
                                                word %%00000000,%%22200000
                                                word %%00002202,%%22202200
                                                word %%00022202,%%22002200
                                                word %%00022002,%%20002200

                                                word %%00000002,%%20000000
                                                word %%00000000,%%20000000
                                                word %%00000020,%%22000000
                                                word %%00000022,%%00000000

                                                word %%00022022,%%00022000
                                                word %%00022222,%%22222000
                                                word %%00022022,%%22022000
                                                word %%00000022,%%22000000