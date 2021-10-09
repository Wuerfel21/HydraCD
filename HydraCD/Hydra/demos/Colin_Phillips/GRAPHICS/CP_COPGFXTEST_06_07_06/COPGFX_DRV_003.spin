' //////////////////////////////////////////////////////////////////////
' COPGFX Driver (2nd itteration tv-graphics engine)
' AUTHOR: Colin Phillips
' LAST MODIFIED: 6.07.06
' VERSION 0.3

CON

  _memstart = $0
  
' Video (TV) Related Constants
  fntsc         = 3_579_545     'NTSC color frequency
  lntsc         = 3640          'NTSC color cycles per line * 16
  sntsc         = 624           'NTSC color cycles per sync * 16
  vntsc         = lntsc-sntsc   '3016
  pix_ntsc      = 16 '10        'vntsc/256 '(11 pulses per pixel) changed to 10 gives 2.2us extra on Left, and 2.2us extra on Right
  frame_ntsc    = pix_ntsc*4    '4 pixels per frame (44 pulses per frame)
  framecnt_ntsc = 40 '64        '64 frames = 256 pixels wide.
  overscan_ntsc = vntsc-framecnt_ntsc*frame_ntsc        ' 3016 - 256*11 = 200
  backporch_ntsc = overscan_ntsc/2
  frontporch_ntsc = overscan_ntsc - overscan_ntsc/2
  fields_ntsc   = 262                                   ' 262 should be 38 left over (for 256x224 res.)
  top_fields_ntsc               = 10                    ' 10
  bottom_fields_ntsc            = 10                    ' 10
  vsync_fields_ntsc             = 18                    ' 18
  active_fields = fields_ntsc-top_fields_ntsc-bottom_fields_ntsc-vsync_fields_ntsc

' TODO: Cater for PAL
  fpal          = 4_433_618     'PAL color frequency
  lpal          = 4540          'PAL color cycles per line * 16
  spal          = 848           'PAL color cycles per sync * 16
  vpal          = lpal-spal

' Graphics Related Constants
  debugled_mask = $00000001
  scanline_buf = $0
  cog_n         = 4             ' 4+1 cogs. (4 scanline generation, 1 video output)
  fix_prec      = 6             ' 6 bits precision, 4 bits tile (0..15), 6 bits map (0..63)

  #0, h_copgfx_status, h_copgfx_vram, h_copgfx_map, h_copgfx_bg0_s, h_copgfx_bg0_h, h_copgfx_bg0_v, h_copgfx_bg0_dh, h_copgfx_bg0_dv
  
VAR

long scanline_memory[(256 * cog_n) >>2]
long cog_copptr

  
PUB start(copptr) : okay | i, n

'' Start COPGFX driver
'' returns false if no cog available
''
''   copptr = pointer to COPGFX engine parameters

  LONG[@v_scanline_addr] := @scanline_memory
    
'   LONG[@v_scanline_addr+4] := @scanline_memory + 256
 '  LONG[@v_scanline_addr+8] := @scanline_memory + 512
  ' LONG[@v_scanline_addr+12] := @scanline_memory + 768

  ' boot preparing cogs first
  cog_copptr := copptr

  repeat i from 0 to CONSTANT(cog_n-1)
    'repeat while LONG[@copgfx_status]                  ' Wait until not Busy (booting cog)
    ' Update Registers
    LONG[@s_scanline_id] := i
    LONG[@copgfx_status] := 1                           ' Busy
    LONG[@s_scanline_buf] := @scanline_memory + i<<8
    LONG[@s_bg0_tile] := LONG[copptr+(h_copgfx_map<<2)]
    LONG[@s_bg0_vram] := LONG[copptr+(h_copgfx_vram<<2)]
    cognew(@entry_prep,copptr)
    LONG[@copgfx_status] := 0                           ' Busy
    repeat n from 0 to 10000

  ' then boot video cog
  cognew(@entry,copptr)

PUB waitvsync

'' Wait for Vertical Retrace Sync.

repeat while (LONG[cog_copptr+(h_copgfx_status<<2)] == 0) ' Wait until end of vsync (+top overscan)
repeat while LONG[cog_copptr+(h_copgfx_status<<2)]      ' Wait until end of active scanlines
  
DAT

