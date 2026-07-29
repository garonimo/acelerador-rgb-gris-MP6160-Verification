// axi_monitor.sv (incluido dentro de axi_pkg)
// Observador pasivo: arma un axi_txn por cada rafaga completa (AW+W o AR+R)
// y lo publica por el analysis port. Solo para logging/depuracion; la
// comparacion final la hace el scoreboard con sus propias lecturas.

class axi_monitor extends uvm_monitor;
  `uvm_component_utils(axi_monitor)

  virtual axi_if.monitor vif;
  uvm_analysis_port #(axi_txn) ap;

  function new(string name = "axi_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if.monitor)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "no se encontro axi_if.monitor en config_db")
  endfunction

  task run_phase(uvm_phase phase);
    fork
      observar_escrituras();
      observar_lecturas();
    join
  endtask

  task automatic observar_escrituras();
    forever begin
      axi_txn tr;
      @(posedge vif.clk);
      if (vif.awvalid && vif.awready) begin
        tr         = axi_txn::type_id::create("tr_wr");
        tr.is_write = 1'b1;
        tr.addr     = vif.awaddr;
        tr.nbytes   = (vif.awlen + 1) * STRB_WIDTH;
        // se descarta el contenido byte a byte aqui; solo se reporta la rafaga
        ap.write(tr);
        `uvm_info(get_type_name(),
          $sformatf("WRITE addr=0x%08h nbytes=%0d", tr.addr, tr.nbytes),
          UVM_HIGH)
      end
    end
  endtask

  task automatic observar_lecturas();
    forever begin
      axi_txn tr;
      @(posedge vif.clk);
      if (vif.arvalid && vif.arready) begin
        tr         = axi_txn::type_id::create("tr_rd");
        tr.is_write = 1'b0;
        tr.addr     = vif.araddr;
        tr.nbytes   = (vif.arlen + 1) * STRB_WIDTH;
        ap.write(tr);
        `uvm_info(get_type_name(),
          $sformatf("READ  addr=0x%08h nbytes=%0d", tr.addr, tr.nbytes),
          UVM_HIGH)
      end
    end
  endtask
endclass
