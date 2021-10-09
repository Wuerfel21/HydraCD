'' Text demo 08-xx-06 
'' JT Cook - www.avalondreams.com

CON

  _clkmode = xtal1 + pll8x  ' ?
  _xinfreq = 10_000_000 + 0000 ' Set to 10Mhz and add 5000 to fix crystal imperfection of hydra prototype
  _stack = (106) 'the game will break if there is less than 106 longs free
  _memstart = $10                   ' memory starts $10 in!!! (this took 2 headaches to figure out)

  paramcount = 14
  SCANLINE_BUFFER = $7F00
' constants            
request_scanline       = SCANLINE_BUFFER-4
tile_adr               = SCANLINE_BUFFER-8  'address of tiles
tile_color_adr         = SCANLINE_BUFFER-12 'address for color of tile
char_data_adr          = SCANLINE_BUFFER-16 'address where characters are at 
xxx2                   = SCANLINE_BUFFER-20 
xxx3                   = SCANLINE_BUFFER-24 
xxx4                   = SCANLINE_BUFFER-28     
xxx5                   = SCANLINE_BUFFER-32 
xxx6                   = SCANLINE_BUFFER-36 
xxx7                   = SCANLINE_BUFFER-40
xxx8                   = SCANLINE_BUFFER-44 
xxx9                   = SCANLINE_BUFFER-48 
xxx10                  = SCANLINE_BUFFER-52 
xxx11                  = SCANLINE_BUFFER-56 
xxx12                  = SCANLINE_BUFFER-60 
xxx13                  = SCANLINE_BUFFER-64 
xxx14                  = SCANLINE_BUFFER-68 
xxx15                  = SCANLINE_BUFFER-72 
xxx16                  = SCANLINE_BUFFER-76  

 ' NES bit encodings for NES gamepad 0
  NES0_RIGHT  = %00000000_00000001
  NES0_LEFT   = %00000000_00000010
  NES0_DOWN   = %00000000_00000100
  NES0_UP     = %00000000_00001000
  NES0_START  = %00000000_00010000
  NES0_SELECT = %00000000_00100000
  NES0_B      = %00000000_01000000
  NES0_A      = %00000000_10000000


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

  long joypad'grab value from controller

' random stuff
  long rand

  ' param for rem_engine:
  long cog_number
  long cog_total  
  long colors[1]

  byte tiles[768] 'memory for tiles   (768 = 32*24)
  byte tile_colors[768] 'memory for colors of tiles (768 = 32*24)
 
OBJ

  tv    : "rem_tv_014.spin"               ' tv driver 256 pixel scanline
  gfx   : "JTC_char_engine_001.spin"    ' graphics engine

PUB start      | i,ii,iii
  DIRA[0] := 1
  outa[0] := 0

  longfill(@colors, $02020202, 1) 'set the border in rightmost two hex digits
  long[tile_adr] := @tiles  'address of tiles
  long[tile_color_adr] := @tile_colors 'address for color of tile
  long[char_data_adr] := @Char_Data 'address for character data  

  ' Boot requested number of rendering cogs:
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
 
  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_colors := @colors
  tv.start(@tv_status)
{
  ClrScreen 'clear the screen

  'test charcaters  
  repeat i from 0 to 139
    PutCHR(i,i)

  repeat
    repeat while tv_status == 1
    repeat while tv_status == 2
}

