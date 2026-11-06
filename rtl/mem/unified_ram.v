`timescale 1ns/1ps

// Synchronous, single-port, word-addressable backing memory. Registered
// read (1-cycle latency) -- deliberately BRAM-inferable, unlike the old
// combinational data_memory, since this now sits behind a cache rather
// than being accessed directly every cycle.
module unified_ram #(
    parameter RAM_WORDS = 256
)(
    input clk,
    input  [$clog2(RAM_WORDS)-1:0] addr,
    input  [31:0] wdata,
    input         we,
    output reg [31:0] rdata
);
    reg [31:0] mem [0:RAM_WORDS-1];
    integer i;

    initial begin
        for (i = 0; i < RAM_WORDS; i = i + 1) mem[i] = 32'h0;
    end

    always @(posedge clk) begin
        if (we) mem[addr] <= wdata;
        rdata <= mem[addr];   // registered read
    end
endmodule