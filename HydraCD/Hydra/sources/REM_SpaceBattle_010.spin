{********************************
 *   Rem Space Battle game v010 *
 ********************************


}

CON

  _clkmode = xtal1 + pll8x  ' ?
  _xinfreq = 10_000_000 + 0000 ' Set to 10Mhz and add 5000 to fix crystal imperfection of hydra prototype
 _stack = ($300 - 200) >> 2             'accomodate display memory and stack

  x_tiles = 16 ' Number of horizontal tiles (each tile is 16x16), so this means 256 pixel
  y_tiles = 12 ' Number of vertical tiles, this means 192 pixel. Resolution is 256x192.

  paramcount = 14
  SCANLINE_BUFFER = $7F00

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
  long cog_number
  long cog_total
  
  long colors[64]
  word screen[x_tiles * y_tiles]

  long temp1
  long temp2
  byte previous
  byte tile
  long framecount

OBJ

  tv    : "rem_tv_010.spin"
  rem   : "rem_spacebattle_asm_010.spin"
  rem2  : "rem_spacebattle_asm_010.spin"


PUB start      | i, j, k, kk, dx, dy, pp, pq, rr, numx, numchr
  DIRA[0] := 1
  outa[0] := 0

  longfill(@colors, $02020202, 1)

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_colors := @colors
  tv.start(@tv_status)

  'init tile screen
  ' screen is defined as a 2D array of tile(x,y), each value being a 10-bit memory address divided by 64 (>>6)
  ' (each tile using 16x16x2bpp = 64 bytes per tile)
  ' and a color-table entry from 0..63 shifted by <<10

  repeat dx from 0 to x_tiles * y_tiles
    screen[dx] := SCANLINE_BUFFER >> 6 + dx

  repeat dx from 0 to 255
    byte[SCANLINE_BUFFER][dx] := $0C + ((dx & $F) << 4)

  ' perform a delay before setting the colors, this prevent a flickering screen
  ' when TV sync with signal
  repeat 160000

  tilemap_adr := @tilemap
  tiles_adr := @tile000
  tv_status_adr := @tv_status
  colors_adr := @colors
  cog_number := 0
  cog_total := 2
  rem.start(@tilemap_adr)
  repeat 10000 ' Allow each time for first cog to boot up before setting 'cog_number' again
  cog_number := 1
  rem2.start(@tilemap_adr)

  ' Start of main loop here
  repeat
    gamepad := NES_Read_Gamepad

    repeat while tv_status == 1

    repeat
      {temp1 := long[SCANLINE_BUFFER-4]
      if(temp1 == 100)
        byte[SCANLINE_BUFFER][40] := $07
      else
        byte[SCANLINE_BUFFER][40] := $02}
    while tv_status == 2

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

tilemap                 byte $1,$2,$3,$4




' parallax bitmap exported from photoshop

tile000 byte $2D,$1C,$1D,$4C,$1D,$1C,$1D,$1D,$1C,$1D,$1D,$1C,$1D,$1D,$2C,$1D
        byte $1D,$4C,$1C,$04,$1C,$04,$2B,$04,$4B,$1C,$4B,$04,$1C,$1D,$04,$1D
        byte $1C,$1D,$04,$3A,$02,$4A,$02,$4A,$4A,$02,$4A,$4A,$4A,$03,$1D,$1C
        byte $1D,$2C,$1C,$02,$05,$FE,$8E,$EE,$EE,$EE,$BE,$FE,$05,$4A,$4B,$1D
        byte $1D,$4C,$04,$4A,$EE,$04,$4A,$4A,$5A,$4A,$5A,$03,$EE,$04,$03,$1C
        byte $1C,$1D,$FB,$02,$FE,$5A,$4A,$4A,$4A,$4A,$4A,$02,$5C,$CD,$4A,$1D
        byte $1D,$2C,$04,$4A,$5E,$5C,$DA,$4B,$5B,$DA,$4B,$04,$06,$4B,$03,$1D
        byte $1D,$2C,$4B,$4A,$FE,$07,$06,$8E,$FE,$06,$FE,$BE,$04,$4A,$4B,$0C
        byte $1D,$1C,$04,$4A,$EE,$03,$4A,$4A,$03,$4A,$5A,$03,$03,$1C,$1D,$1D
        byte $2D,$1D,$2B,$02,$FE,$03,$03,$1D,$1C,$1D,$1C,$1D,$1D,$1D,$04,$1C
        byte $1C,$1D,$04,$4A,$CE,$5A,$4B,$0C,$4C,$1D,$1D,$4C,$0C,$4C,$1D,$03
        byte $1D,$2C,$4B,$4A,$CD,$4A,$4B,$1D,$1C,$1D,$04,$1C,$1D,$1D,$3A,$02
        byte $1D,$1C,$04,$3A,$4A,$4A,$FB,$4C,$1D,$1C,$1D,$1D,$1D,$1C,$5A,$4A
        byte $1D,$1D,$1C,$1D,$1C,$04,$2D,$1C,$1D,$1D,$1C,$1D,$04,$1D,$1D,$1C
        byte $2C,$1D,$1C,$1D,$1D,$1C,$1D,$1D,$04,$1C,$1D,$4C,$0C,$2D,$1D,$04
        byte $1D,$4C,$1D,$1C,$04,$1D,$1C,$1D,$2C,$1D,$1D,$1D,$4C,$1D,$1C,$1D
tile001 byte $1D,$1C,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$2D,$1D,$1D,$2D
        byte $1C,$1D,$1D,$4C,$1D,$1C,$1D,$4C,$1C,$4B,$1D,$1C,$04,$1C,$04,$1C
        byte $1D,$1D,$1D,$1D,$1D,$1D,$4C,$EA,$7A,$4A,$4A,$04,$3A,$4A,$03,$5A
        byte $1D,$4C,$1D,$1C,$1D,$04,$FA,$03,$EE,$FE,$03,$03,$02,$FE,$06,$06
        byte $1D,$1D,$1D,$1D,$4C,$FA,$5B,$8E,$05,$7E,$05,$4A,$4A,$EE,$04,$5A
        byte $1D,$1C,$04,$1D,$03,$03,$06,$04,$02,$03,$FE,$02,$4A,$BE,$03,$02
        byte $4C,$1D,$1D,$3A,$03,$06,$07,$5C,$04,$04,$06,$02,$4A,$FE,$6E,$CD
        byte $1D,$1C,$03,$03,$06,$FE,$06,$FE,$FE,$06,$06,$02,$7A,$FE,$06,$FE
        byte $04,$03,$4A,$EE,$04,$4A,$4A,$5A,$5A,$5B,$CE,$4A,$02,$FE,$5B,$4A
        byte $4B,$4A,$05,$04,$02,$04,$1C,$1D,$4B,$4A,$CE,$02,$4A,$8E,$4A,$4B
        byte $4A,$DE,$5C,$4A,$1C,$1D,$1D,$1D,$4B,$EA,$7E,$4A,$02,$FE,$03,$4B
        byte $CD,$04,$4A,$EB,$2D,$1D,$1D,$1D,$2A,$8A,$CD,$02,$4A,$CD,$4A,$4B
        byte $4A,$4A,$4B,$1D,$1D,$4C,$1D,$1D,$4B,$4A,$4A,$4A,$4A,$4A,$4A,$04
        byte $1D,$1D,$1D,$1D,$1C,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D
        byte $1D,$1C,$1D,$1D,$1D,$1D,$04,$1D,$1C,$1D,$1D,$1C,$1D,$4C,$1C,$04
        byte $1D,$1D,$4C,$1D,$1C,$4C,$1D,$1C,$4C,$04,$2C,$04,$2B,$04,$2B,$4C
tile002 byte $1D,$1D,$1D,$2D,$1D,$1D,$1D,$2D,$1D,$1D,$1D,$1D,$4D,$1D,$1D,$1D
        byte $04,$2C,$04,$1C,$04,$2D,$1D,$1D,$1D,$4D,$1D,$1D,$1D,$1D,$4D,$0D
        byte $03,$4A,$03,$03,$4A,$4A,$4B,$1D,$1D,$1D,$1D,$4D,$1D,$0D,$2D,$1D
        byte $06,$06,$06,$06,$06,$DC,$4A,$1D,$1D,$2D,$1D,$1D,$4D,$1D,$1D,$5B
        byte $4A,$4A,$4A,$4A,$04,$06,$03,$4B,$1D,$4D,$1D,$0D,$1D,$2D,$5B,$03
        byte $02,$02,$02,$02,$4A,$06,$04,$03,$1D,$1D,$1D,$4D,$1D,$03,$03,$06
        byte $5D,$CD,$5D,$CD,$05,$07,$5B,$03,$1D,$1D,$1D,$1D,$03,$03,$06,$07
        byte $7E,$FE,$FE,$8E,$06,$06,$03,$4B,$1D,$0D,$2D,$03,$5B,$FE,$06,$FE
        byte $4A,$03,$5A,$03,$4A,$04,$DC,$4A,$1D,$2D,$03,$4A,$EE,$04,$4A,$5A
        byte $1D,$1D,$1D,$1D,$4B,$4A,$5E,$4A,$04,$4B,$4A,$05,$04,$4A,$04,$1D
        byte $1D,$1D,$1D,$1D,$4B,$03,$EE,$4A,$3A,$4A,$DE,$5C,$4A,$04,$1D,$1D
        byte $1D,$1D,$1D,$1D,$4B,$4A,$CD,$02,$02,$CD,$04,$4A,$EB,$3D,$1D,$0D
        byte $1D,$1D,$1D,$1D,$04,$4A,$4A,$02,$4A,$4A,$03,$4B,$1D,$1E,$1D,$4D
        byte $1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$0D,$1D,$4D,$1D,$0D
        byte $1D,$0D,$4D,$0D,$1D,$1D,$1D,$1D,$1D,$1D,$4D,$1D,$1D,$0D,$1D,$4D
        byte $04,$0D,$1E,$ED,$1E,$EE,$1E,$05,$1E,$0D,$0D,$0D,$4D,$1D,$0D,$1D
tile003 byte $1D,$1D,$1D,$4D,$1D,$0D,$2D,$0D,$2D,$0D,$2D,$0D,$4D,$1D,$0D,$4D
        byte $3D,$1D,$04,$1D,$1D,$2D,$1D,$4C,$0D,$4D,$0D,$2D,$0D,$4D,$0D,$2D
        byte $03,$4A,$4A,$03,$04,$4A,$02,$4A,$04,$1D,$0D,$4D,$0D,$1D,$1D,$4A
        byte $03,$EE,$FE,$03,$03,$4A,$CD,$4A,$4B,$0D,$2D,$0D,$3D,$0D,$4C,$02
        byte $FE,$05,$7E,$05,$4A,$02,$4E,$4A,$04,$1D,$0D,$4D,$0D,$1D,$1D,$4A
        byte $04,$02,$03,$FE,$4A,$02,$FE,$5A,$04,$1D,$0D,$2D,$0D,$4D,$1D,$02
        byte $CD,$5B,$5C,$FE,$7A,$02,$FE,$03,$4B,$0D,$3D,$0D,$4D,$0D,$1D,$02
        byte $5E,$06,$06,$FE,$7A,$4A,$BE,$4A,$04,$1D,$0D,$0D,$1D,$0D,$1D,$7A
        byte $03,$4A,$03,$FE,$02,$4A,$CE,$4A,$04,$0D,$3D,$0D,$4D,$0D,$4C,$02
        byte $1D,$4B,$03,$BE,$4A,$4A,$FE,$03,$4B,$4B,$04,$1C,$04,$4B,$04,$4A
        byte $0D,$4B,$03,$EE,$02,$5A,$CD,$7E,$04,$4B,$EB,$5B,$5B,$DA,$4A,$4A
        byte $3D,$04,$4A,$CD,$4A,$03,$4A,$04,$DE,$FE,$06,$8E,$06,$05,$02,$03
        byte $0D,$4B,$4A,$4A,$4A,$1D,$04,$03,$03,$4A,$03,$4A,$4A,$4A,$03,$1D
        byte $1D,$0D,$1D,$0D,$1D,$0D,$1D,$1E,$1D,$0D,$1D,$0D,$1D,$0D,$1D,$0D
        byte $0D,$2D,$0D,$4D,$0D,$4D,$0D,$1D,$1E,$1D,$1E,$1D,$1E,$1D,$1E,$1D
        byte $4D,$0D,$2D,$0D,$1D,$0D,$4D,$0D,$2D,$1E,$1D,$1E,$1D,$1E,$1D,$1E
tile004 byte $0D,$1D,$0D,$4D,$0D,$1D,$0D,$4D,$0D,$0D,$1D,$1E,$1D,$0D,$1E,$0D
        byte $04,$1D,$2D,$0D,$4D,$0D,$4D,$0D,$1D,$1E,$1D,$1E,$0D,$4D,$0D,$4D
        byte $4A,$02,$04,$0D,$0D,$1D,$0D,$0D,$4D,$0D,$1E,$1D,$1E,$0D,$0D,$0D
        byte $05,$4A,$04,$1D,$1E,$0D,$4D,$0D,$0D,$4D,$0D,$0D,$4D,$0D,$2E,$2D
        byte $CE,$4A,$04,$1D,$0D,$4D,$0D,$4D,$0D,$0D,$4D,$0D,$1E,$0D,$4D,$0D
        byte $EE,$03,$4B,$0D,$0D,$0D,$0D,$0D,$4D,$0D,$0D,$1E,$2D,$1E,$0D,$4B
        byte $8E,$03,$04,$1D,$0D,$4D,$0D,$4D,$0D,$1E,$2D,$1E,$0D,$0D,$2A,$03
        byte $EE,$4A,$4B,$0D,$1E,$0D,$3D,$0D,$1E,$0D,$2E,$0D,$4D,$4B,$03,$06
        byte $FE,$03,$04,$0D,$2D,$1E,$0D,$1E,$0D,$2E,$0D,$2D,$4B,$4A,$DE,$04
        byte $06,$03,$FA,$04,$1C,$04,$4B,$1C,$4C,$0D,$1D,$4B,$4A,$DD,$04,$02
        byte $CD,$5E,$04,$5B,$5B,$4B,$04,$03,$4A,$1D,$03,$4A,$DE,$CD,$02,$1D
        byte $4A,$04,$EE,$FE,$06,$CE,$FE,$AE,$02,$03,$4A,$CC,$5C,$4A,$04,$0D
        byte $04,$03,$03,$4A,$03,$03,$03,$4A,$03,$4A,$4A,$4A,$4A,$04,$0D,$0D
        byte $0D,$0D,$1D,$0D,$1D,$0D,$1D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$4D,$1E
        byte $1E,$4D,$0D,$1E,$0D,$4D,$0D,$1E,$1E,$4D,$0D,$1E,$4D,$0D,$1E,$0D
        byte $0D,$0D,$4D,$0D,$4D,$0D,$1E,$0D,$0D,$1E,$0D,$4D,$0D,$1E,$0D,$2E
tile005 byte $4D,$0D,$1E,$0D,$1E,$0D,$1E,$0D,$1E,$0D,$1E,$0D,$1E,$0D,$1E,$0D
        byte $0D,$1E,$1D,$1D,$1D,$4D,$0D,$2D,$1D,$1D,$4D,$0D,$1E,$4D,$0D,$1E
        byte $1E,$1D,$4B,$7A,$4A,$03,$04,$4A,$02,$7A,$04,$0D,$1E,$0D,$2E,$4C
        byte $0D,$4B,$03,$DE,$EE,$03,$03,$4A,$CD,$4A,$04,$0D,$2E,$0D,$0D,$04
        byte $4B,$03,$FE,$05,$8E,$05,$4A,$02,$FE,$4A,$04,$0D,$0D,$3E,$0D,$4C
        byte $03,$06,$04,$02,$03,$FE,$4A,$4A,$FE,$03,$2A,$04,$4C,$4B,$04,$FA
        byte $06,$07,$CD,$5B,$04,$06,$02,$4A,$BE,$05,$04,$4B,$DA,$4B,$04,$04
        byte $EE,$FE,$7E,$06,$06,$FE,$7A,$02,$04,$07,$CE,$06,$FE,$06,$EE,$06
        byte $4A,$5A,$03,$4A,$5B,$EE,$4A,$4A,$05,$5B,$4A,$03,$5A,$5A,$03,$4A
        byte $1D,$0D,$0D,$4B,$EA,$7E,$02,$4A,$CE,$03,$04,$0D,$1E,$0D,$1E,$4B
        byte $05,$0D,$1E,$04,$4A,$CE,$4A,$02,$FE,$5A,$04,$0D,$1E,$1E,$1E,$04
        byte $1E,$4D,$0D,$04,$4A,$05,$02,$4A,$CD,$4A,$04,$1E,$1E,$1E,$0D,$04
        byte $1E,$0D,$1E,$4C,$4A,$4A,$03,$4A,$5A,$4A,$1D,$0D,$1E,$1E,$1E,$1D
        byte $0D,$2E,$0D,$1E,$0D,$0D,$0D,$1E,$0D,$05,$0D,$1E,$1E,$1E,$1E,$0D
        byte $1E,$1E,$0D,$1E,$1E,$1E,$1E,$1E,$1E,$0D,$2E,$1E,$1E,$1E,$1E,$1E
        byte $0D,$2E,$0D,$2E,$0D,$1E,$1E,$0D,$1E,$1E,$1E,$1E,$1E,$0D,$2E,$1E
