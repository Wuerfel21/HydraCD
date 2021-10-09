' /////////////////////////////////////////////////////////////////////////////
' HEL_GATES_003.SPIN - 
' VERSION: x.x
' AUTHOR: Andre' LaMothe
' LAST MODIFIED:
' COMMENTS: 
' /////////////////////////////////////////////////////////////////////////////

{
TODO -

1. Add ability to set size of map horizontal and vertical to allow, smooth scrolling
vertically at least and course scrolling horizontally

2. Creat tool chain

3. Do version with caching

4. Add sprites?

5. Multiple processors

6. EEPROM access

7. Sound engine built in!

100 Lines of ASM graphics engine

8. Make 3 demos of it pitfall, mario, centipede, venture?

}









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


'//////////////////////////////////////////////////////////////////////////////
' VARS SECTION ////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

VAR

' begin parameter list ////////////////////////////////////////////////////////
' tile engine data structure pointers (can be changed in real-time by app!)
long tile_map_base_ptr_parm
long tile_bitmaps_base_ptr_parm
long tile_palettes_base_ptr_parm

' real-time engine status variables, these are updated in real time by the
' tile engine itself, so they can be monitored outside in SPIN/ASM by game
long tile_status_bits_parm      ' vsync, hsync, etc.

' format of tile_status_bitsine, only the Vsync status bit is updated
'
' byte 3 (unused)|   byte 2    |          byte 1            |                     byte 0                        |
'|x x x x x x x x| line 8-bits | row 4 bits | column 4-bits |x x x x | region 2-bits | hsync 1-bit | vsync 1-bit|
'   b31..b24         b23..b16      b15..b12     b11..b8                    b3..b2          b1            b0
' Region 0=Top Overscan, 1=Active Video, 2=Bottom Overscan, 3=Vsync
' NOTE: In this version of the tile engine only VSYNC is valid

' end parmater list ///////////////////////////////////////////////////////////

long x,y,index

'//////////////////////////////////////////////////////////////////////////////
'OBJS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

OBJ

game_pad : "gamepad_drv_001.spin"


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

' points ptrs to actual memory storage for tile engine
tile_map_base_ptr_parm      := @tile_maps
tile_bitmaps_base_ptr_parm  := @tile_bitmaps
tile_palettes_base_ptr_parm := @palette_map
tile_status_bits_parm       := 1

' launch a COG with ASM video driver
cognew(@HEL_Video_Driver_Entry, @tile_map_base_ptr_parm)


' run a tile around for fun
x := 8
y := 5

repeat while 1
  ' erase, sync to vblank
  
  tile_map0[(x+y<<4)<<1] := 0

  ' move
  if (game_pad.button(NES0_RIGHT))
    if (++x > 15)
       x:=0
  else
  if (game_pad.button(NES0_LEFT))
    if (--x < 0)
       x:=15

  if (game_pad.button(NES0_DOWN))
    if (++y > 11)
       y:=0
  else
  if (game_pad.button(NES0_UP))
    if (--y < 0)
       y:=11

  ' draw
  tile_map0[(x+y<<4)<<1] := 1


  if (game_pad.button(NES0_START))
    repeat 100_000
    if (tile_map_base_ptr_parm == @tile_map0)
      tile_map_base_ptr_parm := @tile_map1
    else
      tile_map_base_ptr_parm := @tile_map0
{
  if (tile_status_bits_parm == 1)
    tile_status_bits_parm := 0
  else
    tile_status_bits_parm := 1
}

  ' delay to see it!
  repeat 20000
  ' // return back to repeat main event loop...
  

' parent COG will terminate now...

DAT

tile_maps     ' you place all your 16x12 tile maps here, you can have as many as you like, in real-time simply re-point the
              ' tile_map_base_ptr_parm to any time map and within 1 frame the tile map will update

tile_map0     ' 16x12 WORDS each, (0..191 WORDs, 384 bytes per tile map) 2-BYTE tiles (msb)[palette_index | tile_index](lsb)
              ' 16x12 tile map, each tile is 2 bytes, there are a total of 64 tiles possible, and thus 64 palettes              
              ' column     0      1      2      3      4      5      6      7      8      9     10     11     12     13     14     15
              word      $01_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$02_01 ' row 0
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
              word      $00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_01 ' row 11

