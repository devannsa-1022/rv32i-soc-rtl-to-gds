module decoder(instr_in,bypass_stall,clk,reset,stall,pc_imm_in,pc_4_in,wrong_predict_in,source_reg_1,source_reg_2,dest_reg,opcode_out,funct_3_out,funct_7_out,load_itype,instr_out,pc_imm_out,pc_4_out);

input		[31:0]		instr_in,pc_imm_in,pc_4_in;
input				clk,stall,wrong_predict_in,reset,bypass_stall;
output reg	[4:0]		source_reg_1,source_reg_2,dest_reg;
output reg	[6:0] 		opcode_out;
output reg	[2:0]		funct_3_out;
output reg	[6:0]		funct_7_out;
output reg	[24:0]		instr_out;
reg 		[31:0]		decode_instr,inter_decode,decode_instr_inter;
reg bypass_in;
output load_itype;
output reg [31:0] pc_imm_out,pc_4_out;

assign load_itype	=	(~instr_in[6] & ~instr_in[5] & ~instr_in[4] & ~instr_in[3] & ~instr_in[2] & instr_in[1] & instr_in[0]);

// FIXED: split out. flush_in causes a real bubble (NOP). stall alone
// must HOLD the current decode, not replace it with a NOP.
wire flush_in = (wrong_predict_in | reset);

always@(*)
begin
decode_instr	= 	32'h0000_0013;
case(flush_in)
	1'b1:	begin
		decode_instr_inter	= 	32'h0000_0013;
		end
	1'b0:	begin
		decode_instr_inter 	= 	instr_in;
		end
	default:decode_instr_inter	= 	instr_in;
endcase
		if(~bypass_stall)
		begin
		decode_instr	= 	decode_instr_inter;
		end
		else
		begin
		decode_instr	= 	inter_decode;
		end
end

// FIXED: when stall is high (and it's not also a flush), hold all
// output registers instead of overwriting them - this is what lets
// the stalled instruction survive to be correctly re-decoded once
// the hazard clears.
always@(posedge clk)
begin
if(!stall || flush_in)
begin
pc_imm_out	<=	pc_imm_in;
pc_4_out	<=	pc_4_in;
source_reg_1 	<= 	decode_instr[19:15];
source_reg_2 	<= 	decode_instr[24:20];
dest_reg 	<= 	decode_instr[11:7];
opcode_out 	<= 	decode_instr[6:0];
funct_3_out 	<= 	decode_instr[14:12];
funct_7_out 	<= 	decode_instr[31:25];
instr_out 	<= 	decode_instr[31:7];
inter_decode	<=	decode_instr;
end
end
endmodule