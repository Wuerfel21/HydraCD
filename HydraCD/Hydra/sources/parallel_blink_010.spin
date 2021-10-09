' //////////////////////////////////////////////////////////////////////
' Multiprocessing demo with blinking LED 
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 1.9.06
' VERSION 1.0
' COMMENTS: This program simply uses two COGs to blink the LED in parallel
'
' //////////////////////////////////////////////////////////////////////


CON

  _clkmode = xtal1 + pll4x          ' enable external clock and pll times 4
  _xinfreq = 10_000_000             ' set frequency to 10 MHZ
  _stack   = 40                     ' accomodate display memory and stack

VAR

long  blink_stack[20]               ' allocate 20 longs for the task stack

'///////////////////////////////////////////////////////////////////////////////
PUB Start
' this is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

' spawn 2 COGs each with the Blink function and some stack space
COGNEW (Blink(5_000_000), @blink_stack[0])
COGNEW (Blink(1_500_000), @blink_stack[10])

'sit in infinite loop, that is do not release COG 0
repeat while TRUE  

'///////////////////////////////////////////////////////////////////////////////  
PUB Blink(rate)
' this is the parallel function, it simple blinks the debug LED on the
' hydra, note is must set the direction output and then falls into
' an infinite loop and turns the LED on / off with a delay count.
' the interesting thing to realize is that the "rate" is sent as a parm
' when we launch the COG, so there will be 2 COGs running this SAME
' infinite loop, but each with a differnet blink rate, the results
' will be a blinking light that has both one constant blink rate
' with another super-imposed on it

DIRA[0] := 1                                             

repeat while TRUE
  OUTA[0] := !OUTA[0]
  waitcnt(CNT + rate)










    