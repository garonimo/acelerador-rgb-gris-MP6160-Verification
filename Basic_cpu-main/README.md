## Imagen RGB a grises

## Requisitos

```bash
sudo apt-get install -y libsystemc-dev g++ cmake
```

## Compilar

```bash
mkdir -p build
cd build
cmake ..
make
cd ..
```

## Correr

```bash
./build/img_accel_tlm
```


## Limpiar

```bash
rm -rf build
```



## Organización del repositorio

```
Basic_cpu/
├── CMakeLists.txt                     # Configuración de build (proyecto: ImageAccelTLM)
├── README.md
├── main.cpp                           # Punto de entrada: instancia y conecta los módulos
├── include/
│   ├── common.h                       # Constantes globales: mapa de memoria y parámetros de imagen
│   ├── storage.h                      # Almacenamiento persistente (periférico TLM en el bus)
│   ├── ram.h                          # RAM de 64 MB (target TLM)
│   ├── bus.h                          # Bus TLM: decodificación de direcciones y enrutamiento
│   ├── accelerator.h                  # Acelerador RGB → escala de grises (dos procesos SystemC)
│   └── cpu.h                          # CPU: orquesta el flujo completo de 7 pasos
└── images/
    ├── input/
    │   └── input_1080p.rgb            # Imagen RAW RGB de entrada (6 220 800 bytes)
    └── output/
        └── output_1080p_gray.raw      # Imagen en escala de grises generada (2 073 600 bytes)
```

---

## Organización de los módulos

El sistema está compuesto por cinco módulos SystemC: 1. CPU, 2.BUs, 3. RAM, 4. Acelerador, 5. Almacenamiento.

### `common.h` — Constantes 

No contiene módulos, solo constantes `constexpr` agrupadas en cuatro namespaces:

| Namespace | Contenido |
|---|---|
| `img` | Dimensiones de imagen: `ANCHO`, `ALTO`, `BYTES_RGB`, `BYTES_GRIS`, `PIXEL_TOTAL` |
| `map` | Rangos de direcciones globales para RAM, Acelerador y Storage |
| `acc_reg` | Offsets de registros del Acelerador: `DIR_IN`, `DIR_OUT`, `NUM_PIXELS`, `CTRL`, `STATUS` |
| `stg_slot` | Offsets dentro de la ventana de disco: `OFFSET_IN`, `OFFSET_OUT` |

### `storage.h` — Almacenamiento Persistente 

Modela el disco como un periférico mapeado en el bus bajo la dirección `0x20000000`. 
La imagen de entrada se carga en un buffer interno durante el constructor. 
En `b_transport()`:  un `READ` copia del buffer al payload; un `WRITE` envía el payload al disco con `std::ofstream`.

### `ram.h` — Ram

RAM de 64 MB implementada con `std::vector<unsigned char>` reservado en el heap. 
El método `b_transport()` ejecuta `std::memcpy` entre el vector interno y el puntero del payload, verificando que la dirección no exceda el tamaño disponible.

### `bus.h` — Bus

**Entrada:** `cpu_target`, `acc_target`  
**Salida:** `ram_init`, `acc_cfg_init`, `stg_init`

El método `decode()` recibe la dirección global, determina el socket de salida correcto y calcula la dirección local. 
El método `b_transport()` fija la dirección local, reenvía la transacción, y restaura la dirección global al retornar.

### `accelerator.h` — Acelerador

Contiene dos procesos SystemC comunicados por un `sc_event`:

- **`cfg_b_transport()`**: atiende escrituras del CPU. Al detectar `START_BIT` en `CTRL`, llama `senal_inicio.notify(SC_ZERO_TIME)` y retorna inmediatamente.
- **`proceso()` (SC_THREAD)**: duerme en `wait(senal_inicio)`. Al despertar, lee la imagen RGB de la RAM, ejecuta `rgb_a_gris()`, escribe el resultado en RAM y pone `listo = true`.

### `cpu.h` — CPU

Orquesta los 7 pasos del pipeline. Expone tres helpers: `enviar_transaccion()` (arma el payload TLM completo), `escribir_registro()` (escribe un `uint32_t` al Acelerador) y `leer_registro()` (lee un `uint32_t`). 
El polling del registro `STATUS` usa `wait(sc_core::SC_ZERO_TIME)` para ceder el turno al SC_THREAD del Acelerador.

---

## Diagrama de bloques

