
#include <iostream>
#include <string>
#include <systemc>

#include "accelerator.h"
#include "bus.h"
#include "common.h"
#include "cpu.h"
#include "ram.h"
#include "storage.h"

int sc_main(int argc, char* argv[])
{
  // rutas de los archivos de entrada y salida
  // si el usuario no pasa argumentos se usan las rutas por defecto
  const std::string ruta_in  = (argc > 1) ? argv[1]
                             : "images/input/input_1080p.rgb";
  const std::string ruta_out = (argc > 2) ? argv[2]
                             : "images/output/output_1080p_gray.raw";

  std::cout << "entrada : " << ruta_in  << "\n"
            << "salida  : " << ruta_out << "\n";

  // crear los 5 modulos del sistema
  CPU         cpu("cpu");
  Bus         bus("bus");
  Ram         ram("ram");
  Accelerator acc("acelerador");
  Storage     stg("storage", ruta_in, ruta_out);

  // conectar los sockets
  // initiator siempre se conecta a target
  cpu.socket.bind(bus.cpu_target);
  acc.dma_socket.bind(bus.acc_target);

  bus.ram_init.bind(ram.socket);
  bus.acc_cfg_init.bind(acc.cfg_socket);
  bus.stg_init.bind(stg.socket);

  // arrancar la simulacion
  sc_core::sc_start();

  std::cout << "Simulacion finalizada\n";
  return 0;
}
