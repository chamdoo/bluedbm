source board.tcl
source $xbsvdir/scripts/xbsv-synth-ip.tcl

xbsv_synth_ip aurora_64b66b 8.3 aurora_64b66b_0 [list CONFIG.interface_mode {Framing} CONFIG.C_GT_LOC_5 {1} CONFIG.C_GT_LOC_1 {X}]
#xbsv_synth_ip ddr3 1.7 ddr3_0 [list CONFIG.interface_mode {Framing} ]