tile_map1     ' 16x12 WORDS each, (0..191 WORDs, 384 bytes per tile map) 2-BYTE tiles (msb)[palette_index | tile_index](lsb)
              ' 16x12 tile map, each tile is 2 bytes, there are a total of 64 tiles possible, and thus 64 palettes              
              ' column     0      1      2      3      4      5      6      7      8      9     10     11     12     13     14     15
              word      $00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_01 ' row 0
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_02,$00_02,$00_02,$00_02,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_02,$00_00,$00_00,$00_02,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 4
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_02,$00_00,$00_00,$00_02,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 5
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_02,$00_02,$00_02,$00_02,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 6
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 7
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 8
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 9
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_01 ' row 11


' /////////////////////////////////////////////////////////////////////////////

tile_bitmaps
              ' tile bitmap memory, each tile 16x16 pixels, or 1 LONG by 16,
              ' 64-bytes each, only define 4 of them for now

tile_bitmap0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 0
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



tile_bitmap1  
              long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3 ' tile 1
              long      %%3_0_0_0_0_0_0_0_0_0_0_0_0_0_0_3
              long      %%3_0_0_0_0_0_0_0_0_0_0_0_0_0_0_3
              long      %%3_0_0_2_2_2_2_2_2_2_2_2_2_0_0_3
              long      %%3_0_0_2_0_0_0_0_0_0_0_0_2_0_0_3
              long      %%3_0_0_2_0_0_0_0_0_0_0_0_2_0_0_3
              long      %%3_0_0_2_0_0_1_1_1_1_0_0_2_0_0_3
              long      %%3_0_0_2_0_0_1_1_1_1_0_0_2_0_0_3
              long      %%3_0_0_2_0_0_1_1_1_1_0_0_2_0_0_3
              long      %%3_0_0_2_0_0_1_1_1_1_0_0_2_0_0_3
              long      %%3_0_0_2_0_0_0_0_0_0_0_0_2_0_0_3
              long      %%3_0_0_2_0_0_0_0_0_0_0_0_2_0_0_3
              long      %%3_0_0_2_2_2_2_2_2_2_2_2_2_0_0_3
              long      %%3_0_0_0_0_0_0_0_0_0_0_0_0_0_0_3
              long      %%3_0_0_0_0_0_0_0_0_0_0_0_0_0_0_3
              long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3

tile_bitmap2
              long      %%3_0_0_0_0_0_0_0_0_0_0_0_0_0_0_3 ' tile 2
              long      %%0_3_0_0_0_0_0_0_0_0_0_0_0_0_3_0
              long      %%0_0_3_0_0_0_0_0_0_0_0_0_0_3_0_0
              long      %%0_0_0_3_0_0_0_0_0_0_0_0_3_0_0_0
              long      %%0_0_0_0_3_0_0_0_0_0_0_3_0_0_0_0
              long      %%0_0_0_0_0_3_0_0_0_0_3_0_0_0_0_0
              long      %%2_2_2_0_1_0_3_0_0_3_0_0_0_0_0_0
              long      %%0_0_2_0_1_0_0_3_3_0_0_0_0_0_0_0
              long      %%0_2_0_0_1_0_0_3_3_0_0_0_0_0_0_0
              long      %%2_0_0_0_1_0_3_0_0_3_0_0_0_0_0_0
              long      %%2_2_2_0_1_3_0_0_0_0_3_0_0_0_0_0
              long      %%0_0_0_0_3_0_0_0_0_0_0_3_0_0_0_0
              long      %%0_0_0_3_0_0_0_0_0_0_0_0_3_0_0_0
              long      %%0_0_3_0_0_0_0_0_0_0_0_0_0_3_0_0
              long      %%0_3_0_0_0_0_0_0_0_0_0_0_0_0_3_0
              long      %%3_0_0_0_0_0_0_0_0_0_0_0_0_0_0_3

tile_bitmap3
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 3
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%2_0_2_2_2_0_2_0_0_0_2_2_2_2_0_0
              long      %%2_0_2_0_2_0_2_0_0_0_0_0_2_0_0_0
              long      %%2_0_2_2_2_0_2_0_0_0_0_0_2_0_0_0
              long      %%2_0_0_0_2_0_2_2_2_0_0_0_2_0_0_0
              long      %%2_0_0_0_2_0_2_0_2_0_0_0_2_0_0_0
              long      %%2_0_0_0_2_0_2_2_2_0_0_0_2_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

