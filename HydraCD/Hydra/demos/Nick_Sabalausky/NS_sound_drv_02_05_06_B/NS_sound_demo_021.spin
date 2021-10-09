{///////////////////////////////////////////////////////////////////////

Sound Demo
AUTHOR: Nick Sabalausky
LAST MODIFIED: 2.5.06
VERSION 2.1

Demonstration of NS_sound_drv.

Generates a tone in various shapes and durations, with
or without frequency sweep.

Keys:
  1: Play a continuous Sine Wave
  2: Play a continuous Square Wave
  3: Play a continuous Triangle Wave
  4: Play a continuous Noise Function
  CTRL-num: Play for 2/5 of a second
  ALT-num:  Play for 2 seconds
  Enter:    Toggle sweep
  Esc/Space Bar: Stop

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

  snd : "NS_sound_drv_021.spin"   'Sound driver
  key : "keyboard_iso_010.spin"   'Keyboard driver

'///////////////////////////////////////////////////////////////////////
' FUNCTIONS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

'// PUB start //////////////////////////////////////////////////////////
PUB start

  'start keyboard on pingroup 
  key.start(3)

  'start sound driver
  snd.start

  freq := FREQ_INIT
  freq_delta := FREQ_DELTA_INIT
  shape := SHAPE_INIT

  snd.PlaySound(shape, freq, snd#DURATION_INFINITE)  'Three seconds

  is_stopped := false
  is_sweep_on := true
  is_shape_changed := false

  repeat

    'Handle input
    key_pressed := key.key
    case key_pressed & $00FF

      'Stop
      KB_SPACE, KB_ESC:
        snd.StopSound
        is_stopped := true

      'Sweep on/off
      KB_ENTER:
        not is_sweep_on

      'Set shape
      "1":
        shape := snd#SHAPE_SINE
        is_shape_changed := true
      "2":
        shape := snd#SHAPE_SQUARE
        is_shape_changed := true
      "3":
        shape := snd#SHAPE_TRIANGLE
        is_shape_changed := true
      "4":
        shape := snd#SHAPE_NOISE
        is_shape_changed := true

    'end of case key_pressed

    'Activate new shape (if one was set)
    if(is_shape_changed)
      is_shape_changed := false

      if(key_pressed & KB_ALT_MOD)
        snd.PlaySound(shape, freq, CONSTANT( snd#SAMPLE_RATE * 2 ))  'Play for two seconds
        is_stopped := false
      elseif(key_pressed & KB_CONTROL_MOD)
        snd.PlaySound(shape, freq, CONSTANT( Round(Float(snd#SAMPLE_RATE) * 0.4)) )  'Play for two fifths of a second
        is_stopped := false
      else
        snd.PlaySound(shape, freq, snd#DURATION_INFINITE)  'Play for an infinite duration
        is_stopped := false
    'end if(is_shape_changed)

    'Perform sweep
    if(not is_stopped and is_sweep_on)
      snd.SetFreq(freq)

      freq += freq_delta
      if((freq => FREQ_MAX) or (freq =< FREQ_MIN))
        -freq_delta

    'Delay before changing frequency again
    WAITCNT(CNT + CONSTANT(80_000_000/100))

'///////////////////////////////////////////////////////////////////////
' DATA /////////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

DAT
