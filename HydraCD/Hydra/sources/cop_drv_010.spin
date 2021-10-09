' //////////////////////////////////////////////////////////////////////
' COP Driver (tv-graphics engine)       
' AUTHOR: Colin Phillips
' LAST MODIFIED: 1.3.06
' VERSION 1.0
'

CON
' Video (TV) Related Constants
  fntsc         = 3_579_545     'NTSC color frequency
  lntsc         = 3640          'NTSC color cycles per line * 16
  sntsc         = 624           'NTSC color cycles per sync * 16
  vntsc         = lntsc-sntsc   '3016
  pix_ntsc      = 10 '16        'vntsc/256 '(11 pulses per pixel) changed to 10 gives 2.2us extra on Left, and 2.2us extra on Right
  frame_ntsc    = pix_ntsc*4    '4 pixels per frame (44 pulses per frame)
  framecnt_ntsc = 64 '40        '64 frames = 256 pixels wide.
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
' data_start    = $130                                  ' FORCE DATA START
  scanline_buf  = $1                                    ' *** Scanline Buffer : data_start + $0...$43 (A LONG on either side used for clipping + an extra LONG on the right for overspill transparancy)
  obj_buf       = scanline_buf+$42                      ' *** Object Buffer : data_start + $40...
  obj_n           = 32 '40 '40 '32 ' 32 '20 '12         ' Number of Objects
  obj_size      = 5                                     ' registers per object.
  obj_total_size = (obj_n*obj_size)                     ' Total Number of registers (LONGS)
  tileline_buf   = obj_buf+obj_total_size               ' *** Tileline Buffer (16 LONGs)
  cop_setupframes = 30                                  ' Allow 30 frames (0.5secs) to setup TV (due to COG sync & Chroma sync)
  cop_beginframe = (cop_setupframes+1)
  cop_n         = 2
  OBJ_OFFSET_X  = 0
  OBJ_OFFSET_Y  = 1
  OBJ_OFFSET_W  = 2
  OBJ_OFFSET_H  = 3
  OBJ_OFFSET_I  = 4

  #0, h_cop_status, h_cop_control, h_cop_debug, h_cop_phase0, h_cop_monitor0, h_cop_monitor1, h_cop_config, h_cop_vram, h_cop_tile, h_cop_panx, h_cop_pany, h_cop_bgcolor, h_cop_obj
  
VAR

  long  cogon, cog, cog2, cog_copptr, sprite_n
  long  vram_addr, vram_w, vram_h, vram_size, vram_ws, vram_tile


PUB _vram_ws
  RETURN vram_ws
  
PUB start(copptr) : okay | i

'' Start COP driver - starts two cogs
'' returns false if no cog available
''
''   copptr = pointer to COP engine parameters

  cog_copptr := copptr

  LONG[copptr+h_cop_debug*4] := $0

  ' Encode COP configuration
  LONG[cog_copptr+h_cop_config*4] := vram_ws

  ' Encode COP VRAM address (for map sprite color data)
  LONG[cog_copptr+h_cop_vram*4] := vram_addr

  ' Encode COP TILE address (for map tile index data)
  LONG[cog_copptr+h_cop_tile*4] := vram_tile

  ' Set COP PANX,PANY position to 0,0
  LONG[cog_copptr+h_cop_panx*4] := 0
  LONG[cog_copptr+h_cop_pany*4] := 0

  ' Set COP Background color to black (sets a quad pixel, $00 'Logical Black' is automatically raised to $02 'Video Black')
  LONG[cog_copptr+h_cop_bgcolor*4] := $00000000
  
  
  newframe

  ' Set cogs to wait 0.1 secs before starting
  LONG[cog_copptr+h_cop_control*4] := cnt+(8)<<20       ' 8 Million clocks (2m instructions)

  LONG[cog_copptr+h_cop_status*4] := 0                  ' COP #0 (tells cog it is COP 0)
  stop
  okay := cogon := (cog := cognew(@entry,copptr)) > 0

  ' Wait until cog has booted and received control register. (COP ID)
  repeat while LONG[cog_copptr+h_cop_status*4]<>255

  LONG[cog_copptr+h_cop_status*4] := 1                  ' COP #1 (tells cog it is COP 1)
  okay := cogon &= (cog := cognew(@entry,copptr)) > 0

  ' Wait until cog has booted and received control register. (COP ID)
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
PUB colormodify(ptr, len, _xor) | i
'' Adjusts pixel colors
'' by performing an XOR operation on all color pixels in the designated buffer. 

