NS_sound_07_09_06
==================

Package Contents
-----------------
10 files:

NS_sound_demo_051.spin (Top File):
   A demonstration of the NS_sound_drv sound driver.
   Play musical notes, sweeping tones, and a PCM sample
   with the keyboard and mouse.

NS_sound_drv_051_22khz_16bit.spin:
   The 22KHz 16-bit version of my sound driver. Supports 6 channels.

NS_sound_drv_051_11khz_16bit.spin:
   The 11KHz 16-bit version of my sound driver. Supports 9 channels.

NS_hydra_sound_011.raw:
   An 11KHz 8-bit *signed* RAW audio file of a voice saying "Hydra".

NS_hydra_sound_011.spin:
   NS_hydra_sound_011.raw converted into a spin source file
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
    CTRL-(F1-F5): Play a High Tone for 2/5 of a second (Channel 4)
    ALT-(F1-F5):  Play a Low Tone for 2 seconds on (Channel 5)
      F1: Sine Wave
      F2: Sawtooth Wave
      F3: Square Wave
      F4: Triangle Wave
      F5: Noise Function
    Caps Lock:    Toggle Sweep on Continuous Tone (Channel 0)
    Esc:          Stop Continuous Tone (Channel 0)


NOTE: The driver expects the system clock to be set at 80MHz

Detailed Change Log
--------------------
v5.1 (7.9.06)
- Added SetVolume()
- Eliminated a "click" that was heard when the driver started up
- Minor cleanups
  - Renamed sample_counter to sound_clock
  - Removed unused channel variable volume_delta
  - Added NO_ENVELOPE constant
  - Added VOLUME_MIN and VOLUME_MAX to both 11KHz and 22KHz versions
    (It was only in the 22KHz version before)
  - Cleaned up some of the comments and fixed a few inaccuracies

v5.0 (4.6.06)
- Added volume parameter
- Changed to use signed samples instead of unsigned
- Changed inline documentation to block-style for easier maintainability
- Added amplitude envelopes
- Split into alternate versions: 11KHz and 22KHz
- Increased maximum number of channels to 6 for 22KHz version, and 9 for 11KHz version
- "Atomic" SPIN-ASM communication

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
- Make SPIN API easier and more powerful
- Provide an Asm API
- Add MIDI-playback (will require another COG)

Wish List
----------
- Provide an "any available channel" setting for PlaySound()
- More options for PCM
- Selectable One-shot vs. Repeating
- Configurable Noise Function
- Frequency Envelope
- "Sound Done" Notification
- Space and speed optimizations

Sound API
----------
See "Documentation" view in Propeller IDE.

NOTE: For now, there is no bounds-checking on parameters, so if you
set an invalid value (such as setting pending_shape to something other
than the SHAPE_* constants) then the behavior is undefined.

Caveats
--------
- Do NOT use a volume of 0 if you want "minimum" volume. The range for
  volume is 1-255 (inclusive), so if you want a minimum volume, use 1
  (ie. VOLUME_MINIMUM). A volume of 0 (ie. NOTHING_PENDING) tells the
  driver "don't change the volume for this channel". The same is also
  true for all parameters except "channel" (ie. "frequency",
  "envelope", "shape", etc.).
- Do NOT use a duration of less than 8, or else the envelope functionality
  will cause improper behavior.
- Do NOT use INFINITE_DURATION by itself as the duration as you did
  with version 4.0 of the sound driver. You MUST "or" it with a duration
  of AT LEAST 8 or else ReleaseSound will not properly end the sound.
- Do NOT pass SHAPE_PCM_8BIT_11KHZ to PlaySoundFM. Use PlaySoundPCM instead.

NOTE: These caveats will be automatically taken care of by either the driver
      or the API in the next version so you won't have to worry about them.
      But for now, you will will need to avoid these pitfalls yourself.

Notes on playing your own PCM samples
--------------------------------------
The standard process involves three steps:

1. Export your audio file to a *signed* 8-bit 11KHz RAW file.

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

