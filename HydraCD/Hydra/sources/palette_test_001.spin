' /////////////////////////////////////////////////////////////////////////////
' TITLE: palette testing program
'
' DESCRIPTION: Generalized input controller demo, uses tile engine as well.
' Breakout like game. Shows off the following techniques:
' - Multiple tile maps
' - Multiple sprites
' - clever use of palettes
' - collision detection and response
' - using multiple input devices in a game environment
' VERSION: x.x
' AUTHOR: Andre' LaMothe
' LAST MODIFIED:
' COMMENTS:
'
' CONTROLS: Uses all controllers, move right left, and hit the ball, to launch
' the ball use the FIRE or START button on the respective controller
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

  ' control key constants for keyboard interface
  KB_LEFT_ARROW  = $C0
  KB_RIGHT_ARROW = $C1
  KB_UP_ARROW    = $C2
  KB_DOWN_ARROW  = $C3
  KB_ESC         = $CB
  KB_SPACE       = $20
  KB_ENTER       = $0D
  KB_LEFT_CTRL   = $F2
  KB_RIGHT_CTRL  = $F3

   
  'encode each universal input id as a bit
  IID_NULL  =      $00 ' null input
  IID_START =      $01
  IID_ESC   =      $02
  IID_FIRE  =      $04
  IID_RIGHT =      $08
  IID_LEFT  =      $10
  IID_UP    =      $20
  IID_DOWN  =      $40

  ' size of playfield
  BALL_PLAYFIELD_MAX_X = 11*16
  BALL_PLAYFIELD_MIN_X = 16

  BALL_PLAYFIELD_MAX_Y = 13*16
  BALL_PLAYFIELD_MIN_Y = 16

  ' size of paddle
  PADDLE_WIDTH    = 24
  PADDLE_WIDTH_2  = 12

  PADDLE_HEIGHT   = 10
  PADDLE_HEIGHT_2 = 5


  ' sequence / pattern detector constants, with these rates you can enter the seqeunce as fast
  ' as your little primate fingers can enter it, and as slow as .5ish seconds per button
  SEQ_COUNT_MIN                   = 1
  SEQ_COUNT_MAX                   = 30

  ' states for sequence detector
  SEQ_STATE_WAIT                  = 0
  SEQ_STATE_READY                 = 1
  SEQ_STATE_MATCH_SEQUENCE        = 2

  ' simple game states, incomplete for brevity
  GAME_STATE_INIT                 = 0 ' game is initializing                                                        '
  GAME_STATE_BALL_WAIT            = 1 ' ball is "waiting" on top of paddle                                              
  GAME_STATE_BALL_INPLAY          = 2 ' ball is in play and bouncing around
  GAME_STATE_BALL_MISSED          = 3 ' ball was just missed by paddle
  
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
long x, y, tx, ty, index, dir, tile_map_index, test_tile' demo working vars
long paddle_x, paddle_y                                   ' position of paddle
long old_paddle_x, old_paddle_y                           ' holds last position of paddle                        

long ball_x, ball_y, ball_state, ball_xv, ball_yv

long curr_count                                           ' current global counter count

long random_seed                                          ' used for random generation

' globals to track presence of input devices
long keyboard_present                                                         
long mouse_present
long gamepad_present

long player_input                                       ' collects all input devices into a single packet
long player_input_x, player_input_y                     ' positionals from data packet

' sequencer globals (not really used in this demo, but included incase you want to do something with it)
long seq_state      ' state of sequencer 
long seq_counter    ' used to count time a button is down or up
long seq_index      ' index into sequence pattern data array
long seq_min_flag   ' flags if the minimum time for a button to be held has elapsed
long seq_fire_event ' this the message that says "do it" whatever the "event" is that the sequence fires off

long sequence[32]   ' storage for sequence
long seq_length     ' how many buttons in sequence

' level tracking variables and game state
long game_state                                           ' current state of game for main event loop
long game_state_counter                                   ' used to count game state ticks and determine when to transition to next states                        

long curr_level                                           ' current level, 0 to num_levels-1 
long level_num_blocks                                     ' number of remaining on level
long level_background_tile                                ' tile under the blocks, so when they are removed we can restore it                      

' these records contain the "levels". Each record contains a pointer to the
' tile map base address along with the number of "blocks" in the level that have
' to be destroyed, and finally the background tile that should be replaced under the block
' once its removed, a WORD is large enough to hold the base addresses, so we will
' use a [WORD, WORD, WORD] size record in the format [level_tiles_base_addresss, num_blocks_on_level, background_tile]
word level_records[16*3]                                    ' storage to hold 16 levels                    
long num_levels                                             ' total number of levels in game


long ball_tx, ball_ty          ' the ball's coordinates translated to tile space
long ball_map_x, ball_map_y    ' the tile index x,y that the ball is in
word tile_entry                ' generic tile entry variable for collision detection algorithms

long y_top, y_bot, x_left, x_right, delta_t, delta_b, delta_r, delta_l ' used for collision calculations
long edge_code_x, edge_code_y, edge_code, min_dist_x, min_dist_y


'//////////////////////////////////////////////////////////////////////////////
'OBJS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

OBJ

mouse           : "mouse_iso_010.spin"    '  instantiate a mouse object
key             : "keyboard_iso_010.spin" ' instantiate a keyboard object       
gamepad         : "gamepad_drv_001.spin"  ' instantiate game pad object
gfx             : "HEL_GFX_ENGINE_040.SPIN"

'//////////////////////////////////////////////////////////////////////////////
'PUBS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

' COG INTERPRETER STARTS HERE...@ THE FIRST PUB

PUB Start
' This is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file


' intialize game state and level
game_state         := GAME_STATE_INIT
game_state_counter := 0


' enter main event loop...
repeat while 1
  ' main even loop code here...

  ' use conitionals for game states rather than "case" statement for fun.

  if (game_state == GAME_STATE_INIT)
    ' initialize all the level records
    ' tile map order for now: 5,2,4,1,3,0

    level_records[0*3+0] := @tile_map6  ' address of level 1 data
    level_records[0*3+1] := 100         ' number of blocks on level 1
    level_records[0*3+2] := $00_00      ' tile under block 


