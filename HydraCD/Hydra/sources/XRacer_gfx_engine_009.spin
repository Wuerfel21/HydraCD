'' Racer Graphic engine
'' JT Cook
'' A stripped down version of Rem's v014 Graphic engine where I added a skewable
'' road, scaling sprites,a scrolling graphic background, and a row of string text.
'' road is drawn by assigning a color that is x pixels in size instead of a bitmap
'' (similar thinking to RLE) after drawing the background. Next the sprites are
'' drawn on the scanline
'' NOTE: Sprite 0 does not contain any sprite data, there are only Sprites 1-6
'' NOTE: For the background, the address of the graphic is written to sprite 0, the
''   colored part above the background is the first 4 pixels in the upper left corner of
''   the background graphic tiled across so it will match and can easily be changed.
'' NOTE: For sprites, x pixel 0 is sprite pixel 255. This is done so the sprites
''    can be moved off the screen to be clipped.
'' Sprites clip on left and right sides of screen (clipping on right still not perfect)
'' Sprites are clipped on bottom of screen
'' Sprites can be scaled.
''   original size of sprite * 512 / new scaled sprite size
''   NOTE: This is NOT calculated in graphics driver and must be calc'd seperately
''   it is multiplied by 512(bit shift by 9) to increase the precision since we can't
''    use decimals in ASM
'' There is a bug with the sprites where the right side and bottom will be clipped odd when
''   scaled
'' NOTE: Added tiled font that uses ROM font
'' NOTE: Debug LED indicating if the scanline is using too much time has been commented out
''  due to lack of COG memory
CON

  SCANLINE_BUFFER = $7F00
  

PUB start(paramadr)

'' Start REM engine - starts a cog
  cognew(@entry, paramadr)

DAT

                        org

' Entry
'
entry                   mov dira, #1 ' enable debug led port
                        ' fetch some parameter, starting at 'par':
                        mov t2,par
                        rdlong cognumber, t2 ' store cog number (0,1,...)

                        add t2, #4 
                        rdlong cogtotal, t2 ' store total number of cogs (1,2,...)

                        'grab addresses
                        rdlong roadgfx, roadgfx_adr       'graphic of road address
                        rdlong roadoffset, roadoffset_adr 'road x offset(used for skewing road)
                        rdlong roadpal, roadpal_adr       'address for palette of road
                        rdlong road_depth, road_depth_adr 'depth buffer to choose what color
                                                          'a road sliver is
                        'sprite addresses
                        rdlong sprite_x_adr, _sprite_x_adr  'x position of sprite
                        rdlong sprite_y_adr, _sprite_y_adr            'y position of sprite
                        rdlong sprite_x_len_adr, _sprite_x_len_adr        'x length of sprite
                        rdlong sprite_y_len_adr, _sprite_y_len_adr        'y length of sprite
                        rdlong sprite_x_scl_adr, _sprite_x_scl_adr       'horizontal scaled size of sprite
                        rdlong sprite_y_scl_adr, _sprite_y_scl_adr        'verticle scaled size of sprite
                        rdlong sprite_adr, _sprite_adr    'address for sprite graphical data                                                                                  
                        rdlong sprite_x_clp_adr, _sprite_x_clp_adr 'pixels to clip off when moving sprite off screen
                        'no longer used
                        'rdlong sprite_y_pxl_adr, _sprite_y_pxl_adr 'for drawing height of sprite
                        ' Syncronise all gfx cog with TV driver before starting
                        call #waitsyncro_start
                        
main_loop
                      
                        ' wait for tv driver to request scanline 0
                        call #waitrequest_start

                        add framecount, #1
        
                        ' Good: all cogs will now prepare a scanline internally

                        ' Here, prepare the scanline in internal memory
prepare_scanline                       
                        'check to see if we draw the string of text,
                        ' solid color above bg graphic, background graphic or the road
                        cmp currentscanline, #32 wz, wc                        
                        if_b jmp #Draw_Tiled_Font 'draw one row of text using built in font
                        cmp currentscanline, #56 wz, wc                        
                        if_b jmp #Draw_BG_High     'draw solid color above background
                        cmp currentscanline, #120 wz, wc
                        if_b jmp #Draw_Background  'draw background graphic above road
