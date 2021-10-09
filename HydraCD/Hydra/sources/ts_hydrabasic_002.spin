' /////////////////////////////////////////////////////////////////////////////
' Hydra BASIC - The only true bad ass HYDRA language 
' VERSION: 0.2
' AUTHOR: Terry Smith (using a modified version of the HEL tile and graphics library by Andre' LaMothe)
' LAST MODIFIED: 05.07.06
' COMMENTS:
' 
' Features:
' - TODO
'
' /////////////////////////////////////////////////////////////////////////////


'//////////////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ///////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x       ' enable external clock range 5-10MHz and pll times 8
  _xinfreq = 10_000_000 + 0000   ' set frequency to 10 MHZ plus some error due to XTAL (1000-5000 usually works)
  _stack   = 128                 ' accomodate display memory and stack


  ' blink rate of the cursor in frames
  CURSOR_BLINK_RATE = 8

  ' important keycodes
  KEYCODE_ENTER     = $0D
  KEYCODE_BACKSPACE = $C8
  KEYCODE_SPACE     = $20
  KEYCODE_LEFT      = $C0
  KEYCODE_RIGHT     = $C1
  KEYCODE_UP        = $C2
  KEYCODE_DOWN      = $C3
  KEYCODE_F3        = $D2
  KEYCODE_ESC       = $CB

  ' where does the file start in memory?
  FILE_START_LOC    = 8000

'//////////////////////////////////////////////////////////////////////////////
' VARS SECTION ////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

VAR

' begin parameter list ////////////////////////////////////////////////////////
' tile engine data structure pointers (can be changed in real-time by app!)
long tile_map_base_ptr_parm
long tile_bitmaps_base_ptr_parm
long tile_palettes_base_ptr_parm
long tile_map_width_parm

' real-time engine status variables, these are updated in real time by the
' tile engine itself, so they can be monitored outside in SPIN/ASM by game
long tile_status_bits_parm      ' vsync, hsync, etc.

' format of tile_status_bits_parm, only the Vsync status bit is updated
'
' byte 3 (unused)|byte 2 (line)|   byte 1 (tile postion)    |                     byte 0 (sync and region)      |
'|x x x x x x x x| line 8-bits | row 4 bits | column 4-bits |x x x x | region 2-bits | hsync 1-bit | vsync 1-bit|
'   b31..b24         b23..b16      b15..b12     b11..b8                    b3..b2          b1            b0
' Region 0=Top Overscan, 1=Active Video, 2=Bottom Overscan, 3=Vsync
' NOTE: In this version of the tile engine only VSYNC and REGION are valid 

' end parameter list ///////////////////////////////////////////////////////////

  byte cursor_on                ' cursor currently on screen? (1 = yes)
  byte cursor_counter           ' counter for cursor blink rate

  word prev_state               ' keep track of the previous state of the cursor position
  byte cursor_rendered

  byte row, col                 ' row and column
  byte last_row, last_col       ' last row and column

  byte curr_key                 ' current_key
  word key_found                ' current key handled flag

  long line_count               ' line counter
  long line_char_count          ' number of characters on the current line

  word program_state            ' the state of the program 

'//////////////////////////////////////////////////////////////////////////////
'OBJS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////

OBJ

  key   : "keyboard_iso_010.spin"    ' instantiate a keyboard object

'//////////////////////////////////////////////////////////////////////////////
'PUBS SECTION /////////////////////////////////////////////////////////////////
'//////////////////////////////////////////////////////////////////////////////


' COG INTERPRETER STARTS HERE...@ THE FIRST PUB

PUB Start | char_count, key_handled, handled_key, char_render_count, render_col, render_row, cursor_handled, shift_count, temp_counter

  ' This is the first entry point the system will see when the PChip starts,
  ' execution ALWAYS starts on the first PUB in the source code for
  ' the top level file

  DIRA[0] := 1
   
  ' start the keyboard driver
  key.start(2)

  ' start in editor mode
  program_state := 0

  ' set to row 0 and col 0
  col := 1
  row := 2

  ' clear the first row row
  repeat while(col < 30)
     BYTE[FILE_START_LOC + (row* 32) + col] := $00_00
     col++

  ' reset the column
  col := 1 

  ' set up the cyrsor
  cursor_on := 1
  cursor_counter := 0
  prev_state := 0
  cursor_rendered := 0

  ' initialize the character count to 0 and initialize the handler
  key_handled := false
  char_count := 0
  key_handled := 0

  ' initialize the counters
  line_count := 2
  line_char_count := 1

  ' initialize the first byte to 0
  BYTE[FILE_START_LOC + char_count] := $00_00
   
  ' points ptrs to actual memory storage for tile engine
  tile_map_base_ptr_parm      := @tile_maps
  tile_bitmaps_base_ptr_parm  := @tile_bitmaps
  tile_palettes_base_ptr_parm := @palette_map
  tile_map_width_parm         := 0 ' set for width 16 tiles, 0 = 32 tiles, 1 = 64 tiles, 2 = 128 tiles, 3 = 256 tiles, etc.
  tile_status_bits_parm       := 0
   
  ' launch a COG with ASM video driver
  cognew(@HEL_GFX_Driver_Entry, @tile_map_base_ptr_parm)   

  repeat while TRUE
    
    if(program_state == 0)
     
      ' start the render loop
      tile_map_base_ptr_parm := @tile_map0
     
      ' save the old info
      last_col := col
      last_row := row
     
      ' handle the keyboard input    
      if(key.gotkey)
     
        ' get the key
        curr_key := key.getkey
        
        if(curr_key == KEYCODE_F3)

          ' change to program 'run' mode
          program_state := 1

          'handled
          key_handled := 1
     
        if(curr_key == KEYCODE_BACKSPACE)
     
          if(col > 1)
     
            ' set up
            temp_counter := col
     
            ' repeat
            repeat while(temp_counter < 30)
     
               ' loop through and reset
               BYTE[FILE_START_LOC + (row * 32) + (temp_counter - 1)] := BYTE[FILE_START_LOC + (row * 32) + temp_counter]
     
               ' increment
               temp_counter++
     
            ' set the cursor's old position
            tile_map0[(row * 32) + (col + 1)] := BYTE[FILE_START_LOC + ((row * 32) + (col + 1))]
     
            ' set the cursor's new position
            col --

          else

            ' we're at the beginning of a row, check if it's not the first row
            if(row > 2)

              ' not the first row, move up in life
              row--
              line_count--
             
          ' handled
          key_handled := 1
     
        if(curr_key == KEYCODE_LEFT)
     
          ' move the cursor
          if(col > 1)
            col--
            tile_map0[(row * 32) + (col + 1)] := BYTE[FILE_START_LOC + (row * 32) + (col + 1)]
            
          key_handled := 1
     
        if(curr_key == KEYCODE_RIGHT)
     
          ' move the cursor
          if(col < 30)
     
            'if(col < line_char_count)
            
               col++
               tile_map0[(row * 32) + (col - 1)] := BYTE[FILE_START_LOC + (row * 32) + (col - 1)]
            
          key_handled := 1
     
        if(curr_key == KEYCODE_UP)
     
          ' move the cursor
          if(row > 2)
            row--
            tile_map0[((row + 1) * 32) + col] := BYTE[FILE_START_LOC + ((row + 1) * 32) + col]
     
          ' handled          
          key_handled := 1
     
        if(curr_key == KEYCODE_DOWN)
     
          ' move the cursor
          if(row < 21)
     
            if(row < line_count)
                row++
                tile_map0[((row - 1) * 32) + col] := BYTE[FILE_START_LOC + ((row - 1) * 32) + col]
            
          key_handled := 1
     
        if(curr_key == KEYCODE_ENTER)
     
          ' insert an enter key
          BYTE[FILE_START_LOC + ((row * 32) + col)] := $00_FF
     
          ' increment the counter
          char_count++
          
          ' move cursor
          if(row < 21)
          
            row++
            tile_map0[((row - 1) * 32) + col] := BYTE[FILE_START_LOC + ((row - 1) * 32) + col] 
     
            col := 1

            ' clear the row
            repeat while(col < 30)
               BYTE[FILE_START_LOC + (row* 32) + col] := $00_00
               col++

            col := 1
     
          ' adjust the counters
          line_count++
          line_char_count := 0
     
          key_handled := 1
     
        if(key_handled == 0)
     
          ' process the key to get the character value
          handled_key := Handle_Key(curr_key)
     
          ' store the key in memory
          BYTE[FILE_START_LOC + ((row * 32) + (col - 1))] := handled_key
     
          ' increment the counters 
          char_count++
          line_char_count++
     
      key_handled := 0
     
      ' enter character render loop
      if(char_count > 0)
     
        ' reset the counters                 
        char_render_count := 0
        render_col := 1
        render_row := 2
     
        ' loop through and render the characters
        repeat while(char_render_count < char_count)
     
          ' if this is a renderable character
          if((BYTE[FILE_START_LOC + ((render_row * 32) + render_col)]) < $00_54)
     
            if((row == render_row) & (render_col == col))
     
               ' do we render the cursor or the character?
               if(cursor_on == 1)
                
                  ' render the cursor
                  tile_map0[(render_row * 32) + render_col] := $00_54
     
                  ' the cursor is taken care of
                  cursor_rendered := 1
     
               else
     
                  ' render the character
                  tile_map0[(render_row * 32) + render_col] := BYTE[FILE_START_LOC + ((render_row * 32) + render_col)]
     
                  ' the cursor is taken care of
                  cursor_rendered := 1
               
            else
                  
               'render the character
               tile_map0[(render_row * 32) + render_col] := BYTE[FILE_START_LOC + ((render_row * 32) + render_col)]
                                     
            ' increment the counters
            char_render_count++
            render_col++
                                   
            if(render_col > 30)
               render_col := 1
               render_row++
     
          ' no, must be a special char
          else
     
            ' if this is the enter key...
            if((BYTE[FILE_START_LOC + ((render_row * 32) + render_col)]) == $00_FF)
     
               tile_map0[(render_row * 32) + render_col] := $00_00
                                         
               ' increment the row
               render_col := 1
               render_row++
               
            ' if this is the space bar...
            if((BYTE[FILE_START_LOC + ((render_row * 32) + render_col)]) == $00_57)
     
               ' increment the row
               render_col++
     
               tile_map0[(render_row * 32) + (render_col - 1)] := $00_00
               
            'increment counters
            char_render_count++
     
      ' if the cursor wasn't rendered yet...
      if(cursor_rendered == 0)
     
        if(cursor_on == 1)
        
          ' render it
          tile_map0[(row * 32) + col] := $00_54 
      
      ' increment the cursor counter
      cursor_counter++
     
      ' do we change the cursor?
      if(cursor_counter > 10)
     
        if(cursor_on == 1)
     
          ' yes, change it
          cursor_on := 0
     
          tile_map0[(row * 32) + col] := $00_00
     
        else
        
          cursor_on := 1
          tile_map0[(row * 32) + col] := $00_54
     
        ' reset the counter
        cursor_counter := 0
     
      cursor_rendered := 0

      ' wait another vsync
       
      repeat while ((tile_status_bits_parm & $01) == $01)
      repeat while ((tile_status_bits_parm & $01) == $00)
       
      repeat while ((tile_status_bits_parm & $01) == $01)
      repeat while ((tile_status_bits_parm & $01) == $00)
       
      repeat while ((tile_status_bits_parm & $01) == $01)
      repeat while ((tile_status_bits_parm & $01) == $00)

    if(program_state == 1)

      if(key.gotkey)
     
        ' get the key
        curr_key := key.getkey
        
        if(curr_key == KEYCODE_F3)

           ' change to program 'run' mode
           program_state := 0

        if(curr_key == KEYCODE_ESC)

           ' change to program 'run' mode
           program_state := 0

      tile_map_base_ptr_parm := @tile_map1

      Parse_File(char_count)
    
      ' wait another vsync
       
      repeat while ((tile_status_bits_parm & $01) == $01)
      repeat while ((tile_status_bits_parm & $01) == $00)
       
      repeat while ((tile_status_bits_parm & $01) == $01)
      repeat while ((tile_status_bits_parm & $01) == $00)
       
      repeat while ((tile_status_bits_parm & $01) == $01)
      repeat while ((tile_status_bits_parm & $01) == $00)
   
    ' return back to repeat main event loop...
      
  ' parent COG will terminate now...if it gets to this point

