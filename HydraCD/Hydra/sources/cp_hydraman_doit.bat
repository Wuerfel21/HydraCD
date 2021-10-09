rem Convert tiles to .spin
xgsbmp cp_hydraman_tiles_001.bmp CP_HYDRAMAN_TILES_001.spin -hydra -phase:f0 -trans:FF00F0 -bias_red:1.0 -bias_green:1.0 -bias_blue:1.0

rem Convert map to .spin
xgsbmp CP_HYDRAMAN_MAP_001.txt CP_HYDRAMAN_MAP_001.spin -asciimap -hydra