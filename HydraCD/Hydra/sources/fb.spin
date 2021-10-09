'
'   Sample demo.
'
'   Copyright 2006, Radical Eye Software.
'
'   Try not to spoil it by reading much more.  I've moved the code below the fold
'   to help.
'


obj
   tvterm : "CC_Terminal"
'  keys : "insert_keyboard"
   keys : "keyboard_iso_010"

con
   _clkmode = xtal1 + pll8x
   _xinfreq = 10_000_000 + 3000  
   maxstack = 20
   progsize = 8192
   ntoks = 12
   linelen = 256

var
   long sp, tp, eop, nextlineloc, rv, curlineno
   long vars[26], stack[maxstack]
   byte program[progsize], tline[linelen]

dat
   tok0 byte "IF", 0
   tok1 byte "THEN", 0
   tok2 byte "INPUT", 0
   tok3 byte "PRINT", 0
   tok4 byte "GOTO", 0
   tok5 byte "GOSUB", 0
   tok6 byte "RETURN", 0
   tok7 byte "REM", 0
   tok8 byte "NEW", 0
   tok9 byte "LIST", 0
   tok10 byte "RUN", 0
   tok11 byte "RND", 0
   toks long @tok0, @tok1, @tok2, @tok3, @tok4, @tok5, @tok6, @tok7, @tok8, @tok9, @tok10, @tok11
   syn byte "SYNTAX ERROR", 0
   ln byte "INVALID LINE NUMBER", 0

pri bgetc | c, dc
   dc := 1
   repeat
      repeat while not keys.gotkey
         tvterm.out(dc)
         dc := (dc + 1) & 3
         waitcnt(cnt+5_000_000)
      tvterm.out(0)
      c := keys.getkey
      if c == $c8 or c == $c9
         c := 8
      if c == 8 or c == 13 or (c => 32 and c < 128)
         return c

pri bputc(c)
   tvterm.out(c)

pri screenpos
   return tvterm.getxpos

pri bputs(s)
   repeat while byte[s][0]
      bputc(byte[s++][0])

