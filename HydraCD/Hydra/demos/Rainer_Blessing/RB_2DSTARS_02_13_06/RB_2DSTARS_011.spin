' 2D Starscroller                       
' AUTHOR: Rainer Blessing
' VERSION 1.1

CON

  _clkmode = xtal1 + pll8x
  _xinfreq = 10_000_000
  _stack = 256

  ' size of graphics tile map
  X_TILES           = 14
  Y_TILES           = 12
  
  SCREEN_WIDTH      = 224
  SCREEN_HEIGHT     = 192 

  paramcount = 14

  stars_count = 100  
  bitmap_base = $2800
  display_base = $5400

VAR

  long  tv_status     '0/1/2 = off/visible/invisible           read-only
  long  tv_enable     '0/? = off/on                            write-only
  long  tv_pins       '%ppmmm = pins                           write-only
  long  tv_mode       '%ccinp = chroma,interlace,ntsc/pal,swap write-only
  long  tv_screen     'pointer to screen (words)               write-only
  long  tv_colors     'pointer to colors (longs)               write-only               
  long  tv_hc         'horizontal cells                        write-only
  long  tv_vc         'vertical cells                          write-only
  long  tv_hx         'horizontal cell expansion               write-only
  long  tv_vx         'vertical cell expansion                 write-only
  long  tv_ho         'horizontal offset                       write-only
  long  tv_vo         'vertical offset                         write-only
  long  tv_broadcast  'broadcast frequency (Hz)                write-only
  long  tv_auralcog   'aural fm cog                            write-only

  word  screen[x_tiles * y_tiles]
  long  colors[64]
  byte  stars[stars_count*3]

  long random_counter

OBJ

  tv    : "tv_drv_010.spin"
  gr    : "graphics_drv_010.spin"
 
PUB start      | dx, dy, x,y,i, j, color

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen ' tile pointer map
  tv_colors := @colors ' colorset table
  tv.start(@tv_status)

  ' init color table.
  ' each entry defines 4 colors (1 byte each), each byte being defined as described in the 'tv_drv_010'
  ' only one colorset is used
  
  byte[@colors][0] := $2 ' black
  byte[@colors][1] := $3
  byte[@colors][2] := $4
  byte[@colors][3] := $7 ' white
  
  'init tile screen  
  repeat dx from 0 to tv_hc - 1
   repeat dy from 0 to tv_vc - 1
      screen[dy * tv_hc + dx] := display_base >> 6 + dy + dx * tv_vc + (0 << 10) ' all tiles use colorset 0
    
  'start and setup graphics
  gr.start
  gr.setup(X_TILES, Y_TILES, 0, 0, bitmap_base)

  i:=0
  repeat while i < stars_count*3/3 ' star layer
   stars[i]:=?x//SCREEN_WIDTH ' x
   stars[i+1]:=?y//SCREEN_HEIGHT ' y
   stars[i+2]:=1 ' speed and color
   i:=i+3
  
  repeat while i < stars_count*3*2/3 ' star layer
   stars[i]:=Rand//SCREEN_WIDTH
   stars[i+1]:=Rand//SCREEN_HEIGHT
   stars[i+2]:=2
   i:=i+3
  
  repeat while i < stars_count*3  ' star layer
   stars[i]:=?x//SCREEN_WIDTH
   stars[i+1]:=?y//SCREEN_HEIGHT
   stars[i+2]:=3
   i:=i+3

   ' seed random counter
  random_counter := 978
  
  repeat

    'clear bitmap
    gr.clear
    i:=0

    repeat while i < stars_count*3
      gr.color(stars[i+2])
      gr.plot(stars[i],stars[i+1])
      stars[i]:=stars[i]+stars[i+2] ' add speed
      if(stars[i]<0)
        stars[i]:=SCREEN_WIDTH-stars[i] ' wrap stars
      i:=i+3
    repeat while tv_status==1                           ' end of visible  
    gr.copy(display_base)


PUB Rand : retval
  random_counter := (1 + random_counter ^ random_counter << 6 ^ random_counter << 2 ^ random_counter << 7)
  retval := random_counter
  
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