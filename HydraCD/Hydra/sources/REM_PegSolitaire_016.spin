{*********************************
 *   Rem Lone Marble game v016   *
 *********************************

 Almost all graphic asset made by Louis-Philippe 'FoX' Guilbert
 Programmed by Remi 'Remz' Veilleux

}

CON

  _clkmode = xtal1 + pll8x  ' Set clock multiplier to 8x
  _xinfreq = 10_000_000 + 0000 ' Set to 10Mhz (and add 5000 to fix crystal imperfection of hydra prototype)
  '_stack = ($300 - 200) >> 2           'accomodate display memory and stack
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
  MEM_BUFFER = SCANLINE_BUFFER - 380
  ' game[] array, 192 bytes
  spin_gamearray = MEM_BUFFER-192
  spin_keyboardshortcut = MEM_BUFFER-196

  ' Map dimension. This much match the map size found in REM_gfx_engine_???!
  ' (Map are normally exported by Mappy and copy/pasted into 'Rem_marble_data_???' starting at line 14
  ' Reminder: the screen is 256x192, which gives 16x12 tiles.
  ' Limitation:
  ' in the default implementation of rem_gfx_engine, MAPSIZEX must be a power of 2.
  ' This greatly limit its usefulness, as you can only have 16, 32, 64,.. width for you map.
  ' This is why in my previous game, Alien Invader, I customised the gfx engine to allow a map of 20 tiles width.
  ' The required code modification is fairly easy, if you need explanation contact me.
  ' MAPSIZEY have no restriction, can be from 1 to infinity.

  ' Also, in the default implementation, if you try to vertically scroll past the top or bottom of your map,
  ' the gfx engine will display black (empty) lines.
  ' However, in Alien Invader, I also customised it to loop the map, to make it scroll indefinitely.
  MAPSIZEX = 16
  MAPSIZEY = 60

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
  NES_A_B    = %11000000


  ' Game specific constant:
  SHORTCUT_N = 1
  SHORTCUT_U = 2
  SHORTCUT_H = 3
  SHORTCUT_L = 4


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
  tv    : "rem_tv_016.spin"
  gfx   : "rem_gfx_engine_016.spin"
  data  : "rem_marble_data_016.spin"
  mouse : "mouse_iso_010.spin"
  loader : "REM_LOADER_KERNEL_016.spin" ' loader kernel (boots paged cogs)


PUB start
  DIRA[0] := 1 ' Set debug LED ready for output         
  'outa[0] := 1 ' Use this to lit the debug led

  ' Use this color to set the background overscan color. Typically black ($02)
  colors[0] := $02

  ' Rem GFX engine setup variables:
  long[spin_tilemap_adr] := data.tilemap                ' Tilemap address
  long[spin_tiles_adr] := data.tiles                    ' Tiles address

  long[spin_top_y] := 0                                 ' How many 'top lines' (non-scrolling)
  long[spin_bottom_y] := 192                            ' Where 'bottom lines' (non-scrolling) starts
  long[spin_stop_y] := 192                              ' Specify a scanline where we stop processing image

  long[spin_vertical_scroll] := 0                       ' Map vertical scrolling
  long[spin_horizontal_scroll] := 0                     ' Map horizontal scrolling

  ' Startup sprite definition.
  ' You don't have to specify sprites here, since they could be defined at runtime in the
  ' assembly code.
  ' Here's how sprite are organised:
  ' Sprite 0 is drawn first, so it will be shown as the farthest
  ' Sprite 15 is drawn last, so it always show on top of everything
  ' Remember that sprites are stored BACKWARD in memory, so sprite 0 definition starts at (spin_sprite_x-0*20),
  ' sprite 1 is at (spin_sprite_x-1*20), ...

  ' X and Y position are stored in 7-bit fixed-point format, using variables spin_sprite_x and spin_sprite_y.
  ' i.e.: If you want to display a sprite at pixel 50,100 on screen,
  '       you'll need to set x and y to CONSTANT(50<<7), CONSTANT(100<<7)
  ' Sprite size is stored in spin_sprite_s. Horizontal width is shifted by 8 bit and is stored as a shift value,
  ' then vertical height is added to it unshifted.
  ' i.e.: To set a 32x50 sprite size, you'll have to known that 32 equal 1 << 5,
  '       so final result would be CONSTANT(5<<8 + 50)
  ' Sprite pixel definition is stored in spin_sprite_a, including animation frame.
  ' Memory address is shifted by 16, and animation frame number is a 4-bit fixed-point value.
  ' i.e.: To set the address of a non-animated 1-frame sprite, you simply have to set
  ' spin_sprite_a to CONSTANT((@my_sprite_definition000 + _memstart)<<16)
  '   Q: What's the _memstart constant here?
  '   A: This is a bug in the propeller compiler which force you to add this magic
  '      'mem start' address to any address you use inside a 'CONSTANT()' calculation
  ' Now let's say your sprite have 3 different frames. (stored vertically in the same BMP file)
  ' If you want to display the frame #2, you'll have to add (2<<4) to the sprite address:
  ' CONSTANT((@my_sprite_definition000 + _memstart)<<16 + (2<<4))
  '   Q: Why is the frame number shifted by 4?
  '   A: This was to allow easy animation: By adding '1' to your sprite animation every vbl,
  '      you'll see the sprite change frame every 16 vbl.
  ' There is a magical value of '255' (unshifted!!) which means 'Don't display this sprite'.
  ' This enables code to hide a sprite at runtime without having to set its Y or X coordinate off-screen.
  ' Alas, this limits the theorical maximum number of animation frame of a sprite to 15.
  
  ' first sprite (0):
  ' The currently grabbed marble (start hidden)
  long[CONSTANT(spin_sprite_x-0*20)] := CONSTANT(70<<7)
  long[CONSTANT(spin_sprite_y-0*20)] := CONSTANT(100<<7)
  long[CONSTANT(spin_sprite_s-0*20)] := CONSTANT(4<<8 + 16)
  long[CONSTANT(spin_sprite_a-0*20)] := CONSTANT((@cursor000+_memstart+3*16*16)<<16 + (255))

  ' sprite (1):
  ' The mouse cursor
  long[CONSTANT(spin_sprite_x-1*20)] := CONSTANT(60<<7)
  long[CONSTANT(spin_sprite_y-1*20)] := CONSTANT(80<<7)
  long[CONSTANT(spin_sprite_s-1*20)] := CONSTANT(4<<8 + 16)
  long[CONSTANT(spin_sprite_a-1*20)] := CONSTANT((@cursor000+_memstart)<<16 + (2<<4))

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

  'start mouse driver
  mouse.start(2)
  
  ' Start assembler code!
  ' Each chunks of code loaded with this 'loader' kernel can have a maximum of 340 longs.
  ' If you need more code, you'll have to load another chunk.
  ' By switching chunk, you lose SOME OF YOUR COG MEMORY VARIABLES. So remember to store every persistent
  ' info to HUB memory using 'MEM_BUFFER' constant or use the top part of cog memory to keep persistent info.
  ' GAMEINIT_START is a special, it is used to setup the initial fixed 100 longs of cog memory
  loader.start(@GAMEINIT_START)

  ' Start of main spin loop here.
  ' The spin code is only used to read the gamepad/keyboard, and redirect mouse driver values to main HUB memory.
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

    ' Arrow pad is mapped over gamepad #1 controls
    if(key.keystate($C2))
      temp1|=CONSTANT(NES_UP)
    elseif(key.keystate($C3))
      temp1|=CONSTANT(NES_DOWN)
    if(key.keystate($C0))
      temp1|=CONSTANT(NES_LEFT)
    elseif(key.keystate($C1))
      temp1|=CONSTANT(NES_RIGHT)
    
    if(key.keystate($20)) ' Spacebar emulates button A
      temp1|=CONSTANT(NES_A)
    ' output gamepads values to our global hub memory
    long[spin_gamepad] := temp1

    ' Output some specific keyboard letter for command shortcuts:
    ' N = New game
    ' U = Undo
    ' H = Help
    ' L = next Level
    long[spin_keyboardshortcut] := 0
    if(key.keystate(110)) ' N
      long[spin_keyboardshortcut] := CONSTANT(SHORTCUT_N)
    elseif(key.keystate(117)) ' U
      long[spin_keyboardshortcut] := CONSTANT(SHORTCUT_U)
    elseif(key.keystate(104)) ' H
      long[spin_keyboardshortcut] := CONSTANT(SHORTCUT_H)
    elseif(key.keystate(108)) ' L
      long[spin_keyboardshortcut] := CONSTANT(SHORTCUT_L)

    ' Output mouse delta x/y and buttons into global hub memory
    long[spin_mouse_dx] := mouse.delta_x
    long[spin_mouse_dy] := -mouse.delta_y
    long[spin_mouse_button] := mouse.buttons
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