```
  ┌─────────────────────────────────────────────────────────────────┐
  │                         Bus TLM-2.0                             │
  │                                                                 │
  │   decode(dirección global)                                      │
  │   ├─ [0x00000000 – 0x03FFFFFF]  ──────────────► ram_init       │
  │   ├─ [0x10000000 – 0x100000FF]  ──────────────► acc_cfg_init   │
  │   └─ [0x20000000 – 0x2FFFFFFF]  ──────────────► stg_init       │
  │                                                                 │
  └───────┬──────────────────────┬──────────────────┬──────────────┘
          │                      │                  │
          ▼                      ▼                  ▼
   ┌────────────┐        ┌──────────────┐    ┌───────────┐
   │  RAM 64MB  │        │  Acelerador  │    │  Storage  │
   │   ram.h    │        │accelerator.h │    │ storage.h │
   └────────────┘        └──────┬───────┘    └───────────┘
          ▲                     │ sc_event
          │              ┌──────▼────────┐
          └──────────────│  proceso()    │
          DMA read/write │  SC_THREAD    │
                         │  rgb_a_gris() │
                         └───────────────┘

  Initiators:
  ┌──────────┐  cpu_target    ┌─────┐
  │   CPU    │ ─────────────► │ Bus │
  │  cpu.h   │                └─────┘
  └──────────┘
  ┌──────────────┐  acc_target
  │ Acelerador   │ ─────────► Bus (acceso DMA a RAM)
  │ dma_socket   │
  └──────────────┘
```

---

## Diagrama de secuencias

```
CPU                Bus           Storage          RAM          Accelerator
 │                  │               │              │                │
 │ [Storage carga imagen en constructor]           │                │
 │                  │    ifstream ──►disco          │                │
 │                  │               │              │                │
 │ ══ sc_start(): flujo_principal() arranca ══════════════════════ │
 │                  │               │              │                │
 │─ Paso 1: READ 0x20000000 ───────►│              │                │
 │                  │──READ────────►│              │                │
 │                  │◄─6 220 800 B──│              │                │
 │◄─────────────────│               │              │                │
 │                  │               │              │                │
 │─ Paso 2: WRITE 0x00000000 ───────────────────►│                │
 │                  │──WRITE──────────────────────►│                │
 │◄─ OK ────────────│               │              │                │
 │                  │               │              │                │
 │─ Paso 3: WRITE registros DIR_IN, DIR_OUT, NUM_PIXELS ──────────►│
 │                  │──WRITE 0x10000000 ───────────────────────────►│
 │                  │──WRITE 0x10000004 ───────────────────────────►│
 │                  │──WRITE 0x10000008 ───────────────────────────►│
 │                  │               │              │                │
 │─ Paso 4: WRITE 0x1000000C (START_BIT) ─────────────────────────►│
 │                  │──WRITE CTRL ────────────────────────────────►│
 │◄─ OK ────────────│               │    senal_inicio.notify()     │
 │                  │               │              │                │
 │─ Paso 5: polling STATUS ─────────────────────────────────────── │
 │  ┌─────────────────────────────────────────────┐  ┌────────────┐│
 │  │ loop {                                      │  │proceso()   ││
 │  │   wait(SC_ZERO_TIME)  ← cede turno ─────────┼─►│despierta   ││
 │  │   READ 0x10000010 ──────────────────────────┼─►│READ RAM    ││
 │  │                                             │  │rgb_a_gris()││
 │  │                 ◄── STATUS = 0 (ocupado) ───┼──│WRITE RAM   ││
 │  │   wait(SC_ZERO_TIME)                        │  │listo=true  ││
 │  │   READ 0x10000010 ──────────────────────────┼─►│            ││
 │  │                 ◄── STATUS = DONE_BIT ───────┘  └────────────┘│
 │  └─────────────────────────────────────────────┘                │
 │                  │               │              │                │
 │─ Paso 6: READ 0x00800000 (imagen gris de RAM) ─────────────────  │
 │                  │──READ───────────────────────►│                │
 │◄─ 2 073 600 B ───│               │              │                │
 │                  │               │              │                │
 │─ Paso 7: WRITE 0x28000000 (guardar en disco) ──────────────────  │
 │                  │──WRITE──────►│               │                │
 │                  │              │──ofstream──►disco              │
 │◄─ OK ────────────│              │               │                │
 │                  │               │              │                │
 │ sc_stop()        │               │              │                │
```

---

## Formato de las transacciones

Todas las transacciones usan `tlm::tlm_generic_payload`. 
La tabla muestra los campos que se configuran en `enviar_transaccion()` (CPU) y su equivalente en el Acelerador:

| Campo del payload | Valor fijado | Descripción |
|---|---|---|
| `command` | `TLM_READ_COMMAND` / `TLM_WRITE_COMMAND` | Tipo de operación |
| `address` | Dirección global (ver mapa) | El Bus la traduce a local antes de reenviar y la restaura al retornar |
| `data_ptr` | Puntero al buffer | Buffer origen (WRITE) o destino (READ) |
| `data_length` | Variable (ver tabla abajo) | Bytes de la transferencia |
| `streaming_width` | Igual a `data_length` | Sin streaming; cada transacción es atómica |
| `byte_enable_ptr` | `nullptr` | No se usan byte enables |
| `dmi_allowed` | `false` | DMI deshabilitado |
| `response_status` | `TLM_INCOMPLETE_RESPONSE` (inicial) | El destino lo cambia a `TLM_OK_RESPONSE` o `TLM_ADDRESS_ERROR_RESPONSE` |

