// bfm_ctrl_if.sv
// Interfaz de control minima entre el test (UVM) y el cpu_accel_bfm (SV puro).
// "start" lo pone en 1 el test cuando ya cargo la imagen de entrada en la RAM;
// "start" lo baja el test al terminar cada fase; "done" lo pone en 1 el bfm
// cuando ya escribio la salida en la RAM y la persistio a disco por DPI.

interface bfm_ctrl_if;
  bit start;
  bit done;
endinterface