' Utility proc: Read in sprite number 'r0' addresses into cog memory register, ready for read/write operation.
' Since this function reside in the first 100 longs of cog memory, it will be kept forever.
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
mouse_dx_adr            long spin_mouse_dx
mouse_dy_adr            long spin_mouse_dy
mouse_button_adr        long spin_mouse_button
fsprite_x_adr           long spin_sprite_x
sprite_x_adr            long spin_sprite_x
sprite_y_adr            long spin_sprite_y
sprite_s_adr            long spin_sprite_s
sprite_a_adr            long spin_sprite_a
sprite_p_adr            long spin_sprite_p

' From here on, you can add game variable that you want to keep permanently
' (i.e.: not lose them when you switch code chunk using the loader kernel)

' GAME VARIABLES GO HERE...
framecount              long 0
gamearray_adr           long spin_gamearray
level_tileoffset        long 0
tilearray_adr           long 0
level                   long 0
nbmarble                long 0
state                   long 0
undomove                long 0
undomove2               long 0
helpactive              long 0
winlevel                long 0
mx                      long 128
my                      long 90
grabx                   long 0
graby                   long 0
mousetile_offset        long 0
mousetile               long 0
mh                      long 0
prevmousehit            long 0
kx                      long 10*16 + 8
ky                      long 5*16 + 12
keyrepeat               long 0
gamepad                 long 0
prevgamepad             long 0
grabtile                long 0
keyboard_short_adr      long spin_keyboardshortcut

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
' Code hint:
' Always use a prefix for your lables and temporary variable.
' In this example, I'm using 'main_'.
' Q: Why?
' A: Because from the assembler point of view, everything is accessible from anywhere.
'    This means that your 'main_loop' variable can be accessed even from another code chunk.
'    BUT beware! It will represent PURE JUNK, since the content of cog memory will not
'    match what the assembler expected to be at that label.

                        call #restartlevel

main_loop
                        ' Debug led flicker tester: enable this to see if your main loop is working.
                        ' Enabling this line will make the debug LED flicker at 60 hz (pretty fast).
                        'xor outa, #1           

                        call #updatekeyboard
                        call #updatemouse

                        call #fetchmousetile

                        call #updateinterface

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

                        ' Wait for VBL
                        call #waitvbl

                        add framecount, #1

                        ' Keep last mouse button state
                        mov prevmousehit, mh

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

