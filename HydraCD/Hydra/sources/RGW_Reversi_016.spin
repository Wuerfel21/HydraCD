' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x            ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000         ' set frequency to 10 MHZ plus some error
  _stack = ($3000 + $3000 + 64) >> 2 ' accomodate display memory and stack

  ' graphics driver and screen constants
  PARAMCOUNT        = 14        
  OFFSCREEN_BUFFER  = $2000           ' offscreen buffer
  ONSCREEN_BUFFER   = $5000           ' onscreen buffer
  

  ' Size of graphics tile map
  X_TILES           = 16
  Y_TILES           = 12

  STONE_HALF        = 8/2

  SCREEN_ORG_X      = 0
  SCREEN_ORG_Y      = 0
  SCREEN_WIDTH      = 256
  SCREEN_HEIGHT     = 192
  
  ' Colors
  ' 0  ' Green (background)
  ' 1  ' White
  ' 2  ' Blue
  ' 3  ' Red
  '                    Color 3     Color 2     color 1     color 0
  PALETTE_GAME      = %1100_1_011__0001_1_011__0000_0_111__0110_0_100
  
  ' GAME_STATES
  GAME_STATE_RUN                = 0
  GAME_STATE_START              = 1
  GAME_STATE_END                = 2
  GAME_STATE_GAMEOVER           = 3
  GAME_STATE_HINT               = 4
  GAME_STATE_FLASH_MOVE         = 5
  GAME_STATE_COMPUTER_MOVE      = 6
  GAME_STATE_PASS               = 7
  GAME_STATE_FLASH_TEXT         = 8
  GAME_STATE_COMPUTER_MOVE_CONT = 9
  GAME_STATE_ATTRACT            = 10
  
  GRID_SIZE  = 15
  'GRID_COUNT = GRID_SIZE * GRID_SIZE
  GRID_HALF  = GRID_SIZE / 2
  GRID_LOOP  = GRID_SIZE - 1

  GRIDLINES_WIDTH = 165
  GRIDLINES_HEIGHT = 165
  GRIDLINES_STEP = 11

  'Current Players
  PLAYER_1     = 0
  PLAYER_2     = 1 ' Computer
  PLAYER_VALID = 2
  PLAYER_FREE  = 3

  USE_DEFAULT       = -1
  REVERSE_STONES    = TRUE
  COUNT_STONES_ONLY = FALSE

  VALID_CLEAR       = 1
  VALID_REBUILD     = 2
  VALID_RESET       = 3

  ' Mouse constants
  LEFT_CLICK    = 0
  RIGHT_CLICK   = 1
  MOUSE_START_X = SCREEN_HEIGHT/2
  MOUSE_START_Y = SCREEN_WIDTH/2

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
  byte  Grid[GRID_SIZE * GRID_SIZE]
  long  MouseX, MouseY, LastMouseX, LastMouseY, GenCount, Rand
  Byte  GameState, Col, Row, Player, FlashCtr, DrawValidMoves, Redraw, LastState
  word  ScorePlayer1, ScorePlayer2

 ' word debug,debug2
  

'byte testing[10]

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ
   tv    : "tv_drv_010.spin"         ' instantiate a tv object
   gr    : "RGW_graphics_drv_010.spin" ' instantiate a graphics object
   mouse : "RGW_mouse_driver_010.spin"

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
            if GetInput(LEFT_CLICK) or GetInput(RIGHT_CLICK)
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
            If FindMove
               GameState := GAME_STATE_FLASH_MOVE
               lRetState := GAME_STATE_RUN

         ' Flash the computers move
         GAME_STATE_COMPUTER_MOVE:
            GameState  := GAME_STATE_FLASH_MOVE
            lRetState  := GAME_STATE_COMPUTER_MOVE_CONT

         ' A player was forced to pass up his turn because no move was available.
         GAME_STATE_PASS:
            LastState := GameState
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
            if ScorePlayer1 < ScorePlayer2
               lIndex := MESSAGE_LOSE
            else
               lIndex := MESSAGE_TIE
            lIndex    := CheckMessage(lIndex)
            GameState := GAME_STATE_FLASH_TEXT
            lRetState := GAME_STATE_START

         GAME_STATE_COMPUTER_MOVE_CONT:
            ComputerMoveEnd
            GameState := LastState

         GAME_STATE_FLASH_TEXT:
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
      Rand += GenCount

      
   ' END GAME LOOP //////////////////////

