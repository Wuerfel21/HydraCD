'' Tiled text engine
'' JT Cook

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

                        rdlong char_data_adr__, char_data_adr_  'characater graphic data
                        
                        call #waitsyncro_start
                        
main_loop
                      
                        ' wait for tv driver to request scanline 0
                        call #waitrequest_start

                        'grab background color
                        rdlong t1, tile_color_adr_
                        rdbyte bg_color, t1
                        'grab text color
                        add t1, #1
                        rdbyte fg_color, t1
                        
                        add framecount, #1
        
                        ' Good: all cogs will now prepare a scanline internally

                        ' Here, prepare the scanline in internal memory
prepare_scanline                       
                        'check to see if we draw the string of text,
'------------------------------------------------------
'Draw tiled characters that are 8*8 pixels in size
Draw_Tiled_Font

        mov temp_adr, currentscanline    'grab scanline
        and temp_adr, #$07               'mask off everything above 7
        add temp_adr, char_data_adr__    'add address for character data
        movd :wrt_bg_scan, #scanbuffer   'location of destination of local scanline buffer
        mov t2, #0                       'number of pixels drawns
        mov t1, #4                       '4 pixel counter
        mov temp_var3, #0                '4 pixel buffer
        rdlong t4, tile_adr_             'grab string text
        mov temp_adr2, currentscanline    'grab scanline
        shr temp_adr2, #3                 ' / 8  (height of character)
        shl temp_adr2, #5                 ' *32  (number of characters on a line)
        add t4, temp_adr2                 'address for string text
                
:rd_char        
        rdbyte t3, t4                    'read character from string
        shl t3, #3                       'multiply * 8 (since each char is 8 bytes)
        add t3, temp_adr                 'address for character data
        rdbyte temp_var1, t3             'read pixel data for char
        mov temp_var4, #9                '8 pixel counter
        add t4, #1                       'move to next string char
        rol temp_var1, #25               'set this up to be msb for character graphic
:next_pixel
        cmpsub temp_var4, #1 wz
        if_e jmp #:rd_char               'if we have finished the character, read new one
        mov temp_var2, temp_var1         'grab char data
        AND temp_var2, #1                'mask off everything but lower bit
        rol temp_var1, #1                'move one bit
        ror temp_var3, #8                'shift pixel buffer
        cmp temp_var2, #1 wz             'check if pixel is there or not
        if_e add temp_var3, fg_color     'if there is a pixel, draw a white pixel
        if_ne add temp_var3, bg_color    'if not, draw black pixel
        djnz t1, #:next_pixel            'if we have shifted through 4 pixels, write to buffer
        ror temp_var3, #8                'shift last output
        mov t1, #4                       'reset 4 pixel counter        
:wrt_bg_scan  mov scanbuffer, temp_var3  'write pixel to local sprite buffe
        add :wrt_bg_scan, destination_increment  'move to next index in scanline buffer
        mov temp_var3, #0                'clear 4 pixel buffer
        add t2, #4                       'check number of pixels we have drawn
        'cmp t2, #255 wz,wc               'if below 256, keep looping
        cmp t2, #230 wz,wc               'debug        
        if_b jmp #:next_pixel            'keep drawing bg                 
        jmp #scanlinefinished           'finish scanline, no sprites

           
'------------------------------------------------------  
scanlinefinished
                        ' Check status of TV: warning: this is a pseudo-call: it might not return!
                        call #checktv           

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
        
checktv_ret             ret


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
tile_adr_               long SCANLINE_BUFFER-8  'address of tiles
tile_color_adr_         long SCANLINE_BUFFER-12 'address for color of tile
char_data_adr_          long SCANLINE_BUFFER-16 'address where characters are at 
xxx2_                   long SCANLINE_BUFFER-20 
xxx3_                   long SCANLINE_BUFFER-24 
xxx4_                   long SCANLINE_BUFFER-28     
xxx5_                   long SCANLINE_BUFFER-32 
xxx6_                   long SCANLINE_BUFFER-36 
xxx7_                   long SCANLINE_BUFFER-40
xxx8_                   long SCANLINE_BUFFER-44 
xxx9_                   long SCANLINE_BUFFER-48 
xxx10_                  long SCANLINE_BUFFER-52 
xxx11_                  long SCANLINE_BUFFER-56 
xxx12_                  long SCANLINE_BUFFER-60 
xxx13_                  long SCANLINE_BUFFER-64 
xxx14_                  long SCANLINE_BUFFER-68 
xxx15_                  long SCANLINE_BUFFER-72 
xxx16_                  long SCANLINE_BUFFER-76  

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

'tile values
char_data_adr__ long    $0 
'char_rom long           $8000 'address where character data is location on rom
pixelcolor long         $0 'should this be removed?
fg_color long           $0 'text color
bg_color long           $0 'background color 

fit 430
scanbuffer_prev res     1                       ' One extra long on the left
scanbuffer res          65                      ' One extra long on the right

temp_adr res 1
temp_adr2 res 1
temp_adr3 res 1
temp_var1 res 1
temp_var2 res 1
temp_var3 res 1
temp_var4 res 1