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

			mov	x,cnt
			add	x,bignum

:loop			shr	frqa,#1
			waitcnt	x,bignum

			shl	frqa,#1
			waitcnt	x,bignum

			jmp	#:loop

_frq			long	$8000_0000
bignum			long	80_000_000 >> 2

x			res	1
