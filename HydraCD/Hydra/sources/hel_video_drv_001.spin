' //////////////////////////////////////////////////////////////////////
' HEL_VIDEO_DRV_001.SPIN - HEL Graphics Engine Video Driver
' VERSION: 0.1
' AUTHOR: Andre' LaMothe
' LAST MODIFIED:
' COMMENTS:
'
'
'
' //////////////////////////////////////////////////////////////////////


CON

  FNTSC         = 3_579_545     'NTSC color frequency
  LNTSC         = 3584          'NTSC color cycles per line (224) * 16
  SNTSC         = 624           'NTSC color cycles per sync (39) * 16
  VNTSC         = LNTSC-SNTSC   'NTSC color cycles per active video * 16

  ' register indexes
  CLKFREQ_REG = 0
  
VAR

  long  cogon, cog


PUB start(hel_ptr) : okay

'' Start hel driver - starts a cog
'' returns false if no cog available
''

  stop
  okay := cogon := (cog := cognew(@entry, hel_ptr)) > 0


PUB stop

'' Stop TV driver - frees a cog

  if cogon~
    cogstop(cog)


DAT

' /////////////////////////////////////////////////////////////////////////////
' ASSEMBLY LANGUAGE
' /////////////////////////////////////////////////////////////////////////////

                        org $000

' /////////////////////////////////////////////////////////////////////////////
' Entry point
' /////////////////////////////////////////////////////////////////////////////

entry
  
                        or      r0, #1                             wz, nr ' clear Z flag to transmit initialize command, do not write results
                        call    #debug_led_glow                           ' glow the led                            


                        ' VCFG: setup Video Configuration register and 3-bit TV DAC pins to outputs
                        
                        movs    vcfg, #%0000_0111                               ' vcfg S = pinmask  (pin31 ->0000_0111<-pin24), only want lower 3-bits
                        movd    vcfg, #3                                        ' vcfg D = pingroup (Hydra uses group 3, pins 24-31)
                        movi    vcfg, #%0_10_1_01_000                           ' vcfg I = controls overall setting, we want baseband video on bottom nibble, 2-bit color, enable chroma on broadcast & baseband
                        or      dira, tvport_mask                               ' set DAC pins to output 24, 25, 26

                        ' CTRA: setup Frequency to Drive Video                        
                        movi    ctra,#%00001_111                                ' pll internal routed to Video, PHSx+=FRQx (mode 1) + pll(16x)
                                                                                ' needn't set D,S fields since they set pin A/B I/Os, but mode 1 is internal, thus irrelvant

                        ' compute the value to place in FREQ such 
                        mov     r1, v_freq                                      ' r1 <- TV color burst frequency in Hz, eg. 3_579_545                                             
                        rdlong  r2, #CLKFREQ_REG                                ' r2 <- CLKFREQ is register 0, eg. 80_000_000

                        call    #dividefract                                    ' perform r3 = 2^32 * r1 / r2
                        mov     frqa, r3                                        ' set frequency for counter such that bit 31 is toggling at a rate of the color burst (2x actually)
                                                                                ' which means that the freq number added at a rate of CLKFREQ (usually 80.000 Mhz) results in a
                                                                                ' pll output of the color burst, this is further multiplied by 16 as the final PLL output
                                                                                ' thus giving the chroma hardware the clock rate of 16X color burst which is what we want :)
                        

next_frame              ' start of new frame of 262 scanlines, no overscan no half line, to hell with the NTSC/PAL spec!

                        rdlong debug_led_brightness, par                        ' copy hel_debug value from mainline into brightness local variable

                        mov     r1, #262-18                                     ' set # of visible scanlines to do, no over/underscan for now

' Horizontal Scanline Loop (r1 itterations)
next_scanline

                        ' HSYNC 10.9us (Horizontal Sync) including color burst
                        mov     vscl, v_shsync
                        waitvid v_chsync, v_phsync

                        ' HVIS 52.6us (Visible Scanline) draw 16 huge pixels
                        mov     vscl, v_shvis
                        waitvid v_chvis , v_phvis 


                        and     r0, #0                             wz, nr ' set Z flag to transmit run command, do not write results
                        call    #debug_led_glow                           ' glow the led                            
        
                
                        djnz    r1, #next_scanline
' End of Horizontal Scanline Loop

                        ' VSYNC Pulse (Vertical Sync)
                        ' 18 scanlines: 6 'high syncs', 6 'low syncs', and finally another 6 'high syncs'

                        call    #vsync_high
                        call    #vsync_low
                        call    #vsync_high

                        
                        jmp #next_frame
                        
