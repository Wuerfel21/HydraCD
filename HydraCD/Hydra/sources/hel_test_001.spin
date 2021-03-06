' //////////////////////////////////////////////////////////////////////
' HEL_TEST_001.SPIN - Hel video driver test bed
' VERSION: 0.1
' AUTHOR: Andre' LaMothe
' LAST MODIFIED:
' COMMENTS:
'
'
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x          ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000      ' set frequency to 10 MHZ plus some error    
  _stack   = 128                    ' accomodate display memory and stack

'///////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

VAR

long  count_dir  
long  hel_debug

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

OBJ
  hel   : "hel_video_drv_001.spin" ' instantiate a HEL object

'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB Start
' this is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

  'start hel engine
   hel_debug := $0
  hel.start(@hel_debug)

  count_dir := $00040000

  'sit in infinite loop, that is do not release COG 0
  repeat while TRUE
    hel_debug+=count_dir
    if(hel_debug==0)
      count_dir := -count_dir