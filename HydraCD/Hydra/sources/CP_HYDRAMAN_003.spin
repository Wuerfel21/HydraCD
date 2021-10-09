' //////////////////////////////////////////////////////////////////////
' HydraMan                              
' AUTHOR: Colin Phillips
' LAST MODIFIED: 1.11.06
' VERSION 0.3
'
' DESCRIPTION:
' HydraMan - Multiplayer bomb blasting game :-)
' Go to line 1833 (INITPLAYERS section) if you wish to modify the initial settings for the players
'
' CONTROLS:
' Player 1 - Controller 0 Move: D-Pad, Drop bomb: (A), Punch bomb: (B)
' Player 2 - Controller 1 Move: D-Pad, Drop bomb: (A), Punch bomb: (B)
' Player 3 - Keyboard Move: WASD , L-Ctrl Drop bomb: (A), L-Shift Punch bomb: (B)
' Player 4 - Keyboard Move: Cursor Keys , R-Ctrl Drop bomb: (A), R-Shift Punch bomb: (B)
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x          ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000      ' set frequency to 10 MHZ plus some error    
  _stack   = 128                    ' stack
  _memstart = $10                   ' memory starts $10 in!!! (this took 2 headaches to figure out)
  
' COP HEADER ------------------------------------------------------------------

  obj_n         = 24                ' Number of Objects
  obj_size      = 6                 ' registers per object.
  obj_total_size = obj_n*obj_size   ' Total Number of registers (LONGS)
  OBJ_OFFSET_X  = 0
  OBJ_OFFSET_Y  = 1
  OBJ_OFFSET_W  = 2
  OBJ_OFFSET_H  = 3
  OBJ_OFFSET_I  = 4
  OBJ_OFFSET_M  = 5

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
  PLAYER_COLOR = 11
  PLAYER_VY = 12
  PLAYER_WEAPONS = 13
  PLAYER_STATE = 14                 ' encode punch state in here (lasts for a dozen or so frames)
  '
  '
  '
  ' PLAYER_???? = 15
  PLAYER_SIZE = 16

  MAX_BOMBS = 32
  BOMB_STATUS = 0               ' can encode direction (up/down/left/right) + bomb sequence in here.
  BOMB_X = 1
  BOMB_Y = 2
  BOMB_EXT = 3                  ' can encode bounce factor in here.
  BOMB_OWNER = 4
  BOMB_RESV0 = 5
  BOMB_RESV1 = 6
  BOMB_RESV2 = 7
  BOMB_SIZE = 8

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

  ITEM_BOMB     = 0
  ITEM_FLAME    = 1
  ITEM_SKATES   = 2
  ITEM_GLOVE    = 3
  ITEM_BOOTS    = 4

  WEAPON_GLOVE  = 1
  WEAPON_BOOTS  = 2

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
byte bomb[MAX_BOMBS*BOMB_SIZE]

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
      controller[2]|=KEY_B
    if(key.keystate($F2)) ' Ctrl-L
      controller[2]|=KEY_A
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
      controller[3]|=KEY_B
    if(key.keystate($F3)) ' Ctrl-R
      controller[3]|=KEY_A

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
g_frame                 LONG                    $0
g_bombidx               LONG                    $0

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
                        
                        mov    r0, #(_memstart+@g_frame)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_frame)
                        mov    r1, #0
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
                        or     __loader_page, #(_memstart+@INITMAP_START)  & $1FF             
                        mov    __loader_size, #(INITMAP_END-INITMAP_START)
                        mov    __loader_jmp, #INITMAP_START
                        jmpret __loader_ret,#__loader_call

                        
                        ' === Execute Block of Code "INITBOMBS"
                        mov    __loader_page, #(_memstart+@INITBOMBS_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@INITBOMBS_START)  & $1FF           
                        mov    __loader_size, #(INITBOMBS_END-INITBOMBS_START)
                        mov    __loader_jmp, #INITBOMBS_START
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

' wait for end of visible screen

                        mov    r1, r0
                        add    r1, #h_cop_status*4
:vsyncloop1             rdlong r2, r1                   wz
        if_nz           jmp    #:vsyncloop1

' perform graphics changes here (i.e. tile bitmap alterations) (vsync + top overscan - i.e. 18 + 10 scanlines (just under 1.8ms)

                        ' === Execute Block of Code "EFFECTS"
                        mov    __loader_page, #(_memstart+@EFFECTS_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@EFFECTS_START)  & $1FF             
                        mov    __loader_size, #(EFFECTS_END-EFFECTS_START)
                        mov    __loader_jmp, #EFFECTS_START
                        jmpret __loader_ret,#__loader_call                        

