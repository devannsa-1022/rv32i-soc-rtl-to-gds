`timescale 1ns/1ps

// Instruction memory: 256 words in a 1rw1r SRAM.
//   - Port 1 (read-only) serves instruction fetch. fetch_addr is the PC the
//     core will hold on the NEXT cycle, so the SRAM's registered output
//     always corresponds to the core's current pc_out.
//   - Port 0 (read/write) is a program-load port driven from the SoC pins,
//     used while the core is held in reset.
// In simulation the image is loaded from +PROGRAM=<file>.hex (default
// program_random.hex). INIT_FILE gives FPGA builds an initial image.
module instruction_memory #(
    parameter INIT_FILE = ""
)(
    input         clk,

    input  [31:0] fetch_addr,
    output [31:0] instr,

    input         load_we,
    input  [7:0]  load_addr,
    input  [31:0] load_data
);

    sram_32x256_1rw1r #(
        .INIT_FILE(INIT_FILE)
    ) sram0 (
        .clk0(clk), .csb0(~load_we), .web0(~load_we), .wmask0(4'hf),
        .addr0(load_addr), .din0(load_data), .dout0(),

        .clk1(clk), .csb1(1'b0), .addr1(fetch_addr[9:2]), .dout1(instr)
    );

`ifndef SYNTHESIS
    integer i;
    reg [8*128-1:0] program_path;   // wide enough for a full path, not just a filename

    initial begin
        // Default all locations to NOP
        for (i = 0; i < 256; i = i + 1)
            sram0.mem[i] = 32'h00000013;

        // Path overridable via plusarg so each UVM test can point at its
        // own generated .hex
        if (!$value$plusargs("PROGRAM=%s", program_path))
            program_path = "program_random.hex";

        $readmemh(program_path, sram0.mem);
    end
`endif

endmodule