' /////////////////////////////////////////////////////////////////////////////

palette_map   ' 4 palettes for only now, palette memory (1..255) LONGs, each palette 4-BYTEs

              long $5C_5B_5A_02 ' palette 0
              long $0C_0B_0A_02 ' palette 1
              long $CC_CB_CA_02 ' paleete 2
              long $0C_0B_0A_02 ' palette 3
                

            


' /////////////////////////////////////////////////////////////////////////////
' ASSEMBLY LANGUAGE VIDEO DRIVER
' /////////////////////////////////////////////////////////////////////////////

CON

  FNTSC         = 3_579_545      ' NTSC color clock frequency in HZ
  LNTSC         = (220*16)       ' NTSC color cycles per line (220-227) * 16
  SNTSC         = (44*16)        ' NTSC color cycles per sync (39-44) * 16
  VNTSC         = (LNTSC-SNTSC)  ' NTSC color cycles per active video * 16
  PNTSC256      = (VNTSC >> 4)   ' NTSC color cycles per "compressed/expanded" on screen pixel
                                 ' allows us to put more or less pixels on the screen, but
                                 ' remember NTSC is 224 visible pixels -- period, so when we display more
                                 ' than 224 per line then we are getting chroma distortion on pixel boundaries
                                 ' a more recommended method for cleaner graphics is about 180-190 pixels horizontally
                                 ' this way you don't overdrive the chroma bandwidth which limits colors to 224
                                 ' color clocks per screen
                                 ' currently set for 16, 16 wide tiles per line


  VIDEO_PINMASK  = %0000_0111   ' vcfg S = pinmask  (pin31 ->0000_0111<-pin24), only want lower 3-bits
  VIDEO_PINGROUP = 3            ' vcfg D = pingroup (Hydra uses group 3, pins 24-31)
  VIDEO_SETUP   = %0_10_1_01_000' vcfg I = controls overall setting, we want baseband video on bottom nibble, 2-bit color, enable chroma on broadcast & baseband
  VIDEO_CNTR_SETUP = %00001_111 ' pll internal routed to Video, PHSx+=FRQx (mode 1) + pll(16x)
                                ' needn't set D,S fields since they set pin A/B I/Os, but mode 1 is internal, thus irrelvant

  ' tile engine status bits/masks
  TILE_STATUSB_VSYNC = (%00000001) ' VSync bitmask

  ' register indexes
  CLKFREQ_REG = 0                ' register address of global clock frequency

  ' debuging stuff
  DEBUG_LED_PORT_MASK = $00000001 ' debug LED is on I/O P0


DAT
                org $000  ' set the code emission for COG add $000

' /////////////////////////////////////////////////////////////////////////////
' Entry point
' /////////////////////////////////////////////////////////////////////////////

HEL_Video_Driver_Entry
' welcome to HEL...
' 16x12 tiles with 16x16 pixel tiles, each with its own 4-color palette
' screen space designed such that left and right most tiles extend into overscan areas

