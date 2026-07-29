// seq_lib.sv (incluido dentro de axi_pkg)
// Secuencias reusables: escribir un buffer completo (fragmentado en rafagas
// de hasta 1024 B) y leerlo de vuelta para verificacion.

// escribe "data" (bytes ya cargados por quien la use) a partir de "base_addr"
class write_image_seq extends uvm_sequence #(axi_txn);
  `uvm_object_utils(write_image_seq)

  bit [ADDR_WIDTH-1:0] base_addr;
  byte unsigned         data[];

  function new(string name = "write_image_seq");
    super.new(name);
  endfunction

  task body();
    int unsigned hecho = 0;
    while (hecho < data.size()) begin
      int unsigned n = ((data.size() - hecho) > 1024) ? 1024 : (data.size() - hecho);
      req = axi_txn::type_id::create("req");
      start_item(req);
      req.is_write = 1'b1;
      req.addr     = base_addr + hecho;
      req.nbytes   = n;
      req.wdata    = new[n];
      for (int i = 0; i < n; i++) req.wdata[i] = data[hecho + i];
      finish_item(req);
      hecho += n;
    end
  endtask
endclass

// lee "nbytes" desde "base_addr" y concatena el resultado en "result"
class read_check_seq extends uvm_sequence #(axi_txn);
  `uvm_object_utils(read_check_seq)

  bit [ADDR_WIDTH-1:0] base_addr;
  int unsigned          nbytes;
  byte unsigned          result[];

  function new(string name = "read_check_seq");
    super.new(name);
  endfunction

  task body();
    int unsigned hecho = 0;
    result = new[nbytes];
    while (hecho < nbytes) begin
      int unsigned n = ((nbytes - hecho) > 1024) ? 1024 : (nbytes - hecho);
      req = axi_txn::type_id::create("req");
      start_item(req);
      req.is_write = 1'b0;
      req.addr     = base_addr + hecho;
      req.nbytes   = n;
      finish_item(req);
      // finish_item bloquea hasta item_done(); el driver llena req.rdata
      // sobre el mismo handle (no hace falta get_response separado).
      for (int i = 0; i < n; i++) result[hecho + i] = req.rdata[i];
      hecho += n;
    end
  endtask
endclass
