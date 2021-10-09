''*************************************
''*  Rem Graphic engine v013          *
''*************************************

CON

  SCANLINE_BUFFER = $7F00
  MAPSIZEX = 20
  MAPSIZEX_SHIFT = 2
  MAPSIZEX_SHIFT2 = 2
  ' MAPSIZEX must be equal to 1<<MAPSIZEX_SHIFT + 1<<(MAPSIZEX_SHIFT + MAPSIZEX_SHIFT2)
  MAPSIZEY = 256
  

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
        if_z            call #setspriteanim

                        add framecount, #1
        
                        ' Good: all cogs will now prepare a scanline internally

                        ' Here, prepare the scanline in internal memory
prepare_scanline
                        ' DEBUG helper: clear the scanbuffer with black
                        ' call #debugclear
                        ' This debug helper should be removed eventually

                        ' Take the currentscanline and add the vertical_scroll
                        mov y_offset, currentscanline
                        rdlong t1, vertical_scroll
                        add y_offset, t1

                        rdlong x_offset, horizontal_scroll
                        mov sprite_a_offset, x_offset

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

                        ' safety check: if trying to draw a line off the tilemap, then output a black scanline
                        {
                        cmp y_offset, max_tile_y wc, wz
        if_a            jmp #blacktiles}
                        and y_offset, max_tile_y

                        ' Start at tilemap 0,0
                        ' tilemap_offset = tilemap offset counter
                        ' skip 32 first tiles because they represent the top and bottom non-scrolling portion
                        mov tilemap_offset, #32
                        call #addscrolloffset

                        ' reset pointer to start of scanbuffer
                        movd copyfourpixel, #scanbuffer_prev ' ..but go back 32-bit because we'll output 65 long

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
                        ' finally add the 32-bit x-offset
                        add t2, t1

                        rdlong t1, t2           ' Pixel read into t1
                        mov tilepixel, t1
shift_rpixel            shl tilepixel, rshift
                        or tilepixel, nexttilepixel
                        
                        mov nexttilepixel, t1
                        shr nexttilepixel, lshift
                        
copyfourpixel           mov scanbuffer, tilepixel
                        add copyfourpixel, destination_increment

                        ' advance to next four pixel
                        add x_offset, #4
                        djnz l1, #nexttile

tilesfinished
{                       ' Debug waste time to see about how many clock we still have for this line
                        mov l1, wasteclock
:waste                  djnz l1, #:waste
}
                        ' Here we draw the sprites!
                        ' Between each sprite, we should do a checktv in case we spent too much time in this line

startsprite
                        ' DEBUG: draw shadow sprite
                        mov t1, framecount
                        and t1, #1 wz
        if_nz           jmp #skip_shadow

                        mov spriteoutput, shadowoutput_instruction
                        mov master_sprite_offset_x, #4
                        mov master_sprite_offset_y, #6
                        call #drawspriteproc

skip_shadow
                        mov spriteoutput, spriteoutput_instruction
                        mov master_sprite_offset_x, #0
                        mov master_sprite_offset_y, #0
                        call #drawspriteproc
                        jmp #scanlinefinished

drawspriteproc
                        mov l5, max_nb_sprite   ' TODO: l5 is 'number of sprites'
                        
                        ' Let's iterate for each sprites
                        ' The first sprite starts at firstsprite_adr
                        mov sprite_p_adr, fsprite_p_adr
                        mov sprite_x_adr, fsprite_x_adr
                        mov sprite_y_adr, fsprite_y_adr
                        mov sprite_s_adr, fsprite_s_adr
                        mov sprite_a_adr, fsprite_a_adr

nextsprite
                        ' If address == 0, this sprite is disabled.
                        rdlong sprite_p, sprite_p_adr wz
        if_z            jmp #spritedone

                        ' Perform Y check:
                        ' sprite_y = currentscanline - sprite_y
                        ' if sprite_y < 0, out
                        ' if sprite_y >= height, out
                        ' Fetch sprite_h and sprite_wshift by unpacking from sprite_s_adr
                        rdlong sprite_h, sprite_s_adr
                        mov sprite_wshift, sprite_h
                        shr sprite_wshift, #8
                        and sprite_h, #$ff

                        rdlong t1, sprite_y_adr
                        sar t1, #7              ' X and Y pos are fixed-point 7-bit
                        mov sprite_y, currentscanline
                        sub sprite_y, t1
                        sub sprite_y, master_sprite_offset_y
                        
                        cmp sprite_y, sprite_h wc, wz
        if_ae           jmp #spritedone

                        ' sprite_s contains the 'shift width': translate this into a real pixel width here
                        mov sprite_s, #1
                        shl sprite_s, sprite_wshift

                        ' Perform X check:
                        rdlong sprite_x, sprite_x_adr
                        sar sprite_x, #7        ' X and Y pos are fixed-point 7-bit
                        ' Adjust x according to horizontal map scroll
                        sub sprite_x, sprite_a_offset
                        add sprite_x, master_sprite_offset_x
                        
                        mov t1, sprite_x
                        add t1, sprite_s
                        cmps t1, #0 wc, wz
        if_be           jmp #spritedone
                        
                        cmps sprite_x, #256 wc, wz
        if_ae           jmp #spritedone

                        mov l1, sprite_s
                        shr l1, #2
                        add l1, #1

                        ' Check if sprite is partially outside screen on the left
                        sub t1, #256 wc, wz
        if_a            shr t1, #2              ' Yes? So let's skip group of four pixel that are outside
        if_a            sub l1, t1
                        
                        ' Check if sprite is partially outside screen on the right
                        mov t1, sprite_x
                        cmps t1, #0 wc, wz
        if_ae           jmp #:x_not_negative
                        ' Sprite is partially outside screen
                        neg t1, t1
                        shr t1, #2

                        ' substract number of pixel to output because some of them are outside
                        sub l1, t1

                        ' skip some pixel data
                        shl t1, #2
                        add sprite_p, t1

                        add sprite_x, t1
        
:x_not_negative         sub sprite_x, #1
                        mov lshift, sprite_x

                        ' Set starting X position in scanbuffer
                        shr sprite_x, #2
                        mov t1, #scanbuffer
                        add t1, sprite_x
                        movd spriteoutput, t1
                        movd spriteoutputand, t1
                        '
                        mov t1, sprite_y
                        shl t1, sprite_wshift
                        add sprite_p, t1
                        
                        and lshift, #3
                        neg lshift, lshift
                        add lshift, #3
                        
                        mov t1, lshift wz
        if_nz           mov shift_rpixel_sprite, shift_rpixel_instruction ' set self-modify code
        if_z            mov shift_rpixel_sprite, skip_rpixel_instruction ' to either shift or move
                        ' I have to do this because shr and shl can't shift by 32 bit :(
                        shl lshift, #3

                        mov rshift, #4
                        sub rshift, t1
                        shl rshift, #3

                        mov nexttilepixel, #0
                        
nextspritepixel         
                        cmp l1, #1 wz           ' Nullify last pixel
        if_e            mov t1, #0
        if_ne           rdlong t1, sprite_p ' Pixel read into t1
        
                        mov tilepixel, t1
shift_rpixel_sprite     shl tilepixel, rshift
                        or tilepixel, nexttilepixel wz

                        mov nexttilepixel, t1
                        shr nexttilepixel, lshift

        if_z            jmp #skipblackpixel     ' Optimisation: skip this whole 32-bit pack if it's all 0s.

                        ' here tilepixel contains the four pixel we want to output
                        ' we'll build a mask in t3 for all non-0 pixel
                        mov t3, full

                        test tilepixel, mask_pixel1 wz
        if_nz           xor t3, mask_pixel1
                        test tilepixel, mask_pixel2 wz
        if_nz           xor t3, mask_pixel2
                        test tilepixel, mask_pixel3 wz
        if_nz           xor t3, mask_pixel3
                        test tilepixel, mask_pixel4 wz
        if_nz           xor t3, mask_pixel4

spriteoutputand         and scanbuffer, t3
spriteoutput            or scanbuffer, tilepixel        ' TODO: Replace this instruction by nop for shadow sprite
skipblackpixel
                        add spriteoutputand, destination_increment
                        add spriteoutput, destination_increment
                        add sprite_p, #4
                        ' advance to next four pixel
                        djnz l1, #nextspritepixel

spritedone
                        call #checktv           ' Check if we have enough time for another sprite
                        
                        sub sprite_p_adr, #20
                        sub sprite_x_adr, #20
                        sub sprite_y_adr, #20
                        sub sprite_s_adr, #20
                        sub sprite_a_adr, #20

                        djnz l5, #nextsprite
drawspriteproc_ret      ret

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

spriteoutput_instruction or scanbuffer, tilepixel
shadowoutput_instruction nop

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

' Add scroll offset
addscrolloffset
                        ' add (currentscanline / 16) * MAPSIZEX
                        mov t1, y_offset
                        shr t1, #4
                        shl t1, #MAPSIZEX_SHIFT
                        add tilemap_offset, t1
                        shl t1, #MAPSIZEX_SHIFT2
                        add tilemap_offset, t1
addscrolloffset_ret     ret

' Setup sprite animation pointer. This is only done on cog #0.
setspriteanim
                        mov l4, max_nb_sprite   ' TODO: l5 is 'number of sprites'
                        
                        ' Let's iterate for each sprites
                        ' The first sprite starts at firstsprite_adr
                        mov sprite_p_adr, fsprite_p_adr
                        mov sprite_a_adr, fsprite_a_adr
                        mov sprite_s_adr, fsprite_s_adr

:nextsprite
                        rdlong sprite_a, sprite_a_adr
                        sub sprite_a_adr, #20
                        ' p1 will store the 'sprite frame number'
                        mov p1, sprite_a
                        and p1, #$ff wz
                        ' sprite_a store the start address (frame 0)
                        shr sprite_a, #16

        if_z            jmp #:skipmultiply      ' Optimisation: skip multiply when frame number = 0

                        ' Check for special animation '255' which means skip display
                        cmp p1, #255 wz
        if_e            mov sprite_a, #0
        if_e            jmp #:skipmultiply

                        shr p1, #4              ' Frame number is fixed-point 4-bit

                        rdlong p2, sprite_s_adr
                        ' Now multiply sprite width * height * frame_number to get the offset
                        mov sprite_wshift, p2
                        shr sprite_wshift, #8
                        and p2, #$ff
                        shl p2, sprite_wshift

                        call #multiply
                        add sprite_a, p2
                        
:skipmultiply
                        wrlong sprite_a, sprite_p_adr
                        ' Move to next sprite
                        sub sprite_p_adr, #20
                        sub sprite_s_adr, #20

                        djnz l4, #:nextsprite
setspriteanim_ret       ret


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

firstsprite_adr         long SCANLINE_BUFFER-60
' First sprite is here, each sprites take 20 bytes (5 long)

' These are backup values to restore when drawing sprites
fsprite_x_adr           long SCANLINE_BUFFER-60
fsprite_y_adr           long SCANLINE_BUFFER-64
fsprite_s_adr           long SCANLINE_BUFFER-68
fsprite_a_adr           long SCANLINE_BUFFER-72
fsprite_p_adr           long SCANLINE_BUFFER-76

sprite_x_adr            long SCANLINE_BUFFER-60
sprite_y_adr            long SCANLINE_BUFFER-64
sprite_s_adr            long SCANLINE_BUFFER-68
sprite_a_adr            long SCANLINE_BUFFER-72
sprite_p_adr            long SCANLINE_BUFFER-76

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
mask_pixel1 long        $000000FF
mask_pixel2 long        $0000FF00
mask_pixel3 long        $00FF0000
mask_pixel4 long        $FF000000

tilemap_offset long     $0
tilepixel long          $0
nexttilepixel long      $0
lshift long             $0
rshift long             $0
y_offset long           $0
x_offset long           $0
y_tile_offset long      $0
max_tile_y long         (MAPSIZEY*16-1)
top_y long              $0
bottom_y long           $0
stop_y long             $0
sprite_a_offset long    $0

sprite_x long           $0
sprite_y long           $0
sprite_s long           $0
sprite_a long           $0
sprite_p long           $0
sprite_h long           $0
sprite_wshift long      $0
max_nb_sprite long      16

master_sprite_offset_x long 0
master_sprite_offset_y long 0

fit 430
scanbuffer_prev res     1                       ' One extra long on the left
scanbuffer res          65                      ' One extra long on the right