' Returns the state of a click (left or right) since the last poll
' for now, used to check the left or right button state of the mouse
PRI GetInput(pWhich)
   Return ClickB[pWhich]~


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
      
      ' Copy the offscreen bitmap to the active display, offscreen -> onscreen
      gr.copy(onscreen_buffer)
   
      LastMouseX := MouseX
      LastMouseY := MouseY            



' If the state is in attract mode then the message is always, click to start
PRI CheckMessage(pIndex)
   if (GameState == GAME_STATE_ATTRACT) or (LastState == GAME_STATE_ATTRACT)
      pIndex := MESSAGE_START
   return pIndex
  

PRI InitGame
   LastState    := GAME_STATE_ATTRACT
   Player       := PLAYER_1
   Redraw       := true
   ScorePlayer1 := ScorePlayer2 := 0
   FlashCtr     := 0

   ' Reset the grid to have all Free elements.
   ValidMoveHints(VALID_CLEAR)
   BeginMove
   DrawValidMoves := true
   RedrawGameBoard
   gr.pix(LastMouseX, LastMouseY, 0, @CURSOR,XOR_MODE)

   
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
   DrawText(@LBL_STATUS_LIT, CheckMessage(lTemp1),USE_DEFAULT)
      
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

   ' After player2's turn, draw the new valid move hints for player 1
   If DrawValidMoves~
      ValidMoveHints(VALID_REBUILD)

   ' Now that the girs has been scanned, draw the scores
   DrawNumb(@LBL_SCORE1_VAL,ScorePlayer1,USE_DEFAULT)
   DrawNumb(@LBL_SCORE2_VAL,ScorePlayer2,USE_DEFAULT)
   'DrawNumb(@LBL_SCORE2_VAL,debug2,USE_DEFAULT)
   'DrawNumb(@LBL_SCORE1_VAL,debug,USE_DEFAULT)
   
   ' Draw non-empty grid elements into the buffer
   repeat lTemp1 from 0 to GRID_LOOP
      CheckUserInput
      repeat lTemp2 from 0 to GRID_LOOP
         'checkuserinput
         lTemp3 := Grid[lTemp1*GRID_SIZE+lTemp2]
         if lTemp3 <> PLAYER_FREE
            DrawStone(lTemp2,lTemp1,lTemp3 )
   
   checkuserinput



' Draw the first two rounds for both player1 and 2.
' for a total of 4 stones.
PRI BeginMove  

   RandMove(0)
   RandMove(1)

   ' Force Player 1 as next player
   Player := PLAYER_1
   Redraw := true
   DrawValidMoves := true

        
PRI RandMove(pOffset) | lType1
   lType1 := (Rand := Rand?) & 1
   
   ' Draw row 1 then row 2
   Grid[GRID_HALF + (GRID_HALF + pOffset)*GRID_SIZE] := lType1
   Grid[GRID_HALF + (GRID_HALF + pOffset)*GRID_SIZE+1] := lType1^1



' Test all valid moves and find the move that gives the largest
' number of stones to be converted to the palyer in question.
' If we find that a valid move is in a corner then take that move
' above all others.
PRI FindMove : rFound | lCount, lCountMax, lRow,lCol, lIndex, lRowStart, lRowEnd, lRowStep, lColStart, lColEnd, lColStep

   ' When searching for a move, randomly pick a search pattern.
   ' Top to bottom or bottom to top
   ' Left to right or right to left
   lRowStart := lColStart := lCount := lCountMax := 0
   lRowEnd   := lColEnd   := GRID_LOOP
   lRowStep  := lColStep  := 1
   
   if ((Rand?)&1)
       lRowStart := GRID_LOOP
       lRowEnd   := 0
       lRowStep  := -1

   if ((Rand?)&1)
       lColStart := GRID_LOOP
       lColEnd   := 0
       lColStep  := -1
    
   
   rFound := FALSE
   ' RGW TODO: Report bug with STEP
   'repeat lRow from lRowStart To lRowEnd step lRowStep
   lRow:=lRowStart
   repeat while lRow<>lRowEnd
      lIndex := lRow * GRID_SIZE
      'repeat lCol from lColStart To lColEnd step lColStep
      lCol:=lColStart
      repeat while lCol<>lColend
         checkuserinput
         If (Grid[lCol + lIndex] == PLAYER_FREE) Or (Grid[lCol+lIndex] == PLAYER_VALID)                          
            lCount := CountStones(lCol, lRow, Player, COUNT_STONES_ONLY)
            If lCount > 0
               ' Take the corner if it is one of the possible positions
               If (lRow == 0 And lCol == 0) Or (lRow == 0 And lCol == GRID_LOOP) Or (lRow == GRID_LOOP And lCol == 0) Or (lRow == GRID_LOOP And lCol == GRID_LOOP)
                  Col := lCol
                  Row := lRow
                  return True

               ' Save the move with the highest stone count.
               If lCount => lCountMax
                  rFound := TRUE
                  Row := lRow
                  Col := lCol
                  lCountMax := lCount
         lCol:=lCol +lcolStep
      lRow := lRow + lrowStep
   return rFound



