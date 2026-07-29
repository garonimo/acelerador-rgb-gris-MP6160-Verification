
#pragma once

#include <systemc>
#include <tlm>
#include <tlm_utils/simple_initiator_socket.h>
#include <tlm_utils/simple_target_socket.h>
#include "common.h"

struct Bus : sc_core::sc_module
{
  // entradas: los modulos que hablan con el bus
  tlm_utils::simple_target_socket<Bus> cpu_target;
  tlm_utils::simple_target_socket<Bus> acc_target;

  // salidas: uno por periferico
  tlm_utils::simple_initiator_socket<Bus> ram_init;
  tlm_utils::simple_initiator_socket<Bus> acc_cfg_init;
  tlm_utils::simple_initiator_socket<Bus> stg_init;

  SC_CTOR(Bus)
    : cpu_target("cpu_target")
    , acc_target("acc_target")
    , ram_init("ram_init")
    , acc_cfg_init("acc_cfg_init")
    , stg_init("stg_init")
  {
    // ambas entradas usan el mismo metodo de ruteo
    cpu_target.register_b_transport(this, &Bus::b_transport);
    acc_target.register_b_transport(this, &Bus::b_transport);
  }

  // mira la direccion y usa los rangos de memoria, ACC y de disco para saber a quien debe enviar los datos y lo hace facil
//el puerto lo asigna en base a eso y la direccion la recorta en basado en la base u lo que llegue. el return es para el decode de delante
  bool decode(std::uint64_t gaddr,
              tlm_utils::simple_initiator_socket<Bus>** port,
              std::uint64_t& laddr)
  {
    if (gaddr >= map::RAM_BASE && gaddr <= map::RAM_END)
    {
      *port = &ram_init;
      laddr = gaddr - map::RAM_BASE;
      return true;
    }
    if (gaddr >= map::ACC_BASE && gaddr <= map::ACC_MAX)
    {
      *port = &acc_cfg_init;
      laddr = gaddr - map::ACC_BASE;
      return true;
    }
    if (gaddr >= map::DISK_BASE && gaddr <= map::DISK_MAX)
    {
      *port = &stg_init;
      laddr = gaddr - map::DISK_BASE;
      return true;
    }
    return false;
  }

  void b_transport(tlm::tlm_generic_payload& trans, sc_core::sc_time& delay)
  {
    const std::uint64_t gaddr = trans.get_address();
    tlm_utils::simple_initiator_socket<Bus>* port = nullptr;
    std::uint64_t laddr = 0;

    // si la direccion no existe respondemos con error. este decode tambien asigna variables basado en lo de arriba 
    if (!decode(gaddr, &port, laddr))
    {
      trans.set_response_status(tlm::TLM_ADDRESS_ERROR_RESPONSE);
      return;
    }

    // cambiamos a direccion local, enviamos con lo que se hace en el decode y restauramos
    trans.set_address(laddr);
    (*port)->b_transport(trans, delay);
    trans.set_address(gaddr);
  }
};
