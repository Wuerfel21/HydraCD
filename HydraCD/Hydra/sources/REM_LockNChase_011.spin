{********************************
 *   Rem Lock'n Chase game v011 *
 ********************************

 This Lock'n Chase close uses 3 additionnal ASM files.
 It uses almost no SPIN code.
 Please read included readme.txt

}

CON

  _clkmode = xtal1 + pll8x  ' ?
  _xinfreq = 10_000_000 + 0000 ' Set to 10Mhz and add 5000 to fix crystal imperfection of hydra prototype
 _stack = ($3000 - 200) >> 2            'accomodate display memory and stack

  x_tiles = 16 ' Number of horizontal tiles (each tile is 16x16), so this means 256 pixel
  y_tiles = 12 ' Number of vertical tiles, this means 192 pixel. Resolution is 256x192.

  paramcount = 14       
  display_base = $5000 ' This is the 'front buffer': this is the memory that gets displayed on the screen
  ' The display takes 256*192*2bit = 12288 bytes

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

  ' param for rem_engine:
  long tilemap_adr
  long tiles_adr
  long tv_status_adr
  long colors_adr
  long gamepad
  long screenv_adr
  long numbers_adr
  long doormap_adr
  
  long colors[64]
  word screen[x_tiles * y_tiles]

  long temp1
  long temp2
  byte previous
  byte tile
  long framecount

OBJ

  tv    : "tv_drv_010.spin"
  rem   : "REM_lnc_asm_011.spin"
  rem2 : "REM_lnc_proc_011.spin"
  rem3 : "REM_lnc_police_011.spin"
  key   : "keyboard_iso_010.spin"


PUB start      | i, j, k, kk, dx, dy, pp, pq, rr, numx, numchr
  DIRA[0] := 1
  outa[0] := 0

  'clear color table.
  longfill(@colors, $02020202, 64)

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  'init tile screen
  ' screen is defined as a 2D array of tile(x,y), each value being a 10-bit memory address divided by 64 (>>6)
  ' (each tile using 16x16x2bpp = 64 bytes per tile)
  ' and a color-table entry from 0..63 shifted by <<10

  repeat dx from 0 to x_tiles * y_tiles
    screen[dx] := display_base >> 6 + dx

  'temp1 := display_base
  repeat dy from 0 to 191
    tile := tilemap[dy]
    screen[dy] |= (lookupz(tile: 0,0,0,0,CONSTANT(1<<10),0,0,CONSTANT(2<<10),0,0,CONSTANT(2<<10)))
    'longmove(temp1, @tile000[tile << 4], 16)
    'temp1 += 64

  repeat dx from 0 to 4
    screen[dx] |= CONSTANT(5<<10)
    screen[dx+7] |= CONSTANT(6<<10)
  screen[5] |= CONSTANT(5<<10)
  screen[6] |= CONSTANT(5<<10)
  screen[12] |= CONSTANT(5<<10)
  screen[13] |= CONSTANT(5<<10)
  screen[14] |= CONSTANT(5<<10)
  repeat dx from 0 to 10
   screen[15+dx*x_tiles] |= CONSTANT(5<<10)
  screen[CONSTANT(15+11*x_tiles)] |= CONSTANT(7<<10)

  tilemap_adr := @tilemap
  tiles_adr := @tile000
  tv_status_adr := @tv_status
  colors_adr := @colors
  screenv_adr := @screen
  numbers_adr := @numbers
  doormap_adr := @doormap
  rem.start(@tilemap_adr)
  rem2.start(@tilemap_adr)
  rem3.start(@tilemap_adr)
  key.start(3)

  ' perform a delay before setting the colors, this prevent a flickering screen
  ' when TV sync with signal
  repeat 160000
  'init color table.
  ' Each entry defines 4 colors (1 byte each), each byte being defined as described in the 'tv_drv_010'
  longmove(@colors, @palette00, 11)

  ' Start of main loop here
  repeat
    temp1 := NES_Read_Gamepad & $FF

    if(temp1 == $FF)
      temp1 := 0

    if(key.keystate($C2))
      temp1|=NES_UP
    if(key.keystate($C3))
      temp1|=NES_DOWN
    if(key.keystate($C0))
      temp1|=NES_LEFT
    if(key.keystate($C1))
      temp1|=NES_RIGHT
    if(key.keystate($0D))
      temp1|=NES_START
    if(key.keystate($F0) or key.keystate($F2) or key.keystate($F4))
      temp1|=NES_A

    gamepad := temp1

    repeat while tv_status == 1
    repeat while tv_status == 2

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
                        long    x_tiles         'hc
                        long    y_tiles         'vc
                        long    10              'hx
                        long    1               'vx
                        long    0               'ho
                        long    0               'vo
                        long    60_000_000'_xinfreq<<4  'broadcast
                        long    0               'auralcog

