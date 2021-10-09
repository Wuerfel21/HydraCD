' //////////////////////////////////////////////////////////////////////
' HydraMan                              
' AUTHOR: Colin Phillips
' LAST MODIFIED: 1.8.06
' VERSION 0.2
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
  _memstart = $10                   ' memory starts $10 in!!! (this took 2 headaches to figure out)
  
' COP HEADER ------------------------------------------------------------------

  obj_n         = 32                ' Number of Objects
  obj_size      = 5                 ' registers per object.
  obj_total_size = obj_n*obj_size   ' Total Number of registers (LONGS)
  OBJ_OFFSET_X  = 0
  OBJ_OFFSET_Y  = 1
  OBJ_OFFSET_W  = 2
  OBJ_OFFSET_H  = 3
  OBJ_OFFSET_I  = 4

  #0, h_cop_status, h_cop_control, h_cop_debug, h_cop_phase0, h_cop_monitor0, h_cop_monitor1, h_cop_config, h_cop_vram, h_cop_tile, h_cop_panx, h_cop_pany, h_cop_bgcolor, h_cop_obj

' -----------------------------------------------------------------------------

  FRAMERATE = 60                ' 60FPS!!!

  MAX_PLAYERS = 4                   
  PLAYER_STATUS = 0
  PLAYER_X = 1
  PLAYER_Y = 2
  PLAYER_ANIM = 3                   ' 0...63 [0..15:0,16..31:1,32..47:0,48..63:2..]
  PLAYER_DIR = 4
  PLAYER_BOMBS = 5
  PLAYER_BUTTON = 6
  PLAYER_BUTTONOLD = 7
  PLAYER_TICK = 8                   ' encode both speed and tick in here.
  PLAYER_FLAME = 9
  PLAYER_INVINCIBLE = 10
  '
  '
  '
  ' PLAYER_???? = 15
  PLAYER_SIZE = 16

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
  MAP_OFFX   = 8
  MAP_OFFY   = 8
  
  MAP_MOVEABLE = 0              ' 0..127 are moveable
  MAP_GROUND = 0                ' 0..31 (ground)
  MAP_ITEM   = 32               ' 32..63 (weapons/items)
  MAP_FLAME  = 64               ' 64..95 (flame)
  
  MAP_SOLID  = 128              ' 128..255 are solid
  MAP_BOMB   = 128              ' 128..159 (bombs)
  MAP_WALL   = 192              ' 192..223 (walls)
  MAP_BRICK  = 224              ' 224..255 (bricks)

  GAMESTATE_ALIVE = 0
  GAMESTATE_TIME = 1
  GAMESTATE_VICTORY = 2
  
'///////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

' COP HEADER ------------------------------------------------------------------

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

' -----------------------------------------------------------------------------

long g_randseed

long player[MAX_PLAYERS*PLAYER_SIZE]
long bomb[MAX_BOMBS*BOMB_SIZE]

long controller[MAX_CONTROLLERS]

byte lmap[MAP_SIZE]                 ' logical map
byte emap[MAP_SIZE]                 ' extended map (used mostly for bomb, flame, brick decays)
byte omap[MAP_SIZE]                 ' owner map (for identifying who owns which bombs/flames)
byte fmap[MAP_SIZE]                 ' flame map overlays logical map.

long gamestate[8]

word tilemap_ptr

long scanline_load

long scratch_pad

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

OBJ
  cop   : "cop_drv_010x.spin"          ' instantiate a cop object
  key   : "keyboard_iso_010.spin"    ' instantiate a keyboard object
  mouse : "mouse_iso_010.spin"       ' instantiate a mouse object  
  tiles : "CP_HYDRAMAN_TILES_001.spin" ' data object. (128x128 block of hydraman sprites)
  'tiles : "CP_HYDRAMAN_TILES_002.spin" ' data object. (16x512 block debug sprites - numbers)
  map   : "CP_HYDRAMAN_MAP_001.spin"  ' data object. (16x14 tile map)
  loader : "CP_LOADER_KERNEL_001.spin" ' loader kernel (boots paged cogs)
  
'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB Start | x, y, i, n, dir, anim, frame
' this is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

  ' setup cop engine params.
  cop.setup(tiles.data,128,128, $f0, map.data)
  'cop.setup(tiles.data,16,512, $f0, map.data)
  ' start cop engine
  cop.start(@cop_status)    
  
  ' start a loader cog, and make it execute GAMEINIT_START code
  g_copptr := @cop_status
  g_objptr := @cop_obj
  g_controllerptr := @controller
  g_playerptr := @player
  g_bombptr := @bomb
  g_vramptr := cop_vram
  g_tileptr := cop_tile
  g_lmap := @lmap
  g_emap := @emap
  g_omap := @omap
  g_fmap := @fmap
  g_gamestate := @gamestate

  loader.start(@GAMEINIT_START)

  'repeat while TRUE
  
  'start keyboard on pingroup 3 
  key.start(3)

  'start mouse on pingroup 2 (Hydra mouse port)
  mouse.start(2)
  
  
  repeat while TRUE
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
    if(key.keystate($77)) 'W'
      controller[2]|=KEY_UP
    if(key.keystate($73)) 'S'
      controller[2]|=KEY_DOWN
    if(key.keystate($61)) ' A
      controller[2]|=KEY_LEFT
    if(key.keystate($64)) ' D
      controller[2]|=KEY_RIGHT
    if(key.keystate($F0)) ' Shift-L
      controller[2]|=KEY_A
'   if(key.keystate($F2)) ' Ctrl-L
'     controller[2]|=KEY_B
  ' Mouse Controllers (one player input)
    controller[3]:= 0
    if(key.keystate($C2))
      controller[3]|=KEY_UP
    if(key.keystate($C3))
      controller[3]|=KEY_DOWN
    if(key.keystate($C0))
      controller[3]|=KEY_LEFT
    if(key.keystate($C1))
      controller[3]|=KEY_RIGHT
    if(key.keystate($F1)) ' Shift-R
      controller[3]|=KEY_A
'   if(key.keystate($F3)) ' Ctrl-R
'     controller[3]|=KEY_B

    cop.waitvsync  


' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////


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
 

' pointers to some spin variables.

g_copptr                LONG                    $0
g_objptr                LONG                    $0
g_controllerptr         LONG                    $0
g_playerptr             LONG                    $0
g_bombptr               LONG                    $0
g_vramptr               LONG                    $0
g_tileptr               LONG                    $0
g_lmap                  LONG                    $0
g_emap                  LONG                    $0
g_omap                  LONG                    $0
g_fmap                  LONG                    $0
g_gamestate             LONG                    $0


' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' GAME ENGINE /////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

' /////////////////////////////////////////////////////////////////////////////
' GAMEINIT ////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        org
GAMEINIT_START

' initialize map, player postions, bombs, scores etc.

                        ' r0 = @cop_status
                        mov    r0, #(_memstart+@g_copptr)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_copptr)
                        rdlong r0, r0

                        ' cop_pany = -8
                        mov    r1, r0
                        add    r1, #h_cop_pany*4
                        neg    r2, #8
                        wrlong r2, r1

                        ' Initialize some game engines...