repeat i from 0 to len-1
  if(BYTE[ptr+i]&$0f)
    BYTE[ptr+i]^=_xor

PUB setup(_vram_addr, _vram_w, _vram_h, _xor, _vram_tile) | t
'' Sets up variables for the COP engine.

vram_addr := _vram_addr
vram_w := _vram_w
vram_h := _vram_h
vram_size := vram_w*vram_h
vram_tile := _vram_tile

' compute width shift
vram_ws := -1
t := vram_w
repeat while t
  t>>=1
  vram_ws++

' modify VRAM sprites
colormodify(vram_addr, vram_size, _xor)

PUB newframe | i, ptr
'' Start New Frame
'' sets ALL sprites to off-screen and resets sprite counter.

ptr := cog_copptr + (h_cop_obj+OBJ_OFFSET_Y)<<2
repeat i from 0 to obj_n-1
  LONG[ptr] := 255
  ptr += (4*obj_size)
sprite_n := 0

PUB sprite(x,y,w,h,offx,offy) | ptr
'' Adds a Sprite to the screen. (Performs HLL assisted Horizontal Pre-Clipping)
'' x: Horizontal placement of sprite.
'' y: Vertical placement of sprite.
'' w: Width of sprite in pixels. (multiple of 4)
'' h: Height of sprite in pixels.
'' offx: Offset of sprite image in VRAM.
'' offy: Offset of sprite image in VRAM.

if(sprite_n==obj_n)
  RETURN
ptr := cog_copptr + (h_cop_obj+sprite_n*obj_size)<<2

' Perform Horizontal Pre-Clipping
if(x < -4)                                              ' Left side
  if(x < -w)
    RETURN
  offx -=(x&$fffffffc)+4
  w += x+1
  x := -((x&$3)^3)

if(x+w>255+4)                                           ' Right side
  if(x>255)
    RETURN
  w := 255+4-x
' RETURN
  
LONG[ptr+OBJ_OFFSET_X<<2] := x
LONG[ptr+OBJ_OFFSET_Y<<2] := y
LONG[ptr+OBJ_OFFSET_W<<2] := (w+3)>>2
LONG[ptr+OBJ_OFFSET_H<<2] := h-1
LONG[ptr+OBJ_OFFSET_I<<2] := vram_addr + (offy<<vram_ws) + offx 'offx
sprite_n++

DAT

'********************************
'* Assembly language COP driver *
'********************************

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

                        ' Cop #0: Record CNT in cop_phase0/cop_phase1
                        ' Cop #1...N: Record CNT in cop_phase1 (Cop #1...N will sync to Cop #0 using this cop_phase0 as reference)
                        
                        mov     r1, par                 ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_phase0*4     ' reference cop_phase0                                   
                        mov     cop_phase1, cnt         ' (cop_phase1) Get global clock at this point
                        cmp     v_copid, #0             wz
        if_z            wrlong  cop_phase1, r1          ' Cop #0 writes current point in cop_phase0
                                                        ' We'll do the rest a little later, for now we'll wait for Cop #0 to update the global variable, 6 scanlines of time should suffice.                     

' VSYNC LOW (6x63.5us) ////////////////////////////////////////////////////////

                        call    #vsync_low              ' 6x63.5us

