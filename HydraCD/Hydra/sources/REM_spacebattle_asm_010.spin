''*************************************
''*  Rem Space Battle ASM engine v010 *
''*************************************

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

                        mov t8, #192

main_loop
                        mov currentscanline, cognumber
                        rdlong currentrequest, request_scanline
                        cmp currentrequest, #0 wz ' Wait until TV ask for scanline 0
        if_nz           jmp #main_loop
                        ' Good: all cogs will now prepare a scanline internally

prepare_scanline
                        ' TODO: Here, prepare the scanline in internal memory
                        '

:wait                   ' Wait here until the TV request exactly the scanline that THIS cog prepared
                        ' Other cog will wait here a bit
                        rdlong currentrequest, request_scanline
                        cmp currentrequest, currentscanline wz
        if_ne           jmp #:wait

                        mov t1, display_base
                        mov l1, #64
                        
                        'mov t2, #$BC
                        {
                        add t2, cognumber

                        ' debug
                        cmp currentscanline, #101 wz
        if_z            add t2, #1}
{       
:colorset
                        mov t3, t2
                        shl t3, #8
                        add t3, t2
                        shl t3, #8
                        add t3, t2
                        shl t3, #8
                        add t3, t2

:nextpixel              
                        wrlong t3, t1
                        add t1, #4
                        djnz l1, #:nextpixel
}
                        ' t1 = destination memory (in scanline buffer)
                        ' t3 = the four-pixel long to write

                        ' t2 = tiles + (currentscanline&15 << 4) + (currentscanline >> 4) * 2560
                        mov t2, tiles
                        mov t3, currentscanline
                        cmp t3, #96 wc, wz
        if_ae           mov l2, #64
        if_ae           jmp #blackleft
                        
                        and t3, #15
                        shl t3, #4
                        add t2, t3

                        ' x * 2560 is equal to (x<<11) + (x<<9)
                        mov t3, currentscanline
                        shr t3, #4
                        shl t3, #9
                        add t2, t3
                        shl t3, #2
                        add t2, t3
                        

' Test: output one tile then skip to next (160 pixel)

                        mov l1, #40/4
                        mov l2, #64-40
:nextpixel              
                        rdlong t3, t2
                        add t2, #4
                        wrlong t3, t1
                        add t1, #4
                        rdlong t3, t2
                        add t2, #4
                        wrlong t3, t1
                        add t1, #4
                        rdlong t3, t2
                        add t2, #4
                        wrlong t3, t1
                        add t1, #4
                        rdlong t3, t2
                        add t2, #244
                        wrlong t3, t1
                        add t1, #4
                        djnz l1, #:nextpixel

blackleft               
                        ' output black remaining pixels (256-160)
:nextpixel2             
                        wrlong black, t1
                        add t1, #4
                        djnz l2, #:nextpixel2
                        
                        ' Line is done, increment to the next one this cog will handle
                        
                        add currentscanline, cogtotal
                        cmp currentscanline, #191 wc, wz
        if_be           jmp #prepare_scanline

                        ' The screen is completed, jump back to main loop a wait for next frame
                        jmp #main_loop

                        
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
black long              $02020202
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

fit 432