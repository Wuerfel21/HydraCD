' //////////////////////////////////////////////////////////////////////
' HydraMan                              
' AUTHOR: Colin Phillips
' LAST MODIFIED: 1.5.06
' VERSION 0.1
'
' DESCRIPTION:
' HydraMan - Multiplayer bomb blasting game :-)
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x          ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000      ' set frequency to 10 MHZ plus some error    
  _stack   = 1024                   ' stack

  obj_n         = 32                ' Number of Objects
  obj_size      = 5                 ' registers per object.
  obj_total_size = obj_n*obj_size   ' Total Number of registers (LONGS)
  OBJ_OFFSET_X  = 0
  OBJ_OFFSET_Y  = 1
  OBJ_OFFSET_W  = 2
  OBJ_OFFSET_H  = 3
  OBJ_OFFSET_I  = 4

  MAX_PLAYERS = 4                   
  PLAYER_STATUS = 0
  PLAYER_X = 1
  PLAYER_Y = 2
  PLAYER_ANIM = 3                   ' 0...63 [0..15:0,16..31:1,32..47:0,48..63:2..]
  PLAYER_DIR = 4
  PLAYER_BOMBS = 5
  PLAYER_BUTTON = 6
  PLAYER_BUTTONOLD = 7  
  PLAYER_SIZE = 8

  MAX_BOMBS = 32
  BOMB_STATUS = 0
  BOMB_X = 1
  BOMB_Y = 2
  BOMB_TYPE = 3
  BOMB_SIZE = 4

  DIR_UP = 0
  DIR_DOWN = 1
  DIR_LEFT = 2
  DIR_RIGHT = 3
  DIR_H = 2     ' Horiz Flag

  MAX_CONTROLLERS = 4
  
  ' BUTTON encodings (same as NES Controller)
  KEY_RIGHT  = %00000001
  KEY_LEFT   = %00000010
  KEY_DOWN   = %00000100
  KEY_UP     = %00001000
  KEY_START  = %00010000
  KEY_SELECT = %00100000
  KEY_B      = %01000000
  KEY_A      = %10000000

  MAP_WIDTH  = 16
  MAP_WIDTHS = 4                ' log2(MAP_WIDTH)
  MAP_HEIGHT = 14
  MAP_SIZE   = (MAP_WIDTH * MAP_HEIGHT)
  
  MAP_MOVEABLE = 0              ' 0..127 are moveable
  MAP_GROUND = 0                ' 0..31 (ground)
  MAP_ITEM   = 32               ' 32..63 (weapons/items)
  MAP_FLAME  = 64               ' 64..95 (flame)
  
  MAP_SOLID  = 128              ' 128..255 are solid
  MAP_BOMB   = 128              ' 128..159 (bombs)
  MAP_WALL   = 192              ' 192..223 (walls)
  MAP_BRICK  = 224              ' 224..255 (bricks)
  
'///////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

VAR

long  cop_status
long  cop_control
long  cop_debug
long  cop_phase0
long  cop_monitor0
long  cop_monitor1
long  cop_config
long  cop_vram
long  cop_tile
long  cop_panx
long  cop_pany
long  cop_bgcolor
' |
' |
' LAST
long  cop_obj[obj_total_size]       ' 12 sprite positions

long g_randseed

long player[MAX_PLAYERS*PLAYER_SIZE]
long bomb[MAX_BOMBS*BOMB_SIZE]

long controller[MAX_CONTROLLERS]

byte lmap[MAP_SIZE]                 ' logical map
byte emap[MAP_SIZE]                 ' extended map (used mostly for bomb, flame, brick decays)

word tilemap_ptr

long scanline_load

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

OBJ
  cop   : "cop_drv_010x.spin"        ' instantiate a cop object
  key   : "keyboard_iso_010.spin"    ' instantiate a keyboard object
  mouse : "mouse_iso_010.spin"       ' instantiate a mouse object  
  tiles : "CP_HYDRAMAN_TILES_001.spin" ' data object. (128x128 block of random sprites)
  map   : "CP_HYDRAMAN_MAP_001.spin" ' data object. (16x14 tile map)
  
