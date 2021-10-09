' /////////////////////////////////////////////////////////////////////////////
' TITLE: INVADERS_DEMO_002.SPIN -  
'
' DESCRIPTION:  
'
' VERSION: 1.0
' AUTHOR: Andre' LaMothe
' LAST MODIFIED:
' COMMENTS:
'
' CONTROLS: Gamepad, right left moves player back and forth


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

  ' base tile index for ship tiles, left to right, top to bottom, 8 tiles per 4 frame sub-tile motion with two
  ' rows; row 0 flame on, row 1 flame off
  SHIP_TILE_INDEX_BASE = $38

  ' missile constants
  NUM_MISSILES         = 10
  MISSILE_TILE_INDEX   = 72 ' base tile for missile animation

  ' missiles states
  MISSILE_STATE_DEAD          = 0 ' missile is dead
  MISSILE_STATE_FIREDBYPLAYER = 1 ' missile is in flight and fired by player
  MISSILE_STATE_FIREDBYENEMY  = 2 ' missile is in fligth and fired by an enemy

  ' alien robots
  NUM_BOTS = 9

  BOTS_FORMATION_X0 = 5     ' formation origin in world coords
  BOTS_FORMATION_Y0 = 1

  BOT_STATE_DEAD  = 0           ' bot is dead
  BOT_STATE_ALIVE = 1           ' bot is alive
  BOT_STATE_DYING = 2           ' bot is dying

  BOT_VMSTATE_FETCH   = 0       ' the bot virtual machine pattern interpreter is fetching an opcode
  BOT_VMSTATE_EXECUTE = 1       ' the bot virtual machine pattern interpreter is executing an opcode 

  NUM_BOT_PATTERNS = 1          ' how many patterns are there

  BOT_TYPE_0_TILE_BASE = 8      ' base tile index numbers for red, green, yellow bot animations 
  BOT_TYPE_1_TILE_BASE = 24
  BOT_TYPE_2_TILE_BASE = 40

  ' pattern commands, all have operands except for PCMD_FIRE, and PCMD_END which have implied operands
  PCMD_IDLE         = 0 ' format: {PCMD_IDLE, n}        - idles for n frames.             
  PCMD_FIRE         = 1 ' format: {PCMD_FIRE}           - fires straight down.          
  PCMD_RIGHT        = 2 ' format: {PCMD_RIGHT, n}       - moves right n frames. 
  PCMD_LEFT         = 3 ' format: {PCMD_LEFT, n}        - moves left n frames.
  PCMD_UP           = 4 ' format: {PCMD_UP, n}          - moves up n frames.
  PCMD_DOWN         = 5 ' format: {PCMD_DOWN, n}        - moves down n frames.
  PCMD_TRACK        = 6 ' format: {PCMD_TRACK, n}       - tracks player for n frames.
  PCMD_EVADE        = 7 ' format: {PCMD_EVADE, n}       - evades player for n frames.
  PCMD_JMP          = 8 ' format: {PCMD_JMP, n}         - set pattern IP or index to n.
  PCMD_END          = 9 ' format: {PCMD_END}            - ends program.  

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
long ship_x, ship_y                                     ' position of ship
long ship_anim_count                                    ' counter for animation to take place
long ship_anim_frame                                    ' frame of animation (0 or 1) flames, no flames :)

long curr_count                                         ' saves counter

long back_tile_buffer, front_tile_buffer                ' pointer to tile map base addr to make access easy

' use parallel arrays for missile data structure instead of indexed arrays this time
byte missile_state[NUM_MISSILES]                        ' state of missiles 0=dead, 1=in flight, fired by player, 2=in flight fired by alien
byte missile_x[NUM_MISSILES]                            ' x position of missile
byte missile_y[NUM_MISSILES]                            ' y position of missile
byte missile_frame[NUM_MISSILES]                        ' current frame of missile
byte fire_debounce                                      ' fire button debounce flag

