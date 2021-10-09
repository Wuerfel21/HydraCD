'//////////////////////////////////////////////////////////////////////////////
CON

  _clkmode = xtal1 + pll4x
  _xinfreq = 10_000_000


  CLOCKS_PER_BIT = 16_000 ' number of system clocks per data bit

'//////////////////////////////////////////////////////////////////////////////
VAR

  long curr_cnt, end_cnt
  long x,y,z

'//////////////////////////////////////////////////////////////////////////////
OBJ

  square : "square_gen01"


'//////////////////////////////////////////////////////////////////////////////
PUB start

  'square.start(40_000_000 / (2*1_000_00) )
  
  'repeat while(1)
    'Send_Data_Hydra_Net(%11110101, 8, CLOCKS_PER_BIT)

  
  DIRA[18] := 1
  DIRA[19] := 1

  OUTA[18] := 1
  OUTA[19] := 1

  repeat while(1)
    result := result 

'//////////////////////////////////////////////////////////////////////////////
PUB Send_Data_Hydra_Net(data, num_bits, clks_bit)              | curr_bit

' data -  32-bit that holds the data in the lower n bits, 8, 16, or 24 bits
'         only 8 bits supported for now to maintain synchronization with receiver
' num_bits - number of bits to send, for now assumes 8 always 
' trans_rate - the number of clocks to send each bit
' 
' this function sends 16-bits out on the hydra net
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
  data := (data << 1) | %1_00000000_0

  ' get current count to prepare for loop

  end_cnt := CNT + clks_bit

  ' send data out of the LSB
  repeat curr_bit from 0 to 9
    ' begin transmission loop ----------------------------

    ' send out LSB
    OUTA[2] := data & %0000000001

    ' shift data packet to right
    data := data >> 1
    
    ' wait for counter to reach this count      
    waitcnt(end_cnt)            

    ' update end count for next iteration
    end_cnt += clks_bit 
    ' end transmission loop ------------------------------

     