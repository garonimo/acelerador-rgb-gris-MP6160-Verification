// axi_pkg.sv
// Paquete UVM con parametros AXI4 y el item de secuencia (axi_txn) usado
// por todo el entorno (agent, sequences, scoreboard).

package axi_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // parametros del bus, deben calzar con axi_if.sv
  parameter int ADDR_WIDTH = 32;
  parameter int DATA_WIDTH = 32;
  parameter int STRB_WIDTH = DATA_WIDTH / 8;

  // mapa de memoria: igual a Basic_cpu-main/include/common.h (map::*)
  parameter bit [ADDR_WIDTH-1:0] INPUT_BASE  = 32'h0000_0000; // map::DIR_IMG_IN
  parameter bit [ADDR_WIDTH-1:0] OUTPUT_BASE = 32'h0080_0000; // map::DIR_IMG_OUT

  // tamaño del recorte de prueba (8192 pixeles, ver hls/tb/vectors/input_crop.rgb)
  parameter int NPIX_TEST    = 8192;
  parameter int BYTES_RGB    = NPIX_TEST * 3;
  parameter int BYTES_GRIS   = NPIX_TEST * 1;

  // carga generica de archivo (copia literal de la carga de Storage,
  // ver verilog_uvm/dpi/dpi_accel_glue.cpp); usada por el test y el scoreboard
  import "DPI-C" function int dpi_load_file(input string ruta,
                                             output byte unsigned datos[],
                                             input int max_len);

  // item de secuencia: una rafaga AXI4 (escritura o lectura)
  class axi_txn extends uvm_sequence_item;
    `uvm_object_utils(axi_txn)

    rand bit                    is_write;
    rand bit [ADDR_WIDTH-1:0]   addr;
    rand int unsigned           nbytes;   // bytes a escribir o a leer (<= 1024 = 256 beats)
    byte unsigned                wdata[]; // datos a escribir (is_write == 1)
    byte unsigned                rdata[]; // datos leidos, llenados por el driver (is_write == 0)
    bit                          resp_error;

    constraint c_nbytes { nbytes inside {[1:1024]}; }

    function new(string name = "axi_txn");
      super.new(name);
    endfunction

    function string convert2string();
      return $sformatf("%s addr=0x%08h nbytes=%0d err=%0b",
                        is_write ? "WR" : "RD", addr, nbytes, resp_error);
    endfunction
  endclass

  `include "axi_sequencer.sv"
  `include "axi_driver.sv"
  `include "axi_monitor.sv"
  `include "axi_agent.sv"
  `include "seq_lib.sv"
  `include "scoreboard.sv"

endpackage
