// rgb2gray_uvm_test.sv (incluido dentro de tb_pkg)
// Orquesta el flujo completo pedido por el enunciado:
//   1) UVM agent escribe la imagen de entrada en la RAM (AXI4)
//   2) cpu_accel_bfm toma el bus, convierte por DPI y escribe la salida
//   3) cpu_accel_bfm relee la salida y la persiste a disco por DPI
//   4) UVM agent relee ambas regiones y el scoreboard compara contra el
//      modelo dorado (RAM SystemC de Basic_cpu-main, ver golden_dump.cpp)

class rgb2gray_uvm_test extends base_test;
  `uvm_component_utils(rgb2gray_uvm_test)

  virtual bfm_ctrl_if ctrl_vif;

  // archivos de texto hexadecimal (un byte por linea), no binarios: subir un
  // archivo binario a EDA Playground puede corromper bytes no-ASCII (se
  // observo el reemplazo UTF-8 U+FFFD en bytes con el bit alto en 1), asi
  // que se usa $readmemh en vez de dpi_load_file para estos 3 vectores.
  string ruta_entrada     = "input_crop.hex";
  string ruta_golden_in   = "golden_ram_in_region.hex";
  string ruta_golden_out  = "golden_ram_out_region.hex";

  function new(string name = "rgb2gray_uvm_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual bfm_ctrl_if)::get(this, "", "ctrl_vif", ctrl_vif))
      `uvm_fatal("NOVIF", "no se encontro bfm_ctrl_if en config_db")
  endfunction

  task run_phase(uvm_phase phase);
    byte unsigned entrada[];
    int           fd;
    write_image_seq wseq;
    read_check_seq  rseq_in;
    read_check_seq  rseq_out;

    phase.raise_objection(this);

    // 1) cargar el recorte de prueba desde el archivo hexadecimal (texto)
    entrada = new[BYTES_RGB];
    fd = $fopen(ruta_entrada, "r");
    if (fd == 0)
      `uvm_fatal(get_type_name(), $sformatf("no se pudo abrir %s", ruta_entrada))
    $fclose(fd);
    $readmemh(ruta_entrada, entrada);

    // 2) fase de carga: el agente UVM escribe la entrada en INPUT_BASE
    wseq = write_image_seq::type_id::create("wseq");
    wseq.base_addr = INPUT_BASE;
    wseq.data      = entrada;
    wseq.start(env.agent.sequencer);
    `uvm_info(get_type_name(), "imagen de entrada escrita en RAM (AXI4)", UVM_LOW)

    // 3) fase de computo/persistencia: se cede el bus al cpu_accel_bfm
    ctrl_vif.start = 1'b1;
    @(posedge ctrl_vif.done);
    ctrl_vif.start = 1'b0;
    `uvm_info(get_type_name(), "cpu_accel_bfm termino (conversion + guardado)", UVM_LOW)

    // 4) fase de verificacion: se relee todo por AXI4
    rseq_in = read_check_seq::type_id::create("rseq_in");
    rseq_in.base_addr = INPUT_BASE;
    rseq_in.nbytes    = BYTES_RGB;
    rseq_in.start(env.agent.sequencer);

    rseq_out = read_check_seq::type_id::create("rseq_out");
    rseq_out.base_addr = OUTPUT_BASE;
    rseq_out.nbytes    = BYTES_GRIS;
    rseq_out.start(env.agent.sequencer);

    // 5) comparar contra los volcados dorados de la RAM SystemC
    env.sb.verificar_bloque(ruta_golden_in,  rseq_in.result,  "INPUT_BASE");
    env.sb.verificar_bloque(ruta_golden_out, rseq_out.result, "OUTPUT_BASE");
    env.sb.resumen();

    phase.drop_objection(this);
  endtask
endclass