tile006 byte $1E,$0D,$1E,$1E,$0D,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E
        byte $2D,$1D,$1D,$1E,$1E,$0D,$2E,$0D,$1E,$0D,$1E,$0D,$1E,$1D,$1D,$1D
        byte $02,$7A,$4A,$1D,$1E,$1E,$0D,$3E,$1E,$1E,$2E,$1E,$1D,$5A,$7A,$02
        byte $4A,$DD,$02,$1D,$1E,$1E,$2E,$0D,$2E,$0D,$2E,$1E,$1D,$7A,$CD,$4A
        byte $4A,$EE,$4A,$1D,$1E,$1E,$1E,$1E,$1E,$2E,$0D,$2E,$1D,$02,$EE,$4A
        byte $03,$8E,$5A,$05,$0D,$1E,$1E,$1E,$0D,$2E,$1E,$1E,$1D,$7A,$EE,$5A
        byte $FE,$04,$4A,$0D,$1E,$1E,$1E,$1E,$2E,$0D,$2E,$0D,$1D,$7A,$EE,$4A
        byte $06,$03,$03,$1E,$1E,$1E,$1E,$0D,$2E,$2E,$1E,$2E,$1D,$4A,$BE,$4A
        byte $04,$5D,$4A,$0D,$1E,$1E,$1E,$2E,$1E,$0D,$2E,$1E,$1D,$02,$FE,$8A
        byte $03,$CE,$4A,$1D,$1E,$1E,$1E,$1E,$1E,$2E,$1E,$1E,$1D,$8A,$EE,$4A
        byte $4A,$EE,$7A,$1D,$1E,$1E,$1E,$1E,$1E,$0E,$1E,$1E,$1D,$4A,$BE,$4A
        byte $4A,$CD,$02,$05,$0D,$1E,$1E,$1E,$1E,$0D,$0E,$1E,$1D,$7A,$CD,$4A
        byte $4A,$4A,$03,$1D,$0E,$1E,$1E,$0E,$1E,$2E,$1E,$0E,$0D,$4A,$4A,$4A
        byte $1E,$0D,$1E,$1E,$1E,$1E,$1E,$1E,$0E,$0D,$0E,$1E,$1E,$1E,$1E,$0D
        byte $1E,$1E,$1E,$1E,$1E,$1E,$0E,$0D,$2E,$0E,$2E,$1E,$0E,$1E,$0E,$0E
        byte $1E,$1E,$1E,$1E,$1E,$1E,$1E,$0E,$1E,$1E,$1E,$0E,$1E,$0E,$1E,$1E
tile007 byte $1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E
        byte $1E,$1E,$1D,$1D,$1D,$5C,$04,$04,$1D,$1D,$1E,$1E,$1E,$1D,$1D,$1D
        byte $04,$4B,$4A,$03,$04,$4B,$EB,$4B,$5A,$5A,$04,$1D,$4B,$8A,$03,$04
        byte $03,$03,$FE,$06,$06,$07,$06,$07,$06,$CD,$4A,$03,$03,$EE,$FE,$8E
        byte $4A,$EE,$CD,$03,$03,$03,$03,$5A,$03,$FE,$04,$02,$EE,$04,$03,$03
        byte $4A,$CE,$03,$4B,$1D,$CD,$1D,$1D,$5B,$03,$CD,$7A,$FE,$03,$04,$1E
        byte $02,$FE,$5A,$04,$1E,$1E,$1E,$EE,$04,$03,$5D,$02,$8E,$4A,$04,$1E
        byte $7A,$CE,$03,$04,$1E,$1E,$1E,$1E,$04,$4A,$DD,$02,$FE,$03,$04,$0E
        byte $02,$FE,$5A,$04,$0E,$1E,$0E,$1E,$04,$3A,$05,$4A,$7E,$4A,$04,$0E
        byte $4A,$CE,$03,$04,$1E,$0E,$1E,$0E,$04,$4A,$CD,$02,$06,$03,$4B,$04
        byte $02,$FE,$5A,$04,$1E,$0E,$1E,$1E,$1D,$4A,$05,$4A,$05,$EE,$04,$4B
        byte $7A,$CD,$4A,$04,$1E,$0E,$2E,$0E,$04,$4A,$CD,$4A,$4A,$04,$DE,$FE
        byte $4A,$4A,$4A,$1D,$0E,$1E,$0E,$1E,$1D,$4A,$4A,$4A,$04,$03,$03,$03
        byte $1E,$1E,$1E,$EE,$1E,$0E,$1E,$0E,$1E,$1E,$1E,$1E,$0E,$0E,$1E,$1E
        byte $1E,$0E,$0E,$1E,$0E,$1E,$0E,$0E,$0E,$0E,$0E,$0E,$1E,$0E,$0E,$0E
        byte $0E,$1E,$1E,$0E,$1E,$0E,$2E,$0E,$2E,$1E,$0E,$1E,$0E,$0E,$2E,$0E
tile008 byte $1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$0E,$1E
        byte $5D,$04,$04,$04,$1D,$1E,$1E,$1E,$0E,$1E,$1E,$0E,$1E,$1E,$2E,$1E
        byte $4B,$04,$4B,$FA,$7A,$1D,$0E,$1E,$1E,$2E,$1E,$1E,$0E,$2E,$0E,$1E
        byte $FE,$FE,$06,$05,$7A,$1D,$1E,$0E,$1E,$0E,$1E,$0E,$2E,$0E,$1E,$1E
        byte $03,$03,$4A,$03,$4A,$ED,$2E,$1E,$0E,$1E,$0E,$1E,$2E,$0E,$1E,$0E
        byte $0D,$1E,$1E,$ED,$1E,$2E,$0E,$2E,$0E,$2E,$1E,$0E,$2E,$0E,$1E,$0E
        byte $0E,$1E,$0E,$2E,$2E,$0E,$1E,$0E,$1E,$0E,$2E,$0E,$0E,$1E,$0E,$2E
        byte $2E,$1E,$0E,$2E,$0E,$1E,$0E,$2E,$0E,$1E,$0E,$2E,$0E,$0E,$2E,$0E
        byte $1E,$0E,$0E,$1E,$0E,$0E,$2E,$0E,$0E,$2E,$0E,$0E,$2E,$0E,$0E,$2E
        byte $04,$1D,$04,$04,$1D,$04,$1D,$04,$1E,$0E,$2E,$0E,$0E,$2E,$0E,$0E
        byte $4B,$DA,$4B,$4B,$02,$4A,$4A,$02,$1D,$0E,$0E,$2E,$0E,$0E,$0E,$0E
        byte $06,$8E,$06,$CD,$4A,$02,$CD,$4A,$04,$2E,$0E,$0E,$0E,$2E,$0E,$3E
        byte $4A,$03,$4A,$03,$4A,$03,$4A,$4A,$1D,$EE,$0E,$2E,$0E,$0E,$0E,$0E
        byte $0E,$1E,$1E,$1E,$0E,$1E,$1E,$DE,$1E,$0E,$0E,$0E,$0E,$3E,$0E,$0E
        byte $0E,$1E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$2E,$0E,$0E,$0E,$0E,$0E
        byte $2E,$0E,$0E,$0E,$2E,$0E,$0E,$2E,$0E,$0E,$0E,$0E,$3E,$0E,$0E,$0E
tile009 byte $2E,$1E,$1E,$2E,$1E,$0E,$2E,$1E,$0E,$2E,$0E,$2E,$0E,$2E,$0E,$2E
        byte $0E,$1E,$0E,$1E,$0E,$1E,$2E,$0E,$2E,$0E,$1E,$0E,$2E,$0E,$1E,$0E
        byte $1E,$1E,$0E,$2E,$1E,$0E,$0E,$1E,$0E,$2E,$0E,$1E,$0E,$2E,$0E,$0E
        byte $0E,$2E,$1E,$0E,$1E,$0E,$2E,$0E,$2E,$0E,$0E,$2E,$0E,$0E,$2E,$0E
        byte $2E,$0E,$0E,$1E,$0E,$2E,$0E,$2E,$0E,$2E,$0E,$0E,$2E,$0E,$0E,$0E
        byte $0E,$1E,$0E,$0E,$2E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$3E,$0E
        byte $0E,$2E,$0E,$2E,$0E,$0E,$2E,$0E,$2E,$0E,$2E,$0E,$3E,$0E,$0E,$0E
        byte $0E,$2E,$0E,$0E,$2E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
        byte $0E,$0E,$2E,$0E,$0E,$3E,$0E,$3E,$0E,$0E,$3E,$0E,$0E,$0E,$0E,$0E
        byte $2E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
        byte $0E,$0E,$3E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
        byte $0E,$0E,$0E,$0E,$3E,$0E,$0E,$3E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
        byte $0E,$3E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$3E,$0E,$0E
        byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
        byte $0E,$0E,$0E,$0E,$0E,$3E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$FE
        byte $3E,$0E,$0E,$3E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
tile010 byte $1C,$1D,$04,$1D,$2C,$1D,$1D,$1C,$1D,$1D,$1C,$1D,$1D,$1C,$1D,$4C
        byte $1D,$1C,$2D,$1C,$1D,$1D,$4C,$1D,$04,$2C,$04,$2C,$04,$4B,$4C,$1C
        byte $2D,$4C,$1D,$4C,$1C,$04,$1C,$4B,$2C,$04,$1C,$4C,$1C,$4C,$1C,$04
        byte $1C,$04,$1C,$04,$2C,$4C,$4C,$1C,$04,$2C,$4C,$4B,$1C,$04,$2B,$4C
        byte $4C,$4C,$1C,$4C,$04,$1C,$04,$4C,$2C,$04,$1C,$4C,$04,$2C,$04,$1C
        byte $1C,$4C,$04,$1C,$4C,$4C,$1C,$4C,$04,$1C,$4C,$1C,$4C,$04,$1C,$4C
        byte $4C,$1D,$4C,$4C,$1C,$04,$4C,$1C,$4C,$4C,$04,$1C,$04,$2C,$4B,$2C
        byte $4C,$4C,$1D,$4C,$4C,$1D,$4C,$04,$1C,$1D,$4C,$4C,$1C,$4C,$1C,$04
        byte $1D,$4C,$04,$1D,$4C,$1C,$4C,$1D,$4C,$4C,$1C,$04,$4C,$1C,$04,$2C
        byte $2D,$1D,$4C,$2C,$04,$2D,$4C,$04,$2C,$04,$2D,$2C,$04,$4C,$4C,$1D
        byte $2D,$1D,$4C,$1D,$2D,$4C,$1D,$4C,$1D,$4C,$4C,$1D,$4C,$1D,$4C,$4C
        byte $4D,$3D,$1D,$5C,$2D,$5C,$1D,$4C,$4C,$1D,$4C,$4C,$1D,$4C,$1C,$4C
        byte $4D,$1D,$5D,$2D,$1D,$4C,$1D,$4C,$1D,$4C,$1D,$4C,$04,$4C,$4C,$04
        byte $4D,$3D,$2D,$5C,$1D,$2D,$4C,$1D,$5C,$1D,$4C,$1D,$2C,$4C,$3C,$4C
        byte $4D,$4D,$4D,$1D,$3D,$1D,$1D,$5C,$1D,$4C,$1D,$4C,$4C,$4B,$2C,$4C
        byte $2E,$4D,$1E,$4D,$4D,$5C,$2D,$2D,$4C,$1D,$04,$4C,$1D,$3C,$4B,$4C
tile011 byte $1C,$04,$1C,$04,$4C,$1C,$04,$2C,$04,$1C,$4B,$2C,$04,$1C,$04,$1C
        byte $04,$2C,$4C,$1C,$04,$3C,$4B,$1C,$4C,$1C,$4C,$4B,$1C,$4C,$1C,$4B
        byte $2C,$4B,$1C,$04,$2C,$04,$1C,$4C,$4B,$04,$1C,$4C,$4B,$1C,$04,$4C
        byte $04,$1C,$4C,$1C,$4C,$1C,$04,$1C,$4C,$1C,$04,$1C,$4C,$04,$2C,$1C
        byte $4C,$1C,$04,$4C,$4B,$2C,$4C,$04,$1C,$4C,$1C,$04,$2C,$1C,$04,$4C
        byte $04,$2C,$4C,$1C,$04,$1C,$04,$2C,$4C,$04,$2C,$04,$2C,$04,$2C,$4B
        byte $4C,$1C,$04,$2C,$4C,$4C,$1C,$04,$1C,$4C,$1C,$4C,$04,$2C,$04,$2C
        byte $4C,$04,$2C,$04,$1C,$04,$2C,$4C,$1D,$4B,$4C,$1C,$4C,$1C,$4C,$04
        byte $1D,$1C,$4C,$1D,$4C,$1C,$04,$2D,$4C,$1C,$04,$4C,$1D,$04,$2C,$4C
        byte $4B,$4C,$04,$1C,$4C,$1D,$4C,$1C,$5C,$4C,$1D,$4C,$1C,$4C,$04,$1C
        byte $1D,$4C,$2D,$4C,$04,$2D,$4C,$1D,$4C,$1C,$04,$2D,$4C,$1D,$4C,$04
        byte $4C,$04,$2C,$1D,$4C,$4C,$1D,$4B,$1D,$4C,$2D,$04,$4C,$1D,$4C,$1C
        byte $2C,$2D,$5C,$1D,$4C,$1D,$4C,$1D,$4C,$1D,$4C,$1D,$1D,$4C,$1D,$4C
        byte $2D,$4C,$1D,$4C,$1D,$4C,$1D,$4C,$1D,$5C,$2D,$4C,$1D,$4C,$04,$4C
        byte $04,$4C,$1C,$5C,$1C,$5C,$1D,$04,$4C,$4B,$04,$1C,$04,$4C,$04,$1C
        byte $1C,$4B,$04,$4C,$04,$3C,$4B,$2C,$04,$2C,$4C,$04,$4C,$04,$1C,$04
tile012 byte $1D,$0D,$1E,$1E,$1E,$1E,$0D,$1E,$1E,$ED,$1E,$05,$1E,$1E,$0D,$1E
        byte $1D,$05,$0D,$05,$FD,$1E,$DE,$0D,$EE,$1E,$1E,$1E,$FD,$EE,$1E,$1E
        byte $1D,$0D,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$DE,$1E,$1E,$1E,$DE
        byte $04,$1E,$1E,$ED,$1E,$1E,$ED,$1E,$1E,$FD,$1E,$1E,$1E,$DE,$0D,$1E
        byte $1D,$0D,$1E,$1E,$1E,$1E,$EE,$1E,$1E,$EE,$1E,$DE,$0D,$1E,$1E,$EE
        byte $1D,$1E,$DE,$1E,$FD,$1E,$1E,$1E,$FD,$1E,$1E,$1E,$EE,$1E,$1E,$1E
        byte $1D,$ED,$1E,$1E,$1E,$1E,$DE,$1E,$1E,$EE,$0D,$EE,$0D,$1E,$EE,$FD
        byte $1D,$0D,$1E,$1E,$EE,$FD,$1E,$0E,$FD,$1E,$1E,$1E,$1E,$0E,$0D,$EE
        byte $1D,$0D,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$EE,$1E,$0E,$FD,$1E,$EE,$1E
        byte $04,$1E,$EE,$1E,$1E,$EE,$FD,$0E,$1E,$1E,$FD,$1E,$0E,$1E,$1E,$1E
        byte $1D,$1E,$FD,$0E,$FD,$0E,$1E,$1E,$FD,$0E,$1E,$1E,$1E,$1E,$FD,$0E
        byte $1D,$1E,$0E,$1E,$0E,$1E,$1E,$0E,$1E,$0E,$1E,$0E,$FD,$EE,$1E,$0E
        byte $1D,$DE,$1E,$0E,$1E,$EE,$FD,$0E,$1E,$FD,$0E,$FD,$0E,$1E,$0E,$FD
        byte $04,$0D,$1E,$EE,$FD,$0E,$0E,$0E,$EE,$0E,$1E,$0E,$1E,$EE,$FD,$0E
        byte $04,$0D,$0D,$1D,$05,$1D,$CD,$1D,$0D,$05,$0D,$05,$FD,$1E,$1E,$1E
        byte $4C,$DD,$05,$0D,$05,$0D,$05,$0D,$05,$1D,$DD,$0D,$05,$1D,$ED,$1D
tile013 byte $0D,$1D,$1E,$1D,$4D,$0D,$1D,$1E,$0D,$1D,$1E,$1D,$1E,$1D,$1E,$1D
        byte $1E,$EE,$1E,$1E,$1E,$0D,$1E,$0D,$4D,$0D,$0D,$4D,$0D,$0D,$4D,$0D
        byte $0D,$1E,$1E,$1E,$1E,$DE,$1E,$1E,$1E,$1E,$1E,$0D,$1E,$0D,$1E,$0D
        byte $1E,$EE,$1E,$FD,$EE,$1E,$1E,$1E,$1E,$1E,$FD,$1E,$1E,$1E,$1E,$1E
        byte $FD,$1E,$1E,$1E,$1E,$1E,$FD,$EE,$1E,$EE,$0D,$05,$1E,$EE,$1E,$1E
        byte $1E,$EE,$1E,$1E,$EE,$1E,$EE,$0D,$1E,$1E,$FD,$1E,$1E,$FD,$EE,$1E
        byte $1E,$1E,$1E,$FD,$1E,$EE,$0D,$0E,$1E,$1E,$DE,$FD,$EE,$1E,$1E,$FD
        byte $1E,$0E,$1E,$DE,$1E,$FD,$0E,$1E,$1E,$EE,$0D,$1E,$1E,$1E,$EE,$1E
        byte $1E,$FD,$1E,$1E,$1E,$0E,$1E,$1E,$FD,$1E,$1E,$ED,$1E,$0E,$FD,$0E
        byte $1E,$EE,$1E,$0E,$FD,$1E,$1E,$DE,$1E,$0E,$0D,$1E,$1E,$1E,$0E,$0D
        byte $1E,$FD,$0E,$1E,$EE,$1E,$FD,$0E,$1E,$1E,$DE,$0D,$EE,$FD,$0E,$1E
        byte $1E,$0E,$0D,$1E,$FD,$0E,$1E,$1E,$FD,$0D,$1E,$ED,$1E,$0E,$1E,$EE
        byte $1E,$1E,$EE,$1E,$0E,$1E,$0E,$FD,$05,$ED,$05,$0D,$05,$0D,$1E,$1E
        byte $1E,$0E,$FD,$0E,$1E,$FD,$0E,$1E,$ED,$1D,$1D,$CD,$1D,$DD,$1E,$EE
        byte $ED,$1E,$1E,$FD,$EE,$1E,$1E,$1E,$0D,$CD,$04,$1D,$1D,$05,$FD,$0E
        byte $DD,$1D,$DD,$4D,$ED,$0D,$0D,$05,$0D,$1D,$04,$1D,$CD,$0D,$1E,$0E