' VSYNC HIGH (6x63.5us) ///////////////////////////////////////////////////////

                        ' Do 5 lines of 63.5us + 1 line of 63.5us + phase_shifter
                        
                        movs    vsync_high_rep_s, #5
                        call    #vsync_high             ' gives us 63.5us of processing at the start of next frame. - if we need to we can have 18 times this (1143us - 22,860 instrs) by calling tasks in pieces
                        movs    vsync_high_rep_s, #6

                        ' HSYNC 10.9us (Horizontal Sync) + 52.6us (Visible Scanline) 'Black' + COP phase_shift
                        mov     vscl, v_shsmart         ' 10.9us <= pixel_data[0...15], 52.6us <= pixel_data[15]

 {       
' /////////////////////////////////////////////////////////////////////////////
' Manual (cop_control) 0..255 adjusting of phase - Unrequired now
' Note: about 2/3rds of the phase is color, 1/3rd B/W. - can reset it dozens of times
' /////////////////////////////////////////////////////////////////////////////
 
                        cmp     v_copid, #0             wz
        if_z            jmp     #skipit3
                        mov     r4, frqa
                        shr     r4, #4                                          ' r4
                        
                        mov     r3, #0
                        mov     r1, par                                         ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_control*4                            ' reference cop_control
                        rdlong  r1, r1

                        mov     r5, #60                                         ' Max. increments per frame (the more higher, the more responsive)
syncitloop              
                        cmp     r1, v_temp              wc,wz
        if_nc           mov     r0, r4
        if_nc           add     v_temp, #1
        if_c_and_nz     neg     r0, r4
        if_c_and_nz     sub     v_temp, #1
                        add     frqa, r0                                        ' PHSA += r0*4 (instruction takes 4 clocks)
                        sub     frqa, r0

                        djnz    r5, #syncitloop
skipit3                 
}         

                        waitvid v_chsync, v_pvsync_high_1                        
        

' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' 63.5us //////////////////////////////////////////////////////////////////////
' 63.5us (1270 instrs) Per frame general processing


' Update Status Register

                        'mov    cop_status,#0                                   ' reset scanline count to 0
                        
                        'mov    r1, par                                         ' copy pointer (par) to our cop variables in HUB memory.
                        'add    r1, #h_cop_status*4                             ' reference cop_status

                        'wrlong cop_status,r1                                   ' copy cop_debug into brightness var.

                        call    #update_status_0

' Copy Sprite Attribute data from hub mem to cog //////////////////////////////

code_obj_copy_i         jmp     #obj_copy_skip                                  ' NOP this after setup
              
                        mov     r1, par                                         ' take boot parameter
                        add     r1, #h_cop_obj*4                                ' offset address to start of obj table in hub mem.
                        movd    :code_obj_copy, #data_start+obj_buf

                        mov     r0, #obj_total_size                             ' obj_total_size LONG's copy loop.
                        
:code_obj_copy          rdlong  0, r1                                           ' 7..22
                        add     r1, #4                                          ' r1+=4 bytes
                        add     :code_obj_copy, k_d0                            ' :code_obj_copy (D)++ (LONG)

                        djnz    r0, #:code_obj_copy
obj_copy_skip

' Update Background Color /////////////////////////////////////////////////////


                        mov     r1, par                                         ' take boot parameter
                        add     r1, #h_cop_bgcolor*4                            ' offset to bgcolor
                        rdlong  v_cbgcolor, r1                                  ' update register

' /////////////////////////////////////////////////////////////////////////////

                        ' get debug value for intensity of RED LED
                        mov     r1, par                                         ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_debug*4                              ' reference cop_debug

code_debugled           rdlong  debugled_brightness,r1                          ' copy cop_debug into brightness var.


' /////////////////////////////////////////////////////////////////////////////

' 52.6us ^^^^ /////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

' Top Overscan ////////////////////////////////////////////////////////////////

                        ' render N black lines (top overscan)
code_topoverscan_s      mov     r1, #top_fields_ntsc-1
                                       
:vsync_loop             ' HSYNC 10.9us (Horizontal Sync) + 52.6us (Visible Scanline) 'Black'
                        mov     vscl, v_shsmart         ' 10.9us <= pixel_data[0...15], 52.6us <= pixel_data[15]
                        waitvid v_chsync, v_phsync

                        call    #process_debugled
                        djnz    r1, #:vsync_loop

                        ' final overscan used for chroma phase calibration!
code_topoverscan_i      call    #chromasync

' END /////////////////////////////////////////////////////////////////////////
                        
' Horizontal Scanline Loop (v_scanline itterations) -----------------------------------

                        mov     v_taskid, #0                                    ' task id - tells which cog to rasterize.
                        mov     v_scanline, #0
