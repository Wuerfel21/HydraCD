{*********************************
 *   Rem Alien Invader game v013 *
 *********************************

 This game uses REM_alien_data_***.spin for tilemap and tiles asset
 Also uses REM_gfx_engine_***.spin: The REM graphic engine
 And REM_tv_***.spin: REM graphic engine TV rasteriser

 It features 16 sprites, two player actions with gamepad and keyboard controls.
 Keyboard is mapped to:
   player 1: W,A,S,D with left control/alt/shift to shoot
   player 2: Arrows with right control/alt/shift to shoot

 Almost all graphic asset made by Louis-Philippe 'FoX' Guilbert
 Programmed by Remi 'Remz' Veilleux

}

CON

  _clkmode = xtal1 + pll8x  ' ?
  _xinfreq = 10_000_000 + 0_000 ' Set to 10Mhz and add 5000 to fix crystal imperfection of hydra prototype
  '_stack = ($300 - 200) >> 2           'accomodate display memory and stack
  _memstart = $10                   ' memory starts $10 in!!! (this took 2 headaches to figure out)

  paramcount = 14
  SCANLINE_BUFFER = $7F00
  ' Define list of intercog global variable: they start right next to the video scanlinebuffer
  spin_request_scanline = SCANLINE_BUFFER-4
  spin_vertical_scroll = SCANLINE_BUFFER-8
  spin_horizontal_scroll = SCANLINE_BUFFER-12
  spin_top_y = SCANLINE_BUFFER-16
  spin_bottom_y = SCANLINE_BUFFER-20
  spin_stop_y = SCANLINE_BUFFER-24
  spin_tilemap_adr = SCANLINE_BUFFER-28
  spin_tiles_adr = SCANLINE_BUFFER-32
  spin_gamepad = SCANLINE_BUFFER-36

  spin_playerlife = SCANLINE_BUFFER-40
  spin_player1score = SCANLINE_BUFFER-44
  spin_player2score = SCANLINE_BUFFER-48
  spin_playertimer = SCANLINE_BUFFER-52

  'reserve some space for expansion'
  
  spin_sprite_x = SCANLINE_BUFFER-60
  spin_sprite_y = SCANLINE_BUFFER-64
  spin_sprite_s = SCANLINE_BUFFER-68
  spin_sprite_a = SCANLINE_BUFFER-72
  spin_sprite_p = SCANLINE_BUFFER-76

  spin_sprite2_x = SCANLINE_BUFFER-80
  spin_sprite2_y = SCANLINE_BUFFER-84
  spin_sprite2_w = SCANLINE_BUFFER-88
  spin_sprite2_h = SCANLINE_BUFFER-92
  spin_sprite2_pixel = SCANLINE_BUFFER-96

  ' Up to 16 sprites...

  MEM_BUFFER = SCANLINE_BUFFER - 380
  spin_alienstatus1 = MEM_BUFFER-00
  spin_alienstatus2 = MEM_BUFFER-04
  spin_alienstatus3 = MEM_BUFFER-08
  spin_alienstatus4 = MEM_BUFFER-12
  spin_alienstatus5 = MEM_BUFFER-16
  spin_explosion = MEM_BUFFER-20
  spin_alien = MEM_BUFFER-24
  spin_framecount = MEM_BUFFER-28
  spin_abulletstatus1 = MEM_BUFFER-32
  spin_abulletstatus2 = MEM_BUFFER-36
  spin_abulletstatus3 = MEM_BUFFER-40
  spin_abulletstatus4 = MEM_BUFFER-44
  spin_abulletstatus5 = MEM_BUFFER-48
  spin_playership = MEM_BUFFER-52
  
  MAPSIZEX = 20
  MAPSIZEY = 256

  NES_RIGHT  = %00000001
  NES_LEFT   = %00000010
  NES_DOWN   = %00000100
  NES_UP     = %00001000
  NES_START  = %00010000
  NES_SELECT = %00100000
  NES_B      = %01000000
  NES_A      = %10000000

VAR
  long tv_status      '0/1/2 = off/visible/invisible           read-only
  long tv_enable      '0/? = off/on                            write-only
  long tv_pins        '%ppmmm = pins                           write-only
  long tv_mode        '%ccinp = chroma,interlace,ntsc/pal,swap write-only
  long tv_screen      'pointer to screen (words)               write-only
  long tv_colors      'pointer to colors (longs)               write-only               
  long tv_hc          'horizontal cells                        write-only
  long tv_vc          'vertical cells                          write-only
  long tv_hx          'horizontal cell expansion               write-only
  long tv_vx          'vertical cell expansion                 write-only
  long tv_ho          'horizontal offset                       write-only
  long tv_vo          'vertical offset                         write-only
  long tv_broadcast   'broadcast frequency (Hz)                write-only
  long tv_auralcog    'aural fm cog                            write-only

  long temp1

  ' param for rem_engine:
  long cog_number
  long cog_total
  
  long colors[1]

OBJ

  key   : "keyboard_iso_010.spin"
  tv    : "rem_tv_013.spin"
  gfx   : "rem_gfx_engine_013.spin"
  data  : "rem_alien_data_013.spin"
  loader : "REM_LOADER_KERNEL_001.spin" ' loader kernel (boots paged cogs)


PUB start      | i, j, k, kk, dx, dy, pp, pq, rr, numx, numchr
  DIRA[0] := 1
  outa[0] := 0

  longfill(@colors, $02020202, 1)

  long[spin_tilemap_adr] := data.tilemap
  long[spin_tiles_adr] := data.tiles

  cog_number := 0
  cog_total := 4
  gfx.start(@cog_number)
  repeat 10000 ' Allow some time for previous cog to boot up before setting 'cog_number' again
  cog_number := 1
  gfx.start(@cog_number)
  repeat 10000 ' Allow some time for previous cog to boot up before setting 'cog_number' again
  cog_number := 2
  gfx.start(@cog_number)
  repeat 10000 ' Allow some time for previous cog to boot up before setting 'cog_number' again
  cog_number := 3
  gfx.start(@cog_number)
  repeat 10000 ' Allow some time for previous cog to boot up before setting 'cog_number' again

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_colors := @colors
  tv.start(@tv_status)

  key.start(3)

  loader.start(@GAMEINIT_START)

  long[spin_top_y] := 17
  long[spin_bottom_y] := 175
  long[spin_stop_y] := 192

  ' Long list of sprite and setup stuff.
  ' All commented line are no longer required since code will set them at runtime
  
  ' player 1:
  long[CONSTANT(spin_sprite_x-0*20)] := CONSTANT(70<<7)
  long[CONSTANT(spin_sprite_y-0*20)] := CONSTANT(-100<<7)
  'long[CONSTANT(spin_sprite_s-0*20)] := CONSTANT(5<<8 + 32)
  'long[CONSTANT(spin_sprite_a-0*20)] := CONSTANT((@pship000+_memstart)<<16 + 0)

' long[CONSTANT(spin_sprite_x-1*20)] := CONSTANT(128<<7)
  long[CONSTANT(spin_sprite_y-1*20)] := CONSTANT(-132<<7)
  long[CONSTANT(spin_sprite_s-1*20)] := CONSTANT(3<<8 + 8)
  long[CONSTANT(spin_sprite_a-1*20)] := CONSTANT((@pthrust000+_memstart)<<16 + 0)

' long[CONSTANT(spin_sprite_x-2*20)] := CONSTANT(118<<7)
  long[CONSTANT(spin_sprite_y-2*20)] := CONSTANT(-132<<7)
  long[CONSTANT(spin_sprite_s-2*20)] := CONSTANT(2<<8 + 16)
  long[CONSTANT(spin_sprite_a-2*20)] := CONSTANT((@pbullet000+_memstart)<<16 + 0)

  ' player 2
  long[CONSTANT(spin_sprite_x-3*20)] := CONSTANT(188<<7)
  long[CONSTANT(spin_sprite_y-3*20)] := CONSTANT(-132<<7)
  'long[CONSTANT(spin_sprite_s-3*20)] := CONSTANT(5<<8 + 32)
  'long[CONSTANT(spin_sprite_a-3*20)] := CONSTANT((@pship000+_memstart)<<16 + 0)

' long[CONSTANT(spin_sprite_x-4*20)] := CONSTANT(128<<7)
  long[CONSTANT(spin_sprite_y-4*20)] := CONSTANT(-132<<7)
  long[CONSTANT(spin_sprite_s-4*20)] := CONSTANT(3<<8 + 8)
  long[CONSTANT(spin_sprite_a-4*20)] := CONSTANT((@pthrust000+_memstart)<<16 + 0)