'    level_records[0*3+0] := @tile_map5  ' address of level 1 data
'    level_records[0*3+1] := 28          ' number of blocks on level 1
'    level_records[0*3+2] := $00_00      ' tile under block 

    level_records[1*3+0] := @tile_map2  ' address of level 2 data
    level_records[1*3+1] := 30          ' number of blocks on level 2
    level_records[1*3+2] := $0A_00      ' tile under block

    level_records[2*3+0] := @tile_map4  ' address of level 3 data
    level_records[2*3+1] := 42          ' number of blocks on level 3
    level_records[2*3+2] := $0A_00      ' tile under block

    level_records[3*3+0] := @tile_map1  ' address of level 4 data
    level_records[3*3+1] := 32          ' number of blocks on level 4
    level_records[3*3+2] := $00_00      ' tile under block

    level_records[4*3+0] := @tile_map3  ' address of level 5 data
    level_records[4*3+1] := 42          ' number of blocks on level 5
    level_records[4*3+2] := $07_00      ' tile under block

    level_records[5*3+0] := @tile_map0  ' address of level 6 data
    level_records[5*3+1] := 42          ' number of blocks on level 6
    level_records[5*3+2] := $23_00      ' tile under block

    ' .. insert more level records here...
     
    ' set current level and 
    curr_level             := 0
    tile_map_base_ptr_parm := level_records[curr_level*2 + 0] ' each record holds a pointer to tile map followed by number of blocks 
    level_num_blocks       := level_records[curr_level*3 + 1] 'initialize number of blocks left for starting level
    level_background_tile  := level_records[curr_level*3 + 2] ' set background tile for level 

    'start mouse
    mouse.start(2)
    repeat 250_000 ' needs 2 seconds to determins if mouse is present
    mouse_present := mouse.present
     
    ' start keyboard
    key.start(3)
    repeat 250_000 ' needs 2 seconds to determins if mouse is present
    keyboard_present := key.present
     
    ' start the gamepad 
    gamepad.start
    repeat 1000
    if ( (gamepad.read & $00FF) <> $FF)
      gamepad_present := 1
    else 
      gamepad_present := 0
      
    ' initialize all vars
    paddle_x  := 16+160/2                    ' set sprite location of paddle to center of screen
    paddle_y  := 16*12+8                       
     
    ball_x := 16+160/2
    ball_y := 16*12+8
     
    ball_xv := 2
    ball_yv := 2
     
    ' random stuff
    random_seed := 1773456 + cnt
     
    ' points ptrs to actual memory storage for tile engine
    tile_map_base_ptr_parm        := level_records[curr_level*2 + 0] ' each record holds a pointer to tile map followed by number of blocks 
    tile_bitmaps_base_ptr_parm    := @tile_bitmaps
    tile_palettes_base_ptr_parm   := @palette_map
    tile_map_sprite_cntrl_parm    := $00_00_03_00 ' set for 1 sprites and width 16 tiles (1 screens wide), 0 = 16 tiles, 1 = 32 tiles, 2 = 64 tiles, 3 = 128 tiles, etc.
    tile_sprite_tbl_base_ptr_parm := @sprite_tbl[0] 
    tile_status_bits_parm         := 0
     
    ' enable/initialize a sprite
    sprite_tbl[0] := $00_00_00_01     ' sprite 0 state: y=xx, x=$xx, z=$xx, enabled/disabled
    sprite_tbl[1] := @sprite_bitmap_1 ' sprite 0 bitmap ptr
     
    sprite_tbl[2] := $00_00_00_01     ' sprite 1 state: y=xx, x=$xx, z=$xx, enabled/disabled
    sprite_tbl[3] := @sprite_bitmap_0 ' sprite 1 bitmap ptr
     
    sprite_tbl[4] := $00_00_00_01     ' sprite 2 state: y=xx, x=$xx, z=$xx, enabled/disabled
    sprite_tbl[5] := @sprite_bitmap_2 ' sprite 2 bitmap ptr
     
    ' initialize input sequencer to nothing for now..not used in this demo yet. 
    seq_state      := SEQ_STATE_WAIT
    seq_counter    := 0
    seq_index      := 0
    seq_min_flag   := 0
    seq_fire_event := 0
    seq_length     := 0
     
    ' launch a COG with ASM video driver
    gfx.start(@tile_map_base_ptr_parm)

    ' transition to GAME_STATE_BALL_WAIT
    game_state := GAME_STATE_BALL_WAIT
 
    ' end GAME_STATE_INIT

  ' this next section of code gets executed always, so its always entered no matter what state the game is in
  ' the strategy will be to conditionally test state where needed in the event loop to change behaviors
  
  curr_count := cnt ' save current counter value

  ' get universal input from all devices
  player_input := UCI_Read_Keyboard2(keyboard_present) | UCI_Read_Mouse2(mouse_present) | UCI_Read_Gamepad2(gamepad_present)

  ' extract out x,y fields, x is in byte 2, y is in byte 3 "~" only works on variable not expression???
  player_input_x := (player_input >> 16)
  player_input_y := (player_input >> 24)

  ' now perform sign extensions
  player_input_x := ~player_input_x
  player_input_y := ~player_input_y  

  ' move the paddle
  if ( (player_input & IID_RIGHT) or (player_input & IID_LEFT))
    paddle_x += player_input_x

  ' test for ball launch by player
  if (game_state == GAME_STATE_BALL_WAIT and (player_input & (IID_START | IID_FIRE)) )
    ' transition to in play mode and fire ball with random upward trajectory
    game_state := GAME_STATE_BALL_INPLAY

    ' give ball intial random upward velocity
    ball_xv := -3 + (?random_seed & $07)
    ball_yv := 2 + (?random_seed & $03) 

    ' clamp yv
    ball_yv <#= 4
  ' end launch ball ///////////////////////////////////////////


  ' move the ball on trajectory if ball is in play
  if (game_state == GAME_STATE_BALL_INPLAY)
    ball_x += ball_xv
    ball_y += ball_yv
  elseif (game_state == GAME_STATE_BALL_WAIT)
  ' move ball with paddle if game is waiting for player launch
    ball_x := paddle_x-2
    ball_y := paddle_y-6  


  ' test for missed state
  if (game_state == GAME_STATE_BALL_MISSED)
     ' decrement counter and test for end of state
    if (--game_state_counter =< 0)
      'transition to waiting state
      game_state := GAME_STATE_BALL_WAIT


  ' test for collision with ball and paddle, use center point of ball and test against bounding box of paddle
  if ( (ball_x > (paddle_x - PADDLE_WIDTH_2) ) and (ball_x < (paddle_x + PADDLE_WIDTH_2) ) )
    if ( (ball_y > (paddle_y - PADDLE_HEIGHT_2) ) and ( ball_y < (paddle_y + PADDLE_HEIGHT_2) ) ) 
      ' there's been a collision, now respond, the "response" depends on how accurate you want to make it!
      ' first invert the y-velocity
      ball_yv := -ball_yv
      ball_yv += -3 + (?random_seed & $03)

      ' now add a little bit of english based on the movement of the paddle
      if (||player_input_x > 0)
          ball_xv -= player_input_x/2
    
      ' clamp velocity of ball
      ball_xv #>= -4
      ball_xv <#= 4

      ball_yv #>= -4
      ball_yv <#= 4

      ball_x += ball_xv
      ball_y += ball_yv
  ' end ball paddle collision////////////////////////////////////////////////

                          
  ' test for ball collision with game playfield boundary
  if ((ball_x > BALL_PLAYFIELD_MAX_X) or (ball_x < BALL_PLAYFIELD_MIN_X))
    ball_xv := -ball_xv 
    ball_x += ball_xv
    ball_y += ball_yv

  if ((ball_y < BALL_PLAYFIELD_MIN_Y) )
    ball_yv := -ball_yv 
    ball_x += ball_xv
    ball_y += ball_yv

  ' player missed ball -- opps!  
  if ( (game_state == GAME_STATE_BALL_INPLAY) and (ball_y > BALL_PLAYFIELD_MAX_Y)) 
    ' reset to waiting state
    game_state         := GAME_STATE_BALL_MISSED
    game_state_counter := 30 ' set counter for a second or so, to let player realize his error
    
    
  ' end ball playfield boundary collision/////////////////////////////////////



  ' test for ball collision with blocks (or barriers), this one is a little longer since we want the ball 
  ' to respond off all 4 sides of the block in a realistic manner, plus we are trying not to perform any kind
  ' of floating/fixed point calculations, just try to keep it simple...
  ' the idea is to see if ball has pierced either of the 4 sides of the block (or barrier), and if so
  ' then make the ball bounce AND remove the block (or leave it, if its a barrier), here we go....

  ' step 1: determine if ball has entered into an occupied block
  ' need to translate ball coords to tile coords
  ball_tx := ball_x - 16 ' the sprite coordinate system is offset -16, -16 to support clipping, thus re-align with tile space
  ball_ty := ball_y - 16

  ' now compute tile coordinates
  ball_map_x := ball_tx >> 4 ' map coordinates equal screen pixel coords/16 
  ball_map_y := ball_ty >> 4

  ' ok, now we have the tile coordinates, so go into the tile map and determine if there is a tile there
  ' use the WORD operator to access memory directly at (x,y), but remember there are 16 tiles per row
  tile_entry := WORD[tile_map_base_ptr_parm][ball_map_x + ball_map_y*16]  

  ' test for block or barrier collision
  if ( (tile_entry & $00FF) == $01 or (tile_entry & $00FF) == $02)
    ' at this point we have hit the block (or barrier), but we need to drill down and figure out which side and output
    ' appropriate response, we are going to use a technique where we compute the distance from the ball's center
    ' to the center of each edge of the block, the closest edge wins! and we will bounce the ball off it
    ' the following algorithm performs the calculations in a clear manner, this could be shortened up quite a bit
    ' but this is easier to follow. Uses the "1-norm" distance for calculations which is an approximation, but works fine here
    
    ' first compute bounding box coordinates of block, notice the numeric codes assigned to each
    y_top   := ball_map_y << 4 ' top    - edge code 0  
    y_bot   := y_top + 16      ' bottom - edge code 1
    x_left  := ball_map_x << 4 ' left   - edge code 2
    x_right := x_left + 16     ' right  - edge code 3
    
    ' now compute deltas of ball from top, bottom, left and right edges, these will be come the "decision" variables
    delta_t := ball_ty - y_top
    delta_b := y_bot - ball_ty
    delta_r := x_right - ball_tx
    delta_l := ball_tx - x_left 
    
    edge_code_x := 0 ' used to hold min dist codes
    edge_code_y := 0 ' used to hold min dist codes
    edge_code   := 0 ' used to hold final edge code
    min_dist_x  := 0 ' used to hold temporate distance results
    min_dist_y  := 0
    
    ' at this pointe we need to find the smallest distance, this will be the edge we will bounce the ball off
    ' compare dx's and dy's then compare winner of each, try to minimize number of conditionals since there are
    ' 16 in worst case!
    if (delta_r < delta_l)
      edge_code_x := 3
      min_dist_x  := delta_r
    else
      edge_code_x := 2
      min_dist_x  := delta_l

    if (delta_t < delta_b)
      edge_code_y := 0
      min_dist_y  := delta_t
    else
      edge_code_y := 1
      min_dist_y  := delta_b
      
    ' now we know the winner on the x,y axis, now compare those winners
    if (min_dist_x < min_dist_y)
      ' set final edge code
      edge_code := edge_code_x
    else
      edge_code := edge_code_y

    ' now we are ready for the response!
    case edge_code              
      0:  ' bounce ball off top edge
        ball_yv := -ball_yv
      1:  ' bound ball off bottom edge
        ball_yv := -ball_yv
      2:  ' bounce ball off left edge
        ball_xv := -ball_xv      
      3:  ' bounce ball off right edge
        ball_xv := -ball_xv

    ' finally translate ball out of collision surface
    ball_x += ball_xv
    ball_y += ball_yv

    ' now that response is complete, finish up details about game play
    ' if collision was with a block, we need to remove the block and decrement the block counter to see if the level has been cleared
    ' if collision was with barrier, then do nothing, response is all that was needed
    if ( (tile_entry & $00FF) == $01 )
      ' replace block with background block
      WORD[tile_map_base_ptr_parm][ball_map_x + ball_map_y*16] := level_background_tile 

      ' decrement block counter
      if (--level_num_blocks == 0)
        ' level is over, move to next level, set player back to waiting state
        ++curr_level
        
        ' set current level 
        if (curr_level == 6)
          curr_level := 0           

        ' based on level set up everything
        tile_map_base_ptr_parm := level_records[curr_level*3 + 0] ' each record holds a pointer to tile map followed by number of blocks 
        level_num_blocks       := level_records[curr_level*3 + 1] 'initialize number of blocks left for starting level
        level_background_tile  := level_records[curr_level*3 + 2] ' set background tile for level 
        ' let player re-launch ball
        game_state := GAME_STATE_BALL_WAIT    
        

    
  ' end test for ball block collisions /////////////////////////////////////////


  ' test for paddle collision with playfield
  if (paddle_x > BALL_PLAYFIELD_MAX_X-8)
    paddle_x := BALL_PLAYFIELD_MAX_X-8
  elseif (paddle_x < BALL_PLAYFIELD_MIN_X+8)
    paddle_x := BALL_PLAYFIELD_MIN_X+8
  