' Move keyboard cursor in direction (r1,r2)
keymove
        {kx = kx / 16 * 16 + 8 + dx
        ky = ky / 16 * 16 + 12 + dy
        If(kx > 248) kx = 248
        If(kx < 8) kx = 8
        If(ky > 184) ky = 184
        If(ky < 8) ky = 8}
                        mov r0, kx
                        sar r0, #4
                        shl r0, #4
                        add r0, #8
                        add r0, r1
                        maxs r0, #248
                        mins r0, #8
                        mov kx, r0

                        mov r0, ky
                        sar r0, #4
                        shl r0, #4
                        add r0, #10
                        add r0, r2
                        maxs r0, #184
                        mins r0, #8
                        mov ky, r0

keymove_ret             ret

' Check for auto-repeat when holding down a key or gamepad
dokeyrepeat
        'If(Not key) Return
                        cmp gamepad, r0 wc, wz
        if_ne           jmp #dokeyrepeat_ret
        
        ' Initial keypress: start repetition delay
        {If(Not prevkey)
                keyrepeat = framecount + 24
                
                KeyMove(dx, dy)
        EndIf}
                        cmp prevgamepad, gamepad wc, wz
        if_e            jmp #:skipinitial
                        mov keyrepeat, framecount
                        add keyrepeat, #16
                        call #keymove

:skipinitial
        {If framecount >= keyrepeat
                keyrepeat = framecount + 4
                KeyMove(dx, dy)
        EndIf}
                        cmp framecount, keyrepeat wc, wz
        if_b            jmp #dokeyrepeat_ret
                        mov keyrepeat, framecount
                        add keyrepeat, #5
                        call #keymove                        

dokeyrepeat_ret         ret

' Update cursor movement from keyboard or gamepad
updatekeyboard
                        rdlong gamepad, gamepad_adr
                        ' Keep only the directional pad info
                        and gamepad, #NES_PAD

                        mov r0, #NES_RIGHT
                        mov r1, #16
                        mov r2, #0
                        call #dokeyrepeat
                        mov r0, #NES_LEFT
                        mov r1, #16
                        neg r1, r1
                        mov r2, #0
                        call #dokeyrepeat

                        mov r0, #NES_DOWN
                        mov r1, #0
                        mov r2, #16
                        call #dokeyrepeat
                        mov r0, #NES_UP
                        mov r1, #0
                        mov r2, #16
                        neg r2, r2
                        call #dokeyrepeat

                        mov prevgamepad, gamepad
                        
updatekeyboard_ret      ret

updateinterface
                        cmp state, #1 wc, wz
        if_e            jmp #updateinterface_ret

                        ' Set initial (normal) state of buttons 
                        mov newbuttontile, #5
                        mov undobuttontile, #12
                        mov helpbuttontile, #13
                        mov winbuttontile, #16

                        ' Compute if mouse button has been clicked this frame
                        mov mouseclick, #0
                        cmp prevmousehit, #0 wc, wz
        if_e            cmp mh, #1 wc, wz
        if_e            mov mouseclick, #1

                        ' Keep keyboard shortcut in r7
                        rdlong r7, keyboard_short_adr

        {If(KeyDown(KEY_N))
                mouseclick = True 
                mousetile_offset = (1 + 2 Shl 4)
        EndIf}
                        cmp r7, #SHORTCUT_N wc, wz
        if_e            mov mouseclick, #1
        if_e            jmp #:click_new_game
        
                        ' Handle 'New game' button:
        {If(mousetile_offset = (1 + 2 Shl 4))
                newbuttontile = 6
                If mouseclick Then RestartLevel()
        EndIf}

                        cmp mousetile_offset, #1+(2<<4) wc, wz
        if_ne           jmp #:skip
:click_new_game
                        mov newbuttontile, #6

                        cmp mouseclick, #1 wc, wz
        if_ne           jmp #:skip

                        ' Special case: on level 4, 'New' will start back on level 0
                        cmp level, #4 wc, wz
        if_e            mov level, #0
        if_e            mov level_tileoffset, #0

                        call #restartlevel
:skip

        'If(state = 0)
                        cmp state, #0 wc, wz
        if_ne           jmp #:notstate0

                        ' undo button
                'If(undomove <> 0)
                        cmp undomove, #0 wc, wz
        if_z            jmp #:skipundo
        
                        'undobuttontile = 7
                        mov undobuttontile, #7

                        
                    {If(KeyDown(KEY_U))
                            mouseclick = True 
                            mousetile_offset = (1 + 4 Shl 4)
                    EndIf}
                        cmp r7, #SHORTCUT_U wc, wz
        if_e            mov mouseclick, #1
        if_e            jmp #:click_undo
                    
                    'If(mousetile_offset = (1 + 4 Shl 4))
                        cmp mousetile_offset, #1+(4<<4) wc, wz
        if_ne           jmp #:skipundo

:click_undo
            ' undobuttontile = 8
                        mov undobuttontile, #8
        
                    '       If mouseclick
                        cmp mouseclick, #1 wc, wz
        if_ne           jmp #:skipundo
{
            ' undo last move
            Local over = (undomove + undomove2) Shr 1
            game[over] = 2
            game[undomove] = 2
            game[undomove2] = 1
            undomove = 0
            nbmarble :+ 1
}
                        mov r0, undomove
                        add r0, undomove2
                        shr r0, #1
                        add r0, gamearray_adr
                        mov r1, #2
                        wrbyte r1, r0

                        mov r0, undomove
                        add r0, gamearray_adr
                        wrbyte r1, r0

                        mov r0, undomove2
                        add r0, gamearray_adr
                        mov r1, #1
                        wrbyte r1, r0

                        mov undomove, #0
                        add nbmarble, #1

