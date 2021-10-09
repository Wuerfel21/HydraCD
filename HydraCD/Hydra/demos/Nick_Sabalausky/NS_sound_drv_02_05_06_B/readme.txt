NS_sound_demo_02_05_06_B
=========================

Package Contents
-----------------
3 files:
NS_sound_demo_021.spin (Top File):
   A demonstration of the NS_sound_drv sound driver. Generates
   a tone in various shapes and durations, with or without
   frequency sweep.  See below for keys.

NS_sound_drv_021.spin:
   My sound driver.

readme.txt:
   This readme file.


Detailed Change Log For NS_sound_drv Sound Driver
--------------------------------------------------
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
- Multiple Channels
- Adjustable Volume
- Selectable One-shot vs. Repeating
- Envelopes
- Frequency Sweep
- Configurable Audio Output Pin
- Configurable Number of Taps For White Noise
- PCM

Demo Keys
----------
1: Play a continuous Sine Wave
2: Play a continuous Square Wave
3: Play a continuous Triangle Wave
4: Play a continuous Noise Function
CTRL-num: Play for 2/5 of a second
ALT-num:  Play for 2 seconds
Enter:    Toggle sweep
Esc/Space Bar: Stop

Note: The demo has no video output, so make sure you either hook up 
      the Hydra's audio to a stereo or speaker, or feed your TV
      a valid video signal from a VCR/DVD/game system/etc.
      Otherwise, your TV might not play the audio.

Sound Driver API
-----------------
start: Starts the sound driver on a new cog.
stop:  Stops the sound driver. Frees a cog.

PlaySound(shape, freq, duration):
              Starts playing a sound. If a sound is already playing, then
              the old sound stops and the new sound is played.
    shape:    The desired shape of the sound. Can be any of the
              following contants: SHAPE_SINE, SHAPE_SQUARE,
              SHAPE_TRIANGLE, SHAPE_NOISE.
    freq:     The desired sound frequncy.
    duration: The amount of time (in 1/SAMPLE_RATE of a second) to play
              the sound. Or use DURATION_INFINITE for an infinite duration.

StopSound: Stops playing a tone.

SetFreq(freq): Changes the frequency of the playing sound. If called
               repetedly, it can be used to create a frequency sweep.

NOTE: There is no bounds-checking on the parameters, so if you set an
invalid value (such as setting pending_shape to something other than
the SHAPE_* constants) then the behavior is undefined.
