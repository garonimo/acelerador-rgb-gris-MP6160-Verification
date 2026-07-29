// axi_if.sv
// Interfaz AXI4 Full (subconjunto necesario: AW/W/B y AR/R, sin AxLOCK/AxCACHE/
// AxPROT/AxQOS porque no se usan en este testbench). Ancho parametrizable.

interface axi_if #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input logic clk,
  input logic rst_n
);

  localparam int STRB_WIDTH = DATA_WIDTH / 8;

  // canal de direccion de escritura (AW)
  logic [ADDR_WIDTH-1:0] awaddr;
  logic [7:0]             awlen;
  logic [2:0]             awsize;
  logic [1:0]             awburst;
  logic                    awvalid;
  logic                    awready;

  // canal de datos de escritura (W)
  logic [DATA_WIDTH-1:0] wdata;
  logic [STRB_WIDTH-1:0] wstrb;
  logic                    wlast;
  logic                    wvalid;
  logic                    wready;

  // canal de respuesta de escritura (B)
  logic [1:0] bresp;
  logic        bvalid;
  logic        bready;

  // canal de direccion de lectura (AR)
  logic [ADDR_WIDTH-1:0] araddr;
  logic [7:0]             arlen;
  logic [2:0]             arsize;
  logic [1:0]             arburst;
  logic                    arvalid;
  logic                    arready;

  // canal de datos de lectura (R)
  logic [DATA_WIDTH-1:0] rdata;
  logic [1:0]              rresp;
  logic                     rlast;
  logic                     rvalid;
  logic                     rready;

  modport master (
    input  clk, rst_n,
    output awaddr, awlen, awsize, awburst, awvalid,
    input  awready,
    output wdata, wstrb, wlast, wvalid,
    input  wready,
    input  bresp, bvalid,
    output bready,
    output araddr, arlen, arsize, arburst, arvalid,
    input  arready,
    input  rdata, rresp, rlast, rvalid,
    output rready
  );

  modport slave (
    input  clk, rst_n,
    input  awaddr, awlen, awsize, awburst, awvalid,
    output awready,
    input  wdata, wstrb, wlast, wvalid,
    output wready,
    output bresp, bvalid,
    input  bready,
    input  araddr, arlen, arsize, arburst, arvalid,
    output arready,
    output rdata, rresp, rlast, rvalid,
    input  rready
  );

  // el monitor solo observa, nunca conduce señales
  modport monitor (
    input clk, rst_n,
    input awaddr, awlen, awsize, awburst, awvalid, awready,
    input wdata, wstrb, wlast, wvalid, wready,
    input bresp, bvalid, bready,
    input araddr, arlen, arsize, arburst, arvalid, arready,
    input rdata, rresp, rlast, rvalid, rready
  );

endinterface