' wait for end of vsync

                        ' r0 = @cop_status
                        mov    r0, #(_memstart+@g_copptr)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_copptr)
                        rdlong r0, r0

                        mov    r1, r0
                        add    r1, #h_cop_status*4        
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
                        or     __loader_page, #(_memstart+@PROCESSPLAYERS_START)  & $1FF      
                        mov    __loader_size, #(PROCESSPLAYERS_END-PROCESSPLAYERS_START)
                        mov    __loader_jmp, #PROCESSPLAYERS_START
                        jmpret __loader_ret,#__loader_call                        

                        ' === Execute Block of Code "PROCESSDEATHPLAYERS"
                        mov    __loader_page, #(_memstart+@PROCESSDEATHPLAYERS_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@PROCESSDEATHPLAYERS_START)  & $1FF 
                        mov    __loader_size, #(PROCESSDEATHPLAYERS_END-PROCESSDEATHPLAYERS_START)
                        mov    __loader_jmp, #PROCESSDEATHPLAYERS_START
                        jmpret __loader_ret,#__loader_call                        

                        ' === Execute Block of Code "PROCESSMAP"
                        mov    __loader_page, #(_memstart+@PROCESSMAP_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@PROCESSMAP_START)  & $1FF          
                        mov    __loader_size, #(PROCESSMAP_END-PROCESSMAP_START)
                        mov    __loader_jmp, #PROCESSMAP_START
                        jmpret __loader_ret,#__loader_call

                        ' === Execute Block of Code "PROCESSBOMBS"
                        mov    __loader_page, #(_memstart+@PROCESSBOMBS_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@PROCESSBOMBS_START)  & $1FF        
                        mov    __loader_size, #(PROCESSBOMBS_END-PROCESSBOMBS_START)
                        mov    __loader_jmp, #PROCESSBOMBS_START
                        jmpret __loader_ret,#__loader_call

' draw...

                        ' === Execute Block of Code "UPDATEMAP"
                        mov    __loader_page, #(_memstart+@UPDATEMAP_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@UPDATEMAP_START)  & $1FF           
                        mov    __loader_size, #(UPDATEMAP_END-UPDATEMAP_START)
                        mov    __loader_jmp, #UPDATEMAP_START
                        jmpret __loader_ret,#__loader_call                                   

                        ' === Execute Block of Code "DRAWPLAYERS"
                        mov    __loader_page, #(_memstart+@DRAWPLAYERS_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@DRAWPLAYERS_START)  & $1FF         
                        mov    __loader_size, #(DRAWPLAYERS_END-DRAWPLAYERS_START)
                        mov    __loader_jmp, #DRAWPLAYERS_START
                        jmpret __loader_ret,#__loader_call


                        ' === Execute Block of Code "DRAWBOMBS"
                        mov    __loader_page, #(_memstart+@DRAWBOMBS_START)>>9
                        shl    __loader_page, #9                     
                        or     __loader_page, #(_memstart+@DRAWBOMBS_START)  & $1FF           
                        mov    __loader_size, #(DRAWBOMBS_END-DRAWBOMBS_START)
                        mov    __loader_jmp, #DRAWBOMBS_START
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


                        mov    r0, #(_memstart+@g_frame)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_frame)
                        rdlong r1, r0
                        add    r1, #1
                        wrlong r1, r0

                        jmp       #:nextframe

GAMELOOP_END

' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' EFFECTS ENGINE //////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        org
EFFECTS_START


' Make the Items' borders alternate color.
                        mov    r0, #(_memstart+@g_frame)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_frame)
                        rdlong :frame, r0
                        
                        ' r0 = @cop_vram
                        mov    r0, #(_memstart+@g_vramptr)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_vramptr)
                        rdlong r0, r0

                        mov    :c, #$cb
                        test   :frame, #4       wz
        if_z            mov    :c, #$59
        
                        ' replicate 8-bit :c to whole 32-bit (4 pixels)
                        mov    :t, :c
                        shl    :c, #8
                        or     :c, :t
                        mov    :t, :c
                        shl    :c, #16
                        or     :c, :t
                        ' width/height
                        mov    :w, #16
                        mov    :h, #16

                        ' tile offset.
                        mov    :vram, r0

                        mov    r0, #6

                        
                        ' x/y
                        mov    :x, #64
                        mov    :y, #32

:rep_tile
                        jmpret :draw_rect_ret, #:draw_rect

                        add    :y, #16
                        djnz   r0, #:rep_tile
                        
                        {
                        ' pixel
                        mov    :tp, :y
                        shl    :tp, #7          ' y*128+x
                        add    :tp, :x
                        mov    :tp, #0
                        add    :tp, :vram       ' :tp = :vram + :y*128 + :x
                        wrbyte :c, :tp
                        }
                        jmp #__loader_return

:draw_rect
                        ' hollow rectangle
                        mov    :tp, :y
                        shl    :tp, #7          ' y*128+x
                        add    :tp, :x

                        add    :tp, :vram       ' :tp = :vram + :y*128 + :x

                        mov    :t, :w
                        shr    :t, #2
:rect_loop1
                        wrlong :c, :tp
                        add    :tp, #4
                        djnz   :t, #:rect_loop1


                        sub    :tp, :w
                        
                        mov    :t, :h
                        sub    :t, #1
:rect_loop2
                        wrbyte :c, :tp
                        add    :tp, :w
                        sub    :tp, #1
                        wrbyte :c, :tp
                        add    :tp, #128+1
                        sub    :tp, :w
                        djnz   :t, #:rect_loop2

                        mov    :t, :w
                        shr    :t, #2
:rect_loop3
                        wrlong :c, :tp
                        add    :tp, #4
                        djnz   :t, #:rect_loop3
                        
:draw_rect_ret          ret
                        
:vram                   long                    $0
:x                      long                    $0
:y                      long                    $0
:c                      long                    $0
:tp                     long                    $0
:w                      long                    $0
:h                      long                    $0
:t                      long                    $0
:frame                  long                    $0

EFFECTS_END

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
                        add    r4, :randadd
                        
                        mov    r5, r4
                        and    r5, #127
                        cmp    r5, #13          wc
        if_c            wrbyte r1, r3
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
                        mov    r3, #0
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

