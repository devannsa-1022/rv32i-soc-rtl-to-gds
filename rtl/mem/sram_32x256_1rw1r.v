`timescale 1ns/1ps

// 256 x 32-bit SRAM with one read/write port and one read-only port.
//
// With USE_SRAM_MACRO defined (the ASIC flow) this is a thin wrapper around
// the OpenRAM sky130_sram_1kbyte_1rw1r_32x256_8 hard macro. Otherwise it is a
// behavioral model with the same ports and cycle-level timing:
//   - csb (chip select) and web (write enable) are active-low
//   - address/control are sampled on the rising clock edge
//   - read data is valid during the following cycle only. The macro drives
//     dout to X after every rising edge and reloads it only on a read, so
//     the model returns X on any cycle whose edge was not a read; users
//     must not rely on dout holding its value.
//   - wmask0 enables writes per byte lane
// It deliberately has no parameters (the macro has none), so synthesis sees a
// single module name it can black-box or swap for the macro.
module sram_32x256_1rw1r (
    // Port 0: read/write
    input         clk0,
    input         csb0,
    input         web0,
    input  [3:0]  wmask0,
    input  [7:0]  addr0,
    input  [31:0] din0,
    output [31:0] dout0,

    // Port 1: read-only
    input         clk1,
    input         csb1,
    input  [7:0]  addr1,
    output [31:0] dout1
);

`ifdef USE_SRAM_MACRO

    // Power pins (vccd1/vssd1) are connected by the power-grid step.
    sky130_sram_1kbyte_1rw1r_32x256_8 macro (
        .clk0(clk0), .csb0(csb0), .web0(web0), .wmask0(wmask0),
        .addr0(addr0), .din0(din0), .dout0(dout0),
        .clk1(clk1), .csb1(csb1), .addr1(addr1), .dout1(dout1)
    );

`else

    reg [31:0] mem [0:255];
    reg [31:0] dout0_r, dout1_r;

    assign dout0 = dout0_r;
    assign dout1 = dout1_r;

    always @(posedge clk0) begin
        dout0_r <= 32'bx;
        if (!csb0) begin
            if (!web0) begin
                if (wmask0[0]) mem[addr0][7:0]   <= din0[7:0];
                if (wmask0[1]) mem[addr0][15:8]  <= din0[15:8];
                if (wmask0[2]) mem[addr0][23:16] <= din0[23:16];
                if (wmask0[3]) mem[addr0][31:24] <= din0[31:24];
            end else begin
                dout0_r <= mem[addr0];
            end
        end
    end

    always @(posedge clk1) begin
        dout1_r <= csb1 ? 32'bx : mem[addr1];
    end

`endif

endmodule
