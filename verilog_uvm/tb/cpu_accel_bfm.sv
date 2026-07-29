// cpu_accel_bfm.sv
// Maestro AXI4 "CPU + acelerador": reproduce Accelerator::proceso() (lee RGB
// de RAM, convierte por DPI, escribe gris en RAM) y el cierre de
// CPU::flujo_principal() (relee la salida de RAM y la persiste a disco por
// DPI). No es un componente UVM: lo dispara el test via bfm_ctrl_if.

module cpu_accel_bfm #(
  parameter string RUTA_SALIDA = "output_crop_gray.raw"
) (
  axi_if.master  axi,
  bfm_ctrl_if    ctrl
);
  import axi_pkg::*;

  import "DPI-C" function void dpi_rgb_to_gray(input byte unsigned rgb[],
                                                output byte unsigned gris[],
                                                input int npix);
  import "DPI-C" function int dpi_save_output(input string ruta,
                                               input byte unsigned datos[],
                                               input int len);

  byte unsigned rgb_buf[];
  byte unsigned gris_buf[];
  byte unsigned gris_verif[];

  initial begin
    axi.awvalid = 1'b0;
    axi.wvalid  = 1'b0;
    axi.bready  = 1'b1;
    axi.arvalid = 1'b0;
    axi.rready  = 1'b1;
    ctrl.done   = 1'b0;

    @(posedge ctrl.start);

    rgb_buf    = new[BYTES_RGB];
    gris_buf   = new[BYTES_GRIS];
    gris_verif = new[BYTES_GRIS];

    leer_bloque(INPUT_BASE, rgb_buf);
    $display("DEBUG-BFM rgb_buf[0:11]  = %p", rgb_buf[0:11]);
    dpi_rgb_to_gray(rgb_buf, gris_buf, NPIX_TEST);
    $display("DEBUG-BFM gris_buf[0:7]  = %p", gris_buf[0:7]);
    escribir_bloque(OUTPUT_BASE, gris_buf);
    leer_bloque(OUTPUT_BASE, gris_verif);
    $display("DEBUG-BFM gris_verif[0:7]= %p", gris_verif[0:7]);
    void'(dpi_save_output(RUTA_SALIDA, gris_verif, BYTES_GRIS));

    ctrl.done = 1'b1;
  end

  // lee "datos.size()" bytes desde "base", fragmentando en rafagas de max 1024 B
  task automatic leer_bloque(bit [ADDR_WIDTH-1:0] base, ref byte unsigned datos[]);
    int unsigned total = datos.size();
    int unsigned hecho = 0;

    while (hecho < total) begin
      int unsigned n     = ((total - hecho) > 1024) ? 1024 : (total - hecho);
      int unsigned beats = (n + STRB_WIDTH - 1) / STRB_WIDTH;

      @(posedge axi.clk);
      axi.araddr  <= base + hecho;
      axi.arlen   <= beats - 1;
      axi.arsize  <= $clog2(STRB_WIDTH);
      axi.arburst <= 2'b01;
      axi.arvalid <= 1'b1;
      @(posedge axi.clk);
      while (!axi.arready) @(posedge axi.clk);
      axi.arvalid <= 1'b0;

      for (int unsigned i = 0; i < beats; i++) begin
        @(posedge axi.clk);
        while (!axi.rvalid) @(posedge axi.clk);
        for (int b = 0; b < STRB_WIDTH; b++) begin
          int idx = hecho + i * STRB_WIDTH + b;
          if (idx < hecho + n) datos[idx] = axi.rdata[8*b +: 8];
        end
      end
      hecho += n;
    end
  endtask

  // escribe "datos" completo a partir de "base", fragmentando en rafagas de max 1024 B
  task automatic escribir_bloque(bit [ADDR_WIDTH-1:0] base, ref byte unsigned datos[]);
    int unsigned total = datos.size();
    int unsigned hecho = 0;

    while (hecho < total) begin
      int unsigned n     = ((total - hecho) > 1024) ? 1024 : (total - hecho);
      int unsigned beats = (n + STRB_WIDTH - 1) / STRB_WIDTH;

      @(posedge axi.clk);
      axi.awaddr  <= base + hecho;
      axi.awlen   <= beats - 1;
      axi.awsize  <= $clog2(STRB_WIDTH);
      axi.awburst <= 2'b01;
      axi.awvalid <= 1'b1;
      @(posedge axi.clk);
      while (!axi.awready) @(posedge axi.clk);
      axi.awvalid <= 1'b0;

      for (int unsigned i = 0; i < beats; i++) begin
        logic [DATA_WIDTH-1:0] beat_data = '0;
        logic [STRB_WIDTH-1:0] beat_strb = '0;
        for (int b = 0; b < STRB_WIDTH; b++) begin
          int idx = hecho + i * STRB_WIDTH + b;
          if (idx < hecho + n) begin
            beat_data[8*b +: 8] = datos[idx];
            beat_strb[b]        = 1'b1;
          end
        end
        axi.wdata  <= beat_data;
        axi.wstrb  <= beat_strb;
        axi.wlast  <= (i == beats - 1);
        axi.wvalid <= 1'b1;
        @(posedge axi.clk);
        while (!axi.wready) @(posedge axi.clk);
      end
      axi.wvalid <= 1'b0;

      while (!axi.bvalid) @(posedge axi.clk);
      @(posedge axi.clk);
      hecho += n;
    end
  endtask
endmodule