Explanation of Envelopes and Duration
--------------------------------------
The duration is specified in 11KHz or 22KHz "ticks" (depending on which
version of the sound driver you're using). So, use a duration of
SAMPLE_RATE to play for one second, 2*SAMPLE_RATE for two seconds,
SAMPLE_RATE/2 for a half-second, etc.

To make a sound play for an infinite duration, you must "or" the
duration with DURATION_INFINITE (which sets bit 31 to 1). You still
need to specify an amount of time for the duration because the sound
driver needs to know how long the amplitude envelope (explained below)
should take. For example, use INFINITE_DURATION | SAMPLE_RATE to play
a never-ending sound using an envelope length of one second.

The amplitude (ie. volume), envelope is a 32-bit value made up of eight
4-bit nybbles, with each nybble representing one of eight "segments"
of the envelope. Each segment plays for 1/8th of the sound's total
duration. Each segment specifies a percentage of the sound's desired
volume, with $0 representing 0%, and $F representing 100%. For instance,
if the sound is played at a volume of 200, then a segment of $0 means
"no volume", $8 means "volume 100", and $F means "volume 200". The eight
envelope segments are specified in reverse-order. The first segment to
be played (segment 0) is the least significant nybble and the final
segment (segment 7) is the most significant nybble. For example,
$1346_ACEF starts at full volume and ends at near-silence. An envelope
of $FFFF_FFFF is effectively no envelope.

Sounds with an infinite duration may also use envelopes. In this case,
the "attack" and "decay" (ie. the first few segments) will play, and
then the sound will remain indefinitely at the "sustain" segment
(segment 3 by default, but can be changed by adjusting the
AMP_ENV_SUSTAIN_SEG constant anywhere from 1 to 6 (0 and 7 are untested)).
When ReleaseSound is called, the "release" (ie. the last few segments)
will play for the rest of the specified envelope duration and then stop.

PCM sounds may also use an envelope, although for now you will have to
modify PlaySoundPCM to do this. The next version of the driver will have
this modification built-in.

Communication Protocol between SPIN and ASM
--------------------------------------------
An Asm API will be provided in the next version of the sound driver, but
for now, if you wish to use the driver from Asm code, you must understand
the communication protocol it uses:

The communication is done through the pending_* variables.

The pending_* variables are normally set to NOTHING_PENDING ($0). To change
a setting, write the desired new values to the appropriate pending_*
variables. Then set bit 31 of pending_shape* to 1. The ASM driver polls the
pending_shape* variables. When it sees a 1 in bit 31, it will poll the rest
of the pending_* variables for that particular channel. When it encounters
a value other than NOTHING_PENDING in any of those variables (including
bits 30..0 of pending_shape*), it will activate the new setting, clear bit 31
of pending_shape*, and write NOTHING_PENDING back to the variable to signal
it has received the new value.

//////////////////////////////////////////////////////////////////////
Object "NS_sound_drv_051_22khz_16bit" Interface:

PUB  start(pin) : okay
PUB  stop
PUB  PlaySoundFM(arg_channel, arg_shape, arg_freq, arg_duration, arg_volume, arg_amp_env)
PUB  PlaySoundPCM(arg_channel, arg_pcm_start, arg_pcm_end, arg_volume)
PUB  StopSound(arg_channel)
PUB  ReleaseSound(arg_channel)
PUB  SetFreq(arg_channel, arg_freq)
PUB  SetVolume(arg_channel, arg_volume)

Program:     511 Longs
Variable:     45 Longs

______________________
PUB  start(pin) : okay

Starts the sound driver on a new cog.

    pin:      The PChip I/O pin to send audio to (always 7 on the Hydra)
    returns:  false if no cog available

_________
PUB  stop

Stops the sound driver. Frees a cog.

_________________________________________________________________________________________
PUB  PlaySoundFM(arg_channel, arg_shape, arg_freq, arg_duration, arg_volume, arg_amp_env)

Starts playing a frequency modulation sound. If a sound is already
playing, then the old sound stops and the new sound is played.

   arg_channel:   The channel on which to play the sound (0-5)
   arg_shape:     The desired shape of the sound. Use any of the
                  following constants: SHAPE_SINE, SHAPE_SAWTOOTH,
                  SHAPE_SQUARE, SHAPE_TRIANGLE, SHAPE_NOISE.
                  Do NOT send a SHAPE_PCM_* constant, use PlaySoundPCM() instead.
   arg_freq:      The desired sound frequncy. Can be a number or a NOTE_* constant.
                  A value of 0 leaves the frequency unchanged.
   arg_duration:  Either a 31-bit duration to play sound for a specific length
                  of time, or (DURATION_INFINITE | "31-bit duration of amplitude
                  envelope") to play until StopSound, ReleaseSound or another call
                  to PlaySound is called. See "Explanation of Envelopes and
                  Duration" for important details.
   arg_volume:    The desired volume (1-255). A value of 0 leaves the volume unchanged.
   arg_amp_env:   The amplitude envelope, specified as eight 4-bit nybbles
                  from $0 (0% of arg_volume, no sound) to $F (100% of arg_volume,
                  full volume), to be applied least significant nybble first and
                  most significant nybble last. Or, use NO_ENVELOPE to not use an envelope.
                  See "Explanation of Envelopes and Duration" for important details.

______________________________________________________________________
PUB  PlaySoundPCM(arg_channel, arg_pcm_start, arg_pcm_end, arg_volume)

Plays a signed 8-bit 11KHz PCM sound once. If a sound is already
playing, then the old sound stops and the new sound is played.

   arg_channel:   The channel on which to play the sound (0-8)
   arg_pcm_start: The address of the PCM buffer
   arg_pcm_end:   The address of the end of the PCM buffer
   arg_volume:    The desired volume (1-255)
   arg_amp_env:   The amplitude envelope, specified as eight 4-bit nybbles
                  from $0 (0% of arg_volume, no sound) to $F (100% of arg_volume,
                  full volume), to be applied least significant nybble first and
                  most significant nybble last. Or, use NO_ENVELOPE to not use an envelope.
                  See "Explanation of Envelopes and Duration" for important details.

___________________________
PUB  StopSound(arg_channel)

Stops playing a sound.

   arg_channel:  The channel to stop.

______________________________
PUB  ReleaseSound(arg_channel)

"Releases" an infinite duration sound. Ie, starts the release portion
of the sound's amplitude envelope.

   arg_channel:  The channel to "release".

___________________________________
PUB  SetFreq(arg_channel, arg_freq)

Changes the frequency of the playing sound. If called
repetedly, it can be used to create a frequency sweep.

   arg_channel:  The channel to set the frequency of.
   arg_freq:     The desired sound frequncy. Can be a number or a NOTE_* constant.
                 A value of 0 leaves the frequency unchanged.

_______________________________________
PUB  SetVolume(arg_channel, arg_volume)

Changes the volume of the playing sound. If called
repetedly, it can be used to manually create an envelope.

   arg_channel:  The channel to set the volume of.
   arg_volume:   The desired volume (1-255). A value of 0 leaves the volume unchanged.

