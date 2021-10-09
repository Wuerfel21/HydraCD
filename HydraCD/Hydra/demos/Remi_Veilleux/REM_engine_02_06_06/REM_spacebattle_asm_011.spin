''*************************************
''*  Rem Space Battle ASM engine v010 *
''*************************************

CON

  SCANLINE_BUFFER = $7F00
  MAPSIZEX = 32
  MAPSIZEX_SHIFT = 5
  MAPSIZEY = 88
  

PUB start(paramadr)

'' Start REM engine - starts a cog
  cognew(@entry, paramadr)

DAT

                        org

' Entry
'
entry                   mov dira, #1 ' enable debug led port
                        ' fetch some parameter, starting at 'par':
                        ' 0 = tilemap_adr
                        ' 4 = tiles_adr
                        ' 8 = tv_status
                        ' 16 = color palette 0
                        mov t2,par
                        rdlong tilemap, t2 ' store colors address

                        add t2, #4
                        rdlong tiles, t2 ' store colors address

                        add t2, #4
                        rdlong tv_status, t2 ' store tv_status address
                        
                        add t2, #4
                        rdlong colors, t2 ' store colors address

                        add t2, #4 ' skip gamepad

                        add t2, #4
                        rdlong cognumber, t2 ' store cog number (0,1,...)

                        add t2, #4
                        rdlong cogtotal, t2 ' store total number of cogs (1,2,...)

                        call #readgamepad

main_loop
                        call #waitrequest_start
                        ' Good: all cogs will now prepare a scanline internally

                        ' Here, prepare the scanline in internal memory