' now update the sprite records to reflect the position of the paddle
  sprite_tbl[0] := ((paddle_y-8) << 24) + ((paddle_x - 16) << 16) + (0 << 8) + ($01)
  sprite_tbl[2] := ((paddle_y-8) << 24) + (((paddle_x - 16)+16) << 16) + (0 << 8) + ($01)            

  ' and now the ball, if not in missed state
  if (game_state == GAME_STATE_BALL_MISSED)
    ' place ball offscreen and disable sprite all togehter
    sprite_tbl[4] := 0
  else ' draw ball, business as usual
    sprite_tbl[4] := ((ball_y-8) << 24) + ((ball_x-8) << 16) + (0 << 8) + ($01)  

  ' lock frame rate to 30-60
  waitcnt(cnt + 3*666_666)

  ' return back to repeat main event loop...

' parent COG will terminate now...if it gets to this point

' /////////////////////////////////////////////////////////////////////////////

PUB UCI_Read_Keyboard2(device_present) : keyboard_state  | kbx, kby
' universal controller interface for keyboard version 2.0
' now supports the x,y fields in bytes 2,3

' make sure the device is present
if (device_present==FALSE)
  return 0

' reset state vars
keyboard_state := 0
kbx := 0
kby := 0

' first control id's
' set ESC id
if (key.keystate(KB_ESC))
  keyboard_state |= IID_ESC         

