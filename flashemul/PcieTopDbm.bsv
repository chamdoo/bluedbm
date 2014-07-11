// Copyright (c) 2014 Quanta Research Cambridge, Inc.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Vector            :: *;
import Clocks            :: *;
import GetPut            :: *;
import FIFO              :: *;
import Connectable       :: *;
import ClientServer      :: *;
import DefaultValue      :: *;
import PcieSplitter      :: *;
import PcieTracer        :: *;
import Xilinx            :: *;
import PCIEWRAPPER       :: *;
import Portal            :: *;
import Leds              :: *;
import Top               :: *;
import MemSlaveEngine    :: *;
import MemMasterEngine   :: *;
import PcieCsr           :: *;
import MemSlave          :: *;
import MemTypes          :: *;
import Bscan             :: *;
`ifndef BSIM
import PcieEndpointX7    :: *;
`endif

import AuroraImportVC707 :: *;

`ifndef DataBusWidth
`define DataBusWidth 64
`endif
`ifndef NumberOfMasters
`define NumberOfMasters 1
`endif
`ifndef PinType
`define PinType Empty
`endif
`ifdef USES_FCLK1
`define CLOCK_ARG  defaultClock
`else
`define CLOCK_ARG
`endif

`ifdef USES_BSCAN
`define BSCAN_ARG  local_bscan
`else
`define BSCAN_ARG
`endif

// implemented in TlpReplay.cxx
import "BDPI" function Action put_tlp(TLPData#(16) d);
import "BDPI" function ActionValue#(TLPData#(16)) get_tlp();
import "BDPI" function Bool can_put_tlp();
import "BDPI" function Bool can_get_tlp();

typedef `DataBusWidth DataBusWidth;
typedef `NumberOfMasters NumberOfMasters;
typedef `PinType PinType;

interface PcieHost#(numeric type dsz, numeric type nSlaves);
   interface Vector#(16,MSIX_Entry)              msixEntry;
   interface MemMaster#(32,32)                   master;
   interface Vector#(nSlaves,MemSlave#(40,dsz))  slave;
   interface Put#(Tuple2#(Bit#(64),Bit#(32)))    interruptRequest;
   interface Client#(TLPData#(16), TLPData#(16)) pci;
   interface BscanTop bscanif;
endinterface

(* synthesize *)
module  mkPcieHost#(PciId my_pciId)(PcieHost#(DataBusWidth, NumberOfMasters));
   Clock epClock125 <- exposeCurrentClock();
   Reset epReset125 <- exposeCurrentReset();
   let dispatcher <- mkTLPDispatcher;
   let arbiter    <- mkTLPArbiter;
   Vector#(NumberOfMasters,MemSlaveEngine#(DataBusWidth)) sEngine <- replicateM(mkMemSlaveEngine(my_pciId));
   Vector#(NumberOfMasters,MemSlave#(40,DataBusWidth)) slavearr;
   MemInterrupt intr <- mkMemInterrupt(my_pciId);
   BscanTop bscan <- mkBscanTop(3); // Use USER3  (JTAG IDCODE address 0x22)
   BscanLocal lbscan <- mkBscanLocal(bscan, clocked_by bscan.tck, reset_by bscan.rst);

   Vector#(PortMax, MemMasterEngine) mvec;
   for (Integer i = 0; i < valueOf(PortMax) - 1 + valueOf(NumberOfMasters); i=i+1) begin
       let tlp;
       if (i == portInterrupt)
           tlp = intr.tlp;
       else if (i >= portAxi) begin
           tlp = sEngine[i - portAxi].tlp;
           slavearr[i - portAxi] = sEngine[i - portAxi].slave;
       end
       else begin
           mvec[i] <- mkMemMasterEngine(my_pciId);
           tlp = mvec[i].tlp;
       end
       mkConnection((interface Server;
                        interface response = dispatcher.out[i];
                        interface request = arbiter.in[i];
                     endinterface), tlp);
   end

   PcieTracer  traceif <- mkPcieTracer();
   mkConnection(traceif.bus, (interface Client;
                                 interface request = arbiter.outToBus;
                                 interface response = dispatcher.inFromBus;
                              endinterface));
`ifndef BSIM
   Reg#(Bit#(TAdd#(TlpTraceAddrSize,1))) bscanPcieTraceBramWrAddrReg <- mkReg(0);
   BscanBram#(Bit#(TAdd#(TlpTraceAddrSize,1)), TimestampedTlpData) pcieBscanBram <- mkBscanBram(127, bscanPcieTraceBramWrAddrReg, lbscan.loc[1]);
   mkConnection(pcieBscanBram.bramClient, traceif.tlpdata.bscanBramServer);
   rule tdorule;
      lbscan.loc[1].tdo(pcieBscanBram.data_out());
   endrule
`endif

   PcieControlAndStatusRegs csr <- mkPcieControlAndStatusRegs(traceif.tlpdata);
   MemSlave#(32,32) my_slave <- mkMemSlave(csr.client);
   mkConnection(mvec[portConfig].master, my_slave);

   interface msixEntry = csr.msixEntry;
   interface master = mvec[portPortal].master;
   interface slave = slavearr;
   interface interruptRequest = intr.interruptRequest;
   interface pci = traceif.pci;
   interface BscanTop bscanif = lbscan.loc[0];
