''*****************************
''*  Rem ASM engine v011      *
''*****************************

{
  REM graphic engine used with REM_locknchase
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

  NES_A_OR_B = %11000000

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

  ' This command enum must be sync with 'command_jumptable' in REM_lnc_police
  ' Command from 16 to 31 are for REM_lnc_police
  CMD_POLICE_RESTART_LEVEL = 16
  CMD_POLICE_UPDATE = 17
  CMD_POLICE_SAD = 18
  
  ' --
  

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
                        rdlong screen_adr, t2 ' store screen tile and color table address

                        add t2, #4
                        rdlong numbers_adr, t2 ' debug numbers data

                        add t2, #4
                        rdlong doormap_adr, t2 ' door tile map data

                        mov pcmd, #CMD_INITIALIZE_FIELD
                        call #waitcommand

                        mov gamestate, #state_press_start
                        'xor outa, #1 ' blink the debug led

main_loop
                        call #readgamepad
                        
                        jmp gamestate           ' jump to the current gamestate

return_from_state       {
                        mov p1, #240
                        wrlong p1, command_p1
                        mov p1, #150
                        wrlong p1, command_p2
                        wrlong framecount, command_p3
                        mov pcmd, #CMD_PRINTHEX
                        call #waitcommand
                        
                        mov p1, #130
                        wrlong p1, command_p2
                        wrlong gamepad, command_p3
                        mov pcmd, #CMD_PRINTHEX
                        call #waitcommand

                        mov p1, #158
                        wrlong p1, command_p2
                        wrlong debug_v1, command_p3
                        mov pcmd, #CMD_PRINTHEX
                        call #waitcommand

                        mov p1, #166
                        wrlong p1, command_p2
                        wrlong debug_v2, command_p3
                        mov pcmd, #CMD_PRINTHEX
                        call #waitcommand }

                        add framecount, #1

                        {mov t1, #$2            ' set black copper: black represent free cycle for this frame
                        wrbyte t1,colors}

                        call #waitvbl

                        {mov t1, #$1c           ' set light blue copper: this represent 'wasted time' for debugging
                        wrbyte t1,colors}

                        {call #wastetime        ' waste a lot of cycle

                        mov t1, #$4             ' set medium gray: this shows how much we currently use
                        wrbyte t1,colors}

                        jmp #main_loop
:infinite               
                        jmp #:infinite

' State when player just completed a level
state_winlevel          cmp framecount, #60 wc, wz
        if_b            jmp #return_from_state
                        ' Reset everything to restart a new level
        
                        add level, #1
                        call #restartlevel

                        mov t1, colors
                        add t1, #1
                        rdbyte t2, t1
                        add t2, #$90
                        wrbyte t2, t1
                        add t1, #1
                        rdbyte t2, t1
                        add t2, #$30
                        wrbyte t2, t1
        
                        jmp #return_from_state

' State when player just died
state_dead              cmp framecount, #60 wc, wz
        if_b            jmp #return_from_state
                        ' Reset stuff to restart life

                        sub life, #1 wz
        if_z            jmp #:gameover
        
                        call #restartlife
                        jmp #return_from_state

:gameover
                        mov gamestate, #state_press_start
                        jmp #return_from_state

' Reset stuff for a new level
restartlevel
                        mov countpellet, #82
                        mov bonus_timer, #0

                        call #restore_tilemap

                        call #restartlife

                        mov p1, #5              ' Set exit to exit color
                        mov p2, #1
                        mov p3, #1
                        call #setpalette

restartlevel_ret        ret

' Reset stuff for a new life
restartlife             ' place hero
                        
                        mov hero_x, #176
                        mov hero_y, #176
                        mov hero_anim, #39
                        mov gamestate, #state_play
                        mov hero_last_move, #0
                        mov hero_try_move, #0
                        mov auto_close_door, #0
                        
                        mov p1, #11             ' Set hero entrance to hero color
                        mov p2, #11
                        mov p3, #2
                        call #setpalette

                        mov pcmd, #CMD_RESTART_LEVEL
                        call #waitcommand
                        wrlong level, command_p1
                        mov pcmd, #CMD_POLICE_RESTART_LEVEL
                        call #waitcommand

                        ' Fix map for player start and police exits
                        mov t1, tilemap ' hero-start
                        add t1, #187            ' Tile 11,11
                        mov t2, #10
                        wrbyte t2, t1

                        mov t1, tilemap
                        add t1, #110            ' Tile 14,6
                        wrbyte t2, t1
                        add t1, #32
                        wrbyte t2, t1
                        mov t1, tilemap
                        add t1, #96             ' Tile 0,6
                        wrbyte t2, t1
                        add t1, #32
                        wrbyte t2, t1                        
                        
restartlife_ret         ret

restore_tilemap
                        ' Copy entire tilemap over
                        mov l1, #192/4          ' 192 tiles copied with long
                        mov t1, tilemap
                        mov t2, tilemap
                        add t2, #192
:loop
                        rdlong t3, t2
                        add t2, #4
                        wrlong t3, t1
                        add t1, #4
                        djnz l1, #:loop
restore_tilemap_ret     ret

' State 'normal game play'
state_play
                        ' Redraw whole screen. This could be optimised a lot
                        ' by only redrawing adjacent tiles, but it's fast enough.
                        mov pcmd, #CMD_INITIALIZE_FIELD
                        call #waitcommand

                        call #tryclosedoor

                        call #closeentrance

                        call #checkwin

                        call #warp

                        call #updatebonus

                        call #checkwinlife

                        mov hero_try_move, #255
                        ' Skip movement if hero is 'eating' a pellet
                        cmpsub eatpellet_freeze, #1 wc
        if_c            mov hero_anim, #50
        if_c            jmp #move_done
        
                        mov hero_try_move, #0
retry_move
                        test gamepad, #NES_UP wz
        if_nz           call #try_move_up
                        test gamepad, #NES_DOWN wz
        if_nz           call #try_move_down
                        test gamepad, #NES_RIGHT wz
        if_nz           call #try_move_right
                        test gamepad, #NES_LEFT wz
        if_nz           call #try_move_left

                        ' if player has not pressed anything this frame
                        cmp hero_try_move, #0 wz
        if_nz           jmp #move_done

                        ' keep on moving until we reach a 16x16 aligned position
                        mov t1, hero_x
                        and t1, #15 wz
        if_nz           jmp #:keep_move
                        mov t1, hero_y
                        and t1, #15 wz
        if_nz           jmp #:keep_move
                        mov p3, hero_anim
                        jmp #drawhero

:keep_move              mov hero_try_move, #255
                        mov gamepad, hero_last_move
                        jmp #retry_move

move_done
                        ' do hero walk animation
                        mov p3, hero_anim
                        cmp hero_try_move, #255 wz
        if_z            jmp #drawhero
                        mov t1, framecount
                        shr t1, #2
                        and t1, #%1
                        add t1, #1
                        add p3, t1

drawhero                ' draw hero
                        wrlong hero_x, command_p1
                        wrlong hero_y, command_p2
                        wrlong p3, command_p3
                        mov pcmd, #CMD_DRAWSPRITE
                        call #waitcommand

                        ' Eat pellets
                        call #eatpellet

                        ' update police
                        wrlong hero_x, command_p1
                        wrlong hero_y, command_p2
                        mov pcmd, #CMD_POLICE_UPDATE
                        call #waitcommand
                        rdlong p1, command_p3 wz ' get param back from function
        if_z            jmp #:continue

                        ' Ouch, collision occured. Player must die here!
                        mov gamestate, #state_dead
                        mov framecount, #0

:continue

                        wrlong score, command_p1
                        wrlong life, command_p2
                        wrlong highscore, command_p3
                        mov pcmd, #CMD_DRAWSCORE
                        call #waitcommand
                        
                        jmp #return_from_state

' Close the 'entrance' as soon as the player has left it
closeentrance
                        cmp hero_y, #161 wz, wc
        if_ae           jmp #closeentrance_ret
                        mov t1, tilemap ' Hard-coded value: put a normal wall
                        add t1, #187            ' Tile 11,11
                        mov t2, #1
                        wrbyte t2, t1

                        mov p1, #11
                        mov p2, #11
                        mov p3, #0
                        call #setpalette

                        ' Also put two door to block police exit
                        mov t1, tilemap
                        add t1, #142            ' Tile 14,8
                        mov t3, tilemap
                        add t3, #128            ' Tile 0,8

                        mov t2, level           ' Alternate which doors are open/close
                        and t2, #1 wz
        if_nz           sub t1, #32
        if_nz           sub t3, #32

                        mov t2, #45
                        wrbyte t2, t1
                        wrbyte t2, t3

closeentrance_ret       ret


' Check if player reaches the exit (only possible when exit is not blocking the way)
checkwin                cmp hero_y, #16 wc, wz
        if_nz           jmp #checkwin_ret
                        ' Hurray, player wins this level!
                        mov gamestate, #state_winlevel
                        mov framecount, #0
checkwin_ret            ret

' Check if player warps (right or left)
warp                    cmp hero_x, #0 wc, wz
        if_z            mov hero_x, #223
                        cmp hero_x, #224 wc, wz
        if_z            mov hero_x, #1
warp_ret                ret

' Update bonus (if it is active)
updatebonus
                        cmp bonus_timer, #0 wz
        if_z            jmp #updatebonus_ret    ' No active bonus, skip
        
                        mov t1, framecount
                        and t1, #1 wz
        if_z            jmp #updatebonus_ret    ' Only decrease bonus timer each 2 frame
        
                        sub bonus_timer, #1 wz
        if_nz           jmp #updatebonus_ret    ' Bonus has not elapsed fully, skip
        
                        ' if bonus just elapsed completely, remove it
                        mov t1, #8+6*16         ' tile 8,6
                        add t1, tilemap
                        mov t2, #10
                        wrbyte t2, t1
                        
updatebonus_ret         ret

' Check if player wins a new life
checkwinlife
                        cmp score, nextlife_score wz, wc
        if_b            jmp #checkwinlife_ret

                        add nextlife_score, nextlife_increment
                        cmp life, #9 wz, wc
        if_ae           jmp #checkwinlife_ret
        
                        add life, #1
                        
checkwinlife_ret        ret

' Check if player tries to close a door (by pressing a button)
tryclosedoor            test auto_close_door, #1 wz     ' Auto-close?
        if_nz           jmp #:tryclose
        
                        test gamepad, #NES_A_OR_B wz
        if_z            jmp #tryclosedoor_ret
:tryclose
                        wrlong hero_x, command_p1
                        wrlong hero_y, command_p2
                        wrlong empty, command_p3
                        mov pcmd, #CMD_TRY_CLOSE_DOOR
                        call #waitcommand
                        rdlong p3, command_p3
                        mov auto_close_door, p3
                        
tryclosedoor_ret        ret

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

' Try to move down
try_move_down           mov p1, #16
                        mov p2, #1
                        mov hero_anim, #42
                        call #try_vertical_move
try_move_down_ret       ret
try_move_up             mov p1, #1
                        neg p1, p1
                        mov p2, #1
                        neg p2, p2
                        mov hero_anim, #39
                        call #try_vertical_move
try_move_up_ret         ret

try_vertical_move
                        ' First, check if the tile on our neighbourg is available to walk on
                        ' tilemap[((hero_x + 8) >> 4) + ((hero_y+p1)>>4) << 4]
                        mov t1, hero_x
                        add t1, #8
                        shr t1, #4
                        
                        mov t2, hero_y
                        adds t2, p1
                        and t2, #(!15) & $1FF
                        add t1, t2
                        
                        add t1, tilemap
                        rdbyte t2, t1

                        cmp t2, #7 wz           ' if value of tile is 7, we can walk on it
        if_nz           cmp t2, #10 wz          ' 10 (empty space), good
        if_nz           cmp t2, #51 wz          ' 51 (cash bonus), good
        if_nz           jmp #try_vertical_move_ret

                        mov t2, hero_x
                        and t2, #15
                        cmp t2, #0 wz           ' if x&15 == 0, we are aligned are ready to move vertically
        if_nz           jmp #try_vertical_move_ret
                        adds hero_y, p2
                        mov hero_last_move, gamepad
                        mov hero_try_move, #1
                                                 
try_vertical_move_ret ret

' Try to move to the right
try_move_right          mov p1, #16
                        mov p2, #1
                        mov hero_anim, #42
                        call #try_horizontal_move
try_move_right_ret      ret
try_move_left           mov p1, #1
                        neg p1, p1
                        mov p2, #1
                        neg p2, p2
                        mov hero_anim, #39
                        call #try_horizontal_move
try_move_left_ret       ret

try_horizontal_move
                        ' First, check if the tile on our neighbourg is available to walk on
                        ' tilemap[((hero_x + p1) >> 4) + ((hero_y+8)>>4) << 4]
                        mov t1, hero_x
                        adds t1, p1
                        shr t1, #4
                        
                        mov t2, hero_y
                        add t2, #8
                        and t2, #(!15) & $1FF
                        add t1, t2
                        
                        add t1, tilemap
                        rdbyte t1, t1

                        cmp t1, #7 wz           ' if value of tile is 7, we can walk on it
        if_nz           cmp t1, #10 wz          ' 10 (empty space), good
        if_nz           cmp t1, #51 wz          ' 51 (cash bonus), good
        if_nz           jmp #try_horizontal_move_ret ' if not, no move.

                        mov t2, hero_y
                        and t2, #15
                        cmp t2, #0 wz           ' if y&15 == 0, we are aligned are ready to move horizontally
        if_nz           jmp #try_horizontal_move_ret
                        adds hero_x, p2
                        mov hero_last_move, gamepad
                        mov hero_try_move, #1
                        
try_horizontal_move_ret ret

' Check if hero is eating a pellet underneath him
eatpellet               
                        wrlong hero_x, command_p1
                        wrlong hero_y, command_p2
                        wrlong empty, command_p3
                        mov pcmd, #CMD_EAT_PELLET
                        call #waitcommand
                        rdlong p1, command_p3 wz ' get param back from function
        if_z            jmp #eatpellet_ret

                        cmp p1, #2 wz
        if_z            jmp #eatbonus
                        add score, #2

                        ' Check to spawn the big cash bonus after about each 32 pellets
                        mov t1, countpellet
                        sub t1, #3
                        and t1, #31 wz
        if_nz           jmp #:skip_bonus
        
                        mov t1, #8+6*16         ' tile 8,6
                        add t1, tilemap
                        mov t2, #51
                        wrbyte t2, t1
                        mov bonus_timer, #200   ' Make bonus timer less long on level up
                        mov t1, level
                        shl t1, #3
                        sub bonus_timer, t1
                        
:skip_bonus
                        ' Check if all pellet have been eated up
                        sub countpellet, #1 wz '  
        if_nz           jmp #:done

                        ' Yes, so open the exit!
                        
                        mov t1, #21             ' Tile 5,1
                        add t1, tilemap
                        mov t2, #10
                        wrbyte t2, t1

                        mov p1, #5              ' Set hero color to exit
                        mov p2, #1
                        mov p3, #2
                        call #setpalette

:done
                        mov eatpellet_freeze, #0        ' Freeze the player from a couple of frames when eating a pellet
                        ' UPDATE: This is disabled because it makes the controls jerky
eatpellet_done
                        cmp score, highscore wz, wc
        if_a            mov highscore, score
                        
eatpellet_ret           ret

eatbonus
                        add score, #100         ' 100(0) points for cash bonus
                        mov bonus_timer, #0
                        mov pcmd, #CMD_POLICE_SAD
                        call #waitcommand
                        jmp #eatpellet_done
                        

' State 'press start': Wait until the player press start on controller 0.
state_press_start       cmp gamepad, #NES_START wz ' Check if 'START' is pressed
        if_e            jmp #next_state_start

                        wrlong gamepad, command_p1
                        wrlong framecount, command_p2
                        mov pcmd, #CMD_PRESS_START
                        call #waitcommand
                        
                        jmp #return_from_state

next_state_start        ' User pressed START: Transit to game state
                        ' First, we have to initialize the game play field
                        mov pcmd, #CMD_INITIALIZE_FIELD
                        call #waitcommand

                        ' Restore color-palette where needed (i.e.: the 'press start' message)
                        mov p1, #6
                        mov p2, #8
                        mov p3, #2
                        call #setpalette
                        mov p1, #7
                        call #setpalette
                        mov p1, #8
                        call #setpalette
                        mov p1, #9
                        call #setpalette

                        mov score, #0
                        mov level, #0
                        mov life, #3
                        mov nextlife_score, nextlife_increment


                        mov t1, colors
                        wrlong maze_color, t1

                        call #restartlevel

                        jmp #return_from_state


' Setpalette: Set the color-palette index for the tile 'p1, p2' to 'p3'
' screen_adr[x + y * 16] |= (color_palette << 10)
setpalette
                        mov t1, p2
                        shl t1, #4
                        add t1, p1
                        shl t1, #1
                        add t1, screen_adr
                        rdword t2, t1
                        
                        and t2, and_mask_palette
                        mov t3, p3
                        shl t3, #10
                        add t2, t3
                        wrword t2, t1
setpalette_ret          ret

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

'setcolors: set 4 color of palette 'p1' to value 'p2'
setcolors               mov t1, p1
                        shl t1, #2
                        add t1, colors
                        wrlong p2, t1
setcolors_ret           ret

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

                        ' Write pcmd to command_exec, so the helper cog will catch it
waitcommand             wrlong pcmd, command_exec
                        ' Wait as long as the command has not been completed
:waitack                rdlong p1, command_exec
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
gamestate long          $0
gamepad long            $0
black long              $02020202
title_color long        $6e6c6b02
joypad_color long       $fe040302
maze_color long         $0d1b3a02
and_mask_palette long   %1111111111
sprite_next_row_increment long 960  ' this is one full row of tile bytes, minus one 1024 - 64
debug_v1 long           $0
debug_v2 long           $0
nextlife_increment long 1000

hero_x long             $0
hero_y long             $0
hero_anim long          $0
hero_last_move long     $0
hero_try_move long      $0
eatpellet_freeze long   $0
auto_close_door long    $0
countpellet long        $0
bonus_timer long        $0
level long              $0
score long              $0
highscore long          $0
life long               $0
nextlife_score long     $0