CON

  _xinfreq = 10_000_000
  _clkmode = xtal1 + pll8x

OBJ

  term : "vgaterm_013.spin"
'
'
' Start monitor3

'
PUB start: I

  term.start(%10111)
  term.print($110)
  repeat 4
    repeat i from 0 to $FF
      term.print(i)