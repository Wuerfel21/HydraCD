''*******************************
''*  Rem ASM engine helper v011 *
''*******************************

{
  REM graphic engine helper, used by REM_engine_011
}
CON
  NES_RIGHT  = %00000001
  NES_LEFT   = %00000010
  NES_DOWN   = %00000100
  NES_UP     = %00001000
  NES_START  = %00010000
  NES_SELECT = %00100000
  NES_B      = %01000000
  NES_A      = %10000000

  COMMAND_ADR = $5000 - 4*8

PUB start(paramadr)

'' Start REM engine helper - starts a cog
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
                        rdlong screen_adr, t2 ' store screen tile and color table address

                        add t2, #4
                        rdlong numbers_adr, t2 ' debug numbers data

                        add t2, #4
                        rdlong doormap_adr, t2 ' door tile map data

main_loop               ' Wait for a command order
waitinputcommand        rdlong t1, command_exec wz
        if_z            jmp #waitinputcommand
                        mov input_cmd, t1
                        add input_cmd, #128

                        rdlong p1, command_p1
                        rdlong p2, command_p2
                        rdlong p3, command_p3

                        cmp t1, #16 wz, wc      ' Check if command is between 1 and 15
        if_ae           jmp #waitinputcommand

                        sub t1, #1
                        add t1, #command_jumptable
                        jmp t1

command_ret             
                        ' Clear command flag
                        wrlong input_cmd, command_exec
                        jmp #main_loop

command_jumptable       jmp #printhex
                        jmp #drawsprite
                        jmp #drawscore
                        jmp #initialize_field
                        jmp #press_start_msg
                        jmp #eat_pellet
                        jmp #try_close_door
                        jmp #restart_level


drawsprite              ' draw at a pseudo-sprite. In this engine, sprite can be either 'x' OR 'y' tile-aligned:
                        ' i.e.: if x is a multiple of 16, then y is free: sprite will be drawn over two vertical tiles
                        ' i.e.: if y is a multiple of 16, then x is free: sprite will be drawn over two horizontal tiles

                        ' starting at 'display_base + p1 * 64 + p2 * 1024' the tile from memory 'tiles + p3 * 64'
                        ' and spanning 1 or 2 tiles
                        ' start y:  (y&15 * 4) + ((y >> 4) << 10)

                        mov t7, tiles
                        shl p3, #6
                        add t7, p3

                        mov t6, p2
                        and t6, #15 wz ' Check if Y is aligned to 16
        if_z            jmp #horizontal_sprite
                        
                        mov l4, t6
                        mov l5, #16
                        sub l5, t6
                        shl t6, #2

                        mov t1, p2
                        shr t1, #4
                        shl t1, #10
                        add t6, t1

                        ' add x
                        shr p1, #4
                        shl p1, #6
                        add t6, p1
                        
                        add t6, display_base
                        
                        ' loop for '16 - (y & 15)' lines to display first half of sprite
                        ' Note: this loops from 1 to 16 times
:copy_tile
                        rdlong t8, t7
                        add t7, #4
                        rdlong t5, t6 ' OR sprite instead of move
                        or t8, t5
                        wrlong t8, t6
                        add t6, #4
                        djnz l5, #:copy_tile

                        ' now we display the bottom half of sprite by jumping down to the next row of tile
                        ' Note: this loops from 0 to 15 times
                        test l4, #$ff wz
        if_z            jmp #command_ret

                        add t6, sprite_next_row_increment
:copy_tile2
                        rdlong t8, t7
                        add t7, #4
                        rdlong t5, t6 ' OR sprite instead of move
                        or t8, t5
                        wrlong t8, t6
                        add t6, #4
                        djnz l4, #:copy_tile2
                        
                        jmp #command_ret

                        
horizontal_sprite       ' Drawing a horizontal sprite is a bit more complex:
                        ' We have to shift the data for the left and right part of sprite
                        mov t6, p2
                        shl t6, #6 ' Multiply Y by 64 since we know Y is 16 aligned

                        ' add 'x & 15' to the display offset
                        mov t5, p1
                        shr t5, #4
                        shl t5, #6
                        add t6, t5
                        add t6, display_base

                        ' now, get by how many pixel we'll have to shift the sprite
                        mov t4, p1
                        and t4, #15
                        shl t4, #1 ' t4 now holds (x&15)*2 bit                        

                        ' now draw the 'left part' of the sprite
                        mov l5, #16
:copy_tile
                        rdlong t8, t7
                        add t7, #4

                        shl t8, t4 'shift the pixels!
                        
                        rdlong t5, t6 ' OR sprite instead of move
                        or t8, t5
                        wrlong t8, t6
                        add t6, #4
                        djnz l5, #:copy_tile

                        ' and now draw the 'right part' of the sprite, if needed
                        test t4, #$ff wz
        if_z            jmp #command_ret

                        sub t7, #64
                        
                        mov l5, #16
                        neg t4, t4
                        add t4, #32
