{///////////////////////////////////////////////////////////////////////

Sound Driver
AUTHOR: Nick Sabalausky
LAST MODIFIED: 2.13.06
VERSION 4.0

start() and stop() code taken from Parallax's drivers
Sine/Cosine lookup function from Hydra Programmer's Manual

NOTE: This expects the system clock to be set at 80MHz

Detailed Change Log
--------------------
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

Sound API
----------
See "Documentation" view in Propeller IDE.

NOTE: There is no bounds-checking on parameters, so if you set an
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

///////////////////////////////////////////////////////////////////////}


'///////////////////////////////////////////////////////////////////////
' CONSTANTS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
CON

  'Approximately 22KHz. Do NOT change this value! The calculation of theta_delta
  'has an optimization (to avoid a division) that relies on this exact sample rate.
  SAMPLE_RATE = 21845

  #1, SHAPE_SILENT, SHAPE_SINE, SHAPE_SAWTOOTH, SHAPE_SQUARE, SHAPE_TRIANGLE, SHAPE_NOISE, SHAPE_PCM_8BIT_11KHZ
  DURATION_INFINITE = $FFFF_FFFF
  NOTHING_PENDING = $0

  'Channel Data Field Offsets
  #0, CHDAT_THETA, CHDAT_THETA_DELTA, CHDAT_THETA_CYCLED, CHDAT_SHAPE, CHDAT_STOP_TIME, CHDAT_LFSR, CHDAT_PCM_START, CHDAT_PCM_END, CHDAT_PCM_CURR, SIZE_OF_CHDAT
  SIZE_OF_PARAM_CHDAT = 5  'pending_shape, pending_freq, pending_duration, pending_pcm_start and pending_pcm_end

  'Musical note frequencies
  NOTE_C0  = 16
  NOTE_Cs0 = 17
  NOTE_Db0 = NOTE_Cs0
  NOTE_D0  = 18
  NOTE_Ds0 = 19
  NOTE_Eb0 = NOTE_Ds0
  NOTE_E0  = 21
  NOTE_F0  = 22
  NOTE_Fs0 = 23
  NOTE_Gb0 = NOTE_Fs0
  NOTE_G0  = 25
  NOTE_Gs0 = 26
  NOTE_Ab0 = NOTE_Gs0
  NOTE_A0  = 28
  NOTE_As0 = 29
  NOTE_Bb0 = NOTE_As0
  NOTE_B0  = 31

  NOTE_C1  = 33
  NOTE_Cs1 = 35
  NOTE_Db1 = NOTE_Cs1
  NOTE_D1  = 37
  NOTE_Ds1 = 39
  NOTE_Eb1 = NOTE_Ds1
  NOTE_E1  = 41
  NOTE_F1  = 44
  NOTE_Fs1 = 46
  NOTE_Gb1 = NOTE_Fs1
  NOTE_G1  = 49
  NOTE_Gs1 = 52
  NOTE_Ab1 = NOTE_Gs1
  NOTE_A1  = 55
  NOTE_As1 = 58
  NOTE_Bb1 = NOTE_As1
  NOTE_B1  = 62

  NOTE_C2  = 65
  NOTE_Cs2 = 69
  NOTE_Db2 = NOTE_Cs2
  NOTE_D2  = 73
  NOTE_Ds2 = 78
  NOTE_Eb2 = NOTE_Ds2
  NOTE_E2  = 82
  NOTE_F2  = 87
  NOTE_Fs2 = 93
  NOTE_Gb2 = NOTE_Fs2
  NOTE_G2  = 98
  NOTE_Gs2 = 104
  NOTE_Ab2 = NOTE_Gs2
  NOTE_A2  = 110
  NOTE_As2 = 117
  NOTE_Bb2 = NOTE_As2
  NOTE_B2  = 123

  NOTE_C3  = 131
  NOTE_Cs3 = 139
  NOTE_Db3 = NOTE_Cs3
  NOTE_D3  = 147
  NOTE_Ds3 = 156
  NOTE_Eb3 = NOTE_Ds3
  NOTE_E3  = 165
  NOTE_F3  = 175
  NOTE_Fs3 = 185
  NOTE_Gb3 = NOTE_Fs3
  NOTE_G3  = 196
  NOTE_Gs3 = 208
  NOTE_Ab3 = NOTE_Gs3
  NOTE_A3  = 220
  NOTE_As3 = 233
  NOTE_Bb3 = NOTE_As3
  NOTE_B3  = 247

  NOTE_C4  = 262      '--- Middle C ---
  NOTE_Cs4 = 277
  NOTE_Db4 = NOTE_Cs4
  NOTE_D4  = 294
  NOTE_Ds4 = 311
  NOTE_Eb4 = NOTE_Ds4
  NOTE_E4  = 330
  NOTE_F4  = 349
  NOTE_Fs4 = 370
  NOTE_Gb4 = NOTE_Fs4
  NOTE_G4  = 392
  NOTE_Gs4 = 415
  NOTE_Ab4 = NOTE_Gs4
  NOTE_A4  = 440
  NOTE_As4 = 466
  NOTE_Bb4 = NOTE_As4
  NOTE_B4  = 494

  NOTE_C5  = 523
  NOTE_Cs5 = 554
  NOTE_Db5 = NOTE_Cs5
  NOTE_D5  = 587
  NOTE_Ds5 = 622
  NOTE_Eb5 = NOTE_Ds5
  NOTE_E5  = 659
  NOTE_F5  = 698
  NOTE_Fs5 = 740
  NOTE_Gb5 = NOTE_Fs5
  NOTE_G5  = 784
  NOTE_Gs5 = 831
  NOTE_Ab5 = NOTE_Gs5
  NOTE_A5  = 880
  NOTE_As5 = 932
  NOTE_Bb5 = NOTE_As5
  NOTE_B5  = 988

  NOTE_C6  = 1047
  NOTE_Cs6 = 1109
  NOTE_Db6 = NOTE_Cs6
  NOTE_D6  = 1175
  NOTE_Ds6 = 1245
  NOTE_Eb6 = NOTE_Ds6
  NOTE_E6  = 1319
  NOTE_F6  = 1397
  NOTE_Fs6 = 1480
  NOTE_Gb6 = NOTE_Fs6
  NOTE_G6  = 1568
  NOTE_Gs6 = 1661
  NOTE_Ab6 = NOTE_Gs6
  NOTE_A6  = 1760
  NOTE_As6 = 1865
  NOTE_Bb6 = NOTE_As6
  NOTE_B6  = 1976

'///////////////////////////////////////////////////////////////////////
' VARIABLES ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
VAR
  long cogon, cog

  'Communication paramaters. See above for explanation of protocol.
  long audio_pin

  long pending_shape
  long pending_freq
  long pending_duration
  long pending_pcm_start
  long pending_pcm_end

  long pending_shape_ch1
  long pending_freq_ch1
  long pending_duration_ch1
  long pending_pcm_start_ch1
  long pending_pcm_end_ch1

  long pending_shape_ch2
  long pending_freq_ch2
  long pending_duration_ch2
  long pending_pcm_start_ch2
  long pending_pcm_end_ch2

  long pending_shape_ch3
  long pending_freq_ch3
  long pending_duration_ch3
  long pending_pcm_start_ch3
  long pending_pcm_end_ch3

'///////////////////////////////////////////////////////////////////////
' OBJECTS //////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

'///////////////////////////////////////////////////////////////////////
' FUNCTIONS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

'// PUB start //////////////////////////////////////////////////////////

PUB start(pin) : okay

'' Starts the sound driver on a new cog.
'' 
''     pin:      The PChip I/O pin to send audio to (always 7 on the Hydra)
''     returns:  false if no cog available

  audio_pin := pin

  stop
  okay := cogon := (cog := cognew(@entry,@audio_pin)) > 0


'///////////////////////////////////////////////////////////////////////

PUB stop

'' Stops the sound driver. Frees a cog.

  if cogon~
    cogstop(cog)

'///////////////////////////////////////////////////////////////////////

PUB PlaySoundFM(arg_channel, arg_shape, arg_freq, arg_duration) | offset

'' Starts playing a frequency modulation sound. If a sound is already
'' playing, then the old sound stops and the new sound is played.
''
''    channel:  The channel on which to play the sound (0-4)
''    shape:    The desired shape of the sound. Can be any of the
''              following contants: SHAPE_SINE, SHAPE_SAWTOOTH,
''              SHAPE_SQUARE, SHAPE_TRIANGLE, SHAPE_NOISE.
''              Do NOT send a SHAPE_PCM_* constant, use PlaySoundPCM() instead.
''    freq:     The desired sound frequncy. Can be a number or a NOTE_* constant.
''    duration: The amount of time (in 1/SAMPLE_RATE of a second) to play
''              the sound. Or use DURATION_INFINITE for an infinite duration.

  offset := arg_channel*SIZE_OF_PARAM_CHDAT
  pending_duration[offset] := arg_duration
  pending_shape[offset]    := arg_shape
  pending_freq[offset]     := arg_freq

'///////////////////////////////////////////////////////////////////////

PUB PlaySoundPCM(arg_channel, arg_pcm_start, arg_pcm_end) | offset

'' Plays an unsigned 8-bit 11KHz PCM sound once. If a sound is already
'' playing, then the old sound stops and the new sound is played.
''
''    channel:   The channel on which to play the sound (0-4)
''    pcm_start: The address of the PCM buffer
''    pcm_end:   The address of the end of the PCM buffer

  offset := arg_channel*SIZE_OF_PARAM_CHDAT
  pending_pcm_start[offset] := arg_pcm_start
  pending_pcm_end[offset]   := arg_pcm_end
  pending_duration[offset]  := DURATION_INFINITE
  pending_shape[offset]     := SHAPE_PCM_8BIT_11KHZ
  pending_freq[offset]      := 400

'///////////////////////////////////////////////////////////////////////

PUB StopSound(arg_channel)

'' Stops playing a sound.
'' 
''    channel:  The channel to stop.

  pending_shape[arg_channel*SIZE_OF_PARAM_CHDAT] := SHAPE_SILENT

'///////////////////////////////////////////////////////////////////////

PUB SetFreq(arg_channel, arg_freq)

'' Changes the frequency of the playing sound. If called
'' repetedly, it can be used to create a frequency sweep.
'' 
''    channel:  The channel to set the frequency of.

  pending_freq[arg_channel*SIZE_OF_PARAM_CHDAT] := arg_freq

'///////////////////////////////////////////////////////////////////////
' DATA /////////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

DAT

'// Assembly language sound driver /////////////////////////////////////

'NOTE: I'm using the convention of prepending ':' to labels that are
'      used for self-modifying code. I believe this is different from
'      the convention used in code from Parallax.

                    org
'---- Entry
entry
                    '---- Initialization ----
                    rdlong  temp,par                         'Get audio pin
                    mov     dira_init,#1
                    shl     dira_init,temp
                    or      dira,dira_init                   'Set audio pin's direction to output

                    mov     time_to_resume,cnt               'Setup delay
                    add     time_to_resume,delay_amount

                    mov     frqa,#0                          'Setup counter A
                    add     ctra_init,temp
                    mov     ctra,ctra_init

                    mov     _param_ptr,par                   'Init communication ptr
                    add     _param_ptr,#4                    'Already done with audio_pin
                    
                    '- Start of main processing loop -
loop
                    '---- Process Pending API Requests ----

                    '- Get pending shape -
                    rdlong  _pending_shape,_param_ptr  wz    'Check for a request for a new shape
       if_z         jmp     #skip_pending_shape
                    wrlong  _nothing_pending,_param_ptr      'Signal that the new shape has been received

                    movd    :set_new_shape,shape_ptr
                    sub     _pending_shape,#1
:set_new_shape      mov     0,_pending_shape                 'Set new shape

                    cmp     _pending_shape,#SHAPE_PCM_8BIT_11KHZ-1  wz
       if_ne        jmp     #skip_pending_shape
                    
                    '- Get PCM addresses -
                    movd    :get_pcm_start,pcm_start_ptr     'Setup cog pointers to pcm_start and pcm_curr
                    movs    :get_pcm_curr,pcm_start_ptr
                    nop   'Needed?
                    movd    :get_pcm_curr,pcm_curr_ptr
 
                    mov     temp,_param_ptr                  'Setup hub pointer to pending_pcm_start
                    add     temp,#12
:get_pcm_start      rdlong  0,temp                           'Read pcm_start
                    wrlong  _nothing_pending,temp            'Signal that pcm_start has been received

:get_pcm_curr       mov     0,0                              'Copy pcm_start into pcm_curr

                    movd    :get_pcm_end,pcm_end_ptr
                    add     temp,#4
:get_pcm_end        rdlong  0,temp
                    wrlong  _nothing_pending,temp            'Signal that pcm_end has been received

skip_pending_shape

                    '- Get pending frequency -
                    add     _param_ptr,#4                    'Advance communication ptr
                    rdlong  _pending_freq,_param_ptr   wz    'Check for a request for a new frequency
       if_z         jmp     #skip_pending_freq
                    wrlong  _nothing_pending,_param_ptr      'Signal that the new freq has been received

                      movd  :set_new_theta_delta,theta_delta_ptr
                      shr   _pending_freq,#2                 'Calculate new theta_delta using a trick to multiply by ($2000/21845 (Approx 22KHz))
                      mov   temp,_pending_freq
                      shr   temp,#1
                      add   _pending_freq,temp               'theta_delta = ($2000*frequency)/(21845 (Approx 22KHz))

:set_new_theta_delta  mov   0,_pending_freq                  'Set new theta_delta
skip_pending_freq

                    '- Get pending duration -
                    add     _param_ptr,#4                    'Advance communication ptr
                    rdlong  _pending_duration,_param_ptr wz  'Check for a request for a new duration
       if_z         jmp     #skip_pending_duration
                    wrlong  _nothing_pending,_param_ptr      'Signal that the new duration has been received

                    movd    :set_new_stop_time,stop_time_ptr
                    cmp     _pending_duration,long_max   wz  'Check for DURATION_INFINITE
       if_z         mov     temp,#0
       if_z         jmp     #:set_new_stop_time

                    mov     temp,_pending_duration
                    add     temp,sample_counter   wz         'Set new stop_time
       if_z         add     temp,#1                          'Ensure _pending_duration+sample_counter doesn't become "never stop" (ie. 0)
:set_new_stop_time  mov     0,temp
skip_pending_duration

                    '---- Stop Finished Sound ----
                    movd    :check_stop_time,stop_time_ptr
                    movd    :stop_sound,shape_ptr
:check_stop_time    cmp     0,sample_counter   wz            'Check if sound should be stopped
:stop_sound   if_e  mov     0,#SHAPE_SILENT-1


                    '---- Get Work Data ----
channel_loop          movs  :theta_to_temp,theta_ptr
                      movs  :theta_cycled_to_temp,theta_cycled_ptr
                      movs  :lfsr_to_temp,lfsr_ptr

:theta_to_temp        mov   theta_temp,0                     'Get theta
:theta_cycled_to_temp mov   theta_cycled_temp,0              'Get theta_cycled
:lfsr_to_temp         mov   lfsr_temp,0                      'Get lfsr

                    '---- Generate Sample ----
                    movs    :jump_table_indexer,shape_ptr
                    mov     shape_jmp_ptr,#shape_jmp_table
:jump_table_indexer add     shape_jmp_ptr,0                  'Compute offset into shape_jmp_table
                    movs    :shape_jmp,shape_jmp_ptr
                    nop                                      'Wait-out the pipelining
:shape_jmp          jmp     0                                'Call shape routine to generate and output sample
return_from_shape

                    '---- Advance Theta ----
                    movs    :advance_theta,theta_delta_ptr
                    nop
:advance_theta      add     theta_temp,0                     'Advance theta
                    cmp     theta_temp,sin_360   wc          'Wrap from 360 degrees to 0 degrees
       if_ae        sub     theta_temp,sin_360

                    mov     theta_cycled_temp,#0             'Update theta_cycled
       if_ae        mov     theta_cycled_temp,#1

                    '---- Store Work Data ----
                    movd    :store_theta,theta_ptr
                    movd    :store_theta_cycled,theta_cycled_ptr
                    movd    :store_lfsr,lfsr_ptr

:store_theta        mov     0,theta_temp                     'Store theta
:store_theta_cycled mov     0,theta_cycled_temp              'Store theta_cycled
:store_lfsr         mov     0,lfsr_temp                      'Store lfsr


                    '---- Add Into Mixer ----
                    add     mixed_sample,sample_temp            'Add sample into mix (no need to load/store sample?)

                    '---- Next Channel ----
                    add     theta_ptr,       #SIZE_OF_CHDAT     'Update channel data pointers
                    cmp     theta_ptr,#end_of_channel_data  wz  'Was this the last channel?
       if_e         jmp     #mixer                              'If yes, jump to mixer
                    add     theta_delta_ptr, #SIZE_OF_CHDAT     'Continue updating channel data pointers
                    add     theta_cycled_ptr,#SIZE_OF_CHDAT
                    add     shape_ptr,       #SIZE_OF_CHDAT
                    add     stop_time_ptr,   #SIZE_OF_CHDAT
                    add     lfsr_ptr,        #SIZE_OF_CHDAT
                    add     pcm_start_ptr,   #SIZE_OF_CHDAT
                    add     pcm_end_ptr,     #SIZE_OF_CHDAT
                    add     pcm_curr_ptr,    #SIZE_OF_CHDAT
                    add     _param_ptr,      #4*3
                    jmp     #loop                               'Goto next channel

                    '---- Average and Output Mixed Sample ----
mixer
                    cmp     active_channels,#0   wz   'Check if no channels are active
       if_z         mov     mixed_sample,word_half    'If no channels are active, just output silence
                    shl     mixed_sample,#16-2        'Crank volume high as possible for 4 channels without clipping (You were right, Colin ;) )
                    mov     frqa,mixed_sample         'Output Mixed Sample

                    mov     mixed_sample,#0           'Clear mixed_sample low bits
                    mov     active_channels,#0        'Clear active_channels

                    '---- Prepare For Next Iteration ----
                    mov     theta_ptr,       #channel_data+CHDAT_THETA
                    mov     theta_delta_ptr, #channel_data+CHDAT_THETA_DELTA
                    mov     theta_cycled_ptr,#channel_data+CHDAT_THETA_CYCLED
                    mov     shape_ptr,       #channel_data+CHDAT_SHAPE
                    mov     stop_time_ptr,   #channel_data+CHDAT_STOP_TIME
                    mov     lfsr_ptr,        #channel_data+CHDAT_LFSR
                    mov     pcm_start_ptr,   #channel_data+CHDAT_PCM_START
                    mov     pcm_end_ptr,     #channel_data+CHDAT_PCM_END
                    mov     pcm_curr_ptr,    #channel_data+CHDAT_PCM_CURR
                    mov     _param_ptr,par
                    add     _param_ptr,#4

                    add     sample_counter,#1        wz      'Increment Sample Counter
       if_z         add     sample_counter,#1                'Skip zero, stop_time uses it to mean "never stop"

                    waitcnt time_to_resume,delay_amount      'Delay
                    jmp     #loop                            'Loop

' // Shape Generation Routines ////////////////////////////////////////
' Note: These use a JMP/JMP protocol instead of JMPRET/JMP or CALL/RET
'       because they are only called from one line of code
' Return: Returns the sample in sample_temp

generate_shape_silent
                    mov     sample_temp,#0                        'Add nothing to mixed_sample
                    jmp     #return_from_shape

generate_shape_sine
                    add     active_channels,#1                    'Increment number of active channels
                    mov     sin,theta_temp                        'Compute sample from sine wave
                    call    #getsin
                    mov     sample_temp,sin
                    add     sample_temp,word_max                  'Adjust range from [-$FFFF,$FFFF] to [$0,$1FFFE]
                    shr     sample_temp,#1                        'Adjust range from [$0,$1FFFE] to [$0,$FFFF]
                    jmp     #return_from_shape

generate_shape_sawtooth
                    add     active_channels,#1                    'Increment number of active channels
                    mov     sample_temp,theta_temp
                    shl     sample_temp,#19                       'Start with a triangle wave [$0,$FFFF_FFFF]
                    abs     sample_temp,sample_temp               'Turn triangle into sawtooth [0,$8FFF_FFFF]
                    shr     sample_temp,#15                       'Adjust range from [0,$8FFF_FFFF] to [0,$FFFF]
                    jmp     #return_from_shape

generate_shape_square
                    add     active_channels,#1                    'Increment number of active channels
                    cmp     theta_temp,sin_180     wc             'Compute sample from square wave
       if_b         mov     sample_temp,#0                        'Output low sample
       if_ae        mov     sample_temp,word_max                  'Output high sample
                    jmp     #return_from_shape

generate_shape_triangle
                    add     active_channels,#1                    'Increment number of active channels
                    mov     sample_temp,theta_temp                'Compute sample from trangular wave
                    shl     sample_temp,#3                        'Adjust range from [$0,$1FFF] to [$0,$FFF8]
                    jmp     #return_from_shape

generate_shape_noise
                    add     active_channels,#1                    'Increment number of active channels
                    mov     sample_temp,lfsr_temp
                    tjnz    theta_cycled_temp,#new_noise_sample   'Only generate a sample once per cycle
                    jmp     #return_from_shape
new_noise_sample
'                    add     sample_temp,#1         '(lfsr + 1)
                    mov     temp,lfsr_temp
{
                    rol     temp,#2
                    xor     sample_temp,temp       '^(lfsr << 2)
                    rol     temp,#4
                    xor     sample_temp,temp       '^(lfsr << 6)
                    rol     temp,#1
                    xor     sample_temp,temp       '^(lfsr << 7)
}
{
                    rol     temp,#15
                    xor     sample_temp,temp       '^(lfsr << 22)
                    rol     temp,#6
                    xor     sample_temp,temp       '^(lfsr << 28)
                    rol     temp,#1
                    xor     sample_temp,temp       '^(lfsr << 29)
                    rol     temp,#1
                    xor     sample_temp,temp       '^(lfsr << 30)
                    rol     temp,#1
                    xor     sample_temp,temp       '^(lfsr << 31)
                    rol     temp,#1
                    xor     sample_temp,temp       '^(lfsr << 32)
}

                    rol     temp,#6
                    xor     sample_temp,temp       '^(lfsr << 6)
                    rol     temp,#1
                    xor     sample_temp,temp       '^(lfsr << 7)
                    rol     temp,#22
                    xor     sample_temp,temp       '^(lfsr << 29)
                    rol     temp,#1
                    xor     sample_temp,temp       '^(lfsr << 30)
                    rol     temp,#1
                    xor     sample_temp,temp       '^(lfsr << 31)
                    rol     temp,#1
                    xor     sample_temp,temp       '^(lfsr << 32)

{
                    rol     temp,#2
                    xor     sample_temp,temp       '^(lfsr << 2)
                    rol     temp,#2
                    xor     sample_temp,temp       '^(lfsr << 4)
                    rol     temp,#1
                    xor     sample_temp,temp       '^(lfsr << 5)
                    rol     temp,#9
                    xor     sample_temp,temp       '^(lfsr << 14)
                    rol     temp,#1
                    xor     sample_temp,temp       '^(lfsr << 15)
                    rol     temp,#1
                    xor     sample_temp,temp       '^(lfsr << 16)
}
                    mov     lfsr_temp,sample_temp  'store new lfsr state
                    shr     sample_temp,#16        'return high 16-bits
'                    and     sample_temp,word_max    'return low 16-bits
                    jmp     #return_from_shape

generate_shape_pcm_8bit_11khz
                    add     active_channels,#1              'Increment number of active channels

                    movs    :pcm_load_pcm_curr,pcm_curr_ptr
                    movs    :pcm_cmp_end,pcm_end_ptr        'Do something useful instead of nop
:pcm_load_pcm_curr  mov     temp,0

                    'I could just "rdlong" once every 4 samples, but that
                    'would require an extra long of storage per channel.
                    rdbyte  sample_temp,temp

                    'Setup the sample
                    shl     sample_temp,#8                  '8-bit -> 16-bit

                    'Advance pointer
                    movd    :pcm_store_pcm_curr,pcm_curr_ptr
                    xor     temp,bit_31                     'Increment 1-bit counter
                    test    temp,bit_31               wz
           if_z     add     temp,#1                         'Only increment ptr every other iteration (ie: 22KHz -> 11KHz)
:pcm_cmp_end        cmp     temp,0                    wz    'Compare pcm_curr with pcm_end
           if_e     movd    :pcm_stop,shape_ptr
:pcm_store_pcm_curr mov     0,temp
:pcm_stop  if_e     mov     0,#SHAPE_SILENT-1

                    jmp     #return_from_shape

'// Sine/Cosine Lookup Function ///////////////////////////////////////
'// from Hydra Programmer's Manual
'
' Get sine/cosine
'
'      quadrant:  1             2             3             4
'         angle:  $0000..$07FF  $0800..$0FFF  $1000..$17FF  $1800..$1FFF
'   table index:  $0000..$07FF  $0800..$0001  $0000..$07FF  $0800..$0001
'        mirror:  +offset       -offset       +offset       -offset
'          flip:  +sample       +sample       -sample       -sample
'
' on entry: sin[12..0] holds angle (0° to just under 360°)
' on exit:  sin holds signed value ranging from $0000FFFF ('1') to $FFFF0001 ('-1')
'
getcos          add     sin,sin_90              'for cosine, add 90°
getsin          test    sin,sin_90      wc      'get quadrant 2|4 into c
                test    sin,sin_180     wz      'get quadrant 3|4 into nz
                negc    sin,sin                 'if quadrant 2|4, negate offset
                or      sin,sin_table           'or in sin table address >> 1
                shl     sin,#1                  'shift left to get final word address
                rdword  sin,sin                 'read word sample from $E000 to $F000
                negnz   sin,sin                 'if quadrant 3|4, negate sample
getsin_ret
getcos_ret      ret                             '39..54 clocks
                                                '(variance is due to HUB sync on RDWORD)


sin_90          long    $0800	
sin_180         long    $1000
sin_360         long    $2000
sin_table       long    $E000 >> 1              'sine table base shifted right

sin             long    0

'// Data ///////////////////////////////////////////////////////////////

delay_amount            long    80_000_000/SAMPLE_RATE
dira_init               long    0
ctra_init               long    6<<26   'mode = duty single

active_channels         long    0       'The number of channels outputting a sound
mixed_sample            long    0       'The sum of samples from each channel

theta_ptr               long    channel_data+CHDAT_THETA        '$0000 = 0 degrees, $2000 = 360 degrees
theta_delta_ptr         long    channel_data+CHDAT_THETA_DELTA  'Formula: ($2000 * frequency) / SAMPLE_RATE
theta_cycled_ptr        long    channel_data+CHDAT_THETA_CYCLED '1 if theta has just completed a cycle, 0 otherwise
shape_ptr               long    channel_data+CHDAT_SHAPE        'Shape of the sound
stop_time_ptr           long    channel_data+CHDAT_STOP_TIME    'Stop the sound when sample_counter reaches this value, or 0 to play forever
lfsr_ptr                long    channel_data+CHDAT_LFSR         'Linear-Feedback Shift Register: Used to generate white noise
pcm_start_ptr           long    channel_data+CHDAT_PCM_START    'Address the PCM data starts at
pcm_end_ptr             long    channel_data+CHDAT_PCM_END      'Address the PCM data ends at (exclusive)
pcm_curr_ptr            long    channel_data+CHDAT_PCM_CURR     'Address of the current PCM sample

channel_data
                        long    0,0,0,0,0,21,0,0,0  'Channel 0
                        long    0,0,0,0,0,21,0,0,0  'Channel 1
                        long    0,0,0,0,0,21,0,0,0  'Channel 2
                        long    0,0,0,0,0,21,0,0,0  'Channel 3
end_of_channel_data

shape_jmp_ptr           long    0
shape_jmp_table         long    generate_shape_silent
                        long    generate_shape_sine
                        long    generate_shape_sawtooth
                        long    generate_shape_square
                        long    generate_shape_triangle
                        long    generate_shape_noise
                        long    generate_shape_pcm_8bit_11khz
                        
sample_counter          long    1                  'Increments at approx 22KHz (ie. once per driver iteration)
time_to_resume          long    0                  'Used with WAITCNT to synchronize iterations of main loop to 22KHz

_param_ptr              long    0
_pending_channel        long    0
_pending_shape          long    0
_pending_freq           long    0
_pending_duration       long    0
_nothing_pending        long    0

'A few commonly-needed values that are too big to use as an inline constant (ie. > 511)
long_max                long    $FFFF_FFFF   'The maximum value a long can hold
word_max                long    $0000_FFFF   'The maximum value a word can hold
word_half               long    $7FFF        'Half of the maximum value a word can hold
bit_31                  long    $8000_0000   'Bit 31 = 1, the rest = 0
bit_31_not              long    !bit_31      'Logical not of bit_31

temp                    long    0            'Just a scratchpads for calculations
temp2                   long    0            'Just a scratchpads for calculations
sample_temp             long    0
theta_temp              long    0
theta_cycled_temp       long    0
lfsr_temp               long    0
