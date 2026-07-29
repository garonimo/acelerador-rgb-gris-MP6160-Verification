// axi_ram.sv
// RAM esclava AXI4 Full que reemplaza a Basic_cpu-main/include/ram.h.
// Backing store disperso (associative array por byte): solo se reservan las
// posiciones realmente escritas, aunque representa una RAM de RAM_SIZE bytes
// direccionable completa (map::RAM_SIZE = 64 MiB en Basic_cpu-main/common.h).
// Estilo "memoria de verificacion" (procedural, no pensado para sintesis),
// igual que hacen las VIP de memoria AXI comerciales.
// Soporta rafagas INCR, WSTRB en escrituras y SLVERR fuera de rango.

module axi_ram #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,
  parameter longint unsigned RAM_SIZE = 64 * 1024 * 1024
) (
  axi_if.slave axi
);

  localparam int STRB_WIDTH = DATA_WIDTH / 8;

  // memoria dispersa indexada por direccion de byte
  bit [7:0] mem [bit [ADDR_WIDTH-1:0]];

  function automatic bit fuera_de_rango(bit [ADDR_WIDTH-1:0] addr, int nbytes);
    return (longint'(addr) + nbytes) > RAM_SIZE;
  endfunction

  // valores de reposo de las señales que maneja este esclavo
  initial begin
    axi.awready = 1'b0;
    axi.wready  = 1'b0;
    axi.bvalid  = 1'b0;
    axi.bresp   = 2'b00;
    axi.arready = 1'b0;
    axi.rvalid  = 1'b0;
    axi.rlast   = 1'b0;
    axi.rresp   = 2'b00;
    axi.rdata   = '0;
  end

  // ---------------- canal de escritura: AW -> W(*) -> B ----------------
  task automatic atender_escrituras();
    bit [ADDR_WIDTH-1:0] addr;
    int unsigned          beats;
    bit                    err;

    forever begin
      // fase de direccion (AW)
      axi.awready <= 1'b1;
      @(posedge axi.clk);
      while (!axi.awvalid) @(posedge axi.clk);
      addr        = axi.awaddr;
      beats       = axi.awlen + 1;
      err         = fuera_de_rango(axi.awaddr, beats * STRB_WIDTH);
      axi.awready <= 1'b0;

      // fase de datos (W), una transferencia por beat
      axi.wready <= 1'b1;
      for (int unsigned i = 0; i < beats; i++) begin
        @(posedge axi.clk);
        while (!axi.wvalid) @(posedge axi.clk);
        if (!err) begin
          for (int b = 0; b < STRB_WIDTH; b++)
            if (axi.wstrb[b]) mem[addr + b] = axi.wdata[8*b +: 8];
        end
        addr = addr + STRB_WIDTH;
      end
      axi.wready <= 1'b0;

      // fase de respuesta (B)
      axi.bresp  <= err ? 2'b10 /* SLVERR */ : 2'b00 /* OKAY */;
      axi.bvalid <= 1'b1;
      @(posedge axi.clk);
      while (!axi.bready) @(posedge axi.clk);
      axi.bvalid <= 1'b0;
    end
  endtask

  // ---------------- canal de lectura: AR -> R(*) ----------------
  task automatic atender_lecturas();
    bit [ADDR_WIDTH-1:0] addr;
    int unsigned          beats;
    bit                    err;

    forever begin
      // fase de direccion (AR)
      axi.arready <= 1'b1;
      @(posedge axi.clk);
      while (!axi.arvalid) @(posedge axi.clk);
      addr        = axi.araddr;
      beats       = axi.arlen + 1;
      err         = fuera_de_rango(axi.araddr, beats * STRB_WIDTH);
      axi.arready <= 1'b0;

      // fase de datos (R), una transferencia por beat
      for (int unsigned i = 0; i < beats; i++) begin
        for (int b = 0; b < STRB_WIDTH; b++)
          axi.rdata[8*b +: 8] <= err ? 8'h00 : mem[addr + b];
        axi.rresp  <= err ? 2'b10 : 2'b00;
        axi.rlast  <= (i == beats - 1);
        axi.rvalid <= 1'b1;
        @(posedge axi.clk);
        while (!axi.rready) @(posedge axi.clk);
        addr = addr + STRB_WIDTH;
      end
      axi.rvalid <= 1'b0;
      axi.rlast  <= 1'b0;
    end
  endtask

  initial begin
    fork
      atender_escrituras();
      atender_lecturas();
    join
  end

endmodule
