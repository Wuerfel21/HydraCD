{**********************************************
 * Hydrabert ( unfinished )  v1.0             *
 *                                            *
 * based on Remis Tutorial game skeleton v017 *
 *                                            *
 *                                            *
 * Bugs:                                      *
 *  - you can jump off from one of the        *
 *    cubes at the bottom                     *
 *  - if you finish the level on a cube on    *
 *    the third row from the top, the colour  *
 *    of the tile is not changing completely  *
 *                                            *
 *  The game is unfinished. There are no      *
 *  opponents and you can't jump off the      *
 *  cubes (well except from one cube).        *
 *  The game restarts after the player        *
 *  visited all cubes                         *
 **********************************************
}

CON

  _clkmode = xtal1 + pll8x  ' Set clock multiplier to 8x
  _xinfreq = 10_000_000 + 0000     ' Set to 10Mhz (and add 5000 to fix crystal imperfection of hydra prototype)
  _memstart = $10           ' memory starts $10 in!

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
  spin_fields_adr = SCANLINE_BUFFER-52
  
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

  ' Map dimension. This much match the map size found in REM_gfx_engine_015!
  ' (Map are normally exported by Mappy and copy/pasted into 'Rem_tutorial_data_015' starting at line 14
  ' Reminder: the screen is 256x192, which gives 16x12 tiles.
  ' Limitation:
  ' in the default implementation of rem_gfx_engine, MAPSIZEX must be a power of 2.
  ' This greatly limit its usefulness, as you can only have 16, 32, 64,.. width for you map.
  ' This is why in my previous game, Alien Invader, I customised the gfx engine to allow a map of 20 tiles width.
  ' The required code modification is fairly easy, if you need explanation contact me.
  ' MAPSIZEY have no restriction, can be from 1 to infinity.

  MAPSIZEX = 16
  MAPSIZEY = 12

  ' Gamepad constant declaration
  NES_RIGHT  = %00000001
  NES_LEFT   = %00000010
  NES_DOWN   = %00000100
  NES_UP     = %00001000
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
  tv    : "rem_tv_017.spin"
  gfx   : "rem_gfx_engine_017.spin"
  data  : "rb_hydrabert_data_100.spin"
  loader : "rem_loader_kernel_017.spin"

PUB start
  DIRA[0] := 1 ' Set debug LED ready for output         
  'outa[0] := 1 ' Use this to lit the debug led

  ' Use this color to set the background overscan color. Typically black ($02)
  colors[0] := $02

  ' Rem GFX engine setup variables:
  long[spin_tilemap_adr] := data.tilemap                ' Tilemap address
  long[spin_tiles_adr] := data.tiles                    ' Tiles address
  long[spin_fields_adr] := data.fields                  ' Fields address
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
  ' This defines a sprite at coordinate 70,100, of size 16x16, using pixel data from @cursor000,
  ' and displaying the 3rd animation frame
  long[CONSTANT(spin_sprite_x-0*20)] := CONSTANT((128-8)<<7)
  long[CONSTANT(spin_sprite_y-0*20)] := CONSTANT((32-20)<<7)
  long[CONSTANT(spin_sprite_s-0*20)] := CONSTANT(4<<8 + 16)
  long[CONSTANT(spin_sprite_a-0*20)] := CONSTANT((@cursor000+_memstart)<<16 + (3<<4))

  ' next sprite (1):
  ' This defines a sprite at coordinate 60,80, of size 16x16, using pixel data from @cursor000,
  ' and displaying the 2nd animation frame
  long[CONSTANT(spin_sprite_x-1*20)] := CONSTANT((200-8)<<7)
  long[CONSTANT(spin_sprite_y-1*20)] := CONSTANT((24-20)<<7)
  long[CONSTANT(spin_sprite_s-1*20)] := CONSTANT(4<<8 + 16)
  long[CONSTANT(spin_sprite_a-1*20)] := CONSTANT((@cursor000+_memstart)<<16 + (3<<4))

  long[CONSTANT(spin_sprite_x-2*20)] := CONSTANT((218-8)<<7)
  long[CONSTANT(spin_sprite_y-2*20)] := CONSTANT((24-20)<<7)
  long[CONSTANT(spin_sprite_s-2*20)] := CONSTANT(4<<8 + 16)
  long[CONSTANT(spin_sprite_a-2*20)] := CONSTANT((@cursor000+_memstart)<<16 + (3<<4))

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
' use cr
divide                  shl r7, #15
                        mov cr, #16
:loop                   cmpsub r6, r7 wc
                        rcl r6, #1
                        djnz cr, #:loop
                        
                        mov r7, r6
                        shl r6, #16
                        shr r6, #16
                        shr r7, #16
divide_ret              ret


' Multiply r6 by r7, return result (r6 * r7) into r7
' use cr
multiply                shl r6, #16
                        mov cr, #16
                        shr r7, #1 wc