numbers                 long    %%0202_0202_0202_0020
                        long    %%0000_0000_0000_0020

                        long    %%0020_0020_0022_0020
                        long    %%0000_0000_0000_0020

                        long    %%0002_0222_0200_0222
                        long    %%0000_0000_0000_0222

                        long    %%0200_0220_0200_0222
                        long    %%0000_0000_0000_0222

                        long    %%0200_0222_0202_0202
                        long    %%0000_0000_0000_0200

                        long    %%0200_0222_0002_0222
                        long    %%0000_0000_0000_0222

                        long    %%0202_0222_0002_0222
                        long    %%0000_0000_0000_0222

                        long    %%0020_0200_0200_0222
                        long    %%0000_0000_0000_0020

                        long    %%0202_0222_0202_0222
                        long    %%0000_0000_0000_0222

                        long    %%0200_0222_0202_0222
                        long    %%0000_0000_0000_0222

                        long    %%0202_0222_0202_0222
                        long    %%0000_0000_0000_0202

                        long    %%0202_0222_0002_0002
                        long    %%0000_0000_0000_0222

                        long    %%0002_0002_0002_0222
                        long    %%0000_0000_0000_0222

                        long    %%0202_0222_0200_0200
                        long    %%0000_0000_0000_0222

                        long    %%0002_0022_0002_0222
                        long    %%0000_0000_0000_0222

                        long    %%0002_0022_0002_0222
                        long    %%0000_0000_0000_0002

tilemap                 byte 36,36,36,36,26,36,36,36,36,36,36,26,36,36,36,36
                        byte 00,01,01,01,03,04,01,01,01,01,03,01,01,01,02,36
                        byte 05,07,07,07,07,07,07,07,07,07,07,07,07,07,06,36
                        byte 08,07,03,01,09,07,03,01,03,07,11,07,12,07,06,36
                        byte 05,07,07,07,07,07,07,07,07,07,07,07,07,07,06,36
                        byte 13,07,11,01,16,07,17,07,09,07,17,07,11,01,14,36
                        byte 10,07,07,07,15,07,15,10,10,10,15,07,07,07,10,36
                        byte 01,07,18,07,19,07,20,07,01,07,20,07,20,07,01,36
                        byte 10,07,07,07,07,07,07,07,07,07,07,07,07,07,10,36
                        byte 00,07,03,01,11,07,09,07,03,07,09,07,11,07,02,36
                        byte 05,07,07,07,07,07,07,07,07,07,07,07,07,07,06,36
                        byte 21,01,01,01,09,01,01,01,09,01,01,10,09,01,14,26

