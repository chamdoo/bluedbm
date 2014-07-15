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
XBSVFLAGS += -D PinType=BlueDBMTopPins
XBSVFLAGS += -D IMPORT_HOSTIF

include $(XBSVDIR)/Makefile.common

prebuild::
	(cd $(BOARD); vivado -mode batch -source ../synth-ip.tcl)