:loop

                        ' r0 = @cop_status
                        mov    r0, #(_memstart+@g_copptr)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_copptr)
                        rdlong r0, r0
                        
                        ' cop_bgcolor = 01010101
                        mov    r1, r0
                        add    r1, #h_cop_bgcolor*4
                        wrlong :bgcolor, r1


                        ' r0 = @gamestate
                        mov    r0, #(_memstart+@g_gamestate)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_gamestate)
                        rdlong r0, r0
                        add    r0, #GAMESTATE_ALIVE*4
                        mov    r1, #4
                        wrlong r1, r0

                        mov    r0, #(_memstart+@g_gamestate)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_gamestate)
                        rdlong r0, r0
                        add    r0, #GAMESTATE_VICTORY*4
                        mov    r1, #0                   ' no victory
                        wrlong r1, r0

                              
                        ' === Execute Block of Code "INITPLAYERS" (should be done before map)
                        mov    __loader_page, #(_memstart+@INITPLAYERS_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@INITPLAYERS_START) & $1FF         
                        mov    __loader_size, #(INITPLAYERS_END-INITPLAYERS_START)
                        mov    __loader_jmp, #INITPLAYERS_START
                        jmpret __loader_ret,#__loader_call

                        ' === Execute Block of Code "INITMAP"
                        mov    __loader_page, #(_memstart+@INITMAP_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@INITMAP_START) & $1FF             
                        mov    __loader_size, #(INITMAP_END-INITMAP_START)
                        mov    __loader_jmp, #INITMAP_START
                        jmpret __loader_ret,#__loader_call                                   

                        ' Start main game loop...

                        ' === Execute Block of Code "GAMELOOP"
                        mov    __loader_page, #(_memstart+@GAMELOOP_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@GAMELOOP_START)            
                        mov    __loader_size, #(GAMELOOP_END-GAMELOOP_START)
                        mov    __loader_jmp, #GAMELOOP_START
                        jmpret __loader_ret,#__loader_call                                   

                        jmp    #:loop

:bgcolor                long                    $01010101

GAMEINIT_END

' /////////////////////////////////////////////////////////////////////////////
' GAMELOOP ////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        org

GAMELOOP_START

:nextframe

                        ' r0 = @cop_status
                        mov    r0, #(_memstart+@g_copptr)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_copptr)
                        rdlong r0, r0


' wait for end of vertical sync pulse...

                        mov    r1, r0
                        add    r1, #h_cop_status*4
:vsyncloop1             rdlong r2, r1                   wz
        if_nz           jmp    #:vsyncloop1
        
:vsyncloop2             rdlong r2, r1                   wz
        if_z            jmp    #:vsyncloop2


' clear obj list...

                        ' (clear obj's) g_objptr = @cop_obj (Set OBJ pointer back to start)
                        mov    r1, r0
                        add    r1, #h_cop_obj*4
                        mov    r2, #(_memstart+@g_objptr)>>9
                        shl    r2, #9
                        or     r2, #(_memstart+@g_objptr)
                        wrlong r1, r2                        

                        mov    r0, r1
                        
' sets all OBJ's Y positions to offscreen.

                        mov    r1, #255                                         ' Y = 255
                        add    r0, #OBJ_OFFSET_Y*4                              ' offset to Y attribute.
                        mov    r2, #obj_n                                       ' do all OBJ's
:objclrloop
                        wrlong r1, r0
                        add    r0, #obj_size*4
                        djnz   r2, #:objclrloop

' process...
                        ' === Execute Block of Code "PROCESSPLAYERS"
                        mov    __loader_page, #(_memstart+@PROCESSPLAYERS_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@PROCESSPLAYERS_START) & $1FF      
                        mov    __loader_size, #(PROCESSPLAYERS_END-PROCESSPLAYERS_START)
                        mov    __loader_jmp, #PROCESSPLAYERS_START
                        jmpret __loader_ret,#__loader_call                        

                        ' === Execute Block of Code "PROCESSMAP"
                        mov    __loader_page, #(_memstart+@PROCESSMAP_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@PROCESSMAP_START) & $1FF          
                        mov    __loader_size, #(PROCESSMAP_END-PROCESSMAP_START)
                        mov    __loader_jmp, #PROCESSMAP_START
                        jmpret __loader_ret,#__loader_call

                        ' === Execute Block of Code "PROCESSBOMBS"
                        mov    __loader_page, #(_memstart+@PROCESSBOMBS_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@PROCESSBOMBS_START) & $1FF        
                        mov    __loader_size, #(PROCESSBOMBS_END-PROCESSBOMBS_START)
                        mov    __loader_jmp, #PROCESSBOMBS_START
                        jmpret __loader_ret,#__loader_call

' draw...

                        ' === Execute Block of Code "UPDATEMAP"
                        mov    __loader_page, #(_memstart+@UPDATEMAP_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@UPDATEMAP_START) & $1FF           
                        mov    __loader_size, #(UPDATEMAP_END-UPDATEMAP_START)
                        mov    __loader_jmp, #UPDATEMAP_START
                        jmpret __loader_ret,#__loader_call                                   

                        ' === Execute Block of Code "DRAWPLAYERS"
                        mov    __loader_page, #(_memstart+@DRAWPLAYERS_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@DRAWPLAYERS_START) & $1FF         
                        mov    __loader_size, #(DRAWPLAYERS_END-DRAWPLAYERS_START)
                        mov    __loader_jmp, #DRAWPLAYERS_START
                        jmpret __loader_ret,#__loader_call


                        ' check victory sequence...
                        mov    r0, #(_memstart+@g_gamestate)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_gamestate)
                        rdlong r0, r0
                        add    r0, #GAMESTATE_VICTORY*4
                        rdlong r1, r0           wz
        if_z            jmp    #:no_victory
                        sub    r1, #1           wz      ' victory--
                        wrlong r1, r0
        if_z            jmp    #__loader_return

                        test   r1, #3           wz
        if_nz           jmp    #:skip_bgeffect
                        
                        ' r0 = @cop_status
                        mov    r0, #(_memstart+@g_copptr)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_copptr)
                        rdlong r0, r0                        
                        add    r0, #h_cop_bgcolor*4
                        rdlong r2, r0
                        
                        add    r2, :bgaddcolor
                        and    r2, :bgandcolor
                        or     r2, :bgorcolor
                        wrlong r2, r0
                        
:skip_bgeffect
        
                        jmp    #:no_winner              ' skip playeralive checking
                        
:bgaddcolor             long                    $10101010                       ' shift colors
:bgandcolor             long                    $f0f0f0f0                       ' stop overspill
:bgorcolor              long                    $0b0b0b0b                       ' enforce chroma enable & luma

:no_victory
' check if it's gameover yet                        

                        ' r0 = @gamestate
                        mov    r0, #(_memstart+@g_gamestate)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_gamestate)
                        rdlong r0, r0
                        add    r0, #GAMESTATE_ALIVE*4
                        rdlong r0, r0           wz      ' "DRAW GAME".
        if_z            jmp    #__loader_return

                        cmp    r0, #1           wz ' a winner
        if_nz           jmp    #:no_winner

                        mov    r0, #(_memstart+@g_gamestate)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_gamestate)
                        rdlong r0, r0
                        add    r0, #GAMESTATE_VICTORY*4
                        mov    r1, #60*3        ' 3 seconds before restart.
                        wrlong r1, r0

:no_winner

                        jmp       #:nextframe

GAMELOOP_END

' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' MAP ENGINE //////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