tilemap_backup          byte 36,36,36,36,26,36,36,36,36,36,36,26,36,36,36,36
                        byte 00,01,01,01,03,04,01,01,01,01,03,01,01,01,02,36
                        byte 05,07,07,07,07,07,07,07,07,07,07,07,07,07,06,36
                        byte 08,07,03,01,09,07,03,01,03,07,11,07,12,07,06,36
                        byte 05,07,07,07,07,07,07,07,07,07,07,07,07,07,06,36
                        byte 13,07,11,01,16,07,17,07,09,07,17,07,11,01,14,36
                        byte 10,07,07,07,15,07,15,10,10,10,15,07,07,07,10,36
                        byte 01,07,18,07,19,07,20,07,01,07,20,07,20,07,01,36
                        byte 10,07,07,07,07,07,07,07,07,07,07,07,07,07,10,36
                        byte 00,07,03,01,11,07,09,07,03,07,09,07,11,07,02,36
                        byte 05,07,07,07,07,07,07,07,07,07,07,07,07,07,06,47
                        byte 21,01,01,01,09,01,01,01,09,01,01,10,09,01,14,26

doormap                 byte 00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
                        byte 00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
                        byte 00,00,00,00,01,00,00,00,00,00,01,00,00,00,00,00
                        byte 00,02,00,00,00,02,00,00,00,02,00,02,00,00,00,00
                        byte 00,00,01,00,00,00,01,00,01,00,01,00,01,00,00,00
                        byte 00,02,00,00,00,02,00,02,00,02,00,02,00,00,00,00
                        byte 00,00,01,00,00,00,00,00,00,00,00,00,01,00,00,00
                        byte 00,02,00,00,00,02,00,02,00,02,00,02,00,02,00,00
                        byte 00,00,01,00,01,00,01,00,00,00,01,00,01,00,00,00
                        byte 00,02,00,00,00,02,00,02,00,02,00,02,00,02,00,00
                        byte 00,00,00,00,01,00,00,00,01,00,00,00,01,00,00,00
                        byte 00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00

tile000                 long $55555555,$aaaaaaa9,$aaaaaaa9,$aaaaaaa9,$aaaaaaa9,$fffffea9,$aaaaaea9,$aaaaaea9
                        long $aaaaaea9,$aaaaaea9,$555aaea9,$555aaea9,$55daaea9,$57daaea9,$5fdaaea9,$3fdaaea9
tile001                 long $55555555,$aaaaaaaa,$aaaaaaaa,$aaaaaaaa,$aaaaaaaa,$ffffffff,$aaaaaaaa,$aaaaaaaa
                        long $aaaaaaaa,$aaaaaaaa,$55555555,$55555555,$55555555,$55555555,$55555555,$00000000
tile002                 long $55555555,$6aaaaaaa,$6aaaaaaa,$6aaaaaaa,$6aaaaaaa,$6abfffff,$6abaaaaa,$6abaaaaa
                        long $6abaaaaa,$6abaaaaa,$6abaa555,$6abaa555,$6abaa655,$6abaa795,$6abaa6e5,$6abaa7b8
tile003                 long $55555555,$aaaaaaaa,$aaaaaaaa,$aaaaaaaa,$aaaaaaaa,$ffffffff,$aaaaeaaa,$aaaaeaaa
                        long $aaaaeaaa,$aaaaeaaa,$5555d555,$5555d555,$5555d555,$5555d555,$5555d555,$00000000
tile004                 long $40000001,$50000005,$64000019,$54000019,$6fc333d9,$5700c0d9,$6730c3d9,$5730c0d9
                        long $673333d9,$54000019,$64000019,$55555559,$66aaaa99,$56aaaa99,$55555555,$00000000
tile005                 long $3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9
                        long $3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9
tile006                 long $6abaa6ec,$6abaa7b8,$6abaa6ec,$6abaa7b8,$6abaa6ec,$6abaa7b8,$6abaa6ec,$6abaa7b8
                        long $6abaa6ec,$6abaa7b8,$6abaa6ec,$6abaa7b8,$6abaa6ec,$6abaa7b8,$6abaa6ec,$6abaa7b8
tile007                 long $00000000,$00000000,$00000000,$00000000,$00000000,$0003f000,$000bfc00,$000bfc00
                        long $000bfc00,$0002a000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
tile008                 long $3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9,$3ffffea9,$3fdaaea9,$3fdaaea9
                        long $3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9
tile009                 long $5555d555,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$ffffffff,$aaaaaaaa,$aaaaaaaa
                        long $aaaaaaaa,$aaaaaaaa,$55555555,$55555555,$55555555,$55555555,$55555555,$00000000
