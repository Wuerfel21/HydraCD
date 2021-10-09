' //////////////////////////////////////////////////////////////////////
' COP Tutorial (Getting Started)
' AUTHOR: Colin Phillips
' LAST MODIFIED: 3.2.06
' VERSION 0.1
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x          ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000      ' set frequency to 10 MHZ plus some error    
  _stack   = 64                     ' stack
  _memstart = $10                   ' memory starts $10 in!!! (this took 2 headaches to figure out)

  obj_n           = 24                                  ' Number of Objects
  obj_size        = 6                                   ' registers per object.
  obj_total_size = (obj_n*obj_size)                     ' Total Number of registers (LONGS)

  OBJ_OFFSET_X  = 0
  OBJ_OFFSET_Y  = 1
  OBJ_OFFSET_W  = 2
  OBJ_OFFSET_H  = 3
  OBJ_OFFSET_I  = 4
  OBJ_OFFSET_M  = 5

  #0, h_cop_status, h_cop_control, h_cop_debug, h_cop_phase0, h_cop_monitor0, h_cop_monitor1, h_cop_config, h_cop_vram, h_cop_tile, h_cop_panx, h_cop_pany, h_cop_bgcolor, h_cop_obj

  FRAMERATE = 60                    ' 60FPS!!!
  
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
long  cop_obj[obj_total_size]       ' 24 sprites

' -----------------------------------------------------------------------------

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

OBJ
  cop   : "cop_drv_011.spin"                            ' instantiate a cop object - Color Co Processor
  tiles : "cp_coptut_tiles_001.spin"                    ' data object. (128x128 block of sprites)
  map   : "cp_coptut_map_001.spin"                      ' data object. (16x32 map)
  
'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB Start | debugled_dir, pan_dir
'' This is the first entry point the system will see when the PChip starts,
'' execution ALWAYS starts on the first PUB in the source code for
'' the top level file

  ' start cop engine
  cop.setup(tiles.data,128,128, $00, map.data)          ' pass parameters to tile data and map data.
  cop.start(@cop_status)                                ' start and boot two cogs
  
  cop_bgcolor := $00000000                              ' background color quadpixel BLACK.
  cop_pany := 0                                         ' map pan position (0,0)
  cop_debug := $0                                       ' initial debug led intensity (0%)
  debugled_dir := $04000000                             ' increment by 1/64th of full intensity. / frame
  pan_dir := 1                                          ' increase pan by 1 pixel. / frame

  repeat while TRUE
'' Clear Sprites for new Frame.
    cop.newframe

'' Draw a Sprite - centered position 128,120, dimensions 64x64, using VRAM source data 0,0
    cop.sprite(128-32,120-32,64,64,0,0)

'' Adjust Pan Y
    cop_pany += pan_dir
      if(cop_pany==-128)
        pan_dir := 1
      else
        if(cop_pany==128)
          pan_dir := -1

'' Adjust Debug LED
    cop_debug += debugled_dir                           
      if(cop_debug==0)
        debugled_dir := -debugled_dir
      else
        if(cop_debug==$fc000000)
          debugled_dir := -debugled_dir
        
'' Synchronize to the Vertical Sync of the COP Engine TV output.
    cop.waitvsync