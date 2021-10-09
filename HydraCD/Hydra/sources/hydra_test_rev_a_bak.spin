' /////////////////////////////////////////////////////////////////////////////
'
' File: HYDRA_TEST_REV_A.SPIN
'
' Author: Andre' LaMothe, Nurve Networks LLC, ceo@nurve.net
'
' Last modified: 8.28.06, Revision A, version 1.0
'
' Description: This programs tests the HYDRA game console and Propeller, uses 8 COGS, the following test procedure should be used:
'
' Step 1: With Hydra on test bench, plug in power adapter, mouse, keyboard, and gamepad (into left port) along with
' A/V cable into stadard tube based NTSC TV (not LCD / PLASMA). Finally, plug VGA monitor in VGA port and make sure VGA enable SWITCH
' at J10 is "ON" for test. Turn the HYDRA on, the blue power LEDs should both be on at D1 and D2, this confirms the 3.3 / 5.0V supplies.
'
' Step 2: Plug in USB cable into USB programming port, launch Propeller IDE version .98xx and load this program with F10 into HYDRA,
' you should see the USB transmit TX (green) and receive RX (red) LEDS flicker as the program loads, make certain they LEDs work
' and are the correct colors, TX (green), RX (red). 
'
' Step 3: You should see the system test suite program run, and a color palette on the screen, the image you should see should be similar
' to the image found in the accompanying file HYDRA_TEST_REV_A.JPG, the following tests verify all the hardware is working: 
' 
' Step 4: VIDEO TEST - Verify that the image is stable and you can see all the colors in the rainbow purples, blues, reds, violets,
' left to right. Also, you should see 6 grays under the palette. Its ok, if the text is hard to read, its very small!
'
' Step 5: AUDIO TEST - You should hear the sound of a "car engine" during the test, as you move the mouse to the right RPMs will change.  
'
' Step 6: MOUSE TEST - move the mouse around and you will see the mouse cursor itself (plus sign) move around as well as its coordinates
' printed next to the word MOUSE, also, as you move the mouse around it will draw on the screen like a paint program :)
'
' Step 7: KEYBOARD TEST -  press keys on the keyboard, you will see the hex codes print next to the word KEYBOARD.
'
' Step 8: GAMEPAD TEST - Make sure the game pad is plugged into the left port 0, you should see the GREEN LED at D5 light up at
' the top right corner of the port. Press buttons on the gamepad, you should see the GAMEPAD display on the screen indicate bit
' patterns. If you unplug the gamepad, the value $FF will display, which means "unplugged". 
'
' Step 9: VGA TEST - The VGA driver should be displaying a color palette on the VGA monitor during the entire time with gray borders.
' This confirms if VGA is working.
'
' Step 10: DEBUG LED TEST - The debug LED (red) to the bottom left of the Propeller chip (d4) should be glowing RED during the entire
' test procedure, visually verify this.
'
'
' Congratulations! The HYDRA works! This concludes the test.
'
' /////////////////////////////////////////////////////////////////////////////


CON

  _clkmode = xtal1 + pll8x  ' ?
  _xinfreq = 10_000_000 + 0000 ' Set to 10Mhz and add 5000 to fix crystal imperfection of hydra prototype
  _stack = ($3000 + 100) >> 2   'accomodate display memory and stack

  x_tiles = 16 ' Number of horizontal tiles (each tile is 16x16), so this means 256 pixel
  y_tiles = 12 ' Number of vertical tiles, this means 192 pixel. Resolution is 256x192.

  paramcount = 14       
  display_base = $5000 ' This is the 'front buffer': this is the memory that gets displayed on the screen


  vga_params = 21
  vga_cols   = 16
  vga_rows    = 16
  vga_screensize = vga_cols * vga_rows
  