copgfx_status           long                    $0
copgfx_idx              long                    $0

'***********************************
'* Assembly language COPGFX driver *
'* Video Generator                 *
'***********************************

                        org
'
'
' Entry
entry                   call    #initialize

next_frame              ' start of new frame

' /////////////////////////////////////////////////////////////////////////////
' VSYNC Pulse (Vertical Sync) /////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' 18 scanlines: 6 'high syncs', 6 'low syncs', and finally another 6 'high syncs'

' VSYNC HIGH (6x63.5us) ///////////////////////////////////////////////////////
                        
                        call    #vsync_high             ' 6x63.5us
                        call    #vsync_low              ' 6x63.5us
                        call    #vsync_high             ' 6x63.5us

' Top Overscan ////////////////////////////////////////////////////////////////
                        
                        ' render M black lines (top overscan)
                        mov     r1, #bottom_fields_ntsc
                        call    #do_overscan                                                                                                       

                        mov     v_scanline_cur, #0
                        mov     v_scanline_taddr, v_scanline_addr
                        add     v_scanline_taddr, #(256 - framecnt_ntsc*4)/2                            ' Left indent 48 pixels (256 => 160)
                        mov     v_scanline, #0
next_scanline

' /////////////////////////////////////////////////////////////////////////////
' Serialize (Rasterize) Scanline //////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        mov     r0, #1
                        wrlong  r0, par_status                                  ' status parameter.

do_raster
                        
                        ' HSYNC 10.9us (Horizontal Sync) + some backporch added
                        mov     vscl, v_shsync
                        add     vscl, #backporch_ntsc 'make the frame bigger (the last pixel in it is Black, so we get black overscan)
                        waitvid v_chsync, v_phsync

                        wrlong  v_scanline, v_copgfx_idx                        ' scanline index.
                        wrlong  v_scanline_cur, v_copgfx_status                 ' update status
                        
' VSU Active Frame Loop ///////////////////////////////////////////////////////
' Feeds thru 4 pixels at a time. 64 itterations, i.e. 256 pixels width.
' 44 pulses / cycle (44/3016 * 52.6us = 0.76us, 0.76us * 20MIPS = 15 instructions/frame)

                        mov     vscl, v_scale
                        mov     r0, #framecnt_ntsc
                        
next_vsuframe           
                        rdlong  r1, v_scanline_taddr
                        add     r1, v_coffset
                        nop
                        waitvid r1, #%%3210                                     ' 5+ clks, feed thru 4 colors / 4 pixels
                        
                        add     v_scanline_taddr, #4                                                        
                        djnz    r0, #next_vsuframe                              ' (6) (15 max - in practice **13**, since waitvid is 5+ clks)

                        add     v_scanline_taddr, #256 - framecnt_ntsc*4        ' EXTRA GAP between scanlines. (to help with clipping)
                        add     v_scanline_cur, #1               
                        cmp     v_scanline_cur, #cog_n  wz
        if_z            mov     v_scanline_cur, #0
        if_z            mov     v_scanline_taddr, v_scanline_addr
        if_z            add     v_scanline_taddr, #(256 - framecnt_ntsc*4)/2    ' Left indent 48 pixels (256 => 160)
                        
' END /////////////////////////////////////////////////////////////////////////

' VSU Frontporch Overscan /////////////////////////////////////////////////////

                        mov     vscl, #frontporch_ntsc 'v_fp
                        add     vscl, cop_phasealter
                        waitvid v_chsync, v_pvsync_high_2 ' v_chsync                        

' END /////////////////////////////////////////////////////////////////////////                          
                        
' /////////////////////////////////////////////////////////////////////////////
' ~~~ End of Serialize (Rasterize) Scanline ///////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        add     v_scanline, #1
                        cmp     v_scanline, #active_fields wz
        if_nz           jmp     #next_scanline

                        mov     r0, #0
                        wrlong  r0, par_status                  ' status parameter.
        
                        ' render M black lines (bottom overscan)
                        mov     r1, #bottom_fields_ntsc
                        call    #do_overscan

                        add     v_frame, #1
                        
                        jmp     #next_frame


' /////////////////////////////////////////////////////////////////////////////
' do_overscan: Generate Overscan for r1 horizontal lines.
' /////////////////////////////////////////////////////////////////////////////