'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB Start | x, y, i, n, dir, anim, frame
' this is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

  ' setup cop engine params.
  cop.setup(tiles.data,128,128, $f0, map.data)
  ' start cop engine
  cop.start(@cop_status)

  tilemap_ptr := map.data+32
  
  ' set random seed to global counter
  srand(cnt)
  
  'start keyboard on pingroup 3 
  key.start(3)

  'start mouse on pingroup 2 (Hydra mouse port)
  mouse.start(2)

  frame := 0
'sit in infinite loop.

  cop_bgcolor := $01010101 '$0a0a0a0a
  cop_panx := -8
  cop_pany := -8


  INIT_PLAYERS                                          ' initialize first
  INIT_BOMBS
  INIT_MAP

repeat while TRUE

' /////////////////////////////////////////////////////////////////////////////
' /// MAIN LOOP ///////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

  ' INPUT

  ' Convert all Inputs to controllers.
  
  ' NES Controllers (two player inputs)
    i := NES_Read_Gamepad
    if(i&$00ff == $00ff) ' controller 0 not plugged in, pretend all buttons are unpressed.
      i&=$ff00
    if(i&$ff00 == $ff00) ' controller 1 not plugged in, pretend all buttons are unpressed.
      i&=$00ff
      
    controller[0]:= i&$ff
    controller[1]:= (i>>8)&$ff
  ' Keyboard Controllers (one player input)
    controller[2]:= 0
    if(key.keystate($C2))
      controller[2]|=KEY_UP
    if(key.keystate($C3))
      controller[2]|=KEY_DOWN
    if(key.keystate($C0))
      controller[2]|=KEY_LEFT
    if(key.keystate($C1))
      controller[2]|=KEY_RIGHT
  ' Mouse Controllers (one player input)
    controller[3]:= 0
    
  INPUT_PLAYERS
  
  ' PROCESS
  PROCESS_PLAYERS
  'PROCESS_BOMBS

  ' DRAW    
  cop.newframe

  DRAW_PLAYERS
  'DRAW_BOMBS

  UPDATE_MAP
' sync to 60FPS :-)

  'cop.sprite(0,scanline_load,16,16,32,0)
  'scanline_load := cop_status
  cop.waitvsync

  frame++

' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

' /////////////////////////////////////////////////////////////////////////////
' MAP ENGINE //////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

PUB INIT_MAP | n,x,y

  ' initialize logical map

  ' set all squares to brick default
  repeat n from 0 to MAP_SIZE-1
    lmap[n] := CONSTANT(MAP_BRICK + 3)
          
  ' cut out player areas + shape (minus border)
  repeat n from 0 to 3
    x := player[n*PLAYER_SIZE+PLAYER_X]>>4
    y := player[n*PLAYER_SIZE+PLAYER_Y]>>4
    SET_CELL2(x,y,CONSTANT(MAP_GROUND))
    SET_CELL2(x-1,y,CONSTANT(MAP_GROUND))
    SET_CELL2(x+1,y,CONSTANT(MAP_GROUND))
    SET_CELL2(x,y-1,CONSTANT(MAP_GROUND))
    SET_CELL2(x,y+1,CONSTANT(MAP_GROUND))

  ' cut out some squares randomly - use prime numbers for rand.
  repeat n from 0 to 20
    x := rand//17
    y := rand//11
    if(x<MAP_WIDTH)
      SET_CELL2(x, y, CONSTANT(MAP_GROUND))
  
  ' insert solid wall blocks around edges
  repeat x from 0 to 14
    SET_CELL2(x,0,CONSTANT(MAP_WALL + 2))
    SET_CELL2(x,12,CONSTANT(MAP_WALL + 2))
  
  repeat y from 0 to 12
    SET_CELL2(0,y,CONSTANT(MAP_WALL + 2))
    SET_CELL2(14,y,CONSTANT(MAP_WALL + 2))

  ' insert solid wall blocks in grid like fashion
  repeat y from 0 to 12
    repeat x from 0 to 14
      if((x&1)==0)
        if((y&1)==0)
          SET_CELL2(x,y,CONSTANT(MAP_WALL + 2))

