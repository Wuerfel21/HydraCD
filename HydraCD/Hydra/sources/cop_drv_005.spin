' //////////////////////////////////////////////////////////////////////
' COP Driver (tv-graphics engine)       
' AUTHOR: Colin Phillips
' LAST MODIFIED: 1.28.06
' VERSION 0.5
'

CON
' Video (TV) Related Constants
  fntsc         = 3_579_545     'NTSC color frequency
  lntsc         = 3640          'NTSC color cycles per line * 16
  sntsc         = 624           'NTSC color cycles per sync * 16
  vntsc         = lntsc-sntsc   '3016
  pix_ntsc      = 10 'vntsc/256 '(11 pulses per pixel) changed to 10 gives 2.2us extra on Left, and 2.2us extra on Right
  frame_ntsc    = pix_ntsc*4    '4 pixels per frame (44 pulses per frame)
  framecnt_ntsc = 64
  overscan_ntsc = vntsc-framecnt_ntsc*frame_ntsc        ' 3016 - 256*11 = 200
  backporch_ntsc = overscan_ntsc/2
  frontporch_ntsc = overscan_ntsc - overscan_ntsc/2
  fields_ntsc   = 262                                   ' 262 should be 38 left over (for 256x224 res.)
  top_fields_ntsc               = 14                    ' 24
  bottom_fields_ntsc            = 6                     ' 18
  vsync_fields_ntsc             = 18                    ' 18
  active_fields = fields_ntsc-top_fields_ntsc-bottom_fields_ntsc-vsync_fields_ntsc

  fpal          = 4_433_618     'PAL color frequency
  lpal          = 4540          'PAL color cycles per line * 16
  spal          = 848           'PAL color cycles per sync * 16
  vpal          = lpal-spal

' Graphics Related Constants
  scanline_buf  = $140          ' Scanline Buffer : $140 - $180 (64 longs / 256 bytes)
  obj_buf       = $180          ' Object Buffer : $180 - $1f0 (112 longs / 448 bytes)
  obj_n         = 7 '12         ' Number of Objects
  obj_size      = 5             ' register per object.
  obj_total_size = obj_n*obj_size                       ' Total Number of registers (LONGS)
  OBJ_OFFSET_X  = 0
  OBJ_OFFSET_Y  = 1
  OBJ_OFFSET_W  = 2
  OBJ_OFFSET_H  = 3
  OBJ_OFFSET_I  = 4
  VRAM_ADDR     = $4000         ' Video RAM (Sprite data)

  #0, h_cop_status, h_cop_control, h_cop_debug, h_cop_obj
  
VAR

  long  cogon, cog


PUB start(copptr) : okay | i

'' Start COP driver - starts a cog
'' returns false if no cog available
''
''   tvptr = pointer to TV parameters

' 'Turn off' all sprites by setting them off screen i.e. Y coord = 255 ////////

  repeat i from 0 to obj_n-1
    LONG[copptr+h_cop_obj*4+i*4*obj_size + OBJ_OFFSET_Y*4] := 255

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

                        ' READY :-)

                        mov     v_frame, #0
next_frame              ' start of new frame

' Copy Sprite Attribute data from hub mem to cog //////////////////////////////
                        
                        mov     r1, par                                         ' take boot parameter
                        add     r1, #h_cop_obj*4                                ' offset address to start of obj table in hub mem.
                        movd    :code_obj_copy, #obj_buf

                        mov     r0, #obj_total_size                             ' obj_total_size LONG's copy loop.
                        
:code_obj_copy          rdlong  0, r1
                        add     r1, #4                                          ' r1+=4 bytes
                        add     :code_obj_copy, k_d0                            ' :code_obj_copy (D)++ (LONG)

                        djnz    r0, #:code_obj_copy

' /////////////////////////////////////////////////////////////////////////////

                        ' get debug value for intensity of RED LED
                        mov     r1, par                                         ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_debug*4                              ' reference cop_debug

                        rdlong  debugled_brightness,r1                          ' copy cop_debug into brightness var.


                        ' render N black lines (top overscan)
                        mov     r1, #top_fields_ntsc
                                       
                        ' HSYNC 10.9us (Horizontal Sync)
:vsync_loop             mov     vscl, v_shsync
                        waitvid v_chsync, v_phsync

                        ' HVIS 52.6us (Visible Scanline)
                        mov     vscl, v_shvis
                        waitvid v_chsync, v_pvsync_high_2
'                       waitvid v_cbgcolor, #%3210
                        

                        call    #process_debugled
                        djnz    r1, #:vsync_loop
                        