:randadd                long                    $1f58932d

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


                        mov    :randval, cnt
                        
                        mov    r4, #MAP_SIZE
:loop
                        ' Bomb Check //////////////////////
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
                        ' Flame Check /////////////////////
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

                        ' Item Destroy check //////////////

                        rdbyte r2, r0
                        shr    r2, #5
                        cmp    r2, #MAP_ITEM>>5 wz
        if_nz           jmp    #:not_item

                        ' Make exploded bricks tick down to 0. and then either vanish or turn into a collectable item.
                        rdbyte r2, r1           wz
        if_z            jmp    #:not_item
                        
                        sub    r2, #1           wz      ' r2==0?

                        wrbyte r2, r1
                        
        if_nz           jmp    #:update_item

                        mov    r2, #MAP_GROUND
                        wrbyte r2, r0
        
                        jmp    #:not_item

:update_item
                        ' Adjust Explosion animation based on time. 31...0 (1,0)
                        shr    r2, #4
                        and    r2, #1
                        xor    r2, #1                   ' 1,0 -> 0,1                                                                                           

                        add    r2, #MAP_ITEM+8
                        
                        wrbyte r2, r0                        

:not_item

                        ' Brick Check /////////////////////
                        rdbyte r2, r0
                        shr    r2, #5
                        cmp    r2, #MAP_BRICK>>5 wz
        if_nz           jmp    #:not_brick

                        ' Make exploded bricks tick down to 0. and then either vanish or turn into a collectable item.
                        rdbyte r2, r1           wz
        if_z            jmp    #:not_brick
                        
                        sub    r2, #1           wz      ' r2==0?

                        wrbyte r2, r1
                        
        if_nz           jmp    #:update_brick
        
                        mov    r2, #MAP_GROUND
                        wrbyte r2, r0
                        ' Check if brick has an item, if so give it.

                        mov    r2, :randval
                        shr    r2, #10                  ' cnt /= 1024 (work with a closer to 1sec number for the pseudo rand)
                        and    r2, #31
                        cmp    r2, #6           wc      ' 20% chance of getting an item.
        if_nc           jmp    #:not_brick

                        test   :randval, #%11   wc      ' carry = parity (bit 0 ^ bit 1)
                        rcr    :randval, #1

                        mov    r2, :randval
                        shr    r2, #15                  ' cnt /= 32768 (work with a closer to 1sec number for the pseudo rand)

                        ' give out 4 different items now
                        and    r2, #3           'wc     ' parity 3/0 (0) -> 0
'       if_nc           mov    r2, #0
        
                        add    r2, #MAP_ITEM
                        wrbyte r2, r0
                        
                        jmp    #:not_brick
                        
:update_brick
                        ' Adjust Brick animation based on time. 47...0 (2,1,0)
                        shr    r2, #4
                        and    r2, #3
                        xor    r2, #3                   ' 2,1,0 -> 1,2,3                                                                                       

                        add    r2, #MAP_BRICK+3
                        
                        wrbyte r2, r0
                        
:not_brick

                        test   :randval, #%11                           wc      ' carry = parity (bit 0 ^ bit 1)
                        rcr    :randval, #1
                        add    :randval, :randadd

                        add    r0, #1
                        add    r1, #1
                        add    r7, #1
                        djnz   r4, #:loop
                        
                        jmp #__loader_return

:randval                long                    $0
:randadd                long                    $1f58932d
                        
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
                        mov    r5, r2
                        shr    r5, #5
                        and    r2, #31 ' lower 5 bits are the tile image.

                        rdbyte r6, r7 ' r6 = emap[e]


                        cmp    r5, #MAP_ITEM>>5 wz
        if_z            add    r2, #:lut_tmapitem
        
                        ' Display Standard image for this tile.
        if_nz           add    r2, #:lut_tmap
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

:lut_tmapitem           LONG                    ($80*32)+$40
                        LONG                    ($80*48)+$40
                        LONG                    ($80*64)+$40
                        LONG                    ($80*80)+$40
                        LONG                    ($80*96)+$40
                        LONG                    ($80*112)+$40
                        LONG                    $0      'unused
                        LONG                    $0      'unused
                        LONG                    ($80*16)+$30
                        LONG                    ($80*16)+$40

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

' /////////////////////////////////////////////////////////////////////////////
' INITBOMBS ///////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
 
                        org
INITBOMBS_START

                        ' wipe out the bomb array
                        ' r0 = @g_bombptr
                        mov    r0, #(_memstart+@g_bombptr)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_bombptr)
                        rdlong r0, r0

                        mov    r1, #MAX_BOMBS*BOMB_SIZE
                        mov    r2, #0

:loop
                        wrbyte r2, r0
                        add    r0, #1
                        djnz   r1, #:loop                        

                        jmp #__loader_return
INITBOMBS_END             

