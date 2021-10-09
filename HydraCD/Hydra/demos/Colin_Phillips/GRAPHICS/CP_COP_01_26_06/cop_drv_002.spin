''*****************************
''*  COP Driver v0.2          *
''*  Colin Phillips           *
''*****************************
'

CON

  fntsc         = 3_579_545     'NTSC color frequency
  lntsc         = 3640          'NTSC color cycles per line * 16
  sntsc         = 624           'NTSC color cycles per sync * 16
  vntsc         = lntsc-sntsc

  fpal          = 4_433_618     'PAL color frequency
  lpal          = 4540          'PAL color cycles per line * 16
  spal          = 848           'PAL color cycles per sync * 16
  vpal          = lpal-spal

  #0, h_cop_status, h_cop_control, h_cop_debug
  
VAR

  long  cogon, cog


PUB start(copptr) : okay

'' Start COP driver - starts a cog
'' returns false if no cog available
''
''   tvptr = pointer to TV parameters

  stop
  okay := cogon := (cog := cognew(@entry,copptr)) > 0


PUB stop

'' Stop TV driver - frees a cog

  if cogon~
    cogstop(cog)


DAT

'********************************
'* Assembly language COP driver *
'********************************

                        org
'
'
' Entry

entry
                        ' setup Debug LED pin (pin 0) to output
                        or      dira, debugled_mask                             'set debug led to output

                        ' VCFG: setup Video Configuration register and 3-bit tv DAC pins to output
                        movs    vcfg, #%0000_0111                               ' vcfg'S = pinmask (pin31: 0000_0111 : pin24)
                        movd    vcfg, #3                                        ' vcfg'D = pingroup (grp. 3 i.e. pins 24-31)
                        movi    vcfg, #%010111_000                              ' baseband video on bottom nibble, 2-bit color, enable chroma on broadcast & baseband
                        or      dira, tvport_mask                               ' set DAC pins to output

                        ' CTRA: setup Frequency to Drive Video
                        movi    ctra,#%00001_111                                ' pll internal routed to Video, PHSx+=FRQx (mode 1) + pll(16x)
                        mov     r1, v_freq                                      ' r1: TV frequency in Hz
                        rdlong  r2,#0                                           ' r2: CLKFREQ
                        call    #dividefract                                    ' perform r3 = 2^32 * r1 / r2
                        mov     frqa, r3                                        ' set frequency for counter
                        

                        mov     v_frame, #0
next_frame              ' start of new frame

                        ' get debug value for intensity of RED LED
                        mov     r1, par                                         ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_debug*4                              ' reference cop_debug

                        rdlong  debugled_brightness,r1                          ' copy cop_debug into brightness var.

                        ' render 24 black lines (top overscan)
                        mov     r1, #24
                        
                        ' HSYNC 10.9us (Horizontal Sync)
:vsync_loop             mov     vscl, v_shsync
                        waitvid v_chsync, v_phsync

                        ' HVIS 52.6us (Visible Scanline)
                        mov     vscl, v_shvis
                        waitvid v_chsync, v_pvsync_high_2

                        call    #process_debugled
                        djnz    r1, #:vsync_loop


                        ' reset pattern
                        mov     r2, #0
                        mov     r3, #0
                        mov     v_ptemp, v_phvis
                        mov     v_ctemp, v_chvis

                        ' make pattern scroll vertically based on 'frame & debugled's brightness': toggle movement pattern every 128 frames.
                        test    v_frame, #256                                   wz

if_z                    neg     r1, debugled_brightness
if_z                    shr     r1, #26
                        
if_nz                   neg    r1, v_frame
if_nz                   and    r1, #127
                        
' Horizontal Scanline Loop (r1 itterations)
                        mov     v_scanline, #0
next_scanline                        
                        ' HSYNC 10.9us (Horizontal Sync)
                        mov     vscl, v_shsync
                        waitvid v_chsync, v_phsync

                        ' HVIS 52.6us (Visible Scanline)
                        mov     vscl, v_scale
                        mov     v_color, v_ctemp
                        waitvid v_color, v_pixel                        
                        add     v_color, v_cadd4
                        waitvid v_color, v_pixel
                        add     v_color, v_cadd4
                        waitvid v_color, v_pixel
                        add     v_color, v_cadd4
                        waitvid v_color, v_pixel
                          
                        ' increase color intensity every 16 lines (5 racks color, 5 racks gray and back again)
                        cmp     v_scanline, r1                                             wc
                        
        if_c            jmp     #skip_patternstart
                        
                        add     r2, #1
                        cmp     r2, #16                            wz
        if_z            mov     r2, #0
        if_z            add     v_ctemp, v_cadd
        if_z            add     r3, #1
                        cmp     r3, #5                             wz
        if_z            add     v_ctemp, v_cadd
        if_z            add     v_ctemp, v_cadd
        if_z            add     v_ctemp, v_cadd
        if_z            mov     r3, #0                        