' ASM written to be clean, fast, easy to understand, but not overly optimized, it was like 50 lines
' of code before, but unintelligble, this is much easier to understand! Now its like 80-85 lines :)


              ' VCFG: setup Video Configuration register and 3-bit TV DAC pins to outputs
                        
              movs    vcfg, #VIDEO_PINMASK              ' vcfg S = pinmask  (pin31 ->0000_0111<-pin24), only want lower 3-bits
              movd    vcfg, #VIDEO_PINGROUP             ' vcfg D = pingroup (Hydra uses group 3, pins 24-31)
              movi    vcfg, #VIDEO_SETUP                ' vcfg I = controls overall setting, we want baseband video on bottom nibble, 2-bit color, enable chroma on broadcast & baseband
              or      dira, tvport_mask                 ' set DAC pins to output 24, 25, 26

              ' CTRA: setup Frequency to Drive Video                        
              movi    ctra, #VIDEO_CNTR_SETUP           ' pll internal routed to Video, PHSx+=FRQx (mode 1) + pll(16x)
                                                        ' needn't set D,S fields since they set pin A/B I/Os, but mode 1 is internal, thus irrelvant

              ' compute the value to place in FREQ such that the final counter
              ' output is NTSC and the PLL output is 16*NTSC
              mov     r1, v_freq                        ' r1 <- TV color burst frequency in Hz, eg. 3_579_545                                             
              rdlong  r2, #CLKFREQ_REG                  ' r2 <- CLKFREQ is register 0, eg. 80_000_000
              call    #Dividefract                      ' perform r3 = 2^32 * r1 / r2
              mov     frqa, r3                          ' set frequency for counter such that bit 31 is toggling at a rate of the color burst (2x actually)
                                                        ' which means that the freq number added at a rate of CLKFREQ (usually 80.000 Mhz) results in a
                                                        ' pll output of the color burst, this is further multiplied by 16 as the final PLL output
                                                        ' thus giving the chroma hardware the clock rate of 16X color burst which is what we want :)


              mov       r0, par                         ' copy boot parameter value and read in parameters from main memory, must be on LONG boundary
              add       r0, #12
              mov       tile_status_bits_ptr, r0        ' ptr to status bits, so tile engine can pass out status of tile engine in real time


Next_Frame    ' start of new frame of 262 scanlines
              ' 26 top overscan
              ' 192 active vide
              ' 26 bottom overscan
              ' 18 vertical sync
                      
              ' read run-time parameters from main memory, user can change these values every frame
              mov       r0, par                         ' copy boot parameter value and read in parameters from main memory, must be on LONG boundary
              rdlong    tile_map_base_ptr, r0           ' base ptr to tile map itself
              add       r0, #4
              rdlong    tile_bitmaps_base_ptr, r0       ' base pointer to array of 16x16 bitmaps, each 64 bytes
              add       r0, #4
              rdlong    tile_palettes_base_ptr, r0      ' base pointer to array of palettes, each palette 4 bytes / 1 long

              mov       r0, #0                          ' clear out status bits for next frame
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory


' /////////////////////////////////////////////////////////////////////////////
Top_Overscan_Scanlines

              mov     r1, #26                           ' set # of scanlines

' Horizontal Scanline Loop (r1 itterations)
:Next_Scanline
        
              ' HSYNC 10.9us (Horizontal Sync) including color burst
              mov     vscl, v_shsync                    ' set the video scale register such that 16 serial pixels takes 39 color clocks (the total time of the hsync and burst)
              waitvid v_chsync, v_phsync                ' send out the pixels and the colors, the pixels are 0,1,2,3 that index into the colors, the colors are blank, sync, burst
                                                        ' we use them to create the hsync pulse itself
              
              ' HVIS 52.6us (Visible Scanline) draw 16 huge pixels
              mov     vscl, v_shvis                     ' set up the video scale so the entire visible scan is composed of 16 huge pixels
              waitvid v_choverscan , v_phoverscan       ' draw 16 pixels with red and blues
              
              djnz    r1, #:Next_Scanline               ' are we done with the scanlines yet?

' /////////////////////////////////////////////////////////////////////////////
Active_Scanlines

                                
              mov     r1, #0                            ' reset scanline counter, in this case we count up

' Horizontal Scanline Loop (r1 itterations)
:Next_Scanline
        
              ' HSYNC 10.9us (Horizontal Sync) including color burst
              mov     vscl, v_shsync                    ' set the video scale register such that 16 serial pixels takes 39 color clocks (the total time of the hsync and burst)
              waitvid v_chsync, v_phsync                ' send out the pixels and the colors, the pixels are 0,1,2,3 that index into the colors, the colors are blank, sync, burst
                                                        ' we use them to create the hsync pulse itself
                       