{
PUB Display_Clock(i) | t, str
' does an sprintf(str, "%05d", i); job
str:=1
repeat t from 0 to 1
  BYTE [@Test_Text+5+str] := 48+(i // 10)
  i/=10
  str--
}
PUB ClrScreen | i
 'clears the screen
  repeat i from 0 to 767
    tiles[i]:=32
PUB NewLine | i, ii, iii
 'scrolls the page up to create a new line
  iii:=0
  repeat i from 0 to 22  'grab all the lines
   repeat ii from 0 to 31
    tiles[ii+iii]:=tiles[ii+iii+32]  'grab the line before it and copy it
   iii+=32    'new line
  'new line
  repeat i from 0 to 31
    tiles[i+iii]:=32    'clear the new line      
PUB PutCHR (char, tile_adrs)
'   char - character that will be printed
'  tile_adrs - memory location
  'make sure we don't go outside the tile map
  if(tile_adrs>CONSTANT((32*24)-1) )
   tile_adrs:=0
  'place tile
  tiles[tile_adrs]:=char
PUB Set_Border_Color(bcolor) | i
'set the color for border around screen
    if(bcolor<2)
     bcolor:=2
    i:= $02020200 + bcolor
    longfill(@colors, i, 1) 'set the border in rightmost two hex digits       
PUB Set_BG_Color (bcolor)
' if(bcolor>$09)
   bcolor-=2
'set color for background
    tile_colors[0]:=bcolor
PUB Set_FG_Color (bcolor)
' if(bcolor>$09)
   bcolor-=2
'set color for text
    tile_colors[1]:=bcolor     
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

DAT
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


'characters
Char_Data
'misc characters
byte 255,255,255,255,255,255,255,255 'solid block - 0
byte 170,85,170,85,170,85,170,85 ' checker board - 1
byte 128,64,32,16,8,4,2,1 ' slash char - 2
byte 56,84,214,254,130,68,56,0 ' smiley face - 3
byte 126,129,165,129,189,153,129,126 ' - 4
byte 0,0,0,0,0,0,0,0 ' nothing - 5                                 
byte 0,0,0,0,0,0,0,0 ' nothing - 6
byte 0,0,0,0,0,0,0,0 ' nothing - 7
byte 0,0,0,0,0,0,0,0 ' nothing - 8
byte 0,0,0,0,0,0,0,0 ' nothing - 9
byte 0,0,0,0,0,0,0,0 ' nothing - 10
byte 0,0,0,0,0,0,0,0 ' nothing - 11              
byte 0,0,0,0,0,0,0,0 ' nothing - 12
byte 0,0,0,0,0,0,0,0 ' nothing - 13
byte 0,0,0,0,0,0,0,0 ' nothing - 14
byte 0,0,0,0,0,0,0,0 ' nothing - 15
byte 0,0,0,0,0,0,0,0 ' nothing - 16
byte 0,0,0,0,0,0,0,0 ' nothing - 17
byte 0,0,0,0,0,0,0,0 ' nothing - 18              
byte 0,0,0,0,0,0,0,0 ' nothing - 19
byte 0,0,0,0,0,0,0,0 ' nothing - 20
byte 0,0,0,0,0,0,0,0 ' nothing - 21
byte 0,0,0,0,0,0,0,0 ' nothing - 22
byte 0,0,0,0,0,0,0,0 ' nothing - 23
byte 0,0,0,0,0,0,0,0 ' nothing - 24
byte 0,0,0,0,0,0,0,0 ' nothing - 25              
byte 0,0,0,0,0,0,0,0 ' nothing - 26
byte 0,0,0,0,0,0,0,0 ' nothing - 27
byte 0,0,0,0,0,0,0,0 ' nothing - 28
byte 0,0,0,0,0,0,0,0 ' nothing - 29
byte 0,0,0,0,0,0,0,0 ' nothing - 30
byte 0,0,0,0,0,0,0,0 ' nothing - 31
'enter, special characters
byte 0,0,0,0,0,0,0,0 ' Enter/Clear - 32              
byte 24,24,24,24,0,0,24,0 ' ! - 33
byte 102,102,102,0,0,0,0,0 ' " - 34
byte 102,102,255,102,255,102,102,0 ' # - 35
byte 24,62,96,60,6,124,24,0 '$ - 36
byte 98,102,12,24,48,102,70,0' % - 37
byte 60,102,60,56,103,102,63,0 ' & - 38
byte 6,12,24,0,0,0,0,0 ' ' - 39              
byte 12,24,48,48,48,24,12,0 ' ( - 40
byte 48,24,12,12,12,24,48,0 ' ) - 41
byte 0,102,60,255,60,102,0,0 ' * - 42
byte 0, 24,24,126,24,24,0,0 ' +  - 43
byte 0,0,0,0,0,24,24,48 ' ,  44
byte 0,0,0,126,0,0,0,0 ' - - 45
byte 0,0,0,0,0,24,24,0 ' . - 46              
byte 0,3,6,12,24,48,96,0 ' / - 47
'Numbers 0-9
byte 60,102,110,118,102,102,60,0 ' 0 - 48
byte 24,24,56,24,24,24,126,0 ' 1 - 49
byte 60,102,6,12,48,96,126,0 ' 2 - 50
byte 60,102,6,28,6,102,60,0 ' 3 - 51
byte 6,14,22,102,127,6,6,0 ' 4 - 52
byte 126,96,124,6,6,102,60,0 ' 5 - 53              
byte 60,102,96,124,102,102,60,0 ' 6 - 54
byte 126,102,12,12,12,12,12,0 ' 7 - 55
byte 60,102,102,60,102,102,60,0 ' 8 - 56
byte 60,102,102,62,6,102,60,0 ' 9 - 57
'special characters
byte 0,0,24,0,0,24,0,0 ' : - 58
byte 0,0,24,0,0,24,24,48 ' ; - 59
byte 14,24,48,96,48,24,14,0 ' < - 60
byte 0,0,126,0,126,0,0,0 ' = - 61
byte 112,24,12,6,12,24,112,0 ' > - 62
byte 60,102,6,12,24,0,24,0 ' ? - 63
byte 60,102,110,110,96,98,60,0 ' @ - 64
'A-Z upper case
byte 24,60,102,126,102,102,102,0 ' A - 65
byte 124,102,102,124,102,102,124,0 ' B - 66
byte 60,102,96,96,96,102,60,0 ' C - 67
byte 120,108,102,102,102,108,120,0 ' D - 68
byte 126,96,96,120,96,96,126,0 ' E - 69
byte 126,96,96,120,96,96,96,0 ' F - 70
byte 60,102,96,110,102,102,60,0 ' G - 71
byte 102,102,102,126,102,102,102,0 ' H - 72
byte 60,24,24,24,24,24,60,0 'I - 73
byte 30,12,12,12,12,108,56,0 ' J - 74
byte 102,108,120,112,120,108,102,0 ' K - 75
byte 96,96,96,96,96,96,126,0 ' L - 76
byte 99,119,127,107,99,99,99,0 ' M - 77
byte 102,118,126,110,102,102,102,0 ' N - 78
byte 60,102,102,102,102,102,60,0 ' O - 79
byte 124,102,102,124,96,96,96,0 ' P - 80
byte 60,102,102,102,102,102,60,14 ' Q - 81
byte 124,102,102,124,120,108,102,0 ' R - 82
byte 60,102,96,60,6,102,60,0 ' S - 83
byte 126,24,24,24,24,24,24,0 ' T - 84
byte 102,102,102,102,102,102,60,0 ' U - 85
byte 102,102,102,102,102,60,24,0 ' V - 86
byte 99,99,99,107,127,119,99,0 ' W - 87
byte 102,102,60,24,60,102,102,0 ' X - 88
byte 102,102,102,60,24,24,24,0 ' Y - 89
byte 126,6,12,24,48,112,126,0 ' Z - 90
'special characters
byte 60,48,48,48,48,48,60,0 ' [ - 91
byte 0,96,48,24,12,6,3,0 ' \ - 92
byte 60,12,12,12,12,12,60,0 ' ] - 93
byte 24,60,102,0,0,0,0,0 ' ^ - 94
byte 0,0,0,0,0,0,255,0 ' _ - 95
byte 96,48,24,0,0,0,0,0 ' ` - 96
'a-z lower case
byte 0,0,60,6,62,102,62,0 'a - 97
byte 0,96,96,124,102,102,124,0 ' b - 98
byte 0,0,60,96,96,96,60,0 ' c - 99
byte 0,6,6,62,102,102,62,0 ' d - 100
byte 0,0,60,102,126,96,60,0 ' e - 101
byte 0,14,24,62,24,24,24,0 ' f - 102
byte 0,0,62,102,102,62,6,124 ' g - 103
byte 0,96,96,124,102,102,102,0 ' h - 104
byte 0,24,0,56,24,24,60,0 ' i -105
byte 0,6,0,6,6,6,6,60 ' j -106
byte 0,96,96,108,120,108,102,0 ' k - 107
byte 0,56,24,24,24,24,60,0 ' l - 108
byte 0,0,102,127,127,107,99,0 ' m - 109
byte 0,0,124,102,102,102,102,0 ' n - 110
byte 0,0,60,102,102,102,60,0 ' o - 111
byte 0,0,124,102,102,124,96,96 ' p - 112
byte 0,0,62,102,102,62,6,6 ' q - 113
byte 0,0,124,102,96,96,96,0 ' r - 114
byte 0,0,62,96,60,6,124,0 ' s - 115
byte 0,24,126,24,24,24,14,0 ' t - 116
byte 0,0,102,102,102,102,62,0 ' u - 117
byte 0,0,102,102,102,60,24,0 ' v - 118
byte 0,0,99,107,127,62,54,0 ' w - 119
byte 0,0,102,60,24,60,102,0 ' x - 120
byte 0,0,102,102,102,62,12,120' y - 121
byte 0,0,126,12,24,48,126,0 ' Clear                                 122
'special characters
byte 28,48,48,224,48,48,28,0 ' { - 123
byte 24,24,24,24,24,24,24,24 ' | - 124
byte 56,12,12,7,12,12,56,0 ' } - 125
byte 54,108,0,0,0,0,0,0 ' ~ - 126
'misc characters
byte 0,0,0,0,0,0,0,0 ' Clear                                 127
byte 0,0,0,0,0,0,0,0 ' Clear                                 128
byte 0,0,0,0,0,0,0,0 ' Clear                                 129
byte 0,0,0,0,0,0,0,0 ' Clear                                 130
byte 0,0,0,0,0,0,0,0 ' Clear                                 131
byte 0,0,0,0,0,0,0,0 ' Clear                                 132
byte 0,0,0,0,0,0,0,0 ' Clear                                 133
byte 0,0,0,0,0,0,0,0 ' Clear                                 134
byte 0,0,0,0,0,0,0,0 ' Clear                                 135
byte 0,0,0,0,0,0,0,0 ' Clear                                 136
byte 0,0,0,0,0,0,0,0 ' Clear                                 137
byte 0,0,0,0,0,0,0,0 ' Clear                                 138
byte 0,0,0,0,0,0,0,0 ' Clear                                 139
byte 0,0,0,0,0,0,0,0 ' Clear                                 140