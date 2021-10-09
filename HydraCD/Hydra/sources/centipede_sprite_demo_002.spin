' /////////////////////////////////////////////////////////////////////////////
' TITLE: CENTIPEDE_SPRITE_DEMO_002.SPIN
'
' DESCRIPTION: Draws a random mushroom patch on screen where each mushroom has
' its own palette, then allows player to move around a "bug blaster" and fire
' missiles with plasma animation effect, but no collision etc.  
'
' VERSION: x.x
' AUTHOR: Andre' LaMothe
' LAST MODIFIED:
' COMMENTS:
'
' CONTROLS: Uses gamepad, use DPAD to move around, "B" to fire!
'
'//////////////////////////////////////////////////////////////////////////////

'//////////////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ///////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x       ' enable external clock range 5-10MHz and pll times 8
  _xinfreq = 10_000_000 + 0000   ' set frequency to 10 MHZ plus some error due to XTAL (1000-5000 usually works)
  _stack   = 128                 ' accomodate display memory and stack

  ' button ids/bit masks
  ' NES bit encodings general for state bits
  NES_RIGHT  = %00000001
  NES_LEFT   = %00000010
  NES_DOWN   = %00000100
  NES_UP     = %00001000
  NES_START  = %00010000
  NES_SELECT = %00100000
  NES_B      = %01000000
  NES_A      = %10000000

  ' NES bit encodings for NES gamepad 0
  NES0_RIGHT  = %00000000_00000001
  NES0_LEFT   = %00000000_00000010
  NES0_DOWN   = %00000000_00000100
  NES0_UP     = %00000000_00001000
  NES0_START  = %00000000_00010000
  NES0_SELECT = %00000000_00100000
  NES0_B      = %00000000_01000000
  NES0_A      = %00000000_10000000

  ' NES bit encodings for NES gamepad 1
  NES1_RIGHT  = %00000001_00000000
  NES1_LEFT   = %00000010_00000000
  NES1_DOWN   = %00000100_00000000
  NES1_UP     = %00001000_00000000
  NES1_START  = %00010000_00000000
  NES1_SELECT = %00100000_00000000
  NES1_B      = %01000000_00000000
  NES1_A      = %10000000_00000000

  ' color constant's to make setting colors for parallax graphics setup easier
  COL_Black       = %0000_0010
  COL_DarkGrey    = %0000_0011
  COL_Grey        = %0000_0100
  COL_LightGrey   = %0000_0101
  COL_BrightGrey  = %0000_0110
  COL_White       = %0000_0111 

  ' colors are in reverse order from parallax drivers, or in order 0-360 phase lag from 0 = Blue, on NTSC color wheel
  ' so code $0 = 0 degrees, $F = 360 degrees, more intuitive mapping, and is 1:1 with actual hardware
  COL_PowerBlue   = %1111_1_100 
  COL_Blue        = %1110_1_100
  COL_SkyBlue     = %1101_1_100
  COL_AquaMarine  = %1100_1_100
  COL_LightGreen  = %1011_1_100
  COL_Green       = %1010_1_100
  COL_GreenYellow = %1001_1_100
  COL_Yellow      = %1000_1_100
  COL_Gold        = %0111_1_100
  COL_Orange      = %0110_1_100
  COL_Red         = %0101_1_100
  COL_VioletRed   = %0100_1_100
  COL_Pink        = %0011_1_100
  COL_Magenta     = %0010_1_100
  COL_Violet      = %0001_1_100
  COL_Purple      = %0000_1_100

  ' game defines
  NUM_MUSHROOMS   = 25 ' number of mushrooms on playfield

  ' sprite stuff
  SPRITE_BITMAPMASK_SIZE = 128 ' size of sprite+mask in bytes, helps access an array for animation

  ' states for missile
  MISSILE_STATE_DEAD   = 0
  MISSILE_STATE_ALIVE  = 1
  MISSILE_STATE_DYING  = 2  

  ' missile constants
  MISSILE_VEL          = 2     ' velocity of missile in pixels/frame
  
'//////////////////////////////////////////////////////////////////////////////
' VARS SECTION ////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

VAR

