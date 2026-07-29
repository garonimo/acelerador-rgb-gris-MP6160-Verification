// dpi_accel_glue.h
// Firmas DPI-C expuestas a SystemVerilog. La logica de cada funcion es una
// copia literal de Basic_cpu-main/include/accelerator.h (rgb_a_gris) y de
// Basic_cpu-main/include/storage.h (carga/guardado de archivo); no se
// modifica el comportamiento, solo se expone sin dependencias de SystemC/TLM.

#ifndef DPI_ACCEL_GLUE_H
#define DPI_ACCEL_GLUE_H

#include "svdpi.h"

extern "C" {

// convierte RGB a gris (BT.601 entero), copia literal de
// Accelerator::rgb_a_gris en Basic_cpu-main/include/accelerator.h
void dpi_rgb_to_gray(const svOpenArrayHandle rgb,
                      svOpenArrayHandle       gris,
                      int                     npix);

// carga un archivo binario completo a un arreglo SV, copia literal de la
// carga que hace el constructor de Storage en Basic_cpu-main/include/storage.h.
// devuelve la cantidad de bytes leidos, o -1 si no se pudo abrir el archivo.
int dpi_load_file(const char* ruta, svOpenArrayHandle datos, int max_len);

// guarda un arreglo SV completo a un archivo binario, copia literal de la
// rama WRITE de Storage::b_transport en Basic_cpu-main/include/storage.h.
// devuelve 0 si se pudo escribir, -1 si no.
int dpi_save_output(const char* ruta, const svOpenArrayHandle datos, int len);

} // extern "C"

#endif