tile010                 long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
                        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
tile011                 long $5555d555,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$ffffffff,$aaaaeaaa,$aaaaeaaa
                        long $aaaaeaaa,$aaaaeaaa,$5555d555,$5555d555,$5555d555,$5555d555,$5555d555,$00000000
tile012                 long $55555555,$6aaaaaaa,$6aaaaaaa,$6aaaaaaa,$6aaaaaaa,$6aaaffff,$6aaaeaaa,$6aaaeaaa
                        long $6aaaeaaa,$6aaaeaaa,$5555d555,$5555d555,$5555d555,$5555d555,$5555d555,$00000000
tile013                 long $3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9,$3fdaaea9,$3ffffea9,$3fdaaaa9,$3fdaaaa9
                        long $3fdaaaa9,$3fdaaaa9,$3fd55555,$3f555554,$3d555550,$35555540,$15555500,$00000000
tile014                 long $6abaa555,$6abaaaaa,$6abaaaaa,$6abaaaaa,$6abaaaaa,$6abfffff,$6aaaaaaa,$6aaaaaaa
                        long $6aaaaaaa,$6aaaaaaa,$55555555,$55555555,$55555555,$55555555,$55555555,$00000000
tile015                 long $aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa
                        long $aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa
tile016                 long $55555555,$aaaaaaaa,$aaaaaaaa,$aaaaaaaa,$aaaaaaaa,$ffffffff,$aaaaeaaa,$aaaaeaaa
                        long $aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa
tile017                 long $5555d555,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$ffffffff,$aaaaeaaa,$aaaaeaaa
                        long $aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa
tile018                 long $5555d555,$6aaaeaaa,$6aaaeaaa,$6aaaeaaa,$6aaaeaaa,$6aaaffff,$6aaaeaaa,$6aaaeaaa
                        long $6aaaeaaa,$6aaaeaaa,$5555d555,$5555d555,$5555d555,$5555d555,$5555d555,$00000000
tile019                 long $aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$ffffeaaa,$aaaaeaaa,$aaaaeaaa
                        long $aaaaeaaa,$aaaaeaaa,$5555d555,$5555d555,$5555d555,$5555d555,$5555d555,$00000000
tile020                 long $aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$aaaaeaaa,$ffffffff,$aaaaeaaa,$aaaaeaaa
                        long $aaaaeaaa,$aaaaeaaa,$5555d555,$5555d555,$5555d555,$5555d555,$5555d555,$00000000
tile021                 long $555aaea9,$aaaaaea9,$aaaaaea9,$aaaaaea9,$aaaaaea9,$fffffea9,$aaaaaaa9,$aaaaaaa9
                        long $aaaaaaa9,$aaaaaaa9,$55555555,$55555554,$55555550,$55555540,$55555500,$00000000
tile022                 long $00005554,$51557ff4,$d5ff7df4,$f7df5ff4,$f55f55f4,$d41f41f4,$50154154,$00000000
                        long $00540000,$55755550,$d7ff7fd4,$557555f4,$f5747f54,$d7f45ff4,$55541554,$00000000
tile023                 long $00000000,$55555515,$7fd7fd1f,$55f55f7d,$7f57f557,$5ff5ff5f,$15555555,$00000000
                        long $05400000,$57555555,$7ff5ff5f,$5757df7d,$57455f7f,$7f401f7f,$55401555,$00000000
tile024                 long $00000000,$00fec000,$ffa57000,$f8156c00,$99515800,$a9545300,$aa955ac0,$ba96bfc0
                        long $aabfff00,$afffc000,$fffc0000,$fc000000,$00000000,$00000000,$00000000,$00000000
tile025                 long $00000000,$00000000,$00000000,$0000003f,$00000ffe,$0003faa6,$03fe951a,$03d5555a
                        long $03d5559a,$03e56aa6,$03f9aaaa,$00fd66bf,$00febfff,$003fffc0,$00000000,$00000000
