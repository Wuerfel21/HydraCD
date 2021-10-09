XGSBMP Version 1.6 Readme
=========================

Contents:

xgsbmp.cpp - XGSBMP tool source code
xgsbmp.exe - XGSBMP tool executeable

Background:

The XGSBMP tool was derived from SXBMP, an XGS Micro/Pico Edition tool for converting BMP images and ASCII maps to SX Microcontroller .src code. With the XGSBMP tool you'll be able to convert Sprites and ASCII tile maps over to compatible formats for XGS Pico, Micro, and Hydra consoles.

How to use (Hydra):

Convert tilesets to .spin
=========================

xgsbmp tileset.bmp tileset.spin -hydra -phase:f0 -trans:FF0000 -bias_red:1.0 -bias_green:1.0 -bias_blue:1.0

What this will do is convert a 24-bit BMP image (tileset.bmp) into a .SPIN source file (tileset.spin).

The output is 8bpp Hydra standard 'CCCCMLLL' format, with the exception that all values are subtracted by 2 ($02), and Transparancy is taken as $00, and Black is taken as $10.

The -hydra parameter is required so the converter knows that you wish to output a .spin compatible file for the Hydra. (If left off, it will default to SX Microcontroller output i.e. for the XGS Micro/Pico Editions)
The -phase:f0 parameter simply adds $f0 onto every color pixel (shifting the chroma angle left 22.5 degrees), this may or may not be needed, depending on how your XGS engine deals with chroma and it's colorburst reference settings.
The -trans:FF0000 parameter is an RRGGBB hexadecimal value (like those in .html, photoshop for instance) which sets the Transparancy color to Red. That is any pixel that has the RGB value FF0000 (or 255,0,0 in decimal form) is stored as $00. NOTE: There is -ZERO- tolerance in this.
The -bias_red, -bias_green, and -bias_blue parameters simply tell xgsbmp that when color matching (finding the closest Hydra color to the 24-bit pixel in question) to perceive certain primary color distances as closer.
How this factors in the color matching equation is as follows:

int closest_color_HYDRA(float r, float g, float b)
{
.
.
.
.

	// Find Closest Color /////////////////////////////////////////////////
	z_best = -1;
	z_value = 0;
	
		for(n=0;n<COLOR_WHEEL_HYDRA_TOTAL;n++)
		{
		r2 = (g_color_wheel_HYDRA[n]>>16)&0xff;
		g2 = (g_color_wheel_HYDRA[n]>>8)&0xff;
		b2 = (g_color_wheel_HYDRA[n])&0xff;

		z = (r2-r)*(r2-r)*g_bias_r+
			(g2-g)*(g2-g)*g_bias_g+
			(b2-b)*(b2-b)*g_bias_b;
		// closer value //
		if(z<z_value || z_best==-1) z_best = n, z_value = z;
		}

}

As you can see 3D distance measurement is used to find the closest color, and each axis of color has a biasing parameter. All the bias's default to 1.0

Convert tilemaps to .spin
=========================

xgsbmp tilemap.txt tilemap.spin -asciimap -hydra

What this will do is convert an ASCII tilemap (tilemap.txt) into a .SPIN source file (tilemap.spin)

The output is 16-bit (WORDs) per tile index. The rest of the parameters for the map are inside your ASCII Map file. (see ASCII Map Format below)

The -hydra parameter is required so the converter knows that you wish to output a .spin compatible file for the Hydra. (If left off, it will default to SX Microcontroller output i.e. for the XGS Micro/Pico Editions)
THe -asciimap parameter is required so that the converter knows that you wish to have your ASCII map encoded into a 16-bit tilemap cells.

ASCII Map Format
================

Here is an example of an ASCII Map file

