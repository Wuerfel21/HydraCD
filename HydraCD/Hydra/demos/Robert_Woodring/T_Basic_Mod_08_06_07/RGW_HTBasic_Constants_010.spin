CON     '' Public constants


   USE_DEFAULT      = -1
   
   NO_ARGS = 0
   VAR_SIZE = 27*4              ' 26 vars (plus 1 padding)
   PRG_SIZE = 10000 -2000
   ASM_STK_SIZE = 2048/4        ' 512 long stack size (this is alot of play room)
  
   ' ASCII Control codes
   CTRL_C  = $03
   CTRL_Y  = $04
   BACK_SP = $08
   LF      = $0A
   CR      = $0D
   CTRL_S  = $13
   CTRL_X  = $18
   SPACE   = " "
   DBL_QUOTE = 34
   SNG_QUOTE = 39

   ' Function Commands
   FUNC_WAIT_RESULTS  =  $80000000                      ' Wait for function to complete before exit                                              
   FUNC_REST_TXT      =  $40000000                      ' Restore T0 after function complete
   
   FUNC_MASK          =  ($FFFF << 16)     
   
   FUNC_GET_KEYBD     =  (%00000001 << 16)
   FUNC_STARTUP       =  (%00000010 << 16)  | FUNC_WAIT_RESULTS | FUNC_REST_TXT
   FUNC_PUSH_LOOP     =  (%00000011 << 16)  | FUNC_WAIT_RESULTS | FUNC_REST_TXT  
   FUNC_POP_LOOP      =  (%00000100 << 16)  | FUNC_WAIT_RESULTS | FUNC_REST_TXT    
   FUNC_PRINT_NUMBER  =  (%00000101 << 16)  | FUNC_WAIT_RESULTS | FUNC_REST_TXT   
   FUNC_GET_LINE      =  (%00000110 << 16)  | FUNC_WAIT_RESULTS | FUNC_REST_TXT
   FUNC_PRINT_LINE    =  (%00000111 << 16)  | FUNC_WAIT_RESULTS | FUNC_REST_TXT
   FUNC_GET_INPUT     =  (%00001000 << 16)  | FUNC_WAIT_RESULTS | FUNC_REST_TXT
   FUNC_PROC_LINE     =  (%00001001 << 16)  | FUNC_WAIT_RESULTS | FUNC_REST_TXT
   FUNC_PRINT_QT_STR  =  (%00001010 << 16)  | FUNC_WAIT_RESULTS | FUNC_REST_TXT
   FUNC_PRINT_STRING  =  (%00001011 << 16)  | FUNC_WAIT_RESULTS
   FUNC_LOAD          =  (%00001100 << 16)  | FUNC_WAIT_RESULTS
   FUNC_SAVE          =  (%00001101 << 16)  | FUNC_WAIT_RESULTS

   ' Compare operators need to have the last 4 bits set to the bits needed
   ' to complete an ASM compare operation
   ' CMP Operators
   CMP_BITS_CMP_B  = %1100
   CMP_BITS_CMP_BE = %1110
   CMP_BITS_CMP_AE = %0011
   CMP_BITS_CMP_E  = %1010
   CMP_BITS_CMP_NE = %0101
   CMP_BITS_CMP_A  = %0001

   ' Tokens
   TOKEN_FLAG = %10000000
   TOKEN_NUM = TOKEN_FLAG | %111_1111
   TOKEN_GEQ = TOKEN_FLAG | %000_0000 | CMP_BITS_CMP_AE ' ">="
   TOKEN_NEQ = TOKEN_FLAG | %000_0000 | CMP_BITS_CMP_NE ' "<>"
   TOKEN_LEQ = TOKEN_FLAG | %000_0000 | CMP_BITS_CMP_BE ' "<="
   TOKEN_GTN = TOKEN_FLAG | %000_0000 | CMP_BITS_CMP_A  ' ">"
   TOKEN_EQU = TOKEN_FLAG | %000_0000 | CMP_BITS_CMP_E  ' "="
   TOKEN_LTN = TOKEN_FLAG | %000_0000 | CMP_BITS_CMP_B  ' "<"

   TOKEN_ADD = TOKEN_FLAG | %001_0000            ' "+" 
   TOKEN_SUB = TOKEN_FLAG | %001_0001            ' "-"
   TOKEN_MUL = TOKEN_FLAG | %001_0010            ' "*"
   TOKEN_DIV = TOKEN_FLAG | %001_0011            ' "/"
   
   TOKEN_LIST = TOKEN_FLAG | %001_0100            ' "LIST"
   TOKEN_LODE = TOKEN_FLAG | %001_0101            ' "LOAD"
   TOKEN_NEW  = TOKEN_FLAG | %001_0110            ' "NEW"
   TOKEN_RUN  = TOKEN_FLAG | %001_0111            ' "RUN"
   TOKEN_SAVE = TOKEN_FLAG | %001_1000            ' "SAVE"                        
   TOKEN_NEXT = TOKEN_FLAG | %001_1001            ' "NEXT"
   TOKEN_LET  = TOKEN_FLAG | %001_1010            ' "LET"
   TOKEN_IF   = TOKEN_FLAG | %001_1011            ' "IF"
   TOKEN_GOTO = TOKEN_FLAG | %001_1100            ' "GOTO"
   TOKEN_GOSB = TOKEN_FLAG | %001_1101            ' "GOSUB"
   TOKEN_RET  = TOKEN_FLAG | %001_1110            ' "RETURN"
   TOKEN_REM  = TOKEN_FLAG | %001_1111            ' "REM"
   TOKEN_FOR  = TOKEN_FLAG | %010_0000            ' "FOR"
   TOKEN_INPT = TOKEN_FLAG | %010_0001            ' "INPUT"
   TOKEN_PRNT = TOKEN_FLAG | %010_0010            ' "PRINT"
   TOKEN_POKE = TOKEN_FLAG | %010_0011            ' "POKE"
   TOKEN_STOP = TOKEN_FLAG | %010_0100            ' "STOP"
   TOKEN_TO   = TOKEN_FLAG | %010_0101            ' "TO"
   TOKEN_STEP = TOKEN_FLAG | %010_0110            ' "STEP"                        
   TOKEN_PEEK = TOKEN_FLAG | %010_0111            ' "PEEK"
   TOKEN_RND  = TOKEN_FLAG | %010_1000            ' "RND"
   TOKEN_ABS  = TOKEN_FLAG | %010_1001            ' "ABS"
   TOKEN_SIZE = TOKEN_FLAG | %010_1010            ' "SIZE"
   TOKEN_RAND = TOKEN_FLAG | %010_1011            ' "RAND" 
   LAST_ENTRY = 0   


   ' COG Swapping constants
   MAX_SWAP_SIZE = 30
   SWAP_AREA_START = $1EF - MAX_SWAP_SIZE - 1
   
PUB Start