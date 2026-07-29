// golden_dump.cpp
// Modelo dorado (offline, no se ejecuta en EDA Playground): instancia los 5
// modulos de Basic_cpu-main SIN modificarlos, corre la simulacion completa
// (1080p, igual que Basic_cpu-main/main.cpp) y, al terminar, vuelca a disco
// los primeros NPIX_CROP pixeles de la RAM (map::DIR_IMG_IN y map::DIR_IMG_OUT)
// para compararlos 1:1 contra lo que el testbench UVM mueve por AXI4 con el
// mismo recorte (ver hls/tb/vectors/input_crop.rgb, tambien NPIX_CROP pixeles).
//
// Se corre una sola vez, en la maquina donde SystemC esta instalado, y los
// dos binarios resultantes se suben a EDA Playground junto al resto del
// testbench (ver verilog_uvm/scripts/run_edaplayground.md).

#include <cstdio>
#include <iostream>
#include <string>
#include <systemc>

#include "../../Basic_cpu-main/include/accelerator.h"
#include "../../Basic_cpu-main/include/bus.h"
#include "../../Basic_cpu-main/include/common.h"
#include "../../Basic_cpu-main/include/cpu.h"
#include "../../Basic_cpu-main/include/ram.h"
#include "../../Basic_cpu-main/include/storage.h"

namespace {
// mismo recorte que usa el testbench UVM (8192 pixeles)
constexpr std::uint32_t NPIX_CROP    = 8192;
constexpr std::uint32_t BYTES_RGB_CROP  = NPIX_CROP * img::RGB_BITS_IN;
constexpr std::uint32_t BYTES_GRIS_CROP = NPIX_CROP * img::RGB_BITS_OUT;

// vuelca "n" bytes de "ram.data" a partir de "offset" en un archivo binario
bool volcar(const std::vector<unsigned char>& datos, std::uint64_t offset,
            std::uint32_t n, const std::string& ruta)
{
  std::FILE* f = std::fopen(ruta.c_str(), "wb");
  if (!f) return false;
  const std::size_t escritos = std::fwrite(&datos[offset], 1, n, f);
  std::fclose(f);
  return escritos == n;
}
} // namespace

int sc_main(int argc, char* argv[])
{
  const std::string ruta_in  = (argc > 1) ? argv[1] : "../../images/input/input_1080p.rgb";
  const std::string ruta_out = (argc > 2) ? argv[2] : "golden_full_output_1080p_gray.raw";

  std::cout << "[golden_dump] entrada : " << ruta_in  << "\n"
            << "[golden_dump] salida  : " << ruta_out << "\n";

  // los mismos 5 modulos y el mismo cableado que Basic_cpu-main/main.cpp
  CPU         cpu("cpu");
  Bus         bus("bus");
  Ram         ram("ram");
  Accelerator acc("acelerador");
  Storage     stg("storage", ruta_in, ruta_out);

  cpu.socket.bind(bus.cpu_target);
  acc.dma_socket.bind(bus.acc_target);
  bus.ram_init.bind(ram.socket);
  bus.acc_cfg_init.bind(acc.cfg_socket);
  bus.stg_init.bind(stg.socket);

  sc_core::sc_start();

  // volcado dorado: solo el recorte de NPIX_CROP pixeles, para comparar 1:1
  // contra lo que el testbench UVM escribe/lee por AXI4
  const bool ok_in  = volcar(ram.data, map::DIR_IMG_IN,  BYTES_RGB_CROP,
                              "golden_ram_in_region.bin");
  const bool ok_out = volcar(ram.data, map::DIR_IMG_OUT, BYTES_GRIS_CROP,
                              "golden_ram_out_region.bin");

  if (!ok_in || !ok_out)
  {
    std::cerr << "[golden_dump] ERROR: no se pudieron escribir los volcados\n";
    return 1;
  }

  std::cout << "[golden_dump] golden_ram_in_region.bin  (" << BYTES_RGB_CROP  << " B)\n"
            << "[golden_dump] golden_ram_out_region.bin (" << BYTES_GRIS_CROP << " B)\n";
  return 0;
}
