''*****************************
''*  Rem Color Chart v010     *
''*****************************

' Use this little program along with REM_color_chart.JPG to experiment with colors.

CON

  _clkmode = xtal1 + pll8x  ' ?
  _xinfreq = 10_000_000 + 0_000 ' Set to 10Mhz and add 5000 to fix crystal imperfection of hydra prototype
  _stack = ($3000 + $3000 + 100) >> 2   'accomodate display memory and stack

  x_tiles = 16 ' Number of horizontal tiles (each tile is 16x16), so this means 256 pixel
  y_tiles = 12 ' Number of vertical tiles, this means 192 pixel. Resolution is 256x192.

  paramcount = 14       
  display_base = $5000 ' This is the 'front buffer': this is the memory that gets displayed on the screen

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
  byte previous

OBJ

  tv    : "tv_drv_010.spin"
  mouse : "mouse_iso_010.spin"


PUB start      | i, j, k, kk, dx, dy, pp, pq, rr, numx, numchr
  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  'init color table.
  ' Each entry defines 4 colors (1 byte each), each byte being defined as described in the 'tv_drv_010'
  
  repeat i from 0 to 255 step 4
    byte[@colors][i] := (((i>>2) & $0f)<<4) + ((i>>6)) + $A   ' color 0 contains ranged color tone
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

  repeat
    mousex := mousex + mouse.delta_x #> 0 <# 255
    mousey := mousey - mouse.delta_y #> 0 <# 191

    previous := getbytepixel(mousex, mousey)
    putpixel(mousex, mousey, 2)

    if mousey < 80
      printbytehex(120, 100, ((mousex>>4)<<4) + $A + (mousey>>4))
    
    if mousey > 96 and mousey < 112 and mousex < 96
      printbytehex(120, 100, (mousex>>4) + $2)
    
    waitcnt(CNT + 2000)
    putbytepixel(mousex, mousey, previous)


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
PUB printbytehex(x, y, num) | i,i2,temp
    repeat i from 0 to 1
      temp := num & $f
      num := num >> 4
      repeat i2 from 0 to 4
        putbytepixel(x + i*4, y + i2, byte[@numbers][temp*5 + i2])

DAT

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

numbers                 byte    %%0020
                        byte    %%0202
                        byte    %%0202
                        byte    %%0202
                        byte    %%0020

                        byte    %%0020
                        byte    %%0022
                        byte    %%0020
                        byte    %%0020
                        byte    %%0020

                        byte    %%0222
                        byte    %%0200
                        byte    %%0222
                        byte    %%0002
                        byte    %%0222

                        byte    %%0222
                        byte    %%0200
                        byte    %%0220
                        byte    %%0200
                        byte    %%0222

                        byte    %%0202
                        byte    %%0202
                        byte    %%0222
                        byte    %%0200
                        byte    %%0200

                        byte    %%0222
                        byte    %%0002
                        byte    %%0222
                        byte    %%0200
                        byte    %%0222

                        byte    %%0222
                        byte    %%0002
                        byte    %%0222
                        byte    %%0202
                        byte    %%0222

                        byte    %%0222    
                        byte    %%0200    
                        byte    %%0200   
                        byte    %%0020     
                        byte    %%0020     

                        byte    %%0222
                        byte    %%0202
                        byte    %%0222
                        byte    %%0202
                        byte    %%0222

                        byte    %%0222
                        byte    %%0202
                        byte    %%0222
                        byte    %%0200
                        byte    %%0222

                        byte    %%0222
                        byte    %%0202
                        byte    %%0222
                        byte    %%0202
                        byte    %%0202

                        byte    %%0002
                        byte    %%0002
                        byte    %%0222
                        byte    %%0202
                        byte    %%0222

                        byte    %%0222
                        byte    %%0002
                        byte    %%0002
                        byte    %%0002
                        byte    %%0222

                        byte    %%0200
                        byte    %%0200
                        byte    %%0222
                        byte    %%0202
                        byte    %%0222

                        byte    %%0222
                        byte    %%0002
                        byte    %%0022
                        byte    %%0002
                        byte    %%0222

                        byte    %%0222
                        byte    %%0002
                        byte    %%0022
                        byte    %%0002
                        byte    %%0002