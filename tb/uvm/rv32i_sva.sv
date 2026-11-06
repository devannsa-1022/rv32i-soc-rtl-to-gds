`timescale 1ns/1ps

module rv32i_sva(
    input clk,
    input reset,
    input [31:0] pc_out,
    input werf_id, i_type_load_id,
    input [4:0] source_reg_1, source_reg_2,
    input idex_i_type_load,
    input [4:0] idex_rd,
    input stall_front,
    input branch_out,
    input flush_if,
    input [4:0] memwb_rd,
    input memwb_werf,
    input [31:0] wb_data
);

    property p_reset_pc;
        @(posedge clk) $fell(reset) |-> (pc_out == 32'h0);
    endproperty
    assert property (p_reset_pc)
        else $error("PC not at boot address immediately after reset deassertion");

    property p_load_use_stalls;
        @(posedge clk) disable iff (reset)
        (idex_i_type_load && (idex_rd != 5'd0) &&
         ((idex_rd == source_reg_1) || (idex_rd == source_reg_2)))
        |-> stall_front;
    endproperty
    assert property (p_load_use_stalls)
        else $error("Load-use hazard present but stall_front not asserted");

    property p_branch_flushes;
        @(posedge clk) disable iff (reset)
        branch_out |-> flush_if;
    endproperty
    assert property (p_branch_flushes)
        else $error("Branch taken but flush_if not asserted");

    property p_no_x_on_writeback;
        @(posedge clk) disable iff (reset)
        (memwb_werf && memwb_rd != 5'd0) |-> !$isunknown(wb_data);
    endproperty
    assert property (p_no_x_on_writeback)
        else $error("Register writeback data is X/Z while werf is asserted");

endmodule

bind rv32i_core rv32i_sva sva_inst(
    .clk(clk), .reset(reset),
    .pc_out(pc_out),
    .werf_id(werf_id), .i_type_load_id(i_type_load_id),
    .source_reg_1(source_reg_1), .source_reg_2(source_reg_2),
    .idex_i_type_load(idex_i_type_load), .idex_rd(idex_rd),
    .stall_front(stall_front),
    .branch_out(branch_out), .flush_if(flush_if),
    .memwb_rd(memwb_rd), .memwb_werf(memwb_werf), .wb_data(wb_data)
);