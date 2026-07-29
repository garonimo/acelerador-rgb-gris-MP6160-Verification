
#pragma once

#include <cstdint>

// Dimensiones de la imagen en pixeles 
// se hace la asignacion de que son 3 bits rgb y 1 para salida 
//se hace uso del numero de bits entonces se pone aqui de una vez
namespace img
{
constexpr std::uint32_t ANCHO        = 1920;
constexpr std::uint32_t ALTO         = 1080;
constexpr std::uint32_t RGB_BITS_IN  = 3;
constexpr std::uint32_t RGB_BITS_OUT = 1;

constexpr std::uint32_t PIXEL_TOTAL = ANCHO * ALTO;
constexpr std::uint32_t BYTES_RGB   = PIXEL_TOTAL * RGB_BITS_IN;
constexpr std::uint32_t BYTES_GRIS  = PIXEL_TOTAL * RGB_BITS_OUT;
}

// Donde vive cada cosa en memoria
// se sigue usando el ull para evitar el overflow como los ejemplos del profe
// se tiene inicio y final de ram
// se tiene el inicio de la direccion de donde se coloca la imagen de entrada la rgb y la de salida
// hay una separacion para mantener rangos 
// estan los accesos al acelerador y del disco y igual max y min
namespace map
{
constexpr std::uint64_t RAM_BASE = 0x00000000ull;
constexpr std::uint64_t RAM_SIZE = 64ull * 1024 * 1024;
constexpr std::uint64_t RAM_END  = RAM_BASE + RAM_SIZE - 1;

constexpr std::uint64_t DIR_IMG_IN  = 0x00000000ull;
constexpr std::uint64_t DIR_IMG_OUT = 0x00800000ull;

constexpr std::uint64_t ACC_BASE = 0x10000000ull;
constexpr std::uint64_t ACC_SIZE = 0x100ull;
constexpr std::uint64_t ACC_MAX  = ACC_BASE + ACC_SIZE - 1;

constexpr std::uint64_t DISK_BASE = 0x20000000ull;
constexpr std::uint64_t DISK_SIZE = 0x10000000ull;
constexpr std::uint64_t DISK_MAX  = DISK_BASE + DISK_SIZE - 1;
}

// Registros del acelerador
namespace acc_reg
{
constexpr std::uint64_t DIR_IN     = 0x00;
constexpr std::uint64_t DIR_OUT    = 0x04;
constexpr std::uint64_t NUM_PIXELS = 0x08;
constexpr std::uint64_t CTRL       = 0x0C;
constexpr std::uint64_t STATUS     = 0x10;

constexpr std::uint32_t START_BIT  = 0x1;
constexpr std::uint32_t DONE_BIT   = 0x2;
}

// Offsets del disco
namespace stg_slot
{
constexpr std::uint64_t OFFSET_IN  = 0x00000000ull;
constexpr std::uint64_t OFFSET_OUT = 0x08000000ull;
}
