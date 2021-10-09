NS_eeprom_drv_02_26_06
======================

Package Contents
-----------------
4 files:

NS_eeprom_test_010.spin (Top File):
   A test program demonstrating how to use the EEPROM Driver.

NS_eeprom_drv_010.spin:
   The EEPROM Driver.

NS_eeprom_drv_nocog_010.spin:
   A special version of the EEPROM Driver intended to be
   copy-and-pasted into any ASM program that wants to use
   the EEPROM Driver without taking up an extra COG.
   (See documentation below for details.)

readme.txt:
   This readme file.

Documentation
=============

 EEPROM Driver for 128k serial eeprom (AT24C1024)
 AUTHOR: Nick Sabalausky
 LAST MODIFIED: 2.26.06
 VERSION 1.0
 
 Detailed Change Log
 --------------------
 v1.0 (2.26.06)
 - Initial Release
 
 To do
 ------
 - Automatically adjust wait times when PChip's clock is <> 80MHz
 
 
 API Documentation
 ==================
 
 There are 3 ways to use this driver:
 - On a dedicated COG, accessed through SPIN
 - On a dedicated COG, accessed through ASM
 - On a non-dedicated COG, accessed through ASM
 
 To use on a dedicated COG through SPIN:
 ----------------------------------------
 1. Import the driver in the OBJ section
 
   example:
     eeprom : "NS_eeprom_drv_010.spin"  'EEPROM Driver
 
 2. Call the start() function
 
   example:
   (See the function reference below for a detailed
   explanation of start()'s parameters.)
 
     eeprom.start(28,29,0)
 
 3. To write data to the eeprom, call the Write() function.
    It will tell the driver to start writing, and then will
    immediately return.
    
    You can check the progress of the transfer by calling
    GetBytesRemaining() to retreive the number of bytes
    remaining to be written. This can be used to display a
    progress bar, if desired.
    
    You can check if the transfer is complete by calling IsDone().
 
    NOTE: Even if GetBytesRemaining() returns zero, the eeprom
          and/or driver may still be working. Therefore, do NOT rely
          on GetBytesRemaining() to determine if it's safe to stop
          the driver's COG, reset the PChip, or remove/power down
          the eeprom. Use IsDone() for this purpose instead.
 
    example:
    (See the function reference below for a detailed explanation of
    the parameters and return values of the following fucntions.)
 
       eeprom.Write(@data_buffer, eeprom_address, num_bytes)
 
       repeat until eeprom.IsDone
           bytes_remaining := eeprom.GetBytesRemaining
           'optionally display bytes_remaining to screen here
 
       'safe to power off here, if desired
 
 4. To read data from the eeprom, call the Read() function
    It will tell the driver to start reading, and then will
    immediately return.
    
    You can check the progress of the transfer by calling
    GetBytesRemaining() to retreive the number of bytes
    remaining to be read. This can be used to display a
    progress bar, if desired.
    
    You can check if the transfer is complete by calling IsDone().
 
    example:
    (See the function reference below for a detailed explanation of
    the parameters and return values of the following fucntions.)
 
       eeprom.Read(@data_buffer, eeprom_address, num_bytes)
 
       repeat until eeprom.IsDone
           bytes_remaining := eeprom.GetBytesRemaining
           'optionally display bytes_remaining to screen here
 
 5. If you're done with the eeprom driver and wish to free a cog,
    ensure no transfers are in progress with IsDone(), and
    then call the stop() function.
 
    example:
       
       repeat until eeprom.IsDone
       eeprom.stop()
 
 Optional: You may instruct the driver to automatically perform a read or write
           as soon as the driver has started by calling Read() or Write() BEFORE
           calling start().
 
 To use on a dedicated COG through ASM:
 ---------------------------------------
 1. Reserve 7 longs in HUB memory to hold the following structure:
 
    long clk_pin
    long dat_pin
    long idle_wait
    long command
    long byte_count
    long eeprom_address
    long buffer_address
 
 2. Initalize the following setup values:
 
    clk_pin:   The PChip I/O pin that is connected to the EEPROM's clock line (usually 28).
    dat_pin:   The PChip I/O pin that is connected to the EEPROM's data line (usually 29).
    idle_wait: The number of cycles the driver will sleep in its
               idle loop before checking for a command:
      Lower values:  Driver receives Read() and Write() commands more quickly
      Higher values: More power is conserved while driver is idle
      Try 0 for Hydra games, Try 500-5000 for applications requiring low power consumption
    command:   Set to COMMAND_NONE (ie 0).
 
 3. Start a new COG with COGINIT, passing it the address of "entry" as the start
    of execution, and the address of "clk_pin" as the PAR value.
 
 4. To write data to the eeprom:
 
    First, set up the following values:
 
    byte_count:                   The number of bytes to be written
    eeprom_address, bits[16..0]:  The 17-bit EEPROM address to write to
    eeprom_address, bits[31..17]: Ignored (addresses are effectively mirrored every 128k)
    buffer_address:               The HUB address of a buffer containing the bytes to be written
    
    Then, write COMMAND_WRITE to "command", and the driver will begin the transfer.
 
    During the transfer, the driver will continuously update byte_count with
    the number of bytes remaining to be written. This can be used to display a
    progress bar, if desired.
 
    When the transfer is complete, the driver will set "command" back to COMMAND_NONE (0)
 
    example:
       
       mov    temp,#10                     '10 bytes to be written
       wrlong temp,byte_count_hub_ptr      'store "10" into byte_count
 
       mov    temp,#0                      'write into first 10 bytes of eeprom
       wrlong temp,eeprom_address_hub_ptr  'store eeprom address of 0 into eeprom_address
 
       mov    temp,data_buffer_hub_ptr     'data to write starts at hub address data_buffer
       wrlong temp,buffer_address_hub_ptr  'store the hub address of data_buffer into buffer_address
 
       mov    temp,#COMMAND_WRITE          'command is "write"
       wrlong temp,command_hub_ptr         'start writing the data
       'at this point, the status of the transfer can be checked
       'by polling byte_count and command via rdlong
 
    NOTE: Even if byte_count is zero, the eeprom and/or driver may
          still be working. Therefore, do NOT rely on byte_count to determine
          if it's safe to stop the driver's COG, reset the PChip, or
          remove/power down the eeprom. Read the value of "command" for
          this purpose instead.
 
 5. To read data from the eeprom:
 
    First, set up the following values:
 
    byte_count:                   The number of bytes to be read
    eeprom_address, bits[16..0]:  The 17-bit EEPROM address to read from
    eeprom_address, bits[31..17]: Ignored (addresses are effectively mirrored every 128k)
    buffer_address:               The HUB address of a buffer where the read bytes are to be stored
    
    Then, write COMMAND_READ to "command", and the driver will begin the transfer.
 
    During the transfer, the driver will continuously update byte_count with
    the number of bytes remaining to be read. This can be used to display a
    progress bar, if desired.
 
    When the transfer is complete, the driver will set "command" back to COMMAND_NONE (0)
 
    example:
 
       mov    temp,#10                     '10 bytes to be read
       wrlong temp,byte_count_hub_ptr      'store "10" into byte_count
 
       mov    temp,#0                      'read the first 10 bytes of eeprom
       wrlong temp,eeprom_address_hub_ptr  'store eeprom address of 0 into eeprom_address
 
       mov    temp,data_buffer_hub_ptr     'buffer to read into starts at hub address data_buffer
       wrlong temp,buffer_address_hub_ptr  'store the hub address of data_buffer into buffer_address
 
       mov    temp,#COMMAND_READ           'command is "read"
       wrlong temp,command_hub_ptr         'start reading the data
       'at this point, the status of the transfer can be checked
       'by polling byte_count and command via rdlong
 
 6. If you're done with the eeprom driver and wish to free a cog,
    ensure no transfers are in progress by waiting for "command" to
    become COMMAND_NONE (0), and then use COGSTOP.
 
 Optional: You may instruct the driver to automatically perform a read or write
           as soon as the driver has started by setting up byte_count, eeprom_address,
           buffer_address, and command BEFORE lauching the COG with COGINIT.
 
 To use on a non-dedicated COG through ASM:
 -------------------------------------------
 You can save a COG by incorporating the driver into your program's
 main ASM routines, or another driver (such as a USB communication
 driver).
 
 The drawbacks are that it will take up extra space in the COG (unless
 you use an ASM paging system), and the read and write routines will
 block and not return until the transfer is complete.
 
 If that is acceptable, the process is as follows:
 
 1. Copy and paste the contents of "NS_eeprom_drv_nocog_*.spin"
    into your ASM source.
 
 2. Create and initialize the 7 long structre just as you would
    in steps 1 and 2 of "Dedicated COG through ASM" mode.
 
 3. Copy the address of clk_pin into "init_par", and then call
    the "init" routine.
 
    example:
       
       mov   init_par,clk_pin_hub_ptr
       call  #init
 
    The driver will now be initialized and ready to perfrom transfers.
 
 4. To write data to the eeprom:
    Setup byte_count, eeprom_address, and buffer_address just
    as you would in "Dedicated COG through ASM" mode. But then
    call the "write_data" routine
 
    example:
 
       mov    temp,#10                     '10 bytes to be written
       wrlong temp,byte_count_hub_ptr      'store "10" into byte_count
 
       mov    temp,#0                      'write into first 10 bytes of eeprom
       wrlong temp,eeprom_address_hub_ptr  'store eeprom address of 0 into eeprom_address
 
       mov    temp,data_buffer_hub_ptr     'data to write starts at hub address data_buffer
       wrlong temp,buffer_address_hub_ptr  'store the hub address of data_buffer into buffer_address
 
       call   #write_data                  'write the data
       'at this point, the transfer will have been completed
 
 4. To read data from the eeprom:
    Setup byte_count, eeprom_address, buffer_address, and command just
    as you would in "Dedicated COG through ASM" mode. But then
    call the "read_data" routine
 
    example:
 
       mov    temp,#10                     '10 bytes to be read
       wrlong temp,byte_count_hub_ptr      'store "10" into byte_count
 
       mov    temp,#0                      'read the first 10 bytes of eeprom
       wrlong temp,eeprom_address_hub_ptr  'store eeprom address of 0 into eeprom_address
 
       mov    temp,data_buffer_hub_ptr     'buffer to read into starts at hub address data_buffer
       wrlong temp,buffer_address_hub_ptr  'store the hub address of data_buffer into buffer_address
 
       call   #read_data                   'read the data
       'at this point, the transfer will have been completed
 
 NOTE: In this mode, you may _NOT_ instruct the driver to automatically
       perform a read or write upon completion of startup. The "init"
       routine MUST be called before either "read_data" or "write_data",
       or else the driver's behavior will be undefined.
 
       In "Dedicated COG" mode, it is possible becase the "entry"
       routine automatically ensures that "init" is called first.
       But, in this "Non-Dedicated COG" mode, the "entry" routine
       is completely omitted, thus it is up to YOU the ensure
       that "init" is called before either "read_data" or "write_data".

///////////////////////////////////////////////////////////////////////

Object "NS_eeprom_drv_010" Interface:

PUB  start(arg_clk_pin, arg_dat_pin, arg_idle_wait)
PUB  stop
PUB  Write(arg_buffer_address, arg_eeprom_address, arg_byte_count)
PUB  Read(arg_buffer_address, arg_eeprom_address, arg_byte_count)
PUB  GetBytesRemaining
PUB  IsDone

Program:     220 Longs
Variable:      9 Longs

___________________________________________________
PUB  start(arg_clk_pin, arg_dat_pin, arg_idle_wait)

 Starts the eeprom driver on a new cog.
 
     arg_clk_pin:   The PChip I/O pin connected to the EEPROM's clock line (usually 28)
     arg_dat_pin:   The PChip I/O pin connected to the EEPROM's data line (usually 29)
     arg_idle_wait: Number of cycles the driver will sleep in its idle loop before checking for a command
                      Lower values:  Driver receives Read() and Write() commands more quickly
                      Higher values: More power is conserved while driver is idle
                      Try 0 for Hydra games, Try 500-5000 for applications requiring low power consumption
     returns:   false if no cog available

_________
PUB  stop

 Stops the eeprom driver. Frees a cog.

__________________________________________________________________
PUB  Write(arg_buffer_address, arg_eeprom_address, arg_byte_count)

 Writes data to the eeprom
 
   arg_buffer_address:                 The HUB address of a buffer containing the bytes to be written
   param_eeprom_address, bits[16..0]:  The 17-bit EEPROM address to write to
   param_eeprom_address, bits[31..17]: Ignored (addresses are effectively mirrored every 128k)
   arg_byte_count:                     The number of bytes to be written

_________________________________________________________________
PUB  Read(arg_buffer_address, arg_eeprom_address, arg_byte_count)

 Reads data from the eeprom
 
   arg_buffer_address:                 The HUB address of a buffer where the read bytes are to be stored
   param_eeprom_address, bits[16..0]:  The 17-bit EEPROM address to read from
   param_eeprom_address, bits[31..17]: Ignored (addresses are effectively mirrored every 128k)
   arg_byte_count:      The number of bytes to be read

______________________
PUB  GetBytesRemaining

 Returns the number of bytes remaining to be read or written.
 NOTE: Even if the value returned is zero, the eeprom and/or driver may still
       be working. Therefore, do NOT rely on this value to determine if it's safe
       to stop the driver's COG, reset the PChip, or remove/power down the eeprom.
       Use IsDone for this purpose instead.

___________
PUB  IsDone

 Returns:
   true:  Driver is done with all operations and is waiting in an idle
          state for new commands. Also, it is safe at this point to stop the
          driver's COG, reset the PChip, or remove/power down the eeprom.
   false: Driver is still busy accessing the eeprom
//////////////////////////////////////////////////////////
// ASSEMBLY ROUTINES /////////////////////////////////////
//////////////////////////////////////////////////////////

// PUBLIC ROUTINES ///////////////////////////////////////
 entry - If you choose to run this driver on a dedicated COG,
         this is the entry point for that COG.
 
 Input:
   par: The HUB address of the following communication parameter structure (all LONGs):
        (Note: this is identical to the init_par structure used by the init subroutine)
      clk_pin(input):         The PChip I/O pin connected to the EEPROM's clock line (usually 28)
      dat_pin(input):         The PChip I/O pin connected to the EEPROM's data line (usually 29)
      idle_wait(input):       Number of cycles the driver will sleep in its idle loop before checking for a command
                                Lower values:  Driver receives Read() and Write() commands more quickly
                                Higher values: More power is conserved while driver is idle
                                Try 0 for Hydra games, Try 500-5000 for applications requiring low power consumption
      command(read/write):    Communication Variable: The command to perform (any of the COMMAND_* constants)
      byte_count(read/write): Communication Variable: The number of bytes to be read or written
      eeprom_address(write):  Communication Variable: The 17-bit EEPROM address to be read from or written to
      buffer_address(write):  Communication Variable: The HUB address of a buffer to be red into or written from
 Output:
   N/A, this code ends in an infinite loop and never exits
   unless the cog is stopped.
 
//////////////////////////////////////////////////////////
 init - Initializes the EEPROM driver
        (must be called before any other subroutines)
 
 Input:
   init_par: The HUB address of the following communication parameter structure structure (all LONGs):
             (Note: this is identical to the par structure used by the entry routine)
      clk_pin(input):         The PChip I/O pin connected to the EEPROM's clock line (usually 28)
      dat_pin(input):         The PChip I/O pin connected to the EEPROM's data line (usually 29)
      idle_wait(input):       Number of cycles the driver will sleep in its idle loop before checking for a command
                                Lower values:  Driver receives Read() and Write() commands more quickly
                                Higher values: More power is conserved while driver is idle
                                Try 0 for Hydra games, Try 500-5000 for applications requiring low power consumption
      command(read/write):    Communication Variable: The command to perform (any of the COMMAND_* constants)
      byte_count(read/write): Communication Variable: The number of bytes to be read or written
      eeprom_address(write):  Communication Variable: The 17-bit EEPROM address to be read from or written to
      buffer_address(write):  Communication Variable: The HUB address of a buffer to be red into or written from
 Output:
   none
 
//////////////////////////////////////////////////////////
 write_data - Writes data to the eeprom
 
 Input:
   param_buffer_address:               The HUB address of a buffer containing
                                       the bytes to be written
   param_eeprom_address, bits[16..0]:  The 17-bit EEPROM address to write to
   param_eeprom_address, bits[31..17]: Ignored (addresses are effectively mirrored every 128k)
   param_byte_count:                   The number of bytes to be written
   param_byte_count_addr:              The HUB address of a long which will be continuously
                                       updated with the number of bytes remaining to be written
                                       (This will have already been set by init, but it can
                                       optionally be changed prior to calling write_data)
 Output:
   none
 Precondition:
   - init must have already been called
 Postcondition:
   - C and Z will have been altered
   - eeprom clock and data bits in DIRA, INA, and OUTA will have been altered
 
//////////////////////////////////////////////////////////
 read_data - Reads data from the eeprom
 
 Input:
   param_buffer_address:               The HUB address of a buffer where the read bytes are to be stored
   param_eeprom_address, bits[16..0]:  The 17-bit EEPROM address to read from
   param_eeprom_address, bits[31..17]: Ignored (addresses are effectively mirrored every 128k)
   param_byte_count:                   The number of bytes to be read
   param_byte_count_addr:              The HUB address of a long which will be continuously
                                       updated with the number of bytes remaining to be read
                                       (This will have already been set by init, but it can
                                       optionally be changed prior to calling read_data)
 Output:
   The bytes read will be placed in the buffer at HUB address param_buffer_address
 Precondition:
   - init must have already been called
 Postcondition:
   - C and Z will have been altered
   - eeprom clock and data bits in DIRA, INA, and OUTA will have been altered
 
// INTERNAL HELPER SUBROUTINES ///////////////////////////
 send_bit - Sends the bit in C to the eeprom
 
 Input:
   C: bit to be sent to the eeprom
 Output:
   none
 Precondition:
   - clock must be low
   - timer must be at least CNT+T_LOW_HALF
 Postcondition:
   - clock will be low
   - timer will be slightly more than CNT+T_LOW_HALF
   - data pin direction will be set to output
   - C remains unchanged
 
//////////////////////////////////////////////////////////
 receive_bit - Receives a bit from the eeprom
 
 Input:
   none
 Output:
   C: bit received from the eeprom
 Precondition:
   - clock must be low
   - timer must be at least CNT+T_LOW_HALF
 Postcondition:
   - clock will be low
   - timer will be slightly more than CNT+T_LOW_HALF
   - data pin direction will be set to input
 
//////////////////////////////////////////////////////////
 send_byte - Sends a byte to the eeprom
 
 Input:
   data_byte, bits[7..0]:  byte to be sent to the eeprom
   data_byte, bits[31..8]: ignored
 Output:
   none
 Precondition:
   - clock must be low
   - timer must be at least CNT+T_LOW_HALF
 Postcondition:
   - clock will be low
   - timer will be slightly more than CNT+T_LOW_HALF
   - index will be 0
   - data pin direction will be set to output
   - data_byte remains unchanged
 
//////////////////////////////////////////////////////////
 receive_byte - Receives a byte from the eeprom
 
 Input:
   none
 Output:
   data_byte, bits[7..0]:  byte read from the eeprom
   data_byte, bits[31..8]: 0
 Precondition:
   - clock must be low
   - timer must be at least CNT+T_LOW_HALF
 Postcondition:
   - clock will be low
   - timer will be slightly more than CNT+T_LOW_HALF
   - index will be 0
   - data pin direction will be set to input
 
//////////////////////////////////////////////////////////
 check_ack - Checks for ACK from eeprom
 
 Input:
   none
 Output:
   Z: 1 if ACK was received, 0 otherwise
 Precondition:
   - clock must be low
   - timer must be at least CNT+T_LOW_HALF
 Postcondition:
   - clock will be low
   - timer will be slightly more than CNT+T_LOW_HALF
   - data pin will be set to input
 
//////////////////////////////////////////////////////////
 start_condition - Generates a "start condition"
 
 Input:
   none
 Output:
   none
 Precondition:
   - clock must be low
   - timer must be at least CNT+T_LOW_HALF
 Postcondition:
   - clock will be low
   - timer will be slightly more than CNT+T_LOW_HALF
   - data pin will be set to output
   - data will be low
 
//////////////////////////////////////////////////////////
 stop_condition - Generates a "stop condition"
 
 Input:
   none
 Output:
   none
 Precondition:
   - clock must be low
   - timer must be at least CNT+T_LOW_HALF
 Postcondition:
   - clock will be low
   - timer will be slightly more than CNT+T_LOW_HALF
   - data pin will be set to output
   - data will be high
 
//////////////////////////////////////////////////////////
 setup_device_address - Sets up a device address byte
 
 Input:
   C: r/w bit (0=write, 1=read)
   param_eeprom_address, bit[16]: p0 (MSB of 17-bit eeprom address)
 Output:
   data_byte: device address byte to be sent to the eeprom via send_byte
 Precondition:
   none
 Postcondition:
   - Z will contain p0 (MSB of 17-bit eeprom address)
   - inputs remain unchanged
 
//////////////////////////////////////////////////////////
 send_address - Sends the low 16-bits of a 17-bit eeprom address to the eeprom
                and checks for ACK (the MSB of the address is sent as part 
                of the device address)
 
 Input:
   param_eeprom_address, bits[15..0]: low 16-bits of desired 17-bit eeprom address
   param_eeprom_address, bits[31..16]: ignored (addresses are effectively mirrored every 128k)
 Output:
   none
 Precondition:
   - clock must be low
   - timer must be at least CNT+T_LOW_HALF, param_eeprom_address contains desired address
 Postcondition:
   - clock will be low
   - timer will be slightly more than CNT+T_LOW_HALF
   - index will be 0
   - data pin direction will be set to output
   - data_byte will be set to param_eeprom_address
