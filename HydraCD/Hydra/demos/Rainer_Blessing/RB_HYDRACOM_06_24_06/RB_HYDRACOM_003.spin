' //////////////////////////////////////////////////////////////////////
' HydraCom - Application to store data on the Hydra EEPROM
' AUTHOR: Rainer Blessing (modified Colins CommTest)
' LAST MODIFIED: 06.24.06
' VERSION 0.3
'
' How to use:
' 1) Run This Hydra App.
' 2) Start HydraCom on th PC
'
'
' //////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

CON

  _clkmode = xtal2 + pll8x          ' enable external clock and pll times 8
  _xinfreq = 10_000_000             ' set frequency to 10 MHZ plus some error    
  _stack   = 64                     ' stack
  _memstart = $10                   ' memory starts $10 in!!! (this took 2 headaches to figure out)  


' -----------------------------------------------------------------------------

  BUFFER_SIZE = 8192                ' adjust this value to the size you want to read/write
  
'///////////////////////////////////////////////////////////////////////
' VARIABLES SECTION ////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

' COP HEADER ------------------------------------------------------------------

VAR

long  copio_rx
long  copio_rxidx
long  copio_tx
long  copio_txidx
long  copio_rxbuf
long  copio_rxsize
long  copio_txbuf
long  copio_txsize

byte copio_receive_queue[1024]                          ' at 11.52kbps - 192 bytes per frame. holds for 5.33 frames.

long  byte_count

VAR

byte u8
word u16
long u32

'///////////////////////////////////////////////////////////////////////
' OBJECT DECLARATION SECTION ///////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

OBJ
  copio : "copio_drv_003.spin"                          ' instantiate a copio object. - IO Co Processor
                                                                           
  
'///////////////////////////////////////////////////////////////////////
' PUBLIC FUNCTIONS /////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB Start | x, y, t, frame, xmodem_state
' this is the first entry point the system will see when the PChip starts,
' execution ALWAYS starts on the first PUB in the source code for
' the top level file

  copio.start(@copio_rx, 31,30,115200)
  copio.receive_circular(@copio_receive_queue, 1024) ' Setup circular buffer for receive queue. (should be sufficient for 2/60th's of baud rate or largest packet size *2 i.e. 260)

  copio.init_xmodem

  repeat while TRUE
    outa[0]:=1
    dira[0]:=1
    
    u8 := 0
    repeat while u8 == 0
      copio.receive_queue(@u8,1)    
    
    if u8 == $6 '$6  ' ACK == recive
      outa[0]:=0
      dira[0]:=0
      copio.receive_xmodem(BUFFER_SIZE)                           
      repeat while (xmodem_state := copio.process_rcv_xmodem) <>2 ' process receive queue for xmodem until no more data to process.
      
    elseif u8 == $15 ' NCK == send
      outa[0]:=0
      dira[0]:=0                
      copio.send_xmodem(BUFFER_SIZE)
      repeat while (xmodem_state := copio.process_snd_xmodem) <>2 ' process send queue for xmodem until no more data to process.        