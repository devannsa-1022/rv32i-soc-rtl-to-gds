`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.09.2026 18:12:22
// Design Name: 
// Module Name: ALU
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "Def.v"
module ALU(operand_1, operand_2, aluop, out);
input   [31:0]  operand_1, operand_2;
input   [3:0]   aluop;
output reg [31:0] out;

// Internal signals
wire    [31:0]  add_res, sub_res, xor_res, or_res, and_res, sll_res, srl_res, sra_res;
wire            slt_res, sltu_res;

assign add_res = operand_1 + operand_2;
assign sub_res = operand_1 - operand_2;
assign xor_res = operand_1 ^ operand_2;
assign or_res  = operand_1 | operand_2;
assign and_res = operand_1 & operand_2;
assign sll_res = operand_1 << operand_2[4:0];
assign srl_res = operand_1 >> operand_2[4:0];
assign sra_res = $signed(operand_1) >>> operand_2[4:0];  // true arithmetic shift
assign slt_res  = ($signed(operand_1) < $signed(operand_2));  // signed comparison
assign sltu_res = (operand_1 < operand_2);                    // unsigned comparison

// ALU output - uses Def.v's ALU_* macros, not a local redefinition
always @(*) begin
    case(aluop)
        `ALU_ADD:  out = add_res;
        `ALU_SUB:  out = sub_res;
        `ALU_SLL:  out = sll_res;
        `ALU_SLT:  out = {31'b0, slt_res};
        `ALU_SLTU: out = {31'b0, sltu_res};
        `ALU_XOR:  out = xor_res;
        `ALU_SRL:  out = srl_res;
        `ALU_SRA:  out = sra_res;
        `ALU_OR:   out = or_res;
        `ALU_AND:  out = and_res;
        default:   out = 32'h0000_0000;
    endcase
end
endmodule