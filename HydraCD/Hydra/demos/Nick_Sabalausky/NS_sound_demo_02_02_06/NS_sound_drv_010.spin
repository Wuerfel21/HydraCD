' //////////////////////////////////////////////////////////////////////
' Sound Driver
' AUTHOR: Nick Sabalausky
' LAST MODIFIED: 2.2.06
' VERSION 1.0
'
' start() and stop() code taken from Parallax's drivers
' Sine/Cosine lookup function from Hydra Programmer's Manual
'
' NOTE: This expects the system clock to be set at 80MHz
'
' To do:
' - Add Features:
'   - Selectable square wave, triangle wave, white noise, and PCM
'   - Multiple Channels
'   - Adjustable Volume
'   - Selectable One-shot vs. Repeating
'   - Envelopes
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
CON

  'Approximately 22KHz. Do NOT change this value! The calculation of theta_delta
  'has an optimization (to avoid a division) that relies on this exact sample rate.
  SAMPLE_RATE = 21845

'///////////////////////////////////////////////////////////////////////
' VARIABLES ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
VAR
  long cogon, cog

  long pending_freq  'Write value to to set frequency, the driver will
                     'activate the new frequency then change this to 0

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

  stop
  okay := cogon := (cog := cognew(@entry,@pending_freq)) > 0


'// PUB stop ///////////////////////////////////////////////////////////

PUB stop

'' Stop sound driver - frees a cog

  if cogon~
    cogstop(cog)

'// PUB set_freq ///////////////////////////////////////////////////////

PUB set_freq(arg_freq)
  pending_freq := arg_freq

'///////////////////////////////////////////////////////////////////////
' DATA /////////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

DAT

'// Assembly language sound driver /////////////////////////////////////

                        org
' Entry
entry                   or      dira,dira_init               'Set audio pin to output

                        mov     time_to_resume,cnt           'Setup delay
                        add     time_to_resume,delay_amount

                        mov     frqa,#0                      'Setup counter A
                        mov     ctra,ctra_init

loop                  
                        rdlong  _pending_freq,par   wz       'Check for a request for a new frequency
           if_z         jmp     #skip_pending_freq
                        wrlong  _pending_freq_done,par       'Signal that the new freq's been received

                        'mov     theta,#0                     'Reset theta

                        mov     theta_delta,_pending_freq    'Calculate new theta_delta
                        shr     theta_delta,#2               'Start of a trick to multiply by ($2000/21845 (Approx 22KHz))
                        mov     temp,theta_delta
                        shr     temp,#1
                        add     theta_delta,temp             'theta_delta = ($2000*frequency)/(21845 (Approx 22KHz))
skip_pending_freq

                        mov     sin,theta                    'Compute sample from sine wave
                        call    #getsin
                        mov     sample,sin
                        add     sample,sin_adjust            'Adjust range from [-$FFFF,$FFFF] to [$0,$1FFFE]
                        shl     sample,#15                   'Adjust range from [$0,$1FFFE] to [$0,$FFFF0000]
                        'add     sample,sin                   'Adjust range from [$0,$FFFF0000] to [$0,$FFFFFFFF] (bug: Causes noise)

                        mov     frqa,sample                  'Output sample

'                        cmp     theta,theta_180   wc         'Compute sample from square wave
'           if_b         mov     frqa,#0                      'Output sample
'           if_ae        mov     frqa,percent_100             'Output sample

                        add     theta,theta_delta            'Advance theta
                        cmp     theta,theta_360   wc         'Wrap from 360 degrees to 0 degrees
           if_ae        sub     theta,theta_360

                        waitcnt time_to_resume,delay_amount  'Delay

                        jmp     #loop                      'Loop


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

delay_amount            long    80_000_000/SAMPLE_RATE
dira_init               long    (1<<7)             'Set pin 7 (audio) to output
ctra_init               long    (6<<26) + (7<<0)   'mode=duty single, out a=pin 7
led_off_mask            long    $FFFF_FFFE
percent_100             long    $FFFF_0000

theta                   long    $0000              '$0000 = 0 degrees, $2000 = 360 degrees
theta_delta             long    $0000              'Start with no tone
theta_delta_orig        long    ($2000 * 500) / SAMPLE_RATE
theta_180               long    $1000
theta_360               long    $2000

sin_adjust              long    $FFFF

_pending_freq_done      long    0

_pending_freq           res     1

sample                  res     1
time_to_resume          res     1
temp                    res     1         'Just a scratchpad for calculations