do_overscan

                        mov     vscl, v_shsmart         ' 10.9us <= pixel_data[0...15], 52.6us <= pixel_data[15]
:vsync_loop             ' HSYNC 10.9us (Horizontal Sync) + 52.6us (Visible Scanline) 'Black'
                        waitvid v_chsync, v_phsync                               
                        djnz    r1, #:vsync_loop

do_overscan_ret         ret

' /////////////////////////////////////////////////////////////////////////////
' vsync_high: Generate 'HIGH' vsync signal for 6 horizontal lines.
' /////////////////////////////////////////////////////////////////////////////

vsync_high              
'vsync                  
vsync_high_rep_s        mov     r1, #6
                        

:vsync_loop             ' HSYNC 10.9us (Horizontal Sync) + 52.6us (Visible Scanline) 'Black'
                        mov     vscl, v_shsmart         ' 10.9us <= pixel_data[0...15], 52.6us <= pixel_data[15]
                        waitvid v_chsync, v_pvsync_high_1                        

                        djnz    r1, #:vsync_loop

vsync_high_ret          ret

' /////////////////////////////////////////////////////////////////////////////
' vsync_low: Generate 'LOW' vsync signal for 6 horizontal lines.
' /////////////////////////////////////////////////////////////////////////////

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
' // COG registers ////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' Various Registers used by the COP engine stored here.
 
' Constants
k_bit31                 long                    $80000000
k_d0                    long                    1<<9
k_d_4                   long                    4<<9
k_d_3                   long                    16383 << 18 + 3<<9 + 511        ' mask 3
minus_255               long                    $ffffff01
minus_8                 long                    $fffffff8
mask_p0                 long                    $000000ff
mask_p1                 long                    $0000ff00
mask_p2                 long                    $00ff0000
mask_p3                 long                    $ff000000
' General Purpose Registers
r0                      long                    $0                              ' should typically equal 0
r1                      long                    $0
r2                      long                    $0
r3                      long                    $0
r4                      long                    $0
r5                      long                    $0
r6                      long                    $0
r7                      long                    $0
' Debug LED Registers
debugled_ctr            long                    $0
debugled_brightness     long                    $0
' Cop Registers
cop_status              long                    $0
' Video (TV) Registers
tvport_mask             long                    %0000_0111<<24
v_scale                 long                    pix_ntsc << 12 + frame_ntsc

' VSU phase color search
v_ccogphase             long                    $8B_8B_8B_8B                    ' Alternates 3 +/- 1 (2, 4)
v_ccogphasepin          long                    $06_00_00_00                    ' Check Luma pins for 2,4, and 6 (out of phase value)

' hsync
v_shsync                long                    sntsc >> 4 << 12 + sntsc
v_chsync                long                    $00_00_02_8A
v_phsync                long                    %0101_00000000_01_10101010101010_0101

' hvis
v_shvis                 long                    vntsc >> 4 << 12 + vntsc

' hline
v_shline                long                    lntsc >> 4 << 12 + lntsc

' does sync 10.9us (16 'colors') then does the remaining 52.6us in the last 'color' (i.e. Black)
v_shsmart               long                    sntsc >> 4 << 12 + lntsc

' vsync pulses 6x High, 6x Low, 6x High
v_pvsync_high_1         long                    %0101010101010101010101_101010_0101
v_pvsync_high_2         long                    %01010101010101010101010101010101
v_pvsync_low_1          long                    %1010101010101010101010101010_0101
v_pvsync_low_2          long                    %01_101010101010101010101010101010

v_freq                  long                    fntsc
v_frame                 long                    $0
v_scanline              long                    $0

' Graphics related vars.
v_coffset               long                    $02020202                       ' color offset (every color is added by $02)
v_cbgcolor              long                    $0a0a0a0a                       ' background color
v_clkfreq               long                    $0
v_copid                 long                    $0
v_phssync               long                    $0
v_taskid                long                    $0
v_cntnext               long                    $0
v_cntpreparelimit       long                    (1270*4 - 128*4)                ' 63.5us * 80 - safety margin
cop_phase1              long                    $0
cop_phasealter          long                    $0
v_setup                 long                    $0
v_vram                  long                    $0
v_tile                  long                    $0
v_add                   long                    $80808080
v_andm                  long                    $f0f0f0f0
v_ando                  long                    $0f0f0f0f
v_xor                   long                    $00000000 '08080808

