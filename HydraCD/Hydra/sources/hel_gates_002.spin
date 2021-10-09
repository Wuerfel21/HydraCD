' /////////////////////////////////////////////////////////////////////////////
' HEL_GATES_002.SPIN - If you were in hell, trapped, walking the perimeter
' this is what you would see for ever and ever :)
' VERSION: 0.2
' AUTHOR: Andre' LaMothe
' LAST MODIFIED:
' COMMENTS: The actual video driver has about 45 lines of ASM, most is setup
' and to keep it legible, you could probably get it down to 20 lines if
' you worked at!
' Demo basically draws 16 blocks per each scanline, each block composed of 16
' pixels, then repeats, creating verticals bars, then they are animated
' "in place" via shifting the source pixel data.
'
' Also, good example of a single spin file with embedded ASM
'
' Couple notes:
' 1. the "call" "ret" is implemented with self modifying code
' "call #foo" hunts for "ret foo_ret", that is, with "ret" appended then
' self modifies the "ret value" with PC+1 for that "call", this is needed
' since the PChip has no stack!
'
' 2. ":" means local label
'
' 3. Excuse wide code, TABs are still not working right in IDE, usually as a rule
' I try to keep it 80 colums or less for print.
'
' 4. Remember the ASM program "lives" in the 512 longs of the COG its loaded into.
' /////////////////////////////////////////////////////////////////////////////

'//////////////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ///////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x       ' enable external clock range 5-10MHz and pll times 8
  _xinfreq = 10_000_000 + 0000   ' set frequency to 10 MHZ plus some error due to XTAL (1000-5000 usually works)
  _stack   = 128                 ' accomodate display memory and stack

  FNTSC         = 3_579_545      ' NTSC color clock frequency in HZ
  LNTSC         = 3584           ' NTSC color cycles per line (224) * 16
  SNTSC         = 624            ' NTSC color cycles per sync (39) * 16
  VNTSC         = LNTSC-SNTSC    ' NTSC color cycles per active video * 16

  ' register indexes
  CLKFREQ_REG = 0               ' register address of global clock frequency

' /////////////////////////////////////////////////////////////////////////////
' COG INTERPRETER STARTS HERE...///////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

PUB Start
' This is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

  ' launch a COG with ASM video driver and NULL pointer for parameters
  cognew(@HEL_Video_Driver_Entry, 0)

' parent COG will terminate now...

DAT

' /////////////////////////////////////////////////////////////////////////////
' ASSEMBLY LANGUAGE VIDEO DRIVER
' /////////////////////////////////////////////////////////////////////////////

                        org $000                ' set the code emission for COG add $000

' /////////////////////////////////////////////////////////////////////////////
' Entry point
' /////////////////////////////////////////////////////////////////////////////

HEL_Video_Driver_Entry

                        ' VCFG: setup Video Configuration register and 3-bit TV DAC pins to outputs
                        
                        movs    vcfg, #%0000_0111                               ' vcfg S = pinmask  (pin31 ->0000_0111<-pin24), only want lower 3-bits
                        movd    vcfg, #3                                        ' vcfg D = pingroup (Hydra uses group 3, pins 24-31)
                        movi    vcfg, #%0_10_1_01_000                           ' vcfg I = controls overall setting, we want baseband video on bottom nibble, 2-bit color, enable chroma on broadcast & baseband
                        or      dira, tvport_mask                               ' set DAC pins to output 24, 25, 26

                        ' CTRA: setup Frequency to Drive Video                        
                        movi    ctra,#%00001_111                                ' pll internal routed to Video, PHSx+=FRQx (mode 1) + pll(16x)
                                                                                ' needn't set D,S fields since they set pin A/B I/Os, but mode 1 is internal, thus irrelvant

                        ' compute the value to place in FREQ such that the final counter
                        ' output is NTSC and the PLL output is 16*NTSC
                        mov     r1, v_freq                                      ' r1 <- TV color burst frequency in Hz, eg. 3_579_545                                             
                        rdlong  r2, #CLKFREQ_REG                                ' r2 <- CLKFREQ is register 0, eg. 80_000_000

                        call    #Dividefract                                    ' perform r3 = 2^32 * r1 / r2
                        mov     frqa, r3                                        ' set frequency for counter such that bit 31 is toggling at a rate of the color burst (2x actually)
                                                                                ' which means that the freq number added at a rate of CLKFREQ (usually 80.000 Mhz) results in a
                                                                                ' pll output of the color burst, this is further multiplied by 16 as the final PLL output
                                                                                ' thus giving the chroma hardware the clock rate of 16X color burst which is what we want :)

                        mov     r2, #5                                          ' how often to animate scrolling pixels

Next_Frame              ' start of new frame of 262 scanlines, no overscan no half line, to hell with the NTSC/PAL spec!

                        mov     r1, #262-18                                     ' set # of visible scanlines to do, no over/underscan for now

