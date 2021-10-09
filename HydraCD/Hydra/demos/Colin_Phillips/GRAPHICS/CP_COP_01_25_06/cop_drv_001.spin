''*****************************
''*  COP Driver v0.1          *
''*  Colin Phillips           *
''*****************************

CON

  fntsc         = 3_579_545     'NTSC color frequency
  lntsc         = 3640          'NTSC color cycles per line * 16
  sntsc         = 624           'NTSC color cycles per sync * 16

  fpal          = 4_433_618     'PAL color frequency
  lpal          = 4540          'PAL color cycles per line * 16
  spal          = 848           'PAL color cycles per sync * 16

  #0, h_cop_status, h_cop_control, h_cop_debug
  
VAR

  long  cogon, cog


PUB start(copptr) : okay

'' Start COP driver - starts a cog
'' returns false if no cog available
''
''   tvptr = pointer to TV parameters

  stop
  okay := cogon := (cog := cognew(@entry,copptr)) > 0


PUB stop

'' Stop TV driver - frees a cog

  if cogon~
    cogstop(cog)


DAT

'********************************
'* Assembly language COP driver *
'********************************

                        org
'
'
' Entry

entry
                        nop                                                     'alignment bug??? not sure yet.
                        or dira, debugled_mask                                  'set debug led to output

loop                    mov     r1, par
                        add     r1, #h_cop_debug*4

                        rdlong debugled_brightness,r1

                        add     debugled_ctr, debugled_brightness wc

        if_c            or      outa, debugled_mask                             'on carry Full Power (ON)
        if_nc           and     outa, debugled_nmask                            'else No Power (OFF)

                        jmp    #loop


r0                      long                    $0
r1                      long                    $0
r2                      long                    $0
r3                      long                    $0
debugled_ctr            long                    $0
debugled_brightness     long                    $4fffffff
debugled_mask           long                    $00000001
debugled_nmask          long                    debugled_mask^$ffffffff