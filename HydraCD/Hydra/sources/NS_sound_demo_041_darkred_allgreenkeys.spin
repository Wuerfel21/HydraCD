{///////////////////////////////////////////////////////////////////////

Sound Demo
AUTHOR: Nick Sabalausky
LAST MODIFIED: 2.14.06
VERSION 4.1: Dark Red Background, All Key Highlights Green (Both Keyboard and Mouse)

Demonstration of NS_sound_drv.
Portions of code taken from mouse demo by Andre' LaMothe

Play musical notes, sweeping tones, and a PCM sample
with the keyboard and mouse.

Controls
---------
  Mouse:
    Click "Hydra Sound Demo" to play a "Hydra" PCM sample (Channel 1)
    Click and drag on the music keyboard to play notes (Channel 2)

  Keyboard:
    QWERTY Row:   Play Natural Notes (Channel 3)
    Number Row:   Play Sharp and Flat Notes (Channel 3)
    Space Bar:    Play "Hydra" PCM Sample (Channel 1)

    F1-F5:        Play a Sweeping Continuous Tone (Channel 0)
    CTRL-(F1-F5): Play a High Tone for 2/5 of a second (Channel 1)
    ALT-(F1-F5):  Play a Low Tone for 2 seconds on (Channel 2)
      F1: Sine Wave
      F2: Sawtooth Wave
      F3: Square Wave
      F4: Triangle Wave
      F5: Noise Function (Note: This tends to drown out other waves)
    Caps Lock:    Toggle Sweep on Continuous Tone (Channel 3)
    Esc:          Stop Continuous Tone (Channel 3)

///////////////////////////////////////////////////////////////////////}

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

  FREQ_INIT = 500
  FREQ_DELTA_INIT = -2
  FREQ_MAX = 800
  FREQ_MIN = 200

  SHAPE_INIT = snd#SHAPE_SINE

  CHANNEL_SWEEP         = 0
  CHANNEL_PCM           = 1
  CHANNEL_MKEY_MOUSE    = 2
  CHANNEL_MKEY_KEYBOARD = 3

  COLOR_WHITE    = 1
  COLOR_BLACK    = 2
  COLOR_MOUSE    = 3
  COLOR_BG     = 0
  COLOR_DEFAULT  = -1  'Used in DrawKey()

  'musical keyboad constants
  MK_NUM_WHITEKEYS   = 15    'Two octaves starting with C and ending with the third C (inclusive)
  MK_NUM_BLACKKEYS   = 10
  MK_NUM_KEYS        = MK_NUM_WHITEKEYS + MK_NUM_BLACKKEYS

  MK_WHITEKEY_WIDTH  = 8
  MK_BLACKKEY_WIDTH  = 5
  
  MK_WIDTH  = MK_WHITEKEY_WIDTH * MK_NUM_WHITEKEYS
  MK_HEIGHT = 38
  MK_LEFT   = 4
  MK_RIGHT  = MK_LEFT + MK_WIDTH
  MK_BOTTOM = 4  '(SCREEN_HEIGHT/2)-(MK_HEIGHT/2)
  MK_TOP    = MK_BOTTOM + MK_HEIGHT

  MK_BLACKKEY_HEIGHT      = (MK_HEIGHT/2)+1
  MK_BLACKKEY_LEFT_OFFSET = -(MK_BLACKKEY_WIDTH/2)
  MK_BLACKKEY_BOTTOM      = MK_TOP - (MK_BLACKKEY_HEIGHT + 1)

  HYDRA_BUTTON_LEFT   = 12
  HYDRA_BUTTON_RIGHT  = SCREEN_WIDTH - HYDRA_BUTTON_LEFT
  HYDRA_BUTTON_TOP    = SCREEN_HEIGHT - 3
  HYDRA_BUTTON_BOTTOM = HYDRA_BUTTON_TOP - 16

  HYDRA_BUTTON_HIGHLIGHT_TIME = 30

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

  'audio states
  long freq, freq_delta
  long shape

  long is_stopped
  long is_shape_changed
  long key_pressed

  'position of the mouse cursor
  'Note: these variables actually store (2 * actual onscreen position)
  long mouse_x, mouse_x_prev
  long mouse_y, mouse_y_prev

  'music key position lookup tables
  long whitekey_pos[MK_NUM_WHITEKEYS]  'High word: left edge position, Low word: right edge position
  long blackkey_pos[MK_NUM_BLACKKEYS]  'High word: left edge position, Low word: right edge position

  'musical key being pressed - White keys: 0 + index | Black keys: MK_NUM_WHITEKEYS + index | No key: $FFFF_FFFF (-1)
  long mouse_mkey_playing
  long keyboard_mkey_playing

  'the PC keyboard key code of the key currently playing a note (No key: 0)
  long keyboard_key_playing

  'the "hydra" button will stay highlighted until this counts down to zero
  long hydra_highlight_count
  
'///////////////////////////////////////////////////////////////////////
' OBJECTS //////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

  snd   : "NS_sound_drv_040.spin"                  'Sound driver
  mouse : "NS_mouse_drv_events_010.spin"           'Mouse Driver
  key   : "NS_keyboard_drv_keyconstants_010.spin"  'Keyboard driver
  tv    : "tv_drv_010.spin"                        'TV Driver
  gr    : "graphics_drv_010.spin"                  'Graphics Driver

  dat_sfx : "NS_hydra_sound_010.spin"              'PCM Sound Effect "Hydra"

'///////////////////////////////////////////////////////////////////////
' FUNCTIONS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

'// PUB start //////////////////////////////////////////////////////////
PUB start | i, dx, dy, temp, dirtyrect_screen_addr

  '---- init i/o ----
  'start keyboard on pingroup 
  key.start(3)

  'start mouse on pingroup 2 (Hydra mouse port)
  mouse.start(2)

  mouse_x := SCREEN_WIDTH   'ie. (SCREEN_WIDTH/2)*2
  mouse_y := CONSTANT((SCREEN_HEIGHT/4)*5)

  '---- init graphics ----
  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)
  
  repeat i from 0 to 64
    colors[i] := $C80206A9

  'init tile screen
  repeat dx from 0 to tv_hc - 1
    repeat dy from 0 to tv_vc - 1
      screen[dy * tv_hc + dx] := onscreen_buffer >> 6 + dy + dx * tv_vc + ((dy & $3F) << 10)

  'start and setup graphics
  gr.start
  gr.setup(X_TILES, Y_TILES, 0, 0, offscreen_buffer)

  '---- init musical keyboard ----
  mouse_mkey_playing    := -1
  keyboard_mkey_playing := -1
 
  'init white key position lookup table
  repeat i from 0 to MK_NUM_WHITEKEYS-1
    whitekey_pos[i] := ((MK_LEFT+(i*MK_WHITEKEY_WIDTH)) << 16) + MK_LEFT+((i+1)*MK_WHITEKEY_WIDTH)

  'init black key position lookup table
  repeat i from 0 to MK_NUM_BLACKKEYS-1
    temp := (CONSTANT(MK_LEFT + MK_BLACKKEY_LEFT_OFFSET) + ((i+LOOKUPZ(i:1,1,2,2,2,3,3,4,4,4))*MK_WHITEKEY_WIDTH))
    blackkey_pos[i] := (temp << 16) + (temp + MK_BLACKKEY_WIDTH)

  '---- draw screen ----
  gr.clear