' set start id
if (key.keystate(KB_SPACE) or key.keystate(KB_ENTER) or key.keystate(KB_LEFT_CTRL) or key.keystate(KB_RIGHT_CTRL) )
  keyboard_state |= IID_START
  
' set fire id
if (key.keystate(KB_SPACE) or key.keystate(KB_LEFT_CTRL) or key.keystate(KB_RIGHT_CTRL) )
  keyboard_state |= IID_FIRE

' now directionals
if (key.keystate(KB_LEFT_ARROW))  
  keyboard_state |= IID_LEFT
  kbx := -2
  
if (key.keystate(KB_RIGHT_ARROW))
  keyboard_state |= IID_RIGHT
  kbx := 2

if (key.keystate(KB_UP_ARROW))    
  keyboard_state |= IID_UP
  kby := -2

if (key.keystate(KB_DOWN_ARROW))  
  keyboard_state |= IID_DOWN
  kby := 2

' merge x,y into packet
keyboard_state := keyboard_state | ((kby & $00FF) << 24) | ((kbx & $00FF) << 16)

return keyboard_state

' end UCI_Read_Keyboard2

' /////////////////////////////////////////////////////////////////////////////
PUB UCI_Read_Mouse2(device_present) : mouse_state | m_dx, m_dy
' universal controller interface for mouse version 2.0
' now supports the x,y fields in bytes 2,3

' make sure the device is present
if (device_present==FALSE)
  return 0

' reset state var
mouse_state := 0

' set ESC id
if (mouse.button(1))
  mouse_state |= IID_ESC
  
' set start id
if (mouse.button(0))
  mouse_state |= IID_START

' set fire id
if (mouse.button(0))
  mouse_state |= IID_FIRE

' get mouse deltas
m_dx := mouse.delta_x
m_dy := -mouse.delta_y ' invert due to mouse coordinate mapping is inverted on y-axis

' now, we need to convert the delta or absolute mouse position into digital output,
if (m_dx > 0)
  mouse_state |= IID_RIGHT    
else
if (m_dx < 0)
  mouse_state |= IID_LEFT

if (m_dy < 0)
  mouse_state |= IID_DOWN    
else
if (m_dy > 0)
  mouse_state |= IID_UP

' merge x,y into packet
mouse_state := mouse_state |((m_dy & $00FF) << 24) | ((m_dx & $00FF) << 16)

return mouse_state

' end UCI_Read_Mouse2

' /////////////////////////////////////////////////////////////////////////////////

PUB UCI_Read_Gamepad2(device_present) : gamepad_state | gpx, gpy
' universal controller interface for gamepad versions 2.0
' now supports the x,y fields in bytes 2,3
' note the gamepad maps very naturally to the universal codes, we could use
' some really clever lookup or logic code to map the codes, but instead lets
' just keep it readable...

' make sure the device is present
if (device_present == 0)
  return 0

' reset state var
gamepad_state := 0
gpx := 0
gpy := 0

' set ESC id
if (gamepad.button(NES0_SELECT))
  gamepad_state |= IID_ESC
  
' set start id
if (gamepad.button(NES0_START))
  gamepad_state |= IID_START

' set fire id
if (gamepad.button(NES0_A) or gamepad.button(NES0_B) )
  gamepad_state |= IID_FIRE
  
' now directionals
if (gamepad.button(NES0_LEFT) )  
  gamepad_state |= IID_LEFT
  gpx := -2

if (gamepad.button(NES0_RIGHT) ) 
  gamepad_state |= IID_RIGHT
  gpx := 2

if (gamepad.button(NES0_UP) )  
  gamepad_state |= IID_UP
  gpy := -2

if (gamepad.button(NES0_DOWN) )  
  gamepad_state |= IID_DOWN
  gpy := 2

' merge x,y into packet
gamepad_state := gamepad_state |((gpy & $00FF) << 24) | ((gpx & $00FF) << 16)

return gamepad_state

' end UCI_Read_Gamepad2

' ////////////////////////////////////////////////////////////////////////////

PUB Sequence_Matcher            | player_input_bits
' this function matches sequences of events from the input controller, it
' uses globals to make things simple, the sequence it tries to match is stored
' in the global sequence[] array, and when/if found it sends a message by
' setting seq_fire_event = 1