PUB Handle_Key(input_key) | key_index_counter, char_counter

  ' if this is a letter, print it
  key_index_counter := 1
  char_counter := 0
  key_found := false

  ' check all of the character keys
  repeat while char_counter < 83

    ' if this is the key...
    if keyboard_map[key_index_counter] == input_key

      ' alert the program
      key_found := true

      ' increment the cursor position
      col++

      ' if the cursor has crossed the lines, let it know
      if(col > 30)
     
        col := 0
        row++

      ' if we found the key, return it
      return keyboard_map[key_index_counter - 1]

    ' increment the counters
    key_index_counter += 2
    char_counter++
  
  ' check the special keys
  if(input_key == KEYCODE_SPACE)

    ' move cursor
    col++
    
    ' return the key
    return $00_57

PUB StrCmp(str_one, str_two, length) | char_counter, str_match

  ' assume they match by default
  str_match := true

  ' loop through each character to test it
  repeat while char_counter < length

    ' if they don't match return false
    if(!(str_one[char_counter] == str_two[char_counter]))

      str_match := false

    ' increment the counter
    char_counter++

  ' return the value
  return str_match

PUB Parse_File(total_char_count) | char_counter, prev_char_counter, render_row, render_col, temp_counter, first_pass

  ' start at the beginning
  prev_char_counter := 0
  char_counter := 0
  temp_counter := 0
  first_pass := true

  ' set up for rendering
  render_row := 2
  render_col := 1

  ' repeat until we're done (EOF)  
  repeat while(char_counter < total_char_count)

    if(first_pass == true)
    
      ' loop through until we find a starting character
      repeat while(BYTE[FILE_START_LOC + char_counter] <> $00_57)

        ' increment
        char_counter++

      first_pass := false
      
    prev_char_counter := char_counter
       
    ' loop through until we find a space
    repeat while(BYTE[FILE_START_LOC + char_counter] <> $00_57)

      ' increment
      char_counter++

    ' we're at a space
    ' go back and get the 'token' and process it
    if(StrCmp(BYTE[FILE_START_LOC + char_counter], keyword_func_print, char_counter - prev_char_counter) == true)

      ' this is a print command
      ' check the next character after the space

      ' if it is a set of quotes, it's text, print it
      if(BYTE[FILE_START_LOC + char_counter + 1] == $00_4A)

        ' set up
        temp_counter := char_counter + 2
        
        ' get the text and print it to the screen
        repeat while(BYTE[FILE_START_LOC + temp_counter] <> $00_4A)

          ' if this is a character...
          if(BYTE[FILE_START_LOC + temp_counter] < $00_54)

             ' display
             tile_map1[(render_row * 32) + render_col] := BYTE[FILE_START_LOC + temp_counter]

          else

             ' check special chars

             ' space
             if(BYTE[FILE_START_LOC + temp_counter] == $00_57)

                ' move
                render_col++

          ' increment the counters
          render_col++
          temp_counter++
        
        ' reset
        render_row++
        render_col := 1

    ' set the last point (move past the space)
    char_counter := temp_counter + 2    
  
DAT

' map out the keyboard

