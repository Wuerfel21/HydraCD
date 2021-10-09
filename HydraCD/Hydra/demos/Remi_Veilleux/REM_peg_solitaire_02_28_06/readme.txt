 ****************************
 *   Rem Peg Solitaire v016 *
 ****************************

This game uses the following SPIN files:
	REM_marble_data_016.spin   : tilemap and tiles asset
	REM_gfx_engine_016.spin    : The REM graphic engine
	REM_tv_016.spin		   : REM graphic engine TV rasteriser
	REM_Loader_Kernel_016.spin : Colin's ASM multi-page Loader kernel, modified version
	keyboard_iso_010.spin	   : Standard keyboard driver
	mouse_iso_010.spin	   : Standard mouse driver

It features 4 different levels with increasing difficulty, mouse, gamepad and keyboard controls,
real-time timer, help button, undo button.

The object of the game is to remove all marble (except the last one), by jumping over a marble and
landing on an empty spot. Use the 'Help' button to find out valid moves if you want to learn the
basics. If you end up with no more possible moves, then the game is over. You may press 'N' to try
again, or press the fourth button (keyboard shortcut: L) to go to the next Level.
This function will only be available if you succeeded (i.e.: ending up with only 1 marble).

Good luck reaching level 4! And solving it!

Keyboard controls are:
Arrow Pad to control,
SpaceBar to click

Credits:

Graphic assets by Louis-Philippe 'FoX' Guilbert
Code by Remi 'Remz' Veilleux

