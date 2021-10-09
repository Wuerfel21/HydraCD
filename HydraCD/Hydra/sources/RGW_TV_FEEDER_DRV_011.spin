CON
  paramcount  = 12

con TEST_ID = 0

PUB Start(_Params)

  cognew(@ASM_Begin, _Params) ' Start Spectrum screen driver in a new cog

DAT
                        org
' Copy parms from the stack to local memory
ASM_Begin               mov     command, par
                        mov        temp, #_ScanBuffer
                        movd       :Reg, Temp                    
                        mov        Temp, #paramcount
:load_Param             add     Command, #4
:Reg                    rdlong        0, Command
                        add        :reg, ConRegPlus1
                        djnz       Temp, #:Load_Param


' Copy the Palette to local memory so we don't get the delay hit
' Of accessing hub memory
PaletteLoop             mov command, _PaletteData
                        sub Command, #1
                        mov Temp, #PaletteTable
                        movd :Reg, Temp
                        mov Temp, #16
:Load_Palette           add command, #1
:Reg                    rdbyte 0, Command
                        add :Reg, ConRegPlus1
                        djnz temp, #:load_Palette

                        ' Radius is static so read it now
                        rdbyte SRadius, _SpriteSize


CalcSpriteInc           mov SpriteInc, #0
                        mov Temp, _MaxID
:IncLoop
                        add SpriteInc, SRadius
                        djnz Temp, #:IncLoop
                        sub SpriteInc, SRadius
                        add spriteinc, spriteinc
                        

CalcImageOffset         Mov ImageLine, _ImageData
                        mov ImageOffset, #0
                        mov Temp, _ID
                        tjz temp, #CalcImageInc
:OffsetLoop             add ImageOffset, #128
                        djnz Temp, #:OffsetLoop

CalcImageInc            mov ImageInc, #0
                        mov Temp, _MaxID
:IncLoop                add ImageInc, #128
                        djnz Temp, #:IncLoop
                        sub ImageInc, #128
                        
BuildFirstLine          call #NewFrame

                        ' Wait for a line to be requested.                        
CommandLoop             rdlong Command, _Command
                        cmp Command, BuildLine wz, wc
              if_z      call #CopyPixelBuff
                        jmp #CommandLoop


' Copy the pixel buffer to the TV's scanline buffer
CopyPixelBuff
                        mov OutPixCnt, #64
                        movd :CopyLoop, #PixelBuff
                        mov ScanLine, _ScanBuffer
:CopyLoop               wrlong PixelBuff, ScanLine
                        add ScanLine, #4
                        add :CopyLoop, ConRegPlus1
                        djnz OutPixCnt, #:CopyLoop
                        
                        ' Now build the pixel buffer for the next scan line
                        add BuildLine, _MaxID
                        cmp BuildLine, #191 wc, wz
              if_b      Jmp #BuildScanLine
              
                        ' New Frame
NewFrame                mov ImageLine, _ImageData
                        add ImageLine, ImageOffset 
                        mov BuildLine, _ID

                        rdlong SXMin, _BallX
                        mov SXMax, SXMin
                        add SXMax, SRadius
                        mov sx1, sxmax
                        mov sx2, sxmax
                        sub sx1 ,#1
                        add SXMax, SRadius
                        sub sxmax, #1

                        rdlong SYMin, _BallY
                        mov SYMax, SYMin
                        add SYMax, SRadius
                        add SYMax, SRadius

                        
                        ' Calculate sprite offset
                        mov Temp, SYMin
                        mov Temp2, _MaxID
                        call #Divide
                        
                        mov Temp, _SpriteOffsets
                        sub Temp, Temp2
                        add Temp, _ID
                        rdbyte Temp3, Temp
                        mov Temp2, SRadius
                        call #Multiply
                        mov SpriteLine, _SpriteData
                        shl Temp3, #1
                        add SpriteLine, Temp3


                        
                        
' Output 256 pixels (packed 2 to a byte), 4 bytes per long
BuildScanLine           movd :PixelStore, #PixelBuff
                        mov InGrpCnt,  #32
                        mov OutPixCnt, #4
                        mov OutPix, #0
                        mov PCol, #0
                        

:NextGroup              rdlong InPixels, ImageLine
                        add Imageline, #4                        
                        mov InPixCnt, #8

' Lookup color in palette table, store in outpix.                        
:NextPixel              mov Temp, InPixels