'Draw road
                        ' reset pointer to start of scanbuffer
                        movd copyfourpixel, #scanbuffer
                        ' number of pixel to output = 256
                        mov l1, #256

'{ debug
                        ' setup road params for scanline
                        mov roadscanline, currentscanline 'grab scanline
                        sub roadscanline, #120        'find out which road line we are on
                        cmp roadscanline, #79 wz,wc   'make sure we are not reading bad
                        if_a mov roadscanline, #79    ' data
                         ' get address of road scanline
                         '(scanline << 1 + scanline << 2 + scanline) = scanline *7 (7 bytes per line)
                         mov temp_var1, roadscanline
                         shl temp_var1, #1
                         mov roadscanlineoffset, roadscanline
                         shl roadscanlineoffset, #2
                         add roadscanlineoffset, temp_var1
                         add roadscanlineoffset, roadscanline
                         'grab values for this scanline
                         mov temp_var2, roadscanlineoffset 'grab current road scanline
                         add temp_var2, roadgfx 'get address for road gfx
                         mov roadxvalue, #0 'reset road index
                         'grab x offset for road(used for skewing road for perspective)
                         mov temp_var1, roadoffset  'grab x offset address
                         add temp_var1, roadscanline 'grab current road scanline
                         add temp_var1, roadscanline 'do this twice, each value 2 byte
                         rdword temp_var3, temp_var1 'grab x offset
                         sub temp_var1, roadscanline 'get this back to 1 byte
                         cmp temp_var3, #255 wz, wc  'if less then 255 
                         if_ae jmp #:LoadValue       ' subtract value from 255
                         mov temp_var4, #255         ' and that gives us our offset
                         sub temp_var4, temp_var3
                         mov temp_var3, temp_var4                         
:LoadValue                         
                         rdbyte roadxcounter, temp_var2  'grab counter value                         
                         mov temp_var1, road_depth   'grab address for depth buffer
                         add temp_var1, roadscanline 'grab value for that scanline                         
                         rdbyte temp_var1, temp_var1 'grab depth buffer value
                         cmp temp_var1, #40 wz, wc   'check value
                         mov temp_var1, #0           'clear variable
                         if_b add temp_var1, #7      'if below 40, get 2nd pal value
                         add temp_var1, roadxvalue   ' grab index
                         add temp_var1, roadpal      ' add address of palette
                         rdbyte roadxcolor, temp_var1 'read color value for that index
                         add roadxvalue, #1 'next index value
                         cmp temp_var3, #255 wz,wc 'check if we skew road left or right
                         if_b jmp #:skew_left     ' skew road left
:skew_right
                         sub temp_var3, #255 '  since 255 is middle, subtract it
                         add roadxcounter, temp_var3 'add value
                         jmp #:FinRoadInit
:skew_left                         
                        'road offset x number of pixels, check to see if offset is greater
                        'than the current run of pixels, if so skip it and grab next value
                        cmp temp_var3, roadxcounter wz, wc
                        if_b sub roadxcounter, temp_var3 'subtract x offset(if any)  
                        if_b jmp #:FinRoadInit 'skip to end(offset less than run of pixels)
                        sub temp_var3, roadxcounter 'cut out this portion of road
                        add temp_var2, #1   'grab next road index
                        jmp #:LoadValue    'grab next set of road data
:FinRoadInit            ' end road stuff
'}
                        mov bufferaccumulator, #0
                        mov buffercounter, #4