' Horizontal Scanline Loop (r1 itterations)
                        mov     v_scanline, #0
next_scanline                        
                        ' HSYNC 10.9us (Horizontal Sync) + some backporch added
                        mov     vscl, v_shsync
                        add     vscl, #backporch_ntsc 'make the frame bigger (the last pixel in it is Black, so we get black overscan)
                        waitvid v_chsync, v_phsync

                        ' HVIS 52.6us (Visible Scanline)

' Sprite Build Up /////////////////////////////////////////////////////////////
' 10.9us = 218 instructions can fit here. (now 262) [Later we'll use alternating cogs to get 10.9+63.5us i.e. 1488 instrs, about 20 sprs/line, 124 total]
' (6) for setup
' (12)*N for no sprite / (30 + Width*2.75)*N for sprite
' about 17 sprites total, about 2-3 max per scanline

                        movs    code_spr_s, #obj_buf+OBJ_OFFSET_Y                ' Sprite.Y
                        movd    code_spr_d, #obj_buf+OBJ_OFFSET_H               ' Sprite.H
                        movs    code_spr_s2, #obj_buf+OBJ_OFFSET_X              ' Sprite.X
                        movs    code_spr_s3, #obj_buf+OBJ_OFFSET_W              ' Sprite.W
                        movs    code_spr_s4, #obj_buf+OBJ_OFFSET_I              ' Sprite.I
                        mov     r5, #obj_n                                      ' (6)

' Sprite processing
next_sprite
                        ' Y range checking (between Sprite.Y and Sprite.Y+Sprite.H)
                        ' checks if we have to print sprite hline on scanline
                        '
         
                        
                        mov     r1, v_scanline
code_spr_s              sub     r1, 0                   wc                      ' CARRY = Y<Sprite.Y
code_spr_d if_nc        cmp     0, r1                   wc                      ' CARRY = Sprite.H<(Y-Sprite.Y)
      if_c              jmp     #skip_spr_hline                                 ' (5) JMP / (4) no JMP
                        ' r1 = 0...Sprite.H (references the H line in the sprite)
                        
                        ' R1 point to correct VRAM line for sprite data retrieval.
                        '
                        shl     r1, #4                                          ' R1 = Y * 16
code_spr_s4             add    r1, 0                                            ' R1 = I + Y * 16

                        ' :code_scanline_d point to correct starting LONG
code_spr_s2             mov     r2, 0 'obj_buf+OBJ_OFFSET_X
                        mov     r0, r2                                          ' pick it up here
                        shr     r2, #2                                          ' offset = x/4
                        add     r2, #scanline_buf
                        movd    code_scanline_d, r2                             ' :code_scanline_d = scanline_buf + Sprite.X>>2

                        shl     r0, #3                                          ' (x&3)<<3 = 0, 8, 16, 24 (depending on pixel)
                        movs    code_scanline_s, r0                             ' :code_scanline_s = (Sprite.X&3)*8
                        xor     r0, #31                                         ' 31, 23, 15, 7
                        movs    code_scanline_x, r0                             ' invert shift 0->31, 8->23, 16->15, 24->7 (we do 1 more shift)
                        movs    code_scanline_y, r0
                        

                        mov     r0, #0
                        
code_spr_s3             mov     r3, 0 'obj_buf+OBJ_OFFSET_W                     ' (18) R3 = no. of quad pixels to draw.
        
loop_scanline
                        ' Read 4 pixels
                        rdlong  r2, r1                                          ' R2 = vram[Y * 16]

                        mov     r4, r2                                          ' save R4 for next time around.
code_scanline_x         shr     r0, #0                                          
                        shr     r0, #1                                          ' shift previous tile stock by inverted amount of what we shift tile.
                        
code_scanline_s         shl     r2, #0                                          ' R2<<= 8*(X&3)
                        or      r2, r0                                          ' add other color data on.
code_scanline_d         or      0,r2                                            ' write to scanline buffer
                        add     r1, #4                                          ' move vram address pointer along to next 4 pixels.
                        add     code_scanline_d, k_d0                           ' move scanline address pointer along to next 4 pixels aswell.
                        mov     r0, r4                                          ' copy saved pixels in r0
                        djnz    r3, #loop_scanline                              ' (11)*Width/4 (i.e. 44 for a 16xH sprite)

                        'Do last off-aligned pixels

code_scanline_y         shr     r0, #0                                          ' shift last pixels into place.
                        shr     r0, #1

                        mov     code_scanline_i, code_scanline_d                ' copy entire instruction to below (takes 1 instruction to pipeline result in code!!!)
                        mov     r2, r0                                          ' add other color data on.                        