PUB MAP_CELL(px,py)

RETURN lmap[(py>>4)<<MAP_WIDTHS | (px>>4)]

PUB SET_CELL(px,py,c)

lmap[(py>>4)<<MAP_WIDTHS | (px>>4)] := c

PUB MAP_CELL2(px,py)

RETURN lmap[(py)<<MAP_WIDTHS | (px)]

PUB SET_CELL2(px,py,c)

lmap[(py)<<MAP_WIDTHS | (px)] := c

PUB UPDATE_MAP | x,y,n,s,d,c

  s := 0
  d := tilemap_ptr
  repeat n from 0 to CONSTANT(16*12-1)
    c := lmap[s] & 31
    WORD[d] := WORD[@lut_tilemap+c<<1]
    s++
    d+=2
    
  {      
  repeat y from 0 to 12
    s := y<<MAP_WIDTHS
    d := tilemap_ptr + s<<1
    repeat x from 0 to 14
      c := lmap[s] & 31
      WORD[d] := WORD[@lut_tilemap+c<<1]
      s++
      d+=2
  }
' /////////////////////////////////////////////////////////////////////////////
' PLAYERS ENGINE //////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
    
PUB INIT_PLAYERS | n,x,y,anim,dir

  ' initialize players

  repeat n from 0 to CONSTANT(MAX_PLAYERS-1)
    player[n*PLAYER_SIZE+PLAYER_STATUS] := 1
    case n
      0:x :=16
        y :=16
        anim :=0
        dir :=DIR_RIGHT
      1:x := 208
        y := 176
        anim := 0
        dir := DIR_LEFT
      2:x := 208
        y := 16
        anim := 0
        dir := DIR_DOWN
      3:x := 16
        y := 176
        anim := 0
        dir := DIR_UP
    player[n*PLAYER_SIZE+PLAYER_X] := x
    player[n*PLAYER_SIZE+PLAYER_Y] := y
    player[n*PLAYER_SIZE+PLAYER_ANIM] := anim
    player[n*PLAYER_SIZE+PLAYER_DIR] := dir
    player[n*PLAYER_SIZE+PLAYER_BOMBS] := 1
    player[n*PLAYER_SIZE+PLAYER_ANIM] := 0
    player[n*PLAYER_SIZE+PLAYER_BUTTONOLD] := 0
    player[n*PLAYER_SIZE+PLAYER_BUTTON] := 0


PUB INPUT_PLAYERS | n

  repeat n from 0 to CONSTANT(MAX_PLAYERS-1)
    player[n*PLAYER_SIZE+PLAYER_BUTTONOLD] := player[n*PLAYER_SIZE+PLAYER_BUTTON]
    player[n*PLAYER_SIZE+PLAYER_BUTTON] := controller[n]    