tile026                 long $55555555,$556a5555,$56fff955,$57feff55,$4fe01fd5,$4fd503f5,$5fd551f5,$0fd550f9
                        long $4fd554bd,$47e554fd,$42f555f9,$50be5bf5,$541fffe5,$5502fe55,$55500155,$55555555
tile027                 long $55555555,$55555555,$555f9555,$554ff555,$554ff555,$554f6555,$554bd555,$5547d555
                        long $5543d555,$5552e555,$555ae555,$555ff555,$550bf555,$55405555,$55545555,$55555555
tile028                 long $55555555,$555a9555,$55bff955,$55ffff55,$56f02f95,$52f507d5,$51fe4055,$507fd555
                        long $540bf955,$5550fe55,$57fe7f95,$53ffffd5,$506fffd5,$54005b55,$55540155,$55555555
tile029                 long $55555555,$555a5555,$55bfe555,$54fff955,$55f0bd55,$50f42955,$547e0555,$55bfd555
                        long $56fa9555,$52f05555,$51f55655,$50bfaf95,$542fff55,$5501a555,$55500555,$55555555
tile030                 long $55555555,$55555555,$55fd5555,$54ff5555,$54bfd555,$54bbf555,$54bcfd55,$55bc3f55
                        long $57ffff95,$51bfffd5,$503d1a55,$552f0155,$552f5555,$55055555,$55555555,$55555555
tile031                 long $55555555,$56a55555,$5bffe555,$47fffd55,$4101bd55,$5150b955,$555af955,$55bff555
                        long $54f96555,$55f01555,$50f55555,$54bfaf95,$542fff95,$5506a955,$55400155,$55555555
tile032                 long $55555555,$55555555,$55ffd555,$54fff955,$5416fe55,$55002f55,$55aa4fd5,$57ffffd5
                        long $57faffd5,$47d01fd5,$43f90bd5,$50ffffd5,$542fff55,$55006555,$55540555,$55555555
tile033                 long $55555555,$55555555,$56fea955,$57ffff95,$53fabf95,$51f40155,$50bd5155,$543e5555
                        long $551f5555,$550fd555,$5547e555,$5542f555,$5551f955,$55506555,$55541555,$55555555
tile034                 long $55555555,$555a5555,$55bfe555,$55f5f955,$55f03e55,$50f52f55,$54bfff55,$55fffe55
                        long $57f9bf55,$53e01fd5,$52f503e5,$50fe53f5,$543ffff5,$550bffd5,$55401455,$55550555
tile035                 long $55555555,$56aaa555,$53fffe55,$52febf95,$52f00f95,$52feaf95,$52fffe55,$52eaa555
                        long $52f01555,$52f55555,$51f55555,$51f55555,$50f55555,$54b55555,$54155555,$55555555
tile036                 long $55555555,$55555555,$55555555,$55555555,$55555555,$55555555,$55555555,$55555555
                        long $55555555,$55555555,$55555555,$55555555,$55555555,$55555555,$55555555,$55555555
tile037                 long $55555000,$7dffd000,$7df3d000,$7d7fd000,$7d57d000,$fd07d000,$55055000,$00000000
                        long $00000550,$555557d0,$f7dfd7d0,$f7fdf7d5,$ff7df7fd,$7d5fd5f5,$5fd55154,$55500000
tile038                 long $00000000,$00155555,$001ff7df,$001f7fdf,$001ff7df,$001f57fd,$0017fd55,$00055500
                        long $55000000,$7d055555,$7d57f5ff,$7fdf57df,$7dfffdff,$7fdff55f,$5555541f,$00000015
tile039                 long $00155400,$001aa400,$001aa400,$01555540,$001ff400,$001cc400,$001ff400,$0007d000
                        long $00014000,$00169400,$00400100,$01aaaa40,$01000040,$006aa900,$00155400,$05500550
