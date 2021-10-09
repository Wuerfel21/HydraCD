' //////////////////////////////////////////////////////////////////////
' Sub-Hunt    - Shooting game with subs
' AUTHOR: Matthew Kanwisher
' LAST MODIFIED: 2.15.06
' VERSION 1.3
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

  ' text position constants  
  SCORE_X_POS       = -SCREEN_WIDTH/2 + 10
  SCORE_Y_POS       = SCREEN_HEIGHT/2 - 1*14

  SCORE_VAL_X_POS   = -SCREEN_WIDTH/2 + 10
  SCORE_VAL_Y_POS   = SCREEN_HEIGHT/2 - 2*14 - 7


  HISCORE_X_POS     = -24
  HISCORE_Y_POS     = SCREEN_HEIGHT/2 - 1*14

  HISCORE_VAL_X_POS = -24
  HISCORE_VAL_Y_POS = SCREEN_HEIGHT/2 - 2*14 - 7

  TIME_X_POS        = SCREEN_WIDTH/2 - 10/2*12
  TIME_Y_POS        = SCREEN_HEIGHT/2 - 1*14

  TIME_VAL_X_POS    = SCREEN_WIDTH/2 - 10/2*12
  TIME_VAL_Y_POS    = SCREEN_HEIGHT/2 - 2*14 - 7

  
   ' data structure simulation with indices

  SUBS_DS_STATE_INDEX       = 0 ' long, state
  SUBS_DS_X_INDEX           = 1 ' long, x position
  SUBS_DS_Y_INDEX           = 2 ' long, y position
  SUBS_DS_DX_INDEX          = 3 ' long, dx velocity
  SUBS_DS_DY_INDEX          = 4 ' long, dy velocity
  SUBS_DS_SIZE_INDEX        = 5 ' long, size
 
  SUBS_DS_LONG_SIZE         = 8 ' 6 longs per sub data record

  ' game object states
  OBJECT_STATE_DEAD    = $00_01
  OBJECT_STATE_ALIVE   = $00_02
  OBJECT_STATE_DYING   = $00_04
  OBJECT_STATE_FROZEN  = $00_08

  POINTS_PER_DUCK      = 10
  LEVEL_DEFAULT_TICKS  = 450
  TICKS_DIVISOR        = 15
  GAME_OVER_WAIT_TIME  = 650
  TITLE_SCREEN_PULSE   = 200

  ' GAME_STATES
  GAME_STATE_TITLE             = 0 'Title screen,
  GAME_STATE_ATTRACT           = 1  'soon Attract mode(like arcade)
  GAME_STATE_RUN               = 2
  GAME_STATE_GAMEOVER          = 3


  'palette
' PALETTE_GAME     =

' 1100_1_011
'__0001_1_011
'__0000_0_111
'__0000_0_100
' PALETTE_GAME    =  %1100_1_111__1111_1_011__0000_0_111__1111_1_001
' PALETTE_GAME    =  %1100_1_111__1111_1_011__1111_1_111__1111_1_001

'1100_1_011
 '                   Color 3     Color 2     color 1     color 0
 'PALETTE_GAME    = %1100_1_011__0001_1_011__0000_0_111__1111_1_001 
  PALETTE_GAME    = %1100_0_001__0000_0_100__0000_0_111__1111_1_001
' PALETTE_GAME    = %1111_1_011__1100_1_111__0000_0_111__1111_1_001 'Mine

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

  long  mousex, mousey            ' holds mouse x,y absolute position
  long  num_ducks

  ' ducks
  long ducks[SUBS_DS_LONG_SIZE*10]

  'scores
  long totalPoints
  long highScore
  long TimeRemaining
  long ticks
  long points_perduck
  long level
  long totalleft

  ' random stuff
  long random_counter
  long random_counter2

  byte GameState

  'Other
  long tmpTimer
  long speed

  'Sound
  long sd_pin_left
  long sd_pin_right
  long sd_freq_left
  long sd_freq_right
  long sd_volume_left
  long sd_volume_right
  
'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ
  tv    : "tv_drv_010.spin"          ' instantiate a tv object
  gr    : "MK_SUB-HUNT_graphics_drv_011.spin" ' instantiate a graphics object
  mouse : "mouse_iso_010.spin"       ' instantiate a mouse object
  sd    : "sound_drv_010.spin"     ' instantiate the sound object