' begin parameter list ////////////////////////////////////////////////////////
' tile engine data structure pointers (can be changed in real-time by app!)
long tile_map_base_ptr_parm       ' base address of the tile map
long tile_bitmaps_base_ptr_parm   ' base address of the tile bitmaps
long tile_palettes_base_ptr_parm  ' base address of the palettes

long tile_map_sprite_cntrl_parm   ' pointer to the value that holds various "control" values for the tile map/sprite engine
                                  ' currently, encodes width of map, and number of sprites to process up to 8 in following format
                                  ' $xx_xx_ss_ww, xx is don't care/unused
                                  ' ss = number of sprites to process 1..8
                                  ' ww = the number of "screens" or multiples of 16 that the tile map is
                                  ' eg. 0 would be 16 wide (standard), 1 would be 32 tiles, 2 would be 64 tiles, etc.
                                  ' this allows multiscreen width playfields and thus large horizontal/vertical scrolling games
                                  ' note that the final size is always a power of 2 multiple of 16

long tile_sprite_tbl_base_ptr_parm ' base address of sprite table


' real-time engine status variables, these are updated in real time by the
' tile engine itself, so they can be monitored outside in SPIN/ASM by game
long tile_status_bits_parm      ' vsync, hsync, etc.

' format of tile_status_bits_parm, only the Vsync status bit is updated
'
' byte 3 (unused)|byte 2 (line)|   byte 1 (tile postion)    |                     byte 0 (sync and region)      |
'|x x x x x x x x| line 8-bits | row 4 bits | column 4-bits |x x x x | region 2-bits | hsync 1-bit | vsync 1-bit|
'   b31..b24         b23..b16      b15..b12     b11..b8                    b3..b2          b1            b0
' Region 0=Top Overscan, 1=Active Video, 2=Bottom Overscan, 3=Vsync
' NOTE: In this version of the tile engine only VSYNC and REGION are valid 

' end parameter list ///////////////////////////////////////////////////////////

byte sbuffer[80]                                          ' string buffer for printing
long x, y, tx, ty, index, dir, tile_map_index, test_tile  ' demo working vars
long blaster_x, blaster_y                                 ' position of blaster
long blaster_frame, blaster_blink_state                   ' used to animate bug blaster's blink
long missile_x, missile_y, missile_state, missile_counter ' data structure for single missile                        
long random_seed                                          ' holds the random seed
long color_1, color_2, color_3                            ' used in random palette generation
long palette_index                                        ' used in loops to access a palette
long curr_count                                           ' current global counter count

'//////////////////////////////////////////////////////////////////////////////
'OBJS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

OBJ

game_pad :      "gamepad_drv_001.spin"
gfx:            "HEL_GFX_ENGINE_040.SPIN"

'//////////////////////////////////////////////////////////////////////////////
'PUBS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

' COG INTERPRETER STARTS HERE...@ THE FIRST PUB

PUB Start
' This is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

' star the game pad driver
game_pad.start

' initialize all vars

' bug blaster
blaster_x           := 160/2             ' set sprite location of blaster to center of screen, bottom
blaster_y           := 190                    
blaster_frame       := 0                 ' set to eyes open animation frame                                            
blaster_blink_state := 0

' missle that player fires
missile_x           := 0
missile_y           := 0
missile_state       := 0  ' 0 = dead, 1 = alive, 2 = dying or exploding, good convention to use
missile_counter     := 0

' seed random number generator
random_seed := cnt + 172372371

' generate random palettes
repeat index from 1 to 15
  random_seed := ?random_seed
  ' get random color nibbles
  color_1 := ((random_seed & $00_00_00_F0) >> 0)  | $0C ' add brightness to it
  color_2 := ((random_seed & $00_00_F0_00) >> 8)  | $0B ' add brightness to it
  color_3 := ((random_seed & $00_F0_00_00) >> 16) | $0D ' add brightness to it
  palette_map[index] := (color_3 << 24) | (color_2 << 16) | (color_1 << 8) | $02 ' color 0 is always background    

' generate a random mushroom field, everywhere a mushroom is placed it will have its own palette
' thus if player moves bug blaster over mushroom, he will change colors :)
' for now, there are 3 "zones" top to bottom, so the screen is broken 3 color regions top to bottom, kinda cool
repeat NUM_MUSHROOMS
  random_seed := ?random_seed

  ' extract some data from random variable
  x := (random_seed & $00_FF) / 26            ' limit to range 0..9
  y := ((random_seed & $FF_00) >> 8) / 22  ' limit to range 0..11

  ' write to tile map
  tile_map0[ x + y << 4] := ( ((y / 4) + 1) << 8) | $01 
                       
