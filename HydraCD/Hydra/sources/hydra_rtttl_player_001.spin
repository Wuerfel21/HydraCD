' //////////////////////////////////////////////////////////////////////
' HYDRA_RTTTL_PLAYER_001.SPIN - Plays RTTTL songs from a playlist using
' RTTTL format  
' 
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 7.6.06
' VERSION 1.0
' 
' Demonstration of Nick Sabalausky's NS_sound_drv and RTTTL music format.
' 
' Controls: gamepad in left port, use UP/DOWN buttons to scroll thru songs
' press START or A or B to play song
' //////////////////////////////////////////////////////////////////////}}

'///////////////////////////////////////////////////////////////////////
' CONSTANTS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
CON

  _clkmode = xtal2 + pll8x       ' enable external clock range 5-10MHz and pll times 8
  _xinfreq = 10_000_000 + 0000   ' set frequency to 10 MHZ plus some error due to XTAL (1000-5000 usually works)
  _stack   = 128                 ' accomodate display memory and stack

  FINAL_CLOCK_FREQ = (8*(10_000_000+0000)) ' this must be the final clock frequency of the system clock

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

  
  ' rtttl player constants
  RTL_START_SONG = 0
  RTL_END_SONG   = 1

  ' ASCII codes
  ASCII_A       = 65
  ASCII_B       = 66
  ASCII_C       = 67
  ASCII_D       = 68
  ASCII_E       = 69
  ASCII_F       = 70
  ASCII_G       = 71
  ASCII_H       = 72
  ASCII_O       = 79  
  ASCII_P       = 80
  ASCII_Z       = 90
  ASCII_0       = 48
  ASCII_9       = 57
  ASCII_LF     = $0A ' line feed 
  ASCII_CR     = $0D ' carriage return
  ASCII_ESC    = $1B ' escape 
  ASCII_LB     = $5B ' [ 
  ASCII_SEMI   = $3A ' ; 
  ASCII_EQUALS = $3D ' = 
  ASCII_PERIOD = $2E ' .
  ASCII_COMMA  = $2C ' ,
  ASCII_SHARP  = $23 ' #
  ASCII_NULL   = $00
  ASCII_SPACE  = $20 ' space

  ' special note commands
  NOTE_PAUSE  = 10000 ' 10000, 10001, 10002 etc. are commands to timing engine

'///////////////////////////////////////////////////////////////////////
' VARIABLES ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
VAR

  ' globals for RTTTL player
  long rtl_data_ptr
  long rtl_duration, rtl_def_duration
  long rtl_note, rtl_note_sharp, rtl_note_dotted
  long rtl_octave, rtl_def_octave
  long rtl_def_bpm
  long rtl_volume, rtl_style
  long rtl_index, rtl_parser_state, rtl_token
  long snd_driver_duration, system_clock_duration
  long title_str[128]
  byte sbuffer[128]

  long song_data_ptr, playlist_top, playlist_cursor, playlist_num_songs

  
'///////////////////////////////////////////////////////////////////////
' OBJECTS //////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

  snd     : "NS_sound_drv_051_22khz_16bit.spin"      ' Sound driver
  term    : "tv_terminal_010.spin"
  gp      : "gamepad_drv_001.spin"   ' gamepad driver
    
'///////////////////////////////////////////////////////////////////////
' FUNCTIONS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

