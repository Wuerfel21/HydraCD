' //////////////////////////////////////////////////////////////////////
' COP Driver (tv-graphics engine)       
' AUTHOR: Colin Phillips
' LAST MODIFIED: 1.30.06
' VERSION 0.7
'

CON
' Video (TV) Related Constants
  fntsc         = 3_579_545     'NTSC color frequency
  lntsc         = 3640          'NTSC color cycles per line * 16
  sntsc         = 624           'NTSC color cycles per sync * 16
  vntsc         = lntsc-sntsc   '3016
  pix_ntsc      = 10 '16 'vntsc/256 '(11 pulses per pixel) changed to 10 gives 2.2us extra on Left, and 2.2us extra on Right
  frame_ntsc    = pix_ntsc*4    '4 pixels per frame (44 pulses per frame)
  framecnt_ntsc = 64 '64 '40 '64
  overscan_ntsc = vntsc-framecnt_ntsc*frame_ntsc        ' 3016 - 256*11 = 200
  backporch_ntsc = overscan_ntsc/2
  frontporch_ntsc = overscan_ntsc - overscan_ntsc/2
  fields_ntsc   = 262                                   ' 262 should be 38 left over (for 256x224 res.)
  top_fields_ntsc               = 14                    ' 24
  bottom_fields_ntsc            = 6                     ' 18
  vsync_fields_ntsc             = 18                    ' 18
  active_fields = fields_ntsc-top_fields_ntsc-bottom_fields_ntsc-vsync_fields_ntsc

' TODO: Cater for PAL
  fpal          = 4_433_618     'PAL color frequency
  lpal          = 4540          'PAL color cycles per line * 16
  spal          = 848           'PAL color cycles per sync * 16
  vpal          = lpal-spal

' Graphics Related Constants
  debugled_mask = $00000001
  scanline_buf  = $140          ' Scanline Buffer : $140 - $180 (64 longs / 256 bytes)
  obj_buf       = $180          ' Object Buffer : $180 - $1f0 (112 longs / 448 bytes)
  obj_n         = 20 '12        ' Number of Objects
  obj_size      = 5             ' register per object.
  obj_total_size = obj_n*obj_size                       ' Total Number of registers (LONGS)
  OBJ_OFFSET_X  = 0
  OBJ_OFFSET_Y  = 1
  OBJ_OFFSET_W  = 2
  OBJ_OFFSET_H  = 3
  OBJ_OFFSET_I  = 4
  VRAM_ADDR     = $4000         ' Video RAM (Sprite data)

  #0, h_cop_status, h_cop_control, h_cop_debug, h_cop_phase0, h_cop_monitor0, h_cop_monitor1, h_cop_obj
  
VAR

  long  cogon, cog, cog2, cog_copptr


PUB start(copptr) : okay | i

'' Start COP driver - starts a cog
'' returns false if no cog available
''
''   tvptr = pointer to TV parameters

' 'Turn off' all sprites by setting them off screen i.e. Y coord = 255 ////////

  cog_copptr := copptr
  
  repeat i from 0 to obj_n-1
    LONG[copptr+h_cop_obj*4+i*4*obj_size + OBJ_OFFSET_Y*4] := 255

  ' Set cogs to wait 0.1 secs before starting
  LONG[cog_copptr+h_cop_control*4] := cnt+(8)<<20       ' 8 Million clocks (2m instructions)

  LONG[cog_copptr+h_cop_status*4] := 0                  ' COP #0
  stop
  okay := cogon := (cog := cognew(@entry,copptr)) > 0

  repeat while LONG[cog_copptr+h_cop_status*4]<>255

 LONG[cog_copptr+h_cop_status*4] := 1                   ' COP #1
 okay := cogon &= (cog := cognew(@entry,copptr)) > 0
 repeat while LONG[cog_copptr+h_cop_status*4]<>255


PUB stop

'' Stop TV driver - frees a cog

  if cogon~
    cogstop(cog)


PUB waitvsync

'' Wait for Vertical Retrace Sync.

repeat while LONG[cog_copptr+h_cop_status*4]            ' Wait until end of active scanline (+bottom overscan) done
repeat while (LONG[cog_copptr+h_cop_status*4] == 0)     ' Wait until end of vsync (+top overscan)

'///////////////////////////////////////////////////////////////////////////////
PUB Sprite_Pixel(ptr, x, y, c)

BYTE[ptr+y*16+x] := c

PUB colormodify(ptr, len, _xor) | i

