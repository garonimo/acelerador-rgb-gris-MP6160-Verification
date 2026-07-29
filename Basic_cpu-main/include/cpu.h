
#pragma once

#include <cstring>
#include <iostream>
#include <vector>
#include <systemc>
#include <tlm>
#include <tlm_utils/simple_initiator_socket.h>
#include "common.h"

struct CPU : sc_core::sc_module
{
  tlm_utils::simple_initiator_socket<CPU> socket;

  SC_CTOR(CPU) : socket("socket")
  {
    SC_THREAD(flujo_principal);
  }

  // arma y manda una transaccion TLM
  // igual que send_transaction del ejemplo del profesor
  void enviar_transaccion(tlm::tlm_command cmd, std::uint64_t addr,
                          unsigned char* buf, std::uint32_t len)
  {
    tlm::tlm_generic_payload trans;
    sc_core::sc_time delay = sc_core::SC_ZERO_TIME;

    trans.set_command(cmd);
    trans.set_address(addr);
    trans.set_data_ptr(buf);
    trans.set_data_length(len);
    trans.set_streaming_width(len);
    trans.set_byte_enable_ptr(nullptr);
    trans.set_dmi_allowed(false);
    trans.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);

    socket->b_transport(trans, delay);
    wait(delay);

    if (trans.is_response_error())
      SC_REPORT_ERROR("TLM-2", trans.get_response_string().c_str());
  }

  // escribe 4 bytes en un registro del acelerador
  void escribir_registro(std::uint64_t addr, std::uint32_t valor)
  {
    enviar_transaccion(tlm::TLM_WRITE_COMMAND, addr,
                       reinterpret_cast<unsigned char*>(&valor),
                       sizeof(valor));
  }

  // lee 4 bytes desde un registro del acelerador
  std::uint32_t leer_registro(std::uint64_t addr)
  {
    std::uint32_t valor = 0;
    enviar_transaccion(tlm::TLM_READ_COMMAND, addr,
                       reinterpret_cast<unsigned char*>(&valor),
                       sizeof(valor));
    return valor;
  }

  // esta es la funcion del trbajo y maneja rodo
  void flujo_principal()
  {
    std::cout << "Iniciando proceso de conversion...\n";

    std::vector<unsigned char> buf_rgb(img::BYTES_RGB);
    std::vector<unsigned char> buf_gris(img::BYTES_GRIS);

    // 1) cargar imagen desde disco al buffer local
    enviar_transaccion(tlm::TLM_READ_COMMAND,
                       map::DISK_BASE + stg_slot::OFFSET_IN,
                       buf_rgb.data(), img::BYTES_RGB);
    std::cout << "Imagen cargada desde disco\n";

    // 2) copiar imagen del buffer local a la RAM
    enviar_transaccion(tlm::TLM_WRITE_COMMAND,
                       map::DIR_IMG_IN,
                       buf_rgb.data(), img::BYTES_RGB);
    std::cout << "Imagen RGB copiada a RAM\n";

    // 3) decirle al acelerador donde esta la imagen y cuantos pixeles tiene
    escribir_registro(map::ACC_BASE + acc_reg::DIR_IN,     map::DIR_IMG_IN);
    escribir_registro(map::ACC_BASE + acc_reg::DIR_OUT,    map::DIR_IMG_OUT);
    escribir_registro(map::ACC_BASE + acc_reg::NUM_PIXELS, img::PIXEL_TOTAL);
    std::cout << "Acelerador programado\n";

    // 4) arrancar el acelerador
    escribir_registro(map::ACC_BASE + acc_reg::CTRL, acc_reg::START_BIT);
    std::cout << "Acelerador iniciado, esperando...\n";

    // 5) esperar hasta que el acelerador termine
    // el wait cede el control para que el acelerador pueda correr
    std::uint32_t estado = 0;
    do {
      wait(sc_core::SC_ZERO_TIME);
      estado = leer_registro(map::ACC_BASE + acc_reg::STATUS);
    } while (!(estado & acc_reg::DONE_BIT));
    std::cout << "Acelerador termino\n";

    // 6) leer imagen en grises desde RAM al buffer local
    enviar_transaccion(tlm::TLM_READ_COMMAND,
                       map::DIR_IMG_OUT,
                       buf_gris.data(), img::BYTES_GRIS);
    std::cout << "Imagen en grises leida desde RAM\n";

    // 7) guardar imagen en grises al disco
    enviar_transaccion(tlm::TLM_WRITE_COMMAND,
                       map::DISK_BASE + stg_slot::OFFSET_OUT,
                       buf_gris.data(), img::BYTES_GRIS);
    std::cout << "Imagen en grises guardada en disco\n";

    std::cout << "Conversion finalizada!\n";
    sc_core::sc_stop();
  }
};
