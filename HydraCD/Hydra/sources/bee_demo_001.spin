' /////////////////////////////////////////////////////////////////////////////
' TITLE: BEE_DEMO_001.SPIN - Random motion demo.
'
' DESCRIPTION:This random motion demo moves around a flock of bees. Each bee
' moves in a random direction for a random amount of time while flapping its wings.
' The uses a double buffered tiled display, that is, the original tile data map is
' copied into a buffer each frame and the animated objects are overwritten into the
' buffer, the buffer is then passed to the tile engine for rendering. This way
' the tile art work isnt destroyed. Also, the motion math is fixed point 24.8 format 
'
' VERSION: 1.0
' AUTHOR: Andre' LaMothe
' LAST MODIFIED:
' COMMENTS:
'
' CONTROLS: Gamepad, right left scrolls image back and forth, the bees do their
' own thing
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

' each bee "record/struct" contains each of these fields
  BEE_INDEX_X     = 0           ' x,y,dx,dy all use 24.8 fixed point math                                   
  BEE_INDEX_Y     = 1           
  BEE_INDEX_DX    = 2            
  BEE_INDEX_DY    = 3
  BEE_INDEX_FRAME = 4           ' current animation frame
  BEE_INDEX_COUNT = 5           ' counter used to signal change of random direction

  BEE_RECORD_SIZE = 6           ' 6 elements per record

  NUM_BEES        = 10          ' number of bees on screen
    
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
long x, y, tx, ty, dx, dy, counter                      ' demo working vars
long index, dir, tile_map_index                         ' demo working vars
long scroll_x, scroll_y                                 ' scrolling vars
long curr_count                                         ' saves counter


long bees[NUM_BEES * BEE_RECORD_SIZE]                   ' data storage for bee records
long bee_record_offset                                  ' used to compute base address to records for speed

' going to use a double buffered tile map in this demo for fun
word tile_map_buffer[16*12] 

long random_var                                         ' global random variable

'//////////////////////////////////////////////////////////////////////////////
'OBJS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

OBJ

game_pad :      "gamepad_drv_001.spin"
gfx:            "HEL_GFX_ENGINE_040.SPIN"
tile_data:      "bee_tile_data.spin" 

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

' initalize all the bees
repeat index from 0 to NUM_BEES-1
  ' pre-compute base index for speed
  bee_record_offset := index * BEE_RECORD_SIZE

  ' initialize fields of record
  bees[bee_record_offset + BEE_INDEX_X]                 := Rand_Range(0, 9*256) 
  bees[bee_record_offset + BEE_INDEX_Y]                 := Rand_Range(0, 9*256)
  bees[bee_record_offset + BEE_INDEX_DX]                := Rand_Range(-1*256, 1*256)
  bees[bee_record_offset + BEE_INDEX_DY]                := Rand_Range(-1*256, 1*256)
  bees[bee_record_offset + BEE_INDEX_FRAME]             := 5
  bees[bee_record_offset + BEE_INDEX_COUNT]             := Rand_Range(5, 15)

' initialize random variable
random_var := cnt*171732
random_var := ?random_var

' launch a COG with ASM video driver
gfx.start(@tile_map_base_ptr_parm)

' enter main event loop...
repeat while 1
  
  ' main even loop code here...
  curr_count := cnt ' save current counter value

  ' step 1: copy tile map data to tile map buffer for destructive animation
  wordmove(@tile_map_buffer, tile_data.tile_maps, 16*12)  

  ' test for scroll
  if (game_pad.button(NES0_RIGHT) and scroll_x < 5)
      scroll_x++

  if (game_pad.button(NES0_LEFT) and scroll_x > 0)
      scroll_x--

' perform animation of bees
  repeat index from 0 to NUM_BEES-1
    ' pre-compute base index for speed
    bee_record_offset := index * BEE_RECORD_SIZE
   
    ' retrieve values for computations
    x              := bees[bee_record_offset + BEE_INDEX_X]                  
    y              := bees[bee_record_offset + BEE_INDEX_Y]                 
    dx             := bees[bee_record_offset + BEE_INDEX_DX]                  
    dy             := bees[bee_record_offset + BEE_INDEX_DY]                 
    tile_map_index := bees[bee_record_offset + BEE_INDEX_FRAME] 
    counter        := bees[bee_record_offset + BEE_INDEX_COUNT]             
    
    ' test for counter complete?
    if (--counter < 0)
      ' compute new direction etc. for bee
      ' pre-compute base index for speed
      bee_record_offset := index * BEE_RECORD_SIZE
       
      ' re-initialize fields of record
      dx      := Rand_Range(-1*256, 1*256)
      dy      := Rand_Range(-1*256, 1*256)
      counter := Rand_Range(5, 15)
     
    ' move bee
    x += dx
    y += dy
 
   ' test for collision with walls, if hit wall just press against until counter complete
   ' otherwise, bees will look like they are bouncing
    if (x > 15*256)
      x := 15*256
    elseif (x < 0)
      x := 0
        
    if (y > 9*256)
      y := 9*256
    elseif (y < 0)
      y := 0
  
    ' animate bee each frame no matter what 
    if (++tile_map_index > 7)
      tile_map_index := 5
 
    ' store working vars back into data structure
    bees[bee_record_offset + BEE_INDEX_X]             := x                  
    bees[bee_record_offset + BEE_INDEX_Y]             := y                
    bees[bee_record_offset + BEE_INDEX_DX]            := dx                 
    bees[bee_record_offset + BEE_INDEX_DY]            := dy    
    bees[bee_record_offset + BEE_INDEX_FRAME]         := tile_map_index
    bees[bee_record_offset + BEE_INDEX_COUNT]         := counter    
  
  ' render bees into tile_map_buffer
  repeat index from 0 to NUM_BEES-1
    ' pre-compute base index for speed
    bee_record_offset := index * BEE_RECORD_SIZE

    ' retrieve x,y, animation frame
    x              := bees[bee_record_offset + BEE_INDEX_X]                  
    y              := bees[bee_record_offset + BEE_INDEX_Y]                 
    tile_map_index := bees[bee_record_offset + BEE_INDEX_FRAME] 

    ' render into buffer palette index and frame (same)
    tile_map_buffer[ (x >> 8) + (y >> 8)*16] := tile_map_index << 8 | tile_map_index
  
  ' update tile base memory pointer
  tile_map_base_ptr_parm := @tile_map_buffer + scroll_x*2

   ' lock frame rate to 3-6 frames to slow this down
  waitcnt(cnt + 5*666_666)
      
  ' return back to repeat main event loop...

' parent COG will terminate now...if it gets to this point

' /////////////////////////////////////////////////////////////////////////////

Pub Rand_Range(rstart, rend) : r_delta
' returns a random number from [rstart to rend] inclusive
r_delta := rend - rstart + 1

result := rstart + ((?random_var & $7FFFFFFF) // r_delta)

return result


'//////////////////////////////////////////////////////////////////////////////
'DAT SECTION //////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////
              