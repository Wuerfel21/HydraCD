' //////////////////////////////////////////////////////////////////////
' Hydra Liner                           
' AUTHOR: Colin Phillips (colin_phillips@gmail.com)
' LAST MODIFIED: 1.25.06
' VERSION 1.2
'
' CONTROLS
' NES D-pad to control liner (sets dir.)
' Keyboard Cursor keys to control liner (sets dir.)
' Mouse L/R buttons to control liner (rotates dir.)
'
' DESCRIPTION:
' Use the NES controller's D-pad to change the direction of the liner,
' survive for as long as you can, don't run over yourself or hit a wall.
' -Added score + hiscore, changed some colors, game speeds up.
' -Screen shrunken to 224x192 (from original 256x192) to free up memory
' -TV and Mouse input added (fixed controller out)
' NOTES:
' Gamepad code taken from asteroids_demo_013 by Andre' LaMothe
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll4x            ' enable external clock and pll times 4
  _xinfreq = 10_000_000 + 0000        ' set frequency to 10 MHZ plus some error
  _stack = ($2c00 + $2c00 + 64) >> 2  ' accomodate display memory and stack

  ' graphics driver and screen constants
  PARAMCOUNT        = 14        
  OFFSCREEN_BUFFER  = $2800           ' offscreen buffer
  ONSCREEN_BUFFER   = $5400           ' onscreen buffer

  ' size of graphics tile map
  X_TILES           = 14
  Y_TILES           = 12
  
  SCREEN_WIDTH      = 224
  SCREEN_HEIGHT     = 192 

  ' NES bit encodings
  NES_RIGHT  = %00000001
  NES_LEFT   = %00000010
  NES_DOWN   = %00000100
  NES_UP     = %00001000
  NES_START  = %00010000
  NES_SELECT = %00100000
  NES_B      = %01000000
  NES_A      = %10000000

  GAMESTATE_INIT = 0
  GAMESTATE_DEAD = 1
  GAMESTATE_PLAY = 2

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
  ' mouse vars
  byte button_hist[2]           ' button history
  byte button_cooldown
  
  ' game vars
  long tmp_c
  word game_state
  long game_score
  long game_hiscore
  long game_curtick
  long frame

  ' sound vars
  long  sd_pin_left
  long  sd_pin_right
  long  sd_freq_left
  long  sd_freq_right
  long  sd_volume_left
  long  sd_volume_right

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ
  tv    : "tv_drv_010.spin"          ' instantiate a tv object
  gr    : "graphics_drv_010.spin"    ' instantiate a graphics object
  sd    : "sound_drv_010.spin"       ' instantiate a sound object
  key   : "keyboard_iso_010.spin"    ' instantiate a keyboard object
  mouse : "mouse_iso_010.spin"       ' instantiate a mouse object
  