repeat i from 0 to len-1
  BYTE[ptr+i]^=_xor
  
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
                        or      dira, #debugled_mask                            'set debug led to output

                        rdlong  v_clkfreq, #0                                   'copy clk frequency.

                        ' DETERMINE COP ID (0 for first, 1 for 2nd etc.) similar to cogid, but we have perfect control of the order.
                        mov     r1, par                                         ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_status*4                             ' reference cop_status

                        rdlong  v_copid,r1                                      ' r1 = cop_status (COP ID)
                              
                        mov     r2, #255                                        
                        wrlong  r2, r1                                          ' cop_status = 255 ("Done")

                        ' SYNC COGS
                        mov     r1, par                                         ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_control*4                            ' reference cop_control                        
                        rdlong  r1,r1                                           ' r1 = cop_control (sync point)
                        waitcnt r1, #0                                          ' wait until this point.
                        
                        ' VCFG: setup Video Configuration register and 3-bit tv DAC pins to output
                        'movs   vcfg, #%0000_0111                               ' vcfg'S = pinmask (pin31: 0000_0111 : pin24)
                        movs    vcfg, #%0000_0000                               ' Turn off pin output (we'll turn it on after a few frames once it's synced)
                        movd    vcfg, #3                                        ' vcfg'D = pingroup (grp. 3 i.e. pins 24-31)
                        movi    vcfg, #%010111_000                              ' baseband video on bottom nibble, 2-bit color, enable chroma on broadcast & baseband
                        or      dira, tvport_mask                               ' set DAC pins to output
                        
                        ' CTRA: setup Frequency to Drive Video
                        movi    ctra,#%00001_111                                ' pll internal routed to Video, PHSx+=FRQx (mode 1) + pll(16x)
                        mov     r1, v_freq                                      ' r1: TV frequency in Hz
                        mov     r2, v_clkfreq                                   ' r2: CLKFREQ
                        call    #dividefract                                    ' perform r3 = 2^32 * r1 / r2
                        
                        mov     frqa, r3                                        ' set frequency for counter                                              

                        mov     v_frame, #0


                        
next_frame              ' start of new frame

' /////////////////////////////////////////////////////////////////////////////
' VSYNC Pulse (Vertical Sync) /////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' 18 scanlines: 6 'high syncs', 6 'low syncs', and finally another 6 'high syncs'

' VSYNC HIGH (6x63.5us) ///////////////////////////////////////////////////////

                        cmp     v_frame, #10    wz      ' Turn on output after 10 frames
        if_z            movs    vcfg, #%0000_0111       ' vcfg'S = pinmask (pin31: 0000_0111 : pin24)
                        
                        call    #vsync_high             ' 6x63.5us

                        ' Cop #0: Record CNT in cop_phase0
                        ' Cop #1: Record CNT in r5 (Cop #1 will sync to Cop #0 using this cop_phase0 as reference)
                        
                        mov     r1, par                 ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_phase0*4     ' reference cop_phase0                                   
                        mov     r5, cnt                 ' (r5) Get global clock at this point
                        cmp     v_copid, #0             wz
        if_z            wrlong  r5, r1                  ' Cop #0 writes current point in cop_phase0
                                                        ' We'll do the rest a little later, for now we'll wait for Cop #0 to update the global variable, 6 scanlines of time should suffice.                     

' VSYNC LOW (6x63.5us) ////////////////////////////////////////////////////////

                        call    #vsync_low              ' 6x63.5us

' VSYNC HIGH (6x63.5us) ///////////////////////////////////////////////////////

{         
                        ' Monitor global clk difference between Cogs at this specific video point (DEBUG)
                        mov     r2, cnt                 ' Get current frame reference idx
                        mov     r1, v_copid
                        shl     r1, #2
                        add     r1, par                 ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_monitor0*4   ' reference cop_debug                                    
                        wrlong r2, r1                   ' par + cop_monitor0*4 + copid*4
}

                        ' Do 5 lines of 63.5us + 1 line of 63.5us + phase_shifter
                        
                        movs    vsync_high_rep_s, #5
                        call    #vsync_high             ' gives us 63.5us of processing at the start of next frame. - if we need to we can have 18 times this (1143us - 22,860 instrs) by calling tasks in pieces
                        movs    vsync_high_rep_s, #6

                        ' HSYNC 10.9us (Horizontal Sync) + 52.6us (Visible Scanline) 'Black' + COP phase_shift
                        mov     vscl, v_shsmart         ' 10.9us <= pixel_data[0...15], 52.6us <= pixel_data[15]


                        ' Increase / Decrease the duration of this VSYNC line based on the phase difference between cogs
                        
                        mov     r3, #0
                        mov     r1, par                                         ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_phase0*4                             ' reference cop_control
                        rdlong  r4, r1                                          ' r4 = Cop Phase #0, r5 = Cop Phase #1
                        sub     r5, r4                  wc,wz                   ' CopPhase_1 - CopPhase_0
                        
        if_nc           max     r5, #255
        if_c            min     r5, minus_255
        if_nz           sub     r3, r5                                          ' 

                        cmp     v_copid, #1             wz
        if_z            add     vscl, r3

