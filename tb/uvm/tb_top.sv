// tb_top.sv
`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
import soc_pkg::*;

module tb_top;

  // ---------------- Clock / reset ----------------
  logic clk;
  logic reset;

  initial clk = 0;
  always #5 clk = ~clk;   // placeholder period -- revisit once tied to real Fmax

  initial begin
    reset = 1;
    repeat (3) @(posedge clk);
    @(negedge clk);
    reset = 0;
  end

  // ---------------- Interfaces ----------------
  // soc_io_if connects directly to top-level DUT ports.
  soc_io_if io_if (.clk(clk), .reset(reset));

  // axi_lite_if / core_mem_if wrap INTERNAL DUT nets -- instantiated here so
  // UVM can grab virtual interface handles, but actually driven/sampled via
  // `bind` into the DUT hierarchy (see tb_binds.sv), not direct connection.
  axi_lite_if axi_if  (.clk(clk), .resetn(!reset));
  core_mem_if cmem_if (.clk(clk), .reset(reset));

  // ---------------- DUT ----------------
  // ---------------- Interfaces ----------------
  // axi_lite_if / core_mem_if are NOT instantiated here -- the real,
  // DUT-connected instances are created by the `bind` statements in
  // tb_binds.sv (u_axi_lite_if_bind inside axi_manager, u_core_mem_if_bind
  // inside rv32i_core). We reference those bound instances directly via
  // hierarchical path below. A separate free-standing instantiation here
  // was the original design and was WRONG -- it created a second,
  // unconnected interface instance that monitors were watching instead of
  // the real one. Do not re-add axi_lite_if/core_mem_if instantiations here.

  // ---------------- DUT ----------------
  rv32i_soc dut (
    .clk       (clk),
    .reset     (reset),
    .gpio_out  (io_if.gpio_out),
    .gpio_in   (io_if.gpio_in),
    .timer_irq (io_if.timer_irq),
    .uart_tx   (io_if.uart_tx),
    .uart_rx   (io_if.uart_rx)
  );

  // ---------------- Debug probe (PC + full GPR readback) ----------------
  core_probe_if probe_if (.clk(clk), .reset(reset));

  assign probe_if.pc_out      = dut.core0.pc_out;
  assign probe_if.branch_out  = dut.core0.branch_out;
  assign probe_if.flush_if    = dut.core0.flush_if;
  assign probe_if.stall_front = dut.core0.stall_front;

  genvar gi;
  generate
    for (gi = 0; gi < 32; gi = gi + 1) begin : gpr_probe_gen
      assign probe_if.gpr[gi] = dut.core0.rf0.reg_filex[gi];
    end
  endgenerate

  // ---------------- Hand virtual interfaces to UVM ----------------
  initial begin
    uvm_config_db#(virtual soc_io_if)::set(null, "*", "io_vif", io_if);
    uvm_config_db#(virtual axi_lite_if)::set(null, "*", "axi_vif", dut.axi_mgr0.u_axi_lite_if_bind);
    uvm_config_db#(virtual core_mem_if)::set(null, "*", "cmem_vif", dut.core0.u_core_mem_if_bind);
    uvm_config_db#(virtual core_probe_if)::set(null, "*", "probe_vif", probe_if);
    run_test();
  end
endmodule : tb_top