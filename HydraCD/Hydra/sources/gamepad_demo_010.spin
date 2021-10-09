' //////////////////////////////////////////////////////////////////////
' Nintendo Gamepad Demo Program - Reads the nintendo gamepads and prints
' the state out on the screen, reads both gamepads at once into a 16-bit
' vector, each gamepad is encoded as 8-bits in the following format:

' RIGHT  = %00000001 (lsb)
' LEFT   = %00000010
' DOWN   = %00000100
' UP     = %00001000
' START  = %00010000
' SELECT = %00100000
' B      = %01000000
' A      = %10000000 (msb)
'
' Gamepad 0 is the left gamepad, gamepad 1 is the right game pad
' 
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 1.07.06
' VERSION 1.0
' COMMENTS: Use gamepads, note that when a controller is NOT pluggedin
' the value returned is $FF, this can be used to "detect" if the game
' controller is present or not.
'
' //////////////////////////////////////////////////////////////////////


'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal1 + pll8x              ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000          ' set frequency to 10 MHZ plus some error
  _stack = ($3000 + $3000 + 64) >> 2    ' accomodate display memory and stack

  ' graphics driver and screen constants
  PARAMCOUNT        = 14        
  OFFSCREEN_BUFFER  = $2000           ' offscreen buffer
  ONSCREEN_BUFFER   = $5000           ' onscreen buffer

  ' size of graphics tile map
  X_TILES           = 16
  Y_TILES           = 12

  ' size of screen  
  SCREEN_WIDTH      = 256
  SCREEN_HEIGHT     = 192 

  ' position of state readouts for the left and right gamepads
  GAMEPAD0_TEXT_X0 = 10
  GAMEPAD0_TEXT_Y0 = 172

  GAMEPAD1_TEXT_X0 = 128
  GAMEPAD1_TEXT_Y0 = 172 


  ' NES bit encodings
  NES_RIGHT  = %00000001
  NES_LEFT   = %00000010
  NES_DOWN   = %00000100
  NES_UP     = %00001000
  NES_START  = %00010000
  NES_SELECT = %00100000
  NES_B      = %01000000
  NES_A      = %10000000

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
  long data

  ' nes gamepad vars
  long nes_buttons

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

  tv    : "tv_drv_010.spin"        ' instantiate a tv object
  gr    : "graphics_drv_010.spin"  ' instantiate a graphics object

'///////////////////////////////////////////////////////////////////////
' EXPORT PUBLICS  //////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB start | i, j, base, base2, dx, dy, x, y, x2, y2, mask

'///////////////////////////////////////////////////////////////////////
 ' GLOBAL INITIALIZATION ///////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

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
  gr.setup(16, 12,0,0, offscreen_buffer)

 ' BEGIN GAME LOOP ////////////////////////////////////////////////////

  repeat 
    'clear bitmap
    gr.clear

    ' INPUT SECTION //////////////////////////////////////////////////////

    ' get nes controller buttons (right stick)
    nes_buttons := NES_Read_Gamepad

    ' END INPUT SECTION ///////////////////////////////////////////////////

 
    ' RENDERING SECTION ////////////////////////////////////////////////////

    'draw text
    gr.textmode(2,1,5,3)

    ' print out total gamepad states vector as 2 hex digits each
    ' each controller printing could be merged into a single loop, but
    ' too confusing, rather be long and legible than too clever!

    ' gamepad 0 first, lower 8-bits /////////////////////////////////////////
    gr.colorwidth(2,0)
    gr.text(GAMEPAD0_TEXT_X0,GAMEPAD0_TEXT_Y0, @gamepad0_string)

    ' insert the hex digits right into output string!
    bits_string[5] := hex_table[ (nes_buttons & $00F0) >> 4 ] 
    bits_string[6] := hex_table[ (nes_buttons & $000F) >> 0]
    gr.colorwidth(1,0)
    gr.text(GAMEPAD0_TEXT_X0,GAMEPAD0_TEXT_Y0-12, @bits_string)

    ' print of gamepad is plugged in?
    if (( nes_buttons & $00FF) <> $00FF)
      gr.colorwidth(1,0)
      gr.text(GAMEPAD0_TEXT_X0,GAMEPAD1_TEXT_Y0-12*2, @plugged_string)
    else
      gr.colorwidth(3,0)
      gr.text(GAMEPAD0_TEXT_X0,GAMEPAD1_TEXT_Y0-12*2, @unplugged_string)

    gr.colorwidth(2,0)
    gr.text(GAMEPAD0_TEXT_X0,GAMEPAD0_TEXT_Y0, @gamepad0_string)

    ' print out the button states in unencoded strings
    ' step one extract the bit for each button and insert it into
    ' the display strings "in place" then we just print the strings
    ' out!
    mask := $01
    repeat i from 0 to 7
      ' test if button is down represented by the bit in mask
      ' updated the 6th character in the next description string with a "0" or "1",
      ' each string is fixed length, so we can look at the bit and then index into
      ' the strings and update the character in place and then print them all out
      gr.colorwidth(2,0)

      ' test for bit set or not, update string with ASCII "1" or "0"
      if (mask & nes_buttons)
        button_string_start_address[i*9+7] := $31
      else
        button_string_start_address[i*9+7] := $30

      ' print the string out with the embedded "1" or "0"
      gr.text(GAMEPAD0_TEXT_X0,GAMEPAD0_TEXT_Y0-12*i-40, @button_string_start_address + 9*i)

      ' move to next bit
      mask := mask << 1
      ' end repeat loop
 
    ' gamepad 1 next, upper 8-bits ///////////////////////////////////////
    gr.colorwidth(2,0)
    gr.text(GAMEPAD1_TEXT_X0,GAMEPAD1_TEXT_Y0, @gamepad1_string)

    ' insert the hex digits right into output string!
    bits_string[5] := hex_table[ (nes_buttons & $F000) >> 12 ] 
    bits_string[6] := hex_table[ (nes_buttons & $0F00) >> 8 ]
    gr.colorwidth(1,0)
    gr.text(GAMEPAD1_TEXT_X0,GAMEPAD1_TEXT_Y0-12, @bits_string)
    ' end print data
  
    ' print of gamepad is plugged in?
    if (( nes_buttons & $FF00) <> $FF00)
      gr.colorwidth(1,0)
      gr.text(GAMEPAD1_TEXT_X0,GAMEPAD1_TEXT_Y0-12*2, @plugged_string)
    else
      gr.colorwidth(3,0)
      gr.text(GAMEPAD1_TEXT_X0,GAMEPAD1_TEXT_Y0-12*2, @unplugged_string)

    ' print out the button states in unencoded strings
    ' step one extract the bit for each button and insert it into
    ' the display strings "in place" then we just print the strings
    ' out!
    mask := $0100
    repeat i from 0 to 7
      ' test if button is down represented by the bit in mask
      ' updated the 6th character in the next description string with a "0" or "1",
      ' each string is fixed length, so we can look at the bit and then index into
      ' the strings and update the character in place and then print them all out
      gr.colorwidth(2,0)

      ' test for bit set or not, update string with ASCII "1" or "0"
      if (mask & nes_buttons)
        button_string_start_address[i*9+7] := $31
      else
        button_string_start_address[i*9+7] := $30

      ' print the string out with the embedded "1" or "0"
      gr.text(GAMEPAD1_TEXT_X0,GAMEPAD0_TEXT_Y0-12*i-40, @button_string_start_address + 9*i)

      ' move to next bit
      mask := mask << 1
      ' end repeat loop
     
    'copy bitmap to display
    gr.copy(onscreen_buffer)

    ' END RENDERING SECTION ///////////////////////////////////////////////

  ' END MAIN GAME LOOP REPEAT BLOCK //////////////////////////////////