' use parallel arrays for alien robots
byte bot_state[NUM_BOTS]                                ' state of bot, 0=dead, 1=alive, 2=dying
byte bot_type[NUM_BOTS]                                 ' type of bot, 0, 1, 2 controls what the bot looks like
byte bot_x[NUM_BOTS]                                    ' x position of bot
byte bot_y[NUM_BOTS]                                    ' y position of bot
byte bot_frame[NUM_BOTS]                                ' current frame of bot                        
byte bot_frame_cnt[NUM_BOTS]                            ' frame update counter

byte bot_vmstate[NUM_BOTS]                              ' state of the bot virtual machine, 0=fetch, 1=executing
byte bot_opcode[NUM_BOTS]                               ' current opcode bot is processing
byte bot_pattern_index[NUM_BOTS]                        ' index into pattern, like an instruction pointer or IP
byte bot_counter[NUM_BOTS]                              ' general counter
word bot_pattern_ptr[NUM_BOTS]                          ' pointer to pattern program base

long bot_index                                          ' used for looping

' going to use a true double buffered tile map in this demo for fun
' tile map itself, original
' tile_map_buffer1 - rendering into this buffer
' tile_map_buffer2 - rasterizing from this buffer
' then swap the buffers each frame
word tile_map_buffer1[32*12], tile_map_buffer2[32*12] 

long random_var                                         ' global random variable

'//////////////////////////////////////////////////////////////////////////////
'OBJS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

OBJ

game_pad :      "gamepad_drv_001.spin"
gfx:            "HEL_GFX_ENGINE_040.SPIN"
tile_data:      "invaders_tile_data3.spin" 

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

' initialize random variable
random_var := cnt*171732
random_var := ?random_var

' set up tile and sprite engine data before starting it, so no ugly startup
' points ptrs to actual memory storage for tile engine
' point everything to the "tile_data" object's data which are retrieved by "getter" functions
tile_map_base_ptr_parm        := tile_data.tile_maps
tile_bitmaps_base_ptr_parm    := tile_data.tile_bitmaps
tile_palettes_base_ptr_parm   := tile_data.tile_palette_map

' these control the sprite engine, all 0 for now, no sprites, map 32 wide
tile_map_sprite_cntrl_parm    := $00_01 ' 0 sprites, tile map set to 0=16 tiles wide, 1=32 tiles, 2=64 tiles, etc.
tile_sprite_tbl_base_ptr_parm := 0 
tile_status_bits_parm         := 0

' pointer pointer to base address of tile map
back_tile_buffer              := @tile_map_buffer1
front_tile_buffer             := @tile_map_buffer2

' initialize scrolling vars
scroll_x := 0
scroll_y := 0

' initialize player vars
ship_x     := 4
ship_y     := 11

' initialize all missile states to "dead"
wordfill(@missile_state, 0, NUM_MISSILES)

