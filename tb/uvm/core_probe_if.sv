interface core_probe_if (input logic clk, input logic reset);
  logic [31:0] pc_out;
  logic [31:0] gpr [0:31];
  logic        branch_out;
  logic        flush_if;
  logic        stall_front;

  clocking mon_cb @(posedge clk);
    default input #1step;
    input pc_out, branch_out, flush_if, stall_front;
  endclocking

  modport MON (clocking mon_cb, input clk, reset);
endinterface : core_probe_if