:copy_tile2
                        rdlong t8, t7
                        add t7, #4

                        shr t8, t4 'shift the pixels the other way
                        
                        rdlong t5, t6 ' OR sprite instead of move
                        or t8, t5
                        wrlong t8, t6
                        add t6, #4
                        djnz l5, #:copy_tile2

                        jmp #command_ret

 
' printhex: print at position p1,p2 the number p3 (16-bit)
printhex                mov t8, display_base

' byte[display_base][((x&!15)<<2) + ((x&15) >> 2) + ((y&15)<<2) + ((y&!15)<<6)] := pixel
                        ' ((x&15) >> 2)
                        'mov t1,p1
                        'and t1, #15
                        'shr t1, #2
                        'add t8, t1
                        add t8, #3

                        ' ((x&!15)<<2)
                        mov t1, p1
                        and t1, #(!15) & $1FF
                        shl t1, #2
                        add t8, t1

                        ' ((y&%1000)<<2)
                        mov t1, p2
                        and t1, #%1000
                        shl t1, #2
                        add t8, t1

                        ' ((y&!15)<<6)
                        mov t1, p2
                        and t1, #(!15) & $1FF
                        shl t1, #6
                        add t8, t1

                        ' repeat i from 0 to 3 (16-bit number display)
                        mov l1, #4
:loop_character
          
                        ' temp := num & $f
                        mov t1, p3
                        and t1, #15
                        ' num := num >> 4
                        shr p3, #4


'     repeat i2 from 0 to 4
'       putbytepixel(x + 28 - (i<<2), y + i2, byte[@numbers][temp*5 + i2])
                        ' temp*5
                        shl t1, #3
                        add t1, numbers_adr

                        rdlong t2, t1
                        add t1,#4
                        rdlong t3, t1
                        
                        wrbyte t2, t8 ' output the 4 pixel
                        add t8, #4 ' jump to next row of this tile
                        ror t2, #8

                        wrbyte t2, t8 ' output the 4 pixel
                        add t8, #4 ' jump to next row of this tile
                        ror t2, #8

                        wrbyte t2, t8 ' output the 4 pixel
                        add t8, #4 ' jump to next row of this tile
                        ror t2, #8

                        wrbyte t2, t8 ' output the 4 pixel
                        add t8, #4 ' jump to next row of this tile

                        wrbyte t3, t8 ' output the 4 pixel

                        sub t8, #17 ' Move out 4 rows and go to the next 4 pixel on the left

                        djnz l1, #:loop_character

                        jmp #command_ret

' Draw score and highscore on screen
drawscore               ' start by drawing life counter
                        mov t2, tilemap
                        add t2, #191            ' Tile 15,11
                        add p2, #26
                        wrbyte p2, t2

                        ' now display score
                        mov t2, tilemap
                        add t2, #3
                        
                        mov l1, #4
:loop_score
                        mov p2, #10
                        call #divide

                        ' set tilemap for score tilemap[0..4] to tiles from 26 (0) to 35 (9)
                        add p2, #26
                        wrbyte p2, t2
                        sub t2, #1
                        djnz l1, #:loop_score                        

                        mov t2, tilemap
                        add t2, #10
                        
                        mov p1, p3
                        mov l1, #4
:loop_score2
                        mov p2, #10
                        call #divide

                        ' set tilemap for score tilemap[0..4] to tiles from 26 (0) to 35 (9)
                        add p2, #26
                        wrbyte p2, t2
                        sub t2, #1
                        djnz l1, #:loop_score2

                        ' We 'abuse' the fact that drawscore will be called each frame
                        ' to increment the frame counter here
                        call #frame_tick
                        
                        jmp #command_ret

                        ' Initialize the playfield by recopying the whole 'tilemap' into vram
initialize_field        mov l1, #192
                        mov l2, tilemap
                        mov p1, #0
                        mov p2, #0
:loop_init_field        rdbyte p3, l2
                        call #drawtile
                        add p1, #1
                        cmp p1, #16 wz
        if_e            mov p1, #0
        if_e            add p2, #1
                        add l2, #1
                        djnz l1, #:loop_init_field

                        jmp #command_ret

' Set palette of 'press start' and controller image
press_start_msg
                        mov gamepad, p1
                        mov framecount, p2
                        
                        mov p1, #6
                        mov p2, #8
                        mov p3, #3
                        call #setpalette
                        mov p1, #7
                        call #setpalette
                        mov p1, #8
                        mov p3, #4
                        call #setpalette
                        mov p1, #9
                        mov p3, #4
                        call #setpalette
                        ' draw controller image
                        mov p1, #8
                        mov p2, #8
                        mov p3, #24
                        call #drawtile                        
                        mov p1, #9
                        mov p3, #25
                        call #drawtile

