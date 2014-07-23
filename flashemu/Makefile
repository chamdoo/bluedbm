# to run:
#     make gen.vc707
# to build:
#     make build.vc707

XBSVDIR=../../xbsv

include ../config/Makefile.list

S2H = FlashEmuRequest PlatformRequest
H2S = FlashEmuIndication PlatformIndication
BSVFILES = FlashEmu.bsv Top.bsv
CPPFILES=main.cpp rawWordManager.cpp
Dma = DmaF
PINS = Std

include ../config/Makefile.emultest.jca
XBSVFLAGS += -D PinType=BlueDBMTopPins
XBSVFLAGS += -D IMPORT_HOSTIF

include $(XBSVDIR)/Makefile.common

ifneq ($(BOARD), bluesim)
prebuild::
	(cd $(BOARD); vivado -mode batch -source ../synth-ip.tcl)
endif