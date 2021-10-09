{*************************************
 *   Rem Dr Hydra v018 *
 *************************************

Dr Hydra is a clone of a popular NES and SNES puzzle game.
The REM engine was modified to use 8x8 tiles (instead of 16x16).
This game uses no sprites.

Code by Remi 'Remz' Veilleux
GFX by Louis-Philippe 'FoX' Guilbert

}

CON

  _clkmode = xtal1 + pll8x  ' Set clock multiplier to 8x
  _xinfreq = 10_000_000 + 0_000 ' Set to 10Mhz (and add 5000 to fix crystal imperfection of hydra prototype)
  _memstart = $10                   ' memory starts $10 in!

  SCANLINE_BUFFER = $7F00
  ' Define list of intercog global variable: they start right next to the video scanlinebuffer
  ' All these constant memory address are used for easy and fast access to shared memory
  ' between cogs and between assembly loaded chunk of code.
  ' They are prefixed 'spin_' here because they can only be accessed directly in 'spin' code.
  ' To use them in assembly, you need a copy stored in a cog register.
  ' Search for 'spin_request_scanline' as an example, you'll see it three times in this code:
  ' this comment, next is right below, and last one is the one being copied into a cog internal register
  ' for usage inside the assembly code.
  spin_request_scanline = SCANLINE_BUFFER-4
  spin_vertical_scroll = SCANLINE_BUFFER-8
  spin_horizontal_scroll = SCANLINE_BUFFER-12
  spin_top_y = SCANLINE_BUFFER-16
  spin_bottom_y = SCANLINE_BUFFER-20
  spin_stop_y = SCANLINE_BUFFER-24
  spin_tilemap_adr = SCANLINE_BUFFER-28
  spin_tiles_adr = SCANLINE_BUFFER-32
  spin_gamepad = SCANLINE_BUFFER-36
  spin_mouse_dx = SCANLINE_BUFFER-40
  spin_mouse_dy = SCANLINE_BUFFER-44
  spin_mouse_button = SCANLINE_BUFFER-48
  'reserved space for expansion

  ' begin sprite memory map:
  spin_sprite_x = SCANLINE_BUFFER-60
  spin_sprite_y = SCANLINE_BUFFER-64
  spin_sprite_s = SCANLINE_BUFFER-68
  spin_sprite_a = SCANLINE_BUFFER-72
  spin_sprite_p = SCANLINE_BUFFER-76
  '.. 16 sprites here

  ' MEM_BUFFER is set to the free top portion of HUB memory where
  ' miscellaneous game global variable can be stored at this point.
  MEM_BUFFER = SCANLINE_BUFFER - 388
  spin_level = MEM_BUFFER
  spin_speed = MEM_BUFFER-8
  spin_virus = MEM_BUFFER-16
  spin_random = MEM_BUFFER-24
  spin_prevpad = MEM_BUFFER-32
  spin_inputdir = MEM_BUFFER-40
  spin_inputbutton = MEM_BUFFER-48
  spin_prevplayer = MEM_BUFFER-56
  spin_keyrepeat = MEM_BUFFER-64 
  spin_canvas = MEM_BUFFER-72
  spin_next1 = MEM_BUFFER-80
  spin_next2 = MEM_BUFFER-88
  spin_current1 = MEM_BUFFER-96
  spin_current2 = MEM_BUFFER-104
  spin_posx = MEM_BUFFER-112
  spin_posy = MEM_BUFFER-120
  spin_downaccum = MEM_BUFFER-128
  spin_orient = MEM_BUFFER-136
  spin_pstate = MEM_BUFFER-144
  spin_combo = MEM_BUFFER-152
  spin_attack = MEM_BUFFER-160
  spin_aistate = MEM_BUFFER-168
  spin_game1p_callmem = MEM_BUFFER-176
  spin_aitoprow = MEM_BUFFER-184

  ' Map dimension. This much match the map size found in REM_gfx_engine_018!
  ' (Map are normally exported by Mappy and copy/pasted into 'Rem_dr_hydra_data_018' starting at line 14
  ' Reminder: the screen is 256x192, tiles are 8x8, which gives 32x24 tiles.
  ' Limitation:
  ' in the default implementation of rem_gfx_engine, MAPSIZEX must be a power of 2.
  ' This greatly limit its usefulness, as you can only have 32, 64,.. width for you map.
  ' MAPSIZEY have no restriction, can be from 1 to infinity.

  ' Also, in the default implementation, if you try to vertically scroll past the top or bottom of your map,
  ' the gfx engine will display black (empty) lines.
  MAPSIZEX = 32
  MAPSIZEY = 96

  ' Gamepad constant declaration
  NES_RIGHT  = %00000001
  NES_LEFT   = %00000010
  NES_DOWN   = %00000100
  NES_UP     = %00001000
  NES_PAD    = %00001111
  NES_START  = %00010000
  NES_SELECT = %00100000
  NES_B      = %01000000
  NES_A      = %10000000


VAR
  ' TV driver legacy variable definition. DON'T USE THEM.
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
  long colors[1]

  ' General purpose spin temporary variable
  long temp1

  ' Parameter for rem_gfx_engine:
  long cog_number     ' Current rendering cog ID
  long cog_total      ' Total number of required rendering cog

OBJ

  key   : "keyboard_iso_010.spin"
  tv    : "rem_tv_018.spin"
  gfx   : "rem_gfx_engine_018.spin"
  data  : "rem_dr_hydra_data_018.spin"
  loader : "rem_loader_kernel_018.spin"


PUB start
  DIRA[0] := 1 ' Set debug LED ready for output         
  'outa[0] := 1 ' Use this to lit the debug led

  ' Use this color to set the background overscan color. Typically black ($02)
  colors[0] := $02

  ' Rem GFX engine setup variables:
  long[spin_tilemap_adr] := data.tilemap                ' Tilemap address
  long[spin_tiles_adr] := data.tiles                    ' Tiles address

  long[spin_top_y] := 96                                 ' How many 'top lines' (non-scrolling)
  long[spin_bottom_y] := 96                            ' Where 'bottom lines' (non-scrolling) starts
  long[spin_stop_y] := 192                              ' Specify a scanline where we stop processing image

  long[spin_vertical_scroll] := 0                       ' Map vertical scrolling
  long[spin_horizontal_scroll] := 0                     ' Map horizontal scrolling

  ' Boot requested number of rendering cogs:
  ' cog_total values are:
  ' 1 = Unnacceptable: screen will flicker horrendously
  ' 2 = No sprite, i.e.: just enough cpu power to render the tilemap
  ' 3 = Couple of sprites.
  ' 4 = A lot of sprites.
  ' If you don't provide enough rendering cogs to draw the sprites, you might see missing sprite horizontal lines
  ' and the debug LED will light up to indicate you need more rendering cogs, or less sprite on the same line, or
  ' horizontally smaller sprites.  
  cog_total := 3
  cog_number := 0
  repeat
    gfx.start(@cog_number)
    repeat 10000 ' Allow some time for previous cog to boot up before setting 'cog_number' again
    cog_number++
  until cog_number == cog_total

  ' Start tv driver
  longmove(@tv_status, @tvparams, 14)
  tv_colors := @colors
  tv.start(@tv_status)

  ' Start keyboard driver
  key.start(3)
  
  ' Start assembler code!
  ' Each chunks of code loaded with this 'loader' kernel can have a maximum of 340 longs.
  ' If you need more code, you'll have to load another chunk.
  ' By switching chunk, you lose SOME OF YOUR COG MEMORY VARIABLES. So remember to store every persistent
  ' info to HUB memory using 'MEM_BUFFER' constant or use the top part of cog memory to keep persistent info.
  ' GAMEINIT_START is a special, it is used to setup the initial fixed 100 longs of cog memory
  loader.start(@GAMEINIT_START)

  ' Start of main spin loop here.
  ' The spin code is only used to read the gamepad/keyboard.
  ' Someday this legacy stuff should be replaced by a proper assembly input driver.
  repeat
    ' Wait for a VBL using the legacy TV variable 'tv_status'
    repeat while tv_status == 1
    repeat while tv_status == 2

    ' Read both gamepad
    temp1 := NES_Read_Gamepad

    if(temp1&$00ff == $00ff) ' controller 0 not plugged in, pretend all buttons are unpressed.
      temp1&=$ff00
    if(temp1&$ff00 == $ff00) ' controller 1 not plugged in, pretend all buttons are unpressed.
      temp1&=$00ff

    ' Player 1:
    if(key.keystate(119)) 'w'
      temp1|=CONSTANT(NES_UP)
    elseif(key.keystate(115)) 's'
      temp1|=CONSTANT(NES_DOWN)
    if(key.keystate(97)) 'a'
      temp1|=CONSTANT(NES_LEFT)
    elseif(key.keystate(100)) 'd'
      temp1|=CONSTANT(NES_RIGHT)
    if(key.keystate(121)) 'y'
      temp1|=CONSTANT(NES_A)
    elseif(key.keystate(103)) 'g'
      temp1|=CONSTANT(NES_B)

    ' Player 2:
    if(key.keystate($E8))       ' Num pad 8-4-6-2
      temp1|=CONSTANT(NES_UP<<8)
    elseif(key.keystate($E2))
      temp1|=CONSTANT(NES_DOWN<<8)
    if(key.keystate($E4))
      temp1|=CONSTANT(NES_LEFT<<8)
    elseif(key.keystate($E6))
      temp1|=CONSTANT(NES_RIGHT<<8)
    if(key.keystate($EA))        ' num pad decimal . 
      temp1|=CONSTANT(NES_A<<8)
    elseif(key.keystate($E0)) ' Num pad 0
      temp1|=CONSTANT(NES_B<<8)
    if(key.keystate($C2))
      temp1|=CONSTANT(NES_UP<<8)
    elseif(key.keystate($C3))
      temp1|=CONSTANT(NES_DOWN<<8)
    if(key.keystate($C0))
      temp1|=CONSTANT(NES_LEFT<<8)
    elseif(key.keystate($C1))
      temp1|=CONSTANT(NES_RIGHT<<8)

    ' output gamepads values to our global hub memory
    long[spin_gamepad] := temp1

  ' Repeat forever

'end of main
'---------------------------------------------

' General read gamepad spin function
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



' Start of assembler section
DAT

' Legacy TV driver stuff. DON'T MODIFY ANYTHING HERE.
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

' Here starts the code. GAMEINIT_START is the first chunk of code loaded in by the loader kernel.
' It is a special case: this code chunk is only 100 longs, and will stay permanently at cog address 0..99
' This is where you can keep persistent variable, and also store in a few general purpose functions.
                        org
GAMEINIT_START
                        mov dira, #1            ' Prepare led debug                        

                        ' Immediately call in another assembly code chunk.
                        ' Doing so will copy the requested chunk from cog address 100..439
                        mov    __loader_page, #(_memstart+@GAMEMAIN_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@GAMEMAIN_START)            
                        mov    __loader_size, #(GAMEMAIN_END-GAMEMAIN_START)
                        mov    __loader_jmp, #GAMEMAIN_START
                        jmpret __loader_ret,#__loader_call

' General purpose divide function. Also kept in memory forever.
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

' param1:pindex  param2:r7   return value in r7
GetRandom
                        rdlong rand_temp1, random_adr

                        mov rand_temp2, rand_temp1
                        shl rand_temp2, #9

                        mov rand_temp3, rand_temp1
                        shr rand_temp3, #3

                        mov rand_temp1, rand_temp2
                        add rand_temp1, rand_temp3
                        add rand_temp1, random_magic
                        xor rand_temp1, random_magic2

                        wrlong rand_temp1, random_adr
                        shr rand_temp1, #22
                        and rand_temp1, r7
                        mov r7, rand_temp1
                        
        {Function GetRandom:Int(param1, param2)
        Local t = random[param1]
        random[param1] = ((t Shl 9) + (t Shr 3) + 1023045607) ~ 1937162121
        t = random[param1] Shr 22
        t = t & param2
        Return t
        End Function}
GetRandom_ret           ret

' param1:pindex         return value in r7
GetBrick
                        mov r7, #255
                        call #GetRandom
                        cmp r7, #85 wc, wz
        if_b            mov r7, #0
        if_b            jmp #GetBrick_ret

                        cmp r7, #170 wc, wz
        if_a            mov r7, #2
        if_a            jmp #GetBrick_ret

                        mov r7, #1
        
        {Function GetBrick:Int(param1)
        Local t = GetRandom(param1, 255)
        If(t < 85)
                Return 0
        Else If(t > 170) 
                Return 2
        Else
                Return 1
        EndIf
        End Function}
GetBrick_ret            ret

' Here, we have to set a cog register for every global hub memory that we want to access
request_scanline        long spin_request_scanline
vertical_scroll         long spin_vertical_scroll
horizontal_scroll       long spin_horizontal_scroll
top_y_adr               long spin_top_y
bottom_y_adr            long spin_bottom_y
stop_y_adr              long spin_stop_y
tilemap_adr             long spin_tilemap_adr
tiles_adr               long spin_tiles_adr
gamepad_adr             long spin_gamepad

level_adr               long spin_level
speed_adr               long spin_speed
virus_adr               long spin_virus
random_adr              long spin_random
prevpad_adr             long spin_prevpad
inputdir_adr            long spin_inputdir
inputbutton_adr         long spin_inputbutton
prevplayer_adr          long spin_prevplayer
keyrepeat_adr           long spin_keyrepeat
canvas_adr              long spin_canvas
next1_adr               long spin_next1
next2_adr               long spin_next2
current1_adr            long spin_current1
current2_adr            long spin_current2
posx_adr                long spin_posx
posy_adr                long spin_posy
downaccum_adr          long spin_downaccum
orient_adr              long spin_orient
pstate_adr              long spin_pstate
combo_adr               long spin_combo
attack_adr              long spin_attack
aistate_adr             long spin_aistate
enemy_attack_adr        long spin_attack+4
enemy_pstate_adr        long spin_pstate+4
enemy_downaccum_adr     long spin_downaccum+4
aitoprow_adr            long spin_aitoprow

game1p_callmem_adr      long spin_game1p_callmem

' From here on, you can add game variable that you want to keep permanently
' (i.e.: not lose them when you switch code chunk using the loader kernel)

