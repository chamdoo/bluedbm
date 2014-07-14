# to run:
#     make gen.vc707
# to build:
#     make build.vc707

XBSVDIR=../../xbsv

include ../config/Makefile.list

S2H = InterfaceRequest PlatformRequest
H2S = InterfaceIndication PlatformIndication
BSVFILES = Interface.bsv Top.bsv
CPPFILES=main.cpp rawWordManager.cpp
Dma = DmaF
PINS = Std

include ../config/Makefile.emultest.jca
XBSVFLAGS += --bscflags ' -D SYNTH_ARG="sys_clk_200mhz,pci_sys_reset_n"'
XBSVFLAGS += -D PinType=BlueDBMTopPins

include $(XBSVDIR)/Makefile.common

prebuild::
	(cd $(BOARD); vivado -mode batch -source ../synth-ip.tcl)