:skipundo
                        ' help button
         '      helpbuttontile = 9
                        mov helpbuttontile, #9
                        
                {If(KeyDown(KEY_H))
                        mouseclick = True 
                        mousetile_offset = (1 + 6 Shl 4)
                EndIf}
                        cmp r7, #SHORTCUT_H wc, wz
        if_e            mov mouseclick, #1
        if_e            jmp #:click_help
                
                {If(mousetile_offset = (1 + 6 Shl 4))
                        If mouseclick Then      helpactive = 1
                        helpbuttontile = 10
                EndIf}
                        cmp mousetile_offset, #1+(6<<4) wc, wz
                if_ne   jmp #:notstate0

:click_help
                        mov helpbuttontile, #10

                        cmp mouseclick, #1 wc, wz
                if_e    mov helpactive, #1

:notstate0              

        {If(winlevel = 1 And level < 4)
                winbuttontile = 14
                If(KeyDown(KEY_L))
                        mouseclick = True 
                        mousetile_offset = (1 + 8 Shl 4)
                EndIf
                If(mousetile_offset = (1 + 8 Shl 4))
                        winbuttontile = 15
                        If mouseclick
                                level :+ 1
                                level_tileoffset :+ 192
                                winlevel = 0
                                RestartLevel()
                        EndIf
                EndIf
        End If}
                        cmp winlevel, #1 wc, wz
            if_ne       jmp #:nowinbutton
                        cmp level, #4 wc, wz
            if_ae       jmp #:nowinbutton

                        mov winbuttontile, #14

                        cmp r7, #SHORTCUT_L wc, wz
        if_e            mov mouseclick, #1
        if_e            jmp #:click_level

                        cmp mousetile_offset, #1+(8<<4) wc, wz
            if_ne       jmp #:nowinbutton

:click_level
                        mov winbuttontile, #15

                        cmp mouseclick, #1 wc, wz
            if_ne       jmp #:nowinbutton

                        add level, #1
                        add level_tileoffset, #192
                        mov winlevel, #0
                        call #restartlevel                        

:nowinbutton

                        ' Write updated button status into tilemap
        {tilemap[(1 + 2 Shl 4) + level_tileoffset] = newbuttontile
        tilemap[(1 + 4 Shl 4) + level_tileoffset] = undobuttontile
        tilemap[(1 + 6 Shl 4) + level_tileoffset] = helpbuttontile
        tilemap[(1 + 8 Shl 4) + level_tileoffset] = winbuttontile}
                        mov r0, tilearray_adr
                        add r0, #1+(2<<4)
                        wrbyte newbuttontile, r0

                        ' Skip draw of undo, help and win on special end level
                        cmp level, #4 wc, wz
        if_e            jmp #updateinterface_ret
                        
                        mov r0, tilearray_adr
                        add r0, #1+(4<<4)
                        wrbyte undobuttontile, r0
                        
                        mov r0, tilearray_adr
                        add r0, #1+(6<<4)
                        wrbyte helpbuttontile, r0
                        
                        mov r0, tilearray_adr
                        add r0, #1+(8<<4)
                        wrbyte winbuttontile, r0
                        
updateinterface_ret     ret

' Fetch the tile offset and tile value currently under mouse
fetchmousetile
{
        If (state = 1)
                tx = (mx-grabx+8) Shr 4
                ty = (my-graby+8) Shr 4
        Else
                tx = mx Shr 4
                ty = my Shr 4
        EndIf
        
        'DrawRect tx*16,ty*16,8,8
        
        mousetile_offset = tx + (ty) Shl 4      
        mousetile = game[mousetile_offset]
}
                        mov r0, mx
                        mov r1, my

                        cmp state, #1 wc, wz
        if_ne           jmp #:not_state1

                        sub r0, grabx
                        add r0, #8
                        sub r1, graby
                        add r1, #8

:not_state1
                        shr r0, #4
                        shr r1, #4
                        shl r1, #4
                        add r1, r0
                        mov mousetile_offset, r1
                        add r1, gamearray_adr
                        rdbyte mousetile, r1
                        
fetchmousetile_ret      ret

' Fetch mouse movement 
updatemouse
                        ' Fetch mouse delta and update our current mouse position
                        ' Clamp to screen 0,0 - 255,191
                        rdlong r0, mouse_dx_adr
                        rdlong r1, mouse_dy_adr

        {If(newmousex <> lastmousex Or newmousey <> lastmousey)
                mx = newmousex
                my = newmousey
                kx = mx
                ky = my
        Else
                If(mx < kx) mx :+ 4
                If(mx > kx) mx :- 4
                If(my < ky) my :+ 4
                If(my > ky) my :- 4
        EndIf}
                        ' Check if mouse x or y has changed
                        cmp r0, #0 wc, wz
        if_nz           jmp #:mousemoved
                        cmp r1, #0 wc, wz
        if_z            jmp #:mousenotmoved
:mousemoved
                        ' Yes: cursor will be positionned at new mouse pos and keyboard pos will follow
                        add mx, r0
                        mins mx, #0
                        maxs mx, #255
                        add my, r1
                        mins my, #0
                        maxs my, #191
                        mov kx, mx
                        mov ky, my

                        jmp #:mousemovecont
:mousenotmoved
                        ' No: since mouse wasn't moved, keyboard controls the mouse
                        cmp mx, kx wc, wz
        if_b            add mx, #3
                        cmp mx, kx wc, wz
        if_a            sub mx, #3
                        cmp my, ky wc, wz
        if_b            add my, #3
                        cmp my, ky wc, wz
        if_a            sub my, #3

:mousemovecont
                        ' Read left mouse button
                        rdlong mh, mouse_button_adr
                        and mh, #1              ' just keep left mouse button

                        ' Gamepad will mimic a mouse press
                        rdlong r0, gamepad_adr
                        test r0, #NES_A_B wc, wz
        if_nz           or mh, #1

