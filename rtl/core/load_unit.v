module load_unit(load_funct3_in,load_in,data_in,addr_in,load_output,load_mux);

input [31:0] data_in;
input [2:0] load_funct3_in;
input load_in;
input [1:0] addr_in;        // byte offset within word

output [31:0] load_output;
reg [7:0] byte_pos;
reg [15:0] half_word_pos;
reg byte_sign,half_word_sign;
reg [31:0] load_inter;
output load_mux;

assign load_mux = load_in;

// FIXED: re-enabled address-based byte/halfword lane selection (was
// hardcoded to read only the lowest byte/halfword regardless of address).
always@(*)
begin
case(addr_in)
2'b00: byte_pos = data_in[7:0];
2'b01: byte_pos = data_in[15:8];
2'b10: byte_pos = data_in[23:16];
2'b11: byte_pos = data_in[31:24];
endcase
end

always@(*)
begin
case(addr_in[1])
1'b0: half_word_pos = data_in[15:0];
1'b1: half_word_pos = data_in[31:16];
endcase
end

// FIXED: sign-extension condition was inverted. funct3[2]==1 means
// LBU/LHU (unsigned - must zero-extend); funct3[2]==0 means LB/LH
// (signed - must sign-extend). Original code did the opposite.
always@(load_funct3_in or byte_pos or half_word_pos)
begin
case(load_funct3_in[2])
1'b0: begin
	byte_sign = byte_pos[7];
	half_word_sign = half_word_pos[15];
	end
1'b1: begin
	byte_sign = 1'b0;
	half_word_sign = 1'b0;
	end
endcase
end

always@(*)
begin
case(load_funct3_in[1:0])
2'b00:	load_inter = {{24{byte_sign}},byte_pos};
2'b01:	load_inter = {{16{half_word_sign}},half_word_pos};
2'b10:	load_inter = data_in;
default:load_inter = data_in;
endcase
end

// FIXED: removed tri-state output - the existing WB mux (Control_unit.v's
// wbmux_contol) already selects between ALU/MEM/PC results, so gating via
// z-state here was redundant and not FPGA-synthesizable.
assign load_output = load_inter;

endmodule