nextpixel
'####################################################################
' Draws the road
drawroad
        'roadxcounter - run length for color, if 0 then grab next index
        'roadxvalue - current index
        'roadxcolor - color value for road
        'roadscanline - grab current scanline of road
        djnz roadxcounter, #:Current_values 'grab new values? (0 Yes, 0> No)
        mov temp_var2, roadscanlineoffset 'grab current road scanline
        mov temp_var1, roadxvalue 'find which index we are using
        add temp_var2, temp_var1 'get new address with index
        add temp_var2, roadgfx 'get address for road info
        rdbyte roadxcounter, temp_var2  'read how many pixels this section will run for
        mov temp_var1, roadxvalue   ' grab index
        add temp_var1, roadpal      ' add address of palette
        mov temp_var3, road_depth   'grab address of depth buffer
        add temp_var3, roadscanline 'grab scanline for depth buffer
        rdbyte temp_var2, temp_var3 'grab depth buffer value
        cmp temp_var2, #40 wz, wc   'check value        
        if_b add temp_var1, #7      'if below 40, get 2nd pal value
        rdbyte roadxcolor, temp_var1 'read color value for that index
        add roadxvalue, #1 ' move to next index
:Current_values                                     
          mov pixelcolor, roadxcolor    'if so, draw background pixel
'####################################################################                        


'                        mov pixelcolor, #$1C 'debug
draw_pxl                        
                        ' draw pixel into buffer
                        add bufferaccumulator, pixelcolor
                        ror bufferaccumulator, #8
                        djnz buffercounter, #skipoutput
                        
copyfourpixel           mov scanbuffer, bufferaccumulator
                        add copyfourpixel, destination_increment

                        mov buffercounter, #4
                        mov bufferaccumulator, #0

skipoutput
                        ' advance to next pixel
                        djnz l1, #nextpixel
                        'because the background graphic renders slower than the road
                        'we need to add an extra delay to it so the sprite scanlines
                        'do not draw out of order

                        jmp #Draw_Sprites 'move onto sprites
'------------------------------------------------------
'Draw tiled font from ROM, draws 16 characters from string on top of screen
Draw_Tiled_Font

        rdlong temp_adr, sprite_adr      'grab location of address of background
        rdlong t7, temp_adr       'read graphic data
        and t7, #$FF              'mask off all but lower 8 bits
        mov temp_adr, currentscanline 'grab scanline
        shl temp_adr, #2  '*4 (32 bits)
        add temp_adr, char_rom  'add address for character
        movd :wrt_bg_scan, #scanbuffer   'location of destination of local scanline buffer
        mov t2, #0 'number of pixels drawns
        mov t1, #4          '4 pixel counter
        mov temp_var3, #0   '4 pixel buffer
        rdlong t4, text_adr_   'address for string text
:rd_char        
        rdbyte t3, t4  'read character from string
        shr t3, #1 wc  'find out if char is odd or even
        shl t3, #7 'multiply to find correct address
        add t3, temp_adr'address for character 
        rdlong temp_var1, t3  'read pixel data for char
        mov temp_var4, #17   '16 pixel counter
        if_c ror temp_var1, #1 'if odd, shift one extra
        add t4, #1             'move to next string char
:next_pixel
        cmpsub temp_var4, #1 wz
        if_e jmp #:rd_char
        mov temp_var2, temp_var1  'grab char data
        AND temp_var2, #1       'mask off everything but lower bit
        ror temp_var1, #2       'move two bits(since even bits are one char, odd bits another)
        ror temp_var3, #8       'shift pixel buffer
        cmp temp_var2, #1 wz    'check if pixel is there or not
        if_e add temp_var3, #$5 'if there is a pixel, draw a white pixel
        if_ne add temp_var3, t7 'if not, draw background pixel
        djnz t1, #:next_pixel   'if we have shifted through 4 pixels, write to buffer
        ror temp_var3, #8 'shift last output
        mov t1, #4 'reset 4 pixel counter        
:wrt_bg_scan  mov scanbuffer, temp_var3 'write pixel to local sprite buffe
        add :wrt_bg_scan, destination_increment  'move to next index in scanline buffer
        mov temp_var3, #0     'clear 4 pixel buffer
        add t2, #4            'check number of pixels we have drawn
        cmp t2, #256 wz,wc    'if below 256, keep looping
        if_b jmp #:next_pixel       'keep drawing bg                 
        jmp #Draw_Sprites 'move onto sprites
        'jmp #scanlinefinished 'finish scanline, no sprites
                               