tile014 byte $0D,$4D,$0D,$0D,$0D,$1E,$0D,$4D,$0D,$4D,$0D,$1E,$1E,$0D,$1E,$1E
        byte $4D,$0D,$0D,$4D,$0D,$0D,$4D,$0D,$1E,$0D,$1E,$0D,$1E,$1E,$4D,$0D
        byte $0D,$0D,$4D,$0D,$1E,$0D,$1E,$0D,$1E,$0D,$1E,$4D,$0D,$0D,$1E,$0D
        byte $1E,$1E,$1E,$0D,$1E,$0D,$4D,$0D,$1E,$4D,$0D,$1E,$1E,$1E,$0D,$2E
        byte $1E,$1E,$0E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$0D,$1E,$0D,$2E,$0D
        byte $EE,$FD,$EE,$FD,$0E,$1E,$EE,$FD,$0E,$1E,$0E,$1E,$1E,$1E,$1E,$1E
        byte $0E,$1E,$1E,$EE,$1E,$FD,$0E,$1E,$1E,$EE,$FD,$0E,$0E,$0E,$1E,$FD
        byte $EE,$FD,$EE,$0D,$0E,$1E,$DE,$1E,$EE,$FD,$0E,$1E,$EE,$FD,$EE,$1E
        byte $1E,$1E,$0E,$1E,$DE,$1E,$1E,$FD,$0E,$1E,$EE,$1E,$0E,$1E,$EE,$0D
        byte $EE,$1E,$FD,$EE,$1E,$FD,$EE,$0E,$1E,$EE,$1E,$0E,$FD,$0E,$1E,$05
        byte $1E,$EE,$1E,$1E,$0E,$1E,$EE,$1E,$EE,$1E,$0E,$EE,$1E,$EE,$0E,$1E
        byte $FD,$0E,$1E,$EE,$FD,$0E,$1E,$1E,$0E,$FD,$0E,$1E,$0E,$1E,$0E,$FD
        byte $0E,$FD,$EE,$1E,$1E,$EE,$FD,$0E,$EE,$1E,$EE,$0E,$EE,$0E,$1E,$05
        byte $FD,$0E,$1E,$0E,$FD,$0E,$1E,$0E,$1E,$0E,$0E,$1E,$0E,$EE,$0E,$FD
        byte $1E,$1E,$FD,$0E,$1E,$EE,$1E,$0E,$EE,$1E,$0E,$EE,$FD,$0E,$0E,$1E
        byte $1E,$FE,$0E,$1E,$EE,$0E,$1E,$EE,$0E,$1E,$0E,$0E,$0E,$0E,$0E,$1E
tile015 byte $4D,$0D,$2E,$1E,$1E,$1E,$0D,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$0D
        byte $1E,$1E,$0D,$1E,$0D,$2E,$1E,$1E,$1E,$1E,$1E,$0D,$2E,$1E,$1E,$1E
        byte $1E,$1E,$1E,$1E,$1E,$0D,$2E,$0D,$2E,$0D,$2E,$1E,$1E,$0D,$2E,$1E
        byte $1E,$0D,$1E,$0D,$2E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$0E,$0D
        byte $2E,$1E,$1E,$1E,$0D,$2E,$0D,$2E,$1E,$1E,$0D,$2E,$1E,$1C,$4B,$3B
        byte $0D,$1E,$0D,$2E,$1E,$1E,$1E,$1E,$0D,$2E,$1E,$1E,$0D,$4B,$3A,$3A
        byte $0E,$1E,$0E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$4B,$3A,$3A
        byte $EE,$1E,$0E,$1E,$0E,$1E,$0E,$1E,$0E,$1E,$0E,$1E,$0E,$1D,$FB,$4B
        byte $EE,$1E,$0E,$1E,$EE,$FD,$0E,$0E,$FD,$0E,$FD,$0E,$FD,$0E,$EE,$1E
        byte $0E,$0E,$1E,$EE,$0E,$1E,$0E,$1E,$0E,$0E,$1E,$0E,$0E,$1E,$1E,$EE
        byte $EE,$1E,$0E,$EE,$1E,$0E,$EE,$1E,$0E,$1E,$0E,$1E,$0E,$0E,$1E,$0E
        byte $0E,$EE,$1E,$0E,$0E,$1E,$0E,$FD,$0E,$EE,$1E,$0E,$EE,$1E,$0E,$1E
        byte $0E,$0E,$1E,$EE,$0E,$FD,$0E,$EE,$0E,$1E,$0E,$EE,$1E,$0E,$FD,$EE
        byte $0E,$EE,$0E,$1E,$0E,$EE,$0E,$1E,$0E,$EE,$1E,$0E,$0E,$1E,$0E,$1E
        byte $0E,$0E,$0E,$EE,$0E,$1E,$0E,$EE,$1E,$0E,$0E,$FD,$0E,$0E,$0E,$1E
        byte $EE,$0E,$0E,$0E,$0E,$0E,$0E,$1E,$0E,$0E,$EE,$0E,$1E,$EE,$1E,$05
tile016 byte $2E,$1E,$1E,$1E,$1E,$0E,$0D,$2E,$1E,$0E,$0E,$0D,$0E,$1E,$0E,$1E
        byte $1E,$1E,$1E,$0E,$0D,$1E,$0E,$1E,$0E,$0D,$0E,$2E,$0E,$1E,$0E,$1E
        byte $1E,$0E,$0D,$1E,$0E,$1E,$1E,$0E,$0D,$0E,$2E,$0E,$1E,$1E,$0E,$1E
        byte $1E,$0D,$2E,$1E,$0D,$1E,$0D,$0D,$1E,$0D,$0D,$1E,$0D,$1E,$0D,$2E
        byte $3B,$4B,$2A,$2A,$3B,$2A,$2A,$2A,$2A,$2A,$2A,$3B,$3B,$2A,$4B,$3B
        byte $FA,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$03,$3A,$2A,$3A,$2A
        byte $3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$2A,$3A,$3B,$3A,$5B,$2A,$03
        byte $2A,$3A,$3A,$3A,$3A,$1A,$3A,$3A,$3A,$3A,$2A,$3A,$3B,$3A,$3B,$3A
        byte $ED,$0D,$1D,$04,$FB,$5B,$2A,$2A,$3A,$2A,$3A,$3B,$3A,$5B,$3A,$3B
        byte $1E,$EE,$0E,$0E,$2E,$0E,$05,$0D,$1D,$04,$4B,$3B,$03,$3B,$3A,$3B
        byte $1E,$0E,$1E,$0E,$1E,$0E,$1E,$EE,$1E,$1E,$04,$2A,$3A,$3B,$03,$3B
        byte $EE,$1E,$0E,$1E,$0E,$1E,$0E,$1E,$0E,$1E,$04,$2A,$5B,$3A,$3B,$3A
        byte $1E,$0E,$0E,$0E,$0E,$1E,$0E,$1E,$0E,$1E,$04,$2A,$3A,$3B,$7B,$3B
        byte $0E,$0E,$1E,$0E,$1E,$0E,$EE,$1E,$0E,$0D,$04,$2A,$5B,$2A,$2A,$03
        byte $0E,$EE,$0E,$1E,$0E,$0E,$1E,$0E,$0E,$1E,$04,$3B,$03,$2A,$7B,$3B
        byte $1E,$0E,$1E,$0E,$0E,$EE,$0E,$0E,$1E,$0E,$04,$2A,$5B,$2A,$2A,$03
tile017 byte $0E,$0E,$1E,$0E,$0E,$0E,$1E,$0E,$0E,$0E,$2E,$0E,$0E,$1E,$0E,$0E
        byte $0E,$1E,$0E,$1E,$0E,$2E,$0E,$1E,$0E,$1E,$0E,$0E,$2E,$0E,$0E,$2E
        byte $0E,$0E,$1E,$0E,$1E,$0E,$0E,$0E,$2E,$0E,$0E,$1E,$0E,$0E,$0E,$0E
        byte $1E,$1E,$0E,$0E,$0E,$0E,$2E,$0E,$0E,$0E,$0E,$0E,$0E,$2E,$0E,$0E
        byte $4B,$2B,$4B,$4B,$2C,$04,$1D,$1D,$1D,$0D,$4D,$1E,$1E,$0E,$0E,$1E
        byte $03,$2A,$2A,$03,$2A,$2A,$3A,$2A,$03,$3B,$2A,$4B,$2A,$4B,$4B,$04
        byte $3B,$03,$3B,$2A,$5B,$3A,$4B,$2A,$3B,$03,$2A,$03,$3B,$2A,$2A,$2A
        byte $3B,$3A,$5B,$3A,$3B,$2A,$5B,$3A,$3B,$03,$3B,$3B,$03,$2A,$5B,$2A
        byte $03,$3B,$3A,$3B,$03,$3B,$3A,$3B,$03,$3B,$03,$2A,$3B,$03,$2A,$4B
        byte $3A,$5B,$2A,$6B,$2A,$03,$3B,$03,$3B,$2A,$3B,$03,$3B,$2A,$5B,$2A
        byte $5B,$3A,$3B,$2A,$2A,$5B,$2A,$3B,$03,$3B,$03,$3B,$03,$3B,$03,$3B
        byte $3B,$2A,$7B,$2A,$5B,$2A,$03,$3B,$3A,$4B,$2A,$5B,$2A,$3B,$2A,$4B
        byte $03,$3B,$2A,$03,$2A,$5B,$3A,$3B,$3B,$03,$3B,$2A,$03,$4B,$03,$2A
        byte $3B,$3A,$5B,$2A,$6B,$2A,$3B,$03,$3B,$03,$3B,$03,$3B,$2A,$4B,$2A
        byte $2A,$5B,$3A,$3B,$2A,$03,$3B,$03,$3B,$2A,$5B,$2A,$5B,$2A,$03,$4B
        byte $3B,$03,$3B,$03,$3B,$5B,$2A,$5B,$2A,$03,$3B,$03,$3B,$4B,$2A,$4B
tile018 byte $0E,$0E,$2E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$3E,$0E,$0E,$0E,$0E,$0E
        byte $0E,$0E,$0E,$0E,$0E,$0E,$4E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
        byte $0E,$2E,$0E,$0E,$0E,$2E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$3E,$0E
        byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$2E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
        byte $0E,$0E,$0E,$2E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
        byte $2D,$1D,$0D,$1E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$4E,$FE,$0E,$0E
        byte $03,$2A,$5B,$4B,$4B,$04,$1D,$1E,$1E,$FE,$0E,$0E,$FE,$0E,$0E,$FE
        byte $4B,$2A,$03,$2A,$4B,$2A,$03,$4B,$4B,$1D,$04,$0D,$4E,$0E,$0E,$0E
        byte $03,$3B,$4B,$2A,$4B,$2A,$4B,$2A,$4B,$FA,$4B,$4B,$0D,$FE,$FE,$0E
        byte $2A,$4B,$03,$3B,$03,$4B,$FA,$4B,$4B,$4B,$4B,$4B,$FD,$FE,$0E,$FE
        byte $03,$3B,$4B,$2A,$FA,$4B,$4B,$2A,$4A,$FA,$03,$4B,$0D,$FE,$0E,$0E
        byte $4B,$2A,$03,$4B,$4B,$2A,$4B,$03,$3A,$3A,$3A,$2A,$05,$FE,$0E,$FE
        byte $4B,$03,$3B,$2A,$4B,$03,$4B,$2A,$3A,$3A,$3A,$4B,$0D,$FE,$0E,$FE
        byte $4B,$2A,$4B,$03,$2A,$4B,$2A,$03,$3A,$3A,$3A,$3A,$1E,$EE,$0E,$FE
        byte $2A,$03,$4B,$2A,$4B,$4B,$FA,$4B,$3A,$3A,$3A,$2A,$05,$0E,$0E,$EE
        byte $03,$3B,$4B,$4B,$FA,$4B,$2A,$5B,$3A,$3A,$3A,$2A,$1D,$DE,$1E,$1E
tile019 byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$FE,$0E
        byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$FE,$0E
        byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$FE,$0E,$FE,$FE
        byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$FE,$0E,$FE,$FE,$0E,$FE
        byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$FE,$0E,$FE,$0E,$FE,$0E,$FE,$06,$4E
        byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$FE,$0E,$FE,$FE,$0E,$FE,$4E,$0E,$FE
        byte $0E,$FE,$0E,$FE,$0E,$FE,$0E,$FE,$0E,$FE,$0E,$FE,$0E,$FE,$FE,$0E
        byte $FE,$0E,$FE,$0E,$0E,$FE,$0E,$FE,$0E,$FE,$0E,$FE,$0E,$FE,$0E,$FE
        byte $0E,$FE,$0E,$FE,$0E,$FE,$FE,$0E,$FE,$0E,$FE,$0E,$FE,$0E,$FE,$0E
        byte $FE,$0E,$0E,$FE,$FE,$0E,$0E,$FE,$0E,$FE,$0E,$FE,$FE,$FE,$0E,$FE
        byte $FE,$0E,$FE,$0E,$FE,$0E,$FE,$4E,$FE,$FE,$FE,$0E,$06,$0E,$06,$0E
        byte $0E,$FE,$0E,$FE,$0E,$FE,$0E,$FE,$FE,$0E,$06,$0E,$0E,$0E,$0E,$FE
        byte $FE,$0E,$FE,$0E,$FE,$0E,$FE,$FE,$0E,$0E,$0E,$0E,$4E,$FE,$0E,$FE
        byte $0E,$FE,$0E,$FE,$FE,$0E,$4E,$FE,$FE,$0E,$FE,$0E,$FE,$FE,$0E,$FE
        byte $0E,$0E,$EE,$4E,$0E,$FE,$FE,$0E,$FE,$0E,$FE,$0E,$FE,$0E,$FE,$FE
        byte $DE,$1E,$0E,$EE,$0E,$EE,$0E,$0E,$FE,$0E,$FE,$0E,$FE,$0E,$FE,$0E
tile020 byte $4D,$4D,$1D,$5C,$1D,$4C,$04,$4C,$04,$3C,$04,$2C,$4C,$4C,$3C,$4C
        byte $2E,$5D,$4D,$1D,$5C,$1D,$4C,$1D,$4C,$4C,$1C,$5C,$4C,$04,$2C,$4C
        byte $4E,$3E,$3E,$5D,$4D,$5D,$1D,$5C,$1D,$4C,$04,$2D,$4C,$1D,$4C,$1D
        byte $4E,$4E,$3E,$3E,$4D,$4D,$4D,$1D,$5C,$2D,$4C,$1D,$5C,$2D,$5C,$2D
        byte $06,$4E,$4E,$4E,$3E,$4D,$5D,$4D,$1D,$5C,$1D,$5C,$4C,$4C,$4C,$04
        byte $06,$06,$4E,$4E,$3E,$3E,$4D,$4D,$5D,$4D,$3D,$1D,$5C,$1D,$4C,$4C
        byte $06,$4E,$06,$3E,$4E,$3E,$3E,$4D,$4D,$1D,$5D,$2D,$5C,$2D,$04,$2D
        byte $06,$06,$4E,$06,$3E,$3E,$3E,$4D,$05,$4D,$4D,$5C,$1D,$2D,$5C,$2D
        byte $06,$06,$06,$4E,$4E,$4E,$3E,$3E,$4D,$4D,$4D,$1D,$5D,$4C,$1D,$5C
        byte $06,$06,$06,$06,$4E,$4E,$3E,$3E,$4D,$4D,$5D,$4D,$1D,$5C,$2D,$5C
        byte $07,$06,$06,$06,$4E,$06,$3E,$3E,$3E,$4D,$4D,$1D,$5D,$4C,$5C,$1D
        byte $07,$06,$07,$06,$06,$3E,$3E,$3E,$4D,$4D,$5D,$4D,$1D,$5C,$1D,$5C
        byte $07,$07,$06,$06,$4E,$4E,$4E,$3E,$3E,$4D,$4D,$4D,$1D,$5D,$2D,$4C
        byte $06,$07,$06,$06,$06,$06,$3E,$3E,$3E,$4D,$5D,$1D,$5D,$4C,$5C,$1D
        byte $07,$06,$06,$4E,$3E,$3E,$4D,$5D,$4D,$5C,$5C,$4C,$4B,$04,$2D,$4B
        byte $07,$07,$06,$5C,$4C,$4C,$4C,$3C,$5C,$2A,$3B,$2A,$3C,$3C,$4C,$3A
