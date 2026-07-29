# Modelo dorado (`golden_dump.cpp`)

Genera los dos binarios que el `scoreboard` de UVM usa como referencia:
`golden_ram_in_region.bin` y `golden_ram_out_region.bin`. Ya están
convertidos a texto hexadecimal en [`../vectors/`](../vectors/)
(`golden_ram_in_region.hex` / `golden_ram_out_region.hex`, junto con
`input_crop.hex`) — no hace falta regenerarlos salvo que cambie la imagen
de entrada o `Basic_cpu-main`.

## Qué hace

Incluye `Basic_cpu-main/include/*.h` **sin modificarlos**, arma los mismos
5 módulos que [`Basic_cpu-main/main.cpp`](../../Basic_cpu-main/main.cpp)
(`CPU + Bus + Ram + Accelerator + Storage`), corre la simulación completa
con la imagen 1080p real y, cuando `sc_start()` regresa, vuelca a disco los
primeros 8192 píxeles de `ram.data` en `map::DIR_IMG_IN` y `map::DIR_IMG_OUT`
(el mismo recorte que usa el testbench UVM, ver [`hls/tb/vectors/input_crop.rgb`](../../hls/tb/vectors/input_crop.rgb)).

Se corre **offline, una sola vez, en la máquina donde SystemC está
instalado** — nunca en EDA Playground.

## Cómo regenerarlo

```bash
cd verilog_uvm/golden
cmake -S . -B build
cmake --build build -j"$(nproc)"
LD_LIBRARY_PATH="$SYSTEMC_HOME/lib:$LD_LIBRARY_PATH" ./build/golden_dump
cp golden_ram_in_region.bin golden_ram_out_region.bin ../vectors/
rm -f golden_ram_in_region.bin golden_ram_out_region.bin golden_full_output_1080p_gray.raw
```

Requiere `SYSTEMC_HOME` apuntando a una instalación de SystemC (la misma
que usa `Basic_cpu-main/CMakeLists.txt`).

**Después, convertir a hexadecimal** (el testbench UVM carga los vectores
con `$readmemh`, no con el binario original — ver [`../scripts/run_edaplayground.md`](../scripts/run_edaplayground.md)
para la razón: subir binarios a EDA Playground corrompe los bytes no-ASCII):

```bash
cd ../vectors
xxd -p -c1 golden_ram_in_region.bin  > golden_ram_in_region.hex
xxd -p -c1 golden_ram_out_region.bin > golden_ram_out_region.hex
```

## Validación cruzada

Los binarios generados ya se compararon byte a byte contra las referencias
de la evaluación de HLS y coinciden exactamente:

- `golden_ram_in_region.bin` == `hls/tb/vectors/input_crop.rgb`
- `golden_ram_out_region.bin` == `hls/tb/vectors/ref_crop.raw`

Es decir, tres implementaciones independientes (TLM puro, HLS, y ahora el
volcado de `Basic_cpu-main`) producen el mismo resultado bit-exacto para
el mismo recorte de imagen.
