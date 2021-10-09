''*****************************
''*  VGA Terminal 40x15 v1.3 *
''*  (C) 2004 Parallax, Inc.  *
''*****************************

CON

  vga_params = 21
  cols = 16
  rows = 16
  screensize = cols * rows

VAR

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

  word  screen[screensize]

  long  col, row, color

OBJ

  vga : "vga_drv_010.spin"


'' Start terminal - starts a cog
'' returns false if no cog available

PUB start(pins) :r

  print($100)
  longmove(@vga_status, @vgaparams, vga_params)
  vga_pins := pins
  vga_videobase := @screen
  vga_colorbase := @vgacolors
  r := vga.start(@vga_status)


'' Stop terminal - frees a cog

PUB stop

  vga.stop


'' Print a character
''
''  $00..$FF = character
''      $100 = clear screen
''      $101 = home
''      $108 = backspace
''      $10D = new line
''$110..$11F = select color

PUB print(c)   | i, k

  case c
    $00..$FF:           'character?
      k := color << 1 + c & 1
      i := k << 10 + $200 + c & $FE
      screen[row * cols + col] := i
      screen[(row + 1) * cols + col] := i | 1
      if ++col == cols
        newline

    $100:               'clear screen?
      wordfill(@screen, $220, screensize)
      col := row := 0

    $101:               'clear screen?
      col := row := 0

    $108:               'backspace?
      if col
        col--

    $10D:               'return?
      newline

    $110..$11F:         'select color?
      color := c & $F


' New line

PRI newline    | i

  col := 0
  if (row += 2) == rows
    row -= 2
    'scroll lines
    repeat i from 0 to rows-3
      wordmove(@screen[i*cols], @screen[(i+2)*cols], cols)
    'clear new line
    wordfill(@screen[(rows-2)*cols], $220, cols<<1)


' Data

DAT

vgaparams               long    0               'status
                        long    1               'enable
                        long    %00_111         'pins
                        long    %011            'mode
                        long    0               'videobase
                        long    0               'colorbase
                        long    cols            'hc
                        long    rows            'vc
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

vgacolors               long
                        long    $C000C000       'red
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