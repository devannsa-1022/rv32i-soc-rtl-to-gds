`timescale 1ns/1ps

module instruction_memory (
    input  [31:0] addr,
    output reg [31:0] instr
);

    reg [31:0] mem [0:255];

`ifndef SYNTHESIS

    // ============================================================
    // SIMULATION
    // ============================================================
    integer i;
    reg [8*128-1:0] program_path;   // wide enough for a full path, not just a filename

    initial begin
        // Default all locations to NOP
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 32'h00000013;

        // Load program from simulation file -- path overridable via plusarg
        // so each UVM test can point at its own generated .hex
        if (!$value$plusargs("PROGRAM=%s", program_path))
            program_path = "program_random.hex";

        $readmemh(program_path, mem);
    end

    always @(*) begin
        instr = mem[addr[9:2]];
    end

`else

    // ============================================================
    // SYNTHESIS
    // ============================================================
    // Same instruction stream as program.hex.
    // This prevents the CPU datapath from being optimized away.

    always @(*) begin

        case (addr[9:2])

            8'd0:
                instr = 32'h00500093;

            8'd1:
                instr = 32'h00a00113;

            8'd2:
                instr = 32'h00202023;

            8'd3:
                instr = 32'h00002183;

            8'd4:
                instr = 32'h00118233;

            8'd5:
                instr = 32'h100002b7;

            8'd6:
                instr = 32'h00100313;

            8'd7:
                instr = 32'h0062a023;

            8'd8:
                instr = 32'h02a00393;

            8'd9:
                instr = 32'h0072a223;

            8'd10:
                instr = 32'h10002437;

            8'd11:
                instr = 32'h00500493;

            8'd12:
                instr = 32'h00942223;

            8'd13:
                instr = 32'h00100513;

            8'd14:
                instr = 32'h00a42423;

            8'd15:
                instr = 32'h0042a583;

            8'd16:
                instr = 32'h10001637;

            8'd17:
                instr = 32'h04100693;

            8'd18:
                instr = 32'h00d62023;

            8'd19:
                instr = 32'h00862783;

            8'd20:
                instr = 32'h0027f813;

            8'd21:
                instr = 32'hfe080ce3;

            8'd22:
                instr = 32'h00462883;

            8'd23:
                instr = 32'h01000993;

            8'd24:
                instr = 32'h0ab00a13;

            8'd25:
                instr = 32'h01498023;

            8'd26:
                instr = 32'h02a00a93;

            8'd27:
                instr = 32'h015980a3;

            8'd28:
                instr = 32'h00098b03;

            8'd29:
                instr = 32'h0009cb83;

            8'd30:
                instr = 32'h00198c03;

            8'd31:
                instr = 32'h00008cb7;

            8'd32:
                instr = 32'h055c8c93;

            8'd33:
                instr = 32'h01999223;

            8'd34:
                instr = 32'h00499d03;

            8'd35:
                instr = 32'h0049dd83;

            8'd36:
                instr = 32'h00000063;

            // Default = NOP
            default:
                instr = 32'h00000013;

        endcase

    end

`endif

endmodule