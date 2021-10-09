' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

   _clkmode = xtal2 + pll8x           ' enable external clock and pll times 8
   _xinfreq = 10_000_000 + 0000        ' set frequency to 10 MHZ plus some error
   _stack = ($3000 + $3000 + 64) >> 2 ' accomodate display memory and stack

   ' graphics driver and screen constants
   PARAMCOUNT       = 14        
   OFFSCREEN_BUFFER = $2000           ' offscreen buffer
   ONSCREEN_BUFFER  = $5000           ' onscreen buffer
  

   ' Size of graphics tile map
   X_TILES          = 16
   Y_TILES          = 12

   STONE_HALF       = 8/2
   STONE_OFFSET     = STONE_HALF+1

   SCREEN_ORG_X     = 0
   SCREEN_ORG_Y     = 0
   SCREEN_WIDTH     = 256
   SCREEN_HEIGHT    = 192
  
   ' Colors
   ' 0 ' Gray (background)
   ' 1 ' White
   ' 2 ' Blue
   ' 3 ' Red
   '                   Color 3     Color 2     color 1     color 0
   'PALETTE_GAME    = %1100_1_011__0001_1_011__0000_0_111__0110_1_100
   PALETTE_GAME     = %1100_1_011__0001_1_011__0000_0_111__0000_0_100
  
   ' GAME_STATES
   GAME_STATE_RUN               = 0
   GAME_STATE_START             = 1
   GAME_STATE_END               = 2
   GAME_STATE_GAMEOVER          = 3
   GAME_STATE_HINT              = 4
   GAME_STATE_FLASH_MOVE        = 5
   GAME_STATE_COMPUTER_MOVE     = 6
   GAME_STATE_PASS              = 7
   GAME_STATE_FLASH_TEXT        = 8
   GAME_STATE_COMPUTER_MOVE_CONT = 9
   GAME_STATE_ATTRACT           = 10
   GAME_STATE_GAMEOVER_FLASH    = 11
  
   GRID_SIZE = 15
   GRID_COUNT = (GRID_SIZE * GRID_SIZE)
   GRID_HALF = GRID_SIZE / 2
   GRID_LOOP = GRID_SIZE - 1

   GRIDLINES_WIDTH = 165
   GRIDLINES_HEIGHT = 165
   GRIDLINES_STEP = 11

   'Current Players
   PLAYER_1    = 0
   PLAYER_2    = 1 ' Computer
   PLAYER_VALID = 2
   PLAYER_FREE = 3

   USE_DEFAULT      = -1
   REVERSE_STONES   = TRUE
   COUNT_STONES_ONLY = FALSE

   ' Mouse constants
   LEFT_CLICK   = 0
   RIGHT_CLICK  = 1
   MOUSE_START_Y = SCREEN_HEIGHT/2
   MOUSE_START_X = SCREEN_WIDTH/2

   ' Status string indexes
   MESSAGE_FIRST  = 0
   MESSAGE_PASS_1 = 0   'Player 1 Passes
   MESSAGE_PASS_2 = 1   'Player 2 Passes
   MESSAGE_WIN    = 2   'Player 1 Wins!!
   MESSAGE_LOSE   = 3   'Player 2 Wins!!
   MESSAGE_TIE    = 4   'Ahh, Tie Game!!
   MESSAGE_START  = 5   'Click To Start
   MESSAGE_1_UP   = 6   'Player 1 UP
   MESSAGE_2_UP   = 7   'Player 2 UP


   XOR_MODE = 1
  
  
