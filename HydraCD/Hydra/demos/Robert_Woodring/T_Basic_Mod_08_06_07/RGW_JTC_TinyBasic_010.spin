'' Support has all the graphics functions
'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

   _clkmode = xtal2 + pll8x           ' enable external clock and pll times 8
   _xinfreq = 10_000_000 + 0000        ' set frequency to 10 MHZ plus some error

    ' ASM constants
   paramcount  = 15+1


   
 
  
'///////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
VAR
  'word  Tiles[X_TILES * Y_TILES] ' storage for screen tile map
  
'  long  Palette[1]                ' color look up table
  
  long Debugger
  long Debugger2
  long pParams  
  

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ    ' instantiate all objects

         
   FUNC : "RGW_JTC_HTBasic_Support_010.spin"
   C    : "RGW_HTBasic_Constants_010.spin"

     
'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
PUB start | lIndex, lRetState, lPtr, lX, lY, l0 

   Debugger:=0
   
   ' Start the Helper cog
   pParams:=FUNC.Start(@BUFFER, @TB_TOKENS)
   FUNC.Setup( 0, 0, @Debugger,0,0,0,0,0,0)

   long[pParams][01]:=@Debugger2
   StartASM(pParams)
 
   ' BEGIN Function loop 
   repeat      
'      Func.Show(Debugger2,0)
'      func.show(Debugger,1)
      Func.CheckFunction
      
      


PRI StartASM(_Params)
   cognew(@ASM_Begin, _Params)
 
     
'///////////////////////////////////////////////////////////////////////
' DATA SECTION /////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
DAT
                        
TB_TOKENS
TB_OPS                  byte C#TOKEN_GEQ,  EXPR_OPS, ">=" + $80
                        byte C#TOKEN_NEQ,  EXPR_OPS, "<>" + $80
                        byte C#TOKEN_LEQ,  EXPR_OPS, "<=" + $80
                        byte C#TOKEN_GTN,  EXPR_OPS, ">"  + $80
                        byte C#TOKEN_EQU,  EXPR_OPS, "="  + $80
                        byte C#TOKEN_LTN,  EXPR_OPS, "<"  + $80
                        byte C#LAST_ENTRY, EXPR_END

TB_PRIORITY2            byte C#TOKEN_ADD,  EXPR2_ADD, "+" + $80
                        byte C#TOKEN_SUB,  EXPR2_SUB, "-" + $80
                        byte C#LAST_ENTRY, LEVEL_END
                        
TB_PRIORITY3            byte C#TOKEN_MUL,  EXPR3_MUL, "*" +$80
                        byte C#TOKEN_DIV,  EXPR3_DIV, "/" +$80
                        byte C#LAST_ENTRY, LEVEL_END


TB_COMMANDS             byte C#TOKEN_LIST, LIST,     "LIST"   + $80
                        byte C#TOKEN_LODE, LOAD,     "LOAD"   + $80
                        byte C#TOKEN_NEW,  NEW,      "NEW"    + $80
                        byte C#TOKEN_RUN,  RUN,      "RUN"    + $80
                        byte C#TOKEN_SAVE, SAVE,     "SAVE"   + $80
                                                
TB_STATEMENTS           byte C#TOKEN_NEXT, NNEXT,    "NEXT"   + $80
                        byte C#TOKEN_LET,  LET,      "LET"    + $80
                        byte C#TOKEN_IF,   IIF,      "IF"     + $80
                        byte C#TOKEN_GOTO, GOTO,     "GOTO"   + $80
                        byte C#TOKEN_GOSB, GOSUB,    "GOSUB"  + $80
                        byte C#TOKEN_RET,  RRETURN,  "RETURN" + $80
                        byte C#TOKEN_REM,  REM,      "REM"    + $80
                        byte C#TOKEN_FOR,  FFOR,     "FOR"    + $80
                        byte C#TOKEN_INPT, IINPUT,   "INPUT"  + $80
                        byte C#TOKEN_PRNT, PRINT,    "PRINT"  + $80
                        byte C#TOKEN_PRNT, PRINT,    "?"      + $80
                        byte C#TOKEN_POKE, POKE,     "POKE"   + $80
                        byte C#TOKEN_STOP, RESTART,  "STOP"   + $80
                        byte C#TOKEN_RAND, RAND,     "RAND"   + $80
                        byte C#LAST_ENTRY, DEFAULT

TB_FOR_TO               byte C#TOKEN_TO,   EXPR_END, "TO"     + $80
                        byte C#LAST_ENTRY, EXPR_END

TB_FOR_STEP             byte C#TOKEN_STEP, EXPR_END, "STEP" + $80
                        byte C#LAST_ENTRY, EXPR_END
                        
TB_FUNCTIONS            byte C#TOKEN_PEEK, F_PEEK,   "PEEK" + $80
                        byte C#TOKEN_RND,  F_RND,    "RND"  + $80
                        byte C#TOKEN_ABS,  F_ABS,    "ABS"  + $80
                        byte C#TOKEN_SIZE, F_SIZE,   "SIZE" + $80
                        byte C#LAST_ENTRY, EXPR4_VAR
TB_END                  byte C#LAST_ENTRY

BUFFER                  long "12345678901234567890",0