v_scanline_addr         long                    $0
v_scanline_taddr        long                    $0
v_scanline_cur          long                    $0
v_copgfx_status         long                    _memstart+@copgfx_status
v_copgfx_idx            long                    _memstart+@copgfx_idx
par_status              long                    $0

' /////////////////////////////////////////////////////////////////////////////
' // COG data /////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' Scanline Buffer & OBJ Buffer stored here, after init.
' !!! WARNING ALL CODE BELOW IS WIPED AFTER INITIALIZATION/SETUP PHASE !!! (after 30 frames)

data_start              ' Data Starts From here (we wipe over the init code once initialization/setup phase is complete)

initialize

                        rdlong  v_clkfreq, #0                                   'copy clk frequency.

                        ' VCFG: setup Video Configuration register and 3-bit tv DAC pins to output
                        movs    vcfg, #%0000_0111                               ' vcfg'S = pinmask (pin31: 0000_0111 : pin24)
                        movd    vcfg, #3                                        ' vcfg'D = pingroup (grp. 3 i.e. pins 24-31)
                        movi    vcfg, #%010111_000                              ' baseband video on bottom nibble, 2-bit color, enable chroma on broadcast & baseband
                        or      dira, tvport_mask                               ' set DAC pins to output
                        
                        ' CTRA: setup Frequency to Drive Video
                        movi    ctra,#%00001_111                                ' pll internal routed to Video, PHSx+=FRQx (mode 1) + pll(16x)
                        mov     r1, v_freq                                      ' r1: TV frequency in Hz
                        mov     r2, v_clkfreq                                   ' r2: CLKFREQ
                        call    #dividefract                                    ' perform r3 = 2^32 * r1 / r2
                        mov     v_freq, r3                                      ' v_freq now contains frqa.
                        mov     frqa, r3                                        ' set frequency for counter

                        mov     par_status, par
                        
initialize_ret          ret

' /////////////////////////////////////////////////////////////////////////////
' dividefract:
' Perform 2^32 * r1/r2, result stored in r3 (useful for TV calc)
' This is taken from the tv driver.
' NOTE: It divides a bottom heavy fraction e.g. 1/2 and gives the result as a 32-bit fraction.
' /////////////////////////////////////////////////////////////////////////////

dividefract                                     
                        mov     r0,#32+1
:loop                   cmpsub  r1,r2           wc
                        rcl     r3,#1
                        shl     r1,#1
                        djnz    r0,#:loop

dividefract_ret         ret                             '+140


'***********************************
'* Assembly language COPGFX driver *
'* Scanline Preparation            *
'***********************************

                        org

entry_prep

                        call    #initialize_prep

next_prep               ' wait for this scanline to begin rasterizing.
                        rdlong  a0, s_copgfx_status
                        cmp     a0, s_scanline_id       wz
        if_nz           jmp     #next_prep

                        ' get index. - the first cop_n scanlines will not have data.
                        rdlong  s_scanline_idx, s_copgfx_idx

                        cmp     s_scanline_idx, s_scanline_id     wz            ' Cog's first scanline ?
        if_nz           jmp     #:not_first

                        ' Update Start position, and horiz & vert vectors.

                        mov     a0, par
                        add     a0, #h_copgfx_bg0_s*4
                        rdlong  m7_vp, a0
                        add     a0, #4
                        rdlong  m7_h_delta, a0
                        add     a0, #4
                        rdlong  m7_v_delta, a0                        
                        'add    a0, #4
                        'rdlong m7_h_delta2, a0
                        'add    a0, #4
                        'rdlong m7_v_delta2, a0                       

                        mov     m7_hp, m7_vp                                    ' horizontal start address = vertical start address. (the four cogs should have between 0.N vertical lines out of phase from scanline cog 0)
                        mov     a0, s_scanline_id                 wz
        if_z            jmp     #:skip_it
:loop_it                
                        add     m7_hp, m7_v_delta
                        'add    m7_v_delta, m7_v_delta2                        
                        djnz    a0, #:loop_it

:skip_it
:not_first

