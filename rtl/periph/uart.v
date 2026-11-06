`timescale 1ns/1ps

// Simple memory-mapped UART: 8-N-1 framing, no FIFO (single-byte TX/RX).
//   0x00 TX_DATA (write-only): writing triggers transmission of wdata[7:0]
//   0x04 RX_DATA (read-only):  most recently received byte
//   0x08 STATUS   (read-only): bit0 = tx_busy, bit1 = rx_valid (cleared on RX_DATA read)
module uart #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115_200
)(
    input         clk,
    input         reset,

    input  [31:0] addr,
    input  [31:0] wdata,
    input         we,
    input         re,          // needed to clear rx_valid on RX_DATA read
    output reg [31:0] rdata,

    output        uart_tx,
    input         uart_rx
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam CNT_WIDTH = $clog2(CLKS_PER_BIT);

    // ---------------- TX ----------------
    localparam TX_IDLE = 2'd0, TX_START = 2'd1, TX_DATA_ST = 2'd2, TX_STOP = 2'd3;
    reg [1:0] tx_state;
    reg [CNT_WIDTH-1:0] tx_clk_cnt;
    reg [2:0] tx_bit_idx;
    reg [7:0] tx_shift;
    reg tx_line;
    wire tx_busy = (tx_state != TX_IDLE);

    assign uart_tx = tx_line;

    always @(posedge clk) begin
        if (reset) begin
            tx_state   <= TX_IDLE;
            tx_line    <= 1'b1;   // idle high
            tx_clk_cnt <= 0;
            tx_bit_idx <= 0;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    tx_line <= 1'b1;
                    if (we && addr[3:0] == 4'h0) begin
                        tx_shift   <= wdata[7:0];
                        tx_state   <= TX_START;
                        tx_clk_cnt <= 0;
                    end
                end
                TX_START: begin
                    tx_line <= 1'b0;   // start bit
                    if (tx_clk_cnt < CLKS_PER_BIT-1) begin
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end else begin
                        tx_clk_cnt <= 0;
                        tx_bit_idx <= 0;
                        tx_state   <= TX_DATA_ST;
                    end
                end
                TX_DATA_ST: begin
                    tx_line <= tx_shift[tx_bit_idx];
                    if (tx_clk_cnt < CLKS_PER_BIT-1) begin
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end else begin
                        tx_clk_cnt <= 0;
                        if (tx_bit_idx < 7) begin
                            tx_bit_idx <= tx_bit_idx + 1;
                        end else begin
                            tx_state <= TX_STOP;
                        end
                    end
                end
                TX_STOP: begin
                    tx_line <= 1'b1;   // stop bit
                    if (tx_clk_cnt < CLKS_PER_BIT-1) begin
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end else begin
                        tx_clk_cnt <= 0;
                        tx_state   <= TX_IDLE;
                    end
                end
                default: tx_state <= TX_IDLE;
            endcase
        end
    end

    // ---------------- RX ----------------
    localparam RX_IDLE = 2'd0, RX_START = 2'd1, RX_DATA_ST = 2'd2, RX_STOP = 2'd3;
    reg [1:0] rx_state;
    reg [CNT_WIDTH-1:0] rx_clk_cnt;
    reg [2:0] rx_bit_idx;
    reg [7:0] rx_shift;
    reg [7:0] rx_data;
    reg rx_valid;
    reg uart_rx_sync1, uart_rx_sync2;   // 2-FF synchronizer

    always @(posedge clk) begin
        if (reset) begin
            uart_rx_sync1 <= 1'b1;
            uart_rx_sync2 <= 1'b1;
        end else begin
            uart_rx_sync1 <= uart_rx;
            uart_rx_sync2 <= uart_rx_sync1;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            rx_state   <= RX_IDLE;
            rx_clk_cnt <= 0;
            rx_bit_idx <= 0;
            rx_valid   <= 1'b0;
        end else begin
            // clear rx_valid when STATUS or RX_DATA is read, whichever
            // convention you prefer -- here, reading RX_DATA clears it
            if (re && addr[3:0] == 4'h4) rx_valid <= 1'b0;

            case (rx_state)
                RX_IDLE: begin
                    if (uart_rx_sync2 == 1'b0) begin   // start bit detected
                        rx_state   <= RX_START;
                        rx_clk_cnt <= 0;
                    end
                end
                RX_START: begin
                    // sample at mid-bit to confirm still low
                    if (rx_clk_cnt < (CLKS_PER_BIT/2)-1) begin
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end else begin
                        rx_clk_cnt <= 0;
                        if (uart_rx_sync2 == 1'b0) begin
                            rx_state   <= RX_DATA_ST;
                            rx_bit_idx <= 0;
                        end else begin
                            rx_state <= RX_IDLE;   // false start
                        end
                    end
                end
                RX_DATA_ST: begin
                    if (rx_clk_cnt < CLKS_PER_BIT-1) begin
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end else begin
                        rx_clk_cnt <= 0;
                        rx_shift[rx_bit_idx] <= uart_rx_sync2;
                        if (rx_bit_idx < 7) begin
                            rx_bit_idx <= rx_bit_idx + 1;
                        end else begin
                            rx_state <= RX_STOP;
                        end
                    end
                end
                RX_STOP: begin
                    if (rx_clk_cnt < CLKS_PER_BIT-1) begin
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end else begin
                        rx_clk_cnt <= 0;
                        rx_data  <= rx_shift;
                        rx_valid <= 1'b1;
                        rx_state <= RX_IDLE;
                    end
                end
                default: rx_state <= RX_IDLE;
            endcase
        end
    end

    // ---------------- Register read mux ----------------
    always @(*) begin
        case (addr[3:0])
            4'h4:    rdata = {24'h0, rx_data};
            4'h8:    rdata = {30'h0, rx_valid, tx_busy};
            default: rdata = 32'h0;
        endcase
    end

endmodule