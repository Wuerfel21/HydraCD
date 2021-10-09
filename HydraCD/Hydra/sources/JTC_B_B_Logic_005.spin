' //////////////////////////////////////////////////////////////////////
' Ball Buster - breakout clone          
' Game logic
' AUTHOR: JT Cook
' LAST MODIFIED: 2.24.06

'///////////////////////////////////////////////////////////////////////
' CONSTANTS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
CON
' locations of addresses
  _player_x = 4
  _player_y = 8
  _ball_x = 12
  _ball_y = 16
  _ball_x_dir = 20
  _ball_y_dir = 24
  _ball_bounce = 28
  
'///////////////////////////////////////////////////////////////////////
' VARIABLES ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
VAR
  long cogon, cog
  long command
'address holders
  long pl_x_adr
  long pl_y_adr
  long bll_x_adr
  long bll_y_adr
  long bll_bounce_adr
  long score_adr_
  long brick_wall_adr
  long game_sound_adr
  long ball_angle_adr_
  long level_adr_
' byte level_
'///////////////////////////////////////////////////////////////////////
' OBJECTS //////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

'///////////////////////////////////////////////////////////////////////
' FUNCTIONS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

'// PUB start //////////////////////////////////////////////////////////

PUB start : okay

  stop
  okay := cogon := (cog := cognew(@entry,@command)) > 0


'///////////////////////////////////////////////////////////////////////

PUB stop

'' Stop game logic cog - frees a cog

  if cogon~
    cogstop(cog)

'///////////////////////////////////////////////////////////////////////
PUB Get_Mem_Address(player_x_, player_y_, ball_x_, ball_y_,ball_bounce, score_, brick_, game_snd)
    pl_x_adr:=player_x_
    pl_y_adr:=player_y_
    bll_x_adr:=ball_x_
    bll_y_adr:=ball_y_
    bll_bounce_adr:=ball_bounce
    score_adr_:=score_
    brick_wall_adr:=brick_
    game_sound_adr:=game_snd
    ball_angle_adr_:=@ball_angle
    level_adr_:=@levels
    command:=1 'grabs address for asm code
'///////////////////////////////////////////////////////////////////////
PUB Game_Loop                          
    command:=2
'///////////////////////////////////////////////////////////////////////
PUB New_Level_
    command:=3
PUB Load_Level_
    command:=4
'///////////////////////////////////////////////////////////////////////
' DATA /////////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

DAT

                     org
' Entry
entry 
loop                    rdlong  t1,par          wz      'wait for command
        if_z            jmp     #loop
        cmp t1, #1 wz, wc
        if_e call #get_var
        cmp t1, #3 wz
        if_e mov game_level, #0
        if_e call #load_level
        cmp t1, #4 wz
        if_e call #load_level
        'main loop
        cmp t1, #2 wz
        if_ne jmp loop_end
        rdbyte playr_x, player_x_adr   'grab variables
        rdbyte playr_y, player_y_adr
        rdbyte bll_x, ball_x_adr
        rdbyte bll_y, ball_y_adr
        rdbyte bll_bounce, ball_bounce_adr
        rdbyte sound_que, sound_que_adr
        rdlong game_score, score_adr
        call #check_wall    ' sets player limits
        call #check_pl_ball ' check colision with paddle and ball
        call #check_b_wall              ' check colision with ball walls
        call #check_bll_brick    'check colision between brick and ball
        call #check_bll_b ' move ball
        call #check_bll_b ' 
        call #check_bll_b ' this is not a typo, this is 3x for faster ball
        wrbyte playr_x, player_x_adr   'write variables
        wrbyte playr_y, player_y_adr
        wrbyte bll_x, ball_x_adr
        wrbyte bll_y, ball_y_adr
        wrbyte bll_bounce, ball_bounce_adr
        wrbyte sound_que, sound_que_adr
        wrlong game_score, score_adr
loop_end 'clear out selecter
        mov t1, #0
        wrlong t1, PAR
        jmp #loop       