:loop         if_c      add r7, r6 wc
                        rcr r7, #1 wc
                        djnz cr,#:loop                   
multiply_ret            ret                                           

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
                        
' Here, we have to set a cog register for every global hub memory that we want to access
request_scanline        long spin_request_scanline
vertical_scroll         long spin_vertical_scroll
horizontal_scroll       long spin_horizontal_scroll
top_y_adr               long spin_top_y
bottom_y_adr            long spin_bottom_y
stop_y_adr              long spin_stop_y
fields_adr              long spin_fields_adr
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
gamepad_adr_old         long 1 ' copy of gamepad_adr to detect if a direction button is still pressed

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
main_loop
                        ' Debug led flicker tester: enable this to see if your main loop is working.
                        ' Enabling this line will make the debug LED flicker at 60 hz (pretty fast).
                        'xor outa, #1           

                        ' Simple code example:
                        ' Read info of sprite 1
                        ' Hint: Change #1 for #0 to move sprite 0 instead. Easy isn't it? :)
                        mov r0, #1
                        call #readspriteinfo

                   
                        ' Call in another chunk of code!
                        ' WARNING: do NOT try to put this piece of code inside a call!
                        ' Doing so will crash your game, because remember that call internaly
                        ' works by using self-modifying code to jump back when doing ret.
                        ' Since the loader kernel replace all memory with the next chunk,
                        ' the self-modifyed ret value will get overwritten.
                        mov    __loader_page, #(_memstart+@GAMEPROCESS_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@GAMEPROCESS_START)         
                        mov    __loader_size, #(GAMEPROCESS_END-GAMEPROCESS_START)
                        mov    __loader_jmp, #GAMEPROCESS_START
                        jmpret __loader_ret,#__loader_call
 

                        ' Wait for VBL
                        call #waitvbl

                        ' Increment our game variable framecount.
                        ' Since this variable is stored in 'permanent' cog memory,
                        ' we don't have to backup-it in HUB.
                        add framecount, #1                        

                        jmp #main_loop

' Here, we can declare temporary cog registers.
' They will be destroyed whenever we load a different chunk of assembly code.
' So rule of thumb:
'   All permanent/shared info should be stored in the first 100-long of cog memory described above.
'   ALL cog registers defined here will be destroyed/filled with crap every time a code chunk gets loaded.
main_temporary          long 0

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

                        ' Read in sprite 0
                        mov r0, #0
                        call #readspriteinfo
                       
                        rdlong r0, sprite_x_adr
                        rdlong r1, sprite_y_adr
                        rdlong r2, gamepad_adr
                        mov r3, #16
                        shr r0, #7
                        mov r4, #24
                        shr r1, #7
                        cmp r2,gamepad_adr_old wz, wc
              if_z      jmp #GP_END

                        mov r6, r1                          
                        mov r7, #16
                        call #divide ' y/16
                        mov r7, #16                        
                        call #multiply ' y*16
                        rdlong r5, tilemap_adr
                        add r5, #32 'offset                         
                        add r5, r7 ' add y
                        add r5, #8 ' middle of sprite
                        mov r6,r0
                        mov r7, #16
                        call #divide
                        add r5, r6 ' add x
                        add r5, #8 ' middle of sprite
                        rdbyte r6,r5 ' read number of tile
                        mov r8, r6
                        mov r7, #2
                        call #divide
                        cmp r7, #0 wz, wc ' unvisited tiles have uneven number
               if_z     jmp #MOVE
               ' change tile colours
                        mov cr, #0
                        cmp r8, #11 wz, wc
               if_z     mov cr, r5               
                        add r8, #1
                        wrbyte r8, r5
                        add  r5, #1
                        rdbyte r8, r5
                        add r8, #1
                        wrbyte r8, r5
                        cmp cr, #0 wz 'tile 11 is handled differently
              if_z      jmp #MOVE
                        mov r5, cr
                        sub r5, #16
                        rdbyte r8, r5
                        add r8, #1
                        wrbyte r8, r5
                        add r5, #1
                        rdbyte r8, r5
                        add r8, #1
                        wrbyte r8, r5
                        
                                                
MOVE                    test r2, #NES_RIGHT wz
              if_z      jmp #LEFT
                        add r0,r3
                        sub r1,r4
LEFT                    test r2, #NES_LEFT wz
              if_z      jmp #DOWN
                        sub r0,r3  ' x=x-16
                        add r1,r4  ' y=y+24                        
DOWN                    test r2, #NES_DOWN wz
              if_z      jmp #UP
                        add r0, r3
                        add r1, r4                        
UP                      test r2, #NES_UP wz
              if_z      jmp #CHECK_MOVE
                        sub r0, r3
                        sub r1, r4

