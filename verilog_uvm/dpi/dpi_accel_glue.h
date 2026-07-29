// dpi_accel_glue.h
// Firmas DPI-C expuestas a SystemVerilog. La logica de cada funcion es una
// copia literal de Basic_cpu-main/include/accelerator.h (rgb_a_gris) y de
// Basic_cpu-main/include/storage.h (guardado de archivo); no se modifica el
// comportamiento, solo se expone sin dependencias de SystemC/TLM.
//
// Nota: la carga de vectores de entrada (input_crop.hex, golden_*.hex) ya
// NO usa DPI: se hace con $readmemh sobre archivos de texto hexadecimal,
// porque subir un archivo binario a EDA Playground corrompe bytes no-ASCII
// (se observo el reemplazo UTF-8 U+FFFD). $readmemh evita ese problema.

#ifndef DPI_ACCEL_GLUE_H
#define DPI_ACCEL_GLUE_H

#include "svdpi.h"

extern "C" {

// convierte RGB a gris (BT.601 entero), copia literal de
// Accelerator::rgb_a_gris en Basic_cpu-main/include/accelerator.h
void dpi_rgb_to_gray(const svOpenArrayHandle rgb,
                      svOpenArrayHandle       gris,
                      int                     npix);

// guarda un arreglo SV completo a un archivo binario, copia literal de la
// rama WRITE de Storage::b_transport en Basic_cpu-main/include/storage.h.
// devuelve 0 si se pudo escribir, -1 si no.
int dpi_save_output(const char* ruta, const svOpenArrayHandle datos, int len);

} // extern "C"

#endif