; this is the map file. symbols are case sensitive.
; for use with the Hydra/Micro/Pico Compatible XGSBMP.
WIDTH 16
HEIGHT 32
VRAM_WIDTH 128
VRAM_HEIGHT 128
TILE_WIDTH 16
TILE_HEIGHT 16
DEFAULT (0,0)
DEFINE '.' (7,6)
DEFINE '!' (6,3)
DEFINE ':' (6,2)
DEFINE '/' (5,0)
DEFINE '-' (6,0)
DEFINE '\\' (7,0)
DEFINE '(' (5,1)
DEFINE '#' (6,1)
DEFINE ')' (7,1)
DEFINE 'Y' (4,0)
DEFINE 'y' (4,1)
DEFINE '?' (2,4)
DEFINE '{' (3,4)
DEFINE '=' (4,4)
DEFINE '}' (5,4)
START 		; next line starts
............!.Y.
..{===}.....!.y.
............!...
............!...
............!!!!
--\....??.......
##).............
##).............
##).../--\......
##)...(##)......
##)...(##)......
##)...(##)......
##)...(##)......
##)...(##)......
##)...(##)......
##)...(##)..Y...
............y...
................
...!!!....!!!...
...!!!....!!!...
.......??.......
...!!......!!...
....!!!..!!!....
......!!!!......
..???..???..???.
..?....?.?..?.?.
..?....?.?..???.
..?....?.?..?...
..???..???..?...
................
................
................

Now what all these commands do are as follows...

; This is my comment
Line comment. Use if you wish to put comments in your map file.


'WIDTH 16'
Specifies the number of Tiles going across in your map. If a line has less characters than this, then the remaining characters will be filled with DEFAULT [see +].


'HEIGHT 32'
Specifies the number of Tiles going down in your map. If you have more map lines listed than this it will not add them, and will try to interpret them as instructions.


'VRAM_WIDTH 128'
Specifies the width in pixels of the Tileset (e.g. 128x128 image containing various tiles) that would be typically stored on the Hydra (i.e. for the COP 1.0 engine). This is just a number used for calculation purposes [see *].


'VRAM_HEIGHT 128'
Specifies the height in pixels of the planned Tileset. [see *]


'TILE_WIDTH 16'
Specifies the width in pixels of the individual tile. (e.g. 16x16 tile/sprite)


'TILE_HEIGHT 16'
Specifies the height in pixels of the individual tile. (e.g. 16x16 tile/sprite)


'DEFAULT (0,0)'

[+] Specifies the default Tile index to store if lines have less characters than WIDTH. in this case 0,0 sprite offset in the VRAM.


'DEFINE '.' (7,6)'

Specifies the Tile index to store if the character '.' is interpreted. in this case 7,6 sprite offset in the VRAM.


'(x,y)'

[*] The parameters in brackets specify 2 dimensional coordinates inside a planned tileset. The formula for the value stored is

Value = y*TILE_HEIGHT*VRAM_WIDTH + x*TILE_WIDTH

Infact in all truthfulness the formula is

Value = y*TILE_HEIGHT*VRAM_WIDTH + (x*TILE_WIDTH)%TILE_WIDTH + TILE_HEIGHT*(x*TILE_WIDTH)/TILE_WIDTH

The difference is that when the x tile reference goes beyond the limit (in this case >7, i.e. 8 16x16 sprites fit horizontally, side by side in a 128x128 tileset). it functions as if the y is incremented by one line. The purpose of this is so that you can refer to the VRAM memory linearly as (i,0) where i goes from 0 to 63. or as 2 dimensionally as (x,y) where both x and y go from 0 to 7.


'START'

Simply tells the XGSBMP parser that the next line is where the Tile map data begins, and will last for 'HEIGHT' lines.


'i' and '$x'

Alternatively you can use decimal (i) and hexadecimal ($x) numbers to reference tiles. for instance 'DEFINE 'c' $1ca0' will convert all character 'c''s into $1ca0 and 'DEFINE 'b' 100' will convert all character 'b''s into 100.


Convert general data to .spin
=============================

xgsbmp bounce.wav bounce.spin -op:copy -hydra

What this will do is convert a data file (bounce.wav) into a .SPIN source file (bounce.spin). Note: This is a generic data copy operation and doesn't try to decode any format (WAV etc.)



Created by Colin Phillips - colin.phillips@gmail.com
----------------------------------------------------