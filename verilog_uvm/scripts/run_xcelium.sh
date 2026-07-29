#!/usr/bin/env bash
# run_xcelium.sh (referencia — no ejecutable aquí, no hay Xcelium instalado
# en este entorno). Pensado para correr FUERA de EDA Playground.

set -euo pipefail
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$AQUI/../vectors"

xrun -uvm -sv \
     -f "$AQUI/filelist.f" \
     "$AQUI/../dpi/dpi_accel_glue.cpp" \
     +UVM_TESTNAME=rgb2gray_uvm_test
