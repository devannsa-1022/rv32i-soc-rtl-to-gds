interface core_mem_if (
  input logic        clk,
  input logic        reset,
  input logic [31:0] mem_addr,
  input logic [31:0] mem_wdata,
  input logic [31:0] mem_rdata,
  input logic [3:0]  mem_wstrb,
  input logic        mem_we,
  input logic        mem_re,
  input logic        mem_ready
);

  clocking mon_cb @(posedge clk);
    default input #1step;
    input mem_addr, mem_wdata, mem_rdata, mem_wstrb, mem_we, mem_re, mem_ready;
  endclocking

  modport MON (clocking mon_cb, input clk, reset);

endinterface : core_mem_if