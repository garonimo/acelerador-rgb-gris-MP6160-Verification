// env.sv (incluido dentro de tb_pkg)
// Entorno UVM: un agente AXI4 (activo, maneja las fases de carga y
// verificacion) mas el scoreboard que compara contra el modelo dorado.

class rgb2gray_env extends uvm_env;
  `uvm_component_utils(rgb2gray_env)

  axi_agent  agent;
  scoreboard sb;

  function new(string name = "rgb2gray_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = axi_agent::type_id::create("agent", this);
    sb    = scoreboard::type_id::create("sb", this);
  endfunction
endclass
