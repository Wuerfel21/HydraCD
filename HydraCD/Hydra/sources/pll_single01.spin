CON

  ' set overclock to 64 MHz
  _clkmode = xtal1 + pll8x
  _xinfreq = 8_000_000

 	

  ' counter modes 5-bits each padding with 1 msb and 3 lsb's
  ' the 3 lsb's represent the clock mux select bits [s2..s0] which selects
  ' the output tap

  CNT_MODE_OFF      = %0_00000_000 
  CNT_MODE_PLL_INT  = %0_00001_000 

  CNT_MODE_PLL_SINGLE = %0_00010_000 
  CNT_MODE_PLL_DIFF   = %0_00011_000 

  CNT_MODE_NCO_SINGLE = %0_00100_000 
  CNT_MODE_NCO_DIFF   = %0_00101_000 

  CNT_MODE_DUTY_SINGLE = %0_00110_000 
  CNT_MODE_DUTY_DIFF   = %0_00111_000 


  ' counter mux selects
  CNT_MUXSEL_X16	= %000000_111
  CNT_MUXSEL_X8		= %000000_110
  CNT_MUXSEL_X4		= %000000_101
  CNT_MUXSEL_X2		= %000000_100
  CNT_MUXSEL_X1		= %000000_011
  CNT_MUXSEL_X1_1	= %000000_011
  CNT_MUXSEL_X1_2	= %000000_010	
  CNT_MUXSEL_X1_4	= %000000_001	
  CNT_MUXSEL_X1_8	= %000000_000                	


PUB start

  coginit(0, @asm_entry, 0)

DAT
                                     
asm_entry		movi	ctra, #CNT_MODE_PLL_SINGLE | CNT_MUXSEL_X1	' set counter mode to pll single with x1 on the mux

							' the output at pin A and B (B='A) tracks phsa[31]

			movs	ctra, #0		' sets pin A in/out to P0, S[5:0]
			movd	ctra, #1		' sets pin B in/out to P1, D[5:0]

			mov	frqa, _frq		' copy _frq value into frqa register
							' this value is added every time to the phsa registers

			mov	dira, #3		' set P0 and P1 to outputs, no output UNTIL these set to outputs
							' 

:loop			jmp	#:loop			' infinite loop

_frq			long	$1000_0000		'maximum count rate, overflows every clock



         
                              
        




 