code_scanline_i         mov     0,r2                                            ' (5) write to scanline buffer

                                                                                ' Total: (23 + Width*2.75) 'Sprite'
                        
skip_spr_hline                                                                    


                        'Increment OBJ pointers
                        add     code_spr_s, #obj_size                           ' Y
                        add     code_spr_d, k_d_obj_size                        ' H
                        add     code_spr_s2, #obj_size                          ' X
                        add     code_spr_s3, #obj_size                          ' W
                        add     code_spr_s4, #obj_size                          ' I

                        djnz    r5, #next_sprite                                ' (7)

' VSU Backporch Overscan //////////////////////////////////////////////////////

                        'mov    vscl, #backporch_ntsc 'v_bp
                        'waitvid v_chsync, #0

' END /////////////////////////////////////////////////////////////////////////
         
' VSU Active Frame Loop ///////////////////////////////////////////////////////
' Feeds thru 4 pixels at a time. 64 itterations, i.e. 256 pixels width.
' 44 pulses / cycle (44/3016 * 52.6us = 0.76us, 0.76us * 20MIPS = 15 instructions/packet)

                        mov     vscl, v_scale
                        mov     v_color, v_chvis
                        mov     r0, #64
                        
                        movs    code_waitvid,#scanline_buf                      ' color (D): start address scanlinebuf[0...63]
                        movd    code_waitvid_2,#scanline_buf                    ' color (D): start address scanlinebuf[0...63]


next_vsuframe           
code_waitvid            mov     r1, 0
                        add     r1, v_coffset
                        waitvid r1, #%%3210                                     ' 5+ clks, feed thru 4 colors / 4 pixels
code_waitvid_2          mov     0, #0
                        add     code_waitvid, #1
                        add     code_waitvid_2, k_d0                    
                        djnz    r0, #next_vsuframe                              ' (6) (15 max - in practice **13**, since waitvid is 5+ clks)

' END /////////////////////////////////////////////////////////////////////////

' VSU Frontporch Overscan /////////////////////////////////////////////////////

                        mov     vscl, #frontporch_ntsc 'v_fp
'                       waitvid v_chsync, #0
                        waitvid v_chsync, v_pvsync_high_2 ' v_chsync                        

' END /////////////////////////////////////////////////////////////////////////
                          
                        call    #process_debugled

                        add     v_scanline, #1
                        cmp     v_scanline, #active_fields wz
        if_nz           jmp     #next_scanline
        
' End of Horizontal Scanline Loop

                        ' render M black lines (bottom overscan)
                        mov     r1, #bottom_fields_ntsc
                        
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

' /////////////////////////////////////////////////////////////////////////////
' vsync_high: Generate 'HIGH' vsync signal for 6 horizontal lines.
' /////////////////////////////////////////////////////////////////////////////

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

                        call    #process_debugled
                        djnz    r1, #:vsync_loop

vsync_low_ret           ret
                        


' /////////////////////////////////////////////////////////////////////////////
' dividefrace:
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

' /////////////////////////////////////////////////////////////////////////////
' process_debugled:
' outputs a PWM signal to the LED giving us and LED with variable intensity. :-)
' /////////////////////////////////////////////////////////////////////////////

process_debugled        
                        ' process debug LED intensity (duty cycle trick).
                        add     debugled_ctr, debugled_brightness  wc

        if_c            or      outa, debugled_mask                             'on carry Full Power (ON)
        if_nc           and     outa, debugled_nmask                            'else No Power (OFF)

process_debugled_ret    ret





' Constants
k_d0                    long                    1<<9
k_d_4                   long                    4<<9
k_d_obj_size            long                    obj_size<<9
k_d_3                   long                    16383 << 18 + 3<<9 + 511        ' mask 3
' General Purpose Registers
r0                      long                    $0                              ' should typically equal 0
r1                      long                    $0
r2                      long                    $0
r3                      long                    $0
r4                      long                    $0
r5                      long                    $0
' Debug LED Registers
debugled_ctr            long                    $0
debugled_brightness     long                    $0
debugled_mask           long                    $00000001
debugled_nmask          long                    $fffffffe
' Video (TV) Registers
tvport_mask             long                    %0000_0111<<24
'v_scale                long                    11 << 12 + 44
v_scale                 long                    pix_ntsc << 12 + frame_ntsc
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

' Graphics related vars.
v_coffset               long                    $02020202                       ' color offset (every color is added by $02)
v_cbgcolor              long                    $02020202                       ' background color
v_vram_ptr              long                    VRAM_ADDR
v_tempo                 long                    $0C0C0C0C