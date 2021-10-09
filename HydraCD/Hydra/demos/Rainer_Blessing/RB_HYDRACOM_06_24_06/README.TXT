HydraCom

The application transfers a file to the Hydra EEPROM.


Instructions:

- load RB_HYDRACOM onto the Hydra EEPROM (The Hydra is reset everytime
  the serial connection is closed.)
- Wait until the red LED is lit until you start the PC application

Modify the BUFFER_SIZE parameter in RB_HYDRACOM to the size you need.

Examples: 

- Send: HydraCom -c 4 -s <filename>
- Receive: HydraCom -c 4 -r <filename>