' /////////////////////////////////////////////////////////////////////////////
' PROCESSBOMBS ////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        org
PROCESSBOMBS_START                       

                        ' PROCESS BOMBS ON MAP FIRST //////////////////////////
                        
                        ' r0 = @lmap
                        mov    r0, #(_memstart+@g_lmap)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_lmap)
                        rdlong r0, r0
                        mov    :lmap_base, r0

                        ' r1 = @emap
                        mov    r1, #(_memstart+@g_emap)>>9
                        shl    r1, #9
                        or     r1, #(_memstart+@g_emap)
                        rdlong r1, r1
                        mov    :emap_base, r1
                        
                        ' r3 = @omap
                        mov    r3, #(_memstart+@g_omap)>>9
                        shl    r3, #9
                        or     r3, #(_memstart+@g_omap)
                        rdlong r3, r3
                        mov    :omap_base, r3

                        ' r7 = @fmap
                        mov    r7, #(_memstart+@g_fmap)>>9
                        shl    r7, #9
                        or     r7, #(_memstart+@g_fmap)
                        rdlong r7, r7
                        mov    :fmap_base, r7

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

                        ' PROCESS BOMBS IN ARRAY NEXT /////////////////////////

                        mov    r0, #(_memstart+@g_bombptr)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_bombptr)
                        rdlong r0, r0
                                        
                        mov    r1, #MAX_BOMBS
:procloop

                        ' Check/Read
                        rdbyte r2, r0           wz
        if_z            add    r0, #BOMB_SIZE   ' (byte array - not long like most of the others)
        if_z            jmp    #:skip_bomb
                                                ' R2 = Dir/Initial Bounce (bbbbbb:dd)
                        add    r0, #1
                        rdbyte r3, r0           ' R3 = X
                        add    r0, #1
                        rdbyte r4, r0           ' R4 = Y
                        add    r0, #1
                        rdbyte r5, r0           ' R5 = EXT (time on bomb)
                        add    r0, #1
                        rdbyte :owner, r0       ' owner = BOMB_OWNER
                        add    r0, #1+3

                        ' Move bombs
                        mov    r6, r2

                        cmp    r2, #7           wc
        if_c            mov    :itter, #1               ' 1 itteration normal
        if_nc           mov    :itter, #2               ' 2 itterations initial bomb bounce.

:next_itter
             
                        and    r6, #3           ' Direction 0/1/2/3
                        cmp    r6, #DIR_UP      wz
        if_z            sub    r4, #1           wz
        if_z            mov    r4, #16*13
        
                        cmp    r6, #DIR_DOWN    wz
        if_z            add    r4, #1
        if_z            cmp    r4, #16*13       wz
        if_z            mov    r4, #0
        
                        cmp    r6, #DIR_LEFT    wz
        if_z            sub    r3, #1           wz
        if_z            mov    r3, #16*15
        
                        cmp    r6, #DIR_RIGHT   wz
        if_z            add    r3, #1
        if_z            cmp    r3, #16*15       wz
        if_z            mov    r3, #0

                        djnz   :itter, #:next_itter     ' multiple itterations if in the initial bomb bounce.                        

                        ' Check if Bombs are 16,16 aligned and if so check if map>>5 & flamemap are both 0. to land.
                        ' doesnt seem to need this. allow it (it's phased off too)
'                       test   r3, #15          wz
'       if_nz           jmp    #:skip_bombland
'                       test   r4, #15          wz
'       if_nz           jmp    #:skip_bombland

                        ' use :lmap_base / fmap_base

                        cmp    r2, #7           wc      
        if_nc           jmp    #:skip_bombland          ' still on the initial big bounce?
                        
                        mov    r7, r4
                        'sub   r7, #8           ' compensate for -8 offset                        
                        shr    r7, #4           
                        shl    r7, #MAP_WIDTHS  ' r7 = (Y/16) * MAP_WIDTH
                        mov    r6, r3
                        'sub   r6, #8           ' compensate for -8 offset
                        shr    r6, #4
                        add    r7, r6           ' r7+= X/16


                        mov    :t0, r7
                        mov    :t1, r7
                        mov    :t2, r7
                        add    r7, :emap_base
                        add    :t0, :lmap_base
                        add    :t1, :fmap_base
                        add    :t2, :omap_base
                        rdbyte r6, :t0          ' r6 = lmap[r7]
                        shr    r6, #5
                        cmp    r6, #MAP_GROUND>>5       wz                      ' ground?
        if_z            rdbyte r6, :t1                  wz                      ' && no flame?

                        
                        mov    r6, #MAP_BOMB+10
'                       mov    r2, #0           ' remove bomb entity.
'                       wrbyte r6, :t0          ' add bomb entity to the map
'                       wrbyte r5, r7           ' add time value to the extended map.
        if_z            mov    r2, #0           ' remove bomb entity.
        if_z            wrbyte r6, :t0          ' add bomb entity to the map
        if_z            wrbyte r5, r7           ' add time value to the extended map.
        if_z            wrbyte :owner, :t2

:skip_bombland

                        cmp    r2, #7           wc
        if_nc           sub    r2, #4           ' R2>=8. then tick down by 4.
                        ' Write Back
                        sub    r0, #8
                        wrbyte r2, r0           ' R2 = Dir/Own
                        add    r0, #1
                        wrbyte r3, r0           ' R3 = X
                        add    r0, #1
                        wrbyte r4, r0           ' R4 = Y
                        add    r0, #1
                        wrbyte r5, r0           ' R5 = EXT (time on bomb)
                        add    r0, #1+4                             

:skip_bomb                        
                        djnz   r1, #:procloop

                        
                        
                        jmp #__loader_return