'------------------------------------------------------
'Draw solid color of background above background graphic
'we grab the first 4 pixels of the background graphic in upper left corner and tile it across
Draw_BG_High
        rdlong temp_adr, sprite_adr      'grab location of address of background
        movd :wrt_bg_scan, #scanbuffer   'location of destination of local scanline buffer
        rdlong temp_var1, temp_adr       'read graphic data
        mov temp_var2, #0                'pixel counter
:wrt_bg_scan  mov scanbuffer, temp_var1 'write pixel to local sprite buffer
        add :wrt_bg_scan, destination_increment  'move to next index in scanline buffer
        add temp_var2, #4            'check number of pixels we have drawn
        cmp temp_var2, #256 wz,wc    'if below 256, keep looping
        if_b jmp #:wrt_bg_scan       'keep drawing bg 
        jmp #Draw_Sprites 'move onto sprites                        
'------------------------------------------------------
'Draw background graphics  
Draw_Background
        mov temp_var1, currentscanline 'grab scanline
        sub temp_var1, #56             'find which row of the graphic we will be drawing
        rdlong temp_adr, sprite_adr     'grab location of address of background
        shl temp_var1, #6  '*64 (length of graphic in pixels)
        add temp_adr, temp_var1  'add scanline offset
        rdlong temp_var3, sprite_x_adr 'find the x offset of background        
        add temp_adr, temp_var3  'add graphic offset 
        movd :wrt_bg_scan, #scanbuffer   'location of destination of local scanline buffer
        mov temp_var2, #0                'pixel counter
        mov temp_var1, #0 'clear 4 pixel buffer
        mov t8, #4 'counter to see if we are ready to write pixels to buffer
:read_bg
        rdbyte temp_var4, temp_adr 'read graphic data
        ror temp_var1, #8 'shift output
        or temp_var1, temp_var4  'place pixel in 4 pixel buffer
        add temp_adr, #1   'ready next address
        add temp_var3, #1       'add 1 to graphic counter         
        cmp temp_var3, #63 wz,wc     'check to see if we still have a valid address
        if_a sub temp_adr, #64       'and reset address
        if_a mov temp_var3, #0       'if not reset counter
        djnz t8, #:read_bg   'if we have shifted through 4 pixels, write to buffer
        ror temp_var1, #8 'shift last output
        mov t8, #4 'reset 4 pixel counter
:wrt_bg_scan  mov scanbuffer, temp_var1 'write pixel to local sprite buffer
        mov temp_var1, #0 'clear 4 pixel buffer
        add :wrt_bg_scan, destination_increment  'move to next index in scanline buffer
        add temp_var2, #4            'check number of pixels we have drawn
        cmp temp_var2, #256 wz,wc    'if below 256, keep looping
        if_b jmp #:read_bg           'keep drawing bg

        
'------------------------------------------------------                        
Draw_Sprites            'start drawing sprites here
        mov sprite_number, #6 'number of sprites to be drawn
:Start_sprite
        '--check y position
        mov sprite_number_l, sprite_number 'grab sprite number value
        shl sprite_number_l, #2            '*4 for reading long values
        mov temp_adr, sprite_y_adr 'address for y location
        add temp_adr, sprite_number 'grab current sprite
        rdbyte sprite_y_, temp_adr     'grab y location of sprite
        mov temp_var1, currentscanline 'grab scanline
        sub temp_var1, sprite_y_       'subtract y location from scanline
        '-- y length of sprite
        mov temp_adr, sprite_y_len_adr 'grab address for y length of sprite
        add temp_adr, sprite_number   'grab current sprite
        rdbyte sprite_y_len_, temp_adr  'grab y length of sprite  
        'cmp temp_var1, sprite_y_len_ wz, wc  'check scanline against height of sprite 
        cmpsub sprite_y_len_, temp_var1 wz, wc  'check scanline against height of sprite and
                                     'also get current sprite scanline
        if_a jmp #:next_sprite   'if scanline > y location + y length of sprite, skip it
        '-- y scaling 
        mov temp_adr, sprite_y_scl_adr 'grab address for scaling
        add temp_adr, sprite_number_l  'find address for this current sprite
        rdlong temp_var2, temp_adr 'grab value that we scale each scanline by
        mov t1, temp_var2     'add scaler value
        mov t2, temp_var1     'current scanline number
        call #multiply
        mov current_x_pixel, t2  'grab scaled value
        shr current_x_pixel, #9                'divide by 512     
        shl current_x_pixel, #6  '*64 (length of graphic in x pixels)            
        '-- check x position               
        mov temp_adr, sprite_number_l ' grab current sprite
        add temp_adr, sprite_x_adr 'address for x location
        rdlong sprite_x__, temp_adr 'grab x location(long so this is 4 bytes)  
        '-- x length of sprite
        mov temp_adr, sprite_x_len_adr 'address for length of sprite
        add temp_adr, sprite_number 'grab current sprite
        rdbyte sprite_x_len_, temp_adr 'grab length of sprite
        '--grab address for sprite  data
        mov temp_var1, sprite_adr 'address for sprite
        add temp_var1, sprite_number_l 'address for current sprite        
        rdlong sp_adr, temp_var1   'grab address of sprite           
        add sp_adr, current_x_pixel 'y offset for sprite
        '-- check left border of screen
