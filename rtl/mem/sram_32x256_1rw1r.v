`timescale 1ns/1ps

// 256 x 32-bit SRAM with one read/write port and one read-only port.
// Behavioral model whose ports and timing follow the OpenRAM
// sky130_sram_1kbyte_1rw1r_32x256_8 macro, so the hard macro can replace it
// in the ASIC flow without touching the modules that use it:
//   - csb (chip select) and web (write enable) are active-low
//   - address/control are sampled on the rising clock edge; read data is
//     valid the following cycle and holds until the port reads again
//   - wmask0 enables writes per byte lane
// INIT_FILE optionally preloads the array (used by FPGA builds).
module sram_32x256_1rw1r #(
    parameter INIT_FILE = ""
)(
    // Port 0: read/write
    input             clk0,
    input             csb0,
    input             web0,
    input      [3:0]  wmask0,
    input      [7:0]  addr0,
    input      [31:0] din0,
    output reg [31:0] dout0,

    // Port 1: read-only
    input             clk1,
    input             csb1,
    input      [7:0]  addr1,
    output reg [31:0] dout1
);

    reg [31:0] mem [0:255];

    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end

    always @(posedge clk0) begin
        if (!csb0) begin
            if (!web0) begin
                if (wmask0[0]) mem[addr0][7:0]   <= din0[7:0];
                if (wmask0[1]) mem[addr0][15:8]  <= din0[15:8];
                if (wmask0[2]) mem[addr0][23:16] <= din0[23:16];
                if (wmask0[3]) mem[addr0][31:24] <= din0[31:24];
            end else begin
                dout0 <= mem[addr0];
            end
        end
    end

    always @(posedge clk1) begin
        if (!csb1) dout1 <= mem[addr1];
    end

endmodule
