' //////////////////////////////////////////////////////////////////////
' Keyboard Demo - This demo allows keys to be pressed and echoes them to
' the screen.
' 
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 1.6.06
' VERSION 1.0
' COMMENTS: 
'
' CONTROLS: keyboard
' ESC - Clear Screen
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal1 + pll8x              ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000          ' set frequency to 10 MHZ plus some error
  _stack = ($2400 + $2400 + $100) >> 2  ' accomodate display memory and stack

  ' graphics driver and screen constants
  PARAMCOUNT        = 14        

  OFFSCREEN_BUFFER  = $3800             ' offscreen buffer
  ONSCREEN_BUFFER   = $5C00             ' onscreen buffer

  ' size of graphics tile map
  X_TILES           = 12
  Y_TILES           = 12
  
  SCREEN_WIDTH      = 192
  SCREEN_HEIGHT     = 192 

  BYTES_PER_LINE    = (192/4)

  KEYCODE_ESC       = $CB
  KEYCODE_ENTER     = $0D
  KEYCODE_BACKSPACE = $C8

'///////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

VAR

  long  tv_status     '0/1/2 = off/visible/invisible           read-only
  long  tv_enable     '0/? = off/on                            write-only
  long  tv_pins       '%ppmmm = pins                           write-only
  long  tv_mode       '%ccinp = chroma,interlace,ntsc/pal,swap write-only
  long  tv_screen     'pointer to screen (words)               write-only
  long  tv_colors     'pointer to colors (longs)               write-only               
  long  tv_hc         'horizontal cells                        write-only
  long  tv_vc         'vertical cells                          write-only
  long  tv_hx         'horizontal cell expansion               write-only
  long  tv_vx         'vertical cell expansion                 write-only
  long  tv_ho         'horizontal offset                       write-only
  long  tv_vo         'vertical offset                         write-only
  long  tv_broadcast  'broadcast frequency (Hz)                write-only
  long  tv_auralcog   'aural fm cog                            write-only

  word  screen[x_tiles * y_tiles] ' storage for screen tile map
  long  colors[64]                ' color look up table

  ' string/key stuff
  byte sbuffer[9]
  byte curr_key
  byte temp_key 
  long data

  ' terminal vars
  long row, column
 
  ' counter vars
  long curr_cnt, end_cnt

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

  tv    : "tv_drv_010.spin"          ' instantiate a tv object
  gr    : "graphics_drv_010.spin"    ' instantiate a graphics object
  key   : "keyboard_iso_010.spin"    ' instantiate a keyboard object       

'///////////////////////////////////////////////////////////////////////
' EXPORT PUBLICS  //////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB start | i, j, base, base2, dx, dy, x, y, x2, y2, last_cos, last_sin

'///////////////////////////////////////////////////////////////////////
 ' GLOBAL INITIALIZATION ///////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

  'start keyboard on pingroup 3 
  key.start(3)

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  'init colors
  repeat i from 0 to 64
    colors[i] := $00001010 * (i+4) & $F + $FB060C02

  'init tile screen
  repeat dx from 0 to tv_hc - 1
    repeat dy from 0 to tv_vc - 1
      screen[dy * tv_hc + dx] := onscreen_buffer >> 6 + dy + dx * tv_vc + ((dy & $3F) << 10)

  'start and setup graphics
  gr.start
  gr.setup(X_TILES, Y_TILES, SCREEN_WIDTH/2, SCREEN_HEIGHT/2, onscreen_buffer)

  ' initialize terminal cursor position
  column :=0
  row := 0

  ' put up title screen
  ' set text mode
  gr.textmode(2,1,5,3)
  gr.colorwidth(1,0)
  gr.text(-SCREEN_WIDTH/2,SCREEN_HEIGHT/2 - 16, @title_string)
  gr.colorwidth(3,0)
  gr.plot(-192/2, 192/2 - 16)
  gr.line(192/2,  192/2 - 16)
  gr.colorwidth(2,0)

 ' BEGIN GAME LOOP ////////////////////////////////////////////////////
  repeat 
   
    ' get key    
    if (key.gotkey==TRUE)
      curr_key := key.getkey
      'print character to screen
      Print_To_Term(curr_key)
    else ' gotkey 
      curr_key := 0      

' ////////////////////////////////////////////////////////////////////

PUB Print_To_Term(char_code)
' prints sent character to terminal or performs control code
' supports, line wrap, and return, esc clears screen      

' test for new line
  if (char_code == KEYCODE_ENTER)
    column :=0             
    if (++row > 13)    
      row := 13
  elseif (char_code == KEYCODE_ESC)
    gr.clear
    gr.textmode(2,1,5,3)
    gr.colorwidth(1,0)
    gr.text(-SCREEN_WIDTH/2,SCREEN_HEIGHT/2 - 16, @title_string)
    gr.colorwidth(3,0)
    gr.plot(-SCREEN_WIDTH/2, SCREEN_HEIGHT/2 - 16)
    gr.line(SCREEN_WIDTH/2,  SCREEN_HEIGHT/2 - 16)
    gr.colorwidth(2,0)
    column := row := 0
  else ' not a carriage return
    ' set the printing buffer up 
    sbuffer[0] := char_code
    sbuffer[1] := 0
    gr.text(-SCREEN_WIDTH/2 + column*12,SCREEN_HEIGHT/2 - 32 - row*12, @sbuffer)

    ' test for text wrapping and new line
    if (++column > 15)
      column := 0
      if (++row > 13)    
        row := 13
        ' scroll text window

'///////////////////////////////////////////////////////////////////////
' DATA SECTION /////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

DAT

' TV PARAMETERS FOR DRIVER /////////////////////////////////////////////

tvparams
                long    0               'status
                long    1               'enable
                long    %011_0000       'pins
                long    %0000           'mode
                long    0               'screen
                long    0               'colors
                long    x_tiles         'hc
                long    y_tiles         'vc
                long    10              'hx timing stretch
                long    1               'vx
                long    0               'ho
                long    0               'vo
                long    55_250_000      'broadcast
                long    0               'auralcog

' STRING STORAGE //////////////////////////////////////////////////////

title_string    byte    "Hydra Keyboard Demo",0         'text
blank_string    byte    "        ",0

'///////////////////////////////////////////////////////////////////////
' WORK AREA SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////