' /////////////////////////////////////////////////////////////////////////////

              ' this next section retrives the tile index, palette index for each tile and draws a single line of video composed of 1 sub
              ' scan line of each tile, the opportunity here is to realize that each tile accessed 16 times, once for each video line, thus
              ' the tile indexes and palettes themselves could be "cached" to save time, however, the added complexity is not needed yet
              ' but the next version will cache the data, so we can have more time per pixel block to do crazy stuff :)

              mov     vscl, v_spixel                    ' set up video scale register for 16 pixels at a time

              ' select proper sub-tile row address
              mov       r2, r1                          ' r1 holds current video line of active video (0..191)
              and       r2, #$0F                        ' r2 = r1 mod 16, this is the sub-row in the tile we want to render, or the LONG index we need to offset the tile memory by

              ' access main memory can get the bitmap data
              shl       r2, #2                          ' r2 = r2*4, byte based row offset of pixels
              add       r2, tile_bitmaps_base_ptr       ' r2 = tile_bitmaps_base_ptr + r2
                                                                                
              ' compute tile index itself for left edge of tile row, inner loop will index across as the scanline is rendered
              mov       tile_map_index_ptr, r1          
              and       tile_map_index_ptr, #$1F0             ' tile_map_index_ptr = [(r1 / 16) * 16], this is the starting tile index for a row, 0, 16, 32, ...
              shl       tile_map_index_ptr, #1                ' tile_map_index_ptr = tile_index*2, since each tile is 2 bytes, we need to convert index to byte address
              add       tile_map_index_ptr, tile_map_base_ptr ' tile_map_index_ptr = [(r1 / 16) * 16] + tile_map_base_ptr, this is a byte address in main memory now
              

              ' at this point we have everything we need for the pixels rendering aspect of the 16 tiles that will be rendered, the inner loop logic will
              ' retrieve the time map indexes, and access the 16 pixels that make up each row of each tile, BUT we need to get the palette(s)
              ' for each tile as well, each tile has its own palette, but the palette will change each group of 16-pixels across the screen since
              ' each 16-pixels represents a single line from a different tile

              ' we could cache all the palettes into the local cache, but for fun let's just read them out of main memory during the inner loop
                  
              ' render the 16 tile lines, r2 is holding proper row address, but we need to add base of actual tile we want rendered
              mov       r4, #16

:Pixel_Render_Loop

              ' read next tile index and palette index from main memory
              rdword    tile_map_word, tile_map_index_ptr
              
              ' retrieve 16-pixels of current row from proper bitmap referenced by tile
              mov       r3, tile_map_word
              and       r3, #$FF                        ' mask off upper 8-bits they hold the palette index, we aren't interested in
              shl       r3, #6                          ' r3 = tile_map_index*64 (bytes)
              add       r3, r2                          ' r3 = tile_map_index*64 + tile_bitmaps_base_ptr + video_line mod 16
              rdlong    r3, r3                          ' r3 = main_memory[r3], retrieve 32 bits of pixel data
                                                        ' 16 clocks until hub comes around, try and be ready, move a couple instructions that aesthically
                                                        ' should be in one place between the hub reads to maximize processing/memory bandwith
                                                        
              mov       v_pixels_buffer, r3             ' r3 holds pixels now, copy to pixel out buffer

              ' retrieve palette for current tile
              mov       r5, tile_map_word
              shr       r5, #8                          ' r5 now holds the palette index and we shifted out the tile index into oblivion
              shl       r5, #2                          ' multiple by 4, since there ar 4-bytes per palette entry
                                                        ' r5 = palette_map_index*4
              add       r5, tile_palettes_base_ptr      ' r5 = palette_map_base_ptr +palette_map_index*4

              ' moved from top of loop to eat time after previous memory read!
              add       tile_map_index_ptr, #2          ' advance pointer 2 bytes to next tile map index entry, for next pass

              rdlong    v_colors_buffer, r5             ' read the palette data into the buffer

              'draw the pixels with the selected palette
              waitvid   v_colors_buffer, v_pixels_buffer


              djnz      r4, #:Pixel_Render_Loop         ' loop until we draw 16 tiles (single pixel row of each)

' /////////////////////////////////////////////////////////////////////////////

              add       r1, #1                          
              cmp       r1, #192                  wc, wz
        if_b  jmp       #:Next_Scanline                 ' if ++r1 (current line) < 192 then loop
        

' /////////////////////////////////////////////////////////////////////////////

Bottom_Overscan_Scanlines
                                 
              mov       r1, #26                         ' set # of scanlines