' GAME VARIABLES GO HERE...
framecount              long 0
state                   long 0
nextstate               long 1
tileoffset              long 0
menuchoice              long 0
cursorflicker           long 0
maxchoice               long 0
gamemode                long 0
gamemodeset             long 0
doctor                  long 0
score                   long 0
hiscore                 long 0
tilearray_adr           long 0
tilearray256_adr        long 0
gamepad                 long 0
zero                    long 0
random_magic            long 1023045607
random_magic2           long 1937162121
rand_temp1              long 0
rand_temp2              long 0
rand_temp3              long 0
number1000              long 1000

pindex                  long 0 'player index (0-1)

' END OF GAME VARIABLES

' Fit 100 will enforce that the previous code section + variable do fit inside 100 longs.
' Else, the compiler will warn you that 'ORIGIN EXCEEDS FIT LIMIT.'
' This means that you have too many variable, or too much code stored here.
                        fit 100


' Real game code starts here!
' Note the org 100, which tells the assembler to generate code from cog address 100.
' This is because we want to keep our previously defined cog variable and functions
' without overriding them.
                        org 100

GAMEMAIN_START

main_loop
                        ' Debug led flicker tester: enable this to see if your main loop is working.
                        ' Enabling this line will make the debug LED flicker at 60 hz (pretty fast).
                        'xor outa, #1
                        call #CheckKeyboard

                        cmp state, #0 wz
        if_e            call #ScreenOpen
                        cmp state, #1 wz
        if_e            call #MainMenu
                        cmp state, #2 wz
        if_e            call #ScreenClose
                        cmp state, #5 wz
        if_e            call #SettingStart
                        cmp state, #7 wz
        if_e            call #MainMenuStart
        
        'If(state = 0) Then ScreenOpen()
        'If(state = 1) Then MainMenu()
        'If(state = 2) Then ScreenClose()
        'If(state = 5) Then SettingStart()
        'If(state = 7) Then MainMenuStart()        

                        ' Call in another chunk of code!
                        ' WARNING: do NOT try to put this piece of code inside a call!
                        ' Doing so will crash your game, because remember that call internaly
                        ' works by using self-modifying code to jump back when doing ret.
                        ' Since the loader kernel replace all memory with the next chunk,
                        ' the self-modifyed ret value will get overwritten.
                        mov    __loader_page, #(_memstart+@GAMEPROCESS_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@GAMEPROCESS_START) & $1FF         
                        mov    __loader_size, #(GAMEPROCESS_END-GAMEPROCESS_START)
                        mov    __loader_jmp, #GAMEPROCESS_START
                        jmpret __loader_ret,#__loader_call

                        mov    __loader_page, #(_memstart+@GAMEPROCESS2_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@GAMEPROCESS2_START) & $1FF         
                        mov    __loader_size, #(GAMEPROCESS2_END-GAMEPROCESS2_START)
                        mov    __loader_jmp, #GAMEPROCESS2_START
                        jmpret __loader_ret,#__loader_call

                        mov    __loader_page, #(_memstart+@GAMEPROCESS6_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@GAMEPROCESS6_START) & $1FF         
                        mov    __loader_size, #(GAMEPROCESS6_END-GAMEPROCESS6_START)
                        mov    __loader_jmp, #GAMEPROCESS6_START
                        jmpret __loader_ret,#__loader_call

                        ' Wait for VBL
                        call #waitvbl

                        ' Hold 'start' for slow motion (debugging)
                        test gamepad, #NES_START wz
        if_z            jmp #:skipslow
                        mov r7, #40
:slowmo                        
                        call #waitvbl
                        djnz r7, #:slowmo
