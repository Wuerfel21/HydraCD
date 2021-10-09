' //////////////////////////////////////////////////////////////////////
' HYDRA NET CLIENT PROGRAM 
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 1.12.06
' VERSION 1.1
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

  _clkmode = xtal1 + pll4x              ' enable external clock and pll times 4
  _xinfreq = 10_000_000 + 0000          ' set frequency to 10 MHZ plus some error
  _stack = ($2400 + $2400 + $100) >> 2  'accomodate display memory and stack

  ' graphics driver and screen constants
  PARAMCOUNT        = 14        

  OFFSCREEN_BUFFER  = $3800           ' offscreen buffer
  ONSCREEN_BUFFER   = $5C00           ' onscreen buffer

  ' size of graphics tile map
  X_TILES           = 12
  Y_TILES           = 12
  
  SCREEN_WIDTH      = 192
  SCREEN_HEIGHT     = 192 

  BYTES_PER_LINE    = (192/4)

  CLOCKS_PER_BIT = 8_000 ' number of system clocks per data bit

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

  ' random stuff
  byte random_counter

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
  key   : "keyboard_iso_010.spin"  ' instantiate a keyboard object       

'///////////////////////////////////////////////////////////////////////
' EXPORT PUBLICS  //////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB start | i, j, base, base2, dx, dy, x, y, x2, y2, last_cos, last_sin

'///////////////////////////////////////////////////////////////////////
 ' GLOBAL INITIALIZATION ///////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

  'start keyboard on pingroup 
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
  gr.setup(12, 12, 96, 96, onscreen_buffer)

  ' initialize terminal cursor position
  column :=0
  row := 0

 ' BEGIN GAME LOOP ////////////////////////////////////////////////////

  ' put up title screen
  ' set text mode
  gr.textmode(2,1,5,3)
  gr.colorwidth(1,0)
  gr.text(-SCREEN_WIDTH/2,SCREEN_HEIGHT/2 - 16, @parallax_string)
  gr.colorwidth(3,0)
  gr.plot(-192/2, 192/2 - 16)
  gr.line(192/2,  192/2 - 16)
  gr.colorwidth(2,0)

  ' say hello
  Send_Data_Hydra_Net($2E, 8, CLOCKS_PER_BIT)

  repeat 
    
    'Receive_Data_Hydra_Net(8, CLOCKS_PER_BIT)
    
    ' get key    
    if (key.gotkey==-1)
      curr_key := key.getkey
      Send_Data_Hydra_Net(curr_key, 8, CLOCKS_PER_BIT)
      'print character to screen
      Print_To_Term(curr_key)
    else ' gotkey 
      curr_key := 0      


'    data := INA
    ' print data
'    sbuffer[0] := hex_table[ (data & $F000) >> 12 ] 
'    gr.text(-SCREEN_WIDTH/2,SCREEN_HEIGHT/2 - 32, @blank_string)
'    sbuffer[1] := hex_table[ (data & $0F00) >> 8 ]
'    sbuffer[2] := hex_table[ (data & $00F0) >> 4 ] 
'    sbuffer[3] := hex_table[ (data & $000F) >> 0]
'    sbuffer[4] := 0
'    gr.text(-SCREEN_WIDTH/2,SCREEN_HEIGHT/2 - 32, @sbuffer)
    ' end print data


' ////////////////////////////////////////////////////////////////////

PUB Print_To_Term(char_code)
' prints sent character to terminal or performs control code      

' test for new line
  if (char_code == KEYCODE_ENTER)
    column :=0             
    if (++row > 13)    
      row := 13
  elseif (char_code == KEYCODE_ESC)
    gr.clear
    gr.textmode(2,1,5,3)
    gr.colorwidth(1,0)
    gr.text(-SCREEN_WIDTH/2,SCREEN_HEIGHT/2 - 16, @parallax_string)
    gr.colorwidth(3,0)
    gr.plot(-192/2, 192/2 - 16)
    gr.line(192/2,  192/2 - 16)
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

' ////////////////////////////////////////////////////////////////////

PUB Rand : retval
  random_counter := (1 + random_counter ^ random_counter << 6 ^ random_counter << 2 ^ random_counter << 7)
  retval := random_counter

' ////////////////////////////////////////////////////////////////////

PUB Delay (count)      | i, x, y, z
  ' delay count times inner loop length
  repeat  i from  0 to count

' ////////////////////////////////////////////////////////////////////

PUB Plot_Pixel(x, y, video_buffer, color)              | video_offset, pixel_value
  ' plot pixel calculation
  video_offset := video_buffer + (x >> 4) * (192*4) + ((x & %1111) >> 2) + (y << 2)
  BYTEMOVE(@pixel_value,video_offset,1)
  pixel_value := pixel_value | (color << ((x & %11) << 1))
  BYTEFILL(video_offset, pixel_value, 1)