' long[CONSTANT(spin_sprite_x-5*20)] := CONSTANT(210<<7)
  long[CONSTANT(spin_sprite_y-5*20)] := CONSTANT(-132<<7)
  long[CONSTANT(spin_sprite_s-5*20)] := CONSTANT(2<<8 + 16)
  long[CONSTANT(spin_sprite_a-5*20)] := CONSTANT((@pbullet000+_memstart)<<16 + 0)

  ' aliens
  'long[CONSTANT(spin_sprite_x-6*20)] := CONSTANT(128<<7)
  long[CONSTANT(spin_sprite_y-6*20)] := CONSTANT(-132<<7)
  long[CONSTANT(spin_sprite_s-6*20)] := CONSTANT(4<<8 + 16)
  long[CONSTANT(spin_sprite_a-6*20)] := CONSTANT((@alien000+_memstart)<<16 + 0)

  'long[CONSTANT(spin_sprite_x-7*20)] := CONSTANT(178<<7)
  long[CONSTANT(spin_sprite_y-7*20)] := CONSTANT(-132<<7)
  long[CONSTANT(spin_sprite_s-7*20)] := CONSTANT(4<<8 + 16)
  long[CONSTANT(spin_sprite_a-7*20)] := CONSTANT((@alien000+_memstart)<<16 + 0)

  'long[CONSTANT(spin_sprite_x-8*20)] := CONSTANT(218<<7)
  long[CONSTANT(spin_sprite_y-8*20)] := CONSTANT(-132<<7)
  long[CONSTANT(spin_sprite_s-8*20)] := CONSTANT(4<<8 + 16)
  long[CONSTANT(spin_sprite_a-8*20)] := CONSTANT((@alien000+_memstart)<<16 + 0)

  'long[CONSTANT(spin_sprite_x-9*20)] := CONSTANT(48<<7)
  long[CONSTANT(spin_sprite_y-9*20)] := CONSTANT(-132<<7)
  long[CONSTANT(spin_sprite_s-9*20)] := CONSTANT(4<<8 + 16)
  long[CONSTANT(spin_sprite_a-9*20)] := CONSTANT((@alien000+_memstart)<<16 + 0)

  'long[CONSTANT(spin_sprite_x-10*20)] := CONSTANT(98<<7)
  long[CONSTANT(spin_sprite_y-10*20)] := CONSTANT(-132<<7)
  long[CONSTANT(spin_sprite_s-10*20)] := CONSTANT(4<<8 + 16)
  long[CONSTANT(spin_sprite_a-10*20)] := CONSTANT((@alien000+_memstart)<<16 + 0)

' long[CONSTANT(spin_sprite_x-11*20)] := CONSTANT(140<<7)
  long[CONSTANT(spin_sprite_y-11*20)] := CONSTANT(-132<<7)
  long[CONSTANT(spin_sprite_s-11*20)] := CONSTANT(2<<8 + 4)
  long[CONSTANT(spin_sprite_a-11*20)] := CONSTANT((@abullet000+_memstart)<<16 + 0)

' long[CONSTANT(spin_sprite_x-12*20)] := CONSTANT(80<<7)
  long[CONSTANT(spin_sprite_y-12*20)] := CONSTANT(-132<<7)
  long[CONSTANT(spin_sprite_s-12*20)] := CONSTANT(2<<8 + 4)
  long[CONSTANT(spin_sprite_a-12*20)] := CONSTANT((@abullet000+_memstart)<<16 + 0)

' long[CONSTANT(spin_sprite_x-13*20)] := CONSTANT(120<<7)
  long[CONSTANT(spin_sprite_y-13*20)] := CONSTANT(-132<<7)
  long[CONSTANT(spin_sprite_s-13*20)] := CONSTANT(2<<8 + 4)
  long[CONSTANT(spin_sprite_a-13*20)] := CONSTANT((@abullet000+_memstart)<<16 + 0)

' long[CONSTANT(spin_sprite_x-14*20)] := CONSTANT(180<<7)
  long[CONSTANT(spin_sprite_y-14*20)] := CONSTANT(-132<<7)
  long[CONSTANT(spin_sprite_s-14*20)] := CONSTANT(2<<8 + 4)
  long[CONSTANT(spin_sprite_a-14*20)] := CONSTANT((@abullet000+_memstart)<<16 + 0)

' long[CONSTANT(spin_sprite_x-15*20)] := CONSTANT(240<<7)
  long[CONSTANT(spin_sprite_y-15*20)] := CONSTANT(-132<<7)
  long[CONSTANT(spin_sprite_s-15*20)] := CONSTANT(2<<8 + 4)
  long[CONSTANT(spin_sprite_a-15*20)] := CONSTANT((@abullet000+_memstart)<<16 + 0)

  long[spin_playerlife] := 0
  long[spin_explosion] := CONSTANT((@explo000+_memstart)<<16 + 0)
  long[spin_alien] := CONSTANT((@alien000+_memstart)<<16 + 0)
  long[spin_alien] := CONSTANT((@alien000+_memstart)<<16 + 0)
  long[spin_playership] := CONSTANT((@pship000+_memstart)<<16 + 0) 

  long[spin_alienstatus1] := 0
  long[spin_alienstatus2] := 0
  long[spin_alienstatus3] := 0
  long[spin_alienstatus4] := 0
  long[spin_alienstatus5] := 0

  ' Start of main loop here
  repeat
    repeat while tv_status == 1
    repeat while tv_status == 2

    temp1 := NES_Read_Gamepad

    if(temp1&$00ff == $00ff) ' controller 0 not plugged in, pretend all buttons are unpressed.
      temp1&=$ff00
    if(temp1&$ff00 == $ff00) ' controller 1 not plugged in, pretend all buttons are unpressed.
      temp1&=$00ff

    ' Player 1 is W,A,S,D with left ctrl/alt/shift, 
    if(key.keystate($77)) 'W'
      temp1|=NES_UP
    if(key.keystate($73)) 'S'
      temp1|=NES_DOWN
    if(key.keystate($61)) ' A
      temp1|=NES_LEFT
    if(key.keystate($64)) ' D
      temp1|=NES_RIGHT
    if(key.keystate($F0) or key.keystate($F2) or key.keystate($F4))
      temp1|=NES_A
    if(key.keystate($20))
      temp1|=NES_START

    ' Player 2 is Arrow pad with rigth ctrl/alt/shift, enter to start
    if(key.keystate($C2))
      temp1|=CONSTANT(NES_UP<<8)
    elseif(key.keystate($C3))
      temp1|=CONSTANT(NES_DOWN<<8)
    if(key.keystate($C0))
      temp1|=CONSTANT(NES_LEFT<<8)
    elseif(key.keystate($C1))
      temp1|=CONSTANT(NES_RIGHT<<8)
    if(key.keystate($F1) or key.keystate($F3) or key.keystate($F5))
      temp1|=CONSTANT(NES_A<<8)      
    if(key.keystate($0D))
      temp1|=CONSTANT(NES_START<<8)

    long[spin_gamepad] := temp1

'end of main
'---------------------------------------------

PUB NES_Read_Gamepad : nes_bits   |       i

DIRA [3] := 1 ' output
DIRA [4] := 1 ' output
DIRA [5] := 0 ' input
DIRA [6] := 0 ' input

OUTA [3] := 0 ' JOY_CLK = 0
OUTA [4] := 0 ' JOY_SH/LDn = 0
OUTA [4] := 1 ' JOY_SH/LDn = 1
OUTA [4] := 0 ' JOY_SH/LDn = 0
nes_bits := 0
nes_bits := INA[5] | (INA[6] << 8)

repeat i from 0 to 6
  OUTA [3] := 1 ' JOY_CLK = 1
  OUTA [3] := 0 ' JOY_CLK = 0
  nes_bits := (nes_bits << 1)
  nes_bits := nes_bits | INA[5] | (INA[6] << 8)

nes_bits := (!nes_bits & $FFFF)
' End NES Game Paddle Read
' //////////////////////////////////////////////////////////////////       


DAT

tvparams                long    0               'status
                        long    1               'enable
                        long    %011_0000       'pins
                        long    %0000           'mode
                        long    0               'screen
                        long    0               'colors
                        long    16              'hc
                        long    12              'vc
                        long    10              'hx
                        long    1               'vx
                        long    0               'ho
                        long    0               'vo
                        long    60_000_000'_xinfreq<<4  'broadcast
                        long    0               'auralcog

                        org
GAMEINIT_START
                        mov dira, #1            ' Prepare led debug
