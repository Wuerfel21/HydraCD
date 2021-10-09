{{//////////////////////////////////////////////////////////////////////

sound test bed
AUTHOR: Andre' LaMothe
LAST MODIFIED: 4.6.06
VERSION 5.0

Demonstration of Nick Sabalausky's NS_sound_drv.

//////////////////////////////////////////////////////////////////////}}

'///////////////////////////////////////////////////////////////////////
' CONSTANTS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
CON

  _clkmode = xtal2 + pll8x       ' enable external clock range 5-10MHz and pll times 8
  _xinfreq = 10_000_000 + 3000   ' set frequency to 10 MHZ plus some error due to XTAL (1000-5000 usually works)
  _stack   = 128                 ' accomodate display memory and stack

  FREQ_INIT = 500
  FREQ_DELTA_INIT = -2
  FREQ_MAX = 800
  FREQ_MIN = 200

  SHAPE_INIT = snd#SHAPE_SINE

  RTL_START_SONG = 0
  RTL_END_SONG   = 1

  ASCII_A = 65
  ASCII_B = 66
  ASCII_C = 67
  ASCII_D = 68
  ASCII_E = 69
  ASCII_F = 70
  ASCII_G = 71
  ASCII_H = 72
  ASCII_O = 79  
  ASCII_P = 80
  ASCII_Z = 90
  
  ASCII_0 = 48
  ASCII_9 = 57

  ASCII_LF     = $0A ' line feed 
  ASCII_CR     = $0D ' carriage return
  ASCII_ESC    = $1B ' escape 
  ASCII_LB     = $5B ' [ 
  ASCII_SEMI   = $3A ' ; 
  ASCII_EQUALS = $3D ' = 
  ASCII_PERIOD = $2E ' .
  ASCII_SHARP  = $23 ' #
   
  ASCII_NULL   = $00
  ASCII_SPACE  = $20 ' space

  NOTE_PAUSE  = 1000 ' 1000...2000 are commands to timing engine
  

'///////////////////////////////////////////////////////////////////////
' VARIABLES ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
VAR

  'audio states
  long freq, freq_delta
  long shape
  byte sbuffer[128]

  ' these are temporary for the debugger interface, 4 LONGs accessed as bytes depending on what they are
  long debug_status_parm                               ' this is the status of the debugger print, 0-ready for input, 1-busy
  long debug_string_parm                               ' 4 characters, space filled for blanks
  long debug_value_parm                                ' 8 hex digits will print out
  long debug_pos_parm                                  ' position to print the string at, $00_00_yy_xx


  ' globals for RTTTL player, makes parsing easier
  long rtl_data_ptr
  long rtl_duration, rtl_def_duration
  long rtl_note, rtl_note_sharp
  long rtl_octave, rtl_def_octave
  long rtl_bpm, rtl_def_bpm
  long rtl_volume, rtl_style
  long rtl_index, rtl_parser_state, rtl_token
  
'///////////////////////////////////////////////////////////////////////
' OBJECTS //////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

  snd     : "NS_sound_drv_050_22khz_16bit.spin"      'Sound driver
  dat_sfx : "gameover_11_8.spin" ' NS_hydra_sound_011.spin"                'PCM Sound Effect "Hydra"
  serial  : "FullDuplex_serial_drv_010.spin"

'///////////////////////////////////////////////////////////////////////
' FUNCTIONS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

'// PUB start //////////////////////////////////////////////////////////
PUB start 

  'start sound driver
  snd.start(7)
  repeat 1000 ' give it a second to boot up...

  'init sound vars
  freq       := FREQ_INIT
  freq_delta := FREQ_DELTA_INIT
  shape      := SHAPE_INIT

  ' play a PCM sound on channel 0

  ' snd.PlaySoundPCM(4, dat_sfx.ns_hydra_sound, dat_sfx.ns_hydra_sound_end, 255)
  
  
  ' stop a sound
  'snd.StopSound(0)

'  shape := snd#SHAPE_SINE
'  shape := snd#SHAPE_SAWTOOTH
'  shape := snd#SHAPE_SQUARE
'  shape := snd#SHAPE_TRIANGLE
'  shape := snd#SHAPE_NOISE

  ' play
   
  ' snd.PlaySoundFM(0, snd#SHAPE_SQUARE, 1000, snd#SAMPLE_RATE/2, 255, $48AD_FFFF)

  ' start a C note two octaves below middle C on sound channel 0 with infinite playback
  'snd.PlaySoundFM(0, snd#SHAPE_SQUARE, snd#NOTE_C2, snd#DURATION_INFINITE | (snd#SAMPLE_RATE), 255, $28BE_F842)  'Play for an infinite duration

  
  ' change frequencey of playing sound a total of 4 octaves and back down again
{
  repeat freq from snd#NOTE_C2 to snd#NOTE_C6
    snd.SetFreq(0, freq)
    repeat 5_000 ' lets hear it for a moment

  repeat freq from snd#NOTE_C6 to snd#NOTE_C2
    snd.SetFreq(0, freq)
    repeat 5_000 ' lets hear it for a moment

  ' release sound
  snd.ReleaseSound(0)  
}

  'repeat(500_000)
  'snd.ReleaseSound(0)

  'snd.PlaySoundFM(0, snd#SHAPE_SQUARE, 500, snd#SAMPLE_RATE, 255, $135A_ADF0 )
  'snd.ReleaseSound(0)

  ' snd.PlaySoundFM(0, snd#SHAPE_SINE, 500, CONSTANT(snd#DURATION_INFINITE | (snd#SAMPLE_RATE/2)), 255, $28BE_F842)  'Play for an infinite duration

          
  ' change frequencey of playing sound
  ' snd.SetFreq(0, freq)
  
  ' release sound
  'snd.ReleaseSound(0)

  ' else play the note
  'snd.PlaySoundFM(0, snd#SHAPE_SQUARE, snd#NOTE_C4, snd#SAMPLE_RATE/4, 255, $248A_DFA8) 

  ' start the serial debugger
  serial.start(31, 30, 9600) ' receive pin, transmit pin, baud rate
  serial.txstring(@debug_clearscreen_string)
  serial.txstring(@debug_home_string)
  serial.txstring(@debug_title_string)   

  debug_status_parm   := $00000000                            
  debug_pos_parm      := $00000000

  debug_string_parm   := $4F_4C_45_48                            
  debug_value_parm    := $12345678                            
  Debugger_Print_Watch(debug_pos_parm, debug_string_parm, debug_value_parm)       

  Play_RTTTL(@RTTTL_data, 0)


' /////////////////////////////////////////////////////////////////////////////

PUB Debugger_Print_Watch(watch_pos, watch_string, watch_value) | cx, cy, index
' this functions prints the watch_string then next to it the watch_value in hex digits on the VT100 terminal
' connected to the serial port via the USB connection
' parms
'
' watch_pos    - holds the x,y in following format $00_00_yy_xx
' watch_string - holds 4 ASCII text digits for the watch label in format $aa_aa_aa_aa
' watch_value  - holds the actual 32-bit value of the watch in hex digit format $h_h_h_h_h_h_h_h_h

' extract printing location
cx := watch_pos.byte[0]
cy := watch_pos.byte[1]

' build up string
sbuffer[0] := ASCII_CR
sbuffer[1] := ASCII_LF

' copy text
bytemove(@sbuffer[2], @watch_string, 4)

' add equals
sbuffer[6] := $3D ' = character 

' now convert watch_value to hex string
repeat index from 0 to 7
  sbuffer[index+7] := hex_table[ (watch_value >> (28-index*4)) & $F ]

' null terminate the string
sbuffer[15] := 0

' print the results out to the VT100 terminal
serial.txstring(@sbuffer)

' end Debugger_Print_Watch 

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

Debugger_Print_Watch($0, $47_55_42_44, $1)

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

Debugger_Print_Watch($0, $47_55_42_44, $2)

' consume any whitespace
WhiteSpace

Debugger_Print_Watch($0, $47_55_42_44, $3)

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
' there's an error
' PARMS:
' _rtl_data_ptr - address to text string
' channel       - channel to play ringtone thru

' point data pointer to data
rtl_data_ptr := _rtl_data_ptr

'set state to starting song
rtl_parser_state := RTL_START_SONG

' start parser off at beginning of string
rtl_index := 0

Debugger_Print_Watch($0, $47_55_42_44, $0)       

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

' print number
Debugger_Print_Watch($0, $20_4D_55_4E, rtl_def_duration)

' search for default octave "o = <4|5|6|7>"
FindChar(ASCII_O)
rtl_index++ ' consume it

FindChar(ASCII_EQUALS)
rtl_index++ ' consume it

' now get number that represents the octave
rtl_def_octave := GetNumber 

' print number
Debugger_Print_Watch($0, $20_4D_55_4E, rtl_def_octave)


' search for default beats per minute " b=xxx"
FindChar(ASCII_B)
rtl_index++ ' consume it

FindChar(ASCII_EQUALS)
rtl_index++ ' consume it

' now get number that represents the octave
rtl_def_bpm := GetNumber 

' print number
Debugger_Print_Watch($0, $20_4D_55_4E, rtl_def_bpm)

' search for volume (not supported)
' search for style (not supported)

' enter main note parsing loop looking for notes in the format "[<duration>]<note>[<sharp#>][<octave>][<special-duration>]
' thus, the only thing it ALWAYS needs is the <note>, everything else is OPTIONAL, also assume no whitespace within note characters
repeat while (rtl_parser_state <> RTL_END_SONG)

  Debugger_Print_Watch($0, $47_55_42_44, $1)       

  ' now parse next note, format is: "[<duration>] <note> [<sharp#>] [<octave>] [<special-duration>] 
  ' ["1"|"2"|"4"|"8"|"16"] <"P"|"C"|"C#"|"D"|"D#"|"E"|"F"|"F#"|"G"|"G#"|"A"|"A#"|"B"|"H"> ["4"|"5"|"6"|"7"] ["."] 
  ' So the only thing that is ALWAYS there is the <Note> field, the others are optional and if omitted, defaults are used.

  ' eat white space up to not defintion for sloppy RTTTL coding 
  WhiteSpace

  ' looking for duration modifier first?
  if ((rtl_duration := GetNumber) == -1)
    rtl_duration := rtl_def_duration ' no duration modifier, so fall back to default

  ' next character MUST be note, so assume it is
  rtl_note := Toupper(byte[rtl_data_ptr][rtl_index])

  ' advance token index and retrieve
  rtl_index++

  ' looking for # character
  rtl_token := byte[rtl_data_ptr][rtl_index]

  if (rtl_token == ASCII_SHARP)
    rtl_note_sharp := 1 ' set sharp true
  else
    rtl_note_sharp := 0  

   
  ' what note is it? This all can be done with look up table,but too cryptic this is easier to understand and change
  case rtl_token
    ASCII_P:
      rtl_note := NOTE_PAUSE

    ASCII_A:
      rtl_note := snd#NOTE_A4

    ASCII_B:
      rtl_note := snd#NOTE_B4

    ASCII_C:
      rtl_note := snd#NOTE_C4

    ASCII_D:                     
      rtl_note := snd#NOTE_D4      

    ASCII_E:
      rtl_note := snd#NOTE_E4

    ASCII_F:
      rtl_note := snd#NOTE_F4

    ASCII_G:
      rtl_note := snd#NOTE_G4

    ASCII_H:
      rtl_note := snd#NOTE_B4

    ASCII_NULL:
      Debugger_Print_Watch($0, $54_49_58_45, $0)
      return

  ' else play the note
  if (rtl_note <> NOTE_PAUSE)
    snd.PlaySoundFM(channel, snd#SHAPE_SQUARE, rtl_note, snd#SAMPLE_RATE/2, 255, $248A_DF84) 
  else
   rtl_note := rtl_note
   
  waitcnt (cnt + 80_000_000/4) ' delay 

return

' end Play_RTTTL


DAT

RTTTL_data    byte    " test-song : d = 5, o=99, b=100   cdefgh hgfedcba ",0

song_01       byte    "axel-f:d=4,o=5,b=160:f#,8a.,8f#,16f#,8b,8f#,8e,f#,8c#.6,8f#,16f#,8d6,8c#6,8a,8f#,8c#6,8f#6,16f#,8e,16e,8c#,8g#,f#",0

{

thunderstr:d=16,o=5,b=160:c6,c,a#,c,a,c,a#,c,a,c,g,c,a,c,f,c,g,c,e,c,f,c,e,c,f,c,e,c,f,c,e,c

axel-f:d=4,o=5,b=160:f#,8a.,8f#,16f#,8b,8f#,8e,f#,8c#.6,8f#,16f#,8d6,8c#6,8a,8f#,8c#6,8f#6,16f#,
8e,16e,8c#,8g#,f#.

c64-intro:d=8,o=5,b=200:8f,8g#,8a#,8p,8g#,8p,8d#,8f,8g#,8c6,8a#,8p,8g#,8p,8d#,8p

jamesbond:d=8,o=5,b=160:e,g,p,d#6,d6,4p,g,a#,b,2p.,g,16a,16g,f#,4p,b4,e,c#,1p

nuke&cosmo:d=16,o=5,b=160:c,p,d,p,d#,p,c,p,d,p,d#,d,p,d,c,p,g4,p,g#4,p,c,p,g4,p,g#4,p,c,g4,p,g4,
g#4,p,g#4,p,g4,p,d#4,p,g#4,p,g4,p,d#4,g#4,p,d#4,g#4,p,b4,p,d5,p,g5,p,b4,d5,g4,f4,d#4,32d4,32p,32g4,
32p,32f4,32p,32d#4,32p,32d4,32p

nuke&cosmo:d=16,o=4,b=125:c,d,d#,c,d,d#,f,d#,f,g,a#,g,a#,c5,d#5,d5,d#5,d5,a#,d#5,d5,a#,d#5,d5,d#5,
d5,a#,g,f,g,d#,d,g#,g,d#,c,d,d#,f,g,g#,a#,c5,d5,d#5,d5,c5,a#,b,d5,d#5,f5,g5,a#5,g5,f5,g5,f5,d#5,
f5,32d#5,32d5,32c#5,32c5,32b,32a#,32a,32g#

tune1:d=8,o=5,b=160:p,g.,16d,2p,p,16d,g.,16d,a.,16d,a#.,16d,a.,p,f.,16c,2p,p,16c,f.,16c,g.,16c,
g#.,16c,g.

wizardry:d=16,o=6,b=160:d#,8p,d#,d,p,c,p,g,d,b5,d,g5,p,d#,f,g,8p,g,f,p,d#,p,a#,f,d,f,a#5,p,c,d,
d#,p,d#,p,d#,d,c,p,d,p,d,p,d,d#,d,b5,c,2p,g#5,c,d#,g#,a#5,d,f,a#,


closeencounter:d=16,o=5,b=125:
d,p,e,p,c,p.,c4,p,g4,1p., d6,p,e6,p,c6,p.,c,p,g,1p.,

bomberman:d=32,o=6,b=125:
f,p,g5,p,c,p,f,p,e,16p.,c,16p.,a#5,16p.,c,16p.,g5,p,8p.,
f,p,g,p,d#,p,e,p,c,p,p,p,2p,8p,
f,p,g5,p,c,p,f,p,e,16p.,c,16p.,a#5,16p.,c,16p.,g5,p,8p.,
f5,p,g5,p,d#5,p,e5,p,c5,p,p,p,2p,8p,


radioloud:d=32,o=6,b=100:
c5,c,16p,g5,g,16p,c5,c,16p,g5,g,f5,f,d#5,d#,16p,d#5,d#,16p,d#5,d#,8p,32p,d#5,d#
d#5,d#,16p,g5,g,16p,d#5,d#,16p,g5,g,d#5,d#,c5,c,16p,c5,c,16p,c5,c,4p,


alainclark:d=16,o=4,b=100:b,p,d5,b,p,a,p,a,a,p,f#,p,b,8p.,1p,

ringtone from the "24" tv-series
CTU24:d=32,o=5,b=140:f,f,16p,f,f,8p.,b,b,b,b,b4,b4,b4,b4,b4,b4,b4,b4,1p.,

thatsit:d=32,o=4,b=100:
a#,16p.,f,p,f,p,g,16p.,f,8p.,a,16p.,16a#,4p,
d5,16p.,a,p,a,p,b,16p.,a,8p.,c#5,16p.,16d5,4p,


}

' DEBUGGER STRINGS ////////////////////////////////////////////////////////////

DAT

debug_clearscreen_string        byte ASCII_ESC,ASCII_LB, $30+$02, $41+$09, $00
debug_home_string               byte ASCII_ESC,ASCII_LB, $41+$07, $00   
debug_title_string              byte "Hydra Debugger Initializing (C) Nurve Networks LLC 20XX", ASCII_CR, ASCII_LF, $00 ' $0D carriage return, $0A line feed 

debug_string_note_a             byte "Note A"



hex_table                       byte    "0123456789ABCDEF"