VAR

  long mousex, mousey

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

  word screen[x_tiles * y_tiles]
  long colors[64]
  byte tube1
  byte tube2
  long nes_buttons

  long  sd_pin                  ' desired pin to output sound on
  long  sd_freq                 ' frequency of sound (related to frequency actually)
  long  sd_volume               ' volume of sound

    
  long  vga_status      'status: off/visible/invisible  read-only       (21 contiguous longs)
  long  vga_enable      'enable: off/on                 write-only
  long  vga_pins        'pins: byte(2),topbit(3)        write-only
  long  vga_mode        'mode: interlace,hpol,vpol      write-only
  long  vga_videobase   'video base @word               write-only
  long  vga_colorbase   'color base @long               write-only              
  long  vga_hc          'horizontal cells               write-only
  long  vga_vc          'vertical cells                 write-only
  long  vga_hx          'horizontal cell expansion      write-only
  long  vga_vx          'vertical cell expansion        write-only
  long  vga_ho          'horizontal offset              write-only
  long  vga_vo          'vertical offset                write-only
  long  vga_hd          'horizontal display pixels      write-only
  long  vga_hf          'horizontal front-porch pixels  write-only
  long  vga_hs          'horizontal sync pixels         write-only
  long  vga_hb          'horizontal back-porch pixels   write-only
  long  vga_vd          'vertical display lines         write-only
  long  vga_vf          'vertical front-porch lines     write-only
  long  vga_vs          'vertical sync lines            write-only
  long  vga_vb          'vertical back-porch lines      write-only
  long  vga_rate        'pixel rate (Hz)                write-only

  word  vga_screen[vga_screensize]

  long  vga_col, vga_row, vga_color


OBJ

  tv      : "tv_drv_010.spin"                     ' tv driver
  mouse   : "mouse_iso_010.spin"                  ' mouse driver
  key     : "keyboard_iso_010.spin"               ' instantiate a keyboard object
  glow    : "glow_led_001.spin"                   ' glowing led driver
  gp      : "gamepad_drv_001.spin"                ' gamepad driver
  sd      : "sound_engine_drv_011.spin"           ' import the "engine" sound driver
  vga     : "vga_drv_010.spin"                    ' import VGA driver
     
PUB start      | i, j, k, kk, dx, dy, pp, pq, rr, numx, numchr, curr_key, glow_rate
  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  'init color table.
  ' Each entry defines 4 colors (1 byte each), each byte being defined as described in the 'tv_drv_010'
  
  repeat i from 0 to 255 step 4
    byte[@colors][i]   := (((i>>2) & $0f)<<4) + ((i>>6)) + $A   ' color 0 contains ranged color tone
    byte[@colors][i+1] := (((i>>2) & $0f)<<4) + $E ' color 1 contains the brightess color tone
    byte[@colors][i+2] := $7 ' color 2 always white
    byte[@colors][i+3] := $2 + ((i>>2) & $7) ' color 3 contains from black to white

  'init tile screen
  ' screen is defined as a 2D array of tile(x,y), each value being a 10-bit memory address divided by 64 (>>6)
  ' (each tile using 16x16x2bpp = 64 bytes per tile)
  ' and a color-table entry from 0..63 shifted by <<10

  ' Here, the color table is setup so that each tile will use a different 4-color-palette entry
  repeat dx from 0 to x_tiles * y_tiles
    screen[dx] := display_base >> 6 + dx
    if dx < 64
       screen[dx] += (dx << 10)

  ' Then the grayscale ramp
  repeat dx from 0 to 5
    screen[6 * x_tiles + dx] += (dx << 10)

  ' And the final color band
  repeat dx from 0 to 15
    screen[4 * x_tiles + dx] += (dx << 10)
  
  'start mouse
  mouse.start(2)

  'start keyboard on pingroup 3 
  key.start(3)

  ' start glowing led
  glow_rate := $800
  glow.start(@glow_rate)

  ' start NES game pad task to read gamepad values
  gp.start

  repeat dx from 0 to 95 step 4
    repeat dy from 96 to 112
      put4pixel(dx, dy, 3)

  repeat dx from 0 to 255 step 4
    repeat dy from 64 to 80
      put4pixel(dx, dy, 1)

  ' Draw color boxes
  repeat dx from 0 to 255
    repeat dy from 0 to 80 step 16
      putpixel(dx, dy, 2)
  repeat dx from 0 to 255 step 16
    repeat dy from 0 to 80
      putpixel(dx, dy, 2)
  repeat dy from 0 to 80
    putpixel(255, dy, 2)

  repeat dx from 0 to 96
    repeat dy from 96 to 112 step 16
      putpixel(dx, dy, 2)
  repeat dx from 0 to 96 step 16
    repeat dy from 96 to 112
      putpixel(dx, dy, 2)

  ' initial mouse position
  mousex := 256/2
  mousey := 192/2 + 64

  'set up parms and start sound engine playing
  sd_pin    := 7                ' pin 7 (hydra sound pin)
  sd_freq   := $00400000        ' anything lower than this sounds like poping
  sd_volume := $FFFF            ' volume $0000-FFFF (max), however, volume not used in this version of driver
  sd.start(@sd_pin)             ' start the "engine" sound driver


  ' vga output
  longmove(@vga_status, @vgaparams, vga_params)
  vga_pins      := %10111
  vga_videobase := @vga_screen  
  vga_colorbase := @TilePalette
  
  vga.start(@vga_status)
  
  repeat i from 0 to 255
    vga_screen[i] := @Tile000>>6 + (byte[@tileMap + (i&63)]<<10)

  ' print static strings

  ' color
  printstring(10, 86, @strColor, 2)
   
  ' mouse
  printstring(10, 120, @strMouse, 2)
   
  ' keyboard
  printstring(10, 130, @strKeyboard, 2)
   
  ' gamepads
  printstring(10, 140, @strGamepad, 2)
   
  ' logo
  printstring(10, 180, @strLogo, 1)


  ' main event loop
  repeat

    mousex := mousex + mouse.delta_x #> 4 <# 251
    mousey := mousey - mouse.delta_y #> 4 <# 188
        
    putpixel(mousex,   mousey,  1)
    putpixel(mousex+1, mousey,  1)
    putpixel(mousex-1, mousey,  1)
    putpixel(mousex,   mousey+1,1)
    putpixel(mousex,   mousey-1,1)

    if mousey < 80
      printbytehex(60, 86, ((mousex>>4)<<4) + $A + (mousey>>4), 2)
    
    if mousey > 96 and mousey < 112 and mousex < 96
      printbytehex(60, 86, (mousex>>4) + $2, 2)

    ' update sound
    sd_freq += mouse.delta_x << 18

    ' don't let sd_freq below $00400000
    if (sd_freq < $00400000)
      sd_freq := $00400000

    ' get key    
    if (key.gotkey==TRUE)
      curr_key := key.getkey

    ' get nes controller button
    nes_buttons := gp.read                                 

     ' print dynamic displays

   ' mouse
    printbytehex(10+88, 120, mousex, 2)
    printbytehex(10+88+16, 120, mousey, 2)
   
   ' keyboard
    printbytehex(10+88, 130, curr_key, 2)

   ' gamepad
   printbytehex(10+88, 140, nes_buttons & $00FF, 2)
    
    waitcnt(CNT + 2000)

