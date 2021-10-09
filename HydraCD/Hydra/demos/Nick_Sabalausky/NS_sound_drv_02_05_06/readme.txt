NS_sound_demo_02_05_06
=======================

Package Contents
-----------------
3 files:
NS_sound_demo_020.spin (Top File):
   A demonstration of the NS_sound_drv sound driver. Generates a
   tone in various shapes, with or without frequency sweep.
   See below for keys.

NS_sound_drv_020.spin:
   My sound driver.

readme.txt:
   This readme file.


Detailed Change Log For NS_sound_drv Sound Driver
--------------------------------------------------
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
Space Bar: Play / Stop
Enter: Toggles sweep
1: Sine wave
2: Square wave
3: Triangle wave
4: Noise

Note: The demo has no video output, so make sure you either hook up 
      the Hydra's audio to a stereo or speaker, or feed your TV
      a valid video signal from a VCR/DVD/game system/etc.
      Otherwise, your TV might not play the audio.

Sound Driver API
-----------------
start: Starts the sound driver on a new cog.
stop:  Stops the sound driver. Frees a cog.

PlaySound(shape, freq): Starts playing a tone. If a tone is already playing,
                        then the old tone stops and the new tone is played.
    shape: The desired shape of the tone. Can be any of the
           following contants: SHAPE_SINE, SHAPE_SQUARE,
           SHAPE_TRIANGLE, SHAPE_NOISE.
    freq:  The desired sound frequncy.

StopSound: Stops playing a tone.

SetFreq(freq): Changes the frequency of the playing sound. If called
               repetedly, it can be used to create a frequency sweep.

NOTE: There is no bounds-checking on the parameters, so if you set an
invalid value (such as setting pending_shape to something other than
the SHAPE_* constants) then the behavior is undefined.