loop
                        'xor outa, #1

                        rdlong framecount, framecount_adr

                        call #mapscroll

                        call #playermove

                        call #displaylife

                        call #displayscore

                        call #alienanimation

                        call #waitvbl

                        call #aliencheckcollision                        

                        add framecount, #1
                        wrlong framecount, framecount_adr

                        mov    __loader_page, #(_memstart+@GAMEPROCESS_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@GAMEPROCESS_START) & $1FF         
                        mov    __loader_size, #(GAMEPROCESS_END-GAMEPROCESS_START)
                        mov    __loader_jmp, #GAMEPROCESS_START
                        jmpret __loader_ret,#__loader_call                        

                        jmp #loop

waitvbl                 
:wait_status_1          rdlong r0, request_scanline
                        cmp r0, #191            wz
        if_ne           jmp #:wait_status_1
:wait_status_2          rdlong r0, request_scanline
                        cmp r0, #192            wz
        if_ne           jmp #:wait_status_2

waitvbl_ret             ret

mapscroll
                        ' Scroll every other frame           
                        ' DISABLED: it makes screen flicker. Scrolling is now 60 pixel per second, a bit too fast.
                        {
                        mov r0, framecount
                        and r0, #1 wz
        if_nz           jmp #mapscroll_ret}
                        rdlong r0, vertical_scroll
                        sub r0, #1
                        wrlong r0, vertical_scroll
mapscroll_ret           ret

playermove
                        rdlong r6, gamepad
                        mov r5, #0
                        mov player, #0
                        rdlong r7, horizontal_scroll
                        shl r7, #7              ' Adjust hscroll to 7-bit fixed-point
                        mov nbaliveplayer, #0

nextplayer
                        ' Read in sprite #0 parameters (player 1 ship)
                        mov r0, player
                        call #readspriteinfo

                        ' Check if this player is currently alive
                        ' playerlife_adr contains (player1_live) + (player2_live << 8)
                        rdbyte r0, playerlife_adr wz
        if_z            jmp #gameoverplayer

                        add nbaliveplayer, #1        

                        rdlong sprite_a, sprite_a_adr
                        rdlong player_y, sprite_y_adr
                        rdlong player_x, sprite_x_adr

                        

                        ' Check if player is currently exploding
                        rdlong r0, explosion_adr
                        shr r0, #16
                        mov r1, sprite_a
                        shr r1, #16
                        cmp r0, r1 wz, wc
        if_ne           jmp #:playernotexploding

                        ' If exploding, then animate multiple explosion?
                        mov r0, sprite_a
                        and r0, #$ff
                        add r0, #5
                        cmp r0, #95 wc, wz
        if_a            mov r0, #0

                        movs sprite_a, r0
                        wrlong sprite_a, sprite_a_adr

                        ' Make sprite move around 32x32
                        {
                        mov r0, framecount
                        and r0, #15
                        sub r0, #8
                        shl r0, #6
                        add player_x, r0
                        wrlong player_x, sprite_x_adr}

                        add player_y, #80
                        wrlong player_y, sprite_y_adr

                        ' Check if explosion has gone off-screen
                        mov r0, player_y
                        sar r0, #7
                        cmp r0, #190 wc, wz
        if_b            jmp #:notoffscreen
                        ' Subtract one life to this player, and make him respawn
                        rdbyte r0, playerlife_adr
                        sub r0, #1 wz
                        wrbyte r0, playerlife_adr
        if_nz           call #respawn_player_sprite

:notoffscreen
                        call #playerbulletmove

                        add r5, player_x
                        jmp #skiptonextplayer
                        
:playernotexploding
                        ' Read-in 'invincible' startup timer
                        rdbyte playertimer, playertimer_adr wz
        if_z            jmp #:skipinvicible

                        sub playertimer, #1
                        wrbyte playertimer, playertimer_adr

                        ' Make player ship auto-move when starting a new life 
                        cmp playertimer, #80 wc, wz
        if_b            jmp #:skipinvicible

                        sub player_y, #1<<7
                        jmp #skipcheckcontrol
                        
:skipinvicible
                        test r6, #NES_DOWN wz
        if_nz           add player_y, #1<<7
                        test r6, #NES_UP wz
        if_nz           sub player_y, #1<<7

                        mov r1, #0
                        movs r1, sprite_a
                        
                        test r6, #NES_RIGHT wz
        if_nz           add player_x, #2<<7
        if_nz           add r1, #2              ' set animation frame to 2
                        test r6, #NES_LEFT wz
        if_nz           sub player_x, #2<<7
        if_nz           sub r1, #2              ' set animation frame to 1

                        mins r1, #8
                        maxs r1, #40

                        test r6, #NES_RIGHT+NES_LEFT wz
        if_nz           jmp #:skipneutral

                        cmp r1, #26 wc, wz
        if_a            sub r1, #2
                        cmp r1, #22 wc, wz
        if_b            add r1, #2                        

:skipneutral
                        movs sprite_a, r1

                        mov r1, min_player_x
                        add r1, r7
                        mins player_x, r1

skipcheckcontrol
                        mins player_y, min_player_y
                        maxs player_y, max_player_y
                        wrlong player_y, sprite_y_adr

                        ' Make invincible player flicker
                        cmp playertimer, #0 wz
        if_z            jmp #:skip_invincible_flicker
                        mov r1, playertimer
                        and r1, #1 wz
        if_z            movs sprite_a, #255     ' Special disappear frame
        if_nz           movs sprite_a, #24

:skip_invincible_flicker
                        wrlong sprite_a, sprite_a_adr   ' Update animation frame number
                        
                        mov r1, max_player_x
                        add r1, r7
                        maxs player_x, r1
                        wrlong player_x, sprite_x_adr

                        add r5, player_x
                        call #animthrust

                        call #playerbulletmove
                        ' bullet move, if currently active
                        rdlong r0, sprite_y_adr
                        cmps r0, #0 wc, wz
        if_a            jmp #:bulletdone

                        test r6, #NES_A wz
        if_z            jmp #:bulletdone
                        ' Player is holding fire: spawn a new bullet at player position
                        mov r0, player_x
                        add r0, player_bullet_x_offset
                        wrlong r0, sprite_x_adr
                        mov r0, player_y
                        add r0, player_bullet_y_offset
                        wrlong r0, sprite_y_adr
:bulletdone

skiptonextplayer

                        cmp player, #3 wz
        if_e            jmp #finishplayer
                        add player, #3          ' Go to next player (3 sprite per player)
                        shr r6, #8              ' Shift gamepad to get player 2

                        add playerlife_adr, #1
                        add playertimer_adr, #1
        
                        jmp #nextplayer

' bullet move, if currently active
playerbulletmove
                        mov r0, player
                        add r0, #2
                        call #readspriteinfo
                        rdlong r0, sprite_y_adr
                        cmps r0, min_player_x wc, wz
        if_be           jmp #playerbulletmove_ret
                        sub r0, bullet_speed    ' This is bullet speed, 14 pixel per frame
                        wrlong r0, sprite_y_adr
playerbulletmove_ret    ret


' Game over: make 'push start' flicker for the adequate player
gameoverplayer
                        mov r1, #5              ' default metal panel tile

                        ' If player press start, start this player
                        test r6, #NES_START wz
        if_nz           jmp #playerstartgame

                        mov r0, framecount
                        and r0, #63
                        cmp r0, #31 wc, wz
        if_a            mov r1, #7              ' set tile to 'press start'

                        call #draw_pressstart
        
                        jmp #skiptonextplayer

' Call to draw the 'press start'
draw_pressstart         
                        rdlong r2, tilemap_adr
                        cmp player, #0 wz
        if_z            add r2, #1
        if_nz           add r2, #14
                        wrbyte r1, r2
draw_pressstart_ret     ret

' Start a new game here
playerstartgame
                        call #draw_pressstart
                        mov r1, #4              ' TODO: 4 lives initial

                        wrbyte r1, playerlife_adr

                        call #respawn_player_sprite

                        mov r0, #0
                        cmp player, #0 wz
        if_z            wrlong r0, player1score_adr
        if_nz           wrlong r0, player2score_adr
                        
                        jmp #skiptonextplayer

' Make a player ship respawn
respawn_player_sprite   
                        mov r2, #128            ' Invincible and intro timer
                        wrbyte r2, playertimer_adr

                        ' Player spawn: Set start x pos
                        mov r0, #70
                        cmp player, #0 wz
        if_nz           mov r0, #200
                        shl r0, #7
                        wrlong r0, sprite_x_adr

                        ' Set Y pos
                        mov r0, #176
                        shl r0, #7
                        wrlong r0, sprite_y_adr

                        ' Set sprite/animation
                        rdlong r0, playership_adr
                        wrlong r0, sprite_a_adr

                        ' Set player sprite width and height to: 5<<8 + 32
                        mov r0,#5
                        shl r0, #8
                        add r0, #32
                        wrlong r0, sprite_s_adr
respawn_player_sprite_ret ret

finishplayer
                        ' Check how many player were alive to see how to adjust scroll
                        ' If no player are alive, skip this
                        ' If 1 player is alive, adjust to this player only
                        ' If 2 player are alive, center scroll between them

                        cmp nbaliveplayer, #0   wz
        if_z            jmp #skiphscroll
                        
                        sar r5, #7              ' Divide by 1 and transform back into hscroll value (7-bit)
                        cmp nbaliveplayer, #2   wz
        if_e            sar r5, #1

                        call #adjusthorizontalscroll
skiphscroll

                        sub playerlife_adr, #1
                        sub playertimer_adr, #1
                        
playermove_ret          ret

animthrust
                        ' Read sprite #1 (player 1 thrust)
                        mov r0, player
                        add r0, #1
                        call #readspriteinfo

                        ' Make thrust flicker on/off every frame (inverted for player 1-2)
                        mov r0, framecount
                        add r0, player
                        and r0, #1 wz
        if_z            jmp #thrustoff

                        mov r1, player_x
                        add r1, player_thrust_x_offset
                        wrlong r1, sprite_x_adr
                        
                        mov r2, player_y
                        add r2, player_thrust_y_offset
                        wrlong r2, sprite_y_adr

                        ' Force thrust visible (because it's hidden when player dies)
                        rdlong r0, sprite_a_adr
                        movs r0, #0
                        wrlong r0, sprite_a_adr

                        jmp #animthrust_ret