'  gr.colorwidth(COLOR_BLACK, $10)
'  gr.box(0,0,SCREEN_WIDTH,SCREEN_HEIGHT)

  'draw keyboard
'  gr.color(COLOR_WHITE)
'  gr.box(CONSTANT(MK_LEFT-1), CONSTANT(MK_BOTTOM-1), CONSTANT(MK_WIDTH+3), CONSTANT(MK_HEIGHT+3))
  repeat i from 0 to MK_NUM_WHITEKEYS
    DrawKey(COLOR_DEFAULT, i)

  'draw keyboard outline
  gr.plot(MK_LEFT, MK_TOP)
  gr.line(MK_RIGHT,MK_TOP)
  gr.line(MK_RIGHT,MK_BOTTOM)
  gr.line(MK_LEFT, MK_BOTTOM)
  gr.line(MK_LEFT, MK_TOP)

  'draw lines separating white keys
  repeat i from 1 to MK_NUM_WHITEKEYS-1
    gr.plot(whitekey_pos[i] >> 16, MK_TOP)
    gr.line(whitekey_pos[i] >> 16, MK_BOTTOM)
  

  'draw rounded bottom corners for white keys
  gr.color(COLOR_BLACK)
  gr.plot(MK_RIGHT, MK_BOTTOM)
  repeat i from 0 to MK_NUM_WHITEKEYS-1
    gr.plot((whitekey_pos[i] >> 16)+1, CONSTANT(MK_BOTTOM+1))
    gr.plot((whitekey_pos[i] & $FFFF)-1, CONSTANT(MK_BOTTOM+1))

  'draw rounded bottom corners for white keys
  gr.color(COLOR_BG)
  gr.plot(MK_RIGHT, MK_BOTTOM)
  repeat i from 0 to MK_NUM_WHITEKEYS-1
    gr.plot(whitekey_pos[i] >> 16, MK_BOTTOM)
{
  'draw black keys
  gr.color(COLOR_BLACK)
  repeat i from 0 to MK_NUM_BLACKKEYS-1
    gr.box(blackkey_pos[i] >> 16, MK_BLACKKEY_BOTTOM, MK_BLACKKEY_WIDTH, MK_BLACKKEY_HEIGHT)
}
  'draw snazzy line
  gr.color(COLOR_MOUSE)
  gr.plot(MK_LEFT+1,MK_TOP)
  gr.line(MK_RIGHT-1,MK_TOP)
  gr.color(COLOR_BLACK)
  gr.plot(MK_LEFT+1,MK_TOP-1)
  gr.line(MK_RIGHT-1,MK_TOP-1)

  'draw help text
  gr.color(COLOR_WHITE)
  gr.textmode(1, 1, 6, %%12)
  gr.text(CONSTANT(SCREEN_WIDTH/2), CONSTANT(SCREEN_HEIGHT-21), @help_sweep_text)
  gr.text(CONSTANT(SCREEN_WIDTH/2), CONSTANT(SCREEN_HEIGHT-34), @help_esc_text)

  'draw box around hydra button
  gr.color(COLOR_WHITE)
  gr.plot(HYDRA_BUTTON_LEFT,  HYDRA_BUTTON_TOP)
  gr.line(HYDRA_BUTTON_RIGHT, HYDRA_BUTTON_TOP)
  gr.line(HYDRA_BUTTON_RIGHT, HYDRA_BUTTON_BOTTOM)
  gr.line(HYDRA_BUTTON_LEFT,  HYDRA_BUTTON_BOTTOM)
  gr.line(HYDRA_BUTTON_LEFT,  HYDRA_BUTTON_TOP)

  '---- init sound ----
  'start sound driver
  snd.start(7)

  'init sound vars
  freq := FREQ_INIT
  freq_delta := FREQ_DELTA_INIT
  shape := SHAPE_INIT

  snd.PlaySoundPCM(CHANNEL_PCM, dat_sfx.ns_hydra_sound, dat_sfx.ns_hydra_sound_end)
  DrawHydraButton(COLOR_MOUSE)
  hydra_highlight_count := HYDRA_BUTTON_HIGHLIGHT_TIME

  is_stopped := false
  is_shape_changed := false

  repeat

    'de-highlight hydra button if it's time
    if(hydra_highlight_count > 0)
      hydra_highlight_count--
      if(hydra_highlight_count == 0)
        DrawHydraButton(COLOR_BG)

    ' INPUT SECTION ////////////////////////////////////////////////////
    '--- mouse ----
    mouse.event_poll

    'save old states
    mouse_x_prev := mouse_x
    mouse_y_prev := mouse_y

    'update mouse position with current delta (remember mouse works in deltas)
    'for fun notice the creepy syntax at the end? these are the "bounds" operators!
    mouse_x := mouse_x + mouse.delta_x #> CONSTANT((SCREEN_LEFT+1)*2)   <# CONSTANT((SCREEN_RIGHT-1)*2)
    mouse_y := mouse_y + mouse.delta_y #> CONSTANT((SCREEN_BOTTOM+1)*2) <# CONSTANT((SCREEN_TOP-1)*2)

    HandleMusicKeyboard
    HandleHydraButton

    '--- keyboard ---
    key_pressed := key.key
    case key_pressed & $00FF

      'Stop
      key#KB_ESC:
        snd.StopSound(CHANNEL_SWEEP)
        is_stopped := true

      'Play PCM
      key#KB_SPACE:
        
        'highlight hydra button
        DrawHydraButton(COLOR_MOUSE)
        hydra_highlight_count := HYDRA_BUTTON_HIGHLIGHT_TIME

        'play sound
        snd.PlaySoundPCM(CHANNEL_PCM, dat_sfx.ns_hydra_sound, dat_sfx.ns_hydra_sound_end)

      'Set shape
      key#KB_F1:
        shape := snd#SHAPE_SINE
        is_shape_changed := true
      key#KB_F2:
        shape := snd#SHAPE_SAWTOOTH
        is_shape_changed := true
      key#KB_F3:
        shape := snd#SHAPE_SQUARE
        is_shape_changed := true
      key#KB_F4:
        shape := snd#SHAPE_TRIANGLE
        is_shape_changed := true
      key#KB_F5:
        shape := snd#SHAPE_NOISE
        is_shape_changed := true

    'end of case key_pressed

    'stop playing CHANNEL_MKEY_KEYBOARD if key was released
    if(keyboard_key_playing <> 0)
      if(not key.keystate(keyboard_key_playing))
        snd.StopSound(CHANNEL_MKEY_KEYBOARD)
        keyboard_key_playing := 0
        keyboard_mkey_playing := -1

    'check for musical keyboard keypress on PC keyboard
    repeat i from 0 to CONSTANT(MK_NUM_KEYS-1)
      if(mkey_keyboard_map.BYTE[i] == key_pressed & $FF and mkey_keyboard_map.BYTE[i] <> keyboard_key_playing)
        snd.PlaySoundFM(CHANNEL_MKEY_KEYBOARD, snd#SHAPE_SQUARE, key_notes[i], snd#DURATION_INFINITE)
        keyboard_key_playing := key_pressed & $FF
        keyboard_mkey_playing := i
        quit

    ' SOUND SECTION ////////////////////////////////////////////////////

    'Activate new shape (if one was set)
    if(is_shape_changed)
      is_shape_changed := false

      if(key_pressed & key#KB_CONTROL_MOD)
        snd.PlaySoundFM(CHANNEL_PCM, shape, FREQ_MAX, CONSTANT( Round(Float(snd#SAMPLE_RATE) * 0.4)) )  'Play for two fifths of a second
        is_stopped := false
      elseif(key_pressed & key#KB_ALT_MOD)
        snd.PlaySoundFM(CHANNEL_MKEY_KEYBOARD, shape, FREQ_INIT, CONSTANT( snd#SAMPLE_RATE * 2 ))  'Play for two seconds
        is_stopped := false
      else
        snd.PlaySoundFM(CHANNEL_SWEEP, shape, freq, snd#DURATION_INFINITE)  'Play for an infinite duration
        is_stopped := false
    'end if(is_shape_changed)

    'Perform sweep
    if(not is_stopped and not key.keystate(key#KB_CAPS_LOCK_STATE))
      snd.SetFreq(CHANNEL_SWEEP, freq)

      freq += freq_delta
      if((freq => FREQ_MAX) or (freq =< FREQ_MIN))
        -freq_delta

    ' RENDERING SECTION ////////////////////////////////////////////////////

    'save mouse cursor's dirty rect
    gr.finish
    dirtyrect_screen_addr := OFFSCREEN_BUFFER + (((mouse_x>>5) * SCREEN_HEIGHT) + CONSTANT(SCREEN_HEIGHT-1)-(mouse_y>>1))<<2
    LONGMOVE(DIRTYRECT_BUFFER, dirtyrect_screen_addr, 8)
    if(mouse_x < CONSTANT((SCREEN_WIDTH-16)<<1))
      LONGMOVE(CONSTANT(DIRTYRECT_BUFFER+(DIRTYRECT_BUFFER_SIZE/2)), dirtyrect_screen_addr + CONSTANT(SCREEN_HEIGHT<<2), (mouse_y>>1) <# 8)

    'highlight active keys
    if(mouse_mkey_playing <> -1 and keyboard_mkey_playing <> -1)
      'Ensure a black key doesn't get drawn before a white key
      if(mouse_mkey_playing < keyboard_mkey_playing)
        DrawKey(COLOR_MOUSE, mouse_mkey_playing)
        DrawKey(COLOR_MOUSE, keyboard_mkey_playing)
      else
        DrawKey(COLOR_MOUSE, keyboard_mkey_playing)
        DrawKey(COLOR_MOUSE, mouse_mkey_playing)
    elseif(mouse_mkey_playing <> -1)
      DrawKey(COLOR_MOUSE, mouse_mkey_playing)
    elseif(keyboard_mkey_playing <> -1)
      DrawKey(COLOR_MOUSE, keyboard_mkey_playing)

    'draw mouse
    gr.pix(mouse_x>>1, mouse_y>>1, 0, @pointer_pix)

    'draw border
    gr.colorwidth(COLOR_WHITE, $10)
    gr.plot(SCREEN_LEFT,  SCREEN_TOP)
    gr.line(SCREEN_LEFT,  SCREEN_BOTTOM)
    gr.line(SCREEN_RIGHT, SCREEN_BOTTOM)
    gr.line(SCREEN_RIGHT, SCREEN_TOP)
    gr.line(SCREEN_LEFT,  SCREEN_TOP)

    'copy bitmap to display
    gr.copy(onscreen_buffer)

    'de-highlight active keys
    if(mouse_mkey_playing <> -1)
      DrawKey(-1, mouse_mkey_playing)
    if(keyboard_mkey_playing <> -1)
      DrawKey(-1, keyboard_mkey_playing)

    'erase mouse cursor
    LONGMOVE(dirtyrect_screen_addr, DIRTYRECT_BUFFER, 8)
    if(mouse_x < CONSTANT((SCREEN_WIDTH-16)<<1))
      LONGMOVE(dirtyrect_screen_addr + CONSTANT(SCREEN_HEIGHT<<2), CONSTANT(DIRTYRECT_BUFFER+(DIRTYRECT_BUFFER_SIZE/2)), (mouse_y>>1) <# 8)

    ' DELAY BEFORE LOOPING ////////////////////////////////////////////////
    repeat while tv_status == 1 
    repeat while tv_status == 2

'///////////////////////////////////////////////////////////////////////

PUB HandleHydraButton | i, x, y, is_in_keyboard

  x := mouse_x >> 1
  y := mouse_y >> 1

  is_in_keyboard  := x > HYDRA_BUTTON_LEFT and x < HYDRA_BUTTON_RIGHT and y > HYDRA_BUTTON_BOTTOM and y < HYDRA_BUTTON_TOP

  'button pressed?
  if(mouse.event_button_pressed(0) and is_in_keyboard)

    'highlight hydra button
    DrawHydraButton(COLOR_MOUSE)
    hydra_highlight_count := HYDRA_BUTTON_HIGHLIGHT_TIME

    'play sound
    snd.PlaySoundPCM(CHANNEL_PCM, dat_sfx.ns_hydra_sound, dat_sfx.ns_hydra_sound_end)

'///////////////////////////////////////////////////////////////////////

PUB HandleMusicKeyboard | i, key_pos, x, y, x_prev, y_prev, is_in_keyboard, was_in_keyboard, left_keyboard

  x := mouse_x >> 1
  y := mouse_y >> 1
  x_prev := mouse_x_prev >> 1
  y_prev := mouse_y_prev >> 1

  is_in_keyboard  := not (x > MK_RIGHT or x < MK_LEFT or y > MK_TOP or y < MK_BOTTOM)
  was_in_keyboard := not (x_prev > MK_RIGHT or x_prev < MK_LEFT or y_prev > MK_TOP or y_prev < MK_BOTTOM)
  left_keyboard   := not is_in_keyboard and was_in_keyboard

  'was the keyboard released?
  if(mouse.event_button_released(0) or left_keyboard)
    snd.StopSound(CHANNEL_MKEY_MOUSE)
    mouse_mkey_playing := -1
    return

  'check if keyboard is being pressed
  if(mouse.button(0) and is_in_keyboard)

    'check if a black key is being pressed
    if(y => MK_BLACKKEY_BOTTOM)
      repeat i from 0 to MK_NUM_BLACKKEYS-1

        'is this key being pressed?
        key_pos := blackkey_pos[i]
        if(x => (key_pos >> 16) and x < (key_pos & $FFFF))

          'if this key isn't already playing...
          if(MK_NUM_WHITEKEYS + i <> mouse_mkey_playing)

            'play note
            snd.PlaySoundFM(CHANNEL_MKEY_MOUSE, snd#SHAPE_SQUARE, blackkey_notes[i], snd#DURATION_INFINITE)
            mouse_mkey_playing := MK_NUM_WHITEKEYS + i

          'if this key if being pressed, return regardless
          'of whether it was already playing or not
          return
        'end if "is this key being pressed?"
      'end repeat
    'end if black key pressed

    'a white key is being pressed, check which one
    repeat i from 0 to MK_NUM_WHITEKEYS-1

      'is this key being pressed?
      if(x < (whitekey_pos[i] & $FFFF))

        'if this key isn't already playing...
        if(i <> mouse_mkey_playing)
          snd.PlaySoundFM(CHANNEL_MKEY_MOUSE, snd#SHAPE_SQUARE, whitekey_notes[i], snd#DURATION_INFINITE)
          mouse_mkey_playing := i

        'if this key if being pressed, return regardless
        'of whether it was already playing or not
        return

      'end if "is this key being pressed?"

'///////////////////////////////////////////////////////////////////////

' color can be COLOR_DEFAULT for key's default color
' ie. white for white keys, and black for black keys
PUB DrawKey(color, key_to_draw)

  if(key_to_draw < MK_NUM_WHITEKEYS) 'White key

    if(color == COLOR_DEFAULT)
      gr.color(COLOR_WHITE)
    else
      gr.color(color)

    gr.box((whitekey_pos[key_to_draw] >> 16)+1, CONSTANT(MK_BOTTOM+1), CONSTANT(MK_WHITEKEY_WIDTH-1), CONSTANT(MK_HEIGHT-2))
    gr.color(COLOR_BLACK)
    gr.plot((whitekey_pos[key_to_draw] >> 16)+1, CONSTANT(MK_BOTTOM+1))
    gr.plot((whitekey_pos[key_to_draw] & $FFFF)-1, CONSTANT(MK_BOTTOM+1))
    if(key_to_draw < MK_NUM_WHITEKEYS-1)
      DrawBlackKey(COLOR_DEFAULT, LOOKUPZ(key_to_draw: 0,0,1,2,2,3,4,5,5,6,7,7,8,9))
      if(LOOKDOWN(key_to_draw: 1,4,5,8,11,12) > 0)
        DrawBlackKey(COLOR_DEFAULT, LOOKUP(key_to_draw: 1,0,0,3,4,0,0,6,0,0,8,9))

  else 'Black key

    DrawBlackKey(color, key_to_draw-MK_NUM_WHITEKEYS)

'///////////////////////////////////////////////////////////////////////

PUB DrawBlackKey(color, key_to_draw)

  if(color == COLOR_DEFAULT)
    gr.color(COLOR_BLACK)
    gr.box(blackkey_pos[key_to_draw] >> 16, MK_BLACKKEY_BOTTOM, MK_BLACKKEY_WIDTH, MK_BLACKKEY_HEIGHT)
  else
    gr.color(color)
    gr.box((blackkey_pos[key_to_draw] >> 16)+1, CONSTANT(MK_BLACKKEY_BOTTOM+1), CONSTANT(MK_BLACKKEY_WIDTH-2), CONSTANT(MK_BLACKKEY_HEIGHT-1))

'///////////////////////////////////////////////////////////////////////

PUB DrawHydraButton(color)
    gr.color(color)
    gr.box(CONSTANT(HYDRA_BUTTON_LEFT+1), CONSTANT(HYDRA_BUTTON_BOTTOM+1), CONSTANT(HYDRA_BUTTON_RIGHT-HYDRA_BUTTON_LEFT-1), CONSTANT(HYDRA_BUTTON_TOP-HYDRA_BUTTON_BOTTOM-1))
    gr.color(COLOR_WHITE)
    gr.text(CONSTANT(SCREEN_WIDTH/2), CONSTANT(SCREEN_HEIGHT-2), @hydra_text)

'///////////////////////////////////////////////////////////////////////
' DATA /////////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

DAT

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

pointer_pix
                                                byte 1, 8, 0, 7
                                                word %%20000000
                                                word %%22000000
                                                word %%23200000
                                                word %%23320000
                                                word %%23332000
                                                word %%23222200
                                                word %%22000000
                                                word %%20000000

'music key frequency lookup tables
key_notes
whitekey_notes
                        word snd#NOTE_C3
                        word snd#NOTE_D3
                        word snd#NOTE_E3
                        word snd#NOTE_F3
                        word snd#NOTE_G3
                        word snd#NOTE_A3
                        word snd#NOTE_B3
                        word snd#NOTE_C4
                        word snd#NOTE_D4
                        word snd#NOTE_E4
                        word snd#NOTE_F4
                        word snd#NOTE_G4
                        word snd#NOTE_A4
                        word snd#NOTE_B4
                        word snd#NOTE_C5
blackkey_notes
                        word snd#NOTE_Cs3
                        word snd#NOTE_Ds3
                        word snd#NOTE_Fs3
                        word snd#NOTE_Gs3
                        word snd#NOTE_As3
                        word snd#NOTE_Cs4
                        word snd#NOTE_Ds4
                        word snd#NOTE_Fs4
                        word snd#NOTE_Gs4
                        word snd#NOTE_As4
                        word 0            'padding

'Table to lookup the PC keyboard key assigned to a musical keyboard key
mkey_keyboard_map
                        byte key#KB_TAB       'White Key 0
                        byte "q"              'White Key 1
                        byte "w"              'White Key 2
                        byte "e"              'White Key 3
                        byte "r"              'White Key 4
                        byte "t"              'White Key 5
                        byte "y"              'White Key 6
                        byte "u"              'White Key 7
                        byte "i"              'White Key 8
                        byte "o"              'White Key 9
                        byte "p"              'White Key 10
                        byte "["              'White Key 11
                        byte "]"              'White Key 12
                        byte key#KB_ENTER     'White Key 13
                        byte key#KB_DEL       'White Key 14
                        byte "1"              'Black Key 0
                        byte "2"              'Black Key 1
                        byte "4"              'Black Key 2
                        byte "5"              'Black Key 3
                        byte "6"              'Black Key 4
                        byte "8"              'Black Key 5
                        byte "9"              'Black Key 6
                        byte "-"              'Black Key 7
                        byte "="              'Black Key 8
                        byte key#KB_BACKSPACE 'Black Key 9

hydra_text              byte "Hydra Sound Demo",0
'help_sweep_text         byte "Sweep-",0
help_sweep_text         byte "F1-F5: Play Sweep",0
help_esc_text           byte "Esc: Stop Sweep",0
'help_caps_text          byte "Caps Lock:Hold still",0
'help_white_text         byte "QWERTY Row:Play white keys",0
'help_black_text         byte "Number Row:Play black keys",0