:lmap_base              long                    $0
:emap_base              long                    $0
:fmap_base              long                    $0
:omap_base              long                    $0
:t0                     long                    $0
:t1                     long                    $0
:t2                     long                    $0
:owner                  long                    $0

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
                        test   r5, #MAP_ITEM    wc      ' Carry = ((r5&MAP_ITEM)!=0)
                        
        if_z_and_nc     jmp    #:continueflame
                        ' abort flame run. but also find out what we hit ;-)
                        shr    r5, #5           
                        cmp    r5, #MAP_BOMB>>5 wz
                        mov    r6, #6                   ' give a 6 frame (6/60 sec) propagation delay between flame->bomb's
        if_z            wrbyte r6, :ep

                        cmp    r5, #MAP_BRICK>>5 wz
                        mov    r6, #47
        if_z            wrbyte r6, :ep

                        cmp    r5, #MAP_ITEM>>5 wz
                        mov    r6, #31
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
:itter                  long                    $0

                        jmp #__loader_return
PROCESSBOMBS_END                         

' /////////////////////////////////////////////////////////////////////////////
' DRAWBOMBS ///////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

' bomb coords must be offsetted -8, -8 since we use bytes to encode the position
{
  g_bombptr := @bomb
byte bomb[MAX_BOMBS*BOMB_SIZE]
  MAX_BOMBS = 32
  BOMB_STATUS = 0               ' can encode direction (up/down/left/right) + owner in here.
  BOMB_X = 1
  BOMB_Y = 2
  BOMB_EXT = 3                  ' can encode bounce factor in here.
  BOMB_SIZE = 4
 }
'                       byte bomb[MAX_BOMBS*BOMB_SIZE]

                        org
DRAWBOMBS_START


                        mov    :tp, #(_memstart+@g_bombptr)>>9
                        shl    :tp, #9
                        or     :tp, #(_memstart+@g_bombptr)
                        rdlong :tp, :tp
                                        
                        mov    :tc, #MAX_BOMBS

                        mov    r2, #7*16
                        mov    r3, #0


                        shl    r3, #7
                        add    r3, r2

                        mov    r2, #(_memstart+@g_vramptr)>>9
                        shl    r2, #9
                        or     r2, #(_memstart+@g_vramptr)
                        rdlong r2, r2
                        add    r2, r3                        

:loop

                        rdbyte :t0, :tp         wz
        if_z            add    :tp, #BOMB_SIZE          ' (byte array - not long like most of the others)
        if_z            jmp    #:skip_bomb

                        add    :tp, #1
                        rdbyte r0, :tp
                        add    :tp, #1
                        rdbyte r1, :tp

                        add    :tp, #1
                        ' EXT unused

                        add    :tp, #1+4

                        cmp    :t0, #7          wc
        if_c            jmp    #:bouncey

                        ' initial bomb bounce need to use a sine table i think...
                        mov    :t1, :t0
                        shr    :t1, #2          ' :t1 24..1
                        
'                       cmpsub :t1, #12         wc                        
'       if_nc           neg    :t1, :t1
'                       sub    r1, :t1

                        ' 0..12 and 24-12 mapping to 0 - 90' (0-4096)
                        
                        cmp    :t1, #12         wc
        if_nc           neg    :t1, :t1
        if_nc           add    :t1, #24
        
                        shl    :t1, #8                  ' *=256 
                        or     :t1, :sine_lut
                        rdword :t1, :t1
                        shr    :t1, #12                 ' 64k -> 16
                        sub    r1, :t1                        

                        jmp    #:drawbombspr
:bouncey                
                        mov    r7, r0
                        add    r7, r1
                        and    r7, #7                   ' bouncey = (X+Y)&7 (xored by 7 when >=4) i.e. /\/\/\/\
                        test   r7, #4           wz
        if_nz           xor    r7, #7
                        sub    r1, r7

:drawbombspr
                        
                        jmpret :draw_sprite_ret, #:draw_sprite

:skip_bomb                        
                        djnz   :tc, #:loop
                        
                        jmp #__loader_return

:tp                     long                    $0
:tc                     long                    $0
:t0                     long                    $0
:t1                     long                    $0
:sine_lut               long                    $E000

:draw_sprite                       

                        ' r6 = @cop_obj[i] where i is the sprite #.
                        mov    r7, #(_memstart+@g_objptr)>>9
                        shl    r7, #9
                        or     r7, #(_memstart+@g_objptr)
                        rdlong r6, r7

                        ' X                        
                        add    r0, #MAP_OFFX-8
                        wrlong r0, r6
                        add    r6, #4

                        ' Y
                        add    r1, #MAP_OFFY+16-8
                        wrlong r1, r6
                        add    r6, #4

                        ' W
:draw_sprite_w          mov    r5, #(16+3)/4
                        wrlong r5, r6
                        add    r6, #4

                        ' H
:draw_sprite_h          mov    r5, #16-1
                        wrlong r5, r6
                        add    r6, #4

                        ' I
                        wrlong r2, r6
                        add    r6, #4

                        ' Color Modifier
                        
                        wrlong :draw_sprite_mod, r6
                        add    r6, #4
                        
                        ' move obj pointer along to next obj.
                        wrlong r6, r7                        

:draw_sprite_ret        ret

:draw_sprite_mod        long                    $00000000

DRAWBOMBS_END             


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

:player_data            long                    1, 16, 16, 0, DIR_RIGHT, 1, 0, 0, 256 << 16, 2, 0, $00000020, 0, 0, 0, 0
                        long                    1, 208, 176, 0, DIR_LEFT, 1, 0, 0, 256 << 16, 2, 0, $00000060, 0, 0, 0, 0            
                        long                    1, 208, 16, 0, DIR_DOWN, 1, 0, 0, 256 << 16, 2, 0, $000000a0, 0, 0, 0, 0
                        long                    1, 16, 176, 0, DIR_UP, 1, 0, 0, 256 << 16, 2, 0, $000000e0, 0, 0, 0, 0
