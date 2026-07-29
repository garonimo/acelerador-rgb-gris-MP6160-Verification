#!/usr/bin/env bash
# run_questa.sh (referencia — no ejecutable aquí, no hay Questa instalado
# en este entorno). Pensado para correr FUERA de EDA Playground.

set -euo pipefail
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$AQUI/../vectors"

vlib work
vlog -sv +incdir+"$AQUI/../rtl" +incdir+"$AQUI/../tb" -f "$AQUI/filelist.f"
vsim -c -sv_lib "$AQUI/../dpi/build/dpi_accel_glue" \
     work.tb_top +UVM_TESTNAME=rgb2gray_uvm_test -do "run -all; quit"
