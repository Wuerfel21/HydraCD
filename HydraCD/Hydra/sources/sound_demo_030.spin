'//////////////////////////////////////////////////////////////////////////////
' Simple sound demo program, simulates the sound of an engine, synthesizes a waveform
' y = x*x along with a harmonic, gives the sound of a car/motorcycle running!
' calls the "engine" sound driver
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 2.19.06
' VERSION 3.0
' COMMENTS: Simply slide the mouse left to right to hear the engine accelerate
' make sure to have the HYDRA's audio output plugged into the TV.
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

  long  sd_pin                  ' desired pin to output sound on
  long  sd_freq                 ' frequency of sound (related to frequency actually)
  long  sd_volume               ' volume of sound

OBJ

  sd    : "sound_engine_drv_011.spin"                   ' import the "engine" sound driver
  mouse : "mouse_iso_010.spin"                          ' import the generic mouse driver

PUB start

  'start mouse on pingroup 2
  mouse.start(2)              

  'set up parms and start sound engine playing
  sd_pin    := 7                ' pin 7 (hydra sound pin)
  sd_freq   := $00400000        ' anything lower than this sounds like poping
  sd_volume := $FFFF            ' volume $0000-FFFF (max), however, volume not used in this version of driver
  sd.start(@sd_pin)             ' start the "engine" sound driver

  ' sit in loop and update frequency with mouse movement, the ASM driver is "watching" this variable
  repeat
    sd_freq += mouse.delta_x << 16

    ' don't let sd_freq below $00400000
    if (sd_freq < $00400000)
      sd_freq := $00400000 