'///////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
VAR
  long  tv_status     '0/1/2 = off/visible/invisible           read-only
  long  tv_enable     '0/? = off/on                            write-only
  long  tv_pins       '%ppmmm = pins                           write-only
  long  tv_mode       '%ccinp = chroma,interlace,ntsc/pal,swap write-only
  long  tv_screen     'pointer to screen (words)               write-only
  long  tv_colors     'pointer to colors (longs)               write-only               
  long  tv_hc         'horizontal cells                        write-only
  long  tv_vc         'vertical cells                          write-only
  long  tv_hx         'horizontal cell expansion               write-only
  long  tv_vx         'vertical cell expansion                 write-only
  long  tv_ho         'horizontal offset                       write-only
  long  tv_vo         'vertical offset                         write-only
  long  tv_broadcast  'broadcast frequency (Hz)                write-only
  long  tv_auralcog   'aural fm cog                            write-only

  word  Screen[X_TILES * Y_TILES] ' storage for screen tile map
  
  'long Palette[64]               ' color look up table
  long  Palette[1]                ' color look up table
  long  Stones[3]
  byte  ClickB[2]
  byte  Grid[GRID_COUNT]
  long  MouseX, MouseY, LastMouseX, LastMouseY, GenCount, Rand
  Byte  GameState, Col, Row, Player, FlashCtr,Redraw, LastState, Score[2], Frames

' word debug,debug2
  

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ
   tv    : "tv_drv_010.spin"         ' instantiate a tv object
   gr    : "RGW_graphics_drv_011.spin" ' instantiate a graphics object
   mouse : "mouse_iso_010.spin"

'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
PUB start | lIndex, lRetState, lPtr, lX, lY

   'start tv
   longmove(@tv_status, @tvparams, paramcount)
   tv_screen := @screen
   tv_colors := @Palette
   tv.start(@tv_status)

   ' Setup the 4 colors for Palette[0] (main game palette).
   Palette[0] := PALETTE_GAME  

   
   ' Init tile screen map to bit buffer, init all tiles to use palette 0.
   repeat lX from 0 to tv_hc - 1
      repeat lY from 0 to tv_vc - 1
         screen[lY * tv_hc + lX] := CONSTANT(onscreen_buffer >> 6) + lY + lX * tv_vc

   ' Start and setup graphics 256x192, with orgin (0,0) at lower left of screen
   gr.start
   gr.setup(X_TILES, Y_TILES, SCREEN_ORG_X, SCREEN_ORG_Y, offscreen_buffer)

   ' Start mouse driver with mouse in about the middle of the screen.
   MouseX := LastMouseX := MOUSE_START_X
   MouseY := LastMouseY := MOUSE_START_Y
   mouse.start(2)
   
   ' Setup defaults
   GameState := GAME_STATE_START
   Stones[0] := @PLAYER1_STONE
   Stones[1] := @PLAYER2_STONE
   Stones[2] := @VALID_MOVE_STONE
   
  
   ' BEGIN GAME LOOP ////////////////////////////////////////////////////
   repeat
    
      case GameState
         GAME_STATE_START:
            InitGame
            GameState := GAME_STATE_ATTRACT

         GAME_STATE_ATTRACT:
            LastState := GameState
            if ClickB[LEFT_CLICK]~ or ClickB[RIGHT_CLICK]~
               InitGame
               LastState := GameState := GAME_STATE_RUN
            else
               ComputerMove
            
         GAME_STATE_RUN:
            LastState:=GameState
            if Player == PLAYER_1
               HumanMove
            Else
               ComputerMove
            
         ' Blink the hint for player 1, if one is available
         GAME_STATE_HINT:
            GameState := GAME_STATE_RUN
            If FindMove(true)
            GameState := GAME_STATE_FLASH_MOVE
            lRetState := GAME_STATE_RUN

         ' Flash the computers move
         GAME_STATE_COMPUTER_MOVE:
            GameState  := GAME_STATE_FLASH_MOVE
            lRetState  := GAME_STATE_COMPUTER_MOVE_CONT

         ' A player was forced to pass up his turn because no move was available.
         GAME_STATE_PASS:
            lPtr      := @LBL_STATUS_LIT
            lIndex    := MESSAGE_PASS_1
            if Player^1 == PLAYER_2
               lIndex := MESSAGE_PASS_2
            lIndex    := CheckMessage(lIndex)
            GameState := GAME_STATE_FLASH_TEXT
            lRetState := LastState

         ' Blink Who Won
         GAME_STATE_GAMEOVER:
            lPtr      := @LBL_STATUS_LIT
            lIndex    := MESSAGE_WIN
            if Score[PLAYER_1] < Score[PLAYER_2]
               lIndex := MESSAGE_LOSE
            elseif Score[PLAYER_1]==Score[PLAYER_2]
               lIndex := MESSAGE_TIE
            lIndex    := CheckMessage(lIndex)
            GameState := GAME_STATE_GAMEOVER_FLASH
            lRetState := LastState
            InitGame
            

         GAME_STATE_COMPUTER_MOVE_CONT:
            ComputerMoveEnd
            GameState := LastState

         GAME_STATE_FLASH_TEXT,GAME_STATE_GAMEOVER_FLASH:
            FlashText(lPtr, lIndex, lRetState)
            
         GAME_STATE_FLASH_MOVE:
            FlashStone(lRetState)
                     
               
      ' GAME LOOP TASKS /////////////////////////////////////////////

      ' Record any user input
      CheckUserInput
      
      ' Completely redraw the offscreen buffer only when needed
      If Redraw~
         RedrawGameBoard
      
      ' Copy the offscreen bitmap to the active display, offscreen -> onscreen
      gr.copy(onscreen_buffer)

      ' Update the General counter, Like a frame counter but not as accurate.
      GenCount++
      Rand += Gencount

      
   ' END GAME LOOP //////////////////////


