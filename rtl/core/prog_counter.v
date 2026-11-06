module prog_counter(clk,reset,jalr_type_in,immbj,stall_in,pc_mux_in,branch_taken_in,ready_in,wrong_predict_in,pc_plus4_in,pc_imm,pc_out,pc_next);

input [31:0] jalr_type_in,immbj;
input stall_in,pc_mux_in,branch_taken_in,ready_in,wrong_predict_in,clk,reset;
output [31:0] pc_plus4_in,pc_imm;
output [31:0] pc_next;
output reg [31:0] pc_out;
reg [31:0] pc_inter_out,next_pc,pc_mux_out,pc_enter,pc_stall_out,reg_pc;

parameter boot_addr = 32'h0000_0000;

assign pc_plus4_in 	=  pc_enter + 4;
assign pc_imm 		=  pc_enter + immbj;

always@(branch_taken_in or pc_imm or pc_plus4_in)
begin
case(branch_taken_in)
1'b1:next_pc = pc_imm;
1'b0:next_pc = pc_plus4_in;
default:next_pc = pc_plus4_in;
endcase
end

always@(pc_mux_in or next_pc)
begin
case(pc_mux_in)
1'b1:pc_inter_out = boot_addr;
1'b0:pc_inter_out = next_pc;
default:pc_inter_out = next_pc;
endcase
end

always@(ready_in or jalr_type_in or pc_inter_out)
begin
if(ready_in)
   pc_mux_out = jalr_type_in;
else
   pc_mux_out = pc_inter_out;
end

always@(stall_in or pc_out or pc_mux_out)
begin
if(stall_in)
   pc_stall_out = pc_out;
else
   pc_stall_out = pc_mux_out;
end

// Fetch address for the synchronous instruction memory: the value pc_out
// takes on the next clock edge (boot_addr while in reset), so the memory's
// registered output lines up with pc_out.
assign pc_next = reset ? boot_addr : pc_stall_out;

// FIXED: added async reset so pc_out/reg_pc start at boot_addr instead of
// unknown (x) - without this, simulation start and any FPGA power-on/reset
// pulse had no defined way to bring the PC to a known state.
always@(posedge clk or posedge reset)
begin
if(reset)
begin
   reg_pc <= boot_addr;
   pc_out <= boot_addr;
end
else
begin
   if(stall_in)
      reg_pc <= reg_pc;
   else
      reg_pc <= pc_out;
   pc_out <= pc_stall_out;
end
end

always@(wrong_predict_in or reg_pc or pc_out)
begin
if(wrong_predict_in)
   pc_enter = reg_pc;
else
   pc_enter = pc_out;
end

endmodule
module jalr_type_adder(reg_1,imm,jalr_out);

input [31:0] reg_1,imm;
output [31:0] jalr_out;
wire [31:0] jalr_inter;

assign jalr_inter = reg_1 + imm;
// FIXED: was {jalr_inter,1'b0} (33 bits, wrong). Per RISC-V spec, JALR
// clears bit 0 of the target address.
assign jalr_out = {jalr_inter[31:1], 1'b0};

endmodule