' /////////////////////////////////////////////////////////////////////////////
' INITMAP /////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        org
INITMAP_START
                        
                        ' r0 = @lmap
                        mov    r0, #(_memstart+@g_lmap)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_lmap)
                        rdlong r0, r0

' set all squares to brick default
                        mov    r1, r0
                        mov    r2, #MAP_SIZE
                        mov    r3, #MAP_BRICK+3
:allbricks
                        wrbyte r3, r1
                        add    r1, #1

                        djnz   r2, #:allbricks

' cut out player areas in a plus '+' shape

                        ' r3 = @player
                        mov    r3, #(_memstart+@g_playerptr)>>9
                        shl    r3, #9
                        or     r3, #(_memstart+@g_playerptr)
                        rdlong r3, r3
                        
                        mov    r2, #MAX_PLAYERS
                        mov    r1, #MAP_GROUND
                           
:allplayers
'                       rdlong r4, r3           wz
'       if_z            jmp    #:allplayersskip ' STATUS == 0?
                        mov    r4, r3
                        add    r4, #PLAYER_X*4
                        rdlong r4, r4
                        mov    r5, r3
                        add    r5, #PLAYER_Y*4
                        rdlong r5, r5

                        ' x/=16, y/=16 (into tiles)
                        shr    r4, #4
                        shr    r5, #4

                        ' r5 = y*16 + x
                        shl    r5, #MAP_WIDTHS
                        add    r5, r4

                        ' offset to tilemap
                        add    r5, r0

                        ' ok do position 8 first. (above) i.e. -width
                        
                        sub    r5, #MAP_WIDTH
                        wrbyte r1, r5

                        ' now do position 4. (left) i.e. -1
                        add    r5, #MAP_WIDTH-1
                        wrbyte r1, r5
                        
                        ' now do position 5. (center) i.e. 0
                        add    r5, #1
                        wrbyte r1, r5

                        ' now do position 6. (right) i.e. +1
                        add    r5, #1
                        wrbyte r1, r5

                        ' finally do position 2. (down) i.e. +width
                        add    r5, #MAP_WIDTH-1
                        wrbyte r1, r5

:allplayersskip         
                        add    r3, #PLAYER_SIZE*4
                        djnz   r2, #:allplayers

' cut out some random squares
' [*] need to use a % modulo function.

                        mov    r3, r0
                        mov    r1, #MAP_GROUND
                        mov    r2, #MAP_SIZE
                        mov    r4, cnt

:randcutout

                        test   r4, #%11         wc      ' carry = parity (bit 0 ^ bit 1)
                        rcr    r4, #1
                        
                        mov    r5, r4
                        and    r5, #0           wz
        if_z            wrbyte r1, r3
                        add    r3, #1
                        
                        djnz   r2, #:randcutout

' insert solid wall blocks in a grid-like pattern

                        mov    r1, #MAP_WALL+2
                        mov    r3, r0

                        mov    r5, #7
:wallloop_y             
                        mov    r4, #8
:wallloop_x             
                        wrbyte r1, r3
                        add    r3, #2
                        djnz   r4, #:wallloop_x
                        
                        add    r3, #MAP_WIDTH   ' skip a line.
                        
                        djnz   r5, #:wallloop_y

' insert solid wall blocks around edges

                        mov    r1, #MAP_WALL+2
                        
                        ' top line
                        mov    r2, #15
                        mov    r3, r0
                        
:perimeter1
                        wrbyte r1, r3
                        add    r3, #1
                        djnz   r2, #:perimeter1

                        ' bottom line
                        mov    r2, #15
                        mov    r3, r0
                        add    r3, #MAP_WIDTH*12
:perimeter2

                        wrbyte r1, r3
                        add    r3, #1
                        djnz   r2, #:perimeter2

                        ' right/left line
                        mov    r2, #12
                        mov    r3, r0
                        add    r3, #14          ' start at right.
:perimeter3

                        wrbyte r1, r3           ' right
                        add    r3, #2
                        wrbyte r1, r3           ' left
                        add    r3, #MAP_WIDTH-2
                        djnz   r2, #:perimeter3


' set extended map to 0.

                        ' r0 = @lmap
                        mov    r0, #(_memstart+@g_emap)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_emap)
                        rdlong r0, r0

                        mov    r1, r0
                        mov    r2, #MAP_SIZE
                        mov    r3, #MAP_BRICK+3
:allext
                        wrbyte r3, r1
                        add    r1, #1

                        djnz   r2, #:allext


' set flame map to 0.

                        ' r0 = @fmap
                        mov    r0, #(_memstart+@g_fmap)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_fmap)
                        rdlong r0, r0

                        mov    r1, r0
                        mov    r2, #MAP_SIZE
                        mov    r3, #0
:allflame
                        wrbyte r3, r1
                        add    r1, #1

                        djnz   r2, #:allflame

                        jmp #__loader_return

INITMAP_END                 

' /////////////////////////////////////////////////////////////////////////////
' PROCESSMAP //////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        org
PROCESSMAP_START

                        ' r0 = @lmap
                        mov    r0, #(_memstart+@g_lmap)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_lmap)
                        rdlong r0, r0

                        ' r1 = @emap
                        mov    r1, #(_memstart+@g_emap)>>9
                        shl    r1, #9
                        or     r1, #(_memstart+@g_emap)
                        rdlong r1, r1

                        ' r7 = @fmap
                        mov    r7, #(_memstart+@g_fmap)>>9
                        shl    r7, #9
                        or     r7, #(_memstart+@g_fmap)
                        rdlong r7, r7

                        mov    r4, #MAP_SIZE
:loop
                        rdbyte r2, r0
                        shr    r2, #5
                        cmp    r2, #MAP_BOMB>>5 wz
        if_nz           jmp    #:not_bomb

                        ' Make bombs tick down to 0. and stay at 0. - process bombs will take care of the rest.
                        rdbyte r2, r1           wz
        if_nz           sub    r2, #1

                        wrbyte r2, r1

                        ' Adjust Bomb animation based on time.
                        add    r2, #8
                        shr    r2, #4
                        and    r2, #3
                        cmp    r2, #3           wz
        if_z            mov    r2, #1                   ' 0,1,2,3 => 0,1,2,1

                        add    r2, #MAP_BOMB+8
                        
                        wrbyte r2, r0

:not_bomb
                        rdbyte r2, r7           ' Flame map. 
                        cmp    r2, #0           wz ' Flame?
        if_z            jmp    #:not_flame
                        ' Make flames tick down to 0 then turn off.
                        rdbyte r2, r1           wz
        if_nz           sub    r2, #1

                        wrbyte r2, r1
                        mov    r2, #0
        if_z            wrbyte r2, r7           ' Extinguish Flame.
        
:not_flame
                        add    r0, #1
                        add    r1, #1
                        add    r7, #1
                        djnz   r4, #:loop
                        
                        jmp #__loader_return
                        
PROCESSMAP_END