'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB start | dx, dy, i , lX, lY

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  'colors[0] := PALETTE_GAME
  'init colors
  'repeat i from 0 to 64
  ' colors[i] := $00000000 & $F + $FB060C02
  ' colors[i] := $00001010 * (i+4) & $F + $FB060C02

  colors[0] := PALETTE_GAME

  
    
   ' Init tile screen map to bit buffer, init all tiles to use palette 0.
  repeat lX from 0 to tv_hc - 1
      repeat lY from 0 to tv_vc - 1
         screen[lY * tv_hc + lX] := (onscreen_buffer >> 6) + lY + lX * tv_vc
  
  'init tile screen
' repeat dx from 0 to tv_hc - 1
'   repeat dy from 0 to tv_vc - 1
'     screen[dy * tv_hc + dx] := onscreen_buffer >> 6 + dy + dx * tv_vc + ((dy & $3F) << 10)

  'start and setup graphics 256x192, with orgin (0,0) at center of screen
  gr.start
  gr.setup(X_TILES, Y_TILES, SCREEN_WIDTH/2, SCREEN_HEIGHT/2, offscreen_buffer)

  'start mouse on pingroup 2 (Hydra mouse port)
  mouse.start(2)
  ' initialize mouse postion
  mousex := 0
  mousey := 0

  ' seed random counter
  random_counter := 42050

          
  ' BEGIN GAME LOOP ////////////////////////////////////////////////////

  totalPoints := 0
  ' infinite loop
  repeat while TRUE
   
    'clear the offscreen buffer
     gr.clear

    ' INPUT SECTION ////////////////////////////////////////////////////
    ' update mouse position with current delta (remember mouse works in deltas)
    ' for fun notice the creepy syntax at the end? these are the "bounds" operators!
    mousex := mousex + mouse.delta_x #> -128 <# 127
    mousey := mousey + mouse.delta_y #> -96 <# 95
 

      case GameState
         GAME_STATE_TITLE:
           ShowTitle
         GAME_STATE_RUN:
           RunGame
         GAME_STATE_GAMEOVER:
           GameOver

    random_counter := random_counter + 1
    'copy bitmap to display offscreen -> onscreen
    gr.copy(onscreen_buffer)

    ' synchronize to frame rate would go here...

    ' END RENDERING SECTION ////////////////////////////////////////////

  ' END MAIN GAME LOOP REPEAT BLOCK ////////////////////////////////////

pub InitDucks | i, base
  
  ' initialize subs (all of them for now)
  repeat i from 0 to num_ducks-1      
    base := i*SUBS_DS_LONG_SIZE          
    ducks[base+SUBS_DS_STATE_INDEX      ] := OBJECT_STATE_ALIVE
    ducks[base+SUBS_DS_X_INDEX          ] := 100+Rand '-128+Rand
    ducks[base+SUBS_DS_Y_INDEX          ] := -91+Rand
    ducks[base+SUBS_DS_DX_INDEX         ] := -2 + Rand >> 5
    ducks[base+SUBS_DS_DY_INDEX         ] := -2 + Rand >> 5
    ducks[base+SUBS_DS_SIZE_INDEX       ] := 20 + Rand >> 3

  ticks := LEVEL_DEFAULT_TICKS
  timeRemaining := ticks / TICKS_DIVISOR
  points_perduck := POINTS_PER_DUCK * level


PUB Rand : retval
 random_counter := (1 + random_counter ^ random_counter << 6 ^ random_counter << 2 ^ random_counter << 7)
 random_counter2 := ((random_counter >> 16) * 154) >> 16
 retval := random_counter2