' Horizontal Scanline Loop (r1 itterations)
:Next_Scanline
                      
              ' HSYNC 10.9us (Horizontal Sync) including color burst
              mov       vscl, v_shsync                  ' set the video scale register such that 16 serial pixels takes 39 color clocks (the total time of the hsync and burst)
              waitvid   v_chsync, v_phsync              ' send out the pixels and the colors, the pixels are 0,1,2,3 that index into the colors, the colors are blank, sync, burst
                                                        ' we use them to create the hsync pulse itself
                        

              ' HVIS 52.6us (Visible Scanline) draw 16 huge pixels that represent an entire line of video
              mov       vscl, v_shvis                   ' set up the video scale so the entire visible scan is composed of 16 huge pixels
              waitvid   v_choverscan , v_phoverscan     ' draw 16 pixels with red and blues

                                     
              djnz      r1, #:Next_Scanline             ' are we done with the scanlines yet?

' /////////////////////////////////////////////////////////////////////////////
Vsync_Pulse

              ' VSYNC Pulse (Vertical Sync)
              ' 18 scanlines: 6 'high syncs', 6 'low syncs', and finally another 6 'high syncs'
              ' refer to NTSC spec, but this makes up the equalization pulses needed for a vsync

              call      #Vsync_High
              call      #Vsync_Low
              call      #Vsync_High
                        
              jmp       #Next_Frame                     ' that's it, do it a googleplex times...
                        
'//////////////////////////////////////////////////////////////////////////////
' SUB-ROUTINES VARIABLE DECLARATIONS
'//////////////////////////////////////////////////////////////////////////////

' /////////////////////////////////////////////////////////////////////////////
' vsync_high: Generate 'HIGH' vsync signal for 6 horizontal lines.
Vsync_High              
                               
              mov       r1, #6
                        
              ' HSYNC 10.9us (Horizontal Sync)
:Vsync_Loop   mov       vscl, v_shsync
              waitvid   v_chsync, v_pvsync_high_1

              ' HVIS 52.6us (Visible Scanline)
              mov       vscl, v_shvis
              waitvid   v_chsync, v_pvsync_high_2
              djnz      r1, #:Vsync_Loop

Vsync_High_Ret
              ret

' /////////////////////////////////////////////////////////////////////////////
' vsync_low: Generate 'LOW' vsync signal for 6 horizontal lines.
Vsync_Low
                               
              mov       r1, #6
                        
              ' HSYNC 10.9us (Horizontal Sync)
:Vsync_Loop   mov       vscl, v_shsync
              waitvid   v_chsync, v_pvsync_low_1

              ' HVIS 52.6us (Visible Scanline)
              mov       vscl, v_shvis
              waitvid   v_chsync, v_pvsync_low_2
              djnz      r1, #:Vsync_Loop

Vsync_Low_Ret
              ret

' /////////////////////////////////////////////////////////////////////////////
' Calculates 2^32 * r1/r2, result stored in r3, r1 must be less that r2, that is, r1 < r2
' the results of the division are a binary weighted 32-bit fractional number where each bit
' is equal to the following weights:
' MSB (31)    30    29 ..... 0
'      1/2   1/4   1/8      1/2^32
Dividefract                                     
              mov       r0,#32+1                        ' 32 iterations, are we done yet?
:Loop         cmpsub    r1,r2           wc              ' does divisor divide into dividend?
              rcl       r3,#1                           ' rotate carry into result
              shl       r1,#1                           ' shift dividend over
              djnz      r0,#:Loop                       ' done with division yet?

Dividefract_Ret
              ret                                       ' return to caller with result in r3

'//////////////////////////////////////////////////////////////////////////////
' VARIABLE DECLARATIONS
'//////////////////////////////////////////////////////////////////////////////

' general purpose registers
                        
r0            long      $0                             
r1            long      $0
r2            long      $0
r3            long      $0
r4            long      $0
r5            long      $0
                                           
' tv output DAC port bit mask
tvport_mask   long      %0000_0111 << 24        ' Hydra DAC is on bits 24, 25, 26


' output buffers to hold colors and pixels, start them off with "test" data
                        '3  2  1  0   <- color indexes
v_pixels_buffer long    %%1111222233330000
v_colors_buffer long    $5C_CC_0C_03            ' 3-RED | 2-GREEN | 1-BLUE | 0-BLACK

' pixel VSCL value for 256 visible pixels per line (clocks per pixel 8 bits | clocks per frame 12 bits )
v_spixel      long      ((PNTSC256 >> 4) << 12) + PNTSC256


