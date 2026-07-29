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

EDA Playground obliga a que el archivo top de cada panel se llame
`design.sv` (Design) y `testbench.sv` (Testbench). Para no depender del
orden en que EDA Playground compile el resto de archivos (fuente de los
errores típicos `Package not defined` / identificadores no declarados),
`testbench.sv` se incluye a sí mismo todo lo demás con `` `include ``, en
el orden correcto, **sin importar el orden del panel**.

**Panel "Design"**:
- Contenido de `rtl/axi_ram.sv` → pegar/subir como `design.sv`.

**Panel "Testbench"**:
- Contenido de `tb/tb_top.sv` → pegar/subir como `testbench.sv` (este archivo
  ya trae al inicio `` `include "axi_if.sv" ``, `` `include "bfm_ctrl_if.sv" ``,
  `` `include "axi_pkg.sv" ``, `` `include "tb_pkg.sv" ``,
  `` `include "cpu_accel_bfm.sv" ``).
- Súbelos también, **con su nombre original** (`axi_if.sv`, `bfm_ctrl_if.sv`,
  `axi_pkg.sv`, `tb_pkg.sv`, `cpu_accel_bfm.sv`) y, a su vez, los 9 archivos
  que `axi_pkg.sv`/`tb_pkg.sv` incluyen (`axi_sequencer.sv`, `axi_driver.sv`,
  `axi_monitor.sv`, `axi_agent.sv`, `seq_lib.sv`, `scoreboard.sv`, `env.sv`,
  `base_test.sv`, `rgb2gray_uvm_test.sv`).
- **Importante**: estos 14 archivos (todos `.sv`) deben marcarse como *"Add
as include file"* al subirlos (o desmarcar la opción "Compile"/"Design
file" que ofrezca el diálogo de subida), **no** como archivo de diseño/
testbench normal. Si se compilan también por su cuenta, sus paquetes o
clases quedan declarados dos veces (error de "ya declarado"/
"redefinition"). Si tu cuenta de EDA Playground no distingue esa opción
por archivo, alcanza con que **no** aparezcan en la lista de archivos "a
compilar" del panel — únicamente deben estar presentes en el directorio de
trabajo para que el `` `include `` los encuentre.

> ⚠️ Esta marca de "include file" es **solo para los 14 `.sv` de arriba**.
> El archivo DPI (`dpi_accel_glue.cpp`, ver abajo) es C++, no SystemVerilog:
> `` `include `` no aplica a él. Si lo marcas como "include file" por
> error, VCS no lo compila/enlaza como objeto DPI y falla en tiempo de
> elaboración con `Error-[DPI-DIFNF] DPI import function not found` (aunque
> el archivo esté subido y se vea en la lista). Debe quedar como archivo de
> compilación normal.

> Por qué este cambio: subir `axi_pkg.sv`/`tb_pkg.sv` como archivos de
> testbench "normales" deja su orden de compilación en manos de EDA
> Playground, que no siempre los compila antes que `testbench.sv` — de ahí
> errores como `Package not defined` o `ADDR_WIDTH`/`DATA_WIDTH` no
> declarados. Incluyéndolos desde dentro de `testbench.sv` el orden queda
> fijo sin importar la configuración del panel.

**Archivo DPI (C++)**:
- `dpi/dpi_accel_glue.cpp` — súbelo en el panel "Testbench" (o en la sección
  de archivos C/C++ si el simulador la separa). **No lo marques como
  "include file"** — a diferencia de los `.sv` de la lista de arriba, este
  archivo sí debe compilarse normalmente para que VCS/Xcelium generen el
  objeto DPI y lo enlacen; si quedó marcado como include por error, el
  síntoma es un `Error-[DPI-DIFNF] DPI import function not found` al correr.
- `dpi/dpi_accel_glue.h` — solo hace falta si `dpi_accel_glue.cpp` lo
  incluye por ruta relativa; súbelo junto al `.cpp` en el mismo panel.
- **Flag de compilación necesario**: EDA Playground no detecta ni enlaza el
  `.cpp` automáticamente solo por estar subido. Hay que agregarlo a mano en
  "Tools & Simulators" → **"Compile Options"**:

  ```
  -sysc +incdir+. dpi_accel_glue.cpp
  ```

  Sin este flag, VCS compila y elabora el testbench sin error, pero falla en
  tiempo de ejecución con `Error-[DPI-DIFNF] DPI import function not found`
  (la firma DPI existe en el `.sv`, pero no hay objeto C++ enlazado que la
  implemente). Con el flag, el mismo `.cpp` que ya estaba subido se compila
  y se enlaza correctamente.

## 3. Archivos de datos (vectores)

Subir como archivos sueltos de **texto** (botón "+" → "Upload" en el panel de
archivos), en formato hexadecimal (un byte por línea), **no los binarios
originales** (`.rgb`/`.bin`):

- `vectors/input_crop.hex` (24 576 líneas)
- `vectors/golden_ram_in_region.hex` (24 576 líneas)
- `vectors/golden_ram_out_region.hex` (8192 líneas)

El testbench los carga con `$readmemh` (`tb/rgb2gray_uvm_test.sv` y
`tb/scoreboard.sv`), no con DPI. **Por qué**: al subir los archivos binarios
originales (`.rgb`/`.bin`) se observó que EDA Playground los trata como texto
UTF-8, y cada byte con el bit alto en 1 (es decir, todo byte no-ASCII) se
reemplazaba por la secuencia UTF-8 del carácter de reemplazo U+FFFD (`EF BF
BD`), corrompiendo silenciosamente los datos antes de que el testbench los
leyera — el error se manifestaba como un `UVM_ERROR` del `scoreboard` en
prácticamente todos los bytes de la comparación. El hexadecimal es texto
ASCII puro (dígitos `0`–`9`/`a`–`f`) y no sufre ese problema.

Si regeneras los `.hex` a partir de los binarios (por ejemplo tras correr de
nuevo `golden_dump.cpp`, ver [`golden/README.md`](../golden/README.md)):

```bash
cd verilog_uvm/vectors
xxd -p -c1 input_crop.rgb              > input_crop.hex
xxd -p -c1 golden_ram_in_region.bin    > golden_ram_in_region.hex
xxd -p -c1 golden_ram_out_region.bin   > golden_ram_out_region.hex
```

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