' // Scanline Preparation /////////////////////////////////////////////////////
' // for 4+1 cogs, we have 63.5us * 4 (254us) processing, which is 5080 instrs or 20 per pixel (256 active pixels)
' // or 31.75 per pixel at true 227 color clks (160 active pixes).

' // BG0: MODE 7 //////////////////////////////////////////////////////////////

' A = YYYYYYYYYYyyyyyy:XXXXXXXXXXxxxxxx (upper word Y position, lower word X position)
' S = YYYYYYYYYYyyyyyy:XXXXXXXXXXxxxxxx (frame start position)
' HS = YYYYYYYYYYyyyyyy:XXXXXXXXXXxxxxxx (scanline start position)
' HA = YYYYYYYYYYyyyyyy:XXXXXXXXXXxxxxxx (horizontal delta/pixel)
' VA = YYYYYYYYYYyyyyyy:XXXXXXXXXXxxxxxx (vertical delta/pixel)
' New Frame : HS = S
' New line : A = HS, S+=VA
' New Pixel : A+=HA
'
' Pixel translation...
' (A >> 8) & MAP_WM   (e.g. 15, 31, 63... 255 must have a mask 255 or less,)
' (A >> 24) & MAP_WH   (optional - for wrapping)
'
' TI = MAP[ (Y>>4) << MAP_WS + (X>>4) ]
' TI : (YYYYYYXXXXXX)
' TP = TILE[TI<<8 + (Y&15) << 4 + (X&15)]
' TP : (yyyyxxxx)
' X+=DX, Y+=DY

                        mov     tm7_h_delta, m7_h_delta
                        movd    :code_1a, #local_buf+(64-framecnt_ntsc)/2
                        mov     m7_p, m7_hp                                     ' current pixel address = horizontal start address.
                        mov     a7, #framecnt_ntsc                              ' Do framecnt*4 pixels (active screen width)
:loop_m7_pixel             

' ITTR #0               
                        mov     a0, m7_p                                        ' a0 = YYYYYY'YYYYyyyyyy:XXXXXX'XXXXxxxxxx
                        shr     a0, #4+fix_prec                                 
                        and     a0, _k_map_wm                                   ' a0 = XXXXXX&MAPWIDTH_MASK
                        mov     a1, m7_p
                        shr     a1, _k_map_wsn                                  ' a1 = YYYYYY(0*MAPWIDTH_SHIFT)
                        and     a1, _k_map_hm                                   ' a1 = YYYYYY(0*MAPWIDTH_SHIFT)&MAPHEIGHT_MASK
                        or      a0, a1                                          ' a0 = YYYYYYXXXXXX
                        add     a0, s_bg0_tile                                  ' tile offset.
                        rdbyte  a0, a0                                          ' a0 = BG0_TILE[a0]
                                                                                ' 9+
                        'mov    a0, #17

                        mov     a2, m7_p
                        shr     a2, #fix_prec
                        and     a2, #$0f                                        ' a2 = :000000000000XXXX
                        mov     a3, m7_p
                        shr     a3, #16+fix_prec-4
                        and     a3, #$f0                                        ' a3 = :00000000YYYY0000
                        or      a2, a3                                          ' a2 = YYYYXXXX (pixel offset)
                        shl     a0, #8                                          
                        add     a0, a2                                          ' (a0*256 + pixel offset)
                        add     a0, s_bg0_vram                                  
                        rdbyte  a0, a0                                          ' a0 = BYTE[s_bg0_vram + a0*256 + pixel offset.]
                                                                                ' 11+
                        
                        mov     a6, a0
                        ror     a6, #8

                        add     m7_p, tm7_h_delta                               ' p += h_delta
                        'add    tm7_h_delta, m7_h_delta2