next_scanline

                        mov     cop_phasealter, #0
                        cmp     v_scanline, #112        wz
code_scanlinecs_i
        if_z            call    #cog_sync

                        call   #update_status_add

                        call    #process_debugled                               ' moved it here (right overscan) due to time pressure


                        ' HSYNC 10.9us (Horizontal Sync) + some backporch added
                        'mov    vscl, v_shsync
                        'add    vscl, #backporch_ntsc 'make the frame bigger (the last pixel in it is Black, so we get black overscan)
                        'waitvid v_chsync, v_phsync

                        'jmp    #single_cog1

' ODD scanlines render scanline (and clear it)
' EVEN scanlines prepare scanline (sprites)
' and opposite for 2nd cog.

                        cmp     v_copid, v_taskid                               wz

        if_z            jmp     #do_raster                                      

' Otherwise prepare scanline

                        ' HSYNC 10.9us (Horizontal Sync) + 52.6us (Visible Scanline) 'Black'
                        mov     vscl, v_shsmart         ' 10.9us <= pixel_data[0...15], 52.6us <= pixel_data[15]
                        add     vscl, cop_phasealter
                        mov     r0, #0
                        waitvid r0, #0
                        mov     v_cntnext, cnt
                        add     v_cntnext, v_cntpreparelimit
'                       movs    vcfg, #%0000_0000       ' disable output

single_cog1

' /////////////////////////////////////////////////////////////////////////////
' Prepare Scanline ////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

' 63.5us = 1270 instructions can fit here. (up from 262) 
' (6) for setup
' (10)*N for no sprite / (30 + Width*2.75)*N for sprite
' about 8 max per scanline

' Note - probably better to just retrieve the OBJ attributes from hub mem, since the sprite pixel data is retrieved from there anyway
' but we may want to keep the Y scanline coord and Height in cog memory since this all cogs preparing scanlines will be checking
' this like mad.

code_sprite_i           jmp     #skip_sprites                                   ' NOP this after setup


' Draw Map onto scanline //////////////////////////////////////////////////////

                        mov     r4, par                                         ' copy pointer (par) to our cop variables in HUB memory.
                        add     r4, #h_cop_pany*4                               ' reference cop_pany

                        rdlong  r4, r4
                        add     r4, v_scanline          wc

                        test    r4, k_bit31             wz                      ' above map is transparant (shows background)
           if_nz        jmp     #skip_map
                        
                        mov     r3, r4
                        shr     r3, #4                                          ' every 16 lines
                        shl     r3, #5                                          ' 16 WORDs (32-bytes) per tile line
                        
                        add     r3, v_tile
                        
                        and     r4, #15
code_map_s0             shl     r4, #0                                          ' Pan Y+Scanline * VRAM Width
                        add     r4, v_vram

                        

                        mov     r5, #16                 ' 16 tiles across
                        movd    code_map_d0, #data_start+scanline_buf
                        movd    code_map_d1, #data_start+scanline_buf+1
                        movd    code_map_d2, #data_start+scanline_buf+2
                        movd    code_map_d3, #data_start+scanline_buf+3                              
                        
loop_map
                        rdword r0, r3                                           ' Get Tile Base Address (16 bit value)
                        add    r0, r4                                           ' Add on VRAM & Y Offset
                        add    r3, #2                                           ' Move pointer along.

                        ' Copy 16 pixels (4 LONGs) of desired Tile Map to Scanline Buffer
code_map_d0             rdlong  0, r0
                        add     r0, #4
                        ' spare '
                        
code_map_d1             rdlong  0, r0
                        add     r0, #4
                        ' spare '
                        
code_map_d2             rdlong  0, r0
                        add     r0, #4
                        ' spare '
                        
code_map_d3             rdlong  0, r0


                        ' Increment Scanline Buffer ptr by 4 LONGs (16 pixels)
                        add     code_map_d0, k_d_4
                        add     code_map_d1, k_d_4
                        add     code_map_d2, k_d_4
                        add     code_map_d3, k_d_4

                        djnz    r5, #loop_map