' /////////////////////////////////////////////////////////////////////////////
' UPDATEMAP ///////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        org
UPDATEMAP_START

                        ' r0 = @lmap "Logical Map"
                        mov    r0, #(_memstart+@g_lmap)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_lmap)
                        rdlong r0, r0

                        ' r1 = @cop_tile
                        mov    r1, #(_memstart+@g_tileptr)>>9
                        shl    r1, #9
                        or     r1, #(_memstart+@g_tileptr)
                        rdlong r1, r1
                        add    r1, #16*2 ' one line down

                        ' r3 = @fmap "Flame Map"
                        mov    r3, #(_memstart+@g_fmap)>>9
                        shl    r3, #9
                        or     r3, #(_memstart+@g_fmap)
                        rdlong r3, r3                        

                        ' r7 = @emap "Ext Map"
                        mov    r7, #(_memstart+@g_emap)>>9
                        shl    r7, #9
                        or     r7, #(_memstart+@g_emap)
                        rdlong r7, r7                        
                        
                        mov    r4, #MAP_SIZE                        
:loop
                        rdbyte r2, r0 ' r2 = lmap[s]
                        and    r2, #31 ' lower 5 bits are the tile image.

                        rdbyte r6, r7 ' r6 = emap[e]

                        ' Display Standard image for this tile.
                        add    r2, #:lut_tmap
                        movd   :code_d, r2
                        add    r0, #1 ' s++

                        rdbyte r2, r3 ' r2 = fmap[f]
                        cmp    r2, #0           wz
        if_z            jmp    #:noflame
                        ' Overide with a Flame image for this tile
                        and    r2, #7  ' flame shapes 1..7  +, |, -, /\, \/, <, >
                        add    r2, #:lut_fmap
                        
                        movs   :code_s, r2
                        nop
                        
:code_s                 mov    r2, 0

                        shr    r6, #3           ' ext/8 (0,1,2,3,4 => 0,1,2,1,0
                        cmp    r6, #3           wz
        if_z            mov    r6, #1
                        cmp    r6, #4           wz
        if_z            mov    r6, #0

                        shl    r6, #4           ' get to correct horiz. cell offset.
                        add    r2, r6
                        
                        wrword r2, r1 ' tile[d] = r1

                        jmp    #:next
        
:noflame                

:code_d                 wrword 0, r1  ' tile[d] = lut_tmap[r2]
:next                   add    r1, #2 ' d++
                        add    r3, #1 ' f++
                        add    r7, #1 ' e++

                        djnz   r4, #:loop

                        
                        jmp #__loader_return

:lut_tmap               LONG                    $0
                        LONG                    $10
                        LONG                    $20
                        LONG                    $30
                        LONG                    $40
                        LONG                    $50
                        LONG                    $60
                        LONG                    $70
                        LONG                    ($80*16)+$0
                        LONG                    ($80*16)+$10
                        LONG                    ($80*16)+$20
                        LONG                    ($80*16)+$30
                        LONG                    ($80*16)+$40
                        LONG                    ($80*16)+$50
                        LONG                    ($80*16)+$60
                        LONG                    ($80*16)+$70

:lut_fmap               LONG                    ($80*0)+$50
                        LONG                    ($80*16)+$50
                        LONG                    ($80*32)+$50
                        LONG                    ($80*48)+$50
                        LONG                    ($80*64)+$50
                        LONG                    ($80*80)+$50
                        LONG                    ($80*96)+$50
                        LONG                    ($80*112)+$50


UPDATEMAP_END

' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' BOMBS ENGINE ////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        org
PROCESSBOMBS_START                       

                        ' r0 = @lmap
                        mov    r0, #(_memstart+@g_lmap)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_lmap)
                        rdlong r0, r0

                        ' r1 = @emap
                        mov    r1, #(_memstart+@g_emap)>>9
                        shl    r1, #9
                        or     r1, #(_memstart+@g_emap)
                        rdlong r1, r1

                        ' r3 = @omap
                        mov    r3, #(_memstart+@g_omap)>>9
                        shl    r3, #9
                        or     r3, #(_memstart+@g_omap)
                        rdlong r3, r3

                        ' r7 = @fmap
                        mov    r7, #(_memstart+@g_fmap)>>9
                        shl    r7, #9
                        or     r7, #(_memstart+@g_fmap)
                        rdlong r7, r7

                        mov    r4, #MAP_SIZE
:loop
                        rdbyte r2, r0
                        shr    r2, #5
                        cmp    r2, #MAP_BOMB>>5 wz
        if_nz           jmp    #:next

                        rdbyte r2, r7           wz ' check flame map to see if this bomb is under a flame.
                        mov    r2, #0              
        if_nz           wrbyte r2, r1              ' if so force explosion immediately!

                        ' Check if Bomb's timer is at 0 - if so explode it!
                        rdbyte r2, r1           wz

        if_z            jmpret :explode_ret, #:explode

:next                              

                        add    r0, #1
                        add    r1, #1
                        add    r3, #1
                        add    r7, #1
                        djnz   r4, #:loop
                        
                        jmp #__loader_return

:explode
                        ' remove bomb
                        mov    r2, #MAP_GROUND
                        wrbyte r2, r0

                        ' give bomb back to owner.
                        rdbyte r2, r3

                        ' r5 = @player
                        mov    r5, #(_memstart+@g_playerptr)>>9
                        shl    r5, #9
                        or     r5, #(_memstart+@g_playerptr)
                        rdlong r5, r5
                        shl    r2, #6           ' PLAYER STRUCTURE SIZE. (PLAYER_SIZE = 16*4bytes) Caution!!!
                        add    r5, r2
                        mov    :playeroffset, r5
                        add    r5, #PLAYER_BOMBS*4

                        rdlong r2, r5
                        add    r2, #1
                        wrlong r2, r5

                        ' generate flame. from r7 in various directions.

                        ' center
                        mov    r2, #1
                        wrbyte r2, r7           ' FLAME

                        mov    r2, #32
                        wrbyte r2, r1           ' EXT


                        ' r5 = @player                        
                        mov    r5, :playeroffset
                        add    r5, #PLAYER_FLAME*4

                        rdlong :flamelen, r5

                        ' Right flame >
                        mov    r2, #32          ' EXT
                        mov    :fp, r7
                        mov    :ep, r1
                        mov    :lp, r0
                        mov    :len, :flamelen
                        mov    :dir, #1
                        mov    :midsect, #3     ' -
                        mov    :endsect, #7     ' >

                        jmpret :flamerun_ret, #:flamerun

                        ' Left flame <
                        mov    :fp, r7
                        mov    :ep, r1
                        mov    :lp, r0
                        mov    :len, :flamelen
                        neg    :dir, #1
                        mov    :midsect, #3     ' -
                        mov    :endsect, #6     ' <

                        jmpret :flamerun_ret, #:flamerun

                        ' Top flame /\
                        mov    :fp, r7
                        mov    :ep, r1
                        mov    :lp, r0
                        mov    :len, :flamelen
                        neg    :dir, #MAP_WIDTH
                        mov    :midsect, #2     ' |
                        mov    :endsect, #4     ' /\

                        jmpret :flamerun_ret, #:flamerun

                        ' Bottom flame \/
                        mov    :fp, r7
                        mov    :ep, r1
                        mov    :lp, r0
                        mov    :len, :flamelen
                        mov    :dir, #MAP_WIDTH
                        mov    :midsect, #2     ' |
                        mov    :endsect, #5     ' \/

                        jmpret :flamerun_ret, #:flamerun
                        
:explode_ret            ret

:flamerun