PUB PROCESS_PLAYERS | n,p,x,y,dx,dy,dir,old_dir, i,anim

  p := 0
  repeat n from 0 to CONSTANT(MAX_PLAYERS-1)
    i := player[p+PLAYER_BUTTON]
    old_dir := player[p+PLAYER_DIR]
    dir := -1
    dx := 0
    dy := 0
    if(dir&DIR_H) ' Horizontal keys have priority i.e. RIGHT+UP => RIGHT if you're already moving right.
      if(i&KEY_LEFT)
        dir := DIR_LEFT
      if(i&KEY_RIGHT)
        dir := DIR_RIGHT
      
    if(i&KEY_UP) ' Otherwise Vertical keys
      dir := DIR_UP
    if(i&KEY_DOWN)
      dir := DIR_DOWN
      
    if((dir&DIR_H)==0)
      if(i&KEY_LEFT)
        dir := DIR_LEFT
      if(i&KEY_RIGHT)
        dir := DIR_RIGHT
      
    x:=player[p+PLAYER_X]&15
    y:=player[p+PLAYER_Y]&15

    ' direction movement: YES
    if(dir<>-1)
      if(dir&DIR_H) ' Horiz. movement
        if(y&15) ' Not Vertically Grid Aligned? Go Up or Down, whichever is closest. if roughly neither then try to go Horiz.
          if(y<8)
            dir := old_dir' DIR_UP
          else
            'if(y>=8)
              dir := old_dir'DIR_DOWN
      else ' Vert. movement      
        if(x&15) ' Not Horizontally Grid Aligned? Go Up or Down, whichever is closest. if roughly neither then try to go Horiz.
          if(x<8)
            dir := old_dir'DIR_LEFT
          else
            'if(x>=8)
              dir := old_dir'DIR_RIGHT

    ' set vector based on direction.
      case dir
        DIR_UP:dy:=-1
        DIR_DOWN:dy:=1
        DIR_LEFT:dx:=-1
        DIR_RIGHT:dx:=1
        
      player[p+PLAYER_DIR] := dir

      ' set vars for detection point.
      x:=player[p+PLAYER_X]
      y:=player[p+PLAYER_Y]
      if(dx==-1)
        x-=1
        y+=8
      if(dy==-1)
        y-=1
        x+=8
      if(dx==1)
        x+=16
        y+=8
      if(dy==1)
        y+=16
        x+=8        
      
      ' solid cell check before movement
      if((MAP_CELL(x,y)&MAP_SOLID)==0)                                                                  
        player[p+PLAYER_X]+= dx
        player[p+PLAYER_Y]+= dy

      ' animate player
      if(player[p+PLAYER_ANIM]==0)
        player[p+PLAYER_ANIM]:=16              ' start on a footing.
      player[p+PLAYER_ANIM]+=2
    ' direction movement: NO
    else
      player[p+PLAYER_ANIM] := 0
    p+=PLAYER_SIZE
    

PUB DRAW_PLAYERS | n,x,y,dir,anim

  repeat n from 0 to CONSTANT(MAX_PLAYERS-1)
    x:= player[n*PLAYER_SIZE+PLAYER_X]-cop_panx
    y:= player[n*PLAYER_SIZE+PLAYER_Y]+8-cop_pany
    dir:= player[n*PLAYER_SIZE+PLAYER_DIR]<<3
    dir+= dir<<1
    anim:= player[n*PLAYER_SIZE+PLAYER_ANIM]
    if(anim&16) '   [0..15:0,16..31:1,32..47:0,48..63:2..]
      anim:= 16 + (anim&32)>>1
    else
      anim:= 0
    cop.sprite(x,y,16,24,anim,32+dir)

' /////////////////////////////////////////////////////////////////////////////
' BOMBS ENGINE ////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

PUB INIT_BOMBS | n

  ' turn off all bombs
  repeat n from 0 to CONSTANT(MAX_BOMBS-1)
    bomb[n*BOMB_SIZE+BOMB_STATUS] := 0

PUB DROP_BOMB(x,y,t) | n

  ' find spare bomb
  repeat n from 0 to CONSTANT(MAX_BOMBS-1)
    if(bomb[n*BOMB_SIZE+BOMB_STATUS]==0)
      bomb[n*BOMB_SIZE+BOMB_STATUS] := CONSTANT(60*3)
      bomb[n*BOMB_SIZE+BOMB_X] := x
      bomb[n*BOMB_SIZE+BOMB_Y] := y
      bomb[n*BOMB_SIZE+BOMB_TYPE] := t ' type / owner of bomb
      quit

PUB PROCESS_BOMBS | n,p

  p := 0
  repeat n from 0 to CONSTANT(MAX_BOMBS-1)
    if(bomb[p+BOMB_STATUS])
      bomb[p+BOMB_STATUS]--
    p+=BOMB_SIZE
      ' animate bomb based on status
      'if(bomb[n*BOMB_SIZE+BOMB_STATUS]==0)
        ' Kaboom!!!