skip_map
' Draw Sprites onto scanline //////////////////////////////////////////////////

                        movs    code_spr_s, #data_start+obj_buf+OBJ_OFFSET_Y     ' Sprite.Y
                        movd    code_spr_d, #data_start+obj_buf+OBJ_OFFSET_H    ' Sprite.H
                        movs    code_spr_s2, #data_start+obj_buf+OBJ_OFFSET_X   ' Sprite.X
                        movs    code_spr_s3, #data_start+obj_buf+OBJ_OFFSET_W   ' Sprite.W
                        movs    code_spr_s4, #data_start+obj_buf+OBJ_OFFSET_I   ' Sprite.I
                        mov     r5, #obj_n                                      ' (6)

' Sprite processing
next_sprite
                        ' Y range checking (between Sprite.Y and Sprite.Y+Sprite.H)
                        ' checks if we have to print sprite hline on scanline
                        '
                        
                        mov     r1, v_scanline
code_spr_s              subs    r1, 0                   wc                      ' CARRY = Y<Sprite.Y
code_spr_d if_nc        cmp     0, r1                   wc                      ' CARRY = Sprite.H<(Y-Sprite.Y)
      if_c              jmp     #skip_spr_hline                                 ' (4) JMP / (5) no JMP
                        ' r1 = 0...Sprite.H (references the H line in the sprite)                        
                        
                        ' R1 point to correct VRAM line for sprite data retrieval.
                        '
code_spr_s5             shl    r1, #0                                           ' R1 = Y * VRAM Width
code_spr_s4             add    r1, 0                                            ' R1 = I + Y * 16

                        ' :code_scanline_d point to correct starting LONG
code_spr_s2             mov     r2, 0 'obj_buf+OBJ_OFFSET_X
                        mov     r0, r2                                          ' pick it up here
                        shr     r2, #2                                          ' offset = x/4
                        add     r2, #data_start+scanline_buf
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
                        cmp     v_cntnext, cnt          wc ' Another check to see if we're reaching our time limit
        if_nc           djnz    r3, #loop_scanline                              ' 22*Width/4, WAS (11)*Width/4 (i.e. 44 for a 16xH sprite)

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

                        cmp     v_cntnext, cnt          wc
                        
        if_nc           djnz    r5, #next_sprite                                ' (10) for No Sprite

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
'                       movs    vcfg, #%0000_0111       'enable output
single_cog2
' END /////////////////////////////////////////////////////////////////////////
         
' VSU Active Frame Loop ///////////////////////////////////////////////////////
' Feeds thru 4 pixels at a time. 64 itterations, i.e. 256 pixels width.
' 44 pulses / cycle (44/3016 * 52.6us = 0.76us, 0.76us * 20MIPS = 15 instructions/frame)

                        mov     vscl, v_scale
                        mov     r0, #framecnt_ntsc
                        
                        movs    code_waitvid,#data_start+scanline_buf           ' color (D): start address scanlinebuf[0...63]
                        movd    code_waitvid_2,#data_start+scanline_buf         ' color (D): start address scanlinebuf[0...63]

dummy_scanline_i        jmp     #dummy_scanline                                 ' NOP This after setup
                        
next_vsuframe           
code_waitvid            mov     r1, 0
                        add     r1, v_coffset
                        waitvid r1, #%%3210                                     ' 5+ clks, feed thru 4 colors / 4 pixels                        
code_waitvid_2          mov     0, v_cbgcolor
                        add     code_waitvid, #1
                        add     code_waitvid_2, k_d0
                        djnz    r0, #next_vsuframe                              ' (6) (15 max - in practice **13**, since waitvid is 5+ clks)

dummy_scanline_back

' END /////////////////////////////////////////////////////////////////////////

' VSU Frontporch Overscan /////////////////////////////////////////////////////

                        mov     vscl, #frontporch_ntsc 'v_fp
                        add     vscl, cop_phasealter
                        waitvid v_chsync, v_pvsync_high_2 ' v_chsync                        

' END /////////////////////////////////////////////////////////////////////////                          
                        