' points ptrs to actual memory storage for tile engine
tile_map_base_ptr_parm        := @tile_map0
tile_bitmaps_base_ptr_parm    := @tile_bitmaps
tile_palettes_base_ptr_parm   := @palette_map
tile_map_sprite_cntrl_parm    := $00_00_02_00 ' set for 2 sprites and width 16 tiles (1 screens wide), 0 = 16 tiles, 1 = 32 tiles, 2 = 64 tiles, 3 = 128 tiles, etc.
tile_sprite_tbl_base_ptr_parm := @sprite_tbl[0] 
tile_status_bits_parm         := 0

' enable/initialize sprites
' bug blaster sprite
sprite_tbl[0] := $70_50_00_01     ' sprite 0 state: y=xx, x=$xx, z=$xx, enabled/disabled
sprite_tbl[1] := @sprite_bitmap_1 ' sprite 0 bitmap ptr

' missile sprite
sprite_tbl[2] := $50_50_00_01     ' sprite 1 state: y=xx, x=$xx, z=$xx, enabled/disabled
sprite_tbl[3] := @sprite_bitmap_3 ' sprite 1 bitmap ptr


' launch a COG with ASM video driver
gfx.start(@tile_map_base_ptr_parm)

' enter main event loop...no need for game states, simple demo, one state - RUN
repeat while 1
  ' main even loop code here...

  ' update random number
  random_seed := ?random_seed

  ' save current count to lock frame rate  
  curr_count := cnt

  ' get gamepad input and move the sprite
  if (game_pad.button(NES0_RIGHT))
    blaster_x+=1
  if (game_pad.button(NES0_LEFT))
    blaster_x-=1
  if (game_pad.button(NES0_DOWN))
    blaster_y+=1
  if (game_pad.button(NES0_UP))
    blaster_y-=1

  ' test if player is firing missile
  if (missile_state == 0 and (game_pad.button(NES0_A) or game_pad.button(NES0_B)) )
    ' start a new missile at blasters location
    missile_state := 1 ' missile active
    missile_x     := blaster_x
    missile_y     := blaster_y-10

  ' run motion / animation state machine for missile, normally this would be in a seperate function
  ' but for brevity we are keeping everythin in the main loop
  case missile_state

    MISSILE_STATE_DEAD:  ' do nothing...

    MISSILE_STATE_ALIVE: ' move and animate the missile, test for off screen
      if ( (missile_y -= MISSILE_VEL) < 0 )                       ' move missile upward...test for offscreen
        missile_state := MISSILE_STATE_DEAD             ' terminate missile

      ' animate missile by rendering random pixels into sprite buffer to make it look like "plasma"
      ' star trek "beam out" effect!
      repeat index from 2 to 13
        sprite_bitmap_3[index] := %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0 & (?random_seed)
              
    MISSILE_STATE_DYING: ' not implemented, but maybe when the missile hits it has a death animation  
  ' end case

  ' test if we want to fire blink animation
  if (blaster_blink_state == 0)
    if ((random_seed & $7F) == 1)
      ' start blink animation, basically change frames and count
      blaster_blink_state := 1
      blaster_frame       := 1
  else
    if (++blaster_blink_state == 30) ' done with blink/wink?
      blaster_blink_state := 0
      blaster_frame       := 0

  ' perform all rendering and screen updates here...

  ' now update the bug blaster to reflect new position, sprite will update on next frame
  sprite_tbl[0] := (blaster_y << 24) + (blaster_x << 16) + (0 << 8) + ($01)            
  sprite_tbl[1] := @sprite_bitmap_1 + (SPRITE_BITMAPMASK_SIZE)*blaster_frame   

  ' update missile sprite, will update on next frame
  sprite_tbl[2] := (missile_y << 24) + (missile_x << 16) + (0 << 8) + ($01)            
  sprite_tbl[3] := @sprite_bitmap_3   

  ' lock frame rate
  waitcnt(curr_count + 666_666)

  ' return back to repeat main event loop...

' parent COG will terminate now...if it gets to this point


'//////////////////////////////////////////////////////////////////////////////
'DAT SECTION //////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////


DAT

tile_maps     ' you place all your 16x12 tile maps here, you can have as many as you like, in real-time simply re-point the
              ' tile_map_base_ptr_parm to any time map and within 1 frame the tile map will update
              ' the engine only renders 10x12 of the tiles on the physical screen, the other 6 columns allow you some "scroll room"

              ' 16x12 WORDS each, (0..191 WORDs, 384 bytes per tile map) 2-BYTE tiles (msb)[palette_index | tile_index](lsb)
              ' 16x12 tile map, each tile is 2 bytes, there are a total of 64 tiles possible, and thus 64 palettes
              '
              ' <---------------------------visible on screen-------------------------------->|<------ to right of screen ---------->|              
              ' column     0      1      2      3      4      5      6      7      8      9   | 10     11     12     13     14     15

tile_map0     word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 0
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 4
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 5
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 6
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 7
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 8
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 9
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 11

' /////////////////////////////////////////////////////////////////////////////

tile_bitmaps long
              ' tile bitmap memory, each tile 16x16 pixels, or 1 LONG by 16,
              ' 64-bytes each, also, note that they are mirrored right to left
              ' since the VSU streams from low to high bits, so your art must
              ' be reflected, we could remedy this in the engine, but for fun
              ' I leave it as a challenge in the art, since many engines have
              ' this same artifact
              ' for this demo, only 4 tile bitmaps defined

              ' empty tile
              ' palette black, blue, gray, white
tile_blank    long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

tile_mushroom long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 1
              long      %%0_0_0_0_0_0_1_1_1_1_1_1_0_0_0_0
              long      %%0_0_0_0_1_1_3_1_1_1_3_1_1_1_0_0
              long      %%0_0_0_1_1_3_1_1_1_3_1_1_1_1_0_0
              long      %%0_0_0_1_1_1_1_1_1_1_1_1_0_0_0_0
              long      %%0_0_1_1_1_1_1_1_1_2_2_0_0_0_0_0
              long      %%0_0_1_1_1_3_1_1_2_2_0_0_0_0_0_0
              long      %%0_0_1_1_3_1_1_2_2_2_0_0_0_0_0_0
              long      %%0_0_1_1_1_1_2_2_2_2_0_0_0_0_0_0
              long      %%0_0_1_1_1_1_2_2_2_2_2_0_0_0_0_0
              long      %%0_0_1_1_1_0_0_2_0_2_2_2_0_0_0_0
              long      %%0_0_0_1_1_0_0_0_2_2_2_2_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_2_0_2_2_2_0_0_0
              long      %%0_0_0_0_0_0_0_0_2_2_0_2_2_0_0_0
              long      %%0_0_0_0_0_0_0_2_2_2_2_2_2_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

tile_mushroom2 long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 1
              long      %%0_0_0_0_0_0_1_1_1_1_1_1_0_0_0_0
              long      %%0_0_0_0_1_1_3_1_1_1_3_1_1_1_0_0
              long      %%0_0_0_1_1_3_1_1_1_3_1_1_1_1_0_0
              long      %%0_0_0_1_1_1_1_1_1_1_1_1_0_0_0_0
              long      %%0_0_1_1_1_1_1_1_1_2_2_0_0_0_0_0
              long      %%0_0_1_1_1_3_1_1_2_2_0_0_0_0_0_0
              long      %%0_0_1_1_3_1_1_2_2_2_0_0_0_0_0_0
              long      %%0_0_1_1_1_1_2_2_2_2_0_0_0_0_0_0
              long      %%0_0_1_1_1_1_2_2_2_2_2_0_0_0_0_0
              long      %%0_0_1_1_1_0_0_2_0_2_2_2_0_0_0_0
              long      %%0_0_0_1_1_0_0_0_2_2_2_2_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_2_0_2_2_2_0_0_0
              long      %%0_0_0_0_0_0_0_2_2_2_0_2_2_2_0_0
              long      %%0_0_0_0_0_0_2_2_2_2_2_2_2_2_2_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