{
 
                        ' Manually change the phase of the cogs
                        mov     r3, #0
                        mov     r1, par                                         ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_control*4                            ' reference cop_control
                        rdlong  r1, r1                                          ' copy cop_debug into brightness var.
                        cmp     r1, #1                  wz
        if_z            mov     r3, #8
                        cmp     r1, #2                  wz
        if_z            mov     r3, minus_8
                        cmp v_copid, #1                 wz
        if_z            add     vscl, r3
 }

{
                        ' Manually change the VSU phase of cog #0
' this is the problem (phsa)
                        cmp     v_copid, #1             wz
        if_nz           jmp     #skip_it
                        mov     r3, frqa
                        mov     r1, par                                        ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_control*4                            ' reference cop_control
                        rdlong  r1, r1                                          ' copy cop_debug into brightness var.
                        cmp     r1, #1                  wz
        if_z            add     phsa, r3
                        cmp     r1, #2                  wz
        if_z            sub     phsa, r3
skip_it
 }

                        waitvid v_chsync, v_pvsync_high_1                        

' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' 63.5us //////////////////////////////////////////////////////////////////////
' 63.5us (1270 instrs) Per frame general processing


' Update Status Register

                        mov     cop_status,#0                                   ' reset scanline count to 0
                        
                        mov     r1, par                                         ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_status*4                             ' reference cop_status

                        wrlong  cop_status,r1                                   ' copy cop_debug into brightness var.

' Copy Sprite Attribute data from hub mem to cog //////////////////////////////
                        
                        mov     r1, par                                         ' take boot parameter
                        add     r1, #h_cop_obj*4                                ' offset address to start of obj table in hub mem.
                        movd    :code_obj_copy, #obj_buf

                        mov     r0, #obj_total_size                             ' obj_total_size LONG's copy loop.
                        
:code_obj_copy          rdlong  0, r1                                           ' 7..22
                        add     r1, #4                                          ' r1+=4 bytes
                        add     :code_obj_copy, k_d0                            ' :code_obj_copy (D)++ (LONG)

                        djnz    r0, #:code_obj_copy

' /////////////////////////////////////////////////////////////////////////////

                        ' get debug value for intensity of RED LED
                        mov     r1, par                                         ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_debug*4                              ' reference cop_debug

                        rdlong  debugled_brightness,r1                          ' copy cop_debug into brightness var.


' 52.6us ^^^^ /////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

' Top Overscan ////////////////////////////////////////////////////////////////

                        ' render N black lines (top overscan)
                        mov     r1, #top_fields_ntsc
                                       
:vsync_loop             ' HSYNC 10.9us (Horizontal Sync) + 52.6us (Visible Scanline) 'Black'
                        mov     vscl, v_shsmart         ' 10.9us <= pixel_data[0...15], 52.6us <= pixel_data[15]
                        waitvid v_chsync, v_phsync

                        call    #process_debugled
                        djnz    r1, #:vsync_loop

' END /////////////////////////////////////////////////////////////////////////
                        
' Horizontal Scanline Loop (r1 itterations) -----------------------------------

                        mov     v_scanline, #0
next_scanline

                        add     cop_status,#1                                   ' reset scanline count to 0
                        
                        mov     r1, par                                         ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_status*4                             ' reference cop_status

                        wrlong  cop_status,r1                                   ' update cop_status

                        call    #process_debugled                               ' moved it here (right overscan) due to time pressure


                        ' HSYNC 10.9us (Horizontal Sync) + some backporch added
                        'mov    vscl, v_shsync
                        'add    vscl, #backporch_ntsc 'make the frame bigger (the last pixel in it is Black, so we get black overscan)
                        'waitvid v_chsync, v_phsync

                        'jmp    #single_cog1

