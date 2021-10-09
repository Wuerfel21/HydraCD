''*************************************************************
''*  Rem Graphic engine v014 - Special version for Floor Demo *
''*************************************************************

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

                        rdlong tilemap, tilemap_adr
                        rdlong tiles, tiles_adr

                        ' Syncronise all gfx cog with TV driver before starting
                        call #waitsyncro_start
                        
main_loop
                        call #waitrequest_start

                        ' Special case: cog #0 will prepare all sprite animation address offset
                        cmp cognumber, #0 wz

                        add framecount, #1
        
                        ' Good: all cogs will now prepare a scanline internally

                        ' Here, prepare the scanline in internal memory
prepare_scanline
                        ' DEBUG helper: clear the scanbuffer with black
                        ' call #debugclear
                        ' This debug helper should be removed eventually

                        ' Take the currentscanline and add the vertical_scroll
                        mov y_offset, currentscanline
                        rdlong x_offset, horizontal_scroll

                        ' Check if currentscanline has reached 'stop_y': this is where we stop
                        ' generating any new pixel data. This will be used to perform a 'curtain screen'
                        ' wipe effect.
                        rdlong stop_y, stop_y_adr
                        cmp currentscanline, stop_y wc, wz
        if_ae           jmp #scanlinedone

                        ' check if we are in the 'top y portion' of the screen (i.e.: non-scrolling)
                        rdlong top_y, top_y_adr
                        cmp currentscanline, top_y wc, wz
        if_b            jmp #top_portion

                        rdlong bottom_y, bottom_y_adr
                        cmp currentscanline, bottom_y wc, wz
        if_ae           jmp #bottom_portion

                        ' reset pointer to start of scanbuffer
                        movd copyfourpixel, #scanbuffer

                        ' number of pixel to output = 256
                        mov l1, #256

                        mov y_tile_offset, y_offset
                        and y_tile_offset, #127
                        shl y_tile_offset, #7
                        add y_tile_offset, tiles

                        mov bufferaccumulator, #0
                        mov buffercounter, #4

                        ' Setup 'xspeed' here
                        mov xspeed, #2
                        shl xspeed, #16
                        rdlong t1, mousey_adr
                        add t1, currentscanline
                        shl t1, #9
                        sub xspeed, t1

                        ' Here we should do:
                        ' x_offset = x_offset - xspeed * mousex
                        mov p1, xspeed
                        sar p1, #2
                        rdlong p2, mousex_adr
                        call #multiply
                        shl p2, #2
                        sub x_offset, p2
nextpixel

' Fetch pixel into 'tilepixel'
fetchtile
                        mov t1, x_offset
                        sar t1, #16
                        and t1, #%1111111
                        add t1, y_tile_offset

                        rdbyte tilepixel, t1    ' Pixel read into tilepixel

                        add bufferaccumulator, tilepixel
                        ror bufferaccumulator, #8
                        djnz buffercounter, #skipoutput
                        
copyfourpixel           mov scanbuffer, bufferaccumulator
                        add copyfourpixel, destination_increment

                        mov buffercounter, #4
                        mov bufferaccumulator, #0

skipoutput
                        ' advance to next pixel
                        add x_offset, xspeed
                        djnz l1, #nextpixel

tilesfinished

scanlinefinished        ' Check status of TV: warning: this is a pseudo-call: it might not return!
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
shift_rpixel_instruction shl tilepixel, rshift
skip_rpixel_instruction mov tilepixel, #0

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
        if_ae           jmp #start_tv_copy
checktv_ret             ret
        

' Draw 'top portion' non-scrolling. This will output a maximum of 16 lines of tile data,
' then if top_y needs more, black.
top_portion
                        cmp currentscanline, #16 wc, wz
        if_ae           jmp #blacktiles

                        ' Here we simply perform a 'turbo copy' of 16 tiles straight.
                        mov t5, currentscanline
                        mov tilemap_offset, tilemap

copy_top_and_bottom
                        movd :topportioncopy, #scanbuffer
                        mov l1, #64/4

:nexttile
                        rdbyte t2, tilemap_offset
                        mov t1, tiles
                        shl t2, #8
                        add t1, t2
                        mov t2, t5
                        shl t2, #4
                        add t1, t2

                        mov l2, #4
