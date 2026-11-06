module bypass_unit(clk,reset,sb_type_in,in_u_type,bypass_ir1_in,bypass_ir2_in,op_format_contrl_in,ir_mux_in,rs1,rd,rs2,load_in,irmux1,irmux2,stall_out,u_type_contrl_in);

input load_in,clk,reset,bypass_ir1_in,bypass_ir2_in,sb_type_in,in_u_type;
input [1:0] ir_mux_in;
input [4:0] rs1,rs2,rd;
input [2:0] op_format_contrl_in;
reg [4:0] reg_rd0,reg_rd1,reg_rd2;
reg [1:0] inter_irmux;
reg  inter1_ir1,inter1_ir2,inter2_ir1,inter2_ir2;
reg reg_u_type;
output [1:0] irmux1;
output [1:0] irmux2;
output reg stall_out,u_type_contrl_in;
reg [1:0] inter1;
reg u_type_in_stall,no_stall;
parameter START = 1'b0, LOAD = 1'b1;

reg STATE,NEXT_STATE;

always@(posedge clk)
begin
if(reset)
begin
STATE <= LOAD;
reg_rd0 	= 0;
reg_rd1 	= 0;
reg_rd2 	= 0;
stall_out 	= 0;
reg_u_type 	= 0; 
u_type_in_stall = 0;
inter1_ir1 	= 0;
inter1_ir2 	= 0;
inter2_ir1 	= 0;
inter2_ir2 	= 0; 
end
else
begin
STATE <= NEXT_STATE;
end

end


always@(posedge clk) //or sb_type_in)
begin
if(sb_type_in | (NEXT_STATE == LOAD))
begin
reg_rd0 <= 5'b00000;
end
else
begin
reg_rd0 <= rd;
end
reg_rd1 <= reg_rd0;
reg_rd2 <= reg_rd1;
reg_u_type <= in_u_type;
end

always@(*)
begin
	inter1_ir1 = ((reg_rd0 == rs1) & (|(rs1)));
	inter1_ir2 = ((reg_rd0 == rs2) & (|(rs2)));
	inter2_ir1 = ((reg_rd1 == rs1) & (|(rs1)));
	inter2_ir2 = ((reg_rd1 == rs2) & (|(rs2)));
	no_stall   = ((reg_rd0 == reg_rd2)| (reg_rd1 == reg_rd2));
case(STATE)
START:	begin
	u_type_contrl_in = ((inter1_ir1 | inter1_ir2) & (reg_u_type));
	stall_out  = (((reg_rd2 == rs2) | (reg_rd2 == rs1)) & (|(reg_rd2)) & (~no_stall));
	// FIXED: was non-blocking (<=) inside a combinational always@(*) block -
	// changed to blocking (=), the correct style for combinational logic.
	if(stall_out)
	begin
	NEXT_STATE = LOAD;
	end
	else
	begin
	NEXT_STATE = START;
	end
	end
LOAD:	begin
	stall_out  = (((reg_rd2 == rs2) | (reg_rd2 == rs1)) & (|(reg_rd2)));
	// FIXED: same non-blocking-in-combinational issue.
	if(stall_out)
	begin
	NEXT_STATE = LOAD;
	end
	else
	begin
	NEXT_STATE = START;
	end
	end
endcase

end
always@(inter2_ir2 or inter1_ir2 or ir_mux_in)
begin
inter_irmux = ir_mux_in;
	case({inter2_ir2,inter1_ir2})
	2'b01:	inter_irmux = {inter2_ir2,inter1_ir2};
	2'b00:	inter_irmux = ir_mux_in;
	2'b10:	inter_irmux = {inter2_ir2,inter1_ir2};
	2'b11:	inter_irmux = {(~inter2_ir2),inter1_ir2};
	default: inter_irmux = ir_mux_in;
	endcase
	
end

assign irmux2 = (bypass_ir2_in)? inter_irmux : ir_mux_in;

always@(inter2_ir1 or inter1_ir1)
begin
inter1 = 2'b00;
	case({inter2_ir1,inter1_ir1})
	2'b01:	inter1 = {inter2_ir1,inter1_ir1};
	2'b00:	inter1 = 2'b00;
	2'b10:	inter1 = {inter2_ir1,inter1_ir1};
	2'b11:	inter1 = {(~inter2_ir1),inter1_ir1};
	default: inter1 = 2'b00;
	endcase
end

assign irmux1 = (bypass_ir1_in)? inter1 : 2'b00;

endmodule