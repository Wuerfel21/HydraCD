''*****************************
''*  TV Terminal Demo v1.0    *
''*  (C) 2004 Parallax, Inc.  *
''*****************************

CON

        _clkmode        = xtal1 + pll8x
        _xinfreq        = 10_000_000 + 3000

VAR

        long    testerror

        long    vlong
        word    vword
        byte    vbyte

OBJ

        term    : "tv_terminal_010.spin"


PUB start  | i

  'start the tv terminal
  term.start

  'change to green
  term.out(2)

  'print a string
  term.pstring(@title)


  'print some small decimal numbers
  repeat i from -6 to 6
    term.dec(i)
    term.out(" ")
  term.out(13)

  'print the extreme decimal numbers
  term.dec($7FFFFFFF)
  term.out(9)
  term.dec($80000001)
  term.out(13)

  'change to red
  term.out(3)

  'print some hex numbers
  repeat i from -6 to 6
    term.hex(i, 2)
    term.out(" ")
  term.out(13)

  'print some binary numbers
  repeat i from 0 to 7
    term.bin(i, 3)
    term.out(13)


DAT

title   byte    "TV Terminal Demo",13,13,0