' extract the digital bits word only from the player_input
player_input_bits := (player_input & $FF)

case seq_state

  SEQ_STATE_WAIT:
    ' wait until no key is pressed, then transition to ready state to try and catch another sequence
    if (player_input_bits == IID_NULL)
        if (++seq_counter > SEQ_COUNT_MIN)
            ' safe to transition into ready state and hunt for sequence
            seq_state    := SEQ_STATE_READY
            seq_counter  := 0
            seq_index    := 0
            seq_min_flag := 0

  SEQ_STATE_READY:
        ' this is the entry point to test the sequence whatever it may be, we know that the last command packet was empty
        ' so anything that comes thru can potentially start the state transition to match sequence
        ' step 1: test for starting command in sequence if found then transition to match sequence
        if (player_input_bits == sequence[seq_index])
            ' transition to match sequence and try and match this "potential"
            seq_state   := SEQ_STATE_MATCH_SEQUENCE
            seq_counter := 0 
       ' test for incorrect button press, if so reset to wait state
        elseif (player_input_bits <> IID_NULL) 
            ' send back to wait state, a wrong key was pressed
            seq_state    := SEQ_STATE_WAIT
            seq_counter  := 0
            ' else input was null, so its ok to stay in this state...        
  
  SEQ_STATE_MATCH_SEQUENCE:
        ' this is the primary matching logic, if we are here, the first button in the sequence is currently pressed, 
        ' so we have to make sure the press is long enough, but not too long

        ' first increment the sequence time counter which is used to time how long buttons are down
        ++seq_counter
        
        ' test for minimum time for botton down satisfied
        if ( (player_input_bits == sequence[seq_index]) and (seq_counter > SEQ_COUNT_MIN) and (seq_min_flag == 0))
            ' set minimum count satisfied flag
            seq_min_flag := 1
              
        ' test for early withdrawel from button press
        elseif ((player_input_bits <> sequence[seq_index]) and (seq_counter < SEQ_COUNT_MIN))
            seq_state    := SEQ_STATE_WAIT
            seq_counter  := 0

        ' test for next button in sequence pressed, or is this last button in sequence
        elseif ((seq_counter > SEQ_COUNT_MIN) and (player_input_bits == sequence[seq_index+1]))
            ' two case: this button is in the middle of the sequence or its the last
            if ((seq_index+1) == (seq_length-1))
              ' end of sequence, fire off event!
              seq_fire_event := 1
              ' move to wait for next sequence
              seq_state      := SEQ_STATE_WAIT
              seq_counter    := 0
            else 
              ' middle of sequence, consume button event and move to next
              seq_counter  := 0
              seq_index++
              seq_min_flag := 0

        ' test if maximum time has expired, no matter what we are done..
        elseif (seq_counter > SEQ_COUNT_MAX)
            ' player held button down too long, reset to wait state
            seq_state    := SEQ_STATE_WAIT
            seq_counter  := 0


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
              ' <---------------------------visible on screen-------------------------------->          |<------ to right of screen ---------->|              
              ' column     0      1      2      3      4      5      6      7      8      9             | 10     11     12     13     14     15

' level 0
tile_map0     word      $23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 0
              word      $23_00,$12_01,$12_01,$12_01,$12_01,$12_01,$12_01,$12_01,$12_01,$23_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $23_00,$1B_01,$13_01,$1B_01,$1B_01,$1B_01,$1B_01,$13_01,$1B_01,$23_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $23_00,$23_00,$12_01,$12_01,$12_01,$12_01,$12_01,$12_01,$23_00,$23_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $23_00,$23_00,$1C_01,$22_02,$1C_01,$1C_01,$22_02,$1C_01,$23_00,$23_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 4
              word      $23_00,$11_01,$11_01,$11_01,$11_01,$11_01,$11_01,$11_01,$11_01,$23_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 5
              word      $23_00,$10_01,$10_01,$10_01,$10_01,$10_01,$10_01,$10_01,$10_01,$23_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 6
              word      $23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 7
              word      $23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 8
              word      $23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 9
              word      $23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $23_00,$25_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$25_00,$23_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 11



' level 1
tile_map1     word      $00_00,$00_00,$13_01,$00_00,$00_00,$00_00,$00_00,$13_01,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 0
              word      $00_00,$00_00,$00_00,$12_01,$00_00,$00_00,$12_01,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $00_00,$00_00,$1B_01,$1B_01,$1B_01,$1B_01,$1B_01,$1B_01,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $00_00,$00_00,$1C_01,$23_02,$1C_01,$1C_01,$23_02,$1C_01,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $00_00,$14_01,$1C_01,$1C_01,$1C_01,$1C_01,$1C_01,$1C_01,$14_01,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 4
              word      $00_00,$14_01,$00_00,$1C_01,$00_00,$00_00,$1C_01,$00_00,$15_01,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 5
              word      $00_00,$15_01,$00_00,$15_01,$00_00,$00_00,$15_01,$00_00,$15_01,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 6
              word      $00_00,$00_00,$00_00,$00_00,$15_01,$15_01,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 7
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 8
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 9
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $23_00,$23_00,$24_00,$24_00,$24_00,$24_00,$24_00,$24_00,$23_00,$23_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 11

' level 2
tile_map2     word      $0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 0
              word      $0A_00,$17_01,$0A_00,$18_01,$0A_00,$19_01,$0A_00,$1A_01,$0A_00,$1B_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $10_01,$0A_00,$11_01,$0A_00,$12_01,$0A_00,$13_01,$0A_00,$14_01,$0A_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $10_01,$0A_00,$11_01,$0A_00,$12_01,$0A_00,$13_01,$0A_00,$14_01,$0A_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $10_01,$0A_00,$11_01,$0A_00,$12_01,$0A_00,$13_01,$0A_00,$14_01,$0A_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 4
              word      $10_01,$0A_00,$11_01,$0A_00,$12_01,$0A_00,$13_01,$0A_00,$14_01,$0A_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 5
              word      $23_02,$0A_00,$23_02,$0A_00,$23_02,$0A_00,$23_02,$0A_00,$23_02,$0A_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 6
              word      $10_01,$0A_00,$11_01,$0A_00,$12_01,$0A_00,$13_01,$0A_00,$14_01,$0A_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 7
              word      $0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 8
              word      $0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 9
              word      $0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $26_00,$26_00,$26_00,$26_00,$26_00,$26_00,$26_00,$26_00,$26_00,$26_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 11