' ' putpixel: Put a pixel on the screen, assuming the current tilemap is ordered from 0..x to 0..y tiles
' x must be between 0 and h_tiles
' y must be between 0 and v_tiles
' c must be between 0 and 3
PUB putpixel(x, y, c) | temp
  temp := ((x&!15)<<2) + ((x&15) >> 2) + ((y&15)<<2) + ((y&!15)<<6)
  byte[display_base][temp] := byte[display_base][temp] & !(3<<((x & 3)<<1)) + c<<((x & 3)<<1)

' ' put4pixel: Put 4 pixels on the screen, assuming the current tilemap is ordered from 0..x to 0..y tiles
' x must be between 0 and h_tiles
' y must be between 0 and v_tiles
' c must be between 0 and 3
PUB put4pixel(x, y, c) | temp
  temp := ((x&!15)<<2) + ((x&15) >> 2) + ((y&15)<<2) + ((y&!15)<<6)
  byte[display_base][temp] := c + (c<<2) + (c<<4) + (c<<6)

' ' getbytepixel: Get one byte (4 pixels) on the screen
PUB getbytepixel(x, y) : pixel
  pixel := byte[display_base][((x&!15)<<2) + ((x&15) >> 2) + ((y&15)<<2) + ((y&!15)<<6)]

' ' putbytepixel: Put one byte (4 pixels) on the screen
PUB putbytepixel(x, y, pixel)
  byte[display_base][((x&!15)<<2) + ((x&15) >> 2) + ((y&15)<<2) + ((y&!15)<<6)] := pixel

' ' printhex: Print a 32-bit hexadecimal number
PUB printhex(x, y, num) | i,i2,temp
    repeat i from 0 to 7
      temp := num & $f
      num := num >> 4
      repeat i2 from 0 to 4
        putbytepixel(x + i*4, y + i2, byte[@numbers][temp*5 + i2])