' keyboard map          tile # keycode          letter
keyboard_map  word      $00_02,$00_41           ' A
              word      $00_03,$00_61           ' a
              word      $00_04,$00_42           ' B
              word      $00_05,$00_62           ' b
              word      $00_06,$00_43           ' C
              word      $00_07,$00_63           ' c
              word      $00_08,$00_44           ' D
              word      $00_09,$00_64           ' d
              word      $00_0A,$00_45           ' E
              word      $00_0B,$00_65           ' e
              word      $00_0C,$00_46           ' F
              word      $00_0D,$00_66           ' f
              word      $00_0E,$00_47           ' G
              word      $00_0F,$00_67           ' g
              word      $00_10,$00_48           ' H
              word      $00_11,$00_68           ' h
              word      $00_12,$00_49           ' I
              word      $00_13,$00_69           ' i
              word      $00_14,$00_4A           ' J
              word      $00_15,$00_6A           ' j
              word      $00_16,$00_4B           ' K
              word      $00_17,$00_6B           ' k
              word      $00_18,$00_4C           ' L
              word      $00_19,$00_6C           ' l
              word      $00_1A,$00_4D           ' M
              word      $00_1B,$00_6D           ' m
              word      $00_1C,$00_4E           ' N
              word      $00_1D,$00_6E           ' n
              word      $00_1E,$00_4F           ' O
              word      $00_1F,$00_6F           ' o
              word      $00_20,$00_50           ' P
              word      $00_21,$00_70           ' p
              word      $00_22,$00_51           ' Q
              word      $00_23,$00_71           ' q
              word      $00_24,$00_52           ' R
              word      $00_25,$00_72           ' r
              word      $00_26,$00_53           ' S
              word      $00_27,$00_73           ' s
              word      $00_28,$00_54           ' T
              word      $00_29,$00_74           ' t
              word      $00_2A,$00_55           ' U
              word      $00_2B,$00_75           ' u
              word      $00_2C,$00_56           ' V
              word      $00_2D,$00_76           ' v
              word      $00_2E,$00_57           ' W
              word      $00_2F,$00_77           ' w
              word      $00_30,$00_58           ' X
              word      $00_31,$00_78           ' x
              word      $00_32,$00_59           ' Y
              word      $00_33,$00_79           ' y
              word      $00_34,$00_5A           ' Z
              word      $00_35,$00_7A           ' z
              word      $00_36,$00_31           ' 1
              word      $00_37,$00_32           ' 2
              word      $00_38,$00_33           ' 3
              word      $00_39,$00_34           ' 4
              word      $00_3A,$00_35           ' 5
              word      $00_3B,$00_36           ' 6
              word      $00_3C,$00_37           ' 7
              word      $00_3D,$00_38           ' 8
              word      $00_3E,$00_39           ' 9
              word      $00_3F,$00_30           ' 0
              word      $00_40,$00_28           ' (
              word      $00_41,$00_29           ' )
              word      $00_42,$00_5B           ' [
              word      $00_43,$00_5D           ' ]
              word      $00_44,$00_2A           ' *
              word      $00_45,$00_2D           ' -
              word      $00_46,$00_3D           ' =
              word      $00_47,$00_2B           ' +
              word      $00_48,$00_2F           ' /
              word      $00_49,$00_27           ' '
              word      $00_4A,$00_22           ' "
              word      $00_4B,$00_3A           ' :
              word      $00_4C,$00_3B           ' ;
              word      $00_4D,$00_3C           ' <
              word      $00_4E,$00_3E           ' >
              word      $00_4F,$00_2C           ' ,
              word      $00_50,$00_2E           ' .
              word      $00_51,$00_3F           ' ?
              word      $00_52,$00_21           ' !
              word      $00_53,$00_25           ' %

                        ' num ' tile
number_map    long      $00_00,$00_3F
              long      $00_01,$00_36
              long      $00_02,$00_37
              long      $00_03,$00_38
              long      $00_04,$00_39
              long      $00_05,$00_3A
              long      $00_06,$00_3B
              long      $00_07,$00_3C
              long      $00_08,$00_3D
              long      $00_09,$00_3E
              long      $00_10,$00_3F

tile_maps     word
              ' you place all your 32x24 tile maps here, you can have as many as you like, in real-time simply re-point the
              ' tile_map_base_ptr_parm to any time map and within 1 frame the tile map will update

              ' 32x24 WORDS each, (0..768 WORDs,1536 bytes per tile map) 2-BYTE tiles (msb)[palette_index | tile_index](lsb)
              ' 32x24 tile map, each tile is 2 bytes, there are a total of 256 tiles possible, and thus 256 palettes              

              ' column     0      1      2      3      4      5      6      7      8      9     10     11     12     13     14     15      16    17      18    19     20     21     22     23     24     25     26     27     28     29     20     31  
tile_map0     word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 0
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 4
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 5
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 6
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 7
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 8
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 9
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 11
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 12
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 13
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 14
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 15
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 16
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 17
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 18
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 19
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 20
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 21
              word      $00_00,$00_0C,$00_36,$00_4B,$00_26,$00_03,$00_2D,$00_0B,$00_00,$00_0C,$00_37,$00_4B,$00_1E,$00_21,$00_0B,$00_1D,$00_00,$00_0C,$00_38,$00_4B,$00_24,$00_2B,$00_1D,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 22
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 23

              ' column     0      1      2      3      4      5      6      7      8      9     10     11     12     13     14     15      16    17      18    19     20     21     22     23     24     25     26     27     28     29     20     31  
tile_map1     word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 0
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 1
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 2
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 3
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 4
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 5
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 6
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 7
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 8
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 9
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 10
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 11
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 12
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 13
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 14
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 15
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 16
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 17
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 18
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 19
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 20
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 21
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 22
              word      $00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00,$00_00 ' row 23              

' /////////////////////////////////////////////////////////////////////////////

tile_bitmaps word
              ' tile bitmap memory, each tile 8x8 pixels, or 1 WORD by 8,
              ' 16-bytes each, also, note that they are mirrored right to left

' empty tile
tile_blank    word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0

tile_line     word      %%0_0_0_0_0_0_0_0 ' tile 1
              word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0


tile_a  word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_1_0_1_0_0
        word    %%0_0_0_1_0_1_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_1_1_1_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_1_0_0_0_0_0_1
        word    %%0_0_0_0_0_0_0_0
                

tile_sa word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_1_1_1_1_0
        word    %%0_0_1_0_0_0_0_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_b  word    %%0_0_0_1_1_1_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_1_1_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_1_1_1_0
        word    %%0_0_0_0_0_0_0_0
                

tile_sb word    %%0_0_0_0_0_0_1_0
        word    %%0_0_0_0_0_0_1_0
        word    %%0_0_0_1_1_1_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_1_1_1_0
        word    %%0_0_0_0_0_0_0_0
                

tile_c  word    %%0_0_0_1_1_1_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_0_0_0_1_0
        word    %%0_0_0_0_0_0_1_0
        word    %%0_0_0_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_sc word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_d  word    %%0_0_0_1_1_1_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_1_1_1_0
        word    %%0_0_0_0_0_0_0_0
                

tile_sd word    %%0_0_1_0_0_0_0_0
        word    %%0_0_1_0_0_0_0_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_e  word    %%0_0_1_1_1_1_1_0
        word    %%0_0_0_0_0_0_1_0
        word    %%0_0_0_0_0_0_1_0
        word    %%0_0_1_1_1_1_1_0
        word    %%0_0_0_0_0_0_1_0
        word    %%0_0_0_0_0_0_1_0
        word    %%0_0_1_1_1_1_1_0
        word    %%0_0_0_0_0_0_0_0
                

tile_se word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_1_1_1_1_0
        word    %%0_0_0_0_0_0_1_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_f  word    %%0_0_1_1_1_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_sf word    %%0_0_0_1_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_g  word    %%0_0_1_1_1_1_0_0
        word    %%0_1_0_0_0_0_1_0
        word    %%0_0_0_0_0_0_1_0
        word    %%0_1_1_1_0_0_1_0
        word    %%0_1_0_0_0_0_1_0
        word    %%0_1_0_0_0_0_1_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_sg word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_1_1_0_0
                

tile_h  word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_1_1_1_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_0_0_0_0_0
                

tile_sh word    %%0_0_0_0_0_0_1_0
        word    %%0_0_0_0_0_0_1_0
        word    %%0_0_0_1_1_1_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_0_0_0_0_0
                

tile_i  word    %%0_0_0_1_1_1_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_si word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_j  word    %%0_0_1_0_0_0_0_0
        word    %%0_0_1_0_0_0_0_0
        word    %%0_0_1_0_0_0_0_0
        word    %%0_0_1_0_0_0_0_0
        word    %%0_0_1_0_0_0_0_0
        word    %%0_0_1_0_0_1_0_0
        word    %%0_0_0_1_1_0_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_sj word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_0_1_1_0_0
                

tile_k  word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_0_0_1_0
        word    %%0_0_0_0_1_0_1_0
        word    %%0_0_0_1_0_1_1_0
        word    %%0_0_0_1_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_0_0_0_0_0
                

tile_sk word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_1_0_0_1_0_0
        word    %%0_0_0_1_0_1_0_0
        word    %%0_0_0_0_1_1_0_0
        word    %%0_0_0_1_0_1_0_0
        word    %%0_0_1_0_0_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_l  word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_sl word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_m  word    %%0_1_0_0_0_0_0_1
        word    %%0_1_1_0_0_0_1_1
        word    %%0_1_1_0_0_0_1_1
        word    %%0_1_0_1_0_1_0_1
        word    %%0_1_0_1_0_1_0_1
        word    %%0_1_0_0_1_0_0_1
        word    %%0_1_0_0_1_0_0_1
        word    %%0_0_0_0_0_0_0_0
                