updatemouse_ret         ret

restartlevel
                        ' Set vertical map scroll to starting screen of current level
                        wrlong level_tileoffset, vertical_scroll

                        ' Cache address of current tilemap into 'tilearray_adr'
                        rdlong tilearray_adr, tilemap_adr
                        add tilearray_adr, #32  ' skip top and bottom tilemap row
                        add tilearray_adr, level_tileoffset                     ' skip to current level screen
                        
                        
                        ' Fill gamearray with 1 (plain background)
        {For i = 0 Until 192
                game[i] = 0
        Next}

                        mov r0, #192
                        mov r1, #0
                        mov r2, gamearray_adr
:fillgamearray
                        wrbyte r1, r2
                        add r2, #1
                        djnz r0, #:fillgamearray

                        ' Set initial marble position for the current level (0..3)
                        cmp level, #0 wc, wz
        if_e            jmp #:level_0
                        cmp level, #1 wc, wz
        if_e            jmp #:level_2
                        cmp level, #2 wc, wz
        if_e            jmp #:level_2
                        cmp level, #3 wc, wz
        if_e            jmp #:level_3

                        ' Level 4 is a special 'win' screen, with no marble
                        jmp #:level_done
:level_0                
                {For i = 0 Until 4
                        For j = 0 Until 5
                                game[i+9+(j+3) Shl 4] = 2
                        Next
                Next}
                        mov r3, #2
                        mov r0, #0
:loop_i                 
                        mov r1, #0
:loop_j                 
                        mov r2, r1
                        add r2, #3
                        shl r2, #4
                        add r2, r0
                        add r2, #9
                        add r2, gamearray_adr
                        wrbyte r3, r2
                        add r1, #1
                        cmp r1, #5 wc, wz
        if_ne           jmp #:loop_j
                        add r0, #1
                        cmp r0, #4 wc, wz
        if_ne           jmp #:loop_i

                        jmp #:marble_done

:level_2                
              {For i = 0 Until 7
                        For j = 0 Until 3
                                game[i+7+(j+4) Shl 4] = 2
                                game[j+9+(i+2) Shl 4] = 2
                        Next
                Next}
                        mov r3, #2
                        mov r0, #0
:loop_i2                
                        mov r1, #0
:loop_j2                
                        mov r2, r1
                        add r2, #4
                        shl r2, #4
                        add r2, r0
                        add r2, #7
                        add r2, gamearray_adr
                        wrbyte r3, r2
                        
                        mov r2, r0
                        add r2, #2
                        shl r2, #4
                        add r2, r1
                        add r2, #9
                        add r2, gamearray_adr
                        wrbyte r3, r2
                        
                        add r1, #1
                        cmp r1, #3 wc, wz
        if_ne           jmp #:loop_j2
                        add r0, #1
                        cmp r0, #7 wc, wz
        if_ne           jmp #:loop_i2

                        cmp level, #2 wc, wz
        if_e            jmp #:marble_done
:level_1                
                        mov r3, #0
                        mov r2, #(2<<4)+10
                        add r2, gamearray_adr
                        wrbyte r3, r2
                        mov r2, #(8<<4)+10
                        add r2, gamearray_adr
                        wrbyte r3, r2
                        mov r2, #(5<<4)+13
                        add r2, gamearray_adr
                        wrbyte r3, r2
                        mov r2, #(5<<4)+7
                        add r2, gamearray_adr
                        wrbyte r3, r2

                        jmp #:marble_done
:level_3                
                {For i = 0 Until 9
                        For j = 0 Until 9
                                game[i+6+(j+1) Shl 4] = 2
                        Next
                Next}
                        mov r3, #2
                        mov r0, #0
:loop_i3                
                        mov r1, #0
:loop_j3                
                        mov r2, r1
                        add r2, #1
                        shl r2, #4
                        add r2, r0
                        add r2, #6
                        add r2, gamearray_adr
                        wrbyte r3, r2
                        
                        add r1, #1
                        cmp r1, #9 wc, wz
        if_ne           jmp #:loop_j3
                        add r0, #1
                        cmp r0, #9 wc, wz
        if_ne           jmp #:loop_i3

                        jmp #:marble_done

:marble_done
                        ' Set starting hole 
                ' game[10 + 5 Shl 4] = 1
                        mov r2, #(5<<4)+10
                        add r2, gamearray_adr
                        mov r3, #1
                        wrbyte r3, r2

:level_done
        {nbmarble = 0
        For i = 0 Until 192
                If(game[i] = 2) nbmarble :+ 1
        Next
        
        state = 0
        framecount = 0
        undomove = 0
        helpactive = 0}
                        mov state, #0
                        mov framecount, #0
                        mov undomove, #0
                        mov helpactive, #0
        
                        mov nbmarble, #0
                        mov r0, #192
                        mov r1, gamearray_adr
:countmarble
                        rdbyte r2, r1
                        cmp r2, #2 wc, wz
        if_e            add nbmarble, #1
                        add r1, #1
                        djnz r0, #:countmarble
                        
restartlevel_ret        ret

' Here, we can declare temporary cog registers.
' They will be destroyed whenever we load a different chunk of assembly code.
' So rule of thumb:
'   All permanent/shared info should be stored in the first 100-long of cog memory described above.
'   ALL cog registers defined here will be destroyed/filled with crap every time a code chunk gets loaded.
newbuttontile           long 0
undobuttontile          long 0
helpbuttontile          long 0
winbuttontile           long 0
mouseclick              long 0