thrustoff               ' make thrust disappear by setting it off-screen
                        mov r2, #0
                        wrlong r2, sprite_y_adr
                        
animthrust_ret          ret

adjusthorizontalscroll
                        ' make screen scroll horizontally according to sprite X pos
                        ' sprite X [ -16..304 ]
                        ' h scroll [ 0..63 ]
                        ' h scroll = (sprite_x + 16 - 160) / 2 + 32, clamped

                        rdlong r4, horizontal_scroll

                        sub r5, #144
                        sar r5, #1
                        add r5, #32
                        mins r5, #0
                        maxs r5, #63

                        cmp r4, r5 wc, wz
        if_b            add r4, #1
        if_a            sub r4, #1

                        wrlong r4, horizontal_scroll
adjusthorizontalscroll_ret ret
                        
' Update alien animation
alienanimation
                        mov alienstatus_adr, alienstatus5_adr ' Start with alien 5 status
                        mov r7, #5              ' NB of aliens
nextalien               
                        mov r0, #5
                        add r0, r7

                        call #readspriteinfo

                        ' Check if this alien is currently exploding

                        rdlong r0, explosion_adr
                        shr r0, #16
                        rdlong r1, sprite_a_adr
                        shr r1, #16
                        cmp r0, r1 wz, wc
        if_ne           jmp #:animatealien

                        rdlong r2, sprite_a_adr
                        and r2, #$ff
                        add r2, #3

                        cmp r2, #95 wc, wz
        if_be           jmp #:continueexplosion

                        ' Explosion is done, make enemy die
                        ' Reset sprite to alien ship
                        rdlong r0, alien_adr
                        wrlong r0, sprite_a_adr
                        ' Reset hp/type/timer to 0
                        mov r0, #0
                        wrlong r0, alienstatus_adr
                        
                        ' Clear position to y = -?? to remove sprite from screen
                        mov r0, min_player_x
                        wrlong r0, sprite_y_adr
                        jmp #:skiptonextalien

:animatealien
                        ' Check if this alien has some hitpoint
                        rdlong r0, alien_adr wz
        if_z            jmp #:skiptonextalien
                        ' Make enemy ship animation (3 frames)
                        rdlong r2, sprite_a_adr
                        and r2, #$ff
                        add r2, #3

                        cmp r2, #47 wc, wz
        if_a            mov r2, #0              ' Loop indefinitely this animation

:continueexplosion
                        shl r1, #16
                        add r1, r2
                        wrlong r1, sprite_a_adr
                        
:skiptonextalien
                        add alienstatus_adr, #4

                        djnz r7, #nextalien
alienanimation_ret      ret

' Check for alien collision with player bullet
aliencheckcollision
                        mov r6, #2              ' Loop for 2 bullets

                        add player2score_adr, #4
                        
                        ' Get player bullet position into player_x and player_y
                        mov r0, #2              ' Bullet sprite of player 1
:nextbullet
                        call #readspriteinfo
                        rdlong player_x, sprite_x_adr
                        mov r5, sprite_y_adr    ' Keep bullet y address in r5
                        rdlong player_y, r5
                        sar player_x, #7
                        sar player_y, #7

                        ' Check if this player bullet is currently active
                        cmps player_y, #0 wc, wz
        if_be           jmp #:skipbullet

                        mov r7, #5              ' NB of aliens
                        mov alienstatus_adr, alienstatus5_adr ' Start with alien 5 status
:nextalien              
                        mov r0, #5
                        add r0, r7

                        call #readspriteinfo
                        rdlong r0, sprite_x_adr
                        sar r0, #7
                        rdlong r1, sprite_y_adr
                        sar r1, #7

                        ' Check for collision between alien and player bullet
                        ' alien x = r0..r0+15
                        ' alien y = r1..r1+15
                        ' player bullet x = player_x..player_x+3
                        ' player bullet y = player_y..player_y+13
                        mov r2, player_x
                        mov r3, player_y
                        add r2, #3
                        add r3, #13

                        cmps r0, r2 wc, wz
        if_a            jmp #:nocollision
                        cmps r1, r3 wc, wz
        if_a            jmp #:nocollision

                        add r0, #15
                        add r1, #15
                        
                        cmps r0, player_x wc, wz
        if_b            jmp #:nocollision
                        cmps r1, player_y wc, wz
        if_b            jmp #:nocollision

                        ' Collision occured!

                        ' Check current alien status
                        rdlong r0, alienstatus_adr
                        mov r1, r0
                        and r1, #$ff wz
                        ' If no hitpoint, this alien is already dead or exploding. Skip.
        if_z            jmp #:nocollision
                        sub r0, #1
                        wrlong r0, alienstatus_adr
                        sub r1, #1 wz           ' If hitpoint falls to 0, this alien will die

                        ' Destroy player bullet, even if alien doesn't die yet
                        ' place bullet y off-screen
                        mov r0, min_player_x
                        wrlong r0, r5

                        ' 'Bump' enemy a bit upward
                        rdlong r0, sprite_y_adr
                        sub r0, #128
                        wrlong r0, sprite_y_adr

                        ' Destroy alien
        if_nz           jmp #:nocollision       ' If alien still have hitpoints, leave him alive

                        ' Turn enemy into an explosion, starting at frame 0
                        rdlong r0, explosion_adr
                        wrlong r0, sprite_a_adr

                        ' Give score to appropriate player
                        rdlong r0, player2score_adr
                        add r0, #1
                        wrlong r0, player2score_adr
                        
                        jmp #:skipbullet
                        
:nocollision
                        add alienstatus_adr, #4
                        djnz r7, #:nextalien

:skipbullet
                        sub player2score_adr, #4

                        mov r0, #5              ' Bullet sprite of player 2
                        djnz r6, #:nextbullet

                        add player2score_adr, #4
                        
aliencheckcollision_ret ret

readspriteinfo
                        ' Get start sprite address with sprite_x_adr - (r0 * 20)
                        mov sprite_x_adr, fsprite_x_adr
                        shl r0, #2
                        sub sprite_x_adr, r0
                        shl r0, #2
                        sub sprite_x_adr, r0

                        mov sprite_y_adr, sprite_x_adr
                        sub sprite_y_adr, #4
                        mov sprite_s_adr, sprite_x_adr
                        sub sprite_s_adr, #8
                        mov sprite_a_adr, sprite_x_adr
                        sub sprite_a_adr, #12
                        mov sprite_p_adr, sprite_x_adr
                        sub sprite_p_adr, #16
readspriteinfo_ret      ret

' Display life for each player
displaylife
                        rdbyte r0, playerlife_adr
                        add r0, #8

                        rdlong r1, tilemap_adr
                        add r1, #19
                        wrbyte r0, r1

                        add playerlife_adr, #1
                        rdbyte r0, playerlife_adr
                        add r0, #8

                        rdlong r1, tilemap_adr
                        add r1, #28
                        wrbyte r0, r1

                        sub playerlife_adr, #1
                        
displaylife_ret         ret

' Display score for each player
displayscore
                        rdlong r6, player1score_adr
                        rdlong r2, tilemap_adr
                        add r2, #5
                        call #display_score_proc

                        rdlong r6, player2score_adr
                        rdlong r2, tilemap_adr
                        add r2, #12
                        call #display_score_proc
                        
displayscore_ret        ret

display_score_proc
                        mov r3, #4