CHECK_MOVE              mov r6, r1                          
                        mov r7, #16
                        call #divide ' y/16
                        mov r7, #16                        
                        call #multiply ' y*16
                        rdlong r5, tilemap_adr
                        add r5, #32 'offset                         
                        add r5, r7  ' add y
                        add r5, #8 ' middle of sprite
                        mov r6,r0
                        mov r7, #16
                        call #divide
                        add r5, r6 ' add x
                        add r5, #8 ' middle of sprite
                        rdbyte r6,r5 ' read number of tile                        
                        cmp r6, #0 wz ,wc
               if_ne    jmp #GP_END
                        
                        test r2, #NES_RIGHT wz
              if_z      jmp #VETOL
VETOR                   sub r0,r3
                        add r1,r4
                        jmp #GP_END                         
VETOL                   test r2, #NES_LEFT wz
              if_z      jmp #VETOD
                        add r0,r3
                        sub r1,r4
                        jmp #GP_END
VETOD                   test r2, #NES_DOWN wz
              if_z      jmp #VETOU
                        sub r0,r3
                        sub r1,r4
                        jmp #GP_END                        
VETOU                   test r2, #NES_UP wz
              if_z      jmp #GP_END
                        add r0,r3
                        add r1,r4          
GP_END
' set visited cube
                        mov r6, r1 ' y
                        sub r6, #12 ' y - startoffset
                        mov r7, #24
                        call #divide                          
                        mov r3, r6  'r3=y
                        mov r7, #2
                        call #divide
                        mov r5, #0
                        cmp r7, #0 wz,wc                        
                  if_e  jmp #EVEN
                        mov r5, #1 'if (row==even) x=x-1
EVEN                        
                        mov r6, r0  ' x
                        mov r7, #32
                        call #divide                        
                        mov r4, r6 ' r4=x
                        mov r6, r3
                        mov r7, #7
                        call #multiply
                        add r7, r4 ' y*7+x
                        sub r7, r5 
                        rdlong r5, fields_adr
                        add r5, r7
                        mov r7, #2
                        wrbyte r7, r5
                        
                        rdlong r5, fields_adr
                        mov cr, #49                      
COMPLETE_LOOP           rdbyte r6, r5
                        add r5, #1
                        cmp r6, #1 wz, wc
                if_e    jmp   #CONTINUE_GAME                        
                        djnz cr, #COMPLETE_LOOP

                        mov r6, r1                          
                        mov r7, #16
                        call #divide ' y/16
                        mov r7, #16                        
                        call #multiply ' y*16
                        rdlong r5, tilemap_adr
                        add r5, #32 'offset                         
                        add r5, r7  ' add y
                        add r5, #8 ' middle of sprite
                        mov r6, r0
                        mov r7, #16
                        call #divide
                        add r5, r6 ' add x
                        add r5, #8 ' middle of sprite
                        rdbyte r8,r5 ' read number of tile
               ' change tile colours
                        mov cr, #0
                        cmp r8, #11 wz, wc
               if_z     mov cr, r5               
                        add r8, #1
                        wrbyte r8, r5
                        add  r5, #1
                        rdbyte r8, r5
                        add r8, #1
                        wrbyte r8, r5
                                                
                        shl r0, #7
                        shl r1, #7
                        wrlong r0, sprite_x_adr
                        wrlong r1, sprite_y_adr
                        call #LEVEL_COMPLETE
CONTINUE_GAME           shl r0, #7
                        shl r1, #7
                        wrlong r0, sprite_x_adr
                        wrlong r1, sprite_y_adr
                        mov gamepad_adr_old,r2                                                                        
                                                
                        ' VERY IMPORTANT: You need to do this jmp to return back to the calling code.
                        jmp   #__loader_return

LEVEL_COMPLETE          call #WASTETIME                        
                        rdlong r5, tilemap_adr
                        add r5, #32 'offset
                        mov r8, #192                        
LEVEL_COMPLETE_LOOP     rdbyte r4, r5
                        cmp r4, #0 wz
              if_z      jmp #LEVEL_COMPLETE_CONT 'skip empty (0) tiles
                        mov r6, r4
                        mov r7, #2
                        call #divide
                        cmp r7, #0 wz, wc              
              if_nz     jmp #LEVEL_COMPLETE_CONT 
                        sub r4, #1               ' reset tile (tile-=1) if tile # == odd
                        wrbyte r4, r5
LEVEL_COMPLETE_CONT     
                        add r5, #1
                        djnz r8, #LEVEL_COMPLETE_LOOP
                                                
                        mov cr, #49
                        rdlong r5, fields_adr
LEVEL_COMPLETE_F_LOOP   rdbyte r6, r5
                        cmp r6, #2 wz, wc
                        mov r6, #0
              if_e      mov r6, #1
                        wrbyte r6, r5
                        add r5, #1                        
                        djnz cr, #LEVEL_COMPLETE_F_LOOP            
                        mov r0, #120 ' reset position
                        mov r1, #12
