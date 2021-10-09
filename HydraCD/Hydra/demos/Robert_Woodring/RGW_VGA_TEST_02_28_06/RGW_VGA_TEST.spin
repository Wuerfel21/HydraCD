''
'' RGW VGA TEST
''

CON

  _xinfreq = 10_000_000 
  _clkmode = xtal1 + pll8x

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

PUB start(pins) :r | lIndex
  
  longmove(@vga_status, @vgaparams, vga_params)
  vga_pins := %10111
  vga_videobase := @screen  
  vga_colorbase := @TilePalette
  
  r := vga.start(@vga_status)

  lIndex := @tileMap
  repeat r from 0 to 255
    screen[r] := @Tile000>>6 + (byte[@tileMap + (r&63)]<<10)


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