TXT_NUTZ                byte "Not Possible!", C#CR, C#LF, 0
TXT_SYNX                byte "Syntax Error!", C#CR, C#LF, 0
TXT_OOM                 byte "No room For That!", C#CR, C#LF,0
TXT_NYI                 byte "Not Yet Implemented"
TXT_CRLF                byte C#CR, C#LF, 0
TXT_CHAR                byte 0,0



' TV PARAMETERS FOR DRIVER /////////////////////////////////////////////
{
tvParams                long    0               'status
                        long    1               'enable
                        long    %011_0000       'pins
                        long    %0000           'mode
tvScreen                long    0               'screen
tvColors                long    0               'colors
                        long    x_tiles         'hc
                        long    y_tiles         'vc
                        long    10              'hx timing stretch
                        long    1               'vx
                        long    0               'ho
                        long    0               'vo
                        long    55_250_000      'broadcast on channel 2 VHF, each channel is 6 MHz above the previous
                        long    0
}

org C#SWAP_AREA_START
SWAP_PRINT              mov NumFormat, #11      ' Default number spacing
                        call #PARSE_SYM
                        long (PRINT_END<<8) + ":"' If the list is null then we are done
                        call #OUT_CRLF
                        jmp #RUN_SAME_LINE
                        
PRINT_END               call #PARSE_SYM         ' End of print line?
                        long (PRINT_LOOP<<8) + C#CR
                        call #OUT_CRLF
                        jmp #RUN_NEXT_LINE


PRINT_CHAR              call #PARSE_SYM         ' Look for chr expression
                        long (PRINT_STRING<<8) + "$"
                        call #EXPR
                        call #OUT_CHAR
                        jmp  #PRINT_NEXT_ITEM

PRINT_STRING
                        call #OUT_QUOTED_STRING
              if_z      jmp  #PRINT_NUM

PRINT_NEXT_ITEM         call #PARSE_SYM         ' Look for a list seperator
                        long (PRINT_DONE<<8) + ";"
                        call #FIN

PRINT_LOOP              call #PARSE_SYM         ' Look for format expression
                        long (PRINT_CHAR<<8) + "#"
                        call #EXPR
                        mov NumFormat, D0       ' Save the new format
                        jmp  #PRINT_NEXT_ITEM

PRINT_NUM               call #EXPR
                        call #OUT_NUMBER
                        jmp  #PRINT_NEXT_ITEM                                                                                                                                                                        

PRINT_DONE              call #OUT_CRLF          ' List ends here
                        jmp  #FINISH

                         

org C#SWAP_AREA_START
SWAP_INPUT              mov Temp4, TxtPtr               ' Save the text pointer in case of error
                        neg CurLine, CurLine            ' Flag that we are in INPUT MODE.                         
                        call #GET_INPUT
                        mov temp2, TxtPtr               ' Save the merged return result
                        and TxtPtr, cBits16             ' Mask out the updated text pointer
                        shr temp2, #16 wz               ' Shift in the return flag
                        shl CurLine, #1 nr, wc          ' direct mode? c set if true
        if_z            abs Curline, Curline            ' Clear input mode flag so error does not repeat        
        if_z            jmp #ERR_SYNTAX
                        cmp Temp2, #$FD wz              ' Was it a control C?
        if_z            jmp #RESTART                    ' Restart if ctl_c

                        ' So far, so good
                        sub Temp2, #"@"                 ' Convert to offset
                        mov Temp6, Temp2
                        call #TEST_VAR                  ' Calculate the var address
                        mov Temp5, Temp6                ' Save the var address
                        mov NumFormat, TxtPtr           ' Save the text pointer
                        mov TxtPtr, #@BUFFER +$10       ' Point to the input buffer
                        call #EXPR                      ' Evaluate the user input
                        mov TxtPtr, NumFormat           ' Restore the text pointer
                        wrlong D0, Temp5                ' Save the results in the variable

                        ' Look for more input items
                        call #PARSE_SYM
                        long (FINISH <<8) + ","         ' If not a comma then the finish the line
                        jmp #IINPUT                     ' go back for more                        


org C#SWAP_AREA_START
SWAP_POKE               call #EXPR                      ' Get address
                        call #PARSE_SYM
                        long (ERR_SYNTAX << 8) + ","
                        mov Temp5, D0                   ' Save address
                        call #EXPR                      ' Get value to poke
                        wrbyte D0, Temp5                ' Write the value
                        jmp #FINISH


org C#SWAP_AREA_START
SWAP_LIST               call #READ_NUM                  ' Is there a line number?
                        call #END_CHECK                 ' If not we get a zero                        
                        call #FIND_LINE                 ' Find this or the next line. Sets c if past end                        
:LS1          if_c      jmp #RESTART                    ' Warm start if pass the end
                        call #OUT_LINE                  ' Print the line
                        call #CHKIO                     ' Check for listing halt
                        cmp D0, #C#CTRL_S wz            ' Pause the listing?
              if_nz     jmp #:LS3
:LS2                    call #CHKIO                     ' If so, wait for the keypress
              if_z      jmp #:LS2
:LS3                    call #FIND_LINE_FROM_HERE       ' Find next line from here
                        jmp #:LS1