{
 each sprite is composed of a 2 LONGs, the first is a control/state LONG (broken into 4 bytes), followed by a LONG ptr to the bitmap data
 the format of the control/state LONG

Header format:

Long 0 - state / control bits

|      Byte 3       |       Byte 2      |       Byte 1      |       Byte 0      |
| y7 y y y y y y y0 | x7 x x x x x x x0 | z7 z z z z z z z0 | s7 s s s s s s s0 |
     y - pos              x - pos                z-pos         state/control bits

State/Control bits

Enabled         %00_000_0_0_1
Mirrorx         %00_000_0_1_0
Mirrory         %00_000_1_0_0
Scale1x         %00_000_0_0_0
Scale2x         %00_001_0_0_0
Scale4x         %00_010_0_0_0
Scale8x         %00_100_0_0_0
Raster_OP       %xx_000_0_0_0

The 2nd long is simply a pointer to the bitmap data, can be any 16x16 palettized bitmap, tile, sprite, whatever.
However, sprites have NO palette, they "use" the palette of the tile(s) that they are rendered onto, so beware...  
}


' sprite table, 8 sprites, 2 LONGs per sprite, 8 LONGs total length

              ' sprite 0 header
sprite_tbl    long $00_00_00_00  ' state/control word: y,x,z,state, enabled, x=$50, y=$60
              long $00_00_00_00  ' bitmap ptr

              ' sprite 1 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 2 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 3 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 4 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 5 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 6 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 7 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr


' end sprite table

' sprite bitmap table
' each bitmap is 16x16 pixels, 1 long x 16 longs
' bitmaps are reflected left to right, so keep that in mind
' they are numbered for reference only and any bitmap can be assigned to any sprite thru the use of the
' sprite pointer in the sprite header, this allows easy animation without data movement
' additionally, each sprite needs a "mask" to help the rendering engine, computation of the mask is
' too time sensitive, thus the mask must follow immediately after the sprite

sprite_bitmaps          long

                      ' bitmap for sprite use, uses the palette of the tile its rendered into
sprite_bitmap_0         long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_2_2_2_2_2_2_0_0_0_0_0
                        long      %%0_0_0_2_2_2_2_2_2_2_2_2_2_0_0_0
                        long      %%0_0_0_2_2_2_2_2_2_2_2_2_2_0_0_0
                        long      %%0_0_2_3_3_3_3_2_2_3_3_3_3_2_0_0
                        long      %%0_0_2_3_3_3_3_2_2_3_3_3_3_2_0_0
                        long      %%0_0_2_1_1_3_3_2_2_1_1_3_3_2_0_0
                        long      %%0_0_2_1_1_3_3_2_2_1_1_3_3_2_0_0
                        long      %%0_0_2_2_2_2_2_2_2_2_2_2_2_2_0_0
                        long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_2_0
                        long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_2_0
                        long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_2_0
                        long      %%0_2_2_0_0_2_2_0_0_2_2_0_0_2_2_0
                        long      %%0_2_2_0_0_2_2_0_0_2_2_0_0_2_2_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

' the mask needs to be a NEGATIVE of the bitmap, basically a "stencil" where we are going to write the sprite into, all the values are 0 (mask) or 3 (write thru)
' however, the algorithm needs a POSITIVE to make some of the shifting easier, so we only need to apply the rule to each pixel of the bitmap:
' if (p_source == 0) p_dest = 0, else p_dest = 3
sprite_bitmap_mask_0    long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_3_3_3_0_0_0_0_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_0_0_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_0_0_0
                        long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
                        long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
                        long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
                        long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
                        long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
                        long      %%0_3_3_3_3_3_3_3_3_3_3_3_3_3_3_0
                        long      %%0_3_3_3_3_3_3_3_3_3_3_3_3_3_3_0
                        long      %%0_3_3_3_3_3_3_3_3_3_3_3_3_3_3_0
                        long      %%0_3_3_0_0_3_3_0_0_3_3_0_0_3_3_0
                        long      %%0_3_3_0_0_3_3_0_0_3_3_0_0_3_3_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0