:check_left_brd        
        cmp sprite_x__, #255 wz, wc 'check if sprite goes off left side of screen(255 = 0)
        if_ae jmp #:check_right_brd 'sprite doesn't need to be clipped
        mov temp_var1, #256         'grab border offset
        sub temp_var1, sprite_x__   ' find out how far sprite is clipped
        cmp sprite_x_len_, temp_var1 wz, wc 'check to see if whole sprite is off screen
        if_be jmp #:next_sprite ' if all the way off the screen, skip sprite
        sub sprite_x_len_, temp_var1 'clip sprite size
        mov sprite_x__, #1        'start drawing sprite at pixel 0
        mov temp_adr3, sprite_x_clp_adr 'grab location for clipped graphic
        add temp_adr3, sprite_number_l  'grab index for current sprite
        rdlong scale_cntr, temp_adr3 'reset the scale counter
        jmp #:no_clip_right     ' no sprite can be scaled larger than the size of a scanline                                  
        '--check to see if sprite is drawn outside of right border
:check_right_brd
        mov scale_cntr, #0          'reset scale counter
        sub sprite_x__, #255 'at this point no sprite will be lower than zero (make sprite 0-255+)
        cmp sprite_x__, #255 wz, wc'check to see if sprite goes off screen completely
        if_a jmp #:next_sprite
        mov temp_var1, sprite_x__ 'grab xlength
        add temp_var1, sprite_x_len_ 'add legth
        cmp temp_var1, #255 wz,wc   'check to see if sprite is drawn past visiable scanline
        if_be jmp #:no_clip_right 'if it isn't outside of border, skip it
        sub temp_var1, #255
        sub sprite_x_len_, temp_var1       
:no_clip_right        
        mov t8, sprite_x_len_       'grab sprite length before we alter it
        mov t3, sprite_x_len_       'grab sprite length to check
        and t3, and_mask3           ' mask off all but lower 2 bits(remainder after shift)
        shr sprite_x_len_, #2 wz    'x length divide by 4 (long = 4 bytes)
        if_z jmp #:next_sprite      'if length of sprite is zero skip to next sprite
        mov temp_var1, sprite_x__   'grab sprite x and place onto remaining x length
        'and sprite_x__, and_mask2   'mask off lower 2 bits
        'sub temp_var1, sprite_x__   'find the 4 pixel offset
        and temp_var1, and_mask3    'mask off all but lower 2 bits
        shr sprite_x__, #2          'x location divide by 4 (each index is 1 long)
        mov temp_var3, #scanbuffer  'location of scanline buffer
        add temp_var3, sprite_x__   'how many longs into sprite buffer we are in
        movs :grab_bg1, temp_var3   'location of scanline buffer to draw under sprite in loop        
        mov temp_var4, #4           'cycle through next 4 pixels
         'code between movs and :grab_bg1 because of one op delay in modified code