'//////////////////////////////////////////////////////////////////////////////
' SUB-ROUTINES VARIABLE DECLARATIONS
'//////////////////////////////////////////////////////////////////////////////

' /////////////////////////////////////////////////////////////////////////////

debug_led_glow
' glows the debuging led at a rate transmitted from the mainline
' also initializes the led output based on incoming commands passed via Z flag
' Z = 0 means initialize funtionality
' Z = 1 glow led normal operation

                        ' setup Debug LED pin (pin 0) to output
        if_nz           or      dira, debug_led_mask                            'set debug led to output
        if_nz           jmp     #debug_led_glow_ret


                        ' process debug LED intensity (PWM trick).
                        add     debug_led_ctr, debug_led_brightness wc

        if_c            or  outa, debug_led_mask                        'on carry Full Power (ON)
        if_nc           and outa, debug_led_nmask                       'else No Power (OFF)

debug_led_glow_ret      ret


' /////////////////////////////////////////////////////////////////////////////
' vsync_high: Generate 'HIGH' vsync signal for 6 horizontal lines.
vsync_high              
'vsync                  
                        mov     r1, #6
                        
                        ' HSYNC 10.9us (Horizontal Sync)
:vsync_loop             mov     vscl, v_shsync
                        waitvid v_chsync, v_pvsync_high_1

                        ' HVIS 52.6us (Visible Scanline)
                        mov     vscl, v_shvis
                        waitvid v_chsync, v_pvsync_high_2
                        djnz    r1, #:vsync_loop

vsync_high_ret          ret

' /////////////////////////////////////////////////////////////////////////////
' vsync_low: Generate 'LOW' vsync signal for 6 horizontal lines.
vsync_low
'vsync                  
                        mov     r1, #6
                        
                        ' HSYNC 10.9us (Horizontal Sync)
:vsync_loop             mov     vscl, v_shsync
                        waitvid v_chsync, v_pvsync_low_1

                        ' HVIS 52.6us (Visible Scanline)
                        mov     vscl, v_shvis
                        waitvid v_chsync, v_pvsync_low_2
                        djnz    r1, #:vsync_loop

vsync_low_ret           ret

' /////////////////////////////////////////////////////////////////////////////
' Perform 2^32 * r1/r2, result stored in r3 (useful for TV calc)
' This is taken from the tv driver.
' NOTE: It divides a bottom heavy fraction e.g. 1/2 and gives the result as a 32-bit fraction.
dividefract                                     
                        mov     r0,#32+1
:loop                   cmpsub  r1,r2           wc
                        rcl     r3,#1
                        shl     r1,#1
                        djnz    r0,#:loop

dividefract_ret         ret                             

'//////////////////////////////////////////////////////////////////////////////
' VARIABLE DECLARATIONS
'//////////////////////////////////////////////////////////////////////////////

' general purpose registers
r0                      long                    $0                              ' should typically equal 0
r1                      long                    $0
r2                      long                    $0
r3                      long                    $0

' debugging output variables
debug_led_ctr           long                    $0
debug_led_brightness    long                    $1FFFFFFF

debug_led_mask          long                    $00000001
debug_led_nmask         long                    $FFFFFFFE


' tv DAC port bit mask
tvport_mask             long                    %0000_0111 << 24

v_color                 long                    $06050403
v_pixel                 long                    %%3210_3210_3210_3210

v_ptemp                 long                    $0
v_ctemp                 long                    $0
v_cadd                  long                    $10_10_10_10

' hsync
v_shsync                long                    ((SNTSC >> 4) << 12) + SNTSC

                                                '3  2  1  0   <- colors
v_chsync                long                    $00_00_02_8A ' SYNC (3) / SYNC (2) / BLACKER THAN BLACK (1) / COLOR BURST (0)

                                                ' BP   BURST BW     SYNC      FP       - Key BP = Back Porch, Burst = Color Burst, BW = Breezway, FP = Front Porch
v_phsync                long                    %%1_1_0_0_0_0_1_2_2_2_2_2_2_2_1_1

' hvis
v_shvis                 long                    ((VNTSC >> 4) << 12) + VNTSC
v_chvis                 long                    $CB_8B_4B_0B
v_phvis                 long                    %%3210_3210_3210_3210

' vsync pulses 6x High, 6x Low, 6x High
v_pvsync_high_1         long                     %%1_1_1_1_1_1_1_1_1_1_1_2_2_2_1_1 '%0101010101010101010101_101010_0101
v_pvsync_high_2         long                     %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1 '%01010101010101010101010101010101

v_pvsync_low_1          long                     %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_1_1' %1010101010101010101010101010_0101
v_pvsync_low_2          long                     %%1_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2' %01_101010101010101010101010101010
  
v_freq                  long                    FNTSC