tile_sm word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_0_1_1_0_1_1_1
        word    %%0_1_0_0_1_0_0_1
        word    %%0_1_0_0_1_0_0_1
        word    %%0_1_0_0_1_0_0_1
        word    %%0_1_0_0_1_0_0_1
        word    %%0_0_0_0_0_0_0_0
                

tile_n  word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_1_1_0
        word    %%0_0_1_0_0_1_1_0
        word    %%0_0_1_0_1_0_1_0
        word    %%0_0_1_1_0_0_1_0
        word    %%0_0_1_1_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_0_0_0_0_0
                

tile_sn word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_1_1_1_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_0_0_0_0_0
                

tile_o  word    %%0_0_1_1_1_1_0_0
        word    %%0_1_0_0_0_0_1_0
        word    %%0_1_0_0_0_0_1_0
        word    %%0_1_0_0_0_0_1_0
        word    %%0_1_0_0_0_0_1_0
        word    %%0_1_0_0_0_0_1_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_so word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_p  word    %%0_0_1_1_1_1_0_0
        word    %%0_1_0_0_0_1_0_0
        word    %%0_1_0_0_0_1_0_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_sp word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_1_1_1_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_1_1_1_0
        word    %%0_0_0_0_0_0_1_0
                

tile_q  word    %%0_0_1_1_1_1_0_0
        word    %%0_1_0_0_0_0_1_0
        word    %%0_1_0_0_0_0_1_0
        word    %%0_1_0_0_0_0_1_0
        word    %%0_1_0_1_0_0_1_0
        word    %%0_1_1_0_0_0_1_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_1_0_0_0_0_0_0
                

tile_sq word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_1_0_0_0_0_0
                

tile_r  word    %%0_0_0_1_1_1_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_1_1_1_0
        word    %%0_0_0_1_0_0_1_0
        word    %%0_0_0_1_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_0_0_0_0_0
                

tile_sr word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_s  word    %%0_0_1_1_1_0_0_0
        word    %%0_1_0_0_0_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_1_1_1_0_0_0
        word    %%0_1_0_0_0_0_0_0
        word    %%0_1_0_0_0_1_0_0
        word    %%0_0_1_1_1_0_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_ss word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_0_0_0_0_1_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_1_0_0_0_0_0
        word    %%0_0_0_1_1_1_1_0
        word    %%0_0_0_0_0_0_0_0
                

tile_t  word    %%0_0_1_1_1_1_1_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_st word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_1_1_1_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_0_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_u  word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_su word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_v  word    %%1_0_0_0_0_0_1_0
        word    %%0_1_0_0_0_1_0_0
        word    %%0_1_0_0_0_1_0_0
        word    %%0_0_1_0_1_0_0_0
        word    %%0_0_1_0_1_0_0_0
        word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_sv word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_1_0_0_0_0_1_0
        word    %%0_0_1_0_0_1_0_0
        word    %%0_0_1_0_0_1_0_0
        word    %%0_0_0_1_1_0_0_0
        word    %%0_0_0_1_1_0_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_w  word    %%0_1_0_0_1_0_0_1
        word    %%0_1_0_0_1_0_0_1
        word    %%0_1_0_1_0_1_0_1
        word    %%0_1_0_1_0_1_0_1
        word    %%0_1_0_1_0_1_0_1
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_0_0_0_0_0
                

tile_sw word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_1_0_0_1_0_0_1
        word    %%0_1_0_0_1_0_0_1
        word    %%0_1_0_1_0_1_0_1
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_0_0_0_0_0
                

tile_x  word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_0_1_0_0
        word    %%0_0_0_1_0_1_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_1_0_1_0_0
        word    %%0_0_0_1_0_1_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_0_0_0_0_0
                

tile_sx word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_0_1_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_1_0_1_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_0_0_0_0_0
                

tile_y  word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_0_1_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_sy word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_1_0_0_0_1_0_0
        word    %%0_0_1_0_1_0_0_0
        word    %%0_0_1_0_1_0_0_0
        word    %%0_0_1_0_1_0_0_0
        word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_0_1_1_0_0
                

tile_z  word    %%0_0_1_1_1_1_0_0
        word    %%0_0_1_0_0_0_0_0
        word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                
      
tile_sz word    %%0_0_0_0_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_1  word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_1_1_0_0_0
        word    %%0_0_0_1_0_1_0_0
        word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_2  word    %%0_0_0_1_1_1_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_0_0
        word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_1_1_1_1_1_0
        word    %%0_0_0_0_0_0_0_0
                

tile_3  word    %%0_0_0_1_1_1_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_0_0
        word    %%0_0_0_1_1_0_0_0
        word    %%0_0_1_0_0_0_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_4  word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_1_1_0_0_0
        word    %%0_0_0_1_0_1_0_0
        word    %%0_0_0_1_0_1_0_0
        word    %%0_0_0_1_0_0_1_0
        word    %%0_0_1_1_1_1_1_0
        word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_5  word    %%0_0_1_1_1_1_0_0
        word    %%0_0_0_0_0_1_0_0
        word    %%0_0_0_1_1_1_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_6  word    %%0_0_0_1_1_1_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_0_0_0_1_0
        word    %%0_0_0_1_1_1_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_7  word    %%0_0_1_1_1_1_1_0
        word    %%0_0_1_0_0_0_0_0
        word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_1_0_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_1_0_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_8  word    %%0_0_0_1_1_1_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_9  word    %%0_0_0_1_1_1_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_1_1_1_1_0_0
        word    %%0_0_1_0_0_0_0_0
        word    %%0_0_1_0_0_0_1_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_0  word    %%0_0_0_1_1_1_0_0
        word    %%0_0_1_1_0_0_1_0
        word    %%0_0_1_0_1_0_1_0
        word    %%0_0_1_0_1_0_1_0
        word    %%0_0_1_0_1_0_1_0
        word    %%0_0_1_0_0_1_1_0
        word    %%0_0_0_1_1_1_0_0
        word    %%0_0_0_0_0_0_0_0
                

tile_start_circ_brace  word     %%0_0_0_0_1_0_0_0       ' (
                       word     %%0_0_0_0_0_1_0_0
                       word     %%0_0_0_0_0_1_0_0
                       word     %%0_0_0_0_0_1_0_0
                       word     %%0_0_0_0_0_1_0_0
                       word     %%0_0_0_0_0_1_0_0
                       word     %%0_0_0_0_0_1_0_0
                       word     %%0_0_0_0_1_0_0_0
                

tile_end_circ_brace  word       %%0_0_0_0_1_0_0_0        ' )
                     word       %%0_0_0_1_0_0_0_0
                     word       %%0_0_0_1_0_0_0_0
                     word       %%0_0_0_1_0_0_0_0
                     word       %%0_0_0_1_0_0_0_0
                     word       %%0_0_0_1_0_0_0_0
                     word       %%0_0_0_1_0_0_0_0
                     word       %%0_0_0_0_1_0_0_0
                

tile_start_square_brace  word   %%0_0_0_1_1_0_0_0       ' [
                         word   %%0_0_0_0_1_0_0_0
                         word   %%0_0_0_0_1_0_0_0
                         word   %%0_0_0_0_1_0_0_0
                         word   %%0_0_0_0_1_0_0_0
                         word   %%0_0_0_0_1_0_0_0
                         word   %%0_0_0_0_1_0_0_0
                         word   %%0_0_0_1_1_0_0_0
                

tile_end_square_brace  word     %%0_0_0_0_1_1_0_0       ' ]
                       word     %%0_0_0_0_1_0_0_0
                       word     %%0_0_0_0_1_0_0_0
                       word     %%0_0_0_0_1_0_0_0
                       word     %%0_0_0_0_1_0_0_0
                       word     %%0_0_0_0_1_0_0_0
                       word     %%0_0_0_0_1_0_0_0
                       word     %%0_0_0_0_1_1_0_0
                

tile_math_multiply     word     %%0_0_0_0_1_0_0_0       ' *
                       word     %%0_0_0_1_1_1_0_0
                       word     %%0_0_0_0_1_0_0_0
                       word     %%0_0_0_1_0_1_0_0
                       word     %%0_0_0_0_0_0_0_0
                       word     %%0_0_0_0_0_0_0_0
                       word     %%0_0_0_0_0_0_0_0
                       word     %%0_0_0_0_0_0_0_0
                