done_scanline

                        add     v_taskid, #1
                        cmp     v_taskid, #cop_n        wz
        if_z            mov     v_taskid, #0


                        add     v_scanline, #1
                        cmp     v_scanline, #active_fields wz
        if_nz           jmp     #next_scanline
        
' End of Horizontal Scanline Loop ---------------------------------------------

'                       movs    vcfg, #%0000_0111       ' re-enable output for both

                        ' render M black lines (bottom overscan)
                        mov     r1, #bottom_fields_ntsc
                        

:vsync_loop             ' HSYNC 10.9us (Horizontal Sync) + 52.6us (Visible Scanline) 'Black'
                        mov     vscl, v_shsmart         ' 10.9us <= pixel_data[0...15], 52.6us <= pixel_data[15]
                        waitvid v_chsync, v_phsync                               

                        call    #process_debugled
                        djnz    r1, #:vsync_loop

                        add     v_frame, #1
code_process_setup_i    call    #process_setup
                        
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
' process_debugled:
' outputs a PWM signal to the LED giving us and LED with variable intensity. :-)
' /////////////////////////////////////////////////////////////////////////////

process_debugled        
                        ' process debug LED intensity (duty cycle trick).
                        add     debugled_ctr, debugled_brightness  wc

        if_c            or      outa, #debugled_mask                            'on carry Full Power (ON)
        if_nc           andn    outa, #debugled_mask                            'else No Power (OFF)

process_debugled_ret    ret

' /////////////////////////////////////////////////////////////////////////////
' update_status
' updates the COP status register so HLL can use this for timing VSYNC etc.
' [+] Todo: All COPs do this, only the master COP needs too. (NOP the 2xcallers)
' /////////////////////////////////////////////////////////////////////////////

update_status_0         neg     cop_status,#1                                   ' reset scanline count to 0
update_status_add       add     cop_status,#1                                   ' increment scanline count by 1
update_status                                                                   ' update status
                        mov     r1, par                                         ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_status*4                             ' reference cop_status

                        wrlong  cop_status,r1                                   ' update cop_status
update_status_ret
update_status_add_ret
update_status_0_ret     ret

' /////////////////////////////////////////////////////////////////////////////
' // COG registers ////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' Various Registers used by the COP engine stored here.
 
' Constants
k_bit31                 long                    $80000000
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
v_cbgcolor              long                    $00000000                       ' background color
v_clkfreq               long                    $0
v_copid                 long                    $0
v_phssync               long                    $0
'v_temp                 long                    128
v_taskid                long                    $0
v_cntnext               long                    $0
v_cntpreparelimit       long                    (1270*4 - 128*4)                ' 63.5us * 80 - safety margin
cop_phase1              long                    $0
cop_phasealter          long                    $0
v_setup                 long                    $0
v_vram                  long                    $0
v_tile                  long                    $0

' /////////////////////////////////////////////////////////////////////////////
' // COG data /////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' Scanline Buffer & OBJ Buffer stored here, after init.
' !!! WARNING ALL CODE BELOW IS WIPED AFTER INITIALIZATION/SETUP PHASE !!! (after 30 frames)

data_start              ' Data Starts From here (we wipe over the init code once initialization/setup phase is complete)

