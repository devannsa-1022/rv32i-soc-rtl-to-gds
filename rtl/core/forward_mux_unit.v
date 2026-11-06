module forward_mux_unit(
    input [4:0] rs1, rs2,
    input [4:0] exmem_rd,
    input       exmem_regwrite,
    input [4:0] memwb_rd,
    input       memwb_regwrite,
    output reg [1:0] fwd_a,
    output reg [1:0] fwd_b
);
always @(*) begin
    if (exmem_regwrite && (exmem_rd != 5'd0) && (exmem_rd == rs1))
        fwd_a = 2'b01;
    else if (memwb_regwrite && (memwb_rd != 5'd0) && (memwb_rd == rs1))
        fwd_a = 2'b10;
    else
        fwd_a = 2'b00;

    if (exmem_regwrite && (exmem_rd != 5'd0) && (exmem_rd == rs2))
        fwd_b = 2'b01;
    else if (memwb_regwrite && (memwb_rd != 5'd0) && (memwb_rd == rs2))
        fwd_b = 2'b10;
    else
        fwd_b = 2'b00;
end
endmodule