' //////////////////////////////////////////////////////////////////////
' COP test (tv-graphics engine)         
' AUTHOR: Colin Phillips
' LAST MODIFIED: 1.25.06
' VERSION 0.2
'
' DESCRIPTION:
' Illustrates the basic framework of COG communication.
' Using PWM techniques, DEBUG LED intensity varies from 0 to Full Voltage,
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x          ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000      ' set frequency to 10 MHZ plus some error    
  _stack   = 40                     ' accomodate display memory and stack

'///////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

VAR

long  blink_stack[20]               ' allocate 20 longs for the task stack
long  cop_status
long  cop_control
long  cop_debug

long  count_dir

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

OBJ
  cop   : "cop_drv_001.spin"          ' instantiate a cop object

'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB Start
' this is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

  'start cop
  cop.start(@cop_status)

  cop_debug := $0

count_dir := $00040000
'sit in infinite loop, that is do not release COG 0
repeat while TRUE
  cop_debug+=count_dir
  if(cop_debug==0)
    count_dir := -count_dir

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