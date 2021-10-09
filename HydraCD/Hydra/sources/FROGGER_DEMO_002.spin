' /////////////////////////////////////////////////////////////////////////////
' TITLE: FROGGER_DEMO_002.SPIN
'
' DESCRIPTION: A Frogger demo using Andre Lamothe's Hydra Extreme Tile Engine v4
'
' VERSION: 0.2
' AUTHOR: Terry Smith (Tile Engine: Andre' LaMothe)
' LAST MODIFIED: 10/2/06
' COMMENTS:
'
' CONTROLS: Uses gamepad
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

  ' GAME STATES
  GAME_STATE_START  = 0
  GAME_STATE_INGAME = 1
  GAME_STATE_WIN    = 2
  GAME_STATE_LOSS   = 3
  GAME_STATE_PAUSE  = 4
  
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
byte game_state                                         ' the game state (started, game over, etc.)
byte bx, bz                                             ' byte valued x,y
byte player_x, player_y                                 ' frogger position
byte life_count                                         ' count of remaining lives
byte frame_gp_delay                                     ' length of delay between processing gamepad input
byte start_button_delay                                 ' length of start button delay (to avoid troubles)
byte level                                              ' level of difficulty
byte message_delay                                      ' time delay for message
byte message_displayed                                  ' true/false for message diplayed
' note: the following positions are in tile values (ie. 3 = the 4th tile, not x = 4)
byte log_position[3]                                    ' first row of log positions
byte second_row_log_position[3]                         ' second row of log positions
long lily_position[3]                                   ' lily positions (must be long for comparisons < 0)
byte object_delays[3]                                   ' time delays for the logs and lily pads
byte object_delay_counters[3]                           ' counters for the above object delays
byte last_button                                        ' the last controller button pressed
byte player_attach_object                               ' the object the player is attached to
long sd_pin                  ' desired pin to output sound on
long sd_freq                 ' frequency of sound (related to frequency actually)
long sd_volume               ' volume of sound
long temp_var                                           ' general temporary variable
long temp_var2

'//////////////////////////////////////////////////////////////////////////////
'OBJS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

OBJ

game_pad :      "GAMEPAD_DRV_001.SPIN"
gfx :           "HEL_GFX_ENGINE_040.SPIN"
sd    :         "NS_sound_drv_052_22khz_16bit.spin"

'//////////////////////////////////////////////////////////////////////////////
'PUBS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

' COG INTERPRETER STARTS HERE...@ THE FIRST PUB

PUB Start | counter, nes_buttons, collision, squish_anim_count, distance
' This is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

' debug stuff
DIRA[0] := 0

' star the game pad driver
game_pad.start

' start the sound driver
sd.start(7)             ' start the "engine" sound driver

' set time delays
object_delays[0] := 26           ' time delay for first log
object_delays[1] := 28           ' time delay for lily pads
object_delays[2] := 30           ' time delay for second log

' set the counters for the above
object_delay_counters[0] := 0
object_delay_counters[1] := 0
object_delay_counters[2] := 0

' set the initial game state
game_state := GAME_STATE_START                    
                       
' points ptrs to actual memory storage for tile engine
tile_map_base_ptr_parm        := @tile_map0
tile_bitmaps_base_ptr_parm    := @tile_bitmaps
tile_palettes_base_ptr_parm   := @palette_map
tile_map_sprite_cntrl_parm    := $00_00_08_00 ' set for 12 sprites and width 16 tiles (1 screens wide), 0 = 16 tiles, 1 = 32 tiles, 2 = 64 tiles, 3 = 128 tiles, etc.
tile_sprite_tbl_base_ptr_parm := @sprite_tbl[0] 
tile_status_bits_parm         := 0

' enable/initialize a sprite
sprite_tbl[0] := $80_90_05_01     ' sprite 0 state: y=xx, x=$xx, z=$xx, enabled/disabled
sprite_tbl[1] := @sprite_bitmap_0 ' sprite 0 bitmap ptr

sprite_tbl[2] := $90_20_04_01     ' sprite 0 state: y=xx, x=$xx, z=$xx, enabled/disabled
sprite_tbl[3] := @sprite_bitmap_0 ' sprite 0 bitmap ptr

sprite_tbl[4] := $A0_10_05_01     ' sprite 0 state: y=xx, x=$xx, z=$xx, enabled/disabled
sprite_tbl[5] := @sprite_bitmap_4 ' sprite 0 bitmap ptr

sprite_tbl[6] := $B0_70_03_01     ' sprite 0 state: y=xx, x=$xx, z=$xx, enabled/disabled
sprite_tbl[7] := @sprite_bitmap_4 ' sprite 0 bitmap ptr

sprite_tbl[8] := $C0_60_00_01     ' sprite 0 state: y=xx, x=$xx, z=$xx, enabled/disabled
sprite_tbl[9] := @sprite_bitmap_1 ' sprite 0 bitmap ptr 

' launch a COG with ASM video driver
gfx.start(@tile_map_base_ptr_parm)

' set up the in game variables
squish_anim_count := 0

' set up life count to 3
life_count := 3

' set player position
player_x := (192 / 2) - 16
player_y := 192

' set object positions
log_position[0] := 2
log_position[1] := 5
log_position[2] := 8

