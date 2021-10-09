*************************************
*   Rem Tutorial game skeleton v015 *
*************************************

Welcome to REM gfx engine tutorial!
Instead of writing a full documentation, I've decided to comment directly in the code.
That way, you have immediate access to a working example!

First, open up 'REM_Tutorial_015.spin'. Compile and run it.
You should see a brownish background with some marbles and programmer's art.
Near the center there's your mouse cursor. If you have a mouse plugged, you should be able to
move the mouse around. Clicking on the left or right button will set graphic engine parameters.
Be warned that you can easily end up with a totally black or white screen. Don't worry, just click
again and move a bit. If needed, restart the application completely.

Next to the mouse cursor is another sprite, somewhat animating: it cycles thru its 4 frames.
By using the gamepad (in port #1) or the keyboard arrow pad, you can move this sprite.

So this simple tutorial shows:
- Tilemap and tiles
- Sprite display
- Sprite animation
- Mouse input being handled in assembly
- Gamepad and keyboard input also handled

It also invisibly demonstrates:
- Multi-page assembly loader kernel
- Parallel processing using 3 rendering cogs

If you want to see a real-life example of what can be done using this engine, trying compiling
'REM_Alien_Invader'.
NOTE: REM_Alien_Invader uses a slightly customised version of rem_gfx_engine, and was using
a older version of the loader kernel.

Your first task will be to read this file from top to bottom. Concentrate on reading the comments.
You can skip irrelevant parts, you can always go back reading them later on when you'll need it.

As you'll see, coding is not clearly user friendly. The file is quite massive and there's no game
yet! You'll have to familiarise with the different code section, some of them you will never have
to modify at all.

I'm including here my explanation on using the exportation perl scripts along with the graphical
file format used by these tools:

First, you need to install Perl, which can be found here:
http://www.activestate.com/Products/Download/Download.plex?id=ActivePerl

In the ActivePerl 5.8.7.815 section, you'll see Windows version,
download the MSI installer package. Personnaly my perl is installed in
C:\Perl, which might be the default path.

Now to execute the scripts, you'll need a text editor of some sort,
because simply running command line won't give you the text output you
need. So on my machine, I'm using Textpad as a simple IDE.

Let's take an example with xgs_sprite.pl, which is used to output data
for a sprite. Open it up in your favorite editor. Right at the top,
you'll see the line:
my $name = "cursor"
This means that the script will load 'cursor.bmp', which is a 4 frames
cursor shape. You can change this to export another sprite.
To launch the script, I'm using Textpad to start an external tool which is :
C:\Perl\Bin\perl.exe -W $File, starting in the current directory.

$File is a token in Textpad used to output the current text file, in
this case, xgs_sprite.pl.
If everything works, the command will spit out in the output window
several rows of data, starting with a line like:
cursor000   Long $000000, $34234, $.... etc
These lines now need to be copy/pasted over in the code to replace the sprite data.
You'll see this sprite in REM_Tutorial_015.spin, around line 613.

More or less the same procedure applies to the script 'xgs_tiles_export.pl',
which is used to output 48 tiles of data for the map. It always read
'tiles.bmp', and the resulting text output have to go in
REM_tutorial_data_015.spin, starting around line 42.

The last script is 'xgs_convert_mappy.pl', which is a quick'n dirty
script that will convert the text output of Mappy (a free Windows map
editor) to the actual format used in my engine. It will read the file
'remmap.txt' as input and output the scrolling map, which should be
pasted over in 'REM_tutorial_data_015.spin', starting at line 24.

If you need Mappy, it can be found here:
http://www.geocities.com/SiliconValley/Vista/7336/robmpy.htm
Download version V1.4.
Once you have Mappy, you can open my map named 'remmap.fmp', and have
some fun editing it. When you're ready to export it, use 'File / Export
as text...'. Mappy will pop a dialog box, you absolutely have to
UNCHECK 'Colour Map', and then select '1D Format' for map output. Then
press OK. Output should take a split second, and presto, you should
have a brand new 'remmap.txt' file, ready for conversion.

That covers all exportation.

Now If you want to modify the actual BMP of any object in the game,
you'll need Photoshop or something similarily powerful (i.e.: not MSPaint).

Example: open up cursor.bmp in photoshop.

You'll see a 16 x 64 image, which is 4 different frames of cursor
shape, each one exactly 16 x 16. The BMP is in 8-bit palettised mode, so
most of photoshop filter and effect are not allowed. You can convert it
to RGB mode if you want, and then later transfer it back into 8-bit
Indexed color mode, using Custom Palette included with the game named
'Hydra_colortable.ACT'. The sprite will be color-reduced and ready to
be exported in the game.

If for any reason you want to change the size or number of animation
frames of a sprite, you'll need to modify the code appropriately.

Last, tiles.BMP is a 128x128 indexed color image that contains the 48
tiles used by the exported. The first one is always plain white (needed by
Mappy). All the others can be changed at will. Just remember to always return back
to indexed color if you switched to RGB mode, and also remember to save your BMP, then
run the appropriate perl script, then copy/paste the output over the
right data in the code.

p.s.: The only BMP not used by the game is 'hydra_color.BMP', which is
a simply 86 x 1 RGB BMP, 1 pixel for each color the Hydra can generate.
It was used to create the photoshop indexed color table.

Hope that'll help!
