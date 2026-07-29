# filelist.f
# Orden de compilación para simuladores que se invocan desde línea de
# comandos (VCS, Xcelium, Questa). En EDA Playground no se usa este archivo:
# ahí basta con arrastrar los archivos a "Design"/"Testbench" (ver
# run_edaplayground.md), EDA Playground los compila en el orden correcto
# automáticamente si uvm_pkg está antes y axi_pkg no se repite.

+incdir+../rtl
+incdir+../tb

../rtl/axi_ram.sv

../tb/axi_if.sv
../tb/bfm_ctrl_if.sv
../tb/axi_pkg.sv
../tb/tb_pkg.sv
../tb/cpu_accel_bfm.sv
../tb/tb_top.sv

# nota: axi_sequencer.sv, axi_driver.sv, axi_monitor.sv, axi_agent.sv,
# seq_lib.sv y scoreboard.sv NO se listan aparte: axi_pkg.sv los incluye
# con `include (deben quedar en el mismo directorio, ver +incdir arriba).
# lo mismo para env.sv, base_test.sv y rgb2gray_uvm_test.sv, incluidos
# dentro de tb_pkg.sv.
