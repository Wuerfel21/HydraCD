CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

VAR

  long duty

PUB go

  cognew(@entry, @duty)

  repeat
    repeat duty from 0 to $10000


DAT

entry			'movi	ctra,#%00101_000
			'movd	ctra,#1
			'movs	ctra,#0

			mov	ctra,ctra_config	'this is more code-efficient if value is known

			mov	frqa,#1

			mov	dira,#3

			mov	cntacc,cnt
			add	cntacc,cntadd

:loop			waitcnt	cntacc,cntadd
			rdword	_duty,par
			neg	phsa,_duty
			jmp	#:loop


cntadd			long	$10000
ctra_config		long	%00101_000 << 23 + 1 << 9 + 0		'configuration data

cntacc			res	1
_duty			res	1
