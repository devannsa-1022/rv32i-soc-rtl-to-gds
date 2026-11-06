`timescale 1ns/1ps

// Direct-mapped, write-back, write-allocate data cache.
//   LINE_WORDS words per line, NUM_LINES lines, backed by a unified_ram
//   of RAM_WORDS words. Address (byte address, bits [9:2] give the word
//   address matching the old data_memory's own indexing convention):
//     word_addr[1:0]              -> word offset within line (LINE_WORDS=4)
//     word_addr[4:2]              -> line index (NUM_LINES=8)
//     word_addr[7:5]              -> tag
module dcache #(
    parameter LINE_WORDS = 4,
    parameter NUM_LINES  = 8,
    parameter RAM_WORDS  = 256
)(
    input clk,
    input reset,

    // Bridge-facing simple bus -- mirrors rv32i_core's own mem_* interface
    // so the same "hold everything until ready" discipline applies here
    // too.
    input  [31:0] addr,
    input  [31:0] wdata,
    input  [3:0]  wstrb,
    input         we,
    input         re,
    output reg [31:0] rdata,
    output reg        ready,   // 1 when a request just completed this cycle

    // Backing RAM port
    output reg [$clog2(RAM_WORDS)-1:0] ram_addr,
    output reg [31:0] ram_wdata,
    output reg        ram_we,
    input      [31:0] ram_rdata
);

    localparam OFFSET_BITS = $clog2(LINE_WORDS);
    localparam INDEX_BITS  = $clog2(NUM_LINES);
    localparam WORD_BITS   = $clog2(RAM_WORDS);
    localparam TAG_BITS    = WORD_BITS - INDEX_BITS - OFFSET_BITS;

    // ---- Cache storage ----
    reg [31:0] line_data [0:NUM_LINES-1][0:LINE_WORDS-1];
    reg [TAG_BITS-1:0] tag_array   [0:NUM_LINES-1];
    reg                valid_array [0:NUM_LINES-1];
    reg                dirty_array [0:NUM_LINES-1];

    integer li, lj;

    // ---- Address decode ----
    wire [WORD_BITS-1:0] word_addr = addr[2+WORD_BITS-1:2];
    wire [OFFSET_BITS-1:0] offset  = word_addr[OFFSET_BITS-1:0];
    wire [INDEX_BITS-1:0]  index   = word_addr[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
    wire [TAG_BITS-1:0]    tag     = word_addr[WORD_BITS-1:OFFSET_BITS+INDEX_BITS];

    wire hit = valid_array[index] && (tag_array[index] == tag);

    // ---- FSM ----
    localparam IDLE      = 3'd0,
               WRITEBACK = 3'd1,
               FILL_REQ  = 3'd2,
               FILL_WAIT = 3'd3,
               APPLY_WR  = 3'd4;

    reg [2:0] state;
    reg [OFFSET_BITS:0] wb_cnt;    // one extra bit: counts 0..LINE_WORDS
    reg [OFFSET_BITS:0] fill_cnt;
    reg [TAG_BITS-1:0]  evict_tag;
    reg [INDEX_BITS-1:0] req_index;
    reg [TAG_BITS-1:0]   req_tag;
    reg [OFFSET_BITS-1:0] req_offset;
    reg pending_we;
    reg [31:0] pending_wdata;
    reg [3:0]  pending_wstrb;

// Add near dcache's other state registers:
    reg just_completed;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            ready <= 1'b0;
            ram_we <= 1'b0;
            just_completed <= 1'b0;
            for (li = 0; li < NUM_LINES; li = li + 1) begin
                valid_array[li] <= 1'b0;
                dirty_array[li] <= 1'b0;
            end
        end else begin
            ready  <= 1'b0;
            ram_we <= 1'b0;
            just_completed <= 1'b0;   // NEW -- default every cycle
    
            case (state)
                IDLE: begin
                    // FIXED: don't service a NEW request on the exact cycle
                    // right after completing one -- the bridge holds we/re
                    // asserted for one extra cycle after ready first appears
                    // (it only drops them the cycle after seeing ready), and
                    // without this guard, IDLE sees the still-asserted
                    // we/re, finds the line now valid (just filled), and
                    // fires a spurious second "hit" completion for what is
                    // actually the SAME already-serviced request.
                    if (just_completed) begin
                        // wait one cycle for we/re to genuinely drop
                    end
                    else if (we || re) begin
                        req_index  <= index;
                        req_tag    <= tag;
                        req_offset <= offset;
                        pending_we    <= we;
                        pending_wdata <= wdata;
                        pending_wstrb <= wstrb;
    
                        if (hit) begin
                            if (re) begin
                                rdata <= line_data[index][offset];
                                ready <= 1'b1;
                                just_completed <= 1'b1;   // NEW
                            end else begin
                                if (wstrb[0]) line_data[index][offset][7:0]   <= wdata[7:0];
                                if (wstrb[1]) line_data[index][offset][15:8]  <= wdata[15:8];
                                if (wstrb[2]) line_data[index][offset][23:16] <= wdata[23:16];
                                if (wstrb[3]) line_data[index][offset][31:24] <= wdata[31:24];
                                dirty_array[index] <= 1'b1;
                                ready <= 1'b1;
                                just_completed <= 1'b1;   // NEW
                            end
                        end else begin
                            evict_tag <= tag_array[index];
                            if (valid_array[index] && dirty_array[index]) begin
                                wb_cnt <= 0;
                                state  <= WRITEBACK;
                            end else begin
                                fill_cnt <= 0;
                                state    <= FILL_REQ;
                            end
                        end
                    end
                end
    
                WRITEBACK: begin
                    ram_addr  <= {evict_tag, req_index, wb_cnt[OFFSET_BITS-1:0]};
                    ram_wdata <= line_data[req_index][wb_cnt[OFFSET_BITS-1:0]];
                    ram_we    <= 1'b1;
                    if (wb_cnt == LINE_WORDS-1) begin
                        fill_cnt <= 0;
                        state    <= FILL_REQ;
                    end else begin
                        wb_cnt <= wb_cnt + 1;
                    end
                end
    
                FILL_REQ: begin
                    ram_addr <= {req_tag, req_index, fill_cnt[OFFSET_BITS-1:0]};
                    state    <= FILL_WAIT;
                end
    
                FILL_WAIT: begin
                    line_data[req_index][fill_cnt[OFFSET_BITS-1:0]] <= ram_rdata;
                    if (fill_cnt == LINE_WORDS-1) begin
                        tag_array[req_index]   <= req_tag;
                        valid_array[req_index] <= 1'b1;
                        dirty_array[req_index] <= 1'b0;
                        if (pending_we) begin
                            state <= APPLY_WR;
                        end else begin
                            rdata <= (fill_cnt[OFFSET_BITS-1:0] == req_offset) ? ram_rdata : line_data[req_index][req_offset];
                            ready <= 1'b1;
                            just_completed <= 1'b1;   // NEW
                            state <= IDLE;
                        end
                    end else begin
                        fill_cnt <= fill_cnt + 1;
                        state    <= FILL_REQ;
                    end
                end
    
                APPLY_WR: begin
                    if (pending_wstrb[0]) line_data[req_index][req_offset][7:0]   <= pending_wdata[7:0];
                    if (pending_wstrb[1]) line_data[req_index][req_offset][15:8]  <= pending_wdata[15:8];
                    if (pending_wstrb[2]) line_data[req_index][req_offset][23:16] <= pending_wdata[23:16];
                    if (pending_wstrb[3]) line_data[req_index][req_offset][31:24] <= pending_wdata[31:24];
                    dirty_array[req_index] <= 1'b1;
                    ready <= 1'b1;
                    just_completed <= 1'b1;   // NEW
                    state <= IDLE;
                end
    
                default: state <= IDLE;
            endcase
        end
    end

endmodule