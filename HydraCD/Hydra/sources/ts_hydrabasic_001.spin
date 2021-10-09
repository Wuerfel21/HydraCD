' //////////////////////////////////////////////////////////////////////
' Hydra BASIC - The Hydra's only true bad ass language
' AUTHOR: Terry Smith
' LAST MODIFIED: 04.30.06
' VERSION 1.0
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal1 + pll8x            ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000        ' set frequency to 10 MHZ plus some error
  _stack = ($3000 + $3000 + 64) >> 2  ' accomodate display memory and stack

  ' graphics driver and screen constants
  PARAMCOUNT        = 14        
  OFFSCREEN_BUFFER  = $2000           ' offscreen buffer
  ONSCREEN_BUFFER   = $5000           ' onscreen buffer

  ' size of graphics tile map
  X_TILES           = 16
  Y_TILES           = 12
  
  SCREEN_WIDTH      = 256
  SCREEN_HEIGHT     = 192

  ' blink rate of the cursor in frames
  CURSOR_BLINK_RATE = 40

  ' important keycodes
  KEYCODE_ENTER     = $0D
  KEYCODE_BACKSPACE = $C8

  ' where does the file start in memory?
  FILE_START_LOC    = 6000 

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

  word  screen[X_TILES * Y_TILES] ' storage for screen tile map
  long  colors[64]                ' color look up table

  byte  sbuffer[12]   ' string buffer holds the starting string
  byte  ibuffer[24]   ' holds the inctructions string
  byte  tbuffer[1]    ' temporary buffer
  byte  cbuffer[1]    ' cursor buffer

  long  cursor_on     ' cursor currently on screen? (1 = yes)
  long  cursor_counter' counter for cursor blink rate
  long  cursor_decr   ' is the cursor leaving the building? (1 = yes)

  long row            ' row
  long col            ' column

  byte curr_key       ' current_key

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

OBJ
  tv    : "tv_drv_010.spin"          ' instantiate a tv object
  gr    : "graphics_drv_010.spin"    ' instantiate a graphics object
  key   : "keyboard_iso_010.spin"    ' instantiate a keyboard object