' ' printbytehex: Print a 8-bit hexadecimal number
PUB printbytehex(x, y, num, k) | i,i2,temp
    repeat i from 0 to 1
      temp := num & $f
      num := num >> 4
      repeat i2 from 0 to 4
        putbytepixel(x + i*4*k, y + i2, byte[@numbers][temp*5 + i2])


' ' printstring: Print a ASCIIZ string
PUB printstring(x, y, string_ptr, k) | i,i2,temp, ch
    repeat i from 0 to strsize(string_ptr)-1

      ch := byte[string_ptr][i]
      case ch 
        32: ' space
          ch := 0
        46: ' period .
          ch := 1

        58: ' colon  :
          ch := 2

        44: ' comma  ,
          ch := 3
              
        40: ' left paren (
          ch := 4
          
        41: ' right paren )
          ch := 5

        45: ' minus -
          ch := 6

        47: ' slash /
          ch := 7

        48..57: ' 0-9
          ch := ch - 48 + 8

        65..90: ' A-Z
          ch := ch - 65 + 8 + 10
           
      repeat i2 from 0 to 4
        putbytepixel(x + i*4*k, y + i2, byte[@charset][ch*5 + i2])



DAT


' /////////////////////////////////////////////////////////////////////////////

tvparams                long    0               'status
                        long    1               'enable
                        long    %011_0000       'pins
                        long    %0000           'mode
                        long    0               'screen
                        long    0               'colors
                        long    x_tiles         'hc
                        long    y_tiles         'vc
                        long    10              'hx
                        long    1               'vx
                        long    0               'ho
                        long    0               'vo
                        long    60_000_000'_xinfreq<<4  'broadcast
                        long    0               'auralcog

' /////////////////////////////////////////////////////////////////////////////

strMouse                byte "MOUSE:",0
strKeyboard             byte "KEYBOARD:", 0
strGamepad              byte "GAMEPAD0:",0
strGamepadUnplugged     byte "UNPLUGGED",0
strColor                byte "COLOR:",0
strLogo                 byte "HYDRA TEST SUITE, REV. A, VER. 1.0 -  NURVE/PARALLAX 8.28.06", 0

' /////////////////////////////////////////////////////////////////////////////

numbers                 byte    %%2222          ' 0
                        byte    %%2002
                        byte    %%2002
                        byte    %%2002
                        byte    %%2222

                        byte    %%0020          ' 1
                        byte    %%0022
                        byte    %%0020
                        byte    %%0020
                        byte    %%0020

                        byte    %%2222          ' 2
                        byte    %%2000
                        byte    %%2222
                        byte    %%0002
                        byte    %%2222

                        byte    %%2222          ' 3
                        byte    %%2000
                        byte    %%2222
                        byte    %%2000
                        byte    %%2222

                        byte    %%2002          ' 4
                        byte    %%2002
                        byte    %%2222
                        byte    %%2000
                        byte    %%2000

                        byte    %%2222          ' 5 
                        byte    %%0002
                        byte    %%2222
                        byte    %%2000
                        byte    %%2222

                        byte    %%2222          ' 6
                        byte    %%0002
                        byte    %%2222
                        byte    %%2002
                        byte    %%2222

                        byte    %%2222          ' 7
                        byte    %%2000    
                        byte    %%2000   
                        byte    %%0200     
                        byte    %%0200     

                        byte    %%2222          ' 8
                        byte    %%2002
                        byte    %%2222
                        byte    %%2002
                        byte    %%2222

                        byte    %%2222          ' 9
                        byte    %%2002
                        byte    %%2222
                        byte    %%2000
                        byte    %%2000

                        byte    %%2222          ' A
                        byte    %%2002
                        byte    %%2222
                        byte    %%2002
                        byte    %%2002

                        byte    %%0002          ' B
                        byte    %%0002
                        byte    %%2222
                        byte    %%2002
                        byte    %%2222

                        byte    %%2222          ' C
                        byte    %%0002
                        byte    %%0002
                        byte    %%0002
                        byte    %%2222

                        byte    %%2000          ' D
                        byte    %%2000
                        byte    %%2222
                        byte    %%2002
                        byte    %%2222

                        byte    %%2222          ' E
                        byte    %%0002
                        byte    %%0222
                        byte    %%0002
                        byte    %%2222

                        byte    %%2222          ' F
                        byte    %%0002
                        byte    %%0222
                        byte    %%0002
                        byte    %%0002



