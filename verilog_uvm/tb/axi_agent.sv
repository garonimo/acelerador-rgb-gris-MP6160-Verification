// axi_agent.sv (incluido dentro de axi_pkg)
// Agrupa sequencer + driver + monitor. Activo por defecto (maneja el bus
// en las fases de carga y de verificacion; ver §5 del plan).

class axi_agent extends uvm_agent;
  `uvm_component_utils(axi_agent)

  axi_sequencer sequencer;
  axi_driver    driver;
  axi_monitor   monitor;

  function new(string name = "axi_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = axi_monitor::type_id::create("monitor", this);
    if (get_is_active() == UVM_ACTIVE) begin
      sequencer = axi_sequencer::type_id::create("sequencer", this);
      driver    = axi_driver::type_id::create("driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