tile021 byte $04,$4C,$4C,$1C,$4B,$4C,$1D,$4C,$4C,$04,$1D,$4C,$1D,$4C,$4C,$04
        byte $4C,$1C,$04,$4C,$04,$2C,$04,$1C,$04,$4C,$4C,$04,$2D,$5C,$1D,$4C
        byte $04,$4C,$04,$2C,$4C,$04,$4C,$4C,$4C,$04,$1D,$4D,$1D,$5C,$1D,$5C
        byte $4C,$4C,$1C,$04,$4C,$1C,$5C,$1D,$4C,$1D,$5C,$1D,$5D,$1D,$5D,$1D
        byte $2C,$04,$4C,$4C,$1D,$04,$4C,$4C,$1D,$5C,$0D,$5D,$1E,$5D,$5D,$4D
        byte $04,$2C,$04,$4C,$4C,$4C,$1D,$5C,$1D,$5D,$5D,$1E,$3E,$05,$1E,$2E
        byte $4C,$1D,$4C,$04,$1D,$04,$2D,$5C,$1D,$5D,$1E,$4E,$3E,$4E,$4E,$4E
        byte $4C,$5C,$1D,$4C,$4C,$1D,$5C,$1D,$5D,$1D,$5E,$4E,$06,$FE,$06,$4E
        byte $1D,$4C,$2D,$04,$2D,$5C,$1D,$5D,$4D,$05,$4E,$06,$06,$06,$06,$06
        byte $2D,$5C,$1D,$4C,$1D,$5C,$1D,$4D,$05,$3E,$FE,$06,$06,$07,$06,$06
        byte $5C,$1D,$5C,$1D,$5C,$2D,$5D,$4D,$2E,$4E,$06,$07,$06,$07,$06,$07
        byte $4C,$1D,$5C,$3D,$1D,$5C,$4D,$1E,$4E,$4E,$06,$07,$07,$06,$07,$06
        byte $5C,$1D,$5C,$1D,$5D,$2D,$5D,$1E,$5E,$FE,$07,$06,$07,$06,$07,$07
        byte $5C,$5C,$2D,$5C,$2D,$5D,$1D,$5D,$4E,$4E,$06,$07,$07,$07,$06,$07
        byte $4B,$4B,$4B,$4B,$4D,$4B,$4B,$4B,$4C,$4C,$5E,$07,$07,$06,$07,$07
        byte $3C,$3C,$3C,$2B,$4C,$3B,$2B,$3C,$3B,$4C,$5D,$07,$07,$06,$07,$07
tile022 byte $1D,$1D,$05,$0D,$05,$0D,$05,$0D,$05,$0D,$05,$1D,$ED,$0D,$05,$1D
        byte $04,$FD,$05,$1E,$05,$0D,$05,$0D,$05,$0D,$05,$0D,$05,$1D,$DD,$0D
        byte $1D,$05,$1E,$ED,$1E,$EE,$1E,$05,$1E,$05,$0D,$05,$0D,$05,$0D,$1D
        byte $04,$1E,$EE,$2E,$EE,$1E,$EE,$1E,$1E,$ED,$1E,$0D,$05,$0D,$CD,$1D
        byte $1D,$DE,$2E,$FE,$5E,$FE,$4E,$EE,$EE,$1E,$05,$1E,$0D,$05,$0D,$05
        byte $5C,$0E,$FE,$06,$FE,$06,$4E,$FE,$4E,$EE,$1E,$05,$0D,$05,$0D,$0D
        byte $05,$FE,$06,$5E,$06,$06,$06,$FE,$FE,$4E,$EE,$1E,$05,$0D,$05,$0D
        byte $1E,$4E,$06,$06,$06,$06,$06,$06,$4E,$FE,$4E,$1E,$1E,$ED,$05,$0D
        byte $3E,$06,$06,$06,$06,$06,$06,$06,$06,$4E,$FE,$EE,$1E,$1E,$0D,$05
        byte $3E,$FE,$06,$07,$06,$07,$06,$06,$06,$06,$4E,$0E,$05,$1E,$05,$0D
        byte $3E,$06,$07,$06,$07,$07,$06,$06,$06,$06,$4E,$0E,$EE,$1E,$05,$0D
        byte $4E,$06,$07,$07,$06,$07,$07,$06,$06,$06,$06,$4E,$1E,$EE,$0D,$05
        byte $4E,$06,$07,$06,$07,$07,$06,$07,$06,$06,$4E,$FE,$4E,$1E,$1E,$0D
        byte $4E,$07,$06,$07,$07,$07,$07,$06,$06,$06,$0E,$4E,$0E,$EE,$05,$1E
        byte $4E,$06,$07,$06,$07,$06,$07,$06,$3E,$3D,$3D,$1D,$1D,$4C,$1D,$04
        byte $0E,$06,$07,$07,$07,$07,$06,$06,$2D,$2D,$2D,$4C,$2C,$1D,$4C,$1C
tile023 byte $05,$0D,$1D,$DD,$1D,$CD,$1D,$DD,$1D,$CD,$4C,$1D,$1D,$CD,$1D,$DD
        byte $DD,$1D,$CD,$0D,$1D,$05,$0D,$1D,$CD,$1D,$04,$1D,$DC,$1D,$CD,$1D
        byte $05,$0D,$1D,$CD,$0D,$1D,$CD,$0D,$05,$1D,$ED,$1D,$05,$0D,$05,$0D
        byte $DD,$0D,$05,$1D,$CD,$0D,$1D,$CD,$0D,$CD,$1D,$DD,$0D,$05,$1D,$DD
        byte $1D,$CD,$1D,$DD,$1D,$CD,$0D,$1D,$05,$1D,$DD,$1D,$05,$1D,$DD,$1D
        byte $05,$0D,$0D,$05,$0D,$1D,$CD,$1D,$DD,$0D,$5D,$ED,$1D,$DD,$0D,$05
        byte $CD,$1D,$CD,$1D,$CD,$0D,$05,$0D,$1D,$CD,$1D,$1D,$CD,$0D,$05,$1D
        byte $1D,$05,$0D,$0D,$05,$1D,$DD,$1D,$CD,$0D,$CD,$1D,$DD,$1D,$05,$0D
        byte $0D,$05,$1D,$DD,$1D,$CD,$1D,$05,$0D,$1D,$CD,$1D,$05,$0D,$DD,$0D
        byte $05,$0D,$DD,$1D,$05,$0D,$DD,$1D,$CD,$0D,$1D,$CD,$0D,$05,$1D,$05
        byte $05,$0D,$05,$0D,$0D,$5D,$0D,$1D,$05,$0D,$CD,$1D,$05,$1D,$DD,$0D
        byte $0D,$05,$1D,$CD,$1D,$ED,$1D,$CD,$0D,$1D,$05,$1D,$ED,$05,$0D,$05
        byte $05,$0D,$0D,$05,$0D,$CD,$0D,$05,$1D,$CD,$1D,$CD,$1D,$0D,$05,$0D
        byte $0D,$05,$DD,$1D,$05,$1D,$CD,$1D,$DD,$0D,$05,$1D,$CD,$05,$1D,$05
        byte $4C,$1D,$04,$2D,$04,$1D,$4C,$04,$2D,$04,$5C,$1D,$04,$1D,$04,$1D
        byte $3B,$5C,$1D,$2C,$1C,$4C,$2C,$2D,$2C,$2A,$04,$1C,$2C,$2C,$1C,$4C
tile024 byte $1D,$ED,$0D,$05,$0D,$0D,$1E,$1E,$EE,$0E,$EE,$0E,$0E,$0E,$EE,$0E
        byte $DD,$1D,$05,$1D,$DD,$05,$ED,$0D,$0D,$ED,$0D,$05,$0D,$05,$1E,$0D
        byte $05,$0D,$DD,$0D,$1D,$DD,$1D,$05,$05,$1E,$05,$1E,$05,$1E,$1E,$CD
        byte $1D,$CD,$1D,$05,$ED,$4D,$DD,$0D,$05,$0D,$05,$1E,$1E,$DE,$1E,$05
        byte $05,$0D,$05,$0D,$05,$0D,$1D,$05,$0D,$05,$0E,$1E,$DE,$1E,$EE,$1E
        byte $0D,$DD,$1D,$05,$0D,$05,$05,$0D,$05,$1E,$EE,$1E,$EE,$EE,$0E,$EE
        byte $CD,$0D,$05,$0D,$05,$0D,$05,$1E,$1E,$DE,$0E,$EE,$4E,$FE,$FE,$4E
        byte $05,$0D,$05,$0D,$05,$0D,$05,$FD,$EE,$1E,$EE,$4E,$06,$06,$06,$4E
        byte $05,$0D,$0D,$05,$1E,$1E,$1E,$05,$0E,$EE,$4E,$06,$06,$FE,$06,$06
        byte $0D,$05,$0D,$05,$0D,$05,$1E,$EE,$1E,$FE,$06,$06,$06,$06,$06,$06
        byte $05,$0D,$05,$0D,$05,$1E,$1E,$DE,$0E,$06,$4E,$06,$06,$06,$06,$06
        byte $1D,$05,$0D,$05,$1E,$1E,$05,$0E,$4E,$06,$06,$06,$07,$07,$06,$06
        byte $ED,$0D,$05,$0D,$05,$1E,$DE,$EE,$0E,$06,$06,$06,$07,$06,$07,$06
        byte $1D,$05,$0D,$05,$0D,$05,$1E,$1E,$4E,$06,$06,$06,$06,$07,$07,$06
        byte $04,$04,$1D,$5C,$1D,$1D,$05,$2E,$4D,$05,$2E,$07,$07,$07,$06,$07
        byte $1C,$2B,$4B,$1D,$2C,$4C,$4C,$2D,$2C,$4B,$3E,$06,$07,$06,$07,$06
tile025 byte $0E,$FE,$FE,$0E,$0E,$0E,$EE,$0E,$0E,$EE,$1E,$0E,$0E,$1E,$FD,$0D
        byte $EE,$2E,$EE,$0E,$4E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$1E,$FE,$05,$1D
        byte $1E,$1E,$05,$1E,$ED,$05,$0D,$05,$0D,$05,$0D,$1E,$1E,$1E,$DD,$1D
        byte $1E,$EE,$1E,$EE,$1E,$1E,$05,$1E,$ED,$1E,$05,$ED,$05,$0D,$05,$1D
        byte $EE,$EE,$0E,$4E,$DE,$1E,$1E,$05,$1E,$05,$0D,$05,$0D,$05,$0D,$1D
        byte $4E,$FE,$FE,$0E,$EE,$1E,$DE,$1E,$ED,$1E,$0D,$05,$0D,$05,$0D,$05
        byte $06,$06,$4E,$FE,$4E,$EE,$1E,$1E,$1E,$05,$05,$0D,$05,$0D,$05,$0D
        byte $06,$06,$06,$06,$FE,$4E,$EE,$EE,$05,$1E,$FD,$05,$1E,$1E,$05,$0D
        byte $06,$06,$06,$06,$06,$FE,$4E,$1E,$0E,$1E,$05,$1E,$0D,$05,$1E,$05
        byte $06,$06,$06,$06,$06,$4E,$FE,$0E,$DE,$1E,$ED,$1E,$05,$1E,$ED,$1E
        byte $06,$07,$06,$06,$06,$06,$4E,$0E,$1E,$EE,$1E,$05,$1E,$05,$1E,$05
        byte $07,$06,$07,$06,$06,$06,$06,$4E,$EE,$1E,$DE,$1E,$1E,$ED,$1E,$05
        byte $07,$07,$07,$06,$06,$06,$06,$0E,$1E,$EE,$1E,$05,$1E,$05,$1E,$ED
        byte $07,$06,$07,$07,$06,$06,$4E,$0E,$4E,$1E,$EE,$1E,$1E,$DE,$1E,$1E
        byte $07,$06,$07,$06,$06,$4E,$4E,$3E,$05,$05,$4D,$05,$1D,$5D,$1D,$05
        byte $07,$07,$07,$06,$3E,$4D,$3D,$2D,$2C,$5C,$1D,$3C,$4C,$1C,$4C,$5C
tile026 byte $DD,$1E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$4E,$04,$3B,$3A,$5B,$2A,$5B
        byte $05,$0D,$EE,$0E,$0E,$0E,$4E,$FE,$0E,$0E,$4C,$03,$3B,$03,$3B,$3A
        byte $DC,$1E,$0E,$4E,$0E,$FE,$FE,$4E,$FE,$FE,$5C,$2A,$5B,$2A,$5B,$2A
        byte $1D,$05,$0D,$05,$1E,$1E,$EE,$4E,$0E,$4E,$1D,$5B,$5B,$3B,$5B,$5B
        byte $CD,$0D,$05,$1E,$1E,$05,$1E,$1E,$EE,$1E,$5D,$04,$4B,$5B,$4B,$4B
        byte $05,$1E,$05,$0D,$05,$0E,$1E,$DE,$2E,$CE,$05,$5D,$04,$04,$4B,$04
        byte $05,$0D,$1E,$05,$0E,$05,$EE,$1E,$05,$4E,$1E,$5D,$1D,$5C,$04,$04
        byte $05,$1E,$DE,$1E,$1E,$EE,$2E,$EE,$4E,$06,$1E,$05,$5D,$04,$4C,$04
        byte $0D,$05,$1E,$DE,$1E,$EE,$EE,$4E,$FE,$5E,$FE,$4E,$4D,$5D,$04,$5C
        byte $05,$1E,$EE,$1E,$1E,$EE,$4E,$FE,$06,$06,$06,$4E,$4E,$05,$5C,$1D
        byte $1E,$1E,$DE,$1E,$CE,$4E,$4E,$06,$4E,$06,$06,$06,$FE,$4D,$5D,$04
        byte $FD,$DE,$1E,$05,$0E,$4E,$FE,$5E,$06,$06,$06,$07,$06,$4E,$5D,$5C
        byte $2E,$05,$0E,$1E,$EE,$5E,$06,$06,$FE,$06,$07,$06,$06,$4E,$1E,$5C
        byte $05,$0E,$05,$EE,$4E,$FE,$FE,$06,$06,$06,$07,$07,$07,$06,$5D,$1D
        byte $2E,$05,$3E,$4E,$06,$4E,$06,$4E,$06,$06,$06,$07,$06,$06,$3E,$5D
        byte $4C,$2D,$3D,$3D,$3D,$4E,$4E,$06,$06,$4C,$06,$07,$06,$4E,$3E,$CD
tile027 byte $3A,$3B,$5B,$2A,$03,$2A,$03,$3B,$03,$3B,$3B,$2A,$4B,$03,$3B,$2A
        byte $4B,$2A,$03,$3B,$3B,$5B,$2A,$3B,$03,$2A,$03,$4B,$2A,$4B,$03,$4B
        byte $5B,$2A,$5B,$3A,$3B,$3A,$5B,$2A,$5B,$2A,$5B,$2A,$03,$3B,$2A,$4B
        byte $3B,$03,$3B,$3B,$5B,$2A,$4B,$3A,$3B,$03,$3B,$2A,$5B,$2A,$5B,$2A
        byte $5B,$4B,$3B,$03,$3B,$2A,$5B,$2A,$5B,$2A,$4B,$4B,$4B,$4B,$3B,$5B
        byte $4B,$4B,$3B,$2A,$5B,$3B,$03,$3B,$2A,$5B,$4B,$4B,$4B,$4B,$2A,$4B
        byte $04,$4B,$5B,$5B,$3B,$5B,$3B,$5B,$3B,$03,$4B,$4B,$4B,$4B,$5B,$4B
        byte $4C,$4B,$4B,$3B,$5B,$3B,$5B,$4B,$4B,$3B,$4B,$04,$4B,$04,$04,$4B
        byte $04,$5C,$3B,$5B,$4B,$4B,$4C,$3B,$3B,$5C,$04,$2A,$FB,$4B,$EB,$4B
        byte $5C,$04,$4B,$4C,$4B,$4C,$5B,$5B,$4B,$4B,$4C,$04,$4B,$04,$4B,$4B
        byte $1D,$5C,$4B,$5C,$5C,$4C,$5C,$4C,$4C,$5B,$4B,$04,$04,$04,$04,$5C
        byte $1D,$5C,$4C,$5D,$4D,$4E,$3E,$5D,$5C,$4B,$4C,$04,$1D,$04,$4C,$04
        byte $CD,$5C,$5C,$4D,$06,$06,$06,$4D,$5C,$5C,$04,$5C,$04,$04,$1D,$04
        byte $5C,$5D,$1D,$5E,$06,$06,$06,$06,$2E,$5C,$4C,$04,$1D,$04,$5C,$5C
        byte $5D,$5C,$5D,$FE,$06,$07,$07,$06,$4D,$5C,$04,$04,$04,$04,$04,$5C
        byte $5D,$5D,$5D,$4E,$07,$06,$07,$FE,$4E,$5C,$04,$5B,$5B,$5B,$5B,$5C
tile028 byte $4B,$2A,$4B,$2A,$4B,$4B,$4B,$2A,$4A,$3A,$3A,$5B,$1D,$05,$FD,$EE
        byte $3B,$03,$2A,$4B,$4B,$2A,$4B,$03,$3A,$3A,$3A,$3B,$05,$1E,$1E,$1E
        byte $2A,$4B,$03,$4B,$2A,$4B,$4B,$2A,$3A,$3A,$3A,$4B,$4C,$ED,$1E,$ED
        byte $03,$4B,$3B,$4B,$4B,$4B,$3B,$4B,$3A,$3A,$3B,$4B,$04,$1E,$1E,$1E
        byte $4B,$2A,$4B,$2A,$4B,$3B,$2A,$3B,$4B,$3B,$4B,$04,$1D,$04,$1D,$DC
        byte $5B,$2A,$5B,$3B,$4B,$4B,$4B,$3A,$3B,$5B,$3A,$4B,$05,$1E,$05,$1E
        byte $5B,$03,$3B,$4B,$4C,$4C,$4B,$5B,$6B,$2A,$3A,$4C,$05,$FD,$EE,$1E
        byte $04,$3B,$5B,$4C,$5C,$4D,$5C,$4B,$3B,$7B,$2A,$5C,$FE,$05,$0D,$05
        byte $EB,$4B,$4B,$04,$04,$5C,$4C,$4B,$5B,$5B,$2A,$5D,$06,$06,$1E,$2E
        byte $04,$2A,$4B,$4B,$1D,$4E,$5C,$4B,$5B,$5B,$4B,$3E,$07,$06,$06,$06
        byte $04,$4B,$4B,$5C,$4D,$4E,$5C,$04,$4B,$5B,$3B,$5D,$06,$4E,$EE,$05
        byte $1D,$5B,$4B,$4B,$5C,$4C,$4C,$4B,$5C,$5B,$3A,$5C,$FE,$4E,$1E,$FE
        byte $5D,$5B,$4B,$4B,$4C,$04,$4B,$5C,$5B,$5B,$3B,$5C,$2E,$DE,$4E,$06
        byte $05,$4B,$4B,$4B,$4B,$4B,$4C,$4B,$5C,$5B,$5B,$4B,$3E,$05,$FE,$06
        byte $05,$4B,$3B,$4B,$4B,$4B,$4B,$4B,$5C,$5B,$3B,$5B,$5D,$1E,$4E,$06
        byte $05,$5B,$4B,$4B,$4B,$4B,$4B,$4B,$5C,$04,$6A,$3B,$5C,$4D,$3D,$4D