charset                 byte    %%0000          ' space, 32
                        byte    %%0000
                        byte    %%0000
                        byte    %%0000
                        byte    %%0000

                        byte    %%0000          ' . , 46
                        byte    %%0000
                        byte    %%0000
                        byte    %%0000
                        byte    %%0020

                        byte    %%0000          ' :  , 58
                        byte    %%0200
                        byte    %%0000
                        byte    %%0000
                        byte    %%0200

                        byte    %%0000          ' ,  , 44
                        byte    %%0000
                        byte    %%0000
                        byte    %%0200
                        byte    %%0020

                        byte    %%0220          ' (  , 40
                        byte    %%0002
                        byte    %%0002
                        byte    %%0002
                        byte    %%0220

                        byte    %%0220          ' )  , 41
                        byte    %%2000
                        byte    %%2000
                        byte    %%2000
                        byte    %%0220

                        byte    %%0000          ' -  , 45
                        byte    %%0000
                        byte    %%2220
                        byte    %%0000
                        byte    %%0000

                        byte    %%0000          ' /  , 47
                        byte    %%2000
                        byte    %%0200
                        byte    %%0020
                        byte    %%0002

                        byte    %%2222          ' 0, 48
                        byte    %%2002
                        byte    %%2002
                        byte    %%2002
                        byte    %%2222

                        byte    %%0020          ' 1
                        byte    %%0022
                        byte    %%0020
                        byte    %%0020
                        byte    %%0020

                        byte    %%2222          ' 2
                        byte    %%2000
                        byte    %%2222
                        byte    %%0002
                        byte    %%2222

                        byte    %%2222          ' 3
                        byte    %%2000
                        byte    %%2222
                        byte    %%2000
                        byte    %%2222

                        byte    %%2002          ' 4
                        byte    %%2002
                        byte    %%2222
                        byte    %%2000
                        byte    %%2000

                        byte    %%2222          ' 5 
                        byte    %%0002
                        byte    %%2222
                        byte    %%2000
                        byte    %%2222

                        byte    %%2222          ' 6
                        byte    %%0002
                        byte    %%2222
                        byte    %%2002
                        byte    %%2222

                        byte    %%2222          ' 7
                        byte    %%2000    
                        byte    %%2000   
                        byte    %%0200     
                        byte    %%0200     

                        byte    %%2222          ' 8
                        byte    %%2002
                        byte    %%2222
                        byte    %%2002
                        byte    %%2222

                        byte    %%2222          ' 9
                        byte    %%2002
                        byte    %%2222
                        byte    %%2000
                        byte    %%2000



                        byte    %%2222          ' A, 65
                        byte    %%2002
                        byte    %%2222
                        byte    %%2002
                        byte    %%2002

                        byte    %%0002          ' B
                        byte    %%0002
                        byte    %%2222
                        byte    %%2002
                        byte    %%2222

                        byte    %%2222          ' C
                        byte    %%0002
                        byte    %%0002
                        byte    %%0002
                        byte    %%2222

                        byte    %%0222          ' D
                        byte    %%2002
                        byte    %%2002
                        byte    %%2002
                        byte    %%0222

                        byte    %%2222          ' E
                        byte    %%0002
                        byte    %%0222
                        byte    %%0002
                        byte    %%2222

                        byte    %%2222          ' F
                        byte    %%0002
                        byte    %%0222
                        byte    %%0002
                        byte    %%0002

                        byte    %%2220         ' G
                        byte    %%0002
                        byte    %%2222
                        byte    %%2002
                        byte    %%2222

                        byte    %%2002          ' H
                        byte    %%2002
                        byte    %%2222
                        byte    %%2002
                        byte    %%2002

                        byte    %%2220          ' I
                        byte    %%0200
                        byte    %%0200
                        byte    %%0200
                        byte    %%2220

                        byte    %%0002          ' J
                        byte    %%0002
                        byte    %%0002
                        byte    %%2002
                        byte    %%0220

                        byte    %%0202          ' K
                        byte    %%0022
                        byte    %%0022
                        byte    %%0202
                        byte    %%2002

                        byte    %%0002          ' L
                        byte    %%0002
                        byte    %%0002
                        byte    %%0002
                        byte    %%2222

                        byte    %%2002          ' M
                        byte    %%2222
                        byte    %%2202
                        byte    %%2002
                        byte    %%2002

                        byte    %%2002          ' N
                        byte    %%2002
                        byte    %%2022
                        byte    %%2202
                        byte    %%2002

                        byte    %%0220          ' O
                        byte    %%2002
                        byte    %%2002
                        byte    %%2002
                        byte    %%0220

                        byte    %%2222          ' P
                        byte    %%2002
                        byte    %%2222
                        byte    %%0002
                        byte    %%0002

                        byte    %%0220           ' Q
                        byte    %%2002
                        byte    %%2002
                        byte    %%0220
                        byte    %%2000

                        byte    %%0222           ' R
                        byte    %%2002
                        byte    %%0222
                        byte    %%0202
                        byte    %%2002

                        byte    %%2220           ' S
                        byte    %%0002
                        byte    %%0220
                        byte    %%2000
                        byte    %%0222

                        byte    %%0222           ' T
                        byte    %%0020
                        byte    %%0020
                        byte    %%0020
                        byte    %%0020

                        byte    %%2002           ' U
                        byte    %%2002
                        byte    %%2002
                        byte    %%2002
                        byte    %%2222

                        byte    %%2002           ' V
                        byte    %%2002
                        byte    %%2002
                        byte    %%0220
                        byte    %%0220

                        byte    %%2002           ' W
                        byte    %%2002
                        byte    %%2002
                        byte    %%2222
                        byte    %%2002

                        byte    %%2002           ' X
                        byte    %%0220
                        byte    %%0220
                        byte    %%0220
                        byte    %%2002

                        byte    %%0202           ' Y
                        byte    %%0202
                        byte    %%0222
                        byte    %%0020
                        byte    %%0020

                        byte    %%2222            'Z
                        byte    %%0200
                        byte    %%0020
                        byte    %%0002
                        byte    %%2222

                        byte    %%0000
                        byte    %%0000
                        byte    %%0000
                        byte    %%0000
                        byte    %%0000

                        byte    %%0000
                        byte    %%0000
                        byte    %%0000
                        byte    %%0000
                        byte    %%0000

                        byte    %%0000
                        byte    %%0000
                        byte    %%0000
                        byte    %%0000
                        byte    %%0000

                        byte    %%0000
                        byte    %%0000
                        byte    %%0000
                        byte    %%0000
                        byte    %%0000