' If controller is not plugged, display appropriate message on screen                        
                        cmp gamepad, #$ff wz
                        mov p3, #22
                        mov p4, #23
        if_e            mov p3, #37
        if_e            mov p4, #38

                        mov p1, #6
                        mov p2, #8
                        call #drawtile                        
                        mov p1, #7
                        mov p2, #8
                        mov p3, p4
                        call #drawtile

                        ' Now, make the message blink
                        mov t1, framecount
                        and t1, #%100000 wz
                        mov p2, black
        if_e            mov p2, title_color
                        mov p1, #3
                        call #setcolors
                        mov p2, black
        if_e            mov p2, joypad_color
                        mov p1, #4
                        call #setcolors

                        jmp #command_ret


frame_tick              add framecount, #1

                        call #fade_all_wall
frame_tick_ret          ret


fade_all_wall           mov l1, closed_wall1
                        mov l2, closed_wall1_timer
                        mov l3, #8
                        call #fadewall
                        mov closed_wall1, l1
                        mov closed_wall1_timer, l2

                        mov l1, closed_wall2
                        mov l2, closed_wall2_timer
                        mov l3, #9
                        call #fadewall
                        mov closed_wall2, l1
                        mov closed_wall2_timer, l2
fade_all_wall_ret       ret


' Make a closed-door wall flicker and fade
fadewall
                        ' Check if we have an active wall
                        cmp l1, #0 wz
        if_z            jmp #fadewall_ret

                        cmp l2, #128 wc, wz
        if_ae           jmp #:skip_flicker

                        ' Make the wall blink a bit before it ends
                        mov p1, l3
                        mov p2, wall_close_color2
                        mov t1, l2
                        cmp l2, #50 wc, wz
        if_a            shr t1, #1
                        shr t1, #2
                        and t1, #%1 wz
        if_z            mov p2, wall_close_color1
                        call #setcolors

:skip_flicker           ' Make it fade over time
                        sub l2, #1 wz
        if_nz           jmp #fadewall_ret

                        ' Wall has completely elapsed, make it disappear
                        mov t1, l1
                        add t1, tilemap
                        mov t2, #10             ' Empty space
                        wrbyte t2, t1
                        mov t1, l1
                        mov p3, #2              ' Normal hero and pellet color
                        call #setpalette_adress
                        
                        mov l1, #0

fadewall_ret            ret

' Try to close a door, if possible
' Conditions to check:
'   - Player must have crossed a door-line
'   - A door must be available: only two doors can be closed at the same time
'   - Player must not be standing 'inside' the door

try_close_door          cmp last_wallpos, #0 wz ' Player has crossed a door-line?
        if_z            jmp #command_ret

                        cmp closed_wall1, #0 wz ' Door 1 or door 2 must be free
        if_z            jmp #:door_free
                        cmp closed_wall2, #0 wz
        if_z            jmp #:door_free
                        jmp #command_ret

:door_free
                        ' calculate [((hero_x + 8) >> 4) + ((hero_y+8)>>4) << 4] into t1
                        mov t1, p1
                        add t1, #8
                        shr t1, #4
                        
                        mov t2, p2
                        add t2, #8
                        and t2, #(!15) & $1FF
                        add t1, t2

                        cmp t1, last_wallpos wz ' Is player currently standing inside this tile?
        if_ne           jmp #:ok
                        mov p3, #1              ' return '1' in p3 to indicate that we'll try to close
                        wrlong p3, command_p3   ' this door again next frame because player is in the way
                        jmp #command_ret

:ok
                        ' Close the door: either horizontal or vertical
                        mov t1, last_wallpos
                        add t1, tilemap

                        mov t2, #45
                        mov t3, last_wallpos
                        add t3, doormap_adr
                        rdbyte t3, t3
                        cmp t3, #2 wz
        if_z            add t2, #1
                        
                        wrbyte t2, t1           ' Door tile set

                        ' Now set palette of this tile to wall color

                        cmp closed_wall1, #0 wz
        if_nz           jmp #:wall2
        
                        mov closed_wall1, last_wallpos
                        mov closed_wall1_timer, wall_close_duration
                        mov p3, #8              ' Wall color
                        jmp #:done
:wall2
                        mov closed_wall2, last_wallpos
                        mov closed_wall2_timer, wall_close_duration
                        mov p3, #9              ' Wall color

