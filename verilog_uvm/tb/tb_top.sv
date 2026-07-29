// tb_top.sv
// Top de simulacion: reloj/reset, las 3 instancias de axi_if (agente UVM,
// cpu_accel_bfm, DUT), el mux estatico que las une (nunca hay dos maestros
// activos a la vez, ver plan §5), el DUT y el BFM, y el arranque de UVM.

module tb_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi_pkg::*;
  import tb_pkg::*;

  // ---------------- reloj y reset ----------------
  logic clk;
  logic rst_n;

  initial clk = 1'b0;
  always #5 clk = ~clk; // 100 MHz

  initial begin
    rst_n = 1'b0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
  end

  // ---------------- interfaces ----------------
  axi_if #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) agent_if (.clk(clk), .rst_n(rst_n));
  axi_if #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) bfm_if   (.clk(clk), .rst_n(rst_n));
  axi_if #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) dut_if   (.clk(clk), .rst_n(rst_n));

  bfm_ctrl_if ctrl ();

  // mux estatico maestro->esclavo: bus_sel=1 mientras el bfm esta trabajando
  // (entre ctrl.start y ctrl.done); el agente UVM nunca esta activo en ese
  // intervalo (lo garantiza el orden de fases del test, no hay arbitraje real)
  wire bus_sel = ctrl.start && !ctrl.done;

  assign dut_if.awaddr  = bus_sel ? bfm_if.awaddr  : agent_if.awaddr;
  assign dut_if.awlen   = bus_sel ? bfm_if.awlen   : agent_if.awlen;
  assign dut_if.awsize  = bus_sel ? bfm_if.awsize  : agent_if.awsize;
  assign dut_if.awburst = bus_sel ? bfm_if.awburst : agent_if.awburst;
  assign dut_if.awvalid = bus_sel ? bfm_if.awvalid : agent_if.awvalid;
  assign dut_if.wdata   = bus_sel ? bfm_if.wdata   : agent_if.wdata;
  assign dut_if.wstrb   = bus_sel ? bfm_if.wstrb   : agent_if.wstrb;
  assign dut_if.wlast   = bus_sel ? bfm_if.wlast   : agent_if.wlast;
  assign dut_if.wvalid  = bus_sel ? bfm_if.wvalid  : agent_if.wvalid;
  assign dut_if.bready  = bus_sel ? bfm_if.bready  : agent_if.bready;
  assign dut_if.araddr  = bus_sel ? bfm_if.araddr  : agent_if.araddr;
  assign dut_if.arlen   = bus_sel ? bfm_if.arlen   : agent_if.arlen;
  assign dut_if.arsize  = bus_sel ? bfm_if.arsize  : agent_if.arsize;
  assign dut_if.arburst = bus_sel ? bfm_if.arburst : agent_if.arburst;
  assign dut_if.arvalid = bus_sel ? bfm_if.arvalid : agent_if.arvalid;
  assign dut_if.rready  = bus_sel ? bfm_if.rready  : agent_if.rready;

  // esclavo->maestro: solo el maestro activo recibe valid/ready; datos y
  // respuestas se difunden a ambos (el que no esta activo no los usa)
  assign agent_if.awready = bus_sel ? 1'b0 : dut_if.awready;
  assign bfm_if.awready   = bus_sel ? dut_if.awready : 1'b0;
  assign agent_if.wready  = bus_sel ? 1'b0 : dut_if.wready;
  assign bfm_if.wready    = bus_sel ? dut_if.wready : 1'b0;
  assign agent_if.bvalid  = bus_sel ? 1'b0 : dut_if.bvalid;
  assign bfm_if.bvalid    = bus_sel ? dut_if.bvalid : 1'b0;
  assign agent_if.bresp   = dut_if.bresp;
  assign bfm_if.bresp     = dut_if.bresp;
  assign agent_if.arready = bus_sel ? 1'b0 : dut_if.arready;
  assign bfm_if.arready   = bus_sel ? dut_if.arready : 1'b0;
  assign agent_if.rvalid  = bus_sel ? 1'b0 : dut_if.rvalid;
  assign bfm_if.rvalid    = bus_sel ? dut_if.rvalid : 1'b0;
  assign agent_if.rdata   = dut_if.rdata;
  assign bfm_if.rdata     = dut_if.rdata;
  assign agent_if.rresp   = dut_if.rresp;
  assign bfm_if.rresp     = dut_if.rresp;
  assign agent_if.rlast   = dut_if.rlast;
  assign bfm_if.rlast     = dut_if.rlast;

  // ---------------- DUT y BFM ----------------
  axi_ram #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .axi(dut_if)
  );

  cpu_accel_bfm #(
    .RUTA_SALIDA("output_crop_gray.raw")
  ) bfm (
    .axi(bfm_if),
    .ctrl(ctrl)
  );

  // ---------------- arranque de UVM ----------------
  initial begin
    uvm_config_db#(virtual axi_if.master)::set(null, "uvm_test_top.env.agent.driver",  "vif", agent_if);
    uvm_config_db#(virtual axi_if.monitor)::set(null, "uvm_test_top.env.agent.monitor", "vif", agent_if);
    uvm_config_db#(virtual bfm_ctrl_if)::set(null, "uvm_test_top", "ctrl_vif", ctrl);
    run_test();
  end

endmodule