' ODD scanlines render scanline (and clear it)
' EVEN scanlines prepare scanline (sprites)
' and opposite for 2nd cog.

                        mov     r1, v_scanline
                        xor     r1, v_copid
                        test    r1, #1                                          wz

        if_nz           jmp     #do_raster                                      


                        ' HSYNC 10.9us (Horizontal Sync) + 52.6us (Visible Scanline) 'Black'
                        mov     vscl, v_shsmart         ' 10.9us <= pixel_data[0...15], 52.6us <= pixel_data[15]
                        mov     r0, #0
                        waitvid r0, v_phsync
'                       waitvid v_chsync, v_phsync                        
 '                      movs vcfg, #%0000_0000                  ' Disable Pins (old method)

single_cog1

' /////////////////////////////////////////////////////////////////////////////
' Prepare Scanline ////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

' 63.5us = 1270 instructions can fit here. (up from 262) 
' (6) for setup
' (10)*N for no sprite / (30 + Width*2.75)*N for sprite
' about 17 sprites total, about 2-3 max per scanline

' Note - probably better to just retrieve the OBJ attributes from hub mem, since the sprite pixel data is retrieved from there anyway
' but we may want to keep the Y scanline coord and Height in cog memory since this all cogs preparing scanlines will be checking
' this like mad.

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
      if_c              jmp     #skip_spr_hline                                 ' (4) JMP / (5) no JMP
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
                        movs    code_scanline_e, r2                             ' :code_scanline_e = scanline_buf + Sprite.X>>2

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

' Transparancy algo kills !!!!
' IDEAS: have a transparancy lookup table (and masks). transparancy mode option for sprites (e.g. sprites after 32 are all solid, we self modify the code to deal with them)
' or we can just accept it, and move on to Quad Parallel processing (63.5us * 3 * 20 MIPS = 3810 instrs) - we gotta use up all the cogs eventually, so 4 for graphics sounds good.

code_scanline_e         mov     r0, 0
                        test    r2, mask_p0             wz
        if_nz           andn    r0, mask_p0
                        test    r2, mask_p1             wz
        if_nz           andn    r0, mask_p1
                        test    r2, mask_p2             wz
        if_nz           andn    r0, mask_p2
                        test    r2, mask_p3             wz
        if_nz           andn    r0, mask_p3
                        or      r0, r2
                        
code_scanline_d         mov     0, r0                                          ' write to scanline buffer
' ^^^ Transparancy algo
        
'code_scanline_d        or 0,r2                                                 ' write to scanline buffer OLD METHOD (crude and can mess with sync)
                        add     r1, #4                                          ' move vram address pointer along to next 4 pixels.
                        add     code_scanline_e, #1                             ' move scanline address pointer along to next 4 pixels aswell.
                        add     code_scanline_d, k_d0                           ' move scanline address pointer along to next 4 pixels aswell.
                        mov     r0, r4                                          ' copy saved pixels in r0
                        djnz    r3, #loop_scanline                              ' 22*Width/4, WAS (11)*Width/4 (i.e. 44 for a 16xH sprite)

                        'Do last off-aligned pixels

code_scanline_y         shr     r0, #0                                          ' shift last pixels into place.
                        shr     r0, #1

                        mov     code_scanline_i, code_scanline_d                ' copy entire instruction to below (takes 1 instruction to pipeline result in code!!!)
                        mov     code_scanline_j, code_scanline_e                
                        mov     r2, r0                                          ' add other color data on.

' Argh, more of that nasty transparancy algo!!!

code_scanline_j         mov     r0, 0
                        test    r2, mask_p0             wz
        if_nz           andn    r0, mask_p0
                        test    r2, mask_p1             wz
        if_nz           andn    r0, mask_p1
                        test    r2, mask_p2             wz
        if_nz           andn    r0, mask_p2
                        test    r2, mask_p3             wz
        if_nz           andn    r0, mask_p3
                        or      r0, r2

code_scanline_i         mov     0, r0                                           ' write to scanline buffer
                        
'code_scanline_i        or      0, r2                                           ' (5) write to scanline buffer OLD METHOD (crude and can mess with sync)

                                                                                ' Total: (23 + Width*2.75) 'Sprite'
                        
skip_spr_hline                                                                    


                        'Increment OBJ pointers
                        add     code_spr_s, #obj_size                           ' Y
                        add     code_spr_d, k_d_obj_size                        ' H
                        add     code_spr_s2, #obj_size                          ' X
                        add     code_spr_s3, #obj_size                          ' W
                        add     code_spr_s4, #obj_size                          ' I

                        djnz    r5, #next_sprite                                ' (10) for No Sprite

skip_sprites

                        'jmp    #single_cog2

                        jmp     #done_scanline