:nextpixel
                        rdlong tilepixel, t1
:topportioncopy         mov scanbuffer, tilepixel
                        add :topportioncopy, destination_increment
                        add t1, #4
                        djnz l2, #:nextpixel

                        add tilemap_offset, #1
                        djnz l1, #:nexttile
        
                        jmp #scanlinefinished

' Bottom portion is exactly like top portion, except that it starts on line 176,
' and its tilemap starts at tilemap + 16
bottom_portion
                        cmp currentscanline, #176 wc, wz
        if_b            jmp #blacktiles

                        mov t5, currentscanline
                        sub t5, #176
                        mov tilemap_offset, tilemap
                        add tilemap_offset, #16
                        jmp #copy_top_and_bottom

' Output all black when drawing off-map stuff
blacktiles
                        call #debugclear
                        jmp #scanlinefinished

' Helper proc to clear the scanbuffer
debugclear
                        movd :debugclear, #scanbuffer
                        mov l1, #64
:debugclear             mov scanbuffer, #0
                        add :debugclear, destination_increment
                        djnz l1, #:debugclear
debugclear_ret          ret

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

' Divide p1 by p2, return result (p1 / p2) into p1, and (p1 % p2) into p2
divide                  shl p2, #15
                        mov l5, #16
:loop                   cmpsub p1, p2 wc
                        rcl p1, #1
                        djnz l5, #:loop
                        
                        mov p2, p1
                        shl p1, #16
                        shr p1, #16
                        shr p2, #16
divide_ret              ret

' Multiply p1 by p2, return result in p2
multiply                shl p1, #16
                        mov l5, #16
                        shr p2, #1 wc
:loop   if_c            add p2, p1 wc
                        rcr p2, #1 wc
                        djnz l5, #:loop                        
multiply_ret            ret

readgamepad             mov t2, par
                        add t2, #16
                        rdlong gamepad, t2
                        and gamepad, #$ff
readgamepad_ret         ret

wastetime
                        mov time, cnt
                        add time, period
                        waitcnt time,period
wastetime_ret           ret

display_base            long SCANLINE_BUFFER
request_scanline        long SCANLINE_BUFFER-4
vertical_scroll         long SCANLINE_BUFFER-8
horizontal_scroll       long SCANLINE_BUFFER-12
top_y_adr               long SCANLINE_BUFFER-16
bottom_y_adr            long SCANLINE_BUFFER-20
stop_y_adr              long SCANLINE_BUFFER-24
tilemap_adr             long SCANLINE_BUFFER-28
tiles_adr               long SCANLINE_BUFFER-32
gamepad                 long SCANLINE_BUFFER-36
framecount_adr          long SCANLINE_BUFFER-40
mousex_adr              long SCANLINE_BUFFER-44
mousey_adr              long SCANLINE_BUFFER-48

' t1-8: temporary registers
t1 long                 $0
t2 long                 $0
t3 long                 $0
t4 long                 $0
t5 long                 $0
t6 long                 $0
t7 long                 $0
t8 long                 $0
' l1-5: loop registers
l1 long                 $0
l2 long                 $0
l3 long                 $0
l4 long                 $0
l5 long                 $0
' p1-7: parameter registers
p1 long                 $0
p2 long                 $0
p3 long                 $0
p4 long                 $0
p5 long                 $0
p6 long                 $0
p7 long                 $0

empty long              $0
full long               $ffffffff
black long              $0                      ' was $02020202 but now TV adds black
white long              $05050505               ' was $07070707 but now TV adds black
destination_increment long 512
time long               $0
period long             220000
framecount long         $0
tilemap long            $0
tiles long              $0
cognumber long          $0
currentscanline long    $0
currentrequest long     $0
cogtotal long           $0
debug_v1 long           $0
debug_v2 long           $0
wasteclock long         400

tilemap_offset long     $0
tilepixel long          $0
nexttilepixel long      $0
lshift long             $0
rshift long             $0
y_offset long           $0
x_offset long           $0
y_tile_offset long      $0
top_y long              $0
bottom_y long           $0
stop_y long             $0

buffercounter long      0
bufferaccumulator long  0
xspeed long             2<<16

fit 430
scanbuffer_prev res     1                       ' One extra long on the left
scanbuffer res          65                      ' One extra long on the right