' //////////////////////////////////////////////////////////////////////
' Hydris                                
' VERSION 1.2
'
' Controls:
' NES gamepad:
'  Select level with <- and ->
'  Press START to start game
'  Move block with D-Pad
'  Press A or B to turn the block
'  
' Keyboard:
'  Press CTRL-L or ALT-L to start game
'  Move block with arrows
'  Press CTRL-L or ALT-L to turn the block
'
'  Bugs:
'  - Blocks can be turned into other blocks or can wrap around
'    the edges (gives the game a unique element :) )
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x            ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0_000       ' set frequency to 10 MHZ
  _stack = 256
                                                                                                      
  ' graphics driver and screen constants
  PARAMCOUNT        = 14        
  OFFSCREEN_BUFFER  = $2900           ' offscreen buffer
  ONSCREEN_BUFFER   = $5500           ' onscreen buffer

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

  word  screen[168] ' storage for screen tile map
  long  colors[64]  ' color look up table

  ' nes gamepad vars
  long nes_buttons
  
  ' game vars
  word game_state
  long game_score
  byte game_lines
  byte game_level
  long frame

  long random_counter

  byte playfield[10*20]

  long freq, freq_delta
 
'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ
  snd   : "NS_sound_drv_030.spin" 'Sound driver
  tv    : "RB_tv_drv_010.spin"    ' instantiate a tv object
  gr    : "RB_graphics_drv_010.spin" ' instantiate a graphics object
  key   : "RB_keyboard_iso_010.spin" ' instantiate a keyboard object

  