' /////////////////////////////////////////////////////////////////////////////
' Serialize (Rasterize) Scanline //////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

do_raster
                        
                        ' HSYNC 10.9us (Horizontal Sync) + some backporch added
                        mov     vscl, v_shsync
                        add     vscl, #backporch_ntsc 'make the frame bigger (the last pixel in it is Black, so we get black overscan)
                        waitvid v_chsync, v_phsync
  '                     movs    vcfg, #%0000_0111                               ' Enable Pins (old method)
                        'call   #process_debugled

single_cog2
' END /////////////////////////////////////////////////////////////////////////
         
' VSU Active Frame Loop ///////////////////////////////////////////////////////
' Feeds thru 4 pixels at a time. 64 itterations, i.e. 256 pixels width.
' 44 pulses / cycle (44/3016 * 52.6us = 0.76us, 0.76us * 20MIPS = 15 instructions/packet)

                        mov     vscl, v_scale
                        'mov    v_color, v_chvis
                        mov     r0, #framecnt_ntsc
                        
                        movs    code_waitvid,#scanline_buf                      ' color (D): start address scanlinebuf[0...63]
                        movd    code_waitvid_2,#scanline_buf                    ' color (D): start address scanlinebuf[0...63]


next_vsuframe           
code_waitvid            mov     r1, 0
                        add     r1, v_coffset
                        waitvid r1, #%%3210                                     ' 5+ clks, feed thru 4 colors / 4 pixels
code_waitvid_2          mov     0, v_cbgcolor
                        add     code_waitvid, #1
                        add     code_waitvid_2, k_d0                    
                        djnz    r0, #next_vsuframe                              ' (6) (15 max - in practice **13**, since waitvid is 5+ clks)

' END /////////////////////////////////////////////////////////////////////////

' VSU Frontporch Overscan /////////////////////////////////////////////////////

                        mov     vscl, #frontporch_ntsc 'v_fp
                        waitvid v_chsync, v_pvsync_high_2 ' v_chsync                        

' END /////////////////////////////////////////////////////////////////////////                          
                        

done_scanline

                        add     v_scanline, #1
                        cmp     v_scanline, #active_fields wz
        if_nz           jmp     #next_scanline
        
' End of Horizontal Scanline Loop ---------------------------------------------

                        ' render M black lines (bottom overscan)
                        mov     r1, #bottom_fields_ntsc
                        

:vsync_loop             ' HSYNC 10.9us (Horizontal Sync) + 52.6us (Visible Scanline) 'Black'
                        mov     vscl, v_shsmart         ' 10.9us <= pixel_data[0...15], 52.6us <= pixel_data[15]
                        waitvid v_chsync, v_phsync                               

                        call    #process_debugled
                        djnz    r1, #:vsync_loop

                        add     v_frame, #1
                        
                        jmp #next_frame

' /////////////////////////////////////////////////////////////////////////////
' vsync_high: Generate 'HIGH' vsync signal for 6 horizontal lines.
' /////////////////////////////////////////////////////////////////////////////

vsync_high              
'vsync                  
vsync_high_rep_s        mov     r1, #6
                        

:vsync_loop             ' HSYNC 10.9us (Horizontal Sync) + 52.6us (Visible Scanline) 'Black'
                        mov     vscl, v_shsmart         ' 10.9us <= pixel_data[0...15], 52.6us <= pixel_data[15]
                        waitvid v_chsync, v_pvsync_high_1                        

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
                        call    #process_debugled

                        ' HVIS 52.6us (Visible Scanline)
                        mov     vscl, v_shvis
                        waitvid v_chsync, v_pvsync_low_2

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

        if_c            or      outa, #debugled_mask                            'on carry Full Power (ON)
        if_nc           andn    outa, #debugled_mask                            'else No Power (OFF)

process_debugled_ret    ret





' Constants
k_d0                    long                    1<<9
k_d_4                   long                    4<<9
k_d_obj_size            long                    obj_size<<9
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
' Debug LED Registers
debugled_ctr            long                    $0
debugled_brightness     long                    $0
' Cop Registers
cop_status              long                    $0
' Video (TV) Registers
tvport_mask             long                    %0000_0111<<24
v_scale                 long                    pix_ntsc << 12 + frame_ntsc

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
v_cbgcolor              long                    $00000000                       ' background color
v_clkfreq               long                    $0
v_copid                 long                    $0
v_phssync               long                    $0

' cop_status:
' -----------
' bits 7..0: active scanline # (0 for overscan/vsync, 1...Screen_Height for current scanline #)