tile029 byte $1E,$ED,$1E,$0D,$05,$0D,$1E,$EE,$1E,$EE,$0E,$4E,$FE,$0E,$FE,$0E
        byte $1E,$0D,$05,$1E,$ED,$1E,$ED,$0D,$05,$0D,$1E,$1E,$1E,$EE,$0E,$FE
        byte $1E,$05,$FD,$1E,$1E,$0D,$05,$0D,$0D,$05,$0D,$DD,$0D,$EE,$1E,$EE
        byte $1E,$ED,$2E,$1E,$05,$0D,$1E,$05,$0D,$0D,$05,$1D,$05,$1E,$EE,$0E
        byte $1E,$1E,$1E,$ED,$1E,$0D,$05,$0D,$0D,$05,$1D,$ED,$1E,$1E,$DE,$1E
        byte $DE,$1E,$1E,$1E,$1E,$1E,$0D,$05,$0D,$0D,$05,$0D,$05,$FD,$1E,$DE
        byte $1E,$DE,$1E,$1E,$DE,$0D,$05,$1D,$DD,$0D,$0D,$05,$0D,$DE,$1E,$1E
        byte $1E,$0D,$05,$0D,$DD,$1D,$ED,$1D,$CD,$1D,$05,$0D,$0D,$05,$1E,$1E
        byte $05,$05,$1E,$05,$0D,$1D,$CD,$1D,$1D,$CD,$1D,$1D,$CD,$0D,$1E,$DD
        byte $0E,$EE,$4E,$1E,$CD,$1D,$CD,$1D,$CD,$1D,$04,$0D,$1D,$04,$04,$1C
        byte $06,$4E,$06,$1E,$05,$0D,$1D,$CD,$1D,$1D,$DD,$1D,$05,$1C,$3B,$4B
        byte $06,$06,$06,$FE,$05,$05,$1D,$1D,$CD,$1D,$05,$05,$1E,$04,$2B,$4B
        byte $06,$06,$06,$06,$2E,$0D,$CD,$1D,$DC,$5D,$1D,$1E,$FE,$1D,$04,$2B
        byte $06,$07,$07,$06,$4E,$05,$1D,$05,$1D,$DD,$0D,$5E,$07,$5D,$4B,$2A
        byte $07,$07,$07,$06,$4E,$ED,$1D,$5D,$1D,$5D,$1E,$06,$06,$FE,$4C,$4B
        byte $07,$06,$07,$05,$4B,$5C,$2A,$4B,$4B,$2B,$3D,$4C,$06,$05,$4B,$5B
tile030 byte $07,$06,$06,$4C,$4B,$3D,$4C,$4C,$4C,$6B,$2B,$3B,$3C,$3C,$3C,$3B
        byte $07,$06,$06,$4C,$4C,$3D,$3E,$4C,$4C,$2A,$3C,$3B,$3C,$3C,$4C,$3B
        byte $06,$07,$3E,$5C,$5C,$5C,$4D,$4C,$4B,$4B,$4B,$4C,$3C,$4C,$4C,$6C
        byte $06,$06,$4E,$04,$3B,$3C,$3B,$3C,$4C,$3A,$3B,$6B,$3B,$3B,$3B,$2A
        byte $06,$06,$3E,$3C,$3B,$4C,$3C,$3C,$4C,$3A,$3C,$3B,$3C,$3C,$3C,$6B
        byte $06,$06,$3E,$4B,$3C,$3C,$3D,$3D,$4C,$3B,$3B,$3B,$3C,$3C,$3C,$2A
        byte $06,$4E,$4E,$4B,$3C,$3C,$3D,$3C,$4C,$6B,$2B,$3B,$3C,$3C,$3C,$6B
        byte $06,$4E,$4E,$3B,$3C,$3C,$3D,$3C,$3C,$3B,$3B,$3B,$3C,$3C,$6C,$2A
        byte $4E,$06,$3E,$3B,$3B,$3C,$3C,$3D,$3C,$6B,$3C,$3B,$3C,$3C,$3C,$6B
        byte $4E,$4E,$3E,$3B,$3B,$3C,$3C,$3C,$3C,$2A,$3B,$3B,$3C,$3C,$3C,$3A
        byte $4E,$4E,$4D,$5B,$3B,$3C,$3D,$3C,$4C,$6B,$3B,$3B,$3C,$3C,$3B,$6B
        byte $4E,$4E,$3E,$3B,$3B,$3C,$3C,$3C,$3C,$3A,$3C,$6B,$3C,$3C,$3C,$6A
        byte $3E,$4D,$4D,$3B,$3B,$3C,$3C,$3C,$4C,$6B,$2B,$3B,$3B,$6B,$3B,$3A
        byte $4C,$04,$4B,$4B,$5B,$4C,$6C,$3C,$4C,$3B,$3C,$5B,$3B,$4B,$3C,$03
        byte $4B,$4C,$4B,$2A,$6A,$3A,$3A,$6B,$3B,$6A,$3A,$2A,$6A,$3B,$5B,$3A
        byte $4B,$3C,$4B,$3A,$2A,$3B,$3B,$3B,$3B,$3A,$3A,$6B,$3A,$3A,$3A,$3A
tile031 byte $3C,$3C,$3C,$3C,$3D,$3B,$3B,$3C,$3C,$3B,$4D,$06,$07,$07,$06,$07
        byte $3C,$3C,$3C,$3C,$3D,$3B,$3C,$3B,$3C,$3C,$5D,$06,$07,$06,$07,$06
        byte $3C,$3C,$3C,$4C,$4C,$5B,$3B,$3C,$5B,$3C,$5D,$06,$06,$07,$06,$06
        byte $3B,$6B,$3B,$3B,$3B,$3B,$3B,$3B,$3B,$3B,$5B,$06,$06,$06,$06,$06
        byte $3C,$3C,$3C,$3C,$4C,$3A,$3B,$3B,$3C,$3B,$4C,$5E,$06,$4E,$06,$4E
        byte $3C,$3C,$3C,$3C,$6C,$3B,$3B,$3C,$3B,$3C,$4C,$5D,$4E,$FE,$4E,$4E
        byte $3C,$3C,$3C,$3C,$3C,$3B,$3B,$3C,$3C,$3B,$4C,$5D,$4E,$5E,$4E,$3E
        byte $3C,$3C,$3C,$3C,$3C,$6B,$3B,$3C,$3B,$3C,$4C,$5D,$5D,$3E,$5D,$5D
        byte $3C,$3C,$3C,$3C,$3B,$3B,$3B,$3C,$3B,$3C,$4B,$3D,$5D,$5C,$05,$5D
        byte $3C,$3C,$3C,$3C,$3C,$6A,$3B,$3C,$3B,$3B,$5B,$5C,$4D,$04,$1D,$5D
        byte $3C,$3C,$3C,$3C,$6C,$2A,$3B,$3B,$3C,$3B,$5C,$5C,$1D,$04,$5D,$1D
        byte $3A,$2A,$6B,$2A,$3B,$3A,$3B,$3C,$3B,$3C,$5B,$5C,$5C,$04,$04,$4D
        byte $3A,$3A,$3A,$3A,$3B,$3B,$3B,$3C,$3C,$3B,$5C,$4C,$04,$4B,$04,$1D
        byte $3B,$3B,$6B,$2A,$3B,$6B,$3B,$3B,$3C,$3B,$5B,$3D,$04,$4C,$04,$5C
        byte $5B,$3A,$3B,$5B,$4B,$3B,$3B,$4B,$3B,$6C,$04,$4B,$4B,$04,$4B,$04
        byte $3A,$3A,$3A,$3A,$2A,$6A,$3A,$3A,$3A,$3A,$4B,$3B,$4B,$2A,$03,$4B
tile032 byte $4E,$06,$06,$07,$06,$07,$07,$06,$2D,$2D,$2C,$1D,$4C,$1C,$4C,$2D
        byte $4E,$06,$06,$07,$06,$07,$06,$06,$2D,$1D,$4C,$1C,$1D,$4C,$1C,$1D
        byte $4E,$06,$06,$06,$06,$06,$06,$06,$1D,$1D,$1D,$5C,$1D,$04,$1D,$4C
        byte $1E,$4E,$06,$06,$06,$06,$06,$06,$4C,$2C,$4B,$1C,$3C,$1C,$2C,$1C
        byte $4D,$FE,$06,$06,$06,$06,$06,$0E,$2D,$2C,$2C,$4C,$1C,$4C,$4C,$1C
        byte $05,$4E,$4E,$06,$FE,$06,$4E,$FE,$2D,$2C,$4C,$1C,$4C,$1C,$2C,$4C
        byte $5D,$05,$4E,$FE,$4E,$06,$4E,$4E,$2D,$2C,$1C,$4C,$1C,$4C,$1C,$1C
        byte $1D,$CE,$4E,$4E,$4E,$4E,$FE,$4E,$2D,$2C,$4C,$1C,$4C,$1C,$4C,$3C
        byte $1D,$CE,$4E,$EE,$FE,$4E,$0E,$1E,$4C,$1C,$2B,$1C,$4B,$2B,$2B,$1C
        byte $5D,$1E,$DE,$0E,$EE,$4E,$EE,$1E,$2C,$4C,$1C,$4B,$2C,$2B,$3C,$2B
        byte $5D,$ED,$1E,$05,$1E,$DE,$1E,$05,$1C,$2B,$4C,$1C,$2B,$2B,$2B,$2B
        byte $5C,$1E,$05,$1E,$05,$1E,$05,$1E,$4C,$1C,$2B,$2B,$2B,$2B,$2B,$2B
        byte $5C,$ED,$1E,$ED,$05,$0D,$05,$0D,$4C,$2B,$2B,$2B,$2B,$3B,$2B,$3B
        byte $1D,$05,$05,$0D,$05,$1E,$05,$0D,$2B,$2B,$3B,$2B,$4B,$2C,$4C,$2B
        byte $1D,$1D,$DC,$1D,$04,$1D,$04,$1D,$04,$1D,$1D,$04,$1D,$4B,$04,$2B
        byte $03,$4B,$FA,$4B,$FB,$2A,$FA,$04,$1C,$3B,$3B,$3B,$2A,$2B,$2A,$2B
tile033 byte $2B,$1D,$2C,$4C,$1C,$4C,$1C,$3C,$1C,$3B,$04,$2C,$4C,$1C,$4C,$1C
        byte $4B,$1D,$1D,$4C,$1D,$1C,$4C,$1D,$4B,$1C,$5C,$1D,$1D,$1D,$4C,$1D
        byte $04,$1D,$04,$1D,$04,$4C,$04,$1C,$1D,$4B,$1D,$04,$1D,$04,$1C,$04
        byte $3B,$4B,$2C,$2C,$1C,$1C,$2B,$2B,$2B,$2A,$04,$2C,$2C,$2C,$4C,$1C
        byte $3B,$5C,$1C,$4C,$2C,$2B,$4C,$1C,$2B,$3B,$04,$1C,$4C,$1C,$1C,$4C
        byte $2A,$1D,$2C,$1C,$4B,$1C,$2B,$2B,$2B,$2A,$04,$2C,$2C,$4C,$2B,$4C
        byte $3B,$4C,$4C,$1C,$2B,$2B,$3C,$2B,$2B,$2A,$04,$2D,$1C,$4C,$1C,$4C
        byte $3B,$04,$2C,$2B,$4C,$2B,$2B,$2B,$2B,$3B,$4B,$2D,$2C,$4C,$1C,$4C
        byte $3B,$4C,$1C,$2B,$2B,$2B,$2B,$2B,$3B,$3B,$04,$2C,$2C,$4C,$1C,$4C
        byte $2A,$4B,$3C,$2B,$2B,$2B,$4B,$2B,$2B,$2A,$4B,$1D,$2C,$1C,$4C,$1C
        byte $2A,$04,$2B,$2B,$3B,$2B,$2B,$3B,$2B,$2A,$4B,$2D,$1C,$4C,$1C,$4C
        byte $2A,$4B,$2B,$2B,$2B,$3B,$2B,$2A,$2B,$2A,$4B,$1D,$2B,$4C,$1C,$3C
        byte $2A,$4B,$3C,$3B,$2B,$3B,$2A,$2B,$2A,$2A,$04,$1D,$2C,$1D,$4C,$04
        byte $04,$1D,$04,$2C,$04,$1C,$04,$04,$4B,$04,$1D,$4C,$04,$2C,$4B,$1C
        byte $03,$4B,$4B,$2A,$2A,$2A,$2A,$2A,$1A,$3A,$4B,$1C,$2B,$2B,$2B,$3B
        byte $3A,$4B,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$3A,$4B,$2B,$2B,$3B,$2B,$3B
tile034 byte $4C,$3B,$4B,$1D,$2C,$2C,$2D,$4C,$1D,$2B,$5D,$06,$07,$07,$06,$07
        byte $1C,$4C,$1D,$1D,$4C,$1D,$1D,$1D,$1D,$5C,$1E,$06,$06,$07,$06,$06
        byte $1D,$4B,$04,$1D,$04,$4C,$1D,$04,$2D,$4B,$0D,$06,$06,$06,$06,$06
        byte $3C,$2B,$4B,$1C,$2C,$1C,$4C,$1C,$2C,$3B,$5C,$06,$06,$06,$06,$06
        byte $1C,$3B,$4B,$1D,$4C,$1C,$4C,$1C,$4C,$3B,$1D,$FE,$06,$FE,$06,$4E
        byte $1C,$4B,$4B,$1D,$2B,$2C,$4C,$1C,$2B,$2A,$04,$FE,$06,$4E,$06,$4E
        byte $1C,$2B,$4B,$2D,$2C,$4C,$1C,$4C,$4C,$3B,$1D,$7E,$4E,$FE,$4E,$FE
        byte $2C,$2B,$4B,$2D,$2C,$1C,$4C,$1C,$2C,$2A,$04,$FE,$4E,$4E,$06,$2E
        byte $1C,$4B,$3C,$1D,$4C,$1C,$4C,$1C,$4C,$2A,$5C,$0E,$EE,$0E,$4E,$DE
        byte $4C,$2B,$4B,$1D,$2B,$4C,$1C,$4C,$1C,$2A,$04,$0E,$EE,$4E,$DE,$1E
        byte $1C,$2B,$4B,$2D,$1C,$2C,$4C,$1C,$4C,$2A,$04,$1E,$1E,$DE,$1E,$05
        byte $1C,$3B,$4B,$2C,$4C,$1C,$4C,$1C,$4C,$2A,$1D,$CD,$1D,$5D,$04,$1D
        byte $2D,$4C,$04,$0D,$4C,$04,$1D,$04,$1C,$04,$4B,$4B,$FB,$04,$FB,$04
        byte $3B,$3B,$4B,$1C,$4C,$2B,$2B,$2B,$2C,$2A,$4B,$FB,$04,$4B,$4B,$FB
        byte $2B,$2A,$2A,$1D,$2B,$1C,$2B,$2C,$2B,$2A,$4B,$04,$FA,$04,$FB,$5B
        byte $2B,$2A,$4B,$4B,$2C,$1D,$4C,$04,$4C,$4B,$03,$03,$4B,$4B,$03,$5A
tile035 byte $06,$07,$06,$07,$3E,$3D,$2D,$2D,$2D,$3D,$1D,$4C,$4C,$4C,$4B,$2D
        byte $07,$06,$07,$06,$3E,$2E,$1E,$4D,$4D,$05,$4D,$1D,$1D,$4D,$1D,$5D
        byte $06,$07,$06,$06,$4D,$2D,$3D,$2D,$1D,$5C,$1D,$5C,$2D,$4C,$4C,$5C
        byte $06,$06,$06,$06,$4D,$3D,$4D,$3D,$3D,$5C,$3D,$3D,$4C,$4C,$4C,$1D
        byte $06,$06,$06,$4E,$3E,$3D,$4D,$1D,$4D,$1D,$4D,$2D,$4C,$2D,$3C,$5C
        byte $06,$06,$FE,$06,$3D,$4D,$4D,$4D,$3D,$4D,$3D,$3D,$2D,$4C,$4C,$1D
        byte $06,$4E,$06,$3E,$3E,$4D,$4D,$4D,$4D,$1D,$5D,$2D,$3D,$4C,$4C,$4D
        byte $4E,$4E,$4E,$0E,$4D,$4D,$1E,$3D,$3D,$5D,$3D,$3D,$4C,$3D,$4C,$2D
        byte $4E,$FE,$4E,$0E,$3E,$3D,$4D,$4D,$3D,$1D,$4D,$3D,$3D,$4C,$4C,$5C
        byte $EE,$0E,$EE,$4E,$4D,$4D,$4D,$3D,$4D,$5C,$3D,$4C,$2D,$4C,$2C,$3D
        byte $EE,$4E,$1E,$05,$1E,$4D,$2E,$3D,$4D,$1D,$4D,$3D,$3D,$4D,$5D,$5D
        byte $04,$1D,$04,$1D,$5D,$1D,$4D,$3D,$3D,$5C,$1D,$4C,$4C,$2D,$4C,$04
        byte $4B,$EB,$4B,$FB,$4D,$3D,$3D,$2D,$4C,$4C,$4C,$2C,$4C,$4C,$2B,$4C
        byte $04,$FB,$4B,$04,$2D,$4C,$4C,$4C,$4C,$4C,$1D,$4C,$3C,$5C,$4B,$5C
        byte $4B,$5B,$03,$04,$2D,$5C,$04,$5D,$1D,$9C,$04,$8B,$04,$03,$8B,$03
        byte $03,$04,$9B,$5B,$04,$9C,$5B,$9B,$5B,$9B,$5B,$9A,$8B,$8B,$03,$8B
