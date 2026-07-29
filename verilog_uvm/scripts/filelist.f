# filelist.f
# Orden de compilación para simuladores que se invocan desde línea de
# comandos (VCS, Xcelium, Questa). En EDA Playground no se usa este archivo
# (ver run_edaplayground.md).
#
# tb_top.sv se incluye a si mismo (via `include) axi_if.sv, bfm_ctrl_if.sv,
# axi_pkg.sv, tb_pkg.sv y cpu_accel_bfm.sv, en ese orden -- por eso NO se
# listan aparte aqui: listarlos tambien como archivos de diseño duplicaria
# la compilacion de sus paquetes/modulos.

+incdir+../rtl
+incdir+../tb

../rtl/axi_ram.sv

../tb/tb_top.sv

# nota: axi_if.sv, bfm_ctrl_if.sv, axi_pkg.sv, tb_pkg.sv, cpu_accel_bfm.sv,
# y a su vez axi_sequencer.sv, axi_driver.sv, axi_monitor.sv, axi_agent.sv,
# seq_lib.sv, scoreboard.sv, env.sv, base_test.sv, rgb2gray_uvm_test.sv,
# se resuelven todos por `include (ver +incdir arriba). Deben existir en
# ../tb/ pero no se pasan como fuentes separadas al simulador.
