module store_unit(op_for,funct3_in,addr_in,rs2_in,rs2_out,wb_mask_out,wr_req_out);

input [31:0] rs2_in;
input [1:0] funct3_in;      // funct3[1:0]: 00=SB, 01=SH, 10=SW
input [1:0] addr_in;        // byte offset within word, from ALU-computed address
input [2:0] op_for;         // Control_unit.v's op_format_out
output [31:0] rs2_out;
output reg [3:0] wb_mask_out;
output wr_req_out;

wire mem_wr;
reg [31:0] rs2_inter;
reg [3:0] byte_mask,half_word_mask;
reg [31:0] byte_out,half_word_out;

// FIXED: was `(~op_for[2]) & (op_for[1]) & (~op_for[0])`, which detects
// op_for==3'b010 - that's Def.v's S_type encoding, but Control_unit.v's
// actual op_format_out encodes S_type as 3'b011. Must track Control_unit.v.
assign mem_wr = (op_for == `S_type);
assign wr_req_out = mem_wr;

// FIXED: re-enabled address-based byte-lane selection (was hardcoded to
// lane 0 only). Byte mask now shifts to the correct lane per addr_in.
always@(*)
begin
case(addr_in)
2'b00: byte_mask = {3'b0,mem_wr};
2'b01: byte_mask = {2'b0,mem_wr,1'b0};
2'b10: byte_mask = {1'b0,mem_wr,2'b0};
2'b11: byte_mask = {mem_wr,3'b0};
endcase
end

always@(*)
begin
case(addr_in[1])
1'b0: half_word_mask = {2'b0,{2{mem_wr}}};
1'b1: half_word_mask = {{2{mem_wr}},2'b0};
endcase
end

always@(*)
begin
case(addr_in)
2'b00: byte_out = {24'b0,rs2_in[7:0]};
2'b01: byte_out = {16'b0,rs2_in[7:0],8'b0};
2'b10: byte_out = {8'b0,rs2_in[7:0],16'b0};
2'b11: byte_out = {rs2_in[7:0],24'b0};
endcase
end

always@(*)
begin
case(addr_in[1])
1'b0: half_word_out = {16'b0,rs2_in[15:0]};
1'b1: half_word_out = {rs2_in[15:0],16'b0};
endcase
end

always@(*)
begin
case(funct3_in)
2'b00: wb_mask_out = byte_mask;
2'b01: wb_mask_out = half_word_mask;
default: wb_mask_out = {4{mem_wr}};
endcase
end

always@(*)
begin
case(funct3_in)
2'b00: rs2_inter = byte_out;
2'b01: rs2_inter = half_word_out;
default: rs2_inter = rs2_in;
endcase
end

// FIXED: removed tri-state (32'hzzzz_zzzz) output - doesn't synthesize
// cleanly on FPGA fabric. Data_mem.v now uses wb_mask_out to gate which
// bytes actually get written, so an inactive value here is harmless.
assign rs2_out = rs2_inter;

endmodule