'// PUB start //////////////////////////////////////////////////////////
PUB start | i,j,k, index, x,y,z, length 

  'start sound driver
  snd.start(7)
  repeat 1000 ' give it a second to boot up...

  ' start gamepad
  gp.start

  'start the tv terminal
  term.start

  ' initialize playlist viewer
  playlist_top       := 0
  playlist_cursor    := 0
  playlist_num_songs := 41

  ' draw list for first time
  DrawPlayList(playlist_top, playlist_cursor)

  ' play first song :)
  song_data_ptr := Playlist_Get_RTTTL_Addr(@RTTTL_playlist_data, playlist_cursor)
  Play_RTTTL(song_data_ptr, 0)      

  ' enter main event loop
  repeat while 1
    if (gp.button(NES_START) or gp.button(NES_A) or gp.button(NES_B))
      ' play currently selected song
        song_data_ptr := Playlist_Get_RTTTL_Addr(@RTTTL_playlist_data, playlist_cursor)
        Play_RTTTL(song_data_ptr, 0)      

    if (gp.button(NES_UP))
      ' move cursor, redraw

      ' test for top of list
      if (--playlist_cursor < 0)
        playlist_cursor := 0

      ' test for scroll
      if (playlist_cursor < playlist_top)
        playlist_top := playlist_cursor

      DrawPlayList(playlist_top, playlist_cursor)
      snd.PlaySoundFM(2,   snd#SHAPE_SAWTOOTH, 2000, snd_driver_duration/4, 255, $1357_DDEF)

    elseif (gp.button(NES_DOWN))
      ' move cursor, redraw

      ' test for end of list
      if (++playlist_cursor => playlist_num_songs)
        playlist_cursor := playlist_num_songs-1

      ' test for scroll
      if (playlist_cursor > playlist_top+13)
         playlist_top++

      DrawPlayList(playlist_top, playlist_cursor)
      snd.PlaySoundFM(2,   snd#SHAPE_SAWTOOTH, 2200, snd_driver_duration/4, 255, $1357_DDEF)
      
    ' end main event loop

' ////////////////////////////////////////////////////////////////////////////

PUB DrawPlayList(_playlist_top, _playlist_cursor) | index , length
' draws the playlist to screen based on globals
  ' clear screen
  term.out(0)

  ' set color
  term.out(1)
  term.pstring(@title_string)  
  term.out(13)

  ' render strings out and highlight cursor position
  repeat index from playlist_top to playlist_top+13
    song_data_ptr := Playlist_Get_RTTTL_Addr(@RTTTL_playlist_data, index)
    Extract_RTTTL_Song_Title(song_data_ptr, @sbuffer, 32)

    if (_playlist_cursor == index)
      term.out(3) ' red
      bytemove(@sbuffer+1, @sbuffer, (length := strsize(@sbuffer))+1)
      sbuffer[0]        := $5B
      sbuffer[length+1] := $5D
      sbuffer[length+2] := 0
      
    else
      term.out(2) ' green
      bytemove(@sbuffer+2, @sbuffer, strsize(@sbuffer)+1)
      sbuffer[0] := ASCII_SPACE
      sbuffer[1] := ASCII_SPACE

    term.pstring(@sbuffer)
    term.out(13)

' /////////////////////////////////////////////////////////////////////////////

PUB Playlist_Get_RTTTL_Addr(playlist_base_addr, song_index)
' this function scans the playlist for the nth song and returns its starting address
' always assumes the nth indexed song is IN list!

' test for base case
if (song_index == 0)
  return(playlist_base_addr)

' else scan for song in list
repeat while (song_index-- > 0)
  playlist_base_addr += strsize(playlist_base_addr)+1

return (playlist_base_addr)  

' /////////////////////////////////////////////////////////////////////////////

PUB Extract_RTTTL_Song_Title(song_string_ptr, str_buffer_ptr, max_length) | index, tok, i
' simply extracts the song title up to the ":" or max_length characters and
' stores the results in str_buffer
index := 0

' look for ":" delimeter which indicates the end of the song title
repeat while ((tok := byte[song_string_ptr][index]) <> ASCII_SEMI)
  index++

' test if string longer than requested
if (index > max_length)
  index := max_length

' copy title string to destination storage    
bytemove(str_buffer_ptr, song_string_ptr, index)

' null terminate
byte [str_buffer_ptr][index] := 0

' return length of string returned
return (index)

' /////////////////////////////////////////////////////////////////////////////

PUB Toupper(ch)
' returns the uppercase of the sent character
if (ch => $61 and ch =< $7A)
  return(ch-32)
else
  return(ch)

' /////////////////////////////////////////////////////////////////////////////

PUB WhiteSpace
' consumes whitespace, lands on first non-white space character
repeat while ((rtl_token := byte[rtl_data_ptr][rtl_index]) == ASCII_SPACE)  
  rtl_index++

return(rtl_token)

' /////////////////////////////////////////////////////////////////////////////

PUB IsDigit(ch)
' tests if sent character is a number 0..9, returns integer 0..9
if (ch => ASCII_0 and ch =< ASCII_9)
  return (ch-ASCII_0)
else
  return(-1)  

' /////////////////////////////////////////////////////////////////////////////

PUB IsAlpha(ch)
' tests if sent character is a number a...zA...Z
ch := Toupper(ch)

if ( (ch => ASCII_A) and (ch =< ASCII_Z))
  return (ch)
else
  return(-1)  

' /////////////////////////////////////////////////////////////////////////////

PUB GetNumber | digit, sum, scale
' reads a number from the stream
sum    := 0
digit  := 0
scale  := 1

' consume any whitespace
WhiteSpace

' start reading number left to right
if (IsDigit((rtl_token := byte[rtl_data_ptr][rtl_index])) <> -1)
  repeat while ((digit := IsDigit((rtl_token := byte[rtl_data_ptr][rtl_index]))) <> -1)
    sum := scale*sum + digit ' continue summing
    scale := 10              ' scale 10's place   
    rtl_index++              ' advance to next character                           
  return(sum)
else
  return(-1)

' /////////////////////////////////////////////////////////////////////////////

PUB FindChar(ch) | findex
' finds first occuracnce of ch in stream returns its index and advances rtl_index

' save rtl_index
findex := rtL_index 

repeat while ((rtl_token := Toupper(byte[rtl_data_ptr][findex])) <> ch)
  findex++
  ' test for exaughsted string
  if (rtl_token == ASCII_NULL)
    ' character wasn't found at all, return -1
    return(-1)
    
'found it, update rtl_index
rtl_index := findex

return(rtl_index)
  
' /////////////////////////////////////////////////////////////////////////////  

PUB Play_RTTTL(_rtl_data_ptr, channel)
' plays an RTTTL (Ring Tones Text Transfer Language) file thru the sound driver, returns when complete
' performs NO error handling, file MUST be correct format!!!! To add error handling you would put catches
' on all the findchar's etc. and if they didn't find what they were supposed to or hit the end of file then
' there's an error. Also, function calls a set of "parser" helper functions above, these all affect globals
' and simply make the code easier to read and understand. Function plays song then returns to caller.
'
' PARMS:
' _rtl_data_ptr - address to RTTTL audio string
' channel       - channel to play ringtone thru

' point data pointer to data
rtl_data_ptr := _rtl_data_ptr

'set state to starting song
rtl_parser_state := RTL_START_SONG

' start parser off at beginning of string
rtl_index := 0

' read in header information

' eat white space 
WhiteSpace

' find name of song and consume, look for first ":"
FindChar(ASCII_SEMI)
rtl_index++ ' consume it

' search for default duration "d = <1|2|4|8|32>"
FindChar(ASCII_D)
rtl_index++ ' consume it

FindChar(ASCII_EQUALS)
rtl_index++ ' consume it

' now get number that represents the duration
rtl_def_duration := GetNumber 

' search for default octave "o = <4|5|6|7>"
FindChar(ASCII_O)
rtl_index++ ' consume it

FindChar(ASCII_EQUALS)
rtl_index++ ' consume it

' now get number that represents the octave
rtl_def_octave := GetNumber 

' search for default beats per minute " b=xxx"
FindChar(ASCII_B)
rtl_index++ ' consume it

FindChar(ASCII_EQUALS)
rtl_index++ ' consume it

' now get number that represents the beats per minute
rtl_def_bpm := GetNumber 

' search for volume (not supported)
' search for style (not supported)

' find ending ":" delimeter before song notes
FindChar(ASCII_SEMI)
rtl_index++ ' consume it

' enter main note parsing loop looking for notes in the format "[<duration>]<note>[<sharp#>][<octave>][<special-duration>]
' thus, the only thing it ALWAYS needs is the <note>, everything else is OPTIONAL, also assume no whitespace within note characters
repeat while (rtl_parser_state <> RTL_END_SONG)

  ' now parse next note, format is: "[<duration>] <note> [<sharp#>] [<octave>] [<special-duration>] 
  ' ["1"|"2"|"4"|"8"|"16"] <"P"|"C"|"C#"|"D"|"D#"|"E"|"F"|"F#"|"G"|"G#"|"A"|"A#"|"B"|"H"> ["4"|"5"|"6"|"7"] ["."] 
  ' So the only thing that is ALWAYS there is the <Note> field, the others are optional and if omitted, defaults are used.

  ' eat white space up to not defintion for sloppy RTTTL coding 
  WhiteSpace

  ' test for end of note sequence
  if (byte[rtl_data_ptr][rtl_index] == ASCII_NULL)
      'Debugger_Print_Watch($0, $54_49_58_45, $0)
      return rtl_index

  ' looking for duration modifier first?
  if ((rtl_duration := GetNumber) == -1)
    rtl_duration := rtl_def_duration ' no duration modifier, so fall back to default

  ' next character MUST be note, so assume it is
  rtl_note := Toupper(byte[rtl_data_ptr][rtl_index])

  ' print note
  'Debugger_Print_Watch($0, $45_54_4F_4E, rtl_token)

  ' advance token index and retrieve next token
  rtl_index++
 
  ' looking for # character
  rtl_token := byte[rtl_data_ptr][rtl_index]

  if (rtl_token == ASCII_SHARP)
    rtl_note_sharp := 1 ' set sharp true
    ' consume # character
    rtl_index++
  else
    rtl_note_sharp := 0  

  ' search for dotted character in INCORRECT location, but many RTTTL files have the dot AFTER the note, rather than after the octave modifier
  rtl_token := byte[rtl_data_ptr][rtl_index]

  if (rtl_token == ASCII_PERIOD)
    rtl_note_dotted := 1 ' set dotted true
    ' consume . character
    rtl_index++
  else
    rtl_note_dotted := 0  

  ' next is a potential octave modifier
  if ((rtl_octave := GetNumber) == -1)
    rtl_octave := rtl_def_octave ' no octave modifier, so fall back to default

  ' search for dotted character in second location
  rtl_token := byte[rtl_data_ptr][rtl_index]

  ' make sure we already didn't find dot
  if (rtl_note_dotted == 0)
    if (rtl_token == ASCII_PERIOD)
      rtl_note_dotted := 1 ' set dotted true
      ' consume . character
      rtl_index++
    else
      rtl_note_dotted := 0  

  ' consume last part of note which is "," delimeter, if its not found, then this is the last note, rtl_index will not be updated
  if (FindChar(ASCII_COMMA) <> -1)
    ' comma was found, so consume it
    rtl_index++

  ' what note is it? This all can be done with look up table and or with formulas,but too cryptic this is easier to understand and change
  ' so use case and mapping logic, so you can "see" what is going on! Only some notes have sharps
  case rtl_note

    ASCII_P:
      rtl_note := NOTE_PAUSE
      'Debugger_Print_Watch($0, $53_55_41_50, $0)

    ASCII_A:
      if (rtl_note_sharp==1)
        rtl_note := snd#NOTE_As4
      else  
        rtl_note := snd#NOTE_A4

    ASCII_B:
        rtl_note := snd#NOTE_B4

    ASCII_C:
      if (rtl_note_sharp==1)
        rtl_note := snd#NOTE_Cs4
      else  
        rtl_note := snd#NOTE_C4

    ASCII_D:                     
      if (rtl_note_sharp==1)
        rtl_note := snd#NOTE_Ds4
      else  
        rtl_note := snd#NOTE_D4

    ASCII_E:
      rtl_note := snd#NOTE_E4

    ASCII_F:
      if (rtl_note_sharp==1)
        rtl_note := snd#NOTE_Fs4
      else  
        rtl_note := snd#NOTE_F4

    ASCII_G:
      if (rtl_note_sharp==1)
        rtl_note := snd#NOTE_Gs4
      else  
        rtl_note := snd#NOTE_G4

    ASCII_H:
      rtl_note := snd#NOTE_B4

  ' now compute the time to play the note, this is not complex, but tricky, the idea is this one quarter note (1/4) equals 1 beat
  ' under normal music theory, so if we are playing at 60 beats per minute, that's 1 beat per second, thus a quarter note (1/4) would last 1 second
  ' an 1/8th note would last 1/2 a second, 1/16th note, 1/4th a second and so forth, thus the base beats per minute and the requested note length
  ' go together to make up the total duration the note should play, we couple this to the sound driver AND the timing loop, so the sound driver
  ' plays the note for the correct duration based on a 22 KHz sample rate, AND we need to "wait" for the sound to play and complete thus we have
  ' to do a a waitcnt at 80 MHz for a specific amount of time equal to the duration as well, so the note has time to complete before we go get another!
  ' here's the code....also, math has to be integer, so perform calcs in such a way to minimize truncation errors

  snd_driver_duration := (4*snd#SAMPLE_RATE*60) / (rtl_duration * rtl_def_bpm)
  system_clock_duration := ((4*FINAL_CLOCK_FREQ) / (rtl_duration * rtl_def_bpm) ) * 60   

  ' adjust for dotted modifier
  if (rtl_note_dotted==1)
    ' add 1/2 length to timing
    snd_driver_duration   := snd_driver_duration + (snd_driver_duration >> 1) 
    system_clock_duration := system_clock_duration + (system_clock_duration >> 1)

  ' play the note
  if (rtl_note <> NOTE_PAUSE)
    ' Debugger_Print_Watch($0, $55_41_50_4E, $1)

    ' now determine what "scale" this note should play in - 4,5,6,7,8?
    ' we need to derive the frequency based on the scale, if the scale is 4 then we are good since the note is
    ' in the 4th scale already, but if its 5, then we need to multiply by 2, 6 we need to multiple by 4, etc. thus
    ' Take base note*2^scale, where scale is 0 based 0,1,2,3,4
    rtl_note := rtl_note * (1 << (rtl_octave-4))
    
    snd.PlaySoundFM(channel,   snd#SHAPE_SQUARE, rtl_note, snd_driver_duration, 255, $1357_DDEF)
    snd.PlaySoundFM(channel+1,   snd#SHAPE_SINE, (rtl_note/2), snd_driver_duration, 128, $1357_DDEF)
  else
    rtl_note := rtl_note
    ' Debugger_Print_Watch($0, $53_55_41_50, $1)

  ' delay long enough for note to complete...   
  waitcnt (cnt + system_clock_duration)  

' return to caller
return rtl_index

' end Play_RTTTL


DAT

' ring tones (some duplicates), only about 50-60 ringtones can be active in the DAT section due to memory limitations of Pchip, so
' simply comment in/out chunks of them and the player will read them in, just make sure to leave the "RTTTL_playlist_data" line alone!
RTTTL_playlist_data ' <---  leave this label, player needs it to find starting address of playlist

        byte    "Halloween:d=4,o=5,b=180:8d6,8g,8g,8d6,8g,8g,8d6,8g,8d#6,8g,8d6,8g,8g,8d6,8g,8g,8d6,8g,8d#6,8g,8c#6,8f#,8f#,8c#6,8f#,8f#,8c#6,8f#,8d6,8f#,8c#6,8f#,8f#,8c#6,8f#,8f#,8c#6,8f#,8d6,8f#",0
        byte    "Adams Family:d=4,o=5,b=190:8c,f,8a,f,8c,b4,2g,8f,e,8g,e,8e4,a4,2f,8c,f,8a,f,8c,b4,2g,8f,e,8c,d,8e,1f,8c,8d,8e,8f,1p,8d,8e,8f#,8g,1p,8d,8e,8f#,8g,p,8d,8e,8f#,8g,p,8c,8d,8e,8f",0
        byte    "Argentina:d=4,o=5,b=70:8e.4,8e4,8e4,8e.4,8f4,8g4,8a4,g4,8p,8g4,8a4,8a4,8g4,c,g4,8f4,e.4,8p,8e4,8f4,8g4,8d4,d4,8d4,8e4,8f4,c4,16p,8c4,8d4,8c4,8e4,g4,16p,8g4,8g4,8a4,c,16p",0
        byte    "Beverly Hills Cop:d=4,o=5,b=160:f#,8a.,8f#,16f#,8b,8f#,8e,f#,8c#.6,8f#,16f#,8d6,8c#6,8a,8f#,8c#6,8f#6,16f#,8e,16e,8c#,8g#,f#",0        
        byte    "Close Encounters:d=16,o=5,b=125:d,p,e,p,c,p.,c4,p,g4,1p., d6,p,e6,p,c6,p.,c,p,g,1p.",0
        byte    "Cantina:d=4,o=5,b=250:8a,8p,8d6,8p,8a,8p,8d6,8p,8a,8d6,8p,8a,8p,8g#,a,8a,8g#,8a,g,8f#,8g,8f#,f.,8d.,16p,p.,8a,8p,8d6,8p,8a,8p,8d6,8p,8a,8d6,8p,8a,8p,8g#,8a,8p,8g,8p,g.,8f#,8g,8p,8c6,a#,a,g",0
        byte    "Barbie Girl:d=4,o=5,b=125:8g#,8e,8g#,8c#6,a,p,8f#,8d#,8f#,8b,g#,8f#,8e,p,8e,8c#,f#,c#,p,8f#,8e,g#,f#",0
        byte    "Bogey:d=4,o=5,b=140:8g,8e,p,8p,8e,8f,8g,e6,e6,2c6,8g,8e,p,8p,8e,8f,8e,g,g,2f,8f,8d,p,8p,8d,8e,8f,8g,8e,p,8p,8e,8f#,8e,8d,8g,8p,8e,8f#,8d,8p,8a,8g.,16f#,8g,8a,8g,8f,8e,8d,8c",0                
        byte    "Coca-cola:d=4,o=5,b=125:8f#6,8f#6,8f#6,8f#6,g6,8f#6,e6,8e6,8a6,f#6,d6,2p",0
        byte    "Crypt:d=4,o=5,b=160:d#,f#,a,8p,8b,a#,f#,d#,8p,8b4,a#4,d#,f#,a,2b4,8p,a#4,d,f,8p,8f#,g#,b,a#,8p,8g#,f#,f,d#,d,2d#,1p,1p,p.,f,g#,b,8p,8c#6,c6,g#,f,8p,8c#,c,f,g#,b,1c#,c,e,g,8p,8g#,a#,c#6,c6,8p,8a#,g#,g,f,e,2f,16p",0
        byte    "Dualing Banjos:d=4,o=5,b=200:8c#,8d,e,c#,d,b4,c#,d#4,b4,p,16c#6,16p,16d6,16p,8e6,8p,8c#6,8p,8d6,8p,8b,8p,8c#6,8p,8a,8p,b,p,a4,a4,b4,c#,d#4,c#,b4,p,8a,8p,8a,8p,8b,8p,8c#6,8p,8a,8p,8c#6,8p,8b",0
        byte    "Dallas:d=4,o=5,b=125:8e,a.,8e,e.6,8a,c#6,8b,8c#6,a,e,a,f#6,e6,8c#6,8d6,2e.6,8p,8e,a,f#6,e6,8c#6,8d6,e6,8b,8c#6,a,e,a,8c#6,8d6,b.,8a,2a",0
        byte    "Dark:d=4,o=5,b=140:8f#6,8e6,2f#6,16e6,16d#6,16d6,16b,a#,1b,8f#,8e,2f#,8c#,8d,8a#4,1b4,8f#,8e,2f#,16e,16d#,16d,16b4,a#4,1b4,8f#,8e,2f#,c#,2d,2e4,1b4",0
        byte    "Davy Crockett:d=4,o=5,b=160:f,8f.,16g,8a.,16g,8f.,16c,d,f,2c,f,g,a,8g.,16f,g,8g.,16a,2g,c,8c.,16c,f,8c.,16c,d,8d.,16d,2g,e,8e.,16e,e,8e.,16d,c,8d.,16e,2f,a,2c.6,d.6,8d6,8c6,a.,8c.,16c,8c.,16c,e,g,2f.,p,a,2c.6,d.6,8d6,8c6,a.,8c.,16c,8c.,16c,e,g,2f.",0
        byte    "Entertainer:d=4,o=5,b=140:8d,8d#,8e,c6,8e,c6,8e,2c.6,8c6,8d6,8d#6,8e6,8c6,8d6,e6,8b,d6,2c6,p,8d,8d#,8e,c6,8e,c6,8e,2c.6,8p,8a,8g,8f#,8a,8c6,e6,8d6,8c6,8a,2d6",0
        byte    "Flintstones:d=4,o=5,b=200:g#,c#,8p,c#6,8a#,g#,c#,8p,g#,8f#,8f,8f,8f#,8g#,c#,d#,2f,2p,g#,c#,8p,c#6,8a#,g#,c#,8p,g#,8f#,8f,8f,8f#,8g#,c#,d#,2c#",0                
        byte    "FunkyTown:d=4,o=4,b=125:8c6,8c6,8a#5,8c6,8p,8g5,8p,8g5,8c6,8f6,8e6,8c6,2p,8c6,8c6,8a#5,8c6,8p,8g5,8p,8g5,8c6,8f6,8e6,8c6",0
        byte    "Georgia on my mind:d=4,o=5,b=90:8e,2g.,8p,8e,2d.,8p,p,e,a,e,2d.,8c,8d,e,g,b,a,f,f,8e,e,1c",0
        byte    "Hitchcock:d=4,o=5,b=200:16c,16p,16f4,8p,8f,32g,32p,16f,32p,16e,32p,16d,32p,16e,8p,16f,32p,16g,8p.,16c,16p,16f4,8p,8f,32g,32p,16f,32p,16e,32p,16d,32p,16e,8p,16f,32p,16g,8p.,16c,16p,16f4,8p,16g#,32p,8c6,16p,16a#,32p,16g#,8p,16c6,32p,8d#6,16p,16c#6,32p,16c6,8p,16d#6,32p,8g6,16p,16f6,32p,16e6,32p,16c#6,32p,16c6,32p,16a#,32p,16g#,32p,16g,32p,8f4",0
        byte    "Indiana Jones:d=4,o=5,b=250:e,8p,8f,8g,8p,1c6,8p.,d,8p,8e,1f,p.,g,8p,8a,8b,8p,1f6,p,a,8p,8b,2c6,2d6,2e6,e,8p,8f,8g,8p,1c6,p,d6,8p,8e6,1f.6,g,8p,8g,e.6,8p,d6,8p,8g,e.6,8p,d6,8p,8g,f.6,8p,e6,8p,8d6,2c6",0
        byte    "Imperial:d=4, o=5, b=120:e, e, e, 8c, 16p, 16g, e, 8c, 16p, 16g, e, p, b, b, b, 8c6, 16p, 16g, d#, 8c, 16p, 16g, e, 8p",0
        byte    "Jamesbond 007:d=8,o=5,b=160:e,g,p,d#6,d6,4p,g,a#,b,2p.,g,16a,16g,f#,4p,b4,e,c#,1p",0
        byte    "Kill me softly:d=4,o=5,b=120:p,8e,f,g,8a,a,8g,d,g.,p,8p,8a,g,8f,8e,8e,8f,2c,p,8e,f,g,8a,a,8g,a,b,8b,8c6,8b,16a,8g,16a,2a,2a.",0                
        byte    "Knight Rider:d=4,o=5,b=63:16e,32f,32e,8b,16e6,32f6,32e6,8b,16e,32f,32e,16b,16e6,d6,8p,p,16e,32f,32e,8b,16e6,32f6,32e6,8b,16e,32f,32e,16b,16e6,f6,p",0
        byte    "Macarena:d=4,o=5,b=180:f,8f,8f,f,8f,8f,8f,8f,8f,8f,8f,8a,8c,8c,f,8f,8f,f,8f,8f,8f,8f,8f,8f,8d,8c,p,f,8f,8f,f,8f,8f,8f,8f,8f,8f,8f,8a,p,2c.6,a,8c6,8a,8f,p,2p",0
        byte    "Mission Impossible:d=4,o=6,b=100:32d,32d#,32d,32d#,32d,32d#,32d,32d#,32d,32d,32d#,32e,32f,32f#,32g,16g,8p,16g,8p,16a#,16p,16c,16p,16g,8p,16g,8p,16f,16p,16f#,16p,16g,8p,16g,8p,16a#,16p,16c,16p,16g,8p,16g,8p,16f,16p,16f#,16p,16a#,16g,2d,32p,16a#,16g,2c#,32p,16a#,16g,2c,16p,16a#5,16c",0
        byte    "Munsters:d=4,o=5,b=160:d,8f,8d,8g#,8a,d6,8a#,8a,2g,8f,8g,a,8a4,8d#4,8a4,8b4,c#,8d,p,c,c6,c6,2c6,8a#,8a,8a#,8g,8a,f,p,g,g,2g,8f,8e,8f,8d,8e,2c#,p,d,8f,8d,8g#,8a,d6,8a#,8a,2g,8f,8g,a,8d#4,8a4,8d#4,8b4,c#,2d",0
        byte    "Light My Fire:d=4,o=5,b=140:8b,16g,16a,8b,8d6,8c6,8b,8a,8g,8a,16f,16a,8c6,8f6,16d6,16c6,16a#,16g,8g#,8g,8g#,16g,16a,8b,8c#6,16b,16a,16g,16f,8e,8f,1a,a",0
        byte    "Newyear:d=4,o=5,b=125:a4,d.,8d,d,f#,e.,8d,e,8f#,8e,d.,8d,f#,a,2b.,b,a.,8f#,f#,d,e.,8d,e,8f#,8e,d.,8b4,b4,a4,2d,16p",0
        byte    "Pink Panther:d=4,o=5,b=160:8d#,8e,2p,8f#,8g,2p,8d#,8e,16p,8f#,8g,16p,8c6,8b,16p,8d#,8e,16p,8b,2a#,2p,16a,16g,16e,16d,2e",0
        byte    "Peanuts:d=4,o=5,b=160:f,8g,a,8a,8g,f,2g,f,p,f,8g,a,1a,2p,f,8g,a,8a,8g,f,2g,2f,2f,8g,1g",0
        byte    "Star Wars:d=4,o=5,b=200:8f,8f,8f,2a#.,2f.6,8d#6,8d6,8c6,2a#.6,f.6,8d#6,8d6,8c6,2a#.6,f.6,8d#6,8d6,8d#6,2c6,p,8f,8f,8f,2a#.,2f.6,8d#6,8d6,8c6,2a#.6,f.6,8d#6,8d6,8c6,2a#.6,f.6,8d#6,8d6,8d#6,2c6",0
        byte    "Star Trek:d=4,o=5,b=63:8f.,16a#,d#.6,8d6,16a#.,16g.,16c.6,f6",0
        byte    "Super Man:d=4,o=5,b=180:8g,8g,8g,c6,8c6,2g6,8p,8g6,8a.6,16g6,8f6,1g6,8p,8g,8g,8g,c6,8c6,2g6,8p,8g6,8a.6,16g6,8f6,8a6,2g.6,p,8c6,8c6,8c6,2b.6,g.6,8c6,8c6,8c6,2b.6,g.6,8c6,8c6,8c6,8b6,8a6,8b6,2c7,8c6,8c6,8c6,8c6,8c6,2c.6",0
        byte    "Smoke:d=4,o=5,b=112:c,d#,f.,c,d#,8f#,f,p,c,d#,f.,d#,c,2p,8p,c,d#,f.,c,d#,8f#,f,p,c,d#,f.,d#,c,p",0
        byte    "Soap:d=4,o=5,b=125:g,8a,8c6,8p,8a,c6,p,8a,8g,8e,8c,p,g,8a,8c6,p,b,p,8a,8g,8e,8c#,2p,p,8a,8c6,2p,p,8a,8g,2p,8a,8g,8e,c",0
        byte    "Scooby Doo:d=4,o=5,b=160:8e6,8e6,8d6,8d6,2c6,8d6,e6,2a,8a,b,g,e6,8d6,c6,8d6,2e6,p,8e6,8e6,8d6,8d6,2c6,8d6,f6,2a,8a,b,g,e6,8d6,2c6",0
        byte    "Take On Me:d=4,o=4,b=160:8f#5,8f#5,8f#5,8d5,8p,8b,8p,8e5,8p,8e5,8p,8e5,8g#5,8g#5,8a5,8b5,8a5,8a5,8a5,8e5,8p,8d5,8p,8f#5,8p,8f#5,8p,8f#5,8e5,8e5,8f#5,8e5,8f#5,8f#5,8f#5,8d5,8p,8b,8p,8e5,8p,8e5,8p,8e5,8g#5,8g#5,8a5,8b5,8a5,8a5,8a5,8e5,8p,8d5,8p,8f#5,8p,8f#5,8p,8f#5,8e5,8e5",0
        byte    "T Birds:d=4,o=4,b=125:8g#5,16f5,16g#5,a#5,8p,16d#5,16f5,8g#5,8a#5,8d#6,16f6,16c6,8d#6,8f6,2a#5,8g#5,16f5,16g#5,a#5,8p,16d#5,16f5,8g#5,8a#5,8d#6,16f6,16c6,8d#6,8f6,2g6,8g6,16a6,16e6,g6,8p,16e6,16d6,8c6,8b5,8a.5,16b5,8c6,8e6,2d6,8d#6,16f6,16c6,d#6,8p,16c6,16a#5,8g#5,8g5,8f.5,16g5,8g#5,8a#5,8c6,8a#5,8g5,8d#5",0
        byte    "X-files:d=4,o=5,b=125:e,b,a,b,d6,2b.,1p,e,b,a,b,e6,2b.,1p,g6,f#6,e6,d6,e6,2b.,1p,g6,f#6,e6,d6,f#6,2b.,1p,e,b,a,b,d6,2b.,1p,e,b,a,b,e6,2b.,1p,e6,2b.",0
        byte    "Yaketysax:d=4,o=5,b=125:8d.,16e,8g,8g,16e,16d,16a4,16b4,16d,16b4,8e,16d,16b4,16a4,16b4,8a4,16a4,16a#4,16b4,16d,16e,16d,g,p,16d,16e,16d,8g,8g,16e,16d,16a4,16b4,16d,16b4,8e,16d,16b4,16a4,16b4,8d,16d,16d,16f#,16a,8f,d,p,16d,16e,16d,8g,16g,16g,8g,16g,16g,8g,8g,16e,8e.,8c,8c,8c,8c,16e,16g,16a,16g,16a#,8g,16a,16b,16a#,16b,16a,16b,8d6,16a,16b,16d6,8b,8g,8d,16e6,16b,16b,16d,8a,8g,g",0

' count up the songs you have in your list and make sure you update this line of code in the init with it
'  playlist_num_songs := xx

        

{


        
        byte    "c64-intro:d=8,o=5,b=200:8f,8g#,8a#,8p,8g#,8p,8d#,8f,8g#,8c6,8a#,8p,8g#,8p,8d#,8p",0
        byte    "thunderstr:d=16,o=5,b=160:c6,c,a#,c,a,c,a#,c,a,c,g,c,a,c,f,c,g,c,e,c,f,c,e,c,f,c,e,c,f,c,e,c",0  
        byte    "nuke&cosmo:d=16,o=5,b=160:c,p,d,p,d#,p,c,p,d,p,d#,d,p,d,c,p,g4,p,g#4,p,c,p,g4,p,g#4,p,c,g4,p,g4,g#4,p,g#4,p,g4,p,d#4,p,g#4,p,g4,p,d#4,g#4,p,d#4,g#4,p,b4,p,d5,p,g5,p,b4,d5,g4,f4,d#4,32d4,32p,32g4,32p,32f4,32p,32d#4,32p,32d4,32p",0
        byte    "wizardry:d=16,o=6,b=160:d#,8p,d#,d,p,c,p,g,d,b5,d,g5,p,d#,f,g,8p,g,f,p,d#,p,a#,f,d,f,a#5,p,c,d,d#,p,d#,p,d#,d,c,p,d,p,d,p,d,d#,d,b5,c,2p,g#5,c,d#,g#,a#5,d,f,a#",0

        byte    "bomberman:d=32,o=6,b=125:f,p,g5,p,c,p,f,p,e,16p.,c,16p.,a#5,16p.,c,16p.,g5,p,8p.,f,p,g,p,d#,p,e,p,c,p,p,p,2p,8p,f,p,g5,p,c,p,f,p,e,16p.,c,16p.,a#5,16p.,c,16p.,g5,p,8p.,f5,p,g5,p,d#5,p,e5,p,c5,p,p,p,2p,8p",0
        byte    "radioloud:d=32,o=6,b=100:c5,c,16p,g5,g,16p,c5,c,16p,g5,g,f5,f,d#5,d#,16p,d#5,d#,16p,d#5,d#,8p,32p,d#5,d#,d#5,d#,16p,g5,g,16p,d#5,d#,16p,g5,g,d#5,d#,c5,c,16p,c5,c,16p,c5,c,4p",0
        byte    "alainclark:d=16,o=4,b=100:b,p,d5,b,p,a,p,a,a,p,f#,p,b,8p.,1p",0
        byte    "24show:d=32,o=5,b=140:f,f,16p,f,f,8p.,b,b,b,b,b4,b4,b4,b4,b4,b4,b4,b4,1p.",0
        byte    "thatsit:d=32,o=4,b=100:a#,16p.,f,p,f,p,g,16p.,f,8p.,a,16p.,16a#,4p,d5,16p.,a,p,a,p,b,16p.,a,8p.,c#5,16p.,16d5,4p",0

        byte    "90210:d=4,o=5,b=140:8f,8a#,8c6,d.6,2d6,p,8f,8a#,8c6,8d6,8d#6,f6,f.6,2a#.,8f,8a#,8c6,8d6,8d#6,8f6,8g6,f6,8d#6,d#6,d6,2c.6,8a#,a,a#.,g6,8f6,8d#6,8d6,8d#6,8d6,8a#,f",0
        byte    "Abdelazer:d=4,o=5,b=160:2d,2f,2a,d6,8e6,8f6,8g6,8f6,8e6,8d6,2c#6,a6,8d6,8f6,8a6,8f6,d6,2a6,g6,8c6,8e6,8g6,8e6,c6,2a6,f6,8b,8d6,8f6,8d6,b,2g6,e6,8a,8c#6,8e6,8c6,a,2f6,8e6,8f6,8e6,8d6,c#6,f6,8e6,8f6,8e6,8d6,a,d6,8c#6,8d6,8e6,8d6,2d6",0
        byte    "TakeOnMe:d=4,o=4,b=160:8f#5,8f#5,8f#5,8d5,8p,8b,8p,8e5,8p,8e5,8p,8e5,8g#5,8g#5,8a5,8b5,8a5,8a5,8a5,8e5,8p,8d5,8p,8f#5,8p,8f#5,8p,8f#5,8e5,8e5,8f#5,8e5,8f#5,8f#5,8f#5,8d5,8p,8b,8p,8e5,8p,8e5,8p,8e5,8g#5,8g#5,8a5,8b5,8a5,8a5,8a5,8e5,8p,8d5,8p,8f#5,8p,8f#5,8p,8f#5,8e5,8e5",0

        byte    "Auld L S:d=4,o=5,b=100:g,c.6,8c6,c6,e6,d.6,8c6,d6,8e6,8d6,c.6,8c6,e6,g6,2a.6,a6,g.6,8e6,e6,c6,d.6,8c6,d6,8e6,8d6,c.6,8a,a,g,2c.6",0

        byte    "Black Bear:d=4,o=5,b=180:d#,d#,8g.,16d#,8a#.,16g,d#,d#,8g.,16d#,8a#.,16g,f,8c.,16b4,c,8f.,16d#,8d.,16d#,8c.,16d,8a#.4,16c,8d.,16a#4,d#,d#,8g.,16d#,8a#.,16g,d#,d#,8g.,16d#,8a#.,16g,f,f,f,8g.,16f,d#,g,2d#",0
        byte    "Bebopalula:d=4,o=5,b=180:2p,2a,a,8a,8e,g,a,a,a,g,a,8p,8a,8a,8e,g,8a,8a,a,a,g,a",0
        byte    "Be-Bop-A-Lula:d=4,o=5,b=180:2p,2a,a,8a,8e,g,a,a,a,g,a,8p,8a,8a,8e,g,8a,8a,a,a,g,a",0 
        byte    "Birdy S:d=4,o=5,b=100:16g,16g,16a,16a,16e,16e,8g,16g,16g,16a,16a,16e,16e,8g,16g,16g,16a,16a,16c6,16c6,8b,8b,8a,8g,8f,16f,16f,16g,16g,16d,16d,8f,16f,16f,16g,16g,16d,16d,8f,16f,16f,16g,16g,16a,16b,8c6,8a,8g,8e,c",0

        byte    "Bolero:d=4,o=5,b=80:c6,8c6,16b,16c6,16d6,16c6,16b,16a,8c6,16c6,16a,c6,8c6,16b,16c6,16a,16g,16e,16f,2g,16g,16f,16e,16d,16e,16f,16g,16a,g,g,16g,16a,16b,16a,16g,16f,16e,16d,16e,16d,8c,8c,16c,16d,8e,8f,d,2g",0
        byte    "Bulletme:d=4,o=5,b=112:b.6,g.6,16f#6,16g6,16f#6,8d.6,8e6,p,16e6,16f#6,16g6,8f#.6,8g6,8a6,b.6,g.6,16f#6,16g6,16f#6,8d.6,8e6,p,16c6,16b,16a,16b",0
        byte    "careaboutus:d=4,o=5,b=125:16f,16e,16f,16e,16f,16e,8d,16e,16d,16e,16d,16e,16d,16c,16d,d",0 
        byte    "Children:d=4,o=5,b=63:8p,f.6,1p,g#6,8g6,d#.6,1p,g#6,8g6,c.6,1p,g#6,8g6,g#.,1p,16f,16g,16g#,16c6,f.6,1p,g#6,8g6,d#.6,1p,16c#6,16c6,c#6,8c6,g#,2p,g.,g#,8c6,f.",0
        byte    "Children2:d=4,o=5,b=70:16e,16f,16g,16a,16b,16c6,16d6,16d6,16d6,c6,e6,8d6,8c6,16b,16c6,32g,32a,16e,f,f,8g,8a,8b,16c6,8b,16d6,16a,16b,16d6,16d6,16a,16b,16c6,16b,16f,16b,8a,f,e,8c6,d,8b,e,8a,8e,8f,8g,8a,8b",0

        byte    "countdown:d=4,o=5,b=125:p,8p,16b,16a,b,e,p,8p,16c6,16b,8c6,8b,a,p,8p,16c6,16b,c6,e,p,8p,16a,16g,8a,8g,8f#,8a,g.,16f#,16g,a.,16g,16a,8b,8a,8g,8f#,e,c6,2b.,16b,16c6,16b,16a,1b",0
        byte    "DasBoot:d=4,o=5,b=100:d#.4,8d4,8c4,8d4,8d#4,8g4,a#.4,8a4,8g4,8a4,8a#4,8d,2f.,p,f.4,8e4,8d4,8e4,8f4,8a4,c.,8b4,8a4,8b4,8c,8e,2g.,2p",0

        byte    "Deutschlandlied:d=4,o=5,b=160:2g,8a,b,a,c6,b,8a,8f#,g,e6,d6,c6,b,a,8b,8g,2d6,2g,8a,b,a,c6,b,8a,8f#,g,e6,d6,c6,b,a,8b,8g,2d6,a,b,8a,8f#,d,c6,b,8a,8f#,d,d6,c6,2b,8b,c#6,8c#6,8d6,2d6,2g6,8f#6,8f#6,8e6,d6,2e6,8d6,8d6,8c6,b,2a,16b,16c6,8d6,8e6,8c6,8a,2g,8b,8a,2g",0
        byte    "Do you hear the people sing:d=4,o=5,b=140:8e.6,16d6,8c.6,16d6,8e.6,16f6,g6,8e6,8d6,8c6,8b.,16a,8b.,16c6,g,8a,8g,8f,8e.,16g,8c.6,16e6,8d.6,16c#6,8d.6,16a,8c.6,16b,8b.,16c6,d6",0
        byte    "don'tcare:d=4,o=5,b=125:16f,16e,16f,16e,16f,16e,8d,16e,16d,16e,16d,16e,16d,16c,16d,d",0
        byte    "don't wanna miss a thing:d=4,o=5,b=125:2p,16a,16p,16a,16p,8a.,16p,a,16g,16p,2g,16p,p,8p,16g,16p,16g,16p,16g,8g.,16p,c6,16a#,16p,a,8g,f,g,8d,8f.,16p,16f,16p,16c,8c,16p,a,8g,16f,16p,8f,16p,16c,16p,g,f",0
        byte    "dualingbanjos:d=4,o=5,b=200:8c#,8d,e,c#,d,b4,c#,d#4,b4,p,16c#6,16p,16d6,16p,8e6,8p,8c#6,8p,8d6,8p,8b,8p,8c#6,8p,8a,8p,b,p,a4,a4,b4,c#,d#4,c#,b4,p,8a,8p,8a,8p,8b,8p,8c#6,8p,8a,8p,8c#6,8p,8b",0
        byte    "Dustman:d=4,o=5,b=140:8a.,16a,16b,16p,16c6,16p,8c#6,p,8e6,16c#6,16p,16c#6,16p,16c#6,16p,16c#6,16p,16c#6,16p,c#6,16c#6,16p,16c#6,16p,16c#6,16p,16d6,16p,16c#6,16p,b,16b,16p,16b,16p,16b,16p,16b,16p,16b,16p,16b,16p,16b,16p,8b.,16p,16e6,16e6,16e6,16p,16d6,16p,16c#6,16p,16b,16p,a",0

        byte    "Equidor:d=4,o=5,b=140:8g.,8d.,8a#,8a,8c6,8a,8f,8g.,8d.,8a#,8a,8c6,8a,8f,8a#.,8f.,8d6,8c6,8d6,8c6,8a,8a#.,8g.,8a#,8a,8a#,8a,8f",0
        byte    "Eternally:d=4,o=5,b=112:b,8b,8a,8b,8c6,a,8a,8g,8a,8b,g,8g,8f#,8e,8d#,2e",0

        byte    "Exodus:d=4,o=5,b=70:8c#,f#.,8c#6,b.,8f#,8a,8b,8g#.,16e,f#.,8c#6,e.6,8d#6,8e6,8f#6,8d#.6,16b,2c#6",0
        byte    "Fawlty:d=4,o=5,b=125:8b,8c6,8d6,8c#6,8d6,8c#6,8d6,8g6,e.6,8d6,8c6,8b,8c6,8b,8c6,8b,8c6,8f#6,d.6,8c6,8b,8a,8g,8f#,8g,8f#,8g,8d6,8c6,8b,8c6,8b,8a,8g,8f#,8g,8e,8f#,d,8c6,8d6,8b,8c6,a",0

        byte    "R Friends:d=4,o=5,b=80:c,g,a#4,f,c,g,a#4,8a#,8e,c,g,a#4,f,c,g,a#4,8a#,8e",0
        byte    "Fun2Remix:d=4,o=5,b=320:c6,8c6,g,8g,a,a#,a,g,a,c6,8c6,g,8g,a,a#,a,g,a,a#,8a#,f,8f,g,g#,g,f,g,c6,8c6,c6,8c6,8c6,8c6,c6,c6,c6,c6",0
 
        byte    "Funky:d=4,o=5,b=125:8c6,8c6,8a#,8c6,8p,8g,8p,8g,8c6,8f6,8e6,8c6,2p,8c6,8c6,8a#,8c6,8p,8g,8p,8g,8c6,8f6,8e6,8c6",0
        byte    "National Anthem:d=4,o=5,b=140:g6,g6,a6,f#.6,8g6,a6,b6,b6,c7,b.6,8a6,g6,a6,g6,f#6,g6",0
        byte    "Greensleaves:d=4,o=5,b=140:g,2a#,c6,d.6,8d#6,d6,2c6,a,f.,8g,a,2a#,g,g.,8f,g,2a,f,2d,g,2a#,c6,d.6,8e6,d6,2c6,a,f.,8g,a,a#.,8a,g,f#.,8e,f#,2g",0

        byte    "HeyBaby:d=4,o=5,b=900:8a4,16a#4,16b4,16c,16c#,16d,16d#,16e,16f,16f#,16g,16g#,16a,16a#,16b,16c6,8c#6,16d6,16d#6,16e6,16f6,p,p,16a4,16a#4,16b4,16c,16c#,16d,16d#,16e,16f,16f#,16g,16g#,16a,16a#,16b,16a#,16a,16g#,16g,16f#,16f,16e,16d#,16d,16c#,16c,16b4,16a#4,16a4",0

        byte    "Ickley:d=4,o=5,b=100:8d,8g.,16g,8g,8d,g,8p,8a,8b.,16b,8b,8a,b,8p,8b,a,g,g,f#,2g",0

        byte    "GirlFromIpane:d=4,o=5,b=160:g.,8e,8e,d,g.,8e,e,8e,8d,g.,e,e,8d,g,8g,8e,e,8e,8d,f,d,d,8d,8c,e,c,c,8c,a#4,2c",0
        byte    "I swear:d=4,o=5,b=125:2p,p,8b,8a.,16f#,8e,p,8p,8f#,8g#,a,8a,8a,a,8c#,8d,2e,8p,8f#,8g#,2e",0
        byte    "Itchy:d=4,o=5,b=160:8c6,8a,p,8c6,8a6,p,8c6,8a,8c6,8a,8c6,8a6,p,8p,8c6,8d6,8e6,8p,8e6,8f6,8g6,p,8d6,8c6,d6,8f6,a#6,a6,2c7",0
        byte    "Jesus:d=4,o=5,b=100:f,8d,2a#4,g,8d#,2a#4,g#,8f,8g#,g,8f,8d#,f,8d,2a#4",0
        byte    "killmesoft:d=4,o=5,b=90:p,8e,f,g,8a,a,8g,d,g.,p,8p,8a,g,8f,8e,8e,8f,2c,p,8e,f,g,8a,a,8g,a,b,8b,8c6,8b,16a,8g,16a,2a,2a.",0





        byte    "Lazy:d=4,o=5,b=160:8d.4,8f4,16d4,8g4,16f4,8d.4,8f4,16d4,8g4,16f4,8d4,8p,8p",0
        byte    "Walk of Life:d=4,o=5,b=160:b.,b.,p,8p,8f#,8g,b,8g,8f,e.,e.,p,2p,p,8f,8g,b.,b.,p,8p,8f,8g,b,8g,f,e.,e.,p,8p,8f,8g,b,8g,8f,8e",0
        byte    "Little Wing:d=4,o=5,b=63:2p,p,8e,8g,8a,a.,p,8a,8g,8g,e.,p,8d,8c,8d,16e,8d.,8p,8d,8d,8c,2a",0
        byte    "Looney:d=4,o=5,b=140:c6,8f6,8e6,8d6,8c6,a.,8c6,8f6,8e6,8d6,8d#6,e.6,8e6,8e6,8c6,8d6,8c6,8e6,8c6,8d6,8a,8c6,8g,8a#,8a,8f",0
        byte    "losing:d=4,o=5,b=63:2p,8b,8c#6,8b,8f#,a.,8a,8a,a,a,a.,8b,8c#6,8b,8f#,a.,8a,8a,a,a.,8b,8c#6,8b,8f#,a.,8a,8a,a,a.,8b,8c#6,8b,8f#,a,a,8a,a,8g#,2g#",0
        byte    "Lulay Lula:d=4,o=4,b=100:d6,d6,c#6,2d6,f6,8e6,8e6,e6,d6,2c#.6,d6,e6,f6,g6,2e6,2d6,a6,2g6,f6,2e6,f6,8e6,8e6,e6,d6,2c#.6,d6,e6,f6,g6,2e6,2f#6",0
 

        byte    "Barbie girl:d=4,o=5,b=125:8g#,8e,8g#,8c#6,a,p,8f#,8d#,8f#,8b,g#,8f#,8e,p,8e,8c#,f#,c#,p,8f#,8e,g#,f#,8g#,8e,8g#,8c#6,a,p,8f#,8d#,8f#,8b,g#,8f#,8e,p,8e,8c#,f#,c#,p,8f#,8e,g#,f#,8g#,8e,8g#,8c#6,a,p,8f#,8d#,8f#,8b,g#,8f#,8e,p,8e,8c#,f#,c#,p,8f#,8e,g#,f#",0
        byte    "Match of the day:d=4,o=5,b=100:8c,8f,8a,8c.6,16a,8a,8a,8a,a,8a#,8c.6,16a,8g,8a,8a#,8c,8e,8g,8a#.,16g,8g,8g,8g,g,8a,8a#.,16g,8f,8g,8a,8c,8f,8a,8c.6,16a,8a,8a,8a,a,8a#,8c.6,16a,8a#,8c6,d6,8d6,8e6,8f6,16f6,8e6,16e6,8d6,8f6,8c6,8c6,8d6,8c6,16a#,8a,16a,8g,f",0
        byte    "missathing:d=4,o=5,b=125:2p,16a,16p,16a,16p,8a.,16p,a,16g,16p,2g,16p,p,8p,16g,16p,16g,16p,16g,8g.,16p,c6,16a#,16p,a,8g,f,g,8d,8f.,16p,16f,16p,16c,8c,16p,a,8g,16f,16p,8f,16p,16c,16p,g,f",0

        byte    "Monty P:d=4,o=5,b=200:f6,8e6,d6,8c#6,c6,8b,a#,8a,8g,8a,8a#,a,8g,2c6,8p,8c6,8a,8p,8a,8a,8g#,8a,8f6,8p,8c6,8c6,8p,8a,8a#,8p,8a#,8a#,8p,8c6,2d6,8p,8a#,8g,8p,8g,8g,8f#,8g,8e6,8p,8d6,8d6,8p,8a#,8a,8p,8a,8a,8p,8a#,2c6,8p,8c6",0
        byte    "munsters:d=4,o=5,b=160:d,8f,8d,8g#,8a,d6,8a#,8a,2g,8f,8g,a,8a4,8d#4,8a4,8b4,c#,8d,p,c,c6,c6,2c6,8a#,8a,8a#,8g,8a,f,p,g,g,2g,8f,8e,8f,8d,8e,2c#,p,d,8f,8d,8g#,8a,d6,8a#,8a,2g,8f,8g,a,8d#4,8a4,8d#4,8b4,c#,2d",0
        byte    "Muppet:d=4,o=5,b=250:c6,c6,a,b,8a,b,g,p,c6,c6,a,8b,8a,8p,g.,p,e,e,g,f,8e,f,8c6,8c,8d,e,8e,8e,8p,8e,g,2p,c6,c6,a,b,8a,b,g,p,c6,c6,a,8b,a,g.,p,e,e,g,f,8e,f,8c6,8c,8d,e,8e,d,8d,c",0
        byte    "Muppets:d=4,o=5,b=250:c6,c6,a,b,8a,b,g,p,c6,c6,a,8b,8a,8p,g.,p,e,e,g,f,8e,f,8c6,8c,8d,e,8e,8e,8p,8e,g,2p,c6,c6,a,b,8a,b,g,p,c6,c6,a,8b,a,g.,p,e,e,g,f,8e,f,8c6,8c,8d,e,8e,d,8d,c",0
        byte    "piccolo:d=4,o=5,b=320:d6,g6,g,g6,8d6,8e6,8d6,8b,g,d,8g,8a,8b,8c6,d6,g6,1d6,d6,g6,g,g6,8d6,8e6,8b,g,d,8f,8g,8a,8b,c6,f6,1c6",0


        byte    "Pilipom:d=4,o=5,b=160:16e,16p,16e,16p,16g,16p,16g,16p,16b4,16c#,16d,16p,16g,16p,16g,16p,16e,16p,16e,16p,16g,16p,16g,16p,16b,16g,16b,16e6,8d#6,8p,16d#6,16d6,16b,16a#,16d#6,16d6,16b,16a#,16d#6,16d6,16b,16a#,16b,16c6,16d6,16d#6,16b,16a#,16g,16f#,16e,16d#,16c,16b4,16e,16f#,16d#,16b4,8e,16p",0
        byte    "Poison:d=4,o=5,b=112:8d,8d,8a,8d,8e6,8d,8d6,8d,8f#,8g,8c6,8f#,8g,8c6,8e,8d,8d,8d,8a,8d,8e6,8d,8d6,8d,8f#,8g,8c6,8f#,8g,8c6,8e,8d,8c,8d,8a,8d,8e6,8d,8d6,8d,8f#,8g,8c6,8f#,8g,8c6,8e,8d,8c,8d,8a,8d,8e6,8d,8d6,8d,8a,8d,8e6,8d,8d6,8d,2a,8d",0
        byte    "polkka:d=4,o=5,b=140:16d,16c#,16d,16e,16f,16e,16f,16f#,16g,16f#,16g,16a,16a#,16a,16g,16a#,16a,16a4,16c#,16e,16a,16g,16f,16e,16f,16e,16d,16c#,16d,16a4,16b4,16c#,16d,16c#,16d,16e,16f,16e,16f,16f#,16g,16f#,16g,16a,16a#,16a,16g,16a#,16a,16a4,16c#,16e,16a,16g,16f,16e,16d,p,2c#,8d,8a4,8d",0
        byte    "Popcorn:d=4,o=5,b=160:8c6,8a#,8c6,8g,8d#,8g,c,8c6,8a#,8c6,8g,8d#,8g,c,8c6,8d6,8d#6,16c6,8d#6,16c6,8d#6,8d6,16a#,8d6,16a#,8d6,8c6,8a#,8g,8a#,c6",0
        byte    "Postman Pat:d=4,o=5,b=100:16f#,16p,16a,16p,8b,8p,16f#,16p,16a,16p,8b,8p,16f#,16p,16a,16p,16b,16p,16d6,16d6,16c#6,16c#6,16a,16p,b.,8p,32f#,16g,16p,16a,16p,16b,16p,16g,16p,8f#.,8e,8p,32f#,16g,16p,16a,16p,32b.,32b.,16g,16p,8f#.,8e,8p,32f#,16g,16p,16a,16p,16b,16p,16g,16p,16f#,16p,16e,16p,16d,16p,16c#,16p,2d",0
        byte    "Rhubarb:d=4,o=5,b=180:8e,8f,8g,d#.,8e,8f,8g,d#.,8e,8f,8g,a#,8a#,2g.,8e,8f,8g,d#.,8e,8f,8g,d#.,e,8e,d,8d,2c.",0
        byte    "Rikasmiesjos:d=4,o=5,b=160:8g,8f,8g,8f,e,c,p,8e,8f,8g,8f,8g,8f,8e,8f,8g,8a,8a#,8a,8a#,8a,g,p,g#,g,f#,f,8d#,8d,8c,8d,d#,p,8d#,8d,8c,8d,d#,c,g,p",0
        byte    "Kiss:d=4,o=5,b=140:8d4,8e4,f.4,8g4,f4,e4,d4,c4,2d4,8d4,8c4,2d4,8d4,8e4,f.4,8g4,f4,e4,c4,e4,2d.4",0
        byte    "Rule B:d=4,o=5,b=100:e.,8e,8f,f,8e,8f.,16e,8d.,16c,2b4,g,f,16e,16c,16f,16d,8g,8f,e,8d.,16c,c",0
        byte    "Scatman:d=4,o=5,b=200:8b,16b,32p,8b,16b,32p,8b,2d6,16p,16c#.6,16p.,8d6,16p,16c#6,8b,16p,8f#,2p.,16c#6,8p,16d.6,16p.,16c#6,16b,8p,8f#,2p,32p,2d6,16p,16c#6,8p,16d.6,16p.,16c#6,16a.,16p.,8e,2p.,16c#6,8p,16d.6,16p.,16c#6,16b,8p,8b,16b,32p,8b,16b,32p,8b,2d6,16p,16c#.6,16p.,8d6,16p,16c#6,8b,16p,8f#,2p.,16c#6,8p,16d.6,16p.,16c#6,16b,8p,8f#,2p,32p,2d6,16p,16c#6,8p,16d.6,16p.,16c#6,16a.,16p.,8e,2p.,16c#6,8p,16d.6,16p.,16c#6,16a,8p,8e,2p,32p,16f#.6,16p.,16b.,16p.",0
        byte    "Schweine:d=4,o=5,b=180:8g.,16p,16g.,8p,16a.,8p,8a,16p,8b,8p,8b.,16p,16d6,16p,d6,16p,e6,16p,16e6,8p,16b.,8p,16b.,8p,16a.,8p,8a.,16p,16g.,16p,g,16p,8d.6,16p,16d6,8p,8c6,16p,8c.6,16p,8b,16p,16b.,16p,8a.,16p,a,16p,8d.6,16p,16d6,8p,8c6,16p,8c.6,16p,8b,16p,16e.6,16p,8b.,16p,d.6,8p",0

        byte    "shoopsong:d=4,o=5,b=125:g,g,g,g,f,8f,8d#,8f,8d#,c,g,8g,8g,g,8g,8g,b,8g,g.,8e,8d,8f,e,d.",0
        byte    "The Simpsons:d=4,o=5,b=160:c.6,e6,f#6,8a6,g.6,e6,c6,8a,8f#,8f#,8f#,2g,8p,8p,8f#,8f#,8f#,8g,a#.,8c6,8c6,8c6,c6",0
        byte    "Skala:d=4,o=5,b=160:32c,32d,32e,32f,32g,32a,32b,32c6,32b,32a,32g,32f,32e,32d,32c",0
        byte    "Wannabe:d=4,o=5,b=125:16g,16g,16g,16g,8g,8a,8g,8e,8p,16c,16d,16c,8d,8d,8c,e,p,8g,8g,8g,8a,8g,8e,8p,c6,8c6,8b,8g,8a,16b,16a,g",0
        byte    "Stairway:d=4,o=5,b=63:8a6,8c6,8e6,8a6,8b6,8e6,8c6,8b6,8c7,8e6,8c6,8c7,8f#6,8d6,8a6,8f#6,8e6,8c6,8a6,c6,8e6,8c6,8a,8g,8g,8a,a",0
        byte    "SWEnd:d=4,o=5,b=225:2c,1f,2g.,8g#,8a#,1g#,2c.,c,2f.,g,g#,c,8g#.,8c.,8c6,1a#.,2c,2f.,g,g#.,8f,c.6,8g#,1f6,2f,8g#.,8g.,8f,2c6,8c.6,8g#.,8f,2c,8c.,8c.,8c,2f,8f.,8f.,8f,2f",0
        byte    "TheSweeney:d=4,o=5,b=125:16a,8c6,a.,p.,16a,8e6,2d6,p.,8p,c6,8c6,16a.,8c6,e.6,8d6,16a,c6,8d6,16a,8c6,a.,p.,16a,8e6,2d6,p.,8p,e6,8e6,16d#.6,8e6,f.6,c6,b,a,2f.6,c6,8g6,1f6",0

        byte    "tears:d=4,o=5,b=112:p,8b,8g,d6,8d6,8b,16a,g.,2p,p,8c6,8c6,8b,8a,8g,b,2a",0


        byte    "Time to say good bye:d=4,o=5,b=80:8c,16d,16e,16d,16e,16f#,16g,16f#,16g,16a,16g,16e,16a,16b,c6,b",0
        byte    "Timetosay:d=4,o=5,b=80:8c,16d,16e,16d,16e,16f#,16g,16f#,16g,16a,16g,16e,16a,16b,c6,b",0 
        byte    "Time to say good bye:d=4,o=5,b=80:8c,16d,16e,16d,16e,16f#,16g,16f#,16g,16a,16g,16e,16a,16b,c6,b",0
        byte    "Wannabe:d=4,o=5,b=125:16g,16g,16g,16g,8g,8a,8g,8e,8p,16c,16d,16c,8d,8d,8c,e,p,8g,8g,8g,8a,8g,8e,8p,c6,8c6,8b,8g,8a,16b,16a,g",0 
        byte    "Vil du :d=4,o=5,b=100:2p,8p,16f#6,16f#6,16f#6,16e6,16d6,16c#6,b,8f#6,e6,16e6,16e6,16e6,16d6,16c#6,16b,a,8f#6,d6,16f#6,16f#6,16f#6,16e6,16d6,16c#6,b,8f#6,e6,8d6,8c#6,2d6",0 
        byte    "They don't care about us:d=4,o=5,b=125:16f,16e,16f,16e,16f,16e,8d,16e,16d,16e,16d,16e,16d,16c,16d,d",0 
        byte    "Solskinnsdag:d=4,o=5,b=140:2p,d#6,e6,8f6,a.6,f6,e6,8d#6,g.6,d#6,a#,8p,8g6,8a,8d#6,8f6",0 
        byte    "More than words:d=4,o=5,b=90:2p,8e,8g,8g,8e,a.,8g,g,8p,8g,g,8a,g,g,g,8g,8a,8g,8f,f,8f,g",0 
        byte    "Bullet me:d=4,o=5,b=112:b.6,g.6,16f#6,16g6,16f#6,8d.6,8e6,p,16e6,16f#6,16g6,8f#.6,8g6,8a6,b.6,g.6,16f#6,16g6,16f#6,8d.6,8e6,p,16c6,16b,16a,16b",0 
        byte    "The shoop shoop song :d=4,o=5,b=125:g,g,g,g,f,8f,8d#,8f,8d#,c,g,8g,8g,g,8g,8g,b,8g,g.,8e,8d,8f,e,d.",0 
        byte    "Losing my religion:d=4,o=5,b=63:2p,8b,8c#6,8b,8f#,a.,8a,8a,a,a,a.,8b,8c#6,8b,8f#,a.,8a,8a,a,a.,8b,8c#6,8b,8f#,a.,8a,8a,a,a.,8b,8c#6,8b,8f#,a,a,8a,a,8g#,2g#",0 
        byte    "Eternally :d=4,o=5,b=112:b,8b,8a,8b,8c6,a,8a,8g,8a,8b,g,8g,8f#,8e,8d#,2e",0 
        byte    "The final countdown:d=4,o=5,b=125:p,8p,16b,16a,b,e,p,8p,16c6,16b,8c6,8b,a,p,8p,16c6,16b,c6,e,p,8p,16a,16g,8a,8g,8f#,8a,g.,16f#,16g,a.,16g,16a,8b,8a,8g,8f#,e,c6,2b.,16b,16c6,16b,16a,1b",0 
        byte    "Tears in heaven:d=4,o=5,b=112:p,8b,8g,d6,8d6,8b,16a,g.,2p,p,8c6,8c6,8b,8a,8g,b,2a",0 
        byte    "Har en drom:d=4,o=5,b=112:8p,8d,8d,d,8d,8d,e.,8f#,f#,8f#,8a,d.6,8a,b.,8f#,1e",0 
        byte    "I swear:d=4,o=5,b=125:2p,p,8b,8a.,16f#,8e,p,8p,8f#,8g#,a,8a,8a,a,8c#,8d,2e,8p,8f#,8g#,2e",0 
        byte    "Little wing:d=4,o=5,b=63:2p,p,8e,8g,8a,a.,p,8a,8g,8g,e.,p,8d,8c,8d,16e,8d.,8p,8d,8d,8c,2a",0 
        byte    "Walk of life:d=4,o=5,b=160:b.,b.,p,8p,8f#,8g,b,8g,8f,e.,e.,p,2p,p,8f,8g,b.,b.,p,8p,8f,8g,b,8g,f,e.,e.,p,8p,8f,8g,b,8g,8f,8e",0 
        byte    "Be-Bop-A-Lula:d=4,o=5,b=180:2p,2a,a,8a,8e,g,a,a,a,g,a,8p,8a,8a,8e,g,8a,8a,a,a,g,a",0 
        byte    "Vårsøg:d=4,o=5,b=100:p,e,e.,8d,2e.,a,c.6,8b,a,g,e,2e,p,p,e,e.,8d,2e.,a,b.,8a,g,a,1e",0 
        byte    "Byssan lull:d=4,o=5,b=90:e,b,b,8b,8b,8c6,8b,8a,8g,f#.,8g,a,8a,8a,8a,8a,8b,8a,2g,f#,8p,8f#,8g,8g,8g,8e,f#.,8f#,8g,8g,8g,8e,f#.,8a,8a,8a,8b,8c6,b,8a,8g,2f#,e",0 
        byte    "Skala:d=4,o=5,b=160:32c,32d,32e,32f,32g,32a,32b,32c6,32b,32a,32g,32f,32e,32d,32c",0 
        byte    "Vinsjan pa Kaia:d=4,o=5,b=90:g,d,g,d,g,b,a#,a,g,d,g,d,g",0 
        byte    "I don't want to miss a thing :d=4,o=5,b=125:2p,16a,16p,16a,16p,8a.,16p,a,16g,16p,2g,16p,p,8p,16g,16p,16g,16p,16g,8g.,16p,c6,16a#,16p,a,8g,f,g,8d,8f.,16p,16f,16p,16c,8c,16p,a,8g,16f,16p,8f,16p,16c,16p,g,f",0 
        byte    "Barbie girl :d=4,o=5,b=125:8g#,8e,8g#,8c#6,a,p,8f#,8d#,8f#,8b,g#,8f#,8e,p,8e,8c#,f#,c#,p,8f#,8e,g#,f#",0 
        byte    "Time to say goodbye :d=4,o=5,b=80:8c,16d,16e,16d,16e,16f#,16g,16f#,16g,16a,16g,16e,16a,16b,c6,b",0 
        byte    "Det gar likar no :d=4,o=5,b=180:e.,g#.,b.,b,8e6,c#.6,b,8b,b.,p,a,8a,a,8b,a,8g#,8g#,8g#,8g#,g#,8g#,g#,8g#,8g#,f#,p",0 
        byte    "Killing me softly :d=4,o=5,b=90:p,8e,f,g,8a,a,8g,d,g.,p,8p,8a,g,8f,8e,8e,8f,2c,p,8e,f,g,8a,a,8g,a,b,8b,8c6,8b,16a,8g,16a,2a,2a.",0 
        byte    "Macarena :d=4,o=5,b=180:f,8f,8f,f,8f,8f,8f,8f,8f,8f,8f,8a,8c,8c,f,8f,8f,f,8f,8f,8f,8f,8f,8f,8d,8c,p,f,8f,8f,f,8f,8f,8f,8f,8f,8f,8f,8a,p,2c.6,a,8c6,8a,8f,p,2p",0 
        byte    "Snørosa :d=4,o=5,b=140:c6,8b,8a,b,8a,8g,8a#,8a#,8a,8g,a,8g,8f,8p,8f,8f,8e,d,8a,2g",0 
        byte    "Popcorn :d=4,o=5,b=112:8c6,8a#,8c6,8g,8d#,8g,c,8c6,8a#,8c6,8g,8d#,8g,c,8c6,8d6,8d#6,16c6,8d#6,16c6,8d#6,8d6,16a#,8d6,16a#,8d6,8c6,8a#,8g,8a#,c6",0 
 
        byte    "Where the wild roses grow:d=4,o=5,b=63:c.6,e.6,8f6,8g6,8f6,e.6,16e6,16f6,8e6,8d6,c.6,16g,16a,8g,8d,e",0
        byte    "Let it be:d=4,o=5,b=100:16e6,8d6,c6,16e6,8g6,8a6,8g.6,16g6,8g6,8e6,16d6,8c6,16a,8g,e.6,p,8e6,16e6,8f.6,8e6,8e6,8d6,16p,16e6,16d6,8d6,2c.6",0
        byte    "Frank Mills:d=4,o=5,b=112:e,8e,8e,e,g,d,d,p,8e,8g,c6,c6,c6,e6,a.,8a,a,8b,8c6,8a,8g,g,p,c6,g,8f,8e,f,c6,p,8p,8a,b,8a,8b,1c6",0
        byte    "Do you hear the people sing:d=4,o=5,b=140:8e.6,16d6,8c.6,16d6,8e.6,16f6,g6,8e6,8d6,8c6,8b.,16a,8b.,16c6,g,8a,8g,8f,8e.,16g,8c.6,16e6,8d.6,16c#6,8d.6,16a,8c.6,16b,8b.,16c6,d6",0
        byte    "Master of the house:d=4,o=5,b=100:16a,16a,16a,16a,8e,8p,16a,16a,16a,16a,8e,8p,16a,16a,16a,16a,16a,16g#,16a,16b,8c#6,8a,8e,8p",0
        byte    "Castle on a Cloud:d=4,o=5,b=90:8a,16b,16c6,8b,8a,8a,8g#,a,p,8a,16b,16c6,8b,8a,8g,8f,e,p,8d,16e,16f,8e,8a,8b,8c6,a,p,8d,16e,16f,8e,8d,8c,8b,a",0
        byte    "Aquarius:d=4,o=5,b=200:e,f#,1g.,a,g,8f#,e,d,1e.,d,8e,f#,2f#.,e,8e,d,8d,1e",0
        byte    "Bogey:d=4,o=5,b=140:8g,8e,p,8p,8e,8f,8g,e6,e6,2c6,8g,8e,p,8p,8e,8f,8e,g,g,2f,8f,8d,p,8p,8d,8e,8f,8g,8e,p,8p,8e,8f#,8e,8d,8g,8p,8e,8f#,8d,8p,8a,8g.,16f#,8g,8a,8g,8f,8e,8d,8c",0
        byte    "Greensleaves:d=4,o=5,b=140:g,2a#,c6,d.6,8d#6,d6,2c6,a,f.,8g,a,2a#,g,g.,8f,g,2a,f,2d,g,2a#,c6,d.6,8e6,d6,2c6,a,f.,8g,a,a#.,8a,g,f#.,8e,f#,2g",0
        byte    "Canon:d=4,o=5,b=80:8d,8f#,8a,8d6,8c#,8e,8a,8c#6,8d,8f#,8b,8d6,8a,8c#,8f#,8a,8b,8d,8g,8b,8a,8d,8f#,8a,8b,8f#,8g,8b,8c#,8e,8a,8c#6,f#6,8f#,8a,e6,8e,8a,d6,8f#,8a,c#6,8c#,8e,b,8d,8g,a,8f#,8d,b,8d,8g,c#.6",0
        byte    "National Anthem:d=4,o=5,b=140:g6,g6,a6,f#.6,8g6,a6,b6,b6,c7,b.6,8a6,g6,a6,g6,f#6,g6",0
        byte    "Rule B:d=4,o=5,b=100:e.,8e,8f,f,8e,8f.,16e,8d.,16c,2b4,g,f,16e,16c,16f,16d,8g,8f,e,8d.,16c,c",0
        byte    "Monty P:d=4,o=5,b=200:f6,8e6,d6,8c#6,c6,8b,a#,8a,8g,8a,8a#,a,8g,2c6,8p,8c6,8a,8p,8a,8a,8g#,8a,8f6,8p,8c6,8c6,8p,8a,8a#,8p,8a#,8a#,8p,8c6,2d6,8p,8a#,8g,8p,8g,8g,8f#,8g,8e6,8p,8d6,8d6,8p,8a#,8a,8p,8a,8a,8p,8a#,2c6,8p,8c6",0
        byte    "Zorba2:d=4,o=5,b=125:16c#6,2d6,2p,16c#6,2d6,2p,32e6,32d6,32c#6,2d6,2p,16c#6,2d6,2p,16b,2c6,2p,32d6,32c6,32b,2c6,2p,16a#,2b,p,8p,32c6,32b,32a,32g,32b,2a,2p,32a,32g,32f#,32a,1g,1p,8c#6,8d6,8d6,8d6,8d6,8d6,8d6,8d6,8c#6,8d6,8d6,8d6,8d6,8d6,16e6,16d6,16c#6,16e6,8c#6,8d6,8d6,8d6,8d6,8d6,8d6,8d6,8c#6,8d6,8d6,8d6,8d6,8d6",0
        byte    "Auld L S:d=4,o=5,b=100:g,c.6,8c6,c6,e6,d.6,8c6,d6,8e6,8d6,c.6,8c6,e6,g6,2a.6,a6,g.6,8e6,e6,c6,d.6,8c6,d6,8e6,8d6,c.6,8a,a,g,2c.6",0
        byte    "Black Bear:d=4,o=5,b=180:d#,d#,8g.,16d#,8a#.,16g,d#,d#,8g.,16d#,8a#.,16g,f,8c.,16b4,c,8f.,16d#,8d.,16d#,8c.,16d,8a#.4,16c,8d.,16a#4,d#,d#,8g.,16d#,8a#.,16g,d#,d#,8g.,16d#,8a#.,16g,f,f,f,8g.,16f,d#,g,2d#",0
        byte    "90210:d=4,o=5,b=140:8f,8a#,8c6,d.6,2d6,p,8f,8a#,8c6,8d6,8d#6,f6,f.6,2a#.,8f,8a#,8c6,8d6,8d#6,8f6,8g6,f6,8d#6,d#6,d6,2c.6,8a#,a,a#.,g6,8f6,8d#6,8d6,8d#6,8d6,8a#,f",0 
        byte    "Dallas:d=4,o=5,b=125:8e,a.,8e,e.6,8a,c#6,8b,8c#6,a,e,a,f#6,e6,8c#6,8d6,2e.6,8p,8e,a,f#6,e6,8c#6,8d6,e6,8b,8c#6,a,e,a,8c#6,8d6,b.,8a,2a",0 
        byte    "aadams:d=4,o=5,b=160:8c,f,8a,f,8c,b4,2g,8f,e,8g,e,8e4,a4,2f,8c,f,8a,f,8c,b4,2g,8f,e,8c,d,8e,1f,8c,8d,8e,8f,1p,8d,8e,8f#,8g,1p,8d,8e,8f#,8g,p,8d,8e,8f#,8g,p,8c,8d,8e,8f",0 
        byte    "KnightRider:d=4,o=5,b=125:16e,16p,16f,16e,16e,16p,16e,16e,16f,16e,16e,16e,16d#,16e,16e,16e,16e,16p,16f,16e,16e,16p,16f,16e,16f,16e,16e,16e,16d#,16e,16e,16e,16d,16p,16e,16d,16d,16p,16e,16d,16e,16d,16d,16d,16c,16d,16d,16d,16d,16p,16e,16d,16d,16p,16e,16d,16e,16d,16d,16d,16c,16d,16d,16d",0
        byte    "axelf:d=4,o=5,b=160:f#,8a.,8f#,16f#,8a#,8f#,8e,f#,8c.6,8f#,16f#,8d6,8c#6,8a,8f#,8c#6,8f#6,16f#,8e,16e,8c#,8g#,f#.",0

        byte    "PinkPanther:d=4,o=5,b=160:8d#,8e,2p,8f#,8g,2p,8d#,8e,16p,8f#,8g,16p,8c6,8b,16p,8d#,8e,16p,8b,2a#,2p,16a,16g,16e,16d,2e",0 
        byte    "Bolero:d=4,o=5,b=80:c6,8c6,16b,16c6,16d6,16c6,16b,16a,8c6,16c6,16a,c6,8c6,16b,16c6,16a,16g,16e,16f,2g,16g,16f,16e,16d,16e,16f,16g,16a,g,g,16g,16a,16b,16a,16g,16f,16e,16d,16e,16d,8c,8c,16c,16d,8e,8f,d,2g",0
        byte    "girl:d=4,o=5,b=125:8g#,8e,8g#,8c#6,a,p,8f#,8d#,8f#,8b,g#,8f#,8e,p,8e,8c#,f#,c#,p,8f#,8e,g#,f#",0 
        byte    "DasBoot:d=4,o=5,b=100:d#.4,8d4,8c4,8d4,8d#4,8g4,a#.4,8a4,8g4,8a4,8a#4,8d,2f.,p,f.4,8e4,8d4,8e4,8f4,8a4,c.,8b4,8a4,8b4,8c,8e,2g.,2p",0
        byte    "Argentina:d=4,o=5,b=70:8e.4,8e4,8e4,8e.4,8f4,8g4,8a4,g4,8p,8g4,8a4,8a4,8g4,c,g4,8f4,e.4,8p,8e4,8f4,8g4,8d4,d4,8d4,8e4,8f4,c4,16p,8c4,8d4,8c4,8e4,g4,16p,8g4,8g4,8a4,c,16p",0
        byte    "Schweine:d=4,o=5,b=180:8g.,16p,16g.,8p,16a.,8p,8a,16p,8b,8p,8b.,16p,16d6,16p,d6,16p,e6,16p,16e6,8p,16b.,8p,16b.,8p,16a.,8p,8a.,16p,16g.,16p,g,16p,8d.6,16p,16d6,8p,8c6,16p,8c.6,16p,8b,16p,16b.,16p,8a.,16p,a,16p,8d.6,16p,16d6,8p,8c6,16p,8c.6,16p,8b,16p,16e.6,16p,8b.,16p,d.6,8p",0



        byte    "killing:d=4,o=5,b=90:p,8e,f,g,8a,a,8g,d,g.,p,8p,8a,g,8f,8e,8e,8f,2c,p,8e,f,g,8a,a,8g,a,b,8b,8c6,8b,16a,8g,16a,2a,2a.",0 
        byte    "aerosmithmissathing:d=4,o=5,b=125:2p,16a,16p,16a,16p,8a.,16p,a,16g,16p,2g,16p,p,8p,16g,16p,16g,16p,16g,8g.,16p,c6,16a#,16p,a,8g,f,g,8d,8f.,16p,16f,16p,16c,8c,16p,a,8g,16f,16p,8f,16p,16c,16p,g,f",0
        byte    "Timetosay :d=4,o=5,b=80:8c,16d,16e,16d,16e,16f#,16g,16f#,16g,16a,16g,16e,16a,16b,c6,b",0 
        byte    "shoopshoop :d=4,o=5,b=125:g,g,g,g,f,8f,8d#,8f,8d#,c,g,8g,8g,g,8g,8g,b,8g,g.,8e,8d,8f,e,d.",0
        byte    "losing:d=4,o=5,b=63:2p,8b,8c#6,8b,8f#,a.,8a,8a,a,a,a.,8b,8c#6,8b,8f#,a.,8a,8a,a,a.,8b,8c#6,8b,8f#,a.,8a,8a,a,a.,8b,8c#6,8b,8f#,a,a,8a,a,8g#,2g#",0
        byte    "Macarena:d=4,o=5,b=180:f,8f,8f,f,8f,8f,8f,8f,8f,8f,8f,8a,8c,8c,f,8f,8f,f,8f,8f,8f,8f,8f,8f,8d,8c,p,f,8f,8f,f,8f,8f,8f,8f,8f,8f,8f,8a,p,2c.6,a,8c6,8a,8f,p,2p",0
        byte    "Halloween:d=4,o=5,b=180:8d6,8g,8g,8d6,8g,8g,8d6,8g,8d#6,8g,8d6,8g,8g,8d6,8g,8g,8d6,8g,8d#6,8g,8c#6,8f#,8f#,8c#6,8f#,8f#,8c#6,8f#,8d6,8f#,8c#6,8f#,8f#,8c#6,8f#,8f#,8c#6,8f#,8d6,8p,8d6,8g,8g,8d6,8g,8g,8d6,8g,8d#6,8g,8d6,8g,8g,8d6,8g,8g,8d6,8g,8d#6,8g,8c#6,8f#,8f#,8c#6,8f#,8f#,8c#6,8f#,8d6,8f#,8c#6,8f#,8f#,8c#6,8f#,8f#,8c#6,8f#,8d6",0
        byte    "PinkPanther:d=4,o=5,b=160:8d#,8e,2p,8f#,8g,2p,8d#,8e,16p,8f#,8g,16p,8c6,8b,16p,8d#,8e,16p,8b,2a#,2p,16a,16g,16e,16d,2e",0
        byte    "Bolero:d=4,o=5,b=80:c6,8c6,16b,16c6,16d6,16c6,16b,16a,8c6,16c6,16a,c6,8c6,16b,16c6,16a,16g,16e,16f,2g,16g,16f,16e,16d,16e,16f,16g,16a,g,g,16g,16a,16b,16a,16g,16f,16e,16d,16e,16d,8c,8c,16c,16d,8e,8f,d,2g",0
        byte    "barbiegirl:d=4,o=5,b=125:8g#,8e,8g#,8c#6,a,p,8f#,8d#,8f#,8b,g#,8f#,8e,p,8e,8c#,f#,c#,p,8f#,8e,g#,f#",0 
        byte    "Argentina:d=4,o=5,b=70:8e.4,8e4,8e4,8e.4,8f4,8g4,8a4,g4,8p,8g4,8a4,8a4,8g4,c,g4,8f4,e.4,8p,8e4,8f4,8g4,8d4,d4,8d4,8e4,8f4,c4,16p,8c4,8d4,8c4,8e4,g4,16p,8g4,8g4,8a4,c,16p",0
        byte    "Schweine:d=4,o=5,b=180:8g.,16p,16g.,8p,16a.,8p,8a,16p,8b,8p,8b.,16p,16d6,16p,d6,16p,e6,16p,16e6,8p,16b.,8p,16b.,8p,16a.,8p,8a.,16p,16g.,16p,g,16p,8d.6,16p,16d6,8p,8c6,16p,8c.6,16p,8b,16p,16b.,16p,8a.,16p,a,16p,8d.6,16p,16d6,8p,8c6,16p,8c.6,16p,8b,16p,16e.6,16p,8b.,16p,d.6,8p",0
        byte    "killing:d=4,o=5,b=90:p,8e,f,g,8a,a,8g,d,g.,p,8p,8a,g,8f,8e,8e,8f,2c,p,8e,f,g,8a,a,8g,a,b,8b,8c6,8b,16a,8g,16a,2a,2a.",0 
        byte    "aerosmithmissathing:d=4,o=5,b=125:2p,16a,16p,16a,16p,8a.,16p,a,16g,16p,2g,16p,p,8p,16g,16p,16g,16p,16g,8g.,16p,c6,16a#,16p,a,8g,f,g,8d,8f.,16p,16f,16p,16c,8c,16p,a,8g,16f,16p,8f,16p,16c,16p,g,f",0
        byte    "Timetosay:d=4,o=5,b=80:8c,16d,16e,16d,16e,16f#,16g,16f#,16g,16a,16g,16e,16a,16b,c6,b",0 
        byte    "mjcareaboutus:d=4,o=5,b=125:16f,16e,16f,16e,16f,16e,8d,16e,16d,16e,16d,16e,16d,16c,16d,d",0 
        byte    "cheershoopshoop:d=4,o=5,b=125:g,g,g,g,f,8f,8d#,8f,8d#,c,g,8g,8g,g,8g,8g,b,8g,g.,8e,8d,8f,e,d.",0
        byte    "losing:d=4,o=5,b=63:2p,8b,8c#6,8b,8f#,a.,8a,8a,a,a,a.,8b,8c#6,8b,8f#,a.,8a,8a,a,a.,8b,8c#6,8b,8f#,a.,8a,8a,a,a.,8b,8c#6,8b,8f#,a,a,8a,a,8g#,2g#",0
        byte    "Macarena:d=4,o=5,b=180:f,8f,8f,f,8f,8f,8f,8f,8f,8f,8f,8a,8c,8c,f,8f,8f,f,8f,8f,8f,8f,8f,8f,8d,8c,p,f,8f,8f,f,8f,8f,8f,8f,8f,8f,8f,8a,p,2c.6,a,8c6,8a,8f,p,2p",0
        byte    "Halloween:d=4,o=5,b=180:8d6,8g,8g,8d6,8g,8g,8d6,8g,8d#6,8g,8d6,8g,8g,8d6,8g,8g,8d6,8g,8d#6,8g,8c#6,8f#,8f#,8c#6,8f#,8f#,8c#6,8f#,8d6,8f#,8c#6,8f#,8f#,8c#6,8f#,8f#,8c#6,8f#,8d6,8p,8d6,8g,8g,8d6,8g,8g,8d6,8g,8d#6,8g,8d6,8g,8g,8d6,8g,8g,8d6,8g,8d#6,8g,8c#6,8f#,8f#,8c#6,8f#,8f#,8c#6,8f#,8d6,8f#,8c#6,8f#,8f#,8c#6,8f#,8f#,8c#6,8f#,8d6",0
        byte    "VanessaMae:d=4,o=6,b=70:32c7,32b,16c7,32g,32p,32g,32p,32d#,32p,32d#,32p,32c,32p,32c,32p,32c7,32b,16c7,32g#,32p,32g#,32p,32f,32p,16f,32c,32p,32c,32p,32c7,32b,16c7,32g,32p,32g,32p,32d#,32p,32d#,32p,32c,32p,32c,32p,32g,32f,32d#,32d,32c,32d,32d#,32c,32d#,32f,16g,8p,16d7,32c7,32d7,32a#,32d7,32a,32d7,32g,16d7,32p,32d7,32p,32d7,32p,16d7,32c7,32d7,32a#,32d7,32a,32d7,32g,16d7,32p,32d7,32p,32d7,32p,32g,32f,32d#, 32d,32c,32d,32d#,32c,32d#,32d,8c",0
        byte    "Verve:d=4,o=5,b=80:8b4,8d,8b4,8c,8a4,8c,8p,8f,8c,8f,8p,8e,8c,8e,8p,8b4,8d,8b4,8c,8a4,8c,8p,8f,8c,8f,8p,8e,8c,8e,8p,8d,8b4,8d,8b4,8p,8c,8c,8p,8f,8c,8f,8g,8e,8c,8e,8p,8b4,8d,8b4,8c,8a4,8c,8p,8f,8c,8f,8p,8e,8c,8e",0
        byte    "Walk of Life:d=4,o=5,b=160:b.,b.,p,8p,8f#,8g,b,8g,8f,e.,e.,p,2p,p,8f,8g,b.,b.,p,8p,8f,8g,b,8g,f,e.,e.,p,8p,8f,8g,b,8g,8f,8e",0
        byte    "Wannabe:d=4,o=5,b=125:16g,16g,16g,16g,8g,8a,8g,8e,8p,16c,16d,16c,8d,8d,8c,e,p,8g,8g,8g,8a,8g,8e,8p,c6,8c6,8b,8g,8a,16b,16a,g",0 
        byte    "YMCA:d=4,o=5,b=160:8c#6,8a#,2p,8a#,8g#,8f#,8g#,8a#,c#6,8a#,c#6,8d#6,8a#,2p,8a#,8g#,8f#,8g#,8a#,c#6,8a#,c#6,8d#6,8b,2p,8b,8a#,8g#,8a#,8b,d#6,8f#6,d#6,f.6,d#.6,c#.6,b.,a#,g#",0
        byte    "Zorba2:d=4,o=5,b=125:16c#6,2d6,2p,16c#6,2d6,2p,32e6,32d6,32c#6,2d6,2p,16c#6,2d6,2p,16b,2c6,2p,32d6,32c6,32b,2c6,2p,16a#,2b,p,8p,32c6,32b,32a,32g,32b,2a,2p,32a,32g,32f#,32a,1g,1p,8c#6,8d6,8d6,8d6,8d6,8d6,8d6,8d6,8c#6,8d6,8d6,8d6,8d6,8d6,16e6,16d6,16c#6,16e6,8c#6,8d6,8d6,8d6,8d6,8d6,8d6,8d6,8c#6,8d6,8d6,8d6,8d6,8d6",0
} 

' DEBUGGER STRINGS ////////////////////////////////////////////////////////////

DAT

debug_clearscreen_string        byte ASCII_ESC,ASCII_LB, $30+$02, $41+$09, $00
debug_home_string               byte ASCII_ESC,ASCII_LB, $41+$07, $00   
debug_title_string              byte "Hydra Debugger Initializing (C) Nurve Networks LLC 20XX", ASCII_CR, ASCII_LF, $00 ' $0D carriage return, $0A line feed 
title_string                    byte "Hydra RTTTL Jukebox Version 1.0",0
hex_table                       byte    "0123456789ABCDEF"