pri putinz(v)
   if v => 10
      putinz(v/10)
   bputc(v // 10 + "0")

pri putint(v) | dp
   if v < 0
      bputc("-")
      v := - v
   putinz(v)

pri getline | i, c
   i := 0
   repeat
      c := bgetc
      if c == 8
         if i > 0
            bputc(8)
            bputc(" ")
            bputc(8)
            i--
      elseif c == 13
         bputc(13)
         tline[i] := 0
         tp := @tline
         return
      elseif i < linelen-1
         bputc(c)
         tline[i++] := c

pri putlinet(s) | c
   repeat while c := byte[s++][0]
      if c => 128
         bputs(@@toks[c-128])
         bputc(" ")
      else
         bputc(c)
   bputc(13)

pri spaces | c
   repeat
      c := byte[tp]
      if c == 0 or c > " "
         return c
      tp++

pri skipspaces
   if byte[tp]
      tp++
   return spaces

pri parseliteral | r, c
   r := 0
   repeat
      c := byte[tp]
      if c < "0" or c > "9"
         return r
      r := r * 10 + c - "0"
      tp++

pri movprog(at, delta)
   if eop + delta + 2 - @program > progsize
      abort string("NO MEMORY")
   bytemove(at+delta, at, eop-at)
   eop += delta

pri fixvar(c)
   if c => "a"
      c -= 32
   return c - "A"

pri isvar(c)
   c := fixvar(c)
   return c => 0 and c < 26

pri tokenize | tok, c, at, put, state, i, j
   at := tp
   put := tp
   state := 0
   repeat while c := byte[at]
      if c == 34  ' double quote
         if state == "Q"
            state := 0
         elseif state == 0
            state := "Q"
      if state == 0
         repeat i from 0 to constant(ntoks-1)
            tok := @@toks[i]
            j := 0
            repeat while byte[tok] and ((byte[tok] ^ byte[j+at]) & constant(!32)) == 0
               j++
               tok++
            if byte[tok] == 0 and not isvar(byte[j+at])
               byte[put++] := 128 + i
               at += j
               if i == 7
                  state := "R"
               else
                  repeat while byte[at] == " "
                     at++
               next
      byte[put++] := byte[at++]
   byte[put] := 0

pri wordat(loc)
   return (byte[loc]<<8)+byte[loc+1]

pri findline(lineno) | at
   at := @program
   repeat while wordat(at) < lineno
      at += 3 + strsize(at+2)
   return at

pri insertline | lineno, fc, loc, locat, newlen, oldlen
   lineno := parseliteral
   if lineno < 0 or lineno => 65535
      abort @ln
   tokenize
   fc := spaces
   loc := findline(lineno)
   locat := wordat(loc)
   newlen := 3 + strsize(tp)
   if locat == lineno
      oldlen := 3 + strsize(loc+2)
      if fc == 0
         movprog(loc+oldlen, -oldlen)
      else
         movprog(loc+oldlen, newlen-oldlen)
   elseif fc
      movprog(loc, newlen)
   if fc
      byte[loc] := lineno >> 8
      byte[loc+1] := lineno
      bytemove(loc+2, tp, newlen-2)

pri clearvars
   sp := 0
   nextlineloc := @program
   bytefill(@vars, 0, 26)

pri clearall
   program := program[1] := 255
   eop := @program+2
   clearvars

pri pushstack
   if sp => constant(maxstack-1)
      abort string("RECURSION ERROR")
   stack[sp++] := nextlineloc

pri factor | tok, t
   tok := spaces
   if tok == "("
      tp++
      t := expr
      if spaces <> ")"
         abort @syn
      tp++
      return t
   elseif isvar(tok)
      tp++
      return vars[fixvar(tok)]
   elseif tok == 139
      tp++
      return (rv? >> 1) ** (factor << 1)
   elseif tok == "-"
      tp++
      return - factor
   elseif tok => "0" and tok =< "9"
      return parseliteral
   else
      abort(@syn)

pri term | tok, t
   t := factor
   repeat
      tok := spaces
      if tok == "*"
         tp++
         t *= factor
      elseif tok == "/"
         tp++
         t /= factor
      else
         return t

pri expr | tok, t
   t := term
   repeat
      tok := spaces
      if tok == "+"
         tp++
         t += term
      elseif tok == "-"
         tp++
         t -= term
      else
         return t

pri texec | ht, nt, a, b, c, op, restart
   restart := 1
   repeat while restart
      restart := 0
      ht := spaces
      if ht == 0
         return
      nt := skipspaces
      if isvar(ht) and nt == "="
         tp++
         vars[fixvar(ht)] := expr
      elseif ht => 128
         case ht
            128: ' if
               a := expr
               op := 0
               spaces
               repeat
                  c := byte[tp]
                  case c
                     "<": op |= 1
                          tp++
                     ">": op |= 2
                          tp++
                     "=": op |= 4
                          tp++
                     other: quit
               if c == 0 or c == 7
                  abort string("MISSING < > <= >= <> =")
               b := expr
               case op
                  1: a := a < b
                  2: a := a > b 
                  3: a := a <> b
                  4: a := a == b
                  5: a := a => b
                  6: a := a =< b
               if (not a)
                  return
               if spaces <> 129
                  abort string("MISSING THEN")
               skipspaces
               restart := 1
            130: ' input
               if not isvar(nt)
                  abort string(@syn)
               getline
               tokenize
               vars[fixvar(nt)] := expr
            131: ' print
               repeat
                  nt := spaces
                  if nt == 0
                     quit
                  if nt == 34
                     tp++
                     repeat
                        c := byte[tp++]
                        if c == 0 or c == 34
                           quit
                        bputc(c)
                  else
                     putint(expr)
                  nt := spaces
                  if nt == ";"
                     tp++
                  elseif nt == ","
                     bputc(" ")
                     repeat while screenpos & 7
                        bputc(" ")
                     tp++
                  elseif nt == 0
                     bputc(13)
                     quit
                  else
                     abort @syn
            132, 133: ' goto. gosub
               a := expr
               if a < 0 or a => 65535
                  abort @ln
               b := findline(a)
               if wordat(b) <> a
                  abort @ln
               if ht == 133
                  pushstack
               nextlineloc := b 
            134: ' return
               if sp == 0
                  abort string("INVALID RETURN")
               nextlineloc := stack[--sp]
            136: ' new
               clearall
            137: ' list
               a := @program
               repeat while a+2 < eop
                  putint(wordat(a))
                  bputc(" ")
                  putlinet(a+2)
                  a += 3 + strsize(a+2)
            138: ' run
                  clearvars
            129, 139: ' then, rnd
               abort(@syn)
      else
         abort(@syn)

pri bexec
   tokenize
   if spaces
      texec

pri repl | err
   clearall
   repeat
      err := \doline
      if err
         if curlineno => 0
            bputs(string("IN LINE "))
            putint(curlineno)
            bputc(" ")
         putlinet(err)
         nextlineloc := eop - 2         

pri doline | c
   curlineno := -1
   if keys.gotkey
      nextlineloc := eop-2
   if nextlineloc < eop-2
      curlineno := wordat(nextlineloc)
      tp := nextlineloc + 2
      nextlineloc := tp + strsize(tp) + 1
      texec
   else
      putlinet(string("OK"))
      getline
      c := spaces
      if "0" =< c and c =< "9"
         insertline
         nextlineloc := eop - 2
      else
         bexec      

pub start
   tvterm.start(24)
   keys.start(2)
   putlinet(string("EXTENDED COLOR BASIC 1.0"))
   putlinet(string("COPYRIGHT (C) 1980 BY TANDY"))
   putlinet(string("UNDER LICENSE FROM MICROSOFT"))
   bputc(13)
   repl