' //////////////////////////////////////////////////////////////////////
' COPIO Driver (io engine)              
' AUTHOR: Colin Phillips
' LAST MODIFIED: 1.20.06
' VERSION 0.1
' Full Duplex - Set for 115,200 bps 8-N-1 protocol
'
' Mini Tutorial
' -------------
' 1) Instantiate the copio object. (i.e. in OBJ section add ' copio : "copio_drv_001.spin" ')
' 2) Call the start(...) function passing a pointer to 8 LONG's (defaultly set to 0)
' 3) Call the receive_circular(...) function passing a pointer to a buffer, and the size of the buffer. e.g. 1K Buffer.
' 4) Call send(ptr, size) function to send packets of any size (0...N) across tx pin.
' Returns true: 'packet has successfully been placed on the queue.'
' Returns false: 'packet has failed to be placed on the queue.'
' 5) Call receive_queue(ptr, size) function to take packets off the receive queue
' Returns bytes retrieved on success.
' Returns false: if not enough bytes on the queue.
' Note: if 'ptr' parameter is -1 ($FFFFFFFF), returns: bytes on queue.
' Note: if 'size' parameter is -1 ($FFFFFFFF), retrieves all bytes on queue.
' Note: if 'ptr' parameter is 0. functions as normal except doesnt write to destination.
'
' The recommended strategy with the send(..) function is to simply send packets of data whenever you wish.
' If the send function returns false, either continuously retry, or do some more processing (e.g. another frame),
' and then retry.
'
' The recommended strategy with the receive_queue(..) function is to simply call the function to retrieve any size packts of data.
'
' The receive_queue(..) function is there to make the receiving of packets much easier.
' a send_queue(..) function would also make the sending of packets easier, but is not so essential.
'
' The recommended strategy with the receive(..) function is to continuously feed it buffers of atleast known size.
' Otherwise data will be lost.


CON

' COPIO HEADER ---------------------------------------------------------------

  system_rate = 80_000_000/115200                       ' 11.52kbps 8-N-1

  h_copio_rx = 0
  h_copio_rxidx = 1
  h_copio_tx = 2
  h_copio_txidx = 3
  h_copio_rxbuf = 4
  h_copio_rxsize = 5
  h_copio_txbuf = 6
  h_copio_txsize = 7

VAR

long  cogon, cog, cog_copioptr
long  cog_rx, cog_tx
long  cog_rx_buf, cog_rx_size
byte u8
word u16
long u32
  
PUB start(copioptr, rxpin, txpin, baudrate) : okay

'' Start COPIO driver - starts a cog
'' returns false if no cog available
''
  LONG[@io_pinrx] := 1<<rxpin
  LONG[@io_pintx] := 1<<txpin
  LONG[@io_rate] := clkfreq / baudrate
  LONG[@io_ratedelay] := (clkfreq / baudrate)>>1        ' take sample from half way in (assuming a perfect square-wave signal.)

  ' receive and send queue pointers.
  cog_rx_buf := 0
  cog_rx_size := 0
  cog_rx := 0
  cog_tx := 0
  cog_copioptr := copioptr
  stop
  okay := cogon := (cog := cognew(@entry,copioptr)) > 0

PUB stop

'' Stop COPIO driver - frees a cog

  if cogon~
    cogstop(cog)

PUB send(ptr, size)
'' Asynchronously Sends a packet of data from address 'ptr' of length 'size'
'' returns false if queue is full.
''
  if(LONG[cog_copioptr + CONSTANT(h_copio_txsize*4)]) ' Grabbed?
    RETURN false ' Queue Full / Busy / Not grabbed.
  ' set packet ptr and size
  LONG[cog_copioptr + CONSTANT(h_copio_txbuf*4)] := ptr
  LONG[cog_copioptr + CONSTANT(h_copio_txsize*4)] := size
  
RETURN true

PUB receive(ptr, size)
'' Asynchronously Receives a packet of data to address 'ptr' of length 'size'
'' returns false if queue is full.
''
  if(LONG[cog_copioptr + CONSTANT(h_copio_rxsize*4)]) ' Grabbed?
    RETURN false ' Queue Full / Busy / Not grabbed.
  ' set packet ptr and size
  LONG[cog_copioptr + CONSTANT(h_copio_rxbuf*4)] := ptr
  LONG[cog_copioptr + CONSTANT(h_copio_rxsize*4)] := size
  
