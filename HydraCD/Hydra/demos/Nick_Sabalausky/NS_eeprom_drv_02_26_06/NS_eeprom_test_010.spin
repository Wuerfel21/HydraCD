{///////////////////////////////////////////////////////////////////////

EEPROM Driver Test
AUTHOR: Nick Sabalausky
LAST MODIFIED: 2.26.06
VERSION 1.0

Detailed Change Log
--------------------
v1.0 (2.26.06)
- Initial release

///////////////////////////////////////////////////////////////////////}

'///////////////////////////////////////////////////////////////////////
' CONSTANTS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
CON
  ' graphics driver and screen constants
  PARAMCOUNT            = 14        

  SCREEN_WIDTH          = 608  'Must be multiple of 16
  SCREEN_HEIGHT         = 384  'Must be multiple of 16

  X_TILES               = SCREEN_WIDTH/16  '38
  Y_TILES               = SCREEN_HEIGHT/16 '24
  
  TILE_SIZE               = 16  'in longs
  TILE_BITMAP_MEMORY_SIZE = TILE_SIZE*2
  TILE_BITMAP_MEMORY      = $8000-TILE_BITMAP_MEMORY_SIZE

  SCREEN_LEFT   = 0
  SCREEN_RIGHT  = SCREEN_WIDTH-1
  SCREEN_BOTTOM = 0
  SCREEN_TOP    = SCREEN_HEIGHT-1

  _clkmode = xtal2 + pll8x            ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000        ' set frequency to 10 MHZ plus some error for xtals that are not exact add 1000-5000 usually works
  _stack = (TILE_BITMAP_MEMORY_SIZE + 64) >> 2  ' accomodate display memory and stack

  CHAR_ROM_UPPER_IMAGE = $8000
  CHAR_ROM_LOWER_IMAGE = $8040
  CHAR_INDEX_01        = 24

  BUFFER_SIZE = 32

'///////////////////////////////////////////////////////////////////////
' VARIABLES ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
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

  word  screen[X_TILES * Y_TILES] ' storage for screen tile map
  long  colors[64]                ' color look up table

  byte write_buffer[BUFFER_SIZE]
  byte read_buffer[BUFFER_SIZE]

  long byte_count

'///////////////////////////////////////////////////////////////////////
' OBJECTS //////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

  tv     : "tv_drv_010.spin"           'TV Driver
  eeprom : "NS_eeprom_drv_010.spin"    'EEPROM Driver

'///////////////////////////////////////////////////////////////////////
' FUNCTIONS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////

PUB testDriver | i, dx, dy

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)
  
  'setup colors
  colors[0] := $07020702
  colors[1] := $3C3C0202
  colors[2] := $02020202

  'init tile screen
  repeat dx from 0 to tv_hc - 1
    repeat dy from 0 to tv_vc - 1
      screen[dy * tv_hc + dx] := CONSTANT(2<<10) + CONSTANT((CHAR_ROM_UPPER_IMAGE>>6)+CHAR_INDEX_01*2)

  'populate write buffer
  repeat i from 0 to CONSTANT(BUFFER_SIZE-1)
    write_buffer[i] := i

  'start eeprom driver
  eeprom.start(28, 29, 0)

  repeat i from 11 to 0
    drawLong(0, i<<1, 0)

  'write to end of eeprom
  eeprom.Write(@write_buffer, CONSTANT(eeprom#LAST_ADDRESS + 1 - BUFFER_SIZE), BUFFER_SIZE)
  repeat until eeprom.IsDone
    byte_count := eeprom.GetBytesRemaining

    'draw progess
    drawLong(0, 11<<1, byte_count)

    repeat while tv_status == 1
    repeat while tv_status == 2

  'read back what was written
  eeprom.Read(@read_buffer, CONSTANT(eeprom#LAST_ADDRESS + 1 - BUFFER_SIZE), BUFFER_SIZE)
  repeat until eeprom.IsDone
    byte_count := eeprom.GetBytesRemaining

    'draw progess
    repeat i from 0 to 7
      drawLong(0, i<<1, LONG[@read_buffer][i])
    drawLong(0, 11<<1, byte_count)

    repeat while tv_status == 1
    repeat while tv_status == 2

  'draw final results
  byte_count := eeprom.GetBytesRemaining
  repeat i from 0 to 7
    drawLong(0, i<<1, LONG[@read_buffer][i])
  drawLong(0, 11<<1, byte_count)

  eraseNibble(0,CONSTANT((10<<1)-1))

  'infinite loop
  repeat

'///////////////////////////////////////////////////////////////////////

PUB drawBit(x, y, bit)

'' To erase a bit, call drawBit with the "bit" parameter set to 2

  screen[( y   *X_TILES) + x] := bit<<10 + CONSTANT((CHAR_ROM_UPPER_IMAGE>>6)+CHAR_INDEX_01*2)
  screen[((y+1)*X_TILES) + x] := bit<<10 + CONSTANT((CHAR_ROM_LOWER_IMAGE>>6)+CHAR_INDEX_01*2)
    
'///////////////////////////////////////////////////////////////////////

PUB drawNibble(x, y, nibble) | i
  repeat i from 0 to 3
    drawBit(x+4-i, y, (nibble>>i) & 1)

'///////////////////////////////////////////////////////////////////////

PUB eraseNibble(x, y) | i
  repeat i from 0 to 3
    drawBit(x+i, y, 2)

'///////////////////////////////////////////////////////////////////////

PUB drawByte(x, y, arg_byte) | i
  repeat i from 0 to 7
    drawBit(x+7-i, y, (arg_byte>>i) & 1)

'///////////////////////////////////////////////////////////////////////

PUB eraseByte(x, y) | i
  repeat i from 0 to 7
    drawBit(x+7-i, y, 2)

'///////////////////////////////////////////////////////////////////////

PUB drawLong(x, y, arg_long) | i
  drawByte(x,    y, arg_long >> 24)
  drawByte(x+9,  y, arg_long >> 16)
  drawByte(x+18, y, arg_long >> 8)
  drawByte(x+27, y, arg_long)

'///////////////////////////////////////////////////////////////////////
' DATA /////////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

DAT

tvparams                long    0               'status
                        long    1               'enable
                        long    %011_0000       'pins
                        long    %0010           'mode
                        long    0               'screen
                        long    0               'colors
                        long    X_TILES         'hc
                        long    Y_TILES         'vc
                        long    4               'hx timing stretch
                        long    1               'vx
                        long    0               'ho
                        long    0               'vo
                        long    55_250_000      'broadcast
                        long    0               'auralcog