:grab_bg1 mov temp_var2, scanbuffer   'grab background
        sub temp_var4, temp_var1      'calc offset between 0-3 pixels per long
        add temp_var1, t3 'add length remainder to total remainder
        cmp temp_var1, #0 wz, wc   
        if_nz add sprite_x_len_, #1
        sub temp_var1, t3 'subtract remained so not to offset backgrond shifting 
        'shift the offset of the 1st x sprite pixel
        shl temp_var1, #3     '*8, how many bits we shift background before we draw sprite
        ror temp_var2, temp_var1 'shift out the background

        mov temp_adr, sprite_number_l   'grab value for current sprite
        add temp_adr, sprite_x_scl_adr 'grab scale value
        rdlong sprite_x_scale_, temp_adr 'read scale value to scale sprite either up or down
        cmp sprite_x_scale_, mask_512 wz, wc 'compare size of sprite vs scaled size of sprite
                                   'we take the original size of sprite and divide it
                                   'by new scaled size, if they are the same size then the
                                   'we 512, if the scaled size is bigger, then it will be
                                   'less than 512 and visa-versa 
        if_a jmp #:scale_small_int 'if scaling down, perform different routines
        movd :wrt_sprite, temp_var3   'location of destination of local scanline buffer
        movs :grab_bg, temp_var3      'location of scanline buffer to draw under sprite in loop
        mov t6, #511                 'clear sprite compare
'---- scale sprite to original size or larger
'sprite drawing loop
:scale_sprite
:nxt_s_pix
        mov t7, scale_cntr            'move value to a temp reg
        shr t7, #9                    'divide by 512
        add t7, sp_adr                'grab location for sprite with correct pixel
        cmp t7, t6 wz, wc             'check to see if we need to grab a new pixel
        if_ne rdbyte pixel8bit, t7    'grab pixel
        if_ne mov t6, t7              'write new pixel number
        add scale_cntr, sprite_x_scale_  'find current pixel to grab
        cmp pixel8bit, #0 wz          'test sprite pixel to see if it is transparent
        if_nz and temp_var2, and_mask 'mask off the lower 8 bits if pixel is not 0
        if_nz or temp_var2, pixel8bit 'insert pixel into buffer if pixel is not 0
        ror temp_var2, #8             'shift temp buffer for next pixel
        sub t8, #1 wz                 'check right side of sprite
        if_z jmp #:clip_right         'if no more x pixels, just shift out bg        
        djnz temp_var4, #:nxt_s_pix   'if we have shifted through 4 pixels, write to buffer

:wrt_sprite  mov scanbuffer, temp_var2 'write pixel to local sprite buffer
        add :wrt_sprite, destination_increment  'move to next index in scanline buffer
        add :grab_bg, #1              'next index to grab background
        mov temp_var4, #4             'cycle through next 4 pixels
:grab_bg mov temp_var2, scanbuffer             'grab background
        djnz sprite_x_len_, #:nxt_s_pix 'if there is still more sprite to draw, grab
                                        'another 4 pixels
:next_sprite
        djnz sprite_number, #:Start_sprite 'go to next sprite
        jmp #scanlinefinished
:clip_right 'no more x pixels, shift out the rest
        sub temp_var4, #1          'subtract one because we skipped the djnz
        shl temp_var4, #3          ' *8 how many bits we shift bg
        ror temp_var2, temp_var4   ' shift out rest of bg since no more sprite is drawn
        jmp #:wrt_sprite
'---- Scale sprite smaller than original size
'sprite drawing loop
:scale_small_int
        movd :wrt_sprite_s, temp_var3   'location of destination of local scanline buffer
        movs :grab_bg_s, temp_var3      'location of scanline buffer to draw under sprite in loop    
:nxt_s_pix_s
        mov t7, scale_cntr            'move value to a temp reg
        shr t7, #9                    'divide by 512
        add t7, sp_adr             'grab location for sprite with correct pixel
        rdbyte pixel8bit, t7   'grab pixel
        add scale_cntr, sprite_x_scale_  'find current pixel to grab
        cmp pixel8bit, #0 wz          'test sprite pixel to see if it is transparent
        if_nz and temp_var2, and_mask 'mask off the lower 8 bits if pixel is not 0
        if_nz or temp_var2, pixel8bit 'insert pixel into buffer if pixel is not 0
        ror temp_var2, #8             'shift temp buffer for next pixel
        sub t8, #1 wz                 'check right side of sprite
        if_z jmp #:clip_right_s       'if no more x pixels, just shift out bg
        djnz temp_var4, #:nxt_s_pix_s   'if we have shifted through 4 pixels, write to buffer
