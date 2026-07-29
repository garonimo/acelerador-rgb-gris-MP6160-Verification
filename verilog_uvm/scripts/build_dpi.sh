#!/usr/bin/env bash
# build_dpi.sh
# Compila dpi_accel_glue.cpp a un objeto/shared library reutilizable por
# simuladores que se invocan fuera de EDA Playground (ahí no hace falta:
# basta con subir el .cpp como archivo de "Files", EDA Playground lo
# compila y enlaza automáticamente junto al resto).
#
# Uso: ./build_dpi.sh <vcs|xcelium|questa>

set -euo pipefail

SIMULADOR="${1:-vcs}"
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DPI_SRC="$AQUI/../dpi/dpi_accel_glue.cpp"
OUT_DIR="$AQUI/../dpi/build"
mkdir -p "$OUT_DIR"

case "$SIMULADOR" in
  vcs)
    : "${VCS_HOME:?defina VCS_HOME (instalación de Synopsys VCS)}"
    g++ -c -fPIC -I"$VCS_HOME/include" "$DPI_SRC" -o "$OUT_DIR/dpi_accel_glue.o"
    ;;
  xcelium)
    : "${XCELIUM_HOME:?defina XCELIUM_HOME (instalación de Cadence Xcelium)}"
    g++ -c -fPIC -I"$XCELIUM_HOME/tools/include" "$DPI_SRC" -o "$OUT_DIR/dpi_accel_glue.o"
    ;;
  questa)
    : "${QUESTA_HOME:?defina QUESTA_HOME (instalación de Siemens Questa)}"
    g++ -c -fPIC -I"$QUESTA_HOME/include" "$DPI_SRC" -o "$OUT_DIR/dpi_accel_glue.o"
    ;;
  *)
    echo "simulador desconocido: $SIMULADOR (use vcs|xcelium|questa)" >&2
    exit 1
    ;;
esac

echo "Generado: $OUT_DIR/dpi_accel_glue.o"