' /////////////////////////////////////////////////////////////////////

PUB Send_Data_Hydra_Net(data_packet, num_bits, clks_bit)               |  curr_bit

' data_packet -  32-bit that holds the data in the lower n bitxs, 8, 16, or 24 bits
'         only 8 bits supported for now to maintain synchronization with receiver
' num_bits - number of bits to send, for now assumes 8 always 
' trans_rate - the number of clocks to send each bit
' 
' this function sends 8-bits out on the hydra net
' Hydra Net Serial Protocal for 8 bits
' START | Bit 0  | Bit 1 | Bit 2 | Bit 3 | Bit 4 | Bit 5 | Bit 6 | Bit 7 | Bit 8 |  STOP
'   0      x        x       x       x       x       x       x       x       x        1

' for now, send 8 bits of data, and 1 start and 1 stop bit, later move to 16-bits of data
' the tranmission protocal is simple, the data word is shifted to the left in place and then
' framed up with a leading 0 start bit, and a tailing 1 stop bit, then the loop runs 10 iterations
' and sends the data out at the desired rate

  ' set up transmission direction on pin p2
  DIRA [ 2 ] := 1 ' set to output for TX pin of Hydra Net

  ' build data packet frame between "1"...."0"
  data_packet := (data_packet << 1) | %1_00000000_0

  ' get current count to prepare for loop

  end_cnt := CNT + clks_bit

  ' send data out of the LSB
  repeat curr_bit from 0 to 9
    ' begin transmission loop ----------------------------

    ' send out LSB
    OUTA[2] := data_packet & %0000000001

    ' shift data packet to right
    data_packet := data_packet >> 1
    
    ' wait for counter to reach this count      
    waitcnt(end_cnt)            

    ' update end count for next iteration
    end_cnt += clks_bit 
    ' end transmission loop ------------------------------


' /////////////////////////////////////////////////////////////////////

PUB Receive_Data_Hydra_Net(num_bits, clks_bit) : data_packet           |  curr_bit

' data_packet -  32-bit that holds the received data in the lower n bits, 8, 16, or 24 bits
'         only 8 bits supported for now to maintain synchronization with receiver
' num_bits - number of bits to receive, for now assumes 8 always 
' trans_rate - the number of clocks to receive each bit
' 
' this function sends 8-bits out on the hydra net
' Hydra Net Serial Protocal for 8 bits
' START | Bit 0  | Bit 1 | Bit 2 | Bit 3 | Bit 4 | Bit 5 | Bit 6 | Bit 7 | Bit 8 |  STOP
'   0      x        x       x       x       x       x       x       x       x        1

' for now, receive 8 bits of data, and 1 start and 1 stop bit, later move to 16-bits of data
' the tranmission protocal is simple, the data word is read in and shifted to the right in place and then
' framed up with a leading 0 start bit, and a tailing 1 stop bit

  ' set up receiver direction on pin p1
  DIRA[1] := 0 ' set to input for RX pin of Hydra Net

  ' reset data packet
  data_packet := 0 

  Print_To_Term($41)

  ' wait for falling edge to signify start bit
  repeat 
    data_packet := 0
      Print_To_Term(INA[1]+$30)
  while (INA[1] == 1)

  Print_To_Term($43)

  ' get current count to prepare for loop
  end_cnt := CNT + (clks_bit >> 1)

  ' send data out of the LSB
  repeat curr_bit from 0 to 9
    ' begin reception loop ----------------------------

    ' wait for counter to reach midway count of bit frame
    waitcnt(end_cnt)            

    ' update end count for next iteration
    end_cnt += (clks_bit >> 1)

    ' get next bit in place into 10th bit and shift right
    data_packet |= (INA[1] << 10)

    ' shift data packet to right
    data_packet := data_packet >> 1
    
    ' wait for counter to reach end of bit frame
    waitcnt(end_cnt)            

    ' update end count for next iteration
    end_cnt += (clks_bit >> 1)
    ' end reception loop ------------------------------

    ' at this point we should have 1_XXXXXXXX_0
    '                              |          |
    '                            stop       start
    ' verify the start and stop bits, if they are correct
    ' then return the data byte, else return -1
    if ( (data_packet & 1_00000000_1) == 1_00000000_0)
      data_packet := ((data_packet >> 1) & %11111111)
    else
      data_packet := -1

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

hex_table               byte    "0123456789ABCDEF"
parallax_string         byte    "Hydra-Net SEND v1.1",0         'text
blank_string            byte    "        ",0
'///////////////////////////////////////////////////////////////////////
' WORK AREA SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////