initialize
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
                        mov     r4, par                                         ' copy pointer (par) to our cop variables in HUB memory.
                        add     r4, #h_cop_control*4                            ' reference cop_control                        
                        rdlong  r5,r4                                           ' r1 = cop_control (sync point)                        
                        

                        ' VCFG: setup Video Configuration register and 3-bit tv DAC pins to output
                        movs    vcfg, #%0000_0111                               ' vcfg'S = pinmask (pin31: 0000_0111 : pin24)
                        'movs   vcfg, #%0000_0000                               ' Turn off pin output (we'll turn it on after a few frames once it's synced)
                        movd    vcfg, #3                                        ' vcfg'D = pingroup (grp. 3 i.e. pins 24-31)
                        movi    vcfg, #%010111_000                              ' baseband video on bottom nibble, 2-bit color, enable chroma on broadcast & baseband
                        or      dira, tvport_mask                               ' set DAC pins to output
                        
                        
                        ' CTRA: setup Frequency to Drive Video
                        movi    ctra,#%00001_111                                ' pll internal routed to Video, PHSx+=FRQx (mode 1) + pll(16x)
                        mov     r1, v_freq                                      ' r1: TV frequency in Hz
                        mov     r2, v_clkfreq                                   ' r2: CLKFREQ
                        call    #dividefract                                    ' perform r3 = 2^32 * r1 / r2
                        mov     v_freq, r3                                      ' v_freq now contains frqa.
                        waitcnt r5, #0                                          ' wait until this point.
                        mov     frqa,#0
                        mov     phsa,#0
                        mov     frqa, r3                                        ' set frequency for counter

                        
                        mov     v_frame, #0


                        ' Configure this COP based on parameters passed...
                        mov     r4, par             
                        add     r4, #h_cop_config*4                                                              
                                                                                                  
                        rdlong  r0, r4                                          ' r0 = cop_config  
                        movs    code_spr_s5, r0                                 ' Set Sprite Width shifter (Y<<r0)
                        movs    code_map_s0, r0                                 ' Set Tile Map Width shifter (Y<<r0)


                        mov     r4, par             
                        add     r4, #h_cop_vram*4                                                                
                                                                                                  
                        rdlong  v_vram, r4                                      ' Set VRAM Address for map.


                        mov     r4, par             
                        add     r4, #h_cop_tile*4                                                                
                                                                                                  
                        rdlong  v_tile, r4                                      ' Set VRAM Tile Address for map.

                        cmp     v_copid, #0     wz                              ' Remove some things from Slave cogs..
        if_nz           mov     code_debugled, #0                               ' NOP Debugled brightness adjuster

                        {
                        ' Let's have a look at the size of the code.
                        'mov    r3, #data_start
                        'mov    r3, #data_start+obj_buf+obj_total_size
                        mov     r1, v_copid
                        shl     r1, #2
                        add     r1, par                 ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_monitor0*4   ' reference cop_debug                                    
                        wrlong  r3, r1                  ' par + cop_monitor0*4 + copid*4
                        }                        

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

' /////////////////////////////////////////////////////////////////////////////
' Increase / Decrease the duration of a Scanline based on the phase difference between cogs
' This gets Cogs' CTR register to 0.0125us accuracy
' /////////////////////////////////////////////////////////////////////////////

cog_sync

                        mov     r3, #0
                        mov     r1, par                                         ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_phase0*4                             ' reference cop_control
                        rdlong  r4, r1                                          ' r4 = Cop Phase #0, r5 = Cop Phase #1
                        sub     cop_phase1, r4          wc,wz                   ' CopPhase_1 - CopPhase_0

        if_nc           maxs    cop_phase1, #255
        if_c            mins    cop_phase1, minus_255                                                      
        if_nz           sub     r3, cop_phase1                                    

                        cmp     v_copid, #0             wz
        if_nz           mov     cop_phasealter, r3

                        cmp     v_frame, #cop_setupframes wz
        if_z            mov     code_scanlinecs_i, #0                           ' Remove Caller (replace call with NOP)
        
cog_sync_ret            ret

' /////////////////////////////////////////////////////////////////////////////
' Adjust PHSA on Secondary Cog until both Cog's VSU Chroma's are closely matched
' This is because the chroma generators on the Cogs' VSUs are randomly out of phase
' - Some TV's do not cope well with scanlines having alternating colorburst references.
' /////////////////////////////////////////////////////////////////////////////

chromasync

                        mov     vscl, v_shsync          ' 10.9us
                        waitvid v_chsync, v_phsync

                        mov     vscl, v_shvis           ' 52.6us ?B value (?B = ????1011 L = 3 +/- 1 due to modulation i.e. COG's output 4 or 2)
                        waitvid v_ccogphase, #0         ' when cogs are in phase they're outputting 4's together (100) and 2's together (010)
                                                        ' when they are out of phase they're outputing 6's (100 OR 010 = 110 = 6)
                                                
                        mov     r1, frqa
                        shr     r1, #8
                        
                        cmp     v_copid, #1             wz
        if_nz           jmp     #no_shift

                        mov     r2, #128
                        mov     r3, #0
