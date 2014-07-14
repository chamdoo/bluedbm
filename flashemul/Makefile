include ../config/Makefile.list

S2H = InterfaceRequest PlatformRequest
H2S = InterfaceIndication PlatformIndication
BSVFILES = Interface.bsv Top.bsv
CPPFILES=main.cpp rawWordManager.cpp
Dma = DmaF
PINS = Std

include ../config/Makefile.emultest.jca

XBSVDIR=../../xbsv
BOARD=vc707
TOP=PcieTopDbm.bsv
MKTOP=mkPcieTop

.PHONY:
prebuild::
	cp ../xilinx/$(BOARD)-ddr3-mig.prj $(BOARD)
	(cd $(BOARD); vivado -mode batch -source ../synth-ip.tcl)

include $(XBSVDIR)/Makefile.common