org C#SWAP_AREA_START
SWAP_FOR                call #QPUSH_LOOP         ' Save the previous loop info
                        call #SET_VAL           ' Set the control variable's value
                        wrlong Temp4, _LopVar   ' Save the control var address                        
                        rdbyte temp, TxtPtr
                        cmp temp, #C#TOKEN_TO wz
              if_z      add TxtPtr, #1
              if_nz     jmp #ERR_SYNTAX                     

                        call #EXPR              ' Evaluate the limit
                        wrlong D0, _LopLmt      ' Save the limit value
                        mov D0, #1
                        rdbyte temp, TxtPtr
                        cmp temp, #C#TOKEN_STEP wz
              if_z      add TxtPtr, #1
              if_z      call #EXPR                        
                        wrlong D0, _LopInc      ' Save the step value
                        wrlong CurLine, _LopLin ' Save line ptr
                        wrlong TxtPtr, _LopPtr  ' Save the text pointer
                        jmp  #FINISH             ' All done
                        
                                                 
org C#SWAP_AREA_START
SWAP_GOSUB              call #QPUSH_LOOP
                        call #EXPR              ' Get line number to gosub
                        sub SP, #4
                        wrlong TxtPtr, SP       ' Save the text pointer
                        mov D1, D0
                        call #FIND_LINE         ' Find the target line
              if_nz     jmp #ERR_NUTZ 
                        sub SP, #4
                        wrlong CurLine, SP      ' Save the current line pointer
                        
                        rdlong temp, _STKGOS
                        sub SP, #4
                        wrlong temp, SP         ' Save the stack frame
                        
                        wrlong cZero, _LopVar   ' Zero out loop var
                        wrlong SP, _STKGOS
                        jmp #RUN_THIS_LINE


org C#SWAP_AREA_START
SWAP_RETURN             call #END_CHECK
                        rdlong D1, _StkGos wz   ' Fetch stack frame pointer
              if_z      jmp  #ERR_NUTZ          ' There has to be something to return to
                        mov SP, D1
                        rdlong temp, SP                        
                        add SP, #4
                        wrlong temp, _StkGos    ' Restore previous frame
                        rdlong CurLine, SP      ' Restore current line pointer
                        add SP, #4
                        rdlong TxtPtr, SP       ' Restore text pointer
                        add SP, #4
                        call #QPOP_LOOP
                        jmp #FINISH
                        

org C#SWAP_AREA_START
SWAP_RAND               rdlong RND, _KBD_Frame   ' Get new seed
                        jmp #FINISH
                 
                        
                                                




                        
' Copy parms from the stack to local memory
                        org
ASM_Begin               mov  Temp2, par
                        mov  temp, #_Debugger
                        mov  Temp3, #paramcount
                        call #BLOCK_MOVE                        
                        jmp #RESTART 


SAVE                    call #SAVE_FUNC
                        jmp #RESTART
                         

' Reset memory and load new program text
LOAD                    wrlong _MemStart, _FreeMem
                        call #LOAD_FUNC         
                        jmp #RESTART


' Table entry points - MUST BE in the first 256 LONGS.
' Table Default entry points
'NYI                     mov Temp, #@TXT_NYI +$10
'                        jmp #ERROR_REPORT


DEFAULT                 rdbyte temp, TxtPtr
                        cmp Temp, #C#CR wz                        
              if_z      jmp #FINISH


LET                     call #SET_VAL             ' Do the assignment
                        call #PARSE_SYM           ' Look for more "LET" items.
                        long (FINISH << 8) + ","                        
                        jmp #LET


NEW                     call #END_CHECK
                        wrlong _MemStart, _FreeMem
                        jmp #RESTART


F_PEEK                  call #PARN              ' Get address
                        rdbyte D0,D0            ' Get the byte
                        jmp #POP_RETN                        


F_ABS                   call #PARN              ' Get expression
                        abs D0,D0               ' ABS(<EXPR>)
                        jmp #POP_RETN



F_RND                   mov D0, RND wz          ' Get seed value
              if_z      rdlong D0, _KBD_Frame   ' Pickup New seed if neg or zero
                        and D0, cRND_Mask       ' Mask the tap bits
                        test D0, D0 wc          ' Parity is in C
                        rcl RND, #1              ' Rotate carry into result
                        abs RND, RND              ' Make it positive                        
                        jmp #POP_RETN
                         


NNEXT                   call #END_CHECK
                        rdLong Temp, _LopVar wz ' Was a loop in progress?
               if_z     jmp #ERR_NUTZ           ' Can't loop

                        rdlong D1, _LopVar      ' Fetch the lopVar Address
                        rdlong D0, D1           ' Fetch the loop var value
                        rdlong Temp, _LopInc    ' Fetch the inc value
                        adds D0, Temp           ' Update the loop var value
                        wrlong D0, D1           ' Write the value to the loop var                        
                        rdlong D1, _LopLmt      ' Fetch the limit value
                        test Temp, cNeg wz      ' If Inc is negative, then swap the cmp
              if_z      cmp D1, D0 wc           ' Set carry if outside limit
              if_nz     cmp D0, D1 wc           ' Set carry if outside limit                    
              if_nc     rdlong CurLine, _LopLin ' Restore pointer to loop line 
              if_nc     rdlong TxtPtr, _LopPtr  ' Restore Text pointer              
              if_c      call #QPOP_LOOP         ' Pop this loop off the stack
              
                        jmp  #FINISH