tile_math_subtract  word        %%0_0_0_0_0_0_0_0       ' -
                    word        %%0_0_0_0_0_0_0_0
                    word        %%0_0_0_0_0_0_0_0
                    word        %%0_0_0_1_1_1_0_0
                    word        %%0_0_0_0_0_0_0_0
                    word        %%0_0_0_0_0_0_0_0
                    word        %%0_0_0_0_0_0_0_0
                    word        %%0_0_0_0_0_0_0_0
                

tile_math_equal  word           %%0_0_0_0_0_0_0_0       ' =
                 word           %%0_0_1_1_1_1_0_0
                 word           %%0_0_0_0_0_0_0_0
                 word           %%0_0_1_1_1_1_0_0
                 word           %%0_0_0_0_0_0_0_0
                 word           %%0_0_0_0_0_0_0_0
                 word           %%0_0_0_0_0_0_0_0
                 word           %%0_0_0_0_0_0_0_0
                

tile_math_addition  word        %%0_0_0_0_0_0_0_0       ' +
                    word        %%0_0_0_0_1_0_0_0
                    word        %%0_0_0_0_1_0_0_0
                    word        %%0_0_1_1_1_1_1_0
                    word        %%0_0_0_0_1_0_0_0
                    word        %%0_0_0_0_1_0_0_0
                    word        %%0_0_0_0_0_0_0_0
                    word        %%0_0_0_0_0_0_0_0
                

tile_math_divide  word          %%0_0_1_0_0_0_0_0       ' /
                  word          %%0_0_1_0_0_0_0_0
                  word          %%0_0_0_1_0_0_0_0
                  word          %%0_0_0_1_0_0_0_0
                  word          %%0_0_0_1_0_0_0_0
                  word          %%0_0_0_0_1_0_0_0
                  word          %%0_0_0_0_1_0_0_0
                  word          %%0_0_0_0_0_0_0_0
                

tile_quote_single  word         %%0_0_0_0_1_0_0_0       ' '
                   word         %%0_0_0_0_1_0_0_0
                   word         %%0_0_0_0_1_0_0_0
                   word         %%0_0_0_0_0_0_0_0
                   word         %%0_0_0_0_0_0_0_0
                   word         %%0_0_0_0_0_0_0_0
                   word         %%0_0_0_0_0_0_0_0
                   word         %%0_0_0_0_0_0_0_0
                

tile_quote_double  word         %%0_0_1_0_1_0_0_0       ' "
                   word         %%0_0_1_0_1_0_0_0
                   word         %%0_0_1_0_1_0_0_0
                   word         %%0_0_0_0_0_0_0_0
                   word         %%0_0_0_0_0_0_0_0
                   word         %%0_0_0_0_0_0_0_0
                   word         %%0_0_0_0_0_0_0_0
                   word         %%0_0_0_0_0_0_0_0
                

tile_colon  word                %%0_0_0_0_0_0_0_0       ' :
            word                %%0_0_0_0_0_0_0_0
            word                %%0_0_0_0_1_0_0_0
            word                %%0_0_0_0_0_0_0_0
            word                %%0_0_0_0_0_0_0_0
            word                %%0_0_0_0_0_0_0_0
            word                %%0_0_0_0_1_0_0_0
            word                %%0_0_0_0_0_0_0_0
                

tile_semicolon  word            %%0_0_0_0_0_0_0_0       ' ;
                word            %%0_0_0_0_0_0_0_0
                word            %%0_0_0_0_1_0_0_0
                word            %%0_0_0_0_0_0_0_0
                word            %%0_0_0_0_0_0_0_0
                word            %%0_0_0_0_0_0_0_0
                word            %%0_0_0_0_1_0_0_0
                word            %%0_0_0_0_1_0_0_0
                

tile_lessthan  word             %%0_0_0_0_0_0_0_0       ' <
               word             %%0_0_1_0_0_0_0_0
               word             %%0_0_0_1_1_1_0_0
               word             %%0_0_0_0_0_0_1_0
               word             %%0_0_0_1_1_1_0_0
               word             %%0_0_1_0_0_0_0_0
               word             %%0_0_0_0_0_0_0_0
               word             %%0_0_0_0_0_0_0_0
                

tile_greaterthan  word          %%0_0_0_0_0_0_0_0       ' >
                  word          %%0_0_0_0_0_0_1_0
                  word          %%0_0_0_1_1_1_0_0
                  word          %%0_0_1_0_0_0_0_0
                  word          %%0_0_0_1_1_1_0_0
                  word          %%0_0_0_0_0_0_1_0
                  word          %%0_0_0_0_0_0_0_0
                  word          %%0_0_0_0_0_0_0_0
                

tile_comma  word                %%0_0_0_0_0_0_0_0       ' ,
            word                %%0_0_0_0_0_0_0_0
            word                %%0_0_0_0_0_0_0_0
            word                %%0_0_0_0_0_0_0_0
            word                %%0_0_0_0_0_0_0_0
            word                %%0_0_0_0_0_0_0_0
            word                %%0_0_0_1_0_0_0_0
            word                %%0_0_0_1_0_0_0_0
                

tile_period  word               %%0_0_0_0_0_0_0_0       ' .
             word               %%0_0_0_0_0_0_0_0
             word               %%0_0_0_0_0_0_0_0
             word               %%0_0_0_0_0_0_0_0
             word               %%0_0_0_0_0_0_0_0
             word               %%0_0_0_0_0_0_0_0
             word               %%0_0_0_0_0_0_0_1
             word               %%0_0_0_0_0_0_0_0
                

tile_question  word             %%0_0_0_1_1_1_0_0       ' ?
               word             %%0_0_1_0_0_0_1_0
               word             %%0_0_1_0_0_0_0_0
               word             %%0_0_0_1_0_0_0_0
               word             %%0_0_0_0_1_0_0_0
               word             %%0_0_0_0_0_0_0_0
               word             %%0_0_0_0_1_0_0_0
               word             %%0_0_0_0_0_0_0_0
               word

tile_exclamation  word          %%0_0_0_0_1_0_0_0       ' !
                  word          %%0_0_0_0_1_0_0_0
                  word          %%0_0_0_0_1_0_0_0
                  word          %%0_0_0_0_1_0_0_0
                  word          %%0_0_0_0_1_0_0_0
                  word          %%0_0_0_0_0_0_0_0
                  word          %%0_0_0_0_1_0_0_0
                  word          %%0_0_0_0_0_0_0_0
                

tile_percent  word              %%0_0_1_0_0_1_1_1       ' %
              word              %%0_0_1_0_0_1_0_1
              word              %%0_0_0_1_0_1_0_1
              word              %%1_1_1_1_0_1_1_1
              word              %%1_0_1_0_1_0_0_0
              word              %%1_0_1_0_0_1_0_0
              word              %%1_1_1_0_0_1_0_0
              word              %%0_0_0_0_0_0_0_0

tile_cursor   word              %%1_1_1_1_1_1_1_1       ' working tile
              word              %%1_1_1_1_1_1_1_1
              word              %%1_1_1_1_1_1_1_1
              word              %%1_1_1_1_1_1_1_1
              word              %%1_1_1_1_1_1_1_1
              word              %%1_1_1_1_1_1_1_1
              word              %%1_1_1_1_1_1_1_1
              word              %%1_1_1_1_1_1_1_1

tile_space    word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0
              word      %%0_0_0_0_0_0_0_0

' /////////////////////////////////////////////////////////////////////////////

palette_map   ' 4 palettes for only now, palette memory (1..255) LONGs, each palette 4-BYTEs

              long $01_01_07_02 ' palette 0
              long $0C_0B_00_02 ' palette 1
              long $CC_CB_CA_02 ' paleete 2
              long $0C_0B_0A_02 ' palette 3
 
' /////////////////////////////////////////////////////////////////////////////
' ASSEMBLY LANGUAGE HEL_GFX_DRIVER
' Engine 3 Design Notes
' Status: In progress
'
' Specs:
' - 32x24 tile map, each entry 2 bytes, format: [palette index:tile index]
' - 8x8 bitmap tiles, 4 colors each, array of 8 WORDs, each WORD represents 8 pixels, 16 bytes each tile, 4 LONGs
' - Course scrolling, horizontal and vertical, playfield width 32, 64, 128, 256
' 
' Features:
' - Multiple tile maps 256
' - Multiple palettes 256
' - Bitmaps 256
' - All assets base pointers passed to engine each frame, thus "on the fly" changes can be made
' - Supports page flipping, double buffering by design.
' - Engine passes back vertical region and hsyn/vsync status as well as current line
' /////////////////////////////////////////////////////////////////////////////


