module id_ex_pip_reg(
    input clk, reset, stall, bubble,
    input [31:0] pc_4_in,
    input [31:0] rs1_data_in, rs2_data_in, imm_in,
    input [4:0]  rs1_in, rs2_in, rd_in,
    input [2:0]  funct3_in,
    input [3:0]  aluop_in,
    input        werf_in,
    input [1:0]  wbmux_in,
    input        i_type_load_in,
    input [2:0]  op_format_in,

    output reg [31:0] pc_4_out,
    output reg [31:0] rs1_data_out, rs2_data_out, imm_out,
    output reg [4:0]  rs1_out, rs2_out, rd_out,
    output reg [2:0]  funct3_out,
    output reg [3:0]  aluop_out,
    output reg        werf_out,
    output reg [1:0]  wbmux_out,
    output reg        i_type_load_out,
    output reg [2:0]  op_format_out
);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        pc_4_out        <= 0;
        rs1_data_out    <= 0;
        rs2_data_out    <= 0;
        imm_out         <= 0;
        rs1_out         <= 0;
        rs2_out         <= 0;
        rd_out          <= 0;
        funct3_out      <= 0;
        aluop_out       <= 0;
        werf_out        <= 0;
        wbmux_out       <= 0;
        i_type_load_out <= 0;
        op_format_out   <= 0;
    end else if (stall) begin
        // FIXED: stall now checked BEFORE bubble. A stall means nothing
        // may advance or change this cycle -- including a bubble meant
        // to squash a hazardous instruction that hasn't issued yet.
        // Without this, a memory stall occurring on the exact same cycle
        // a load-use hazard is detected would wipe the load's own
        // already-latched identity (rd/i_type_load) via the bubble path,
        // instead of holding it, permanently losing track of the
        // in-flight load.
    end else if (bubble) begin
        werf_out        <= 0;
        i_type_load_out <= 0;
        wbmux_out       <= 0;
        op_format_out   <= 0;
        rd_out          <= 0;
    end else begin
        pc_4_out        <= pc_4_in;
        rs1_data_out    <= rs1_data_in;
        rs2_data_out    <= rs2_data_in;
        imm_out         <= imm_in;
        rs1_out         <= rs1_in;
        rs2_out         <= rs2_in;
        rd_out          <= rd_in;
        funct3_out      <= funct3_in;
        aluop_out       <= aluop_in;
        werf_out        <= werf_in;
        wbmux_out       <= wbmux_in;
        i_type_load_out <= i_type_load_in;
        op_format_out   <= op_format_in;
    end
end
endmodule