:floop
                        add    :fp, :dir
                        add    :ep, :dir
                        add    :lp, :dir                        

                        rdbyte r5, :lp
                        test   r5, #MAP_SOLID   wz
        if_z            jmp    #:continueflame
                        ' abort flame run. but also find out what we hit ;-)
                        shr    r5, #5           
                        cmp    r5, #MAP_BOMB>>5 wz
                        mov    r6, #6                   ' give a 6 frame (6/60 sec) propagation delay between flame->bomb's
        if_z            wrbyte r6, :ep
                        
                        jmp #:endfloop
                        
:continueflame

                        cmp    :len, #1         wz
        if_z            wrbyte :endsect, :fp
        if_nz           wrbyte :midsect, :fp
                        wrbyte r2, :ep
                        
                        djnz   :len, #:floop
:endfloop

:flamerun_ret           ret

:lp                     long                    $0
:fp                     long                    $0
:ep                     long                    $0
:len                    long                    $0
:dir                    long                    $0
:midsect                long                    $0
:endsect                long                    $0
:flamelen               long                    $0
:playeroffset           long                    $0
                        
                        jmp #__loader_return
PROCESSBOMBS_END                         

' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' PLAYERS ENGINE //////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

' /////////////////////////////////////////////////////////////////////////////
' INITPLAYERS /////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        org
INITPLAYERS_START                        
                        
                        ' r0 = @player
                        mov    r0, #(_memstart+@g_playerptr)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_playerptr)
                        rdlong r0, r0

                        movd   :code_d, #:player_data
                        'mov   r1, #32  ' :player_data_end-:player_data
                        mov    r1, #:player_data_end
                        sub    r1, #:player_data

:code_d                 wrlong 0, r0
                        add    r0, #4
                        add    :code_d, :k_d0
                        djnz   r1, #:code_d
                        
                        jmp   #__loader_return

:k_d0                   long                    1<<9

:player_data            long                    1, 16, 16, 0, DIR_RIGHT, 6, 0, 0, 384 << 16, 6, 0, 0, 0, 0, 0, 0
                        long                    1, 208, 176, 0, DIR_LEFT, 6, 0, 0, 384 << 16, 6, 0, 0, 0, 0, 0, 0
                        long                    1, 208, 16, 0, DIR_DOWN, 6, 0, 0, 384 << 16, 6, 0, 0, 0, 0, 0, 0
                        long                    1, 16, 176, 0, DIR_UP, 6, 0, 0, 384 << 16, 6, 0, 0, 0, 0, 0, 0
:player_data_end

INITPLAYERS_END

' /////////////////////////////////////////////////////////////////////////////
' PROCESSPLAYERS //////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        org
PROCESSPLAYERS_START                     

                        mov    r1, #0

                        ' r0 = @player
                        mov    r0, #(_memstart+@g_playerptr)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_playerptr)
                        rdlong r0, r0

                        mov    :playersalive, #0
:loop
' r0: @player[0....n] 
' r1: 0...n (player index)

                        mov    r3, r0
                        add    r3, #PLAYER_STATUS*4
                        rdlong r2, r3
                        cmp    r2, #1           wz      ' PLAYER_STATUS == 1 (alive and kicking), 2+ death sequence, 0 dead.
        if_nz           jmp    #:continue


                        ' decrement invincibility if you have it.
                        mov    r3, r0
                        add    r3, #PLAYER_INVINCIBLE*4
                        rdlong r2, r3
                        cmp    r2, #0           wz
        if_nz           sub    r2, #1             
                        wrlong r2, r3           


                        mov    :aliveidx, r1            ' when one player is alive we can use this to quickly reference the player that's alive
                        add    :playersalive, #1
                        ' Map controller[r1] -> button[r1]
                        
                        ' r2 = @controller
                        mov    r2, #(_memstart+@g_controllerptr)>>9
                        shl    r2, #9
                        or     r2, #(_memstart+@g_controllerptr)
                        rdlong r2, r2
                        mov    r3, r1
                        shl    r3, #2
                        add    r2, r3           
                        rdlong r2, r2           ' r2 = controller[r1]


                        mov    r3, r0
                        add    r3, #PLAYER_BUTTON*4
                        rdlong r4, r3           ' r4 = player[r1].button
                        wrlong r2, r3           ' player[r1].button = r2

                        mov    r3, r0
                        add    r3, #PLAYER_BUTTONOLD*4
                        wrlong r4, r3           ' player[r1].buttonold = r4

                        ' get x,y position
                        mov    r2, r0
                        add    r2, #PLAYER_X*4
                        rdlong :x, r2
                        add    r2, #4
                        rdlong :y, r2

                        mov    :flamehitflag, #0

                        ' Process movement code a number of times depending on the rate/tick
                        mov    r2, r0
                        add    r2, #PLAYER_TICK*4 ' [RATE:16 | TICK:16]
                        rdlong :tick, r2
                        mov    :rate, :tick
                        shl    :tick, #16       
                        shr    :tick, #16       ' :tick = [0:16 | TICK:16]
                        shr    :rate, #16       ' :rate = [0:16 | RATE:16]
                        
                        add    :tick, :rate

:ittr                   
                        cmpsub :tick, #256      wc      ' C = :tick >= 256
        if_nc           jmp    #:end_ittr
                        
                        ' get x,y position
                        mov    r2, r0
                        add    r2, #PLAYER_X*4
                        rdlong :x, r2
                        add    r2, #4
                        rdlong :y, r2

                        ' Set DIR based on button[r1]
                        
                        mov    r3, r0
                        add    r3, #PLAYER_BUTTON*4
                        rdlong r2, r3           ' r2 = player[r1].button

                        mov    r5, r0
                        add    r5, #PLAYER_DIR*4
                        rdlong r4, r5           ' r4 = player[r1].dir 'old_dir' (incase we need to continue going in the same dir)

                        
                        mov    r3, r4           
                        'xor   r3, #DIR_H               ' Opposite Priority (De-rem if you prefer Default Priority)
                        
                        test   r3, #DIR_H       wc      ' If HORIZ? give Horiz priority. (Horiz bitmask just 1 bit so C = parity = the bit)
                        mov r3, #255 ' no dir.                        

        if_c            jmp    #:keyvert

                        test   r2, #KEY_LEFT    wz
        if_nz           mov    r3, #DIR_LEFT
                        test   r2, #KEY_RIGHT   wz
        if_nz           mov    r3, #DIR_RIGHT
:keyvert
                        test   r2, #KEY_UP      wz
        if_nz           mov    r3, #DIR_UP
                        test   r2, #KEY_DOWN    wz
        if_nz           mov    r3, #DIR_DOWN

        if_c            test   r2, #KEY_LEFT    wz
        if_nz_and_c     mov    r3, #DIR_LEFT
        if_c            test   r2, #KEY_RIGHT   wz
        if_nz_and_c     mov    r3, #DIR_RIGHT


                        cmp    r3, #255         wz
        if_nz           jmp    #:move_player

                        ' animate anim[r1] = 0
                        mov    r2, r0
                        add    r2, #PLAYER_ANIM*4
                        mov    r3, #16-1        ' right next to first step anim.
                        wrlong r3, r2
                                     
                        jmp    #:no_move