'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB start | i, dx, dy, x, y, t, t2

  'start keyboard on pingroup 3 
  key.start(3)

  'start mouse on pingroup 2 (Hydra mouse port)
  mouse.start(2)

  button_hist[0] := 0
  button_hist[1] := 0
  button_cooldown := 0

  'start sound
  sd_pin_left := 6
  sd_pin_right := 7
  sd_freq_left := 0
  sd_freq_right := 0
  sd_volume_left := $0
  sd_volume_right := $0
  sd.start(@sd_pin_left)

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  'init colors
  repeat i from 0 to 64
    colors[i] := $00001010 * (i+4) & $F + $CB060C02

  'change top two lines' color #3 to a purple (resulting in the hiscore being light purple)
  colors[0] &= $00FFFFFF
  colors[1] &= $00FFFFFF
  colors[0] |= $FC000000
  colors[1] |= $FC000000

  'init tile screen
  repeat dx from 0 to tv_hc - 1
    repeat dy from 0 to tv_vc - 1
      screen[dy * tv_hc + dx] := onscreen_buffer >> 6 + dy + dx * tv_vc + ((dy & $3F) << 10)
      
  'start and setup graphics 256x192, with orgin (0,0) at center of screen
  gr.start
  gr.setup(X_TILES, Y_TILES, SCREEN_WIDTH/2, SCREEN_HEIGHT/2, offscreen_buffer)

  'reset game vars
  game_hiscore := 0
  
  game_state := GAMESTATE_INIT
             
  ' BEGIN GAME LOOP /////////////////////////////////////////////////

  ' infinite loop
  repeat while TRUE

  
  ' INPUT SECTION
  ' NES Controller
    nes_buttons := NES_Read_Gamepad
    if(nes_buttons&$ff == $ff)
      nes_buttons&=$ff00                                ' if all 1's then controller is likely not inserted so we pretend no input
    
  ' Keyboard (mapped onto NES buttons)
    if(key.keystate($C2))
      nes_buttons|=NES_UP
    if(key.keystate($C3))
      nes_buttons|=NES_DOWN
    if(key.keystate($C0))
      nes_buttons|=NES_LEFT
    if(key.keystate($C1))
      nes_buttons|=NES_RIGHT
      
  ' Mouse (mapped onto NES buttons)
    button_hist[0] := (button_hist[0]<<1 | mouse.button(0)&1)
    button_hist[1] := (button_hist[1]<<1 | mouse.button(1)&1)

    if(button_cooldown)
      button_cooldown--
    else
      if(button_hist[0]&3==%01) ' L-Click-Down (i.e. previously 0 UP, now 1 DOWN)
        t := dy
        dy := dx                                          ' dy' = dx
        dx := -t                                          ' dx' = -dy
        button_cooldown := 5                              ' 5 frame cooldown (stops accidental double clicks)
      if(button_hist[1]&3==%01) ' R-Click-Down (i.e. previously 0 UP, now 1 DOWN)
        t := dx
        dx := dy                                          ' dy' = dx
        dy := -t                                          ' dx' = -dy
        button_cooldown := 5                              ' 5 frame cooldown (stops accidental double clicks)
      
      
  ' HANDLE GAME STATES
    case game_state
      GAMESTATE_INIT:                                   ' INITIALIZATION        ////////////////

        'turn off sound
        sd_freq_left := $200C2345>>4
        sd_freq_right := $20100000>>4
        sd_volume_left := $0
        sd_volume_right := $0

        'clear canvas
        gr.clear

        'make a border
        gr.colorwidth(3,0)

        x := SCREEN_WIDTH/2 - 1
        y := SCREEN_HEIGHT/2 - 1
        gr.plot(-x, -y)
        gr.line(x, -y)
        gr.line(x, y-32)
        gr.line(-x, y-32)
        gr.line(-x, -y)

        'init game vars
        game_score := 0
        game_curtick := 0


        'update score
        gr.textmode(2,1,6,5)
        gr.colorwidth(2,0)
        gr.text(-(SCREEN_WIDTH/4),SCREEN_HEIGHT/2 - 8,@score_string)

        gr.text(SCREEN_WIDTH/4,SCREEN_HEIGHT/2 - 8,@hiscore_string)
                                                       
        x := 0
        y := 0
        dx := 1
        dy := 0
        frame := 0

        game_state := GAMESTATE_PLAY
        
      GAMESTATE_PLAY:                                   ' GAME IN PLAY          ////////////////
        if((nes_buttons & NES_UP) <> 0)
          dx := 0
          dy := 1
        if((nes_buttons & NES_DOWN) <> 0)
          dx := 0
          dy := -1
        if((nes_buttons & NES_LEFT) <> 0)
          dx := -1
          dy := 0
        if((nes_buttons & NES_RIGHT) <> 0)
          dx := 1
          dy := 0

        game_score++
        if(game_score>game_hiscore)
         game_hiscore := game_score

        repeat while game_curtick<game_score+100
          ' move the pixel at full frame rate
          x := x + dx
          y := y + dy
          tmp_c := Get_Pixel(x,y)
          if(tmp_c)
            sd_freq_left := $200C2345>>4
            sd_freq_right := $20100000>>4
            sd_volume_left := $FFFF
            sd_volume_right := $FFFF

            frame := 0
            game_state := GAMESTATE_DEAD
            quit
          ' plot pixel trail
          gr.colorwidth(1,0)    
          gr.plot(x, y)
          game_curtick+=250
        ' END Itteration REPEAT
        game_curtick-=game_score

        ' draw score & hiscore
        Update_Score(0)
        Update_Score(1)        
            
      GAMESTATE_DEAD:                                   ' GAME OVER             ////////////////
        gr.colorwidth(1,0)
        gr.plot(x, y)
        gr.arc(x, y, frame, frame, frame*32, 256, 32+1, 1)

        sd_freq_left += frame<<16
        sd_freq_right += frame<<16
        if(frame==200)
          game_state := GAMESTATE_INIT
        
    ' END CASE LIST    

    ' BLIT SECTION (render to offscreen buffer always) //////////////
    
    'copy bitmap to display offscreen -> onscreen
    gr.copy(onscreen_buffer)

    ' synchronize to frame rate would go here...
    'repeat while tv_status==2                          ' end of invisible (sync)
    'repeat while tv_status==1                          ' end of visible

    frame++
    ' END DRAW SECTION //////////////////////////////////////////////

  ' END MAIN GAME LOOP REPEAT BLOCK /////////////////////////////////

PUB Update_Score(h) | i, x

    x := -(SCREEN_WIDTH/4)
    
    if(h)
      i := game_hiscore
      x+= SCREEN_WIDTH/2
    else
      i := game_score
    
    'update score area
    gr.colorwidth(0,0)                                  ' blank out score region
    gr.box(-42+x, 72, 84, 9)
    
    Int_To_String(@value_string, i)                    
    gr.textmode(3,1,6,5)                                ' draw text
    gr.colorwidth(1+h<<1,0)
    gr.text(x,SCREEN_HEIGHT/2 - 20,@value_string)

PUB Int_To_String(str, i) | t

' does an sprintf(str, "%05d", i); job
str+=4
repeat t from 0 to 4
  BYTE[str] := 48+(i // 10)
  i/=10
  str--


PUB Get_Pixel(x, y): c | tx, ty, mask

' pixel layout:
' 16 pixels fit in a LONG
'   192 longs fit a vertical BLOCK going down the page (i.e. screen height is 192)
'     16 blocks fit the SCREEN going across the page

tx := SCREEN_WIDTH/2 + x
ty := SCREEN_HEIGHT/2 - y - 1
mask := %11 << ((tx&15)<<1)

c := (LONG[offscreen_buffer + (tx>>4)*768 + ty*4]>>((tx&15)<<1)) & %11

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
                        long    55_250_000      'broadcast on channel 2 VHF, each channel is 6 MHz above the previous
                       long    0               'auralcog

' GAME DATA ////////////////////////////////////////////////////////////
score_string            byte    "Score",0        'text
hiscore_string          byte    "Hiscore",0      'text
value_string            byte    "00000",0        'text