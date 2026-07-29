
#pragma once

#include <cstring>
#include <vector>
#include <systemc>
#include <tlm>
#include <tlm_utils/simple_initiator_socket.h>
#include <tlm_utils/simple_target_socket.h>
#include "common.h"

struct Accelerator : sc_core::sc_module
{
  // cfg_socket: el CPU lo programa y consulta su estado
  // dma_socket: el acelerador accede a la RAM por su cuenta
  tlm_utils::simple_target_socket<Accelerator>    cfg_socket;
  tlm_utils::simple_initiator_socket<Accelerator> dma_socket;

  // registros internos que el CPU programa
  std::uint32_t dir_entrada = 0;
  std::uint32_t dir_salida  = 0;
  std::uint32_t num_pixeles = 0;
  bool ocupado = false;
  bool listo   = false;

  // señal para despertar el proceso cuando manadmos start
  sc_core::sc_event senal_inicio;

  SC_CTOR(Accelerator) : cfg_socket("cfg_socket"), dma_socket("dma_socket")
  {
    cfg_socket.register_b_transport(this, &Accelerator::cfg_b_transport);
    SC_THREAD(proceso);
  }

  // convierte RGB a escala de grises usando BT.601
  // multiplico los pesos por 256 para evitar decimales
  // y al final divido con >>8 que es igual a dividir por 256
// lo consegui en internt entonces creo que esta mas o menos bien
  static void rgb_a_gris(const unsigned char* rgb,
                          unsigned char* gris,
                          std::uint32_t npix)
  {
    for (std::uint32_t i = 0; i < npix; ++i)
    {
      const std::uint32_t r = rgb[3*i+0];
      const std::uint32_t g = rgb[3*i+1];
      const std::uint32_t b = rgb[3*i+2];
      gris[i] = static_cast<unsigned char>((77*r + 150*g + 29*b) >> 8);
    }
  }

  // manda una transaccion TLM hacia la RAM
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

    dma_socket->b_transport(trans, delay);
    wait(delay);

    if (trans.is_response_error())
      SC_REPORT_ERROR("ACC", trans.get_response_string().c_str());
  }

  // atiende cuando el CPU escribe o lee registros
  void cfg_b_transport(tlm::tlm_generic_payload& trans, sc_core::sc_time& delay)
  {
    const auto cmd  = trans.get_command();
    const auto addr = trans.get_address();
    auto*      ptr  = trans.get_data_ptr();

    if (cmd == tlm::TLM_WRITE_COMMAND)
    {
      std::uint32_t val;
      std::memcpy(&val, ptr, 4);

      // guardar el valor en el registro correspondiente
      if (addr == acc_reg::DIR_IN)     dir_entrada = val;
      if (addr == acc_reg::DIR_OUT)    dir_salida  = val;
      if (addr == acc_reg::NUM_PIXELS) num_pixeles = val;

      // si el CPU manda START arrancamos el proceso
      if (addr == acc_reg::CTRL && (val & acc_reg::START_BIT))
      {
        ocupado = true;
        listo   = false;
        senal_inicio.notify(sc_core::SC_ZERO_TIME);
      }
    }
    else
    {
      // el CPU pregunta si ya terminamos
      std::uint32_t val = (listo ? acc_reg::DONE_BIT : 0);
      std::memcpy(ptr, &val, 4);
    }

    trans.set_response_status(tlm::TLM_OK_RESPONSE);
  }

  // proceso paralelo que hace la conversion
  // duerme hasta recibir START, procesa y vuelve a dormir
  void proceso()
  {
    std::vector<unsigned char> buf_rgb(img::BYTES_RGB);
    std::vector<unsigned char> buf_gris(img::BYTES_GRIS);

    while (true)
    {
      // esperar la senal de inicio del CPU
      wait(senal_inicio);

      // leer imagen RGB desde RAM
      enviar_transaccion(tlm::TLM_READ_COMMAND,
                         dir_entrada, buf_rgb.data(), img::BYTES_RGB);

      // convertir a escala de grises
      rgb_a_gris(buf_rgb.data(), buf_gris.data(), num_pixeles);

      // escribir resultado a RAM
      enviar_transaccion(tlm::TLM_WRITE_COMMAND,
                         dir_salida, buf_gris.data(), img::BYTES_GRIS);

      ocupado = false;
      listo   = true;
    }
  }
};