:player_data_end
{
' HYPER Edition :-) 
:player_data            long                    1, 16, 16, 0, DIR_RIGHT, 6, 0, 0, 384 << 16, 10, 0, $00000020, 0, WEAPON_GLOVE, 0, 0
                        long                    1, 208, 176, 0, DIR_LEFT, 6, 0, 0, 384 << 16, 10, 0, $00000060, 0, WEAPON_GLOVE, 0, 0
                        long                    1, 208, 16, 0, DIR_DOWN, 6, 0, 0, 384 << 16, 10, 0, $000000a0, 0, WEAPON_GLOVE, 0, 0
                        long                    1, 16, 176, 0, DIR_UP, 6, 0, 0, 384 << 16, 10, 0, $000000e0, 0, WEAPON_GLOVE, 0, 0
:player_data_end
}
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

                        ' get x,y position
                        mov    r2, r0
                        add    r2, #PLAYER_X*4
                        rdlong :x, r2
                        add    r2, #4
                        rdlong :y, r2

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


                        ' Decrement State to 0 (currently just used for punching)
                        mov    r3, r0
                        add    r3, #PLAYER_STATE*4                            
                        rdlong :state, r3       wz
        if_nz           sub    :state, #1
        if_nz           wrlong :state, r3


                        mov    r5, r0
                        add    r5, #PLAYER_WEAPONS*4                          
                        rdlong r5, r5

                        test   r5, #WEAPON_GLOVE wz
        if_z            jmp    #:cant_punch                        
                                     
                        ' Look for a button press transition on B.
                        test   r4, #KEY_B       wc      ' Carry = old KEY_B (0 -> NC)
                        test   r2, #KEY_B       wz      ' Not Zero = KEY_B (1 -> NZ)
                        mov    r2, #16
        if_nz_and_nc    wrlong r2, r3                   ' player[r1].state = 16 (punch out)
        if_nz_and_nc    jmpret :punch_ret, #:punch

:cant_punch
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

                        cmp     :state, #0      wz
        if_nz           jmp     #:skip_movement

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

:skip_movement

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

                        jmpret :getdetectpoints_ret, #:getdetectpoints
{
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
 }
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


                        ' Check if we're touching an item.
                        mov    :tx, :x
                        mov    :ty, :y

                        add    :tx, #8
                        add    :ty, #8

                        jmpret :getmapcell_ret, #:getmapcell
                        
                        mov    r2, :tc
                        shr    r2, #5
                        cmp    r2, #MAP_ITEM>>5 wz
        if_z            jmpret :itemcollect_ret, #:itemcollect

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

                        mov    :tz, :ty
                        shl    :tz, #MAP_WIDTHS
                        add    :tz, :tx

                        ' :tmp2 = @lmap
                        mov    :tmp2, #(_memstart+@g_lmap)>>9
                        shl    :tmp2, #9
                        or     :tmp2, #(_memstart+@g_lmap)
                        rdlong :tmp2, :tmp2
                        add    :tmp2, :tz

                        rdbyte :tc, :tmp2

:getmapcell_ret         ret


:getfmapcell

                        shr    :tx, #4
                        shr    :ty, #4

                        mov    :tz, :ty
                        shl    :tz, #MAP_WIDTHS
                        add    :tz, :tx

                        ' :tmp2 = @fmap
                        mov    :tmp2, #(_memstart+@g_fmap)>>9
                        shl    :tmp2, #9
                        or     :tmp2, #(_memstart+@g_fmap)
                        rdlong :tmp2, :tmp2
                        add    :tmp2, :tz

                        rdbyte :tc, :tmp2

:getfmapcell_ret        ret

:flamehit

                        mov    r3, r0
                        add    r3, #PLAYER_INVINCIBLE*4                    
                        rdlong r2, r3           wz
        if_nz           jmp    #:skip_flamehitkill

                        ' Just vanish him for now.
                        mov    r3, r0
                        add    r3, #PLAYER_STATUS*4
                        mov    r2, #2           ' DEATH Sequence mode.
                        wrlong r2, r3

                        mov    r3, r0
                        add    r3, #PLAYER_VY*4
                        neg    r2, #16          ' Negative Velocity (Upward)
                        wrword r2, r3
                        add    r3, #2
                        mov    r2, #0           ' 0 Positional Offset.
                        wrword r2, r3

:skip_flamehitkill

:flamehit_ret           ret

