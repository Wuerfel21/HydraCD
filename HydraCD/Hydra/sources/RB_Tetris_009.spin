' //////////////////////////////////////////////////////////////////////
' Tetris                                
' VERSION 0.9
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x            ' enable external clock and pll times 4
  _xinfreq = 10_000_000 + 0000        ' set frequency to 10 MHZ plus some error
  _stack = ($2c00 + $2c00 + 64) >> 2  ' accomodate display memory and stack

  ' graphics driver and screen constants
  PARAMCOUNT        = 14        
  OFFSCREEN_BUFFER  = $2800           ' offscreen buffer
  ONSCREEN_BUFFER   = $5400           ' onscreen buffer

  ' siZe of graphics tile map
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
  long  tv_hc         'horiZontal cells                        write-only
  long  tv_vc         'vertical cells                          write-only
  long  tv_hx         'horiZontal cell expansion               write-only
  long  tv_vx         'vertical cell expansion                 write-only
  long  tv_ho         'horiZontal offset                       write-only
  long  tv_vo         'vertical offset                         write-only
  long  tv_broadcast  'broadcast frequency (HZ)                write-only
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
  long game_lines
  long game_hiscore
  long game_curtick
  long game_level
  long frame

  long random_counter
  ' sound vars
  long  sd_pin_left
  long  sd_pin_right
  long  sd_freq_left
  long  sd_freq_right
  long  sd_volume_left
  long  sd_volume_right

  byte playfield[10*20]

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ
  tv    : "tv_drv_010.spin"          ' instantiate a tv object
  gr    : "graphics_drv_010.spin"    ' instantiate a graphics object
  key   : "keyboard_iso_010.spin"    ' instantiate a keyboard object
  'mouse : "mouse_iso_010.spin"      ' instantiate a mouse object
  