' Count the possible stones in all eight directions from the given grid location
' If pRedraw is true then actually convert the stones to the current player.
PRI CountStones(pCol,pRow,pGridID,pRedraw) : rCount | lRowStep,lColStep
   ' Count the stones in all eight directions from the current stone
   rCount:= 0
   repeat lRowStep from -1 to 1
      repeat lColStep from -1 to 1
         rCount += CountGridSection(pCol,pRow,lColStep,lRowStep,pGridID,pRedraw)
   return rCount



' Counts the stones in the given direction
PRI CountGridSection(pCol, pRow, pColStep, pRowStep, pGridID, pRedraw) : rCount | lRow, lCol, lIndex, lFound

   rCount := 0
   lFound := FALSE
   lRow   := pRow + pRowStep
   lCol   := pCol + pColStep
   if pRowStep==0 and pColStep==0
      return rcount

   ' Scan the grid in the current direction.
   ' If we hit a free space or valid hint marker without finding a stone of the correct type
   ' Then we are done.
   ' Once we find a stone of the correct type then we are done scanning.
   ' rCount will be the count of stones that would be converted
   Repeat While (lRow => 0) and (lRow =< GRID_LOOP) and (lCol =>0) And (lCol =< GRID_LOOP)
      CheckUserInput
      lIndex := lCol + (lRow*GRID_SIZE)
      If Grid[lIndex] == pGridID^1
         rCount := rCount + 1
      ElseIf Grid[lIndex] == pGridID
         lFound := TRUE
         quit
      elseIf (Grid[lIndex] == PLAYER_FREE) Or (Grid[lIndex] == PLAYER_VALID)
         lFound := FALSE
         quit
      lRow += pRowStep
      lCol += pColStep

   ' If the required stones where found then clear any count that was
   ' built up during the scanning process.
   If lFound == FALSE
      rCount := 0

   ' If redraw then convert stones to the current player.
   elseif pRedraw      
      lRow := pRow + pRowStep
      lCol := pCol + pColStep
      lIndex := rCount
      Repeat while lIndex-- > 0
        CheckUserInput
        Grid[lCol+lRow*GRID_SIZE] := pGridID
         lRow += pRowStep
         lCol += pColStep
   return rCount



' It is Player 1's turn..
PRI HumanMove | lIndex 

   ' If Right mouse buttom clicked then Show Hint
   if mouse.button(RIGHT_CLICK)
      GameState := GAME_STATE_HINT
      'GameState := GAME_STATE_GAMEOVER

   ' Check and see if the left button is clicked, if not then we are out of here
   if mouse.button(LEFT_CLICK)   
      ' Convert mouse position to grid positions
      Col := MouseX / GRIDLINES_STEP
      Row := MouseY / GRIDLINES_STEP

      ' If this was a legal move, then the computer gets no valid move hints
      ' so remove the ones showing for player 1
      If MoveOK      
         ValidMoveHints(VALID_RESET)

   
PRI ComputerMove
   
   ' If there are no valid moves for the computer then pass up this turn
   redraw := true
   GameState := GAME_STATE_COMPUTER_MOVE
   If not FindMove
      Player := Player^1
      ' Computer is going to pass up this turn, If the other player has no valid move then GAME OVER.
      GameState := GAME_STATE_PASS
      if not FindMove
         GameState := GAME_STATE_GAMEOVER


