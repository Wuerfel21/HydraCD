{///////////////////////////////////////////////////////////////////////

Sound Driver
AUTHOR: Nick Sabalausky
LAST MODIFIED: 2.5.06
VERSION 2.1

start() and stop() code taken from Parallax's drivers
Sine/Cosine lookup function from Hydra Programmer's Manual

NOTE: This expects the system clock to be set at 80MHz

Detailed Change Log
--------------------
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

Sound API
----------
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

StopSound: Stops playing a sound.

SetFreq(freq): Changes the frequency of the playing sound. If called
               repetedly, it can be used to create a frequency sweep.

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

///////////////////////////////////////////////////////////////////////}


'///////////////////////////////////////////////////////////////////////
' CONSTANTS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
CON

  'Approximately 22KHz. Do NOT change this value! The calculation of theta_delta
  'has an optimization (to avoid a division) that relies on this exact sample rate.
  SAMPLE_RATE = 21845

  #1, SHAPE_SILENT, SHAPE_SINE, SHAPE_SQUARE, SHAPE_TRIANGLE, SHAPE_NOISE
  DURATION_INFINITE = $FFFF_FFFF

  NOTHING_PENDING = $0

'///////////////////////////////////////////////////////////////////////
' VARIABLES ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
VAR
  long cogon, cog

  'Communication paramaters. See above for explanation of protocol.
  long pending_shape
  long pending_freq
  long pending_duration

'///////////////////////////////////////////////////////////////////////
' OBJECTS //////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

'///////////////////////////////////////////////////////////////////////
' FUNCTIONS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

'// PUB start //////////////////////////////////////////////////////////

PUB start : okay

'' Start sound driver - starts a cog
'' returns false if no cog available

  pending_shape := NOTHING_PENDING
  pending_freq := NOTHING_PENDING

  stop
  okay := cogon := (cog := cognew(@entry,@pending_shape)) > 0


'///////////////////////////////////////////////////////////////////////

PUB stop

'' Stop sound driver - frees a cog

  if cogon~
    cogstop(cog)

'///////////////////////////////////////////////////////////////////////

PUB PlaySound(arg_shape, arg_freq, arg_duration)

'' Starts playing a sound. If a sound is already playing, then
'' the old sound stops and the new sound is played.
''
''    shape:    The desired shape of the sound. Can be any of the
''              following contants: SHAPE_SINE, SHAPE_SQUARE,
''              SHAPE_TRIANGLE, SHAPE_NOISE.
''    freq:     The desired sound frequncy.
''    duration: The amount of time (in 1/SAMPLE_RATE of a second) to play
''              the sound. Or use DURATION_INFINITE for an infinite duration.
              
  pending_shape    := arg_shape
  pending_freq     := arg_freq
  pending_duration := arg_duration

'///////////////////////////////////////////////////////////////////////

PUB StopSound

'' Stops playing a sound.

  pending_shape := SHAPE_SILENT

'///////////////////////////////////////////////////////////////////////

PUB SetFreq(arg_freq)

'' Changes the frequency of the playing sound. If called
'' repetedly, it can be used to create a frequency sweep.

  pending_freq := arg_freq

'///////////////////////////////////////////////////////////////////////
' DATA /////////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

DAT

'// Assembly language sound driver /////////////////////////////////////

                     org
' Entry
entry               or      dira,dira_init                   'Set audio pin to output

                    mov     time_to_resume,cnt               'Setup delay
                    add     time_to_resume,delay_amount

                    mov     frqa,#0                          'Setup counter A
                    mov     ctra,ctra_init

loop
                    cmp     stop_time, counter  wz           'Check if sound should be stopped
       if_e         mov     shape,#(SHAPE_SILENT-1)

                    mov     _param_ptr,par                   'Init communication ptr
                    rdlong  _pending_shape,_param_ptr  wz    'Check for a request for a new shape
       if_z         jmp     #skip_pending_shape
                    wrlong  _nothing_pending,_param_ptr      'Signal that the new shape has been received

                    mov     shape,_pending_shape             'Set new shape
                    sub     shape,#1
skip_pending_shape

                    add     _param_ptr,#4                    'Advance communication ptr
                    rdlong  _pending_freq,_param_ptr   wz    'Check for a request for a new frequency
       if_z         jmp     #skip_pending_freq
                    wrlong  _nothing_pending,_param_ptr      'Signal that the new freq has been received

                    mov     theta_delta,_pending_freq        'Calculate new theta_delta
                    shr     theta_delta,#2                   'Start of a trick to multiply by ($2000/21845 (Approx 22KHz))
                    mov     temp,theta_delta
                    shr     temp,#1
                    add     theta_delta,temp                 'theta_delta = ($2000*frequency)/(21845 (Approx 22KHz))
skip_pending_freq

                    add     _param_ptr,#4                    'Advance communication ptr
                    rdlong  _pending_duration,_param_ptr wz  'Check for a request for a new frequency
       if_z         jmp     #skip_pending_duration
                    wrlong  _nothing_pending,_param_ptr      'Signal that the new freq has been received

                    cmp     _pending_duration,value_FFFF_FFFF  wz  'Check for DURATION_INFINITE
       if_z         mov     stop_time,#0
       if_z         jmp     #skip_pending_duration

                    mov     stop_time,_pending_duration
                    add     stop_time,counter   wz         'Set new stop_time
       if_z         add     stop_time,#1                   'Ensure _pending_duration+counter doesn't become "never stop" (ie. 0)
skip_pending_duration

                    mov     shape_jmp_ptr,#shape_jmp_table
                    add     shape_jmp_ptr,shape              'Compute offset into shape_jmp_table
                    movs    shape_jmp,shape_jmp_ptr
                    nop
shape_jmp           jmp     0                                'Call shape routine to generate and output sample
return_from_shape

                    add     theta,theta_delta                'Advance theta
                    cmp     theta,theta_360   wc             'Wrap from 360 degrees to 0 degrees
       if_ae        sub     theta,theta_360
                    mov     theta_cycled,#0
       if_ae        mov     theta_cycled,#1

                    waitcnt time_to_resume,delay_amount      'Delay

                    add     counter,#1        wz             'Increment Counter
       if_z         add     counter,#1                       'Skip zero, stop_time uses it to mean "never stop"
                    jmp     #loop                            'Loop

' // Shape Generation Routines ////////////////////////////////////////
' Note: These use a JMP/JMP protocol instead of JMPRET/JMP or CALL/RET
'       because they are only called from one line of code

generate_shape_silent
                    jmp     #return_from_shape

generate_shape_sine
                    mov     sin,theta                        'Compute sample from sine wave
                    call    #getsin
                    add     sin,sin_adjust                   'Adjust range from [-$FFFF,$FFFF] to [$0,$1FFFE]
                    mov     sample,sin
                    shl     sample,#15                       'Adjust range from [$0,$1FFFE] to [$0,$FFFF0000]
                    and     sin,sin_adjust
                    add     sample,sin                       'Adjust range from [$0,$FFFF0000] to [$0,$FFFFFFFF]
                    mov     frqa,sample                      'Output sample
                    jmp     #return_from_shape

generate_shape_square
                    cmp     theta,theta_180   wc             'Compute sample from square wave
       if_b         mov     frqa,#0                          'Output low sample
       if_ae        mov     frqa,value_FFFF_FFFF             'Output high sample
                    jmp     #return_from_shape

generate_shape_triangle
                    mov     sample,theta                     'Compute sample from trangular wave
                    shl     sample,#19
                    mov     frqa,sample                      'Output sample
                    jmp     #return_from_shape

generate_shape_noise
                    tjnz    theta_cycled,#new_noise_sample   'Only generate a sample once per cycle
                    jmp     #return_from_shape
new_noise_sample
                    mov     sample,lfsr
'                    add     sample,#1         '(lfsr + 1)
                    mov     temp,lfsr
{
                    rol     temp,#2
                    xor     sample,temp       '^(lfsr << 2)
                    rol     temp,#4
                    xor     sample,temp       '^(lfsr << 6)
                    rol     temp,#1
                    xor     sample,temp       '^(lfsr << 7)
}
                    rol     temp,#15
                    xor     sample,temp       '^(lfsr << 22)
                    rol     temp,#6
                    xor     sample,temp       '^(lfsr << 28)
                    rol     temp,#1
                    xor     sample,temp       '^(lfsr << 29)
                    rol     temp,#1
                    xor     sample,temp       '^(lfsr << 30)
                    rol     temp,#1
                    xor     sample,temp       '^(lfsr << 31)
                    rol     temp,#1
                    xor     sample,temp       '^(lfsr << 32)

{
                    rol     temp,#6
                    xor     sample,temp       '^(lfsr << 6)
                    rol     temp,#1
                    xor     sample,temp       '^(lfsr << 7)
                    rol     temp,#22
                    xor     sample,temp       '^(lfsr << 29)
                    rol     temp,#1
                    xor     sample,temp       '^(lfsr << 30)
                    rol     temp,#1
                    xor     sample,temp       '^(lfsr << 31)
                    rol     temp,#1
                    xor     sample,temp       '^(lfsr << 32)
}
                    mov     lfsr,sample       'store new lfsr state
                   ' shl     sample,#24
                    mov     frqa,sample       'Output sample
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
sin_table       long    $E000 >> 1              'sine table base shifted right

sin             long    0

'// Data ///////////////////////////////////////////////////////////////

a_value     long  SAMPLE_RATE*60
delay_amount            long    80_000_000/SAMPLE_RATE
dira_init               long    (1<<7)             'Set pin 7 (audio) to output
ctra_init               long    (6<<26) + (7<<0)   'mode=duty single, out a=pin 7

theta                   long    $0000              '$0000 = 0 degrees, $2000 = 360 degrees
theta_delta             long    $0000              'Formula: ($2000 * frequency) / SAMPLE_RATE
shape                   long    SHAPE_SILENT
stop_time               long    $0000              'Stop the sound when counter reaches this value, or 0 to play forever

theta_180               long    $1000
theta_360               long    $2000
theta_cycled            long    $0000              '1 if theta has just completed a cycle, 0 otherwise

sin_adjust              long    $FFFF

shape_jmp_table         long    generate_shape_silent
                        long    generate_shape_sine
                        long    generate_shape_square
                        long    generate_shape_triangle
                        long    generate_shape_noise
                        
lfsr                    long    21                 'Linear-Feedback Shift Register: Used to generate white noise
counter                 long    1                  'Increments at approx 22KHz (ie. once per driver iteration)

value_FFFF_FFFF         long    $FFFF_FFFF   'A commonly-needed value, but too big to use as an inline constant (ie. > 511)
_nothing_pending        long    $0

_param_ptr              res     1
_pending_shape          res     1
_pending_freq           res     1
_pending_duration       res     1

shape_jmp_ptr           res     1

sample                  res     1
time_to_resume          res     1
temp                    res     1         'Just a scratchpad for calculations
