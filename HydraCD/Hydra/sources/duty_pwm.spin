CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

PUB go

  coginit(0, @entry, 0)

DAT

entry			movi	ctra,#%00100_000
			movd	ctra,#1
			movs	ctra,#0

			mov	frqa,#1

			mov	dira,#3

			mov	x,cnt
			add	x,cntadd

:loop			waitcnt	x,cntadd
			neg	phsa,duty
			jmp	#:loop


cntadd			long	$1000
duty			long	$C00
x			res	1
