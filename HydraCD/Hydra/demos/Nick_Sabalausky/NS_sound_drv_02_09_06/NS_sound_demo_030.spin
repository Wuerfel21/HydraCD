{///////////////////////////////////////////////////////////////////////

Sound Demo
AUTHOR: Nick Sabalausky
LAST MODIFIED: 2.9.06
VERSION 3.0

Demonstration of NS_sound_drv.

Generates a tone in various shapes and durations, with
or without frequency sweep.

Keys:
  1: Sine Wave
  2: Sawtooth Wave
  3: Square Wave
  4: Triangle Wave
  5: Noise Function (Note: This tends to drown out the other waves)
  num:      Play a Sweeping Continuous Tone on Channel 0
  CTRL-num: Play a High Tone for 2/5 of a second on Channel 1
  ALT-num:  Play a Low Tone for 4 seconds on Channel 2
  Enter:    Toggle Sweep on Channel 0
  Esc/Space Bar: Stop Channel 0

Note: This has no video output, so make sure you either hook up 
      the Hydra's audio to a stereo or speaker, or feed your TV
      a valid video signal from a VCR/DVD/game system/etc.
      Otherwise, your TV might not play the audio.

///////////////////////////////////////////////////////////////////////}

'///////////////////////////////////////////////////////////////////////
' CONSTANTS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
CON
  _clkmode = xtal2 + pll8x            ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000        ' set frequency to 10 MHZ plus some error for xtals that are not exact add 1000-5000 usually works
  _stack = (128) >> 2                 ' accomodate stack   

  FREQ_INIT = 500
  FREQ_DELTA_INIT = -1
  FREQ_MAX = 800
  FREQ_MIN = 200

  SHAPE_INIT = snd#SHAPE_SINE

  ' control keys
  KB_LEFT_ARROW  = $C0
  KB_RIGHT_ARROW = $C1
  KB_UP_ARROW    = $C2
  KB_DOWN_ARROW  = $C3
  KB_ESC         = $CB
  KB_SPACE       = $20
  KB_ENTER       = $0D

  KB_LSHIFT      = $F0
  KB_RSHIFT      = $F1
  KB_LCONTROL    = $F2
  KB_RCONTROL    = $F3
  KB_LALT        = $F4
  KB_RALT        = $F5
  KB_LWIN        = $F6
  KB_RWIN        = $F7

  ' key modifiers
  KB_SHIFT_MOD   = $100
  KB_CONTROL_MOD = $200
  KB_ALT_MOD     = $400
  KB_WIN_MOD     = $800

'///////////////////////////////////////////////////////////////////////
' VARIABLES ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
VAR

  long freq, freq_delta
  long shape

  long is_stopped
  long is_sweep_on
  long is_shape_changed
  long key_pressed

'///////////////////////////////////////////////////////////////////////
' OBJECTS //////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

  snd : "NS_sound_drv_030.spin"   'Sound driver
  key : "keyboard_iso_010.spin"   'Keyboard driver

'///////////////////////////////////////////////////////////////////////
' FUNCTIONS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

'// PUB start //////////////////////////////////////////////////////////
PUB start

  'start keyboard on pingroup 
  key.start(3)

  'start sound driver
  snd.start(7)

  freq := FREQ_INIT
  freq_delta := FREQ_DELTA_INIT
  shape := SHAPE_INIT

  snd.PlaySound(3, shape, freq, snd#DURATION_INFINITE)

  is_stopped := false
  is_sweep_on := true
  is_shape_changed := false

  repeat

    'Handle input
    key_pressed := key.key
    case key_pressed & $00FF

      'Stop
      KB_SPACE, KB_ESC:
        snd.StopSound(3)
        is_stopped := true

      'Sweep on/off
      KB_ENTER:
        not is_sweep_on

      'Set shape
      "1":
        shape := snd#SHAPE_SINE
        is_shape_changed := true
      "2":
        shape := snd#SHAPE_SAWTOOTH
        is_shape_changed := true
      "3":
        shape := snd#SHAPE_SQUARE
        is_shape_changed := true
      "4":
        shape := snd#SHAPE_TRIANGLE
        is_shape_changed := true
      "5":
        shape := snd#SHAPE_NOISE
        is_shape_changed := true

    'end of case key_pressed

    'Activate new shape (if one was set)
    if(is_shape_changed)
      is_shape_changed := false

      if(key_pressed & KB_CONTROL_MOD)
        snd.PlaySound(1, shape, FREQ_MAX, CONSTANT( Round(Float(snd#SAMPLE_RATE) * 0.4)) )  'Play for two fifths of a second
        is_stopped := false
      elseif(key_pressed & KB_ALT_MOD)
        snd.PlaySound(2, shape, FREQ_INIT, CONSTANT( snd#SAMPLE_RATE * 4 ))  'Play for four seconds
        is_stopped := false
      else
        snd.PlaySound(3, shape, freq, snd#DURATION_INFINITE)  'Play for an infinite duration
        is_stopped := false
    'end if(is_shape_changed)

    'Perform sweep
    if(not is_stopped and is_sweep_on)
      snd.SetFreq(3, freq)

      freq += freq_delta
      if((freq => FREQ_MAX) or (freq =< FREQ_MIN))
        -freq_delta

    'Delay before changing frequency again
    WAITCNT(CNT + CONSTANT(80_000_000/100))

'///////////////////////////////////////////////////////////////////////
' DATA /////////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

DAT
