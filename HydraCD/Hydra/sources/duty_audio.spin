CON

  _clkmode = xtal1 + pll8x
  _xinfreq = 8_000_000

PUB go

  coginit(0, @entry, 0)

DAT

entry			movi	ctra,#%00111_000
			movd	ctra,#1
			movs	ctra,#0

			mov	frqa,_frq

			mov	dira,#3

:loop			add	frqa, _envelope

			jmp	#:loop

_frq			long	$C000_0000
_envelope		long	$000F_FFFF