PRI CheckUserInput
   ' Read the mouse, redraw cursor if needed
   MouseX := mouseX + mouse.delta_x #> 0 <# 256
   MouseY := MouseY + mouse.delta_y #> 0 <# 187
   if mouse.button(LEFT_CLICK)
      ClickB[LEFT_CLICK] := true
   if mouse.button(RIGHT_CLICK)
      ClickB[RIGHT_CLICK] := true
   
   if (LastMouseX<>MouseX or LastMouseY<>MouseY) 'and GameState=<1
      gr.pix(LastMouseX, LastMouseY, 0, @CURSOR ,XOR_MODE)       ' Un-draw corsor at last location
      gr.pix(MouseX, MouseY, 0, @CURSOR, XOR_MODE)               ' Draw cursor at new location
      LastMouseX := MouseX
      LastMouseY := MouseY
      
      ' Copy the offscreen bitmap to the active display, offscreen -> onscreen
      gr.copy(onscreen_buffer)
      



' If the state is in attract mode then the message is always, click to start
PRI CheckMessage(pIndex)
   if (GameState == GAME_STATE_ATTRACT) or (LastState == GAME_STATE_ATTRACT)
      pIndex := MESSAGE_START
   return pIndex
  

PRI InitGame

   ' Reset the grid to have all free elements and make the starting move.
   bytefill(@Grid,PLAYER_FREE,GRID_COUNT)   
   Player          := PLAYER_1
   Redraw          := true
   Score[PLAYER_1] := Score[PLAYER_2] := FlashCtr:= 0
   BeginMove

   
