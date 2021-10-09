rem Convert tiles to .spin
xgsbmp bbuster.bmp bbuster_tiles_001.spin -hydra -phase:f0 -trans:FF00F0 -bias_red:1.0 -bias_green:1.0 -bias_blue:1.0

rem Convert map to .spin
xgsbmp bbuster_map.txt bbuster_map_001.spin -asciimap -hydra
