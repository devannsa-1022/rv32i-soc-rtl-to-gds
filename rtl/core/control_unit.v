`include "Def.v"
`define ERR 4'b1111

module control_unit(
    input clk,
    input reset,
    input load_type_in,
    input [6:0] opcode_in,
    input [2:0] funct3_in,
    input funct7_in,
    
    output reg werf_contrl,
    output reg [1:0] wbmux_contol,
    output reg [3:0] aluop,
    output reg [1:0] ir_mux,
    output stall,
    output reg [2:0] op_format_out,
    output bypass_ir1,
    output bypass_ir2,
    output sb_type,
    output out_u_type,
    output reg reg_u_type_lui,
    output ready_in,
    output i_type_load
);

parameter FETCH = 1'b0;
parameter LOAD_STALL = 1'b1;

wire r_type = (opcode_in == 7'b0110011);
wire i_type = (opcode_in == 7'b0010011);
assign i_type_load = (opcode_in == 7'b0000011);
wire s_type = (opcode_in == 7'b0100011);
wire b_type = (opcode_in == 7'b1100011);
wire i_type_jalr = (opcode_in == 7'b1100111);
wire j_type = (opcode_in == 7'b1101111) || i_type_jalr;
wire u_type_lui = (opcode_in == 7'b0110111);
wire u_type_auipc = (opcode_in == 7'b0010111);

assign bypass_ir2 = r_type || s_type || b_type;
assign out_u_type = u_type_lui || u_type_auipc;
assign bypass_ir1 = ~(j_type || out_u_type);
assign sb_type = b_type || s_type;
assign stall = i_type_load && ~load_type_in;
assign ready_in = i_type_jalr;

reg state, next_state;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= FETCH;
        reg_u_type_lui <= 0;
    end else begin
        state <= next_state;
        reg_u_type_lui <= u_type_lui;
    end
end

always @(*) begin
    next_state = FETCH;
    werf_contrl = 1'b0;
    wbmux_contol = 2'b00;
    aluop = `ALU_ADD;
    ir_mux = 2'b00;
    op_format_out = 3'b000;
    
    case (state)
        FETCH: begin
            // The selects are decoded from distinct opcodes, so they are
            // mutually exclusive and parallel_case cannot change behavior.
            (* parallel_case *)
            case (1'b1)
                u_type_auipc: op_format_out = `U_type_AUIPC;
                b_type:       op_format_out = `B_type;
                j_type:       op_format_out = `J_type;
                u_type_lui:   op_format_out = `U_type_LUI;
                r_type:      op_format_out = `R_type;
                s_type:       op_format_out = `S_type;
                i_type:      op_format_out = `I_type;
                i_type_load:  op_format_out = `I_type_load;
                default:      op_format_out = 3'b000;
            endcase
            
            if (op_format_out == `R_type) begin
                case (funct3_in)
                    3'b000: aluop = funct7_in ? `ALU_SUB : `ALU_ADD;
                    3'b001: aluop = `ALU_SLL;
                    3'b010: aluop = `ALU_SLT;
                    3'b011: aluop = `ALU_SLTU;
                    3'b100: aluop = `ALU_XOR;
                    3'b101: aluop = funct7_in ? `ALU_SRA : `ALU_SRL;
                    3'b110: aluop = `ALU_OR;
                    3'b111: aluop = `ALU_AND;
                    default: aluop = `ERR;
                endcase
            end
            else if (op_format_out == `I_type) begin
                case (funct3_in)
                    3'b000: aluop = `ALU_ADD;
                    3'b001: aluop = `ALU_SLL;
                    3'b010: aluop = `ALU_SLT;
                    3'b011: aluop = `ALU_SLTU;
                    3'b100: aluop = `ALU_XOR;
                    3'b101: aluop = funct7_in ? `ALU_SRA : `ALU_SRL;
                    3'b110: aluop = `ALU_OR;
                    3'b111: aluop = `ALU_AND;
                    default: aluop = `ERR;
                endcase
            end
            else begin
                aluop = `ALU_ADD;
            end
            
            werf_contrl = r_type | i_type | i_type_load | j_type | u_type_lui | u_type_auipc;
            
            case (op_format_out)
                `R_type, `I_type: wbmux_contol = 2'b00;
                `I_type_load:     wbmux_contol = 2'b01;
                `J_type:         wbmux_contol = 2'b10;
                default:         wbmux_contol = 2'b00;
            endcase
            
            ir_mux = 2'b00; // unused in this integration (bypass_unit.v not instantiated)
            
            if (i_type_jalr) begin
                op_format_out = `I_type;
            end
            
            next_state = (i_type_load && ~load_type_in) ? LOAD_STALL : FETCH;
        end
        
        LOAD_STALL: begin
            next_state = load_type_in ? LOAD_STALL : FETCH;
        end
    endcase
end

endmodule