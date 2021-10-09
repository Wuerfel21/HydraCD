' //////////////////////////////////////////////////////////////////////
' CommTest - Communications Test
' AUTHOR: Colin Phillips
' LAST MODIFIED: 2.24.06
' VERSION 0.1
'
' How to use:
' 1) Run This Hydra App.
' 2) Open a Terminal program, Start a Connection at 115200bps (typically on COM3) 8-N-1
' For Hyper Terminal goto File->New Connection.
' Enter a Name and Icon.
' Select: Connect Using: 'COM3' (or whichever is the USB2SER COM port for the Hydra).
' Port Settings...
' Bits per second: '115200'
' Data bits: 8
' Parity: None
' Stop bits: 1
' Flow Control: Hardware
' Click Ok.
' (Connected)
' On Hydra Keyboard:
' Press F1 - To send a NULL terminated string (cp_file_001.spin) to the Terminal.
' Press F2 - To start receive XMODEM file. (Terminal must have file ready and waiting to be sent on XMODEM
' protocol (Hyperterminal: Transfer->Send File... (Protocol 'XMODEM' (original 128 byte packet XMODEM, not 1K XMODEM))
' All other keys send ASCII chars to the Terminal.
' On Terminal Keyboard:
' Press any key sends ASCII chars to the Hydra.
' Send File using XMODEM protocol.
'
' This program will copy upto 4K file into the last 16 sprites.
' Be careful not to send bytes which equate to SYNC, otherwise these will be displayed and will
' distort/ruin the picture output.
' recommended send file: cp_cop_tiles_002.bin (4k bitmap 16x256 pixels)
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x          ' enable external clock and pll times 8
  _xinfreq = 10_000_000 + 0000      ' set frequency to 10 MHZ plus some error    
  _stack   = 64                     ' stack
  _memstart = $10                   ' memory starts $10 in!!! (this took 2 headaches to figure out)
  
' COP HEADER ------------------------------------------------------------------

  obj_n         = 24                ' Number of Objects
  obj_size      = 6                 ' registers per object.
  obj_total_size = obj_n*obj_size   ' Total Number of registers (LONGS)
  OBJ_OFFSET_X  = 0
  OBJ_OFFSET_Y  = 1
  OBJ_OFFSET_W  = 2
  OBJ_OFFSET_H  = 3
  OBJ_OFFSET_I  = 4
  OBJ_OFFSET_M  = 5

  #0, h_cop_status, h_cop_control, h_cop_debug, h_cop_phase0, h_cop_monitor0, h_cop_monitor1, h_cop_config, h_cop_vram, h_cop_tile, h_cop_panx, h_cop_pany, h_cop_bgcolor, h_cop_obj

' -----------------------------------------------------------------------------

' COPSND HEADER ---------------------------------------------------------------

  audio_freq = 11025
  system_rate = 80_000_000/11025                          '7256
  channel_data = $0                                       ' offsetted by data_start
  channel_len = 0                                         ' Status 0 off, N length in samples.
  channel_cnt = 1
  channel_volume = 2
  channel_freq = 3
  channel_phase = 4
  channel_venv = 5
  channel_fenv = 6
  channel_tick = 7                                        ' internal counter
  channel_size = 8
  max_channels = 4
  ' special frequency bit masks
  FRQ_WHITENOISE = $80000000

' -----------------------------------------------------------------------------

' COPIO HEADER ---------------------------------------------------------------

  h_copio_rx = 0
  h_copio_rxidx = 1
  h_copio_tx = 2
  h_copio_txidx = 3
  h_copio_rxbuf = 4
  h_copio_rxsize = 5
  h_copio_txbuf = 6
  h_copio_txsize = 7

' -----------------------------------------------------------------------------

  FRAMERATE = 60                ' 60FPS!!!

  
'///////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

' COP HEADER ------------------------------------------------------------------

VAR