skip_patternstart

                        call    #process_debugled

                        add     v_scanline, #1
                        cmp     v_scanline, #262-18-24-18          wz
        if_nz           jmp     #next_scanline
        
' End of Horizontal Scanline Loop


                        ' render 18 black lines (bottom overscan)
                        mov     r1, #18
                        
                        ' HSYNC 10.9us (Horizontal Sync)
:vsync_loop             mov     vscl, v_shsync
                        waitvid v_chsync, v_phsync

                        ' HVIS 52.6us (Visible Scanline)
                        mov     vscl, v_shvis
                        waitvid v_chsync, v_pvsync_high_2

                        call    #process_debugled
                        djnz    r1, #:vsync_loop


                        ' VSYNC Pulse (Vertical Sync)
                        ' 18 scanlines: 6 'high syncs', 6 'low syncs', and finally another 6 'high syncs'
                        call    #vsync_high
                        call    #vsync_low
                        call    #vsync_high
                        
                        'mov    vscl, v_shhalf
                        'waitvid v_chsync, v_pvsync_high_2

                        add     v_frame, #1
                        
                        jmp #next_frame
                        
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

                        call    #process_debugled
                        djnz    r1, #:vsync_loop

vsync_high_ret          ret

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

                        call    #process_debugled
                        djnz    r1, #:vsync_loop

vsync_low_ret           ret
                        


'
' Perform 2^32 * r1/r2, result stored in r3 (useful for TV calc)
' This is taken from the tv driver.
' NOTE: It divides a bottom heavy fraction e.g. 1/2 and gives the result as a 32-bit fraction.
'

dividefract                                     
                        mov     r0,#32+1
:loop                   cmpsub  r1,r2           wc
                        rcl     r3,#1
                        shl     r1,#1
                        djnz    r0,#:loop

dividefract_ret         ret                             '+140

process_debugled        
                        ' process debug LED intensity (duty cycle trick).
                        add     debugled_ctr, debugled_brightness  wc

        if_c            or      outa, debugled_mask                             'on carry Full Power (ON)
        if_nc           and     outa, debugled_nmask                            'else No Power (OFF)

process_debugled_ret    ret


r0                      long                    $0                              ' should typically equal 0
r1                      long                    $0
r2                      long                    $0
r3                      long                    $0
debugled_ctr            long                    $0
debugled_brightness     long                    $0
debugled_mask           long                    $00000001
debugled_nmask          long                    $fffffffe
tvport_mask             long                    %0000_0111<<24

v_scale                 long                    vntsc >> 4 << 12 + vntsc/4
v_color                 long                    $0
v_pixel                 long                    %%0000_0000_0000_3210

v_ptemp                 long                    $0
v_ctemp                 long                    $0
v_cadd                  long                    $01_01_01_01
v_cadd4                 long                    $40_40_40_40

' hsync
v_shsync                long                    sntsc >> 4 << 12 + sntsc
v_chsync                long                    $00_00_02_8A
v_phsync                long                    %0101_00000000_01_10101010101010_0101

' hvis
v_shvis                 long                    vntsc >> 4 << 12 + vntsc
v_chvis                 long                    $3a2a1a0a
v_phvis                 long                    %%3210_3210_3210_3210

' hline
v_shline                long                    lntsc >> 4 << 12 + lntsc
v_chline                long                    $00_00_02_8A
v_phline                long                    %%3210_3210_3210_3210

' hhalf
v_shhalf                long                    lntsc/2

' vsync pulses 6x High, 6x Low, 6x High
v_pvsync_high_1         long                    %0101010101010101010101_101010_0101
v_pvsync_high_2         long                    %01010101010101010101010101010101
v_pvsync_low_1          long                    %1010101010101010101010101010_0101
v_pvsync_low_2          long                    %01_101010101010101010101010101010

v_freq                  long                    fntsc
v_frame                 long                    $0
v_scanline              long                    $0