PUB DRAW_BOMBS | n

  repeat n from 0 to CONSTANT(MAX_BOMBS-1)
    if(bomb[n*BOMB_SIZE+BOMB_STATUS])
      ' Render bombs as sprites when they're off 16x16 aligned (i.e. sliding bombs)

' /////////////////////////////////////////////////////////////////////////////
' MISC. Functions /////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

PUB Int_To_String(i, x, y) | n

' does an sprintf(str, "%08lX", i); job
repeat n from 7 to 0
  cop.sprite(x+(n<<4), y, 16, 16, 0, (i&15)<<4)
  i>>=4

PUB Sin(x) : y | t
' y = sin(x)
t := x&63
if(x&64)
  t^=63

y := WORD[$E000 | t<<6]

if(x&128)
  y := -y

PUB srand(seed)

g_randseed := seed

PUB rand | n1,n2

n1 := g_randseed&1      ' LSB1
n2 := g_randseed&2      ' LSB2
n2>>=1
n1 := n1^n2
n1<<=30
g_randseed>>=1
g_randseed := g_randseed|n1

RETURN g_randseed

PUB NES_Read_Gamepad : nes_bits        |  i

' //////////////////////////////////////////////////////////////////
' NES Game Paddle Read
' //////////////////////////////////////////////////////////////////       
' reads both gamepads in parallel encodes 8-bits for each in format
' right game pad #1 [15..8] : left game pad #0 [7..0]
'
' set I/O ports to proper direction
' P3 = JOY_CLK      (4)
' P4 = JOY_SH/LDn   (5) 
' P5 = JOY_DATAOUT0 (6)
' P6 = JOY_DATAOUT1 (7)
' NES Bit Encoding
'
' RIGHT  = %00000001
' LEFT   = %00000010
' DOWN   = %00000100
' UP     = %00001000
' START  = %00010000
' SELECT = %00100000
' B      = %01000000
' A      = %10000000

' step 1: set I/Os
DIRA [3] := 1 ' output
DIRA [4] := 1 ' output
DIRA [5] := 0 ' input
DIRA [6] := 0 ' input

' step 2: set clock and latch to 0
OUTA [3] := 0 ' JOY_CLK = 0
OUTA [4] := 0 ' JOY_SH/LDn = 0
'Delay(1)

' step 3: set latch to 1
OUTA [4] := 1 ' JOY_SH/LDn = 1
'Delay(1)

' step 4: set latch to 0
OUTA [4] := 0 ' JOY_SH/LDn = 0

' step 5: read first bit of each game pad

' data is now ready to shift out
' first bit is ready 
nes_bits := 0

' left controller
nes_bits := INA[5] | (INA[6] << 8)

' step 7: read next 7 bits
repeat i from 0 to 6
 OUTA [3] := 1 ' JOY_CLK = 1
 'Delay(1)             
 OUTA [3] := 0 ' JOY_CLK = 0
 nes_bits := (nes_bits << 1)
 nes_bits := nes_bits | INA[5] | (INA[6] << 8)

 'Delay(1)             
' invert bits to make positive logic
nes_bits := (!nes_bits & $FFFF)

' //////////////////////////////////////////////////////////////////
' End NES Game Paddle Read
' //////////////////////////////////////////////////////////////////

DAT

lut_tilemap             WORD                    $0
                        WORD                    $10
                        WORD                    $20
                        WORD                    $30
                        WORD                    $40
                        WORD                    $50
                        WORD                    $60
                        WORD                    $70
                        WORD                    ($80*16)+$0
                        WORD                    ($80*16)+$10
                        WORD                    ($80*16)+$20
                        WORD                    ($80*16)+$30
                        WORD                    ($80*16)+$40
                        WORD                    ($80*16)+$50
                        WORD                    ($80*16)+$60
                        WORD                    ($80*16)+$70