:itemcollect            
                        mov    :tmp0, :tc
                        test   :tmp0, #8        wz      ' items 8+ are explosion.
        if_nz           mov    :flamehitflag, #1        ' you just got burnt!
        if_nz           jmp    #:itemcollect_ret
        
                        and    :tmp0, #15

                        ' Check Item type and credit player appropriately.
{
  ITEM_BOMB     = 0
  ITEM_FLAME    = 1
  ITEM_SKATES   = 2
  ITEM_GLOVE    = 3
  ITEM_BOOTS    = 4
}
                        mov    r3, r0
        
                        cmp    :tmp0, #ITEM_BOMB wz                                            
        if_z            add    r3, #PLAYER_BOMBS*4
        if_z            rdlong r2, r3
        if_z            add    r2, #1
        if_z            wrlong r2, r3              ' player[r1].bombs++
        if_z            jmp    #:itemcollectdone


                        cmp    :tmp0, #ITEM_FLAME wz                                           
        if_z            add    r3, #PLAYER_FLAME*4
        if_z            rdlong r2, r3
        if_z            add    r2, #1
        if_z            wrlong r2, r3              ' player[r1].flame++
        if_z            jmp    #:itemcollectdone

                        cmp    :tmp0, #ITEM_SKATES wz                                          
        if_z            add    r3, #PLAYER_TICK*4
        if_z            rdlong r2, r3
        if_z            add    r2, :skateincrement
        if_z            wrlong r2, r3              ' player[r1].speed+=:skateincrement
        if_z            jmp    #:itemcollectdone

                        cmp    :tmp0, #ITEM_GLOVE wz                                           
        if_z            add    r3, #PLAYER_WEAPONS*4
        if_z            rdlong r2, r3
        if_z            or     r2, #WEAPON_GLOVE
        if_z            wrlong r2, r3              ' player[r1].weapons|=#WEAPON_GLOVE
        if_z            jmp    #:itemcollectdone

:itemcollectdone


                        
                        
                        ' Remove Item
                        
                        ' :tmp1 = @lmap
                        mov    :tmp1, #(_memstart+@g_lmap)>>9
                        shl    :tmp1, #9
                        or     :tmp1, #(_memstart+@g_lmap)
                        rdlong :tmp1, :tmp1
                        add    :tmp1, :tz

                        mov    :tmp0, #MAP_GROUND
                        wrbyte :tmp0, :tmp1
                        
':tc, :tz r0

':skip_itemcollect

:itemcollect_ret        ret

:punch
                        mov    :tx, :x
                        mov    :ty, :y

                        mov    r5, r0
                        add    r5, #PLAYER_DIR*4
                        rdlong r3, r5           ' r3 = player[r1].dir
                        jmpret :getdetectpoints_ret, #:getdetectpoints          ' tx/ty are offsetted to detect point.

                        jmpret :getmapcell_ret, #:getmapcell

                        shr    :tc, #5                        
                        cmp    :tc, #MAP_BOMB>>5        wz
        if_nz           jmp    #:skip_punchbomb

                        ' Remove Bomb from Map
                        ' r2 = @lmap
                        mov    r2, #(_memstart+@g_lmap)>>9
                        shl    r2, #9
                        or     r2, #(_memstart+@g_lmap)
                        rdlong r2, r2
                        add    r2, :tz

                        mov    :tc, #MAP_GROUND+0
                        wrbyte :tc, r2


                        ' Get Extended Value
                        ' r2 = @emap
                        mov    r2, #(_memstart+@g_emap)>>9
                        shl    r2, #9
                        or     r2, #(_memstart+@g_emap)
                        rdlong r2, r2
                        add    r2, :tz

                        rdbyte :tmp0, r2        ' save extended map value.
                        mov    :tc, #0
                        wrbyte :tc, r2

                        ' Get Owner
                        ' r2 = @omap
                        mov    r2, #(_memstart+@g_omap)>>9
                        shl    r2, #9
                        or     r2, #(_memstart+@g_omap)
                        rdlong r2, r2
                        add    r2, :tz

                        rdbyte :tmp3, r2        ' save owner value

                        mov    r2, #(_memstart+@g_bombidx)>>9
                        shl    r2, #9
                        or     r2, #(_memstart+@g_bombidx)                        
                        rdlong r4, r2                        
                        mov    r5, r4
                        shl    r5, #3           ' r5 *=8                               
                        add    r4, #1
                        and    r4, #MAX_BOMBS-1 ' 32 bomb entities. wraparound
                        wrlong r4, r2

                        mov    r2, #(_memstart+@g_bombptr)>>9
                        shl    r2, #9
                        or     r2, #(_memstart+@g_bombptr)                        
                        rdlong r2, r2
                        add    r2, r5           ' r2 = @bomb[n]

                        or     r3, #4*24        ' r3 = 4*N + dir. where N is how many initial big bounce frames.
                        wrbyte r3, r2           ' Bomb Direction    
                        add    r2, #1
                        mov    r3, :tx          ' Bomb X
                        shl    r3, #4
                        add    r3, #8
                        wrbyte r3, r2                               
                        add    r2, #1
                        mov    r3, :ty          ' Bomb Y
                        shl    r3, #4
                        add    r3, #8
                        wrbyte r3, r2                               
                        add    r2, #1
                        mov    r3, :tmp0        ' Bomb EXT: roughly 2 seconds
                        wrbyte r3, r2                                                             
                        add    r2, #1
                        mov    r3, :tmp3        ' Bomb OWNER
                        wrbyte r3, r2           '                                                 
{
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
}

:skip_punchbomb         
                        
:punch_ret              ret

:getdetectpoints
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
:getdetectpoints_ret    ret

:skateincrement         long                    64<<16
:tmp0                   long                    $0
:tmp1                   long                    $0
:tmp2                   long                    $0
:tmp3                   long                    $0
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
:state                  long                    $0

PROCESSPLAYERS_END


' /////////////////////////////////////////////////////////////////////////////
' PROCESSDEATHPLAYERS /////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        org
PROCESSDEATHPLAYERS_START                

                        mov    r1, #0

                        ' r0 = @player
                        mov    r0, #(_memstart+@g_playerptr)>>9
                        shl    r0, #9
                        or     r0, #(_memstart+@g_playerptr)
                        rdlong r0, r0

