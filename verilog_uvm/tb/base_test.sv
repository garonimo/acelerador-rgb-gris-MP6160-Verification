// base_test.sv (incluido dentro de tb_pkg)
// Test base: solo construye el entorno. Los tests concretos heredan de aqui.

class base_test extends uvm_test;
  `uvm_component_utils(base_test)

  rgb2gray_env env;

  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = rgb2gray_env::type_id::create("env", this);
  endfunction
endclass