:loop_score
                        mov r7, #10
                        call #divide

                        add r7, #8
                        wrbyte r7, r2
                        sub r2, #1
                        
                        djnz r3, #:loop_score
display_score_proc_ret  ret
                        


' Divide r6 by r7, return result (r6 / r7) into r6, and (r6 % r7) into r7
' use r0
divide                  shl r7, #15
                        mov r0, #16
:loop                   cmpsub r6, r7 wc
                        rcl r6, #1
                        djnz r0, #:loop
                        
                        mov r7, r6
                        shl r6, #16
                        shr r6, #16
                        shr r7, #16
divide_ret              ret

request_scanline        long SCANLINE_BUFFER-4
vertical_scroll         long SCANLINE_BUFFER-8
horizontal_scroll       long SCANLINE_BUFFER-12
top_y_adr               long SCANLINE_BUFFER-16
bottom_y_adr            long SCANLINE_BUFFER-20
stop_y_adr              long SCANLINE_BUFFER-24
tilemap_adr             long SCANLINE_BUFFER-28
tiles_adr               long SCANLINE_BUFFER-32
gamepad                 long SCANLINE_BUFFER-36

playerlife_adr          long SCANLINE_BUFFER-40
player1score_adr        long SCANLINE_BUFFER-44
player2score_adr        long SCANLINE_BUFFER-48
playertimer_adr         long SCANLINE_BUFFER-52


fsprite_x_adr           long SCANLINE_BUFFER-60
sprite_x_adr            long SCANLINE_BUFFER-60
sprite_y_adr            long SCANLINE_BUFFER-64
sprite_s_adr            long SCANLINE_BUFFER-68
sprite_a_adr            long SCANLINE_BUFFER-72
sprite_p_adr            long SCANLINE_BUFFER-76

alienstatus5_adr        long MEM_BUFFER-16
alienstatus_adr         long 0
explosion_adr           long MEM_BUFFER-20
alien_adr               long MEM_BUFFER-24
framecount_adr          long MEM_BUFFER-28

framecount              long 0
min_player_x            long -14<<7
max_player_x            long 238<<7
player                  long 0
player_x                long 0
player_y                long 0
sprite_a                long 0
min_player_y            long 16<<7
max_player_y            long 150<<7
player_bullet_x_offset  long 14<<7
player_bullet_y_offset  long -15<<7
bullet_speed            long 14<<7
player_thrust_x_offset  long 12<<7
player_thrust_y_offset  long 31<<7
nbaliveplayer           long 0
playershift             long 0
playertimer             long 0
playership_adr          long MEM_BUFFER-52

GAMEINIT_END

fit 440 ' real maximum is 448

org
GAMEPROCESS_START
:gameprocess_start
                        rdlong framecount2, framecount_adr

                        call #alienmove
                        call #alienshoot
                        call #alienbullet
                        
                        jmp   #__loader_return

' Manage when an alien shoot a bullet
alienshoot
                        ' Select a target (player 1 or 2)
                        mov r2, framecount
                        and r2, #1 wz
        if_nz           mov r2, #3
                        mov r1, #2
checkotherplayer
                        mov r0, r2
                        call #readspriteinfo2
                        rdlong target_y, sprite_y_adr2
                        cmps target_y, #0 wc, wz
        if_ae           jmp #:goodtarget
                        neg r2, r2
                        add r2, #3
                        djnz r1, #checkotherplayer
:goodtarget
                        sar target_y, #7

                        rdlong target_x, sprite_x_adr2
                        sar target_x, #7

                        mov alienstatus_adr2, alienstatus5_adr2 ' Start with alien 5 status
                        mov r7, #5              ' NB of aliens
:nextalien
                        ' Check if this alien is alive
                        rdlong r0, alienstatus_adr2
                        and r0, #$FF wz
        if_z            jmp #:skiptonextalien

                        ' Read alien sprite position
                        mov r0, #5
                        add r0, r7
                        call #readspriteinfo2
                        rdlong r2, sprite_x_adr2
                        add r2, alienbullet_offset_x
                        rdlong r3, sprite_y_adr2
                        add r3, alienbullet_offset_y

                        ' Determine if this alien wants to shoot now
                        call #getrandom2
                        and r0, #511
                        cmp r0, #509 wc, wz
        if_b            jmp #:skiptonextalien

                        ' Now let's find out a bullet that is available 

                        mov r6, #5              ' NB of alien bullets
                        mov abulletstatus_adr2, abulletstatus5_adr2
:nextalienbullet        
                        mov r0, #10
                        add r0, r6

                        call #readspriteinfo2

                        ' If bullet x is 0, this bullet is inactive
                        rdlong r0, sprite_x_adr2 wz
        if_nz           jmp #:skipnextbullet

                        ' We found one, now spawn this bullet near enemy position
                        wrlong r2, sprite_x_adr2
                        sar r2, #7
                        wrlong r3, sprite_y_adr2
                        sar r3, #7

                        ' Default X direction
                        mov r0, #140

                        ' Check if player is on the left of alien
                        add target_x, #32
                        cmp r2, target_x wc, wz
        if_a            neg r0, r0
        if_a            jmp #:setbulletdirection

                        ' Check if on the right
                        sub target_x, #32
                        add r2, #16
                        cmp r2, target_x wc, wz
        if_b            jmp #:setbulletdirection

                        ' Else, player is right below
                        mov r0, #0

:setbulletdirection
                        shl r0, #16
                        add r0, #220
                        
                        wrlong r0, abulletstatus_adr2
                        jmp #:skiptonextalien

:skipnextbullet
                        ' Next alien bullet
                        add abulletstatus_adr2, #4
                        djnz r6, #:nextalienbullet

:skiptonextalien
                        add alienstatus_adr2, #4
                        djnz r7, #:nextalien
alienshoot_ret          ret

' Move alien bullet
alienbullet
                        mov r7, #5              ' NB of alien bullets
                        mov abulletstatus_adr2, abulletstatus5_adr2
:nextalienbullet        
                        mov r0, #10
                        add r0, r7

                        call #readspriteinfo2

                        ' If bullet x is 0, this bullet is inactive
                        rdlong r0, sprite_x_adr2 wz
        if_z            jmp #:skipnextbullet
                        
                        rdlong r1, sprite_y_adr2

                        ' temp debug: make bullet move downward
                        rdlong r2, abulletstatus_adr2
                        mov r3, r2
                        sar r3, #16
                        
                        and r2, low_word_mask
                        add r0, r3
                        add r1, r2

                        ' TODO: when bullet go off-screen, mark it as unused
                        cmp r1, max_bullet_y2 wc, wz
        if_ae           mov r0, #0


                        wrlong r0, sprite_x_adr2
                        mov r4, r0
                        sar r4, #7
                        add r4, #2
                        wrlong r1, sprite_y_adr2
                        mov r5, r1
                        sar r5, #7
                        add r5, #2

                        ' Make bullet flicker on/off: DISABLED: it's not looking good on various tile
                        {
                        rdlong r1, sprite_a_adr2
                        movs r1, #0             ' Set frame 0
                        mov r0, framecount2
                        add r0, r7              ' Invert on/off for each bullet
                        and r0, #1 wz
        if_z            movs r1, #255           ' Set special frame 255 to make bullet flicker
                        wrlong r1, sprite_a_adr2 }

                        ' Now check for alienbullet collision with player
                        call #checkplayercollide

:skipnextbullet
                        ' Next alien bullet
                        add abulletstatus_adr2, #4
                        djnz r7, #:nextalienbullet
alienbullet_ret         ret

' Move alien in predefined pattern and 'kill' them when their timer expire
alienmove
                        mov alienstatus_adr2, alienstatus5_adr2 ' Start with alien 5 status
                        mov r7, #5              ' NB of aliens
nextalien2
                        ' Read alien sprite info
                        mov r0, #5
                        add r0, r7
                        call #readspriteinfo2
                        
                        ' Check if this alien is alive
                        rdlong r3, alienstatus_adr2
                        ' Extract alien Hitpoint in r4
                        mov r4, r3
                        and r4, #$FF wz
        if_nz           jmp #:alienisalive

                        ' check if alien has finished exploding
                        cmp r3, #0 wz
        if_nz           jmp #:skiptonextalien

                        ' Check if a least one player is currently alive
                        rdlong r0, playerlife_adr2 wz
        if_z            jmp #:skiptonextalien

                        ' Now randomly check if we spawn a new enemy
                        call #getrandom2
                        and r0, #511
                        cmp r0, #2 wc, wz
        if_a            jmp #:skiptonextalien

                        ' Spawn an enemy here
                        mov r4, #4              ' Initial hitpoints
                        ' These parameters will vary according to selected type
                        call #getrandom2
                        mov r3, r0
                        and r3, #7
                        cmp r3, #6 wc, wz
        if_a            mov r3, #2

                        add :self_mod, r3
                        nop