tile036 byte $3D,$2C,$3D,$3D,$4C,$4E,$3E,$3E,$4E,$3D,$4E,$07,$06,$06,$5D,$5C
        byte $4D,$4D,$4D,$4D,$4D,$4E,$3D,$3E,$3E,$4D,$06,$06,$06,$3E,$5D,$5D
        byte $2D,$3D,$3D,$3D,$4C,$4D,$2D,$3D,$3D,$3C,$3E,$06,$4E,$5E,$5D,$1D
        byte $3D,$3D,$3D,$3D,$4C,$4D,$2D,$3D,$3C,$4C,$5D,$06,$4E,$3E,$5C,$CD
        byte $3D,$3D,$3D,$3D,$3C,$2E,$3D,$3D,$3C,$3C,$05,$4E,$5E,$5D,$5D,$04
        byte $3D,$3D,$3D,$3D,$4C,$4D,$3D,$3D,$3C,$4C,$5D,$2E,$05,$5C,$1D,$5C
        byte $3D,$3D,$3D,$3D,$3C,$4D,$3D,$3C,$4C,$4B,$4D,$05,$5D,$1D,$04,$04
        byte $3D,$3D,$3D,$3D,$4C,$3D,$3D,$4C,$3C,$3C,$5D,$05,$5C,$04,$04,$5B
        byte $3D,$3D,$3D,$3D,$3C,$3D,$4C,$4C,$3C,$4B,$1D,$5D,$CD,$5C,$04,$04
        byte $3D,$3D,$3D,$3C,$3D,$4D,$2D,$4C,$4C,$04,$04,$4B,$4B,$4B,$4B,$FA
        byte $1D,$3D,$3D,$3D,$5C,$04,$4C,$4B,$4B,$4B,$4B,$4B,$FA,$2A,$03,$03
        byte $3D,$4C,$4C,$3C,$4C,$4C,$4B,$2B,$4B,$3B,$4B,$FA,$4B,$03,$2A,$03
        byte $4C,$3D,$3C,$4B,$4C,$2D,$04,$3A,$5B,$5B,$03,$4B,$03,$5A,$5A,$03
        byte $4C,$5C,$03,$6A,$5B,$04,$5B,$7B,$5B,$9A,$03,$5B,$9A,$03,$7B,$8B
        byte $9B,$03,$03,$8A,$03,$8B,$5B,$CA,$03,$03,$8B,$5B,$5B,$04,$04,$04
        byte $5B,$8B,$5B,$9B,$5B,$04,$04,$5C,$CD,$5D,$05,$EE,$8E,$EE,$5E,$FE
tile037 byte $1E,$5D,$5D,$3E,$06,$06,$06,$4E,$5D,$5C,$5B,$5B,$5B,$5B,$5B,$5C
        byte $EE,$5D,$5C,$5D,$4D,$4E,$4E,$3E,$5D,$4C,$5C,$5B,$5B,$7C,$5B,$5C
        byte $8E,$5D,$04,$4C,$5D,$5D,$5D,$5C,$5C,$04,$5B,$7C,$4B,$5B,$04,$5C
        byte $4E,$5D,$4B,$5C,$4B,$5C,$5C,$04,$4C,$4B,$5D,$5D,$5C,$04,$5B,$5D
        byte $4E,$5D,$4B,$4C,$5B,$4C,$4B,$4C,$5B,$4B,$5C,$5B,$04,$6C,$04,$5C
        byte $DE,$5C,$4B,$4B,$5C,$4B,$5B,$4B,$4C,$5B,$5C,$5C,$5C,$5B,$5C,$05
        byte $4E,$5C,$4B,$5B,$4B,$4C,$5B,$4B,$5B,$3B,$6D,$6D,$6D,$5C,$5C,$05
        byte $05,$5C,$5B,$04,$5B,$04,$5B,$5C,$5B,$04,$5C,$5D,$5D,$6D,$6D,$05
        byte $05,$04,$04,$04,$5B,$04,$04,$5B,$04,$5B,$5D,$05,$5D,$5D,$5C,$05
        byte $5C,$04,$04,$04,$5B,$04,$5B,$04,$04,$04,$04,$5D,$5C,$04,$6D,$8D
        byte $1D,$04,$04,$04,$04,$5B,$04,$04,$04,$5B,$5C,$8D,$5C,$5C,$04,$04
        byte $04,$04,$9B,$5B,$04,$04,$04,$5B,$04,$04,$8D,$FE,$06,$5E,$7E,$FE
        byte $04,$5B,$04,$5B,$5B,$8B,$4B,$04,$5B,$5B,$CD,$4E,$4E,$4E,$4E,$5D
        byte $7B,$8B,$5B,$9B,$04,$04,$04,$5C,$CC,$5C,$05,$4D,$6E,$05,$05,$5D
        byte $05,$05,$1E,$4E,$5E,$5E,$FE,$5E,$4E,$4E,$2E,$6E,$05,$4D,$5D,$1D
        byte $4E,$4E,$4E,$4E,$4E,$4E,$4E,$3E,$05,$1D,$05,$04,$1D,$04,$4B,$4B
tile038 byte $5D,$5C,$3B,$4B,$3B,$4B,$3B,$4B,$5C,$5B,$3B,$5B,$3D,$4D,$4D,$5D
        byte $5C,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$5C,$5B,$5B,$3B,$5C,$4C,$04,$2D
        byte $1D,$04,$4B,$4B,$4B,$4B,$3B,$4B,$04,$5B,$6B,$3B,$5C,$2D,$4C,$4D
        byte $5C,$5B,$4B,$3B,$4B,$3B,$4B,$4B,$5B,$5B,$2A,$5B,$4C,$1D,$4B,$4D
        byte $5C,$04,$3B,$4B,$4B,$4B,$4B,$4B,$5B,$5B,$6A,$4B,$5C,$4C,$4C,$4D
        byte $5C,$4B,$4B,$4B,$4B,$4B,$2A,$4B,$5B,$5B,$3B,$5B,$4C,$1D,$4C,$5C
        byte $5D,$5B,$4B,$4B,$2A,$5B,$4B,$4B,$5B,$8B,$03,$4B,$04,$4C,$4C,$1D
        byte $04,$04,$5B,$4B,$5B,$DA,$4B,$4B,$9B,$04,$5B,$5B,$04,$5C,$4C,$5C
        byte $5B,$04,$04,$5B,$04,$4B,$04,$4B,$04,$5B,$8B,$04,$04,$4C,$4B,$4B
        byte $03,$04,$5B,$04,$DA,$5B,$DA,$04,$04,$9C,$4B,$4B,$04,$5B,$5B,$5B
        byte $5B,$04,$04,$5B,$4B,$4B,$04,$4B,$04,$8D,$4B,$04,$04,$9B,$04,$04
        byte $6E,$04,$5B,$04,$4B,$04,$4B,$04,$04,$AD,$5B,$5B,$04,$05,$05,$05
        byte $5D,$04,$5B,$04,$4B,$EB,$04,$04,$1D,$5C,$1D,$04,$1D,$5D,$5D,$5D
        byte $5D,$5C,$1D,$CD,$5C,$5D,$1D,$5C,$1D,$5C,$05,$5C,$5D,$1D,$5C,$1D
        byte $5D,$CD,$5D,$2D,$5D,$1D,$5D,$5D,$1D,$5D,$1D,$1D,$5C,$1D,$5D,$1D
        byte $4B,$4B,$5C,$04,$4C,$5C,$1D,$5C,$1D,$5D,$5C,$4D,$5D,$1D,$5D,$5C
tile039 byte $06,$06,$07,$5C,$04,$1D,$4B,$4C,$4B,$4C,$4C,$5C,$06,$3D,$4B,$4C
        byte $06,$06,$06,$04,$2A,$4B,$3B,$4B,$3B,$4B,$4B,$1D,$4E,$5D,$5C,$6B
        byte $FE,$06,$FE,$04,$2A,$4C,$2A,$4B,$2B,$2A,$3B,$4B,$1E,$5C,$5D,$5B
        byte $4E,$4E,$4E,$4C,$2A,$4B,$2A,$2B,$4B,$4B,$2B,$3B,$0D,$04,$9B,$5B
        byte $EE,$EE,$4E,$04,$3B,$4C,$3B,$4B,$2B,$3B,$2A,$4B,$0D,$5B,$4A,$4A
        byte $1E,$EE,$4E,$4B,$2A,$4B,$2B,$3B,$3B,$4B,$2B,$4B,$1D,$5B,$03,$4A
        byte $05,$1D,$CD,$4B,$4B,$4C,$4B,$4B,$4B,$4B,$3B,$4B,$03,$FA,$3A,$2A
        byte $04,$4B,$FA,$5B,$3A,$03,$2A,$3A,$3A,$3A,$03,$4A,$5A,$5A,$7B,$03
        byte $4B,$4B,$03,$7B,$03,$03,$7B,$7A,$7A,$5A,$03,$7A,$7A,$7A,$03,$8A
        byte $9B,$5B,$9A,$9B,$5B,$8B,$5B,$9B,$04,$5B,$9C,$5B,$9B,$5B,$03,$5B
        byte $04,$04,$9D,$5D,$05,$05,$EE,$3E,$05,$05,$2E,$05,$1E,$05,$1D,$04
        byte $05,$5E,$1E,$05,$2E,$05,$5D,$05,$5D,$05,$4D,$1D,$5C,$04,$5C,$04
        byte $05,$4D,$05,$5D,$4D,$5D,$1D,$5D,$1D,$5C,$1D,$5C,$1D,$5C,$1D,$5C
        byte $2D,$5C,$1D,$5C,$1D,$5C,$1D,$5C,$5C,$1D,$04,$1D,$5C,$1D,$5C,$1D
        byte $5D,$5C,$1D,$5C,$5C,$04,$4C,$04,$4C,$04,$4C,$04,$4C,$04,$4C,$04
        byte $1D,$5C,$4C,$1D,$04,$4C,$1D,$4C,$04,$4C,$4C,$04,$4C,$04,$4C,$4C
tile040 byte $4B,$4B,$4B,$4B,$3A,$6B,$2A,$3B,$6B,$6A,$6A,$6A,$3A,$3B,$3A,$3A
        byte $5A,$03,$5B,$04,$5C,$5B,$5B,$5B,$5B,$6A,$6A,$6A,$3A,$6B,$3B,$3A
        byte $8B,$8B,$9B,$5B,$9A,$8A,$5A,$5B,$5A,$02,$02,$6A,$5A,$5B,$04,$5B
        byte $5C,$04,$04,$04,$8B,$5B,$8B,$03,$7B,$4A,$7A,$4A,$8A,$9A,$7B,$8B
        byte $5C,$5C,$04,$5C,$5C,$5C,$04,$5C,$04,$04,$5B,$04,$04,$5B,$9B,$04
        byte $2E,$2E,$3E,$5D,$1E,$4D,$05,$4D,$5C,$1D,$5C,$04,$5C,$5C,$5C,$04
        byte $2E,$05,$3E,$5E,$4E,$4E,$4E,$4E,$EE,$5E,$4E,$4E,$4E,$EE,$4E,$EE
        byte $5B,$2A,$5B,$4B,$04,$5C,$04,$4D,$5D,$5D,$5C,$CD,$5D,$1E,$05,$4D
        byte $4B,$5B,$4B,$03,$4B,$4B,$4B,$5B,$DA,$03,$03,$03,$5B,$5B,$4B,$04
        byte $5B,$03,$03,$5B,$03,$03,$9A,$03,$03,$5A,$03,$5A,$8A,$03,$03,$03
        byte $4B,$04,$4B,$4B,$DA,$03,$03,$5A,$03,$03,$8A,$03,$03,$9A,$03,$03
        byte $3B,$3B,$4B,$3B,$3C,$4B,$4B,$4C,$4B,$4B,$5B,$03,$03,$03,$4A,$03
        byte $4A,$4A,$3A,$2A,$5B,$3B,$3B,$3B,$4B,$4B,$4B,$4C,$4B,$4B,$4B,$4B
        byte $3A,$3A,$3A,$5A,$3A,$3A,$3A,$4A,$3A,$2A,$3B,$03,$3B,$4B,$FA,$5B
        byte $4B,$4B,$5B,$4B,$3A,$03,$3A,$4A,$02,$4A,$02,$4A,$02,$4A,$7A,$4A
        byte $4A,$4A,$4A,$4A,$4A,$3A,$3A,$3A,$3A,$3A,$2A,$5A,$3A,$02,$4A,$03
tile041 byte $3A,$3A,$3B,$6B,$2A,$3A,$3B,$3B,$3C,$3B,$4B,$2A,$03,$4B,$03,$4B
        byte $6A,$3A,$6A,$3A,$3A,$6A,$3A,$3B,$3B,$3B,$5B,$2A,$2A,$2A,$03,$4B
        byte $5B,$5B,$5B,$5B,$7B,$5B,$5B,$6B,$6A,$7B,$5B,$2A,$03,$3B,$03,$03
        byte $8B,$5B,$9B,$5B,$03,$7B,$03,$5B,$9A,$7B,$5B,$03,$2A,$03,$2A,$03
        byte $8B,$03,$5B,$9B,$8B,$9B,$5B,$9B,$03,$8B,$5B,$9B,$5B,$9B,$5B,$9B
        byte $5C,$CC,$04,$5B,$04,$9B,$5B,$03,$8B,$03,$04,$9C,$5B,$9B,$5B,$04
        byte $3E,$6E,$6E,$05,$05,$05,$05,$5D,$CD,$04,$8D,$1D,$04,$04,$5B,$CC
        byte $1E,$05,$2E,$4D,$05,$4D,$05,$4D,$1E,$5C,$05,$04,$03,$4B,$03,$8B
        byte $04,$5C,$1D,$5C,$4C,$4B,$4B,$04,$1D,$5B,$04,$4B,$03,$03,$4A,$03
        byte $03,$03,$03,$03,$03,$03,$8A,$4A,$8A,$03,$03,$03,$03,$5A,$03,$9A
        byte $9A,$03,$03,$03,$9A,$4A,$4A,$4A,$8A,$03,$03,$03,$03,$03,$03,$9A
        byte $5A,$03,$8A,$03,$03,$03,$8A,$4A,$4A,$8A,$8A,$03,$5A,$9A,$4A,$03
        byte $03,$03,$03,$4A,$4A,$8A,$4A,$4A,$02,$4A,$02,$4A,$4A,$03,$03,$8A
        byte $4B,$4B,$2B,$4B,$4B,$FA,$03,$4A,$02,$02,$4A,$02,$5A,$8A,$EA,$5A
        byte $2A,$4B,$4B,$4B,$4B,$4B,$4B,$4A,$4A,$02,$8A,$4A,$4A,$8A,$4A,$4A
        byte $03,$4B,$4A,$03,$03,$4A,$4A,$02,$8A,$EA,$4A,$9A,$EA,$5A,$03,$CA
tile042 byte $2A,$FB,$4B,$FB,$4B,$EB,$4B,$04,$2B,$2A,$2B,$2A,$2B,$2A,$2B,$2A
        byte $2A,$DA,$4B,$FA,$4B,$FA,$4B,$FB,$3B,$2B,$2A,$2A,$2A,$2B,$2A,$2A
        byte $2A,$FA,$4B,$4B,$4B,$FB,$4B,$04,$1C,$04,$4B,$04,$04,$04,$04,$04
        byte $2A,$4B,$FB,$4B,$03,$5B,$03,$4B,$04,$8B,$03,$5B,$9B,$03,$03,$8B
        byte $5B,$DA,$5B,$8B,$03,$9B,$5B,$9B,$5B,$9B,$04,$04,$CD,$5C,$05,$05
        byte $9D,$5D,$8D,$05,$05,$BE,$EE,$EE,$EE,$4E,$FE,$8E,$06,$FE,$FE,$5E
        byte $4E,$05,$0E,$5D,$4E,$4E,$4E,$04,$5B,$04,$04,$4E,$1E,$5D,$5D,$04
        byte $04,$5C,$4B,$03,$04,$04,$5B,$5A,$7A,$4A,$03,$04,$04,$4B,$03,$03
        byte $03,$03,$03,$7A,$8A,$03,$9A,$4A,$4A,$8A,$4A,$8A,$03,$03,$4A,$02
        byte $03,$03,$03,$7A,$03,$03,$03,$03,$9A,$03,$03,$8A,$03,$5A,$8A,$4A
        byte $03,$8A,$03,$5A,$03,$03,$9A,$03,$03,$03,$03,$4A,$8A,$4A,$02,$4A
        byte $4A,$8A,$4A,$9A,$4A,$8A,$4A,$8A,$EA,$8A,$03,$8A,$EA,$7A,$4A,$02
        byte $5A,$EA,$7A,$02,$4A,$02,$02,$03,$8A,$03,$4A,$4A,$8A,$02,$8A,$02
        byte $8A,$4A,$02,$02,$02,$8A,$4A,$CA,$5A,$03,$03,$9A,$EA,$4A,$02,$EA
        byte $8A,$4A,$02,$8A,$02,$02,$4A,$5A,$03,$03,$8A,$4A,$4A,$03,$8A,$4A
        byte $4A,$EA,$8A,$EA,$03,$03,$9A,$03,$03,$4A,$EA,$03,$03,$4B,$EB,$4B