rep_chromasync
                        mov     r0, ina
                        and     r0, v_ccogphasepin      wc ' r0 = ina & $06000000 Carry = Parity (i.e. 6 => 0, 2/4 => 1)
        if_nc           add     frqa, r1
        if_nc           sub     frqa, r1
        if_nc           add     r3, #1

                        djnz    r2, #rep_chromasync

                        cmp     r3, #16                 wc
        if_c            mov     code_topoverscan_i, #0     ' Remove Caller (replace call with NOP)
        if_c            add     code_topoverscan_s, #1     ' COP 1: Add the Scanline we stole.
no_shift
                        cmp     v_frame, #cop_setupframes wz
        if_z            mov     code_topoverscan_i, #0     ' Remove Caller (replace call with NOP)
        if_z            add     code_topoverscan_s, #1     ' COP 0: Remove scanline - It's *VERY* unlikely the other COP will get here.
 {
'                       mov     r2, #data_start
'                       ' Monitor global clk difference between Cogs at this specific video point (DEBUG) 'Dual Cog only'
                        mov     r1, v_copid
                        shl     r1, #2
                        add     r1, par                 ' copy pointer (par) to our cop variables in HUB memory.
                        add     r1, #h_cop_monitor0*4   ' reference cop_debug                                    
                        wrlong r3, r1                   ' par + cop_monitor0*4 + copid*4
}
 
chromasync_ret          ret

' /////////////////////////////////////////////////////////////////////////////
' Render a Blank scanline instead of that from the scanline buffer
' This protects against these setup/init functions getting destroyed too early
' Since they all reside in what will later be Scanline/OBJ memory
' /////////////////////////////////////////////////////////////////////////////

dummy_scanline
                        
:next_vsuframe          
                        mov     r1, v_cbgcolor
                        add     r1, v_coffset
                        waitvid r1, #%%3210                                     ' 5+ clks, feed thru 4 colors / 4 pixels                        
                        djnz    r0, #:next_vsuframe                             ' (6) (15 max - in practice **13**, since waitvid is 5+ clks)

                        jmp     #dummy_scanline_back

' /////////////////////////////////////////////////////////////////////////////
' Handles the switch over between setup state and full rendering state w/ sprites etc.
' /////////////////////////////////////////////////////////////////////////////

process_setup
                        cmp     v_frame, #cop_beginframe   wz
        if_nz           jmp     #process_setup_ret
                        'Setup complete, Allow Sprites/Scanline etc. engine to start
                        mov     code_process_setup_i, #0   ' Remove Caller (replace call with NOP)
                        mov     code_sprite_i, #0          ' Enable Sprite Rendering (Writes to scanline buffer)
                        mov     code_obj_copy_i, #0        ' Enable Sprite OBJ Copying (Writes to OBJ buffer)
                        mov     dummy_scanline_i, #0       ' Enable Scanline Buf Rasterizing/Clearing
                        
process_setup_ret       ret
                        
' cop_status:
' -----------
' bits 7..0: active scanline # (0 for overscan/vsync, 1...Screen_Height for current scanline #)
'
' cop_control:
' -----------
' bits 31..0: Only used during COG initialization.
'
' cop_debug:
' -----------
' bits 31..0: DEBUG LED Brightness 0 ($0) - 100% ($ffffffff)
'
' cop_monitor0:
' -----------
' bits 31..0: Used for debugging (To read what COP #0 is doing)
'
' cop_monitor1:
' -----------
' bits 31..0: Used for debugging (To read what COP #1 is doing)
'
' cop_phase0: (INTERNAL)
' -----------
' bits 31..0: Used to Sync Cogs.
'
' cop_obj:
' -----------
' (5 LONGS*obj_n)
' X - X position
' Y - Y position
' W - Width (W+3)/4
' H - Height (H-1)
' I - Pointer to sprite
'
' Contains the Sprite Object-Attribute data to be rendered to the screen.
'
' cop_vram:
' -----------
' 32-bit pointer to start of VRAM in hub memory
'
' cop_tile:
' -----------
' 32-bit pointer to start of TILE Map in hub memory
'
' cop_config:
' -----------
' bits 4..0: log2(VRAM_Width) "VRAM width shifter"
'