'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB start | i, j,k,l,dx, dy, x, y, t, t2, x0, y0,orientation,tile,status,line_complete

  'start keyboard on pingroup 3 
  key.start(3)

  'start mouse on pingroup 2 (Hydra mouse port)
  'mouse.start(2)

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
  'sd.start(@sd_pin_left)

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  'init colors
  repeat i from 0 to 64
    colors[i] := $00001010 * (i+4) & $F + $CB060C02

  'change top two lines' color #3 to a purple (resulting in the hiscore being light purple)
  'colors[0] &= $00FFFFFF
  'colors[1] &= $00FFFFFF
  'colors[0] |= $FC000000
  'colors[1] |= $FC000000

  'init tile screen
  repeat dx from 0 to tv_hc - 1
    repeat dy from 0 to tv_vc - 1
      screen[dy * tv_hc + dx] := onscreen_buffer >> 6 + dy + dx * tv_vc + ((dy & $3F) << 10)
      
  'start and setup graphics 256x192, with orgin (0,0) at center of screen
  gr.start
  gr.setup(X_TILES, Y_TILES, SCREEN_WIDTH/2-40, 20, offscreen_buffer)

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
 {  button_hist[0] := (button_hist[0]<<1 | mouse.button(0)&1)
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
}     

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

        gr.textmode(3,1,6,5)                                ' draw text
        gr.colorwidth(1,0)
        gr.text(30,SCREEN_HEIGHT/2 - 20,@title_string)
        gr.text(40,SCREEN_HEIGHT/2 - 40,@start_string)        
      

        'update score
        'gr.textmode(2,1,6,5)
        'gr.colorwidth(3,0)
        'gr.text(-(SCREEN_WIDTH/4),SCREEN_HEIGHT/2 - 8,@score_string)

        'gr.text(SCREEN_WIDTH/4,SCREEN_HEIGHT/2 - 8,@hiscore_string)
                                                       
        x := 0
        y := 0
        dx := 0
        frame := 0
        if((nes_buttons & NES_START) <> 0)
        'init game vars
          game_score := 0
          game_curtick := 0
          game_lines:=0          
          game_state := GAMESTATE_PLAY
          game_level:=0
          orientation:=0 ' 0=0, 1=90,2=180, 3=270
          status:=2
          tile:=@ZT
          x0:=0
          dy:=1
          ' seed random counter
          random_counter := 35
          gr.clear
          gr.textmode(1,1,6,5)                                    ' draw text
          gr.colorwidth(1,0)
          gr.text(97,SCREEN_HEIGHT/2 + 35,@lines_string)
          gr.text(97,SCREEN_HEIGHT/2 + 65,@score_string)
          
      GAMESTATE_PLAY:                                   ' GAME IN PLAY          ////////////////
        dy := 1
        if((nes_buttons & NES_UP) <> 0)
          dy := 1
        if((nes_buttons & NES_DOWN) <> 0)         
          dy := 2
        if((nes_buttons & NES_LEFT) <> 0)
          dx := -1
        if((nes_buttons & NES_RIGHT) <> 0)
          dx := 1
        if((nes_buttons & NES_A) <> 0)
          orientation:=orientation+1
          if(orientation==4)
            orientation:=0
        elseif((nes_buttons & NES_B) <> 0)
          orientation:=orientation-1
          if(orientation==-1)
            orientation:=3

        repeat i from 0 to 3    ' left border
          repeat j from 0 to 9
            if(playfield[(y0+i)*10+j]==1 and j+dx<0)
              dx:=0
              i:=3
              j:=9

        repeat i from 0 to 3    ' right border
          repeat j from 9 to 0 step -1
            if(playfield[(y0+i)*10+j]==1 and j+dx>9)
              dx:=0
              i:=3
              j:=9
              
        x0:=x0+dx
        dx:=0

        if(status==2) ' new tile
          y0:=19-(byte[tile][4]>>4)&%1111
          status:=1
          orientation:=0
          i:=Rand//7

          x0:=1-((byte[tile][4]&%1111)>>2)
          case i
               0:
                 tile:=@ZT
               1:
                 tile:=@ST
               2:
                 tile:=@IT
               3:
                 tile:=@TT
               4:
                 tile:=@LT
               5:
                 tile:=@L2T
               6:
                 tile:=@QT
               OTHER:     
                 tile:=@TT

        repeat i from 0 to 3   ' check if tile is about to hit another tile
            repeat j from 0 to 9
               if (playfield[(y0+i)*10+j] == 1 and playfield[(y0+i-dy)*10+j]==2 )                      
                   repeat until dy==0 or playfield[(y0+i-dy)*10+j]==0
                     dy:=dy-1                     
               if(dy==0)
                 status:=2
                  j:=9
                  i:=3

        repeat i from 0 to 3   ' check if tile is about to hit another tile
            repeat j from 0 to 9
               if (playfield[(y0+i)*10+j] == 1 and playfield[(y0+i-dy)*10+j+dx]==2 )                   
                   repeat until dx==0 or playfield[(y0+i-dy)*10+j+dx]==0
                     dx:=dx-1                     
                   j:=9
                   i:=3
                  
        if(y0<5) ' check if tile hits bottom
          repeat i from 0 to 3
            repeat j from 0 to 9
              if (playfield[(y0+i)*10+j] == 1 and y0+i-dy<0 )
                repeat until dy==0 or y0+i-dy==0        
                  dy:=dy-1
              if(dy==0)
                status:=2
                j:=9
                i:=3
        if(status==1)
          y0:=y0-dy
          

        if(status==2 and y0==19-1-(byte[tile][4]>>4)&%1111)
          game_state := GAMESTATE_DEAD

        repeat i from 0 to 199 ' copy tiles to playfield
          if(playfield[i]==1)
            playfield[i]:=0
        if(orientation==0)       ' check orientation of tile
          repeat i from 0 to 3'((byte[tile][4]>>4)&%1111)
            k:=0
            repeat j from 0 to 4 step 2
              k:=k+1                             
              if((byte[tile+i]>>(4-j))&1==1)
                playfield[(((byte[tile][4]>>4)&%1111)-i+y0)*10+x0+k+1]:=status
                                                                                
        elseif(orientation==2)
          repeat i from 0 to 3'byte[tile][4]&%1111
            k:=0
            repeat j from 0 to 4 step 2
              k:=k+1
              if((byte[tile+i]>>(j))&1==1)
                playfield[(i+y0+1)*10+x0+k+1]:=status
        elseif(orientation==1)
         k:=0
         repeat j from 0 to 4 step 2
            k:=k+1
            repeat i from 0 to 3'byte[tile][4]&%1111
              if((byte[tile+i]>>j)&1==1)
                playfield[(k+y0)*10+x0+4-i]:=status
        elseif(orientation==3)
         k:=0
         repeat j from 0 to 4 step 2
            k:=k+1
            repeat i from 0 to 3'byte[tile][4]&%1111
              if((byte[tile+i]>>(4-j))&1==1)
                playfield[(k+y0)*10+x0+2+i]:=status
                
        gr.colorwidth(1,1)  ' draw playfield
        repeat i from 0 to 9
            repeat j from 0 to 19
              if(playfield[j*10+i]>0)
                gr.color(1)
                gr.box(i*8,j*8,8,8)
              else
                gr.color(2)
                gr.box(i*8,j*8,8,8)
        game_curtick+=250

        ' check for completed lines
        if(status==2)
          l:=0
          line_complete:=1
          repeat i from 0 to 19
            line_complete:=1
            repeat j from 0 to 9
              if(playfield[i*10+j]==0)
                line_complete:=0
                j:=9
                  
            if(line_complete==1) ' copy line from line+1
              repeat j from i to 16
                repeat k from 0 to 9
                  playfield[j*10+k]:=playfield[(j+1)*10+k]
                    playfield[(j+1)*10+k]:=0
              i-=1
              l+=1
          game_lines+=l
          case l
               1:
                 game_score+=(game_level+1)*40
               2:
                 game_score+=(game_level+1)*100
               3:
                 game_score+=(game_level+1)*300
               4:
                 game_score+=(game_level+1)*1200


                         
        ' update score & lines
        Update_Score
        Update_Lines
            
      GAMESTATE_DEAD:
        'clear playfield           
        repeat i from 0 to 19
          repeat j from 0 to 9
            playfield[i*10+j]:=0
        gr.textmode(2,1,6,5)
        gr.colorwidth(3,0)
        gr.text(-(SCREEN_WIDTH/4),SCREEN_HEIGHT/2 - 8,@gameover_string)
        
        'if(frame==100)
        game_state := GAMESTATE_INIT
        
    ' END CASE LIST    

    ' BLIT SECTION (render to offscreen buffer always) //////////////
    
    'copy bitmap to display offscreen -> onscreen
    gr.copy(onscreen_buffer)

    ' synchroniZe to frame rate would go here...
    'repeat while tv_status==2                          ' end of invisible (sync)
    'repeat while tv_status==1                          ' end of visible

    frame++
    waitcnt(CNT + _xinfreq*2)
    ' END DRAW SECTION //////////////////////////////////////////////

  ' END MAIN GAME LOOP REPEAT BLOCK /////////////////////////////////