CON

  FNTSC         = 3_579_545      ' NTSC color clock frequency in HZ
  LNTSC         = (220*16)       ' NTSC color cycles per line (220-227) * 16
  SNTSC         = (44*16)        ' NTSC color cycles per sync (39-44) * 16
  VNTSC         = (LNTSC-SNTSC)  ' NTSC color cycles per active video * 16
  PNTSC256      = (VNTSC >> 4)   ' NTSC color cycles per "compressed/expanded" on screen pixel
                                 ' allows us to put more or less pixels on the screen, but
                                 ' remember NTSC is 224 visible pixels -- period, so when we display more
                                 ' than 224 per line then we are getting chroma distortion on pixel boundaries
                                 ' a more recommended method for cleaner graphics is about 180-190 pixels horizontally
                                 ' this way you don't overdrive the chroma bandwidth which limits colors to 224
                                 ' color clocks per screen
                                 ' we are going to leave clocks per pixel the same, but CHANGE the clocks per frame to 1/2 the value
                                 ' it was for the 16 pixel tiles, this way the timing stays the same, but the waitvid will need
                                 ' 2 - 8 pixel sets 2x as fast


  VIDEO_PINMASK    = %0000_0111     ' vcfg S = pinmask  (pin31 ->0000_0111<-pin24), only want lower 3-bits
  VIDEO_PINGROUP   = 3              ' vcfg D = pingroup (Hydra uses group 3, pins 24-31)
  VIDEO_SETUP      = %0_10_1_01_000 ' vcfg I = controls overall setting, we want baseband video on bottom nibble, 2-bit color, enable chroma on broadcast & baseband
  VIDEO_CNTR_SETUP = %00001_111     ' pll internal routed to Video, PHSx+=FRQx (mode 1) + pll(16x)
                                    ' needn't set D,S fields since they set pin A/B I/Os, but mode 1 is internal, thus irrelvant

' format of tile_status_bits_parm, only the Vsync status bit is updated
'
' byte 3 (unused)|byte 2 (line)|   byte 1 (tile postion)    |                     byte 0 (sync and region)      |
'|x x x x x x x x| line 8-bits | row 4 bits | column 4-bits |x x x x | region 2-bits | hsync 1-bit | vsync 1-bit|
'   b31..b24         b23..b16      b15..b12     b11..b8                    b3..b2          b1            b0
' Region 0=Top Overscan, 1=Active Video, 2=Bottom Overscan, 3=Vsync
' NOTE: In this version of the tile engine only VSYNC and REGION are valid 

  ' tile engine status bits/masks
  TSB_VSYNC                     = %0000_00_01    ' Vsync 
  TSB_HSYNC                     = %0000_00_10    ' Hsync 

  ' regions indicate which parts of the vertical scan the raster is in, useful to time all rendering during the total blanking period which
  ' is any region other than "01"
  TSB_REGION_MASK               = %0000_11_00    ' region status bits bitmask

  TSB_REGION_TOP_OVERSCAN       = %0000_00_00    ' top overscan region (00)
  TSB_REGION_ACTIVE_VIDEO       = %0000_01_00    ' active video region (01)
  TSB_REGION_BOTT_OVERSCAN      = %0000_10_00    ' bottom overscan region (10)
  TSB_REGION_VSYNC              = %0000_11_00    ' vsync region (replicated in vsync bit)                                                

  
  ' register indexes
  CLKFREQ_REG = 0                ' register address of global clock frequency

  ' debuging stuff
  DEBUG_LED_PORT_MASK = $00000001 ' debug LED is on I/O P0


DAT
                org $000  ' set the code emission for COG add $000

HEL_GFX_Driver_Entry

              ' VCFG: setup Video Configuration register and 3-bit TV DAC pins to outputs
                        
              movs    vcfg, #VIDEO_PINMASK              ' vcfg S = pinmask  (pin31 ->0000_0111<-pin24), only want lower 3-bits
              movd    vcfg, #VIDEO_PINGROUP             ' vcfg D = pingroup (Hydra uses group 3, pins 24-31)
              movi    vcfg, #VIDEO_SETUP                ' vcfg I = controls overall setting, we want baseband video on bottom nibble, 2-bit color, enable chroma on broadcast & baseband
              or      dira, tvport_mask                 ' set DAC pins to output 24, 25, 26

              ' CTRA: setup Frequency to Drive Video                        
              movi    ctra, #VIDEO_CNTR_SETUP           ' pll internal routed to Video, PHSx+=FRQx (mode 1) + pll(16x)
                                                        ' needn't set D,S fields since they set pin A/B I/Os, but mode 1 is internal, thus irrelvant

              ' compute the value to place in FREQ such that the final counter
              ' output is NTSC and the PLL output is 16*NTSC
              mov     r1, v_freq                        ' r1 <- TV color burst frequency in Hz, eg. 3_579_545                                             
              rdlong  r2, #CLKFREQ_REG                  ' r2 <- CLKFREQ is register 0, eg. 80_000_000
              call    #Dividefract                      ' perform r3 = 2^32 * r1 / r2
              mov     frqa, r3                          ' set frequency for counter such that bit 31 is toggling at a rate of the color burst (2x actually)
                                                        ' which means that the freq number added at a rate of CLKFREQ (usually 80.000 Mhz) results in a
                                                        ' pll output of the color burst, this is further multiplied by 16 as the final PLL output
                                                        ' thus giving the chroma hardware the clock rate of 16X color burst which is what we want :)


              mov       r0, par                         ' copy boot parameter value and read in parameters from main memory, must be on LONG boundary
              add       r0, #16
              mov       tile_status_bits_ptr, r0        ' ptr to status bits, so tile engine can pass out status of tile engine in real time


Next_Frame    ' start of new frame of 262 scanlines
              ' 26 top overscan
              ' 192 active vide
              ' 26 bottom overscan
              ' 18 vertical sync
                      
              ' read run-time parameters from main memory, user can change these values every frame
              mov       r0, par                         ' copy boot parameter value and read in parameters from main memory, must be on LONG boundary
              rdlong    tile_map_base_ptr, r0           ' base ptr to tile map itself
              add       r0, #4
              rdlong    tile_bitmaps_base_ptr, r0       ' base pointer to array of 8x8 bitmaps, each 16 bytes
              add       r0, #4
              rdlong    tile_palettes_base_ptr, r0      ' base pointer to array of palettes, each palette 4 bytes / 1 long
              add       r0, #4
              rdlong    tile_map_width, r0              ' value of tile map width 0=32, 1=64, 2=128, etc.

              mov       r0, #0                          ' clear out status bits for next frame, 0 means region top overscan, vsync FALSE
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory






' /////////////////////////////////////////////////////////////////////////////
Top_Overscan_Scanlines

              mov       r0, #TSB_REGION_TOP_OVERSCAN    ' set region to top overscan 
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory

              mov     r1, #26                           ' set # of scanlines

' Horizontal Scanline Loop (r1 itterations)
:Next_Scanline
        
              ' HSYNC 10.9us (Horizontal Sync) including color burst
              mov     vscl, v_shsync                    ' set the video scale register such that 16 serial pixels takes 39 color clocks (the total time of the hsync and burst)
              waitvid v_chsync, v_phsync                ' send out the pixels and the colors, the pixels are 0,1,2,3 that index into the colors, the colors are blank, sync, burst
                                                        ' we use them to create the hsync pulse itself

              ' set hsync output status bit and set region
              mov       r0, #TSB_REGION_TOP_OVERSCAN | TSB_HSYNC ' set region to top overscan and set hsync 
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory

              
              ' HVIS 52.6us (Visible Scanline) draw 16 huge pixels
              mov     vscl, v_shvis                     ' set up the video scale so the entire visible scan is composed of 16 huge pixels
              waitvid v_choverscan , v_phoverscan       ' draw 16 pixels with red and blues

              mov       r0, #TSB_REGION_TOP_OVERSCAN    ' set region to top overscan and reset hsync 
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory

              
              djnz    r1, #:Next_Scanline               ' are we done with the scanlines yet?