' hsync VSCL value (clocks per pixel 8 bits | clocks per frame 12 bits )
v_shsync      long      ((SNTSC >> 4) << 12) + SNTSC

' hsync colors (4, 8-bit values, each represent a color in the format chroma shift, chroma modulatation enable, luma | C3 C2 C1 C0 | M | L2 L1 L0 |
                        '3  2  1  0   <- color indexes
v_chsync      long      $00_00_02_8A ' SYNC (3) / SYNC (2) / BLACKER THAN BLACK (1) / COLOR BURST (0)

' hsync pixels
                        ' BP  |BURST|BW|    SYNC      |FP| <- Key BP = Back Porch, Burst = Color Burst, BW = Breezway, FP = Front Porch
v_phsync      long      %%1_1_0_0_0_0_1_2_2_2_2_2_2_2_1_1

' active video values
v_shvis       long      ((VNTSC >> 4) << 12) + VNTSC

' the colors used, 4 of them always
                        'red, color 3 | dark blue, color 2 | blue, color 1 | light blue, color 0
v_chvis       long      $5A_0A_0B_0C            ' each 2-bit pixel below references one of these 4 colors, (msb) 3,2,1,0 (lsb)

' the pixel pattern                             
v_phvis       long      %%3210_0123_3333_3333   ' 16-pixels, read low to high is rendered left to right, 2 bits per pixel
                                                ' the numbers 0,1,2,3 indicate the "colors" to use for the pixels, the colors
                                                ' are defined by a single byte each with represents the chroma shift, modulation,
                                                ' and luma
' the colors used, 4 of them always
                        'grey, color 3 | dark grey, color 2 | blue, color 1 | black, color 0
v_choverscan  long      $06_04_0B_03            ' each 2-bit pixel below references one of these 4 colors, (msb) 3,2,1,0 (lsb)

' the pixel pattern
v_phoverscan  long      %%1111_1111_1111_1111   ' 16-pixels, read low to high is rendered left to right, 2 bits per pixel
                                                ' the numbers 0,1,2,3 indicate the "colors" to use for the pixels, the colors
                                                ' are defined by a single byte each with represents the chroma shift, modulation,
                                                ' and luma

' vsync pulses 6x High, 6x Low, 6x High
' the vertical sync pulse according to the NTSC spec should be composed of a series
' of pulses called the pre-equalization, serration pulses (the VSYNC pulse itself), and the post-equalization pulses
' there are 6 pulses of each, and they more or less inverted HSYNC, followed by 6 HSYNC pulses, followed by 6 more inverted HSYNC pulses.
' this keeps the horizontal timing circutry locked as well as allows the 60 Hz VSYNC filter to catch the "vsync" event.
' the values 1,2 index into "colors" that represent sync and blacker than black.
' so the definitions below help with generated the "high" and "low" dominate HSYNC timed pulses which are combined
' to generated the actual VSYNC pulse, refer to NTSC documentation for more details.
                                
v_pvsync_high_1         long    %%1_1_1_1_1_1_1_1_1_1_1_2_2_2_1_1  
v_pvsync_high_2         long    %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
                                
v_pvsync_low_1          long    %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_1_1
v_pvsync_low_2          long    %%1_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
  
v_freq                  long    FNTSC

' tile engine locals
tile_row                long    $0
video_line              long    $0
tile_map_ptr            long    $0
tile_cache_ptr          long    $0
palette_cache_ptr       long    $0
tile_map_index          long    $0
tile_map_index_ptr      long    $0
tile_map_word           long    $0
tile_palette_index      long    $0

' tile engine passed parameters
tile_map_base_ptr       long    $0
tile_bitmaps_base_ptr   long    $0
tile_palettes_base_ptr  long    $0
tile_status_bits_ptr    long    $0

' local COG cache memories (future expansion)
tile_cache              word    $0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
palette_cache           long    $0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0

' END ASM /////////////////////////////////////////////////////////////////////