' level 3
tile_map3     word      $07_00,$19_01,$07_00,$19_01,$07_00,$07_00,$19_01,$07_00,$19_01,$07_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 0
              word      $19_01,$19_01,$19_01,$19_01,$19_01,$19_01,$19_01,$19_01,$19_01,$19_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $0F_00,$0F_00,$0F_00,$19_01,$19_01,$19_01,$19_01,$0F_00,$0F_00,$0F_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $1B_01,$1B_01,$0F_00,$07_00,$07_00,$07_00,$07_00,$0F_00,$1B_01,$1B_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $1B_01,$1B_01,$0F_00,$19_01,$19_01,$19_01,$19_01,$0F_00,$1B_01,$1B_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 4
              word      $1C_01,$1C_01,$0F_00,$07_00,$07_00,$07_00,$07_00,$0F_00,$1C_01,$1C_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 5
              word      $1C_01,$1C_01,$0F_00,$19_01,$19_01,$19_01,$19_01,$0F_00,$1C_01,$1C_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 6
              word      $23_02,$07_00,$0F_00,$07_00,$07_00,$07_00,$07_00,$0F_00,$07_00,$23_02,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 7
              word      $07_00,$07_00,$0F_00,$07_00,$07_00,$07_00,$07_00,$0F_00,$07_00,$07_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 8
              word      $0F_00,$0F_00,$0F_00,$07_00,$07_00,$07_00,$07_00,$0F_00,$0F_00,$0F_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 9
              word      $07_00,$07_00,$07_00,$07_00,$07_00,$07_00,$07_00,$07_00,$07_00,$07_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $27_00,$27_00,$27_00,$27_00,$27_00,$27_00,$27_00,$27_00,$27_00,$27_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 11

' level 4
tile_map4     word      $11_01,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$11_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 0
              word      $23_02,$11_01,$11_01,$0A_00,$0A_00,$0A_00,$0A_00,$11_01,$11_01,$23_02,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $0A_00,$12_01,$12_01,$12_01,$0A_00,$0A_00,$12_01,$12_01,$12_01,$0A_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $13_01,$13_01,$23_02,$13_01,$0A_00,$0A_00,$13_01,$23_02,$13_01,$13_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $0A_00,$13_01,$0A_00,$0A_00,$13_01,$13_01,$0A_00,$0A_00,$13_01,$0A_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 4
              word      $14_01,$14_01,$14_01,$23_02,$14_01,$14_01,$23_02,$14_01,$14_01,$14_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 5
              word      $0A_00,$13_01,$0A_00,$12_01,$12_01,$12_01,$12_01,$0A_00,$13_01,$0A_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 6
              word      $11_01,$13_01,$12_01,$0A_00,$0A_00,$0A_00,$0A_00,$12_01,$13_01,$11_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 7
              word      $0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 8
              word      $0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 9
              word      $0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,$0A_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,$23_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 11

' level 5
tile_map5     word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 0
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$11_01,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $00_00,$23_02,$00_00,$00_00,$00_00,$00_00,$00_00,$12_01,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $13_01,$00_00,$00_00,$00_00,$00_00,$13_01,$14_01,$14_01,$14_01,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $15_01,$15_01,$00_00,$16_01,$16_01,$16_01,$17_01,$17_01,$18_01,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 4
              word      $00_00,$18_01,$18_01,$18_01,$19_01,$19_01,$00_00,$00_00,$1A_01,$1A_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 5
              word      $00_00,$1B_01,$1B_01,$1B_01,$00_00,$00_00,$00_00,$23_02,$00_00,$1C_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 6
              word      $00_00,$00_00,$1D_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 7
              word      $00_00,$00_00,$1E_01,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 8
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 9
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $28_00,$28_00,$28_00,$28_00,$28_00,$28_00,$28_00,$28_00,$28_00,$28_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 11

' level 6
tile_map6
              word      $00_00,$01_00,$02_00,$03_00,$04_00,$05_00,$06_00,$07_00,$00_01,$00_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 0
              word      $08_00,$09_00,$0a_00,$0b_00,$0c_00,$0d_00,$0e_00,$0f_00,$00_01,$00_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $10_00,$11_00,$12_00,$13_00,$14_00,$15_00,$16_00,$17_00,$00_01,$00_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $18_00,$19_00,$1a_00,$1b_00,$1c_00,$1d_00,$1e_00,$1f_00,$00_01,$00_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $20_00,$21_00,$22_00,$23_00,$24_00,$25_00,$26_00,$27_00,$00_01,$00_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 0
              word      $28_00,$29_00,$2a_00,$2b_00,$2c_00,$2d_00,$2e_00,$2f_00,$00_01,$00_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $30_00,$31_00,$32_00,$33_00,$34_00,$35_00,$36_00,$37_00,$00_01,$00_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 0
              word      $38_00,$39_00,$3a_00,$3b_00,$3c_00,$3d_00,$3e_00,$3f_00,$00_01,$00_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $40_00,$41_00,$42_00,$43_00,$44_00,$45_00,$46_00,$47_00,$00_01,$00_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 0
              word      $48_00,$49_00,$4a_00,$4b_00,$4c_00,$4d_00,$4e_00,$4f_00,$00_01,$00_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,$00_01,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 11
'              word      $50_00,$51_00,$52_00,$53_00,$54_00,$55_00,$56_00,$57_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 0
'              word      $58_00,$59_00,$5a_00,$5b_00,$5c_00,$5d_00,$5e_00,$5f_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1

' level 7
tile_map7     word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 0
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 4
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 5
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 6
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 7
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 8
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 9
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 11

' level 8
tile_map8     word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 0
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 4
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 5
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 6
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 7
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 8
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 9
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 11

' level 9
tile_map9     word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 0
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 4
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 5
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 6
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 7
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 8
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 9
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,          $00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 11


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

tile_blank    long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1 ' tile 0
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_1_1_1
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_1_1_1
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_1_1_1
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_1_1_1
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_1_1_1
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_1_1_1
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_1_1_1
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_1_1_1
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_1_1_1
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_1_1_1
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_1_1_1
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_1_1_1
              long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_1_1_1

' normal block
tile_block1   long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1