LEVEL_COMPLETE_RET      ret

WASTETIME               mov cr, #180 
WASTETIME_LOOP          call #waitvbl
                        djnz cr, #WASTETIME_LOOP
                        
WASTETIME_RET           ret

                      
GAMEPROCESS_END


fit 440

' END OF GAME CODE -----------
cr                      long                    $0


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
r8                      long                    $0
lives                   long                    $0
score                   long                    $0
time                    long                    $0
period                  long                    22000000

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

cursor000 long $00000000,$00000000,$00000000,$00000000,$00010100,$00000000,$00000000,$00010101
        long $01010101,$00000000,$00000000,$01019B01,$01019B01,$00000000,$00000000,$019B0100
        long $00019B01,$00000000,$00000000,$019B0100,$00019B01,$00000000,$00000000,$019B0100
        long $01019B01,$00000000,$00000000,$019B9B01,$019B9B01,$00000101,$00000000,$019B9B01
        long $9B9B9B01,$0101019B,$01010101,$019B9B01,$9B9B9B01,$9B9B9B9B,$9B9B9B9B,$019B9B9B
        long $9B9B0101,$9B9B9B9B,$9B9B9B9B,$01019B9B,$01010100,$9B9B9B9B,$9B9B9B9B,$0000019B
        long $01000000,$9B9B9B01,$9B9B9B9B,$00000001,$01000000,$9B9B9B01,$019B9B9B,$00000001
        long $00000000,$9B9B9B01,$01019B9B,$00000000,$00000000,$01010101,$00010101,$00000000
        long $00000000,$00000000,$00000000,$00000000,$01000000,$00010101,$01010100,$00000001
        long $01010000,$00019B9B,$9B9B0100,$00000101,$01010000,$019B9B9B,$9B010100,$0000019B
        long $9B010000,$01019B9B,$9B010100,$0000019B,$9B010000,$0001019B,$01000000,$0000019B
        long $9B010100,$0000019B,$01000000,$0000019B,$9B9B0100,$0000019B,$01000000,$0000019B
        long $9B010100,$0101019B,$01010101,$0000019B,$9B010000,$9B9B9B9B,$9B9B9B9B,$0000019B
        long $9B010000,$9B9B9B9B,$9B9B9B9B,$0000019B,$01010000,$9B9B9B9B,$9B9B9B9B,$0000019B
        long $01000000,$9B9B9B01,$9B9B9B9B,$00000101,$01000000,$9B9B9B01,$019B9B9B,$00000001
        long $00000000,$9B9B9B01,$01019B9B,$00000000,$00000000,$01010101,$00010101,$00000000
        long $00000001,$00000000,$00000000,$00000000,$00000101,$00000000,$00000000,$00000000
        long $00010501,$00000000,$00000000,$00000000,$0105AA01,$00000000,$00000000,$00000000
        long $059CAA01,$00000001,$00000000,$00000000,$9C9CAA01,$00000105,$00000000,$00000000
        long $9C9CAA01,$0001059C,$00000000,$00000000,$9C9CAA01,$01059C9C,$00000000,$00000000
        long $9C9CAA01,$05AAAAAA,$00000001,$00000000,$01AAAA01,$01010101,$00000000,$00000000
        long $0001AA01,$00000101,$00000000,$00000000,$00000101,$00010100,$00000000,$00000000
        long $00000000,$01010000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
        long $00000000,$BABABABA,$00C9C9C9,$00000000,$BABA0000,$BACACACA,$C9C9C9C9,$000000C9
        long $CABABA00,$BACACA05,$C9C9C9C9,$0000B9B9,$05CABABA,$BABACACA,$C9C9C9C9,$00B9B9B9
        long $CACABAC9,$C9BABACA,$C9C9C9C9,$00C8B9B9,$CABABAC9,$C9C9BABA,$B9C9C9C9,$C8C8C8B9
        long $BABABAC9,$C9C9C9BA,$B9B9C9C9,$C8C8C8C8,$C9C9C9C9,$B9C9C9C9,$C8B9B9B9,$C8C8C8C8
        long $C9C9C9B9,$B9B9C9C9,$C8B9C8C8,$C8C8C8C8,$C9C9C9C8,$C8B9B9C9,$C8C8B9B9,$C8C8C8C8
        long $B9B9C8C8,$B9C8B9B9,$C8C8C8C8,$01C8C8C8,$C8C8C800,$C8C8C8C8,$C8C8C8C8,$00C8C8C8
        long $C8C80000,$C8C8C8C8,$C8C8C8C8,$0001C8C8,$C8000000,$C8C8C8C8,$C8C8C8C8,$00000101
        long $00000000,$0101B800,$01010101,$00000000,$00000000,$00000000,$00000000,$00000000