DAT

vgaparams               long    0               'status
                        long    1               'enable
                        long    %00_111         'pins
                        long    %011            'mode
                        long    0               'videobase
                        long    0               'colorbase
                        long    vga_cols        'hc
                        long    vga_rows        'vc
                        long    1               'hx
                        long    1               'vx
                        long    0               'ho
                        long    0               'vo
                        long    256             'hd
                        long    8               'hf
                        long    32              'hs
                        long    96              'hb
                        long    768>>1          'vd
                        long    2               'vf
                        long    8               'vs
                        long    48              'vb
                        long    16_000_000      'rate

'vgacolors              long
                        long    $C030C0DA       'red
                        long    $C0C00000
                        long    $30003000       'green
                        long    $30300000
                        long    $0C000C00       'blue
                        long    $0C0C0000
                        long    $FC00FC00       'white
                        long    $FCFC0000
                        long    $FF80FF80       'red/white
                        long    $FFFF8080
                        long    $FF20FF20       'green/white
                        long    $FFFF2020
                        long    $3C143C14       'blue/white
                        long    $3C3C1414
                        long    $00A800A8       'grey/black
                        long    $0000A8A8
                        long    $C0408080       'redbox
spcl                    long    $30100020       'greenbox
                        long    $3C142828       'cyanbox
                        long    $FC54A8A8       'greybox
                        long    $3C14FF28       'cyanbox+underscore
                        long    0




TileMap        Byte 00
               Byte 01
               Byte 02
               Byte 03
               Byte 04
               Byte 05
               Byte 06
               Byte 07
               Byte 08
               Byte 09
               Byte 10
               Byte 11
               Byte 12
               Byte 13
               Byte 14
               Byte 15
               Byte 16
               Byte 17
               Byte 18
               Byte 19
               Byte 20
               Byte 21
               Byte 22
               Byte 23
               Byte 24
               Byte 25
               Byte 26
               Byte 27
               Byte 28
               Byte 29
               Byte 30
               Byte 31
               Byte 32
               Byte 33
               Byte 34
               Byte 35
               Byte 36
               Byte 37
               Byte 38
               Byte 39
               Byte 40
               Byte 41
               Byte 42
               Byte 43
               Byte 44
               Byte 45
               Byte 46
               Byte 47
               Byte 48
               Byte 49
               Byte 50
               Byte 51
               Byte 52
               Byte 53
               Byte 54
               Byte 55
               Byte 56
               Byte 57
               Byte 58
               Byte 59
               Byte 60
               Byte 61
               Byte 62
               Byte 63
               
               