' Common Accept move routine for both Player1 and Player2
' Plays a sound, updates grid array, convert captured stones
' Swaps to the next player.
PRI MoveOK | lIndex

   lIndex := Row*GRID_SIZE+Col
   
   ' Check that the target cell is marked as a valid move
   if (Grid[lIndex] <> PLAYER_VALID) and (Player == PLAYER_1)
      MoveReject
      return false

   ' Play Accept Sound

   ' Force a redraw of the game board
   Redraw := True

   ' Update GRID array
   Grid[lIndex] := Player
   
   ' Convert captured stones
   CountStones(Col,Row,Player,REVERSE_STONES)

   ' Swap Players
   Player := Player^1
   
   ' If this is player 1 then update valid move hints
   If Player == PLAYER_1      
      DrawValidMoves := true

   return true
' Called back from the main loop after the computers
' Choice is flashed to screen.
' Force player1 to pass up his turn if he has no valid moves.
PRI ComputerMoveEnd

   MoveOK
   Redraw := True
   ' If the human has no moves then tell player1 they are being forced
   ' to pass up a turn and Let the computer take another turn.
   DrawValidMoves:=true
   if not FindMove
      GameState := GAME_STATE_PASS
      Player := Player^1
                  

                  

' General purpose routine that does a few important things, depening on the passed in parameter.
' 1) Clears all elements of the GRID array to indicate all are free for use.
' 2) Tags GRID array elements that are to be considered valid moves.
' 3) Resets GRID array elements tha are taged as VALID moves to FREE elements.
' 4) Scores the players.
PRI ValidMoveHints(pMode) | lIndex, lRidx

   ' Clears or Builds the Valid moves from the Grid Array
   ScorePlayer1:=ScorePlayer2:=0
   repeat Row from 0 To GRID_LOOP
      lRidx := Row*GRID_SIZE
      repeat Col from 0 To GRID_LOOP
         checkuserinput
         CheckUserInput
         lIndex := Col+lRidx

         ' Always free up Valid move markers or all elements if option is set.
         if (Grid[lIndex] == PLAYER_VALID) or (pMode == VALID_CLEAR)
            Grid[lIndex] := PLAYER_FREE
             
         ' Update players score values
         if Grid[lIndex] == PLAYER_1
            ++ScorePlayer1
         if Grid[lIndex] == PLAYER_2
            ++ScorePlayer2

         ' Mark elements for valid move hints if option is set.
         if pMode == VALID_REBUILD
            If Grid[lIndex] == PLAYER_FREE
               If (CountStones(Col, Row, Player,COUNT_STONES_ONLY)) > 0
                  Grid[lIndex] := PLAYER_VALID


PRI DrawStone(pX,pY,pStoneID)
  ' RGW TODO: Report the bug with CONST()
  ' gr.pix(pX * CONST(GRIDLINES_STEP+STONE_HALF+1), pY * CONST(GRIDLINES_STEP+STONE_HALF+1), 0, Stones[pStoneID])

  gr.pix(pX * GRIDLINES_STEP+STONE_HALF+1, pY * GRIDLINES_STEP+STONE_HALF+1, 0, Stones[pStoneID],XOR_MODE)


   
PRI MoveReject
   ' Do Something here for a rejected move (sound?)
   

' Helper function for the Game State loop to allow a flashing stone on the screen
PRI FlashStone(pExitState)
   if (GenCount & $40)
      GenCount:=0
      DrawStone(Col, Row, Player)
      FlashCtr := FlashCtr + 1
      if FlashCtr => 15
         FlashCtr := 0
         Redraw := True
         GameState := pExitState

' RGW Un-comment to make computer - to computer faster (during debug only)
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
' The text will be draw according to the valus held in the text structure
PRI DrawText(pTxtPtr, lIndex, pColor) | lColor,lX,lY,lExX,lExY

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
   repeat while lIndex-->0
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
                        byte  "Right Click",0     ' Text String
                        
LBL_INSTR2_LIT          byte  001, 001            ' X Scale, Y Scale
                        byte  007, 005            ' Inter char spacing, Justification
                        byte  002                 ' Color index
                        byte  210, 005            ' X,Y screen location
                        byte  "For Hint",0        ' Text String



' Status display Area. Note use of multiple string entries
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