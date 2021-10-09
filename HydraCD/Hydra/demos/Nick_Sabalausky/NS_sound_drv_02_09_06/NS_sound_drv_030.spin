{///////////////////////////////////////////////////////////////////////

Sound Driver
AUTHOR: Nick Sabalausky
LAST MODIFIED: 2.9.06
VERSION 3.0

start() and stop() code taken from Parallax's drivers
Sine/Cosine lookup function from Hydra Programmer's Manual
Divide function from Hydra Programmer's Manual

NOTE: This expects the system clock to be set at 80MHz

Detailed Change Log
--------------------
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

Sound API
----------
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

///////////////////////////////////////////////////////////////////////}


'///////////////////////////////////////////////////////////////////////
' CONSTANTS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
CON

  'Approximately 22KHz. Do NOT change this value! The calculation of theta_delta
  'has an optimization (to avoid a division) that relies on this exact sample rate.
  SAMPLE_RATE = 21845

  #1, SHAPE_SILENT, SHAPE_SINE, SHAPE_SAWTOOTH, SHAPE_SQUARE, SHAPE_TRIANGLE, SHAPE_NOISE
  DURATION_INFINITE = $FFFF_FFFF
  NOTHING_PENDING = $0

  'Channel Data Field Offsets
  #0, CHDAT_THETA, CHDAT_THETA_DELTA, CHDAT_THETA_CYCLED, CHDAT_SHAPE, CHDAT_STOP_TIME, CHDAT_LFSR, SIZE_OF_CHDAT
  SIZE_OF_PARAM_CHDAT = 3  'pending_shape, pending_freq, and pending_duration

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

  long pending_shape_ch1
  long pending_freq_ch1
  long pending_duration_ch1

  long pending_shape_ch2
  long pending_freq_ch2
  long pending_duration_ch2

  long pending_shape_ch3
  long pending_freq_ch3
  long pending_duration_ch3

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

PUB PlaySound(arg_channel, arg_shape, arg_freq, arg_duration) | offset

'' Starts playing a sound. If a sound is already playing, then
'' the old sound stops and the new sound is played.
''
''    channel:  The channel on which to play the sound (0-4)
''    shape:    The desired shape of the sound. Can be any of the
''              following contants: SHAPE_SINE, SHAPE_SAWTOOTH,
''              SHAPE_SQUARE, SHAPE_TRIANGLE, SHAPE_NOISE.
''    freq:     The desired sound frequncy.
''    duration: The amount of time (in 1/SAMPLE_RATE of a second) to play
''              the sound. Or use DURATION_INFINITE for an infinite duration.

  offset := arg_channel*SIZE_OF_PARAM_CHDAT
  pending_duration[offset] := arg_duration
  pending_shape[offset]    := arg_shape
  pending_freq[offset]     := arg_freq

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
                    add     _param_ptr,      #4
                    jmp     #loop                               'Goto next channel

                    '---- Average and Output Mixed Sample ----
mixer
                    cmp     active_channels,#0   wz   'Check if no channels are active
                    mov     x,mixed_sample            'mixed_sample is sum of samples, divide by number of active channels
                    mov     y,active_channels
                    call    #divide                   'Final mixed sample is now in x

                    shl     x,#16                     'Extend from 16-bit to 32-bit (range becomes [$0,$FFFF_0000],
                                                      'so not full range (ie volume), but close enough to not notice)

       if_z         mov     x,#long_half              'If no channels are active, just output 50%
                    mov     frqa,x                    'Output Mixed Sample
'                    mov     frqa,sample_temp                    'Output Mixed Sample

                    mov     mixed_sample,#0           'Clear mixed_sample low bits
                    mov     active_channels,#0        'Clear active_channels

                    '---- Prepare For Next Iteration ----
                    mov     theta_ptr,       #channel_data+CHDAT_THETA
                    mov     theta_delta_ptr, #channel_data+CHDAT_THETA_DELTA
                    mov     theta_cycled_ptr,#channel_data+CHDAT_THETA_CYCLED
                    mov     shape_ptr,       #channel_data+CHDAT_SHAPE
                    mov     stop_time_ptr,   #channel_data+CHDAT_STOP_TIME
                    mov     lfsr_ptr,        #channel_data+CHDAT_LFSR
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


'// 32-bit Unsigned Division Function ///////////////////////////////////////
'// From Hydra Programmer's Manual
'
' Divide x[31..0] by y[15..0] (y[16] must be 0)
' on exit, quotient is in x[15..0] and remainder is in x[31..16]
'
' 204 cycles
'
divide          shl     y,#15              'get divisor into y[30..15]
                mov     temp,#16           'ready for 16 quotient bits

divide_loop     cmpsub  x,y     wc         'if y =< x then subtract it, quotient bit into c
                rcl     x,#1               'rotate c into quotient, shift dividend
                djnz    temp,#divide_loop  'loop until done

divide_ret      ret                        'quotient in x[15..0], remainder in x[31..16]

x    long  0
y    long  0

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

channel_data
                        long    0,0,0,0,0,21  'Channel 0
                        long    0,0,0,0,0,21  'Channel 1
                        long    0,0,0,0,0,21  'Channel 2
                        long    0,0,0,0,0,21  'Channel 3
end_of_channel_data

shape_jmp_ptr           long    0
shape_jmp_table         long    generate_shape_silent
                        long    generate_shape_sine
                        long    generate_shape_sawtooth
                        long    generate_shape_square
                        long    generate_shape_triangle
                        long    generate_shape_noise
                        
sample_counter          long    1                  'Increments at approx 22KHz (ie. once per driver iteration)
time_to_resume          long    0                  'Used with WAITCNT to synchronize iterations of main loop to 22KHz

_param_ptr              long    0
_pending_channel        long    0
_pending_shape          long    0
_pending_freq           long    0
_pending_duration       long    0
_nothing_pending        long    0

'A couple commonly-needed values that are too big to use as an inline constant (ie. > 511)
long_half               long    $7FFF_FFFF   'Half of the maximum value a long can hold
long_max                long    $FFFF_FFFF   'The maximum value a long can hold
word_max                long    $0000_FFFF   'The maximum value a word can hold

temp                    long    0            'Just a scratchpads for calculations
sample_temp             long    0
theta_temp              long    0
theta_cycled_temp       long    0
lfsr_temp               long    0
