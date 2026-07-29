# EC4 — RAM en Verilog + UVM + DPI (verificación)

Integra el módulo de RAM del sistema TLM de [`Basic_cpu-main/`](../Basic_cpu-main/)
como un esclavo AXI4 Full en SystemVerilog, verificado con UVM, y conecta la
lógica de CPU/acelerador de esa misma evaluación por DPI-C. Ver el planeamiento
completo en [`verificacion_copilot.md`](../verificacion_copilot.md).

No depende de gem5 ni de un kernel SystemC vivo: pensado para correr en
**EDA Playground** (ver [`scripts/run_edaplayground.md`](scripts/run_edaplayground.md)).

## Organización

```
verilog_uvm/
├── rtl/axi_ram.sv            DUT: RAM esclava AXI4 Full, backing disperso
├── tb/                       Testbench SystemVerilog + UVM
│   ├── axi_if.sv             Interfaz AXI4 (modports master/slave/monitor)
│   ├── bfm_ctrl_if.sv        Handshake start/done entre el test y el bfm
│   ├── axi_pkg.sv            VIP AXI4 (paquete): parámetros, axi_txn, e incluye:
│   │   ├── axi_sequencer.sv
│   │   ├── axi_driver.sv     Traduce axi_txn a rafagas AXI4 reales
│   │   ├── axi_monitor.sv    Observador pasivo (logging)
│   │   ├── axi_agent.sv
│   │   ├── seq_lib.sv        write_image_seq / read_check_seq
│   │   └── scoreboard.sv     Compara contra el modelo dorado
│   ├── tb_pkg.sv             Entorno + tests (paquete), incluye:
│   │   ├── env.sv
│   │   ├── base_test.sv
│   │   └── rgb2gray_uvm_test.sv
│   ├── cpu_accel_bfm.sv      "CPU + acelerador": maestro AXI4 + DPI
│   └── tb_top.sv             Reloj/reset, mux de bus, instancias, run_test()
├── dpi/dpi_accel_glue.{h,cpp} extern "C": rgb_a_gris, carga/guarda archivo
├── golden/golden_dump.cpp    Genera el modelo dorado (offline, ver su README)
├── vectors/                  input_crop.rgb + los dos volcados dorados
└── scripts/                  filelist.f, build_dpi.sh, run_*.sh, run_edaplayground.md
```

## Arquitectura

Un solo puerto AXI4 esclavo (`axi_ram`), compartido en el tiempo por dos
maestros que nunca están activos a la vez (sin árbitro; el orden de fases del
test lo garantiza):

```
        ┌───────────────────────────────────────────────────┐
        │                  tb_top (mux estático)             │
        │                                                     │
 UVM agent ──AXI4──►┌──────────┐◄──AXI4──── cpu_accel_bfm     │
 (write/read_check) │ axi_ram  │            (DPI: rgb_a_gris, │
                     │  (DUT)   │             guardar archivo) │
        └───────────►└──────────┘◄───────────────────────────┘
              scoreboard compara contra golden_ram_*_region.bin
              (volcado offline de Ram::data en Basic_cpu-main)
```

## Flujo (dado por el enunciado)

1. **Carga**: el agente UVM (`write_image_seq`) escribe `input_crop.rgb` en
   `INPUT_BASE` (= `map::DIR_IMG_IN`) por AXI4.
2. **Cómputo**: se cede el bus a `cpu_accel_bfm`, que lee `INPUT_BASE`,
   convierte a gris por DPI (`dpi_rgb_to_gray`, copia literal de
   `Accelerator::rgb_a_gris`) y escribe el resultado en `OUTPUT_BASE`
   (= `map::DIR_IMG_OUT`).
3. **Persistencia**: `cpu_accel_bfm` relee `OUTPUT_BASE` y llama a
   `dpi_save_output` para escribir `output_crop_gray.raw` (almacenamiento
   permanente), igual que `Storage::b_transport` en modo escritura.
4. **Verificación**: el agente UVM relee `INPUT_BASE` y `OUTPUT_BASE`; el
   `scoreboard` compara byte a byte contra `golden_ram_in_region.bin` /
   `golden_ram_out_region.bin` (volcado de la RAM real de `Basic_cpu-main`,
   ver [`golden/README.md`](golden/README.md)) y emite `UVM_ERROR`/`UVM_FATAL`
   si algo no coincide.

## Mapa de memoria

Igual al de [`Basic_cpu-main/include/common.h`](../Basic_cpu-main/include/common.h):

| Símbolo | Valor |
|---|---|
| `INPUT_BASE` (`map::DIR_IMG_IN`) | `0x0000_0000` |
| `OUTPUT_BASE` (`map::DIR_IMG_OUT`) | `0x0080_0000` |
| Ancho de datos AXI | 32 bits (`STRB_WIDTH` = 4) |
| Tamaño de RAM representado | 64 MiB (backing disperso, solo se reservan las posiciones escritas) |
| Recorte de prueba | 8192 píxeles (24 576 B RGB / 8192 B gris), igual a `hls/tb/vectors/input_crop.rgb` |

## Cómo correr

- **EDA Playground (recomendado, sin instalación)**: ver
  [`scripts/run_edaplayground.md`](scripts/run_edaplayground.md).
- **Simulador local con licencia** (VCS/Xcelium/Questa): ver
  `scripts/run_vcs.sh`, `scripts/run_xcelium.sh`, `scripts/run_questa.sh`
  (usan `scripts/filelist.f` y `scripts/build_dpi.sh`).

## Alcance y decisiones registradas

- El registro de control del acelerador (`CTRL/STATUS/START/DONE`) se modela
  como estado interno de `cpu_accel_bfm`, no como una segunda ventana AXI4:
  lo que EC4 pide verificar con UVM/AXI4 es la RAM, no el bus de control.
- No se corre un kernel SystemC vivo co-simulado con el kernel SV (requeriría
  soporte de co-simulación no garantizado en EDA Playground); en cambio, la
  lógica ya verificada de `Basic_cpu-main` se reutiliza dos veces sin
  modificarla: como cuerpo literal de las funciones DPI, y como generador
  offline del modelo dorado (`golden_dump.cpp`).
- `Basic_cpu-main/` y la evaluación de HLS/gem5 no se modifican en absoluto.

## Declaración de uso de IA

Este módulo (RTL, UVM, DPI, modelo dorado, scripts y esta documentación) se
diseñó e implementó con asistencia de GitHub Copilot (agente en VS Code),
a partir del enunciado de la evaluación y del análisis del código ya existente
en el repositorio (`Basic_cpu-main/`, `hls/`, `virtual_prototype/`). El
planeamiento previo a la implementación está documentado en
[`verificacion_copilot.md`](../verificacion_copilot.md).
