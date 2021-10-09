NS_sound_02_13_06
==================

Package Contents
-----------------
9 files:

NS_sound_demo_040.spin (Top File):
   A demonstration of the NS_sound_drv sound driver.
   Play musical notes, sweeping tones, and a PCM sample
   with the keyboard and mouse. Now includes tv output!

NS_sound_drv_040.spin:
   My sound driver.

NS_hydra_sound_010.raw:
   An 11KHz 8-bit unsigned RAW audio file of a voice saying "Hydra".

NS_hydra_sound_010.spin:
   NS_hydra_sound_010.raw converted into a spin source file
   (See below for important details).

NS_keyboard_drv_keyconstants_010.spin:
   A modified version of keyboard_iso_010.spin that
   adds KB_* constants for all control keys.

NS_mouse_drv_events_010.spin:
   A modified version of mouse_iso_010.spin that adds an
   event polling system to detect when a mouse button is
   pressed or released (instead of just whether it's up or down).

xgsbmp.exe:
   Colin Philips's xgsbmp tool. Used to convert raw audio file
   into a spin source file (See below for important details).

xgsbmp_readme.txt:
   The readme file for Colin Philips's xgsbmp tool.

readme.txt:
   This readme file.


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


Detailed Change Log For NS_sound_drv Sound Driver
--------------------------------------------------
v4.0 (2.13.06)
- Added constants for musical note frequencies
- Added 8-bit unsigned 11KHz PCM playback via PlaySoundPCM()
- Renamed PlaySound() to PlaySoundFM()
- Improved mixer (Replaced strange-sounding and
  computationaly-expensive "sum_of_samples/active_channels"
  method with just plain "sum_of_samples")

v3.0 (2.9.06)
- Added Sawtooth Wave
- Configurable Audio Output Pin
- Multiple Channels (4 channels max)
- Changed samples from 32-bit to 16-bit

v2.1 (2.5.06)
- Fixed bug: Couldn't get full amplitude range from sine wave without introducing noise
- Added setting for sound duration
- Changed the API documentation to inline-style. Use the PIDE's "Documentation" view to view it.

v2.0 (2.5.06):
- Added PlaySound() and StopSound()
- Can now choose between waveform shapes: Sine, Square, Triangle, and Noise

v1.0 (2.2.06):
- Initial release
- Sine wave output
- Sweeping possible via repeated calls to SetFreq()


To do
------
- Provide an "any available channel" setting for PlaySound()
- Provide an Asm API
- Atomic SPIN-ASM communication
- More options for PCM
- Adjustable Volume
- Volume Envelope
- Selectable One-shot vs. Repeating
- Configurable Noise Function
- Frequency Envelope
- "Sound Done" Notification
- Space and speed optimizations


Notes on playing your own PCM samples
--------------------------------------
The standard process involves three steps:

1. Export your audio file to an unsigned 8-bit 11KHz RAW file.

You should be able to do this with just about any good sound
editing software. I recommend Audacity. It's free, it's powerful,
it's on any platform you could possibly want, and you can get it
here: http://audacity.sourceforge.net.

2. Use Colin Philips's xgsbmp tool to convert the RAW file
into a spin source file.

Use the command-line:
xgsbmp audiofile.raw audiofile.spin -op:copy -hydra

3. Minor manual touch-up to the spin source file.

The file will already have a label at the start of the data,
and a getter function to obtain that label's address. You
will need to add an additional label denoting the *end* of
the data, and provide a getter for that. See NS_hydra_sound_010.spin
for an example:

  PUB ns_hydra_sound
  RETURN @_ns_hydra_sound

  PUB ns_hydra_sound_end
  RETURN @_ns_hydra_sound_end

  DAT
  ' Data Type: RAW Data
  ' Size: 6946 Bytes
  ' Range: 0 -> 1B22
  _ns_hydra_sound
         byte    $7f, 'etc...
         'etc...
         byte    $7f, $7f, $7f, $7f '......
  _ns_hydra_sound_end


Sound Driver API
-----------------
NOTE: PlaySound() has been renamed to PlaySoundFM()!

start(pin): Starts the sound driver on a new cog.
       pin: The PChip I/O pin to send audio to (always 7 on the Hydra)

stop: Stops the sound driver. Frees a cog.

PlaySoundFM(channel, shape, freq, duration):
    Starts playing a frequency modulation sound. If a sound is already
    playing, then the old sound stops and the new sound is played.

    channel:  The channel on which to play the sound (0-4)
    shape:    The desired shape of the sound. Can be any of the
              following contants: SHAPE_SINE, SHAPE_SAWTOOTH,
              SHAPE_SQUARE, SHAPE_TRIANGLE, SHAPE_NOISE.
              Do NOT send a SHAPE_PCM_* constant, use PlaySoundPCM() instead.
    freq:     The desired sound frequncy. Can be a number or a NOTE_* constant.
    duration: The amount of time (in 1/SAMPLE_RATE of a second) to play
              the sound. Or use DURATION_INFINITE for an infinite duration.

PlaySoundPCM(channel, pcm_start, pcm_end)
    Plays an unsigned 8-bit 11KHz PCM sound once. If a sound is already
    playing, then the old sound stops and the new sound is played.

    channel:   The channel on which to play the sound (0-4)
    pcm_start: The address of the PCM buffer
    pcm_end:   The address of the end of the PCM buffer

StopSound(channel): Stops playing a sound.
           channel: The channel to stop.

SetFreq(channel, freq):
    Changes the frequency of the playing sound. If called
    repetedly, it can be used to create a frequency sweep.
    
    channel:  The channel to set the frequency of.

NOTE: There is no bounds-checking on the parameters, so if you set an
invalid value (such as setting pending_shape to something other than
the SHAPE_* constants) then the behavior is undefined.


Communication Protocol between SPIN and ASM
--------------------------------------------
The communication is done through the pending_* variables.

The pending_* variables are normally set to NOTHING_PENDING ($0). To change
a setting, the desired new value is written to the appropriate pending_*
variable. The ASM driver polls these variables. When it encounters a
value other than NOTHING_PENDING, it will activate the new setting and
write NOTHING_PENDING back to the variable to signal it has received the
new value.

(NOTE: There will be a slight change to this protocol in a later version.)
