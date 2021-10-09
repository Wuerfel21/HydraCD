NS_sound_demo_02_09_06
=========================

Package Contents
-----------------
3 files:
NS_sound_demo_030.spin (Top File):
   A demonstration of the NS_sound_drv sound driver.
   Generates tones in various shapes and durations,
   with or without frequency sweep. See below for keys.

NS_sound_drv_030.spin:
   My sound driver.

readme.txt:
   This readme file.


Demo Keys
----------
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

Note: The demo has no video output, so make sure you either hook up 
      the Hydra's audio to a stereo or speaker, or feed your TV
      a valid video signal from a VCR/DVD/game system/etc.
      Otherwise, your TV might not play the audio.


Detailed Change Log For NS_sound_drv Sound Driver
--------------------------------------------------
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
- Allow "-1" for channel to mean "any available channel"
- Provide an Asm API
- Atomic SPIN-ASM communication
- PCM
- Clickable On-Screen Keyboard
- Adjustable Volume
- Volume Envelope
- Selectable One-shot vs. Repeating
- Configurable Noise Function
- Frequency Envelope
- "Sound Done" Notification


Sound Driver API
-----------------
start(pin): Starts the sound driver on a new cog.
       pin: The PChip I/O pin to send audio to (always 7 on the Hydra)

stop: Stops the sound driver. Frees a cog.

PlaySound(channel, shape, freq, duration):
              Starts playing a sound. If a sound is already playing, then
              the old sound stops and the new sound is played.
    channel:  The channel on which to play the sound (0-4)
    shape:    The desired shape of the sound. Can be any of the
              following contants: SHAPE_SINE, SHAPE_SAWTOOTH,
              SHAPE_SQUARE, SHAPE_TRIANGLE, SHAPE_NOISE.
    freq:     The desired sound frequncy.
    duration: The amount of time (in 1/SAMPLE_RATE of a second) to play
              the sound. Or use DURATION_INFINITE for an infinite duration.

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

(NOTE: There will be a slight change to this protocol in the next version.)