:move_player                      
                        ' a direction key pressed (r3: DIR_UP/DOWN/LEFT/RIGHT)

                        ' lock to grid-rail movement w/ some tolerance.
                        
                        test    r3,#DIR_H       wz      ' HORIZ?
        if_z            jmp     #:vert
        
                        test    :y,#%1100       wc      ' offsets 0..3 and 12..15 are passable.
        if_c            mov     r3,r4           ' dir = old_dir
                        test    :y, #%1111      wz
        if_z            jmp     #:horizvertdone
        if_nc           test    :y, #%1000      wz
        if_nc_and_z     sub     :y, #1
        if_nc_and_nz    add     :y, #1
                        jmp     #:horizvertdone
:vert
                        test    :x,#%1100       wc
        if_c            mov     r3,r4           ' dir = old_dir
                        test    :x, #%1111      wz
        if_z            jmp     #:horizvertdone
        if_nc           test    :x, #%1000      wz
        if_nc_and_z     sub     :x, #1
        if_nc_and_nz    add     :x, #1
:horizvertdone


                        ' update direction
                        wrlong  r3, r5          ' player[r1].dir = r3
                                

                        ' get current position's cell offset (tzo) (the center position of you (8,8) , i.e. same place you drop bombs, and collect things etc.)
                        mov    :tx, :x
                        mov    :ty, :y

                        add    :tx, #8
                        add    :ty, #8
                        
                        shr    :tx, #4
                        shr    :ty, #4

                        shl    :ty, #MAP_WIDTHS
                        add    :ty, :tx
                        mov    :tzo, :ty                ' get cell offset in :tz                        
                        
                        ' set vector                        
                        mov    :dx, #0
                        mov    :dy, #0

                        ' set test point.
                        mov    :tx, :x
                        mov    :ty, :y

                        cmp    r3, #DIR_UP      wz
        if_z            neg    :dy, #1
        if_z            add    :tx, #8
        if_z            sub    :ty, #1
                        cmp    r3, #DIR_DOWN    wz
        if_z            mov    :dy, #1
        if_z            add    :tx, #8
        if_z            add    :ty, #16
                        cmp    r3, #DIR_LEFT    wz
        if_z            neg    :dx, #1
        if_z            sub    :tx, #1
        if_z            add    :ty, #8
                        cmp    r3, #DIR_RIGHT   wz
        if_z            mov    :dx, #1
        if_z            add    :tx, #16
        if_z            add    :ty, #8                        

                        jmpret :getmapcell_ret, #:getmapcell                    ' tz contains cell offset of desired square

                        cmp    :tzo, :tz        wz                              ' if moving into same cell as you're already in, then assume traversable.
        if_nz           test   :tc, #MAP_SOLID  wz                                                
                        ' move x,y position
        if_z            add    :x, :dx
        if_z            add    :y, :dy

                        ' set new x,y position
                        mov    r2, r0
                        add    r2, #PLAYER_X*4
                        wrlong :x, r2
                        add    r2, #4
                        wrlong :y, r2

                        ' animate anim[r1]+=1
                        mov    r2, r0
                        add    r2, #PLAYER_ANIM*4
                        rdlong r3, r2
                        add    r3, #1
                        wrlong r3, r2                        
                        
:no_move


                        jmp    #:ittr
:end_ittr

                        ' update itteration phase.
                        
                        mov    r2, r0
                        add    r2, #PLAYER_TICK*4

                        shl    :rate, #16
                        or     :rate, :tick
                        wrlong :rate, r2        ' [RATE:16 | TICK:16]

                        ' Check if we're touching a flame.

                        mov    :tx, :x
                        mov    :ty, :y

                        add    :tx, #8
                        add    :ty, #8

                        jmpret :getfmapcell_ret, #:getfmapcell

                        cmp    :tc, #0          wz
        if_nz           mov    :flamehitflag, #1 ' LOL       
                        
                        ' Drop Bomb?

                        mov    r3, r0
                        add    r3, #PLAYER_BUTTON*4
                        rdlong r2, r3           ' r2 = player[r1].button

                        mov    r5, r0
                        add    r5, #PLAYER_BUTTONOLD*4
                        rdlong r4, r5           ' r4 = player[r1].dir 'old_dir' (incase we need to continue going in the same dir)

                        test   r2, #KEY_A       wz      ' nz = A button state
                        test   r4, #KEY_A       wc      ' c = previous A button state
        if_nz_and_nc    jmpret :drop_bomb_ret, #:drop_bomb

                        cmp    :flamehitflag, #0 wz     ' Hmmm. Did somebody just get burnt?
        if_nz           jmpret :flamehit_ret, #:flamehit

:continue

                        add    r0, #PLAYER_SIZE*4
                        add    r1, #1
                        cmp    r1, #4           wz
        if_nz           jmp    #:loop

                        ' update some gamestates

                        ' r0 = @gamestate
                        mov    r0, #(_memstart+@g_gamestate)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_gamestate)
                        rdlong r0, r0
                        add    r0, #GAMESTATE_ALIVE*4
                        wrlong :playersalive, r0
                        
                        cmp    :playersalive, #1        wz                      ' 1 player alive - make him invincible.
        if_nz           jmp    #:skip_invinci

                        ' Set invincibility to -1 (effectively infinite).
                        ' r0 = @player
                        mov    r0, #(_memstart+@g_playerptr)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_playerptr)
                        rdlong r0, r0

                        mov    r3, :aliveidx
                        shl    r3, #6                                           ' PLAYER_SIZE*4 = 64 Caution !!!                               
                        add    r3, r0
                        add    r3, #PLAYER_INVINCIBLE*4                    
                        rdlong r2, r3                   wz                      ' invinci switched on?
        if_z            neg    r2, #1
        if_z            wrlong r2, r3             

:skip_invinci
                        
                        jmp   #__loader_return

:drop_bomb
                        mov    r3, r0
                        add    r3, #PLAYER_BOMBS*4
                        rdlong r2, r3           wz ' r2 = player[r1].bombs
        if_z            jmp   #:dontdrop

                        ' plant bomb
                        
                        mov    :tx, :x
                        mov    :ty, :y

                        add    :tx, #8
                        add    :ty, #8

                        shr    :tx, #4
                        shr    :ty, #4

                        shl    :ty, #MAP_WIDTHS
                        add    :ty, :tx

                        ' :tx = @lmap
                        mov    :tx, #(_memstart+@g_lmap)>>9
                        shl    :tx, #9
                        or     :tx, #(_memstart+@g_lmap)
                        rdlong :tx, :tx
                        add    :tx, :ty

                        ' check if square already has something solid.
                        rdbyte :tc, :tx
                        test   :tc, #MAP_SOLID          wz
        if_nz           jmp    #:dontdrop       ' a bomb/solid on this square
                                    
                        
                        mov    :tc, #MAP_BOMB+10
                        wrbyte :tc, :tx

                        ' extended map: bomb tick
                        mov    :tc, #127-16     ' roughly 2 seconds

                        ' :tx = @emap
                        mov    :tx, #(_memstart+@g_emap)>>9
                        shl    :tx, #9
                        or     :tx, #(_memstart+@g_emap)
                        rdlong :tx, :tx
                        add    :tx, :ty

                        wrbyte :tc, :tx

                        ' owner map: r1 (player index)

                        ' :tx = @emap
                        mov    :tx, #(_memstart+@g_omap)>>9
                        shl    :tx, #9
                        or     :tx, #(_memstart+@g_omap)
                        rdlong :tx, :tx
                        add    :tx, :ty

                        wrbyte r1, :tx
                        
                        sub    r2, #1
                        wrlong r2, r3             ' player[r1].bombs--
                        