PRI RedrawGameBoard | lTemp1,lTemp2, lTemp3

   ' Clear the off screen buffer and set the default color and width for drawing
   gr.clear
   gr.ColorWidth(2,0)
   gr.pix(MouseX, MouseY, 0, @CURSOR,XOR_MODE)

   ' Draw insructions
   DrawText(@LBL_INSTR1_LIT,0,-1)
   DrawText(@LBL_INSTR2_LIT,0,-1)
   
   ' Draw Status message
   lTemp1 := MESSAGE_START
   if GameState == GAME_STATE_RUN or LastState == GAME_STATE_RUN
      lTemp1 := MESSAGE_1_UP
      if Player==PLAYER_2
         lTemp1 := MESSAGE_2_UP
   If GameState <> GAME_STATE_GAMEOVER_FLASH and GameState<>GAME_STATE_PASS
      DrawText(@LBL_STATUS_LIT, CheckMessage(lTemp1),USE_DEFAULT)

 ' debug:=lastState
   
   ' Draw Score literals
   DrawText(@LBL_SCORE1_LIT,0,USE_DEFAULT)
   DrawText(@LBL_SCORE2_LIT,0,USE_DEFAULT)

   ' Draw grid lines left to right
   repeat lTemp1 from 0 to GRIDLINES_WIDTH step GRIDLINES_STEP
      gr.plot(0,lTemp1)
      gr.line(Gridlines_width,lTemp1)

   ' Draw grid lines top to bottom
   repeat lTemp1 from 0 to GRIDLINES_HEIGHT step GRIDLINES_STEP
      gr.plot(lTemp1,0)
      gr.line(lTemp1,gridlines_height)

   DrawNumb(@LBL_SCORE1_VAL,Score[PLAYER_1],USE_DEFAULT)
   DrawNumb(@LBL_SCORE2_VAL,Score[PLAYER_2],USE_DEFAULT)
'  DrawNumb(@LBL_SCORE1_VAL,debug,USE_DEFAULT)
   'DrawNumb(@LBL_SCORE2_VAL,debug2,USE_DEFAULT)
   
   
   ' Draw non-empty grid elements into the buffer
   repeat lTemp1 from 0 to GRID_LOOP
      CheckUserInput
      repeat lTemp2 from 0 to GRID_LOOP
         lTemp3 := Grid[lTemp1*GRID_SIZE+lTemp2]
         if lTemp3 <> PLAYER_FREE
            DrawStone(lTemp2,lTemp1,lTemp3 )
   
   checkuserinput



' Draw the first two rounds for both player1 and 2.
' for a total of 4 stones.
PRI BeginMove  

   RandMove(0)
   RandMove(1)

   ' Game always start with Player 1
   Player := PLAYER_1

        
PRI RandMove(pOffset) | lType1
   lType1 := (Rand := Rand?) & 1
   
   ' Draw row 1 then row 2
   Grid[GRID_HALF + (GRID_HALF + pOffset)*GRID_SIZE] := lType1
   Grid[GRID_HALF + (GRID_HALF + pOffset)*GRID_SIZE+1] := lType1^1



' Test all valid moves and find the move that gives the largest
' number of stones to be converted to the palyer in question.
' If we find that a valid move is in a corner then take that move
' above all others.
' Also counts the stones per player
' and enable the valid move hints (empty circles) when requested.
PRI FindMove(pShowValid) : rFound | lCount, lCountMax, lRow,lCol, lIndex, lTest

   Score[0]:=Score[1]:=0
   rFound := FALSE
   repeat lRow from GRID_LOOP to 0 step 1
      lIndex := lRow * GRID_SIZE
      repeat lCol from 0 to GRID_LOOP
         CheckUserInput
         lTest:=lCol+lIndex

         ' Count Stones per player for the score
         if Grid[lTest] =< PLAYER_2
            Score[Grid[lTest]]++          
         
         ' Clear any old valid move markers
         if Grid[lTest]==PLAYER_VALID
            Grid[lTest]:=PLAYER_FREE
            
         If (Grid[lTest] == PLAYER_FREE)         
            lCount := CountStones(lCol, lRow, Player, COUNT_STONES_ONLY)
            
            If lCount > 0
               ' Show valid moves if requested
               If pShowValid
                  Grid[lTest]:=PLAYER_VALID
                  
               ' Take the corner if it is one of the possible positions
               If (lRow == 0 And lCol == 0) Or (lRow == 0 And lCol == GRID_LOOP) Or (lRow == GRID_LOOP And lCol == 0) Or (lRow == GRID_LOOP And lCol == GRID_LOOP)
                  Col := lCol
                  Row := lRow
                  return True

               ' Save the move with the highest stone count.
               if lCount => lCountMax
                  ' if we already have a move with this count,
                  ' then randomly replace it. This keeps things from clustering in one quadrant of the screen.
                  if lCount==lCountMax
                     if (Rand?)&1
                        Row := lRow
                        Col := lCol
                  else
                     Row := lRow
                     Col := lCol
                  rFound := TRUE
                  lCountMax := lCount
   return rFound



