`timescale 1ns/1ps

module rv32i_core_synth_top (
    input  clk,
    input reset,

    // External memory interface
    output [31:0] mem_addr,
    output [31:0] mem_wdata,
    output [3:0]  mem_wstrb,
    output        mem_we,
    output        mem_re,

    // Observable CPU state
    output [31:0] debug_pc,
    output [31:0] debug_alu_result,
    output [31:0] debug_wb_data,
    output [4:0]  debug_wb_rd,
    output        debug_wb_we
);

    wire [31:0] mem_rdata;
    wire        mem_ready;

    // ------------------------------------------------------------
    // Synthesis-only memory response
    // ------------------------------------------------------------
    assign mem_rdata = 32'h00000000;
    assign mem_ready = 1'b1;

    // ------------------------------------------------------------
    // RV32I core
    // ------------------------------------------------------------
    rv32i_core core0 (
        .clk(clk),
        .reset(reset),

        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),

        .mem_we(mem_we),
        .mem_re(mem_re),

        .mem_rdata(mem_rdata),
        .mem_ready(mem_ready)
    );

    // ------------------------------------------------------------
    // Make important datapath/state signals observable
    // ------------------------------------------------------------
    assign debug_pc         = core0.pc_out;
    assign debug_alu_result = core0.alu_result;
    assign debug_wb_data    = core0.wb_data;
    assign debug_wb_rd      = core0.memwb_rd;
    assign debug_wb_we      = core0.memwb_werf;

endmodule