:dontdrop

:drop_bomb_ret          ret

:getmapcell

                        shr    :tx, #4
                        shr    :ty, #4

                        shl    :ty, #MAP_WIDTHS
                        add    :ty, :tx
                        mov    :tz, :ty                 ' get cell offset in :tz

                        ' :tx = @lmap
                        mov    :tx, #(_memstart+@g_lmap)>>9
                        shl    :tx, #9
                        or     :tx, #(_memstart+@g_lmap)
                        rdlong :tx, :tx
                        add    :tx, :ty

                        rdbyte :tc, :tx

:getmapcell_ret         ret


:getfmapcell

                        shr    :tx, #4
                        shr    :ty, #4

                        shl    :ty, #MAP_WIDTHS
                        add    :ty, :tx
                        mov    :tz, :ty                 ' get cell offset in :tz

                        ' :tx = @fmap
                        mov    :tx, #(_memstart+@g_fmap)>>9
                        shl    :tx, #9
                        or     :tx, #(_memstart+@g_fmap)
                        rdlong :tx, :tx
                        add    :tx, :ty

                        rdbyte :tc, :tx

:getfmapcell_ret        ret

:flamehit

                        mov    r3, r0
                        add    r3, #PLAYER_INVINCIBLE*4                    
                        rdlong r2, r3           wz
        if_nz           jmp    #:skip_flamehitkill

                        ' Just vanish him for now.
                        mov    r3, r0
                        add    r3, #PLAYER_STATUS*4
                        mov    r2, #0
                        wrlong r2, r3
:skip_flamehitkill

:flamehit_ret           ret

:tzo                    long                    $0
:tz                     long                    $0
:tx                     long                    $0
:ty                     long                    $0
:tc                     long                    $0
:x                      long                    $0
:y                      long                    $0
:dx                     long                    $0
:dy                     long                    $0
:tick                   long                    $0
:rate                   long                    $0
:flamehitflag           long                    $0
:playersalive           long                    $0
:aliveidx               long                    $0

PROCESSPLAYERS_END

' /////////////////////////////////////////////////////////////////////////////
' DRAWPLAYERS /////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
                        
                        org
DRAWPLAYERS_START

                        mov    :t0, #4

                        ' :t3 = @player
                        mov    :t3, #(_memstart+@g_playerptr)>>9
                        shl    :t3, #9
                        or     :t3, #(_memstart+@g_playerptr)
                        rdlong :t3, :t3

:loop

                        mov    :t2,:t3
                        
                        rdlong :t1,:t2                  ' STATUS
                        cmp    :t1, #0          wz
        if_z            jmp    #:skip

                        mov    r0, :t2
                        add    r0, #PLAYER_INVINCIBLE*4
                        rdlong r0, r0           wz
        if_z            jmp    #:no_invinci
        
                        test   r0, #1           wz      ' make it flash
        if_z            jmp    #:skip

:no_invinci

                        add    :t2, #4                  ' X
                        rdlong r0, :t2
                        
                        add    :t2, #4                  ' Y
                        rdlong r1, :t2

                        add    :t2, #4                  ' ANIM - 0...63 [0..15:0,16..31:1,32..47:0,48..63:2..]
                        rdlong r2, :t2

                        shr    r2, #4
                        and    r2, #3                   ' wrap over 0..3
                        
                        cmp    r2, #2           wz      ' 32..47 => 0
        if_z            mov    r2, #0
                        cmp    r2, #3           wz      ' 48..63 => 2
        if_z            mov    r2, #2
                        shl    r2, #4                   ' X: offset to anim sprite (i.e. 0, 16, or 32)
                        

                        add    :t2, #4                  ' DIR
                        rdlong r4, :t2
                        shl    r4, #3                   ' r4 = DIR*8
                        mov    r3, r4                   ' r3 = r4
                        add    r3, r4                   ' r3 = 2*r4
                        add    r3, r4                   ' r3 = 3*r4 (DIR*24)
                        add    r3, #32                  ' Y: offset to dir sprite (i.e. 32, 48, 64, or 80)
                        
                        call   #draw_sprite

:skip
                        add    :t3, #PLAYER_SIZE*4
                        djnz   :t0, #:loop

{
' DEBUG Frame load
                        ' 1 Reference
                        mov    r1, #1                   ' Y
                        mov    r0, #0                   ' X
                        mov    r2, #32                  ' Source X
                        mov    r3, #16                  ' Source Y
                        movs   draw_sprite_h, #16-1     ' H
                        
                        call   #draw_sprite

                        ' Scanline Reference
                        mov    r0, #(_memstart+@g_copptr)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_copptr)
                        rdlong r0, r0
                        add    r0, #h_cop_status*4
                        rdlong r1, r0                   ' Y
                        mov    r0, #8                   ' X
                        mov    r2, #32                  ' Source X
                        mov    r3, #16                  ' Source Y
                        movs   draw_sprite_h, #16-1     ' H
                        call   #draw_sprite
' END DEBUG Frame load
}

                        jmp   #__loader_return
                        
:t0                     long                    $0
:t1                     long                    $0
:t2                     long                    $0
:t3                     long                    $0

draw_sprite                        

                        ' r6 = @cop_obj[i] where i is the sprite #.
                        mov    r7, #(_memstart+@g_objptr)>>9
                        shl    r7, #9
                        or     r7, #(_memstart+@g_objptr)
                        rdlong r6, r7

                        ' X                        
                        add    r0, #MAP_OFFX
                        wrlong r0, r6
                        add    r6, #4

                        ' Y
                        add    r1, #MAP_OFFY+16-8
                        wrlong r1, r6
                        add    r6, #4

                        ' W
draw_sprite_w           mov    r5, #(16+3)/4
                        wrlong r5, r6
                        add    r6, #4

                        ' H
draw_sprite_h           mov    r5, #24-1
                        wrlong r5, r6
                        add    r6, #4

                        ' I
                        shl    r3, #7
                        add    r3, r2
                        
                        mov    r2, #(_memstart+@g_vramptr)>>9
                        shl    r2, #9
                        or     r2, #(_memstart+@g_vramptr)
                        rdlong r2, r2
                        add    r2, r3                        
                        wrlong r2, r6
                        add    r6, #4
                        
                        ' move obj pointer along to next obj.
                        wrlong r6, r7                        

draw_sprite_ret         ret

DRAWPLAYERS_END


