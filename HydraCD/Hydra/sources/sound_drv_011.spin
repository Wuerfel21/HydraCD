'//////////////////////////////////////////////////////////////////////////////
' Simple sound driver, originally based on parallax unofficial sound driver
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 2.19.06
' VERSION 1.0
' COMMENTS: 
'//////////////////////////////////////////////////////////////////////////////


CON

  rate          = 22050         'sample rate

VAR

  long  cogon, cog


PUB start(sound_ptr) : okay

'' Start sound driver - starts a cog
'' returns false if no cog available
'' sound_ptr base address of sound parameters

  stop
  okay := cogon := (cog := cognew(@entry,sound_ptr)) > 0


PUB stop

'' Stop sound driver - frees a cog

  if cogon~
    cogstop(cog)


DAT

'**********************************
'* Assembly language sound driver *
'**********************************

                        org
' Entry
'
entry                   mov     cntacc,cnt              ' init cntacc
                        add     cntacc,cntadd

:loop
                        mov     t2, par                 ' retrieve parameter values from caller
                        rdlong  _pin_left, t2           
                        add     t2, #4
                        rdlong  _freq_left, t2
                        add     t2, #4
                        rdlong  _volume_left, t2

                         mov     t1, #1                  ' convert pin # into bit position
                        shl     t1, _pin_left        

                        or      dira, t1                ' set general direction of I/O to output without disturbing other settings
                        movs    ctra, _pin_left         ' set cntr A pin to the hydra's output pin
                        movi    ctra, #%0_00110_000     ' duty cycle mode "00110", single ended


                        mov     t1, phase_left          ' calculate samples
                        shr     t1, #32-13
                        mov     t2, _volume_left
                        call    #polar
                        mov     left, t1

                        waitcnt cntacc, cntadd          ' wait for count sync

                        add     phase_left, _freq_left  ' update phases                                                        
                        
                        mov     t1, _freq_left
                        shr     t1, #2
                        add     phase_left2, t1

                        mov     frqa, left              ' update channel output

                        jmp     #:loop                  ' loop


' Polar to cartesian conversion function
'
'   in:         t1 = 13-bit angle
'               t2 = 16-bit length
'
'   out:        t1 = x|y
'
polar                   test    t1,sine_180     wz      ' get sine quadrant 3|4 into nz
                        test    t1,sine_90      wc      ' get sine quadrant 2|4 into c
                        negc    t1,t1                   ' if sine quadrant 2|4, negate table offset
                        or      t1,sine_table           ' or in sine table address >> 1
                        shl     t1,#1                   ' shift left to get final word address
                        rdword  t1,t1                   ' read sine/cosine word
                        call    #multiply               ' multiply sine/cosine by length to get x|y
                        shr     t1,#2                   ' justify x|y integer
                        add     t1,h80000000            ' convert to duty cycle
                        negnz   t1,t1                   ' if sine quadrant 3|4, negate x|y
polar_ret               ret




' local literal pool
sine_90                 long    $0800                   '90° bit
sine_180                long    $1000                   '180° bit
sine_table              long    $E000 >> 1              'sine table address shifted right
h80000000               long    $80000000





' 16x16 Multiply function (unrolled)
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



' variables and locals

cntadd                  long    80_000_000 / 22_050 ' clock frequency is hard coded here (roughly 3628 clocks per synthesis cycle)
cntacc                  long    $0

' temporary registers
t1                      long    $0
t2                      long    $0
t3                      long    $0

' PWM variables
phase_left              long    $00000000
phase_left2             long    $00000000
left                    long    $00000000

' parameters from caller

_pin_left               long 0   '%ppppp         read-only
_freq_left              long 0   'long           read-only
_volume_left            long 0   'word           read-only