' Upon return, the upperword of TxtPtr is
' 1) The variable ascii code
' 2) the Value $FF indicating an error
'    and TxtPtr is left at the error point inthe text
' 3) The value $FE indicating a control C was entered
IINPUT_RETRY            mov TxtPtr, Temp4
                        abs CurLine, CurLine            ' turn off Input Flag
                        
IINPUT                  mov Temp2, #(@SWAP_INPUT+$10-4)>>2
                        jmp #BLOCK_RUN

POKE                    mov Temp2, #(@SWAP_POKE+$10-4)>>2
                        jmp #BLOCK_RUN

PRINT                   mov Temp2, #(@SWAP_PRINT+$10-4)>>2
                        jmp #BLOCK_RUN

LIST                    mov Temp2, #(@SWAP_LIST+$10-4)>>2
                        jmp #BLOCK_RUN

FFOR                    mov Temp2, #(@SWAP_FOR+$10-4)>>2
                        jmp #BLOCK_RUN

GOSUB                   mov Temp2, #(@SWAP_GOSUB+$10-4)>>2
                        jmp #BLOCK_RUN

RRETURN                 mov Temp2, #(@SWAP_RETURN+$10-4)>>2
                        jmp #BLOCK_RUN

RAND                    mov Temp2, #(@SWAP_RAND+$10-4)>>2
                        jmp #BLOCK_RUN


REM                     jmp #SKIP_LINE
IIF                     call #EXPR                      ' non zero is true
                        cmp D0, #0 wz                        
              if_nz     jmp #RUN_SAME_LINE
SKIP_LINE               mov TblPtr, TxtPtr
                        mov D4, #0
                        call #FIND_SKIP
              if_nc     cmp CurLine, #1 wc
              if_nc     jmp #RUN_THIS_LINE
                        jmp #RESTART                        
                        

VSIZE                   call #PUSH_RETN
F_SIZE                  mov D0, _VarBgn
                        rdlong Temp, _FreeMem
                        sub D0, Temp                        
                        jmp #POP_RETN


EXPR                    call #PUSH_RETN
                        call #EXPR2
                        call #STK_D0
                        mov TblPtr, #@TB_OPS+$10        ' Point to Ops table                        
                        jmp #EXEC                       ' Try Parsing an op

' Returns to here if OPS table parsed a valid logical operation.
' Temp2 holds the token, the last 4 bits of the token are the cccc bits of the cmp instruction.
EXPR_OPS                shl Temp2, #18                  ' Convert to asm compare bits
                        and :CMP_RESULT, cCMP_MASK      ' Zero out any old condition bits 
                        or  :CMP_RESULT, Temp2          ' Update the condition bits
                        call #EXPR2                     ' Evaluate second expression
                        call #USTK_D1                   ' Compare the two expressions
                        cmp D1,D0 wc,wz
                        mov D0, #0                      ' Assume result is true
:CMP_RESULT  if_never   mov D0, #1 wz                   ' Change result according to compare
                        jmp #POP_RETN

EXPR_END                rdlong D0, SP wz
                        add SP, #4

' Returns to the address on the top of the stack
LEVEL_END               
POP_RETN                rdlong RETURN_ADDR, SP
                        add SP, #4                        
PARN_RET                        
EXPR_RET
SIZE_RET                        
VSIZE_RET
EXPR2_RET               
EXPR3_RET               
EXPR4_RET
RETURN_ADDR             ret


' Push the contents of the address in temp on the stack
PUSH_RETN               sub SP, #4
                        wrlong EXPR_RET, SP
PUSH_RETN_RET           ret            
                                                


EXPR2                   call #PUSH_RETN
                        call #PARSE_SYM         ' If "-" then unary minus 
                        long (EXPR2_CONT<<8)+C#TOKEN_SUB

EXP_NEG                 mov  D0, #0              ' simulate 0-<EXP>
                        jmp  #EXPR2_SUB
                        
EXPR2_CONT              call #EXPR3
EXPR2_LOOP              mov  TblPtr, #@TB_PRIORITY2 + $10
                        jmp  #EXEC                        
EXPR2_SUB               call #STK_D0
                        call #EXPR3
                        neg  D0, D0             ' Reverse the sign                        
                        jmp  #EXPR2_ADD2        ' and add the two
                        
EXPR2_ADD               call #STK_D0            ' Save the value
                        call #EXPR3             ' Get second Expr
EXPR2_ADD2              call #USTK_D1           ' Get the result #2
                        adds D0, D1 wc
              if_c      jmp  #ERR_NUTZ          ' Error if overflow
                        jmp  #EXPR2_LOOP        ' Look for more                        

EXPR3                   call #PUSH_RETN
                        call #EXPR4

EXPR3_CONT              mov TblPtr, #@TB_PRIORITY3+$10
                        jmp #EXEC
                        
EXPR3_DOIT              call #STK_D0
                        call #EXPR4
                        call #USTK_D1
EXPR3_DOIT_RET          ret                        


