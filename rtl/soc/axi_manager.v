`timescale 1ns/1ps

module axi_manager (
    input         clk,
    input         resetn,

    // Core-side simple memory interface
    input  [31:0]  mem_addr,
    input  [31:0]  mem_wdata,
    input  [3:0]  mem_wstrb,
    input         mem_we,
    input         mem_re,

    output reg [31:0] mem_rdata,
    output reg        mem_ready,

    // AXI4-Lite master write address
    output reg [31:0] axi_awaddr,
    output reg        axi_awvalid,
    input              axi_awready,

    // AXI4-Lite master write data
    output reg [31:0] axi_wdata,
    output reg [3:0]  axi_wstrb,
    output reg        axi_wvalid,
    input              axi_wready,

    // AXI4-Lite write response
    input  [1:0]       axi_bresp,
    input              axi_bvalid,
    output reg         axi_bready,

    // AXI4-Lite master read address
    output reg [31:0] axi_araddr,
    output reg        axi_arvalid,
    input              axi_arready,

    // AXI4-Lite read data
    input  [31:0]      axi_rdata,
    input  [1:0]       axi_rresp,
    input              axi_rvalid,
    output reg         axi_rready
);

    localparam IDLE         = 3'd0;
    localparam WRITE_ADDR   = 3'd1;
    localparam WRITE_RESP   = 3'd2;
    localparam READ_ADDR    = 3'd3;
    localparam READ_DATA    = 3'd4;
    localparam READ_CAPTURE = 3'd5;
    localparam READ_COMPLETE= 3'd6;

    reg [2:0] state;
    reg just_completed;   // NEW -- see IDLE state comment below

    // FIXED: was `posedge clk or posedge resetn`, which only reset the
    // flip-flops at the moment resetn was RELEASED (rising edge), never
    // when reset was actually ASSERTED (resetn falling). Active-low
    // async reset needs `negedge resetn` here.
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state       <= IDLE;

            axi_awaddr  <= 32'd0;
            axi_awvalid <= 1'b0;

            axi_wdata   <= 32'd0;
            axi_wstrb   <= 4'd0;
            axi_wvalid  <= 1'b0;

            axi_bready  <= 1'b0;

            axi_araddr  <= 32'd0;
            axi_arvalid <= 1'b0;

            axi_rready  <= 1'b0;

            mem_rdata   <= 32'd0;
            mem_ready   <= 1'b0;
            just_completed <= 1'b0;
        end
        else begin

            // IMPORTANT:
            // mem_ready is a one-cycle completion pulse.
            // Default LOW every cycle.
            mem_ready <= 1'b0;
            just_completed <= 1'b0;

            case (state)

                // =========================================================
                // IDLE
                // =========================================================
                IDLE: begin
                    axi_awvalid <= 1'b0;
                    axi_wvalid  <= 1'b0;
                    axi_bready  <= 1'b0;

                    axi_arvalid <= 1'b0;
                    axi_rready  <= 1'b0;

                    // FIXED: on the exact cycle a transaction just
                    // completed (mem_ready pulsed last cycle), the
                    // core's mem_we/mem_re still reflect the OLD
                    // instruction -- exmem0 only presents the NEXT
                    // instruction's values starting the FOLLOWING
                    // cycle. Without this guard, IDLE would spuriously
                    // re-trigger a transaction using stale mem_we/mem_re,
                    // desyncing this FSM from the pipeline.
                    if (just_completed) begin
                        // wait one cycle for fresh mem_we/mem_re
                    end
                    else if (mem_we) begin
                        // Start AXI write
                        axi_awaddr  <= mem_addr;
                        axi_awvalid <= 1'b1;

                        axi_wdata   <= mem_wdata;
                        axi_wstrb   <= mem_wstrb;
                        axi_wvalid  <= 1'b1;

                        state <= WRITE_ADDR;
                    end
                    else if (mem_re) begin
                        // Start AXI read
                        axi_araddr  <= mem_addr;
                        axi_arvalid <= 1'b1;

                        state <= READ_ADDR;
                    end
                end

                // =========================================================
                // WRITE ADDRESS / DATA
                // =========================================================
                WRITE_ADDR: begin

                    // Address accepted
                    if (axi_awvalid && axi_awready)
                        axi_awvalid <= 1'b0;

                    // Data accepted
                    if (axi_wvalid && axi_wready)
                        axi_wvalid <= 1'b0;

                    // Both channels accepted
                    if ((!axi_awvalid || axi_awready) &&
                        (!axi_wvalid  || axi_wready)) begin

                        axi_bready <= 1'b1;
                        state      <= WRITE_RESP;
                    end
                end

                // =========================================================
                // WRITE RESPONSE
                // =========================================================
                WRITE_RESP: begin
                    if (axi_bvalid) begin
                        axi_bready <= 1'b0;

                        // Write transaction completed
                        mem_ready <= 1'b1;
                        just_completed <= 1'b1;   // NEW

                        state <= IDLE;
                    end
                end

                // =========================================================
                // READ ADDRESS
                // =========================================================
                READ_ADDR: begin
                    if (axi_arvalid && axi_arready) begin
                        axi_arvalid <= 1'b0;
                        state       <= READ_DATA;
                    end
                end

                // =========================================================
                // WAIT FOR READ DATA
                // =========================================================
                READ_DATA: begin
                    if (axi_rvalid) begin
                        state <= READ_CAPTURE;
                    end
                end

                // =========================================================
                // CAPTURE AXI READ DATA
                // =========================================================
                READ_CAPTURE: begin
                    // Capture the AXI response
                    mem_rdata <= axi_rdata;

                    // Accept the AXI response
                    axi_rready <= 1'b1;

                    state <= READ_COMPLETE;
                end

                // =========================================================
                // COMPLETE READ
                // =========================================================
                READ_COMPLETE: begin
                    // Data is now registered in mem_rdata.
                    // Generate exactly one completion pulse.
                    mem_ready  <= 1'b1;
                    just_completed <= 1'b1;   // NEW
                    axi_rready <= 1'b0;

                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule