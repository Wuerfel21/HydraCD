'///////////////////////////////////////////////////////////////////////
' 
'' EEPROM Driver for 128k serial eeprom (AT24C1024)
'' AUTHOR: Nick Sabalausky
'' LAST MODIFIED: 2.26.06
'' VERSION 1.0
'' 
'' Detailed Change Log
'' --------------------
'' v1.0 (2.26.06)
'' - Initial Release
'' 
'' To do
'' ------
'' - Automatically adjust wait times when PChip's clock is <> 80MHz
'' 
'' 
'' API Documentation
'' ==================
'' 
'' There are 3 ways to use this driver:
'' - On a dedicated COG, accessed through SPIN
'' - On a dedicated COG, accessed through ASM
'' - On a non-dedicated COG, accessed through ASM
'' 
'' To use on a dedicated COG through SPIN:
'' ----------------------------------------
'' 1. Import the driver in the OBJ section
'' 
''   example:
''     eeprom : "NS_eeprom_drv_010.spin"  'EEPROM Driver
'' 
'' 2. Call the start() function
'' 
''   example:
''   (See the function reference below for a detailed
''   explanation of start()'s parameters.)
'' 
''     eeprom.start(28,29,0)
'' 
'' 3. To write data to the eeprom, call the Write() function.
''    It will tell the driver to start writing, and then will
''    immediately return.
''    
''    You can check the progress of the transfer by calling
''    GetBytesRemaining() to retreive the number of bytes
''    remaining to be written. This can be used to display a
''    progress bar, if desired.
''    
''    You can check if the transfer is complete by calling IsDone().
'' 
''    NOTE: Even if GetBytesRemaining() returns zero, the eeprom
''          and/or driver may still be working. Therefore, do NOT rely
''          on GetBytesRemaining() to determine if it's safe to stop
''          the driver's COG, reset the PChip, or remove/power down
''          the eeprom. Use IsDone() for this purpose instead.
'' 
''    example:
''    (See the function reference below for a detailed explanation of
''    the parameters and return values of the following fucntions.)
'' 
''       eeprom.Write(@data_buffer, eeprom_address, num_bytes)
'' 
''       repeat until eeprom.IsDone
''           bytes_remaining := eeprom.GetBytesRemaining
''           'optionally display bytes_remaining to screen here
'' 
''       'safe to power off here, if desired
'' 
'' 4. To read data from the eeprom, call the Read() function
''    It will tell the driver to start reading, and then will
''    immediately return.
''    
''    You can check the progress of the transfer by calling
''    GetBytesRemaining() to retreive the number of bytes
''    remaining to be read. This can be used to display a
''    progress bar, if desired.
''    
''    You can check if the transfer is complete by calling IsDone().
'' 
''    example:
''    (See the function reference below for a detailed explanation of
''    the parameters and return values of the following fucntions.)
'' 
''       eeprom.Read(@data_buffer, eeprom_address, num_bytes)
'' 
''       repeat until eeprom.IsDone
''           bytes_remaining := eeprom.GetBytesRemaining
''           'optionally display bytes_remaining to screen here
'' 
'' 5. If you're done with the eeprom driver and wish to free a cog,
''    ensure no transfers are in progress with IsDone(), and
''    then call the stop() function.
'' 
''    example:
''       
''       repeat until eeprom.IsDone
''       eeprom.stop()
'' 
'' Optional: You may instruct the driver to automatically perform a read or write
''           as soon as the driver has started by calling Read() or Write() BEFORE
''           calling start().
'' 
'' To use on a dedicated COG through ASM:
'' ---------------------------------------
'' 1. Reserve 7 longs in HUB memory to hold the following structure:
'' 
''    long clk_pin
''    long dat_pin
''    long idle_wait
''    long command
''    long byte_count
''    long eeprom_address
''    long buffer_address
'' 
'' 2. Initalize the following setup values:
'' 
''    clk_pin:   The PChip I/O pin that is connected to the EEPROM's clock line (usually 28).
''    dat_pin:   The PChip I/O pin that is connected to the EEPROM's data line (usually 29).
''    idle_wait: The number of cycles the driver will sleep in its
''               idle loop before checking for a command:
''      Lower values:  Driver receives Read() and Write() commands more quickly
''      Higher values: More power is conserved while driver is idle
''      Try 0 for Hydra games, Try 500-5000 for applications requiring low power consumption
''    command:   Set to COMMAND_NONE (ie 0).
'' 
'' 3. Start a new COG with COGINIT, passing it the address of "entry" as the start
''    of execution, and the address of "clk_pin" as the PAR value.
'' 
'' 4. To write data to the eeprom:
'' 
''    First, set up the following values:
'' 
''    byte_count:                   The number of bytes to be written
''    eeprom_address, bits[16..0]:  The 17-bit EEPROM address to write to
''    eeprom_address, bits[31..17]: Ignored (addresses are effectively mirrored every 128k)
''    buffer_address:               The HUB address of a buffer containing the bytes to be written
''    
''    Then, write COMMAND_WRITE to "command", and the driver will begin the transfer.
'' 
''    During the transfer, the driver will continuously update byte_count with
''    the number of bytes remaining to be written. This can be used to display a
''    progress bar, if desired.
'' 
''    When the transfer is complete, the driver will set "command" back to COMMAND_NONE (0)
'' 
''    example:
''       
''       mov    temp,#10                     '10 bytes to be written
''       wrlong temp,byte_count_hub_ptr      'store "10" into byte_count
'' 
''       mov    temp,#0                      'write into first 10 bytes of eeprom
''       wrlong temp,eeprom_address_hub_ptr  'store eeprom address of 0 into eeprom_address
'' 
''       mov    temp,data_buffer_hub_ptr     'data to write starts at hub address data_buffer
''       wrlong temp,buffer_address_hub_ptr  'store the hub address of data_buffer into buffer_address
'' 
''       mov    temp,#COMMAND_WRITE          'command is "write"
''       wrlong temp,command_hub_ptr         'start writing the data
''       'at this point, the status of the transfer can be checked
''       'by polling byte_count and command via rdlong
'' 
''    NOTE: Even if byte_count is zero, the eeprom and/or driver may
''          still be working. Therefore, do NOT rely on byte_count to determine
''          if it's safe to stop the driver's COG, reset the PChip, or
''          remove/power down the eeprom. Read the value of "command" for
''          this purpose instead.
'' 
'' 5. To read data from the eeprom:
'' 
''    First, set up the following values:
'' 
''    byte_count:                   The number of bytes to be read
''    eeprom_address, bits[16..0]:  The 17-bit EEPROM address to read from
''    eeprom_address, bits[31..17]: Ignored (addresses are effectively mirrored every 128k)
''    buffer_address:               The HUB address of a buffer where the read bytes are to be stored
''    
''    Then, write COMMAND_READ to "command", and the driver will begin the transfer.
'' 
''    During the transfer, the driver will continuously update byte_count with
''    the number of bytes remaining to be read. This can be used to display a
''    progress bar, if desired.
'' 
''    When the transfer is complete, the driver will set "command" back to COMMAND_NONE (0)
'' 
''    example:
'' 
''       mov    temp,#10                     '10 bytes to be read
''       wrlong temp,byte_count_hub_ptr      'store "10" into byte_count
'' 
''       mov    temp,#0                      'read the first 10 bytes of eeprom
''       wrlong temp,eeprom_address_hub_ptr  'store eeprom address of 0 into eeprom_address
'' 
''       mov    temp,data_buffer_hub_ptr     'buffer to read into starts at hub address data_buffer
''       wrlong temp,buffer_address_hub_ptr  'store the hub address of data_buffer into buffer_address
'' 
''       mov    temp,#COMMAND_READ           'command is "read"
''       wrlong temp,command_hub_ptr         'start reading the data
''       'at this point, the status of the transfer can be checked
''       'by polling byte_count and command via rdlong
'' 
'' 6. If you're done with the eeprom driver and wish to free a cog,
''    ensure no transfers are in progress by waiting for "command" to
''    become COMMAND_NONE (0), and then use COGSTOP.
'' 
'' Optional: You may instruct the driver to automatically perform a read or write
''           as soon as the driver has started by setting up byte_count, eeprom_address,
''           buffer_address, and command BEFORE lauching the COG with COGINIT.
'' 
'' To use on a non-dedicated COG through ASM:
'' -------------------------------------------
'' You can save a COG by incorporating the driver into your program's
'' main ASM routines, or another driver (such as a USB communication
'' driver).
'' 
'' The drawbacks are that it will take up extra space in the COG (unless
'' you use an ASM paging system), and the read and write routines will
'' block and not return until the transfer is complete.
'' 
'' If that is acceptable, the process is as follows:
'' 
'' 1. Copy and paste the contents of "NS_eeprom_drv_nocog_*.spin"
''    into your ASM source.
'' 
'' 2. Create and initialize the 7 long structre just as you would
''    in steps 1 and 2 of "Dedicated COG through ASM" mode.
'' 
'' 3. Copy the address of clk_pin into "init_par", and then call
''    the "init" routine.
'' 
''    example:
''       
''       mov   init_par,clk_pin_hub_ptr
''       call  #init
'' 
''    The driver will now be initialized and ready to perfrom transfers.
'' 
'' 4. To write data to the eeprom:
''    Setup byte_count, eeprom_address, and buffer_address just
''    as you would in "Dedicated COG through ASM" mode. But then
''    call the "write_data" routine
'' 
''    example:
'' 
''       mov    temp,#10                     '10 bytes to be written
''       wrlong temp,byte_count_hub_ptr      'store "10" into byte_count
'' 
''       mov    temp,#0                      'write into first 10 bytes of eeprom
''       wrlong temp,eeprom_address_hub_ptr  'store eeprom address of 0 into eeprom_address
'' 
''       mov    temp,data_buffer_hub_ptr     'data to write starts at hub address data_buffer
''       wrlong temp,buffer_address_hub_ptr  'store the hub address of data_buffer into buffer_address
'' 
''       call   #write_data                  'write the data
''       'at this point, the transfer will have been completed
'' 
'' 4. To read data from the eeprom:
''    Setup byte_count, eeprom_address, buffer_address, and command just
''    as you would in "Dedicated COG through ASM" mode. But then
''    call the "read_data" routine
'' 
''    example:
'' 
''       mov    temp,#10                     '10 bytes to be read
''       wrlong temp,byte_count_hub_ptr      'store "10" into byte_count
'' 
''       mov    temp,#0                      'read the first 10 bytes of eeprom
''       wrlong temp,eeprom_address_hub_ptr  'store eeprom address of 0 into eeprom_address
'' 
''       mov    temp,data_buffer_hub_ptr     'buffer to read into starts at hub address data_buffer
''       wrlong temp,buffer_address_hub_ptr  'store the hub address of data_buffer into buffer_address
'' 
''       call   #read_data                   'read the data
''       'at this point, the transfer will have been completed
'' 
'' NOTE: In this mode, you may _NOT_ instruct the driver to automatically
''       perform a read or write upon completion of startup. The "init"
''       routine MUST be called before either "read_data" or "write_data",
''       or else the driver's behavior will be undefined.
'' 
''       In "Dedicated COG" mode, it is possible becase the "entry"
''       routine automatically ensures that "init" is called first.
''       But, in this "Non-Dedicated COG" mode, the "entry" routine
''       is completely omitted, thus it is up to YOU the ensure
''       that "init" is called before either "read_data" or "write_data".
''
''///////////////////////////////////////////////////////////////////////

'///////////////////////////////////////////////////////////////////////
' CONSTANTS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
CON

  LAST_ADDRESS = $1FFFF

  'EEPROM Minimum Timings at 3.3v (in 80MHz clocks, ie 12.5ns per clock)
  'Names are same as in the AT24C1024 datasheet
  T_LOW  = 200 '>104clks, >1.3us   Clock Pulse Width Low
  T_HIGH = 60  '>48clks,  >0.6us   Clock Pulse Width High
  T_LOW_HALF  = T_LOW/2
  T_HIGH_HALF = T_HIGH/2

  #0, COMMAND_NONE, COMMAND_READ, COMMAND_WRITE

'///////////////////////////////////////////////////////////////////////
' VARIABLES ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
VAR

  long cogon, cog

  long clk_pin, dat_pin
  long idle_wait
  long command
  long byte_count
  long eeprom_address, buffer_address
{
  long watch_val0
  long watch_val1
  long watch_val2
  long watch_val3
  long watch_val4
  long watch_val5
  long watch_val6
  long watch_val7
  long watch_val8
  long watch_val9
  long watch_val10
  long watch_val11
}
'///////////////////////////////////////////////////////////////////////
' OBJECTS //////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////
OBJ

'///////////////////////////////////////////////////////////////////////
' FUNCTIONS ////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

PUB start(arg_clk_pin, arg_dat_pin, arg_idle_wait)

'' Starts the eeprom driver on a new cog.
'' 
''     arg_clk_pin:   The PChip I/O pin connected to the EEPROM's clock line (usually 28)
''     arg_dat_pin:   The PChip I/O pin connected to the EEPROM's data line (usually 29)
''     arg_idle_wait: Number of cycles the driver will sleep in its idle loop before checking for a command
''                      Lower values:  Driver receives Read() and Write() commands more quickly
''                      Higher values: More power is conserved while driver is idle
''                      Try 0 for Hydra games, Try 500-5000 for applications requiring low power consumption
''     returns:   false if no cog available

  clk_pin   := arg_clk_pin
  dat_pin   := arg_dat_pin
  idle_wait := arg_idle_wait

  stop
  return cogon := (cog := cognew(@entry,@clk_pin)) > 0


'///////////////////////////////////////////////////////////////////////

PUB stop

'' Stops the eeprom driver. Frees a cog.

  if cogon~
    cogstop(cog)

  command := COMMAND_NONE

'///////////////////////////////////////////////////////////////////////

PUB Write(arg_buffer_address, arg_eeprom_address, arg_byte_count)

'' Writes data to the eeprom
'' 
''   arg_buffer_address:                 The HUB address of a buffer containing the bytes to be written
''   param_eeprom_address, bits[16..0]:  The 17-bit EEPROM address to write to
''   param_eeprom_address, bits[31..17]: Ignored (addresses are effectively mirrored every 128k)
''   arg_byte_count:                     The number of bytes to be written

  buffer_address := arg_buffer_address
  eeprom_address := arg_eeprom_address
  byte_count     := arg_byte_count
  command        := COMMAND_WRITE

'///////////////////////////////////////////////////////////////////////

PUB Read(arg_buffer_address, arg_eeprom_address, arg_byte_count)

'' Reads data from the eeprom
'' 
''   arg_buffer_address:                 The HUB address of a buffer where the read bytes are to be stored
''   param_eeprom_address, bits[16..0]:  The 17-bit EEPROM address to read from
''   param_eeprom_address, bits[31..17]: Ignored (addresses are effectively mirrored every 128k)
''   arg_byte_count:      The number of bytes to be read

  buffer_address := arg_buffer_address
  eeprom_address := arg_eeprom_address
  byte_count     := arg_byte_count
  command        := COMMAND_READ

'///////////////////////////////////////////////////////////////////////
{
PUB GetWatchAddress
'For Debugging
  return @watch_val0
}
'///////////////////////////////////////////////////////////////////////

PUB GetBytesRemaining

'' Returns the number of bytes remaining to be read or written.
'' NOTE: Even if the value returned is zero, the eeprom and/or driver may still
''       be working. Therefore, do NOT rely on this value to determine if it's safe
''       to stop the driver's COG, reset the PChip, or remove/power down the eeprom.
''       Use IsDone for this purpose instead.

  return byte_count

'///////////////////////////////////////////////////////////////////////

PUB IsDone

'' Returns:
''   true:  Driver is done with all operations and is waiting in an idle
''          state for new commands. Also, it is safe at this point to stop the
''          driver's COG, reset the PChip, or remove/power down the eeprom.
''   false: Driver is still busy accessing the eeprom

  return (command == COMMAND_NONE)

'///////////////////////////////////////////////////////////////////////
' DATA /////////////////////////////////////////////////////////////////
'///////////////////////////////////////////////////////////////////////

DAT

''//////////////////////////////////////////////////////////
''// ASSEMBLY ROUTINES /////////////////////////////////////
''//////////////////////////////////////////////////////////
''
''// PUBLIC ROUTINES ///////////////////////////////////////
'' entry - If you choose to run this driver on a dedicated COG,
''         this is the entry point for that COG.
'' 
'' Input:
''   par: The HUB address of the following communication parameter structure (all LONGs):
''        (Note: this is identical to the init_par structure used by the init subroutine)
''      clk_pin(input):         The PChip I/O pin connected to the EEPROM's clock line (usually 28)
''      dat_pin(input):         The PChip I/O pin connected to the EEPROM's data line (usually 29)
''      idle_wait(input):       Number of cycles the driver will sleep in its idle loop before checking for a command
''                                Lower values:  Driver receives Read() and Write() commands more quickly
''                                Higher values: More power is conserved while driver is idle
''                                Try 0 for Hydra games, Try 500-5000 for applications requiring low power consumption
''      command(read/write):    Communication Variable: The command to perform (any of the COMMAND_* constants)
''      byte_count(read/write): Communication Variable: The number of bytes to be read or written
''      eeprom_address(write):  Communication Variable: The 17-bit EEPROM address to be read from or written to
''      buffer_address(write):  Communication Variable: The HUB address of a buffer to be red into or written from
'' Output:
''   N/A, this code ends in an infinite loop and never exits
''   unless the cog is stopped.
'' 
                    org
entry
                    mov     init_par,par
                    call    #init

                    '---- Wait For Command ----
wait_for_command
                    mov     timer,param_idle_wait         'init timer
                    add     timer,cnt
wait_for_command_loop
                    rdlong  temp2,param_command_addr  wz  'check for a command
        if_z        add     timer,#38                     'add max clocks this loop may take to timer
        if_z        waitcnt timer,param_idle_wait         'if no command, sleep before checking again
        if_z        jmp     #wait_for_command_loop

                    '---- Run Command ----
                    rdlong  param_byte_count,param_byte_count_addr
                    mov     temp,par
                    add     temp,#20
                    rdlong  param_eeprom_address,temp     'get eeprom address
                    add     temp,#4
                    rdlong  param_buffer_address,temp     'get address of buffer

                    cmp     temp2,#COMMAND_READ   wz
        if_e        call    #read_data
        if_e        jmp     #command_done

                    cmp     temp2,#COMMAND_WRITE  wz
        if_e        call    #write_data

                    '---- Signal That The Command Is Done ----
command_done
                    wrlong  zero,param_command_addr
                    jmp     #wait_for_command

''//////////////////////////////////////////////////////////
'' init - Initializes the EEPROM driver
''        (must be called before any other subroutines)
'' 
'' Input:
''   init_par: The HUB address of the following communication parameter structure structure (all LONGs):
''             (Note: this is identical to the par structure used by the entry routine)
''      clk_pin(input):         The PChip I/O pin connected to the EEPROM's clock line (usually 28)
''      dat_pin(input):         The PChip I/O pin connected to the EEPROM's data line (usually 29)
''      idle_wait(input):       Number of cycles the driver will sleep in its idle loop before checking for a command
''                                Lower values:  Driver receives Read() and Write() commands more quickly
''                                Higher values: More power is conserved while driver is idle
''                                Try 0 for Hydra games, Try 500-5000 for applications requiring low power consumption
''      command(read/write):    Communication Variable: The command to perform (any of the COMMAND_* constants)
''      byte_count(read/write): Communication Variable: The number of bytes to be read or written
''      eeprom_address(write):  Communication Variable: The 17-bit EEPROM address to be read from or written to
''      buffer_address(write):  Communication Variable: The HUB address of a buffer to be red into or written from
'' Output:
''   none
'' 

init
                    '---- Initialization ----
                    rdlong  param_clk_pin,par            'get clock pin
                    mov     temp,par
                    add     temp,#4
                    rdlong  param_dat_pin,temp           'get data pin
                    add     temp,#4
                    rdlong  param_idle_wait,temp         'get idle_wait

                    shl     clk_mask,param_clk_pin       'setup mask for clock pin
                    shl     dat_mask,param_dat_pin       'setup mask for data pin

                    mov     clk_mask_inv,clk_mask
                    xor     clk_mask_inv,long_max        'setup inverted mask for clock pin
                    mov     dat_mask_inv,dat_mask
                    xor     dat_mask_inv,long_max        'setup inverted mask for data pin

                    add     temp,#4
                    mov     param_command_addr,temp      'get HUB address of command
                    add     temp,#4
                    mov     param_byte_count_addr,temp   'get HUB address of byte_count

{
                    '---- Setup Pointers to Watches (For Debugging) ----
                    mov     temp,#watch_val0_ptr
                    movd    watch_ptr_setup_loop,temp
                    mov     temp2,par
                    add     temp2,#(7*4)
                    mov     index,#12

watch_ptr_setup_loop
                    mov     0,temp2
                    add     temp,#1
                    movd    watch_ptr_setup_loop,temp
                    add     temp2,#4
                    djnz    index,#watch_ptr_setup_loop

'                    wrlong  clk_mask_inv,watch_val0_ptr   'output a couple of watch values
'                    wrlong  dat_mask_inv,watch_val1_ptr
                    wrlong  param_idle_wait,watch_val9_ptr
}

init_ret            ret

init_par            long    0

''//////////////////////////////////////////////////////////
'' write_data - Writes data to the eeprom
'' 
'' Input:
''   param_buffer_address:               The HUB address of a buffer containing
''                                       the bytes to be written
''   param_eeprom_address, bits[16..0]:  The 17-bit EEPROM address to write to
''   param_eeprom_address, bits[31..17]: Ignored (addresses are effectively mirrored every 128k)
''   param_byte_count:                   The number of bytes to be written
''   param_byte_count_addr:              The HUB address of a long which will be continuously
''                                       updated with the number of bytes remaining to be written
''                                       (This will have already been set by init, but it can
''                                       optionally be changed prior to calling write_data)
'' Output:
''   none
'' Precondition:
''   - init must have already been called
'' Postcondition:
''   - C and Z will have been altered
''   - eeprom clock and data bits in DIRA, INA, and OUTA will have been altered
'' 

write_data
                    '--- Setup Normal Condition ---
                    and     outa,clk_mask_inv          'set clock pin output to low
                    or      outa,dat_mask              'set data pin output to high
                    or      dira,clk_mask              'set clock pin direction to output
                    or      dira,dat_mask              'set data pin direction to output
                    mov     timer,#T_LOW_HALF
                    add     timer,cnt                  'the helper subroutines require timer to be set up like this

write_data_start
                    '--- Initiate Transfer ---
                    movs    write_data_jmp,#write_data_loop  'init loop address to "Write Byte"
                    call    #start_condition                 'generate start condition
                    test    long_max,#0   wc                 'set C to 0 (write)
                    call    #setup_device_address            'setup device address byte (including p0 and r/w bits)
                    call    #send_byte                       'send device address byte
                    call    #check_ack                       'check for ACK from eeprom
        if_nz       jmp     #write_data_start                'keep polling until ACK is received
                    call    #send_address                    'set desired eeprom address

write_data_loop
{
                    'Just a delay (For Debugging)
                    mov     big_time,big_time_init
                    add     big_time,cnt
                    waitcnt big_time,#0
                    mov     timer,#T_LOW_HALF
                    add     timer,cnt
}

                    '--- Write Byte ---
                    rdbyte  data_byte,param_buffer_address           'get byte to be written from buffer
                    call    #send_byte                               'send byte
                    call    #check_ack                               'receive ACK from eeprom
                    add     param_buffer_address,#1                  'increment buffer address
                    add     param_eeprom_address,#1                  'increment eeprom address
                    test    param_eeprom_address,#$FF  wz            'test if crossing a 256-byte page boundary
        if_z        call    #stop_condition                          'generate stop condition
        if_z        movs    write_data_jmp,#write_data_start         'change loop address to "Initiate Transfer"
                    sub     param_byte_count,#1  wz                  'decrement number of bytes left
                    wrlong  param_byte_count,param_byte_count_addr   'let other cogs know the progress so far
write_data_jmp
        if_nz       jmp     #0                                       'if not done, write next byte
                    call    #stop_condition                          'generate stop condition

                    '--- Wait For EEPROM's Write Cycle To Finish ---
write_data_wait_for_done
                    sub     param_eeprom_address,#1          'move eeprom address back to last byte written
                    call    #start_condition                 'generate start condition
                    test    long_max,#0   wc                 'set C to 0 (write)
                    call    #setup_device_address            'setup device address byte (including p0 and r/w bits)
                    call    #send_byte                       'send device address byte
                    call    #check_ack                       'check for ACK from eeprom
        if_nz       jmp     #write_data_wait_for_done        'keep polling until ACK is received
                    call    #stop_condition                  'generate stop condition

write_data_ret      ret

''//////////////////////////////////////////////////////////
'' read_data - Reads data from the eeprom
'' 
'' Input:
''   param_buffer_address:               The HUB address of a buffer where the read bytes are to be stored
''   param_eeprom_address, bits[16..0]:  The 17-bit EEPROM address to read from
''   param_eeprom_address, bits[31..17]: Ignored (addresses are effectively mirrored every 128k)
''   param_byte_count:                   The number of bytes to be read
''   param_byte_count_addr:              The HUB address of a long which will be continuously
''                                       updated with the number of bytes remaining to be read
''                                       (This will have already been set by init, but it can
''                                       optionally be changed prior to calling read_data)
'' Output:
''   The bytes read will be placed in the buffer at HUB address param_buffer_address
'' Precondition:
''   - init must have already been called
'' Postcondition:
''   - C and Z will have been altered
''   - eeprom clock and data bits in DIRA, INA, and OUTA will have been altered
'' 

read_data
                    '--- Setup Normal Condition ---
                    and     outa,clk_mask_inv          'set clock pin output to low
                    or      outa,dat_mask              'set data pin output to high
                    or      dira,clk_mask              'set clock pin direction to output
                    or      dira,dat_mask              'set data pin direction to output
                    mov     timer,#T_LOW_HALF
                    add     timer,cnt                  'the helper subroutines require timer to be set up like this

read_data_start
                    '--- Initiate Transfer ---
                    call    #start_condition           'generate start condition
                    test    long_max,#0   wc           'set C to 0 (write)
                    call    #setup_device_address      'setup device address byte (including p0 and r/w bits)
                    call    #send_byte                 'send device address byte
                    call    #check_ack                 'check for ACK from eeprom
        if_nz       jmp     #read_data_start           'keep polling until ACK is received
                    call    #send_address              'set desired eeprom address

                    call    #start_condition           'generate start condition
                    test    long_max,#1   wc           'set C to 1 (read)
                    call    #setup_device_address      'setup device address byte (including p0 and r/w bits)
                    call    #send_byte                 'send device address byte
                    call    #check_ack                 'check for ACK from eeprom

read_data_loop
{
                    'Just a delay (For Debugging)
                    mov     big_time,big_time_init
                    add     big_time,cnt
                    waitcnt big_time,#0
                    mov     timer,#T_LOW_HALF
                    add     timer,cnt
}

                    '--- Read Byte ---
                    call    #receive_byte                            'receive byte
                    sub     param_byte_count,#1  wz                  'decrement number of bytes left
                    wrlong  param_byte_count,param_byte_count_addr   'let other cogs know the progress so far
        if_nz       test    long_max,#0   wc                         'set C to 0 for "ACK" (meaning "not done")
        if_z        test    long_max,#1   wc                         'set C to 1 for "No ACK" (meaning "done")
                    call    #send_bit                                'send "ACK"/"No ACK"
                    wrbyte  data_byte,param_buffer_address           'store received byte into buffer
                    add     param_buffer_address,#1                  'increment buffer address
        if_nz       jmp     #read_data_loop                          'if not done, read next byte
                    call    #stop_condition                          'generate stop condition

read_data_ret       ret

''// INTERNAL HELPER SUBROUTINES ///////////////////////////
'' send_bit - Sends the bit in C to the eeprom
'' 
'' Input:
''   C: bit to be sent to the eeprom
'' Output:
''   none
'' Precondition:
''   - clock must be low
''   - timer must be at least CNT+T_LOW_HALF
'' Postcondition:
''   - clock will be low
''   - timer will be slightly more than CNT+T_LOW_HALF
''   - data pin direction will be set to output
''   - C remains unchanged
'' 

send_bit
                    waitcnt timer,#T_LOW_HALF       'wait for middle of clock low
                    or      dira,dat_mask           'ensure data pin is set to output
        if_nc       and     outa,dat_mask_inv       'if C=0 pull data low
        if_c        or      outa,dat_mask           'if C=1 pull data high
                    waitcnt timer,#T_HIGH           'wait for rest of clock low
                    or      outa,clk_mask           'pull clock high (bit is latched by the eeprom)
                    waitcnt timer,#T_LOW_HALF       'wait for entire clock high
                    and     outa,clk_mask_inv       'pull clock low
send_bit_ret        ret

''//////////////////////////////////////////////////////////
'' receive_bit - Receives a bit from the eeprom
'' 
'' Input:
''   none
'' Output:
''   C: bit received from the eeprom
'' Precondition:
''   - clock must be low
''   - timer must be at least CNT+T_LOW_HALF
'' Postcondition:
''   - clock will be low
''   - timer will be slightly more than CNT+T_LOW_HALF
''   - data pin direction will be set to input
'' 

receive_bit
                    waitcnt timer,#T_LOW_HALF       'wait for middle of clock low
                    and     dira,dat_mask_inv       'set data to input
                    waitcnt timer,#T_HIGH           'wait for rest of clock low
                    or      outa,clk_mask           'pull clock high
                    mov     receive_bit_temp,ina
                    shr     receive_bit_temp,param_dat_pin
                    shr     receive_bit_temp,#1 wc  'shift received bit into C 
                    waitcnt timer,#T_LOW_HALF       'wait for entire clock high
                    and     outa,clk_mask_inv       'pull clock low
receive_bit_ret     ret

receive_bit_temp    long    0

''//////////////////////////////////////////////////////////
'' send_byte - Sends a byte to the eeprom
'' 
'' Input:
''   data_byte, bits[7..0]:  byte to be sent to the eeprom
''   data_byte, bits[31..8]: ignored
'' Output:
''   none
'' Precondition:
''   - clock must be low
''   - timer must be at least CNT+T_LOW_HALF
'' Postcondition:
''   - clock will be low
''   - timer will be slightly more than CNT+T_LOW_HALF
''   - index will be 0
''   - data pin direction will be set to output
''   - data_byte remains unchanged
'' 

send_byte
                    shl     data_byte,#24
                    mov     index,#8
send_byte_loop
                    rol     data_byte,#1       wc
                    call    #send_bit
                    djnz    index,#send_byte_loop
send_byte_ret       ret

''//////////////////////////////////////////////////////////
'' receive_byte - Receives a byte from the eeprom
'' 
'' Input:
''   none
'' Output:
''   data_byte, bits[7..0]:  byte read from the eeprom
''   data_byte, bits[31..8]: 0
'' Precondition:
''   - clock must be low
''   - timer must be at least CNT+T_LOW_HALF
'' Postcondition:
''   - clock will be low
''   - timer will be slightly more than CNT+T_LOW_HALF
''   - index will be 0
''   - data pin direction will be set to input
'' 

receive_byte
                    mov     data_byte,#0
                    mov     index,#8
receive_byte_loop
                    call    #receive_bit
                    rcl     data_byte,#1
                    djnz    index,#receive_byte_loop
receive_byte_ret    ret

''//////////////////////////////////////////////////////////
'' check_ack - Checks for ACK from eeprom
'' 
'' Input:
''   none
'' Output:
''   Z: 1 if ACK was received, 0 otherwise
'' Precondition:
''   - clock must be low
''   - timer must be at least CNT+T_LOW_HALF
'' Postcondition:
''   - clock will be low
''   - timer will be slightly more than CNT+T_LOW_HALF
''   - data pin will be set to input
'' 

check_ack
                    waitcnt timer,#T_LOW_HALF    'wait for middle of clock low
                    or      outa,dat_mask
                    and     dira,dat_mask_inv    'set data to input
                    waitcnt timer,#T_HIGH        'wait for rest of clock low
                    or      outa,clk_mask        'pull clock high
                    test    dat_mask,ina   wz    'check if data pin is 0 (ACK received)
                    waitcnt timer,#T_LOW_HALF    'wait for entire clock high
                    and     outa,clk_mask_inv    'pull clock low
check_ack_ret       ret

''//////////////////////////////////////////////////////////
'' start_condition - Generates a "start condition"
'' 
'' Input:
''   none
'' Output:
''   none
'' Precondition:
''   - clock must be low
''   - timer must be at least CNT+T_LOW_HALF
'' Postcondition:
''   - clock will be low
''   - timer will be slightly more than CNT+T_LOW_HALF
''   - data pin will be set to output
''   - data will be low
'' 

start_condition
                    waitcnt timer,#T_LOW_HALF    'wait for middle of clock low
                    or      outa,dat_mask        'pull data high
                    or      dira,dat_mask        'set data pin to output
                    waitcnt timer,#T_HIGH_HALF   'wait for rest of clock low
                    or      outa,clk_mask        'pull clock high
                    waitcnt timer,#T_HIGH_HALF   'wait for middle of the clock high
                    and     outa,dat_mask_inv    'pull data low
                    waitcnt timer,#T_LOW_HALF    'wait for rest of the clock high
                    and     outa,clk_mask_inv    'pull clock low
start_condition_ret ret

''//////////////////////////////////////////////////////////
'' stop_condition - Generates a "stop condition"
'' 
'' Input:
''   none
'' Output:
''   none
'' Precondition:
''   - clock must be low
''   - timer must be at least CNT+T_LOW_HALF
'' Postcondition:
''   - clock will be low
''   - timer will be slightly more than CNT+T_LOW_HALF
''   - data pin will be set to output
''   - data will be high
'' 

stop_condition
                    waitcnt timer,#T_LOW_HALF    'wait for middle of clock low
                    or      dira,dat_mask        'set data pin to output
                    and     outa,dat_mask_inv    'pull data low
                    waitcnt timer,#T_HIGH_HALF   'wait for rest of clock low
                    or      outa,clk_mask        'pull clock high
                    waitcnt timer,#T_HIGH_HALF   'wait for middle of the clock high
                    or      outa,dat_mask        'pull data high
                    waitcnt timer,#T_LOW_HALF    'wait for rest of the clock high
                    and     outa,clk_mask_inv    'pull clock low
stop_condition_ret  ret

''//////////////////////////////////////////////////////////
'' setup_device_address - Sets up a device address byte
'' 
'' Input:
''   C: r/w bit (0=write, 1=read)
''   param_eeprom_address, bit[16]: p0 (MSB of 17-bit eeprom address)
'' Output:
''   data_byte: device address byte to be sent to the eeprom via send_byte
'' Precondition:
''   none
'' Postcondition:
''   - Z will contain p0 (MSB of 17-bit eeprom address)
''   - inputs remain unchanged
'' 

setup_device_address
                            mov     data_byte,device_address                'get device address bits
                if_c        or      data_byte,#%0001                        'if C=1, set r/w to 1
                            test    param_eeprom_address,addr_msb_mask  wz  'get address msb into Z
                if_nz       or      data_byte,#%0010                        'if address msb is 1, set p0 to 1
setup_device_address_ret    ret

''//////////////////////////////////////////////////////////
'' send_address - Sends the low 16-bits of a 17-bit eeprom address to the eeprom
''                and checks for ACK (the MSB of the address is sent as part 
''                of the device address)
'' 
'' Input:
''   param_eeprom_address, bits[15..0]: low 16-bits of desired 17-bit eeprom address
''   param_eeprom_address, bits[31..16]: ignored (addresses are effectively mirrored every 128k)
'' Output:
''   none
'' Precondition:
''   - clock must be low
''   - timer must be at least CNT+T_LOW_HALF, param_eeprom_address contains desired address
'' Postcondition:
''   - clock will be low
''   - timer will be slightly more than CNT+T_LOW_HALF
''   - index will be 0
''   - data pin direction will be set to output
''   - data_byte will be set to param_eeprom_address
'' 

send_address
                    'send address high-byte
                    mov     data_byte,param_eeprom_address
                    shr     data_byte,#8
                    call    #send_byte
                    call    #check_ack

                    'send address low-byte
                    mov     data_byte,param_eeprom_address
                    call    #send_byte
                    call    #check_ack
send_address_ret    ret

'// Data ///////////////////////////////////////////////////////////////

temp                    long    0            'just a scratchpad for calculations
temp2                   long    0            'just a scratchpad for calculations

'test_val                long    %01010101_01010101_01010101_01010101
'test_byte               long    %10110001

index                   long    0
timer                   long    0
data_byte               long    0            'paramater for send_byte and receive_byte (high 24-bits are ignored)
device_address          long    %1010_00_00  'bits 1 and 0 are placeholders for p0 (MSB of 17-bit address) and r/w, respectively
param_eeprom_address    long    0            '17-bit address in eeprom to read or write (high 15-bits are ignored)
param_buffer_address    long    0            'HUB address of buffer to be written from or read into
param_byte_count        long    0            'number of bytes left to be read/written
param_byte_count_addr   long    0            'HUB address of byte_count parameter
param_command_addr      long    0            'HUB address of command parameter
param_idle_wait         long    0            'Number of cycles the driver will sleep in it's
                                             'idle loop before checking for a command

param_clk_pin           long    0
param_dat_pin           long    0

clk_mask                long    1
clk_mask_inv            long    0            'clk_mask inverted
dat_mask                long    1
dat_mask_inv            long    0            'dat_mask inverted
addr_msb_mask           long    1<<17

{
watch_val0_ptr          long    0
watch_val1_ptr          long    0
watch_val2_ptr          long    0
watch_val3_ptr          long    0
watch_val4_ptr          long    0
watch_val5_ptr          long    0
watch_val6_ptr          long    0
watch_val7_ptr          long    0
watch_val8_ptr          long    0
watch_val9_ptr          long    0
watch_val10_ptr         long    0
watch_val11_ptr         long    0
}
{
big_time                long    0    'for debugging
'big_time_init           long    100_000_000 '1.25 sec
'big_time_init           long    100_000_000/4
big_time_init           long    10_000_000/2
}

'Commonly-needed values that cannot be used as an inline constant
long_max                long    $FFFF_FFFF   'The maximum value a long can hold
zero                    long    0            'Needed to write a 0 to HUB memory