:wrt_sprite_s  mov scanbuffer, temp_var2 'write pixel to local sprite buffer
        add :wrt_sprite_s, destination_increment  'move to next index in scanline buffer
        add :grab_bg_s, #1              'next index to grab background
        mov temp_var4, #4             'cycle through next 4 pixels
:grab_bg_s mov temp_var2, scanbuffer             'grab background
        djnz sprite_x_len_, #:nxt_s_pix_s 'if there is still more sprite to draw, grab
                                          'another 4 pixels
        jmp #:next_sprite                'finished drawing sprite                                
:clip_right_s 'no more x pixels, shift out the rest
        sub temp_var4, #1          'subtract one because we skipped the djnz
        shl temp_var4, #3          ' *8 how many bits we shift bg
        ror temp_var2, temp_var4   ' shift out rest of bg since no more sprite is drawn
        jmp #:wrt_sprite_s                                        
'------------------------------------------------------  
scanlinefinished
                        ' Check status of TV: warning: this is a pseudo-call: it might not return!
                        'call #checktv           

:wait                   ' Wait here until the TV request exactly the scanline that THIS cog prepared
                        ' Other cog will wait here a bit
                        rdlong currentrequest, request_scanline
                        cmps currentrequest, currentscanline wz, wc
        if_b            jmp #:wait

start_tv_copy
                        movs :nextcopy, #scanbuffer
                        mov t1, display_base
                        mov l1, #64

:nextcopy               mov t3,scanbuffer
                        add :nextcopy, #1
                        wrlong t3, t1
                        add t1, #4
                        djnz l1, #:nextcopy                      
scanlinedone
                        ' Line is done, increment to the next one this cog will handle
                        
                        add currentscanline, cogtotal                        
                        cmp currentscanline, #191 wc, wz
        if_be           jmp #prepare_scanline
                        ' The screen is completed, jump back to main loop a wait for next frame                        
                        jmp #main_loop
' Instruction that will get copied over at line 'shift_rpixel'
shift_rpixel_instruction shl pixelcolor, rshift
skip_rpixel_instruction mov pixelcolor, #0

' Verification: if the TV is already asking for this scanline or more
' (except scanline 0), then lit the debug led: we have failed preparing this
' scanline in time: we need to optimize or use more cog
' if we failed, then skip straight to TV output: This means that WE WONT RETURN TO THE CALLER.

checktv
{
                        cmp currentrequest, #0 wz
        if_z            jmp #checktv_ret
                        rdlong currentrequest, request_scanline
                        cmp currentrequest, currentscanline wz, wc
                        ' At this point, we could skip drawing sprites or something like that and go
                        ' straight to image output and still stay synced with the tv driver
                        ' We must be quick though!
        if_b            mov outa, #0
        if_ae           mov outa, #1
        'if_ae           jmp #start_tv_copy
}        
'checktv_ret             ret


' Wait until the tv driver request scanline 0
waitrequest_start
                        mov currentscanline, cognumber
:waitloop               rdlong currentrequest, request_scanline wz
        if_nz           jmp #:waitloop
waitrequest_start_ret   ret

' Wait until the tv driver request scanline 192
waitsyncro_start
:waitloop               rdlong currentrequest, request_scanline
                        cmp currentrequest, #192 wz
        if_ne           jmp #:waitloop

waitsyncro_start_ret    ret
{
wastetime
                        mov time, cnt
                        add time, period
                        waitcnt time,period
wastetime_ret           ret
}
' Multiply t1 by t2, return result in t2

multiply                shl t1, #16
                        mov t3, #16
                        shr t2, #1 wc
:loop   if_c            add t2, t1 wc
                        rcr t2, #1 wc
                        djnz t3, #:loop                        
multiply_ret            ret