' /////////////////////////////////////////////////////////////////////////////
Active_Scanlines

              mov       r0, #TSB_REGION_ACTIVE_VIDEO    ' set region to active video
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory

              mov     r1, #0                            ' reset scanline counter, in this case we count up

' Horizontal Scanline Loop (r1 iterations)
:Next_Scanline
        
              ' HSYNC 10.9us (Horizontal Sync) including color burst
              mov     vscl, v_shsync                    ' set the video scale register such that 16 serial pixels takes 39 color clocks (the total time of the hsync and burst)
              waitvid v_chsync, v_phsync                ' send out the pixels and the colors, the pixels are 0,1,2,3 that index into the colors, the colors are blank, sync, burst
                                                        ' we use them to create the hsync pulse itself

              ' set hsync output status bit and set region and active line
              mov       r0, r1
              shl       r0, #16                                     ' set the current line                        
              or        r0, #TSB_REGION_ACTIVE_VIDEO | TSB_HSYNC    ' set region to active video reset hsync 
              wrlong    r0, tile_status_bits_ptr                    ' write out status bits to main memory
                       
' /////////////////////////////////////////////////////////////////////////////

              ' this next section retrives the tile index, palette index for each tile and draws a single line of video composed of 1 sub
              ' scan line of each tile, the opportunity here is to realize that each tile accessed 16 times, once for each video line, thus
              ' the tile indexes and palettes themselves could be "cached" to save time, however, the added complexity is not needed yet
              ' but the next version will cache the data, so we can have more time per pixel block to do crazy stuff :)

              mov     vscl, v_spixel                    ' set up video scale register for 8 pixels at a time

              ' select proper sub-tile row address
              mov       r2, r1                          ' r1 holds current video line of active video (0..191)
              and       r2, #$07                        ' r2 = r1 mod 8, this is the sub-row in the tile we want to render, or the WORD index we need to offset the tile memory by

              ' access main memory can get the bitmap data
              shl       r2, #1                          ' r2 = r2*2, byte based row offset of pixels, 2 bytes per pixel row, 8 pixels, 2 bits per pixel
              add       r2, tile_bitmaps_base_ptr       ' r2 = tile_bitmaps_base_ptr + r2
                                                                                
              ' compute tile index itself for left edge of tile row, inner loop will index across as the scanline is rendered
              ' new code is needed here to support scrolling horizontally, we need to be able to tell the engine that a tile row has MORE than
              ' 8 tiles per row, so that when it access the next tile row down, it calculates properly, so this nice power of 2 math has to be
              ' revisited, however, we are going to constrain that the tiles per row must be a power of 2 multiple of 32 at least, so we don't have to use
              ' complex division yet, trying to keep each engine simple... so the playfield widths are  32, 64, 128, 256 (max), thus the
              ' only thing we need to add is a shift to the mask operation that performs the (line/8) * 32, since now the 32 could be 32, 64, 128, etc.

              ' new code with support for playfields 32, 64, 128... in size which then allows scrolling to be supported (course scrolling of course :)
              mov       tile_map_index_ptr, r1                ' r1 = line, copy it 
              and       tile_map_index_ptr, #$1F8             ' tile_map_index_ptr = [(r1 / 8) * 32..256], this is the starting tile index for a row, 0, 32, 64, ...
              shl       tile_map_index_ptr, #2                ' results in tile_map_index_ptr = [(r1 / 8) * 32]                  
              shl       tile_map_index_ptr, tile_map_width    ' this finishes off the playfield x2, x4, x8, etc. scrolling support


              shl       tile_map_index_ptr, #1                ' tile_map_index_ptr = tile_index*2, since each tile is 2 bytes, we need to convert index to byte address
              add       tile_map_index_ptr, tile_map_base_ptr ' tile_map_index_ptr = [(r1 / 8) * 32..256] + tile_map_base_ptr, this is a byte address in main memory now


              ' at this point we have everything we need for the pixels rendering aspect of the 32 tiles that will be rendered, the inner loop logic will
              ' retrieve the time map indexes, and access the 8 pixels that make up each row of each tile, BUT we need to get the palette(s)
              ' for each tile as well, each tile has its own palette, but the palette will change each group of 8-pixels across the screen since
              ' each 8-pixels represents a single line from a different tile

              ' we could cache all the palettes into the local cache, but for fun let's just read them out of main memory during the inner loop
                  
              ' render the 32 tile lines, r2 is holding proper row address, but we need to add base of actual tile we want rendered
              mov       r4, #32

:Pixel_Render_Loop

              ' read next tile index and palette index from main memory
              rdword    tile_map_word, tile_map_index_ptr
              
              ' retrieve 8-pixels of current row from proper bitmap referenced by tile
              mov       r3, tile_map_word
              and       r3, #$FF                        ' mask off upper 8-bits they hold the palette index, we aren't interested in
              shl       r3, #4                          ' r3 = tile_map_index*16 (bytes per tile bitmap)
              add       r3, r2                          ' r3 = tile_map_index*16 + tile_bitmaps_base_ptr + video_line mod 8
              rdword    r3, r3                          ' r3 = main_memory[r3], retrieve 16 bits of pixel data (8 pixels)
                                                        ' 16 clocks until hub comes around, try and be ready, move a couple instructions that aesthically
                                                        ' should be in one place between the hub reads to maximize processing/memory bandwith
                                         
              mov       v_pixels_buffer, r3             ' r3 holds pixels now, copy to pixel out buffer

              ' retrieve palette for current tile
              mov       r5, tile_map_word
              shr       r5, #8                          ' r5 now holds the palette index and we shifted out the tile index into oblivion
              shl       r5, #2                          ' multiple by 4, since there ar 4-bytes per palette entry
                                                        ' r5 = palette_map_index*4
              add       r5, tile_palettes_base_ptr      ' r5 = palette_map_base_ptr +palette_map_index*4

              ' moved from top of loop to eat time after previous memory read!
              add       tile_map_index_ptr, #2          ' advance pointer 2 bytes to next tile map index entry, for next pass

              rdlong    v_colors_buffer, r5             ' read the palette data into the buffer

              
              'draw the pixels with the selected palette (8 pixels, waitvid will come around 2x as fast now!)
              waitvid   v_colors_buffer, v_pixels_buffer

              ' reset hsync output status bit and set region and active line
              mov       r0, r1
              shl       r0, #16                         ' set the current line                        
              or        r0, #TSB_REGION_ACTIVE_VIDEO    ' set region to active video reset hsync 
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory

              djnz      r4, #:Pixel_Render_Loop         ' loop until we draw 32 tiles (single pixel row of each)

' /////////////////////////////////////////////////////////////////////////////

              add       r1, #1                          
              cmp       r1, #192                  wc, wz
        if_b  jmp       #:Next_Scanline                 ' if ++r1 (current line) < 192 then loop
        
' /////////////////////////////////////////////////////////////////////////////

Bottom_Overscan_Scanlines

              mov       r0, #TSB_REGION_BOTT_OVERSCAN   ' set region to bottom overscan
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory

              mov       r1, #26                         ' set # of scanlines

' Horizontal Scanline Loop (r1 itterations)
:Next_Scanline


              ' HSYNC 10.9us (Horizontal Sync) including color burst
              mov       vscl, v_shsync                  ' set the video scale register such that 16 serial pixels takes 39 color clocks (the total time of the hsync and burst)
              waitvid   v_chsync, v_phsync              ' send out the pixels and the colors, the pixels are 0,1,2,3 that index into the colors, the colors are blank, sync, burst
                                                        ' we use them to create the hsync pulse itself
              ' set hsync output status bit and set region
              mov       r0, #TSB_REGION_BOTT_OVERSCAN | TSB_HSYNC ' set region to bottom overscan and set hsync 
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory


              ' HVIS 52.6us (Visible Scanline) draw 16 huge pixels that represent an entire line of video
              mov       vscl, v_shvis                   ' set up the video scale so the entire visible scan is composed of 16 huge pixels
              waitvid   v_choverscan , v_phoverscan     ' draw 16 pixels with red and blues

              ' reset hsync output status bit and set region
              mov       r0, #TSB_REGION_BOTT_OVERSCAN   ' set region to bottom overscan and reset hsync 
              wrlong    r0, tile_status_bits_ptr        ' write out status bits to main memory

              djnz      r1, #:Next_Scanline             ' are we done with the scanlines yet?

