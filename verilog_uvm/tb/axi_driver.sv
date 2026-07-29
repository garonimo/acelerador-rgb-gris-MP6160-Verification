// axi_driver.sv (incluido dentro de axi_pkg)
// Traduce cada axi_txn en una rafaga AXI4 real sobre el virtual interface
// (modport master). Una rafaga por item (maximo 256 beats).

class axi_driver extends uvm_driver #(axi_txn);
  `uvm_component_utils(axi_driver)

  virtual axi_if.master vif;

  function new(string name = "axi_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if.master)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "no se encontro axi_if.master en config_db")
  endfunction

  task run_phase(uvm_phase phase);
    // valores de reposo
    vif.awvalid <= 1'b0;
    vif.wvalid  <= 1'b0;
    vif.bready  <= 1'b1;
    vif.arvalid <= 1'b0;
    vif.rready  <= 1'b1;

    forever begin
      seq_item_port.get_next_item(req);
      req.resp_error = 1'b0;
      if (req.is_write) escribir(req);
      else              leer(req);
      seq_item_port.item_done();
    end
  endtask

  // rafaga de escritura: AW -> W(*beats) -> B
  task automatic escribir(axi_txn item);
    int unsigned beats = (item.nbytes + STRB_WIDTH - 1) / STRB_WIDTH;

    @(posedge vif.clk);
    vif.awaddr  <= item.addr;
    vif.awlen   <= beats - 1;
    vif.awsize  <= $clog2(STRB_WIDTH);
    vif.awburst <= 2'b01; // INCR
    vif.awvalid <= 1'b1;
    @(posedge vif.clk);
    while (!vif.awready) @(posedge vif.clk);
    vif.awvalid <= 1'b0;

    for (int unsigned i = 0; i < beats; i++) begin
      logic [DATA_WIDTH-1:0] beat_data = '0;
      logic [STRB_WIDTH-1:0] beat_strb = '0;
      for (int b = 0; b < STRB_WIDTH; b++) begin
        int idx = i * STRB_WIDTH + b;
        if (idx < item.nbytes) begin
          beat_data[8*b +: 8] = item.wdata[idx];
          beat_strb[b]        = 1'b1;
        end
      end
      vif.wdata  <= beat_data;
      vif.wstrb  <= beat_strb;
      vif.wlast  <= (i == beats - 1);
      vif.wvalid <= 1'b1;
      @(posedge vif.clk);
      while (!vif.wready) @(posedge vif.clk);
    end
    vif.wvalid <= 1'b0;

    while (!vif.bvalid) @(posedge vif.clk);
    item.resp_error = (vif.bresp != 2'b00);
    @(posedge vif.clk);
  endtask

  // rafaga de lectura: AR -> R(*beats)
  task automatic leer(axi_txn item);
    int unsigned beats = (item.nbytes + STRB_WIDTH - 1) / STRB_WIDTH;
    item.rdata = new[item.nbytes];

    @(posedge vif.clk);
    vif.araddr  <= item.addr;
    vif.arlen   <= beats - 1;
    vif.arsize  <= $clog2(STRB_WIDTH);
    vif.arburst <= 2'b01; // INCR
    vif.arvalid <= 1'b1;
    @(posedge vif.clk);
    while (!vif.arready) @(posedge vif.clk);
    vif.arvalid <= 1'b0;

    for (int unsigned i = 0; i < beats; i++) begin
      @(posedge vif.clk);
      while (!vif.rvalid) @(posedge vif.clk);
      for (int b = 0; b < STRB_WIDTH; b++) begin
        int idx = i * STRB_WIDTH + b;
        if (idx < item.nbytes) item.rdata[idx] = vif.rdata[8*b +: 8];
      end
      if (vif.rresp != 2'b00) item.resp_error = 1'b1;
    end
  endtask
endclass