'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB start | i, dx, dy, char_counter

  ' prepare the LED (for testing purposes)
  DIRA[0] := 1

  ' set to row 0 and col 0
  row := 0
  col := 0

  ' initialize the character count to 0
  char_counter := 0

  ' init cursor variables
  cursor_on := 1
  cursor_counter := CURSOR_BLINK_RATE
  cursor_decr := 1

  'start and setup graphics 256x192, with orgin (0,0) at bottom left of screen
  gr.start
  gr.setup(X_TILES, Y_TILES, 0,0, offscreen_buffer)
  
  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  ' start the keyboard
  key.start(3)

  'init colors
  repeat i from 0 to 64
    colors[i] := $00001010 * (i+4) & $F + $FB060C02

  'init tile screen
  repeat dx from 0 to tv_hc - 1
    repeat dy from 0 to tv_vc - 1
      screen[dy * tv_hc + dx] := onscreen_buffer >> 6 + dy + dx * tv_vc + ((dy & $3F) << 10)

  ' BEGIN GAME LOOP ////////////////////////////////////////////////////

  ' set up the text mode and color information
  gr.textmode(1,1,6,3) ' scale 1x1, 6 for spacing, justification left-bottom)

  ' copy a screen worth of the static string into the working string sbuffer
  BYTEMOVE(@sbuffer, @text_string, 11)
    
  ' terminate the string
  sbuffer[11] := 0

  ' copy a screen worth of the static string into the working string sbuffer
  BYTEMOVE(@ibuffer, @instruct_string, 24)
    
  ' terminate the string
  ibuffer[24] := 0 
  
  ' infinite loop
  repeat while TRUE

    ' clear the screen
    gr.clear

    gr.colorwidth(6,0)

    ' draw the logo and instructions   
    gr.text(0, SCREEN_HEIGHT - 16, @sbuffer)

    gr.text(SCREEN_WIDTH - 144, SCREEN_HEIGHT - 16, @ibuffer)

    gr.colorwidth(3,0)
    
    gr.plot(0, SCREEN_HEIGHT - 20)
    gr.line(SCREEN_WIDTH, SCREEN_HEIGHT - 20)

    gr.colorwidth(2,0)

    ' check if there is a new key for us to handle
    if key.gotkey == true

      ' store the information and move on
      curr_key := key.getkey
      BYTE[FILE_START_LOC + char_counter] := curr_key

      ' if we have an enter key, reset the cursor
      if curr_key == KEYCODE_ENTER

        ' reset to a new row, col = 0
        row++
        col := 0

        'increment counter
        char_counter++

      ' else, if this is the backspace, go back
      if curr_key == KEYCODE_BACKSPACE

        if col > 0

          ' handle the backspace TODO: Modify to handle current position, not just last character
          Handle_Backspace(char_counter - 1, char_counter)
           
          ' move back
          col--
           
          ' move char counter
          char_counter--
        
      ' otherwise, just move the cursor
      else

        ' move over
        col++

        ' increment counter
        char_counter++ 
         
    else ' gotkey
      curr_key := 0

    ' if the cursor is active
    if cursor_on == 1
      ' copy a screen worth of the static string into the working string sbuffer
      BYTEMOVE(@cbuffer, @cursor_string, 1)
      ' terminate the string
      cbuffer[1] := 0   
       
      ' draw the cursor  
      gr.text(6 * col - 2, 192 - 40 - (16 * row), @cbuffer)

      ' if the cursor is on it's way out
      if cursor_decr == 1
        if cursor_counter == 0
          cursor_on := 0
          cursor_decr := 0
        else
          cursor_counter--

    ' the cursor is not on
    else
      if cursor_counter < CURSOR_BLINK_RATE
        cursor_counter++
      else
        cursor_on := 1
        cursor_decr := 1

    Print_Current_File(char_counter)

    ' copy the back to the front
    gr.copy(onscreen_buffer)
    
    ' RENDERING SECTION (render to offscreen buffer always//////////////

    ' END RENDERING SECTION ///////////////////////////////////////////////

  ' END MAIN GAME LOOP REPEAT BLOCK //////////////////////////////////

PUB Print_Current_File(character_counter) | curr_count, local_row, local_col, curr_char

  ' initialize row and column to 0
  local_row := 0
  local_col := 0

  curr_count := 0
  
  ' loop through all of the code and print it to the screen
  repeat while curr_count < character_counter

    ' check to see if this is a return character
    if BYTE[FILE_START_LOC + curr_count] == KEYCODE_ENTER

      ' reset to a new row and reset the column
      local_row++
      local_col := 0

    ' otherwise, print the character
    else

      ' set the current charater
      curr_char := BYTE[FILE_START_LOC + curr_count]
      curr_char[1] := 0

      ' print
      gr.text(6 * local_col, 192 - 40 - (16 * local_row), @curr_char)

      local_col++

    ' increment the counter
    curr_count++

PUB Handle_Backspace(curr_pos, character_counter) | curr_count

  ' record our current position
  curr_count := curr_pos
  
  ' loop through the list
  repeat while curr_count < character_counter

    ' move everything in the list back one
    BYTE[FILE_START_LOC + curr_count] := BYTE[FILE_START_LOC + curr_count + 1]

    curr_count++

  BYTE[FILE_START_LOC + curr_count] := 0
  

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
                        long    55_250_000      'broadcast on channel 2 VHF, each channel is 6 MHz above the previous
                        long    0               'auralcog


text_string             byte    "Hydra BASIC",0 'logo
instruct_string         byte    "F1 Save  F2 Open  F3 Run",0 'instructions
cursor_string           byte    "|",0 'cursor
                        