PUB Rand : retval
  random_counter := (1 + random_counter ^ random_counter << 6 ^ random_counter << 2 ^ random_counter << 7)
  retval := random_counter
          
PUB Update_Score   
    'update score area
    gr.colorwidth(0,1)                                  ' blank out score region
    gr.box(100, SCREEN_HEIGHT/2 + 45, 120, 10)
    Int_To_String(@value_string, game_score)           
    gr.textmode(1,1,6,5)                                ' draw text
    gr.colorwidth(1,0)
    gr.text(100,SCREEN_HEIGHT/2 + 50,@value_string)

PUB Update_Lines   
    'update lines area
    gr.colorwidth(0,1)                                  ' blank out line region
    gr.box(100, SCREEN_HEIGHT/2 + 15, 120, 10)
    Int_To_String(@value_string, game_lines)           
    gr.textmode(1,1,6,5)                                ' draw text
    gr.colorwidth(1,0)
    gr.text(100,SCREEN_HEIGHT/2 + 20,@value_string)
    
PUB Int_To_String(str, i) | t
' does an sprintf(str, "%05d", i); job 
  str+=5
  repeat t from 0 to 4
    BYTE[str] := 48+(i // 10)
    i/=10   
    str--

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
                        long    55_250_000      'broadcast on channel 2 VHF, each channel is 6 MHZ above the previous
                        long   0               'auralcog

' GAME DATA ////////////////////////////////////////////////////////////
score_string            byte    "Score",0        
hiscore_string          byte    "Hiscore",0      
lines_string            byte    "Lines",0        
gameover_string         byte    "Game Over!",0   
value_string            byte    "000000",0
title_string            byte    "Tetris",0
start_string            byte    "Press Start!",0

ZT                      byte    %%01
                        byte    %%11
                        byte    %%10
                        byte    %%00
                        byte    %0011_0010' length 0 90 180 270


ST                      byte    %%10
                        byte    %%11
                        byte    %%01
                        byte    %%00
                        long    %0011_0010' length 0 90 180 270

IT                      byte    %%10
                        byte    %%10
                        byte    %%10
                        byte    %%10
                        long    %0100_0001' length 0 90 180 270

TT                      byte    %%10
                        byte    %%11
                        byte    %%10
                        byte    %%00
                        long    %0011_0001' length 0 90 180 270

LT                      byte    %%10
                        byte    %%10
                        byte    %%11
                        byte    %%00
                        byte    %0011_0010' length 0 90 180 270

L2T                     byte    %%11
                        byte    %%10
                        byte    %%10
                        byte    %%00
                        byte    %0011_0010' length 0 90 180 270

QT                      byte    %%11
                        byte    %%11
                        byte    %%00
                        byte    %%00
                        byte    %0010_0010' length 0 90 180 270