EXPR3_MUL               call #EXPR3_DOIT
                        call #MULTIPLY
                        jmp  #EXPR3_CONT
                        
EXPR3_DIV               call #EXPR3_DOIT
                        call #SWAP_D0_D1
                        call #DIVIDE
                        and  D0, cBits16         ' Delete the remainder
                        jmp  #EXPR3_CONT


EXPR4                   call #PUSH_RETN
                        mov  TblPtr, #@TB_FUNCTIONS +$10
                        jmp  #EXEC
                        
EXPR4_VAR               call #TEST_VARS
              if_nc     rdlong D0, Temp6        ' If it's a var, we are done.              
              if_nc     jmp  #LEVEL_END          ' Read the vars value
                        call #READ_NUM          ' Check for a number
                        mov  D0, D1
              if_nz     call #PARN
                        jmp  #LEVEL_END                        


' Multiply D1[15..0] by d0[15..0] (d0[31..16] must be 0)
' on exit, product in d0[31..0]
multiply                shl D1,#16              ' Get multiplicand into x[31..16]
                        mov Temp,#16            ' Ready for 16 multiplier bits
                        shr D0,#1 wc            ' Get initial multiplier bit into c
:loop         if_c      add D0,D1 wc            ' If c set, add multiplicand into product
                        rcr D0,#1 wc            ' Get next multiplier bit into c, shift product
                        djnz Temp,#:loop        ' Loop until done
multiply_ret            ret                     ' Return with product in D0[31..0]


' Divide D0[31..0] by D1[15..0] (D1[16] must be 0)
' on exit, quotient is in D0[15..0] and remainder Is in D0[31..16]
divide                  shl D1,#15              ' Get divisor into D1[30..15]
                        mov temp,#16            ' Ready for 16 quotient bits
:loop                   cmpsub D0,D1 wc         ' If D1 =< D0 then subtract it, quotient bit into c
                        rcl D0,#1               ' Rotate c into quotient, shift dividend
                        djnz temp,#:loop        ' Loop until done
divide_ret              ret                     ' Quotient in D0[15..0], remainder in D0[31..16]




END_CHECK               call #PARSE_SYM
                        long (ERR_SYNTAX<<8)+ C#CR
                        sub TxtPtr, #1
END_CHECK_RET           ret              


RUN                     call #END_CHECK
                        mov TxtPtr, _MemStart
                        mov CurLine, _MemStart

RUN_NEXT_LINE           test CurLine, CurLine wz        ' If current is not zero then running
              if_z      jmp #RESTART                    ' If not we finished a direct statement
                        mov D1, #0
                        call #FIND_LINE_FROM_HERE
              if_c      jmp #RESTART                    ' Stop if no more lines.

RUN_THIS_LINE           mov CurLine, TxtPtr             ' Save the start of text for this line
                        add TxtPtr, #5                  ' Skipping the line number

RUN_SAME_LINE           call #CHKIO                     ' Look for CTRL+C
'                        mov TblPtr, #@TB_STATEMENTS+$10                                                              
'                        jmp #EXEC
                        jmp #DIRECT
                                                

GOTO                    call #EXPR
                        call #END_CHECK
                        mov D1, D0
                        call #FIND_LINE
              if_z      jmp #RUN_THIS_LINE        

ERR_NUTZ                mov Temp, #@TXT_NUTZ+$10
                        jmp #ERROR_REPORT

FINISH                  call #FIN                       ' Check for end of command
ERR_SYNTAX              mov Temp, #@TXT_SYNX+$10
                        jmp #ERROR_REPORT

ERR_OOM                 mov Temp, #@TXT_OOM+$10
ERROR_REPORT            mov Temp2, TxtPtr       ' Save the error pointer
                        mov TxtPtr, Temp        ' Point to error message
                        call #OUT_MESSAGE       ' Print the error message
                        mov TxtPtr, Temp2       ' Restore the error pointer
                        mov D0, CurLine wz      ' If the current line is zero do a warm start
              if_z      jmp #RESTART
                        shl D0, #1 nr, wc       ' If current line is neg then we were in input
              if_c      jmp #IINPUT_RETRY       ' If so, redo input
                        mov TxtPtr, CurLine     ' Point to the current line in error
                        call #OUT_ERROR_LINE    ' Display the line in error


RESTART                 mov CurLine, #0              
                        call #STARTUP

NEW_LINE                mov D0, #">"
                        call #GET_LINE          ' Get the tokenized line from the user
                        call #PROC_LINE         ' Do it to it!
              if_z      jmp #NEW_LINE           ' All done, go for another
                        cmp TxtPtr, #1 wz       ' Was the line number too big
              if_z      jmp #ERR_NUTZ           ' Tell user they are nutz if so              
                        cmp TxtPtr, #2 wz       ' Was there enough memory to add this line?
              if_z      jmp #ERR_OOM            ' Tell the user ther was not enough memory for that
                        mov TxtPtr, #@BUFFER+$10' Must be a direct statement, reset text pointer

DIRECT                  mov TblPtr, #@TB_COMMANDS+$10