### Transacciones por paso del pipeline

| Paso | Iniciador | Cmd | Dirección global | Bytes |
|---|---|---|---|---|
| 1 — leer imagen de disco | CPU | READ | `0x20000000` | 6 220 800 |
| 2 — copiar imagen a RAM | CPU | WRITE | `0x00000000` | 6 220 800 |
| 3 — escribir `DIR_IN` | CPU | WRITE | `0x10000000` | 4 |
| 3 — escribir `DIR_OUT` | CPU | WRITE | `0x10000004` | 4 |
| 3 — escribir `NUM_PIXELS` | CPU | WRITE | `0x10000008` | 4 |
| 4 — escribir `CTRL` (START) | CPU | WRITE | `0x1000000C` | 4 |
| 5 — leer `STATUS` (polling) | CPU | READ | `0x10000010` | 4 |
| 5 — leer imagen RGB (DMA) | Acelerador | READ | `0x00000000` | 6 220 800 |
| 5 — escribir imagen gris (DMA) | Acelerador | WRITE | `0x00800000` | 2 073 600 |
| 6 — leer imagen gris de RAM | CPU | READ | `0x00800000` | 2 073 600 |
| 7 — guardar imagen en disco | CPU | WRITE | `0x28000000` | 2 073 600 |

---

## Mapa de memoria

### Vista global del bus

| Rango | Tamaño | Periférico | Descripción |
|---|---|---|---|
| `0x00000000` – `0x03FFFFFF` | 64 MB | `Ram` | Memoria principal |
| `0x10000000` – `0x100000FF` | 256 B | `Accelerator` | Registros de configuración |
| `0x20000000` – `0x2FFFFFFF` | 256 MB | `Storage` | Ventana de disco |

### Región RAM (direcciones locales)

| Dirección local | Tamaño | Contenido |
|---|---|---|
| `0x00000000` | 6 220 800 B | Imagen de entrada RGB (1920 × 1080 × 3 bytes/pixel) |
| `0x00800000` | 2 073 600 B | Imagen de salida en escala de grises (1920 × 1080 × 1 byte/pixel) |
| `0x00C00000` – `0x03FFFFFF` | ~57 MB | Sin asignar |

### Ventana de Storage (direcciones locales)

| Offset local | Dirección global | Descripción |
|---|---|---|
| `0x00000000` | `0x20000000` | Imagen RGB de entrada (lectura) |
| `0x08000000` | `0x28000000` | Imagen gris de salida (escritura) |

---

## Resultados obtenidos

### Salida de la simulación

```
        SystemC 2.3.3-Accellera --- Aug 10 2020 09:07:17
        Copyright (c) 1996-2018 by all Contributors,
        ALL RIGHTS RESERVED

entrada : images/input/input_1080p.rgb
salida  : images/output/output_1080p_gray.raw

Info: STORAGE: imagen cargada: images/input/input_1080p.rgb
Iniciando proceso de conversion...
Imagen cargada desde disco
Imagen RGB copiada a RAM
Acelerador programado
Acelerador iniciado, esperando...
Acelerador termino
Imagen en grises leida desde RAM
Info: STORAGE: imagen guardada: images/output/output_1080p_gray.raw
Imagen en grises guardada en disco
Conversion finalizada!

Info: /OSCI/SystemC: Simulation stopped by user.
Simulacion finalizada
```

### Métricas

| Métrica | Valor |
|---|---|
| Resolución | 1920 × 1080 píxeles (Full HD) |
| Tamaño imagen de entrada (RGB) | 6 220 800 bytes |
| Tamaño imagen de salida (gris) | 2 073 600 bytes |
| Reducción de tamaño | 3× |
| Fórmula de conversión | `Y = (77·R + 150·G + 29·B) >> 8` |
| Estándar de referencia | ITU-R BT.601 (aproximación entera) |
| Verificación de correctitud | 0 errores en 1000 píxeles muestreados aleatoriamente |


### Imágenes de entrada y salida

| | Descripción |
|---|---|
| **Entrada** | Imagen RAW RGB 1080p — 3 bytes por píxel, sin cabecera |
| **Salida** | Imagen RAW en escala de grises — 1 byte por píxel, sin cabecera |

## Declaración de uso de Inteligencia Artificial
 
Se declara que durante la elaboración de este README se utilizó **Claude (Anthropic), modelo Claude Sonnet 4.6**, vía claude.ai, para los siguientes propósitos:
 
- **Generación de diagramas:** los diagramas de bloques y de secuencias en formato ASCII fueron generados con asistencia de Claude a partir del código fuente del proyecto.
- **Mejora de redacción:** la estructuración y redacción de las secciones de este README fueron revisadas y mejoradas con asistencia de Claude.
- **Depuracion de codigo:** El código del proyecto fue desarrollado por el equipo y partes con fallas fueron resueltas con IA.