:self_mod               jmp #:jmp_table

:jmp_table
                        jmp #:alien_type0
                        jmp #:alien_type1
                        jmp #:alien_type2
                        jmp #:alien_type3
                        jmp #:alien_type4
                        jmp #:alien_type5

:alien_type0            ' Left Horizontal slide enemy
                        mov r0, #16             ' Start x position
                        neg r0, r0
                        mov r1, #10             ' Start y position
                        mov r2, #270            ' Lifetime counter
                        jmp #:continuealien

:alien_type1            ' Right Horizontal slide enemy
                        mov r0, #320            ' Start x position
                        mov r1, #10             ' Start y position
                        mov r2, #270            ' Lifetime counter
                        jmp #:continuealien

:alien_type2            ' Descending enemy
                        call #getrandom2
                        and r0, #255
                        add r0, #32
                        mov r1, #1              ' Start y position
                        mov r2, #150            ' Lifetime counter
                        jmp #:continuealien

:alien_type3            ' Zig zag
                        call #getrandom2
                        and r0, #63
                        mov r1, #20
                        add r1, r0

                        mov r0, #16
                        neg r0, r0
                        mov r2, #270            ' Lifetime counter
                        jmp #:continuealien

:alien_type4            ' Zig zag mirror
                        call #getrandom2
                        and r0, #63
                        mov r1, #20
                        add r1, r0

                        mov r0, #320
                        mov r2, #270            ' Lifetime counter
                        jmp #:continuealien

:alien_type5            ' The back bastard
                        call #getrandom2
                        and r0, #255
                        add r0, #32
                        mov r1, #180

                        mov r2, #400            ' Lifetime counter
                        mov r4, #10             ' Superior hitpoints!
                        jmp #:continuealien

:continuealien
                        sub :self_mod, r3
                        
                        ' Set information to this alien
                        shl r0, #7
                        shl r1, #7
                        wrlong r0, sprite_x_adr2
                        wrlong r1, sprite_y_adr2

                        shl r2, #8
                        add r2, r3
                        shl r2, #8
                        add r2, r4
                        wrlong r2, alienstatus_adr2
                        
                        jmp #:skiptonextalien

:alienisalive

                        ' Update position of alien
                        rdlong r0, sprite_x_adr2
                        rdlong r1, sprite_y_adr2

                        ' Extract alien type in r2
                        mov r2, r3
                        shr r2, #8
                        and r2, #$FF

                        ' Extract alien timer in r3
                        shr r3, #16

                        ' Here we move alien depending on its type

                        add :self_mod2, r2
                        nop
:self_mod2              jmp #:jmp_table_move

:jmp_table_move
                        jmp #:move_type0
                        jmp #:move_type1
                        jmp #:move_type2
                        jmp #:move_type3
                        jmp #:move_type4
                        jmp #:move_type5

:move_type0
                        add r0, #160
                        add r1, #30
                        jmp #:alien_move_done
:move_type1
                        sub r0, #160
                        add r1, #30
                        jmp #:alien_move_done
:move_type2
                        add r1, #230
                        jmp #:alien_move_done
:move_type3
                        mov r5, r3
                        and r5, #63
                        cmp r5, #31 wc, wz
        if_a            add r1, #70
        if_be           sub r1, #70
        
                        add r0, #160
                        jmp #:alien_move_done

:move_type4
                        mov r5, r3
                        and r5, #63
                        cmp r5, #31 wc, wz
        if_a            add r1, #70
        if_be           sub r1, #70
        
                        sub r0, #160
                        jmp #:alien_move_done

:move_type5
                        cmp r3, #333 wc, wz
        if_a            sub r1, #240
        if_a            jmp #:alien_move_done

                        cmp r3, #100 wc, wz
        if_a            jmp #:alien_move_done
        
                        cmp r3, #60 wc, wz
        if_a            sub r0, #340
        if_a            jmp #:alien_move_done

                        cmp r3, #20 wc, wz
        if_a            add r0, #340
        if_a            jmp #:alien_move_done

                        sub r1, #350
                        jmp #:alien_move_done

:alien_move_done
                        sub :self_mod2, r2
                        
                        sub r3, #1 wz
        if_nz           jmp #:skipalienreset

:doalienreset
                        ' Nuke this enemy by setting 0 hitpoint and type 0, timer also 0
                        mov r4, #0
                        mov r2, #0
                        ' And set y pos to -?? to hide the sprite
                        mov r1, alien_start_x2

:skipalienreset
                        ' Write back updated timer
                        shl r3, #8
                        add r3, r2
                        shl r3, #8
                        add r3, r4
                        wrlong r3, alienstatus_adr2
                        
                        ' Write back updated position, and keep r4, r5 to do player collision
                        wrlong r0, sprite_x_adr2
                        mov r4, r0
                        sar r4, #7
                        add r4, #8
                        wrlong r1, sprite_y_adr2
                        mov r5, r1
                        sar r5, #7
                        add r5, #8

                        ' Now check for alien collision with player
                        ' Cheap hack: alien ship are checked exactly has alien bullet (4x4)
                        ' So collision with alien will be a bit slack
                        call #checkplayercollide

:skiptonextalien
                        add alienstatus_adr2, #4

                        djnz r7, #nextalien2
alienmove_ret           ret

' Check if player collide with alien bullet or ship
checkplayercollide
                        mov r6, #2
                        mov r0, #0
                        mov pthrust_index, #1
                        
:nextplayer
                        call #readspriteinfo2
                        ' First, check if this player is alive
                        ' playerlife_adr2 contains (player1_live) + (player2_live << 8)
                        rdbyte r2, playerlife_adr2 wz
        if_z            jmp #:skipplayer

                        ' Now check if player is in the invincible starting timer
                        rdbyte r2, playertimer_adr2 wz
        if_nz           jmp #:skipplayer

                        ' Then check if player is already exploding
                        rdlong r0, explosion_adr2
                        shr r0, #16
                        rdlong r1, sprite_a_adr2
                        shr r1, #16
                        cmp r0, r1 wz, wc
        if_e            jmp #:skipplayer
                        

                        ' read and check player position with bullet (r4,r5)
                        rdlong r0, sprite_x_adr2
                        sar r0, #7
                        add r0, #11
                        rdlong r1, sprite_y_adr2
                        sar r1, #7
                        add r1, #2

                        cmps r4, r0 wc, wz
        if_b            jmp #:skipplayer
                        add r0, #10
                        cmps r4, r0 wc, wz
        if_a            jmp #:skipplayer
                        
                        cmps r5, r1 wc, wz
        if_b            jmp #:skipplayer
                        add r1, #30
                        cmps r5, r1 wc, wz
        if_a            jmp #:skipplayer

                        ' Player is hit: make player explode!
                        'xor outa, #1
                        sub r0, #6
                        shl r0, #7
                        wrlong r0, sprite_x_adr2
                        sub r1, #20
                        shl r1, #7
                        wrlong r1, sprite_y_adr2
                        
                        ' Turn Player into an explosion, starting at frame 0
                        rdlong r0, explosion_adr2
                        wrlong r0, sprite_a_adr2

                        ' Set player sprite width and height to: 4<<8 + 16
                        mov r0,#4
                        shl r0, #8
                        add r0, #16
                        wrlong r0, sprite_s_adr2

                        ' Turn off 'player thrust' sprite
                        mov r0, pthrust_index
                        call #readspriteinfo2
                        rdlong r0, sprite_a_adr2
                        movs r0, #255
                        wrlong r0, sprite_a_adr2
                        
:skipplayer
                        add playerlife_adr2, #1
                        add playertimer_adr2, #1
                        mov r0, #3
                        mov pthrust_index, #4
                        djnz r6, #:nextplayer

                        sub playerlife_adr2, #2
                        sub playertimer_adr2, #2
checkplayercollide_ret  ret

' Read sprite info
readspriteinfo2
                        ' Get start sprite address with sprite_x_adr - (r0 * 20)
                        mov sprite_x_adr2, fsprite_x_adr2
                        shl r0, #2
                        sub sprite_x_adr2, r0
                        shl r0, #2
                        sub sprite_x_adr2, r0

                        mov sprite_y_adr2, sprite_x_adr2
                        sub sprite_y_adr2, #4
                        mov sprite_s_adr2, sprite_x_adr2
                        sub sprite_s_adr2, #8
                        mov sprite_a_adr2, sprite_x_adr2
                        sub sprite_a_adr2, #12
                        mov sprite_p_adr2, sprite_x_adr2
                        sub sprite_p_adr2, #16
