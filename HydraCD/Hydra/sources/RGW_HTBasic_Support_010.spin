CON
  
   #0, _WaitForReady, _SetUp, _PrintChar, _Scroll, _SetCursorMode, _CursorFlash, _PauseFlash, _ProcessLine, _PushLoop, _PopLoop, _loop
  
VAR
   long vCogon, vCog
   long vCommand
   long vBitmapBase, vBitmapLongs  
   long vCurRow, vCurCol
     
   long vpDebugger
   long vTblToken
   long vFuncBuff[3]  
   long vFuncCmd
   long vKbdBuff
   long vBuffer
   long vLastKey
   long vTxtUnf
   long vFlash                    ' Cursor Flash timer
   long vKBD_Frame
   long vRND
   long vMemEnd
   long vVarBgn

   long vStkGos
   long vStkInp
   long vLopVar
   long vLopInc
   long vLopLmt
   long vLopLin
   long vLopPtr

   long vLoopVars   
   long vParams[17]   
   byte vWork[80]
   byte vSave[80]
   byte vSaveEnd
   byte vProg[C#PRG_SIZE]
   long tc1

OBJ
   KBD  : "RGW_keyboard_iso_010.spin"
   C    : "RGW_HTBasic_Constants_010.spin"

   UART : "RGW_FullDuplex.spin"
   
PUB start(pBuffPtr, pTblToken) : rParamPtr                                        '' Start helper driver - Returns false if no COG is available
   DIRA[0] := 1
   stop
   KBD.start(3,@vKBD_Frame)
   vFlash~
   vBuffer:=pBuffPtr
   vTblToken:=pTblToken
   vMemEnd:= @vProg + (C#PRG_SIZE)
   vVarBgn:= vMemEnd - C#VAR_SIZE - C#ASM_STK_SIZE

   vParams[02] := @vProg
   vParams[03] := @vFuncBuff
   vParams[04] := @vFuncCmd                          
   vParams[05] := @vLastKey                       ' Last key pressed                          
   vParams[06] := @vTxtUnf                        ' Free memory                           
   vParams[07] := vVarBgn                         ' VarBgn
   vParams[08] := @vCommand
   vParams[09] := @vRND                           ' RND Seed

   vLoopVars:=10
   vParams[10] := @vStkGos                        ' StkGos
   vParams[11] := @vStkInp                        ' StkInp
   vParams[12] := @vLopVar                        ' LopVar
   vParams[13] := @vLopInc                        ' LopInc
   vParams[14] := @vLopLmt                        ' LopLmt
   vParams[15] := @vLopLin                        ' LopLin
   vParams[16] := @vLopPtr                        ' LopPtr
   
   vCogon := (vCog := cognew(@Commandloop_, @vCommand)) > 0
   rParamPtr:=@vParams

   uart.start(31, 30, 2400)

  
PUB stop                                                '' Stops driver - frees a cog
  if vCogon~     
    cogstop(vCog)
  vCommand~


' Check for screen output and keyboard input
' Also updates the last key variable
PUB CheckFunction 

   ' Check Misc functions
   if vFuncCmd <> 0
      case (vFuncCmd & C#FUNC_MASK)
         C#FUNC_PRINT_STRING:
            PrintString(vFuncBuff, vFuncCmd & $FF,0)
         C#FUNC_GET_LINE:
            vFuncBuff := Tokenize(GetLine(vBUFFER, vFuncCmd & $FF))            
         C#FUNC_PRINT_LINE:
            vFuncBuff := PrintLine(vFuncBuff, vFuncCmd & $FFFF,0)
         C#FUNC_GET_INPUT:
            vFuncBuff := INPUT(vFuncBuff)
         C#FUNC_GET_KEYBD:
             if vFuncBuff==0
                vFuncBuff:=CheckKBD
         C#FUNC_PRINT_QT_STR:
            TestString(@vFuncBuff)
         C#FUNC_PRINT_NUMBER:
            PrintNumber(C#USE_DEFAULT, C#USE_DEFAULT, vFuncBuff[0], vFuncCmd & $FF,0,0)
         C#FUNC_STARTUP:
            Startup
         C#FUNC_PROC_LINE:
            PROCESS_LINE
         C#FUNC_SAVE:
            SAVE
         C#FUNC_LOAD:
            LOAD
         C#FUNC_RND:
            RND_FUNC
      vFuncCmd := 0
   CheckKBD


PRI StartUp
   ' If a cold start then print logo and reset the free area
   if vFuncBuff[0]== 0
      PrintString(@TXT_LOGO, 0, 0)
      vTxtUnf:=@vProg                                   ' Point Free area to start of Prog area

   vLopVar:=0
   vStkGos:=0
   vFuncBuff[0]:=vMemEnd                                ' Reset SP
   PrintString(@TXT_OK, 0,0)                            ' Say OK

PRI RND_FUNC
   if vFuncBuff==0
      vRnd:=vKBD_Frame
   vRnd := ||?vRnd                                      ' Gerate a new seed 
   vFuncBuff[0] := vRnd // vFuncBuff                    ' Limit the return result via MOD

PRI LOAD | lTemp, lBuffPtr
   repeat
      if checkKBD== C#CTRL_C
         return
      lTemp:= RecByte
      if lTemp == "@"
         quit               
      repeat until lTemp==":"
         if checkKBD== C#CTRL_C
            return
      lBuffPtr:=vBuffer
      repeat
         if checkKBD== C#CTRL_C
            return
         lTemp:=RecByte
         byte[lBuffPtr++]:=lTemp
         if lTemp==C#CR
            vFuncBuff[0] := Tokenize(lBuffPtr)            
            PROCESS_LINE
            quit
          

PRI RecByte : rValue
   repeat until ( rValue:= uart.rxcheck) => 0
      if checkKBD== C#CTRL_C
         quit


' Send the program to to serial port
PRI SAVE | lTxtBgn, lTxtEnd, lDummy
   lTxtBgn := @vProg
   lTxtEnd := vTxtUnf

   repeat until lTxtBgn == vTxtUnf
      putc(":")
      lTxtBgn:=printline(lTxtBgn, @lDummy, 1)
   putc("@")
      
   
PRI OUT_CRLF
   putc(C#CR)
   putc(C#LF)


PUB putc(txbyte)
  uart.tx(txbyte)


PUB hex(value, digits) ', Term)
  value <<= (8 - digits) << 2
  repeat digits
    putc(lookupz((value <-= 4) & $F : "0".."9", "A".."F"))


PRI PROCESS_LINE
   SetCommand(_WaitForReady, C#NO_ARGS)                 ' Make sure last command finished
   SetCommand(_ProcessLine, C#NO_ARGS)

      
pub Show(value, lRow)  | ll, pp
  ll:=vCurRow
  pp:=vCurCol 
  PrintNumber(lRow, 0, value, 12,0,0)
  vCurRow :=ll
  vCurCol :=pp


PUB setup(pBasePtr, pRow, pCol, pDebugger, ppTxtUnf, ppBuffer, ppMemStart, ppVarBgn, ppFuncBuff, ppLoopVars)    '' Step Helper Cog
  SetCommand(_WaitForReady, C#NO_ARGS)                  ' make sure last command finished

  vpDebugger   := pDebugger
  vBitmapBase  := pBasePtr                              ' retain high-level bitmap data
  vBitmapLongs := (12 * 16) * 16
  pRow         := @vCurRow
  pCol         := @vCurCol
  ppTxtUnf     := @vTxtUnf
  ppBuffer     := vBuffer
  ppMemStart   := @vProg
  ppVarBgn     := vVarBgn
  ppfuncBuff   := @vFuncBuff
  ppLoopVars   := @vStkGos  
  SetCommand(_SetUp, @pBasePtr)
  CLS

  
PUB CLS                                                 '' Clear the screen                                    
  SetCommand(_WaitForReady, C#NO_ARGS)                  ' Make sure last command finished
  longfill(vBitmapBase, 0, vBitmapLongs)                ' Clear bitmap
  CursorLoc(0,0)


PUB Scroll
  SetCommand(_WaitForReady, C#NO_ARGS)                  ' Make sure last command finished
  SetCommand(_Scroll, C#NO_ARGS)


PUB PrintString(pStringPtr, lTermChar, pWhere)          '' Print a string up to the Terminating char, pointer is direct
  repeat until byte[pStringPtr] == lTermChar   
     PrintChar(byte[pStringPtr++], pWhere)


PUB PrintStringPtr(pStringPtr, lTermChar, pWhere)       '' Print a string up to the Terminating char, pointer is direct
  repeat until byte[long[pStringPtr]] == lTermChar   
     PrintChar(byte[long[pStringPtr]++], pWhere)


PUB PrintChar(pChar, pWhere)                            '' Print single char at x,y. -x or -y = at current loc for x or
   if pWhere == 0
      SetCommand(_WaitForReady, C#NO_ARGS)              ' Make sure last command finished
      SetCommand(_PrintChar, @pChar)
   else
      putc(pChar)

        
PUB CursorLoc(pRow, pCol)                               '' Move cursor location.
  SetCommand(_WaitForReady, C#NO_ARGS)                  ' Make sure last command finished
  SetCommand(_PauseFlash, C#NO_ARGS)
  If pRow => 0
     vCurRow := pRow
  If pCol => 0
     vCurCol := pCol


PUB SetCursorMode(pMode)                                '' 0=off, 1=on
  SetCommand(_WaitForReady, C#NO_ARGS)                  ' Make sure last command finished
  SetCommand(_SetCursorMode, @pMode)


PUB CursorFlash
  SetCommand(_WaitForReady, C#NO_ARGS)                  ' Make sure last command finished
  SetCommand(_CursorFlash, C#NO_ARGS)


PUB CheckKBD : rKey
   if KBD.Present
      if KBD.GotKey          
          vLastKey:=rKey:=TranslateKeys(KBD.Key)


PUB PrintNumber(pRow, pCol, pValue, pWidth, pTrailSpace, pWhere) | lSign, lTxtPtr
   lTxtPtr := @LBL_NUMBER_END                           ' Point to the end of the string space  
   lSign := (pValue < 0) + 2
   ||pValue

   repeat
      if lSign == 0
         BYTE[--lTxtPtr] := " "
      else
         BYTE[--lTxtPtr] := (pValue // 10)+48
         if (pValue /= 10)==0
            if lSign~ == 1
               BYTE[--lTxtPtr] := "-"
               pWidth--
      pWidth--         
   until pValue==0 and pWidth=<0 
   CursorLoc(pRow, pCol)            
   PrintString(lTxtPtr, 0, pWhere)
   if pTrailSpace
      PrintChar(C#SPACE, pWhere)


PRI SetCommand(pCmd, pArgptr)
  vCommand := pCmd << 16 + pArgptr                      ' Write command and pointer
  repeat while vCommand                                 ' Wait for command to be cleared, signifying receipt


PUB PrintLine(lPtr, pErrPtr, pWhere) : rBuffEnd

   ' Read the line number
   ParseNumber(@lPtr, 5, pWhere)
   repeat until byte[lPtr]==C#CR
      if lPtr == pErrPtr
         PrintChar("?", pWhere)   
      if !ParseToken(@lPtr, pWhere)
         PrintChar(byte[lPtr++], pWhere)
   PrintChar(C#CR, pWhere)
   PrintChar(C#LF, pWhere)
   rBuffend:=lPtr+1      


PRI ParseNumber(lPtr, lWidth, pWhere) : rValid | lTemp
   rValid~
   if byte[long[lPtr]] == $FF
      bytemove(@lTemp, long[lPtr]+1,4)
      PrintNumber(C#USE_DEFAULT, C#USE_DEFAULT, lTemp, lWidth, 1, pWhere)
      long[lPtr]+=5
      rValid:=true


PRI ParseToken(lPtr, pWhere) :rMatch | lTblPtr 
   rMatch~
   if ParseNumber(lPtr, 0, pWhere)
      rMatch:=true
   else
      lTblPtr:=vTblToken
      repeat until byte[lTblPtr]==0                     ' End when we hit the last table
         repeat                                         ' loop until the end of this table
            if byte[long[lPtr]] == byte[lTblPtr++]      ' Find the correct token
               lTblPtr++
               repeat until byte[lTblPtr] & $80
                  PrintChar(byte[lTblPtr++], pWhere)
               PrintChar(byte[lTblPtr]&$7f, pWhere)
               rMatch:=true
               long[lPtr]++            
               if byte[long[lPtr]] <> C#CR              ' if not at the end of the line, print a space between expanded tokens
                  PrintChar(C#SPACE, pWhere)
               return
            else
               if byte[lTblPtr-1]<>0
                  lTblPtr++
                  repeat until byte[lTblPtr++] & $80    ' Skip this entry text
               else               
                  lTblPtr++
                  quit


PRI INPUT(lInPtr) : rEndValue | lSavePtr, lTemp, lVar
   lVar~
   rEndValue:=lInPtr
   if TestString(@rEndValue)
      lVar:=TestVar(@rEndValue)
   else
      lSavePtr:=rEndValue                               ' Save the text pointer
      lVar:=TestVar(@rEndValue)                         ' Returns 0 if no var
      if lVar<>0
         PrintChar(lVar, 0)
         
   ' Get the user input (if a valid var was given)
   if (lVar>0) 'and (lVar<>$FE)
      lTemp:=Tokenize(GetLine(vBUFFER, ":"))
   if vLastKey==C#CTRL_C
      lVar:=$FD
   rEndValue:=rEndValue | (lVar << 16)

      
PRI TestVar(lPtr) : rValue                              ' Returns zero if not a var name
   rValue:=byte[long[lPtr]]
   rValue:=rValue*(||(rValue=>"A" and rValue=<"Z"))


PRI TestString(lPtr) : rFound | lTest
   rFound:=False
   lTest:=byte[long[lPtr]]
   if (lTest==C#DBL_QUOTE) or (lTest==C#SNG_QUOTE)
      long[lPtr]++
      PrintStringPtr(lPtr, lTest, 0)
      long[lPtr]++
      rFound:=True
      
   if lTest=="_"
      PrintChar(C#CR,0)
      rFound:=true
      long[lPtr]++

  
PRI GetLine(pBuffStart, pPrompt) : rBuffEnd | lN
' READS in the input line into 'BUFFER'. It first prompts with the char in D0
' CTL H = delete last char
' CTL X = Delete whole line.
' CR = END OF LINE
' Ignore LF but echo them back.

   SetCursorMode(1)
   PrintChar(pPrompt,0)                ' Display the prompt
   PrintChar(C#SPACE,0)                ' Trailing space  
   vFuncBuff := pBuffStart
  
   repeat
      repeat until vKbdBuff:=CheckKBD
         CheckTimer
         
      case vkbdBuff
         C#UP_ARROW:
            if vSaveEnd<>0
               repeat lN from 0 to vSaveEnd
                  byte[vFuncBuff++]:=byte[@vSave+lN]
                  PrintChar(byte[@vSave+lN],0)
               vSaveEnd:=0
         C#CTRL_C:
            SetCursorMode(0)
            byte[pBuffStart] := C#CR
            rBuffEnd:=pBuffStart
            vSaveEnd:=0
            quit
         C#BACK_SP:
            CharDelete
         C#CTRL_X:
            repeat while CharDelete
         0..12,14..31:               ' Ignore other control codes
         other:
            if vFuncBuff =< vBUFFER+79
               byte[vFuncBuff++] := vkbdBuff
               PrintChar(vkbdBuff,0)
               if vkbdBuff == C#CR
                  PrintChar(C#LF,0)
                  SetCursorMode(0)
                  rBuffEnd:=vFuncBuff
                  vSaveEnd:=vFuncBuff-pBuffStart-2
                  longmove(@vSave, pBuffStart, 20)                ' Save the input 
                  quit
            else
               CharDelete


' Parse the buffer and convert to tokens   
PRI Tokenize(pBuffEnd) : rBuffEnd | lBuffPtr, lChar, lQuote, lOutPtr, lEnd, lFirstToken 
   bytemove(@vWork, vBUFFER, 80)                        ' copy line buffer to work buffer

   ' convert from the work buffer to the line buffer
   lBuffPtr:=@vWork
   lOutPtr:=vBUFFER
   lEnd:= (pBuffEnd -lOutPtr)+lBuffPtr
   lFirstToken:=0

   lQuote~
   repeat until lBuffPtr=>lEnd' (byte[lBuffPtr] == CR) =
     byte[lOutPtr]:=lChar:= byte[lBuffPtr]
     if (lChar == C#SNG_QUOTE) or (lChar == C#DBL_QUOTE)
        lOutPtr++
        lBuffPtr++
        if lQuote
           if lQuote == lChar
              lQuote:=0     
        else  
           lQuote := lChar
     else
        if (not lQuote) and (lFirstToken<>C#TOKEN_REM)
           lChar:=ToToken(@lBuffPtr, @lOutPtr)
           if lFirstToken==0
              lFirstToken:=lChar
        else
           lOutPtr++
           lBuffPtr++

   rBuffEnd:=lOutPtr


PRI ToToken(pInPtr, pOutPtr) : rValue | lValue, lCount, lSave 

   ' Convert the next item in the buffer to a token
   ' First see if a number follows, lT2 = number of digits
   SkipWhiteSpace(pInPtr, pOutPtr)   
   lSave:=long[pInPtr]
   rValue:=0

   ' Quotes are processed outside of this routine
   if byte[long[pInPtr]]==C#DBL_QUOTE or byte[long[pInPtr]]==C#SNG_QUOTE
      return 
   
   lValue:=TokenNumber(pInPtr, @lCount)
   if lCount
      byte[long[pOutPtr]++]:=C#TOKEN_NUM                ' Store the marker
      bytemove(long[pOutPtr],@lValue,4)                 ' Store the long value
      long[pOutPtr]+=4                                  ' Adjust the pointer for a long move
   else                                                 ' If not a number, try the token tables
      long[pInptr]:=lSave                               ' Restore the pointer value
      lValue := TokenLookup(pInPtr)
      if lValue
         byte[long[pOutPtr]++]:=lValue                  ' Store the token
         rValue:=lValue
      else                                              ' Not a token, store the original value
         long[pInptr]:=lSave                            ' Restore the pointer value
         if byte[long[pOutPtr]]=>"a" and byte[long[pOutPtr]]=<"z"
            byte[long[pOutPtr]]-=32 
         long[pOutPtr]++                                ' Bump the out buffer ptr
         long[pInPtr]++                                 ' Bump the in buffer ptr


PRI TokenLookup(lInPtr) : rToken | lTblPtr, lSavePtr, lMatch, lChar, lTChar    , lc      

   ' Save the starting text pointer
   lSavePtr:=long[lInPtr]
   lTblPtr:=vTblToken

   repeat until byte[lTblPtr]==0                        ' End when we hit the last table
      repeat                                            ' loop until the end of this table
         rToken:=byte[lTblPtr++]                        ' Pick up the Token ID
         lTblPtr++
         if rToken==0
            quit
            
         long[lInPtr]:=lSavePtr
         lMatch~
         repeat 
            lChar:=byte[long[lInPtr]++]                 ' Get the text char
            if lChar => "a" and lChar =< "z"            ' Convert to upper case
               lChar-=32
        
            lTChar:=byte[lTblPtr++]                     ' Get the table char to test
            if (lChar== ".") and lMatch
               return
            if lChar==(lTChar & $7F)                    ' Is there a match?
               lMatch:=true
               if byte[lTblPtr-1] & $80                 ' All done if at the end of this entry
                  return
            else                                        ' skip to next entry
               if not(lTChar & $80)
                  repeat until byte[lTblPtr++] & $80
               lmatch~
               quit
   rToken~
   long[lInPtr]:=lSavePtr


PRI TokenNumber(pInPtr, pCount) : rValue

   ' Try to parse the text to see if a number is present
   ' If so, return the value and update pCount to the number of digits
   rValue~
   long[pCount]~
   repeat while byte[long[pInPtr]] => "0" and byte[long[pInPtr]] =< "9"
      rValue:=rValue*10+(byte[long[pInPtr]++]&$F)
      long[pCount]++


PUB ddebug(value )
  Show(value,0)         
  repeat
     if kbd.gotkey
        kbd.getkey
        return   
     CheckKBD
     

PRI SkipWhiteSpace(pInPtr, pOutPtr) 
   repeat while byte[long[pInPtr]] == C#SPACE
      long[pInPtr]++
      if pOutPtr <> 0
         byte[long[pOutPtr]]:=byte[long[pInPtr]]


' Check Timer for activity
PRI Checktimer   
   vFlash++
   if vFlash & %1000000000000
       vFlash~
       CursorFlash


PRI CharDelete : rOK
   rOK:=false
   PrintChar(C#BACK_SP, 0)
   PrintChar(C#SPACE, 0)
   if vFuncBuff > vBUFFER 
      PrintChar(C#BACK_SP, 0)
      vFuncBuff--
      rOK:=true


PRI TranslateKeys(pKeyCode) : rKey

   ' Lower Byte is key code in ASCII
   ' Upper Byte:
   ' 2 = CTRL
   ' 4 = ATL
   '
   ' $62E = CTRL+ATL+DEL
   case pKeyCode
      13,C#SPACE.."~":
         rKey:=pKeyCode
      $C8:
        rKey:=C#BACK_SP
      $278:
         rKey:=C#CTRL_X
      $62E:
         reboot
      $263:
         rKey:=C#CTRL_C
      $273:
         rKey:=C#CTRL_S
      $1C2:
         rKey:=C#UP_ARROW
      other:
         'ddebug(pKeyCode)
         'PrintNumber(4,0, pKeyCode, 8,0)  
















DAT
TXT_LOGO                byte "Hydra Tiny Basic - v1.0", C#CR, C#LF, 0
TXT_OK                  byte C#CR, C#LF, "Ready", C#CR, C#LF, 0

LBL_NUMBER              byte "               "
LBL_NUMBER_END          byte 0


'*************************************
'* Assembly language Helper driver *
'*************************************

                        org
                        
' Helper driver - main loop
Commandloop_            wrlong  cZero, Par               'zero command to signify received
:Loop                   rdlong  t1, par          wz      ' Wait for command
        if_z            jmp     #:Loop
                        
                        movd    :arg, #arg0              ' get the setup params
                        mov     t2, t1
                        mov     t3, #10 
:arg                    rdlong  arg0,t2
                        add     :arg, cd0
                        add     t2, #4
                        djnz    t3, #:arg

                               
                        'wrlong  t3, Par                 'zero command to signify received

                        ror     t1,#16+2                'lookup command address
                        add     t1,#Jumps_
                        movs    :table,t1
                        rol     t1,#2
                        shl     t1,#3
:table                  mov     t2,0
                        shr     t2,t1
                        and     t2,#$FF
                        jmp     t2                      'jump to command


' Jump Table for commands
Jumps_                  byte    0
                        byte    SetUp_
                        byte    PrintChar_
                        byte    Scroll_
                        byte    SetCursorMode_
                        byte    CursorFlash_
                        byte    PauseFlash_
                        byte    Process_Line_
                        byte    PushLoop_
                        byte    PopLoop_
                        byte    Commandloop_



Setup_                  mov _BasePtr,  Arg0
                        mov _CurRow,   Arg1
                        mov _CurCol,   Arg2
                        mov _Debugger, Arg3
                        mov _TxtUnf,   Arg4
                        mov _Buffer,   Arg5
                        mov _Memstart, Arg6
                        mov _VarBgn,   Arg7
                        mov _FuncBuff, Arg8
                        mov _LoopVars, Arg9
                        mov CursorLast, #0
                        mov Cursorstatus, #0
                        jmp #CommandLoop_

Process_Line_           call #PROC_LINE
                        jmp #CommandLoop_
                        
SetCursorMode_          mov CursorMode, Arg0 wz
PauseFlash_             call #ResetCursor
                        jmp #CommandLoop_
                        
                        
ResetCursor             mov T1, CursorLast
                        cmp CursorStatus, #0 wz
              if_nz     mov CursorStatus, #0                        
              if_nz     call #Reverse
ResetCursor_Ret         ret                        

                        
CursorFlash_            cmp CursorMode, #0 wz           ' If not enabled then exit
              if_z      jmp #CommandLoop_
                        call #CalcCursorAddr            ' Calc new screen address
                        mov t1, CursorLast
                        cmp CursorStatus, #0 wz         ' Restore old cursor pos
              if_nz     cmp T1, T2 wz                   ' If in the middle of a flash
              if_nz     call #Reverse                   ' and the old pos does not match the new
              if_nz     mov CursorStatus, #0            ' reset the status toggle
                        xor CursorStatus, #1            ' Toggle Status
              
                        mov t1, T2                      ' New cursor pos
                        call #Reverse                   ' Reverse new corsor pos
                        jmp #CommandLoop_                        

Reverse                 mov CursorLast, t1
                        mov t3, #16
:Loop                   rdword t4, t1
                        xor t4, cReverseMask                        
                        wrword  t4, t1
                        add t1, #4
                        djnz t3, #:Loop                       
Reverse_Ret             ret


CalcCursorAddr          rdlong Row, _CurRow
                        rdlong Col, _CurCol
                       
                        ' lScreenIndex := onscreen_buffer +(lRow *(32*2) ) + ((lCol&$FE) * (192*4/2))
                        mov t2, Row             ' T2 = Row
                        shl t2, #6              ' T2 = T2 * 64

' RGW TODO: compress math                        
                        mov t3, Col             ' t3 = lCol
                        and t3, #$FE            ' t3 = lcol&$FE
                        shl t3, #5              ' * 32
                        mov t4, t3
                        add t3, t4              ' * 64
                        add t3, t4              ' * 96
                        mov t4, t3
                        add t3, t4
                        add t3, t4
                        add t3, t4

                        and Col, #$FE nr, wz
              if_z      mov t3, #0
                        add t2, t3              ' t2 = t2 + t3
                        add t2, _BasePtr         ' t2 = t2 + OnScreen_Buffer

                        mov t6, Col             ' t6 = lColFlag
                        and t6, #1              ' t6 = lColFlag & 1
                        shl t6, #1              ' t6 = (lcolFlag &1) * 2
                        add t2, t6              ' t6 = t6 + RowIdx+lScreenPtr
CalcCursorAddr_Ret      ret

PrintChar_              call #ResetCursor
                        call #CalcCursorAddr

                         ' lCharIndex := ((lChar&$FE)*$40)+$8000
                        mov t1, Arg0            ' Pick up Char
                        and t1, #$FE            ' T1 = Char & $FE
                        shl t1, #6              ' T1 = T1 * 64($40)
                        add t1, cFontBase       ' T1 = T1 + $8000

                        cmp Arg0, #31 wz, wc    ' Control or char
              if_ae     jmp #DrawChar           ' If not a control code then display the char
              
ASCII_Control           cmp Arg0, #C#CR wz
              if_nz     jmp #:Test_LF
                        mov Col, #0             ' Carrage Return
                        jmp #SaveLoc
                        
:Test_LF                cmp Arg0, #C#LF wz
              if_z      jmp #NextRow            ' Line Feed
              
                        cmp Arg0, #C#BACK_SP wz
              if_nz     jmp #:Test_ESC
              
                        sub Col, #1 wc            ' Back Space
              if_nc     jmp #SaveLoc
                        mov Col, #31
                        sub Row, #1 wc
              if_c      mov Row, #0
                        jmp #SaveLoc
                        
:Test_ESC              


                        jmp #CommandLoop_       ' All done, reenter the command loop.

DrawChar
' RGW TODO: Merge lCharPtr with t5                              
                        mov t5, #1
                        mov t4, #60             ' Repeat t4 from 0 to 60-1                        
                        mov t9, #0              ' RowIDX

                        mov t3, Arg0            ' Char
                        and t3, #1
                        xor t3, #1              ' lCharFlag ^ 1
                        
:RowLoop                mov t10, t1
                        add t10, t5             ' t2 =lCharPtr+temp5                        
                        rdlong t8, t10
                        shl t8, t3              ' long[lCharPtr+Temp5] << (lCharFlag ^1)
                        mov t6, #16             ' repeat t6 from 0 to 15
                        
:CharLoop               mov t10, t8
                        and t10, cFontMask      ' (t8 & %10000000000000000000000000000000)                        
                        or  t7, t10             ' t7 = t7 | (t8 & %10000000000000000000000000000000)
                        shr t7, #1
                        shl t8, #2
                        djnz t6, #:CharLoop
                        
                        rev t7, #0              ' t7 = t7 ><32
                        mov t6, t2              '
                        add t6, t9                        
                        wrword t7, t6           ' word[lScreenPtr+RowIdx+ (lColFlag * 2)] := temp7
                        
                        add t9, #4
                        add t5, #9
                        sub t4, #4 wz,wc
              if_a      jmp #:RowLoop
                        add t6, #4
                        mov t7, #0
                        wrword t7, t6

                        ' Move cursor, scrolling screen if needed
                        add Col, #1
                        cmp Col, #32 wz,wc
              if_b      jmp #SaveLoc
                        mov Col, #0
                        
NextRow                 add Row, #1
                        cmp Row, #12 wz,wc
              if_b      jmp #SaveLoc
                        mov Row, #11
                        call #ScrollScreen
                                                
SaveLoc                 wrlong Row, _CurRow
                        wrlong Col, _CurCol
                        jmp #CommandLoop_       ' All done, reenter the command loop.
                        


Scroll_                 call #ScrollScreen
                        jmp #CommandLoop_       ' All done, reenter the command loop.








PROC_LINE               rdlong T4, _FuncBuff    ' Save the end of buffer pointer
                        mov T0, _Buffer         ' Point to the input buffer
                        call #READ_NUM          ' Look for a number

          if_nz         jmp #DIRECT             ' If line number not found then execute a direct statment
          if_z_and_c    jmp #QNUTZ              ' Yell if it is a number but too big for a line number
          
                        call #FIND_LINE         ' Find the line in the save area                        
                        mov T5, T0              ' Save possible line pointer
              if_nz     jmp #INSERT_LINE        ' Skip to insert if the line was not found
              
DELETE_LINE             call #FIND_NEXT         ' Find Next line
                        mov T1, T0
                        call #FIND_NEXT         ' Find Next line
                        mov T2, T5              ' Pointer to line to be deleted
                        rdlong T3, _TxtUnf
                        call #MMOVE_UP          ' Move up the code to delete
                        wrlong T2, _TxtUnf

INSERT_LINE             mov D0, T4              ' Calc the length of the new Line
                        sub D0, _Buffer
                        cmp D0, #6 wz           ' Is it just a line number and CR?                         
              if_z      jmp #EMPTY_LINE         ' If so, it was just deleted so go back for another
                        rdlong T3, _TxtUnf
                        add T3, D0
                        mov D0, _VarBgn
                        cmp D0, T3 wz, wc                        
              if_be     jmp #QOOM
                        rdlong T1, _TxtUnf
                        wrlong T3, _TxtUnf

                        mov T2, T5              ' Points to begin of move area
                        call #MMOVE_DOWN        ' Move things out of the way

                        mov T1, _Buffer
                        mov T2, T5                        
                        mov T3, T4
                        call #MMOVE_UP
                                                
EMPTY_LINE              mov t4, #0              ' Flag empty line or line update complete
                        jmp #PROC_LINE_EXIT
                        

QNUTZ                   mov T4, #1              ' Flag that the user was nuts to think that would work.
                        jmp #PROC_LINE_EXIT
                        
QOOM                    mov T4, #2              ' Flag that the system is out of memory
                        jmp #PROC_LINE_EXIT                        
                                                
Direct                  mov T4, #3              ' Flag out of memory
PROC_LINE_EXIT          wrlong T4, _FuncBuff                                                 
PROC_LINE_RET           ret




                        
FIND_LINE               cmp D1, cBits16 wc      ' Must be less than 65535
              if_nc     jmp #QNUTZ
                        mov T0, _MemStart
                        
FIND_LINE_HERE          rdlong T2, _TxtUnf
                        sub T2, #1
                        cmp T2, T0 wc,wz        ' if pass the end, return
              if_c      jmp #FIND_LINE_RET      ' with z=0 and c=1

                        mov D5, D1              ' Save D1 as read line num uses that
                        call #READ_NUM          ' fetch the line number
                        mov D2, D1
                        sub T0, #5              ' reset the text pointer
                        mov D1, D5              ' Restore D1
                        cmp D2, D1 wc,wz        ' Test the line # found against the target line #
                        
              if_nc     jmp #FIND_LINE_RET                                                        
FIND_NEXT               add T0, #5
FIND_SKIP               rdbyte temp, T0
                        add T0, #1                        
                        cmp temp, #C#CR wz
              if_nz     jmp #FIND_SKIP
                        jmp #FIND_LINE_HERE
FIND_NEXT_RET                        
FIND_LINE_RET           ret


' ARG order for loop calls
'  vStkGos  ARG0
'  vStkInp  ARG1
'  vLopVar  ARG2
'  vLopInc  ARG3
'  vLopLmt  ARG4
'  vLopLin  ARG5
'  vLopPtr  ARG6
'  vVarBgn  ARG7
PopLoop_
                        rdlong T0, _FuncBuff    ' Fetch SP
                        rdlong Temp, T0 wz      ' pop var address
                        add T0, #4
                        mov ARG2, _LoopVars
                        add ARG2, #2*4 
                        wrlong Temp, ARG2       ' Restore LopVar address
                        add ARG2, #4
                        
              if_nz     rdlong Temp, T0         ' If loop var address is zero then nothing was stacked
              if_nz     add T0, #4
              if_nz     wrLong Temp, ARG2       ' POP LopInc
              if_nz     add ARG2, #4              
              
              if_nz     rdlong Temp, T0
              if_nz     add T0, #4
              if_nz     wrlong Temp, ARG2       ' POP LopLmt
              if_nz     add ARG2, #4

              if_nz     rdlong Temp, T0
              if_nz     add T0, #4
              if_nz     wrlong temp, ARG2       ' POP LopLin
              if_nz     add ARG2, #4
              
              if_nz     rdlong Temp, T0
              if_nz     add T0, #4              
              if_nz     wrlong Temp, ARG2       ' POP LopPtr
              if_nz     add ARG2, #4
                        wrlong T0, _FuncBuff    ' Return new SP
                        jmp #CommandLoop_       ' All done, reenter the command loop.



PushLoop_               rdlong T0, _FuncBuff    ' Fetch SP
                        mov ARG2, _LoopVars 
                        add ARG2, #2*4                        
                        rdlong D0, ARG2 wz      ' Fetch Loop Var address
                        add ARG2, #4*4                        
                            
              if_nz     rdlong Temp, ARG2
              if_nz     sub ARG2, #4
              if_nz     sub T0, #4
              if_nz     wrlong Temp, T0         ' Push LopPtr              
                            
              if_nz     rdlong Temp, ARG2
              if_nz     sub ARG2, #4
              if_nz     sub T0, #4
              if_nz     wrlong Temp, T0         ' Push LopLin              
              
              if_nz     rdlong Temp, ARG2
              if_nz     sub ARG2, #4
              if_nz     sub T0, #4
              if_nz     wrlong Temp, T0         ' Push LopLmt              
              
              if_nz     rdlong Temp, ARG2
              if_nz     sub ARG2, #4
              if_nz     sub T0, #4
              if_nz     wrlong Temp, T0         ' Push LopInc
              
                        sub T0, #4
                        wrlong D0, T0           ' Push loop var address
                        wrlong T0, _FuncBuff    ' Return the SP
                        jmp #CommandLoop_       ' All done, reenter the command loop.              
              













ScrollScreen            mov t1, #16             ' 16 long columns to scroll                        
                        mov t8, _BasePtr
                        mov t9, _BasePtr
                        add t9, #4
                        
:Loop1                  mov t3, #16               
:ColLoop                mov t2, #192
                        cmp t1, #1 wz
              if_z      sub t2, #1
                        mov t4, t8
                        mov t5, t9
                        
:ScrollLoop             rdlong t6, t5
                        add t5, #4
                        wrlong t6, t4
                        add t4, #4
                        djnz t2, #:ScrollLoop
                        mov t6, #0
                        wrlong t6, t4           ' Clear last row
                        djnz t3, #:ColLoop      ' Scroll 16 lines
                        
                        mov t8, t4
                        mov t9, t5
                        djnz t1, #:Loop1                         
ScrollScreen_Ret        ret                        





' Read a long from memory that is not aligned on a long boundry
' T1 = Memory address
' D1 = return value
READ_NUM                rdbyte temp, T0
                        cmp temp, #$FF wz
              if_z      add T0, #1          
                        mov D1, #0
              if_z      mov D3, #4
              if_z      mov D4, #0                        
:LOOP         if_z      rdbyte Temp, T0
              if_z      add  T0, #1                        
              if_z      shl Temp, D4
              if_z      or D1, Temp
              if_z      add D4, #8
              if_z      djnz D3, #:LOOP
                        cmp cBits16, D1 nr,wc    ' Set carry if overlfow 16 bits
READ_NUM_RET            ret




MMOVE_DOWN              cmp T2, T1 wz
              if_z      jmp #MMOVE_DOWN_RET
                        sub T1, #1
                        sub T3, #1
                        rdbyte Temp, T1
                        wrbyte Temp, T3
                        jmp #MMOVE_DOWN

MMOVE_UP                cmp T3, T1 wz
              if_z      jmp #MMOVE_UP_RET
                        rdbyte Temp, T1
                        wrbyte Temp, T2
                        add T1, #1
                        add T2, #1
                        jmp #MMOVE_UP
MMOVE_UP_RET
MMOVE_DOWN_RET           ret





Debug                   wrlong t1, _Debugger
:Loop                   jmp #:Loop





'
' Vars
'
Row                     long 0
Col                     long 0
CursorLast              long 0
CursorMode              long 0
CursorStatus            long 0

_BasePtr                long 0
_Debugger               long 0
_CurRow                 long 0
_CurCol                 long 0
_TxtUnf                 long 0
_Buffer                 long 0
_MemStart               long 0
_VarBgn                 long 0
_FuncBuff               long 0
_LoopVars               long 0


'
' Constant data
'
cd0                     long $200
cFontBase               long $8000           ' ROM based font base address
cFontMask               long %10000000000000000000000000000000
cReverseMask            long -1
cZero                   long 0
cBits16                 long $FFFF


t0                      long 0
t1                      long 0
t2                      long 0
t3                      long 0
t4                      long 0
t5                      long 0
t6                      long 0
t7                      long 0
t8                      long 0
t9                      long 0
t10                     long 0

Temp                    long 0
D0                      long 0
D1                      long 0
D2                      long 0
D3                      long 0
D4                      long 0
D5                      long 0

arg0                    long 0       ' Arguments passed from high-level
arg1                    long 0
arg2                    long 0
arg3                    long 0
arg4                    long 0
arg5                    long 0
arg6                    long 0
arg7                    long 0
arg8                    long 0
arg9                    long 0



          