second_row_log_position[0] := 1
second_row_log_position[1] := 4
second_row_log_position[2] := 7

lily_position[0] := 1
lily_position[1] := 4
lily_position[2] := 7

' set the player's level
level := 0

' set the object attachment
player_attach_object := 0

' enter main event loop...
repeat while 1
  ' main even loop code here...

  if(game_state == GAME_STATE_START)

    repeat counter from 0 to 3
        sd.StopSound(counter)

    ' update the player's position
    sprite_tbl[8] := (player_y << 24) + (player_x << 16) + (0 << 8) + ($01)

    ' read the game pad
    nes_buttons := NES_Read_Gamepad

    ' check for start button so we can get this frog on the road :)
    if (game_pad.button(NES0_START))

      if(start_button_delay < 5)
        start_button_delay++
      else
        ' update the game state
        game_state := GAME_STATE_INGAME
         
        ' get rid of the Press Start message
        tile_map0[0] := $00_00
        tile_map0[1] := $00_00
        tile_map0[2] := $00_00
        tile_map0[3] := $00_00
         
        ' set up so the player can't delay the start button (annoying)
        start_button_delay := 0

  if(game_state == GAME_STATE_PAUSE)

    ' game is paused, touch nothing
    repeat counter from 0 to 3
      sd.StopSound(counter)

    ' make sure the Press Start message is display
    tile_map0[0] := $00_04
    tile_map0[1] := $00_05
    tile_map0[2] := $00_06
    tile_map0[3] := $00_07
    
    if (game_pad.button(NES0_START))
    
      ' check for the start button to resume
      if(start_button_delay >  5)
      
        ' update the game state
        game_state := GAME_STATE_INGAME
         
        ' get rid of the Press Start message
        tile_map0[0] := $00_00
        tile_map0[1] := $00_00
        tile_map0[2] := $00_00
        tile_map0[3] := $00_00

      start_button_delay := 0

    else

      if(start_button_delay <  10)
        start_button_delay++
  
  if(game_state == GAME_STATE_INGAME)

    nes_buttons := NES_Read_Gamepad
     
      ' move the sprite
      if (game_pad.button(NES0_RIGHT))

        if((last_button == NES0_RIGHT) & (frame_gp_delay > 3))

          if(player_x < 155)
            player_x += 16

          frame_gp_delay := 0

        else
        
          frame_gp_delay++

        last_button := NES0_RIGHT
          
      if (game_pad.button(NES0_LEFT))
     
        if((last_button == NES0_LEFT) & (frame_gp_delay > 3))

          if(player_x > 20)
            player_x -= 16

          frame_gp_delay := 0

        else
        
          frame_gp_delay++

        last_button := NES0_LEFT
          
      if (game_pad.button(NES0_DOWN))

        if((last_button == NES0_DOWN) & (frame_gp_delay > 3))

          if(player_y < 190)
            player_y += 16

          frame_gp_delay := 0

        else
        
          frame_gp_delay++
          
        last_button := NES0_DOWN
          
      if (game_pad.button(NES0_UP))
     
        if((last_button == NES0_UP) & (frame_gp_delay > 3))

          if(player_y > 48)
              player_y -= 16
          if(player_y == 48)
            player_attach_object := 0
            if( player_x == 96 )
              player_y-= 16

          frame_gp_delay := 0

        else
        
          frame_gp_delay++
          
        last_button := NES0_UP

    if (game_pad.button(NES0_START))
      
      if(start_button_delay > 5)
        
        ' pause game
        game_state := GAME_STATE_PAUSE

      start_button_delay := 0

    else

    if(start_button_delay < 10)
    
      ' increment the counter
      start_button_delay++

    ' move first two cars
    repeat counter from 0 to 1
      ' move sprite 'counter', extract current z, add to x, write back to record
      bx := ((sprite_tbl[counter*2] & $00_FF_00_00) >> 16)
      bz := ((sprite_tbl[counter*2] & $00_00_FF_00) >> 8)
      bx := bx - bz
     
      sprite_tbl[counter*2] := (sprite_tbl[counter*2] & $FF_00_FF_FF) | (bx << 16)

       ' update the sound
      temp_var := player_x - bx
      if(temp_var < 0)
        temp_var := 0 - temp_var

      distance := temp_var

      temp_var := player_y - ((7 + counter) * 16) 
      if(temp_var < 0)
        temp_var := 0 - temp_var

      temp_var := (^^((temp_var*temp_var) + (distance*distance))) * 2
      
      sd.PlaySoundFM(counter, sd#SHAPE_NOISE, 800-temp_var, sd#DURATION_INFINITE | (sd#SAMPLE_RATE>>1), 255 - temp_var, $2457_9DEF)
      
    ' move other cars
    repeat counter from 2 to 3
      ' move sprite 'counter', extract current z, add to x, write back to record
      bx := ((sprite_tbl[counter*2] & $00_FF_00_00) >> 16)
      bz := ((sprite_tbl[counter*2] & $00_00_FF_00) >> 8)
      bx := bx + bz
      if(bx > 176)
        bx := 0
     
      sprite_tbl[counter*2] := (sprite_tbl[counter*2] & $FF_00_FF_FF) | (bx << 16)

      ' update the sound
      temp_var := player_x - bx
      if(temp_var < 0)
        temp_var := 0 - temp_var

      distance := temp_var

      temp_var := player_y - ((7 + counter) * 16) 
      if(temp_var < 0)
        temp_var := 0 - temp_var

      temp_var := (^^((temp_var*temp_var) + (distance*distance))) * 2
      
      sd.PlaySoundFM(counter, sd#SHAPE_NOISE, 800-temp_var, sd#DURATION_INFINITE | (sd#SAMPLE_RATE>>1), 255 - temp_var, $2457_9DEF)

    ' update the log positions?
    if(object_delay_counters[0] > object_delays[0])

      ' update the log positions
      repeat counter from 0 to 2
        tile_map0[48 + log_position[counter]] := $06_09
        log_position[counter] := log_position[counter] + 1

        if(player_attach_object == 1 + counter)

          ' move the attached player
          player_x += 16
       
        if(log_position[counter] > 9)
          log_position[counter] := 0

          {if(player_attach_object == 1 + counter)
            player_attach_object := 0
            player_x -= 16}
        
        tile_map0[48 + log_position[counter]] := $06_0F

      ' reset
      object_delay_counters[0] := 0

    else

      object_delay_counters[0]++

    ' update the lily positions?
    if(object_delay_counters[1] > object_delays[1])

      ' update the lily positions
      repeat counter from 0 to 2
        tile_map0[64 + lily_position[counter]] := $09_00
        lily_position[counter] := lily_position[counter] - 1

        if(player_attach_object == 4 + counter)

          ' move the attached player
          player_x -= 16
       
        if(lily_position[counter] < 0)
          lily_position[counter] := 9

          {if(player_attach_object == 4 + counter)
            player_attach_object := 0
            player_x += 16} 
        
        tile_map0[64 + lily_position[counter]] := $09_10

      ' reset
      object_delay_counters[1] := 0

    else

      object_delay_counters[1]++

    ' update the second log positions?
    if(object_delay_counters[2] > object_delays[2])

      ' update the log positions
      repeat counter from 0 to 2
        tile_map0[80 + second_row_log_position[counter]] := $06_09
        second_row_log_position[counter] := second_row_log_position[counter] + 1

        if(player_attach_object == (7 + counter))

          ' move the attached player
          player_x += 16
       
        if(second_row_log_position[counter] > 9)
           second_row_log_position[counter] := 0

           {if(player_attach_object == (7 + counter))
              player_attach_object := 0
              player_x -= 16}
        
        tile_map0[80 + second_row_log_position[counter]] := $06_0F

      ' reset
      object_delay_counters[2] := 0

    else

      object_delay_counters[2]++

    if(collision <> true)
      ' update the player's position
      sprite_tbl[8] := (player_y << 24) + (player_x << 16) + (0 << 8) + ($01)

    ' collision detection
    if(player_y == 176)

      ' street row one, check for collision with car one
      bx := ((sprite_tbl[6] & $00_FF_00_00) >> 16)
      if(player_x < (bx + 16))
        if(player_x > bx)
          ' collision
          collision := true

    if(player_y == 160)

      ' street row one, check for collision with car one
      bx := ((sprite_tbl[4] & $00_FF_00_00) >> 16)
      if(player_x < (bx + 16))
        if(player_x > bx)
          ' collision
          collision := true

    if(player_y == 144)

      ' street row one, check for collision with car one
      bx := ((sprite_tbl[2] & $00_FF_00_00) >> 16)
      if(player_x < (bx + 16))
        if(player_x > bx)
          ' collision
          collision := true

    if(player_y == 128)

      ' street row one, check for collision with car one
      bx := ((sprite_tbl[0] & $00_FF_00_00) >> 16)
      if(player_x < (bx + 16))
        if(player_x > bx)
          ' collision
          collision := true

    if(player_y == 112)
      player_attach_object := 0
      

    ' if player is on tiles at top, move along with them
    if(player_y == 96)

      if(collision == false)

        collision := true
         
        repeat counter from 0 to 2
          if(tile_map0[80 + ((player_x / 16) - 1)] == $06_0F)
            collision := false
            player_attach_object := 7 + counter

    if(player_y == 80)

      if(collision == false)

        collision := true
         
        repeat counter from 0 to 2
          if(tile_map0[64 + (player_x / 16) - 1] == $09_10)
            collision := false
            player_attach_object := 4 + counter

    if(player_y == 64)

      if(collision == false)

        collision := true
         
        repeat counter from 0 to 2
          if(tile_map0[48 + (player_x / 16) - 1] == $06_0F)
            collision := false
            player_attach_object := 1 + counter
    
    if(player_y == 48)

      collision := true

      if( (player_x > 64) & (player_x < 128) )
        collision := false
    
    if(player_y == 32)
      game_state := GAME_STATE_WIN

    if(collision == true)

     player_attach_object := 0

     if(squish_anim_count == 45)
     
      life_count--

      tile_map0[9 - life_count] := $00_00 ' minus one life 
          
      if(life_count > 0)

        ' display the Press Start message
        tile_map0[0] := $00_04
        tile_map0[1] := $00_05
        tile_map0[2] := $00_06
        tile_map0[3] := $00_07

        start_button_delay := 0

        game_state := GAME_STATE_START
            
      else

        ' display game over
        tile_map0[0] := $00_11
        tile_map0[1] := $00_12
        tile_map0[2] := $00_13
        tile_map0[3] := $00_14

        game_state := GAME_STATE_LOSS

      ' reset the player's position
      player_x := (192 / 2) - 16
      player_y := 192

      collision := false

      squish_anim_count := 0
      sprite_tbl[9] := @sprite_bitmap_1

    if(collision == true)

      if(squish_anim_count < 45)

        sprite_tbl[9] := @sprite_bitmap_2
        squish_anim_count++

  ' end game_state == IN GAME

  if(game_state == GAME_STATE_LOSS)

    ' turn off sound
    repeat counter from 0 to 3
      sd.StopSound(counter)

    ' reset the player's position
    player_x := (192 / 2) - 16
    player_y := 192

    ' update the player's position
    sprite_tbl[8] := (player_y << 24) + (player_x << 16) + (0 << 8) + ($01)

    ' make sure we give the player a new three lives
    life_count := 3

    ' and let them know
    tile_map0[7] := $00_03
    tile_map0[8] := $00_03
    tile_map0[9] := $00_03
    
    ' read the game pad
    nes_buttons := NES_Read_Gamepad

    ' check for start button so we can get this frog on the road :)
    if (game_pad.button(NES0_START))

      ' update the game state
      game_state := GAME_STATE_START

      ' display the Press Start message
      tile_map0[0] := $00_04
      tile_map0[1] := $00_05
      tile_map0[2] := $00_06
      tile_map0[3] := $00_07

      ' set up so the player can't delay the start button (annoying)
      start_button_delay := 0

  if(game_state == GAME_STATE_WIN)

    ' turn off sound
    repeat counter from 0 to 3
      sd.StopSound(counter)

    ' update the player's position
    sprite_tbl[8] := (player_y << 24) + (player_x << 16) + (0 << 8) + ($01)

    ' make sure we give the player a new three lives
    life_count := 3

    tile_map0[0] := $00_15
    tile_map0[1] := $00_16

    ' and let them know
    tile_map0[7] := $00_03
    tile_map0[8] := $00_03
    tile_map0[9] := $00_03
    
    ' read the game pad
    nes_buttons := NES_Read_Gamepad

    ' check for start button so we can get this frog on the road :)
    if (game_pad.button(NES0_START))

      ' update the game state
      game_state := GAME_STATE_START

      ' display the Press Start message
      tile_map0[0] := $00_04
      tile_map0[1] := $00_05
      tile_map0[2] := $00_06
      tile_map0[3] := $00_07

      ' set up so the player can't delay the start button (annoying)
      start_button_delay := 0
    
  ' delay a little bit, so you can see the sprite, they are VERY fast!!!
  repeat 7500

  ' return back to repeat main event loop...

' parent COG will terminate now...if it gets to this point

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

' maze plus dots
tile_map0     word      $00_04,$00_05,$00_06,$00_07,$00_00,$00_00,$00_00,$00_03,$00_03,$00_03,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 0
              word      $00_0B,$00_0B,$00_0B,$00_0B,$00_0B,$08_0A,$00_0B,$00_0B,$00_0B,$00_0B,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $06_09,$06_09,$06_09,$06_09,$00_0E,$00_0C,$00_0D,$06_09,$06_09,$06_09,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $06_09,$06_09,$06_0F,$06_09,$06_09,$06_0F,$06_09,$06_09,$06_0F,$06_09,$07_02,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $09_10,$09_00,$09_00,$09_10,$09_00,$09_00,$09_10,$09_00,$09_00,$09_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 4
              word      $06_09,$06_0F,$06_09,$06_09,$06_0F,$06_09,$06_09,$06_0F,$06_09,$06_09,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 5
              word      $00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 6
              word      $07_00,$07_00,$07_00,$07_00,$07_00,$07_00,$07_00,$07_00,$07_00,$07_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 7
              word      $02_02,$02_02,$02_02,$02_02,$02_02,$02_02,$02_02,$02_02,$02_02,$02_02,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 8
              word      $01_08,$01_08,$01_08,$01_08,$01_08,$01_08,$01_08,$01_08,$01_08,$01_08,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 9
              word      $03_02,$03_02,$03_02,$03_02,$03_02,$03_02,$03_02,$03_02,$03_02,$03_02,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 11



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

tile_grass    long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3 ' tile 1
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3

tile_street   long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_0_0_0 ' tile 2
              long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_0_0_0
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

tile_life     long      %%0_0_0_0_0_1_1_1_1_1_1_0_0_0_0_0 ' tile 3
              long      %%0_0_0_0_1_1_1_1_1_1_1_1_0_0_0_0
              long      %%0_0_0_0_1_3_0_3_3_0_3_1_0_0_0_0
              long      %%0_0_0_0_1_3_3_3_3_3_3_1_0_0_0_0
              long      %%0_0_0_0_1_1_1_1_1_1_1_1_0_0_0_0
              long      %%0_0_1_1_0_1_1_1_1_1_1_0_1_1_0_0
              long      %%0_0_1_0_1_1_1_1_1_1_1_1_0_1_0_0
              long      %%0_0_0_1_0_1_1_1_1_1_1_0_1_0_0_0
              long      %%0_0_0_0_0_1_1_1_1_1_1_0_0_0_0_0
              long      %%0_0_0_0_0_1_1_1_1_1_1_0_0_0_0_0
              long      %%0_0_0_0_1_1_1_1_1_1_1_1_0_0_0_0
              long      %%0_0_0_1_0_1_1_1_1_1_1_0_1_0_0_0
              long      %%0_0_0_1_0_1_1_1_1_1_1_0_1_0_0_0
              long      %%0_0_0_1_0_1_1_1_1_1_1_0_1_0_0_0
              long      %%0_0_0_1_1_0_1_1_1_1_0_1_1_0_0_0
              long      %%0_0_0_1_1_0_0_1_1_0_0_1_1_0_0_0

tile_pre      long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 4
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_3_3_3_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_3_0_0_3_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_3_0_0_3_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_3_0_0_3_0
              long      %%0_0_3_3_3_0_0_0_3_3_0_0_3_3_3_0
              long      %%0_3_0_0_0_3_0_3_0_0_3_0_0_0_3_0
              long      %%0_0_3_3_3_3_0_3_0_0_3_0_0_0_3_0
              long      %%0_0_0_0_0_3_0_0_0_0_3_0_0_0_3_0
              long      %%0_3_0_0_0_3_0_0_0_0_3_0_0_0_3_0
              long      %%0_0_3_3_3_0_0_0_0_0_3_0_0_0_3_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

tile_ss       long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 5
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_3_3_3_0_0_0_3_3_3_0
              long      %%0_0_0_0_0_3_0_0_0_3_0_3_0_0_0_3
              long      %%0_0_0_0_0_0_0_0_3_0_0_0_0_0_3_0
              long      %%0_0_0_0_0_0_3_3_0_0_0_0_3_3_0_0
              long      %%0_0_0_0_0_3_0_0_0_3_0_3_0_0_0_3
              long      %%0_0_0_0_0_0_3_3_3_0_0_0_3_3_3_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

tile_sta      long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 6
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_3_0_0_0_3_3_3_3_0
              long      %%0_0_0_0_0_0_0_3_0_0_3_0_0_0_0_3
              long      %%0_0_0_0_0_0_0_3_0_0_0_0_0_0_0_3
              long      %%0_0_0_0_0_0_0_3_0_0_0_0_0_0_3_0
              long      %%3_0_0_0_0_3_3_3_3_3_0_0_0_3_0_0
              long      %%0_3_0_0_0_0_0_3_0_0_0_0_3_0_0_0
              long      %%0_0_3_0_0_0_0_3_0_0_0_3_0_0_0_0
              long      %%0_0_3_0_0_0_0_3_0_0_3_0_0_0_0_0
              long      %%0_0_3_0_3_0_0_3_0_0_3_0_0_0_0_3
              long      %%3_3_0_0_0_3_3_0_0_0_0_3_3_3_3_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

tile_art      long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 7
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_3_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_3_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_3_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_3_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_3_3_3_3_3_0_0_3_3_3_0_0_0_0_3
              long      %%0_0_0_3_0_0_0_3_0_0_0_3_0_0_3_0
              long      %%0_0_0_3_0_0_0_3_0_0_0_3_0_3_0_0
              long      %%0_0_0_3_0_0_0_0_0_0_0_3_0_3_0_0
              long      %%3_0_0_3_0_0_0_0_0_0_0_3_0_3_3_0
              long      %%0_3_3_0_0_0_0_0_0_0_0_3_0_3_0_3
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0


tile_fullst   long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3 ' tile 8
              long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3
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

tile_water    long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 9
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


tile_dock     long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0 ' tile A
              long      %%0_0_3_2_2_2_2_2_2_2_2_2_2_3_0_0
              long      %%0_0_3_2_2_2_2_2_2_2_2_2_2_3_0_0
              long      %%0_0_3_0_0_0_0_0_0_0_0_0_0_3_0_0
              long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
              long      %%0_0_3_2_2_2_2_2_2_2_2_2_2_3_0_0
              long      %%0_0_3_2_2_2_2_2_2_2_2_2_2_3_0_0
              long      %%0_0_3_0_0_0_0_0_0_0_0_0_0_3_0_0
              long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
              long      %%0_0_3_2_2_2_2_2_2_2_2_2_2_3_0_0
              long      %%0_0_3_2_2_2_2_2_2_2_2_2_2_3_0_0
              long      %%0_0_3_0_0_0_0_0_0_0_0_0_0_3_0_0
              long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
              long      %%0_0_3_2_2_2_2_2_2_2_2_2_2_3_0_0
              long      %%0_0_3_2_2_2_2_2_2_2_2_2_2_3_0_0
              long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3

tile_top      long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile B
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
              long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3


tile_grass_tw long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2 ' tile C
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3

tile_grass_th long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2 ' tile D
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
              long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3

tile_grass_fo long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_3 ' tile E
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3

tile_log      long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile F
              long      %%3_3_3_3_0_3_3_3_3_0_2_3_3_3_3_3
              long      %%3_2_2_2_3_2_2_3_2_3_3_2_2_2_2_3
              long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_3_0
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_3_0
              long      %%0_3_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%0_3_2_2_2_2_2_2_2_2_2_2_2_2_3_0
              long      %%0_0_3_2_2_2_2_2_2_2_2_2_2_3_0_0
              long      %%0_3_2_2_2_2_2_2_2_2_2_2_2_2_3_0
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_3_0
              long      %%0_3_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_2_3
              long      %%0_3_2_2_2_2_2_2_3_2_2_3_2_2_2_2
              long      %%0_3_3_3_3_3_3_3_0_3_3_0_3_3_3_3

tile_lily     long      %%0_0_0_0_0_0_0_3_3_3_3_3_3_3_0_0 ' tile 10
              long      %%0_0_0_0_0_0_3_2_2_2_2_2_2_2_3_0
              long      %%0_0_0_0_3_3_2_2_2_2_2_3_2_2_2_3
              long      %%0_0_0_3_2_2_2_2_2_2_2_2_2_2_3_0
              long      %%0_0_3_2_2_2_2_2_2_2_2_2_2_3_0_0
              long      %%0_3_2_2_2_3_2_2_2_2_2_2_3_0_0_0
              long      %%3_2_2_2_2_2_2_2_2_2_2_3_3_3_0_0
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_3_0
              long      %%3_2_2_2_2_2_2_3_2_2_2_2_2_2_2_3
              long      %%3_2_2_2_2_2_2_2_2_2_2_2_2_2_3_0
              long      %%0_3_2_2_2_2_2_2_2_2_2_3_2_2_3_0
              long      %%0_3_2_3_2_2_2_2_2_2_2_2_2_3_0_0
              long      %%0_0_3_2_2_2_2_2_2_2_2_2_3_0_0_0
              long      %%0_0_0_3_2_2_2_2_2_2_3_3_0_0_0_0
              long      %%0_0_0_0_3_2_2_2_3_3_0_0_0_0_0_0
              long      %%0_0_0_0_0_3_3_3_0_0_0_0_0_0_0_0

tile_gam      long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 11
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_3_3_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_3_0_0_3_0_0
              long      %%0_0_0_0_0_0_0_0_0_3_0_0_0_0_3_0
              long      %%0_0_0_0_0_0_0_0_0_3_0_0_0_0_0_3
              long      %%0_0_0_0_3_3_0_0_0_0_0_0_0_0_0_3
              long      %%3_0_0_3_0_0_3_0_0_0_0_0_0_0_0_3
              long      %%3_0_3_0_0_0_0_3_0_3_3_3_3_0_0_3
              long      %%3_0_3_0_0_0_0_3_0_3_0_0_0_0_3_0
              long      %%3_0_3_3_0_0_3_3_0_0_3_0_0_3_0_0
              long      %%3_0_3_0_3_3_0_0_0_0_0_3_3_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

tile_me       long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 12
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_3_3_3_0_0_0_3_3_0_3_3
              long      %%0_0_0_0_3_0_0_0_3_0_3_0_0_3_0_0
              long      %%0_0_0_0_3_0_0_0_3_0_3_0_0_3_0_0
              long      %%0_0_0_0_3_3_3_3_3_0_3_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_3_0_3_0_0_0_0_0
              long      %%0_0_0_0_3_3_3_3_0_0_3_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

tile_ov       long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 13
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_3_3_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_3_0_0_3_0_0_0
              long      %%0_0_0_0_0_0_0_0_3_0_0_0_0_3_0_0
              long      %%0_0_0_0_0_0_0_0_3_0_0_0_0_3_0_0
              long      %%0_0_3_0_0_0_3_0_3_0_0_0_0_3_0_0
              long      %%3_0_3_0_0_0_3_0_3_0_0_0_0_3_0_0
              long      %%3_0_3_0_0_0_3_0_3_0_0_0_0_3_0_0
              long      %%3_0_3_0_0_0_3_0_3_0_0_0_0_3_0_0
              long      %%3_0_0_3_0_3_0_0_0_3_0_0_3_0_0_0
              long      %%0_0_0_0_3_0_0_0_0_0_3_3_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

tile_er       long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 14
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_3_3_0_0_0_0_3_3_3
              long      %%0_0_0_0_0_0_3_0_0_3_0_0_3_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_3_0_3_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_3_0_3_3_3_3
              long      %%0_0_0_0_0_0_0_0_0_0_3_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_3_0_3_3_3_3
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

tile_win      long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 15
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_3_0_0_0_0_0_3_0
              long      %%0_0_0_0_0_0_0_0_3_0_0_0_0_0_3_0
              long      %%0_0_0_0_0_0_3_0_3_0_0_0_0_0_3_0
              long      %%0_0_0_0_0_0_0_0_3_0_0_0_0_0_3_0
              long      %%0_3_3_3_0_0_3_0_3_0_0_0_0_0_3_0
              long      %%3_0_0_0_3_0_3_0_3_0_0_0_0_0_3_0
              long      %%3_0_0_0_3_0_3_0_3_0_0_0_0_0_3_0
              long      %%3_0_0_0_3_0_3_0_3_0_0_3_0_0_3_0
              long      %%3_0_0_0_3_0_3_0_0_3_0_3_0_3_0_0
              long      %%3_0_0_0_3_0_3_0_0_0_3_3_3_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

tile_ner      long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0 ' tile 16
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_3_3_0_0_0_3_3_0_0_0_3_3_3_0_0
              long      %%3_0_0_3_0_3_0_0_3_0_3_0_0_0_3_0
              long      %%0_0_0_3_0_3_3_3_3_0_3_0_0_0_3_0
              long      %%0_0_0_3_0_0_0_0_3_0_3_0_0_0_3_0
              long      %%0_0_0_3_0_3_0_0_3_0_3_0_0_0_3_0
              long      %%0_0_0_3_0_0_3_3_0_0_3_0_0_0_3_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0      

' /////////////////////////////////////////////////////////////////////////////

              ' palette memory (1..255 palettes) each palette 4-BYTEs or 1-LONG
              ' color 0 - used for black
              ' color 1 - used for car and grass
              ' color 2 - used for frogger
              ' color 3 - white

' some frogger palettes...
palette_map   long $07_3A_3D_02  
              long $07_2C_3D_02 
              long $07_6C_3D_02
              long $07_4C_3D_02
              long $07_3C_3D_02
              long $07_D6_3D_02
              long $1A_0C_3D_7C
              long $07_DC_3D_02
              long $07_0C_3D_02
              long $2B_3C_3D_7C 

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
              
              ' sprite 8 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 9 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 10 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 11 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 12 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 13 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 14 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 15 header
              long $00_00_00_00  ' state/control word: y,x,z,state
              long $00_00_00_00  ' bitmap ptr

              ' sprite 16 header
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
                        long      %%0_3_3_3_3_3_3_0_0_3_3_3_3_3_3_0
                        long      %%0_3_3_0_0_3_3_0_0_3_3_0_0_3_3_0
                        long      %%0_0_0_3_3_0_0_0_0_0_0_3_3_0_0_0 
                        long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_0_0 
                        long      %%2_2_3_3_3_3_2_3_3_3_3_2_2_3_2_0 
                        long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_3_2_2 
                        long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_3_3_2 
                        long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_3_3_2 
                        long      %%2_2_2_2_2_2_2_2_2_2_2_2_2_3_2_2 
                        long      %%2_2_3_3_3_3_2_3_3_3_3_2_2_3_2_0 
                        long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_0_0
                        long      %%0_0_0_3_3_0_0_0_0_0_0_3_3_0_0_0
                        long      %%0_3_3_0_0_3_3_0_0_3_3_0_0_3_3_0
                        long      %%0_3_3_3_3_3_3_0_0_3_3_3_3_3_3_0
               
' the mask needs to be a NEGATIVE of the bitmap, basically a "stencil" where we are going to write the sprite into, all the values are 0 (mask) or 3 (write thru)
' however, the algorithm needs a POSITIVE to make some of the shifting easier, so we only need to apply the rule to each pixel of the bitmap:
' if (p_source == 0) p_dest = 0, else p_dest = 3

sprite_bitmap_mask_0    long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_3_3_3_3_3_3_0_0_3_3_3_3_3_3_0
                        long      %%0_3_3_0_0_3_3_0_0_3_3_0_0_3_3_0
                        long      %%0_0_0_3_3_0_0_0_0_0_0_3_3_0_0_0 
                        long      %%0_3_3_3_3_3_3_3_3_3_3_3_3_3_0_0 
                        long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_0 
                        long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3 
                        long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3 
                        long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3 
                        long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3 
                        long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_0 
                        long      %%0_3_3_3_3_3_3_3_3_3_3_3_3_3_0_0
                        long      %%0_0_0_3_3_0_0_0_0_0_0_3_3_0_0_0
                        long      %%0_3_3_0_0_3_3_0_0_3_3_0_0_3_3_0
                        long      %%0_3_3_3_3_3_3_0_0_3_3_3_3_3_3_0


sprite_bitmap_1         long      %%0_0_0_0_0_1_1_1_1_1_1_0_0_0_0_0
                        long      %%0_0_0_0_1_1_1_1_1_1_1_1_0_0_0_0
                        long      %%0_0_0_0_1_3_0_3_3_0_3_1_0_0_0_0
                        long      %%0_0_0_0_1_3_3_3_3_3_3_1_0_0_0_0
                        long      %%0_0_0_0_1_1_1_1_1_1_1_1_0_0_0_0
                        long      %%0_0_1_1_0_1_1_1_1_1_1_0_1_1_0_0
                        long      %%0_0_1_0_1_1_1_1_1_1_1_1_0_1_0_0
                        long      %%0_0_0_1_0_1_1_1_1_1_1_0_1_0_0_0
                        long      %%0_0_0_0_0_1_1_1_1_1_1_0_0_0_0_0
                        long      %%0_0_0_0_0_1_1_1_1_1_1_0_0_0_0_0
                        long      %%0_0_0_0_1_1_1_1_1_1_1_1_0_0_0_0
                        long      %%0_0_0_1_0_1_1_1_1_1_1_0_1_0_0_0
                        long      %%0_0_0_1_0_1_1_1_1_1_1_0_1_0_0_0
                        long      %%0_0_0_1_0_1_1_1_1_1_1_0_1_0_0_0
                        long      %%0_0_0_1_1_0_1_1_1_1_0_1_1_0_0_0
                        long      %%0_0_0_1_1_0_0_1_1_0_0_1_1_0_0_0

sprite_bitmap_mask_1    long      %%0_0_0_0_3_3_3_3_3_3_3_0_0_0_0_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_0_0_0_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_0_0_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_0_0_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_0_0_0
                        long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
                        long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_3_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_3_3_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_0_0_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_0_0_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_0_0_0
                        long      %%0_0_3_3_0_3_3_3_3_3_3_0_3_3_0_0
                        long      %%0_0_3_3_0_3_3_3_3_3_3_0_3_3_0_0
                        long      %%0_0_3_3_0_3_3_3_3_3_3_0_3_3_0_0
                        long      %%0_0_3_3_3_0_3_3_3_3_0_3_3_3_0_0
                        long      %%0_0_3_3_3_0_0_3_3_0_0_3_3_0_0_0

sprite_bitmap_2         long      %%0_0_0_0_0_1_1_1_1_1_1_0_0_0_0_0
                        long      %%0_0_0_0_0_1_0_1_0_1_0_1_0_0_0_0
                        long      %%0_0_0_0_1_0_0_0_3_0_0_1_0_0_0_0
                        long      %%0_0_0_0_1_3_0_3_0_3_0_1_0_0_0_0
                        long      %%0_0_0_0_1_1_1_0_1_0_1_1_0_0_0_0
                        long      %%0_0_0_1_0_1_0_1_0_1_0_0_0_1_0_0
                        long      %%0_0_1_0_1_0_1_0_1_0_1_1_0_0_1_0
                        long      %%0_0_0_1_0_1_1_1_1_1_1_0_1_1_0_0
                        long      %%0_0_0_0_0_1_0_1_0_1_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_1_0_1_0_1_0_0_0_0_0
                        long      %%0_0_0_0_1_0_1_0_1_0_1_0_0_0_0_0
                        long      %%0_0_0_1_0_1_0_1_0_1_0_0_1_0_0_0
                        long      %%0_0_0_1_0_0_1_0_1_0_1_0_1_0_0_0
                        long      %%0_0_0_1_0_1_0_1_0_1_0_0_1_0_0_0
                        long      %%0_0_0_1_1_0_1_1_1_1_0_1_1_0_0_0
                        long      %%0_0_0_1_1_0_0_1_1_0_0_1_1_0_0_0

sprite_bitmap_mask_2    long      %%0_0_0_0_3_3_3_3_3_3_3_0_0_0_0_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_0_0_0_0
                        long      %%0_0_0_3_3_3_0_3_3_0_3_3_3_0_0_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_0_0_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_0_0_0
                        long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
                        long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_3_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_3_3_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_0_0_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_0_0_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_0_0_0
                        long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
                        long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
                        long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
                        long      %%0_0_3_3_3_3_3_3_3_3_3_3_3_3_0_0
                        long      %%0_0_0_3_3_3_3_3_3_3_3_3_3_0_0_0

sprite_bitmap_4         long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_3_3_3_3_3_3_0_0_3_3_3_3_3_3_0
                        long      %%0_3_3_0_0_3_3_0_0_3_3_0_0_3_3_0
                        long      %%0_0_0_3_3_0_0_0_0_0_0_3_3_0_0_0 
                        long      %%0_0_2_2_2_2_2_2_2_2_2_2_2_2_2_0
                        long      %%0_2_3_2_2_3_3_3_3_2_3_3_3_3_2_2 
                        long      %%2_2_3_2_2_2_2_2_2_2_2_2_2_2_2_2
                        long      %%2_3_3_2_2_2_2_2_2_2_2_2_2_2_2_2
                        long      %%2_3_3_2_2_2_2_2_2_2_2_2_2_2_2_2
                        long      %%2_2_3_2_2_2_2_2_2_2_2_2_2_2_2_2
                        long      %%0_2_3_2_2_3_3_3_3_2_3_3_3_3_2_2 
                        long      %%0_2_2_2_2_2_2_2_2_2_2_2_2_2_0_0
                        long      %%0_0_0_3_3_0_0_0_0_0_0_3_3_0_0_0
                        long      %%0_3_3_0_0_3_3_0_0_3_3_0_0_3_3_0
                        long      %%0_3_3_3_3_3_3_0_0_3_3_3_3_3_3_0

sprite_bitmap_mask_4    long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_3_3_3_3_3_3_0_0_3_3_3_3_3_3_0
                        long      %%0_3_3_0_0_3_3_0_0_3_3_0_0_3_3_0
                        long      %%0_0_0_3_3_0_0_0_0_0_0_3_3_0_0_0 
                        long      %%0_3_3_3_3_3_3_3_3_3_3_3_3_3_0_0 
                        long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_0 
                        long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3 
                        long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3 
                        long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3 
                        long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_3 
                        long      %%3_3_3_3_3_3_3_3_3_3_3_3_3_3_3_0 
                        long      %%0_3_3_3_3_3_3_3_3_3_3_3_3_3_0_0
                        long      %%0_0_0_3_3_0_0_0_0_0_0_3_3_0_0_0
                        long      %%0_3_3_0_0_3_3_0_0_3_3_0_0_3_3_0
                        long      %%0_3_3_3_3_3_3_0_0_3_3_3_3_3_3_0
 