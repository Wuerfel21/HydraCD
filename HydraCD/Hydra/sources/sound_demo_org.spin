''*****************************
''*  Sound Demo               *
''*  (C) 2005 Parallax, Inc.  *
''*****************************

CON

  _clkmode = xtal1 + pll4x
  _xinfreq = 10_000_000

VAR

  long	mousex, mousey

  long	sd_pin_left
  long	sd_pin_right
  long	sd_freq_left
  long	sd_freq_right
  long	sd_volume_left
  long	sd_volume_right

OBJ

  sd	: sound
  mouse	: mouse_iso


PUB start

  'start mouse
  mouse.start(2)


  'start sound
  sd_pin_left := 0
'  sd_pin_right := 7
  sd_freq_left := $200C2345>>4
'  sd_freq_right := $20100000>>4
  sd_volume_left := $FFFF >> 0
'  sd_volume_right := $FFFF >> 0
  sd.start(@sd_pin_left)

  repeat
    sd_freq_left += mouse.delta_x << 18
 '   sd_freq_right += mouse.delta_y << 18
