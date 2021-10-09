' /////////////////////////////////////////////////////////////////////////////
' Glow Led object - simple glows the led slowly, lets you know the processor
' is processing, and looks very cool --
'
' AUTHOR: Andre' LaMothe
' LAST MODIFIED: 2.09.06
' VERSION 0.1
' COMMENTS: Simple call start(@rate) where rate is $00000000 - $FFFFFFFF
' $00000800 creates a 1 second cycle approx., looks nice
' ///////////////////////////////////////////////////////////////////////////


CON

DEBUG_LED_PORT_MASK = $00000001 ' debug LED is on I/O P0


VAR

  long  cogon, cog


PUB start(glow_led_parms_ptr) : okay

'' Start glowing LED- starts a cog
'' returns false if no cog available
''
  stop
  okay := cogon := (cog := cognew(@entry,glow_led_parms_ptr)) > 0


PUB stop

'' Stops driver - frees a cog

  if cogon~
    cogstop(cog)


DAT

                        org $000
' Entry point 
'
entry
                        ' initialize debug LED
                        or  DIRA, #DEBUG_LED_PORT_MASK  ' set pin to output
                        and OUTA, #(!DEBUG_LED_PORT_MASK) & $1FF ' turn LED off to begin

                        mov lptr, par                   ' copy parameter pointer to global pointer for future ref
                        rdlong debug_led_inc, lptr      ' now access main memory and retrieve the value

:glow_loop

                        ' add the current brightness to the counter
                        add debug_led_ctr, debug_led_brightness                 wc                      

                        ' based on carry turn LED on/off
        if_c            or  OUTA, #DEBUG_LED_PORT_MASK
        if_nc           and OUTA, #(!DEBUG_LED_PORT_MASK) & $1FF

                        ' update brightness and invert increment if we hit 0
                        add debug_led_brightness, debug_led_inc                 wz                      
        if_z            neg debug_led_inc, debug_led_inc

                        ' loop and do forever                                                                                          
                        jmp #:glow_loop         

'// VARIABLES //////////////////////////////////////////////////////////////////

debug_led_ctr           long                    $00000000   ' PWM counter
debug_led_inc           long                    $0000000    ' increment to add to counter
debug_led_brightness    long                    $80000000   ' current brightness level
lptr                    long                    $00000000   ' general long pointer


                   