' Cycle through all 64 VGA Palete colors
TilePalette
long
long %11111111_11111111_11111111_10_10_10_00    ' Set the first to a shade of gray so the bkgrnd picks this up
long %11111111_11111111_11111111_00_00_01_00
long %11111111_11111111_11111111_00_00_10_00
long %11111111_11111111_11111111_00_00_11_00
long %11111111_11111111_11111111_00_01_00_00
long %11111111_11111111_11111111_00_01_01_00
long %11111111_11111111_11111111_00_01_10_00
long %11111111_11111111_11111111_00_01_11_00
long %11111111_11111111_11111111_00_10_00_00
long %11111111_11111111_11111111_00_10_01_00
long %11111111_11111111_11111111_00_10_10_00
long %11111111_11111111_11111111_00_10_11_00
long %11111111_11111111_11111111_00_11_00_00
long %11111111_11111111_11111111_00_11_01_00
long %11111111_11111111_11111111_00_11_10_00
long %11111111_11111111_11111111_00_11_11_00

long %11111111_11111111_11111111_01_00_00_00
long %11111111_11111111_11111111_01_00_01_00
long %11111111_11111111_11111111_01_00_10_00
long %11111111_11111111_11111111_01_00_11_00
long %11111111_11111111_11111111_01_01_00_00
long %11111111_11111111_11111111_01_01_01_00
long %11111111_11111111_11111111_01_01_10_00
long %11111111_11111111_11111111_01_01_11_00
long %11111111_11111111_11111111_01_10_00_00
long %11111111_11111111_11111111_01_10_01_00
long %11111111_11111111_11111111_01_10_10_00
long %11111111_11111111_11111111_01_10_11_00
long %11111111_11111111_11111111_01_11_00_00
long %11111111_11111111_11111111_01_11_01_00
long %11111111_11111111_11111111_01_11_10_00
long %11111111_11111111_11111111_01_11_11_00

long %11111111_11111111_11111111_10_00_00_00
long %11111111_11111111_11111111_10_00_01_00
long %11111111_11111111_11111111_10_00_10_00
long %11111111_11111111_11111111_10_00_11_00
long %11111111_11111111_11111111_10_01_00_00
long %11111111_11111111_11111111_10_01_01_00
long %11111111_11111111_11111111_10_01_10_00
long %11111111_11111111_11111111_10_01_11_00
long %11111111_11111111_11111111_10_10_00_00
long %11111111_11111111_11111111_10_10_01_00
long %11111111_11111111_11111111_10_10_10_00
long %11111111_11111111_11111111_10_10_11_00
long %11111111_11111111_11111111_10_11_00_00
long %11111111_11111111_11111111_10_11_01_00
long %11111111_11111111_11111111_10_11_10_00
long %11111111_11111111_11111111_10_11_11_00

long %11111111_11111111_11111111_11_00_00_00
long %11111111_11111111_11111111_11_00_01_00
long %11111111_11111111_11111111_11_00_10_00
long %11111111_11111111_11111111_11_00_11_00
long %11111111_11111111_11111111_11_01_00_00
long %11111111_11111111_11111111_11_01_01_00
long %11111111_11111111_11111111_11_01_10_00
long %11111111_11111111_11111111_11_01_11_00
long %11111111_11111111_11111111_11_10_00_00
long %11111111_11111111_11111111_11_10_01_00
long %11111111_11111111_11111111_11_10_10_00
long %11111111_11111111_11111111_11_10_11_00
long %11111111_11111111_11111111_11_11_00_00
long %11111111_11111111_11111111_11_11_01_00
long %11111111_11111111_11111111_11_11_10_00
long %11111111_11111111_11111111_11_11_11_00






Tile000
long
Long $00000000
Long $00000000
Long $00000000
Long $00000000
Long $00000000
Long $00000000
Long $00000000
Long $00000000
Long $00000000
Long $00000000
Long $00000000
Long $00000000
Long $00000000
Long $00000000
Long $00000000
Long $00000000                        