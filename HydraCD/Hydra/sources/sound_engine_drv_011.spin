'//////////////////////////////////////////////////////////////////////////////
' Simple sound driver, simulates the sound of an engine, synthesizes a waveform
' y = x*x along with a harmonic, gives the sound of a car/motorcycle running!
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 2.19.06
' VERSION 1.1
' COMMENTS: 
'//////////////////////////////////////////////////////////////////////////////

CON

  rate          = 22050         ' sample rate to update the sound output at

VAR

  long  cogon, cog

PUB start(sound_ptr) : okay

'' Start sound driver - starts a cog
'' returns false if no cog available
'' sound_ptr base address of sound parameters
'' parameters from caller
''_pin_left               long    $0   ' 0 - 31
''_freq_left              long    $0   ' any 32-bit value, but only a small range of values will be audible
''_volume_left            long    $0   ' $0000-FFFF, unused in this version of drivers, always FULL volume

  stop
  okay := cogon := (cog := cognew(@entry,sound_ptr)) > 0


PUB stop
'' Stop sound driver - frees a cog
  if cogon~
    cogstop(cog)


DAT

'//////////////////////////////////////////////////////////////////////////////
' Assembly language "engine" sound driver 
'//////////////////////////////////////////////////////////////////////////////

                        org
' Entry
'
entry                   mov     cntacc,cnt              ' init cntacc
                        add     cntacc,cntadd           ' add to counter number of cycles such that this loop executes at a rate of 22050 Hz

:loop
                        mov     t2, par                 ' retrieve parameter values from caller
                        rdlong  _pin, t2                ' pin # to output signal           
                        add     t2, #4
                        rdlong  _freq, t2               ' frequency to play
                        add     t2, #4
                        rdlong  _volume, t2             ' volume (unused in this demo)

                        mov     t1, #1                  ' convert pin # into bit position
                        shl     t1, _pin        

                        or      dira, t1                ' set general direction of I/O to output without disturbing other settings
                        movs    ctra, _pin              ' set cntr A pin to the hydra's output pin
                        movi    ctra, #%0_00110_000     ' duty cycle mode "00110", single ended

                        ' the idea is to square the phase accumlator
                        mov     t1, phase               ' calculate samples
                        shr     t1, #32-16              ' scale the phase down to fit into 16 bits
                        mov     t2, t1
                        call    #multiply
                        mov     output_amp, t1          ' final output = scale*(phase*phase)

                        ' same thing with phase2 accumulator which is a harmonic 
                        mov     t1, phase2              ' calculate samples
                        shr     t1, #32-16              ' scale the phase down to fit into 16 bits
                        mov     t2, t1
                        call    #multiply

                        add     output_amp, t1                ' sun both harmonics final output = scale*[(phase*phase) +(phase2*phase2) ] 

                        waitcnt cntacc, cntadd          ' wait for count sync

                        add     phase, _freq            ' update phase (fundamental)                                                        
                        
                        mov     t1, _freq               ' compute 1/2 harmonic 
                        shr     t1, #2
                        add     phase2, t1              ' update phase2 (harmonic)

                        mov     frqa, output_amp        ' update channel output counter

                        jmp     #:loop                  ' loop infinitely

' /////////////////////////////////////////////////////////////////////////////

' 16x16 Multiply function (unrolled), simply performs a "shift-add" multiply
'
'   input:      t1 = 16-bit multiplicand (t1[31..16] must be 0)
'               t2 = 16-bit multiplier
'
'   output:     t1 = 32-bit product (t1*t2)
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

' /////////////////////////////////////////////////////////////////////////////

' variables and locals

cntadd                  long    80_000_000 / 22_050 ' clock frequency is hard coded here (roughly 3628 clocks per synthesis cycle)
cntacc                  long    $0

' temporary registers
t1                      long    $0
t2                      long    $0
t3                      long    $0

' PWM variables
phase                   long    $00000000       ' phase accumulator for fundamental
phase2                  long    $00000000       ' phase accumulator for harmonic
output_amp              long    $00000000       ' final summed output amplitude

' parameters from caller
_pin                    long    $0   ' 0 - 31
_freq                   long    $0   ' any 32-bit value, but only a small range of values will be audible
_volume                 long    $0   ' $0000-FFFF, unused in this version of drivers, always FULL volume