endmodule: mkPcieHost

interface PcieTop#(type ipins);
`ifndef BSIM
   (* prefix="PCIE" *)
   interface PciewrapPci_exp#(PcieLanes) pcie;
   (* always_ready *)
   method Bit#(NumLeds) leds();
   (* prefix="" *)
   interface ipins       pins;
`endif
endinterface

`ifndef BSIM
(* no_default_clock, no_default_reset *)
`endif
module mkPcieTop#( Clock pci_sys_clk_p, Clock pci_sys_clk_n,
		   Clock sys_clk_p,     Clock sys_clk_n,
		   Reset pci_sys_reset_n,
		   Clock gtx_clk_0_p, Clock gtx_clk_0_n,
		   Clock gtx_clk_1_0_p, Clock gtx_clk_1_0_n)
   (PcieTop#(BlueDBMTopPins));


   Vector#(AuroraPorts,Clock) gtx_clk_p;
   gtx_clk_p[0] = gtx_clk_0_p;
   gtx_clk_p[1] = gtx_clk_1_0_p;
   Vector#(AuroraPorts,Clock) gtx_clk_n;
   gtx_clk_n[0] = gtx_clk_0_n;
   gtx_clk_n[1] = gtx_clk_1_0_n;

`ifdef BSIM
   let dc <- exposeCurrentClock;
   let dr <- exposeCurrentReset;
   Clock epClock125 = dc;
   Reset epReset125 = dr;
   PcieHost#(DataBusWidth, NumberOfMasters) pciehost <- mkPcieHost(PciId{ bus:0, dev:0, func:0});
   // connect pciehost.pci to bdip functions here
   rule from_bdpi if (can_get_tlp);
      TLPData#(16) foo <- get_tlp;
      pciehost.pci.response.put(foo);
      //$display("from_bdpi: %h %d", foo, valueOf(SizeOf#(TLPData#(16))));
   endrule
   rule to_bdpi if (can_put_tlp);
      TLPData#(16) foo <- pciehost.pci.request.get;
      put_tlp(foo);
      //$display("to_bdpi");
   endrule
`else
   Clock sys_clk_200mhz <- mkClockIBUFDS(sys_clk_p, sys_clk_n);
   Clock sys_clk_200mhz_buf <- mkClockBUFG(clocked_by sys_clk_200mhz);
   Clock pci_clk_100mhz_buf <- mkClockIBUFDS_GTE2(True, pci_sys_clk_p, pci_sys_clk_n);
   // Instantiate the PCIE endpoint
   PcieEndpointX7#(PcieLanes) ep7 <- mkPcieEndpointX7( clocked_by pci_clk_100mhz_buf
						      , reset_by pci_sys_reset_n
						       );

   Clock epClock125 = ep7.epClock125;
   Reset epReset125 = ep7.epReset125;
   PcieHost#(DataBusWidth, NumberOfMasters) pciehost <- mkPcieHost(
         PciId{ bus:  ep7.cfg.bus_number(), dev: ep7.cfg.device_number(), func: ep7.cfg.function_number()},
         clocked_by epClock125, reset_by epReset125);
   mkConnection(ep7.tlp, pciehost.pci, clocked_by epClock125, reset_by epReset125);
`endif

   PortalTop#(40, 64, BlueDBMTopPins, NumMasters) portalTop <- mkPortalTop(sys_clk_200mhz, pci_sys_reset_n, gtx_clk_p, gtx_clk_n, clocked_by epClock125, reset_by epReset125);
   mkConnection(pciehost.master, portalTop.slave, clocked_by epClock125, reset_by epReset125);
   if (valueOf(NumberOfMasters) > 0) begin
      mapM(uncurry(mkConnection),zip(portalTop.masters, pciehost.slave));
   end

   // going from level to edge-triggered interrupt
   Vector#(15, Reg#(Bool)) interruptRequested <- replicateM(mkReg(False, clocked_by epClock125, reset_by epReset125));
   rule interrupt_rule;
     Integer intr_num = 0;
     for (Integer i = 0; i < 15; i = i + 1) begin
	 if (intr_num == 0 && portalTop.interrupt[i] && !interruptRequested[i])
             intr_num = i+1;
	 interruptRequested[i] <= portalTop.interrupt[i];
     end
     if (intr_num != 0) begin // i= 0 for the directory
        MSIX_Entry msixEntry = pciehost.msixEntry[intr_num];
        pciehost.interruptRequest.put(tuple2({msixEntry.addr_hi, msixEntry.addr_lo}, msixEntry.msg_data));
     end
   endrule

`ifndef BSIM
   interface pcie = ep7.pcie;
   method Bit#(NumLeds) leds();
      return extend({ep7.user.lnk_up(),3'd2});
   endmethod
   interface pins = portalTop.pins;
`endif
endmodule
