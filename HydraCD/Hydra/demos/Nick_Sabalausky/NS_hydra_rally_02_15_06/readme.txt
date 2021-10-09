NS_hydra_rally_02_15_06
========================

5 files:

NS_hydra_rally_021.spin (Top File):
   The beginnings of a racing game based on the Deep Cavern codebase.

NS_sound_drv_040.spin:
   My sound driver.

NS_keyboard_drv_keyconstants_010.spin:
   A modified version of keyboard_iso_010.spin that
   adds KB_* constants for all control keys.

NS_graphics_drv_small_010.spin:
   A modification of graphics_drv_010.spin removes arcs, text,
   and rounded pixels for "plot", which shrinks this driver
   from 810 longs to 467 longs.

readme.txt: This readme file.

To play:
  Move left and right with the gamepad or the arrow keys, but stay on the track!

Detailed Change Log
--------------------
v2.1 (2.15.06):
- Engine sound keeps playing
- Psuedo-3D Perspective on Gates
- Camera moves left and right

v2.0 (2.14.06):
- Merged original version of racer (NS_deep_cavern_alt_013.spin)
  with newest version of Deep Cavern (NS_deep_cavern_020.spin)
- Reversed direction of scrolling
