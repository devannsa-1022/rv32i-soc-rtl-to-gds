`timescale 1ns/1ps

module coverage_collector(
    input clk,
    input reset,
    input [2:0] op_format_id,       // instruction type currently in ID
    input werf_id,
    input i_type_load_id,
    input stall_front,
    input branch_out,
    input branch_enable,
    input flush_if,
    input [1:0] id_fwd_a, id_fwd_b, // ID-stage forwarding mux select
    input [1:0] ex_fwd_a, ex_fwd_b, // EX-stage forwarding mux select
    input [3:0] idex_aluop,
    input [2:0] idex_op_format       // instruction type currently in EX
);
    covergroup instr_cg @(posedge clk);
        option.per_instance = 1;

        // Instruction type coverage
        cp_op_format: coverpoint op_format_id iff (!reset) {
            bins r_type       = {3'b111};
            bins i_type       = {3'b000};
            bins i_type_load  = {3'b001};
            bins s_type       = {3'b010};
            bins b_type       = {3'b011};
            bins j_type       = {3'b100};
            bins u_type_lui   = {3'b101};
            bins u_type_auipc = {3'b110};
        }

        // Same field, one stage later (EX) -- needed to align with EX-stage
        // forwarding decisions (cp_ex_fwd_a), since op_format_id and
        // ex_fwd_a otherwise refer to two different instructions on the
        // same clock edge.
        cp_idex_op_format: coverpoint idex_op_format iff (!reset) {
            bins r_type       = {3'b111};
            bins i_type       = {3'b000};
            bins i_type_load  = {3'b001};
            bins s_type       = {3'b010};
            bins b_type       = {3'b011};
            bins j_type       = {3'b100};
            bins u_type_lui   = {3'b101};
            bins u_type_auipc = {3'b110};
        }

        // ALU operation coverage (only meaningful while an R/I-type is in EX)
        cp_aluop: coverpoint idex_aluop iff (!reset) {
            bins add  = {4'b0000};
            bins sub  = {4'b0001};
            bins sll  = {4'b0010};
            bins slt  = {4'b0011};
            bins sltu = {4'b0100};
            bins xor_ = {4'b0101};
            bins srl  = {4'b0110};
            bins sra  = {4'b0111};
            bins or_  = {4'b1000};
            bins and_ = {4'b1001};
        }

        // Hazard/control-flow events
        cp_stall:  coverpoint stall_front iff (!reset) { bins hit = {1'b1}; bins miss = {1'b0}; }
        cp_branch: coverpoint branch_out iff (!reset && branch_enable) { bins taken = {1'b1}; bins not_taken = {1'b0}; }
        cp_flush:  coverpoint flush_if    iff (!reset) { bins hit = {1'b1}; bins miss = {1'b0}; }

        // Forwarding paths -- did we ever exercise EACH source (none/EX/MEM)?
        cp_id_fwd_a: coverpoint id_fwd_a iff (!reset) { bins none={2'b00}; bins from_exmem={2'b01}; bins from_memwb={2'b10}; }
        cp_id_fwd_b: coverpoint id_fwd_b iff (!reset) { bins none={2'b00}; bins from_exmem={2'b01}; bins from_memwb={2'b10}; }
        cp_ex_fwd_a: coverpoint ex_fwd_a iff (!reset) { bins none={2'b00}; bins from_exmem={2'b01}; bins from_memwb={2'b10}; }
        cp_ex_fwd_b: coverpoint ex_fwd_b iff (!reset) { bins none={2'b00}; bins from_exmem={2'b01}; bins from_memwb={2'b10}; }

        // Cross: has forwarding actually engaged during an R-type op?
        // FIXED: crosses idex_op_format (EX-stage) against cp_ex_fwd_a
        // (also an EX-stage decision) -- both now refer to the same
        // instruction, unlike the old op_format_id/cp_ex_fwd_a cross.
        cx_rtype_forward: cross cp_idex_op_format, cp_ex_fwd_a {
            bins rtype_fwd_exmem = binsof(cp_idex_op_format.r_type) && binsof(cp_ex_fwd_a.from_exmem);
            bins rtype_fwd_memwb = binsof(cp_idex_op_format.r_type) && binsof(cp_ex_fwd_a.from_memwb);
            ignore_bins others = !binsof(cp_idex_op_format.r_type);
}

        // cx_load_stall removed: stall_front is asserted based on the
        // CONSUMER instruction (in ID), never the load itself (which is
        // in EX at that moment) -- op_format_id can never show i_type_load
        // at the same cycle stall_front fires, by construction. cp_stall's
        // 100% already proves the stall path is exercised; this cross
        // added no further verification value.
    endgroup

    instr_cg cg_inst = new();
endmodule

bind rv32i_core coverage_collector cov_inst(
    .clk(clk), .reset(reset),
    .op_format_id(op_format_id), .werf_id(werf_id), .i_type_load_id(i_type_load_id),
    .stall_front(stall_front), .branch_out(branch_out), .branch_enable(branch_enable), .flush_if(flush_if),
    .id_fwd_a(id_fwd_a), .id_fwd_b(id_fwd_b),
    .ex_fwd_a(ex_fwd_a), .ex_fwd_b(ex_fwd_b),
    .idex_aluop(idex_aluop),
    .idex_op_format(idex_op_format)
);