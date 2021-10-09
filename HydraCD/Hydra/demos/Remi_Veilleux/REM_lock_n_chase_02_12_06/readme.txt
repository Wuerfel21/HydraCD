REM Lock 'N Chase Hydra Clone v012
----------------------------------

Lock'N Chase was an Intellivision game that looked a bit like pacman, but added several gameplay twists
such as closing door (both automatic and player-controlled), slightly changing maze, multiple cash bonus,
etc. It was really hard and controls were atrocious (as almost every Intellivision games ;) )

Try to reach level 10!!


BUG FIX AND UPDATE:
	v010			- Initial release
	v011			- Fix bug where exit would not always appear on level 2+
	v012			- Current level display in top corner, random generator enhanced, basic sound


REM Lock 'N Chase needs these file:

REM_LockNChase_012.spin		- The file that you need to compile, which starts the game and contains
				  all graphic assets.
REM_lnc_asm_012.spin		- Assembler file containing most of the game implementation
REM_lnc_proc_012.spin		- Additional assembler file to split up work
REM_lnc_police_012.spin		- Police 'AI' code
NS_sound_drv_030.spin		- Nick sound driver

It also uses two standard librairy files:

tv_drv_010.spin			- TV image output code
keyboard_iso_010.spin		- Keyboard driver

It supports gamepad and keyboard control:

NES gamepad:
	Press START to start game
	Move hero with D-Pad
	Press A or B to close electrical door. Only two doors can be closed at a time

Keyboard:
	Press ENTER to start game
	Move hero with arrows
	Use left SHIFT / CTRL / ALT to close door

Gameplay stuff:
	- If you close a door while a policeman walks on him, he'll get 'fried' for a couple of second
	- Grabbing the bag of cash in the vault makes the police cry, giving for free time to loot!
	- Bonus thief each 10000 bucks
	- There is a bug that can trap a policeman into its own starting door. Use it as your advantage! ;)


Making modification to the game
-------------------------------

The art assert were drawn with photoshop, and saved as standard 24-bit BMP files.
The included file in this package are:

hydra_color.bmp			- This is a 87x1 image containing all available colors on the hydra itself.
				  It should need to be modify.

tiles.BMP			- A 256x256 image containing all game tiles, in grayscale (4 level of gray).
				  Each tile is exactly 16x16 pixel, and should use the four shade of gray I used.

palette.bmp			- A 4x64 image representing the color palette used in the game.
				  Each 4 pixel row represent one palette. The game currently uses 10 palettes.
				  
Exporting data to actual game code format is done using two perl scripts, also included in this package.
To actually execute them, you'll need a Perl interpreter. Personnally I'm using ActivePerl for Windows build 806.

xgs_palette.pl			- This perl script will read the 'hydra_color.bmp' reference image, and also
				  read the 'palette.bmp' game palette. It will output hexadecimal color values
				  for each palette (total of 10, if you look at the line: for($j=0; $j<10; $j++))
				  The text output can now be copy/pasted into the game, in the main source file
				  named 'REM_LockNChase_010.spin', at the bottom where you see this line:
				  palette00               byte $02,$3A,$1B,$0D

xgs_export.pl			- This script reads 'tiles.bmp', and outputs hexadecimal data for each tile
				  (total of 53: for($c=0; $c<=53; $c++)) by looking at the grayscale value
				  and mapping black to color 0, light gray to 1, medium to 2, and white to 3.
				  
The game also defines a tilemap, which is the game maze, along with some initialisation code that will set which
palette is going to be used for each tile. *Actually, there are also some dumb hard-coded color values here and
there in the code.
