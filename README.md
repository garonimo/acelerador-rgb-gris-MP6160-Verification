# Verificación de una RAM AXI4 con UVM y DPI-C

**Evaluación Corta 4 — Diseño de Alto Nivel (MP6160)**
II Cuatrimestre 2026 · Tecnológico de Costa Rica
Profesor: Luis G. León-Vega, Ph.D.

En esta tarea se reimplementa el módulo de RAM del sistema TLM-2.0 de una tarea anterior como un esclavo **AXI4 Full en SystemVerilog**, se verifica con un testbench **UVM**, y se integra la lógica de CPU/acelerador de ese mismo sistema mediante **DPI-C**. Un **modelo golden** (un archivo hexadecimal offline de la RAM real en SystemC) sirve como
metodo comparación en el `scoreboard`.

| Parte | Estado |
|---|---|
| RTL (`axi_ram.sv`), VIP AXI4, BFM, DPI-C, modelo dorado(golden) | Implementado |
| Modelo dorado (`golden_dump.cpp`) | Compilado, ejecutado y verificado bit a bit contra los vectores de HLS |
| Corrida del testbench UVM en EDA Playground (VCS) |  **PASS**: `scoreboard` confirma RAM RTL (AXI4) == RAM SystemC (golden dump), 0 `UVM_ERROR` / 0 `UVM_FATAL` (Sec. 9.2) |

> Este repositorio reúne tres entregas relacionadas; este README documenta la más
> reciente (EC4). Las anteriores quedan intactas y se referencian como oráculo/insumo:
> - [`Basic_cpu-main/`](Basic_cpu-main/README.md) — evaluación base: el acelerador
>   modelado con TLM-2.0 "a secas" (CPU + Bus + **RAM** + Acelerador + Almacenamiento).
>   Es la fuente de la RAM y del mapa de memoria que EC4 reimplementa.
> - [`hls/`](hls/README.md) y [`virtual_prototype/`](virtual_prototype/scripts/) —
>   segunda evaluación: el mismo acelerador en Vitis HLS y en un prototipo virtual
>   ARM64+gem5. Aportan los vectores de prueba recortados (`hls/tb/vectors/`) que EC4
>   reutiliza para acelerar la simulación.
> - Implementación en EDA playground: https://www.edaplayground.com/x/nTZx

---

## Tabla de contenido

