' //////////////////////////////////////////////////////////////////////
' Hydra Liner                           
' AUTHOR: Colin Phillips (colin_phillips@gmail.com)
' LAST MODIFIED: 1.25.06
' VERSION 1.2
'
' CONTROLS
' NES D-pad to control liner (sets dir.)
' Keyboard Cursor keys to control liner (sets dir.)
' Mouse L/R buttons to control liner (rotates dir.)
'
' DESCRIPTION:
' Use the NES controller's D-pad to change the direction of the liner,
' survive for as long as you can, don't run over yourself or hit a wall.
' -Added score + hiscore, changed some colors, game speeds up.
' -Screen shrunken to 224x192 (from original 256x192) to free up memory
' -TV and Mouse input added (fixed controller out)
' NOTES:
' Gamepad code taken from asteroids_demo_013 by Andre' LaMothe
'
' //////////////////////////////////////////////////////////////////////

You will need the following generic library files

tv_drv_010.spin
graphics_drv_010.spin
sound_drv_010.spin
keyboard_iso_010.spin
mouse_iso_010.spin
