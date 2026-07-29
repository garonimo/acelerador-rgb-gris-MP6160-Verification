# Cómo correr esto en EDA Playground

Este testbench no depende de gem5 ni de un kernel SystemC vivo: es SystemVerilog +
UVM + DPI-C estándar, compatible con los simuladores que ofrece EDA Playground de
forma gratuita. Pasos exactos:

## 1. Elegir simulador

En el panel izquierdo, "Tools & Simulators": elegir **Synopsys VCS** o
**Cadence Xcelium** (ambos con soporte sólido de UVM 1.2 + DPI-C en el tier
gratuito de EDA Playground). Aldec Riviera-PRO también funciona si VCS/Xcelium
no están disponibles en tu cuenta.

Marcar la casilla **"Open EPWave after run"** si quieres ver las formas de onda
del bus AXI4 (opcional).

En "UVM library", seleccionar **1.2** (o la versión "built-in" que ofrezca el
simulador elegido).

## 2. Archivos y en qué panel van

**Panel "Design"** (RTL, el DUT):
- `rtl/axi_ram.sv`

**Panel "Testbench"** (SystemVerilog + UVM), **en este orden**:
1. `tb/axi_if.sv`
2. `tb/bfm_ctrl_if.sv`
3. `tb/axi_pkg.sv`
4. `tb/tb_pkg.sv`
5. `tb/cpu_accel_bfm.sv`
6. `tb/tb_top.sv`

> `tb/axi_pkg.sv` incluye por `` `include `` a `axi_sequencer.sv`, `axi_driver.sv`,
> `axi_monitor.sv`, `axi_agent.sv`, `seq_lib.sv` y `scoreboard.sv`; `tb/tb_pkg.sv`
> incluye a `env.sv`, `base_test.sv` y `rgb2gray_uvm_test.sv`. **Súbelos
> también** (en cualquier panel, EDA Playground los resuelve por nombre porque
> quedan todos en el mismo directorio de compilación), pero **no los agregues
> a la lista de compilación como módulos aparte** — si el simulador se queja de
> clases duplicadas, usa "Add as include file" en vez de "Add as design file"
> para esos 9 archivos.

**Archivo DPI (C++)**:
- `dpi/dpi_accel_glue.cpp` — súbelo en el panel "Testbench" o en la sección de
  archivos C/C++ si el simulador la separa (VCS/Xcelium en EDA Playground
  detectan la extensión `.cpp` y lo compilan/enlazan automáticamente junto al
  resto, sin flags adicionales).

## 3. Archivos de datos (vectores)

Subir como archivos sueltos (botón "+" → "Upload" en el panel de archivos),
**no como código**, para que queden en el directorio de ejecución (el
testbench los abre por ruta relativa con `dpi_load_file`):

- `vectors/input_crop.rgb` (24 576 B)
- `vectors/golden_ram_in_region.bin` (24 576 B)
- `vectors/golden_ram_out_region.bin` (8192 B)

Si tu cuenta de EDA Playground no permite subir binarios sueltos, conviértelos
a texto y decodifícalos en el propio testbench (alternativa de respaldo, no
necesaria si la subida binaria funciona):

```bash
xxd -p vectors/input_crop.rgb > input_crop.hex
```

y usar `$readmemh` en vez de `dpi_load_file` para ese archivo puntual — no se
documenta más a fondo porque el camino principal (subida binaria + DPI) ya
funciona en los tres simuladores mencionados.

## 4. Comando de simulación

EDA Playground arma el comando de compilación/corrida automáticamente al
apretar "Run". Si necesitas customizarlo (panel "Tools & Simulators" →
"Simulation Options" / "More Options"), usar equivalentes a:

- VCS: `-sverilog -ntb_opts uvm-1.2 +UVM_TESTNAME=rgb2gray_uvm_test`
- Xcelium: `-uvm -sv +UVM_TESTNAME=rgb2gray_uvm_test`

`+UVM_TESTNAME=rgb2gray_uvm_test` selecciona el test que orquesta el flujo
completo (ver `tb/rgb2gray_uvm_test.sv`).

## 5. Qué esperar en la consola

```
UVM_INFO ... imagen de entrada escrita en RAM (AXI4)
UVM_INFO ... cpu_accel_bfm termino (conversion + guardado)
UVM_INFO ... PASS: RAM RTL (AXI4) == RAM SystemC (golden dump)
```

Si algo no coincide, aparece un `UVM_ERROR` por cada byte distinto (dirección,
valor esperado y obtenido) y un `UVM_FATAL` de resumen al final del test.

## 6. Archivo de salida

`cpu_accel_bfm` persiste el resultado en `output_crop_gray.raw` (vía DPI, en
el directorio de ejecución de EDA Playground) — descargable desde el panel de
archivos al terminar la corrida, igual que hace `Storage` en `Basic_cpu-main`.