readspriteinfo2_ret     ret

' Compute a pseudo-random number
getrandom2
                        xor random2, framecount2
                        rol random2, #13
                        add random2, 0          ' memory address 0 = garbage
                        rol random2, #5
                        add random2, cnt
                        rol random2, #19
                        ' Output pseudo-random in r0
                        mov r0, random2
                        shr r0, #4
getrandom2_ret          ret

fsprite_x_adr2          long SCANLINE_BUFFER-60
sprite_x_adr2           long SCANLINE_BUFFER-60
sprite_y_adr2           long SCANLINE_BUFFER-64
sprite_s_adr2           long SCANLINE_BUFFER-68
sprite_a_adr2           long SCANLINE_BUFFER-72
sprite_p_adr2           long SCANLINE_BUFFER-76
alienstatus5_adr2       long MEM_BUFFER-16
alienstatus_adr2        long 0
framecount2             long 0
max_bullet_y2           long 178<<7
alienbullet_offset_x    long 7<<7
alienbullet_offset_y    long 6<<7
random2                 long 0
abulletstatus5_adr2     long MEM_BUFFER-48
abulletstatus_adr2      long 0
low_word_mask           long $0000FFFF
target_x                long 0
target_y                long 0
playerlife_adr2         long SCANLINE_BUFFER-40
explosion_adr2          long MEM_BUFFER-20
playertimer_adr2        long SCANLINE_BUFFER-52
pthrust_index           long 0
max_alien_x2            long 320<<7
alien_start_x2          long -16<<7
alien_start_y2          long 16<<7
player1score_adr2       long SCANLINE_BUFFER-44

GAMEPROCESS_END

' /////////////////////////////////////////////////////////////////////////////
' GLOBAL REGISTERS ////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        org                     $1e0

r0                      long                    $0
r1                      long                    $0
r2                      long                    $0
r3                      long                    $0
r4                      long                    $0
r5                      long                    $0
r6                      long                    $0
r7                      long                    $0

' /////////////////////////////////////////////////////////////////////////////
' LOADER REGISTERS ////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        org                     $1c0                        
__loader_return         res                     7
__loader_call           res                     6
__loader_execute

                        org                     $1e0                            ' general registers 1e0-1ef
__loader_registers
__g0                    res                     1 ' g0..g7 : Global COG Registers
__g1                    res                     1
__g2                    res                     1
__g3                    res                     1
__g4                    res                     1
__g5                    res                     1
__g6                    res                     1
__g7                    res                     1

__t0                    res                     1
__t1                    res                     1
__t2                    res                     1
__loader_ret            res                     1
__loader_stack          res                     1
__loader_page           res                     1
__loader_size           res                     1
__loader_jmp            res                     1

' //////////////////////////////////////////////////////////////////////////
' HUB VARIABLES ////////////////////////////////////////////////////////////
' //////////////////////////////////////////////////////////////////////////

org
pship000 long $00000000,$00000000,$00000000,$01000000,$00000001,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$04010000,$00000001,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$04010000,$00000104,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$03010000,$00000104,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$03010000,$00000104,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$03010000,$00000104,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$052A0100,$00000104,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$3C2A2A01,$00000103,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$3B2A2A01,$00000103,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$053B3B01,$00000104,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$3C2A2A01,$00010404,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$3B2A2A01,$00010504,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$2A2A0100,$00010504,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$03020201,$00010504,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$04030101,$00010503,$00000000,$00000000,$00000000,$00000000,$00000000,$01000000,$04030101,$01050503,$00000001,$00000100,$00000000
        long $00000000,$00000000,$CA010000,$04030101,$CA040503,$000101CA,$00000100,$00000000,$00000000,$00000000,$C9CA0100,$04030101,$CA040503,$0105CACA,$00000101,$00000000
        long $00000000,$00010000,$C9C90201,$04030101,$CA040503,$0505CACA,$00000105,$00000000,$00000000,$01010000,$C9C90202,$04030101,$C9040503,$0505CAC9,$00000105,$00000000
        long $00000000,$02010000,$C8C90102,$04030101,$C9040303,$0504C9C9,$00000105,$00000000,$00000000,$01010000,$C8C80101,$04030101,$C8040203,$0404C9C9,$00000105,$00000000
        long $00000000,$01010000,$C8C80101,$03030101,$C8010303,$0103C9C8,$00000001,$00000000,$00000000,$00000000,$01010101,$03040301,$01010304,$00010101,$00000000,$00000000
        long $00000000,$00000000,$00000000,$03050301,$00010305,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$03050301,$00010305,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$03040402,$01040304,$00000000,$00000000,$00000000,$00000000,$00000000,$02000000,$04020404,$04030204,$00000001,$00000000,$00000000
        long $00000000,$00000000,$04010000,$04040204,$03030203,$00000001,$00000000,$00000000,$00000000,$00000000,$04010000,$03040103,$03020101,$00000001,$00000000,$00000000
        long $00000000,$00000000,$01000000,$01010001,$01010101,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$01000000,$00000001,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02010000,$00000105,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$02010000,$00000104,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02010000,$00000103,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$02010000,$00000103,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$02010000,$00000104,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$3B010000,$00000105,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$2A010100,$0001033B,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$2A010100,$0001042B,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$3B010100,$00010405,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$2A010301,$0104043B,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$2A010301,$0105043B,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$2A010301,$0105042B,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$04020301,$01050305,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$04020301,$01050305,$00000000,$00000000,$00000000,$00000000,$00000000,$01010000,$04020302,$03050305,$00000101,$00000000,$00000000
        long $00000000,$01000000,$03040101,$04020302,$03050305,$01010204,$00000001,$00000000,$00000100,$C8010100,$0304CACA,$04020303,$04050305,$CACA0404,$000101C9,$00010000
        long $01000100,$CA020201,$0304CACA,$04020302,$03050305,$CACA0403,$010204CA,$00010001,$01010100,$C9030202,$0404C9CA,$04020202,$02030305,$C9CA0303,$040404CA,$00010102
        long $01010100,$C9020202,$0403C9C9,$04020202,$02020304,$C9C90303,$040403C9,$00010204,$01010100,$C8020201,$0303C8C8,$03020202,$02020304,$C9C90302,$040303C9,$00010204
        long $01010100,$C8010101,$0202C8C8,$03030201,$01030304,$C8C80202,$010101C9,$00010101,$00000000,$01000000,$01010101,$03040301,$01040303,$01010101,$00000001,$00000000
        long $00000000,$00000000,$00000000,$03050201,$01050203,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$03050201,$01050202,$00000000,$00000000,$00000000
        long $00000000,$00000000,$01000000,$03050202,$03050202,$00000001,$00000000,$00000000,$00000000,$00000000,$02010000,$03040202,$03040202,$00000104,$00000000,$00000000
        long $00000000,$00000000,$02020100,$02020102,$03020102,$00010403,$00000000,$00000000,$00000000,$00000000,$02020100,$01020101,$01020101,$00010303,$00000000,$00000000
        long $00000000,$00000000,$01010000,$00010100,$00010100,$00000101,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$01000000,$00000001,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$01000000,$00000104,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$04010000,$00000104,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$04010000,$00000103,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$04010000,$00000103,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$04010000,$00000103,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$04010000,$00012A05,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$03010000,$012A2A3C,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$03010000,$012A2A3B,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$04010000,$013B3B05,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$04040100,$012A2A3C,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$04050100,$012A2A3B,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$04050100,$00012A2A,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$04050100,$01020203,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$03050100,$01010304,$00000000,$00000000,$00000000,$00000000,$00010000,$01000000,$03050501,$01010304,$00000001,$00000000,$00000000
        long $00000000,$00010000,$CA010100,$030504CA,$01010304,$000001CA,$00000000,$00000000,$00000000,$01010000,$CACA0501,$030504CA,$01010304,$0001CAC9,$00000000,$00000000
        long $00000000,$05010000,$CACA0505,$030504CA,$01010304,$0102C9C9,$00000100,$00000000,$00000000,$05010000,$C9CA0505,$030504C9,$01010304,$0202C9C9,$00000101,$00000000
        long $00000000,$05010000,$C9C90405,$030304C9,$01010304,$0201C9C8,$00000102,$00000000,$00000000,$05010000,$C9C90404,$030204C8,$01010304,$0101C8C8,$00000101,$00000000
        long $00000000,$01000000,$C8C90301,$030301C8,$01010303,$0101C8C8,$00000101,$00000000,$00000000,$00000000,$01010100,$04030101,$01030403,$01010101,$00000000,$00000000
        long $00000000,$00000000,$00000000,$05030100,$01030503,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$05030100,$01030503,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$04030401,$02040403,$00000000,$00000000,$00000000,$00000000,$00000000,$01000000,$04020304,$04040204,$00000002,$00000000,$00000000
        long $00000000,$00000000,$01000000,$03020303,$04020404,$00000104,$00000000,$00000000,$00000000,$00000000,$01000000,$01010203,$03010403,$00000104,$00000000,$00000000
        long $00000000,$00000000,$00000000,$01010101,$01000101,$00000001,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000