' Horizontal Scanline Loop (r1 itterations)
Next_Scanline
        
                        ' HSYNC 10.9us (Horizontal Sync) including color burst
                        mov     vscl, v_shsync                                  ' set the video scale register such that 16 serial pixels takes 39 color clocks (the total time of the hsync and burst)
                        waitvid v_chsync, v_phsync                              ' send out the pixels and the colors, the pixels are 0,1,2,3 that index into the colors, the colors are blank, sync, burst
                                                                                ' we use them to create the hsync pulse itself
                        ' HVIS 52.6us (Visible Scanline) draw 16 huge pixels
                        mov     vscl, v_shvis                                   ' set up the video scale so the entire visible scan is composed of 16 huge pixels
                        waitvid v_chvis , v_phvis                               ' draw 16 pixels with red and blues
                        
                        
                        djnz    r1, #Next_Scanline                              ' are we done with the active scan portion of the frame?

                        ' the animation section... 3 lines!
                        djnz    r2, #No_Scroll
Scroll                  ror     v_phvis, #2                                     ' here we simple rotate the pixels in place creating an "animation" :)
                        mov     r2, #5
No_Scroll               
                        
' End of Horizontal Scanline Loop

                        ' VSYNC Pulse (Vertical Sync)
                        ' 18 scanlines: 6 'high syncs', 6 'low syncs', and finally another 6 'high syncs'
                        ' refer to NTSC spec, but this makes up the equalization pulses needed for a vsync
                        call    #Vsync_High
                        call    #Vsync_Low
                        call    #Vsync_High
                        
                        jmp     #Next_Frame                                      ' that's it, do it a googleplex times...
                        
'//////////////////////////////////////////////////////////////////////////////
' SUB-ROUTINES VARIABLE DECLARATIONS
'//////////////////////////////////////////////////////////////////////////////

' /////////////////////////////////////////////////////////////////////////////
' vsync_high: Generate 'HIGH' vsync signal for 6 horizontal lines.
Vsync_High              
'vsync                  
                        mov     r1, #6
                        
                        ' HSYNC 10.9us (Horizontal Sync)
:Vsync_Loop             mov     vscl, v_shsync
                        waitvid v_chsync, v_pvsync_high_1

                        ' HVIS 52.6us (Visible Scanline)
                        mov     vscl, v_shvis
                        waitvid v_chsync, v_pvsync_high_2
                        djnz    r1, #:Vsync_Loop

Vsync_High_Ret          ret

' /////////////////////////////////////////////////////////////////////////////
' vsync_low: Generate 'LOW' vsync signal for 6 horizontal lines.
Vsync_Low
'vsync                  
                        mov     r1, #6
                        
                        ' HSYNC 10.9us (Horizontal Sync)
:Vsync_Loop             mov     vscl, v_shsync
                        waitvid v_chsync, v_pvsync_low_1

                        ' HVIS 52.6us (Visible Scanline)
                        mov     vscl, v_shvis
                        waitvid v_chsync, v_pvsync_low_2
                        djnz    r1, #:Vsync_Loop

Vsync_Low_Ret           ret

' /////////////////////////////////////////////////////////////////////////////
' Calculates 2^32 * r1/r2, result stored in r3, r1 must be less that r2, that is, r1 < r2
' the results of the division are a binary weighted 32-bit fractional number where each bit
' is equal to the following weights:
' MSB (31)    30    29 ..... 0
'      1/2   1/4   1/8      1/2^32
' the results of this division are useful when computing the frequency value to program
' into the video timing chain, for example, given that the counters are 32 bits, and the
' system is running at 80_000_000HZ, and we want the finatl counter to run at 3_579_545 HZ
' i.e, the color burst frequency, what number should be put into FREQ? The answer
' is 2^32 * 3_579_545 / 80_000_000 = 192175358 as an integer
' Also, if we do the real valued division we get 3_579_545 / 80_000_000 = .044744312
' (calculator result)

' if you look at it as a binary fraction then
' you have this string of digits:  0000 1 0 11 0 111 0 1 000 1 0 111 00 1111111 0
' considering the leftmost or MSB digit is the 1/2^1 place and then summing the result we get
'   0*1/2^1 + 0*1/2^2 + 0*1/2^3 + 0*1/2^4 + 1*1/2^5 + 0*1/2^6 + 1*1/2^7 + 1*1/2^8 +
'   0*1/2^9 + 1*1/2^10 + 1*1/2^11 + 1*1/2^12 + 0*1/2^13 + 1*1/2^14 + 0*1/2^15 + 0*1/2^16 +
'   0*1/2^17 + 1*1/2^18 + 0*1/2^19 + 1*1/2^20 + 1*1/2^21 + 1*1/2^22 + 0*1/2^23 + 0*1/2^24 +
'   1*1/2^25 + 1*1/2^26 + 1*1/2^27 + 1*1/2^28 + 1*1/2^29 + 1*1/2^30 + 1*1/2^31 + 0*1/2^32
' = 0.0447443122975528 (computer results of sum)
'
' as you can see the binary fraction is correct, now considering that, then reviewing the integer
' interpretation of 192175358, if this number if summed in PHSx at a rate of 80_000_000 in a
' 32-bit counter, this results in the MSB(31) bit clocking at a rate of 3_579_545!  