GAMEMAIN_END
' Put a safety 'fit' here: Your code CANNOT exceed this fit value. The compiler will warn you if it happens.
                        fit 448
' Q: Why?
' A: Because a cog contains 512 long of memory, and the loader kernel mecanism only loads 340 of it at a time.
'    (340 = 440 - first 100 long)
'    So if you exceed this, you'll need to split some of your code to another 'chunk'.


' Here, we declare another 'chunk of assembly code', that can be swapped by the loader kernel.
' Remember to start at ORG 100 or ELSE TERRIBLE THINGS WILL HAPPEN.
                        org 100
GAMEPROCESS_START
               
                        call #updatetilemap

                        ' Read in mouse cursor sprite
                        mov r0, #1
                        call #readspriteinfo

                        cmp state, #0 wc, wz
        if_z            jmp #state0
                        cmp state, #1 wc, wz
        if_z            jmp #state1
                        cmp state, #2 wc, wz
        if_z            jmp #state2

backfromstate
                        ' CHEAT DEBUG: Enable this line to allow 'Win' button always enabled
                        'mov winlevel, #1

                        call #displaymarbles
                        call #displaytimer

                        ' VERY IMPORTANT: You need to do this jmp to return back to the calling code.
                        jmp   #__loader_return

' Utility called from state0 when counting valid moves
checkmove
                        mov r3, r6
                        add r3, r2
                        rdbyte r0, r3
                        cmp r0, #1 wc, wz
        if_ne           jmp #checkmove_ret

                        sar r6, #1
                        add r6, r2
                        rdbyte r0, r6
                        cmp r0, #2 wc, wz
        if_ne           jmp #checkmove_ret
                        add marblemove, #1                        
                        
checkmove_ret           ret

' State 0: Normal state of gameplay when starting
state0

            {   ' Count number of possible remaining move
                Local validmoves = 0
                For Local i = 0 Until 192
                        If(game[i] <> 2) Continue
                        Local marblemove = 0
                        For Local j = 0 Until 4
                                Local check
                                Select j
                                        Case 0 check = 2
                                        Case 1 check = -2
                                        Case 2 check = 32
                                        Case 3 check = -32
                                EndSelect
                                If(i + check < 0) Continue
                                If(i + check >= 192) Continue
                                If(game[i+check] <> 1) Continue
                                If(game[i+check Sar 1] <> 2) Continue
                                marblemove :+ 1
                        Next
                        
                        If(helpactive And marblemove > 0)
                                tilemap[i + level_tileoffset] = 11
                        EndIf
                        validmoves :+ marblemove
                Next

                If(validmoves = 0)
                        state = 2
                EndIf}

                        mov validmoves, #0
                        mov r7, #192
                        mov r2, gamearray_adr
loop_count
                        rdbyte r0, r2
                        cmp r0, #2 wc, wz
        if_ne           jmp #continuecount

                        mov marblemove, #0

                        mov r6, #2
                        call #checkmove
                        mov r6, #32
                        call #checkmove
                        mov r6, #2
                        neg r6, r6
                        call #checkmove
                        mov r6, #32
                        neg r6, r6
                        call #checkmove

                        add validmoves, marblemove

                        cmp helpactive, #1 wc, wz
        if_ne           jmp #continuecount

                        cmp marblemove, #0 wc, wz
        if_z            jmp #continuecount

                        mov r0, #192
                        sub r0, r7
                        add r0, tilearray_adr
                        mov r1, #11
                        wrbyte r1, r0

continuecount
                        add r2, #1
                        djnz r7, #loop_count

                        ' End of game: win or lose, there are no more moves
                        cmp validmoves, #0 wc, wz
        if_z            mov state, #2
                        

                        ' Set mouse cursor and hotspot depending if over a marble
                {If (mousetile >= 2)
                        SetImageHandle(cursor, 3, 1)
                        DrawImage(cursor, mx, my, 0)
                Else
                        SetImageHandle(cursor, 3, 1)
                        DrawImage(cursor, mx, my, 2)
                EndIf}
                        mov r0, mx
                        mov r1, my
                        rdlong r2, sprite_a_adr

                        cmp mousetile, #2 wc, wz
        if_ae           jmp #:over_marble

                        ' Not over a marble, set normal sprite
                        movs r2, #2<<4          ' set cursor frame 2
                        jmp #:set_sprite
:over_marble
                        movs r2, #0<<4          ' set cursor frame 0
:set_sprite
                        sub r0, #3              ' Subtract 'hotspot' of cursor
                        sub r1, #1

                        shl r0, #7
                        wrlong r0, sprite_x_adr
                        shl r1, #7
                        wrlong r1, sprite_y_adr
                        wrlong r2, sprite_a_adr

                        ' Ensure sprite 0 is hidden
                        mov r0, #0
                        call #readspriteinfo
                        rdlong r2, sprite_a_adr
                        movs r2, #255
                        wrlong r2, sprite_a_adr

                        ' Check for mouse click over a marble to grab it -> go to state 1
                {If (prevmousehit = 0 And mh = 1)
                        ' and mouse is currently over a valid marble
                        If (mousetile >= 2)
                                ' then remove the marble from the board and attach it to the cursor
                                game[mousetile_offset] = 1
                                state = 1
                                grabtile = mousetile_offset
                                grabx = mx & 15
                                graby = my & 15
                                helpactive = 0
                        EndIf
                EndIf}
                        cmp prevmousehit, #0 wc, wz
                if_ne   jmp #backfromstate
                        cmp mh, #1 wc, wz
                if_ne   jmp #backfromstate
                        cmp mousetile, #2 wc, wz
                if_b    jmp #backfromstate

                        mov r0, gamearray_adr
                        add r0, mousetile_offset
                        mov r1, #1
                        wrbyte r1, r0
                        mov state, #1
                        mov grabtile, mousetile_offset
                        mov grabx, mx
                        and grabx, #15
                        mov graby, my
                        and graby, #15
                        mov helpactive, #0
       
                        jmp #backfromstate

