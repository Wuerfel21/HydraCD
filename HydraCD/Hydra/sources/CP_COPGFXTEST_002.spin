' //////////////////////////////////////////////////////////////////////
' CopGFX Test                           
' AUTHOR: Colin Phillips
' LAST MODIFIED: 3.10.06
' VERSION 0.1
'
' DESCRIPTION:
' CopGFX - 2nd graphics engine test.
'
' NOTES: This is a 'bitmapped mode 7'. That is instead of referencing tiles,
' and retrieving pixels from the tileset. This is just outputting the tile
' value as a pixel value. Just to prove this works. Next step is to change
' this into a 'tilemapped mode 7'. Then add..
' - A window clip (esp vertical)
' - A Simple/Non-Scrolling Background layer.
' - Sprite Rasterizing System.
'
' Emphasis in this engine is for games that require a mode 7 layer, with
' a few sprites on top of the layer. e.g. Racing games.
' Also for simple games that dont require mode 7 (non-scrolling to platformers)
' with a LOT of sprites. e.g. Shoot Em Up's, Asteroids, Platformer games.
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x          ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000      ' set frequency to 10 MHZ plus some error    
  _memstart = $10                   ' memory starts $10 in!!! (this took 2 headaches to figure out)

  #0, h_copgfx_status, h_copgfx_vram
  
'///////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

VAR

LONG copgfx_status
LONG copgfx_vram
LONG copgfx_bg0_s                   ' start position
LONG copgfx_bg0_h                   ' horizontal vector
LONG copgfx_bg0_v                   ' vertical vector

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

OBJ
  copgfx : "copgfx_drv_001.spin"                        ' instantiate a copgfx object.
  tiles : "cp_copgfx_tiles_001.spin"                    ' tiles
'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB Start | x, y, i, n, dir, anim, frame, t
' this is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

  copgfx_vram := tiles.data
  copgfx.start(@copgfx_status)

  ' Initial Vectors Orthognal View origin (0,0)
  copgfx_bg0_s := $0000_0000
  copgfx_bg0_h := $0000_0100
  copgfx_bg0_v := $0100_0000                               

  frame := 0
  dir := 0
  repeat while TRUE
  
    ' Adjust Scale and Direction as a function of time.
    t := $200 + ($180*Sin(frame*2))~>16
    dir += 256 + (768*Sin(frame))~>16
    
    copgfx_bg0_h := GetVect((dir~>8),t/2)
    copgfx_bg0_v := GetVect((dir~>8)+64,t/2)
    
    ' Center View
    copgfx_bg0_s := $0000_0000
    copgfx_bg0_s -= copgfx_bg0_h * 128
    copgfx_bg0_s -= copgfx_bg0_v * 112

    frame++
    copgfx.waitvsync

' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

PUB Sin(x) : y | t
' y = sin(x)
t := x&63
if(x&64)
  t^=63

y := WORD[$E000 | t<<6]

if(x&128)
  y := -y

PUB GetVect(a,d) : v | x,y
' returns a 32-bit composite vector angle a, magnitude d.
x := (Sin(a)*d)~>16
y := (Sin(a+64)*d)~>16

v := y<<16 | x&$ffff