' Count the possible stones in all eight directions from the given grid location
' If pRedraw is true then actually convert the stones to the current player.
PRI CountStones(pCol,pRow,pPlayerID,pRedraw) : rCount | lRowStep, lColStep, lRow, lCol, lTest, lTemp, lFound
   rCount:= 0
   repeat lRowStep from -1 to 1
      repeat lColStep from -1 to 1
         ' No steps would cause an enless loop, So don't do it.
         if lRowStep==0 and lColStep==0
            next
            
         ' Scan the grid in the current direction.
         ' If we hit a free space or valid hint marker without finding a stone of the correct type
         ' Then we are done. Once we find a stone of the correct type then we are done scanning.
         ' rCount will be the count of stones that would be converted
         lTemp:= lfound:= 0
         lRow := pRow + lRowStep
         lCol := pCol + lColStep
         Repeat While (lRow => 0) and (lRow =< GRID_LOOP) and (lCol =>0) and (lCol =< GRID_LOOP)
            CheckUserInput
            lTest := Grid[lCol + (lRow*GRID_SIZE)]
            If lTest => PLAYER_VALID
               lTemp := 0
               quit
            If lTest == pPlayerID
               lFound := true
               quit
            else
               lTemp++
            lRow += lRowStep
            lCol += lColStep

         ' If redraw then convert stones to the player's color.
         if pRedraw and lTemp>0 and lFound
            lRow := pRow + lRowStep
            lCol := pCol + lColStep
            lTest := lTemp
            Repeat while lTest-- > 0
               CheckUserInput
               Grid[lCol+lRow*GRID_SIZE] := pPlayerID
               lRow += lRowStep
               lCol += lColStep
               
         ' Accumulate stone count
         rCount+=lTemp        
   return rCount




' It is Player 1's turn..
PRI HumanMove | lIndex 

   ' If Right mouse buttom clicked then Show Hint
   if mouse.button(RIGHT_CLICK)
      GameState := GAME_STATE_HINT

   ' Check and see if the left button is clicked, if not then we are out of here
   if mouse.button(LEFT_CLICK)   
      ' Convert mouse position to grid positions
      Col := MouseX / GRIDLINES_STEP
      Row := MouseY / GRIDLINES_STEP

      ' Validate move
      CheckMoveOK    

   
PRI ComputerMove
   
   ' If there are no valid moves for the computer then pass up this turn
   redraw := true
   GameState := GAME_STATE_COMPUTER_MOVE
   If not FindMove(0)
      Player := Player^1
      GameState := GAME_STATE_PASS
      Redraw := True
      ' Computer is going to pass up this turn, If the other player has no valid move then GAME OVER.
      if not FindMove(true * (GameState==GAME_STATE_RUN))
         GameState := GAME_STATE_GAMEOVER


' Common Accept move routine for both Player1 and Player2
' Plays a sound, updates grid array, convert captured stones
' Swaps to the next player.
PRI CheckMoveOK | lIndex

   lIndex := Row*GRID_SIZE+Col
   
   ' Check that the target cell is marked as a valid move
   if (CountStones(Col,Row,Player,false)==0) and GameState==GAME_STATE_RUN
      return

   ' Play Accept Sound

   ' Force a redraw of the game board
   Redraw := True

   ' Update GRID array
   Grid[lIndex] := Player
   
   ' Convert captured stones
   CountStones(Col,Row,Player,REVERSE_STONES)

   ' Swap Players
   Player := Player^1    


