COP Test 0.6 Readme
===================

If you want to modify the sprites, edit tiles.bmp in paint, then run doit.bat which will convert tiles.bmp into tile.spin then simply build the CP_COP_test_005 as usual. If you don't get color, fudge the Clock Frequency as usual.

Should demonstrate 6 sprites moving on the screen in a sine-derived motion, and a 7th sprite (16x256) controlled by the mouse.

to change the overscans edit the constants at the top of the cop_drv_005.

e.g.

  pix_ntsc      = 10  <- controls the width of the pixels, 16 is equal to color burst.
  framecnt_ntsc = 64  <- controls the number of frames (quadpixels rendered).

pix_ntsc*4*framecnt_ntsc must be less than 3016 (52.6us), equal amounts of left & right overscan are added.

The scanline preparation (sprites placed on scanline) is done in the 10.9us HSYNC + Left Overscan.
Debug LED + Cop_Status register are updated in the Right Overscan. so be careful not to squash the overscans, or these processes will mess up the WAITVID sync.

Remz color table was used for the XGSBMP palette conversion.

Also colors data in the COP engine are stored as 8 bit chroma-luma like the standard PChip video format, EXCEPT all luma values are offseted -2. That is Black is $00 instead of $02, White is $05 instead of $07. This was to help the masking process
for transparant pixels. (transparant pixels on transparant/solid pixels work, solid pixels on transparant pixels work, but solid pixels on solid pixels dont - due to the OR'ing process)

-Colin Phillips