:done
                        mov t1, last_wallpos
                        call #setpalette_adress
                        mov p3, #0              ' Careful to clear out p3
                        mov last_wallpos, #0    ' Clear last wall
                        
                        jmp #command_ret
                        
eat_pellet              ' p1 = hero_x,  p2 = hero_y,  p3 = return value 1 if eat a pellet
                        ' First, check if the tile we are in
                        ' tilemap[((hero_x + 8) >> 4) + ((hero_y+8)>>4) << 4]
                        ' hero_x+8&15 must be > 4 and < 12
                        ' hero_y+8&15 must be > 4 and < 12
                        ' At the same time, we'll check into 'doormap[]' to see if we are crossing
                        ' a potential door tile
                        mov t1, p1
                        add t1, #8
                        mov t2, t1
                        and t2, #15
                        cmp t2, #4 wz, wc
        if_be           jmp #command_ret
                        cmp t2, #12 wz, wc
        if_a            jmp #command_ret

                        mov t2, p2
                        add t2, #8
                        mov t3, t2
                        and t3, #15
                        cmp t3, #4 wz, wc
        if_be           jmp #command_ret
                        cmp t3, #12 wz, wc
        if_a            jmp #command_ret
                        
                        shr t1, #4
                        and t2, #(!15) & $1FF
                        add t1, t2

                        mov t4, t1
                        add t4, doormap_adr
                        rdbyte t2, t4 wz        ' read the doortile
        if_z            jmp #checkpellet

                        mov last_wallpos, t4    ' Remember the last doortile we have walked on
                        sub last_wallpos, doormap_adr

checkpellet
                        add t1, tilemap
                        rdbyte t2, t1

                        mov t3, #1
                        cmp t2, #7 wz           ' if value of tile is 7, it's a pellet
        if_z            jmp #:pellet

                        mov t3, #2
                        cmp t2, #51 wz          ' if value of tile is 51, it's a cash bonus
        if_nz           jmp #command_ret        ' something else? go away!

:pellet
                        mov t2, #10
                        wrbyte t2, t1           ' replace the pellet/cash with an empty space
                        
                        wrlong t3, command_p3
                        jmp #command_ret

' Restart level: clear some variable
restart_level
                        mov last_wallpos, #0
                        mov closed_wall1_timer, #1
                        mov closed_wall2_timer, #1
                        call #fade_all_wall
                        jmp #command_ret
           
drawtile                ' draw at 'display_base + p1 * 64 + p2 * 1024' the tile from memory 'tiles + p3 * 64'
                        mov t6, p2
                        shl t6, #4
                        add t6, p1
                        shl t6, #6
                        add t6, display_base
                        
                        mov t7, tiles
                        shl p3, #6
                        add t7, p3
                        mov l5, #16
:copy_tile
                        rdlong t8, t7
                        add t7, #4
                        wrlong t8, t6
                        add t6, #4
                        djnz l5, #:copy_tile
drawtile_ret            ret

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

' Setpalette: Set the color-palette index for the tile 'p1, p2' to 'p3'
' screen_adr[x + y * 16] |= (color_palette << 10)
setpalette
                        mov t1, p2
                        shl t1, #4
                        add t1, p1
setpalette_adress
                        shl t1, #1
                        add t1, screen_adr
                        rdword t2, t1
                        
                        and t2, and_mask_palette
                        mov t3, p3
                        shl t3, #10
                        add t2, t3
                        wrword t2, t1
setpalette_adress_ret
setpalette_ret          ret

'setcolors: set 4 color of palette 'p1' to value 'p2'
setcolors               mov t1, p1
                        shl t1, #2
                        add t1, colors
                        wrlong p2, t1
setcolors_ret           ret

display_base long       $5000
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

input_cmd long          $0

command_p1 long         COMMAND_ADR
command_p2 long         COMMAND_ADR+4
command_p3 long         COMMAND_ADR+8
command_exec long       COMMAND_ADR+28

empty long              $0
full long               $ffffffff
time long               $0
period long             220000
framecount long         $0
tilemap long            $0
tiles long              $0
tv_status long          $0
screen_adr long         $0
colors long             $0
numbers_adr long        $0
doormap_adr long        $0
gamestate long          $0
gamepad long            $0
black long              $02020202
title_color long        $6e6c6b02
joypad_color long       $fe040302
wall_close_color1 long  $07bbba02
wall_close_color2 long  $076ebb02
and_mask_palette long   %1111111111
sprite_next_row_increment long 960  ' this is one full row of tile bytes, minus one 1024 - 64
debug_v1 long           $0
debug_v2 long           $0
wall_close_duration long 350

last_wallpos long       $0
closed_wall1 long       $0
closed_wall1_timer long $0
closed_wall2 long       $0
closed_wall2_timer long $0