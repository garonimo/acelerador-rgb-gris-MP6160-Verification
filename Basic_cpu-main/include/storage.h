
#pragma once

#include <cstring>
#include <fstream>
#include <string>
#include <vector>
#include <systemc>
#include <tlm>
#include <tlm_utils/simple_target_socket.h>
#include "common.h"

struct Storage : sc_core::sc_module
{
  tlm_utils::simple_target_socket<Storage> socket;

  std::string ruta_entrada, ruta_salida;
  std::vector<unsigned char> buf_entrada;

  Storage(sc_core::sc_module_name nombre,
          const std::string& ruta_in,
          const std::string& ruta_out)
    : sc_module(nombre)
    , socket("socket")
    , ruta_entrada(ruta_in)
    , ruta_salida(ruta_out)
  {
    socket.register_b_transport(this, &Storage::b_transport);

    // cargar la imagen de entrada al inicio
    std::ifstream f(ruta_entrada, std::ios::binary | std::ios::ate);
    if (!f)
      SC_REPORT_FATAL("STORAGE",
        ("no se pudo abrir: " + ruta_entrada).c_str());
// pone a cero ademas que hace un rize del tamano de la imagen para el bs y lee y pone datos accesibles 
    const auto tam = f.tellg();
    f.seekg(0);
    buf_entrada.resize(static_cast<std::size_t>(tam));
    f.read(reinterpret_cast<char*>(buf_entrada.data()), tam);

    SC_REPORT_INFO("STORAGE",
      ("imagen cargada: " + ruta_entrada).c_str());
  }
//leemos y asignamos igual para usar 
  void b_transport(tlm::tlm_generic_payload& trans, sc_core::sc_time& delay)
  {
    const auto cmd  = trans.get_command();
    const auto addr = trans.get_address();
    auto*      ptr  = trans.get_data_ptr();
    const auto len  = trans.get_data_length();

    if (cmd == tlm::TLM_READ_COMMAND)
    {
      // si entra entonecs leemos la imagen para el cp
      const std::uint64_t offset = addr - stg_slot::OFFSET_IN;
      std::memcpy(ptr, buf_entrada.data() + offset, len);
    }
    else
    {
      // para guardar la imagen de salida 
      std::ofstream f(ruta_salida, std::ios::binary | std::ios::trunc);
      f.write(reinterpret_cast<const char*>(ptr), len);
      SC_REPORT_INFO("STORAGE",
        ("imagen guardada: " + ruta_salida).c_str());
    }

    trans.set_response_status(tlm::TLM_OK_RESPONSE);
  }
};