' bug blaster bitmap
sprite_bitmap_1         long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_1_1_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_1_1_1_1_0_0_0_0_0_0
                        long      %%0_0_0_0_0_2_2_1_1_2_2_0_0_0_0_0
                        long      %%0_0_0_0_1_2_2_1_1_2_2_1_0_0_0_0
                        long      %%0_0_0_0_1_1_1_1_1_1_1_1_0_0_0_0
                        long      %%0_0_0_0_1_1_1_1_1_1_1_1_0_0_0_0
                        long      %%0_0_0_0_1_1_1_1_1_1_1_1_0_0_0_0
                        long      %%0_0_0_0_0_1_1_1_1_1_1_0_0_0_0_0
                        long      %%0_0_0_0_0_0_1_1_1_1_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_1_1_1_1_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_1_1_1_1_0_0_0_0_0_0                        
                        long      %%0_0_0_0_0_0_0_1_1_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_1_1_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0



sprite_bitmap_mask_1    long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_3_3_3_3_0_0_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_3_3_3_0_0_0_0_0
                        long      %%0_0_0_0_3_3_3_3_3_3_3_3_0_0_0_0
                        long      %%0_0_0_0_3_3_3_3_3_3_3_3_0_0_0_0
                        long      %%0_0_0_0_3_3_3_3_3_3_3_3_0_0_0_0
                        long      %%0_0_0_0_3_3_3_3_3_3_3_3_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_3_3_3_0_0_0_0_0
                        long      %%0_0_0_0_0_0_3_3_3_3_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_3_3_3_3_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_3_3_3_3_0_0_0_0_0_0                        
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

' bug blaster bitmap with eyes closed :)
sprite_bitmap_2         long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_1_1_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_1_1_1_1_0_0_0_0_0_0
                        long      %%0_0_0_0_0_1_2_1_1_2_1_0_0_0_0_0
                        long      %%0_0_0_0_1_1_1_1_1_1_1_1_0_0_0_0
                        long      %%0_0_0_0_1_1_1_1_1_1_1_1_0_0_0_0
                        long      %%0_0_0_0_1_1_1_1_1_1_1_1_0_0_0_0
                        long      %%0_0_0_0_1_1_1_1_1_1_1_1_0_0_0_0
                        long      %%0_0_0_0_0_1_1_1_1_1_1_0_0_0_0_0
                        long      %%0_0_0_0_0_0_1_1_1_1_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_1_1_1_1_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_1_1_1_1_0_0_0_0_0_0                        
                        long      %%0_0_0_0_0_0_0_1_1_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_1_1_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0



sprite_bitmap_mask_2    long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_3_3_3_3_0_0_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_3_3_3_0_0_0_0_0
                        long      %%0_0_0_0_3_3_3_3_3_3_3_3_0_0_0_0
                        long      %%0_0_0_0_3_3_3_3_3_3_3_3_0_0_0_0
                        long      %%0_0_0_0_3_3_3_3_3_3_3_3_0_0_0_0
                        long      %%0_0_0_0_3_3_3_3_3_3_3_3_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_3_3_3_0_0_0_0_0
                        long      %%0_0_0_0_0_0_3_3_3_3_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_3_3_3_3_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_3_3_3_3_0_0_0_0_0_0                        
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

' missile bitmap (will be animated in real time to look like plasma!)
sprite_bitmap_3         long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0                        
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

sprite_bitmap_mask_3    long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0                        
                        long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0



' /////////////////////////////////////////////////////////////////////////////

              ' palette memory (1..255 palettes) each palette 4-BYTEs or 1-LONG
{
  COL_PowerBlue   = %1111_1_100 
  COL_Blue        = %1110_1_100
  COL_SkyBlue     = %1101_1_100
  COL_AquaMarine  = %1100_1_100
  COL_LightGreen  = %1011_1_100
  COL_Green       = %1010_1_100
  COL_GreenYellow = %1001_1_100
  COL_Yellow      = %1000_1_100
  COL_Gold        = %0111_1_100
  COL_Orange      = %0110_1_100
  COL_Red         = %0101_1_100
  COL_VioletRed   = %0100_1_100
  COL_Pink        = %0011_1_100
  COL_Magenta     = %0010_1_100
  COL_Violet      = %0001_1_100
  COL_Purple      = %0000_1_100
}

' palettes..              
palette_map   long $07_5C_BB_02                  ' palette 0, bug blaster palette at bottom of screen, we control these colors somewhat
              long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ' palettes 1-15 will be randomly generated


              