{
:inf                    jmp    #:inf
_k1                     long                    $7ffc


                        mov    g_copptr, gameinit_par0
                        mov    g_controller, gameinit_par1
                        
                        ' setup g_cop_obj
                        mov    g_cop_obj, g_copptr
                        add    g_cop_obj, #h_cop_obj*4

                        ' setup g_cop_tile
                        mov    g_cop_tile, g_copptr
                        add    g_cop_tile, #h_cop_tile*4

                        ' setup cop_pany (-8)
                        mov    r0, g_copptr
                        add    r0, #h_cop_pany*4
                        neg    r1, #8
                        wrlong r1, r0

                        ' setup cop_bgcolor
                        mov    r0, g_copptr
                        add    r0, #h_cop_bgcolor*4
                        wrlong bgcolor, r0

                        ' start game loop                        
'                       mov    __loader_page, pagetable_GAMELOOP
'                       mov    __loader_size, #(GAMELOOP_END-GAMELOOP_START) '>>2
'                       mov    __loader_jmp, #GAMELOOP_START

'                       mov    __loader_page, pagetable_GAMEINIT
'                       mov    __loader_size, #(GAMEINIT_END-GAMEINIT_START) '>>2
'                       mov    __loader_jmp, #GAMEINIT_START

'                       jmp    #__loader_execute
                        mov    r7, #128
:loop

                        call   #cop_newframe

                        ' get controller #0
                        mov    r0, g_controller
                        add    r0, #0
                        rdlong r0, r0
                        
                        test   r0, #KEY_RIGHT   wz
        if_nz           add    r7, #1
                        test   r0, #KEY_LEFT    wz
        if_nz           sub    r7, #1
                        test   r0, #KEY_A       wz
        if_nz           jmp    #bootnextcog
                        
                        mov    r0, r7 '#16
                        mov    r1, #16
                        add    r1, #8
                        mov    r2, #(16+3)/4
                        mov    r3, #24-1
                        mov    r4, #0
                        mov    r5, #32
                        call   #cop_sprite


                        mov    r0, #208
                        mov    r1, #16
                        and    r1, #255
                        add    r1, #8
                        mov    r2, #(16+3)/4
                        mov    r3, #24-1
                        mov    r4, #0
                        mov    r5, #32
                        call   #cop_sprite

                       
                        call   #cop_waitvsync
                        
                        jmp #:loop

bootnextcog             'jmp   #GAMEINIT_START
                        ' start game loop                        
'                       mov    __loader_page, pagetable_GAMELOOP
'                       mov    __loader_size, #(GAMELOOP_END-GAMELOOP_START) '>>2
'                       mov    __loader_jmp, #GAMELOOP_START

                        mov    r0, #511
                        wrlong r0, scratchpad
                        'mov   __loader_page, pagetable_GAMEINIT
                        'mov   __loader_size, #(GAMEINIT_END-GAMEINIT_START) '>>2
                        'mov   __loader_jmp, #GAMEINIT_START
                        'jmp   #__loader_execute
:loop                   jmp    #:loop

scratchpad              long                    $6000

cop_newframe

' sets all OBJ's Y positions to offscreen.
                        mov    r1, #255                                         ' Y = 255
                        mov    g_cop_obj, g_copptr
                        add    g_cop_obj, #h_cop_obj*4                          ' offset to OBJ buffer.

                        mov    r0, g_cop_obj
                        add    r0, #OBJ_OFFSET_Y*4                              ' offset to Y attribute.

                        mov    r2, #obj_n                                       ' do all OBJ's
:loop
                        wrlong r1, r0
                        add    r0, #obj_size*4
                        djnz   r2, #:loop
                        
cop_newframe_ret        ret

cop_waitvsync

' waits for end of vertical sync pulse
                        mov    r1, g_copptr
                        add    r1, #h_cop_status*4
:loop1                  rdlong r0, r1                   wz
        if_nz           jmp    #:loop1
        
:loop2                  rdlong r0, r1                   wz
        if_z            jmp    #:loop2

cop_waitvsync_ret       ret

cop_sprite

' adds a sprite to the list and moves the cop_obj pointer along
                        add    r0, #MAP_OFFX
                        add    r1, #MAP_OFFY
                        
                        mov    r6, g_cop_obj
                        wrlong r0, r6           ' X
                        add    r6, #4
                        wrlong r1, r6           ' Y
                        add    r6, #4
                        wrlong r2, r6           ' W
                        add    r6, #4
                        wrlong r3, r6           ' H
                        add    r6, #4


                        shl    r5, #7           ' offy * 128 + offx
                        add    r5, r4
                        mov    r3, g_copptr
                        add    r3, #h_cop_vram*4
                        rdlong r3, r3
                        add    r5, r3
                        
                        wrlong r5, r6           ' I
                        
                        add    g_cop_obj, #obj_size*4

cop_sprite_ret          ret


io_initcontroller       or     dira, #%0011000          ' 3/4 OUTPUT (Clock/Latch)
                        andn   dira, #%1100000          ' 5/6 INPUT (DATA0/DATA1)

io_initcontroller_ret   ret

io_updatecontroller

' probes nes controllers, stores result in r0/r1

                        or     dira, #%00011000 ' 3/4 OUTPUT (Clock/Latch)
                        andn   dira, #%01100000         ' 5/6 INPUT (DATA0/DATA1)

                        ' setup time factor to 8us
                        mov r4, #8
                        mov r3, #80
                        shl r3, #3                      ' r3 = 8us (80 * 8)

                        mov r2, cnt
                        add r2, r3
                                                                                                           
                        or outa, #%00010000             ' P4 (SH/LATCHn = 0) 'SHIFT'
:loop
                        ' take bit #0
                        mov   r2, cnt
                        add   r2, #511
                        waitcnt r2, #0 'r3              ' 8us                                                                      
                        
                        shl r0, #1
                        shl r1, #1

                        test ina, #%00100000    wz      ' P5 (JOY0 DATA)
            if_nz       or  r0, #1
                        test ina, #%01000000    wz      ' P6 (JOY1 DATA)
            if_nz       or  r1, #1

                        or outa, #%00001000             ' P3 (CLK = 1)

                        mov   r2, cnt
                        add   r2, #511                        
                        waitcnt r2, #0 'r3              ' 8us
                        
                        andn outa, #%00001000           ' P3 (CLK = 0)
                        
                        djnz r4, #:loop

                        ' continue latching until next frame.
                        andn outa, #%00010000           ' P4 (SH/LATCHn = 0) 'LATCH'
 
io_updatecontroller_ret ret
}

{

                        ' setup cop_pany
                        'mov   :r0, g_copptr
                        'add   :r0, #h_cop_pany*4
                        'neg   :r1, #112
                        'wrlong :r1, :r0
                        mov    :r0, #$fa
                        wrlong :r0, :_k1

                        jmp     #:loop                            
:_k1                    long                    $7ffc

:r0                     res                     1
:r1                     res                     1
:r2                     res                     1
:r3                     res                     1
:r4                     res                     1
:r5                     res                     1
:r6                     res                     1
:r7                     res                     1

GAMELOOP_END
}

' /////////////////////////////////////////////////////////////////////////////
' GLOBAL REGISTERS ////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        org                     $1e0

r0                      long                    $0
r1                      long                    $0
r2                      long                    $0
r3                      long                    $0
r4                      long                    $0
r5                      long                    $0
r6                      long                    $0
r7                      long                    $0

' /////////////////////////////////////////////////////////////////////////////
' LOADER REGISTERS ////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        org                     $1c0                        
__loader_return         res                     7
__loader_call           res                     6
__loader_execute

                        org                     $1e0                            ' general registers 1e0-1ef
__loader_registers
__g0                    res                     1 ' g0..g7 : Global COG Registers
__g1                    res                     1
__g2                    res                     1
__g3                    res                     1
__g4                    res                     1
__g5                    res                     1
__g6                    res                     1
__g7                    res                     1

__t0                    res                     1
__t1                    res                     1
__t2                    res                     1
__loader_ret            res                     1
__loader_stack          res                     1
__loader_page           res                     1
__loader_size           res                     1
__loader_jmp            res                     1

' //////////////////////////////////////////////////////////////////////////
' HUB VARIABLES ////////////////////////////////////////////////////////////
' //////////////////////////////////////////////////////////////////////////