' initialize bots all to same startup pattern0 
repeat bot_index from 0 to NUM_BOTS - 1
  ' start bots in 3 x n formation
  bot_state[bot_index]         := BOT_STATE_ALIVE
  bot_type[bot_index]          := bot_index / 3                    
  bot_x[bot_index]             := BOTS_FORMATION_X0 + (bot_index // 3)*2                       
  bot_y[bot_index]             := BOTS_FORMATION_Y0 + (bot_index / 3)                         
  bot_frame[bot_index]         := 0                                           
  bot_frame_cnt[bot_index]     := 0              

  bot_vmstate[bot_index]       := BOT_VMSTATE_FETCH ' set VM to fetch an instruction for execution
  bot_opcode[bot_index]        := 0 
  bot_pattern_index[bot_index] := 0      
  bot_counter[bot_index]       := 0           
  bot_pattern_ptr[bot_index]   := @bot_pattern_0 ' bot_pattern_ptrs [ Rand_Range(0, NUM_BOT_PATTERNS-1) ]              

' launch a COG with ASM video driver
gfx.start(@tile_map_base_ptr_parm)

' enter main event loop...
repeat while 1

  ' copy tile map data to back buffer
  wordmove(back_tile_buffer, tile_data.tile_maps, 32*12)  
  
  ' main even loop code here...
  curr_count := cnt ' save current counter value

  ' process each alien bot ////////////////////////////////////////////////////
  repeat bot_index from 0 to NUM_BOTS - 1
    ' process each bot
    if ( bot_state[ bot_index ] <> BOT_STATE_DEAD)
      ' process alive and dying states    

      ' test state of bot vm - fetch or execute?
      if (bot_vmstate[bot_index] == BOT_VMSTATE_FETCH)
        ' fetch next opcode, leave instruction index on opcode though
         bot_opcode[bot_index] := byte[ bot_pattern_ptr[bot_index] ] [ bot_pattern_index[bot_index] ]  

      ' now process (or continue processing current opcode)
      case (bot_opcode[bot_index])          


        PCMD_IDLE:          ' format: {PCMD_IDLE, n} - idles for n frames.             
          ' if instruction was just fetched, then fetch operand and prepare to execute
          if (bot_vmstate[bot_index] == BOT_VMSTATE_FETCH)
            ' fetch path
            ' need to retrieve parameter and store in counter
            bot_counter[bot_index] := byte[ bot_pattern_ptr[bot_index] ] [ bot_pattern_index[bot_index] + 1 ]                                     
            ' set vmstate to execute
            bot_vmstate[bot_index] := BOT_VMSTATE_EXECUTE    
          else
            ' execute path
            ' decrement frame counter
            if (bot_counter[bot_index]-- < 1)
              ' time is up, done with instruction, fetch another, next time around
              bot_vmstate[bot_index] := BOT_VMSTATE_FETCH                                                        
              ' advance instruction index past opcode and operand
              bot_pattern_index[bot_index] += 2                           


        PCMD_FIRE:          ' format: {PCMD_FIRE} - fires straight down.          
          ' if instruction was just fetched, then fetch operand and prepare to execute
          if (bot_vmstate[bot_index] == BOT_VMSTATE_FETCH)
            ' fetch path
            Fire_Missile(bot_x[bot_index], bot_y[bot_index], MISSILE_STATE_FIREDBYENEMY)
            ' advance instruction index past opcode, leave in fetch mode to get next instruction
            ' since we can immediately process the fire command
            bot_pattern_index[bot_index] += 1                           


        PCMD_RIGHT:         ' format: {PCMD_RIGHT, n} - moves right n frames. 
          ' if instruction was just fetched, then fetch operand and prepare to execute

          if (bot_vmstate[bot_index] == BOT_VMSTATE_FETCH)
            ' fetch path
            ' need to retrieve parameter and store in counter
            bot_counter[bot_index] := byte[ bot_pattern_ptr[bot_index] ] [ bot_pattern_index[bot_index] + 1 ]                                     
            ' set vmstate to execute
            bot_vmstate[bot_index] := BOT_VMSTATE_EXECUTE    

          else
            ' execute path
            ' decrement frame counter
            if (bot_counter[bot_index]-- < 1)
              ' time is up, done with instruction, fetch another, next time around
              bot_vmstate[bot_index] := BOT_VMSTATE_FETCH
              ' advance instruction index past opcode and operand
              bot_pattern_index[bot_index] += 2                           
              
            else
              ' execute command
              bot_x[bot_index]++                                                          


        PCMD_LEFT:          ' format: {PCMD_LEFT, n} - moves left n frames.

          ' if instruction was just fetched, then fetch operand and prepare to execute
          if (bot_vmstate[bot_index] == BOT_VMSTATE_FETCH)
            ' fetch path
            ' need to retrieve parameter and store in counter
            bot_counter[bot_index] := byte[ bot_pattern_ptr[bot_index] ] [ bot_pattern_index[bot_index] + 1 ]                                     
            ' set vmstate to execute
            bot_vmstate[bot_index] := BOT_VMSTATE_EXECUTE    
          else
            ' execute path
            ' decrement frame counter
            if (bot_counter[bot_index]-- < 1)
              ' time is up, done with instruction, fetch another, next time around
              bot_vmstate[bot_index] := BOT_VMSTATE_FETCH
              ' advance instruction index past opcode and operand
              bot_pattern_index[bot_index] += 2                           
            else
              ' execute command
              bot_x[bot_index]--                                                          


        PCMD_UP:            ' format: {PCMD_UP, n} - moves up n frames.

          ' if instruction was just fetched, then fetch operand and prepare to execute
          if (bot_vmstate[bot_index] == BOT_VMSTATE_FETCH)
            ' fetch path
            ' need to retrieve parameter and store in counter
            bot_counter[bot_index] := byte[ bot_pattern_ptr[bot_index] ] [ bot_pattern_index[bot_index] + 1 ]                                     
            ' set vmstate to execute
            bot_vmstate[bot_index] := BOT_VMSTATE_EXECUTE    
          else
            ' execute path
            ' decrement frame counter
            if (bot_counter[bot_index]-- < 1)
              ' time is up, done with instruction, fetch another, next time around
              bot_vmstate[bot_index] := BOT_VMSTATE_FETCH
              ' advance instruction index past opcode and operand
              bot_pattern_index[bot_index] += 2                           
            else
              ' execute command
              bot_y[bot_index]--                                                          

        PCMD_DOWN:          ' format: {PCMD_DOWN, n} - moves down n frames.
        
          ' if instruction was just fetched, then fetch operand and prepare to execute
          if (bot_vmstate[bot_index] == BOT_VMSTATE_FETCH)
            ' fetch path
            ' need to retrieve parameter and store in counter
            bot_counter[bot_index] := byte[ bot_pattern_ptr[bot_index] ] [ bot_pattern_index[bot_index] + 1 ]                                     
            ' set vmstate to execute
            bot_vmstate[bot_index] := BOT_VMSTATE_EXECUTE    
          else
            ' execute path
            ' decrement frame counter
            if (bot_counter[bot_index]-- < 1)
              ' time is up, done with instruction, fetch another, next time around
              bot_vmstate[bot_index] := BOT_VMSTATE_FETCH
              ' advance instruction index past opcode and operand
              bot_pattern_index[bot_index] += 2                           
            else
              ' execute command
              bot_y[bot_index]++                                                          

        PCMD_TRACK:         ' format: {PCMD_TRACK, n} - tracks player for n frames.
          ' if instruction was just fetched, then fetch operand and prepare to execute
          if (bot_vmstate[bot_index] == BOT_VMSTATE_FETCH)
            ' fetch path
            ' need to retrieve parameter and store in counter
            bot_counter[bot_index] := byte[ bot_pattern_ptr[bot_index] ] [ bot_pattern_index[bot_index] + 1 ]                                     
            ' set vmstate to execute
            bot_vmstate[bot_index] := BOT_VMSTATE_EXECUTE    
          else
            ' execute path
            ' decrement frame counter
            if (bot_counter[bot_index]-- < 1)
              ' time is up, done with instruction, fetch another, next time around
              bot_vmstate[bot_index] := BOT_VMSTATE_FETCH
              ' advance instruction index past opcode and operand
              bot_pattern_index[bot_index] += 2                           
            else
              ' execute command
              if (ship_x > bot_x[bot_index])
                bot_x[bot_index]++
              elseif (ship_x < bot_x[bot_index])
                bot_x[bot_index]--
                                                        
              if (ship_y > bot_y[bot_index])
                bot_y[bot_index]++
              elseif (ship_y < bot_y[bot_index])
                bot_y[bot_index]--

        PCMD_EVADE:         ' format: {PCMD_EVADE, n} - evades player for n frames.
          ' if instruction was just fetched, then fetch operand and prepare to execute
          if (bot_vmstate[bot_index] == BOT_VMSTATE_FETCH)
            ' fetch path
            ' need to retrieve parameter and store in counter
            bot_counter[bot_index] := byte[ bot_pattern_ptr[bot_index] ] [ bot_pattern_index[bot_index] + 1 ]                                     
            ' set vmstate to execute
            bot_vmstate[bot_index] := BOT_VMSTATE_EXECUTE    
          else
            ' execute path
            ' decrement frame counter
            if (bot_counter[bot_index]-- < 1)
              ' time is up, done with instruction, fetch another, next time around
              bot_vmstate[bot_index] := BOT_VMSTATE_FETCH
              ' advance instruction index past opcode and operand
              bot_pattern_index[bot_index] += 2                           
            else
              ' execute command
              if (ship_x > bot_x[bot_index])
                bot_x[bot_index]--
              elseif (ship_x < bot_x[bot_index])
                bot_x[bot_index]++
                                                        
              if (ship_y > bot_y[bot_index])
                bot_y[bot_index]--
              elseif (ship_y < bot_y[bot_index])
                bot_y[bot_index]++
                                                                                                                                                
        PCMD_JMP:           ' format: {PCMD_JMP, n} - set pattern IP or index to n.
          ' if instruction was just fetched, then fetch operand and prepare to execute
          if (bot_vmstate[bot_index] == BOT_VMSTATE_FETCH)
            ' fetch path
            ' need to retrieve parameter and store in pattern index this time
            bot_pattern_index[bot_index] := byte[ bot_pattern_ptr[bot_index] ] [ bot_pattern_index[bot_index] + 1 ]                                     

            ' leave state in fetch state, since vm has to retrieve next instruction since this was a jump

        PCMD_END:           ' format: {PCMD_END} - ends program.  
          ' if instruction was just fetched, then fetch operand and prepare to execute
          if (bot_vmstate[bot_index] == BOT_VMSTATE_FETCH)
            ' fetch path
            ' anything we want could go here, but for now, just select another pattern to play
            bot_vmstate[bot_index]       := BOT_VMSTATE_FETCH ' set VM to fetch an instruction for execution
            bot_opcode[bot_index]        := 0 
            bot_pattern_index[bot_index] := 0      
            bot_counter[bot_index]       := 0           
            bot_pattern_ptr[bot_index]   := @bot_pattern_0 ' bot_pattern_ptrs [Rand_Range(0, NUM_BOT_PATTERNS-1) ]              

      ' animate each bot
      if (++bot_frame_cnt[bot_index] > 10)
        ' reset counter advance frame
        bot_frame_cnt[bot_index] := 0
        if ( (bot_frame[bot_index]+=8) > 8)
          bot_frame[bot_index] := 0    

      ' bot environment collision detection
      if (bot_x[bot_index] > 14)
        bot_x[bot_index] := 1
      elseif (bot_x[bot_index] < 1 )
        bot_x[bot_index] := 14
        
      if (bot_y[bot_index] > 11)
        bot_y[bot_index] := 0
      elseif (~~bot_y[bot_index] < 0 )
        bot_y[bot_index] := 11

          
  ' end BOT VM /////////////////////////////////////////////////////////////////


  ' test for player movement right?
  if (game_pad.button(NES0_RIGHT) and ship_x < 16-2)
    ship_x++
    ' now perform scroll logic to move view window as player pushes against boundaries
    if ( ((scroll_x + 9 - ship_x) < 3) and (scroll_x < 16-10) )
      scroll_x++
  
  ' test for player movement left?       
  if (game_pad.button(NES0_LEFT) and ship_x > 1)
    ship_x--
    ' now perform scroll logic to move view window as player pushes against boundaries
    if ( ((ship_x - scroll_x) < 3) and (scroll_x > 0 ) )
      scroll_x--

  ' move missiles
  Move_Missiles

  ' is player firing a missile
  if ( (game_pad.button(NES0_A) or game_pad.button(NES0_B)) and fire_debounce == 0) 
     ' fire the missile
     Fire_Missile(ship_x, ship_y, MISSILE_STATE_FIREDBYPLAYER)
     ' set fire button debounce flag
     fire_debounce := 1

  elseif ( game_pad.button(NES0_A)==0 and game_pad.button(NES0_B)==0)
     ' test for fire button debounce        
      fire_debounce := 0
      
  ' update animation of flame!
  if (++ship_anim_count > 1)
    ' reset flame and frame
    ship_anim_count := 0
    if ( (ship_anim_frame += 8) > 8)
      ship_anim_frame := 0


  ' draw bots
  repeat bot_index from 0 to NUM_BOTS - 1
    if (bot_state[ bot_index ] <> BOT_STATE_DEAD) 
      ' draw each bot differently based on type, for now just animatio frames are different, but could be more complex later...
      if (bot_type[bot_index] == 0)
        ' draw type 0 bot
        WORD[back_tile_buffer][ bot_x[bot_index] + bot_y[bot_index]*32] := (BOT_TYPE_0_TILE_BASE + bot_frame[bot_index]) << 8 | (BOT_TYPE_0_TILE_BASE + bot_frame[bot_index])        
        ' more specialized rendering code...
      elseif (bot_type[bot_index] == 1)
        ' draw type 1 bot
        WORD[back_tile_buffer][ bot_x[bot_index] + bot_y[bot_index]*32] := (BOT_TYPE_1_TILE_BASE + bot_frame[bot_index]) << 8 | (BOT_TYPE_0_TILE_BASE + bot_frame[bot_index])
        ' more specialized rendering code...
      elseif (bot_type[bot_index] == 2)
        ' draw type 2 bot
        WORD[back_tile_buffer][ bot_x[bot_index] + bot_y[bot_index]*32] := (BOT_TYPE_2_TILE_BASE + bot_frame[bot_index]) << 8 | (BOT_TYPE_0_TILE_BASE + bot_frame[bot_index])        
        ' more specialized rendering code...

  ' draw missiles
  Draw_Missiles
       
  ' draw player always, pay attention to how tiles are addressed and how the animation is performed by adding the offset to the 2nd row of tiles
  WORD[back_tile_buffer][ship_x + ship_y*32] := (SHIP_TILE_INDEX_BASE + ship_anim_frame)     << 8 | (SHIP_TILE_INDEX_BASE + ship_anim_frame) 

  ' flip pages 
  if (back_tile_buffer == @tile_map_buffer1)
    back_tile_buffer  := @tile_map_buffer2
    front_tile_buffer := @tile_map_buffer1
  else
    back_tile_buffer  := @tile_map_buffer1
    front_tile_buffer := @tile_map_buffer2

  ' update tile base memory pointer
  tile_map_base_ptr_parm := front_tile_buffer + scroll_x*2

   ' lock frame rate to 15-30 frames to slow this down
  waitcnt(cnt + 3*666_666)
      
  ' return back to repeat main event loop...

' parent COG will terminate now...if it gets to this point

' /////////////////////////////////////////////////////////////////////////////

Pub Rand_Range(rstart, rend) : r_delta
' returns a random number from [rstart to rend] inclusive
r_delta := rend - rstart + 1

result := rstart + ((?random_var & $7FFFFFFF) // r_delta)

return result

' /////////////////////////////////////////////////////////////////////////////
{
word missile_state[NUM_MISSILES]                        ' state of missiles 0=dead, 1=in flight
word missile_x[NUM_MISSILES]                            ' x position of missile
word missile_y[NUM_MISSILES]                            ' y position of missile
word missile_frame[NUM_MISSILES]                        ' current frame of missile
}
PUB Fire_Missile(mx, my, owner)
' scans for inactive missile and fires it from mx, my
' owner refers to player or enemy

repeat index from 0 to NUM_MISSILES - 1
  ' look for inactive missile...
  if ( missile_state[index] == 0)
    ' start this missile up
    missile_state[index] := owner                    ' state of missiles 0=dead, 1=in flight
    missile_x[index]     := mx                       ' x position of missile
    missile_y[index]     := my                       ' y position of missile
    missile_frame[index] := MISSILE_TILE_INDEX       ' current frame of missile
    quit ' terminate loop, we are done

' end Fire_Missile

' /////////////////////////////////////////////////////////////////////////////

PUB Draw_Missiles
' draws all the active missiles
repeat index from 0 to NUM_MISSILES - 1
  ' render if missile is active?
  if ( missile_state[index] <> MISSILE_STATE_DEAD)
    ' render missile
    WORD[back_tile_buffer][ missile_x[index] + missile_y[index]*32] := missile_frame[index] << 8 | missile_frame[index]    

' end Draw_Missiles

' /////////////////////////////////////////////////////////////////////////////

PUB Erase_Missiles
' erases all the active missiles

' end Erase_Missiles

' /////////////////////////////////////////////////////////////////////////////

PUB Move_Missiles
' moves all the active missiles and tests for collision

repeat index from 0 to NUM_MISSILES - 1
  ' process missile is active?
  if ( missile_state[index] <> MISSILE_STATE_DEAD)
    ' move and animate missile

    ' animate missile
    if (++missile_frame[index] > (MISSILE_TILE_INDEX+1))
      ' reset frame
      missile_frame[index] := MISSILE_TILE_INDEX      

    ' move missile based on type
    if (missile_state[index] == MISSILE_STATE_FIREDBYPLAYER )
      missile_y[index]--
      ' test for off screen? Notice use of BYTE size data, thus the need for sign extension operator "~"
      if (~missile_y[index] < 0)
        ' terminate missile
        missile_state[index] := MISSILE_STATE_DEAD

    ' move missile based on type
    elseif (missile_state[index] == MISSILE_STATE_FIREDBYENEMY )
      missile_y[index]++
      ' test for off screen? Notice use of BYTE size data, thus the need for sign extension operator "~"
      if (~missile_y[index] > 11)
        ' terminate missile
        missile_state[index] := MISSILE_STATE_DEAD

    ' test for collision with enemies would go here...

' end Move_Missiles


'//////////////////////////////////////////////////////////////////////////////
'DAT SECTION //////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

DAT 

{
  PCMD_IDLE         = 0 ' format: {PCMD_IDLE, n}        - idles for n frames.             
  PCMD_FIRE         = 1 ' format: {PCMD_FIRE}           - fires straight down.          
  PCMD_RIGHT        = 2 ' format: {PCMD_RIGHT, n}       - moves right n frames. 
  PCMD_LEFT         = 3 ' format: {PCMD_LEFT, n}        - moves left n frames.
  PCMD_UP           = 4 ' format: {PCMD_UP, n}          - moves up n frames.
  PCMD_DOWN         = 5 ' format: {PCMD_DOWN, n}        - moves down n frames.
  PCMD_TRACK        = 6 ' format: {PCMD_TRACK, n}       - tracks player for n frames.
  PCMD_JMP          = 7 ' format: {PCMD_JMP, n}         - set pattern IP or index to n.
  PCMD_END          = 8 ' format: {PCMD_END}            - ends program.  

}

' bot patterns
bot_pattern_0  byte PCMD_IDLE,10, PCMD_RIGHT,1, PCMD_DOWN,3, PCMD_RIGHT,1, PCMD_UP,3, PCMD_FIRE, PCMD_RIGHT,1, PCMD_DOWN,3, PCMD_RIGHT,1, PCMD_UP,3, PCMD_LEFT,4, PCMD_JMP,0        

' set up pointer array to all the patterns for ease of access
bot_pattern_ptrs long @bot_pattern_0 

              