tile043 byte $2A,$FA,$3B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$04,$1C,$4B,$4C,$4B,$4B
        byte $2A,$04,$4C,$04,$1C,$5C,$04,$04,$04,$5B,$04,$5B,$9B,$4B,$03,$03
        byte $5B,$04,$5B,$DA,$8B,$03,$03,$03,$03,$9A,$03,$9A,$03,$03,$03,$5B
        byte $9A,$9A,$9B,$5B,$5B,$04,$04,$04,$04,$CD,$5C,$ED,$05,$05,$1E,$0D
        byte $4E,$4E,$0E,$0E,$EE,$4E,$EE,$FE,$4E,$4E,$2E,$4E,$2E,$1E,$05,$05
        byte $FE,$4E,$4E,$5E,$4E,$2E,$5E,$2E,$05,$1E,$5D,$1D,$5D,$1D,$1D,$5C
        byte $04,$5C,$1D,$5C,$DC,$4C,$04,$04,$04,$4B,$04,$04,$4B,$04,$4B,$4B
        byte $5A,$03,$03,$4B,$03,$03,$03,$4A,$03,$2A,$03,$2A,$03,$2A,$4B,$4B
        byte $4A,$8A,$03,$03,$4B,$03,$4A,$02,$4A,$03,$3A,$3A,$03,$03,$3A,$3A
        byte $02,$4A,$4A,$03,$03,$4A,$02,$4A,$4A,$4B,$03,$4B,$2A,$03,$2A,$03
        byte $02,$8A,$4A,$8A,$4A,$02,$02,$4A,$8A,$4A,$03,$03,$5B,$03,$4B,$4B
        byte $8A,$4A,$02,$EA,$8A,$03,$4A,$CA,$4A,$03,$03,$03,$03,$03,$03,$03
        byte $4A,$8A,$02,$9A,$03,$4A,$8A,$03,$03,$4A,$9A,$03,$8A,$03,$03,$03
        byte $02,$EA,$4A,$03,$4B,$4B,$EA,$03,$03,$03,$4B,$FA,$04,$4B,$04,$04
        byte $8A,$4A,$03,$2A,$4B,$04,$2C,$04,$1C,$04,$1D,$04,$1D,$04,$0C,$04
        byte $04,$1C,$04,$04,$0C,$04,$04,$1C,$04,$04,$04,$4B,$FB,$5B,$03,$2A
tile044 byte $1D,$04,$7B,$03,$04,$04,$5B,$03,$9B,$03,$5A,$03,$9B,$5B,$03,$9A
        byte $03,$5A,$03,$03,$8A,$03,$9A,$03,$5A,$03,$9A,$03,$5B,$04,$04,$04
        byte $9B,$4B,$5C,$04,$04,$5C,$CD,$5C,$05,$05,$1E,$4E,$EE,$FE,$8E,$06
        byte $1E,$1E,$1E,$2E,$1E,$05,$1E,$1E,$1E,$1E,$4E,$1E,$4E,$EE,$3E,$4E
        byte $2E,$05,$1E,$05,$1E,$4D,$0D,$5D,$1D,$05,$1D,$5D,$1D,$04,$1D,$04
        byte $1D,$04,$1D,$04,$1D,$04,$4B,$04,$4B,$4B,$4B,$4B,$04,$4B,$04,$4B
        byte $03,$4B,$03,$2A,$03,$2A,$03,$2A,$03,$4B,$03,$03,$2A,$5B,$4B,$4B
        byte $4B,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$03,$2A,$4B,$03,$4B,$03,$4B,$5B
        byte $03,$3A,$03,$2A,$03,$2A,$5B,$4B,$4B,$4B,$4B,$4B,$4B,$04,$4B,$4B
        byte $2A,$03,$2A,$03,$4B,$03,$3A,$03,$2A,$03,$4B,$03,$4B,$03,$4B,$4B
        byte $4B,$4B,$4B,$2A,$5B,$2A,$03,$2A,$03,$03,$2A,$03,$4B,$2A,$03,$4B
        byte $03,$03,$03,$03,$03,$4B,$4B,$4B,$4B,$4B,$4B,$03,$2A,$5B,$03,$4B
        byte $5B,$03,$04,$4B,$04,$04,$04,$1D,$04,$4C,$4B,$4B,$03,$4B,$2A,$03
        byte $1D,$04,$1D,$04,$1D,$04,$1C,$04,$4B,$FB,$03,$2A,$4B,$03,$4B,$4B
        byte $04,$04,$FB,$4B,$4B,$4B,$03,$2A,$03,$2A,$3A,$5B,$2A,$03,$3B,$03
        byte $2A,$3A,$2A,$3A,$03,$2A,$2A,$03,$3B,$03,$2A,$03,$2A,$5B,$3A,$2A
tile045 byte $04,$9B,$03,$9B,$04,$04,$9B,$04,$8C,$04,$04,$9D,$5C,$CD,$05,$05
        byte $04,$05,$05,$05,$05,$8E,$FE,$7E,$06,$FE,$06,$FE,$06,$FE,$06,$4E
        byte $FE,$06,$4E,$06,$FE,$4E,$06,$4E,$4E,$4E,$4E,$4E,$1E,$3E,$05,$1E
        byte $4E,$05,$1E,$05,$2E,$05,$1D,$5D,$1D,$CD,$04,$1D,$04,$5C,$04,$04
        byte $04,$4C,$04,$04,$4B,$4B,$04,$4B,$5B,$4B,$4B,$4B,$04,$4B,$04,$4B
        byte $04,$4B,$04,$4B,$4B,$4B,$4B,$4B,$03,$4B,$4B,$03,$4B,$2A,$4B,$2A
        byte $4B,$04,$4B,$4B,$04,$4B,$04,$4B,$4B,$4B,$4B,$4B,$4B,$03,$4B,$03
        byte $4B,$4B,$4B,$4B,$4B,$4B,$4B,$03,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$4B
        byte $4B,$4B,$5B,$03,$4B,$03,$2A,$4B,$03,$4B,$FA,$03,$2A,$03,$2A,$03
        byte $04,$4B,$04,$04,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$5B,$03,$4B,$2A,$5B
        byte $03,$03,$2A,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$3B,$4B,$03,$2A
        byte $2A,$4B,$03,$2A,$03,$03,$2A,$03,$03,$2A,$03,$2A,$03,$4B,$4B,$03
        byte $03,$2A,$03,$5B,$2A,$4B,$03,$4B,$4B,$03,$4B,$4B,$2A,$03,$2A,$4B
        byte $4B,$03,$4B,$03,$4B,$03,$4B,$2A,$4B,$2A,$03,$4B,$03,$4B,$2A,$03
        byte $4B,$2A,$5B,$2A,$4B,$2A,$4B,$03,$4B,$03,$4B,$2A,$4B,$2A,$03,$3B
        byte $03,$2A,$03,$2A,$03,$03,$2A,$03,$2A,$3A,$2A,$03,$3A,$03,$2A,$3A
tile046 byte $EE,$FE,$FE,$FE,$06,$FE,$FE,$06,$4E,$FE,$4E,$FE,$4E,$4E,$4E,$4E
        byte $06,$4E,$4E,$4E,$4E,$4E,$4E,$05,$1E,$05,$1E,$5D,$1D,$5D,$1D,$04
        byte $1D,$05,$1D,$5C,$1D,$04,$04,$04,$4B,$4B,$4B,$4B,$4B,$03,$4B,$5B
        byte $04,$4B,$04,$4B,$04,$4B,$04,$3C,$04,$4B,$04,$4B,$04,$4B,$4B,$4B
        byte $4B,$4B,$4B,$4B,$4B,$4B,$4B,$5B,$03,$4B,$4B,$2A,$5B,$4B,$03,$4B
        byte $4B,$5B,$4B,$4B,$03,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$2A
        byte $03,$2A,$03,$4B,$03,$4B,$03,$2A,$4B,$03,$4B,$4B,$03,$2A,$5B,$4B
        byte $4B,$4B,$4B,$4B,$4B,$2A,$4B,$03,$4B,$2A,$03,$4B,$2A,$03,$4B,$03
        byte $2A,$03,$2A,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$2A,$5B,$4B,$2A,$5B
        byte $03,$3B,$03,$4B,$03,$2A,$03,$2A,$03,$2A,$03,$4B,$03,$4B,$03,$2A
        byte $4B,$03,$3B,$03,$2A,$5B,$2A,$5B,$03,$4B,$4B,$2A,$5B,$2A,$4B,$2A
        byte $4B,$2A,$5B,$2A,$5B,$03,$2A,$5B,$2A,$03,$3B,$03,$2A,$5B,$3A,$4B
        byte $2A,$03,$4B,$03,$2A,$2A,$03,$2A,$5B,$2A,$03,$2A,$03,$2A,$5B,$3A
        byte $4B,$2A,$03,$3B,$03,$2A,$5B,$3A,$3A,$3B,$3A,$5B,$3A,$3B,$3A,$2A
        byte $03,$2A,$03,$2A,$3A,$5B,$3A,$3B,$03,$2A,$03,$2A,$3A,$3A,$3B,$5A
        byte $2A,$5A,$2A,$6A,$2A,$3A,$2A,$3A,$2A,$3A,$3B,$6A,$3B,$3A,$5B,$3A
tile047 byte $2E,$05,$4D,$CD,$1D,$04,$04,$04,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$5C
        byte $1D,$04,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$4B
        byte $5B,$4B,$4B,$4B,$4B,$04,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$03,$4B,$2A
        byte $4B,$4B,$4B,$4B,$4B,$4B,$4B,$2A,$5B,$03,$4B,$03,$2A,$03,$3B,$03
        byte $03,$4B,$4B,$4B,$4B,$4B,$5B,$4B,$4B,$4B,$4B,$4B,$03,$3B,$03,$2A
        byte $4B,$03,$4B,$03,$2A,$03,$4B,$03,$2A,$03,$3A,$2A,$03,$2A,$5B,$3A
        byte $4B,$4B,$4B,$4B,$4B,$4B,$4B,$2A,$5B,$2A,$03,$3B,$5A,$3A,$2A,$03
        byte $2A,$03,$3B,$03,$4B,$2A,$5B,$03,$4B,$2A,$5B,$03,$3B,$5B,$3A,$3B
        byte $4B,$2A,$5B,$2A,$5B,$03,$3B,$2A,$03,$4B,$2A,$5B,$2A,$2A,$5B,$2A
        byte $03,$4B,$03,$3B,$03,$3B,$03,$3B,$5B,$3A,$3B,$3A,$5B,$3A,$3B,$7B
        byte $5B,$2A,$5B,$2A,$3B,$03,$3B,$3A,$3B,$3B,$03,$3B,$3B,$03,$3B,$2A
        byte $3A,$3B,$03,$3B,$03,$3B,$6B,$2A,$03,$3B,$03,$3B,$3A,$3B,$6B,$2A
        byte $3B,$03,$3B,$3A,$3B,$3A,$3B,$03,$3B,$03,$3B,$3A,$5B,$3A,$2A,$03
        byte $03,$2A,$6B,$2A,$03,$3B,$03,$3B,$3A,$2A,$6B,$2A,$3A,$2A,$3A,$2A
        byte $3B,$3A,$2A,$03,$3B,$3A,$3B,$5A,$3B,$3A,$3A,$2A,$03,$3B,$3A,$3B
        byte $3B,$3A,$3B,$3A,$3A,$03,$3A,$2A,$6A,$2A,$03,$2A,$3A,$3A,$3B,$5A
tile048 byte $4B,$4B,$3B,$4B,$04,$4C,$04,$4B,$4B,$4C,$04,$1D,$04,$4C,$4B,$04
        byte $4B,$03,$4B,$4B,$4B,$4B,$4B,$1D,$4B,$4B,$4B,$4B,$4C,$04,$4C,$4B
        byte $4B,$4B,$2A,$03,$4B,$2A,$4B,$03,$3B,$4B,$4B,$2A,$4B,$2A,$4B,$04
        byte $2A,$03,$4B,$4B,$2A,$5B,$4B,$2A,$03,$4B,$03,$4B,$03,$4B,$4B,$4C
        byte $03,$2A,$03,$3A,$03,$3A,$3A,$03,$2A,$3A,$2A,$03,$3B,$4B,$4B,$4B
        byte $5B,$3A,$4B,$2A,$4B,$2A,$03,$2A,$03,$3A,$5B,$3A,$2A,$03,$2A,$4B
        byte $2A,$3A,$5B,$3A,$2A,$5B,$2A,$03,$3B,$3B,$3A,$4B,$3A,$4B,$03,$3B
        byte $7B,$2A,$2A,$03,$3B,$3A,$5B,$3A,$3B,$03,$3B,$03,$3B,$3B,$2A,$5B
        byte $2A,$5B,$3A,$3B,$7B,$2A,$3B,$6B,$2A,$3B,$6B,$2A,$3B,$6B,$2A,$3A
        byte $2A,$3B,$6B,$2A,$3B,$3B,$3A,$3B,$3B,$03,$3B,$3B,$2A,$3B,$3B,$5B
        byte $6B,$2A,$3B,$2A,$5B,$2A,$5B,$3B,$3B,$3B,$2A,$6B,$3B,$03,$3B,$2A
        byte $2A,$5B,$2A,$5B,$3A,$3B,$3A,$3B,$6B,$2A,$5B,$2A,$3B,$3B,$6B,$3B
        byte $2A,$3A,$3A,$2A,$3A,$3B,$3A,$2A,$03,$2A,$3A,$3B,$3A,$3B,$2A,$3B
        byte $6A,$2A,$3A,$6B,$3A,$3A,$3B,$6A,$2A,$3A,$6B,$2A,$6B,$3A,$3A,$3B
        byte $3A,$3B,$3A,$2A,$2A,$3A,$3B,$3A,$3B,$3A,$2A,$3A,$2A,$2A,$03,$2A
        byte $2A,$5A,$2A,$3A,$6B,$2A,$3A,$5B,$3A,$2A,$3A,$3B,$3A,$03,$3B,$3A
tile049 byte $4C,$4B,$04,$4B,$4C,$4B,$4B,$04,$4C,$04,$4C,$4B,$4C,$4C,$04,$4C
        byte $2A,$4B,$4B,$4C,$4B,$4B,$3B,$3B,$4B,$4B,$4B,$4C,$4B,$4B,$4B,$2A
        byte $4C,$4B,$4B,$4B,$4B,$4B,$4B,$4B,$2A,$4B,$4B,$4B,$2A,$4B,$3A,$4B
        byte $4C,$4C,$1D,$2C,$5C,$4B,$4B,$4B,$03,$3B,$03,$2A,$03,$2A,$03,$2A
        byte $04,$4B,$4B,$4B,$4B,$2A,$03,$2A,$03,$2A,$03,$3B,$03,$3B,$3A,$5B
        byte $2A,$4B,$4B,$4B,$03,$3B,$03,$3B,$5B,$2A,$6B,$2A,$5B,$3A,$3B,$3A
        byte $03,$3B,$03,$2A,$4B,$2A,$5B,$3A,$3B,$3A,$3B,$03,$3B,$3B,$6B,$3B
        byte $2A,$3B,$3B,$2A,$03,$3B,$2A,$6B,$3B,$3B,$3B,$3B,$6B,$2A,$3B,$2A
        byte $3B,$6B,$2A,$5B,$3B,$6B,$2A,$3B,$3B,$3A,$6B,$2A,$3B,$3B,$3B,$6B
        byte $3B,$3B,$3B,$3B,$3B,$3B,$3B,$3B,$3B,$3B,$3B,$3B,$3B,$6B,$3B,$3B
        byte $6B,$2A,$3B,$6B,$2A,$3B,$3B,$6B,$3B,$3B,$3B,$3B,$3B,$3B,$3B,$3B
        byte $3B,$3B,$3B,$3B,$3B,$6B,$3B,$3B,$3B,$5B,$3B,$6B,$3B,$3B,$3B,$3B
        byte $6B,$2A,$5B,$2A,$3B,$3B,$2A,$5B,$3B,$3B,$3B,$3B,$3B,$6B,$3B,$3B
        byte $3A,$3B,$3A,$5B,$3A,$5B,$3A,$3B,$6B,$2A,$6B,$2A,$3B,$3B,$6B,$3B
        byte $6B,$2A,$03,$3B,$3A,$3B,$3B,$3A,$3B,$2A,$2A,$6B,$3A,$3B,$2A,$3B
        byte $2A,$03,$3B,$3A,$3B,$6A,$3B,$3A,$3B,$6B,$2A,$2A,$5A,$5A,$2A,$6A
tile050 byte $3A,$4A,$4A,$4A,$03,$2A,$5B,$2A,$4B,$4B,$03,$4A,$02,$4A,$02,$4A
        byte $4B,$4A,$02,$4A,$03,$03,$5A,$03,$8A,$4A,$4A,$8A,$02,$4A,$8A,$4A
        byte $4A,$4A,$02,$02,$7A,$4A,$8A,$4A,$4A,$8A,$4A,$EA,$8A,$4A,$EA,$02
        byte $02,$4A,$02,$4A,$4A,$8A,$03,$4A,$8A,$EA,$02,$5A,$4A,$03,$4A,$03
        byte $4A,$4A,$8A,$4A,$EA,$4A,$4A,$EA,$5A,$03,$03,$4B,$EB,$4B,$04,$4B
        byte $03,$2A,$03,$4B,$4B,$FA,$4B,$04,$FB,$4B,$04,$FB,$4B,$4B,$FB,$4B
        byte $4B,$4B,$FB,$4B,$FB,$4B,$4B,$4B,$4B,$FB,$2A,$5B,$FA,$3A,$3A,$3A
        byte $4B,$FA,$03,$2A,$03,$3A,$FA,$3A,$3A,$3A,$4A,$3A,$3A,$3A,$3A,$3A
        byte $3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
        byte $3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$2A
        byte $3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$4A,$3A,$3A,$3A
        byte $3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
        byte $3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$4A,$3A,$4A,$3A,$3A
        byte $3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
        byte $3A,$2A,$3A,$2A,$3A,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$2A
        byte $3A,$3A,$03,$3A,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$2A,$3A,$3A