' Lets confirm, by dividing the total range of the counter 2^32 by the magic number
' = 4294967296 / 192175358 = 22.34929929
' so, 22 and some change, consider that, we are clocking at 80_000_000 HZ and it
' takes 22.34929929 counts before we toggle the MSB(31) then that means that 80/22.349...
' is the output frequency which doing the math is equal to 3.57954.. MHz which is exactly
' what we were looking for. Hopefully, this long odyssey proves to you that all the math
' works out in a number of ways :) I only wrote this since many people still have trouble
' understanding binary division, fractions, and their relationship to counters etc.
' hopefully this example helped a bit since graphics is all about timing.

Dividefract                                     
                        mov     r0,#32+1                ' 32 iterations
:Loop                   cmpsub  r1,r2           wc      ' does divisor divide into dividend?
                        rcl     r3,#1                   ' rotate carry into result
                        shl     r1,#1                   ' shift dividend over
                        djnz    r0,#:Loop               ' done with division yet?

Dividefract_Ret         ret                             ' return to caller with result in r3

'//////////////////////////////////////////////////////////////////////////////
' VARIABLE DECLARATIONS
'//////////////////////////////////////////////////////////////////////////////

' general purpose registers
r0                      long                    $0                             
r1                      long                    $0
r2                      long                    $0
r3                      long                    $0

' tv output DAC port bit mask
tvport_mask             long                    %0000_0111 << 24                ' Hydra DAC is on bits 24, 25, 26

' hsync VSCL value (clocks per pixel 8 bits | clocks per frame 12 bits )
v_shsync                long                    ((SNTSC >> 4) << 12) + SNTSC

' hsync colors (4, 8-bit values, each represent a color in the format chroma shift, chroma modulatation enable, luma | C3 C2 C1 C0 | M | L2 L1 L0 |
                                                '3  2  1  0   <- color indexes
v_chsync                long                    $00_00_02_8A ' SYNC (3) / SYNC (2) / BLACKER THAN BLACK (1) / COLOR BURST (0)

' hsync pixels
                                                ' BP  |BURST|BW|    SYNC      |FP| <- Key BP = Back Porch, Burst = Color Burst, BW = Breezway, FP = Front Porch
v_phsync                long                    %%1_1_0_0_0_0_1_2_2_2_2_2_2_2_1_1

' active video values
v_shvis                 long                    ((VNTSC >> 4) << 12) + VNTSC

' the colors used, 4 of them always
                                               'red, color 3 | dark blue, color 2 | blue, color 1 | light blue, color 0
v_chvis                 long                    $5A_0A_0B_0C                    ' each 2-bit pixel below references one of these 4 colors, (msb) 3,2,1,0 (lsb)

' the pixel pattern
v_phvis                 long                    %%3210_0123_3333_3333           ' 16-pixels, read low to high is rendered left to right, 2 bits per pixel
                                                                                ' the numbers 0,1,2,3 indicate the "colors" to use for the pixels, the colors
                                                                                ' are defined by a single byte each with represents the chroma shift, modulation,
                                                                                ' and luma
' vsync pulses 6x High, 6x Low, 6x High
' the vertical sync pulse according to the NTSC spec should be composed of a series
' of pulses called the pre-equalization, serration pulses (the VSYNC pulse itself), and the post-equalization pulses
' there are 6 pulses of each, and they more or less inverted HSYNC, followed by 6 HSYNC pulses, followed by 6 more inverted HSYNC pulses.
' this keeps the horizontal timing circutry locked as well as allows the 60 Hz VSYNC filter to catch the "vsync" event.
' the values 1,2 index into "colors" that represent sync and blacker than black.
' so the definitions below help with generated the "high" and "low" dominate HSYNC timed pulses which are combined
' to generated the actual VSYNC pulse, refer to NTSC documentation for more details.
v_pvsync_high_1         long                    %%1_1_1_1_1_1_1_1_1_1_1_2_2_2_1_1  
v_pvsync_high_2         long                    %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

v_pvsync_low_1          long                    %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_1_1
v_pvsync_low_2          long                    %%1_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
  
v_freq                  long                    FNTSC

' END ASM /////////////////////////////////////////////////////////////////////