prepare_scanline
                        ' DEBUG helper: clear the scanbuffer with black
                        call #debugclear
                        ' This debug helper should be removed eventually

                        ' Take the currentscanline and add the vertical_scroll
                        mov y_offset, currentscanline
                        rdlong t1, vertical_scroll
                        add y_offset, t1

                        rdlong x_offset, horizontal_scroll

                        ' safety check: if trying to draw a line off the tilemap, then output a black scanline
                        cmp y_offset, max_tile_y wc, wz
        if_a            jmp #blacktiles

                        ' HERE we'll draw the 'LEFT PART' of the screen tile map
                        ' If x_offset is aligned to 32-bit, then all the screen is drawn
                        ' Else, they'll be from 1 to 31 lines not displayed, that will get
                        ' drawn during the 'RIGHT PART'.
                        
                        ' Start at tilemap 0,0
                        ' tilemap_offset = tilemap offset counter
                        mov tilemap_offset, #0
                        call #addscrolloffset

                        ' reset pointer to start of scanbuffer
                        movd copyfourpixell, #scanbuffer_prev

                        ' number of four-pixel to output = 65
                        mov l1, #65             ' 1 extra for horizontal scroll

                        ' Calculate things that won't change during a scanline:
                        mov lshift, x_offset
                        and lshift, #3
                        mov t1, lshift wz
        if_nz           mov shift_rpixel, shift_rpixel_instruction ' set self-modify code
        if_z            mov shift_rpixel, skip_rpixel_instruction ' to either shift or move
                        ' I have to do this because shr and shl can't shift by 32 bit :(
                        shl lshift, #3

                        mov rshift, #4
                        sub rshift, t1
                        shl rshift, #3

                        add tilemap_offset, tilemap

                        mov y_tile_offset, y_offset
                        and y_tile_offset, #15
                        shl y_tile_offset, #4
                        add y_tile_offset, tiles

nexttile

' Fetch tile (32-bit) pixel into 'tilepixel'
fetchtile
                        mov t2, tilemap_offset

                        ' Now add x offset / 16 : this will give us a full tile offset
                        mov t1, x_offset
                        shr t1, #4
                        add t2, t1
                        
                        mov t1, x_offset
                        and t1, #%1100
                        add t1, y_tile_offset

                        ' Fetch the current tile in t2
                        rdbyte t2, t2
                        shl t2, #8              ' Each tile is 256 bytes
                        ' t2 will point to the tile memory
                         '  add the current scanline & 15 line offset for this tile
                        ' finally add the 32-bit offset
                        add t2, t1

                        rdlong t1, t2           ' Pixel read into t1
                        mov tilepixel, t1
shift_rpixel            shl tilepixel, rshift
                        or tilepixel, nexttilepixel
                        
                        mov nexttilepixel, t1
                        shr nexttilepixel, lshift
                        
copyfourpixell          or scanbuffer, tilepixel
                        add copyfourpixell, destination_increment

                        ' advance to next four pixel
                        add x_offset, #4
                        djnz l1, #nexttile

tilesfinished
                        ' Debug waste time to see about how many clock we still have for this line
                        {mov l1, wasteclock
:waste                  djnz l1, #:waste}


                        ' Verification: if the TV is already asking for this scanline or more
                        ' (except scanline 0), then lit the debug led: we have failed preparing this
                        ' scanline in time: we need to optimize or use more cog
                        cmp currentrequest, #0 wz
        if_z            jmp #:wait
                        rdlong currentrequest, request_scanline
                        cmp currentrequest, currentscanline wz, wc
                        ' At this point, we could skip drawing sprites or something like that and go
                        ' straight to image output and still stay synced with the tv driver
                        ' We must be quick though!
        if_b            mov outa, #0
        if_ae           mov outa, #1
        if_ae           jmp #start_tv_copy

        
:wait                   ' Wait here until the TV request exactly the scanline that THIS cog prepared
                        ' Other cog will wait here a bit
                        rdlong currentrequest, request_scanline
                        cmp currentrequest, currentscanline wz, wc
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
                        
                        
                        ' Line is done, increment to the next one this cog will handle
                        
                        add currentscanline, cogtotal
                        cmp currentscanline, #191 wc, wz
        if_be           jmp #prepare_scanline

                        ' The screen is completed, jump back to main loop a wait for next frame
                        jmp #main_loop

' Instruction that will get copied over at line 'shift_rpixel'
shift_rpixel_instruction shl tilepixel, rshift
skip_rpixel_instruction mov tilepixel, #0

' Output all black when drawing off-map stuff
blacktiles
                        call #debugclear
                        jmp #tilesfinished

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
                        rdlong currentrequest, request_scanline
                        cmp currentrequest, #0 wz ' Wait until TV ask for scanline 0
        if_nz           jmp #waitrequest_start
waitrequest_start_ret   ret

' Add scroll offset
addscrolloffset
                        ' add (currentscanline >> 4) * MAPSIZEX
                        mov t1, y_offset
                        shr t1, #4
                        shl t1, #MAPSIZEX_SHIFT
                        add tilemap_offset, t1
addscrolloffset_ret     ret


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

readgamepad             mov t2, par
                        add t2, #16
                        rdlong gamepad, t2
                        and gamepad, #$ff
readgamepad_ret         ret

waitvbl
:wait_status_1          rdlong t1, tv_status
                        cmp t1, #1              wz
        if_e            jmp #:wait_status_1

:wait_status_2          rdlong t1, tv_status
                        cmp t1, #2              wz
        if_e            jmp #:wait_status_2
waitvbl_ret             ret

wastetime
                        mov time, cnt
                        add time, period
                        waitcnt time,period
wastetime_ret           ret

display_base            long SCANLINE_BUFFER
request_scanline        long SCANLINE_BUFFER-4
vertical_scroll         long SCANLINE_BUFFER-8
horizontal_scroll       long SCANLINE_BUFFER-12

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
tv_status long          $0
colors long             $0
gamepad long            $0
cognumber long          $0
currentscanline long    $0
currentrequest long     $0
cogtotal long           $0
debug_v1 long           $0
debug_v2 long           $0
wasteclock long         2400

tilemap_offset long     $0
tilepixel long          $0
nexttilepixel long      $0
lshift long             $0
rshift long             $0
y_offset long           $0
x_offset long           $0
y_tile_offset long      $0
max_tile_y long         (MAPSIZEY*16-1)


fit 240
scanbuffer_prev res     4
scanbuffer res          64