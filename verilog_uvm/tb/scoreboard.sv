// scoreboard.sv (incluido dentro de axi_pkg)
// Compara lo leido por AXI4 de la RAM RTL contra los volcados dorados de la
// RAM SystemC (golden_ram_in_region.bin / golden_ram_out_region.bin,
// generados offline por verilog_uvm/golden/golden_dump.cpp). Ver plan §4.3.

class scoreboard extends uvm_component;
  `uvm_component_utils(scoreboard)

  int unsigned errores = 0;

  function new(string name = "scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // carga "ruta_dorada" (texto hexadecimal, un byte por linea) y la compara
  // byte a byte contra "actual". Se usa $readmemh en vez de dpi_load_file:
  // un archivo binario subido a EDA Playground puede corromper bytes no-ASCII.
  task automatic verificar_bloque(string ruta_dorada, byte unsigned actual[], string nombre);
    byte unsigned golden[];
    int           fd;

    golden = new[actual.size()];
    fd = $fopen(ruta_dorada, "r");
    if (fd == 0) begin
      errores++;
      `uvm_error(get_type_name(), $sformatf("no se pudo abrir %s", ruta_dorada))
      return;
    end
    $fclose(fd);
    $readmemh(ruta_dorada, golden);

    for (int i = 0; i < actual.size(); i++) begin
      if (actual[i] !== golden[i]) begin
        errores++;
        `uvm_error(get_type_name(),
          $sformatf("%s byte %0d: rtl=0x%02h golden=0x%02h",
                     nombre, i, actual[i], golden[i]))
      end
    end
  endtask

  // veredicto final: uvm_fatal si hubo al menos un mismatch
  function void resumen();
    if (errores == 0)
      `uvm_info(get_type_name(),
        "PASS: RAM RTL (AXI4) == RAM SystemC (golden dump)", UVM_LOW)
    else
      `uvm_fatal(get_type_name(),
        $sformatf("FAIL: %0d bytes distintos entre RAM RTL y golden", errores))
  endfunction
endclass