' If the next char is a token that is valid for the table being pointed
' to in TblPtr, then jmp to the address for the token, else jmp to the default address
' given as the last table entry
' 
EXEC                    rdbyte Temp, TxtPtr     ' Pick up the token from the text
                        mov D2, #0              ' Clear match flag
:TBL_TEST_ENTRY         rdbyte Temp2, TblPtr wz ' Pick up the Token ID
                        add TblPtr, #1              
                        rdbyte Temp3, TblPtr    ' Pickup the address to jump to
                        add TblPtr, #1
              if_z      sub TxtPtr, #1          ' Back up text pointer if exec default 
              if_nz     cmp Temp2, temp wz      ' Do they match or at end of table?
              if_z      movs :REG, Temp3        ' Store the address to jmp to
              if_z      add TxtPtr, #1          ' Bump up the text pointer
:REG          if_z      jmp #0                  ' Execute the correct routine

                        ' Skip to the next item in the table.
:TBL_NXT_ENTRY          rdbyte Temp3, TblPtr
                        test Temp3, #$80 wz     ' Is this the end of the key word?
                        add TblPtr, #1
              if_z      jmp #:TBL_NXT_ENTRY     ' If zero keep scanning forward
                        jmp #:TBL_TEST_ENTRY
              


' Find the next line equal to or greater than the number in D1                        
FIND_LINE               cmp D1, cBits16 wc      ' Must be less than 65535
              if_nc     jmp #ERR_NUTZ
                        mov TxtPtr, _MemStart       '
                        
FIND_LINE_FROM_HERE     mov D4, D1
FIND_LINE_LOOP          rdlong Temp2, _FreeMem
                        sub Temp2, #1
                        cmp Temp2, TxtPtr wc,wz ' If pass the end, return
              if_c      jmp  #FIND_LINE_RET     ' With z=0 and c=1
                        call #READ_NUM          ' Fetch the line number
                        sub TxtPtr, #5          ' Reset the text pointer to the start of the line number
                        cmp D1, D4 wc,wz        ' Test the line # found against the target line #
              if_nc     jmp  #FIND_LINE_RET                                                        
FIND_NEXT               call #READ_NUM          ' Skip any possible number
FIND_SKIP               rdbyte Temp, TxtPtr     ' Look for the CR
                        add TxtPtr, #1                        
                        cmp Temp, #C#CR wz
              if_nz     jmp #FIND_SKIP
                        jmp #FIND_LINE_LOOP


                        
FIN                     call #PARSE_SYM
                        long (:FIN1 << 8) + ":" ' If ":" then don't return
                        jmp #RUN_SAME_LINE      ' Continue on same line
:FIN1                   call #PARSE_SYM
                        long (FIN_RET << 8) + C#CR
                        jmp #RUN_NEXT_LINE
FIN_RET
FIND_SKIP_RET
FIND_NEXT_RET
FIND_LINE_RET
FIND_LINE_FROM_HERE_RET      ret                      





                        


SET_VAL                 call #TEST_VARS         ' Variable name?
                        mov Temp4, Temp6
              if_c      jmp #ERR_SYNTAX
                        call #PARSE_SYM         ' Get past the = sign
                        long (ERR_SYNTAX << 8) + C#TOKEN_EQU
                        call #EXPR
                        wrlong D0, Temp4        ' Save the value in the var
SET_VAL_RET             ret


PARN                    call #PUSH_RETN
                        call #PARSE_SYM         ' LOOK FOR A PARN EXPRESSION
                        long (ERR_SYNTAX<<8) + "("
                        call #EXPR
                        call #PARSE_SYM
                        long (ERR_SYNTAX<<8) + ")"
                        jmp #POP_RETN



' RGW TODO: validate this routine (too many changes)

' return nc if found and Temp2=address, else returns c
TEST_VARS
                        rdbyte Temp6, TxtPtr
                        sub Temp6, #"@" wc, wz
              if_c      jmp #TEST_VAR_RET
              if_nz     jmp #TEST_VAR           ' Jmp if not the '@' array
                        add TxtPtr, #1          ' If it is then there needs to be
                        call #PARN              ' (EXPR) as it's index
                        add D0, D0 wc           ' 
                        add D0, D0 wc
                        mov Temp6, D0           ' Save the index
                        call #VSIZE             ' Get amount of free memory

                        cmp D0, Temp6 wz, wc

             if_be      jmp #ERR_OOM            ' Error if out of memory
                        mov Temp, _VarBgn
                        sub Temp, Temp6         ' Calc address of element
                        
                        jmp #TEST_VAR_RET       ' All done with array processing

TEST_VAR                mov Temp, #27           ' If carry then was not a-z
                        cmp Temp, Temp6 wc
              if_nc     add TxtPtr, #1          ' Bump up text pointer if it was a var name
              if_nc     shl Temp6 , #2          ' Calculate the variable address
              if_nc     add Temp6, _VarBgn              
TEST_VAR_RET              
TEST_VARS_RET           ret



SWAP_D0_D1              mov Temp, D0
                        mov D0, D1
                        mov D1, Temp
SWAP_D0_D1_RET          ret


STK_D0                  sub SP, #4              ' Save D0 on the stack
                        wrlong D0, SP           
STK_D0_RET              ret

USTK_D1                 rdlong D1, SP
                        add SP, #4