RETURN true

PUB receive_clear
'' Clears receive queue
''
  cog_rx := LONG[cog_copioptr + CONSTANT(h_copio_rxidx*4)]

PUB receive_queue(ptr, size) | len, ref, sptr, otherside
'' Copies 'size' bytes off the circular queue, into ptr
'' returns: false if not enough bytes on the queue.
'' returns: bytes retrieved on success.
'' Note: if 'ptr' parameter is -1 ($FFFFFFFF), returns: bytes on queue.
'' Note: if 'size' parameter is -1 ($FFFFFFFF), retrieves all bytes on queue.
'' Note: if 'ptr' parameter is 0. functions as normal except doesnt write to destination.
''
  if(cog_rx_size==0 or size==0)
    RETURN false
  
  otherside := 0
  ref := LONG[cog_copioptr + CONSTANT(h_copio_rxidx*4)]
  if(ref==cog_rx_size)
    ref:=0
    
  if(cog_rx>ref) ' ref is on the other side, put it infront.
    ref+=cog_rx_size
    otherside := 1
    
  if(ptr==-1)    ' if ptr parameter is -1 just return buffer size.
    RETURN ref-cog_rx

  if(size==-1)
    size := ref-cog_rx

  ' check if there is enough bytes on the queue to retrieve.
  if(cog_rx + size > ref)
    RETURN false
    
  sptr := cog_rx_buf + cog_rx

  if(ptr<>0)
    ' if head is infront or size is small enough on this side then just copy size
    if(otherside==0 or size<(cog_rx_size-cog_rx))
      len := size
      ' copy ahead data (from rx...rx+size)
      bytemove(ptr, sptr, len)       
    else ' head is behind. then copy all the way to the end, and then some of the beginning.
      len := cog_rx_size - cog_rx
      ' copy ahead data (from rx...rx_size)
      bytemove(ptr, sptr, len)
      ptr+=len
      ' copy remaining behind data (from 0...size-len)
      bytemove(ptr, cog_rx_buf, size-len)
  
  cog_rx+=size
  if(cog_rx=>cog_rx_size)
    cog_rx-=cog_rx_size

  RETURN size

PUB receive_circular(ptr, size)
'' Sets COPIO to Circular Receiving mode.
'' For easy queue receiving.
''
  ' set packet ptr and size
  LONG[cog_copioptr + CONSTANT(h_copio_rxbuf*4)] := $80000000 | ptr
  LONG[cog_copioptr + CONSTANT(h_copio_rxsize*4)] := size
  cog_rx_buf := ptr
  cog_rx_size := size

'' ////////////////////////////////////////////////////////////////////////////
'' XMODEM Protocol
'' http://www.amulettechnologies.com/support/help/xmodem.htm
'' ////////////////////////////////////////////////////////////////////////////

CON

XMODEM_SOH = $01
XMODEM_EOT = $04
XMODEM_ACK = $06
XMODEM_NAK = $15
XMODEM_ETB = $17
XMODEM_CAN = $18
XMODEM_C = $43

VAR

byte XMODEM_packet_no, XMODEM_mode
word XMODEM_crc
long XMODEM_ptr, XMODEM_size

PUB init_xmodem

  XMODEM_mode := 255

PUB receive_xmodem(ptr, size)
'' Receives a file using the XModem Protocol. (Receiver Initiates Handshake)
''
  receive_clear                                         ' Clear Queue
  
  u8 := XMODEM_C                                        ' Send 'C' 
  send(@u8, 1)

  XMODEM_packet_no := 0
  XMODEM_mode := 1
  XMODEM_ptr := ptr
  XMODEM_size := size

' process_xmodem

' repeat while process_xmodem    
  
PUB process_xmodem : retval
'' Processes Rceieve queue
'' Returns: 0 - No data processed
'' Returns: 1 - Some data processed
'' Returns: 2 - Done. (default)
'' (no error checking implemented)

  retval := 0                                           
  
  case XMODEM_mode
    1:' Check Reply
      if(receive_queue(@u8, 1))
        retval := 1
        case u8
          XMODEM_SOH:
            XMODEM_mode := 2
          XMODEM_EOT:
            u8 := XMODEM_ACK
            send(@u8, 1)
            XMODEM_mode := 255                         
          XMODEM_ETB:
            u8 := XMODEM_ACK
            send(@u8, 1)
            XMODEM_mode := 255
    2:' Retrieve Packet Number, (Packet Number^0xff), 128 bytes packet data.
      if(receive_queue(-1, -1)=>2)                      ' 2+ bytes on queue?
        retval := 1
        receive_queue(@XMODEM_packet_no, 1)
        receive_queue(@u8, 1)
        ' [+] check XMODEM_packet_no + u8 == 0xff
        XMODEM_mode := 3
    3:' Retrieve 128 Byte Packet Data
      if(receive_queue(-1, -1)=>CONSTANT(128+2))        ' Packet + 16-bit CRC on queue?
        retval := 1                  
        if(XMODEM_size=>128)
          receive_queue(XMODEM_ptr, 128)
          XMODEM_ptr+=128
          XMODEM_size-=128
        else
          if(XMODEM_size>0)
            receive_queue(XMODEM_ptr, XMODEM_size)
            XMODEM_ptr+=XMODEM_size
            receive_queue(0, 128-XMODEM_size)           ' ignore rest - not enough space
            XMODEM_size:=0
          else
            receive_queue(0, 128) ' ignore rest - not enough space
            
        receive_queue(@XMODEM_crc, 2)
        ' [+] check XMODEM_crc against packet
        u8 := XMODEM_ACK
        send(@u8, 1)
        XMODEM_mode := 1
    255:
      retval := 2                                       ' DONE
  
DAT

'**********************************
'* Assembly language COPIO driver *
'**********************************

                        org
'
'
' Entry
entry

                        ' setup io pins
                        or      outa, io_pintx          ' default output on stop bit (1)
                        mov     dira, io_pintx          ' io_dirmask

:loop

' GENERAL PROCESS /////////////////////////////////////////////////////////////

' update transmit pointer/size

                        cmp     io_tsize, #0    wz      ' data to stream?
        if_nz           jmp     #:skip_update
                        ' no data to stream, update registers.
                        mov     r1, #0
                        mov     r0, par
                        add     r0, #h_copio_txsize*4
                        rdlong  io_tsize, r0    wz      ' read and check last parameter - only update if not 0. (in caller code, set this parameter last)
        if_z            jmp     #:skip_update
                        
                        wrlong  r1, r0          ' set parameter to 0 txsize
                        sub     r0, #4
                        rdlong  io_tptr, r0
                        wrlong  r1, r0          ' set parameter to 0 txbuf
                        mov     io_tidx, #0     ' reset transmit counter
:skip_update

' update receive pointer/size

                        cmp     io_rsize, #0    wz      ' data to save?
        if_nz           jmp     #:skip_update_r
                        ' no data to save, update registers.
                        mov     r1, #0
                        mov     r0, par
                        add     r0, #h_copio_rxsize*4
                        rdlong  io_rsize, r0    wz      ' read and check last parameter - only update if not 0. (in caller code, set this parameter last)
        if_z            jmp     #:skip_update_r

                        test    io_rsize, io_circularmask wz ' circular receiving mode. ?
                        
        if_z            andn    io_rsize, io_circularmask    ' if so remove bit mask, so io_rsize just holds the size of the circular buffer.
        
        if_nz           wrlong  r1, r0          ' set parameter to 0 (except in circular mode)
                        sub     r0, #4
                        rdlong  io_rptr, r0
        if_nz           wrlong  r1, r0          ' set parameter to 0 (except in circular mode)
                        mov     io_ridx, #0     ' reset receive counter
:skip_update_r
                        

' RECEIVE LOGIC ///////////////////////////////////////////////////////////////

' io_rmode 0 - Lock onto Start bit (0)
' io_rmode 1..N - Sample Data bits
  
                        cmp     io_rmode, #0    wz
        if_z            jmp     #:start_lock

' SAMPLE DATA BITS

                        ' check if bit duration passed.
                        mov     r0, ina
                        mov     r1, cnt
                        sub     r1, io_rcnt
                        cmp     r1, io_rate     wc
        if_c            jmp     #:rx_continue           ' cnt-io_rcnt < io_rate ?

                         ' passed, move rcnt along by 1 bit duration (approx this time period), shift sample into io_rdata
                        add     io_rcnt, io_rate                        
                        
                        shr     io_rdata, #1
                        test    r0, io_pinrx    wz
        if_nz           or      io_rdata, #$100
                        add     io_rmode, #1

                        cmp     io_rmode, #11   wz
        if_nz           jmp     #:rx_continue           ' More bits to do?

' RECEIVED ALL DATA BITS
                        mov     io_rmode, #0            ' reset mode to start bit lock

                        and     io_rdata, #$ff          ' cut off the stop bit.

                        cmp     io_rsize, #0    wz      ' data to save
        if_z            jmp     #:recv_cont

                        wrbyte  io_rdata, io_rptr       ' set byte
                        add     io_rptr, #1
                        sub     io_rsize, #1
        
:recv_cont
                        ' increment byte counter. (For DEBUG / Progress bar purposes)
                        wrlong  io_rdata, par
                        add     io_ridx, #1
                        mov     r0, par
                        add     r0, #h_copio_rxidx*4
                        wrlong  io_ridx, r0

                        
                        
                        jmp     #:rx_continue

' START BIT LOCK
:start_lock
                        ' read RX pin and save current time point.
                        mov     r0, ina
                        mov     io_rcnt, cnt
                        test    r0, io_pinrx    wz

        if_z            sub     io_rcnt, io_ratedelay   ' align sampling to max peak of signal.
        if_z            mov     io_rmode, #1            ' set mode to 1 (start data sampling)
        if_z            mov     io_rdata, #0            ' receive bits.

:rx_continue

' SEND LOGIC //////////////////////////////////////////////////////////////////

' io_tmode 0 - Send Start bit (0)
' io_tmode 1..N - Send Data bits
  
                        cmp     io_tmode, #0    wz
        if_z            jmp     #:start_send
' SEND DATA BITS
                        mov     r1, cnt
                        sub     r1, io_tcnt
                        cmp     r1, io_rate     wc
        if_c            jmp     #:tx_continue           ' cnt-io_tcnt < io_rate ?
                        
                        ' passed, move tcnt along by 1 bit duration (approx this time period), shift io_tdata into pin.
                        add     io_tcnt, io_rate                        
                        add     io_tmode, #1

                        cmp     io_tmode, #11          wz
        if_z            jmp     #:tx_sentall            ' All bits sent?
                        
                        shr     io_tdata, #1    wc
        if_nc           andn    outa, io_pintx
        if_c            or      outa, io_pintx

                        jmp     #:tx_continue                                                     
' SENT ALL DATA BITS + STOP BIT
:tx_sentall
                        mov     io_tmode, #0            ' reset mode to start.

                        ' increment byte counter. (For DEBUG / Progress bar purposes)
                        mov     r0, par
                        add     r0, #h_copio_txidx*4
                        add     io_tidx, #1
                        wrlong  io_tidx, r0
                       
                        jmp     #:tx_continue
' SEND START BIT
:start_send

                        cmp     io_tsize, #0    wz      ' data to stream?
        if_z            jmp     #:tx_continue

                        ' set TX pin to 0, save current time point.
                        andn    outa, io_pintx
                        mov     io_tcnt, cnt
                        mov     io_tmode, #1

                        ' get byte
                        rdbyte  io_tdata, io_tptr       ' get byte
                        or      io_tdata, stopbits      ' set bits 8-31 to 1 (STOP BIT - upto 24 stop bits)                                
                        add     io_tptr, #1
                        sub     io_tsize, #1
                        
'                       jmp     #:tx_continue
:tx_continue
            
                        jmp     #:loop


r0                      long                    $0
r1                      long                    $0
r2                      long                    $0
stopbits                long                    $ffffff00
io_tidx                 long                    $0
io_tdata                long                    $0
io_tmode                long                    $0
io_tcnt                 long                    $0
io_tptr                 long                    $0
io_tsize                long                    $0
io_ridx                 long                    $0
io_rdata                long                    $0
io_rmode                long                    $0
io_rcnt                 long                    $0
io_rptr                 long                    $0
io_rsize                long                    $0
'io_dirmask             long                    $40000000
io_pinrx                long                    $80000000
io_pintx                long                    $40000000
io_rate                 long                    system_rate
io_ratedelay            long                    system_rate/2                   ' assumed for a perfect square wave (sample 1/2 a bit after positive signal)
io_circularmask         long                    $80000000