' Called back from the main loop after the computers
' Choice is flashed to screen.
' Force player1 to pass up his turn if he has no valid moves.
PRI ComputerMoveEnd

   CheckMoveOK
   Redraw := True
   ' If the human has no moves then tell player1 they are being forced
   ' to pass up a turn and Let the computer take another turn.
   if not FindMove(true*(GameState==GAME_STATE_RUN))
      GameState := GAME_STATE_PASS
      Player := Player^1
                  

PRI DrawStone(pX,pY,pStoneID)
  
  gr.pix(pX*GRIDLINES_STEP+STONE_OFFSET, pY*GRIDLINES_STEP+STONE_OFFSET, 0, Stones[pStoneID],XOR_MODE)



' Helper function for the Game State loop to allow a flashing stone on the screen
PRI FlashStone(pExitState)
   if (GenCount & $40)
      GenCount:=0
      DrawStone(Col, Row, Player)
      FlashCtr := FlashCtr + 1
      if FlashCtr =>  9'15
         FlashCtr := 0
         Redraw := True
         GameState := pExitState

' RGW Uncomment to make computer make it's moves seem faster (during debug only)
'GameState := pExitState


' Helper function for the Game State loop to allow flashing text on the screen
PRI FlashText(pTxtPtr,lIndex, pExitState)
   if (GenCount & $40)
      GenCount :=0
      DrawText(pTxtPtr, lIndex,-(FlashCtr & 1))
      FlashCtr := FlashCtr + 1
      if FlashCtr => 30
         FlashCtr := 0
         Redraw := true
         GameState := pExitState         
              

