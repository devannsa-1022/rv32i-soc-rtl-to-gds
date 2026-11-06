`include "Def.v"
module branch_unit(funct3_in,opcode_in,source_1,source_2,branch_out,jal_enab,enable);

input [31:0] source_1,source_2;
input [4:0] opcode_in;//after decode stage
input [2:0] funct3_in;
wire [2:0] alu_op;
reg branch;
output branch_out,jal_enab,enable;
wire beq_op,bne_op,blt_op,bge_op,bltu_op,bgeu_op;
wire jal_enable,jalr_enable;
wire signed [31:0] signed_rs1,signed_rs2;

//enable and jal_enable need to be declared outside the module in top level module and given to branch predicting unit

assign enable = ((opcode_in[4]) & (opcode_in[3]) & (~opcode_in[2]) & (~opcode_in[1]) & (~opcode_in[0]));
assign jal_enable = ((opcode_in[4]) & (opcode_in[3]) & (!opcode_in[2]) & (opcode_in[1]) & (opcode_in[0]));
assign jalr_enable = ((opcode_in[4]) & (opcode_in[3]) & (!opcode_in[2]) & (~opcode_in[1]) & (opcode_in[0]));
assign jal_enab = jalr_enable;

assign signed_rs1 	= source_1;
assign signed_rs2 	= source_2;
assign beq_op 		= (source_1 == source_2);
assign bne_op 		= (source_1 != source_2);
// FIXED: was `signed_rs1 < source_2` - mixing a signed operand with an
// unsigned one makes Verilog do the WHOLE comparison unsigned, silently
// discarding the sign. Now compares signed against signed.
assign blt_op 		= (signed_rs1 < signed_rs2);
// FIXED: same bug, was `source_1 >= signed_rs2`.
assign bge_op 		= (signed_rs1 >= signed_rs2);
assign bltu_op 		= (source_1 < source_2);
assign bgeu_op 		= (source_1 >= source_2);

// FIXED: was `alu_op = (enable)? funct3_in : 4'bzzzz;` - 4-bit literal
// assigned to a 3-bit wire, and using z as a case selector is fragile
// under synthesis. Default to a defined value instead; enable now gates
// branch_out directly below.
assign alu_op = (enable)? funct3_in : 3'b000;

always@(*)
begin
branch = 1'b0;
case(alu_op)

	3'b000: branch 	= beq_op;

	3'b001: branch 	= bne_op;

	3'b100: branch 	= blt_op;

	3'b101: branch 	= bge_op;

	3'b110: branch 	= bltu_op;

	3'b111: branch 	= bgeu_op;

	default: branch = 1'b0;

endcase
end

// FIXED: branch_out is now explicitly gated by enable, rather than relying
// on alu_op's disabled-state value happening to fall through to default.
assign branch_out = branch & enable;

endmodule