tile051 byte $03,$03,$4A,$4A,$EA,$8A,$4A,$CA,$4A,$4A,$8A,$4A,$8A,$4A,$8A,$4A
        byte $4A,$8A,$EA,$9A,$4A,$4A,$8A,$4A,$4A,$9A,$4A,$EA,$4A,$EA,$03,$4B
        byte $8A,$EA,$7A,$4A,$03,$4A,$EA,$4A,$FA,$4B,$4B,$4B,$04,$04,$1C,$04
        byte $EA,$03,$2A,$4B,$EB,$4B,$04,$4B,$04,$FB,$4B,$FB,$4B,$FB,$4B,$4B
        byte $04,$2B,$EB,$4B,$4B,$1C,$04,$FB,$4B,$4B,$FB,$5B,$03,$2A,$03,$3A
        byte $FB,$4B,$4B,$FA,$2A,$EA,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$2A,$03
        byte $3A,$4A,$3A,$3A,$4A,$3A,$2A,$3A,$2A,$3A,$2A,$3A,$2A,$3A,$3A,$2A
        byte $3A,$3A,$3A,$3A,$2A,$3A,$3A,$03,$3A,$2A,$03,$3A,$3A,$03,$2A,$5A
        byte $3A,$3A,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$3A
        byte $3A,$3A,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$2A,$5A,$3A,$3A,$3A,$03,$2A
        byte $3A,$3A,$3A,$3A,$3A,$2A,$5A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
        byte $3A,$3A,$3A,$3A,$3A,$3A,$3A,$2A,$3A,$03,$3A,$2A,$5A,$3B,$3A,$6B
        byte $3A,$3A,$3A,$3A,$3A,$03,$3A,$3A,$3A,$3B,$3A,$03,$3A,$3A,$2A,$3A
        byte $3A,$3A,$2A,$3A,$2A,$3A,$3A,$2A,$3A,$3A,$3A,$2A,$3A,$3A,$6B,$3A
        byte $3A,$3A,$3A,$03,$3A,$3A,$3A,$3A,$3A,$3A,$6B,$3A,$3A,$2A,$3A,$3A
        byte $3A,$3A,$2A,$3A,$3A,$2A,$3A,$3A,$3B,$3A,$3A,$2A,$3A,$3A,$3A,$2A
tile052 byte $03,$8A,$4A,$03,$03,$EA,$4B,$FA,$4B,$04,$04,$1C,$04,$04,$1D,$04
        byte $EA,$4B,$04,$FB,$04,$4C,$04,$04,$1C,$04,$04,$04,$1C,$4B,$4B,$FA
        byte $04,$1C,$4B,$04,$2B,$04,$FB,$4B,$FA,$4B,$FA,$2A,$03,$FA,$3A,$3A
        byte $FA,$4B,$FA,$2A,$03,$3A,$3A,$2A,$3A,$2A,$3A,$03,$2A,$03,$3B,$2A
        byte $3A,$2A,$03,$3A,$2A,$03,$2A,$03,$2A,$03,$3B,$4B,$3A,$3B,$03,$3B
        byte $2A,$03,$2A,$4B,$03,$2A,$4B,$03,$3B,$5B,$3A,$2A,$03,$2A,$03,$2A
        byte $03,$2A,$03,$2A,$03,$2A,$3A,$2A,$03,$3A,$2A,$03,$3A,$3A,$3A,$3A
        byte $3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$03,$3A,$2A,$3A,$3B,$5A
        byte $3A,$3A,$2A,$3A,$6B,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$5A,$3A,$3A
        byte $3A,$3A,$3A,$3A,$2A,$5A,$3A,$03,$2A,$3A,$3B,$6A,$3A,$3A,$3A,$3A
        byte $3A,$3A,$6B,$2A,$5A,$3A,$3B,$3A,$6B,$3A,$3A,$2A,$3A,$2A,$3A,$3B
        byte $2A,$3A,$2A,$5A,$2A,$03,$3A,$2A,$3A,$3A,$2A,$5A,$03,$3A,$3A,$3A
        byte $3A,$3A,$3A,$2A,$5A,$2A,$3A,$03,$2A,$03,$3A,$2A,$3A,$3B,$3A,$3A
        byte $2A,$3A,$03,$3A,$2A,$6A,$2A,$3A,$6B,$3A,$2A,$6A,$2A,$6A,$2A,$3A
        byte $3A,$3A,$2A,$3A,$6B,$2A,$3A,$3A,$2A,$3A,$2A,$3A,$3A,$2A,$6A,$2A
        byte $3A,$2A,$5A,$2A,$3A,$3A,$2A,$03,$3A,$2A,$5A,$3B,$5A,$2A,$5A,$2A
tile053 byte $1C,$04,$04,$FB,$4B,$4B,$4B,$03,$2A,$3A,$2A,$3A,$3A,$2A,$03,$2A
        byte $4B,$03,$3A,$2A,$3A,$3A,$FA,$3A,$03,$2A,$03,$2A,$03,$3B,$3A,$4B
        byte $3A,$2A,$3A,$3A,$3A,$2A,$3A,$2A,$03,$2A,$3A,$03,$2A,$3A,$3A,$2A
        byte $03,$2A,$03,$2A,$03,$2A,$03,$3B,$3A,$2A,$03,$2A,$3A,$5B,$3A,$2A
        byte $03,$3B,$3A,$4B,$3A,$3B,$3A,$03,$2A,$03,$3A,$3A,$2A,$3A,$3A,$03
        byte $03,$2A,$3A,$2A,$3A,$03,$2A,$3A,$3A,$3A,$3B,$3A,$3A,$3A,$2A,$3A
        byte $2A,$6A,$2A,$03,$3A,$2A,$6A,$3B,$3A,$5B,$3A,$3A,$3B,$5A,$3A,$2A
        byte $3A,$2A,$5A,$2A,$6A,$2A,$3A,$03,$3A,$3A,$2A,$3A,$3A,$3B,$3A,$03
        byte $3A,$3A,$3A,$3A,$2A,$5A,$2A,$3A,$2A,$3A,$3A,$2A,$5A,$3A,$2A,$3A
        byte $3A,$03,$3B,$6A,$3A,$3A,$3A,$3A,$3A,$3A,$6B,$3A,$2A,$3A,$3A,$3A
        byte $6A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
        byte $2A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
        byte $3A,$2A,$3A,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
        byte $03,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$2A,$3A,$3A,$2A,$3A,$3A,$2A,$3A
        byte $3A,$2A,$6B,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$2A,$3A,$3A
        byte $6A,$2A,$3A,$3A,$2A,$3A,$2A,$3A,$2A,$3A,$3A,$3A,$2A,$3A,$3A,$3A
tile054 byte $03,$3B,$03,$2A,$3A,$2A,$03,$2A,$3A,$2A,$3A,$3B,$3A,$3A,$2A,$03
        byte $3A,$2A,$03,$3A,$2A,$5A,$3A,$03,$2A,$5A,$5A,$3A,$3A,$03,$3A,$3B
        byte $03,$3A,$2A,$03,$2A,$03,$2A,$3A,$3A,$3B,$3A,$03,$3B,$3A,$3A,$3A
        byte $3A,$5B,$3A,$2A,$3A,$6B,$2A,$3A,$5B,$3A,$2A,$3A,$3A,$3B,$03,$3B
        byte $3A,$2A,$3A,$3A,$3B,$3A,$3A,$2A,$3A,$3A,$5B,$3A,$3B,$3A,$3A,$3A
        byte $3A,$3A,$2A,$6A,$3A,$3A,$2A,$5A,$2A,$3A,$3A,$3A,$3A,$2A,$03,$2A
        byte $3A,$03,$2A,$3A,$2A,$03,$3A,$2A,$6A,$2A,$3A,$2A,$5A,$3A,$3A,$3A
        byte $3B,$3A,$3A,$3B,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$2A,$3A,$3B,$3A
        byte $3A,$2A,$3A,$3A,$3A,$3B,$3A,$3A,$03,$2A,$03,$2A,$6B,$3A,$3A,$3A
        byte $3B,$6A,$2A,$03,$3A,$3A,$2A,$3A,$3B,$3A,$3A,$3A,$2A,$3A,$2A,$3A
        byte $3A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$3A,$3B,$3A,$3A,$2A,$5A,$3A
        byte $3A,$3A,$3A,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$2A,$5A,$2A,$3A
        byte $3A,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
        byte $3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
        byte $2A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$2A,$3A,$3A,$3A,$3A
        byte $3A,$2A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$2A,$3A,$3A
tile055 byte $3A,$5B,$3A,$03,$2A,$3A,$5B,$3A,$2A,$03,$2A,$3A,$2A,$3A,$3A,$03
        byte $3A,$3A,$2A,$3A,$2A,$3A,$3A,$2A,$3A,$3A,$3A,$2A,$7B,$2A,$3A,$3B
        byte $3A,$2A,$5A,$2A,$6A,$2A,$3A,$3A,$03,$2A,$3A,$3A,$3A,$3A,$2A,$3A
        byte $3A,$5B,$3A,$3B,$3A,$03,$2A,$3A,$3A,$3A,$6B,$2A,$3A,$3A,$3A,$3A
        byte $2A,$3A,$3A,$2A,$3A,$3B,$6A,$2A,$6B,$2A,$3A,$2A,$3A,$2A,$3A,$6B
        byte $6B,$2A,$3A,$03,$2A,$3A,$2A,$3A,$2A,$3A,$2A,$3A,$3A,$03,$2A,$3A
        byte $3A,$3A,$2A,$3A,$3A,$6B,$2A,$3A,$2A,$3A,$3A,$2A,$3A,$2A,$3A,$3A
        byte $2A,$3A,$03,$2A,$3A,$2A,$3A,$3A,$03,$2A,$3A,$03,$3A,$3A,$3A,$3B
        byte $3A,$2A,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$2A,$3A,$2A,$6B,$3A,$3A
        byte $2A,$5A,$2A,$3A,$2A,$5A,$3A,$3A,$2A,$6A,$3A,$3A,$3A,$3A,$2A,$3A
        byte $03,$2A,$6A,$2A,$6A,$2A,$3A,$3B,$3A,$2A,$3A,$3A,$2A,$3A,$3A,$3A
        byte $2A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$2A,$6A,$3A,$3A,$3A,$2A
        byte $3A,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$3A
        byte $3A,$3A,$3A,$3A,$3A,$6A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$2A,$3A
        byte $3A,$3A,$2A,$6A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
        byte $2A,$3A,$3A,$2A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
tile056 byte $3A,$2A,$6A,$2A,$3A,$3A,$3A,$03,$3A,$6B,$3A,$2A,$3A,$2A,$3A,$2A
        byte $3A,$3B,$3A,$3A,$2A,$3A,$3B,$3A,$2A,$3A,$2A,$3A,$2A,$6B,$3A,$2A
        byte $3A,$3A,$3A,$2A,$6B,$3A,$3A,$2A,$3A,$3A,$3A,$2A,$3A,$3A,$2A,$3A
        byte $2A,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$3B,$3A,$2A,$6A,$2A,$3A,$3A,$3A
        byte $3A,$2A,$3A,$2A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$3B,$3A
        byte $2A,$3A,$3A,$3A,$3B,$3A,$3A,$3B,$3A,$3B,$3A,$3A,$3A,$2A,$6A,$2A
        byte $3A,$2A,$3A,$3A,$3A,$2A,$6A,$3A,$3A,$3A,$2A,$6B,$2A,$3A,$2A,$3A
        byte $3A,$3A,$3B,$3A,$2A,$3A,$2A,$3A,$3B,$3A,$3A,$2A,$3A,$3A,$3A,$2A
        byte $3A,$3A,$3A,$3A,$6B,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$2A,$3A,$3A
        byte $2A,$3A,$2A,$3A,$2A,$3A,$2A,$3A,$3A,$3A,$3B,$3A,$3A,$3A,$3B,$3A
        byte $3A,$3A,$3A,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$3B,$3A,$3A,$3A
        byte $3A,$3A,$2A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
        byte $3A,$3A,$3A,$2A,$6A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
        byte $3A,$2A,$6A,$3A,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$2A,$6A,$2A,$3A
        byte $3A,$3A,$2A,$3A,$3A,$3A,$3A,$2A,$6A,$2A,$3A,$3A,$3A,$3A,$3A,$3A
        byte $2A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$2A
tile057 byte $6A,$2A,$5A,$3B,$3A,$3B,$3A,$3B,$3A,$3B,$3A,$6B,$2A,$3A,$3A,$2A
        byte $3A,$3A,$2A,$5A,$2A,$6A,$2A,$3A,$3A,$3A,$2A,$3A,$2A,$3A,$3B,$6A
        byte $3B,$5A,$3A,$2A,$6A,$2A,$3A,$6B,$3A,$2A,$3A,$3A,$3A,$3B,$5A,$3A
        byte $3A,$2A,$3A,$3A,$2A,$6A,$3A,$3A,$3A,$3A,$3A,$3B,$3A,$3A,$2A,$3A
        byte $3A,$3A,$2A,$6A,$2A,$3A,$2A,$3A,$3A,$2A,$3A,$3A,$3A,$3B,$3A,$2A
        byte $3A,$3A,$3A,$2A,$6A,$3A,$3A,$3A,$2A,$3A,$3A,$2A,$6A,$2A,$3A,$3A
        byte $2A,$3A,$3B,$3A,$3A,$2A,$3A,$2A,$6A,$2A,$3A,$3A,$2A,$3A,$3B,$6A
        byte $6A,$2A,$6A,$2A,$3A,$2A,$3A,$2A,$3A,$3A,$2A,$6B,$2A,$3A,$2A,$3A
        byte $3B,$3A,$3A,$3A,$2A,$6A,$2A,$3A,$3A,$2A,$3A,$3A,$3A,$2A,$6A,$2A
        byte $3A,$3A,$2A,$3A,$3A,$3A,$3A,$2A,$6A,$3A,$2A,$3A,$3A,$3A,$3A,$2A
        byte $2A,$6B,$3A,$2A,$3A,$3B,$3A,$3A,$3B,$3A,$3A,$3B,$3A,$3B,$6A,$3A
        byte $3A,$3A,$2A,$3A,$3A,$3A,$6B,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$2A
        byte $2A,$3A,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$2A,$3A,$6B,$3A,$3A,$2A,$6A
        byte $3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
        byte $3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
        byte $3A,$3A,$2A,$3A,$2A,$3A,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
tile058 byte $6A,$2A,$6A,$2A,$3A,$3A,$3A,$3A,$2A,$6A,$2A,$6A,$2A,$3A,$3B,$6B
        byte $2A,$3A,$3B,$3A,$2A,$2A,$6B,$2A,$3A,$3B,$3A,$3B,$3A,$5B,$3A,$3A
        byte $2A,$3A,$3A,$3A,$6B,$3A,$2A,$3A,$3B,$5A,$3B,$03,$3B,$3A,$3B,$2A
        byte $3B,$3A,$3B,$2A,$2A,$3A,$3B,$3A,$3B,$3A,$3B,$3A,$3B,$3A,$5B,$2A
        byte $6A,$2A,$3A,$6B,$2A,$3B,$03,$3B,$3B,$5B,$3B,$3B,$5B,$3B,$3B,$4B
        byte $2A,$3A,$2A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$2A,$3A,$3B,$3B,$5B,$3B
        byte $2A,$6A,$3A,$2A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$6B,$3A,$3A,$3A,$3A
        byte $2A,$3A,$3A,$3A,$3B,$3A,$3A,$6B,$3A,$3A,$3A,$3A,$3A,$02,$7A,$02
        byte $6A,$3B,$3A,$2A,$6A,$2A,$3A,$2A,$3A,$2A,$3A,$3A,$3A,$3A,$3A,$02
        byte $3A,$3A,$3A,$3A,$3B,$3A,$3A,$2A,$3A,$2A,$3A,$2A,$3A,$3A,$3A,$3A
        byte $3A,$3B,$3A,$6B,$3A,$2A,$6A,$3A,$3A,$6B,$3A,$3A,$2A,$3A,$3A,$3A
        byte $3A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$2A
        byte $3A,$2A,$6A,$3A,$3A,$3A,$2A,$3A,$2A,$3A,$2A,$3A,$3A,$3B,$3A,$3A
        byte $3A,$3A,$3A,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
        byte $3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$2A
        byte $3A,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$6A
tile059 byte $2A,$3B,$3A,$3B,$6B,$2A,$5B,$3A,$3A,$5A,$03,$5A,$4A,$02,$3A,$3A
        byte $3A,$03,$3B,$3A,$3B,$2A,$3B,$4B,$03,$3A,$3A,$3A,$6A,$02,$6A,$4A
        byte $3B,$2A,$5B,$4B,$4B,$4C,$4B,$5B,$4A,$02,$6A,$02,$4A,$02,$02,$4A
        byte $5C,$4C,$4C,$5B,$03,$03,$5A,$4A,$7A,$02,$4A,$02,$4A,$02,$4A,$4A
        byte $2D,$4C,$03,$03,$4A,$02,$4A,$4A,$02,$4A,$4A,$02,$4A,$4A,$02,$4A
        byte $3A,$4B,$3B,$4B,$3B,$4B,$2A,$03,$2A,$03,$3A,$4A,$4A,$02,$02,$02
        byte $3B,$3A,$3A,$2A,$3A,$2A,$2A,$3B,$2A,$2A,$2A,$2A,$2A,$4B,$3B,$4B
        byte $3A,$2A,$3A,$3B,$3A,$2A,$3A,$2A,$3A,$3A,$2A,$3A,$3A,$2A,$3A,$2A
        byte $4A,$7A,$3A,$3A,$3A,$3A,$3B,$3A,$3A,$2A,$3A,$3B,$3A,$2A,$2A,$2A
        byte $3A,$3A,$02,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$2A,$3A,$3A
        byte $3A,$3A,$3A,$3A,$3A,$4A,$4A,$3A,$4A,$4A,$4A,$4A,$02,$4A,$02,$4A
        byte $3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
        byte $3A,$2A,$3A,$2A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A
        byte $3A,$3A,$3A,$3A,$2A,$3A,$2A,$3A,$2A,$3A,$3A,$2A,$3A,$3A,$3A,$3A
        byte $3A,$3A,$2A,$6A,$3A,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$2A,$3A,$3A
        byte $3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$2A,$3A,$3A,$3A,$3A