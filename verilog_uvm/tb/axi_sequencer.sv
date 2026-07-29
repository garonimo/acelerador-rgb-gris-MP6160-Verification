// axi_sequencer.sv (incluido dentro de axi_pkg)
// Sequencer generico de items axi_txn.

class axi_sequencer extends uvm_sequencer #(axi_txn);
  `uvm_component_utils(axi_sequencer)

  function new(string name = "axi_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass
