' //////////////////////////////////////////////////////////////////////
' Loader Kernel                         
' AUTHOR: Colin Phillips
' LAST MODIFIED: 1.5.06
' VERSION 0.1
' Slightly hacked by Remi for Alien Invader
'

CON
  
VAR

word kernel_stack[64]
  
PUB start(ptr)

  ' set up kernel stack pointer.
  LONG[@kernel_stack_ptr] := @kernel_stack + 63*2
  cognew(@entry,ptr)

DAT

' /////////////////////////////////////////////////////////////////////////////
' INITIALIZATION CODE /////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        org

entry

                        ' copy loader from original address (just after this initialization) to near the end of the cog.
                        mov     tmp0, #(__loader_registers-__loader_space) ' longs to copy
:loop_copy              mov     __loader_space, __loader_original               ' copy source to dest.
                        add     :loop_copy, k_ds0                               ' increment source and dest by 1.
                        djnz    tmp0, #:loop_copy

                        ' setup loader_stack pointer
                        mov     __loader_stack, kernel_stack_ptr
                        
                        ' initial asm page is assumed 448 LONG's and executes from org $0.
                        mov     __loader_page, par
                        mov     __loader_size, #448
                        mov     __loader_jmp, #0

                        jmp     #__loader_execute
                        
k_ds0                   long                    1<<9 | 1
tmp0                    long                    $0
kernel_stack_ptr        long                    $0

' /////////////////////////////////////////////////////////////////////////////
' LOADER CODE /////////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

__loader_original       ' Original address
                        org                     $1c0                            ' loader functions 1c0-1df
                        ' Final address
__loader_space

__loader_return
                        ' POP   __loader_page, __loader_size, __loader_jmp off stack. 3x WORDS
                        add     __loader_stack, #2
                        rdword  __loader_page, __loader_stack
                        add     __loader_stack, #2
                        rdword  __loader_size, __loader_stack
                        add     __loader_stack, #2
                        rdword  __loader_jmp, __loader_stack
                        jmp     #__loader_execute
__loader_call           ' (+7)
                        ' PUSH  __loader_ret, __loader_size, __loader_page on stack. 3x WORDS
                        wrword  __loader_ret, __loader_stack
                        sub     __loader_stack, #2
                        wrword  __loader_psize, __loader_stack
                        sub     __loader_stack, #2
                        wrword  __loader_ppage, __loader_stack
                        sub     __loader_stack, #2
                        ' [+] should also copy cog code back to hub.
__loader_execute        ' (+6)
                        movd    :loop_copy, #0

                        ' save current page/size
                        mov     __loader_ppage, __loader_page
                        mov     __loader_psize, __loader_size

                        ' copy hub[__page...__page+__size-1] -> cog[0...__size-1]

                        ' DEBUG >>>>
                        'rdlong r0, __loader_page
                        'wrlong r0, _k1
                        ' <<<<
                      
:loop_copy              rdlong  0, __loader_page                                ' copy a long over from hub mem to cog mem.                        
                        
                        add     __loader_page, #4                               ' increment source address by a long. (4 bytes)
                        add     :loop_copy, __k_d0                              ' increment destination address by a long. (1 register)

                        ' DEBUG >>>>
                        'mov r0, :loop_copy
                        'wrlong r0, _k1
                        'mov    r0, #20
                        'shl    r0, #20
                        'add    r0, cnt
                        'waitcnt r0, #0
                        ' DEBUG <<<<
                                    
                        djnz    __loader_size, #:loop_copy

                        ' execute code.
                        jmp     __loader_jmp
                        
__k_d0                  long                    1<<9
_k1                     long                    $7ffc
r0                      long                    $0

' /////////////////////////////////////////////////////////////////////////////
' LOADER REGISTERS ////////////////////////////////////////////////////////////
' /////////////////////////////////////////////////////////////////////////////

                        fit                     $1e0
                        org                     $1e0                            ' general registers 1e0-1ef
__loader_registers
__g0                    res                     1
__g1                    res                     1
__g2                    res                     1
__g3                    res                     1
__g4                    res                     1
__g5                    res                     1
__g6                    res                     1
__g7                    res                     1

__t0                    res                     1
__loader_ppage          res                     1
__loader_psize          res                     1
__loader_ret            res                     1
__loader_stack          res                     1
__loader_page           res                     1
__loader_size           res                     1
__loader_jmp            res                     1  