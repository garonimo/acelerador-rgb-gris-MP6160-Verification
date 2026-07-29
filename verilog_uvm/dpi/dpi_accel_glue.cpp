// dpi_accel_glue.cpp
// Implementacion de las funciones DPI-C. Se documenta en cada funcion de que
// archivo de Basic_cpu-main viene copiado el cuerpo (sin cambios de logica).

#include "dpi_accel_glue.h"

#include <cstdio>
#include <cstdint>

// ---- copia literal de Accelerator::rgb_a_gris (accelerator.h) ----
void dpi_rgb_to_gray(const svOpenArrayHandle rgb,
                      svOpenArrayHandle       gris,
                      int                     npix)
{
  const auto* prgb  = static_cast<const unsigned char*>(svGetArrayPtr(rgb));
  auto*       pgris = static_cast<unsigned char*>(svGetArrayPtr(gris));

  for (int i = 0; i < npix; ++i)
  {
    const std::uint32_t r = prgb[3*i+0];
    const std::uint32_t g = prgb[3*i+1];
    const std::uint32_t b = prgb[3*i+2];
    pgris[i] = static_cast<unsigned char>((77*r + 150*g + 29*b) >> 8);
  }
}

// ---- copia literal de la carga de archivo en el constructor de Storage (storage.h) ----
int dpi_load_file(const char* ruta, svOpenArrayHandle datos, int max_len)
{
  std::FILE* f = std::fopen(ruta, "rb");
  if (!f) return -1;

  auto* buf = static_cast<unsigned char*>(svGetArrayPtr(datos));
  const std::size_t leidos = std::fread(buf, 1, static_cast<std::size_t>(max_len), f);
  std::fclose(f);

  return static_cast<int>(leidos);
}

// ---- copia literal de la rama WRITE de Storage::b_transport (storage.h) ----
int dpi_save_output(const char* ruta, const svOpenArrayHandle datos, int len)
{
  std::FILE* f = std::fopen(ruta, "wb");
  if (!f) return -1;

  const auto* buf = static_cast<const unsigned char*>(svGetArrayPtr(datos));
  const std::size_t escritos = std::fwrite(buf, 1, static_cast<std::size_t>(len), f);
  std::fclose(f);

  return (escritos == static_cast<std::size_t>(len)) ? 0 : -1;
}
