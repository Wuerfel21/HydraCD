{{//////////////////////////////////////////////////////////////////////
Music Demo - A small program that loops Mary had a little lamb
JT Cook
6-24-06
Uses Nick's sound engine

//////////////////////////////////////////////////////////////////////}}

'///////////////////////////////////////////////////////////////////////
' CONSTANTS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
CON
  ' graphics driver and screen constants
  PARAMCOUNT            = 14

  SCREEN_WIDTH          = 128  'Must be multiple of 16
  SCREEN_HEIGHT         = 96   'Must be multiple of 16

  X_TILES               = SCREEN_WIDTH/16
  Y_TILES               = SCREEN_HEIGHT/16
  
  SCREEN_BUFFER_SIZE    = (SCREEN_WIDTH/4) * SCREEN_HEIGHT
  DIRTYRECT_BUFFER_SIZE = (8*2)<<2  '8 "longs" tall by 2 "longs" wide

  ONSCREEN_BUFFER       = $8000-SCREEN_BUFFER_SIZE               'onscreen buffer
  OFFSCREEN_BUFFER      = ONSCREEN_BUFFER-SCREEN_BUFFER_SIZE     'offscreen buffer
  DIRTYRECT_BUFFER      = OFFSCREEN_BUFFER-DIRTYRECT_BUFFER_SIZE 'dirty rectangle buffer (for mouse cursor)

  SCREEN_LEFT   = 0
  SCREEN_RIGHT  = SCREEN_WIDTH-1
  SCREEN_BOTTOM = 0
  SCREEN_TOP    = SCREEN_HEIGHT-1

  _clkmode = xtal2 + pll8x            ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000        ' set frequency to 10 MHZ plus some error for xtals that are not exact add 1000-5000 usually works
  _stack = ((SCREEN_BUFFER_SIZE*2) + DIRTYRECT_BUFFER_SIZE + 64) >> 2  ' accomodate display memory and stack   

  COLOR_WHITE    = 0
  COLOR_BLACK    = 2
  COLOR_MOUSE    = 3
  COLOR_KEYBOARD = 1
  COLOR_DEFAULT  = -1  'Used in DrawKey()
 
  HYDRA_BUTTON_LEFT   = 12
  HYDRA_BUTTON_RIGHT  = SCREEN_WIDTH - HYDRA_BUTTON_LEFT
  HYDRA_BUTTON_TOP    = SCREEN_HEIGHT - 3
  HYDRA_BUTTON_BOTTOM = HYDRA_BUTTON_TOP - 16

'  HYDRA_BUTTON_HIGHLIGHT_TIME = 30

'///////////////////////////////////////////////////////////////////////
' VARIABLES ////////////////////////////////////////////////////////////
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
  'song variables
  byte current_note[4]            'which note is being played
  byte time_note[4]               'how much time until next note
  byte music_vol[4]              'volume of channel
  long music_adr[4]              'address where song is at
'///////////////////////////////////////////////////////////////////////
' OBJECTS //////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

  snd   : "NS_sound_drv_050_22khz_16bit.spin"      'Sound driver
  tv    : "tv_drv_010.spin"                        'TV Driver
  gr    : "graphics_drv_010.spin"                  'Graphics Driver
 

'///////////////////////////////////////////////////////////////////////
' FUNCTIONS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

'// PUB start //////////////////////////////////////////////////////////
PUB start | i, dx, dy, temp, dirtyrect_screen_addr

  
  '---- init graphics ----
  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)
  
  repeat i from 0 to 64
    colors[i] := $C802AB06

  'init tile screen
  repeat dx from 0 to tv_hc - 1
    repeat dy from 0 to tv_vc - 1
      screen[dy * tv_hc + dx] := onscreen_buffer >> 6 + dy + dx * tv_vc + ((dy & $3F) << 10)

  'start and setup graphics
  gr.start
  gr.setup(X_TILES, Y_TILES, 0, 0, offscreen_buffer)

   '---- draw screen ----
  gr.clear
  gr.colorwidth(COLOR_BLACK, $10)
  gr.box(0,0,SCREEN_WIDTH,SCREEN_HEIGHT)

   'draw help text
  gr.color(COLOR_WHITE)
  gr.textmode(1, 1, 6, %%12)
  gr.text(CONSTANT(SCREEN_WIDTH/2), CONSTANT(SCREEN_HEIGHT-2), @hydra_text)
  
  'draw box around hydra button
  gr.color(COLOR_WHITE)
  gr.plot(HYDRA_BUTTON_LEFT,  HYDRA_BUTTON_TOP)
  gr.line(HYDRA_BUTTON_RIGHT, HYDRA_BUTTON_TOP)
  gr.line(HYDRA_BUTTON_RIGHT, HYDRA_BUTTON_BOTTOM)
  gr.line(HYDRA_BUTTON_LEFT,  HYDRA_BUTTON_BOTTOM)
  gr.line(HYDRA_BUTTON_LEFT,  HYDRA_BUTTON_TOP)
  gr.copy(onscreen_buffer)

  'start sound driver
  snd.start(7)
  'reset sound properties
  time_note[0]:=0
  current_note[0]:=0
  music_vol[0]:=255
  music_adr[0]:=@Music
  time_note[1]:=0
  current_note[1]:=0
  music_vol[1]:=100
  music_adr[1]:=@Music2
    
  repeat
'        snd.PlaySoundFM(CHANNEL_SWEEP, shape, freq, CONSTANT(snd#DURATION_INFINITE | (snd#SAMPLE_RATE>>1)), 255, $2457_9DEF)  'Play for an infinite duration
    ' DELAY BEFORE LOOPING ////////////////////////////////////////////////
    repeat while tv_status == 1 
    repeat while tv_status == 2
     PlaySong(0) 'music
     'PlaySong(1) 'background beat
     'this below is done just to slow the program down so the music plays at a desent rate
     gr.copy(onscreen_buffer)
     gr.copy(onscreen_buffer)
     gr.copy(onscreen_buffer)
     gr.copy(onscreen_buffer)
     gr.copy(onscreen_buffer)
     gr.copy(onscreen_buffer)                   

PUB PlaySong(num) | n, nn, nnn, S_Note, S_Time, S_Note_Time, s_freq,s_length, M_adr
'  current_note[4] 'which note is being played
'  time_note[4] 'how much time until next note
   M_adr:=music_adr[num]    'grab address for where song is located
   time_note[num]-=1        'count down the clock
   if(time_note[num]<1)     'if it is at zero, grab next note
    S_Note:=byte[M_adr+current_note[num]]
    if(S_Note==255) 'if at the end of the song, start song over
     current_note[num]:=0
     S_Note:=byte[M_adr+current_note[num]] 'grab first note
    'grab length of note 
    S_Note_Time:=byte[M_adr+(current_note[num]+1)]
    'grab time until next note
    time_note[num]:=byte[M_adr+(current_note[num]+2)]
    'advance to next note
    current_note[num]+=3
'    int_str(s_freq)
    'find out time of note 
    if(S_Note_Time==0) 'whole note
     s_length:=32000
    if(S_Note_Time==1) 'half note
     s_length:=16000
    if(S_Note_Time==2) 'quarter note
     s_length:=8000
    if(S_Note_Time==3) 'eight note
     s_length:=4000
    'load note freq
    s_freq:=word[@M_Notes+(S_Note<<1)]
    'if note is not a rest, play note
    if(s_freq>0)
     if(s_freq<1000) 'normal note
      snd.PlaySoundFM(num, snd#SHAPE_SINE, s_freq, s_length,music_vol[num], $2457_9DEF)
     else
      s_freq-=1000  'beat
      snd.PlaySoundFM(num, snd#SHAPE_TRIANGLE, s_freq, s_length,music_vol[num], $2457_9DEF)     
     
'///////////////////////////////////////////////////////////////////////
' DATA /////////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

DAT

'starting with middle C
M_Notes 'music notes
'    0  1   2   3   4   5   6   7 , 8
' none, C , D , E , F , G , A , B ,beat 
word 0,262,294,330,349,392,440,494,1025
'length of note 0-whole, 1-half, 2-quarter, 3-eight
Music 'note(255 starts over),length of note, time until next note
'Mary Had a Little Lamb - rock on

byte 3,2,200, 2,2,200, 1,2,200, 2,2,200, 3,2,200, 3,2,200, 3,1,200, 0,0,200
byte 2,2,200, 2,2,200, 2,1,200, 0,0,200, 3,2,200, 5,2,200, 5,1,200, 0,0,200
byte 3,2,200, 2,2,200, 1,2,200, 2,2,200, 3,2,200, 3,2,200, 3,1,200, 0,0,200 
byte 2,2,200, 2,2,200, 3,2,200, 2,2,200, 1,1,200, 0,0,200, 0,0,200, 0,0,200, 255

'debug
'byte 0,0,200, 0,0,200, 0,0,200, 255  
Music2
byte 8,2,200, 8,2,200, 8,2,200, 8,1,200, 255
 
tvparams                long    0               'status
                        long    1               'enable
                        long    %011_0000       'pins
                        long    %0000           'mode
                        long    0               'screen
                        long    0               'colors
                        long    X_TILES         'hc
                        long    Y_TILES         'vc
                        long    10*2            'hx timing stretch
                        long    1*2             'vx
                        long    0               'ho
                        long    0               'vo
                        long    55_250_000      'broadcast
                        long    0               'auralcog


hydra_text              byte "Hydra Music Demo",0