' State 1: User is currently dragging a marble
state1
                        ' Display appropriate mouse cursor and sprite of grabbed marble
                {SetImageHandle(cursor, 3, 1)
                DrawImage(cursor, mx, my, 1) }
                        mov r0, mx
                        mov r1, my
                        rdlong r2, sprite_a_adr
                        movs r2, #1<<4          ' set cursor frame 1
                        sub r0, #3              ' Subtract 'hotspot' of cursor
                        sub r1, #1
                        shl r0, #7
                        wrlong r0, sprite_x_adr
                        shl r1, #7
                        wrlong r1, sprite_y_adr
                        wrlong r2, sprite_a_adr

               { SetImageHandle(cursor, 0, 0)
                DrawImage(cursor, mx-grabx, my-graby, 3)}               
                        ' Read in sprite 0 info
                        
                        mov r0, #0
                        call #readspriteinfo
                        mov r0, mx
                        mov r1, my
                        rdlong r2, sprite_a_adr
                        movs r2, #0             ' set cursor frame 0
                        sub r0, grabx
                        sub r1, graby
                        shl r0, #7
                        wrlong r0, sprite_x_adr
                        shl r1, #7
                        wrlong r1, sprite_y_adr
                        wrlong r2, sprite_a_adr
                        
                        ' Now check if user released the mouse button
              {If (prevmousehit = 1 And mh = 0)}
                        cmp prevmousehit, #1 wc, wz
                if_ne   jmp #backfromstate
                        cmp mh, #0 wc, wz
                if_ne   jmp #backfromstate

                        ' Is mouse is currently over a valid hole?
                        cmp mousetile, #1 wc, wz
                if_ne   jmp #:putback

                    ' there are 4 valid possibilities:
                    {Local diff = mousetile_offset - grabtile
                    If (diff = 2 Or diff = -2 Or diff = 32 Or diff = -32)}
                        mov r0, mousetile_offset
                        sub r0, grabtile
                        cmp r0, #2 wc, wz
        if_e            jmp #:offset_valid
                        cmp r0, #32 wc, wz
        if_e            jmp #:offset_valid
                        neg r0, r0
                        cmp r0, #2 wc, wz
        if_e            jmp #:offset_valid
                        cmp r0, #32 wc, wz
        if_e            jmp #:offset_valid
                        jmp #:putback

:offset_valid
                        ' Move is over a hole AND correct distance:
                        ' Check if there was a marble to jump over
            {Local over = (mousetile_offset + grabtile) Shr 1
            If(game[over] >= 2)}
                        mov r0, mousetile_offset
                        add r0, grabtile
                        shr r0, #1
                        add r0, gamearray_adr
                        rdbyte r1, r0
                        cmp r1, #2 wc, wz
            if_b        jmp #:putback

                         ' Great, user made a valid move!
                         ' clear the jumped over marble
                         'game[over] = 1
                         mov r1, #1
                         wrbyte r1, r0
                         ' set the landing marble
                         {undomove = grabtile
                         undomove2 = mousetile_offset
                         grabtile = mousetile_offset
                         nbmarble :- 1}
                         mov undomove, grabtile
                         mov undomove2, mousetile_offset
                         mov grabtile, mousetile_offset
                         sub nbmarble, #1

:putback
                        ' Otherwise, reset by putting it back at the starting place
                {game[grabtile] = 2
                state = 0}
                        mov r0, gamearray_adr
                        add r0, grabtile
                        mov r1, #2
                        wrbyte r1, r0
                        mov state, #0
                        
                        jmp #backfromstate

state2
                        ' Game over: the normal mouse cursor
                        mov r0, mx
                        mov r1, my
                        sub r0, #3              ' Subtract 'hotspot' of cursor
                        sub r1, #1
                        rdlong r2, sprite_a_adr
                        movs r2, #2<<4          ' set cursor frame 2
                        shl r0, #7
                        wrlong r0, sprite_x_adr
                        shl r1, #7
                        wrlong r1, sprite_y_adr
                        wrlong r2, sprite_a_adr

                        'If (nbmarble = 1) winlevel = 1
                        cmp nbmarble, #1 wc, wz
        if_e            mov winlevel, #1

                        jmp #backfromstate

' Display remaining marbles on screen
displaymarbles
                        mov r6, nbmarble
                        mov r2, tilearray_adr
                        add r2, #13+(11<<4)

                        mov r3, #3
:loop_display
                        mov r7, #10
                        call #divide

                        add r7, #21             ' Number 0 starts at tile #21
                        wrbyte r7, r2
                        sub r2, #1
                        
                        djnz r3, #:loop_display
displaymarbles_ret      ret

' Display timer on screen
displaytimer
                        cmp state, #2 wc, wz
        if_e            jmp #displaytimer_ret

                        mov r6, framecount
                        mov r2, tilearray_adr
                        add r2, #5+(11<<4)

                        ' First, divide framecount by 60 to obtain elapsed seconds
                        mov r7, #60
                        call #divide

                        ' 1st second digit: 0-9
                        mov r7, #10
                        call #divide
                        add r7, #21             ' Number 0 starts at tile #21
                        wrbyte r7, r2
                        sub r2, #1

                        ' 2nd second digit: 0-5
                        mov r7, #6
                        call #divide
                        add r7, #21             ' Number 0 starts at tile #21
                        wrbyte r7, r2
                        sub r2, #2

                        ' 1st minute digit: 0-9
                        mov r7, #10
                        call #divide
                        add r7, #21             ' Number 0 starts at tile #21
                        wrbyte r7, r2
                        sub r2, #1

                        ' 2nd minute digit: 0-9
                        mov r7, #10
                        call #divide
                        add r7, #21             ' Number 0 starts at tile #21
                        wrbyte r7, r2
                        sub r2, #1