' If we are within the sprites domain then use it's pixel data
:TestSprite
                        cmp BuildLine, SYMin wz, wc
              if_b      jmp #:ScanContinue
                        cmp BuildLine, SYMax wz, wc
              if_a      jmp #:ScanContinue
              
                        cmp PCol, SXMin wz, wc
              if_b      jmp #:ScanContinue
                        cmp PCol, SXMax wz, wc
              if_a      jmp #:ScanContinue



                        rdword SHold, spriteline
                        cmp SHold, #0 wz
              if_z      jmp #:SpriteContinue
                        mov temp, #$f

                        ' Translate the data
                        mov Temp, ImageLine
                        mov Temp2, SHold
                        shr Temp2, #8
                        and Temp2, #$FF
                        shr temp2, #1 wc
                        add Temp, Temp2

                        mov temp2, pcol
                        and temp2, #%11
                        add temp, temp2
                        
                        rdbyte temp, Temp
              if_nc     shr temp, #4
                        and temp, #$f
                        

                        

:SpriteContinue         cmp PCol, sx1 wz, wc
              if_b      add spriteLine, #2
                        cmp PCol, SX2 wz,wc
              if_a      sub spriteLine, #2
              
                        cmp PCol, SXMax wz,wc
              if_b      jmp #:ScanContinue
                        add SpriteLine, SpriteInc

:ScanContinue           and Temp, #$F
                        add Temp, #PaletteTable                        
                        movs :PaletteLookup, Temp
                        shr InPixels, #4                        
:PaletteLookup          or  OutPix, OutPix

'cmp _id, #TEST_ID wz
'if_z mov OutPix, TestColor

                        ror OutPix, #8
                        add PCol, #1
                        
                        djnz OutPixCnt, #:Continue                        
:PixelStore             mov PixelPtr, OutPix
                        add :PixelStore, ConRegPlus1
                        mov OutPix, #0
                        mov OutPixCnt, #4
                        
:Continue               djnz InPixCnt, #:NextPixel ' Next Pixel of 8
                        djnz InGrpCnt, #:NextGroup ' Next group
                        add ImageLine, ImageInc
NewFrame_Ret
CopyPixelBuff_Ret       
BuildScanLine_Ret       ret
                        



' multiply Temp2 * Temp3
multiply
                        mov Temp4, #16
                        shl Temp2, #16
                        shr Temp3, #1 wc
:loop         if_c      add Temp3, Temp2 wc
                        rcr Temp3, #1 wc
                        djnz Temp4, #:loop                     
multiply_ret            ret


' Divide p1 by p2, return result (p1 / p2) into p1, and (p1 % p2) into p2
Divide                  shl Temp2, #15
                        mov Temp4, #16
:loop                   cmpsub Temp, Temp2 wc
                        rcl Temp, #1
                        djnz Temp4, #:loop                        
                        mov Temp2, Temp
                        shl Temp,  #16
                        shr Temp,  #16
                        shr Temp2, #16
divide_ret              ret



'+Debug = Discard after use       
debug
        wrlong temp, _debugger
:Debug_loop
        nop
        jmp #:Debug_Loop
'-Debug

InGrpCnt                long $0
InPixCnt                long $0
InPixels                long $0
OutPixCnt               long $0
ImageOffset             long $0
ImageInc                long $0
ImageLine               long $0
Scanline                long $0
Command                 long $0
BuildLine               long $0
PixelPtr                long $0
OutPix                  long $0
PCol                    long $0
Temp                    long $0
Temp2                   long $0
Temp3                   long $0
Temp4                   long $0
TempSpriteInc           long $0


SHold                   long $0
SpriteLine              long $0
SpriteInc               long $0
SYMax                   long $0
SRadius                 long $0
SWidth                  long $0
SHeight                 long $0
SXMin                   long $0
SXMax                   long $0
SYMin                   long $0
SX1                     Long $0
SX2                     long $0

' Params area
_TV_Status              long $0
_Scanbuffer             long $0
_SpriteOffsets          long $0
_SpriteSize             long $0
_SpriteData             long $0
_BallX                  long $0
_BallY                  long $0
_ImageData              long $0
_PaletteData            long $0
_Command                long $0
_Debugger               long $0
_MaxID                  long $0
_ID                     long $0

' Constants too big for literal use.
ConRegPlus1             long 1 << 9
TestColor               long $CCCCCCCC


' Pixel buffer holds the pre-rendered scanline buffer
PixelBuff               long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                        long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

' The copy the 16 bytes of palette info stored in local memory.
PaletteTable            long 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0