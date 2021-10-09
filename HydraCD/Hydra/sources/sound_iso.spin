''*****************************
''*  Sound Driver v1.0        *
''*  (C) 2005 Parallax, Inc.  *
''*****************************

CON

  rate		= 22050		'sample rate

VAR

  long	cogon, cog


PUB start(sound_ptr) : okay

'' Start sound driver - starts a cog
'' returns false if no cog available
''

  stop
  okay := cogon := (cog := cognew(@entry, sound_ptr)) > 0


PUB stop

'' Stop sound driver - frees a cog

  if cogon~
    cogstop(cog)

DAT

'**********************************
'* Assembly language sound driver *
'**********************************

			org
' Entry
'
entry			mov	cntacc,cnt		'init cntacc
			add	cntacc,cntadd		' add in 40M/22050 = ~1814 (number of cycles per software update)

:loop			movd	:arg,#_pin_left		' get parameters start address, store in dummy var D of rdlong instruction
			mov	t2, par			' par points to actual parameter table from caller
			mov	t3,#6			' number of parameters to copy from caller to local vars
:arg			rdlong	0,t2			' 0 is dummy which is overwritten with self modifying code call at :loop with address of next var
			add	:arg,d0			' var is read, :arg is updated by 9 << 1 since this is the LSB of the destination address as located in the instruction format
			add	t2,#4
			djnz	t3,#:arg

			mov	t1,#0			'make outputs
			mov	t2,#0

			test	_pin_left,#$20	wc
			mov	t3,#1
			shl	t3,_pin_left
	if_nc		or	t1,t3
	if_c		or	t2,t3


			mov	dira,t1
			movs	ctra,_pin_left		'set ctr's
			movi	ctra,#%00110_000	'(delta modulation)

        		mov	t1,phase_left		'calculate samples
			shr	t1,#32-13
			mov	t2,_volume_left
			call	#polar
			mov	left,t1

			add	phase_left,_freq_left	'update phases

			waitcnt	cntacc,cntadd		'wait for count sync

			mov	frqa, left		'update left and right outputs

			jmp	#:loop			'loop
'
'
' Polar to cartesian
'
'   in:		t1 = 13-bit angle
'		t2 = 16-bit length
'
'   out:	t1 = x|y
'
polar			test	t1,sine_180	wz	'get sine quadrant 3|4 into nz
			test	t1,sine_90	wc	'get sine quadrant 2|4 into c
			negc	t1,t1			'if sine quadrant 2|4, negate table offset
			or	t1,sine_table		'or in sine table address >> 1
			shl	t1,#1			'shift left to get final word address
			rdword	t1,t1			'read sine/cosine word
			call	#multiply		'multiply sine/cosine by length to get x|y
			shr	t1,#2			'justify x|y integer
			add	t1,h80000000		'convert to duty cycle
			negnz	t1,t1			'if sine quadrant 3|4, negate x|y
polar_ret		ret

sine_90			long	$0800			'90° bit
sine_180		long	$1000			'180° bit
sine_table		long	$E000 >> 1		'sine table address shifted right
h80000000		long	$80000000
'
'
' Multiply
'
'   in:		t1 = 16-bit multiplicand (t1[31..16] must be 0)
'		t2 = 16-bit multiplier
'
'   out:	t1 = 32-bit product
'
multiply		shl	t2,#16

			shr	t1,#1		wc
	if_c		add	t1,t2		wc
			rcr	t1,#1		wc
	if_c		add	t1,t2		wc
			rcr	t1,#1		wc
	if_c		add	t1,t2		wc
			rcr	t1,#1		wc
	if_c		add	t1,t2		wc
			rcr	t1,#1		wc
	if_c		add	t1,t2		wc
			rcr	t1,#1		wc
	if_c		add	t1,t2		wc
			rcr	t1,#1		wc
	if_c		add	t1,t2		wc
			rcr	t1,#1		wc
	if_c		add	t1,t2		wc
			rcr	t1,#1		wc
	if_c		add	t1,t2		wc
			rcr	t1,#1		wc
	if_c		add	t1,t2		wc
			rcr	t1,#1		wc
	if_c		add	t1,t2		wc
			rcr	t1,#1		wc
	if_c		add	t1,t2		wc
			rcr	t1,#1		wc
	if_c		add	t1,t2		wc
			rcr	t1,#1		wc
	if_c		add	t1,t2		wc
			rcr	t1,#1		wc
	if_c		add	t1,t2		wc
			rcr	t1,#1		wc
	if_c		add	t1,t2		wc
			rcr	t1,#1		wc

multiply_ret		ret
'
'
' Initialized data
'
d0			long	1 << 9 << 0			' = 512? why not use 512

cntadd			long	40_000_000 / rate

lfsr_left		long	1

phase_left		long	0

'
'
' Uninitialized data
'
freq_left		res	1


left			res	1

cntacc			res	1
t1			res	1
t2			res	1
t3			res	1
'
'
' Parameter buffer
'
_pin_left		res	1	'%ppppp		read-only
_freq_left		res	1	'long		read-only
_volume_left		res	1	'word		read-only