displaytimer_ret        ret

updatetilemap
        ' update tilemap with game data
        {
        For i = 2 Until 15
                For j = 1 Until 11
                        Local i2 = i + j Shl 4
                        Local t = game[i2]
                        Local tile = 2
        
                        ' Skip non-game tiles
                        If(t = 0)
                                Continue                
                        ElseIf(t = 2)
                                tile = 3
                                Local t2 = game[i2 + 16]        
                                If(t2 = 2) tile = 4
                        EndIf
                        tilemap[i2 + level_tileoffset] = tile
                Next
        Next
        }
                        mov r0, #2
:loop_i                 
                        mov r1, #1
:loop_j
                        mov r2, r1
                        shl r2, #4
                        add r2, r0
                        mov r3, gamearray_adr
                        add r3, r2
                        rdbyte r3, r3 wz
        if_z            jmp #:skip_loop_j

                        mov r4, #2

                        cmp r3, #2 wc, wz
        if_ne           jmp #:put_tile
                        mov r4, #3

                        mov r3, gamearray_adr
                        add r3, r2
                        add r3, #16
                        rdbyte r3, r3
                        cmp r3, #2 wc, wz
        if_e            mov r4, #4

:put_tile
                        mov r3, tilearray_adr
                        add r3, r2
                        wrbyte r4, r3

:skip_loop_j
                        add r1, #1
                        cmp r1, #11 wc, wz
        if_ne           jmp #:loop_j

                        add r0, #1
                        cmp r0, #15 wc, wz
        if_ne           jmp #:loop_i

updatetilemap_ret       ret

validmoves              long 0
marblemove              long 0

GAMEPROCESS_END
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

' GAME SPRITE DEFINITION :
' Everything up from this point is simply stored in HUB memory, read for future access.
' You can put as many sprites as you like. Simply press F8 to actually see how much
' free memory you still have left.
' Hint: You can reduce the number of tiles if you want more sprite data.
' The default number of tiles is 48. Each tile is 16x16, using up exactly 12288 bytes of data.
' Edit 'rem_tutorial_data_015.spin' to see the tiles and tilemap.

' Cursor000 is a 16x64 image, containing 4 frames for a 16x16 sprite.
' It is exported from 'cursor.bmp' using 'xgs_sprite.pl'.
' Read the readme.txt file for information on exportation and file format.

cursor000 long $01000000,$00000405,$00000000,$00000000,$05010000,$00040505,$00000000,$00000000
        long $05010000,$04050505,$00000000,$00000000,$01000000,$04050505,$00040501,$00000000
        long $01000000,$05050505,$04050104,$00000000,$00000000,$05050501,$04050405,$00000401
        long $05040100,$05050502,$05050505,$00040505,$05050501,$05050502,$04050504,$00040505
        long $05050501,$04050504,$03040403,$00040504,$05050501,$04050505,$03040403,$00040504
        long $05050100,$03040505,$04030404,$00000405,$05010000,$04050505,$05040505,$00000405
        long $01000000,$05050505,$05050505,$00000004,$00000000,$05050501,$04050505,$00000000
        long $00000000,$01010100,$01010101,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$04050501,$00040501,$00000000
        long $01000000,$05050505,$04050104,$00000000,$01000000,$05050505,$04050405,$00000401
        long $05040100,$05050502,$05050505,$00040505,$05050501,$05050502,$04050504,$00040505
        long $05050501,$04050504,$03040403,$00040504,$05050501,$04050505,$03040403,$00040504
        long $05050100,$03040505,$04030404,$00000405,$05010000,$04050505,$05040505,$00000405
        long $01000000,$05050505,$05050505,$00000004,$00000000,$05050501,$04050505,$00000000
        long $00000000,$01010100,$01010101,$00000000,$00000000,$00000000,$00000000,$00000000
        long $01000000,$00000001,$00000000,$00000000,$05010000,$00000105,$00000000,$00000000
        long $05010000,$00010505,$00000000,$00000000,$05010000,$01050505,$00000000,$00000000
        long $05010000,$05050505,$00000001,$00000000,$05010000,$05050505,$00000105,$00000000
        long $05010000,$05050505,$00010505,$00000000,$05010000,$05050505,$01050505,$00000000
        long $05010000,$05050505,$00010405,$00000000,$05010000,$05050505,$00000004,$00000000
        long $05010000,$05050105,$00000004,$00000000,$05010000,$05010100,$00000405,$00000000
        long $00010000,$05010000,$00000405,$00000000,$00000000,$01010000,$00040505,$00000000
        long $00000000,$01000000,$00000505,$00000000,$00000000,$01000000,$00000001,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$5A5A0000,$00005C5B,$00000000,$00000000,$035B0202,$5C5C5B03,$00000000
        long $02000000,$03035A02,$5C03035B,$0000005C,$02000000,$5B035B02,$03035B04,$0000005C
        long $02590000,$03035B02,$0303035B,$00005C5B,$02590000,$03035A02,$03030303,$00005C03
        long $59590000,$03035A02,$03030303,$00005C5B,$59590000,$035A0202,$5B5B0303,$00005C5B
        long $59000000,$5A020259,$5A5A5A5A,$0000005B,$59000000,$02025959,$5A020202,$0000005A
        long $00000000,$59595959,$5A5A0259,$00000000,$00000000,$5A5A0000,$00005A5A,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000

        