' //////////////////////////////////////////////////////////////////////
' COPSND Driver (sound engine)          
' AUTHOR: Colin Phillips
' LAST MODIFIED: 1.12.06
' VERSION 0.1

CON

audio_freq = 11025
system_rate = 80_000_000/11025                          '7256
channel_data = $0                                       ' offsetted by data_start
channel_len = 0                                         ' Status 0 off, N length in samples.
channel_cnt = 1
channel_volume = 2
channel_freq = 3
channel_phase = 4
channel_venv = 5
channel_fenv = 6
channel_tick = 7                                        ' internal counter
channel_size = 8
max_channels = 4
' special frequency bit masks
FRQ_WHITENOISE = $80000000

VAR

long  cogon, cog
  
PUB start(copsndptr) : okay

'' Start COPSND driver - starts a cog
'' returns false if no cog available
''
  stop
  okay := cogon := (cog := cognew(@entry,copsndptr)) > 0

PUB stop

'' Stop TV driver - frees a cog

  if cogon~
    cogstop(cog)

DAT

'***********************************
'* Assembly language COPSND driver *
'***********************************

                        org
'
'
' Entry
entry

                        ' setup counter to output on pin 7 (Audio)
                        movi    ctra, #%00110_000       '(delta modulation)
                        movs    ctra, #7
                        mov     frqa, #0
                        or      dira, #1<<7
                        mov     a_cnt, cnt
                        add     a_cnt, a_rate

                        mov     data_start+channel_data+channel_size*0, #0
                        mov     data_start+channel_data+channel_size*1, #0
                        mov     data_start+channel_data+channel_size*2, #0
                        mov     data_start+channel_data+channel_size*3, #0

' /////////////////////////////////////////////////////////////////////////////
' Sample Generation Main Loop /////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

'                       call    #insert_sample
:loop

                        ' check if a new sample has been requested.
                        rdlong  r0, par         wz
        if_nz           call    #insert_sample
                        
                        ' process & sum all channels.
                        mov     r1, #max_channels
                        mov     r0, #data_start+channel_data
                        mov     a_sample, h80000000                             ' Clear summed sample. (0v)
:next_channel
                        ' copy channel parameters
                        movs    :copy_len, r0
                        movs    :copy_cnt, r0
                        movs    :copy_vol, r0
                        movs    :copy_frq, r0
                        movs    :copy_phs, r0
                        movs    :copy_venv, r0
                        movs    :copy_fenv, r0
                        movs    :copy_tick, r0
                        
                        add     :copy_cnt, #1
                        add     :copy_vol, #2
                        add     :copy_frq, #3
                        add     :copy_phs, #4
                        add     :copy_venv, #5
                        add     :copy_fenv, #6
                        add     :copy_tick, #7
                        
:copy_len               mov     a_channel_len, 0
:copy_cnt               mov     a_channel_cnt, 0
:copy_vol               mov     a_channel_vol, 0
:copy_frq               mov     a_channel_frq, 0
:copy_phs               mov     a_channel_phs, 0
:copy_venv              mov     a_channel_venv, 0
:copy_fenv              mov     a_channel_fenv, 0
:copy_tick              mov     a_channel_tick, 0

                        ' check if channel is on.
                        cmp     a_channel_len, #0 wz                            ' if status==0 skip channel.
        if_z            jmp     #:continue


' Process Channel /////////////////////////////////////////////////////////////

' r2 = f(a_channel_cnt/a_channel_len)
                        mov     r2, a_channel_len
                        shr     r2, #3
                        add     a_channel_tick, #1
                        cmp     a_channel_tick, r2      wz
        if_z            mov     a_channel_tick, #0
        if_z            shr     a_channel_venv, #4

                        mov     t2, a_channel_venv                              ' take lower 4 bits of volume envelope to scale volume
                        and     t2, #15
                        mov     t1, a_channel_vol
                        call    #multiply
                        shr     t1, #4
                        mov     r3, t1

                        test    a_channel_frq, a_FRQ_WHITENOISE wz
        if_z            jmp     #:skip_whitenoise
                        ' attenuate volume based on white noise factor
                        test    lfsr, #%11      wc      ' carry = parity (bit 0 ^ bit 1)
                        rcr     lfsr, #1

                        mov     t1, lfsr
                        shl     t1, #16
                        shr     t1, #16
                        mov     t2, r3
                        call    #multiply
                        shr     t1, #32-16
                        
                        
                        mov     r3, t1
        :skip_whitenoise
        
                        ' generate sine wave - using a_channel_frq / a_channel_vol
                        mov     t1,a_channel_phs
'                       shr     t1,#32-13
                        mov     t2,r3 'a_channel_vol
                        call    #polar
                        mov     r2,t1
                        sub     r2, h80000000   ' get sine wave oscilating around 0 instead of $80000000, so we can add samples more easily
                        
                        add     a_channel_phs, a_channel_frq
                        
                        ' add to final sample.
                        add     a_sample, r2

                        ' increment sample counter / end sample.
                        add     a_channel_cnt, #1
                        cmp     a_channel_cnt, a_channel_len                    wz
        if_z            mov     a_channel_len, #0

' END Process Channel /////////////////////////////////////////////////////////

:continue
                        ' update channel parameters & move pointer along to next channel
                        movd    :update_len, r0
                        add     r0, #1
                        movd    :update_cnt, r0
                        add     r0, #1                        
                        movd    :update_vol, r0
                        add     r0, #1
                        movd    :update_frq, r0
                        add     r0, #1                        
                        movd    :update_phs, r0
                        add     r0, #1                        
                        movd    :update_venv, r0
                        add     r0, #1                        
                        movd    :update_fenv, r0
                        add     r0, #1                        
                        movd    :update_tick, r0
                        add     r0, #1                        
                        
