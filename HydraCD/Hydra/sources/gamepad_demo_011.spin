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
' LAST MODIFIED: 2.09.06
' VERSION 1.1
' COMMENTS: Use gamepads, note that when a controller is NOT pluggedin
' the value returned is $FF, this can be used to "detect" if the game
' controller is present or not.
' 
' ASM version driver
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

  ' button ids/bit masks
  ' NES bit encodings general for state bits
  NES_RIGHT  = %00000001
  NES_LEFT   = %00000010
  NES_DOWN   = %00000100
  NES_UP     = %00001000
  NES_START  = %00010000
  NES_SELECT = %00100000
  NES_B      = %01000000
  NES_A      = %10000000

  ' NES bit encodings for NES gamepad 0
  NES0_RIGHT  = %00000000_00000001
  NES0_LEFT   = %00000000_00000010
  NES0_DOWN   = %00000000_00000100
  NES0_UP     = %00000000_00001000
  NES0_START  = %00000000_00010000
  NES0_SELECT = %00000000_00100000
  NES0_B      = %00000000_01000000
  NES0_A      = %00000000_10000000

  ' NES bit encodings for NES gamepad 1
  NES1_RIGHT  = %00000001_00000000
  NES1_LEFT   = %00000010_00000000
  NES1_DOWN   = %00000100_00000000
  NES1_UP     = %00001000_00000000
  NES1_START  = %00010000_00000000
  NES1_SELECT = %00100000_00000000
  NES1_B      = %01000000_00000000
  NES1_A      = %10000000_00000000

  ' debug LED port bit mask
  DEBUG_LED_PORT_MASK = $00000001 ' debug LED is on I/O P0
            

'///////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

VAR


 
  ' tv parameters
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

  ' glowing rate
  long glow_rate

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

  tv    : "tv_drv_010.spin"        ' instantiate a tv object
  gr    : "graphics_drv_010.spin"  ' instantiate a graphics object
  glow  : "glow_led_001.spin"      ' glowing led driver
  gp    : "gamepad_drv_001.spin"   ' gamepad driver
  
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


  ' start up driver to read gamepads
  ' pass parameter base address, in this case only one parameter which is where
  ' to store the buttons

  glow_rate := $800
  glow.start(@glow_rate)

' direct inline asm call
' cognew(@asm_glow_led_entry, @glow_rate)

  ' cognew(@NES_Read_Gamepad_ASM_Entry, @nes_buttons)
  ' start NES game pad task to read gamepad values
  gp.start

 ' BEGIN GAME LOOP ////////////////////////////////////////////////////////////

  repeat 
    'clear bitmap
    gr.clear

    ' INPUT SECTION //////////////////////////////////////////////////////

    ' get nes controller button
    nes_buttons := gp.read                                 

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

' data is now ready to shift out, clear storage
nes_bits := 0

' step 5: read 8 bits, 1st bits are already latched and ready, simply save and clock remaining bits
repeat i from 0 to 7

 nes_bits := (nes_bits << 1)
 nes_bits := nes_bits | INA[5] | (INA[6] << 8)

 OUTA [3] := 1 ' JOY_CLK = 1
 'Delay(1)             
 OUTA [3] := 0 ' JOY_CLK = 0
 
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
' ASM AREA  ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON
                      
  IO_JOY_CLK       = %00001000    
  IO_JOY_SHLDn     = %00010000    
  IO_JOY_DATAOUT0  = %00100000    
  IO_JOY_DATAOUT1  = %01000000    
  NES_LATCH_DELAY  = $40

DAT


' //////////////////////////////////////////////////////////////////
' NES Game Paddle Read ASM Version Reads Continuously
' //////////////////////////////////////////////////////////////////       
' reads both gamepads in parallel encodes 8-bits for each in format
' right game pad #1 [15..8] : left game pad #0 [7..0]
' results are constantly written to ->PAR as a LONG
' call with something like
' cognew(@NES_Read_Gamepad_ASM_Entry, @nes_buttons)
' where "nes_buttons" is where you want the results to be stored from the
' continuous scanning of the gamepads
'
' set I/O ports to proper direction

' P3 = JOY_CLK      (pin 4) / output
' P4 = JOY_SH/LDn   (pin 5) / output
' P5 = JOY_DATAOUT0 (pin 6) / input
' P6 = JOY_DATAOUT1 (pin 7) / input

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

        org $000

