 ****************************
 *   Rem DR Hydra v018      *
 ****************************

This game uses the following SPIN files:
	REM_dr_hydra_data_018.spin : tilemap and tiles asset
	REM_gfx_engine_018.spin    : The REM graphic engine
	REM_tv_018.spin		   : REM graphic engine TV rasteriser
	REM_Loader_Kernel_018.spin : Colin's ASM multi-page Loader kernel, modified version
	keyboard_iso_010.spin	   : Standard keyboard driver
	
Dr Hydra is a clone of a popular NES and SNES puzzle game.
The REM engine was modified to use 8x8 tiles (instead of 16x16).
This game uses no sprites.

It features:
- One and two player game play
- Versus Computer (AI controlled code)
- Combo will send random blocks to opponent
- Joypad and keyboard controls
- Almost 4,000 lines of source code
- Hold 'START' button on gamepad to put game in super slow motion (this was a debugging tool)

Note:
The 'AI' is not very strong and plays best with its speed set to 'low'.
It's not good in game end, but can sometimes play surprisingly fast while doing lots of combo moves :)

Keyboard controls are mapped like this:

Left player (player 1):
W A S D to move block
Y = Button 'A' (Accept / Ok / Rotate clockwise)
G = Button 'B' (Cancel / Rotate counter-clockwise)

Right player (player 2):
Arrow pad and numeric keypad to move block
NumPad . = Button 'A' (Accept / Ok / Rotate clockwise)
Numpad 0 = Button 'B' (Cancel / Rotate counter-clockwise)


Credits:

Graphic assets by Louis-Philippe 'FoX' Guilbert
Code by Remi 'Remz' Veilleux