'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB start | i, j,k,l,dx, dy, x0, y0,orientation,do,tile,status,line_complete,next_tile,sound_play,frame_counter

  'start keyboard on pingroup 3 
  key.start(3)

  'start sound driver
  snd.start(7)

  freq := 200
  freq_delta := 10
  
  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  'init colors
  repeat i from 0 to 64
    colors[i] := $00001010 * (i+4) & $F + $CB060C02

  repeat i from 0 to 64 step 4
    byte[@colors][i] := $2
    byte[@colors][i+2] := $7     
    'byte[@colors][i+1] :=((1<<4)+$C)
    byte[@colors][i+3] :=((1<<4)+$E)

  'init tile screen
  repeat dx from 0 to tv_hc - 1
    repeat dy from 0 to tv_vc - 1
      screen[dy * tv_hc + dx] := onscreen_buffer >> 6 + dy + dx * tv_vc + ((dy & $3F) << 10)
      
  'start and setup graphics 224x192, with orgin (0,0) at bottom of playfield
  gr.start
  gr.setup(14, 12, SCREEN_WIDTH/2-64, 20, offscreen_buffer)

  'reset game vars
  game_level   := 1
  game_state   := GAMESTATE_INIT

  frame := 0
                 
  ' BEGIN GAME LOOP /////////////////////////////////////////////////
  
  ' infinite loop

  sound_play:=0
  frame_counter:=0
  
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
    if(key.keystate($F2) or key.keystate($F4))
      nes_buttons|=NES_START
    if(key.keystate($F2)) ' CTRL-L
     nes_buttons|=NES_A
    if(key.keystate($F4)) ' ALT-L
      nes_buttons|=NES_B      
                

  ' HANDLE GAME STATES
    case game_state
      GAMESTATE_INIT:                                   ' INITIALIZATION        ////////////////                                                                                        
        'clear canvas
        gr.clear
        gr.colorwidth(2,14)
        gr.box(-45,-11,216,180,1)
        gr.colorwidth(3,14)
        gr.box(-46,-10,216,180,1)
        gr.textmode(3,1,6,6)                                ' draw text
        gr.colorwidth(2,1)                
        gr.text(65,SCREEN_HEIGHT/2+19 ,@title_string)
        gr.colorwidth(1,0)        
        gr.text(64,SCREEN_HEIGHT/2+20 ,@title_string)
        gr.text(64,SCREEN_HEIGHT/2-20 ,@start_string)

        gr.text(64,SCREEN_HEIGHT/2-40 ,@level_string)
        case game_level
          0:
            gr.text(64,SCREEN_HEIGHT/2-60 ,@level_easy)
          1:
            gr.text(64,SCREEN_HEIGHT/2-60 ,@level_normal)
          2:
            gr.text(64,SCREEN_HEIGHT/2-60 ,@level_hard)      

        if(frame//4==1)
          if((nes_buttons & NES_LEFT) <> 0)
            if(game_level>0)
              game_level-=1
            else
              game_level:=2

          if((nes_buttons & NES_RIGHT) <> 0)
            if(game_level<2)
              game_level+=1
            else
              game_level:=0
              
        if((nes_buttons & NES_START) <> 0)
          'init game vars
          game_score := 0
          game_lines:=0
          orientation:=0 ' 0=0, 1=90,2=180, 3=270
          do:=0
          status:=2
          tile:=next_tile
          next_tile:=New_Tile
          x0:=0
          dy:=1
          dx := 0

          ' seed random counter
          random_counter := frame
          
          if(sound_play==0)
            snd.PlaySound(3, snd#SHAPE_SINE, freq, snd#DURATION_INFINITE)
            sound_play:=1
            frame_counter:=frame
        if(sound_play==1)
          snd.SetFreq(3, freq)
          freq += freq_delta
          if((freq => 800) or (freq =< 200))
            -freq_delta
        if(sound_play==1 and frame>frame_counter+60)
          sound_play:=2
          snd.StopSound(3)
          game_state := GAMESTATE_PLAY
          gr.clear
          gr.colorwidth(2,14)
          gr.box(-9,-11,150,180,1)
          gr.color(3)
          gr.box(-10,-10,150,180,1)
          gr.colorwidth(1,6)                                      
          gr.box(93, SCREEN_HEIGHT/2 + 40, 37, 11,1)              ' score                               
          gr.box(93, SCREEN_HEIGHT/2 + 10, 37, 11,1)              ' lines
          gr.box(93, SCREEN_HEIGHT/2-35, 37, 37,1)                ' next block
          gr.textmode(1,1,6,5)                                    ' draw text
          gr.colorwidth(2,0)
          gr.text(107,SCREEN_HEIGHT/2 + 30,@lines_string)
          gr.text(107,SCREEN_HEIGHT/2 + 60,@score_string)
          gr.color(0)
          'clear playfield
          gr.box(0,0,10*8,20*8,1)                                             
          repeat i from 0 to 199
            playfield[i]:=0
          status:=2
          
      GAMESTATE_PLAY:                                   ' GAME IN PLAY          ////////////////
        dy := 1
                                             
        if((nes_buttons & NES_UP) <> 0)
          k:=1              
        if((nes_buttons & NES_DOWN) <> 0)         
          dy := 2
        if((nes_buttons & NES_LEFT) <> 0)
          dx := -1
        if((nes_buttons & NES_RIGHT) <> 0)
          dx := 1
        if((nes_buttons & NES_A) <> 0)
            do:=1
        elseif((nes_buttons & NES_B) <> 0)
            do:=-1

        orientation+=do
        do:=0
        if(orientation==4)
          orientation:=0
        elseif(orientation==-1)
          orientation:=3
           
        if(status==2) ' new tile
          y0:=19-(byte[tile][4]>>4)&%1111
          x0:=1-((byte[tile][4]&%1111)>>2)
          status:=1
          orientation:=0
          tile:=next_tile
          next_tile:=New_Tile
          frame_counter:=frame
        
        if(status==1)
          repeat i from 0 to 3  ' left border
            repeat j from 0 to 9
              if(playfield[(y0+i)*10+j]==1 and j+dx<0)
                dx:=0
                i:=3
                j:=9

          repeat i from 0 to 3  ' right border
            repeat j from 9 to 0 step -1
              if(playfield[(y0+i)*10+j]==1 and j+dx>9)
                dx:=0
                i:=3
                j:=9
          repeat i from 0 to 3 ' check if tile is about to hit another tile
            repeat j from 0 to 9
               if (playfield[(y0+i)*10+j] == 1 and playfield[(y0+i)*10+j+dx]==2 )                      
                   dx:=0                          
                   j:=9
                   i:=3

          x0+=dx
          dx:=0

          i:=frame-frame_counter
          case game_level
            0:
              i//=4
            1:
              i//=3
            2:
              i//=2
          
          if(i==0)            
            repeat i from 0 to 3       ' check if tile is about to hit another tile
              repeat j from 0 to 9
               if (playfield[(y0+i)*10+j] == 1 and playfield[(y0+i-dy)*10+j]==2 )
                   repeat until dy==0 or playfield[(y0+i-dy)*10+j]==0
                    dy-=1               
               if(dy==0)
                 status:=2              
                 j:=9
                 i:=3
            if(status==1 and y0<5)              
              dy:=Check_Bottom(y0,dy)              
              if(dy>190)
                y0-=200-dy
                status:=2
            if(status==1)
                y0-=dy          
        
        if(status==2 and y0==19-1-(byte[tile][4]>>4)&%1111)
          game_state := GAMESTATE_DEAD
          frame_counter:=frame
          freq:=800
          sound_play:=0

        repeat i from 0 to 199 ' clear playfield
          if(playfield[i]==1)
            playfield[i]:=0

        k:=0
        case orientation ' check orientation of tile
          0:
            repeat i from 0 to 3
              k:=0
              repeat j from 0 to 4 step 2
                k:=k+1                           
                if((byte[tile+i]>>(4-j))&1==1)
                  playfield[(((byte[tile][4]>>4)&%1111)-i+y0)*10+x0+k+1]:=status
                                                                                
          2:
            repeat i from 0 to 3
              k:=0
              repeat j from 0 to 4 step 2
                k:=k+1
                if((byte[tile+i]>>(j))&1==1)
                  playfield[(i+y0+1)*10+x0+k+1]:=status
          1:
            repeat j from 0 to 4 step 2
              k+=1
              repeat i from 0 to 3
                if((byte[tile+i]>>j)&1==1)
                  playfield[(k+y0)*10+x0+4-i]:=status
          3:
            repeat j from 0 to 4 step 2
              k+=1
              repeat i from 0 to 3
                if((byte[tile+i]>>(4-j))&1==1)
                  playfield[(k+y0)*10+x0+2+i]:=status

        gr.width(0)
        repeat i from 0 to 9 ' draw playfield
          repeat j from 0 to 19
              gr.color(1)
              if(playfield[j*10+i]>0)
                gr.box(i*8,j*8,8,8,0)               
              else
               gr.color(0)
               gr.box(i*8,j*8,8,8,0)           

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
              snd.PlaySound(1, snd#SHAPE_NOISE, 300, CONSTANT( Round(Float(snd#SAMPLE_RATE) * 0.1)) )
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
        Draw_Block(next_tile)

      GAMESTATE_DEAD:
        gr.textmode(3,1,6,6)
        gr.color(1)
        gr.text(65,SCREEN_HEIGHT/2-1 ,@gameover_string)
        gr.color(3)
        gr.text(64,SCREEN_HEIGHT/2 ,@gameover_string)
        if(sound_play==0)
            snd.PlaySound(3, snd#SHAPE_SINE, freq, snd#DURATION_INFINITE)
            sound_play:=1
        if(sound_play==1)
          snd.SetFreq(3, freq)
          freq -= 5
          if (freq =< 200)
             snd.StopSound(3)
             sound_play:=2
        if(frame>frame_counter+210)
          sound_play:=0
          freq := 200
          freq_delta := 10
          game_state := GAMESTATE_INIT
        
    ' END CASE LIST    

    ' synchronise to frame rate
    repeat while tv_status==1                           ' end of visible
    'copy bitmap to display offscreen -> onscreen
    gr.copy(onscreen_buffer)

    frame++

    ' END DRAW SECTION //////////////////////////////////////////////

  ' END MAIN GAME LOOP REPEAT BLOCK /////////////////////////////////
          
PUB Update_Score   
    'update score area
    gr.colorwidth(0,6)                                  ' blank out score region
    gr.box(92, SCREEN_HEIGHT/2 + 41, 37, 11,1)
    Int_To_String(@value_string, game_score)           
    gr.textmode(1,1,6,5)                                ' draw text
    gr.colorwidth(1,0)
    gr.text(110,SCREEN_HEIGHT/2 + 46,@value_string)

PUB Update_Lines   
    'update lines area
    gr.colorwidth(0,6)                                  ' blank out line region
    gr.box(92, SCREEN_HEIGHT/2 + 11, 37, 11,1)
    Int_To_String(@value_string, game_lines)           
    gr.textmode(1,1,6,5)                                ' draw text
    gr.colorwidth(1,0)
    gr.text(110,SCREEN_HEIGHT/2 + 16,@value_string)
    
PUB Int_To_String(str, i) | t
' does an sprintf(str, "%05d", i); job 
  str+=4
  repeat t from 0 to 3
    BYTE[str] := 48+(i // 10)
    i/=10   
    str--

PUB Check_Bottom(y0,dy): retval|i,j
  repeat i from 0 to 3
    repeat j from 0 to 9 
      if (playfield[(y0+i)*10+j] == 1 and y0+i-dy<1 )
         repeat until y0+i-dy==0
          dy-=1
         if(dy>0)
           dy:=200-dy
         else
           dy:=200+dy
         j:=9
         i:=3
  retval:=dy
      

PUB Draw_Block(tile)|i,j,k
  gr.colorwidth(0,6)                                ' blank out line region
  gr.box(92, SCREEN_HEIGHT/2-34, 37, 37,1)

  repeat i from 0 to 3
    k:=0
    repeat j from 0 to 4 step 2
      k+=1                                       
      if((byte[tile+i]>>(4-j))&1==1)
        gr.colorwidth(1,0)
        gr.box(86+k*8,SCREEN_HEIGHT/2-8-i*8,8,8,0)

PUB New_Tile: retval
  random_counter:=+frame
  retval:=@ZT+(1 + random_counter ^ random_counter << 6 ^ random_counter << 2 ^ random_counter << 7)//7*5
    
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
value_string            byte    "00000",0
title_string            byte    "Hydris",0
start_string            byte    "Press Start!",0
level_string            byte    "Level:",0
level_easy              byte    "Easy",0
level_normal            byte    "Normal",0
level_hard              byte    "Hard",0

ZT                      byte    %%01
                        byte    %%11
                        byte    %%10
                        byte    %%00
                        byte    %0011_0010' length 0 90 180 270


ST                      byte    %%10
                        byte    %%11
                        byte    %%01
                        byte    %%00
                        byte    %0011_0010' length 0 90 180 270

IT                      byte    %%10
                        byte    %%10
                        byte    %%10
                        byte    %%10
                        byte    %0100_0001' length 0 90 180 270

TT                      byte    %%10
                        byte    %%11
                        byte    %%10
                        byte    %%00
                        byte    %0011_0001' length 0 90 180 270

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