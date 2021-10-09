' /////////////////////////////////////////////////////////////////////////////
' Nintendo Gamepad Driver - Reads the nintendo gamepads.
' Reads both gamepads at once into a 16-bit
' vector, each gamepad is encoded as 8-bits in the following format:

' RIGHT  = %00000001 (lsb)
' LEFT   = %00000010
' DOWN   = %00000100
' UP     = %00001000
' START  = %00010000
' SELECT = %00100000
' B      = %01000000
' A      = %10000000 (msb)
'
' Gamepad 0 is the left gamepad, gamepad 1 is the right game pad
' 
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 2.09.06
' VERSION 0.1
' COMMENTS: Use gamepads, note that when a controller is NOT pluggedin
' the value returned is $FF, this can be used to "detect" if the game
' controller is present or not.
' 
' ///////////////////////////////////////////////////////////////////////////


CON

DEBUG_LED_PORT_MASK = $00000001


VAR

  long  cogon, cog


PUB start(gamepad_parms_ptr) : okay

'' Start NES gamepad driver - starts a cog
'' returns false if no cog available
''
  stop
  okay := cogon := (cog := cognew(@entry,gamepad_parms_ptr)) > 0


PUB stop

'' Stops driver - frees a cog

  if cogon~
    cogstop(cog)


DAT

                        org $0
' Entry point 
'
entry

                        ' initialize debug LED
                        or DIRA, #DEBUG_LED_PORT_MASK            ' set pin to output
                        and OUTA, #(!DEBUG_LED_PORT_MASK) & $1FF ' turn LED off to begin

:glow_loop


                        add debug_led_ctr, debug_led_brightness                 wc
                        
        if_c            or OUTA, #DEBUG_LED_PORT_MASK
        if_nc           and OUTA, #(!DEBUG_LED_PORT_MASK) & $1FF

                        add debug_led_brightness, debug_led_inc                                         

                        cmp debug_led_brightness,DEBUG_LED_MAX                  wc, wz                            
        if_ae           neg debug_led_inc, debug_led_inc
'       if_ae           or OUTA, #DEBUG_LED_PORT_MASK

                        cmp debug_led_brightness,DEBUG_LED_MIN                  wc, wz                  
        if_b            neg debug_led_inc, debug_led_inc
'       if_b            and OUTA, #!DEBUG_LED_PORT_MASK 
                                                                                                                                       
                        jmp #:glow_loop         


'// VARIABLES //////////////////////////////////////////////////////////////////

debug_led_ctr           long                    $00000000
debug_led_inc           long                    $00001fff

debug_led_brightness    long                    $80000000

DEBUG_LED_MAX           long                    $fffff000
DEBUG_LED_MIN           long                    $00000fff


                   