display_base            long SCANLINE_BUFFER
request_scanline        long SCANLINE_BUFFER-4
update_ok               long SCANLINE_BUFFER-8
text_adr_               long SCANLINE_BUFFER-12
xx3                     long SCANLINE_BUFFER-16 
xx4                     long SCANLINE_BUFFER-20 
'_sprite_y_pxl_adr       long SCANLINE_BUFFER-24 'no longer used
_sprite_x_clp_adr       long SCANLINE_BUFFER-28 'pixels to clip off when moving sprite off screen 
roadgfx_adr             long SCANLINE_BUFFER-32 'graphic of road
road_depth_adr          long SCANLINE_BUFFER-36 'road divider/depth buffer
framecount_adr          long SCANLINE_BUFFER-40
roadoffset_adr          long SCANLINE_BUFFER-44 'values for skewing road
roadpal_adr             long SCANLINE_BUFFER-48 'palette for road
'sprite values
_sprite_x_adr           long SCANLINE_BUFFER-52 'x position of sprite
_sprite_y_adr           long SCANLINE_BUFFER-56 'y position of sprite
_sprite_x_len_adr       long SCANLINE_BUFFER-60 'x length of sprite
_sprite_y_len_adr       long SCANLINE_BUFFER-64 'y length of sprite
_sprite_x_scl_adr       long SCANLINE_BUFFER-68 'horizontal scaled size of sprite
_sprite_y_scl_adr       long SCANLINE_BUFFER-72 'verticle scaled size of sprite
_sprite_adr             long SCANLINE_BUFFER-76 'address for sprite graphic data


' t1-8: temporary registers
t1 long                 $0
t2 long                 $0
t3 long                 $0
t4 long                 $0
t5 long                 $0
t6 long                 $0
t7 long                 $0
t8 long                 $0


l1 long                 $0  'loop register

destination_increment long 512
'time long               $0
'period long             220000
framecount long         $0
cognumber long          $0
currentscanline long    $0
currentrequest long     $0
cogtotal long           $0
'debug_v1 long           $0
'debug_v2 long           $0

lshift long             $0
rshift long             $0

buffercounter long      0
bufferaccumulator long  0

'sprite values
sprite_color long       $0 'color of current sprite pixel
sprite_number long      $0 'number of sprites to be rendered
sprite_number_l long    $0 'sprite number *4 to read long values
sprite_adr              long $0'address for sprite graphic data
sprite_x_adr            long $0'x position of sprite
sprite_y_adr            long $0 'y position of sprite
sprite_x_len_adr        long $0 'x length of sprite
sprite_y_len_adr        long $0 'y length of sprite
sprite_x_scl_adr        long $0 'horizontal scaled size of sprite
sprite_y_scl_adr        long $0 'verticle scaled size of sprite
sprite_x_clp_adr        long $0 'pixels to clip off when moving sprite off screen
'sprite_y_pxl_adr        long $0 'used for drawing height of sprite(no longer used)  

'road values
roadgfx long            $0  'address
roadoffset long         $0  'address
roadpal long            $0  'address
roadxvalue long         $0
roadxcolor long         $0
roadscanline long       $0
roadscanlineoffset long $0
road_depth long         $0
pixelcolor long         $0
roadxcounter byte       $0
pixel8bit long          $0  'temp pixel holder for sprite drawing routines
and_mask long           $ffffff00 'mask for anding sprite pixels
and_mask2 long          $fffffffc 'mask for anding sprite pixels
and_mask3 long          $00000002 'mask all but last 2 bits 
mask_512  long          $200  
char_rom long           $8000

fit 430
scanbuffer_prev res     1                       ' One extra long on the left
scanbuffer res          65                      ' One extra long on the right
'temp holders for sprite rendering
current_x_pixel res 1
sprite_x__ res 1
sprite_y_ res 1
sprite_y_len_ res 1
sprite_x_len_ res 1
sprite_x_scale_ res 1
scale_cntr res 1
sp_adr res 1
temp_adr res 1
temp_adr2 res 1
temp_adr3 res 1
temp_var1 res 1
temp_var2 res 1
temp_var3 res 1
temp_var4 res 1