'PUB RandBounds : retval 'Special bounds for 0-164 the bounds of the attack square
' random_counter2 := ((Rand >>16) * 100/164) >> 16
' retval := random_counter2

  
PUB Int_To_String(str, i) | t
' does an sprintf(str, "%05d", i); job 
  str+=5
  repeat t from 0 to 4
    BYTE[str] := 48+(i // 10)
    i/=10   
    str--

pub DrawScores
  if( timeRemaining > 0 )
   if (totalLeft > 0)
    ticks := ticks - 1
    timeRemaining := ticks / TICKS_DIVISOR

  if( highScore < totalPoints )
   highScore := totalPoints

 'draw text
  gr.textmode(2,1,5,3)
  gr.colorwidth(2,0)


  ' draw score and num players
  gr.text(SCORE_X_POS, SCORE_Y_POS, @score_string)
  gr.text(HISCORE_X_POS, HISCORE_Y_POS, @hiscore_string)
  gr.text(TIME_X_POS, TIME_Y_POS, @time_string)


  Int_To_String(@value_string, totalPoints)
  gr.text(SCORE_VAL_X_POS, SCORE_VAL_Y_POS, @value_string)

  Int_To_String(@value_string2, highScore)
  gr.text(HISCORE_VAL_X_POS, HISCORE_VAL_Y_POS, @value_string2)


  Int_To_String(@value_string3, timeRemaining)
  gr.text(TIME_VAL_X_POS, TIME_VAL_Y_POS, @value_string3)

pub ChangeGameState (gs)
  ticks := LEVEL_DEFAULT_TICKS
  timeRemaining := ticks / TICKS_DIVISOR
  'GameState := GAME_STATE_TITLE
 
  ' Intialize the ducks posistions  
  level := 1
  tmpTimer := 0
  GameState := gs
  speed  := 1
  totalPoints := 0

  'Setup ducks
  num_ducks := 2

  InitDucks                  
  
pub ShowTitle
    'Pulse  the Title screen
    if( tmpTimer < 150 )
      gr.textmode(1,1,6,5)
      gr.colorwidth(1,0)
      gr.text(1,10,@title_string)
      gr.text(1,1,@title2_string)

    tmpTimer := tmpTimer + 1
    if(tmpTimer > TITLE_SCREEN_PULSE) 'Pulse
      tmpTimer := 0

    if mouse.button(0) ' left button
        ChangeGameState(GAME_STATE_RUN)

    'random_counter := random_counter + 1

pub GameOver
    gr.textmode(1,1,6,5)
    gr.colorwidth(1,0)
    gr.text(1,10,@GameOver_string)  'Show Game Over Text

    tmpTimer := tmpTimer + 1
    if(tmpTimer > GAME_OVER_WAIT_TIME) 'Go to title screen after a certain amount of time
       ChangeGameState(GAME_STATE_TITLE)

    if mouse.button(0) ' left button
        ChangeGameState(GAME_STATE_RUN)

pub RunGame | i, base, newpos, tmp, dx, dy, x, y

    ' RENDERING SECTION (render to offscreen buffer always//////////////
         
    'draw mouse cursor
    'gr.colorwidth(3,0)

    gr.textmode(1,1,6,5)
    'gr.colorwidth(3,0)

    'DrawDebug(0)

   MoveSubs

   'gr.colorwidth(3,0)
   totalLeft := 0
   repeat i from 0 to   num_ducks-1
     base := i*SUBS_DS_LONG_SIZE
     if ( not (ducks[base+SUBS_DS_STATE_INDEX] & OBJECT_STATE_DEAD ) )           
       dx := ducks[base + SUBS_DS_X_INDEX]
       dy := ducks[base + SUBS_DS_Y_INDEX]
       gr.pix(dx, dy, 0, @sub_bitmap)
       totalLeft := totalLeft + 1

   if (totalLeft == 0)
        gr.text(1,1,@levelComplete_string)
        tmpTimer := tmpTimer + 1

   if( timeRemaining < 1 )
    if (totalLeft > 0)
      ChangeGameState(GAME_STATE_GAMEOVER)
      
   if( tmpTimer == 100 )
    level := level + 1
    tmpTimer := 0
    ticks := 0
    if ( num_ducks < 10)        'Add a duck each level
      num_ducks := num_ducks + 1
    if (speed < 10)
      speed := speed + 1
      'Increcase speed each level
    InitDucks
        

   DrawScores

    ' test for mouse buttons to change bitmap rendered
    if mouse.button(0) ' left button
       ' draw tie fighter with left wing retracted at x,y with rotation angle 0
       gr.pix(mousex, mousey, 0, @mouse_left_bitmap)

       repeat i from 0 to   num_ducks-1
         base := i*SUBS_DS_LONG_SIZE
         dx := ducks[base + SUBS_DS_X_INDEX]
         dy := ducks[base + SUBS_DS_Y_INDEX]
        
         'dx := dx
         dy := dy - 4
         if(mousex > dx )
          dx := dx + 16
          if(mousex < dx )
            if(mousey > dy )
               dy := dy + 4
               if(mousey < dy + 8)
                  if ( not (ducks[base+SUBS_DS_STATE_INDEX] & OBJECT_STATE_DEAD ) )
                    'if ( not (ducks[base+SUBS_DS_STATE_INDEX] & OBJECT_STATE_DYING ) )
                      'gr.text( -50, -50, @hit_string )
                      ducks[base+SUBS_DS_STATE_INDEX] := OBJECT_STATE_DEAD
                      totalPoints += points_perduck
                      PlayHitSound  
'      CheckForHits                           
       
                                                        
    else
       ' draw tie fighter with normal wing configuration at x,y with rotation angle 0
       gr.pix(mousex, mousey, 0, @mouse_normal_bitmap)

 
   
'pub CheckForHits  | i, base, dx, dy
                                 


pub MoveSubs | i, base, x
  ' move subs
  repeat i from 0 to num_ducks-1
    base := i*SUBS_DS_LONG_SIZE
    if ( not (ducks[base+SUBS_DS_STATE_INDEX] & OBJECT_STATE_DEAD ) )
      ducks[base + SUBS_DS_X_INDEX] -= speed
      x := ducks[base + SUBS_DS_X_INDEX]
      
      if (x < -SCREEN_WIDTH/2 )
       ducks[base+SUBS_DS_X_INDEX] := 128+Rand
       ducks[base+SUBS_DS_Y_INDEX] := -91+Rand
       totalPoints := totalPoints - 5
       if( totalPoints < 0 )
         totalPoints := 0

pub PlayHitSound | i
  'start sound
  
  sd_pin_left := 7
  sd_freq_left := $200C2345>>4
  sd_volume_left := $FFFF >> 0
  sd.start(@sd_pin_left)

   repeat i from 0 to 100
    sd_freq_left += 18
    sd_freq_right +=  18
   sd.stop
'pub DrawDebug
'DEBUG//////////////////////////////////////////

   ' Int_To_String(@value_string2, Rand)
   ' gr.text(1,10,@value_string2)

   ' temp := ((random_counter >> 16) * 100) >> 16
   ' Int_To_String(@value_string, temp)
   ' gr.text(1,1,@value_string)

    'Int_To_String(@value_string2, mousex+128)
    'gr.text(1,10,@value_string2)

    'Int_To_String(@value_string, mousey+96)
    'gr.text(1,1,@value_string)
'End DEBUG//////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' DATA SECTION /////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

DAT

' TV PARAMETERS FOR DRIVER /////////////////////////////////////////////

tvparams  long    0               'status
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

'' Pixel sprite definition:
''
''    word                          ' This is need to WORD align the data structure
''    byte    xwords, ywords        ' x,y dimensions expressed as WORDsexpress dimensions and center, define pixels
''    byte    xorigin, yorigin      ' Center of pixel sprite  
''    word    %%xxxxxxxx,%%xxxxxxxx ' Now comes the data in row major WORD form...
''    word    %%xxxxxxxx,%%xxxxxxxx
''    word    %%xxxxxxxx,%%xxxxxxxx

' bitmaps for mouse cursor

mouse_left_bitmap     word                           
                      byte    2,8,3,3                ' 2 words wide (8 pixels) x 8 words high (8 lines), 8x8 sprite
                      word    %%00000000,%%00000000      
                      word    %%00000000,%%00000000
                      word    %%00000011,%%11000000
                      word    %%00000111,%%11100000
                      word    %%00000111,%%11100000
                      word    %%00000011,%%11000000
                      word    %%00000000,%%00000000
                      word    %%00000000,%%00000000

mouse_normal_bitmap word                             
                      byte    2,8,3,3                ' 2 words wide (8 pixels) x 8 words high (8 lines), 8x8 sprite
                      word    %%00000001,%%10000000      
                      word    %%00000001,%%10000000
                      word    %%00000001,%%10000000
                      word    %%00001101,%%10110000
                      word    %%00000001,%%10000000
                      word    %%00000001,%%10000000
                      word    %%00000001,%%10000000
                      word    %%00000000,%%00000000

sub_bitmap            word                           ' Duck1
                      byte    2,8,3,3                ' 2 words wide (8 pixels) x 8 words high (8 lines), 8x8 sprite
                      word    %%00002222,%%20000000
                      word    %%00000002,%%22000000      
                      word    %%00000022,%%22200000
                      word    %%02222222,%%22222220
                      word    %%33333333,%%33333333
                      word    %%03333333,%%33333330
                      word    %%00333333,%%33333300
                      word    %%00000000,%%00000000

                      
value_string            byte    "000000",0
value_string2           byte    "000000",0
value_string3           byte    "000000",0
'hit_string             byte    "Hit!", 0
levelComplete_string    byte    "Level Complete!", 0
score_string            byte    "Score",0               'text
hiscore_string          byte    "High",0                'text
time_string             byte    "Time",0                'text
GameOver_string         byte    "Game Over",0           'text
title_string            byte    "Sub Hunt!", 0
title2_string           byte    "Click to start!", 0





                  