' umovable block
tile_block2   long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_1_1 ' tile 1
              long      %%3_0_0_0_0_0_0_0_0_0_0_0_0_1_1_1
              long      %%0_3_0_0_0_0_0_0_0_0_0_0_1_1_1_1
              long      %%0_0_3_0_0_0_0_0_0_0_0_1_1_1_1_1
              long      %%0_0_0_3_0_0_0_0_0_0_1_1_1_1_1_1
              long      %%0_0_0_0_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%0_0_0_0_1_0_0_0_0_0_1_1_1_1_1_1
              long      %%0_0_0_0_1_0_0_0_0_0_1_1_1_1_1_1
              long      %%0_0_0_0_1_0_0_0_0_0_1_1_1_1_1_1
              long      %%0_0_0_0_1_0_0_0_0_0_1_1_1_1_1_1
              long      %%0_0_0_0_1_0_0_0_0_0_1_1_1_1_1_1
              long      %%0_0_0_0_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%0_0_0_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%0_0_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%0_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
              long      %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1




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

' right half of paddle (remember images are mirrored)

                      ' bitmap for sprite use, uses the palette of the tile its rendered into
sprite_bitmap_0         long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0'0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0'0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0'0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0'0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_2_2_2_0_0_0_0_0_0_0'0_0_0_0_0_0_0_0_2_2_0_0_0_0_0_0
                        long      %%0_0_0_0_0_2_2_3_0_0_2_2_2_2_0_0'3_3_3_3_3_3_3_0_2_2_2_0_0_0_0_0
                        long      %%0_0_0_0_0_2_3_2_2_2_2_2_2_2_2_2'2_2_2_2_2_2_2_0_2_2_2_0_0_0_0_0
                        long      %%0_0_0_0_0_2_2_2_2_3_3_3_3_3_3_3'2_2_2_2_2_2_2_0_2_2_2_0_0_0_0_0
                        long      %%0_0_0_0_0_2_2_2_2_2_2_2_2_2_2_2'2_2_2_2_2_2_2_0_2_2_2_0_0_0_0_0
                        long      %%0_0_0_0_0_2_2_2_2_2_2_2_2_2_2_2'2_2_2_2_2_2_2_0_2_2_2_0_0_0_0_0
                        long      %%0_0_0_0_0_2_2_2_2_2_2_2_2_2_2_2'2_2_2_2_2_2_2_0_2_2_2_0_0_0_0_0
                        long      %%0_0_0_0_0_2_2_2_0_0_1_1_1_1_1_1'1_1_1_1_1_1_1_0_2_2_2_0_0_0_0_0
                        long      %%0_0_0_0_0_0_2_2_2_0_0_0_0_0_0_0'0_0_0_0_0_0_0_0_2_2_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_1_1_1_0_0_0_0_0_0_0'0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0'0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0'0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0


' the mask needs to be a NEGATIVE of the bitmap, basically a "stencil" where we are going to write the sprite into, all the values are 0 (mask) or 3 (write thru)
' however, the algorithm needs a POSITIVE to make some of the shifting easier, so we only need to apply the rule to each pixel of the bitmap:
' if (p_source == 0) p_dest = 0, else p_dest = 3
sprite_bitmap_mask_0    long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0'0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0'0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0'0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0'0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_3_3_3_0_0_0_0_0_0_0'0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_0_0_3_3_3_3_0_0'3_3_3_3_3_3_3_0_2_2_0_0_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_3_3_3_3_3_3_3_3'2_2_2_2_2_2_2_0_2_2_2_0_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_3_3_3_3_3_3_3_3'2_2_2_2_2_2_2_0_2_2_2_0_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_3_3_3_3_3_3_3_3'2_2_2_2_2_2_2_0_2_2_2_0_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_3_3_3_3_3_3_3_3'2_2_2_2_2_2_2_0_2_2_2_0_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_3_3_3_3_3_3_3_3'2_2_2_2_2_2_2_0_2_2_2_0_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_3_0_0_3_3_3_3_3'1_1_1_1_1_1_1_0_2_2_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_3_3_3_0_0_0_0_0_0_0'0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_3_3_3_0_0_0_0_0_0_0'0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0'0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0'0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

' left half of paddle (remember images are mirrored)
sprite_bitmap_1         long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_2_2_2_0_0_0_0_0_0
                        long      %%0_0_2_2_2_2_0_0_2_2_2_0_0_0_0_0
                        long      %%2_2_2_2_2_2_2_2_2_2_2_0_0_0_0_0
                        long      %%3_3_3_3_3_3_3_2_2_2_2_0_0_0_0_0
                        long      %%2_2_2_2_2_2_2_2_2_2_2_0_0_0_0_0
                        long      %%2_2_2_2_2_2_2_2_2_2_2_0_0_0_0_0
                        long      %%2_2_2_2_2_2_2_2_2_1_2_0_0_0_0_0
                        long      %%1_1_1_1_1_1_0_0_1_2_2_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_2_2_2_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0


' the mask needs to be a NEGATIVE of the bitmap, basically a "stencil" where we are going to write the sprite into, all the values are 0 (mask) or 3 (write thru)
' however, the algorithm needs a POSITIVE to make some of the shifting easier, so we only need to apply the rule to each pixel of the bitmap:
' if (p_source == 0) p_dest = 0, else p_dest = 3
sprite_bitmap_mask_1    long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_3_0_0_0_0_0_0
                        long      %%0_0_3_3_3_3_0_0_3_3_3_0_0_0_0_0
                        long      %%3_3_3_3_3_3_3_3_3_3_3_0_0_0_0_0
                        long      %%3_3_3_3_3_3_3_3_3_3_3_0_0_0_0_0
                        long      %%3_3_3_3_3_3_3_3_3_3_3_0_0_0_0_0
                        long      %%3_3_3_3_3_3_3_3_3_3_3_0_0_0_0_0
                        long      %%3_3_3_3_3_3_3_3_3_3_3_0_0_0_0_0
                        long      %%3_3_3_3_3_3_0_0_3_3_3_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_3_3_3_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0

' the ball
sprite_bitmap_2         long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_3_3_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_3_1_0_0_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_3_1_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_3_3_1_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_1_1_1_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0


