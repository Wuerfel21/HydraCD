NS_deep_cavern_02_14_06
========================

5 files:

NS_deep_cavern_020.spin (Top File):
   A "caves of mars" style game.

NS_sound_drv_040.spin:
   My sound driver.

NS_keyboard_drv_keyconstants_010.spin:
   A modified version of keyboard_iso_010.spin that
   adds KB_* constants for all control keys.

NS_graphics_drv_small_010.spin:
   A modification of graphics_drv_010.spin removes arcs, text,
   and rounded pixels for "plot", which shrinks this driver
   from 810 longs to 467 longs.

readme.txt:
   This readme file.

To play:
  Move left and right with the gamepad or the arrow keys, but don't hit the walls!

Detailed Change Log
--------------------
v2.0 (2.14.06):
- Collision Detection
- Psuedo-3D Perspective
- Redone Color Scheme
- Player "Drops In"
- Player Can Die and Restart
- Space Optimizations
- Added Sound Effects

v1.3 (2.5.06):
- Fixed bug: Keyboard would not move player if no controller was present.

v1.2 (2.2.06):
- Optimized DrawCavern()
- Added keyboard input
- Graphical improvements

v1.1 (2.2.06):
- Replaced random function with ? operator
- Changed clock from 40MHz to 80MHz
- Add outline to walls
- Optimized playfield rendering by drawing the "hole" instead of the walls
- Renamed Draw_Walls() to DrawCavern() to reflect new method of rendering