USTK_D1_RET             ret



' Read a long from memory that is not aligned on a long boundry
' TxtPtr = Memory address
' D1 = return value
' z is set if not a number and temp will hold the fist char
' z is clear is it was a number and temp will hold the next char after the number
READ_NUM                mov D1, #0
                        rdbyte temp, TxtPtr
                        cmp temp, #$FF wz
              if_z      add TxtPtr, #1                        
              if_z      mov D3, #4
              if_z      mov D2, #0                        
:LOOP         if_z      rdbyte Temp, TxtPtr
              if_z      add  TxtPtr, #1                        
              if_z      shl Temp, D2
              if_z      or D1, Temp
              if_z      add D2, #8
              if_z      djnz D3, #:LOOP
READ_NUM_RET            ret



' Try to parse the next byte in the text stream against the test symbol
' The long word following the call to this routine will be formatted as such.
' bits 0-7 hold the byte to test against and bits 8-31 hold the return address to jump
' to if the test fails.
PARSE_SYM               movs :REG, PARSE_SYM_RET  ' Update the source register for the instr at :REG
                        add PARSE_SYM_RET, #1     ' Fixup return address to the one AFTER the long data
                        rdbyte Temp, TxtPtr       ' Read the next byte in the text stream
:REG                    mov D4, 0                 ' Read the long data following the call
                        mov Temp2, D4             ' Save a copy
                        shr Temp2, #8             ' Find the alt return address 
                        and D4, #$FF              ' Mask out the char to test                        
                        cmp Temp, D4 wz           ' Test char, if nz then return to alt address
              if_nz     movs PARSE_SYM_RET, Temp2 ' Return to the alternate address
              if_z      add TxtPtr, #1            ' If the symbols matched, move on to next char        
PARSE_SYM_RET           ret



OUT_CRLF                mov Temp2, TxtPtr
                        mov TxtPtr, #@TXT_CRLF+$10      ' Print a CRLF
                        jmp #OUT_COMMON                        
OUT_CHAR                mov Temp2, TxtPtr               ' Prints a single ASCII char
                        mov TxtPtr, #@TXT_CHAR+$10
                        wrbyte D0, TxtPtr
OUT_COMMON              call #OUT_MESSAGE
                        mov TxtPtr, Temp2
OUT_CHAR_RET                             
OUT_CRLF_RET            ret

STARTUP                 mov D4, FUNC_STARTUP            ' Warm or cold start
                        mov Temp2, TxtPtr               ' Save Text Pointer
                        mov TxtPtr, SP                  ' Pass the Stack Pointer value
                        call #FUNC_EXEC
                        rdlong temp, _FuncBuff wz
                        mov SP, TxtPtr                  ' Update the new SP value
                        mov TxtPtr, Temp2               ' Restore the Text Pointer                        
STARTUP_RET             ret

' Attempts to print various strings
' Returns z set if nothing was printed
OUT_QUOTED_STRING       mov D4, FUNC_PRT_QUOTE_STR
                        mov Temp2, TxtPtr
                        call #FUNC_EXEC
                        cmp Temp2, TxtPtr wz            ' Return zero if nothing changed
OUT_QUOTED_STRING_RET   ret                        

' Prints a formatted number to <NumFormat> spaces                        
OUT_NUMBER              mov D4, FUNC_PRT_NUM
                        or D4, NumFormat                ' Add in the format number
                        mov Temp2, TxtPtr
                        mov TxtPtr, D0
                        call #FUNC_EXEC
                        mov TxtPtr, Temp2
OUT_NUMBER_RET          ret                        

' Add - Insert - Delete a line                        
PROC_LINE               mov D4, FUNC_PROCESS_LINE
                        jmp #FUNC_EXEC
                        
' Prints the text pointed to by Temp to the screen
OUT_MESSAGE             mov D4, FUNC_PRT_STR
                        jmp #FUNC_EXEC

' Prints a tokenized line
OUT_LINE                mov Temp2, #0
OUT_ERROR_LINE          mov D4, FUNC_PRT_LINE
                        or D4, Temp2                    ' Add in the error pointer
                        jmp #FUNC_EXEC
                        
GET_INPUT               mov D4, FUNC_INPUT
                        jmp #FUNC_EXEC

SAVE_FUNC               mov D4, FUNC_SAVE
                        jmp #FUNC_EXEC
                        
LOAD_FUNC               mov D4, FUNC_LOAD
                        jmp #FUNC_EXEC                                                
                        
' Get a line from the user, returned tokenized                        
GET_LINE                mov D4, FUNC_GET_LIN
                        add D4, D0

FUNC_EXEC               call #WAIT_FUNC                 ' Wait for previous function to complete
                        wrlong TxtPtr, _FuncBuff        ' always write TxtPtr
                        wrlong D4, _FuncCmd             ' Execute the function

                        shl D4, #1 nr, wc               ' Test if the wait for result flag is set
              if_c      call #WAIT_FUNC
                        shl D4, #1 nr, wc
              if_c      rdlong TxtPtr, _FuncBuff wz     ' Pickup the new value for TxtPtr
