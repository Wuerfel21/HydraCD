{
  REM lock'n chase police AI stuff, used by REM_engine_011
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

  ' This command enum must be sync with 'command_jumptable' in REM_engine_helper
  ' Command from 1 to 15 are for REM_engine_helper
  CMD_PRINTHEX = 1
  CMD_DRAWSPRITE = 2
  CMD_DRAWSCORE = 3
  CMD_INITIALIZE_FIELD = 4
  CMD_PRESS_START = 5
  CMD_EAT_PELLET = 6
  CMD_TRY_CLOSE_DOOR = 7
  CMD_RESTART_LEVEL = 8

PUB start(paramadr)

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

                        add t2, #4
                        rdlong snd_adr, t2 ' snd driver data

main_loop               ' Wait for a command order
waitinputcommand        rdlong t1, command_exec wz
        if_z            jmp #waitinputcommand
                        mov input_cmd, t1
                        add input_cmd, #128

                        rdlong p1, command_p1
                        rdlong p2, command_p2
                        rdlong p3, command_p3

                        sub t1, #16
                        cmp t1, #16 wz, wc      ' Check if command is between 16 and 32
        if_ae           jmp #waitinputcommand

                        add t1, #command_jumptable
                        jmp t1

command_ret             
                        ' Clear command flag
                        wrlong input_cmd, command_exec
                        jmp #main_loop

command_jumptable       jmp #restart_level
                        jmp #movepolice
                        jmp #policesad
                        jmp #playsound


' Restart level: clear some variable
restart_level
                        mov level, p1

                        mov police1_x, #1
                        mov police1_y, #6*16
                        mov police1_dir, #1

                        mov police2_x, #1
                        mov police2_y, #8*16
                        mov police2_dir, #1

                        mov police3_x, #223
                        mov police3_y, #6*16
                        mov police3_dir, #3

                        mov police4_x, #223
                        mov police4_y, #8*16
                        mov police4_dir, #3

                        mov police_sad_timer, #0
                        
                        jmp #command_ret

' Make police cry for a couple of second: player has taken the cash bonus
policesad
                        mov police_sad_timer, #200
                        mov t1, level
                        shl t1, #4
                        sub police_sad_timer, t1
                        jmp #command_ret


' update: move and draw four police guy
movepolice              add framecount, #1
                        mov hero_x, p1
                        mov hero_y, p2
                        ' Return default value 0: no collision
                        mov collision_detect, #0

                        cmpsub police_sad_timer, #1 wz,wc
        if_c            jmp #:skip_movement

                        mov t1, #0
                        mov policetemp_x, police1_x
                        mov policetemp_y, police1_y
                        mov policetemp_dir, police1_dir
                        call #move_one_police
                        mov police1_x, policetemp_x
                        mov police1_y, policetemp_y
                        mov police1_dir, policetemp_dir
                        
                        mov t1, #1
                        mov policetemp_x, police2_x
                        mov policetemp_y, police2_y
                        mov policetemp_dir, police2_dir
                        call #move_one_police
                        mov police2_x, policetemp_x
                        mov police2_y, policetemp_y
                        mov police2_dir, policetemp_dir

                        mov t1, #2
                        mov policetemp_x, police3_x
                        mov policetemp_y, police3_y
                        mov policetemp_dir, police3_dir
                        call #move_one_police
                        mov police3_x, policetemp_x
                        mov police3_y, policetemp_y
                        mov police3_dir, policetemp_dir

                        mov t1, #3
                        mov policetemp_x, police4_x
                        mov policetemp_y, police4_y
                        mov policetemp_dir, police4_dir
                        call #move_one_police
                        mov police4_x, policetemp_x
                        mov police4_y, policetemp_y
                        mov police4_dir, policetemp_dir

:skip_movement          
                        call #drawpolice
                        
                        wrlong collision_detect, command_p3

                        jmp #command_ret

move_one_police
                        ' compare t1 (police num) with framecount, to slow down police a bit
                        add t1, framecount
                        cmp level, #5 wz, wc
        if_ae           and t1, #3              ' Move police faster on level '1' and +
        if_b            and t1, #1              ' #3 slow by 1/4,  #7 slow by 1/8, ...

                        cmp t1, #0 wz
                        
        if_z            jmp #move_one_police_ret

                        ' Check if police is stuck in a closed door
                        mov t1, policetemp_x
                        add t1, #8
                        mov t2, t1
                        and t2, #15
                        cmp t2, #2 wz, wc
        if_be           jmp #:not_stuck
                        cmp t2, #14 wz, wc
        if_a            jmp #:not_stuck 

                        mov t2, policetemp_y
                        add t2, #8
                        mov t3, t2
                        and t3, #15
                        cmp t3, #2 wz, wc
        if_be           jmp #:not_stuck 
                        cmp t3, #14 wz, wc
        if_a            jmp #:not_stuck 
                        
                        shr t1, #4
                        and t2, #(!15) & $1FF
                        add t1, t2
                        add t1, tilemap
                        rdbyte t2, t1
                        cmp t2, #7 wz           ' if value of tile is 7, it's ok
        if_nz           cmp t2, #10 wz          ' 10 is good too
        if_z            jmp #:not_stuck
                        
:stuck                  
                        ' We are stuck!! Just 'wiggle' a bit then :)
                        ' (it makes a nice 'electrical' effect)
                        add policetemp_dir, #2
                        and policetemp_dir, #3

                        call #playelectrocutesound
                        jmp #keep_moving
                        
:not_stuck
                        call #check_collision

                        mov t1, policetemp_x
                        and t1, #15 wz
        if_nz           jmp #keep_moving
                        mov t1, policetemp_y
                        and t1, #15 wz
        if_nz           jmp #keep_moving

change_direction
                        
                        ' police reached at 16,16 multiple: may change direction here
                        ' use 'random' as a pseudo random number
                        call #getrandom
                        mov t1, random
                        ror t1, #4
                        and t1, #15
                        
                        cmp t1, #9 wz, wc       ' Random to check if we try a random direction or seek the hero
        if_ae           jmp #:seek_hero
                        cmp t1, #2 wz, wc       ' Do we keep the current direction?
        if_ae           jmp #:check_validity                        
        
                        ' Else, we select a random direction
                        call #getrandom
                        mov policetemp_dir, random
                        ror policetemp_dir, #4
                        and policetemp_dir, #3
                        jmp #:check_validity

:seek_hero              mov t1, random
                        and t1, #%1 wz
        if_z            jmp #:check_y_first
        
                        cmp policetemp_x, hero_x wz, wc
        if_b            mov policetemp_dir, #1
                        cmp policetemp_x, hero_x wz, wc
        if_a            mov policetemp_dir, #3
                        jmp #:check_validity

:check_y_first
                        cmp policetemp_y, hero_y wz, wc
        if_b            mov policetemp_dir, #2
                        cmp policetemp_y, hero_y wz, wc
        if_a            mov policetemp_dir, #0
                        

:check_validity
                        ' now check if that direction is available

                        mov t5, policetemp_x
                        mov t6, policetemp_y
                        cmp policetemp_dir, #0 wz
        if_e            sub t6, #16
                        cmp policetemp_dir, #1 wz
        if_e            add t5, #16
                        cmp policetemp_dir, #2 wz
        if_e            add t6, #16
                        cmp policetemp_dir, #3 wz
        if_e            sub t5, #16

                        ' tilemap[((t5 +- 16) >> 4) + ((t6+-16)>>4) << 4]
                        mov t1, t5
                        mov t2, t6
                        and t2, #(!15) & $1FF
                        shr t1, #4
                        add t1, t2
                        add t1, tilemap
                        rdbyte t2, t1

                        cmp t2, #7 wz           ' if value of tile is 7, it's ok
        if_nz           cmp t2, #10 wz          ' 10 is good
        if_nz           jmp #move_one_police_ret ' if not, can't move this frame

                        ' if success, then keep on moving

keep_moving
                        cmp policetemp_dir, #0 wz
        if_e            sub policetemp_y, #1
                        cmp policetemp_dir, #1 wz
        if_e            add policetemp_x, #1
                        cmp policetemp_dir, #2 wz
        if_e            add policetemp_y, #1
                        cmp policetemp_dir, #3 wz
        if_e            sub policetemp_x, #1
                        
move_one_police_ret     ret   

' Compute a pseudo-random number
getrandom
                        xor random, framecount
                        rol random, #13
                        add random, joypad_color
                        rol random, #5
                        add random, cnt
                        rol random, #19
getrandom_ret           ret


' Check collision between police and hero
check_collision
                        mov t1, policetemp_x
                        mov t2, hero_x
                        add t1, #10
                        add t2, #6
                        cmp t1, t2 wz, wc
        if_b            jmp #check_collision_ret

                        mov t1, policetemp_x
                        mov t2, hero_x
                        add t1, #6
                        add t2, #10
                        cmp t1, t2 wz, wc
        if_a            jmp #check_collision_ret

                        mov t1, policetemp_y
                        mov t2, hero_y
                        add t1, #10
                        add t2, #6
                        cmp t1, t2 wz, wc
        if_b            jmp #check_collision_ret

                        mov t1, policetemp_y
                        mov t2, hero_y
                        add t1, #6
                        add t2, #10
                        cmp t1, t2 wz, wc
        if_a            jmp #check_collision_ret

                        ' Collision occured, hero is dead meat.
                        mov collision_detect, #1
        
check_collision_ret     ret

drawpolice
                        mov l1, framecount
                        wrlong police1_x, command_p1
                        wrlong police1_y, command_p2
                        call #draw_one_police

                        add l1, #5
                        wrlong police2_x, command_p1
                        wrlong police2_y, command_p2
                        call #draw_one_police
                        add l1, #5
                        wrlong police3_x, command_p1
                        wrlong police3_y, command_p2
                        call #draw_one_police
                        add l1, #5
                        wrlong police4_x, command_p1
                        wrlong police4_y, command_p2
                        call #draw_one_police                        

drawpolice_ret          ret

draw_one_police
                        mov p3, #48
                        
                        cmp police_sad_timer, #0 wz
        if_nz           mov p3, #52             ' If police are 'crying', set the sprite
        
                        mov t1, l1
                        shr t1, #3
                        and t1, #%1
                        add p3, t1                        
                        wrlong p3, command_p3
                        mov pcmd, #CMD_DRAWSPRITE
                        call #waitcommand

                        cmp police_sad_timer, #0 wz
        if_nz           call #playsadsound
draw_one_police_ret     ret

playsadsound

                        mov t2, police_sad_timer
                        shl t2, #1
                        and t2, #63
                        cmp t2, #14 wc, wz
        if_a            jmp #playsadsound_ret
                        
                        shl t2, #2
                        mov t1, snd_adr
                        mov t3, #4              ' Square wave SHAPE_SQUARE
                        wrlong t3, t1

                        add t1, #4
                        add t2, #400
                        wrlong t2, t1           ' Set frequency

                        add t1, #4
                        mov t2, #440
                        wrlong t2, t1           ' Set duration (*4)
                        
playsadsound_ret        ret

playelectrocutesound
                        mov t1, snd_adr
                        mov t2, #2              ' Square wave SHAPE_SINE
                        wrlong t2, t1

                        add t1, #4
                        mov t2, framecount
                        shl t2, #1
                        and t2, #63
                        add t2, #200
                        wrlong t2, t1           ' Set frequency

                        add t1, #4
                        mov t2, #70
                        wrlong t2, t1           ' Set duration (*4)
                        
playelectrocutesound_ret ret

' Test play a sound here
playsound                        
                        mov t1, snd_adr
                        mov t2, #4              ' Square wave SHAPE_SQUARE
                        wrlong t2, t1

                        add t1, #4                                                
                        wrlong p1, t1           ' Set frequency

                        add t1, #4
                        shl p2, #2
                        wrlong p2, t1           ' Set duration (*4)
                        jmp #command_ret

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

                        ' Write pcmd to command_exec, so the helper cog will catch it
waitcommand             wrlong pcmd, command_exec
                        ' Wait as long as the command has not been completed
:waitack                rdlong p1, command_exec wz
                        sub p1, #128
                        cmp p1, pcmd wz
        if_nz           jmp #:waitack
waitcommand_ret         ret

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
pcmd long               $0

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
snd_adr long            $0
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
hero_x long             $0
hero_y long             $0
level long              $0
collision_detect long   $0
random long             $7261934

police1_x long          $0
police1_y long          $0
police1_dir long        $0

police2_x long          $0
police2_y long          $0
police2_dir long        $0

police3_x long          $0
police3_y long          $0
police3_dir long        $0

police4_x long          $0
police4_y long          $0
police4_dir long        $0

police_sad_timer long   $0

policetemp_x long       $0
policetemp_y long       $0
policetemp_dir long     $0