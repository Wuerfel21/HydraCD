' //////////////////////////////////////////////////////////////////////
' HEL_TEST_002.SPIN - Hel video driver test bed
' VERSION: 0.1
' AUTHOR: Andre' LaMothe
' LAST MODIFIED:
' COMMENTS:
'
'
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x          ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000      ' set frequency to 10 MHZ plus some error    
  _stack   = 128                    ' accomodate display memory and stack

  FNTSC         = 3_579_545     'NTSC color frequency
  LNTSC         = 3584          'NTSC color cycles per line (224) * 16
  SNTSC         = 624           'NTSC color cycles per sync (39) * 16
  VNTSC         = LNTSC-SNTSC   'NTSC color cycles per active video * 16

  ' register indexes
  CLKFREQ_REG = 0

'///////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

VAR

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

OBJ

'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB Start
' This is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

  
  cognew(@entry, 0)

' parent COG will terminate now...

DAT

' /////////////////////////////////////////////////////////////////////////////
' ASSEMBLY LANGUAGE VIDEO DRIVER
' /////////////////////////////////////////////////////////////////////////////

                        org $000

' /////////////////////////////////////////////////////////////////////////////
' Entry point
' /////////////////////////////////////////////////////////////////////////////

entry
  

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
                        mov     r2, #5

next_frame              ' start of new frame of 262 scanlines, no overscan no half line, to hell with the NTSC/PAL spec!

                        mov     r1, #262-18                                     ' set # of visible scanlines to do, no over/underscan for now

' Horizontal Scanline Loop (r1 itterations)
next_scanline

                        ' HSYNC 10.9us (Horizontal Sync) including color burst
                        mov     vscl, v_shsync
                        waitvid v_chsync, v_phsync

                        ' HVIS 52.6us (Visible Scanline) draw 16 huge pixels
                        mov     vscl, v_shvis
                        waitvid v_chvis , v_phvis 
                        
                        
                        djnz    r1, #next_scanline

                        djnz    r2, #no_scroll
                        ror     v_phvis, #2
                        mov     r2, #5
no_scroll               
                        
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

' tv DAC port bit mask
tvport_mask             long                    %0000_0111 << 24

' hsync VSCL value
v_shsync                long                    ((SNTSC >> 4) << 12) + SNTSC

' hsync colors
                                                '3  2  1  0   <- color indexes
v_chsync                long                    $00_00_02_8A ' SYNC (3) / SYNC (2) / BLACKER THAN BLACK (1) / COLOR BURST (0)

' hsync pixels
                                                ' BP  |BURST|BW|    SYNC      |FP| <- Key BP = Back Porch, Burst = Color Burst, BW = Breezway, FP = Front Porch
v_phsync                long                    %%1_1_0_0_0_0_1_2_2_2_2_2_2_2_1_1

' active video values
v_shvis                 long                    ((VNTSC >> 4) << 12) + VNTSC
v_chvis                 long                    $5A_0A_0B_0C                    ' each 2-bit pixel below references one of these 4 colors, (msb) 3,2,1,0 (lsb)
v_phvis                 long                    %%3210_0123_3333_3333           ' 16-pixels, read low to high is rendered left to right, 2 bits per pixel

' vsync pulses 6x High, 6x Low, 6x High
v_pvsync_high_1         long                    %%1_1_1_1_1_1_1_1_1_1_1_2_2_2_1_1  
v_pvsync_high_2         long                    %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

v_pvsync_low_1          long                    %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_1_1
v_pvsync_low_2          long                    %%1_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
  
v_freq                  long                    FNTSC