' Pass in a pointer to a text structure, Value to print and possible override color.
' NOTE: the text structure must have 5 bytes of text space reserved.
PRI DrawNumb(pTxtPtr,pValue,pColor) | lPtr,lIndex
   lPtr := pTxtPtr+11
   repeat lIndex from 0 to 4
      BYTE[lPtr--] := (pValue // 10)+48
      pValue/=10
   DrawText(pTxtPtr,0,pColor)



' Pass in a pointer to a text structure and a possible text index and color override
' The text will be draw according to the values held in the text structure
PRI DrawText(pTxtPtr, pIndex, pColor) | lColor,lX,lY,lExX,lExY

   lExX := byte[pTxtPtr++]
   lExY := byte[pTxtPtr++]
   gr.textmode(lExX, lExY, byte[pTxtPtr++], byte[pTxtPtr++]) ' XScale, YScale, Spacing, Justification
   
   lColor := byte[pTxtPtr++]

   ' If passed in color = -1 then use color from text definition, else use color passed in
   if pColor =>0
      lColor:=pcolor

   lX := byte[pTxtPtr++]                                                           ' X
   lY := byte[pTxtPtr++]                                                           ' Y

   ' Skip forward to find the literal string that was indexed
   repeat while pIndex-->0
      repeat while byte[pTxtPtr++] <> 0

   ' Draw the text with a shadow effect
   ' Draw the text with in white, slightly larger than the requested size
   gr.colorwidth(1,lExY+1)
   gr.text(lX, lY, pTxtPtr)

   ' Draw the text again with the correct size and color, to the right and up
   gr.ColorWidth(lColor,lExY)
   gr.text(lX + 1, lY + 1, pTxtPtr)

   ' Restore the pixel width
   gr.width(0)






'///////////////////////////////////////////////////////////////////////
' DATA SECTION /////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

DAT

' TV PARAMETERS FOR DRIVER /////////////////////////////////////////////

tvparams                long    0               'status
                        long    1               'enable
                        long    %011_0000       'pins
                        long    %0000           'mode
                        long    0               'screen
                        long    0               'colors
                        long    x_tiles         'hc
                        long    y_tiles         'vc
                        long    10              'hx timing stretch
                        long    1               'vx
                        long    0               'ho
                        long    0               'vo
                        long    55_250_000      'broadcast on channel 2 VHF, each channel is 6 MHz above the previous



' SCREEN LABEL PARAMETERS ////////////////////////////////////////////

' Player 1 Score label and value metrics
LBL_SCORE1_LIT          byte  002, 002            ' X Scale, Y Scale
                        byte  007, 005            ' Inter char spacing, Justification
                        byte  002                 ' Color index
                        byte  210, 155            ' X,Y screen location
                        byte  "Score",0           ' Text String

LBL_SCORE1_VAL          byte  002,002             ' X Scale, Y Scale
                        byte  007, 005            ' Inter char spacing, Justification
                        byte  002                 ' Color index
                        byte  210,130             ' X,Y screen location
                        byte  "00000",0           ' Text String


' Player 2 Score label and value metrics
LBL_SCORE2_LIT          byte  002, 002            ' X Scale, Y Scale
                        byte  007, 005            ' Inter char spacing, Justification
                        byte  003                 ' Color index
                        byte  210, 080            ' X,Y screen location
                        byte  "Score",0           ' Text String

LBL_SCORE2_VAL          byte  002, 002            ' X Scale, Y Scale
                        byte  007, 005            ' Inter char spacing, Justification
                        byte  003                 ' Color index
                        byte  210, 055            ' X,Y screen location
                        byte  "00000",0           ' Text String

                        
LBL_INSTR1_LIT          byte  001, 001            ' X Scale, Y Scale
                        byte  007, 005            ' Inter char spacing, Justification
                        byte  002                 ' Color index
                        byte  210, 020            ' X,Y screen location
                        byte  "Left Click",0      ' Text String
                        
LBL_INSTR2_LIT          byte  001, 001            ' X Scale, Y Scale
                        byte  007, 005            ' Inter char spacing, Justification
                        byte  002                 ' Color index
                        byte  210, 005            ' X,Y screen location
                        byte  "For Hint",0        ' Text String



' Status display Area. Note the use of multiple string entries
LBL_STATUS_LIT          byte  002, 002            ' X Scale, Y Scale
                        byte  007, 000            ' Inter char spacing, Justification
                        byte  002                 ' Color index
                        byte  010, 165            ' X,Y screen location
                        byte  "Player 1 Passes",0 ' Text String 0
                        byte  "Player 2 Passes",0 ' Text String 1
                        byte  "Player 1 Wins!!",0 ' Text String 2
                        byte  "Player 2 Wins!!",0 ' Text String 3
                        byte  "Ahh, Tie Game!!",0 ' Text String 4
                        byte  "Click To Start",0  ' Text String 5
                        byte  "Player 1 UP",0     ' Text string 6
                        byte  "Player 2 UP",0     ' Text string 7





' PIXLE SPRITES  ////////////////////////////////////////
PLAYER1_STONE           word                         
                        byte  1,8,3,3                
                        word  %%00111100
                        word  %%01222210
                        word  %%12212221
                        word  %%12122221
                        word  %%12222221
                        word  %%12222221
                        word  %%01222210
                        word  %%00111100

PLAYER2_STONE           word                         
                        byte  1,8,3,3                
                        word  %%00111100
                        word  %%01333310
                        word  %%13313331
                        word  %%13133331
                        word  %%13333331
                        word  %%13333331
                        word  %%01333310
                        word  %%00111100

VALID_MOVE_STONE        word                                               
                        byte  1,8,3,3                
                        word  %%00111100
                        word  %%01000010
                        word  %%10000001
                        word  %%10000001                       
                        word  %%10000001
                        word  %%10000001
                        word  %%01000010
                        word  %%00111100

CURSOR                  word                                               
                        byte  1,8,3,3                
                        word  %%00000000'
                        word  %%00000000'
                        word  %%01111100'
                        word  %%01222210'
                        word  %%01222100'
                        word  %%01211210'
                        word  %%00100121'
                        word  %%00000011'