1. [Descripción del sistema](#1-descripción-del-sistema)
2. [Instrucciones de compilación y ejecución](#2-instrucciones-de-compilación-y-ejecución)
3. [Organización del repositorio](#3-organización-del-repositorio)
4. [Organización de los módulos](#4-organización-de-los-módulos)
5. [Diagrama de bloques](#5-diagrama-de-bloques)
6. [Diagrama de secuencias](#6-diagrama-de-secuencias)
7. [Formato de las transacciones](#7-formato-de-las-transacciones)
8. [Mapa de memoria y registros](#8-mapa-de-memoria-y-registros)
9. [Resultados obtenidos](#9-resultados-obtenidos)
10. [Correspondencia con las evaluaciones anteriores](#10-correspondencia-con-las-evaluaciones-anteriores)
11. [Declaración sobre el uso de Inteligencia Artificial](#11-declaración-sobre-el-uso-de-inteligencia-artificial)

---

## 1. Descripción del sistema

El enunciado de EC4 pide integrar, mediante DPI/VPI, el módulo de RAM del sistema TLM
existente dentro de un flujo de verificación en SystemVerilog/UVM. El sistema elegido
como base es `Basic_cpu-main/` porque es la única de las dos evaluaciones previas que
modela una **RAM real** (buffer con `b_transport()`, no acceso directo a archivo).

### Flujo verificado (4 fases, orquestadas por `rgb2gray_uvm_test`)

1. **Carga**: un agente UVM (`write_image_seq`) escribe la imagen recortada de entrada
   (`input_crop.hex`, texto hexadecimal cargado con `$readmemh`) en la RAM AXI4 (`INPUT_BASE`).
2. **Cómputo**: se cede el bus a `cpu_accel_bfm` (maestro AXI4 en SV plano), que lee
   `INPUT_BASE`, convierte a escala de grises por DPI-C (`dpi_rgb_to_gray`, copia literal
   de `Accelerator::rgb_a_gris`) y escribe el resultado en `OUTPUT_BASE`.
3. **Persistencia**: `cpu_accel_bfm` relee `OUTPUT_BASE` y llama a `dpi_save_output` para
   escribir `output_crop_gray.raw` a disco, igual que `Storage::b_transport` en escritura.
4. **Verificación**: el agente UVM relee `INPUT_BASE` y `OUTPUT_BASE`; el `scoreboard`
   compara byte a byte contra el **modelo dorado** (volcado real de `Ram::data` en
   `Basic_cpu-main`) y reporta `UVM_ERROR`/`UVM_FATAL` ante cualquier discrepancia.

### Conversión implementada

La misma fórmula BT.601 entera de las dos evaluaciones anteriores, reproducida
literalmente en la función DPI `dpi_rgb_to_gray`:

```
Y = (77·R + 150·G + 29·B) >> 8
```

### Por qué un modelo dorado en vez de co-simular SystemC en vivo

Se tuvieron muchos problemas a la hora de intentar correr systemC en paralelo con UVM, 
pareciera ser un flujo muy pesado para una herramienta gratuita como EDA playground.
Según lo que pudimos investigar: No hay garantía de que EDA Playground soporte co-simulación 
SystemC+SV en tiempo real, y el enunciado no lo exige. por lo que se decidió implementar la
tarea de la siguiente manera: la lógica ya verificada de `Basic_cpu-main`(Tarea 2) se
reutiliza **dos veces sin modificarla**:

- Como cuerpo literal de las funciones DPI (`dpi_rgb_to_gray`, y `dpi_save_output`,
  copiado de la escritura de archivo de `storage.h`).
- Como generador **offline** del modelo dorado ([`verilog_uvm/golden/golden_dump.cpp`](verilog_uvm/golden/golden_dump.cpp)):
  corre el sistema TLM completo una vez, y vuelca a disco el contenido de `Ram::data` en
  las regiones de entrada y salida. Esos volcados son el modelo que usa el `scoreboard`.
- Es decir de corre el modelo de la tarea 1 para generar una serie de vectores que son el resultado
  final de la conversión y se guardan en un archivo. hex. Después esos vectores son leidos por el 
  scoreboard y comparados con el resultado final que se guarda en la memoria RAM creada en Verilog.
- Si se diera alguna diferencia entre los vectores y el resultado obtenido en Verilog se lanza un UVM_ERROR,
  de lo contrario no oasa nada. El test pasa si no hay ningún UVM_ERROR.

---

## 2. Instrucciones de compilación y ejecución

### 2.1 EDA Playground (recomendado — no requiere instalación)

Guía paso a paso completa en [`verilog_uvm/scripts/run_edaplayground.md`](verilog_uvm/scripts/run_edaplayground.md).
Resumen:

1. Crear un proyecto en [edaplayground.com](https://www.edaplayground.com/) con
   **SystemVerilog + UVM 1.2**, simulador **VCS** o **Xcelium** (ambos soportan DPI-C y UVM).
2. Panel **Design**: pegar el contenido de [`verilog_uvm/rtl/axi_ram.sv`](verilog_uvm/rtl/axi_ram.sv)
   como `design.sv` (EDA Playground fuerza ese nombre).
3. Panel **Testbench**: pegar el contenido de [`verilog_uvm/tb/tb_top.sv`](verilog_uvm/tb/tb_top.sv)
   como `testbench.sv`. Este archivo se auto-incluye (`` `include ``) todo lo demás en el
   orden correcto, así que además hay que **subir con su nombre original** (marcados como
   *"include file"*, no como diseño aparte) los 14 archivos: `axi_if.sv`, `bfm_ctrl_if.sv`,
   `axi_pkg.sv`, `tb_pkg.sv`, `cpu_accel_bfm.sv`, y los 9 que esos dos paquetes incluyen
   (`axi_sequencer.sv`, `axi_driver.sv`, `axi_monitor.sv`, `axi_agent.sv`, `seq_lib.sv`,
   `scoreboard.sv`, `env.sv`, `base_test.sv`, `rgb2gray_uvm_test.sv`).
4. Subir [`verilog_uvm/dpi/dpi_accel_glue.cpp`](verilog_uvm/dpi/dpi_accel_glue.cpp) (y su
   `.h`) **sin** marcarlo como include file, y agregar en "Compile Options":
   `-sysc +incdir+. dpi_accel_glue.cpp` (necesario para que VCS enlace el objeto DPI).
5. Subir los tres archivos hexadecimales de [`verilog_uvm/vectors/`](verilog_uvm/vectors/)
   (`input_crop.hex`, `golden_ram_in_region.hex`, `golden_ram_out_region.hex`) como
   archivos de texto — **no** los `.rgb`/`.bin` binarios: EDA Playground corrompe los
   bytes con el bit alto en 1 al tratarlos como texto UTF-8, y el testbench los carga con
   `$readmemh` precisamente para evitar ese problema.
6. Argumentos de simulación: `+UVM_TESTNAME=rgb2gray_uvm_test`.

Guía con el detalle completo y los errores típicos (con su causa y solución) en
[`verilog_uvm/scripts/run_edaplayground.md`](verilog_uvm/scripts/run_edaplayground.md).

### 2.2 Regenerar el modelo dorado localmente

Requiere SystemC (probado con 3.0.2, Accellera) y CMake ≥ 3.16:

```bash
cd verilog_uvm/golden
cmake -S . -B build
cmake --build build -j$(nproc)
LD_LIBRARY_PATH="$SYSTEMC_HOME/lib:$LD_LIBRARY_PATH" ./build/golden_dump
```

Genera `golden_ram_in_region.bin` y `golden_ram_out_region.bin`; convertirlos a texto
hexadecimal (`xxd -p -c1`) y copiarlos a `verilog_uvm/vectors/` (junto con
`input_crop.hex`) es lo que ya se hizo para esta entrega — el testbench UVM carga
los vectores con `$readmemh`, no con los binarios originales (ver Sec. 2.1, paso 5).
Detalle y resultado de la verificación cruzada en
[`verilog_uvm/golden/README.md`](verilog_uvm/golden/README.md).

### 2.3 Simulador local con licencia (VCS / Xcelium / Questa)

Scripts de referencia (no probados en este entorno, sin licencias disponibles):
`verilog_uvm/scripts/run_vcs.sh`, `run_xcelium.sh`, `run_questa.sh` y `build_dpi.sh`,
que usan la lista de archivos [`verilog_uvm/scripts/filelist.f`](verilog_uvm/scripts/filelist.f).

---

## 3. Organización del repositorio

```
acelerador-rgb-gris-MP6160-Verification/
├── README.md                          Este documento (EC4)
│
├── verilog_uvm/                       EVALUACIÓN CORTA 4  (esta entrega)
│   ├── README.md                      Arquitectura, mapa de memoria, cómo correr
│   ├── rtl/axi_ram.sv                 DUT: RAM esclava AXI4 Full
│   ├── tb/                            Testbench SystemVerilog + UVM (ver Sec. 4)
│   ├── dpi/dpi_accel_glue.{h,cpp}     Puente DPI-C hacia la lógica de Basic_cpu-main
│   ├── golden/golden_dump.cpp         Generador offline del modelo dorado (SystemC)
│   ├── vectors/                       input_crop.hex + los dos volcados dorados (hex)
│   └── scripts/                       filelist.f, build_dpi.sh, run_*.sh, run_edaplayground.md
│
├── Basic_cpu-main/                    Evaluación base: TLM-2.0 con RAM real (oráculo de EC4)
│
├── hls/                               Segunda evaluación: implementación en Vitis HLS
├── virtual_prototype/                 Segunda evaluación: prototipo virtual ARM64 + gem5
│
├── images/                            Imagen de entrada/salida RAW RGB (1080p completa)
├── docs/diagrama_bloques.txt          Diagrama de bloques del prototipo virtual (Eval. 2)
└── scripts/cross_check.sh             Verificación cruzada entre Eval. 1, HLS y VP
```

Detalle del árbol de `verilog_uvm/` en la [sección 4](#4-organización-de-los-módulos) y en
[`verilog_uvm/README.md`](verilog_uvm/README.md).

---

## 4. Organización de los módulos

### 4.1 `verilog_uvm/rtl/` — DUT

| Archivo | Función |
|---|---|
| `axi_ram.sv` | RAM esclava AXI4 Full. Backing disperso (`bit[7:0] mem[bit[ADDR_WIDTH-1:0]]`, solo reserva las posiciones escritas). Dos `task automatic` en `forever` (`atender_escrituras`, `atender_lecturas`) atienden AW→W→B y AR→R con soporte de `WSTRB` y `BRESP/RRESP` = `SLVERR` fuera de rango. |

### 4.2 `verilog_uvm/tb/` — testbench SystemVerilog + UVM

| Archivo | Función |
|---|---|
| `axi_if.sv` | Interfaz AXI4 (modports `master`/`slave`/`monitor`). |
| `bfm_ctrl_if.sv` | Handshake `start`/`done` entre el test y `cpu_accel_bfm`. |
| `axi_pkg.sv` | Paquete VIP AXI4: parámetros, clase `axi_txn`, e incluye `axi_sequencer.sv`, `axi_driver.sv` (traduce `axi_txn` a ráfagas reales), `axi_monitor.sv` (observador pasivo), `axi_agent.sv`, `seq_lib.sv` (`write_image_seq`/`read_check_seq`) y `scoreboard.sv` (compara contra el modelo dorado). |
| `tb_pkg.sv` | Paquete de entorno/tests: incluye `env.sv` (`rgb2gray_env`), `base_test.sv` y `rgb2gray_uvm_test.sv` (orquesta las 4 fases de la Sec. 1). |
| `cpu_accel_bfm.sv` | Módulo plano (no UVM) que reproduce `Accelerator::proceso()` + el cierre de `CPU::flujo_principal()`: maestro AXI4 propio + llamadas DPI. |
| `tb_top.sv` | Reloj/reset, tres instancias de `axi_if`, mux estático de bus (ver Sec. 5), instanciación del DUT y del BFM, `uvm_config_db`, `run_test()`. |

### 4.3 `verilog_uvm/dpi/` — puente DPI-C

`dpi_accel_glue.h`/`.cpp` — dos funciones `extern "C"`, cada una copia literal de la
lógica ya verificada en `Basic_cpu-main`:

| Función DPI | Copia de |
|---|---|
| `dpi_rgb_to_gray` | `Accelerator::rgb_a_gris` (BT.601 entero) |
| `dpi_save_output` | Rama de escritura de `Storage::b_transport` |

> La carga de los vectores de entrada (`input_crop.hex` y los dos volcados
> dorados) **no** usa DPI: se hace con `$readmemh` sobre archivos de texto
> hexadecimal. Subir el binario original (`.rgb`/`.bin`) a EDA Playground
> corrompía los bytes con el bit alto en 1 (los reemplazaba por la secuencia
> UTF-8 de U+FFFD), porque la plataforma trata los archivos subidos como
> texto UTF-8. El hexadecimal es texto ASCII puro y no sufre ese problema.

### 4.4 `verilog_uvm/golden/` — modelo dorado

`golden_dump.cpp` incluye sin modificar los headers de `Basic_cpu-main`
(`accelerator.h`, `bus.h`, `common.h`, `cpu.h`, `ram.h`, `storage.h`), instancia los
mismos 5 módulos que `Basic_cpu-main/main.cpp`, corre `sc_start()` y vuelca
`Ram::data` en las regiones de entrada/salida a `golden_ram_in_region.bin` /
`golden_ram_out_region.bin`. Esos binarios se convierten después a texto
hexadecimal (`vectors/*.hex`) para poder subirlos a EDA Playground sin
corrupción (ver Sec. 4.3). Detalle y resultado en
[`verilog_uvm/golden/README.md`](verilog_uvm/golden/README.md).

---

## 5. Diagrama de bloques

Un solo puerto AXI4 esclavo (`axi_ram`), compartido en el tiempo por dos maestros que
nunca están activos a la vez (sin árbitro: el orden de fases del test lo garantiza vía
`bus_sel = ctrl.start && !ctrl.done`):

```
        +==========================================================+
        |            tb_top  (mux estatico de bus AXI4)            |
        |                                                          |
        |   +--------------+                    +---------------+ |
        |   |  UVM agent   |                     |               | |
        |   | (sequencer + |---AXI4 (bus_sel=0)-->|               | |
        |   |   driver)    |<--------------------|               | |
        |   +--------------+                     |               | |
        |         write_image_seq /              |    axi_ram    | |
        |         read_check_seq                  |     (DUT)     | |
        |                                          |               | |
        |   +--------------+                      |               | |
        |   | cpu_accel_bfm|---AXI4 (bus_sel=1)-->|               | |
        |   | (DPI: rgb_a_gris,                    |               | |
        |   |  guarda archivo)|<------------------|               | |
        |   +------+-------+                     +-------+-------+ |
        |          ^ start/done (bfm_ctrl_if)             |         |
        +----------|------------------------------------- |---------+
                   test (rgb2gray_uvm_test)          scoreboard compara
                                                     contra golden_ram_*.hex
```

Versión narrada y con más detalle en [`verilog_uvm/README.md`](verilog_uvm/README.md#arquitectura).

---

## 6. Diagrama de secuencias

```
 rgb2gray_uvm_test      env.agent (UVM)        axi_ram (DUT)      cpu_accel_bfm      scoreboard
        |                     |                     |                    |               |
        |--write_image_seq--->|---AXI4 W (AW/W/B)-->|                    |               |
        |   (input_crop.hex)   |                     |  (guarda en mem)   |               |
        |                     |                     |                    |               |
        |--ctrl.start=1------------------------------------------------->|               |
        |                     |                     |<--AXI4 R (AR/R)----|               |
        |                     |                     |------------------->| dpi_rgb_to_gray|
        |                     |                     |<--AXI4 W (AW/W/B)--| (BT.601 int)   |
        |                     |                     |------------------->| dpi_save_output|
        |                     |                     |                    | (a disco)      |
        |<--ctrl.done=1-------------------------------------------------|               |
        |--ctrl.start=0------------------------------------------------->|               |
        |                     |                     |                    |               |
        |--read_check_seq---->|---AXI4 R (AR/R)---->|                    |               |
        |   (INPUT_BASE)      |<--------------------|                    |               |
        |--read_check_seq---->|---AXI4 R (AR/R)---->|                    |               |
        |   (OUTPUT_BASE)     |<--------------------|                    |               |
        |                     |                     |                    |               |
        |--verificar_bloque(golden_ram_in_region.hex, ...)------------------------------->|
        |--verificar_bloque(golden_ram_out_region.hex, ...)------------------------------>|
        |--resumen() ---------------------------------------------------------------->UVM_INFO/FATAL
```

---

## 7. Formato de las transacciones

El DUT y el VIP implementan el subconjunto de **AXI4 Full** necesario para ráfagas
`INCR`: canales de escritura `AW`/`W`/`B` y de lectura `AR`/`R` (sin `AxLOCK`/`AxCACHE`/
`AxPROT`/`AxQOS`).

| Canal | Señales relevantes | Uso en este diseño |
|---|---|---|
| `AW` (dirección de escritura) | `awaddr`, `awlen`, `awvalid/awready` | `awlen` codifica ráfagas de hasta 256 beats |
| `W` (datos de escritura) | `wdata`, `wstrb`, `wlast`, `wvalid/wready` | `wstrb` habilita escrituras parciales de 32 bits |
| `B` (respuesta de escritura) | `bresp`, `bvalid/bready` | `2'b00` OKAY / `2'b10` SLVERR (fuera de rango) |
| `AR` (dirección de lectura) | `araddr`, `arlen`, `arvalid/arready` | Igual que `AW` |
| `R` (datos de lectura) | `rdata`, `rresp`, `rlast`, `rvalid/rready` | `rlast` marca el último beat de la ráfaga |

La clase `axi_txn` (en `axi_pkg.sv`) es la transacción de más alto nivel que usa el VIP:
`is_write`, `addr`, `nbytes` (1–1024 B, restringido por `constraint c_nbytes`), `wdata[]`/
`rdata[]`, `resp_error`. El driver la fragmenta en una o más ráfagas AXI4 reales; las
secuencias (`write_image_seq`/`read_check_seq`) fragmentan buffers arbitrariamente
grandes en varias `axi_txn` de ≤1024 B cada una.

---

## 8. Mapa de memoria y registros

Igual al de [`Basic_cpu-main/include/common.h`](Basic_cpu-main/include/common.h) — **no**
al de `virtual_prototype/`, que no tiene RAM ni este mapa:

| Símbolo | Valor |
|---|---|
| `INPUT_BASE` (`map::DIR_IMG_IN`) | `0x0000_0000` |
| `OUTPUT_BASE` (`map::DIR_IMG_OUT`) | `0x0080_0000` |
| Ancho de datos AXI | 32 bits (`STRB_WIDTH` = 4) |
| Tamaño de RAM representado | 64 MiB (`map::RAM_SIZE`), backing disperso |
| Recorte de prueba | 8192 píxeles → 24 576 B RGB / 8192 B gris (mismo recorte que `hls/tb/vectors/input_crop.rgb`) |

Los registros de control del acelerador (`acc_reg::{DIR_IN,DIR_OUT,NUM_PIXELS,CTRL,
STATUS}`, con `START_BIT`/`DONE_BIT`) **no** se exponen como una segunda ventana AXI4:
se modelan como estado interno de `cpu_accel_bfm`, sincronizado con el test por
`bfm_ctrl_if` (`start`/`done`). Lo que EC4 pide verificar con UVM/AXI4 es la **RAM**, no
el bus de control del acelerador.

---

## 9. Resultados obtenidos

### 9.1 Validación del modelo dorado (completada localmente)

```bash
$ cmp golden_ram_in_region.bin  hls/tb/vectors/input_crop.rgb   # MATCH
$ cmp golden_ram_out_region.bin hls/tb/vectors/ref_crop.raw     # MATCH
```

| Comparación | Resultado |
|---|---|
| `golden_ram_in_region.bin` (volcado de `Ram::data` en `INPUT_BASE`) vs. `input_crop.rgb` (vector de HLS) | Idénticos byte a byte |
| `golden_ram_out_region.bin` (volcado de `Ram::data` en `OUTPUT_BASE`) vs. `ref_crop.raw` (referencia de HLS) | Idénticos byte a byte |

Esto confirma, con **tres implementaciones independientes** (TLM/SystemC de
`Basic_cpu-main`, HLS y el volcado dorado de EC4), que el mapa de memoria, el recorte de
8192 píxeles y la fórmula BT.601 concuerdan exactamente. Ver el detalle en
[`verilog_uvm/golden/README.md`](verilog_uvm/golden/README.md).

### 9.2 Corrida del testbench UVM en EDA Playground

No hay licencia local de VCS/Xcelium/Questa, así que la corrida se realizó en
**EDA Playground** con el simulador **Synopsys VCS X-2025.06** y **UVM 1.2**. El resultado es
**PASS**: el `scoreboard` confirma que la RAM RTL en AXI4 produce, byte a byte, el mismo
contenido que el modelo dorado volcado desde la RAM SystemC de `Basic_cpu-main`.

Corrida reproducible en línea: <https://www.edaplayground.com/x/nTZx>

#### Traza de la simulación

```
UVM_INFO @ 0: reporter [RNTST] Running test rgb2gray_uvm_test...
UVM_INFO rgb2gray_uvm_test.sv(54) @ 62395:  uvm_test_top [rgb2gray_uvm_test] imagen de entrada escrita en RAM (AXI4)
UVM_INFO rgb2gray_uvm_test.sv(60) @ 165755: uvm_test_top [rgb2gray_uvm_test] cpu_accel_bfm termino (conversion + guardado)
UVM_INFO scoreboard.sv(45) @ 248315:        uvm_test_top.env.sb [scoreboard] PASS: RAM RTL (AXI4) == RAM SystemC (golden dump)

--- UVM Report Summary ---
** Report counts by severity
UVM_INFO    : 6
UVM_WARNING : 0
UVM_ERROR   : 0
UVM_FATAL   : 0

$finish at simulation time 248315
```

Los tres hitos de la traza corresponden a las fases del flujo descritas en la Sec. 1: la carga
de la imagen en la RAM AXI4 (@62395), el cómputo y guardado por el BFM (@165755) y la
verificación final contra el modelo dorado (@248315). El conteo `UVM_ERROR : 0` /
`UVM_FATAL : 0` es la condición de aprobación del testbench.

#### Problemas de integración resueltos durante la puesta a punto

Antes de llegar al PASS se encontraron y resolvieron varios problemas propios del entorno de
EDA Playground, no de la lógica del diseño:

| Problema | Causa | Solución |
|---|---|---|
| `Package not defined` (`axi_pkg`/`tb_pkg`) y `ADDR_WIDTH`/`DATA_WIDTH` no declarados | EDA Playground no garantiza que compile los paquetes antes que `testbench.sv` cuando son archivos separados en el panel. | `tb_top.sv` se auto-incluye (`` `include ``) `axi_if.sv`, `bfm_ctrl_if.sv`, `axi_pkg.sv`, `tb_pkg.sv` y `cpu_accel_bfm.sv` en el orden correcto, sin depender del panel; esos archivos se suben aparte solo como *include file*. |
| `Error-[SE] Syntax error ... token is 'buf'` en `cpu_accel_bfm.sv` | `buf` es palabra reservada de Verilog (primitiva de compuerta `buf`/`bufif0`/`bufif1`), no se puede usar como nombre de variable. | Renombrada la variable a `datos` en las tasks `leer_bloque`/`escribir_bloque`. |
| `Error-[DPI-DIFNF] DPI import function not found` en tiempo de ejecución | `dpi_accel_glue.cpp` estaba subido pero EDA Playground no lo compila/enlaza como objeto DPI solo por estar presente. | Agregar en "Compile Options": `-sysc +incdir+. dpi_accel_glue.cpp`. |
| El `scoreboard` reportaba error en *todos* los bytes de `OUTPUT_BASE`, con valores "ruidosos" (no una imagen en escala de grises real) | Los vectores binarios (`input_crop.rgb`) subidos a EDA Playground se corrompían: la plataforma trata los archivos subidos como texto UTF-8, y reemplazaba cada byte con el bit alto en 1 por la secuencia UTF-8 de U+FFFD (3 bytes). Confirmado byte a byte con `$display` de depuración temporal en `cpu_accel_bfm.sv` y aplicando la fórmula BT.601 a mano sobre los bytes corruptos, que reproducía exactamente el valor erróneo reportado. | Los 3 vectores se convirtieron a texto hexadecimal (`xxd -p -c1`, un byte por línea) y se cargan con `$readmemh` en vez de con la función DPI `dpi_load_file` (que se eliminó por quedar sin uso; ver Sec. 4.3). El hexadecimal es texto ASCII puro y no sufre ese problema. |

---

## 10. Correspondencia con las evaluaciones anteriores

```
        Evaluación base (TLM-2.0, Basic_cpu-main): CPU + Bus + RAM + Acelerador + Storage
         RAM real (Ram::data), acelerador BT.601 entero
                                    |
                +-------------------+-------------------+
                |                                       |
      Segunda evaluación (HLS + VP)              Evaluación Corta 4 (esta entrega)
   sin RAM intermedia (E/S directa a archivo)    RAM real -> AXI4 Full + UVM + DPI-C
   aporta los vectores recortados (input_crop.rgb)   modelo dorado = volcado de Ram::data
                |                                       |
                +-------------------+-------------------+
                                    |
                  Misma fórmula BT.601 entera, mismo mapa de memoria,
                  mismo recorte de 8192 píxeles: verificado bit a bit (Sec. 9.1)
```

El acelerador y su fórmula de conversión no cambian entre evaluaciones; lo que cambia es
el mecanismo de transporte de los datos (TLM-2.0 puro → AXI4-Lite/HLS → AXI4 Full/UVM) y,
en EC4, el hecho de que ahora existe un **golden model** explícito para automatizar esa
comparación dentro del propio testbench, en vez de compararla manualmente con `cmp`.

---

## 11. Declaración sobre el uso de Inteligencia Artificial

De acuerdo con lo establecido en el enunciado, se declara el uso de herramientas de
Inteligencia Artificial durante el desarrollo de esta evaluación. Se utilizó **GitHub Copilot**,
con los siguientes propósitos:

- **Planeamiento de la arquitectura de verificación.** Se consultó cómo estructurar un entorno
  UVM para verificar una RAM AXI4 e integrar la lógica de un sistema TLM existente mediante
  DPI-C. *Prompt representativo:* «cómo verificar con UVM un esclavo de RAM AXI4 en
  SystemVerilog y reutilizar por DPI-C la función de conversión de un modelo SystemC previo».

- **Generación de código base.** A partir del sistema `Basic_cpu-main`, se generó con asistencia
  el andamiaje del DUT (`axi_ram.sv`), del VIP AXI4 (driver, monitor, sequencer, agente), del
  `scoreboard`, del `cpu_accel_bfm` y del puente DPI-C (`dpi_accel_glue.cpp`), así como el
  generador del modelo dorado (`golden_dump.cpp`). *Prompt representativo:* «escribir un driver
  AXI4 UVM que fragmente una transacción de alto nivel en ráfagas INCR y un scoreboard que
  compare contra un volcado de referencia».

- **Depuración.** Se utilizó asistencia para diagnosticar los problemas de integración
  documentados en la Sec. 9.2: el orden de compilación de paquetes, la palabra reservada `buf`,
  el enlace del objeto DPI y la corrupción de los vectores binarios en EDA Playground.

- **Scripts y documentación.** Los scripts de ejecución (`run_*.sh`, `filelist.f`,
  `run_edaplayground.md`) y la redacción de esta documentación técnica se elaboraron con
  asistencia a partir del código del proyecto.

La totalidad del código y de los resultados fue revisada y verificada por el equipo. La fórmula
de conversión BT.601, el mapa de memoria y el sistema base `Basic_cpu-main` provienen del
trabajo propio desarrollado en las evaluaciones anteriores.
