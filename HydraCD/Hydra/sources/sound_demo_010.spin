'//////////////////////////////////////////////////////////////////////////////
' Simple sound demo program - generates a square wave by using a counter in
' simple mode, there is no PWM, no D/A, this demo does nothing but gate
' a counter in NCO mode to p7 (the HYDRA's sound pin). Also, does everything with
' SPIN rather than ASM to control the counter.
'
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 2.19.06
' VERSION 1.0
' COMMENTS: Simply slide the mouse left to right to hear the square wave frequency
' increase / decrease. Also, make sure to have the HYDRA's audio output plugged into
' the TV.
'
' NOTE: some tv's will NOT output audio if there is NO video signal, if this is
' the case, then either add the video drivers to the demo and output nothing
' or plug the output of the HYDRA into an AUX audio input, later we will add
' video to all sound demos to make sure you can hear them, but wanted to keep
' this demo short! 
'//////////////////////////////////////////////////////////////////////////////

CON
  _clkmode = xtal2 + pll8x      ' set PLL to x8
  _xinfreq = 10_000_000         ' set input XTAL to 10MHz, thus final freq = 80MHz 

VAR
  long  mousex, mousey          ' track mouse position
  long  sd_freq                 ' frequency of sound (related to frequency actually)

OBJ
  mouse : "mouse_iso_010.spin"                          ' import the generic mouse driver

PUB start

  'start mouse on pingroup 2
  mouse.start(2)              

  'set up parms and start sound engine playing
  sd_freq   := $00000200        ' anything lower is hard to hear
 
  ' step 1: set CTRA mode to NCO single mode "00100", Pin B 0, Pin A = 7
  CTRA := %0_00100_000_00000_000000000_000000111 
  '          mode                Pin B     Pin A   

  ' step 2: set the frequency value that will be added to the PHSA register each clock
  FRQA := sd_freq

  ' step 3: set pin 7 to output
  DIRA := %00000000_00000000_00000000_10000000

  ' sit in loop and update frequency with mouse movement
  repeat
    sd_freq += mouse.delta_x << 8

    ' don't allow frequency to go lower than a rumble
    if (sd_freq < $00000200)
      sd_freq := $00000200

    ' and finally update frequency
    FRQA := sd_freq

