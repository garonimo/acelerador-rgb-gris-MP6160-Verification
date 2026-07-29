// tb_pkg.sv
// Paquete con el entorno UVM y los tests (env, base_test, rgb2gray_uvm_test).
// Se separa de axi_pkg para que axi_pkg quede como una VIP AXI4 reusable
// e independiente de este testbench en particular.

package tb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi_pkg::*;

  `include "env.sv"
  `include "base_test.sv"
  `include "rgb2gray_uvm_test.sv"

endpackage