long  cop_status
long  cop_control
long  cop_debug
long  cop_phase0
long  cop_monitor0
long  cop_monitor1
long  cop_config
long  cop_vram
long  cop_tile
long  cop_panx
long  cop_pany
long  cop_bgcolor
' |
' |
' LAST
long  cop_obj[obj_total_size]       ' 12 sprite positions

' -----------------------------------------------------------------------------

' COPSND HEADER ---------------------------------------------------------------

VAR

long  copsnd_len                                        ' Status 0 off, N length in samples.
long  copsnd_cnt
long  copsnd_volume
long  copsnd_freq
long  copsnd_phase
long  copsnd_venv
long  copsnd_fenv
long  copsnd_tick                                       ' internal counter

' -----------------------------------------------------------------------------

long  copio_rx
long  copio_rxidx
long  copio_tx
long  copio_txidx
long  copio_rxbuf
long  copio_rxsize
long  copio_txbuf
long  copio_txsize

byte copio_receive_queue[1024]                          ' at 11.52kbps - 192 bytes per frame. holds for 5.33 frames.

word  map_data[16*16]
long  old_s
long  old_r
long  key_s
long  key_r

VAR

byte u8
word u16
long u32

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

OBJ
  cop   : "cop_drv_010x.spin"                           ' instantiate a cop object - Color Co Processor
  copio : "copio_drv_001.spin"                          ' instantiate a copio object. - IO Co Processor
  key   : "keyboard_iso_010.spin"                       ' instantiate a keyboard object.  
  tiles : "cp_cop_tiles_001.spin"                       ' data object. (128x128 block of sprites)
  testfile : "cp_file_001.spin"                         ' data object. (text file)
  
'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB Start | x, y, t, frame, xmodem_state
' this is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

  ' start cop io engine
  copio.start(@copio_rx, 31,30,115200)
  copio.receive_circular(@copio_receive_queue, 1024) ' Setup circular buffer for receive queue. (should be sufficient for 2/60th's of baud rate or largest packet size *2 i.e. 260)
  ' start cop engine
  cop.setup(tiles.data,16,512, $00, @map_data) ' graphics is pre-XOR'ed with $F0 (XGSBMP 1.07 feature)
  cop.start(@cop_status)

  ' start keyboard on pingroup 3  
  key.start(3)

  repeat x from 0 to CONSTANT(16*16)
    map_data[x] := 17<<8

  repeat x from 0 to 16
    map_data[8+x<<4] := x<<8
    map_data[9+x<<4] := (16+x)<<8
  
  frame := 0
  
  cop_bgcolor := $00000000
  cop_pany := -8
  cop_debug:= 0
  old_s := 1
  old_r := 1

  copio.init_xmodem

  repeat while TRUE
    cop.newframe

    key_s := key.keystate($D0)                          ' F1 Send
    key_r := key.keystate($D1)                          ' F2 Receive

    ' Send Keys to Terminal.
    if(u8 := key.key)
      if(u8<>$D0 and u8<>$D1)                           ' all keys except F1/F2
        copio.send(@u8, 1)

    ' Send a big string to Terminal.
    if(old_s==0 and key_s<>0)
      copio.send(testfile.data, strsize(testfile.data))

    ' Send Receive Request to Terminal. (Commences XMODEM file transfer)
    if(old_r==0 and key_r<>0)
      copio.receive_xmodem(tiles.data+16<<8, CONSTANT(256*16))

    old_s := key_s
    old_r := key_r

    MapNumber(frame, 0, 0)
    MapNumber(xmodem_state, 0, 1)
    MapNumber(copio_rx, 0, 2)
    MapNumber(copio_rxidx, 0, 3)
    
    cop.waitvsync

    repeat while (xmodem_state := copio.process_xmodem) == 1 ' process receive queue for xmodem until no more data to process.
    'repeat while (xmodem_state := copio.process_xmodem) <> 2 ' process receive queue for xmodem until entire file processed.
    
    frame++


PUB MapNumber(v, x, y) | z, c

x+=7
repeat z from 0 to 7
  c := v&15
  map_data[y<<4 | x] := c<<8
  v>>=4
  x--