{ // code prototyping area


word tile_cache[16];    // holds the cached tiles for a row of tiles
long palette_cache[16]; // hold the cached palettes for a row of tiles

// render frame 262 lines composed of top overscan, active video, bottom overscan, vertical sync

// render top overscan with overscan color
for (line = 0; line < 26; line++)

// render active video area
for (line = 0; line < 192; line++)
    {
    // start line with hsync
    Wait_Hsync();

    // at this point we have 39 color clocks to work, or a total of 872 system clocks or 218 instructions roughly
    // step 1: read current tile row out of main memory into local cache

    // compute current row
    curr_row = line / 16;

    // final address of 16-bit tile equals base address plus the row*2 (2 bytes per tile)
    tile_row_base_ptr := tile_memory_base + curr_row*2

    // now copy the tiles into the tile cache from main memory, assumes tile memory starts at long base address!
    // copies 2 tiles at a time to maximize 32-bit architecture
    tile_cache_ptr = (long)tile_cache;

    for (index = 0; index < 8; index++)
         {
         ((long *)tile_cache_ptr)[index] := ((long *)tile_row_base_ptr)[index];
         } // end for index

    // step 2: read the palettes out of main memory that are referred to

    for (index = 0; index < 16; index++)
         {
         // read palette index out
         (word)palette_index = (word)tile_cache[index] >> 8;
   
         // read palette out of main memory into cache
         palette_cache[index] = (long *)palette_base_ptr + palette_index

         } // end for index


    // render the 16 tiles now...
    // get pixel data, waitvid loop

    for (index = 0; index < 16; index++)
         {
         pixel_data = tile_bitmap_base + (tile_cache[index] && 0xff) * 32 * 4
         color_data = palette_cache[ tile_cache[index] >> 8]
         Wait_Video();

         } // end for index

    } // end for line


// render bottom overscan with overscan color
for (line = 0; line < 26; line++)

// render top vertical sync
for (line = 0; line < 18; line++)



 {
 ' indirect addressing technique
              ' step 2: get pixels to render from tile memory
              movs    :read, #test_tile                 ' get base address of testtile memory
              add     :read, r2                         ' pointer r3 = test_tile[r2]
              nop
:read         mov     r3, 0                             ' above 2 instructions self modify "source" address, the only way read tables unfortuntely

}

 
}


{' TILE / PALETTE CACHING LOOP ////////////////////////////////////////////////
              
              ' now we have the hsync time (39-44) color clocks to do all our "caching" for this line of video, this amounts to 872ish main system clocks roughly
              ' but, remember there are 4 clocks per instruction, and 7..22 clocks per main memory access, so we have to be quick
              ' we can't cache everything, but we can cache the tiles for this line and the palettes for this line
              {
              tile_row = r1/4;
              }
              mov     tile_row, r1                                    
              shr     tile_row, #4                      ' tile_row = r1 / 16, which is the current tile row being rendered (0-11)
          
              ' now compute address of tile memory in main memory
              {
              tile_map_ptr = tile_map_base_ptr + tile_row*32 ' 32 bytes per row, 16 words, 16 tiles
              }
              mov tile_map_ptr, tile_map_base_ptr
              mov r2, tile_row
              shl r2, #5
              add tile_map_ptr, r2

                        
              ' at this point tile_memory_ptr points to the row of 16-WORD size tiles in main memory, each tile is 16-bit, so we can read
              ' 2 tiles per LONG access, thus we need 8 LONG memory reads, and of course the tile map itself is LONG aligned, so
              ' everything works out

              mov tile_cache_ptr, #tile_cache

              ' read 8 LONGs from the tile map in main memory and copy to local cache
              mov r4, #8

:Tile_Copy_To_Cache_Loop

              movd    :read, tile_cache_ptr             ' self modify destination operand of the "rdlong" opcode with the destination of read pointer
              nop
:read         rdlong  0, tile_map_ptr
              add     r2, #4                            ' main memory add 4 to get to next LONG, always BYTE addresses
              add     r3, #1                            ' r2 pointing to COG memory always LONG addresses
              djnz    r4, #:Tile_Copy_To_Cache_Loop





{
              ' initialize debug LED
              or  DIRA, #DEBUG_LED_PORT_MASK  ' set pin to output
              and OUTA, #!DEBUG_LED_PORT_MASK ' turn LED off to begin



             ' based on z turn LED on/off
        if_nz or  OUTA, #DEBUG_LED_PORT_MASK
        if_z  and OUTA, #!DEBUG_LED_PORT_MASK
}






}' END TILE / PALETTE CACHING LOOP /////////////////////////////////////////////
