`timescale 1ns/1ps

// Data memory: 256 words in a 1rw1r SRAM (port 0 only). Reads are
// synchronous: the address presented with mem_read is sampled on the clock
// edge and read_data is valid the following cycle, holding until the next
// access. axi_lite_to_simple_bus keeps the read address stable from R_ACCESS
// into R_RESP and samples read_data in R_RESP, which matches this timing.
module data_memory (
    input         clk,
    input  [31:0] addr,
    input  [31:0] write_data,
    input  [3:0]  wstrb,
    input         mem_read,
    input         mem_write,
    output [31:0] read_data
);

    sram_32x256_1rw1r sram0 (
        .clk0(clk), .csb0(~(mem_read | mem_write)), .web0(~mem_write), .wmask0(wstrb),
        .addr0(addr[9:2]), .din0(write_data), .dout0(read_data),

        .clk1(clk), .csb1(1'b1), .addr1(8'h00), .dout1()
    );

`ifndef SYNTHESIS
    // Zero-fill so programs that load before storing see 0 rather than X.
    // A real SRAM powers up undefined.
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) sram0.mem[i] = 32'h0;
    end
`endif

endmodule
