''*****************************
''*  TV Terminal              *
''*  (C) 2005 Parallax, Inc.  *
''*****************************

CON

  x_tiles = 16
  y_tiles = 13

  x_screen = x_tiles << 4
  y_screen = y_tiles << 4

  width = 0             '0 = minimum
  x_scale = 1           '1 = minimum
  y_scale = 1           '1 = minimum
  x_spacing = 6         '6 = normal
  y_spacing = 13        '13 = normal

  x_chr = x_scale * x_spacing
  y_chr = y_scale * y_spacing

  y_offset = y_spacing / 6 + y_chr - 1

  x_limit = x_screen / (x_scale * x_spacing)
  y_limit = y_screen / (y_scale * y_spacing)
  y_max = y_limit - 1

  y_screen_bytes = y_screen << 2
  y_scroll = y_chr << 2
  y_scroll_longs = y_chr * y_max
  y_clear = y_scroll_longs << 2
  y_clear_longs = y_screen - y_scroll_longs

  paramcount = 14       

VAR

  long  x, y, bitmap_base

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

  long  bitmap[x_tiles * y_tiles << 4 + 16]     'add 16 longs to allow for 64-byte alignment
  word  screen[x_tiles * y_tiles]

OBJ

  tv    : "tv_drv_010.spin"
  gr    : "graphics_drv_010.spin"


PUB start

'' Start terminal

  'init bitmap and tile screen
  bitmap_base := (@bitmap + $3F) & $7FC0
  repeat x from 0 to x_tiles - 1
    repeat y from 0 to y_tiles - 1
      screen[y * x_tiles + x] := bitmap_base >> 6 + y + x * y_tiles

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @color_schemes
  tv.start(@tv_status)

  'start graphics
  gr.start
  gr.setup(x_tiles, y_tiles, 0, y_screen, bitmap_base)
  gr.textmode(x_scale, y_scale, x_spacing, 0)
  gr.width(width)
  out(0)



PUB stop

'' Stop terminal

  tv.stop
  gr.stop


PUB out(c)

'' Print a character
''
''       $00 = home
''  $01..$03 = color
''  $04..$07 = color schemes
''       $09 = tab
''       $0D = return
''  $20..$7E = character

  case c

    $00:                'home?
      gr.clear
      x := y := 0

    $01..$03:           'color?
      gr.color(c)

    $04..$07:           'color scheme?
      tv_colors := @color_schemes[c & 3]

    $09:                'tab?
      repeat
        out($20)
      while x & 7

    $0D:                'return?
      newline

    $20..$7E:           'character?
      gr.text(x * x_chr, -y * y_chr - y_offset, @c)
      gr.finish
      if ++x == x_limit
        newline


PUB pstring(string_ptr)  | i

'' Print a zero-terminated string

  repeat i from 0 to strsize(string_ptr) - 1
    out(byte[string_ptr][i])


PUB dec(value)  | i, z

'' Print a decimal number

  if value < 0
    -value
    out("-")

  i := 1_000_000_000
  z~

  repeat 10
    if value => i
      out(value / i + "0")
      value //= i
      z~~
    elseif z or i == 1
      out("0")
    i /= 10


PUB hex(value, digits)

'' Print a hexadecimal number

  value <<= (8 - digits) << 2
  repeat digits
    out(lookupz((value <-= 4) & $F : "0".."9", "A".."F"))


PUB bin(value, digits)

'' Print a binary number

  value <<= 32 - digits
  repeat digits
    out((value <-= 1) & 1 + "0")


PRI newline

  if ++y == y_limit
    gr.finish
    repeat x from 0 to x_tiles - 1
      y := bitmap_base + x * y_screen_bytes
      longmove(y, y + y_scroll, y_scroll_longs)
      longfill(y + y_clear, 0, y_clear_longs)
    y := y_max
  x := 0


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
                        long    55_250_000      'broadcast
                        long    0               'auralcog

color_schemes           long    $BC_6C_05_02
                        long    $0E_0D_0C_0A
                        long    $6E_6D_6C_6A
                        long    $BE_BD_BC_BA