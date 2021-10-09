'//////////////////////////////////////////////////////////////////////////////
CON

  rate		= 2_000_00		'sample rate

'//////////////////////////////////////////////////////////////////////////////
VAR

  long	cogon, cog

  ' parameter table, passed to ASM by "par" global for COG on init
  long par_freq	' frequency or count of master clock for each loop iteration


'//////////////////////////////////////////////////////////////////////////////
PUB start(freq) : okay


  stop
  ' pass frequency into parameter passing area
  par_freq := freq

  okay := cogon := (cog := cognew(@entry, @par_freq)) > 0

PUB stop

'' Stop sound driver - frees a cog

  if cogon~
    cogstop(cog)


'//////////////////////////////////////////////////////////////////////////////
DAT

'//////////////////////////////////////////////////////////////////////////////
' Assembly language square wave generator 
'//////////////////////////////////////////////////////////////////////////////

			org
'
' Entry
'
entry			
			' extract parameters
			mov	t1, par			' load pointer to parameter passing area
			add	t1, #0*4		' index into 0th element which is frequency
			rdlong	_par_freq, t1		' read main memory (hub sync as well)

			mov	cntacc, cnt		' init current count cntacc
			add	cntacc, _par_freq	' add the desired number of clocks the code is to "take"

			mov	dira, #%00000100	' set direction of I/O pins

:square         	xor	outa, #%00000100	' invert clock pin

			waitcnt	cntacc, _par_freq	' wait for count sync
			jmp	#:square


'//////////////////////////////////////////////////////////////////////////////



'//////////////////////////////////////////////////////////////////////////////
' Initialized data
'//////////////////////////////////////////////////////////////////////////////

cntadd			long	40_000_000 / 2_000_00

'//////////////////////////////////////////////////////////////////////////////
' Uninitialized data
'//////////////////////////////////////////////////////////////////////////////

cntacc			res	1
t1			res	1
t2			res	1
t3			res	1

' local copy of parameters
_par_freq		res	1