'''''''''''''''''''''''''''''''''
get_var ' get variables
        mov temp_ptr, PAR
        add temp_ptr, #4         'grabs address for player_x
        rdlong player_x_adr, temp_ptr
        add temp_ptr, #4         'grabs address for player_y
        rdlong player_y_adr, temp_ptr
        add temp_ptr, #4         'grabs address for ball_x
        rdlong ball_x_adr, temp_ptr
        add temp_ptr, #4         'grabs address for ball_y
        rdlong ball_y_adr, temp_ptr
        add temp_ptr, #4         'grabs address for ball_x_dir
        rdlong ball_bounce_adr, temp_ptr
        add temp_ptr, #4         'grabs address for score
        rdlong score_adr, temp_ptr
        add temp_ptr, #4         'grabs address for brick_wall
        rdlong brick_adr, temp_ptr
        add temp_ptr, #4         'grabs sound que address
        rdlong sound_que_adr, temp_ptr
        add temp_ptr, #4         'grabs address for ball_angle
        rdlong ball_angle_adr, temp_ptr
        add temp_ptr, #4         'grabs address for levels
        rdlong level_adr, temp_ptr
Get_Var_ret ret
'''''''''''''''''''''''''''''''''
check_wall ' check player limits
        mins playr_x, #16    ' check left limit on wall
        maxs playr_x, #112   ' check right limit on wall
check_wall_ret ret
'''''''''''''''''''''''''''''''
check_pl_ball  ' check colision with paddle and ball
        mov temp1, playr_y
        add temp1, #7
        mov temp2, bll_y
        add temp2, #3
        cmp temp1, temp2 wz, wc ' check top of paddle
if_a    jmp #check_pl_ball_ret
        add temp1, #1
        sub temp2, #3
        cmp temp1, temp2 wz, wc 'check bottom of paddle
if_b    jmp #check_pl_ball_ret
        mov temp1, bll_x
        add temp1, #3
        cmp playr_x,temp1 wz, wc' check left side of paddle
if_a    jmp #check_pl_ball_ret
        sub temp1, #3
        mov temp2, playr_x
        add temp2, #32
        cmp temp2, temp1 wz, wc' check right side of paddle
if_b    jmp #check_pl_ball_ret
        mov temp2, bll_x
        add temp2, #4
        sub temp2, playr_x 'subtract ball_x from paddle_x and divide by 6 to get 0-6
        mov temp1, #0
:Divide_X    'divide by 6
        cmp temp2, #6 wz,wc
        if_ae sub temp2, #6
        if_ae add temp1, #1
        if_ae jmp #:Divide_X
        mov temp2, #:Change_Angle
        shl temp1, #1 ' *2  mov instruction and jmp instruction
        add temp2, temp1
        mov sound_que, #3        'play sound for hitting paddle
        jmp temp2

:Change_Angle
        mov ball_dir, #0
        jmp check_pl_ball_ret
        mov ball_dir, #3
        jmp check_pl_ball_ret
        mov ball_dir, #6
        jmp check_pl_ball_ret
        mov ball_dir, #15
        jmp check_pl_ball_ret
        mov ball_dir, #12
        jmp check_pl_ball_ret
        mov ball_dir, #9
        jmp check_pl_ball_ret
        mov ball_dir, #9
        jmp check_pl_ball_ret
        mov ball_dir, #9
        jmp check_pl_ball_ret
check_pl_ball_ret ret
        
'''''''''''''''''''''''''''''''
check_b_wall    ' set ball limits
        cmp bll_x, #139 wz, wc  ' check right side of wall
if_a    mov bll_x_dir, #(-1) & $1FF
if_a    mov sound_que, #2  'play sound for hitting wall
        cmp bll_x, #17 wz, wc ' check left side of wall                          
if_b    mov bll_x_dir, #1
if_b    mov sound_que, #2  'play sound for hitting wall
        cmp bll_y, #179 wz, wc  'check top of wall
if_a    mov bll_y_dir, #(-1) & $1FF
if_a    mov sound_que, #2  'play sound for hitting wall
        cmp bll_y, #2 wz, wc 'check bottom of wall
        if_b mov bll_bounce, #5 ' ball hit bottom of screen, subtract life
        if_b mov bll_y, #4 'move ball up a bit
check_b_wall_ret ret
'''''''''''''''''''''''''''''''
check_bll_b     'move ball and paddle
       cmp bll_bounce, #0 wz           'if ball is on paddle
if_ne  cmp bll_bounce, #4 wz
if_ne  jmp #:in_play 
       mov bll_x, playr_x
       add bll_x, #16
       mov bll_y, playr_y
       add bll_y, #8
       mov bll_x_old, bll_x
       mov bll_y_old, bll_y
       mov ball_dir, #9
       mov sound_que, #0 'turn off sound
       jmp #check_bll_b_ret        
:in_play                               'if ball is in play
       cmp bll_bounce, #1 wz
if_ne  jmp check_bll_b_ret
       'get the direction of the ball
       cmp bll_x_dir, #1 wz   ' change direction of ball
if_e   add ball_dir, #9
if_e   mov bll_x, bll_x_old
if_e   mov bll_y, bll_y_old
       cmp bll_x_dir, #(-1) & $1FF wz
