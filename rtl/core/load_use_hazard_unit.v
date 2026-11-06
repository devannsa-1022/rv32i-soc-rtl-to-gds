module load_use_hazard_unit(
    input [4:0] id_rs1, id_rs2,
    input [4:0] idex_rd,
    input       idex_mem_read,
    output      hazard
);
assign hazard = idex_mem_read && (idex_rd != 5'd0) &&
                ((idex_rd == id_rs1) || (idex_rd == id_rs2));
endmodule