pthrust000 long $002B3C00,$003C2B00,$003C052B,$2B053C00
        long $0005053C,$3C050500,$00050505,$05050500
        long $00050505,$05050500,$003C053C,$3C053C00
        long $002B052B,$2B052B00,$00002B00,$002B0000

pbullet000 long $00BCBC00,$BCBCBCBC
        long $BCBCBCBC,$BCBCBCBC
        long $BABCBCBA,$BABABABA
        long $BABABABA,$B9BABAB9
        long $B9BABAB9,$B9B9B9B9
        long $B9B9B9B9,$B8B9B9B8
        long $B8B9B9B8,$B8B9B9B8
        long $B8B8B8B8,$B8B8B8B8

alien000 long $00000000,$E9E9E900,$00DAEAEA,$00000000,$00000000,$292828E9,$DA4B2B2A,$00000000
        long $E8000000,$28282828,$4B2B2928,$000000EA,$E8000000,$28282828,$2B292828,$000000EA
        long $E8000000,$39393928,$2A284939,$000000E9,$E8000000,$39393928,$29284949,$000000E9
        long $E8000000,$39392828,$29282849,$000000E9,$E9E90000,$EAE9E9E9,$DBDBDAEA,$0000E9E9
        long $01E9EA00,$E9E9E902,$01E9E9E9,$00E9DB02,$01E9E95A,$01E9E901,$01E9E902,$2BDBDA01
        long $5C5C5CE8,$01E9E9E9,$E9E9E901,$E92B2B5A,$EAEAEAE8,$2B2B5A5A,$5C5C5C5A,$E9EAEAEA
        long $E8E8E8AA,$EAEAEAEA,$E9E9EAEA,$AAE8E8E8,$0000AA00,$E8E8E8E8,$E8E8E8E8,$00AA0000
        long $00000000,$AA000000,$000000AA,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$E9E9E900,$00DAEAEA,$00000000,$00000000,$292828E9,$DA4B2B2A,$00000000
        long $E8000000,$28282828,$4B2B2928,$000000EA,$E8000000,$39393928,$2B294939,$000000EA
        long $E8000000,$39393928,$2A284949,$000000E9,$E8000000,$39392828,$29282849,$000000E9
        long $E8000000,$39392828,$29282849,$000000E9,$E9E90000,$EAE9E9E9,$DBDBDAEA,$0000E9E9
        long $01E9EA00,$E9E9E902,$01E9E9E9,$00E9DB02,$01E9E95C,$01E9E901,$01E9E902,$5CDBDA01
        long $2B2B5AE8,$01E9E9E9,$E9E9E901,$E95A2B2B,$EAEAEAE8,$5C5C5A2B,$2B5A5C5C,$E9EAEAEA
        long $E8E8E8AA,$EAEAEAEA,$E9E9EAEA,$AAE8E8E8,$AA9C9CAB,$E8E8E8E8,$E8E8E8E8,$AB9C9CAA
        long $AAAB9CAA,$9C9CAA00,$00AA9C9C,$AA9CABAA,$0000AA00,$AAAA0000,$0000AAAA,$00AA0000
        long $00000000,$E9E9E900,$00DAEAEA,$00000000,$00000000,$292828E9,$DA4B2B2A,$00000000
        long $E8000000,$39393928,$4B2B2939,$000000EA,$E8000000,$39393928,$2B294949,$000000EA
        long $E8000000,$39392828,$2A282849,$000000E9,$E8000000,$39392828,$29282849,$000000E9
        long $E8000000,$39392828,$29282849,$000000E9,$E9E90000,$EAE9E9E9,$DBDBDAEA,$0000E9E9
        long $01E9EA00,$E9E9E902,$01E9E9E9,$00E9DB02,$01E9E92B,$01E9E901,$01E9E902,$5ADBDA01
        long $5A2B2BE8,$01E9E9E9,$E9E9E901,$E95A5C5C,$EAEAEAE8,$5A5C5C5C,$5C5A2B2B,$E9EAEAEA
        long $E8E8E8AB,$EAEAEAEA,$E9E9EAEA,$ABE8E8E8,$00AB9CAA,$E8E8E8E8,$E8E8E8E8,$AA9CAB00
        long $0000AA00,$9CAB0000,$0000AB9C,$00AA0000,$00000000,$AA000000,$000000AA,$00000000


explo000 long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$B8B80000,$000000B8,$00000000,$00000000,$AAAAB900,$00A9AAAA,$00000000
        long $00000000,$9CAAAAB8,$B8A99A9C,$00000000,$00000000,$04AA9CAA,$B8AA9C9C,$00000000
        long $00000000,$9C9C9AB9,$B8AA9C9B,$00000000,$00000000,$9C9CAAA9,$00AAAA9C,$00000000
        long $00000000,$AAAAAA00,$00B8AAAA,$00000000,$00000000,$A9B80000,$0000B8A9,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$A8B8A800,$00000000,$00000000,$00000000,$B8A9B8B8,$00B8A8A8,$00000000
        long $B8000000,$A9A8A8B8,$B8B8A9B9,$000000B8,$B8B80000,$A9B9B9A8,$A8B9A9AA,$00000000
        long $A8B80000,$B9B9B9A9,$B9AAAAAA,$000000B8,$B8000000,$AAB9B9B9,$A9B9A9AA,$0000B8A8
        long $B8B80000,$B9B9A9A9,$B9A9AAA9,$000000A8,$A8B80000,$B9AAAAA9,$B9AAA9B9,$0000B8A9
        long $B8B80000,$AAAAAAA9,$A8B8B9B9,$000000A8,$B8000000,$B9AAAAB9,$B8A8A9A9,$00000000
        long $00000000,$A9B9B9B8,$00B8A8A8,$00000000,$00000000,$A8A80000,$000000A8,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00020300,$00000000,$00000000
        long $02000000,$02B80203,$B8030202,$00000200,$03030000,$B8B802B8,$B8B8A8A8,$00000302
        long $02030000,$B9B8B8B8,$B8B802B8,$00030203,$B8020000,$B8B8B802,$02B802AA,$000002B8
        long $A8B80200,$00B9B8B8,$B9B8B800,$000202B8,$B8000000,$000000B9,$A9B90000,$0000B8A8
        long $B8020000,$0000B8A9,$B9AAB900,$000002A8,$A8030200,$00B8AAAA,$AAAAB8B8,$0000B802
        long $03B80200,$A9AA03AA,$A8B8B9B9,$000302A8,$02020000,$B9030202,$B8A8A9A9,$00000302
        long $02000000,$A9030202,$030303A8,$00000000,$00020000,$A8A80002,$00020203,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00020003,$00000002,$00000000
        long $00000000,$00000303,$00000303,$00000003,$02000000,$00000200,$00020200,$00000003
        long $03000000,$03020303,$00000202,$00020000,$00020000,$00020303,$02020000,$00000200
        long $02000000,$00000200,$02000200,$00000300,$00020000,$00000203,$00000000,$00020300
        long $02000000,$00000003,$00030200,$00000303,$02000000,$00020303,$00030200,$00000002
        long $00000000,$00030200,$00000202,$00000203,$00000000,$03030002,$03000302,$00000003
        long $00000000,$00020000,$00030203,$00000000,$00000000,$00000000,$00000003,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$02000002,$00000000,$00000000,$02000000,$00000003,$00000203,$00000000
        long $00000000,$00020000,$03000000,$00000000,$02000000,$00000000,$00020000,$00000000
        long $00000000,$00000000,$00000000,$00020200,$00000000,$00000000,$02000000,$00030000
        long $00000000,$00000000,$00000000,$00000000,$00000300,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00020000,$02000000,$00020000,$00000000,$00000000,$00000200
        long $00000003,$00000000,$00000000,$00000000,$03000000,$00000002,$00000000,$00030200
        long $00020300,$00000000,$02030003,$00000000,$00000000,$02000002,$00020000,$00000303
        long $00000000,$00000200,$00000003,$00000000,$00000000,$00000300,$00000000,$00000000
        long $00000000,$02000002,$00000002,$00000000,$00000200,$00000000,$00000003,$00000200
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000300,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000300
        long $00020000,$00000000,$00000000,$00020000,$00000000,$00000300,$00000000,$00000000

abullet000 long $009C9C00,$9CBABA9C
        long $9CBABA9C,$009C9C00
     