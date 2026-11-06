`include "Def.v"

module rv32i_core(
    input clk,
    input reset,

    // Instruction fetch. The memory is synchronous (data returns the cycle
    // after the address), so imem_addr is the PC for the next cycle.
    output [31:0] imem_addr,
    input  [31:0] imem_rdata,

    // External memory bus
    output [31:0] mem_addr,
    output [31:0] mem_wdata,
    output [3:0]  mem_wstrb,
    output        mem_we,
    output        mem_re,
    input  [31:0] mem_rdata,
    input         mem_ready
);

    // ================================================================
    // IF STAGE
    // ================================================================
    wire [31:0] pc_out;
    wire [31:0] pc_plus4_in;
    wire [31:0] pc_imm;
    wire [31:0] instr;


    // ================================================================
    // ID STAGE
    // ================================================================
    wire jal_taken;

    wire [4:0] source_reg_1;
    wire [4:0] source_reg_2;
    wire [4:0] dest_reg;

    wire [6:0] opcode_out;
    wire [2:0] funct_3_out;
    wire [6:0] funct_7_out;

    wire load_itype;
    wire [24:0] instr_out;

    wire [31:0] pc_imm_out;
    wire [31:0] pc_4_out;

    wire werf_id;
    wire bypass_ir1_u;
    wire bypass_ir2_u;
    wire sb_type_id;
    wire out_u_type_u;
    wire reg_u_type_lui_u;

    wire ready_in_id;
    wire i_type_load_id;
    wire stall_load_u;

    wire [1:0] wbmux_id;
    wire [1:0] ir_mux_u;

    wire [3:0] aluop_id;
    wire [2:0] op_format_id;

    wire [31:0] read_data1;
    wire [31:0] read_data2;
    wire [31:0] imm_id;

    wire branch_out;
    wire jal_enab_u;
    wire branch_enable;

    wire branch_taken_out;
    wire wrong_predict_out;
    wire is_branch;

    wire [31:0] jalr_target;

    wire [1:0] id_fwd_a;
    wire [1:0] id_fwd_b;

    wire [31:0] id_operand1;
    wire [31:0] id_operand2;

    wire lu_hazard;
    wire stall_front;
    wire flush_if;


    // ================================================================
    // ID/EX STAGE
    // ================================================================
    wire [31:0] idex_pc_4;
    wire [31:0] idex_rs1_data;
    wire [31:0] idex_rs2_data;
    wire [31:0] idex_imm;

    wire [4:0] idex_rs1;
    wire [4:0] idex_rs2;
    wire [4:0] idex_rd;

    wire [2:0] idex_funct3;
    wire [3:0] idex_aluop;

    wire idex_werf;
    wire [1:0] idex_wbmux;

    wire idex_i_type_load;
    wire [2:0] idex_op_format;

    wire [31:0] branch_target;


    // ================================================================
    // MEMORY STALL
    // ================================================================
    // An outstanding external memory transaction freezes the pipeline
    // until axi_manager produces a one-cycle mem_ready pulse.
    // In rv32i_core.v, near mem_stall's declaration:



    // ================================================================
    // EX STAGE
    // ================================================================
    wire [1:0] ex_fwd_a;
    wire [1:0] ex_fwd_b;

    wire [31:0] ex_operand1;
    wire [31:0] ex_operand2;

    wire [31:0] alu_op1;
    wire [31:0] alu_op2;
    wire [31:0] alu_result;

    wire [3:0] store_mask;
    wire [31:0] store_data;

    wire ex_is_store;
    wire ex_is_load;
    wire mem_op_enable;
    wire mem_rw;


    // ================================================================
    // EX/MEM STAGE
    // ================================================================
    wire [31:0] exmem_alu_res;
    wire [31:0] exmem_store_data;
    wire [31:0] exmem_pc_4;

    wire exmem_werf;
    wire exmem_mem_enable;
    wire exmem_mem_rw;
    wire exmem_is_load;

    wire [1:0] exmem_wbmux;
    wire [3:0] exmem_mask;

    wire [4:0] exmem_rd;
    wire [2:0] exmem_funct3;


    // ================================================================
    // MEM STAGE
    // ================================================================
    wire [31:0] mem_read_data;
    wire [31:0] load_output;

    assign mem_read_data = mem_rdata;


    // ================================================================
    // MEM/WB STAGE
    // ================================================================
    wire [31:0] memwb_pc_4;
    wire [31:0] memwb_read_mem;
    wire [31:0] memwb_alu_result;

    wire memwb_load;
    wire memwb_werf;

    wire [1:0] memwb_wbsel;
    wire [4:0] memwb_rd;
    wire mem_stall = exmem_mem_enable && !mem_ready;
    reg [31:0] wb_data;


    // ================================================================
    // BRANCH TARGET
    // ================================================================
    // pc_4_out belongs to the branch currently in ID.
    assign branch_target =
        (pc_4_out - 32'd4) + imm_id;


    // ================================================================
    // IF
    // ================================================================
    prog_counter pc0(
        .clk(clk),
        .reset(reset),

        .jalr_type_in(jalr_target),
        .immbj(branch_target - pc_out),

        .stall_in((stall_front | mem_stall) & ~flush_if),

        .pc_mux_in(1'b0),

        .branch_taken_in(branch_out | jal_taken),

        .ready_in(ready_in_id),

        .wrong_predict_in(1'b0),

        .pc_plus4_in(pc_plus4_in),
        .pc_imm(pc_imm),
        .pc_out(pc_out),
        .pc_next(imem_addr)
    );


    // ================================================================
    // INSTRUCTION FETCH (memory lives in rv32i_soc)
    // ================================================================
    assign instr = imem_rdata;


    // ================================================================
    // IF/ID + DECODER
    // ================================================================
    decoder if_id0(
        .instr_in(instr),

        .bypass_stall(1'b0),

        .clk(clk),
        .reset(reset),

        .stall(stall_front | mem_stall),

        .pc_imm_in(pc_imm),
        .pc_4_in(pc_plus4_in),

        .wrong_predict_in(flush_if),

        .source_reg_1(source_reg_1),
        .source_reg_2(source_reg_2),
        .dest_reg(dest_reg),

        .opcode_out(opcode_out),
        .funct_3_out(funct_3_out),
        .funct_7_out(funct_7_out),

        .load_itype(load_itype),
        .instr_out(instr_out),

        .pc_imm_out(pc_imm_out),
        .pc_4_out(pc_4_out)
    );


    // ================================================================
    // CONTROL UNIT
    // ================================================================
    control_unit cu0(
        .clk(clk),
        .reset(reset),

        .load_type_in(1'b1),

        .opcode_in(opcode_out),
        .funct3_in(funct_3_out),
        .funct7_in(funct_7_out[5]),

        .werf_contrl(werf_id),
        .wbmux_contol(wbmux_id),

        .aluop(aluop_id),
        .ir_mux(ir_mux_u),

        .stall(stall_load_u),

        .op_format_out(op_format_id),

        .bypass_ir1(bypass_ir1_u),
        .bypass_ir2(bypass_ir2_u),

        .sb_type(sb_type_id),
        .out_u_type(out_u_type_u),
        .reg_u_type_lui(reg_u_type_lui_u),

        .ready_in(ready_in_id),
        .i_type_load(i_type_load_id)
    );


    // ================================================================
    // IMMEDIATE GENERATOR
    // ================================================================
    imm_gen ig0(
        .instr(instr_out),
        .imm_mux(op_format_id),
        .imm(imm_id)
    );


    // ================================================================
    // REGISTER FILE
    // ================================================================
    reg_file rf0(
        .clk(clk),
        .reset(reset),

        .read_address1(source_reg_1),
        .read_address2(source_reg_2),

        .write_enable(memwb_werf),
        .write_address(memwb_rd),
        .write_data(wb_data),

        .read_data1(read_data1),
        .read_data2(read_data2)
    );


    // ================================================================
    // ID FORWARDING
    // ================================================================
    forward_mux_unit id_fwd(
        .rs1(source_reg_1),
        .rs2(source_reg_2),

        .exmem_rd(exmem_rd),
        .exmem_regwrite(exmem_werf),

        .memwb_rd(memwb_rd),
        .memwb_regwrite(memwb_werf),

        .fwd_a(id_fwd_a),
        .fwd_b(id_fwd_b)
    );


    assign id_operand1 =
        (id_fwd_a == 2'b01) ? exmem_alu_res :
        (id_fwd_a == 2'b10) ? wb_data :
                              read_data1;

    assign id_operand2 =
        (id_fwd_b == 2'b01) ? exmem_alu_res :
        (id_fwd_b == 2'b10) ? wb_data :
                              read_data2;


    // ================================================================
    // BRANCH UNIT
    // ================================================================
    branch_unit br0(
        .funct3_in(funct_3_out),
        .opcode_in(opcode_out[6:2]),

        .source_1(id_operand1),
        .source_2(id_operand2),

        .branch_out(branch_out),
        .jal_enab(jal_enab_u),
        .enable(branch_enable)
    );


    // ================================================================
    // BRANCH PREDICTION UNIT
    // ================================================================
    branch_prediction_unit bp0(
        .clock(clk),

        .opcode_in(opcode_out[6:2]),

        .reset(reset),

        .branch_in(branch_out),

        .branch_taken_out(branch_taken_out),
        .wrong_predict_out(wrong_predict_out),
        .is_branch(is_branch)
    );


    // ================================================================
    // JALR TARGET
    // ================================================================
    jalr_type_adder jalr0(
        .reg_1(id_operand1),
        .imm(imm_id),
        .jalr_out(jalr_target)
    );


    // ================================================================
    // LOAD-USE HAZARD DETECTION
    // ================================================================
    load_use_hazard_unit lu0(
        .id_rs1(source_reg_1),
        .id_rs2(source_reg_2),

        .idex_rd(idex_rd),
        .idex_mem_read(idex_i_type_load),

        .hazard(lu_hazard)
    );


    assign stall_front = lu_hazard;

    assign flush_if =
        branch_out |
        ready_in_id |
        jal_taken;


    // ================================================================
    // ID/EX PIPELINE REGISTER
    // ================================================================
    id_ex_pip_reg idex0(
        .clk(clk),
        .reset(reset),

        .stall(mem_stall),
        .bubble(lu_hazard),

        .pc_4_in(pc_4_out),

        .rs1_data_in(id_operand1),
        .rs2_data_in(id_operand2),

        .imm_in(imm_id),

        .rs1_in(source_reg_1),
        .rs2_in(source_reg_2),
        .rd_in(dest_reg),

        .funct3_in(funct_3_out),

        .aluop_in(aluop_id),

        .werf_in(werf_id),

        .wbmux_in(wbmux_id),

        .i_type_load_in(i_type_load_id),

        .op_format_in(op_format_id),

        .pc_4_out(idex_pc_4),

        .rs1_data_out(idex_rs1_data),
        .rs2_data_out(idex_rs2_data),
        .imm_out(idex_imm),

        .rs1_out(idex_rs1),
        .rs2_out(idex_rs2),
        .rd_out(idex_rd),

        .funct3_out(idex_funct3),

        .aluop_out(idex_aluop),

        .werf_out(idex_werf),

        .wbmux_out(idex_wbmux),

        .i_type_load_out(idex_i_type_load),

        .op_format_out(idex_op_format)
    );


    // ================================================================
    // EX FORWARDING
    // ================================================================
    forward_mux_unit ex_fwd(
        .rs1(idex_rs1),
        .rs2(idex_rs2),

        .exmem_rd(exmem_rd),
        .exmem_regwrite(exmem_werf),

        .memwb_rd(memwb_rd),
        .memwb_regwrite(memwb_werf),

        .fwd_a(ex_fwd_a),
        .fwd_b(ex_fwd_b)
    );


    assign ex_operand1 =
        (ex_fwd_a == 2'b01) ? exmem_alu_res :
        (ex_fwd_a == 2'b10) ? wb_data :
                              idex_rs1_data;

    assign ex_operand2 =
        (ex_fwd_b == 2'b01) ? exmem_alu_res :
        (ex_fwd_b == 2'b10) ? wb_data :
                              idex_rs2_data;


    // ================================================================
    // ALU INPUT SELECTION
    // ================================================================
    assign alu_op1 =
        (idex_op_format == `U_type_LUI)   ? 32'h00000000 :
        (idex_op_format == `U_type_AUIPC) ?
            (idex_pc_4 - 32'd4) :
            ex_operand1;

    assign alu_op2 =
        (idex_op_format == `R_type) ?
            ex_operand2 :
            idex_imm;


    // ================================================================
    // ALU
    // ================================================================
    ALU alu0(
        .operand_1(alu_op1),
        .operand_2(alu_op2),
        .aluop(idex_aluop),
        .out(alu_result)
    );


    // ================================================================
    // MEMORY OPERATION CONTROL
    // ================================================================
    assign ex_is_store  = (idex_op_format == `S_type);
    assign ex_is_load   = idex_i_type_load;

    assign mem_op_enable =
        ex_is_store | ex_is_load;

    assign mem_rw =
        ex_is_store;       // 0 = read, 1 = write
    assign jal_taken = (op_format_id == `J_type);

    // ================================================================
    // STORE DATA / BYTE MASK
    // ================================================================
    store_unit store0(
        .op_for(idex_op_format),
        .funct3_in(idex_funct3[1:0]),

        .addr_in(alu_result[1:0]),
        .rs2_in(ex_operand2),

        .rs2_out(store_data),
        .wb_mask_out(store_mask),

        .wr_req_out()
    );


    // ================================================================
    // EX/MEM PIPELINE REGISTER
    // ================================================================
    mem_pip_reg exmem0(
        .clk(clk),
        .reset(reset),

        .stall(mem_stall),

        .load_type_pip_in(ex_is_load),
        .funct3_pip_in(idex_funct3),

        .alu_out(alu_result),

        .addr_in_pip(idex_rd),

        .imm_in_mem(32'h00000000),

        .mask_bits_in_to(store_mask),

        .mem_enable_in(mem_op_enable),

        .mem_rw_in(mem_rw),

        .pc_4_pip(idex_pc_4),

        .pc_imm_pip(32'h00000000),

        .werf_in(idex_werf),

        .wb_mux_in(idex_wbmux),

        .store_in(store_data),

        .alu_res(exmem_alu_res),
        .data_mem_store(exmem_store_data),

        .werf_contrl_out(exmem_werf),

        .wb_mux_output(exmem_wbmux),

        .pc_4_wb(exmem_pc_4),
        .pc_imm_wb(),

        .data_mem_enable_out(exmem_mem_enable),
        .data_mem_rw_out(exmem_mem_rw),

        .mask_bits_out(exmem_mask),

        .wb_imm(),

        .addr_out_pip(exmem_rd),

        .funct3_out_pip(exmem_funct3),

        .load_type_unit_in(exmem_is_load)
    );


    // ================================================================
    // EXTERNAL MEMORY BUS
    // ================================================================
    assign mem_addr  = exmem_alu_res;
    assign mem_wdata = exmem_store_data;
    assign mem_wstrb = exmem_mask;
    

    assign mem_we =
        exmem_mem_enable &
        exmem_mem_rw;

    assign mem_re =
        exmem_mem_enable &
        ~exmem_mem_rw;


    // ================================================================
    // LOAD UNIT
    // ================================================================
    load_unit load0(
        .load_funct3_in(exmem_funct3),

        .load_in(exmem_is_load),

        .data_in(mem_read_data),

        .addr_in(exmem_alu_res[1:0]),

        .load_output(load_output),

        .load_mux()
    );


    // ================================================================
    // MEM/WB PIPELINE REGISTER
    // ================================================================
    pip_reg4 memwb0(
        .clk(clk),
        .stall(mem_stall),

        .addr_wb_in(exmem_rd),

        .werf_enable_in(exmem_werf),

        .pc_plus_4_in(exmem_pc_4),

        .immu_in(32'h00000000),

        .pc_plus_immu_in(32'h00000000),

        // IMPORTANT:
        // Use the AXI-returned data directly after mem_ready.
        .read_mem_in(load_output),

        .load_in(exmem_is_load),

        .alu_result_in(exmem_alu_res),

        .wb_select_in(exmem_wbmux),

        .pc_plus_4_out(memwb_pc_4),

        .immu_out(),

        .pc_plus_immu_out(),

        .read_mem_out(memwb_read_mem),

        .load_out(memwb_load),

        .alu_result_out(memwb_alu_result),

        .wb_select_out(memwb_wbsel),

        .addr_wb_out(memwb_rd),

        .werf_enable_out(memwb_werf)
    );


    // ================================================================
    // WRITEBACK
    // ================================================================
    always @(*) begin

        case (memwb_wbsel)

            2'b00:
                wb_data = memwb_alu_result;

            2'b01:
                wb_data = memwb_read_mem;

            2'b10:
                wb_data = memwb_pc_4;

            default:
                wb_data = memwb_alu_result;

        endcase

    end

endmodule