' ITTR #1               
                        mov     a0, m7_p                                        ' a0 = YYYYYY'YYYYyyyyyy:XXXXXX'XXXXxxxxxx
                        shr     a0, #4+fix_prec                                 
                        and     a0, _k_map_wm                                   ' a0 = XXXXXX&MAPWIDTH_MASK
                        mov     a1, m7_p
                        shr     a1, _k_map_wsn                                  ' a1 = YYYYYY(0*MAPWIDTH_SHIFT)
                        and     a1, _k_map_hm                                   ' a1 = YYYYYY(0*MAPWIDTH_SHIFT)&MAPHEIGHT_MASK
                        or      a0, a1                                          ' a0 = YYYYYYXXXXXX
                        add     a0, s_bg0_tile                                  ' tile offset.
                        rdbyte  a0, a0                                          ' a0 = BG0_TILE[a0]
                                                                                ' 9+
                        'mov    a0, #17
                        
                        mov     a2, m7_p
                        shr     a2, #fix_prec
                        and     a2, #$0f                                        ' a2 = :000000000000XXXX
                        mov     a3, m7_p
                        shr     a3, #16+fix_prec-4
                        and     a3, #$f0                                        ' a3 = :00000000YYYY0000
                        or      a2, a3                                          ' a2 = YYYYXXXX (pixel offset)
                        shl     a0, #8                                          
                        add     a0, a2                                          ' (a0*256 + pixel offset)
                        add     a0, s_bg0_vram                                  
                        rdbyte  a0, a0                                          ' a0 = BYTE[s_bg0_vram + a0*256 + pixel offset.]
                                                                                ' 11+

                        or      a6, a0
                        ror     a6, #8

                        add     m7_p, tm7_h_delta                               ' p += h_delta
                        'add    tm7_h_delta, m7_h_delta2
                        
' ITTR #2               
                        mov     a0, m7_p                                        ' a0 = YYYYYY'YYYYyyyyyy:XXXXXX'XXXXxxxxxx
                        shr     a0, #4+fix_prec                                 
                        and     a0, _k_map_wm                                   ' a0 = XXXXXX&MAPWIDTH_MASK
                        mov     a1, m7_p
                        shr     a1, _k_map_wsn                                  ' a1 = YYYYYY(0*MAPWIDTH_SHIFT)
                        and     a1, _k_map_hm                                   ' a1 = YYYYYY(0*MAPWIDTH_SHIFT)&MAPHEIGHT_MASK
                        or      a0, a1                                          ' a0 = YYYYYYXXXXXX
                        add     a0, s_bg0_tile                                  ' tile offset.
                        rdbyte  a0, a0                                          ' a0 = BG0_TILE[a0]
                                                                                ' 9+
                        'mov    a0, #17
                        
                        mov     a2, m7_p
                        shr     a2, #fix_prec
                        and     a2, #$0f                                        ' a2 = :000000000000XXXX
                        mov     a3, m7_p
                        shr     a3, #16+fix_prec-4
                        and     a3, #$f0                                        ' a3 = :00000000YYYY0000
                        or      a2, a3                                          ' a2 = YYYYXXXX (pixel offset)
                        shl     a0, #8                                          
                        add     a0, a2                                          ' (a0*256 + pixel offset)
                        add     a0, s_bg0_vram                                  
                        rdbyte  a0, a0                                          ' a0 = BYTE[s_bg0_vram + a0*256 + pixel offset.]
                                                                                ' 11+

                        or      a6, a0
                        ror     a6, #8

                        add     m7_p, tm7_h_delta                               ' p += h_delta
                        'add    tm7_h_delta, m7_h_delta2
                        
' ITTR #3               
                        mov     a0, m7_p                                        ' a0 = YYYYYY'YYYYyyyyyy:XXXXXX'XXXXxxxxxx
                        shr     a0, #4+fix_prec                                 
                        and     a0, _k_map_wm                                   ' a0 = XXXXXX&MAPWIDTH_MASK
                        mov     a1, m7_p
                        shr     a1, _k_map_wsn                                  ' a1 = YYYYYY(0*MAPWIDTH_SHIFT)
                        and     a1, _k_map_hm                                   ' a1 = YYYYYY(0*MAPWIDTH_SHIFT)&MAPHEIGHT_MASK
                        or      a0, a1                                          ' a0 = YYYYYYXXXXXX
                        add     a0, s_bg0_tile                                  ' tile offset.
                        rdbyte  a0, a0                                          ' a0 = BG0_TILE[a0]
                                                                                ' 9+
                        'mov    a0, #17
                        
                        mov     a2, m7_p
                        shr     a2, #fix_prec
                        and     a2, #$0f                                        ' a2 = :000000000000XXXX
                        mov     a3, m7_p
                        shr     a3, #16+fix_prec-4
                        and     a3, #$f0                                        ' a3 = :00000000YYYY0000
                        or      a2, a3                                          ' a2 = YYYYXXXX (pixel offset)
                        shl     a0, #8                                          
                        add     a0, a2                                          ' (a0*256 + pixel offset)
                        add     a0, s_bg0_vram                                  
                        rdbyte  a0, a0                                          ' a0 = BYTE[s_bg0_vram + a0*256 + pixel offset.]
                                                                                ' 11+

                        or      a6, a0
                        ror     a6, #8

                        add     m7_p, tm7_h_delta                               ' p += h_delta
                        'add    tm7_h_delta, m7_h_delta2
                        