' ////////////////////////////////////////////////////////////////////

PUB NES_Read_Gamepad : nes_bits        |  i

' //////////////////////////////////////////////////////////////////
' NES Game Paddle Read
' //////////////////////////////////////////////////////////////////       
' reads both gamepads in parallel encodes 8-bits for each in format
' right game pad #1 [15..8] : left game pad #0 [7..0]
'
' set I/O ports to proper direction
' P3 = JOY_CLK      (4)
' P4 = JOY_SH/LDn   (5) 
' P5 = JOY_DATAOUT0 (6)
' P6 = JOY_DATAOUT1 (7)
' NES Bit Encoding
'
' RIGHT  = %00000001
' LEFT   = %00000010
' DOWN   = %00000100
' UP     = %00001000
' START  = %00010000
' SELECT = %00100000
' B      = %01000000
' A      = %10000000

' step 1: set I/Os
DIRA [3] := 1 ' output
DIRA [4] := 1 ' output
DIRA [5] := 0 ' input
DIRA [6] := 0 ' input

' step 2: set clock and latch to 0
OUTA [3] := 0 ' JOY_CLK = 0
OUTA [4] := 0 ' JOY_SH/LDn = 0
'Delay(1)

' step 3: set latch to 1
OUTA [4] := 1 ' JOY_SH/LDn = 1
'Delay(1)

' step 4: set latch to 0
OUTA [4] := 0 ' JOY_SH/LDn = 0

' step 5: read first bit of each game pad

' data is now ready to shift out
' first bit is ready 
nes_bits := 0

' left controller
nes_bits := INA[5] | (INA[6] << 8)

' step 7: read next 7 bits
repeat i from 0 to 6
 OUTA [3] := 1 ' JOY_CLK = 1
 'Delay(1)             
 OUTA [3] := 0 ' JOY_CLK = 0
 nes_bits := (nes_bits << 1)
 nes_bits := nes_bits | INA[5] | (INA[6] << 8)

 'Delay(1)             
' invert bits to make positive logic
nes_bits := (!nes_bits & $FFFF)

' //////////////////////////////////////////////////////////////////
' End NES Game Paddle Read
' //////////////////////////////////////////////////////////////////       

' ////////////////////////////////////////////////////////////////////

PUB Delay (count)      | i, x, y, z
  ' delay count times inner loop length
  repeat  i from  0 to count

'///////////////////////////////////////////////////////////////////////
' DATA SECTION /////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

DAT

' TV PARAMETERS FOR DRIVER /////////////////////////////////////////////

tvparams                long    0               'status
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

hex_table              byte "0123456789ABCDEF"
gamepad0_string        byte "Gamepad 0:",0         'text
gamepad1_string        byte "Gamepad 1:",0         'text
bits_string            byte "Bits:  ",0
plugged_string         byte "Plugged",0
unplugged_string       byte "Unplugged",0


button_string_start_address
RIGHT_button_string    byte "Right:  ",0 
LEFT_button_string     byte "Left:   ",0
DOWN_button_string     byte "Down:   ",0
UP_button_string       byte "Up:     ",0
START_button_string    byte "Start:  ",0
SELECT_button_string   byte "Select: ",0
B_button_string        byte "B:      ",0
A_button_string        byte "A:      ",0


'///////////////////////////////////////////////////////////////////////
' WORK AREA SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////