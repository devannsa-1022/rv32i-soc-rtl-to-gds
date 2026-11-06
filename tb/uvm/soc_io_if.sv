// soc_io_if.sv
// Top-level rv32i_soc I/O. Shared by:
//   - gpio_agent (active): drives gpio_in, monitors gpio_out
//   - uart_agent (active): drives uart_rx, monitors uart_tx
//   - timer_irq: passive-only, no dedicated agent -- sampled here, consumed
//                directly by scoreboard/coverage (Section 7 item 4: pulse
//                width == 1 cycle check).

interface soc_io_if (input logic clk, input logic reset);

  logic [31:0] gpio_out;
  logic [31:0] gpio_in;
  logic        timer_irq;
  logic        uart_tx;
  logic        uart_rx;

  clocking mon_cb @(posedge clk);
    default input #1step;
    input gpio_out, gpio_in, timer_irq, uart_tx, uart_rx;
  endclocking

  // Driver CB for gpio_agent (drives gpio_in only)
  clocking gpio_drv_cb @(posedge clk);
    default input #1step output #1step;
    output gpio_in;
    input  gpio_out;
  endclocking

  // Driver CB for uart_agent (drives uart_rx, observes uart_tx)
  clocking uart_drv_cb @(posedge clk);
    default input #1step output #1step;
    output uart_rx;
    input  uart_tx;
  endclocking

  modport MON      (clocking mon_cb,      input clk, reset);
  modport GPIO_DRV (clocking gpio_drv_cb, input clk, reset);
  modport UART_DRV (clocking uart_drv_cb, input clk, reset);

endinterface : soc_io_if