' /////////////////////////////////////////////////////////////////////////////
' TITLE: PARALLAX_SCROLL_DEMO_001.SPIN 
'
' DESCRIPTION: Parallax scrolling demo, loads in
' alien planet map and art, and scrolls layers at different velocities to
' simulate parallax 
'
' VERSION: 1.0
' AUTHOR: Andre' LaMothe
' LAST MODIFIED:
' COMMENTS:
'
' CONTROLS: Gamepad, right left scrolls image back and forth in parallax.

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


  ' artifical "velocity" of each scrolling layer
  SKY_RATE         = 256
  MOUNTAIN_RATE    = 5
  GRASS0_RATE      = 4
  GRASS1_RATE      = 3
  GRASS2_RATE      = 2
  GRASS3_RATE      = 1
  
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

byte sbuffer[80]                                        ' string buffer for printing
long x, y, tx, ty, index, dir, tile_map_index           ' demo working vars
long scroll_x, scroll_y                                 ' scrolling vars

long sky_cnt
long mountain_cnt
long grass0_cnt
long grass1_cnt
long grass2_cnt
long grass3_cnt

long curr_count                                         ' saves counter
word tile_buffer[128]                                   ' tile row buffer large enough for 128 tile entries

'//////////////////////////////////////////////////////////////////////////////
'OBJS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

OBJ

game_pad :      "gamepad_drv_001.spin"
gfx:            "HEL_GFX_ENGINE_040.SPIN"
tile_data:      "alienplanet_tile_data.spin" 

'//////////////////////////////////////////////////////////////////////////////
'PUBS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

' COG INTERPRETER STARTS HERE...@ THE FIRST PUB

PUB Start 
' This is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

' star the game pad driver (will need it later)
game_pad.start

' set up tile and sprite engine data before starting it, so no ugly startup
' points ptrs to actual memory storage for tile engine
' point everything to the "tile_data" object's data which are retrieved by "getter" functions
tile_map_base_ptr_parm        := tile_data.tile_maps
tile_bitmaps_base_ptr_parm    := tile_data.tile_bitmaps
tile_palettes_base_ptr_parm   := tile_data.tile_palette_map

' these control the sprite engine, all 0 for now, no sprites
tile_map_sprite_cntrl_parm    := $00_00 ' 0 sprites, tile map set to 0=16 tiles wide, 1=32 tiles, 2=64 tiles, etc.
tile_sprite_tbl_base_ptr_parm := 0 
tile_status_bits_parm         := 0

' initialize scrolling vars
scroll_x := 0
scroll_y := 0

' launch a COG with ASM video driver
gfx.start(@tile_map_base_ptr_parm)

' enter main event loop...
repeat while 1
  
  ' main even loop code here...
  curr_count := cnt ' save current counter value
  
 scroll_x := 0

 ' is player scrolling? 
 if (game_pad.button(NES0_RIGHT))
   scroll_x := -1 

 if (game_pad.button(NES0_LEFT))
   scroll_x := 1 

 ' update scrolling rates for each layer 
 if (scroll_x <> 0)
    if (++sky_cnt => SKY_RATE)
      sky_cnt := 0
      ' scroll layers
      Scroll_Layer(tile_map_base_ptr_parm, 16, 0, 2, scroll_x)
     
    if (++mountain_cnt => MOUNTAIN_RATE)
      mountain_cnt := 0
      ' scroll layers
      Scroll_Layer(tile_map_base_ptr_parm, 16, 5, 7, scroll_x)
     
    if (++grass0_cnt => GRASS0_RATE)
      grass0_cnt := 0
      ' scroll layers
      Scroll_Layer(tile_map_base_ptr_parm, 16, 8, 8, scroll_x)
     
    if (++grass1_cnt => GRASS1_RATE)
      grass1_cnt := 0
      ' scroll layers
      Scroll_Layer(tile_map_base_ptr_parm, 16, 9, 9, scroll_x)
     
    if (++grass2_cnt => GRASS2_RATE)
      grass2_cnt := 0
      ' scroll layers
      Scroll_Layer(tile_map_base_ptr_parm, 16, 10, 10, scroll_x)
     
    if (++grass3_cnt => GRASS3_RATE)
      grass3_cnt := 0
      ' scroll layers
      Scroll_Layer(tile_map_base_ptr_parm, 16, 11, 11, scroll_x)
     
   ' lock frame rate to 3-6 frames to slow this down
  waitcnt(cnt + 10*666_666)
      
  ' return back to repeat main event loop...

' parent COG will terminate now...if it gets to this point

' /////////////////////////////////////////////////////////////////////////////

PUB Scroll_Layer(tile_map_ptr, width, ys, ye, dx)
  ' this function scrolls a layer or region of the sent tile map from ys to ye an amount dx (signed)
  ' tile_map_ptr - points to beginning of tile map, 16x12 WORDs usually
  ' width        - number of WORDs per row, usually 16
  ' ys, ye       - start and ending y-region to scroll
  ' dx           - amount to scroll horizontally (+-1)

  ' do scroll in 3 steps as to not invoke built in "overlap logic" also so that as change occurs
  ' user doesn't see tiles moving around
  dx := dx // width

  if (dx > 0)
    repeat y from ys to ye
      ' copy left half of row to buffer
      wordmove(@tile_buffer + (dx<<1), tile_map_ptr + (y*width<<1), width-dx)
      ' copy right half of row to buffer
      wordmove(@tile_buffer, tile_map_ptr + ((y*width) + (width-dx))<<1, dx)    
      ' finally copy buffer back to tile row
      wordmove(tile_map_ptr + (y*width<<1), @tile_buffer, width) 
  elseif (dx < 0)
    dx := -dx ' invert dx now
    repeat y from ys to ye
      ' copy right half first
      wordmove(@tile_buffer, tile_map_ptr + ((y*width) + (dx))<<1, width-dx)

      ' copy left half of row to buffer
      wordmove(@tile_buffer + (width-dx)<<1, tile_map_ptr + (y*width<<1), dx)
          
      ' finally copy buffer back to tile row
      wordmove(tile_map_ptr + (y*width*2), @tile_buffer, width) 
  
'//////////////////////////////////////////////////////////////////////////////
'DAT SECTION //////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////
              