tile040                 long $00155400,$001aa400,$001aa400,$01555540,$001ff400,$001cc400,$001ff400,$0007d000
                        long $00014000,$0005a500,$00100040,$006aaa90,$00400010,$055aaa40,$00555500,$00000550
tile041                 long $00155400,$001aa400,$001aa400,$01555540,$001ff400,$001cc400,$001ff400,$0007d000
                        long $00014000,$005a5000,$01000400,$06aaa900,$04000100,$01aaa550,$00555500,$05500000
tile042                 long $00155400,$001aa400,$001aa400,$01555540,$001ff400,$00133400,$001ff400,$0007d000
                        long $00014000,$00169400,$00400100,$01aaaa40,$01000040,$006aa900,$00155400,$05500550
tile043                 long $00155400,$001aa400,$001aa400,$01555540,$001ff400,$00133400,$001ff400,$0007d000
                        long $00014000,$0005a500,$00100040,$006aaa90,$00400010,$055aaa40,$00555500,$00000550
tile044                 long $00155400,$001aa400,$001aa400,$01555540,$001ff400,$00133400,$001ff400,$0007d000
                        long $00014000,$005a5000,$01000400,$06aaa900,$04000100,$01aaa550,$00555500,$05500000
tile045                 long $0006e400,$0006e400,$0006e400,$0006e400,$0006e400,$0006e400,$0006e400,$0006e400
                        long $0006e400,$0006e400,$0006e400,$0006e400,$0006e400,$0006e400,$0006e400,$0006e400
tile046                 long $00000000,$00000000,$00000000,$55555555,$aaaaaaaa,$ffffffff,$aaaaaaaa,$55555555
                        long $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
tile047                 long $55555555,$54000015,$54aaaa15,$54aaaa15,$54aaaa15,$54aaaa15,$40aaaa01,$4aaaaaa1
                        long $40000001,$55404055,$554c0c55,$55433055,$5550c155,$55433055,$554c0c55,$55404055
tile048                 long $01555550,$05aaaa90,$06afea40,$06afe900,$06aba400,$06aaa950,$06aaaaa4,$05054150
                        long $01820900,$018ec910,$118ec910,$106aa450,$14155040,$05555514,$01555550,$15400000
tile049                 long $00000000,$01555550,$05aaaa90,$06afea40,$06afe900,$06aba400,$06aaa950,$060aa0a4
                        long $05414150,$1063b240,$1063b244,$111aa914,$04155050,$51555500,$05555500,$00000550
tile050                 long $00155500,$001aa900,$00155500,$015ccd50,$001ccd00,$001ffd00,$001c0d04,$0f073404
                        long $2fc15014,$2fd6a510,$0a400040,$01aaaa90,$01000050,$006aaa40,$00155500,$05500550
tile051                 long $00000000,$0000c000,$0000fc00,$000affc0,$0000aa00,$000c0000,$003cfc00,$03f03f00
                        long $03cccfc0,$0ffccff0,$0ff03ff0,$0bccffc0,$0bcccfc0,$02f03f00,$00a8ac00,$00000000
tile052                 long $01555550,$05aaaa90,$0eafea40,$06afe930,$06aba400,$36aaa953,$060202a4,$05155150
                        long $01aaa900,$01a02900,$01a00900,$00682400,$14155000,$05555554,$01555500,$15400150
tile053                 long $00000000,$01555550,$05aaaa90,$06afea40,$06afe900,$06aba400,$06aaa950,$060202a4
                        long $05155150,$01aaa900,$01a02900,$01a00914,$00682450,$54555400,$01555500,$15400150

palette00               byte $02,$3A,$1B,$0D
palette01               byte $02,$3A,$1B,$BB
palette02               byte $02,$6B,$6C,$06
palette03               byte $02,$6B,$6C,$6E
palette04               byte $02,$03,$04,$FE
palette05               byte $02,$03,$6C,$6E
palette06               byte $02,$03,$BB,$AE
palette07               byte $02,$03,$1B,$0D
palette08               byte $02,$BA,$BB,$07
palette09               byte $02,$BA,$BB,$07
                        