{///////////////////////////////////////////////////////////////////////

Sound Demo
AUTHOR: Nick Sabalausky
LAST MODIFIED: 2.5.06
VERSION 2.0

Demonstration of NS_sound_drv.

Generates a tone in various shapes, with or without frequency sweep.

Keys:
  Space Bar: Play / Stop
  Enter: Toggles sweep
  1: Sine wave
  2: Square wave
  3: Triangle wave
  4: Noise

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

'///////////////////////////////////////////////////////////////////////
' VARIABLES ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
VAR

  long freq, freq_delta
  long shape

  long is_playing, is_sweep_on
  long is_shape_changed
  long key_pressed

'///////////////////////////////////////////////////////////////////////
' OBJECTS //////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

  snd : "NS_sound_drv_020.spin"   'Sound driver
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

  snd.PlaySound(shape, freq)
  is_playing := true
  is_sweep_on := true
  is_shape_changed := false

  repeat

    'Handle input
    key_pressed := key.key
    case key_pressed

      'Play/Stop
      KB_SPACE:
        if(is_playing)
          snd.StopSound
          is_playing := false
        else
          snd.PlaySound(shape, freq)
          is_playing := true

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

    'Activate new shape (if changed)
    if(is_shape_changed and is_playing)
      snd.PlaySound(shape, freq)
      is_shape_changed := false

    'Perform sweep
    if(is_playing and is_sweep_on)
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