:loop
' r0: @player[0....n] 
' r1: 0...n (player index)

                        mov    r3, r0
                        add    r3, #PLAYER_STATUS*4
                        rdlong r2, r3
                        cmp    r2, #2           wc      ' PLAYER_STATUS == 1 (alive and kicking), 2+ death sequence, 0 dead.
        if_c            jmp    #:continue
'                       cmp    r2, #0           wz
'       if_z            jmp    #:continue
        
                        add    r2, #1

                        cmp    r2, #150         wz      ' 2.5 secs. to completely dead.
        if_z            mov    r2, #0
        
                        wrlong r2, r3


                        ' Process VY (Offset Y and Velocity Y) w/ some gravity
                        ' copy values into registers
                        mov    r3, r0
                        add    r3, #PLAYER_VY*4
                        rdword :vy, r3
                        add    r3, #2
                        rdword :y, r3

                        ' sign extend these values (i.e. 16bit -> 32bit (rdword 0-extends)
                        test   :y, :sign16      wz
        if_nz           or     :y, :signextend16
                        test   :vy, :sign16     wz
        if_nz           or     :vy, :signextend16
                        
                        add    :y, :vy          wz '
        if_nz           add    :vy, #1          ' We have gravity!

                        ' Trap at 0.
                        cmp    :y, #1           wc
        if_c            mov    :y, #0
        if_c            mov    :vy, #0
                        
                        ' copy values back. (upper 16 bits are cut off)
                        mov    r3, r0
                        add    r3, #PLAYER_VY*4
                        wrword :vy, r3
                        add    r3, #2
                        wrword :y, r3

                        ' animate and face south.

                        mov    r3, r0
                        add    r3, #PLAYER_ANIM*4
                        rdlong r4, r3


                        cmp    r2, #40          wc
        if_c            add    r4, #1

                        cmp    r2, #60          wc
        if_c            add    r4, #1

                        cmp    r2, #80          wc
        if_c            add    r4, #1
        
                        cmp    r2, #100         wc
        if_c            add    r4, #1
        if_nc           mov    r4, #0
                        
                        wrlong r4, r3
                        


:continue

                        add    r0, #PLAYER_SIZE*4
                        add    r1, #1
                        cmp    r1, #4           wz
        if_nz           jmp    #:loop

                        jmp    #__loader_return

:sign16                 long                    $00008000
:signextend16           long                    $ffff0000
:y                      long                    $0
:vy                     long                    $0

PROCESSDEATHPLAYERS_END

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

                        ' check state (punching) and force anim at 3 instead of 0,1,2
                        shr    r4, #2                   ' r4 = DIR*2
                        add    r4, #:lut_dirvect        ' offsetted to start of dirvect[4][2] array.
                        movs   :code_x, r4              
                        add    r4, #1
                        movs   :code_y, r4
                        mov    :t2, :t3
                        add    :t2, #PLAYER_STATE*4
                        rdlong :t2, :t2         wz                        
        if_nz           mov    r2, #48                  ' change source X to 48 (anim 3)
:code_x if_nz           add    r0, 0
:code_y if_nz           add    r1, 0
                        
                        
                        
                        mov    :t2, :t3
                        add    :t2, #PLAYER_COLOR*4
                        rdlong :draw_sprite_mod, :t2

                        movs   :draw_sprite_w, #(16+3)/4
                        movs   :draw_sprite_h, #24-1


                        mov    :t2, :t3
                        add    :t2, #PLAYER_STATUS*4
                        rdlong :t2, :t2
                        cmp    :t2, #2          wc
        if_c            jmp    #:skip_deathspr
                        
                        ' Get Y offset
                        ' copy values into registers
                        mov    :t2, :t3
                        add    :t2, #PLAYER_VY*4
                        add    :t2, #2
                        rdword :t2, :t2
                        

                        ' sign extend these values (i.e. 16bit -> 32bit (rdword 0-extends)
                        test   :t2, :sign16     wz
        if_nz           or     :t2, :signextend16

                        cmp    :t2, #0          wz
                        add    r1, :t2
                        add    r1, #10
                        
        if_z            movs   :draw_sprite_h, #14-1
'                       movs   :draw_sprite_h, #14-1
                        
:skip_deathspr

                        jmpret :draw_sprite_ret, #:draw_sprite

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
                        movs   :draw_sprite_h, #16-1    ' H
                        
                        jmpret :draw_sprite_ret, #:draw_sprite

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
                        movs   :draw_sprite_h, #16-1    ' H
                        jmpret :draw_sprite_ret, #:draw_sprite
' END DEBUG Frame load
}

                        jmp   #__loader_return
                        
:t0                     long                    $0
:t1                     long                    $0
:t2                     long                    $0
:t3                     long                    $0
:draw_sprite_mod        long                    $0
:sign16                 long                    $00008000
:signextend16           long                    $ffff0000
:lut_dirvect            long                    $00000000, $ffffffff
                        long                    $00000000, $00000001
                        long                    $fffffffd, $00000000
                        long                    $00000003, $00000000

:draw_sprite                       

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
:draw_sprite_w          mov    r5, #(16+3)/4
                        wrlong r5, r6
                        add    r6, #4

                        ' H
:draw_sprite_h          mov    r5, #24-1
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

                        ' Color Modifier
                        
                        wrlong :draw_sprite_mod, r6
                        add    r6, #4
                        
                        ' move obj pointer along to next obj.
                        wrlong r6, r7                        

:draw_sprite_ret        ret

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