if_e   sub ball_dir, #9
if_e   mov bll_x, bll_x_old
if_e   mov bll_y, bll_y_old
       cmp bll_y_dir, #(-1) & $1FF wz
if_e   add ball_dir, #18
if_e   mov bll_x, bll_x_old
if_e   mov bll_y, bll_y_old
       cmp bll_y_dir, #1 wz
if_e   sub ball_dir, #18
if_e   mov bll_x, bll_x_old
       mov bll_x_dir, #0
       mov bll_y_dir, #0
       mov bll_x_old, bll_x
       mov bll_y_old, bll_y
       cmp ball_dir, #35 wz,wc 'make sure ball does not get stuck
       if_a mov ball_dir, #33
       mov temp_ptr, ball_angle_adr
       add temp_ptr, ball_dir
       rdbyte ball_dir_0, temp_ptr
       add temp_ptr, #1
       rdbyte ball_dir_1, temp_ptr
       add temp_ptr, #1
       rdbyte ball_dir_2, temp_ptr
:get_dir
       cmp ball_dir_c, #0 wz
       if_e mov temp2, ball_dir_0
       cmp ball_dir_c, #1 wz
       if_e mov temp2, ball_dir_1
       cmp ball_dir_c, #2 wz
       if_e mov temp2, ball_dir_2
:move_ball
       cmp temp2, #0 wz       'direction 0, reset counter
       if_e mov ball_dir_c, #0
       if_e jmp #:get_dir
       cmp temp2, #1  wz      ' move up
       if_e add bll_y, #1
       cmp temp2, #2  wz      ' move down
       if_e sub bll_y, #1
       cmp temp2, #3  wz      ' move left
       if_e sub bll_x, #1
       cmp temp2, #4  wz      ' move right
       if_e add bll_x, #1
       add ball_dir_c, #1 
       cmp ball_dir_c, #2 wz, wc ' make sure it doesn't overflow
       if_a mov ball_dir_c, #0
       
check_bll_b_ret ret
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''
check_bll_brick      'check ball colision with bricks
        mov temp1, #0  'for loop to check all 4 sides of ball
:New_Side
        mov bll_x_check, bll_x   ' use ball_x_check as temp place holders
        mov bll_y_check, bll_y
        sub bll_x_check, #16
        sub bll_y_check, #4
        cmp temp1, #0 wz ' top of ball?
if_ne   jmp #:Bottom
        add bll_x_check, #1      'go to center of ball
        jmp #:Check_ball
:Bottom
        cmp temp1, #1 wz ' bottom of ball?
if_ne   jmp #:Left
        add bll_x_check, #1     ' go to center of ball
        sub bll_y_check, #6     ' go to bottom of ball(6?)
        jmp #:Check_ball
:Left   
        cmp temp1, #2 wz ' left of ball?
if_ne   jmp #:Right
        sub bll_y_check, #3     'go to center of ball
        jmp #:Check_ball
:Right
        cmp temp1, #3 wz ' right of ball?
if_ne   jmp #:Next_Side
        sub bll_y_check, #3 ' go to center of ball
        add bll_x_check, #3 ' go to right side of ball
:Check_ball
        cmp bll_y_check, #80 wz, wc ' check to see if ball is in range of bricks
if_b    jmp #:Next_Side
        sub bll_y_check, #80 ' find the brick x, y coords
        shr bll_y_check, #3  ' /8
        shr bll_x_check, #4  ' /16
        cmp bll_x_check, #7 wz,wc ' make sure we are in limits for x blocks
if_a    jmp #:Next_Side
        cmp bll_y_check, #7 wz,wc ' make sure we are in limits for y blocks
if_a    jmp #:Next_Side
        mov brick_check, bll_y_check  'find which brick we just hit
        shl brick_check, #3 ' *8
        add brick_check, bll_x_check
        cmp brick_check, #63
        if_a mov brick_check, #63
        mov temp_ptr, brick_adr                                                          'grab the address for the brick
        add temp_ptr, brick_check
        rdbyte brick, temp_ptr    ' grab values for that brick
        cmp brick, #1 wz 'check to see if brick is solid or not
if_ne   jmp #:Next_Side
        add game_score, #10 'if we just hit brick, add to score
        mov sound_que, #1        'play sound for hitting brick
        mov brick, #0    'clear out brick
        wrbyte brick, temp_ptr  'write new openeing to wall                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      
        mov bll_bounce, #2 'let game know to redraw playfield
        wrbyte bll_bounce, ball_bounce_adr
        sub brick_cnt, #1
        cmp brick_cnt, #0 wz  ' if we clear out all bricks, load new level
        if_e mov bll_bounce, #6
        if_e add game_level, #1 'advance to next level        