' inline asm entry point
NES_Read_Gamepad_ASM_Entry

        ' step 1: set I/Os, 
        or  DIRA, #(IO_JOY_CLK | IO_JOY_SHLDn)          ' JOY_CLK and JOY_SH/LDn to outputs
        and DIRA, #(!(IO_JOY_DATAOUT0 | IO_JOY_DATAOUT1)) & $1FF ' JOY_DATAOUT0 and JOY_DATAOUT1 to inputs
        
NES_Latchbits

        ' step 2: set latch and clock to 0
        and OUTA, #(!(IO_JOY_CLK | IO_JOY_SHLDn)) & $1FF ' JOY_CLK = 0, JOY_SH/LDn = 0

        ' initialize counter and delay to let NES settle
        mov _counter, CNT
        add _counter, #NES_LATCH_DELAY
        waitcnt _counter, #NES_LATCH_DELAY
        
        ' step 3: set latch to 1
        or OUTA, #(IO_JOY_SHLDn) ' JOY_SH/LDn = 1

        ' initialize counter and delay to let NES settle
        mov _counter, CNT
        add _counter, #NES_LATCH_DELAY
        waitcnt _counter, #NES_LATCH_DELAY
                                     
        ' step 4: set latch to 0
        and OUTA,#(!(IO_JOY_SHLDn)) & $1FF ' JOY_SH/LDn = 0

        ' clear gamepad storage word
        xor _nes_bits, _nes_bits

        ' step 5: read 8 bits, 1st bits are already latched and ready, simply save and clock remaining bits
        mov _index, #8

NES_Getbits_Loop

        shl _nes_bits, #$1 '             ' shift results 1 bit to the left each time
        
        mov _nes_gamepad0, INA           ' read all 32-bits of input including gamepads
        mov _nes_gamepad1, _nes_gamepad0 ' copy all 32-bits of input including gamepads

        ' the next 6 instructions could also be done with a test, mask, write, but this is cleaner and executes in the same amount
        ' of time always
        ' now extract bits from inputs
        and _nes_gamepad0, #(IO_JOY_DATAOUT0)
        and _nes_gamepad1, #(IO_JOY_DATAOUT1)

        ' shift bits into place, so that gamepad0 bits fall into bit 0 of 16-bit result and gamepad1 bits fall into bit 8 of 16-bit result
        ' then continuously shift the entire result until every buttons has been shifted into position from both gamepads
        shr _nes_gamepad0, #5
        shl _nes_gamepad1, #2

        ' finally OR results into accumulating result/sum
        or _nes_bits, _nes_gamepad0
        or _nes_bits, _nes_gamepad1

        ' pulse clock...
        or OUTA, #%00001000 ' JOY_CLK = 1

        ' initialize counter and delay to let NES settle
        mov _counter, CNT
        add _counter, #NES_LATCH_DELAY
        waitcnt _counter, #NES_LATCH_DELAY
        
        and OUTA,#%11110111 ' JOY_CLK = 0

        ' initialize counter and delay to let NES settle
        mov _counter, CNT
        add _counter, #NES_LATCH_DELAY
        waitcnt _counter, #NES_LATCH_DELAY

        djnz _index, #NES_Getbits_Loop
        ' END NES_getbits_loop

        ' invert bits to make positive logic
        xor _nes_bits, _MAXINT

        ' mask lower 16-bits only
        and _nes_bits, _NES_GAMEPAD_MASK

        ' finally write results back out to caller
        wrlong _nes_bits, par ' now access main memory and write the value

        ' continue looping...
        jmp #NES_Latchbits


' VARIABLE DECLARATIONS ///////////////////////////////////////////////////////

_MAXINT                 long                    $ffff_ffff                      ' 32-bit maximum value constant
_NES_GAMEPAD_MASK       long                    $0000_ffff                      ' mask for NES lower 16-bits 

_nes_bits               long                    $0                              ' storage for 16 NES gamepad bits (lower 16-bits)
_nes_gamepad0           long                    $0                              ' left gamepad temp storage
_nes_gamepad1           long                    $0                              ' right gamepad temp storage
_index                  long                    $0                              ' general counter/index
_counter                long                    $0                              ' general counter