:code_1a                mov     0, a6
                        add     :code_1a, _k_d0

                        djnz    a7, #:loop_m7_pixel                                                     ' 9 instrs + rdbyte
                        
                        add     m7_hp, m7_v_delta                               ' horizontal start address += v_delta
                        add     m7_hp, m7_v_delta                               ' horizontal start address += v_delta
                        add     m7_hp, m7_v_delta                               ' horizontal start address += v_delta
                        add     m7_hp, m7_v_delta                               ' horizontal start address += v_delta
                        'add    m7_v_delta, m7_v_delta2
                        'add    m7_v_delta, m7_v_delta2
                        'add    m7_v_delta, m7_v_delta2
                        'add    m7_v_delta, m7_v_delta2

' // SPR: Sprites /////////////////////////////////////////////////////////////



' // //////////////////////////////////////////////////////////////////////////

end_prep                ' wait for this scanline to end rasterizing. (load<63.5us)
                        rdlong  a0, s_copgfx_status
                        cmp     a0, s_scanline_id       wz
        if_z            jmp     #end_prep

                        ' update scanlinebuffer - copy 256 pixels from local memory to screen buffer.
                        movd    code_update_d, #local_buf ' src:= local_buf
                        movd    code_update_d2, #local_buf ' src:= local_buf
                        mov     a1, #64                 ' len := 64
                        mov     a0, s_scanline_buf      ' dest := scanlinebuf
                        
code_update_d           wrlong  0, a0                   ' scanlinebuf[0...63<<2] := local_buf[0..63]
code_update_d2          mov     0, s_cbgcolor           ' local_buf[0..63] := background color (blank it out for next frame)
                        add     a0, #4                  ' dest++
                        add     code_update_d, _k_d0    ' src++
                        add     code_update_d2, _k_d0   ' src++
                        djnz    a1, #code_update_d

                        jmp     #next_prep                        

_k_d0                   long                    1<<9
s_copgfx_status         long                    _memstart+@copgfx_status
s_copgfx_idx            long                    _memstart+@copgfx_idx
s_scanline_id           long                    $0
s_scanline_buf          long                    $0
s_scanline_idx          long                    $0
s_cbgcolor              long                    $0a0a0a0a                       ' background color
' addresses
s_bg0_tile              long                    $0                              ' BG0 tile map address.
s_bg0_vram              long                    $0                              ' BG0 vram address.

a0                      long                    $0                              ' should typically equal 0
a1                      long                    $0
a2                      long                    $0
a3                      long                    $0
a4                      long                    $0
a5                      long                    $0
a6                      long                    $0
a7                      long                    $0

' constants
_k_map_wm               long                    (1<<6)-1
_k_map_wsn              long                    32-6-fix_prec
_k_map_hm               long                    ((1<<6)-1)<<6
                        
' mode 7 regs
m7_p                    long                    $0                              ' current pixel address (per pixel)
m7_hp                   long                    $0                              ' horizontal start address (per scanline)
m7_vp                   long                    $0                              ' vertical start address (per frame)
m7_h_delta              long                    $0000_0100                      ' horizontal delta vector
m7_v_delta              long                    $0100_0000                      ' vertical delta vector
m7_h_delta2             long                    $0000_0000                      ' horizontal delta vector '2
m7_v_delta2             long                    $0000_0000                      ' vertical delta vector '2
tm7_h_delta             long                    $0                              ' temp reg.

x0                      long                    $0
y0                      long                    $0
dx0                     long                    $0
dy0                     long                    $0

local_buf

initialize_prep
                        wrlong  a0, s_copgfx_status     ' Zero Status.

initialize_prep_ret     ret