' the mask needs to be a NEGATIVE of the bitmap, basically a "stencil" where we are going to write the sprite into, all the values are 0 (mask) or 3 (write thru)
' however, the algorithm needs a POSITIVE to make some of the shifting easier, so we only need to apply the rule to each pixel of the bitmap:
' if (p_source == 0) p_dest = 0, else p_dest = 3
sprite_bitmap_mask_2    long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_3_3_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_3_3_0_0_0_0_0_0
                        long      %%0_0_0_0_0_3_3_3_3_3_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_3_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_3_3_3_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0
                        long      %%0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0







' /////////////////////////////////////////////////////////////////////////////

              ' palette memory (1..255 palettes) each palette 4-BYTEs or 1-LONG
              ' pacman ish palette needs 4 colors in each palette to have certain properties
              ' color 0 - used for black
              ' color 1 - used for walls (unless, paddle will cross a wall, we can reuse this color for the paddle if we need 2 colors for paddle, or have multiple colored walls)
              ' color 2 - used for paddle color (can change possibly tile to tile)
              ' color 3 - white
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

' the palettes
' conventions for color use and mapping:
' color 0: light shade of base block color
' color 1: dark shade of base block color
' color 2: used for primary paddle color
' color 3: always white             
palette_map


              long $0a_0a_02_0a ' pallete 0 ' lighter palettes, same colors, better for blocks
              long $1a_1a_02_1a ' pallete 1
              long $2a_2a_02_2a ' pallete 2
              long $3a_3a_02_3a ' pallete 3
              long $4a_4a_02_4a ' pallete 4
              long $5a_5a_02_5a ' pallete 5
              long $6a_6a_02_6a ' pallete 6
              long $7a_7a_02_7a ' pallete 7
              long $8a_8a_02_8a ' pallete 8
              long $9a_9a_02_9a ' pallete 9
              long $aa_aa_02_Aa ' pallete 10
              long $ba_ba_02_Ba ' pallete 11
              long $ca_ca_02_Ca ' pallete 12
              long $da_da_02_Da ' pallete 13
              long $ea_ea_02_Ea ' pallete 14
              long $fa_fa_02_Fa ' pallete 15

              long $0b_0b_02_0b ' pallete 0 ' lighter palettes, same colors, better for blocks
              long $1b_1b_02_1b ' pallete 1
              long $2b_2b_02_2b ' pallete 2
              long $3b_3b_02_3b ' pallete 3
              long $4b_4b_02_4b ' pallete 4
              long $5b_5b_02_5b ' pallete 5
              long $6b_6b_02_6b ' pallete 6
              long $7b_7b_02_7b ' pallete 7
              long $8b_8b_02_8b ' pallete 8
              long $9b_9b_02_9b ' pallete 9
              long $ab_ab_02_Ab ' pallete 10
              long $bb_bb_02_Bb ' pallete 11
              long $cb_cb_02_Cb ' pallete 12
              long $db_db_02_Db ' pallete 13
              long $eb_eb_02_Eb ' pallete 14
              long $fb_fb_02_Fb ' pallete 15


              long $0c_0c_02_0c ' pallete 0 ' lighter palettes, same colors, better for blocks
              long $1c_1c_02_1c ' pallete 1
              long $2c_2c_02_2c ' pallete 2
              long $3c_3c_02_3c ' pallete 3
              long $4c_4c_02_4c ' pallete 4
              long $5c_5c_02_5c ' pallete 5
              long $6c_6c_02_6c ' pallete 6
              long $7c_7c_02_7c ' pallete 7
              long $8c_8c_02_8c ' pallete 8
              long $9c_9c_02_9c ' pallete 9
              long $ac_ac_02_Ac ' pallete 10
              long $bc_bc_02_Bc ' pallete 11
              long $cc_cc_02_Cc ' pallete 12
              long $dc_dc_02_Dc ' pallete 13
              long $ec_ec_02_Ec ' pallete 14
              long $fc_fc_02_Fc ' pallete 15

              long $0d_0d_02_0d ' pallete 0 ' lighter palettes, same colors, better for blocks
              long $1d_1d_02_1d ' pallete 1
              long $2d_2d_02_2d ' pallete 2
              long $3d_3d_02_3d ' pallete 3
              long $4d_4d_02_4d ' pallete 4
              long $5d_5d_02_5d ' pallete 5
              long $6d_6d_02_6d ' pallete 6
              long $7d_7d_02_7d ' pallete 7
              long $8d_8d_02_8d ' pallete 8
              long $9d_9d_02_9d ' pallete 9
              long $ad_ad_02_Ad ' pallete 10
              long $bd_bd_02_Bd ' pallete 11
              long $cd_cd_02_Cd ' pallete 12
              long $dd_dd_02_Dd ' pallete 13
              long $ed_ed_02_Ed ' pallete 14
              long $fd_fd_02_Fd ' pallete 15

              long $0e_0e_02_0e ' pallete 0 ' lighter palettes, same colors, better for blocks
              long $1e_1e_02_1e ' pallete 1
              long $2e_2e_02_2e ' pallete 2
              long $3e_3e_02_3e ' pallete 3
              long $4e_4e_02_4e ' pallete 4
              long $5e_5e_02_5e ' pallete 5
              long $6e_6e_02_6e ' pallete 6
              long $7e_7e_02_7e ' pallete 7
              long $8e_8e_02_8e ' pallete 8
              long $9e_9e_02_9e ' pallete 9
              long $ae_ae_02_Ae ' pallete 10
              long $be_be_02_Be ' pallete 11
              long $ce_ce_02_Ce ' pallete 12
              long $de_de_02_De ' pallete 13
              long $ee_ee_02_Ee ' pallete 14
              long $fe_fe_02_Fe ' pallete 15


              long $0f_0f_0f_0f ' pallete 0 ' lighter palettes, same colors, better for blocks
              long $1f_1f_1f_1f ' pallete 1
              long $2f_2f_2f_2f ' pallete 2
              long $3f_3f_3f_3f ' pallete 3
              long $4f_4f_4f_4f ' pallete 4
              long $5f_5f_5f_5f ' pallete 5
              long $6f_6f_6f_6f ' pallete 6
              long $7f_7f_7f_7f ' pallete 7
              long $8f_8f_8f_8f ' pallete 8
              long $9f_9f_9f_9f ' pallete 9
              long $af_af_Af_Af ' pallete 10
              long $bf_bf_Bf_Bf ' pallete 11
              long $cf_cf_Cf_Cf ' pallete 12
              long $df_df_Df_Df ' pallete 13
              long $ff_ff_Ff_Ff ' pallete 15
              