'       if_e mov bll_y, #20
'       if_e call #Load_Level
'       cmp bll_bounce, #6 wz
'       if_e jmp #check_bll_brick_ret
'       if_e jmp #loop_end
        mov temp_ptr, brick_adr
        add temp_ptr, #64
        wrbyte brick_check, temp_ptr ' tell program which brick to kill
        cmp temp1, #0 wz 'top of ball
if_e    mov bll_y_dir, #(-1) & $1FF
if_e    jmp #check_bll_brick_ret
        cmp temp1, #1 wz 'bottom of ball
if_e    mov bll_y_dir, #1
if_e    jmp #check_bll_brick_ret
        cmp temp1, #2 wz 'left of ball
if_e    mov bll_x_dir, #1
if_e    jmp #check_bll_brick_ret
        cmp temp1, #3 wz,wc 'right of ball
if_ae   mov bll_x_dir, #(-1) & $1FF        

:Next_Side
        add temp1, #1   'increase counter(choose a different side of ball)
        cmp temp1, #4 wz, wc 'make sure we are in bounds of counter
if_b    jmp #:New_side     'if we are in bounds, loop back to top                               
check_bll_brick_ret ret
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Load_Level
        mov temp3, #0           '2nd counter
        mov brick_cnt, #0       'reset brick counter
        mov t2, brick_adr 'grab address for bricks
        mov temp_ptr, level_adr 'grab address for level
        cmp game_level, #9 wz,wc
        if_a mov game_level, #0 'reset levels after 10
        mov temp1, game_level ' grab current level
        shl temp1, #3          '*8
        add temp_ptr, temp1 'grab correct level
        rdbyte brick, temp_ptr 'read one row(8bits) of the level
        mov temp1, #0                   'reset counter
:Next_brick
        mov temp2, brick
        and temp2, #%00000001   'mask off 7 bits
        add brick_cnt, temp2    'add to brick counter
        wrbyte temp2, t2 'write brick
        shr brick, #1           'shift bricks over
        add t2, #1              'add to address
        add temp3, #1           'add to counter
        add temp1, #1
        cmp temp1, #8 wz        'make sure we are in limits
        if_ne jmp #:Next_brick
        mov temp1, #0
        add temp_ptr, #1         'read next row
        rdbyte brick, temp_ptr   'read one row(8bits) of the level
        cmp temp3, #64 wz, wc    'make sure we are in limits of bricks
        if_b jmp #:Next_brick
        
Load_Level_ret ret
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''
''' variables
player_x_adr long 1
player_y_adr long 1
ball_x_adr long 1
ball_y_adr long 1
ball_bounce_adr long 1
ball_angle_adr long 1
score_adr long 1
brick_adr long 1
sound_que_adr long 1
level_adr long 1
temp_ptr long 1
t1 long 1
t2 long 1
game_score long 1
brick_cnt res 1  
temp1 res 1
temp2 res 1
temp3 res 1
sound_que res 1
game_level res 1
playr_x res 1
playr_y res 1
bll_x res 1
bll_y res 1
bll_x_old res 1
bll_y_old res 1
bll_x_dir res 1
bll_y_dir res 1
bll_bounce res 1
bll_x_check res 1
bll_y_check res 1
brick_check res 1
brick res 1
ball_dir_c res 1
ball_dir res 1
ball_dir_0 res 1
ball_dir_1 res 1
ball_dir_2 res 1
' ball direction, 0-start over, 1-up, 2-down, 3-left, 4-right
ball_angle byte 3,3,1,3,1,0,3,1,1 'upper left
           byte 4,4,1,4,1,0,4,1,1 'upper right
           byte 3,3,2,3,2,0,3,2,2 'lower left
           byte 4,4,2,4,2,0,4,2,2 'lower right
' hit left side, add 9, hit right side, sub 9
' hit top, added 18, hit bottom sub 18
' levels made up of 8 bytes
levels
'   byte   128,0,0,0,0,0,0,0 'debug
    byte 4,142,203,219,113,113,32,32 'sine wave
    byte 255,126,60,24,24,60,126,255 'double triangle
    byte 255,0,169,47,169,169,0,255 ' Hi !
    byte  56, 68,130,254,255,214, 84, 56 'smiley face
    byte  60,126,255,165,165,255,126, 60 'ufo
    byte 60,78,191,191,253,253,114,60 'ball
    byte   1,  3,  7, 15, 31, 63,127,255 'angle
    byte 36,66,36,126,219,219,126,60 'Alien
    byte 24,24,60,60,126,126,255,255 'triangle facing down
    byte 170,85,170,85,170,85,170,85     'checkard board