:skipslow
                        

                        ' Increment our game variable framecount.
                        ' Since this variable is stored in 'permanent' cog memory,
                        ' we don't have to backup-it in HUB.
                        add framecount, #1

                        {rdbyte r6, inputdir_adr
                        mov r5, #0
                        call #debugprint
                        mov r0, inputdir_adr
                        add r0, #4
                        rdbyte r6, r0
                        mov r5, #32
                        call #debugprint}                        

                        jmp #main_loop

' Wait for the TV driver to finish displaying the last scanline (192).
' Note: Altought his function is general purpose, it is stored here because we'll only
' need it from this code chunk. In other words, there is no need to 'waste' our valuable
' shared 100 longs with it.
waitvbl                 
:wait_status_1          rdlong r0, request_scanline
                        cmp r0, #191            wz
        if_ne           jmp #:wait_status_1
:wait_status_2          rdlong r0, request_scanline
                        cmp r0, #192            wz
        if_ne           jmp #:wait_status_2

waitvbl_ret             ret

' Receive 'gamepad' of current player in 'gamepadtemp'
' Receive 'param1' (which player) in r7 (0-4)
CheckKeyRepeat          
                        add inputdir_adr, r7
                        add prevpad_adr, r7
                        add keyrepeat_adr, r7

                        mov r0, gamepadtemp
                        and r0, #NES_PAD
       ' Local t = gamepad & NES_PAD                  

                        wrbyte zero, inputdir_adr
       'inputdir[param1] = 0

                        rdbyte r1, prevpad_adr
                        cmp r0, r1 wz
        if_e            jmp #:ckr_not_direction

                        mov r1, framecount
                        add r1, #12
                        wrlong r1, keyrepeat_adr

                        wrbyte r0, prevpad_adr
                        wrbyte r0, inputdir_adr

        {' User pressed a new direction: restart repetition delay
        If(t <> prevpad[param1])
                keyrepeat[param1] = framecount + 12
                prevpad[param1] = t
                inputdir[param1] = t
        EndIf}

:ckr_not_direction
                        rdlong r1, keyrepeat_adr
                        cmp framecount, r1 wc, wz
        if_b            jmp #:ckr_not_repeat

                        mov r1, framecount
                        add r1, #4
                        wrlong r1, keyrepeat_adr

                        wrbyte r0, inputdir_adr

:ckr_not_repeat
                        sub inputdir_adr, r7
                        sub prevpad_adr, r7
                        sub keyrepeat_adr, r7

        {If framecount >= keyrepeat[param1]
                keyrepeat[param1] = framecount + 4
                inputdir[param1] = t
        EndIf}


CheckKeyRepeat_ret      ret

' Display a number on screen (value to display:r6, offset on screen:r5)
debugprint
                        mov r2, tilearray_adr
                        add r2, r5
                        add r2, #4

                        mov r3, #4
:loop_display
                        mov r7, #10
                        call #divide

                        add r7, #70             ' Number 0 starts at tile #70
                        wrbyte r7, r2
                        sub r2, #1
                        
                        djnz r3, #:loop_display
debugprint_ret      ret

update_tileoffset
                        rdlong tilearray_adr, tilemap_adr
                        add tilearray_adr, #64  ' skip top and bottom tilemap row
                        add tilearray_adr, tileoffset                     ' skip to current screen
                        
                        mov tilearray256_adr, tilearray_adr
                        add tilearray256_adr, #256      ' tilearray256_adr point to 256 after tilearray_adr to help with
                                                        ' 9-bit immediate

                        mov r0, tileoffset
                        shr r0, #2
                        wrlong r0, vertical_scroll

update_tileoffset_ret   ret

CheckKeyboard
                        call #update_tileoffset

                        rdlong gamepad, gamepad_adr
                        mov gamepadtemp, gamepad

                        cmp gamemodeset, #1 wz
        if_e            jmp #:ck_mode1
                        mov r0, gamepad
                        shr r0, #8
                        or gamepadtemp, r0
                        mov r7, #0
                        call #CheckKeyRepeat
                        jmp #:ck_skipmode1
:ck_mode1
                        mov r7, #0
                        call #CheckKeyRepeat
                        
                        shr gamepadtemp, #8
                        mov r7, #4
                        call #CheckKeyRepeat
                        
        {If(gamemodeset <> 1)
                gamepad = player[0] | player[1]
                CheckKeyRepeat(0)
        Else
                gamepad = player[0]
                CheckKeyRepeat(0)
                gamepad = player[1]
                CheckKeyRepeat(1)
        EndIf}
:ck_skipmode1
 
                        mov r6, gamepad
                        mov r7, #0
:ck_loopbutton
                        wrbyte zero, inputbutton_adr

                        mov r0, r6
                        test r0, #NES_A wz
        if_z            jmp #:ck_not_buttona

                        rdbyte r1, prevplayer_adr
                        test r1, #NES_A wz
        if_nz           jmp #:ck_not_buttona

                        mov r1, #NES_A
                        wrbyte r1, inputbutton_adr 

:ck_not_buttona

                        mov r0, r6
                        test r0, #NES_B wz
        if_z            jmp #:ck_not_buttonb

                        rdbyte r1, prevplayer_adr
                        test r1, #NES_B wz
        if_nz           jmp #:ck_not_buttonb

                        mov r1, #NES_B
                        wrbyte r1, inputbutton_adr 

:ck_not_buttonb
                        wrbyte r6, prevplayer_adr
                        
                        ' Shift gamepad to next player
                        shr r6, #8
                        add inputbutton_adr, #4
                        add prevplayer_adr, #4
                        
                        add r7, #1
                        cmp r7, #2 wz
        if_ne           jmp #:ck_loopbutton

                        sub inputbutton_adr, #8
                        sub prevplayer_adr, #8
         
        {For Local p=0 Until 2
                inputbutton[p] = 0
                If (player[p] & NES_A) And Not (prevplayer[p] & NES_A) Then inputbutton[p] = NES_A
                If (player[p] & NES_B) And Not (prevplayer[p] & NES_B) Then inputbutton[p] = NES_B
                prevplayer[p] = player[p]
        Next}

                        cmp gamemodeset, #1 wz
        if_e            jmp #:ck_notmode1_2

                        mov r0, inputbutton_adr
                        add r0, #4
                        rdbyte r1, r0
                        mov r0, inputbutton_adr 
                        rdbyte r2, r0
                        or r2, r1
                        wrbyte r2, r0 
                        
        {' Combine both gamepads when not player in 2 player-mode
        If(gamemodeset <> 1)
                inputbutton[0] :| inputbutton[1]
        EndIf}
:ck_notmode1_2
                        
CheckKeyboard_ret       ret

ScreenOpen
                        rdlong r0, bottom_y_adr
                        add r0, #4
                        wrlong r0, bottom_y_adr
                        rdlong r0, top_y_adr
                        sub r0, #4 wz
                        wrlong r0, top_y_adr
        if_z            mov state, nextstate                        
ScreenOpen_ret          ret

ScreenClose
                        rdlong r0, bottom_y_adr
                        sub r0, #4
                        wrlong r0, bottom_y_adr
                        rdlong r0, top_y_adr
                        add r0, #4
                        wrlong r0, top_y_adr
                        cmp r0, #96 wz
        if_e            mov state, nextstate                        
ScreenClose_ret          ret
{        top_y :+ 4
        bottom_y :- 4
        If(top_y = 96) Then state = nextstate
}

MainMenu
                        rdbyte r0, inputdir_adr
                        
                        test r0, #NES_UP wz
        if_z            jmp #:mn_notup
                        cmp gamemode, #0 wc, wz
        if_a            sub gamemode, #1
        if_be           mov gamemode, #2

                        mov cursorflicker, #0
:mn_notup

                        test r0, #NES_DOWN wz
        if_z            jmp #:mn_notdown
                        cmp gamemode, #2 wc, wz
        if_b            add gamemode, #1
        if_ae           mov gamemode, #0

                        mov cursorflicker, #0
:mn_notdown                        
{
        If inputdir[0] & NES_UP
                If gamemode > 0
                        gamemode :- 1
                Else
                        gamemode = 2
                EndIf
                cursorflicker = 0
        EndIf
        If inputdir[0] & NES_DOWN
                If gamemode < 2
                        gamemode :+ 1
                Else
                        gamemode = 0
                EndIf
                cursorflicker = 0
        EndIf
        
        If inputbutton[0] = NES_A
                state = 2
                nextstate = 5
                gamemodeset = gamemode
        EndIf
}
                        rdbyte r0, inputbutton_adr
                        cmp r0, #NES_A wz
        if_ne           jmp #:mn_not_buttona
                        mov state, #2
                        mov nextstate, #5
                        mov gamemodeset, gamemode

:mn_not_buttona
                        mov r0, tilearray256_adr
                        add r0, #214
                        mov r1, #107

                        mov r2, #3
:mainmenu_clear                        
                        add r0, #50
                        wrbyte r1, r0
                        add r0, #14
                        wrbyte r1, r0
                        djnz r2, #:mainmenu_clear                        
        
                        add cursorflicker, #1

        ' Draw flashing cursor around selected item
        {If(cursorflicker & 4 = 0)
                Local t = (16 + (gamemode Shl 1)) Shl 5
                tilemap[8 + t] = 207
                tilemap[22 + t] = 207
        EndIf}        
                        mov r0, cursorflicker
                        and r0, #4 wz
        if_nz           jmp #MainMenu_ret

                        mov r0, tilearray256_adr
                        mov r1, gamemode
                        shl r1, #6
                        add r1, #264
                        
                        add r0, r1
                        mov r1, #207
                        wrbyte r1, r0
                        add r0, #14
                        wrbyte r1, r0
                        
MainMenu_ret            ret

MainMenuStart
                        mov tileoffset, #0
                        mov state, #0
                        mov nextstate, #1
        {tileoffset = 0
        state = 0
        nextstate = 1}
MainMenuStart_ret       ret

SettingStart
                        mov tileoffset, #72
                        shl tileoffset, #5
                        call #update_tileoffset
                        
                        mov state, #0
                        mov nextstate, #6
                        mov maxchoice, #1
                        mov menuchoice, #0

                        cmp gamemode, #2 wz
        if_e            mov maxchoice, #3
                        cmp gamemode, #0 wz
        if_e            mov r0, level_adr
        if_e            add r0, #4
        if_e            wrbyte zero, r0
                    
        {tileoffset = 72*32
        state = 0
        nextstate = 6
        maxchoice = 1
        menuchoice = 0
        If(gamemode = 2) Then maxchoice = 3
        If(gamemode = 0) Then level[1] = 0}
                        mov r1, #107
                        
                        mov r0, tilearray_adr
                        add r0, #72
                        wrbyte r1, r0
                        add r0, #1                
                        wrbyte r1, r0
                        add r0, #190
                        wrbyte r1, r0

                        mov r0, tilearray256_adr
                        add r0, #327
                        wrbyte r1, r0                     
        {
        tilemap[8 + 2 Shl 5 + tileoffset] = 107
        tilemap[9 + 2 Shl 5 + tileoffset] = 107
        tilemap[7 + 8 Shl 5 + tileoffset] = 107
        tilemap[7 + 18 Shl 5 + tileoffset] = 107
        }                       

                        cmp gamemode, #0 wz
        if_ne           jmp #:ss_notmode0
                        mov r0, tilearray_adr
                        add r0, #74
                        mov r2, #71
                        wrbyte r2, r0

                        mov r0, tilearray256_adr
                        add r0, #8
                        wrbyte r1, r0
                        add r0, #1
                        wrbyte r1, r0
                        add r0, #319                        
                        wrbyte r1, r0
                        add r0, #1
                        wrbyte r1, r0
                        
        {' If game is one player mode, change title to '1p'
        If(gamemode = 0)
                tilemap[10 + 2 Shl 5 + tileoffset] = 71
                
                'Clear 2p virus and speed info
                tilemap[8 + 8 Shl 5 + tileoffset] = 107
                tilemap[9 + 8 Shl 5 + tileoffset] = 107

                tilemap[8 + 18 Shl 5 + tileoffset] = 107
                tilemap[9 + 18 Shl 5 + tileoffset] = 107
        EndIf}

:ss_notmode0
                        cmp gamemode, #1 wz
        if_ne           jmp #:ss_notmode1
                        mov r2, #72
                        mov r3, #59

                        mov r0, tilearray_adr
                        add r0, #74
                        wrbyte r2, r0

                        mov r0, tilearray256_adr
                        add r0, #8
                        wrbyte r2, r0
                        add r0, #1
                        wrbyte r3, r0
                        add r0, #319
                        wrbyte r2, r0
                        add r0, #1
                        wrbyte r3, r0
                        
        {' 2P mode
        If(gamemode = 1)
                tilemap[10 + 2 Shl 5 + tileoffset] = 72

                tilemap[8 + 8 Shl 5 + tileoffset] = 72
                tilemap[9 + 8 Shl 5 + tileoffset] = 59

                tilemap[8 + 18 Shl 5 + tileoffset] = 72
                tilemap[9 + 18 Shl 5 + tileoffset] = 59
        EndIf}

:ss_notmode1

                        cmp gamemode, #2 wz
        if_ne           jmp #:ss_notmode2
                        mov r2, #46
                        mov r3, #58
                        mov r4, #56

                        mov r0, tilearray_adr
                        add r0, #72
                        wrbyte r2, r0
                        add r0, #1
                        wrbyte r3, r0
                        add r0, #1
                        wrbyte r4, r0

                        mov r0, tilearray256_adr
                        add r0, #7
                        wrbyte r2, r0
                        add r0, #1
                        wrbyte r3, r0
                        add r0, #1
                        wrbyte r4, r0
                        
                        add r0, #318
                        wrbyte r2, r0
                        add r0, #1
                        wrbyte r3, r0
                        add r0, #1
                        wrbyte r4, r0
        {
                ' VS Comp: change title 
        If(gamemode = 2)
                tilemap[8 + 2 Shl 5 + tileoffset] = 46
                tilemap[9 + 2 Shl 5 + tileoffset] = 58
                tilemap[10 + 2 Shl 5 + tileoffset] = 56

                tilemap[7 + 8 Shl 5 + tileoffset] = 46
                tilemap[8 + 8 Shl 5 + tileoffset] = 58
                tilemap[9 + 8 Shl 5 + tileoffset] = 56
                
                tilemap[7 + 18 Shl 5 + tileoffset] = 46
                tilemap[8 + 18 Shl 5 + tileoffset] = 58
                tilemap[9 + 18 Shl 5 + tileoffset] = 56
        EndIf
        }
:ss_notmode2
        
SettingStart_ret        ret

' Here, we can declare temporary cog registers.
' They will be destroyed whenever we load a different chunk of assembly code.
' So rule of thumb:
'   All permanent/shared info should be stored in the first 100-long of cog memory described above.
'   ALL cog registers defined here will be destroyed/filled with crap every time a code chunk gets loaded.
gamepadtemp             long 0

GAMEMAIN_END
' Put a safety 'fit' here: Your code CANNOT exceed this fit value. The compiler will warn you if it happens.
                        fit 440
' Q: Why?
' A: Because a cog contains 512 long of memory, and the loader kernel mecanism only loads 340 of it at a time.
'    (340 = 440 - first 100 long)
'    So if you exceed this, you'll need to split some of your code to another 'chunk'.


' Here, we declare another 'chunk of assembly code', that can be swapped by the loader kernel.
' Remember to start at ORG 100 or ELSE TERRIBLE THINGS WILL HAPPEN.
                        org 100
GAMEPROCESS_START

                        cmp state, #6 wz
        if_e            call #SettingLoop
        'If(state = 6) Then SettingLoop()

                        ' VERY IMPORTANT: You need to do this jmp to return back to the calling code.
                        jmp   #__loader_return
SettingLoop
                        mov r0, inputbutton_adr
                        add r0, #4
                        rdbyte r1, r0
                        rdbyte r0, inputbutton_adr
                        or r0, r1
                        wrbyte r0, inputbutton_adr

                        mov r0, inputdir_adr
                        add r0, #4
                        rdbyte r1, r0
                        and r1, #(NES_UP|NES_DOWN)
                        rdbyte r0, inputdir_adr
                        or r0, r1
                        wrbyte r0, inputdir_adr
                        
        {' Mix input of player 2 for buttons and up/down controls
        inputbutton[0] :| inputbutton[1]
        Local t = inputdir[1] & (NES_UP | NES_DOWN)
        inputdir[0] :| t }

                        rdbyte r0, inputbutton_adr
                        test r0, #NES_B wz
        if_z            jmp #:sl_notb
                        mov state, #2
                        mov nextstate, #7
                        mov gamemodeset, #0
        {If(inputbutton[0] = NES_B)
                state = 2
                nextstate = 7
                gamemodeset = 0
        EndIf}

:sl_notb        
                        rdbyte r0, inputbutton_adr
                        test r0, #NES_A wz
        if_z            jmp #:sl_nota
                        mov state, #2
                        cmp gamemode, #0 wz
        if_e            mov nextstate, #3
        if_e            mov score, #0
        if_ne           mov nextstate, #8
        {If(inputbutton[0] = NES_A)
                state = 2
                If(gamemode = 0)
                        nextstate = 3
                        score = 0
                Else
                        nextstate = 8
                EndIf
        EndIf}
:sl_nota

                        rdbyte r0, inputdir_adr
                        test r0, #NES_UP wz
        if_z            jmp #:sl_notup
                        cmp menuchoice, #0 wc, wz
        if_a            sub menuchoice, #1
        if_be           mov menuchoice, maxchoice
                        mov cursorflicker, #0
        {' Check user input
        If inputdir[0] & NES_UP
                If menuchoice > 0
                        menuchoice :- 1
                Else
                        menuchoice = maxchoice
                EndIf
                cursorflicker = 0
        EndIf}

:sl_notup        
                        test r0, #NES_DOWN wz
        if_z            jmp #:sl_notdown
                        cmp menuchoice, maxchoice wc, wz
        if_b            add menuchoice, #1
        if_ae           mov menuchoice, #0
                        mov cursorflicker, #0
        {If inputdir[0] & NES_DOWN
                If menuchoice < maxchoice
                        menuchoice :+ 1
                Else
                        menuchoice = 0
                EndIf
                cursorflicker = 0
        EndIf}

:sl_notdown

                        call #SettingLeftRight

                        mov r1, #107
                        mov r0, tilearray_adr
                        add r0, #165
                        wrbyte r1, r0
                        add r0, #13
                        wrbyte r1, r0
                        add r0, #52
                        wrbyte r1, r0
                        add r0, #19
                        wrbyte r1, r0

                        mov r0, tilearray256_adr
                        add r0, #6
                        wrbyte r1, r0
                        add r0, #19
                        wrbyte r1, r0
                        add r0, #76
                        wrbyte r1, r0
                        add r0, #6
                        wrbyte r1, r0

                        add r0, #91
                        wrbyte r1, r0
                        add r0, #4
                        wrbyte r1, r0
                        add r0, #124
                        wrbyte r1, r0
                        add r0, #4
                        wrbyte r1, r0
                        
        {        
        tilemap[5 + 5 Shl 5 + tileoffset] = 107
        tilemap[18 + 5 Shl 5 + tileoffset] = 107
        tilemap[6 + 7 Shl 5 + tileoffset] = 107
        tilemap[25 + 7 Shl 5 + tileoffset] = 107
        
        tilemap[6 + 8 Shl 5 + tileoffset] = 107
        tilemap[25 + 8 Shl 5 + tileoffset] = 107
        tilemap[5 + 11 Shl 5 + tileoffset] = 107
        tilemap[11 + 11 Shl 5 + tileoffset] = 107
        
        tilemap[6 + 14 Shl 5 + tileoffset] = 107
        tilemap[10 + 14 Shl 5 + tileoffset] = 107
        tilemap[6 + 18 Shl 5 + tileoffset] = 107
        tilemap[10 + 18 Shl 5 + tileoffset] = 107}
                        mov r1, #207
                        
                        test cursorflicker, #4 wz
        if_nz           jmp #:sl_cursornotflick
                        cmp gamemode, #2 wz
        if_e            jmp #:sl_mode2

                        cmp menuchoice, #0 wz
        if_ne           jmp #:sl_modenot2_choicenot0                        


                        mov r0, tilearray_adr
                        add r0, #165
                        wrbyte r1, r0
                        add r0, #13
                        wrbyte r1, r0
                        jmp #:sl_cursornotflick
:sl_modenot2_choicenot0
                        mov r0, tilearray256_adr
                        add r0, #101
                        wrbyte r1, r0
                        add r0, #6
                        wrbyte r1, r0
                        jmp #:sl_cursornotflick
:sl_mode2
                        mov r2, #7
                        mov r3, #19
                        cmp menuchoice, #1 wz
        if_e            mov r2, #8
                        cmp menuchoice, #2 wz
        if_e            mov r2, #14
        if_e            mov r3, #4
                        cmp menuchoice, #3 wz
        if_e            mov r2, #18
        if_e            mov r3, #4

                        shl r2, #5
                        add r2, #6
                        mov r0, tilearray_adr
                        add r0, r2
                        wrbyte r1, r0
                        add r0, r3
                        wrbyte r1, r0
        {' Draw flashing cursor around selected item
        If(cursorflicker & 4 = 0)
                If(gamemode <> 2)
                        If(menuchoice = 0)
                                tilemap[5 + 5 Shl 5 + tileoffset] = 207
                                tilemap[18 + 5 Shl 5 + tileoffset] = 207
                        Else
                                tilemap[5 + 11 Shl 5 + tileoffset] = 207
                                tilemap[11 + 11 Shl 5 + tileoffset] = 207
                        EndIf
                Else
                        Select menuchoice
                                Case 0
                                        tilemap[6 + 7 Shl 5 + tileoffset] = 207
                                        tilemap[25 + 7 Shl 5 + tileoffset] = 207
                                Case 1
                                        tilemap[6 + 8 Shl 5 + tileoffset] = 207
                                        tilemap[25 + 8 Shl 5 + tileoffset] = 207
                                Case 2
                                        tilemap[6 + 14 Shl 5 + tileoffset] = 207
                                        tilemap[10 + 14 Shl 5 + tileoffset] = 207
                                Case 3
                                        tilemap[6 + 18 Shl 5 + tileoffset] = 207
                                        tilemap[10 + 18 Shl 5 + tileoffset] = 207
                        EndSelect
                EndIf
        EndIf}
        
:sl_cursornotflick
                        mov r6, #0
                        mov r7, #7
                        call #DrawVirusLevel        
                        mov r6, #4
                        mov r7, #8
                        call #DrawVirusLevel        

                        mov r6, #0
                        mov r7, #15
                        call #DrawSpeed        
                        mov r6, #4
                        mov r7, #17
                        call #DrawSpeed        

        {DrawVirusLevel(0, 7 Shl 5)
        DrawVirusLevel(1, 8 Shl 5)
        
        DrawSpeed(0, 15 Shl 5)
        DrawSpeed(1, 17 Shl 5)}
        
                        add cursorflicker, #1

SettingLoop_ret         ret

' Param1:r6 (player index)  Param2:r7 (tile offset on screen)
DrawSpeed
                        mov r5, r7
                        shl r7, #5
                        add r7, tilearray_adr
                        add r7, #10

                        mov r0, speed_adr
                        add r0, r6
                        rdbyte r6, r0

                        mov r1, #107
                        mov r2, #14
:ds_loop
                        mov r0, r7
                        add r0, r2
                        wrbyte r1, r0 
                        djnz r2, #:ds_loop

                        cmp gamemode, #0 wz
        if_ne           jmp #:ds_continue
                        cmp r5, #17 wz
        if_e            jmp #DrawSpeed_ret

:ds_continue
                        mov r0, #1
                        cmp r6, #1 wz
        if_e            mov r0, #6
                        cmp r6, #2 wz
        if_e            mov r0, #11

                        mov r1, #207
                        
                        add r0, r7
                        wrbyte r1, r0
                        add r0, #1                                                 
                        wrbyte r1, r0
                        add r0, #1                                                 
                        wrbyte r1, r0

        {param1 = speed[param1]
        For Local i=14 Until 0 Step -1
                tilemap[10+i + param2 + tileoffset] = 107
        Next
        
        Local t = 11
        If(param1 = 1) Then t = 16
        If(param1 = 2) Then t = 21
        
        If(gamemode = 0 And param2 = 17 Shl 5) Then Return
        
        tilemap[t + param2 + tileoffset] = 207
        tilemap[t+1 + param2 + tileoffset] = 207
        tilemap[t+2 + param2 + tileoffset] = 207}

DrawSpeed_ret           ret

' Param1:r6 (player)  Param2:r7 (tile offset on screen)
DrawVirusLevel
                        shl r7, #5
                        add r7, tilearray_adr
                        add r7, #11
                        
                        mov r0, level_adr
                        add r0, r6
                        rdbyte r6, r0

                        mov r1, #184
                        cmp r6, #0 wc, wz
        if_a            mov r1, #186

                        mov r0, r7
                        wrbyte r1, r0

                        mov r2, #9
:dv_loop
                        mov r1, #222
                        cmp r6, r2 wc, wz
        if_a            mov r1, #223
                        mov r0, r7
                        add r0, r2
                        wrbyte r1, r0                        
                        djnz r2, #:dv_loop

                        mov r1, #187
                        cmp r6, #10 wc, wz
        if_a            mov r1, #189
                        mov r0, r7
                        add r0, #10
                        wrbyte r1, r0

                        mov r2, #70
                        mov r3, #70
                        
                        cmp r6, #10 wc, wz
        if_ae           mov r2, #71
        if_ae           mov r3, #60

                        add r3, r6
                        mov r0, r7
                        add r0, #12
                        wrbyte r2, r0
                        add r0, #1
                        wrbyte r3, r0           

        {Function DrawVirusLevel(param1, param2)
        param1 = level[param1]
        'Red block,   yellow
        '11,7 = 184      188   
        '12-20,7 = 222   223
        '21,7 = 185     189
        Local t = 184
        If(param1 > 0) Then t = 186
        tilemap[11 + param2 + tileoffset] = t
        For Local i=9 Until 0 Step -1
                t = 222
                If(param1 > i) Then t = 223
                tilemap[11 + i + param2 + tileoffset] = t
        Next
        t = 187
        If(param1 > 10) Then t = 189
        tilemap[21 + param2 + tileoffset] = t
        
        If(param1 >= 10)
                tilemap[23 + param2 + tileoffset] = 71
                tilemap[24 + param2 + tileoffset] = 60 + param1
        Else
                tilemap[23 + param2 + tileoffset] = 70
                tilemap[24 + param2 + tileoffset] = 70 + param1
        EndIf}
        
                        
DrawVirusLevel_ret      ret

'param1:r6 (player number),  param2:r7 (input dir of player)
SetVirusLevel
                        add level_adr, r6
                        
                        test r7, #NES_LEFT wz
        if_z            jmp #:sv_notleft
                        rdbyte r0, level_adr
                        cmpsub r0, #1
                        wrbyte r0, level_adr                        

:sv_notleft
                        test r7, #NES_RIGHT wz
        if_z            jmp #:sv_notright
                        rdbyte r0, level_adr
                        cmp r0, #11 wc, wz
        if_b            add r0, #1
                        wrbyte r0, level_adr                        

        {Function SetVirusLevel(param1, param2)
        If param2 & NES_LEFT
                If level[param1] > 0
                        level[param1]:- 1
                EndIf
        EndIf
        If param2 & NES_RIGHT
                If level[param1]< 11
                        level[param1]:+ 1
                EndIf
        EndIf}
:sv_notright        
                        sub level_adr, r6
SetVirusLevel_ret       ret

'param1:r6 (player number),  param2:r7 (input dir of player)
SetSpeed
                        
                        add speed_adr, r6
                        
                        test r7, #NES_LEFT wz
        if_z            jmp #:sp_notleft
                        rdbyte r0, speed_adr
                        cmpsub r0, #1
                        wrbyte r0, speed_adr                        

:sp_notleft
                        test r7, #NES_RIGHT wz
        if_z            jmp #:sp_notright
                        rdbyte r0, speed_adr
                        cmp r0, #2 wc, wz
        if_b            add r0, #1
                        wrbyte r0, speed_adr                        

        {If param2 & NES_LEFT
                If speed[param1] > 0
                        speed[param1] :- 1
                EndIf
        EndIf
        If param2 & NES_RIGHT
                If speed[param1] < 2
                        speed[param1] :+ 1
                EndIf
        EndIf}
:sp_notright        
                        sub speed_adr, r6
SetSpeed_ret            ret

SettingLeftRight
                        cmp gamemode, #2 wz
        if_e            jmp #:slr_mode2

                        mov r6, #0
                        rdbyte r7, inputdir_adr

                        cmp menuchoice, #0 wz
        if_ne           jmp #:slr_pl0_speed
                        call #SetVirusLevel
                        jmp #:slr_pl0_next
:slr_pl0_speed
                        call #SetSpeed
:slr_pl0_next

                        cmp gamemode, #1 wz
        if_ne           jmp #SettingLeftRight_ret

                        mov r6, #4
                        mov r0, inputdir_adr
                        add r0, #4 
                        rdbyte r7, r0

                        cmp menuchoice, #0 wz
        if_ne           jmp #:slr_pl1_speed
                        call #SetVirusLevel
                        jmp #SettingLeftRight_ret
:slr_pl1_speed
                        call #SetSpeed
                        jmp #SettingLeftRight_ret
        
        { ' if not 'vs comp':
        If(gamemode <> 2)
                ' if setting the virus level:
                If(menuchoice = 0)
                        SetVirusLevel(0, inputdir[0])
                Else
                        SetSpeed(0, inputdir[0])
                EndIf
                
                If(gamemode <> 1) Then Return
                
                If(menuchoice = 0)
                        SetVirusLevel(1, inputdir[1])
                Else
                        SetSpeed(1, inputdir[1])
                EndIf
                
                Return  
        EndIf}

:slr_mode2
                        mov r6, #0
                        rdbyte r7, inputdir_adr

                        cmp menuchoice, #0 wz
        if_ne           jmp #:slr_choice1
                        call #SetVirusLevel
                        jmp #SettingLeftRight_ret
:slr_choice1
                        cmp menuchoice, #1 wz
        if_ne           jmp #:slr_choice2
                        mov r6, #4
                        call #SetVirusLevel
                        jmp #SettingLeftRight_ret
:slr_choice2
                        cmp menuchoice, #2 wz
        if_ne           jmp #:slr_choice3
                        call #SetSpeed
                        jmp #SettingLeftRight_ret
:slr_choice3
                        mov r6, #4
                        call #SetSpeed

        
        {' If 'vs comp'
        If(menuchoice = 0)      
                SetVirusLevel(0, inputdir[0])
                Return
        EndIf
        If(menuchoice = 1)      
                SetVirusLevel(1, inputdir[0])
                Return
        EndIf
        If(menuchoice = 2)      
                SetSpeed(0, inputdir[0])
                Return
        EndIf
        If(menuchoice = 3)      
                SetSpeed(1, inputdir[0])
                Return
        EndIf}        


SettingLeftRight_ret    ret

GAMEPROCESS_END
fit 440


                        org 100
GAMEPROCESS2_START
                        cmp state, #4 wz
        if_e            jmp #Game1PLoop
                        cmp state, #9 wz
        if_e            jmp #Game2PLoop

        
        'If(state = 4) Then Game1PLoop()
        'If(state = 9) Then Game2PLoop()
                        ' VERY IMPORTANT: You need to do this jmp to return back to the calling code.
                        jmp   #__loader_return


Game1PLoop
                        rdbyte r6, level_adr
                        mov r5, #508
                        mov r4, #2
                        call #PrintValue
                        rdbyte r6, virus_adr
                        mov r5, #350
                        shl r5, #1              ' 700
                        mov r4, #2
                        call #PrintValue

                        cmp score, hiscore wc, wz
        if_a            mov hiscore, score

                        mov r6, hiscore
                        mov r5, #262
                        mov r4, #5
                        call #PrintValue                         
                        mov r6, score
                        mov r5, #358
                        mov r4, #5
                        call #PrintValue                         
                        
        {Function Game1PLoop()
        PrintValue(level[0], 1276, 2)
        PrintValue(virus[0], 1468, 2)
        
        If(score > hiscore) Then hiscore = score
        PrintValue(hiscore, 1030, 5)
        PrintValue(score, 1126, 5)}

                        wrbyte zero, game1p_callmem_adr

game1p_specialcall
                        call #AnimateVirus
        {AnimateVirus(0)}

                        mov    __loader_page, #(_memstart+@GAMEPROCESS3_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@GAMEPROCESS3_START) & $1FF         
                        mov    __loader_size, #(GAMEPROCESS3_END-GAMEPROCESS3_START)
                        mov    __loader_jmp, #GAMEPROCESS3_START
                        jmpret __loader_ret,#__loader_call

                        mov    __loader_page, #(_memstart+@GAMEPROCESS4_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@GAMEPROCESS4_START) & $1FF         
                        mov    __loader_size, #(GAMEPROCESS4_END-GAMEPROCESS4_START)
                        mov    __loader_jmp, #GAMEPROCESS4_START
                        jmpret __loader_ret,#__loader_call

                        mov    __loader_page, #(_memstart+@GAMEPROCESS5_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@GAMEPROCESS5_START) & $1FF         
                        mov    __loader_size, #(GAMEPROCESS5_END-GAMEPROCESS5_START)
                        mov    __loader_jmp, #GAMEPROCESS5_START
                        jmpret __loader_ret,#__loader_call

                        call #DrawNext

                        rdbyte r0, game1p_callmem_adr wz
        if_nz           jmp #game2p_special_ret                        
        {DrawNext(0)}

game1p2p
                        call #AnimateDoctor
        {AnimateDoctor()}

Game1PLoop_ret          jmp #__loader_return

Game2PLoop              
                        rdbyte r6, level_adr
                        mov r5, #77
                        mov r4, #2
                        call #PrintValue
                        
                        rdbyte r6, virus_adr
                        mov r5, #367
                        add r5, #256
                        mov r4, #2
                        call #PrintValue

                        add level_adr, #4
                        add virus_adr, #4
                        rdbyte r6, level_adr
                        mov r5, #83
                        mov r4, #2
                        call #PrintValue
                        
                        rdbyte r6, virus_adr
                        mov r5, #337
                        add r5, #256
                        mov r4, #2
                        call #PrintValue
                        sub level_adr, #4
                        sub virus_adr, #4
        {PrintValue(level[0], 1613, 2)
        PrintValue(virus[0], 2159, 2)
        PrintValue(level[1], 1619, 2)
        PrintValue(virus[1], 2129, 2)}

                        mov r1, #1
                        wrbyte r1, game1p_callmem_adr

                        ' Do player 1 update
                        mov r7, #1
                        call #offset_player_array2
                        jmp #game1p_specialcall
game2p_special_ret
                        wrbyte zero, game1p_callmem_adr
                        ' Go back to player 0 and update
                        mov r7, #1
                        neg r7, r7
                        call #offset_player_array2
                        jmp #game1p_specialcall                       


offset_player_array2
                        add pindex, r7
                        shl r7, #2
                        add canvas_adr, r7
                        add random_adr, r7
                        add level_adr, r7
                        add virus_adr, r7
                        add speed_adr, r7
                        add inputdir_adr, r7
                        add inputbutton_adr, r7
                        add next1_adr, r7
                        add next2_adr, r7
                        add current1_adr, r7
                        add current2_adr, r7
                        add posx_adr, r7
                        add posy_adr, r7
                        add downaccum_adr, r7
                        add orient_adr, r7
                        add pstate_adr, r7
                        add combo_adr, r7
                        add attack_adr, r7
                        add aistate_adr, r7
                        neg r7,r7
                        add enemy_attack_adr, r7
                        add enemy_pstate_adr, r7
                        add enemy_downaccum_adr, r7
offset_player_array2_ret ret

DrawNext
                        rdlong r0, canvas_adr
                        sub r0, #93
                        rdbyte r1, next1_adr
                        add r1, #184
                        rdbyte r2, next2_adr
                        add r2, #187
                        wrbyte r1, r0
                        add r0, #1
                        wrbyte r2, r0
        {Function DrawNext(param1)
        Local t = canvas[param1] - 3 Shl 5 + 3
        tilemap[t] = next1[param1] + 184
        tilemap[t+1] = next2[param1] + 187
        End Function}
DrawNext_ret            ret

AnimateDoctor
                        cmp doctor, #0 wz
        if_e            jmp #AnimateDoctor_ret

                        test framecount, #15 wz
        if_nz           jmp #AnimateDoctor_ret

                        mov r6, #130
                        mov r7, #112
                        call #SwapDoctor           
                        mov r6, #131
                        mov r7, #113
                        call #SwapDoctor           
                        mov r6, #146
                        mov r7, #128
                        call #SwapDoctor           
                        mov r6, #147
                        mov r7, #129
                        call #SwapDoctor           
                        mov r6, #162
                        mov r7, #144
                        call #SwapDoctor

                        sub doctor, #1           
        {Function AnimateDoctor()
        If(doctor = 0) Then Return
        If(framecount & 15 <> 0) Then Return
        
        SwapDoctor(130, 112)
        SwapDoctor(131, 113)
        SwapDoctor(146, 128)
        SwapDoctor(147, 129)
        SwapDoctor(162, 144)
        doctor :- 1
        End Function}
AnimateDoctor_ret       ret

'param2:r6,  param3:r7
SwapDoctor
                        mov r4, #7
:sw_loopj
                        mov r5, #15
:sw_loopi
                        mov r0, r4
                        shl r0, #5
                        add r0, r5
                        add r0, tilearray_adr
                        rdbyte r1, r0

                        cmp r1, r6 wz
        if_e            mov r1, r7
        if_e            jmp #:sw_skip
                        cmp r1, r7 wz
        if_e            mov r1, r6
:sw_skip
                        wrbyte r1, r0

                        add r5, #1
                        cmp r5, #27 wc, wz
        if_be           jmp #:sw_loopi
                        
                        add r4, #1
                        cmp r4, #11 wc, wz
        if_be           jmp #:sw_loopj
                        
        {Function SwapDoctor(param2, param3)
        For Local j=0 To 11
                For Local i=15 To 27
                        Local t = tilemap[tileoffset + i + j Shl 5]
                        If(t = param2)
                                t = param3
                        Else If(t = param3)
                                t = param2
                        End If
                        tilemap[tileoffset + i + j Shl 5] = t
                Next
        Next    
        End Function}
SwapDoctor_ret          ret

'param1:r6 (value) param2:r5 (screen pos)  param3:r4 (nb digit)
PrintValue
                        mov r2, tilearray_adr
                        add r2, r5

:pv_loop
                        mov r7, #10
                        call #divide

                        add r7, #70             ' Number 0 starts at tile #70
                        wrbyte r7, r2
                        sub r2, #1
                        
                        djnz r4, #:pv_loop
                        
        {Function PrintValue(param1, param2, param3)
        For Local i=param3 To 1 Step -1
                Local t = param1 Mod 10
                tilemap[param2] = t + 70
                param2 :- 1
                param1 = param1 / 10
        Next 
        End Function}
PrintValue_ret          ret
        
AnimateVirus
                        test framecount, #7 wz
        if_nz           jmp #AnimateVirus_ret
                        
                        mov r6, #152
                        mov r7, #168
                        call #SwapTiles

                        mov r6, #153
                        mov r7, #169
                        call #SwapTiles

                        mov r6, #154
                        mov r7, #170
                        call #SwapTiles

        {If framecount & 7 <> 0 Then Return
        
        ' Swap tiles to animate viruses
        SwapTiles(param1, 152, 168)
        SwapTiles(param1, 153, 169)
        SwapTiles(param1, 154, 170)}
AnimateVirus_ret        ret

' param1:pindex, param2=r6, param3=r7
SwapTiles
                        rdlong r3, canvas_adr
                        mov r4, #16
:st_loopj
                        mov r5, #8
:st_loopi
                        mov r0, r4
                        shl r0, #5
                        add r0, r5
                        add r0, r3
                        sub r0, #33
                        rdbyte r1, r0
                        cmp r1, r6 wz
        if_e            mov r1, r7
        if_e            jmp #:st_ok
                        cmp r1, r7 wz
        if_e            mov r1, r6

:st_ok
                        wrbyte r1, r0

                        djnz r5, #:st_loopi
        
                        djnz r4, #:st_loopj
        {For Local j=0 Until 16
                For Local i=0 Until 8
                        Local t = tilemap[canvas[param1] + i + j Shl 5]
                        If(t = param2)
                                t = param3
                        Else If(t = param3)
                                t = param2
                        End If
                        tilemap[canvas[param1] + i + j Shl 5] = t
                Next
        Next}    
SwapTiles_ret           ret
                        
GAMEPROCESS2_END
fit 440

                        org 100
GAMEPROCESS3_START

                        rdbyte r0, pstate_adr
                        cmp r0, #0 wz
        if_e            jmp #Player_State0
                        cmp r0, #5 wz
        if_e            jmp #Dead
                        cmp r0, #6 wz
        if_e            jmp #Win
        {If(pstate[0] = 0)
        Else If(pstate[0] = 1)
                CheckGroup(0)
        Else If(pstate[0] = 5)
                Dead(0)
        Else If(pstate[0] = 6)
                Win(0)
        EndIf}

                        ' VERY IMPORTANT: You need to do this jmp to return back to the calling code.
                        jmp   #__loader_return

Player_State0
                        call #EraseCurrent

                        cmp gamemodeset, #2 wz
        if_ne           jmp #:ps_notmode2
                        cmp pindex, #1 wz
        if_ne           jmp #:ps_notmode2
                   
                        mov    __loader_page, #(_memstart+@GAMEPROCESS7_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@GAMEPROCESS7_START) & $1FF         
                        mov    __loader_size, #(GAMEPROCESS7_END-GAMEPROCESS7_START)
                        mov    __loader_jmp, #GAMEPROCESS7_START
                        jmpret __loader_ret,#__loader_call
                        
:ps_notmode2            
                        call #CheckMove
                        call #MoveDown
                        call #DrawCurrent
                {EraseCurrent(0)
                        If(gamemodeset = 2 And p = 1)
                                AIControl(p)
                        EndIf

                CheckMove(0)
                MoveDown(0)
                DrawCurrent(0)}

                        jmp   #__loader_return

EraseCurrent
                        call #CalculateCanvasPos

                        mov r2, #32
                        wrbyte r2, r0
                        rdbyte r1, orient_adr
                        add r0, r1
                        wrbyte r2, r0  
        {Function EraseCurrent(param1)
        Local t = canvas[param1] + posx[param1] + posy[param1] Shl 5
        tilemap[t] = 32
        tilemap[t+orient[param1]] = 32
        End Function}
EraseCurrent_ret         ret

CheckMove
                        rdbyte r6, inputdir_adr

                        test r6, #NES_LEFT wz
        if_z            jmp #:cm_notleft
                        rdbyte r5, posx_adr
                        sub r5, #1
                        wrbyte r5, posx_adr

                        call #BlockCollision
                        cmp r7, #0 wz
        if_z            jmp #:cm_notleft
                        add r5, #1                         
                        wrbyte r5, posx_adr
:cm_notleft
        {Function CheckMove(param1)
        If(inputdir[param1] & NES_LEFT)
                posx[param1] :- 1
                If(BlockCollision(param1))
                        posx[param1] :+ 1
                EndIf
        EndIf}

                        test r6, #NES_RIGHT wz
        if_z            jmp #:cm_notright
                        rdbyte r5, posx_adr
                        add r5, #1
                        wrbyte r5, posx_adr

                        call #BlockCollision
                        cmp r7, #0 wz
        if_z            jmp #:cm_notright
                        sub r5, #1                         
                        wrbyte r5, posx_adr

:cm_notright

        {If(inputdir[param1] & NES_RIGHT)
                posx[param1] :+ 1
                If(BlockCollision(param1))
                        posx[param1] :- 1
                EndIf
        EndIf}
        
                        test r6, #NES_DOWN wz
        if_z            jmp #:cm_notdown
                        mov r1, #99
                        wrbyte r1, downaccum_adr
:cm_notdown        
        {If(inputdir[param1] & NES_DOWN)
                downaccum[param1] = 99
        EndIf}

                        rdbyte r6, inputbutton_adr

                        test r6, #NES_A wz
        if_z            jmp #:cm_nota
                        call #TurnRight

                        call #BlockCollision
                        cmp r7, #0 wz
        if_z            jmp #CheckMove_ret
                        call #TurnLeft

:cm_nota
                        test r6, #NES_B wz
        if_z            jmp #CheckMove_ret
                        call #TurnLeft

                        call #BlockCollision
                        cmp r7, #0 wz
        if_z            jmp #CheckMove_ret
                        call #TurnRight
                        
        {If(inputbutton[param1] & NES_A)
                TurnRight(param1)
                If(BlockCollision(param1))
                        TurnLeft(param1)
                EndIf
        EndIf
        If(inputbutton[param1] & NES_B)
                TurnLeft(param1)
                If(BlockCollision(param1))
                        TurnRight(param1)
                EndIf
        EndIf
        End Function}

CheckMove_ret           ret

TurnRight
                        rdbyte r0, orient_adr
                        cmp r0, #1 wz
        if_e            mov r0, #32
        if_e            wrbyte r0, orient_adr
        if_e            jmp #TurnRight_ret

                        mov r0, #1
                        wrbyte r0, orient_adr

                        rdbyte r0, current1_adr
                        rdbyte r1, current2_adr
                        wrbyte r1, current1_adr
                        wrbyte r0, current2_adr
        {Function TurnRight(param1)
        If(orient[param1] = 1)
                orient[param1] = 32
        Else
                orient[param1] = 1
                Local t = current1[param1]
                current1[param1] = current2[param1]
                current2[param1] = t
        EndIf
        End Function}
TurnRight_ret           ret

TurnLeft
                        rdbyte r0, orient_adr
                        cmp r0, #1 wz
        if_ne           jmp #:tl_orientnot1        

                        mov r0, #32
                        wrbyte r0, orient_adr

                        rdbyte r0, current1_adr
                        rdbyte r1, current2_adr
                        wrbyte r1, current1_adr
                        wrbyte r0, current2_adr
                        jmp #TurnLeft_ret

:tl_orientnot1                        
                        mov r0, #1
                        wrbyte r0, orient_adr
        {Function TurnLeft(param1)
        If(orient[param1] = 1)
                orient[param1] = 32
                Local t = current1[param1]
                current1[param1] = current2[param1]
                current2[param1] = t
        Else
                orient[param1] = 1
        EndIf
        End Function}
TurnLeft_ret            ret

MoveDown
                        rdbyte r1, downaccum_adr
                        add r1, #1
                        wrbyte r1, downaccum_adr

                        rdbyte r0, speed_adr
                        neg r0, r0
                        add r0, #2
                        shl r0, #4
                        add r0, #20

                        cmp r1, r0 wc,wz
        if_be           jmp #MoveDown_ret

                        wrbyte zero, downaccum_adr
                        rdbyte r1, posy_adr
                        add r1, #1
                        wrbyte r1, posy_adr

                        call #BlockCollision
                        cmp r7, #0 wz
        if_z            jmp #MoveDown_ret

                        rdbyte r0, posy_adr
                        sub r0, #1
                        wrbyte r0, posy_adr

                        call #DrawCurrent

                        mov r0, #1
                        wrbyte r0, pstate_adr 
                                                
        {downaccum[param1] :+ 1
        Local t = ((2-speed[param1]) Shl 4) + 20
        If(downaccum[param1] > t)
                downaccum[param1] = 0
                posy[param1] :+ 1
                
                If(BlockCollision(param1))
                        posy[param1] :- 1
                        DrawCurrent(param1)
                        pstate[param1] = 1
                EndIf
        EndIf}

MoveDown_ret            ret

' return value in r7
BlockCollision
                        mov r7, #1
                        call #CalculateCanvasPos
                        rdbyte r1, r0
                        cmp r1, #32 wz
        if_ne           jmp #BlockCollision_ret

                        rdbyte r1, orient_adr
                        add r0, r1
                        rdbyte r1, r0
                        cmp r1, #32 wz
        if_ne           jmp #BlockCollision_ret

                        mov r7, #0
                                                       
        {Function BlockCollision:Int(param1)
        Local t = canvas[param1] + posx[param1] + posy[param1] Shl 5
        If(tilemap[t] <> 32) Then Return 1
        If(tilemap[t+orient[param1]] <> 32) Then Return 1
        Return 0
        End Function}
BlockCollision_ret      ret

' return 'canvas[param1] + posx[param1] + posy[param1] Shl 5' in r0
' uses r1 as temp
CalculateCanvasPos
                        rdbyte r0, posy_adr
                        shl r0, #5
                        rdbyte r1, posx_adr
                        add r0, r1
                        rdlong r1, canvas_adr
                        add r0, r1
CalculateCanvasPos_ret  ret

DrawCurrent
                        rdbyte r3, current1_adr
                        rdbyte r4, current2_adr
                        
                        call #CalculateCanvasPos
                        
                        rdbyte r1, orient_adr
                        cmp r1, #1 wz
        if_ne           jmp #:dc_notorient1
                        add r3, #184
                        wrbyte r3, r0
                        add r0, #1
                        add r4, #187
                        wrbyte r4, r0
                        jmp #DrawCurrent_ret
:dc_notorient1
                        add r3, #156
                        wrbyte r3, r0
                        add r0, #32
                        add r4, #172
                        wrbyte r4, r0
        {Local t = canvas[param1] + posx[param1] + posy[param1] Shl 5
        If(orient[param1] = 1)
                tilemap[t] = current1[param1] + 184
                tilemap[t+1] = current2[param1] + 187
        Else
                tilemap[t] = current1[param1] + 156
                tilemap[t+32] = current2[param1] + 172
        EndIf}
DrawCurrent_ret         ret

Dead                    call #DeadInternal
Dead_ret                jmp   #__loader_return

DeadInternal
                        wrbyte zero, inputdir_adr
                        rdlong r0, canvas_adr
                        mov r2, #137
                        add r0, #129
                        mov r1, #138
                        wrbyte r1, r0
                        add r0, #1
                        wrbyte r2, r0
                        add r0, #1
                        wrbyte r2, r0
                        add r0, #1
                        wrbyte r2, r0
                        add r0, #1
                        wrbyte r2, r0
                        add r0, #1
                        mov r1, #141
                        wrbyte r1, r0
                        
                        add r0, #27
                        mov r1, #123
                        wrbyte r1, r0
                        add r0, #1
                        mov r1, #55
                        wrbyte r1, r0
                        add r0, #1
                        mov r1, #58
                        wrbyte r1, r0
                        add r0, #1
                        mov r1, #62
                        wrbyte r1, r0
                        add r0, #1
                        mov r1, #48
                        wrbyte r1, r0
                        add r0, #1
                        mov r1, #122
                        wrbyte r1, r0

                        add r0, #27
                        mov r1, #142
                        wrbyte r1, r0
                        add r0, #1
                        wrbyte r2, r0
                        add r0, #1
                        wrbyte r2, r0
                        add r0, #1
                        wrbyte r2, r0
                        add r0, #1
                        wrbyte r2, r0
                        add r0, #1
                        mov r1, #139
                        wrbyte r1, r0
                                                
        {Function Dead(param1)
        tilemap[canvas[param1] + 1 + 4 Shl 5] = 138
        tilemap[canvas[param1] + 2 + 4 Shl 5] = 137
        tilemap[canvas[param1] + 3 + 4 Shl 5] = 137
        tilemap[canvas[param1] + 4 + 4 Shl 5] = 137
        tilemap[canvas[param1] + 5 + 4 Shl 5] = 137
        tilemap[canvas[param1] + 6 + 4 Shl 5] = 141
        
        tilemap[canvas[param1] + 1 + 5 Shl 5] = 123
        tilemap[canvas[param1] + 2 + 5 Shl 5] = 55
        tilemap[canvas[param1] + 3 + 5 Shl 5] = 58
        tilemap[canvas[param1] + 4 + 5 Shl 5] = 62
        tilemap[canvas[param1] + 5 + 5 Shl 5] = 48
        tilemap[canvas[param1] + 6 + 5 Shl 5] = 122
        
        tilemap[canvas[param1] + 1 + 6 Shl 5] = 142
        tilemap[canvas[param1] + 2 + 6 Shl 5] = 137
        tilemap[canvas[param1] + 3 + 6 Shl 5] = 137
        tilemap[canvas[param1] + 4 + 6 Shl 5] = 137
        tilemap[canvas[param1] + 5 + 6 Shl 5] = 137
        tilemap[canvas[param1] + 6 + 6 Shl 5] = 139}
        
                        rdbyte r0, downaccum_adr
                        cmp r0, #0 wc, wz
        if_a            sub r0, #1
        if_a            wrbyte r0, downaccum_adr
        if_a            jmp #DeadInternal_ret

        {If(downaccum[param1] > 0)
                downaccum[param1] :- 1
                Return
        EndIf}

                        rdbyte r0, inputbutton_adr wz
        if_z            jmp #DeadInternal_ret

                        mov state, #2
                        cmp gamemodeset, #0 wz
        if_ne           jmp #:di_notmode0
                        rdbyte r0, pstate_adr
                        cmp r0, #6 wz
        if_ne           jmp #:di_notmode0
                        rdbyte r0, level_adr
                        add r0, #1
                        wrbyte r0, level_adr
                        mov nextstate, #3
                        jmp #:di_skip                                   

:di_notmode0
                        mov nextstate, #5
:di_skip
                        wrbyte zero, inputbutton_adr        
        {If(inputbutton[param1])
                state = 2
                If(gamemodeset = 0 And pstate[0] = 6)
                        level[0] :+ 1
                        nextstate = 3
                Else
                        nextstate = 5
                EndIf

                inputdir[0] = 0
                inputbutton[0] = 0
                inputdir[1] = 0
                inputbutton[1] = 0
        EndIf
        End Function}
                    
DeadInternal_ret        ret

Win
                        call #DeadInternal
                        rdlong r0, canvas_adr
                        add r0, #162
                        mov r1, #66
                        wrbyte r1, r0
                        add r0, #1
                        mov r1, #52
                        wrbyte r1, r0
                        add r0, #1
                        mov r1, #57
                        wrbyte r1, r0
                        add r0, #1
                        mov r1, #43
                        wrbyte r1, r0
        {Function Win(param1)
        Dead(param1)
        
        tilemap[canvas[param1] + 2 + 5 Shl 5] = 66
        tilemap[canvas[param1] + 3 + 5 Shl 5] = 52
        tilemap[canvas[param1] + 4 + 5 Shl 5] = 57
        tilemap[canvas[param1] + 5 + 5 Shl 5] = 43
        End Function}
                     
Win_ret                 jmp   #__loader_return

GAMEPROCESS3_END
fit 440

                        org 100
GAMEPROCESS4_START

                        rdbyte r0, pstate_adr
                        cmp r0, #1 wz
        if_e            jmp #CheckGroup

                        jmp   #__loader_return

CheckGroup
                        mov clear, #0
                        mov r5, #0              ' r5 = c
:cg_loopc
                        mov r4, #0              ' r4 = j shl 5
:cg_loopj
                        mov groupcount, #0
                        mov r3, #0              ' r3 = i
:cg_loopi
                                                
        {Function CheckGroup(param1)
        ' Check horizontal group of 4 of same color
        Local groupcount
        Local clear = 0
        
        For Local c=0 Until 3
                For Local j=0 Until 16
                        groupcount = 0
                        For Local i=0 Until 8}

                        rdlong r0, canvas_adr
                        add r0, r3
                        add r0, r4
                        rdbyte r7, r0
                        sub r7, r5

                        call #CheckColor
                        cmp r7, #0 wz
        if_e            mov groupcount, #0
        if_e            jmp #:cg_loop1i_continue

{                                Local t = tilemap[canvas[param1] + i + j Shl 5]
                                
                                t = t - c
                                If(CheckColor(t) = 0)
                                        groupcount = 0
                                        Continue
                                End If}

                        add groupcount, #1
                        cmp groupcount, #4 wc, wz
        if_b            jmp #:cg_loop1i_continue

                        mov clear, #1
                        mov r2, #0
:cg_loopi2
                        mov r6, r4
                        add r6, r3
                        sub r6, r2
                        mov r7, r5
                        call #ClearTile

                        add r2, #1
                        cmp r2, #4 wz
        if_ne           jmp #:cg_loopi2

                                {groupcount :+ 1
                                If(groupcount >= 4)
                                        clear = 1
                                        For Local i2=0 Until 4
                                                ClearTile(param1, i - i2 + j Shl 5, c)
                                        Next
                                EndIf}

:cg_loop1i_continue
                        cmp r3, #7 wz
        if_ne           add r3, #1
        if_ne           jmp #:cg_loopi

                        cmp r4, #480 wz
        if_ne           add r4, #32
        if_ne           jmp #:cg_loopj

                {        Next
                Next}

                        mov r3, #0              ' r3 = i
:cg_loop2i
                        mov groupcount, #0
                        mov r4, #0              ' r4 = j shl 5
:cg_loop2j
                
                {For Local i=0 Until 8
                        groupcount = 0
                        For Local j=0 Until 16}

                        rdlong r0, canvas_adr
                        add r0, r3
                        add r0, r4
                        rdbyte r7, r0
                        sub r7, r5

                        call #CheckColor
                        cmp r7, #0 wz
        if_e            mov groupcount, #0
        if_e            jmp #:cg_loop2j_continue
                        
                                {Local t = tilemap[canvas[param1] + i + j Shl 5]
                                
                                t = t - c
                                If(CheckColor(t) = 0)
                                        groupcount = 0
                                        Continue
                                End If}

                        add groupcount, #1
                        cmp groupcount, #4 wc, wz
        if_b            jmp #:cg_loop2j_continue

                        mov clear, #1
                        mov r2, #0
:cg_loopi22
                        mov r6, r4
                        add r6, r3
                        sub r6, r2
                        mov r7, r5
                        call #ClearTile

                        add r2, #32
                        cmp r2, #128 wz
        if_ne           jmp #:cg_loopi22

                                {groupcount :+ 1
                                If(groupcount >= 4)
                                        clear = 1
                                        For Local i2=0 Until 4
                                                ClearTile(param1, i + (j - i2) Shl 5, c)
                                        Next
                                EndIf}
:cg_loop2j_continue
                        cmp r4, #480 wz
        if_ne           add r4, #32
        if_ne           jmp #:cg_loop2j

                        cmp r3, #7 wz
        if_ne           add r3, #1
        if_ne           jmp #:cg_loop2i

                {        Next
                Next}

                        cmp r5, #2 wz
        if_ne           add r5, #1
        if_ne           jmp #:cg_loopc
                
        {Next}

                        ' temp stuff
                        cmp clear, #0 wz
        if_ne           jmp #:cg_clearnot0
                        rdbyte r0, combo_adr
                        cmp r0, #1 wz, wc
        if_be           jmp #:cg_combo_not

                        rdbyte r0, enemy_attack_adr
                        rdbyte r1, combo_adr
                        add r0, r1
                        wrbyte r0, enemy_attack_adr 
                        ' attack[1-param1] :+ combo[param1]
                        jmp #:cg_combo_not
:cg_combo_not
                        wrbyte zero, combo_adr

                        rdbyte r0, attack_adr wz
        if_z            jmp #:cg_attack_0
                        mov r0, #4
                        wrbyte r0, pstate_adr
                        jmp #CheckGroup_ret
:cg_attack_0
                        call #GetNextBlock2
                        call #BlockCollision2
                        cmp r7, #0 wz
        if_z            wrbyte zero, pstate_adr
        if_z            jmp #CheckGroup_ret

                        mov r0, #5
                        wrbyte r0, pstate_adr

                        mov r0, #6
                        wrbyte r0, enemy_pstate_adr
                        ' TODO pstate[1-param1] = 6
                        
                        mov r0, #30
                        wrbyte r0, downaccum_adr
                        wrbyte r0, enemy_downaccum_adr
                        ' TODO downaccum[1-param1] = 30

                        jmp #CheckGroup_ret
                                                         
        {If(clear = 0)
                If(combo[param1] > 1)
                        attack[1-param1] :+ combo[param1]
                EndIf
                combo[param1] = 0
                
                If(attack[param1])
                        pstate[param1] = 4
                Else
                        GetNextBlock(param1)
                        If(BlockCollision(param1))
                                pstate[param1] = 5
                                pstate[1-param1] = 6
                                downaccum[param1] = 30
                                downaccum[1-param1] = 30
                        Else
                                pstate[param1] = 0
                        EndIf
                EndIf}
:cg_clearnot0
                        mov r0, #2
                        wrbyte r0, pstate_adr
                        mov r0, #12
                        wrbyte r0, downaccum_adr                
        {Else
                pstate[param1] = 2
                downaccum[param1] = 12
        EndIf
        End Function}
              
CheckGroup_ret          jmp   #__loader_return

' param1:pindex,  param2:r6,  param3:r7
' destory r0, r6
ClearTile
                        rdlong r0, canvas_adr
                        add r0, r6
                        rdbyte r6, r0
                        sub r6, r7
                        cmp r6, #152 wz
        if_e            jmp #:ct_equal152
                        cmp r6, #168 wz
        if_ne           jmp #:ct_notequal
:ct_equal152
                        rdbyte r6, virus_adr
                        sub r6, #1
                        wrbyte r6, virus_adr
                        add score, #1
                        add doctor, #4                        
:ct_notequal
                        mov r6, r7
                        add r6, #224
                        wrbyte r6, r0        
        {Function ClearTile(param1, param2, param3)
        Local t = tilemap[canvas[param1] + param2] - param3
        If(t = 152 Or t = 168)
                virus[param1] :- 1
                score :+ 1
                doctor :+ 4
        EndIf
        tilemap[canvas[param1] + param2] = 224 + param3
        End Function}
ClearTile_ret           ret

' param in r7, return value in r7
CheckColor
                        cmp r7, #152 wz
        if_e            jmp #:cc_return1
                        cmp r7, #168 wz
        if_e            jmp #:cc_return1
                        cmp r7, #156 wz
        if_e            jmp #:cc_return1
                        cmp r7, #172 wz
        if_e            jmp #:cc_return1
                        cmp r7, #184 wz
        if_e            jmp #:cc_return1
                        cmp r7, #187 wz
        if_e            jmp #:cc_return1
                        cmp r7, #109 wz
        if_e            jmp #:cc_return1
                        cmp r7, #224 wz
        if_e            jmp #:cc_return1
                        mov r7, #0
                        jmp #CheckColor_ret
        {Function CheckColor:Int(t)
        If(t = 152 Or t = 168 Or t = 156 Or t = 172 Or t = 184 Or t = 187 Or t = 109 Or t = 224)
                Return 1
        Else
                Return 0
        End If
        End Function}
:cc_return1             mov r7, #1        
CheckColor_ret          ret

' These functions are copied in this code page for easier access
GetNextBlock2
                        rdbyte r0, next1_adr
                        wrbyte r0, current1_adr
                        rdbyte r0, next2_adr
                        wrbyte r0, current2_adr

                        call #GetBrick
                        wrbyte r7, next1_adr
                        call #GetBrick
                        wrbyte r7, next2_adr

                        mov r0, #3
                        wrbyte r0, posx_adr
                        wrbyte zero, posy_adr
                        mov r0, #1
                        wrbyte r0, orient_adr
                        wrbyte zero, downaccum_adr
                        wrbyte zero, combo_adr
                        wrlong zero, aistate_adr
GetNextBlock2_ret        ret

' return value in r7
BlockCollision2
                        mov r7, #1
                        call #CalculateCanvasPos2
                        rdbyte r1, r0
                        cmp r1, #32 wz
        if_ne           jmp #BlockCollision2_ret

                        rdbyte r1, orient_adr
                        add r0, r1
                        rdbyte r1, r0
                        cmp r1, #32 wz
        if_ne           jmp #BlockCollision2_ret

                        mov r7, #0
BlockCollision2_ret      ret

' return 'canvas[param1] + posx[param1] + posy[param1] Shl 5' in r0
' uses r1 as temp
CalculateCanvasPos2
                        rdbyte r0, posy_adr
                        shl r0, #5
                        rdbyte r1, posx_adr
                        add r0, r1
                        rdlong r1, canvas_adr
                        add r0, r1
CalculateCanvasPos2_ret  ret

' Temporary variable (trashed by loader kernel)
groupcount              long    $0
clear                   long    $0

GAMEPROCESS4_END
fit 440

                        org 100
GAMEPROCESS5_START

                        rdbyte r0, pstate_adr
                        cmp r0, #2 wz
        if_e            jmp #AnimatePop
                        cmp r0, #3 wz
        if_e            jmp #Gravity
                        cmp r0, #4 wz
        if_e            jmp #ReceiveAttack

                        jmp   #__loader_return

AnimatePop
                        rdbyte r0, downaccum_adr
                        sub r0, #1
                        wrbyte r0, downaccum_adr
                        cmp r0, #11 wz
        if_ne           jmp #:ap_down_not11

                        mov r3, #0              ' r3 = j shl 5
:ap_loopj
                        mov r4, #0              ' r4 = i
:ap_loopi
                        rdlong r0, canvas_adr
                        add r0, r3
                        add r0, r4
                        rdbyte r1, r0
                        cmp r1, #224 wc, wz
        if_ae           mov r1, #155
                        wrbyte r1, r0

                        add r4, #1
                        cmp r4, #8 wz
        if_ne           jmp #:ap_loopi

                        cmp r3, #480 wz
        if_ne           add r3, #32
        if_ne           jmp #:ap_loopj
        
        {Function AnimatePop(param1)
        downaccum[param1] :- 1
        
        If(downaccum[param1] = 11)
                For Local j=0 Until 16
                        For Local i=0 Until 8
                                Local t = tilemap[canvas[param1] + i + j Shl 5]
                                If(t >= 224) Then t = 155
                                tilemap[canvas[param1] + i + j Shl 5] = t
                        Next
                Next
        EndIf}

:ap_down_not11
                        rdbyte r0, downaccum_adr
                        cmp r0, #10 wz
        if_ne           jmp #:ap_down_not10

                        mov r2, #0              ' r2 = c
:ap_loop2c
                        mov r3, #0              ' r3 = j shl 5
:ap_loop2j
                        mov r4, #0              ' r4 = i
:ap_loop2i
                        rdlong r0, canvas_adr
                        add r0, r3
                        add r0, r4
                        rdbyte r1, r0
                        sub r1, r2
                        
                        mov r6, #1
                        
                        cmp r1, #184 wz
        if_e            mov r7, #187
        if_e            jmp #:ap_loop2_skip
                        cmp r1, #187 wz
        if_e            neg r6, r6
        if_e            mov r7, #184
        if_e            jmp #:ap_loop2_skip

                        mov r6, #32
                        cmp r1, #156 wz
        if_e            mov r7, #172
        if_e            jmp #:ap_loop2_skip
                        cmp r1, #172 wz
        if_e            neg r6, r6
        if_e            mov r7, #156
        if_e            jmp #:ap_loop2_skip
        
                        jmp #:ap_loop_continue2
                                
        {' Check for bone section to 'break' in half
        Local offset, half
        If(downaccum[param1] = 10)
                For Local c=0 Until 3
                        For Local j=0 Until 16
                                For Local i=0 Until 8
                                        Local t = tilemap[canvas[param1] + i + j Shl 5]
                                        
                                        t = t - c
                                        If(t = 184)
                                                offset = 1
                                                half = 187
                                        Else If(t = 187)
                                                offset = -1
                                                half = 184
                                        Else If(t = 156)
                                                offset = 32
                                                half = 172
                                        Else If(t = 172)
                                                offset = -32
                                                half = 156
                                        Else
                                                Continue
                                        EndIf}
:ap_loop2_skip
                        add r6, r0
                        rdbyte r1, r6
                        cmp r1, r7 wc, wz
        if_b            jmp #:ap_ok

                        add r7, #2
                        cmp r1, r7 wc, wz
        if_be           jmp #:ap_loop_continue2

:ap_ok
                        mov r1, #109
                        add r1, r2
                        wrbyte r1, r0            
                                        {Local t2 = tilemap[canvas[param1] + offset + i + j Shl 5]
                                        
                                        If(t2 < half Or t2 > half+2)
                                                tilemap[canvas[param1] + i + j Shl 5] = 109+c
                                        EndIf}
:ap_loop_continue2                                        
                        add r4, #1
                        cmp r4, #8 wz
        if_ne           jmp #:ap_loop2i

                        cmp r3, #480 wz
        if_ne           add r3, #32
        if_ne           jmp #:ap_loop2j
        
                        add r2, #1
                        cmp r2, #3 wz
        if_ne           jmp #:ap_loop2c

                                {Next
                        Next
                Next
        EndIf}

:ap_down_not10
                        rdbyte r0, downaccum_adr
                        cmp r0, #5 wz
        if_ne           jmp #:ap_down_not5

                        mov r6, #155
                        mov r7, #171
                        call #SetTiles

                        rdbyte r0, virus_adr wz
        if_nz           jmp #AnimatePop_ret

                        mov r0, #6
                        wrbyte r0, pstate_adr

                        mov r0, #5
                        wrbyte r0, enemy_pstate_adr
                        ' TODO pstate[1-param1] = 5
                        mov r0, #30
                        wrbyte r0, downaccum_adr
                        wrbyte r0, enemy_downaccum_adr
                        ' TODO downaccum[1-param1] = 30
                        jmp #AnimatePop_ret
                                
        {If(downaccum[param1] = 5)
                SetTiles(param1, 155, 171)
                
                ' Win: player has cleared all fossils :)
                If(virus[param1] = 0)
                        pstate[param1] = 6
                        pstate[1-param1] = 5
                        downaccum[param1] = 30
                        downaccum[1-param1] = 30
                        Return
                EndIf
        EndIf}

:ap_down_not5
                        rdbyte r0, downaccum_adr wz
        if_nz           jmp #AnimatePop_ret

                        mov r6, #171
                        mov r7, #32
                        call #SetTiles

                        mov r0, #3
                        wrbyte r0, pstate_adr
                        rdbyte r0, combo_adr
                        add r0, #1
                        wrbyte r0, combo_adr        
        
        {If(downaccum[param1] = 0)
                SetTiles(param1, 171, 32)
                
                pstate[param1] = 3
                combo[param1] :+ 1
        EndIf
        End Function}              
AnimatePop_ret          jmp   #__loader_return

Gravity                 
                        rdbyte r0, downaccum_adr
                        cmp r0, #0 wc, wz
        if_a            sub r0, #1
        if_a            wrbyte r0, downaccum_adr
        if_a            jmp #Gravity_ret
        
        {Function Gravity(param1)
        If(downaccum[param1] > 0)
                downaccum[param1] :- 1
                Return
        EndIf}
                        mov r6, #0              ' r6 = keepfalling

                        mov r3, #448            ' r3 = j shl 5
:gr_loopj
                        mov r4, #0              ' r4 = i
:gr_loopi
                        rdlong r0, canvas_adr
                        add r0, r3
                        add r0, r4
                        rdbyte r1, r0

                        add r0, #32
                        rdbyte r2, r0
                        cmp r2, #32 wz
        if_ne           jmp #:gr_continue

                        cmp r1, #32 wz
        if_e            jmp #:gr_continue
                        cmp r1, #152 wz
        if_e            jmp #:gr_continue
                        cmp r1, #153 wz
        if_e            jmp #:gr_continue
                        cmp r1, #154 wz
        if_e            jmp #:gr_continue
                        cmp r1, #168 wz
        if_e            jmp #:gr_continue
                        cmp r1, #169 wz
        if_e            jmp #:gr_continue
                        cmp r1, #170 wz
        if_e            jmp #:gr_continue
                        cmp r1, #187 wz
        if_e            jmp #:gr_continue
                        cmp r1, #188 wz
        if_e            jmp #:gr_continue
                        cmp r1, #189 wz
        if_e            jmp #:gr_continue
        {Local keepfalling = 0
        
        For Local j=14 To 0 Step -1
                For Local i=0 Until 8
                        Local t = tilemap[canvas[param1] + i + j Shl 5]
                        Local t2 = tilemap[canvas[param1] + 32 + i + j Shl 5]
                        If(t2 <> 32) Then Continue
                        If(t = 32 Or t = 152 Or t = 153 Or t = 154 Or t = 168 Or t = 169 Or t = 170) Then Continue
                        If(t = 187 Or t = 188 Or t = 189) Then Continue}

                        cmp r1, #184 wz, wc
        if_b            jmp #:gr_skip
                        cmp r1, #186 wz, wc
        if_a            jmp #:gr_skip

                        add r4, #1
                        add r0, #1
                        rdbyte r2, r0
                        cmp r2, #32 wz
        if_ne           jmp #:gr_continue

                        sub r0, #1
                        wrbyte r1, r0
                        sub r0, #32
                        mov r1, #32
                        wrbyte r1, r0
                        add r0, #1
                        rdbyte r1, r0
                        add r0, #32
                        
                        {' Check for linked section: this special case need two empty space
                        ' to fall down
                        If(t >= 184 And t <= 186)
                                i :+ 1
                                t2 = tilemap[canvas[param1] + 32 + i + j Shl 5]
                                If(t2 <> 32)
                                        Continue
                                EndIf
                                
                                tilemap[canvas[param1] + 32 - 1 + i + j Shl 5] = t
                                tilemap[canvas[param1] - 1 + i + j Shl 5] = 32
                                t = tilemap[canvas[param1] + i + j Shl 5]
                        EndIf}

:gr_skip
                        wrbyte r1, r0
                        sub r0, #32
                        mov r1, #32
                        wrbyte r1, r0

                        mov r6, #1        
                        {tilemap[canvas[param1] + 32 + i + j Shl 5] = t
                        tilemap[canvas[param1] + i + j Shl 5] = 32
                        keepfalling = 1}

:gr_continue
                        add r4, #1
                        cmp r4, #8 wz,wc
        if_b            jmp #:gr_loopi

                        cmp r3, #0 wz
        if_ne           sub r3, #32
        if_ne           jmp #:gr_loopj

        {        Next
        Next}
                        cmp r6, #0 wz
        if_e            mov r1, #1
        if_e            wrbyte r1, pstate_adr
        if_e            jmp #Gravity_ret

                        mov r1, #10
                        wrbyte r1, downaccum_adr
        {If(keepfalling = 0)
                pstate[param1] = 1
                Return
        EndIf
        
        downaccum[param1] = 10
        End Function}
Gravity_ret             jmp   #__loader_return

ReceiveAttack
                        rdbyte r6, attack_adr
                        
                        mov r5, #0
:ra_loop
                        cmp r5, #80 wz, wc
        if_a            jmp #:ra_exitloop
                        add r5, #1

                        mov r7, #7
                        call #GetRandom
                        mov r4, r7

                        rdlong r0, canvas_adr
                        add r0, r4
                        rdbyte r1, r0
                        cmp r1, #32 wz
        if_ne           jmp #:ra_loop

                        call #GetBrick
                        add r7, #109
                        wrbyte r7, r0

:ra_continue
                        add r5, #1
                        cmp r5, r6 wc, wz
        if_be           jmp #:ra_loop

:ra_exitloop
                        wrbyte zero, attack_adr
                        mov r0, #3
                        wrbyte r0, pstate_adr
                
        {Function ReceiveAttack(param1)
        Local att = attack[param1]
        
        ' Spawn a number of random blocks on the top row and let them fall
        Local infinite_loop = 0
        For Local i = 0 Until att
                Repeat
                        If(infinite_loop > 80) Then Exit
                        infinite_loop :+ 1
                        
                        Local x = GetRandom(param1, 7)
                        Local t = tilemap[canvas[param1] + x]
                        If(t <> 32) Then Continue
                        t = GetBrick(param1)
                        tilemap[canvas[param1] + x] = 109 + t
                        Exit
                Forever
        Next
        
        attack[param1] = 0
        pstate[param1] = 3
        End Function}

ReceiveAttack_ret       jmp   #__loader_return

'param1=pindex, param2=r6, param3=r7
SetTiles
                        mov r3, #0              ' r3 = j shl 5
:st_loopj
                        mov r4, #0              ' r4 = i
:st_loopi
                        rdlong r0, canvas_adr
                        add r0, r3
                        add r0, r4
                        rdbyte r1, r0
                        cmp r1, r6 wz
        if_e            mov r1, r7
                        wrbyte r1, r0

                        add r4, #1
                        cmp r4, #8 wz
        if_ne           jmp #:st_loopi

                        cmp r3, #480 wz
        if_ne           add r3, #32
        if_ne           jmp #:st_loopj

        {Function SetTiles(param1, param2, param3)
        For Local j=0 Until 16
                For Local i=0 Until 8
                        Local t = tilemap[canvas[param1] + i + j Shl 5]
                        If(t = param2)
                                t = param3
                        End If
                        tilemap[canvas[param1] + i + j Shl 5] = t
                Next
        Next    
        End Function}
SetTiles_ret            ret

GAMEPROCESS5_END
fit 440

                        org 100
GAMEPROCESS6_START
                        cmp state, #3 wz
        if_e            call #Game1PStart
                        cmp state, #8 wz
        if_e            call #Game2PStart
        
         'If(state = 3) Then Game1PStart()
        'If(state = 8) Then Game2PStart()
                        jmp   #__loader_return

Game1PStart
                        mov tileoffset, #24
                        shl tileoffset, #5
                        call #update_tileoffset2
                        mov state, #0
                        mov nextstate, #4

                        wrlong framecount, random_adr

                        mov r1, #204
                        add r1, tilearray_adr
                        wrlong r1, canvas_adr

                        call #InitializeCanvas
                        
        {Function Game1PStart()
        tileoffset = 24*32
        state = 0
        nextstate = 4
        
        canvas[0] = 972
        
        InitializeCanvas(0)

        Game1PLoop()
        End Function}
Game1PStart_ret         ret

Game2PStart
                        mov tileoffset, #48
                        shl tileoffset, #5
                        call #update_tileoffset2
                        mov state, #0
                        mov nextstate, #9

                        wrlong framecount, random_adr
                        mov r1, #196
                        add r1, tilearray_adr
                        wrlong r1, canvas_adr
                        call #InitializeCanvas

                        mov r7, #1
                        call #offset_player_array
                        
                        wrlong framecount, random_adr
                        mov r1, #212
                        add r1, tilearray_adr
                        wrlong r1, canvas_adr
                        call #InitializeCanvas

                        mov r7, #1
                        neg r7, r7
                        call #offset_player_array

        {Function Game2PStart()
        tileoffset = 48*32
        state = 0
        nextstate = 9
        
        canvas[0] = 1732
        canvas[1] = 1748
        
        random[0] = framecount
        random[1] = random[0]
        
        For Local p=0 Until 2
                InitializeCanvas(p)
        Next
        
        Game2PLoop()
        
        End Function}
Game2PStart_ret         ret

offset_player_array
                        add pindex, r7
                        shl r7, #2
                        add canvas_adr, r7
                        add random_adr, r7
                        add level_adr, r7
                        add virus_adr, r7
                        add speed_adr, r7
                        add inputdir_adr, r7
                        add inputbutton_adr, r7
                        add next1_adr, r7
                        add next2_adr, r7
                        add current1_adr, r7
                        add current2_adr, r7
                        add posx_adr, r7
                        add posy_adr, r7
                        add downaccum_adr, r7
                        add orient_adr, r7
                        add pstate_adr, r7
                        add combo_adr, r7
                        add attack_adr, r7
                        add aistate_adr, r7
offset_player_array_ret ret

' param1: pindex
InitializeCanvas
                        rdlong r0, canvas_adr

                        mov r2, #32
                        
                        mov r6, #16
:ic_loopj                        
                        mov r5, #8
:ic_loopi                        
                        mov r1, r6
                        shl r1, #5
                        add r1, r5
                        sub r1, #33
                        add r1, r0
                        wrbyte r2, r1
                        djnz r5, #:ic_loopi                         
                        djnz r6, #:ic_loopj                         

        {Function InitializeCanvas(param1)
        For Local j=0 Until 16
                For Local i=0 Until 8
                        tilemap[canvas[param1] + i + j Shl 5] = 32
                Next
        Next}

                        rdbyte r0, level_adr
                        shl r0, #2
                        add r0, #4
                        wrbyte r0, virus_adr
        {virus[param1] = (level[param1] Shl 2) + 4}

                        mov r2, #152
                        
                        rdbyte r6, virus_adr
:ic_loopvirus
                        rdlong r3, canvas_adr
                        
                        mov r7, #7
                        call #GetRandom
                        add r3, r7                        

                        mov r7, #7
                        call #GetRandom
                        mov r4, r7                        
                        mov r7, #3
                        call #GetRandom
                        add r4, r7
                        add r4, #5
                        shl r4, #5
                        add r3, r4

                        rdbyte r0, r3
                        cmp r0, #32 wz
        if_ne           jmp #:ic_loopvirus
                        wrbyte r2, r3
                        add r2, #1
                        cmp r2, #155 wz
        if_e            mov r2, #152
                        jmp #:ic_loopvirus_exit

                        jmp #:ic_loopvirus
:ic_loopvirus_exit
                        djnz r6, #:ic_loopvirus
                        
        {Local v = 152
        
        For Local i=0 Until virus[param1]
                Repeat 
                        Local x = GetRandom(param1, 7)
                        Local y = GetRandom(param1, 7)+GetRandom(param1, 3) + 5
                        Local t = canvas[param1] + x + y Shl 5
                        If (tilemap[t] = 32) Then
                                tilemap[t] = v
                                v :+ 1
                                If v = 155 Then v = 152
                                Exit
                        EndIf
                Forever
        Next}

                        wrlong framecount, random_adr
        {random[param1] = framecount}

                        call #GetNextBlock                        
                        call #GetNextBlock

                        wrbyte zero, pstate_adr
                        wrbyte zero, attack_adr
                                
        {GetNextBlock(param1)
        GetNextBlock(param1)
        
        pstate[param1] = 0
        attack[param1] = 0
        End Function}
InitializeCanvas_ret    ret

GetNextBlock
                        rdbyte r0, next1_adr
                        wrbyte r0, current1_adr
                        rdbyte r0, next2_adr
                        wrbyte r0, current2_adr

                        call #GetBrick
                        wrbyte r7, next1_adr
                        call #GetBrick
                        wrbyte r7, next2_adr

                        mov r0, #3
                        wrbyte r0, posx_adr
                        wrbyte zero, posy_adr
                        mov r0, #1
                        wrbyte r0, orient_adr
                        wrbyte zero, downaccum_adr
                        wrbyte zero, combo_adr
                        wrlong zero, aistate_adr
        {Function GetNextBlock(param1)
        current1[param1] = next1[param1]
        current2[param1] = next2[param1]
        
        next1[param1] = GetBrick(param1)
        next2[param1] = GetBrick(param1)
        
        posx[param1] = 3
        posy[param1] = 0
        orient[param1] = 1
        downaccum[param1] = 0
        combo[param1] = 0
        aistate[param1] = 0
        End Function}
GetNextBlock_ret        ret

update_tileoffset2
                        rdlong tilearray_adr, tilemap_adr
                        add tilearray_adr, #64  ' skip top and bottom tilemap row
                        add tilearray_adr, tileoffset                     ' skip to current screen
                        
                        mov tilearray256_adr, tilearray_adr
                        add tilearray256_adr, #256      ' tilearray256_adr point to 256 after tilearray_adr to help with
                                                        ' 9-bit immediate

                        mov r0, tileoffset
                        shr r0, #2
                        wrlong r0, vertical_scroll

update_tileoffset2_ret   ret

GAMEPROCESS6_END
fit 440


' AI code goes here
                        org 100
GAMEPROCESS7_START
                        wrbyte zero, inputdir_adr
                        wrbyte zero, inputbutton_adr
        {Function AIControl(param1)
        inputdir[param1] = 0
        inputbutton[param1] = 0}

                        test framecount, #7 wz
        if_ne           jmp   #__loader_return        
        'If(framecount & 7 <> 0) Then Return

                        mov r5, #0              ' r5 = i
:ai_loopi
                        mov r0, #3
                        mov r1, aitoprow_adr
                        add r1, r5
                        wrbyte r0, r1
                                                       
        {Local toprow[8]
        For Local i=0 Until 8
                toprow[i] = 3}
                        mov r4, #32              ' r4 = j shl 5
:ai_loopj                        
                        rdlong r0, canvas_adr
                        add r0, r4
                        add r0, r5
                        rdbyte r0, r0
                        cmp r0, #32 wz
        if_e            jmp #:ai_continue
                {For Local j=1 Until 16
                        Local t = tilemap[canvas[param1] + i + j Shl 5]
                        If(t = 32) Then Continue}

                        mov r3, #0              ' r3 = c
:ai_loopc
                        mov r7, r0
                        sub r7, r3
                        call #CheckColor2
                        cmp r7, #1 wz
        if_ne           jmp #:ai_nextc

                        rdbyte r0, posy_adr
                        add r0, #1
                        shl r0, #5
                        cmp r0, r4 wc, wz
        if_a            mov r1, #4

                        wrbyte r3, r1
                        jmp #:ai_exitj
:ai_nextc
                        add r3, #1
                        cmp r3, #3 wz
        if_ne           jmp #:ai_loopc                                
                        {For Local c=0 Until 3
                                If(CheckColor(t-c) = 1)
                                        If(posy[param1]+1 > j) Then c = 4
                                        toprow[i] = c
                                        j = 16
                                        Exit
                                EndIf
                        Next}
:ai_continue
                        cmp r4, #480 wz
        if_ne           add r4, #32
        if_ne           jmp #:ai_loopj

:ai_exitj
                        add r5, #1
                        cmp r5, #8 wz
        if_ne           jmp #:ai_loopi                        
                {Next
        Next}

                        mov desiredx, #255
        {Local desiredx = 255}
        
                        rdlong r5, aistate_adr
                        rdlong r4, orient_adr
                        cmp r5, number1000 wc, wz
        if_ae           mov desiredx, r5
        if_ae           sub desiredx, number1000
        if_ae           jmp #:ai_skipbig_if
                        
        ' When aistate is set to +1000, it means we already know our desired place
        {If(aistate[param1] >= 1000)
                desiredx = aistate[param1] - 1000}

                        mov backward, #0
                        test framecount, #32 wz
        if_z            mov backward, #1

                        cmp r5, #0 wz
        if_ne           jmp #:ai_skipstate0

                        cmp r4, #32 wz
        if_e            jmp #:ai_skiporient32
                        rdbyte r0, inputbutton_adr
                        or r0, #NES_A
                        wrbyte r0, inputbutton_adr
                        jmp #__loader_return
        {Else
                Local backward = 0
                If(framecount & 32 = 0) Then backward = 1
                
                If(aistate[param1] = 0)
                        If(orient[param1] != 32)
                                inputbutton[param1] :| NES_A
                                Return
                        EndIf}

:ai_skiporient32
                        mov r2, #0              ' r2 = i2
:ai_vf_loopi
                        mov r3, r2              ' r3 = i
                        cmp backward, #0 wc ,wz
        if_ne           mov r3, #7
        if_ne           sub r3, r2

                        mov r1, aitoprow_adr
                        add r1, r3
                        rdbyte r1, r1
                        rdbyte r0, current1_adr
                        cmp r0, r1 wc, wz
        if_ne           jmp #:ai_vertfit_continue
        
                        rdbyte r0, current2_adr
                        cmp r0, r1 wc, wz
        if_ne           jmp #:ai_vertfit_continue

                        mov desiredx, r3
                        mov r0, desiredx
                        add r0, number1000
                        wrlong r0, aistate_adr
                        jmp #:ai_skipbig_if
                                                                                                     
                        {' Try all vertical position for this vertical block
                        ' to look for a perfect fit
                        For Local i2=0 Until 8
                                Local i = i2
                                If(backward) Then i = 7-i2
                                If(current1[param1] <> toprow[i]) Then Continue
                                If(current2[param1] <> toprow[i]) Then Continue
                                ' Perfect fit found at 'i'!
                                
                                desiredx = i
                                aistate[param1] = desiredx + 1000
                                Print "Perfect vertical fit at "+desiredx
                                Exit
                        Next}
:ai_vertfit_continue
                        add r2, #1
                        cmp r2, #8 wz
        if_ne           jmp #:ai_vf_loopi

:ai_skipstate0
                        cmp r5, #4 wc, wz
        if_ae           jmp #:ai_skipstate4

                        cmp r4, #1 wz
        if_ne           jmp #:ai_skipbig_if

                {Else If aistate[param1] < 4
                        If(orient[param1] = 1)}

                        mov r2, #0              ' r2 = i2
:ai_hf_loopi
                        mov r3, r2              ' r3 = i
                        cmp backward, #0 wc ,wz
        if_ne           mov r3, #6
        if_ne           sub r3, r2

                        mov r1, aitoprow_adr
                        add r1, r3
                        rdbyte r1, r1
                        rdbyte r0, current1_adr
                        cmp r0, r1 wc, wz
        if_ne           jmp #:ai_horfit_continue
        
                        mov r1, aitoprow_adr
                        add r1, r3
                        add r1, #1
                        rdbyte r1, r1
                        rdbyte r0, current2_adr
                        cmp r0, r1 wc, wz
        if_ne           jmp #:ai_horfit_continue

                        mov desiredx, r3
                        mov r0, desiredx
                        add r0, number1000
                        wrlong r0, aistate_adr
                        jmp #:ai_skipbig_if
                                                                                                     
:ai_horfit_continue
                        add r2, #1
                        cmp r2, #7 wz
        if_ne           jmp #:ai_hf_loopi
                                       
                                {' Try all horizontal position for this horizontal block
                                ' to look for a perfect fit
                                For Local i2=0 Until 7
                                        Local i = i2
                                        If(backward) Then i = 6-i2
                                        
                                        If(current1[param1] <> toprow[i]) Then Continue
                                        If(current2[param1] <> toprow[i+1]) Then Continue
                                        ' Perfect fit found at 'i'!
                                        
                                        desiredx = i
                                        aistate[param1] = desiredx + 1000
                                        Print "Perfect horizontal fit at "+desiredx
                                        Exit
                                Next
                        EndIf}

:ai_skipstate4
                        cmp r5, #7 wc, wz
        if_ae           jmp #:ai_skipstate10

                        cmp r4, #1 wz
        if_ne           jmp #:ai_skipbig_if

                {Else If aistate[param1] < 7
                        If(orient[param1] = 1)}

                        mov r2, #0              ' r2 = i
:ai_hf_loopi2
                        mov r1, aitoprow_adr
                        add r1, r2
                        rdbyte r1, r1
                        rdbyte r0, current1_adr
                        cmp r0, r1 wc, wz
        if_ne           jmp #:ai_horfit_continue2
        
                        mov r1, aitoprow_adr
                        add r1, r2
                        add r1, #1
                        rdbyte r1, r1
                        cmp r1, #3 wc, wz
        if_ne           jmp #:ai_horfit_continue2

                        mov desiredx, r2
                        jmp #:ai_skipbig_if
                                                                                                     
:ai_horfit_continue2
                        add r2, #1
                        cmp r2, #7 wz
        if_ne           jmp #:ai_hf_loopi2
                
                        {        For Local i=0 Until 7
                                        If(current1[param1] <> toprow[i]) Then Continue
                                        If(toprow[i+1] <> 3) Then Continue
                                        ' Good fit found at 'i'!
                                        
                                        desiredx = i
                                        Print "Good horizontal fit at "+desiredx
                                        Exit
                                Next
                        EndIf
                Else}

:ai_skipstate10

                        cmp r4, #32 wc, wz
        if_ne           jmp #:ai_skipbig_if
                
                        {If(orient[param1] = 32)}

                        mov r2, #0              ' r2 = i
:ai_vf_loopi2
                        mov r1, aitoprow_adr
                        add r1, r2
                        rdbyte r1, r1

                        cmp r1, #3 wz
        if_e            mov desiredx, r2
        if_e            jmp #:ai_skipbig_if  
                        
                        rdbyte r0, current2_adr
                        cmp r0, r1 wc, wz
        if_ne           jmp #:ai_vfit_continue2
        
                        mov desiredx, r2
                        jmp #:ai_skipbig_if
                                                                                                     
:ai_vfit_continue2
                        add r2, #1
                        cmp r2, #8 wz
        if_ne           jmp #:ai_vf_loopi2

                                {' Try all vertical position for this vertical block
                                ' to look for a acceptable fit
                                For Local i=0 Until 8
                                        If(toprow[i] = 3)
                                                desiredx = i
                                                Print "Empty vertical fit at "+desiredx
                                        Else
                                                If(current2[param1] <> toprow[i]) Then Continue
                                                ' good fit found at 'i'!
                                                
                                                desiredx = i
                                                Print "Good vertical fit at "+desiredx
                                        EndIf
                                        Exit
                                Next
                        EndIf
                EndIf
        EndIf}

:ai_skipbig_if        
                        cmp desiredx, #255 wz
        if_ne           jmp #:ai_skipflip

                        mov r1, #NES_RIGHT
                        mov r0, framecount
                        and r0, #63
                        cmp r0, #32 wz, wc
        if_a            mov r1, #NES_LEFT

                        rdbyte r0, inputdir_adr
                        or r0, r1
                        wrbyte r0, inputdir_adr

                        rdlong r0, aistate_adr
                        add r0, #1
                        wrlong r0, aistate_adr
                        rdbyte r0, inputbutton_adr
                        or r0, #NES_A
                        wrbyte r0, inputbutton_adr
                        jmp #__loader_return             
                
        {' Can't find a good place, let's flip the block and try again
        If(desiredx = 255)
                If(framecount & 63 > 32)
                        inputdir[param1] :| NES_LEFT
                Else
                        inputdir[param1] :| NES_RIGHT
                EndIf

                aistate[param1] :+ 1
                inputbutton[param1] :| NES_A
                Return
        EndIf}
:ai_skipflip        
                        rdbyte r0, posx_adr
                        rdbyte r1, inputdir_adr
                        cmp r0, desiredx wc, wz
        if_b            or r1, #NES_RIGHT
        if_a            or r1, #NES_LEFT
        if_e            or r1, #NES_DOWN
                        wrbyte r1, inputdir_adr
                        
        {If(posx[param1] < desiredx) Then inputdir[param1] :| NES_RIGHT
        If(posx[param1] > desiredx) Then inputdir[param1] :| NES_LEFT
        If(posx[param1] = desiredx) Then inputdir[param1] :| NES_DOWN

        End Function}

                        jmp   #__loader_return

' param in r7, return value in r7
CheckColor2
                        cmp r7, #152 wz
        if_e            jmp #:cc_return1
                        cmp r7, #168 wz
        if_e            jmp #:cc_return1
                        cmp r7, #156 wz
        if_e            jmp #:cc_return1
                        cmp r7, #172 wz
        if_e            jmp #:cc_return1
                        cmp r7, #184 wz
        if_e            jmp #:cc_return1
                        cmp r7, #187 wz
        if_e            jmp #:cc_return1
                        cmp r7, #109 wz
        if_e            jmp #:cc_return1
                        cmp r7, #224 wz
        if_e            jmp #:cc_return1
                        mov r7, #0
                        jmp #CheckColor2_ret
        {Function CheckColor:Int(t)
        If(t = 152 Or t = 168 Or t = 156 Or t = 172 Or t = 184 Or t = 187 Or t = 109 Or t = 224)
                Return 1
        Else
                Return 0
        End If
        End Function}
:cc_return1             mov r7, #1        
CheckColor2_ret          ret

desiredx                long                    0
backward                long                    0
                        
GAMEPROCESS7_END
fit 440


' END OF GAME CODE -----------


' GLOBAL GENERAL PURPOSE REGISTERS. Don't mess with the following few lines.
' These registers are NOT destroyed when switching between code chunks.
                        org                     $1e0

r0                      long                    $0
r1                      long                    $0
r2                      long                    $0
r3                      long                    $0
r4                      long                    $0
r5                      long                    $0
r6                      long                    $0
r7                      long                    $0

' LOADER KERNEL REGISTERS. Don't mess.
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