' /////////////////////////////////////////////////////////////////////////////
Vsync_Pulse

              ' VSYNC Pulse (Vertical Sync)
              ' 18 scanlines: 6 'high syncs', 6 'low syncs', and finally another 6 'high syncs'
              ' refer to NTSC spec, but this makes up the equalization pulses needed for a vsync

              mov       r0, #TSB_VSYNC | TSB_REGION_VSYNC ' set region to vsync as well 
              wrlong    r0, tile_status_bits_ptr          ' write out vertical sync status bit to main memory

              call      #Vsync_High
              call      #Vsync_Low
              call      #Vsync_High
                        
              jmp       #Next_Frame                     ' that's it, do it a googleplex times...
                        
'//////////////////////////////////////////////////////////////////////////////
' SUB-ROUTINES VARIABLE DECLARATIONS
'//////////////////////////////////////////////////////////////////////////////

' /////////////////////////////////////////////////////////////////////////////
' vsync_high: Generate 'HIGH' vsync signal for 6 horizontal lines.
Vsync_High              
                               
              mov       r1, #6
                        
              ' HSYNC 10.9us (Horizontal Sync)
:Vsync_Loop   mov       vscl, v_shsync
              waitvid   v_chsync, v_pvsync_high_1

              ' HVIS 52.6us (Visible Scanline)
              mov       vscl, v_shvis
              waitvid   v_chsync, v_pvsync_high_2
              djnz      r1, #:Vsync_Loop

Vsync_High_Ret
              ret

' /////////////////////////////////////////////////////////////////////////////
' vsync_low: Generate 'LOW' vsync signal for 6 horizontal lines.
Vsync_Low
                               
              mov       r1, #6
                        
              ' HSYNC 10.9us (Horizontal Sync)
:Vsync_Loop   mov       vscl, v_shsync
              waitvid   v_chsync, v_pvsync_low_1

              ' HVIS 52.6us (Visible Scanline)
              mov       vscl, v_shvis
              waitvid   v_chsync, v_pvsync_low_2
              djnz      r1, #:Vsync_Loop

Vsync_Low_Ret
              ret

' /////////////////////////////////////////////////////////////////////////////
' Calculates 2^32 * r1/r2, result stored in r3, r1 must be less that r2, that is, r1 < r2
' the results of the division are a binary weighted 32-bit fractional number where each bit
' is equal to the following weights:
' MSB (31)    30    29 ..... 0
'      1/2   1/4   1/8      1/2^32
Dividefract                                     
              mov       r0,#32+1                        ' 32 iterations, are we done yet?
:Loop         cmpsub    r1,r2           wc              ' does divisor divide into dividend?
              rcl       r3,#1                           ' rotate carry into result
              shl       r1,#1                           ' shift dividend over
              djnz      r0,#:Loop                       ' done with division yet?

Dividefract_Ret
              ret                                       ' return to caller with result in r3

'//////////////////////////////////////////////////////////////////////////////
' VARIABLE DECLARATIONS
'//////////////////////////////////////////////////////////////////////////////

' general purpose registers
                        
r0            long      $0                             
r1            long      $0
r2            long      $0
r3            long      $0
r4            long      $0
r5            long      $0
                                           
' tv output DAC port bit mask
tvport_mask   long      %0000_0111 << 24        ' Hydra DAC is on bits 24, 25, 26


' output buffers to hold colors and pixels, start them off with "test" data
                        '3  2  1  0   <- color indexes
v_pixels_buffer long    %%1111222233330000
v_colors_buffer long    $5C_CC_0C_03            ' 3-RED | 2-GREEN | 1-BLUE | 0-BLACK

' pixel VSCL value for 256 visible pixels per line (clocks per pixel 8 bits | clocks per frame 12 bits )
' notice we divide PNTSC256 by 2, this in essence means draw only 8 pixels per waitvid, this way we can
' double the number of tiles, and only 8 of the 16 pixels in the "pixels" array sent to waitvid are rendered
v_spixel      long      ((PNTSC256 >> 4) << 12) + (PNTSC256 >> 1)


' hsync VSCL value (clocks per pixel 8 bits | clocks per frame 12 bits )
v_shsync      long      ((SNTSC >> 4) << 12) + SNTSC

' hsync colors (4, 8-bit values, each represent a color in the format chroma shift, chroma modulatation enable, luma | C3 C2 C1 C0 | M | L2 L1 L0 |
                        '3  2  1  0   <- color indexes
v_chsync      long      $00_00_02_8A ' SYNC (3) / SYNC (2) / BLACKER THAN BLACK (1) / COLOR BURST (0)

' hsync pixels
                        ' BP  |BURST|BW|    SYNC      |FP| <- Key BP = Back Porch, Burst = Color Burst, BW = Breezway, FP = Front Porch
v_phsync      long      %%1_1_0_0_0_0_1_2_2_2_2_2_2_2_1_1

' active video values
v_shvis       long      ((VNTSC >> 4) << 12) + VNTSC

' the colors used, 4 of them always
                        'red, color 3 | dark blue, color 2 | blue, color 1 | light blue, color 0
v_chvis       long      $5A_0A_0B_0C            ' each 2-bit pixel below references one of these 4 colors, (msb) 3,2,1,0 (lsb)

' the pixel pattern                             
v_phvis       long      %%3210_0123_3333_3333   ' 16-pixels, read low to high is rendered left to right, 2 bits per pixel
                                                ' the numbers 0,1,2,3 indicate the "colors" to use for the pixels, the colors
                                                ' are defined by a single byte each with represents the chroma shift, modulation,
                                                ' and luma
' the colors used, 4 of them always
                        'grey, color 3 | dark grey, color 2 | blue, color 1 | black, color 0
v_choverscan  long      $06_04_0C_02            ' each 2-bit pixel below references one of these 4 colors, (msb) 3,2,1,0 (lsb)

' the pixel pattern
v_phoverscan  long      %%0000_0000_0000_0000   ' 16-pixels, read low to high is rendered left to right, 2 bits per pixel
                                                ' the numbers 0,1,2,3 indicate the "colors" to use for the pixels, the colors
                                                ' are defined by a single byte each with represents the chroma shift, modulation,
                                                ' and luma, always uses palette color 0

' vsync pulses 6x High, 6x Low, 6x High
' the vertical sync pulse according to the NTSC spec should be composed of a series
' of pulses called the pre-equalization, serration pulses (the VSYNC pulse itself), and the post-equalization pulses
' there are 6 pulses of each, and they more or less inverted HSYNC, followed by 6 HSYNC pulses, followed by 6 more inverted HSYNC pulses.
' this keeps the horizontal timing circutry locked as well as allows the 60 Hz VSYNC filter to catch the "vsync" event.
' the values 1,2 index into "colors" that represent sync and blacker than black.
' so the definitions below help with generated the "high" and "low" dominate HSYNC timed pulses which are combined
' to generated the actual VSYNC pulse, refer to NTSC documentation for more details.
                                
v_pvsync_high_1         long    %%1_1_1_1_1_1_1_1_1_1_1_2_2_2_1_1  
v_pvsync_high_2         long    %%1_1_1_1_1_1_1_1_1_1_1_1_1_1_1_1
                                
v_pvsync_low_1          long    %%2_2_2_2_2_2_2_2_2_2_2_2_2_2_1_1
v_pvsync_low_2          long    %%1_2_2_2_2_2_2_2_2_2_2_2_2_2_2_2
  
v_freq                  long    FNTSC

' tile engine locals
tile_row                long    $0
video_line              long    $0
tile_map_ptr            long    $0
tile_cache_ptr          long    $0
palette_cache_ptr       long    $0
tile_map_index          long    $0
tile_map_index_ptr      long    $0
tile_map_word           long    $0
tile_palette_index      long    $0

' tile engine passed parameters
tile_map_base_ptr       long    $0
tile_bitmaps_base_ptr   long    $0
tile_palettes_base_ptr  long    $0
tile_map_width          long    $0
tile_status_bits_ptr    long    $0

' keywords

' special chars
keyword_brace_circle_start      word            $00_40
keyword_brace_circle_end        word            $00_41

' ops
keyword_op_add                  word            $00_47
keyword_op_sub                  word            $00_45
keyword_op_mul                  word            $00_44
keyword_op_div                  word            $00_48
keyword_op_equals               word            $00_46

keyword_func_print              word            $00_20,$00_24,$00_12,$00_1C,$00_28

' built in functions

' local COG cache memories (future expansion)
tile_cache              word    $0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
palette_cache           long    $0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0

' END ASM /////////////////////////////////////////////////////////////////////