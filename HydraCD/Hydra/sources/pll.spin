CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

PUB go

  coginit(0, @entry, 0)

DAT

entry			movi	ctra, #%00011_000
			movd	ctra, #1
			movs	ctra, #0

			mov	frqa, _frq

			mov	dira, #3

:loop			jmp	#:loop

_frq			long	$1000_0000




   