:update_len             mov     0, a_channel_len
:update_cnt             mov     0, a_channel_cnt
:update_vol             mov     0, a_channel_vol
:update_frq             mov     0, a_channel_frq
:update_phs             mov     0, a_channel_phs
:update_venv            mov     0, a_channel_venv
:update_fenv            mov     0, a_channel_fenv
:update_tick            mov     0, a_channel_tick

                        djnz    r1, #:next_channel

                        ' sync to system rate, and set new signal.
                        add     a_tick, #1
                        waitcnt a_cnt, a_rate                                   ' sync loop to 11KHz or a factor of this.
                        mov     frqa, a_sample                                  ' change sample exactly after sync.
                        
                        jmp #:loop

' /////////////////////////////////////////////////////////////////////////////
' Insert Sample ///////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

insert_sample

                        mov     r0, #data_start+channel_data
                        mov     r1, #max_channels
:entity_scan
                        movd    :code_d, r0
                        nop
:code_d                 cmp     0, #0 wz
        if_nz           jmp     #:continue

                         
                        ' copy over data, clear status, and get out!!!
                        movd    :code_d2, r0
                        mov     r0, par
                        mov     r1, #channel_size
:loop                   
:code_d2                rdlong  0, r0
                        add     r0, #4
                        add     :code_d2, k_d0
                        djnz    r1, #:loop                        
                        
'                       ' Clear Status out.
'                       mov     r0, #0
'                       wrlong  r0, par

                        ' Get out!
                        jmp     #:done
:continue
                        add     r0, #channel_size
                        djnz    r1, #:entity_scan
:done

                        ' Clear Status out. regardless of whether it made it on a vacant channel or not.
                        mov     r0, #0
                        wrlong  r0, par

insert_sample_ret       ret


'
'
' Polar to cartesian
'
'   in:         t1 = 13-bit angle (0-8191)
'               t2 = 16-bit length (0-64k)
'
'   out:        t1 = x|y
'
polar                   test    t1,sine_180     wz      'get sine quadrant 3|4 into nz
                        test    t1,sine_90      wc      'get sine quadrant 2|4 into c
                        negc    t1,t1                   'if sine quadrant 2|4, negate table offset
                        or      t1,sine_table           'or in sine table address >> 1
                        shl     t1,#1                   'shift left to get final word address
                        rdword  t1,t1                   'read sine/cosine word
                        call    #multiply               'multiply sine/cosine by length to get x|y
                        shr     t1,#2                   'justify x|y integer
                        add     t1,h80000000            'convert to duty cycle
                        negnz   t1,t1                   'if sine quadrant 3|4, negate x|y
polar_ret               ret

sine_90                 long    $0800                   '90° bit
sine_180                long    $1000                   '180° bit
sine_table              long    $E000 >> 1              'sine table address shifted right
h80000000               long    $80000000
'
'
' Multiply
'
'   in:         t1 = 16-bit multiplicand (t1[31..16] must be 0)
'               t2 = 16-bit multiplier
'
'   out:        t1 = 32-bit product
'
multiply                shl     t2,#16

                        shr     t1,#1           wc
        if_c            add     t1,t2           wc
                        rcr     t1,#1           wc
        if_c            add     t1,t2           wc
                        rcr     t1,#1           wc
        if_c            add     t1,t2           wc
                        rcr     t1,#1           wc
        if_c            add     t1,t2           wc
                        rcr     t1,#1           wc
        if_c            add     t1,t2           wc
                        rcr     t1,#1           wc
        if_c            add     t1,t2           wc
                        rcr     t1,#1           wc
        if_c            add     t1,t2           wc
                        rcr     t1,#1           wc
        if_c            add     t1,t2           wc
                        rcr     t1,#1           wc
        if_c            add     t1,t2           wc
                        rcr     t1,#1           wc
        if_c            add     t1,t2           wc
                        rcr     t1,#1           wc
        if_c            add     t1,t2           wc
                        rcr     t1,#1           wc
        if_c            add     t1,t2           wc
                        rcr     t1,#1           wc
        if_c            add     t1,t2           wc
                        rcr     t1,#1           wc
        if_c            add     t1,t2           wc
                        rcr     t1,#1           wc
        if_c            add     t1,t2           wc
                        rcr     t1,#1           wc
        if_c            add     t1,t2           wc
                        rcr     t1,#1           wc

multiply_ret            ret

a_channel_len           long                    $0
a_channel_cnt           long                    $0
a_channel_vol           long                    $0
a_channel_frq           long                    $0
a_channel_phs           long                    $0
a_channel_venv          long                    $0
a_channel_fenv          long                    $0
a_channel_tick          long                    $0

a_FRQ_WHITENOISE        long                    FRQ_WHITENOISE
lfsr                    long                    $9af9be35
t1                      long                    $0
t2                      long                    $0
k_d0                    long                    1<<9
r0                      long                    $0
r1                      long                    $0
r2                      long                    $0
r3                      long                    $0
r4                      long                    $0
r5                      long                    $0
r6                      long                    $0
r7                      long                    $0
a_sample                long                    0                               ' resultant 32-bit output sample
a_cnt                   long                    0
a_tick                  long                    0
a_mode                  long                    6<<26 | 7                       ' Mode 6: OUTA = PHSA[32] (FRQA+=PHSA always) + pin 7 audio output
a_rate                  long                    system_rate                     ' System rate
a_freq                  long                    audio_freq                      ' Sample Frequency (samples per second)
' data begins after (channel data etc.)
data_start