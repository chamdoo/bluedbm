source board.tcl
source $xbsvdir/scripts/xbsv-synth-ip.tcl

#xbsv_synth_ip aurora_64b66b 8.3 aurora_64b66b_0 [list CONFIG.interface_mode {Framing} CONFIG.C_GT_LOC_5 {1} CONFIG.C_GT_LOC_1 {X}]
xbsv_synth_ip mig_7series 2.0 ddr3_0 [list CONFIG.BOARD_MIG_PARAM Custom CONFIG.XML_INPUT_FILE "$project_dir/../../xilinx/$boardname-ddr3-mig.prj" CONFIG.Component_Name ddr3_0 CONFIG.RESET_BOARD_INTERFACE Custom ]
