#!/usr/bin/env bash
# run_vcs.sh (referencia — no ejecutable aquí, no hay VCS instalado en este
# entorno). Pensado para correr FUERA de EDA Playground, con licencia local.

set -euo pipefail
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$AQUI/../vectors" # los archivos de imagen se buscan por ruta relativa al cwd

vcs -sverilog -ntb_opts uvm-1.2 \
    -CFLAGS "-I${VCS_HOME}/include" \
    "$AQUI/../dpi/dpi_accel_glue.cpp" \
    -f "$AQUI/filelist.f" \
    -o simv

./simv +UVM_TESTNAME=rgb2gray_uvm_test
