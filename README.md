# Verificación de una RAM AXI4 con UVM y DPI-C

**Evaluación Corta 4 — Diseño de Alto Nivel (MP6160)**
II Cuatrimestre 2026 · Tecnológico de Costa Rica
Profesor: Luis G. León-Vega, Ph.D.

Reimplementa el módulo de RAM del sistema TLM-2.0 de una evaluación anterior
(`Basic_cpu-main/`) como un esclavo **AXI4 Full en SystemVerilog**, lo verifica con un
testbench **UVM**, e integra la lógica de CPU/acelerador de ese mismo sistema mediante
**DPI-C**. Un **modelo dorado** (volcado offline de la RAM real en SystemC) sirve como
oráculo de comparación en el `scoreboard`.

| Parte | Estado |
|---|---|
| RTL (`axi_ram.sv`), VIP AXI4, BFM, DPI-C, modelo dorado | ✅ Implementado |
| Modelo dorado (`golden_dump.cpp`) | ✅ Compilado, ejecutado y verificado bit a bit contra los vectores de HLS |
| Corrida del testbench UVM en un simulador SystemVerilog real | ⏳ Pendiente (sin licencia local; pensado para **EDA Playground**, ver Sec. 2) |

> Este repositorio reúne tres entregas relacionadas; este README documenta la más
> reciente (EC4). Las anteriores quedan intactas y se referencian como oráculo/insumo:
> - [`Basic_cpu-main/`](Basic_cpu-main/README.md) — evaluación base: el acelerador
>   modelado con TLM-2.0 "a secas" (CPU + Bus + **RAM** + Acelerador + Almacenamiento).
>   Es la fuente de la RAM y del mapa de memoria que EC4 reimplementa.
> - [`hls/`](hls/README.md) y [`virtual_prototype/`](virtual_prototype/scripts/) —
>   segunda evaluación: el mismo acelerador en Vitis HLS y en un prototipo virtual
>   ARM64+gem5. Aportan los vectores de prueba recortados (`hls/tb/vectors/`) que EC4
>   reutiliza para acelerar la simulación.
> - Planeamiento previo a esta implementación: [`verificacion_copilot.md`](verificacion_copilot.md).

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
   (`input_crop.rgb`) en la RAM AXI4 (`INPUT_BASE`).
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

No hay garantía de que EDA Playground soporte co-simulación SystemC+SV en tiempo real, y
el enunciado no lo exige. En su lugar, la lógica ya verificada de `Basic_cpu-main` se
reutiliza **dos veces sin modificarla**:

- Como cuerpo literal de las funciones DPI (`dpi_rgb_to_gray`, y el copiado de la carga/
  guardado de archivo de `storage.h`).
- Como generador **offline** del modelo dorado ([`verilog_uvm/golden/golden_dump.cpp`](verilog_uvm/golden/golden_dump.cpp)):
  corre el sistema TLM completo una vez, y vuelca a disco el contenido de `Ram::data` en
  las regiones de entrada y salida. Esos volcados son el oráculo que usa el `scoreboard`.

---

## 2. Instrucciones de compilación y ejecución

### 2.1 EDA Playground (recomendado — no requiere instalación)

Guía paso a paso completa en [`verilog_uvm/scripts/run_edaplayground.md`](verilog_uvm/scripts/run_edaplayground.md).
Resumen:

1. Crear un proyecto en [edaplayground.com](https://www.edaplayground.com/) con
   **SystemVerilog + UVM 1.2**, simulador **VCS** o **Xcelium** (ambos soportan DPI-C y UVM).
2. Panel **Design**: subir [`verilog_uvm/rtl/axi_ram.sv`](verilog_uvm/rtl/axi_ram.sv).
3. Panel **Testbench**, en este orden: `axi_if.sv`, `bfm_ctrl_if.sv`, `axi_pkg.sv`,
   `tb_pkg.sv`, `cpu_accel_bfm.sv`, `tb_top.sv`. Subir también los 9 archivos que esos dos
   paquetes incluyen por `` `include `` (`axi_sequencer.sv`, `axi_driver.sv`,
   `axi_monitor.sv`, `axi_agent.sv`, `seq_lib.sv`, `scoreboard.sv`, `env.sv`,
   `base_test.sv`, `rgb2gray_uvm_test.sv`) como *include files*.
4. Subir [`verilog_uvm/dpi/dpi_accel_glue.cpp`](verilog_uvm/dpi/dpi_accel_glue.cpp) (se
   compila automáticamente junto al testbench).
5. Subir los tres archivos de [`verilog_uvm/vectors/`](verilog_uvm/vectors/) como
   binarios (no como código fuente).
6. Argumentos de simulación: `+UVM_TESTNAME=rgb2gray_uvm_test`.

### 2.2 Regenerar el modelo dorado localmente

Requiere SystemC (probado con 3.0.2, Accellera) y CMake ≥ 3.16:

```bash
cd verilog_uvm/golden
cmake -S . -B build
cmake --build build -j$(nproc)
LD_LIBRARY_PATH="$SYSTEMC_HOME/lib:$LD_LIBRARY_PATH" ./build/golden_dump
```

Genera `golden_ram_in_region.bin` y `golden_ram_out_region.bin`; copiarlos a
`verilog_uvm/vectors/` (junto con `input_crop.rgb`) es lo que ya se hizo para esta
entrega. Detalle y resultado de la verificación cruzada en
[`verilog_uvm/golden/README.md`](verilog_uvm/golden/README.md).

### 2.3 Simulador local con licencia (VCS / Xcelium / Questa)

Scripts de referencia (no probados en este entorno, sin licencias disponibles):
`verilog_uvm/scripts/run_vcs.sh`, `run_xcelium.sh`, `run_questa.sh` y `build_dpi.sh`,
que usan la lista de archivos [`verilog_uvm/scripts/filelist.f`](verilog_uvm/scripts/filelist.f).

---

## 3. Organización del repositorio

```
repo-acc-verif/
├── README.md                          Este documento (EC4)
├── verificacion_copilot.md            Planeamiento previo a la implementación
│
├── verilog_uvm/                       EVALUACIÓN CORTA 4  (esta entrega)
│   ├── README.md                      Arquitectura, mapa de memoria, cómo correr
│   ├── rtl/axi_ram.sv                 DUT: RAM esclava AXI4 Full
│   ├── tb/                            Testbench SystemVerilog + UVM (ver Sec. 4)
│   ├── dpi/dpi_accel_glue.{h,cpp}     Puente DPI-C hacia la lógica de Basic_cpu-main
│   ├── golden/golden_dump.cpp         Generador offline del modelo dorado (SystemC)
│   ├── vectors/                       input_crop.rgb + los dos volcados dorados
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

`dpi_accel_glue.h`/`.cpp` — tres funciones `extern "C"`, cada una copia literal de la
lógica ya verificada en `Basic_cpu-main`:

| Función DPI | Copia de |
|---|---|
| `dpi_rgb_to_gray` | `Accelerator::rgb_a_gris` (BT.601 entero) |
| `dpi_load_file` | Carga de archivo en el constructor de `Storage` |
| `dpi_save_output` | Rama de escritura de `Storage::b_transport` |

### 4.4 `verilog_uvm/golden/` — modelo dorado

`golden_dump.cpp` incluye sin modificar los headers de `Basic_cpu-main`
(`accelerator.h`, `bus.h`, `common.h`, `cpu.h`, `ram.h`, `storage.h`), instancia los
mismos 5 módulos que `Basic_cpu-main/main.cpp`, corre `sc_start()` y vuelca
`Ram::data` en las regiones de entrada/salida a `golden_ram_in_region.bin` /
`golden_ram_out_region.bin`. Detalle y resultado en
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
                                                     contra golden_ram_*.bin
```

Versión narrada y con más detalle en [`verilog_uvm/README.md`](verilog_uvm/README.md#arquitectura).

---

## 6. Diagrama de secuencias

```
 rgb2gray_uvm_test      env.agent (UVM)        axi_ram (DUT)      cpu_accel_bfm      scoreboard
        |                     |                     |                    |               |
        |--write_image_seq--->|---AXI4 W (AW/W/B)-->|                    |               |
        |   (input_crop.rgb)  |                     |  (guarda en mem)   |               |
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
        |--verificar_bloque(golden_ram_in_region.bin, ...)------------------------------->|
        |--verificar_bloque(golden_ram_out_region.bin, ...)------------------------------>|
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
| `golden_ram_in_region.bin` (volcado de `Ram::data` en `INPUT_BASE`) vs. `input_crop.rgb` (vector de HLS) | ✅ Idénticos byte a byte |
| `golden_ram_out_region.bin` (volcado de `Ram::data` en `OUTPUT_BASE`) vs. `ref_crop.raw` (referencia de HLS) | ✅ Idénticos byte a byte |

Esto confirma, con **tres implementaciones independientes** (TLM/SystemC de
`Basic_cpu-main`, HLS y el volcado dorado de EC4), que el mapa de memoria, el recorte de
8192 píxeles y la fórmula BT.601 concuerdan exactamente. Ver el detalle en
[`verilog_uvm/golden/README.md`](verilog_uvm/golden/README.md).

### 9.2 Corrida del testbench UVM

Pendiente de ejecutarse en un simulador SystemVerilog real (no hay licencia local de
VCS/Xcelium/Questa en este entorno). El código se escribió siguiendo IEEE 1800/UVM 1.2
estándar y se revisó manualmente, pero **no ha sido compilado ni simulado todavía**. La
primera corrida real se hará en EDA Playground siguiendo la Sec. 2.1; si el `scoreboard`
reporta `UVM_FATAL`, esta sección se actualizará con la traza y la corrección aplicada.

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
Se utilizó la herramienta de github copilot para el planeamiento de como desarrollar esta tarea, desarrollo de secciones de codigo, desarrollo de scripts, creacion de parte de la documentacion, depuracion y analisos de codigo.