OUT_LINE_RET          
GET_LINE_RET            
PROC_LINE_RET
GET_INPUT_RET
FUNC_EXEC_RET
OUT_MESSAGE_RET
SAVE_FUNC_RET
LOAD_FUNC_RET
OUT_ERROR_LINE_RET      ret



WAIT_FUNC               rdlong temp, _FuncCmd wz        ' Wait for Dispatcher to be free
              if_nz     jmp #WAIT_FUNC
WAIT_FUNC_RET           ret                        
                        

CHKIO                   rdlong D0, _LastKey
                        wrlong cZero, _LastKey
                        cmp D0, #C#CTRL_C wz
              if_z      jmp #RESTART
CHKIO_RET               ret




QPUSH_LOOP              mov D4, #FUNC#_PushLoop         ' Set the function to run
                        jmp #QPOP_PUSH_CONT
                        
QPOP_LOOP               mov D4, #FUNC#_PopLoop
QPOP_PUSH_CONT          shl D4, #16
:Loop1                  rdlong Temp, _Command wz
              if_nz     jmp #:Loop1
                        wrlong SP, _FuncBuff        
                        wrlong D4, _Command
:Loop2                  rdlong Temp, _Command wz
              if_nz     jmp #:Loop2
                        rdlong SP, _FuncBuff wz
              if_z      jmp #ERR_OOM                    ' Jump to OOM if so flagged              
QSTARTUP_RET
QPOP_LOOP_RET
QPUSH_LOOP_RET           ret                            ' Return                        





' Screen IO Ready commands (too big to be used directly)
FUNC_PRT_STR            long C#FUNC_PRINT_STRING
FUNC_PRT_NUM            long C#FUNC_PRINT_NUMBER
FUNC_GET_LIN            long C#FUNC_GET_LINE
FUNC_INPUT              long C#FUNC_GET_INPUT
FUNC_GET_KEY            long C#FUNC_GET_KEYBD
FUNC_PRT_LINE           long C#FUNC_PRINT_LINE
FUNC_PROCESS_LINE       long C#FUNC_PROC_LINE
FUNC_PRT_QUOTE_STR      long C#FUNC_PRINT_QT_STR
FUNC_PUSH_LOOP          long C#FUNC_PUSH_LOOP
FUNC_POP_LOOP           long C#FUNC_POP_LOOP
FUNC_STARTUP            long C#FUNC_STARTUP
FUNC_LOAD               long C#FUNC_LOAD
FUNC_SAVE               long C#FUNC_SAVE

' ASM REGISTERS
SP                      Long $0                 ' Stack Pointer
CurLine                 long $0                 ' Current Line pointer
NumFormat               long $0                 ' Format for printing numbers
TxtPtr                  long $0                 ' Pointer into the text stream
TblPtr                  long $0                 ' Pointer to a exec table or literal text
Rnd                     long $0                 ' Random number seed

' Temp registers, listed from most used to least used
Temp                    long $0
Temp2                   long $0
Temp3                   long $0
Temp4                   long $0          
Temp5                   long $0
Temp6                   long $0

' Data registers, listed from most used to least used
D0                      long $0                 ' Result from expression evaluation
D1                      long $0
D2                      long $0
D3                      long $0
D4                      long $0 

' Local copy of Params
_Debugger               long $0                 ' HHL will display this result on line 0 (if enabled)
_MemStart               long $0                 ' Start of program memory
_FuncBuff               long $0                 ' Function buffer pointer
_FuncCmd                long $0                 ' Function command buffer pointer                         
_LastKey                long $0                 ' Last key pressed
_FreeMem                long $0                 ' Pointer to free memory
_VarBgn                 long $0                 ' Var area pointer
_Command                long $0 
_KBD_Frame              long $0                 ' Frame count as of last key press
_StkGos                 long $0                 ' Save stack pointer in "gosub"
_StkInp                 long $0                 ' Save stack pointer in "input"
_LopVar                 long $0                 ' 'FOR' loop save area
_LopInc                 long $0                 ' Loop increment
_LopLmt                 long $0                 ' Loop limit
_LopLin                 long $0                 ' Loop line number
_LopPtr                 long $0                 ' Text pointer



' Constants too big or awkward for literal use.
cDestRegPlus1           long 1 << 9               
cBits16                 long $FFFF
cZero                   long $0
cNeg                    long $80000000
cRndA                   long $00FD43FD
cRndC                   long $002B0843
cCmp_Mask               long %111111_1111_0000_111111111_111111111
cRND_Mask               long %10110100_00000000_00000000_00000000



' Copies a block of longs form HUB memory to COG memory then executes the block
BLOCK_RUN               shl Temp2, #2
                        mov Temp, #SWAP_AREA
                        mov Temp3, #C#MAX_SWAP_SIZE
                        call #BLOCK_MOVE
                        jmp #SWAP_AREA               

' Moves a block of long data from the hub memory to the local cog memory
BLOCK_MOVE              movd :Reg, Temp                        
:load                   add Temp2, #4
:Reg                    rdlong 0, Temp2
                        add :reg, cDestRegPlus1
                        djnz Temp3, #:Load
BLOCK_MOVE_RET          ret


' Free area to swap in statements and functions.
' Has to be inclusive. Two swaps can not be active at the same time.
org C#SWAP_AREA_START
SWAP_AREA               nop 