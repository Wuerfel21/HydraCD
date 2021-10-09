CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

PUB go

  coginit(0, @entry, 0)

DAT

entry			movi	ctra,#%00101_000
			movd	ctra,#1
			movs	ctra,#0

			mov	frqa,_frq

			mov	dira,#3

:loop			add	frqa,#1
			jmp	#:loop

_frq			long	$0100_0000
