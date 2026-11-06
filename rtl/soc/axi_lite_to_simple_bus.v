`timescale 1ns/1ps

module axi_lite_to_simple_bus #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input clk,
    input resetn,

    input  [ADDR_WIDTH-1:0] axi_awaddr,
    input                   axi_awvalid,
    output reg              axi_awready,

    input  [DATA_WIDTH-1:0] axi_wdata,
    input  [3:0]            axi_wstrb,
    input                   axi_wvalid,
    output reg              axi_wready,

    output reg [1:0]        axi_bresp,
    output reg              axi_bvalid,
    input                   axi_bready,

    input  [ADDR_WIDTH-1:0] axi_araddr,
    input                   axi_arvalid,
    output reg              axi_arready,

    output reg [DATA_WIDTH-1:0] axi_rdata,
    output reg [1:0]        axi_rresp,
    output reg              axi_rvalid,
    input                   axi_rready,

    output reg [ADDR_WIDTH-1:0] mem_addr,
    output reg [DATA_WIDTH-1:0] mem_wdata,
    output reg [3:0]            mem_wstrb,
    output reg                  mem_we,
    output reg                  mem_re,
    input      [DATA_WIDTH-1:0] mem_rdata,

    output reg [ADDR_WIDTH-1:0] gpio_addr,
    output reg [DATA_WIDTH-1:0] gpio_wdata,
    output reg                  gpio_we,
    input      [DATA_WIDTH-1:0] gpio_rdata,

    output reg [ADDR_WIDTH-1:0] timer_addr,
    output reg [DATA_WIDTH-1:0] timer_wdata,
    output reg                  timer_we,
    input      [DATA_WIDTH-1:0] timer_rdata,

    output reg [ADDR_WIDTH-1:0] uart_addr,
    output reg [DATA_WIDTH-1:0] uart_wdata,
    output reg                  uart_we,
    output reg                  uart_re,
    input      [DATA_WIDTH-1:0] uart_rdata
);

    localparam SEL_MEM   = 3'b000;
    localparam SEL_GPIO  = 3'b001;
    localparam SEL_UART  = 3'b010;
    localparam SEL_TIMER = 3'b011;
    localparam SEL_NONE  = 3'b111;

    wire [2:0] wsel = (axi_awaddr[31:28] == 4'h0)      ? SEL_MEM :
                       (axi_awaddr[31:12] == 20'h10000)  ? SEL_GPIO :
                       (axi_awaddr[31:12] == 20'h10001)  ? SEL_UART :
                       (axi_awaddr[31:12] == 20'h10002)  ? SEL_TIMER : SEL_NONE;
    wire [2:0] rsel = (axi_araddr[31:28] == 4'h0)      ? SEL_MEM :
                       (axi_araddr[31:12] == 20'h10000)  ? SEL_GPIO :
                       (axi_araddr[31:12] == 20'h10001)  ? SEL_UART :
                       (axi_araddr[31:12] == 20'h10002)  ? SEL_TIMER : SEL_NONE;

    localparam W_IDLE   = 2'b00;
    localparam W_ACCESS = 2'b01;
    localparam W_RESP   = 2'b10;

    reg [1:0] wstate;
    reg aw_done;
    reg w_done;
    reg [2:0] wsel_latched;
    reg [ADDR_WIDTH-1:0] awaddr_latched;
    reg [DATA_WIDTH-1:0] wdata_latched;
    reg [3:0]            wstrb_latched;

    localparam R_IDLE   = 2'b00;
    localparam R_ACCESS = 2'b01;
    localparam R_RESP   = 2'b10;

    reg [1:0] rstate;
    reg [2:0] rsel_latched;
    reg [ADDR_WIDTH-1:0] araddr_latched_r;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            wstate         <= W_IDLE;
            aw_done        <= 1'b0;
            w_done         <= 1'b0;
            wsel_latched   <= SEL_NONE;
            awaddr_latched <= {ADDR_WIDTH{1'b0}};
            wdata_latched  <= {DATA_WIDTH{1'b0}};
            wstrb_latched  <= 4'h0;
            axi_awready    <= 1'b0;
            axi_wready     <= 1'b0;
            axi_bvalid     <= 1'b0;
            axi_bresp      <= 2'b00;
        end else begin
            case (wstate)
                W_IDLE: begin
                    axi_bvalid <= 1'b0;

                    if (rstate == R_IDLE) begin
                        axi_awready <= 1'b1;
                        axi_wready  <= 1'b1;
                    end else begin
                        axi_awready <= 1'b0;
                        axi_wready  <= 1'b0;
                    end

                    if (axi_awvalid && axi_awready) begin
                        awaddr_latched <= axi_awaddr;
                        wsel_latched   <= wsel;
                        aw_done        <= 1'b1;
                    end
                    if (axi_wvalid && axi_wready) begin
                        wdata_latched <= axi_wdata;
                        wstrb_latched <= axi_wstrb;
                        w_done        <= 1'b1;
                    end

                    if ((aw_done || (axi_awvalid && axi_awready)) &&
                        (w_done  || (axi_wvalid  && axi_wready))) begin
                        axi_awready <= 1'b0;
                        axi_wready  <= 1'b0;
                        aw_done <= 1'b0;
                        w_done  <= 1'b0;
                        wstate  <= W_ACCESS;
                    end
                end

                W_ACCESS: begin
                    axi_bresp  <= (wsel_latched == SEL_NONE) ? 2'b11 : 2'b00;
                    axi_bvalid <= 1'b1;
                    wstate     <= W_RESP;
                end

                W_RESP: begin
                    axi_awready <= 1'b0;
                    axi_wready  <= 1'b0;
                    if (axi_bready) begin
                        axi_bvalid <= 1'b0;
                        wstate <= W_IDLE;
                    end
                end

                default: wstate <= W_IDLE;
            endcase
        end
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            rstate           <= R_IDLE;
            rsel_latched     <= SEL_NONE;
            araddr_latched_r <= {ADDR_WIDTH{1'b0}};
            axi_arready      <= 1'b0;
            axi_rvalid       <= 1'b0;
            axi_rresp        <= 2'b00;
            axi_rdata        <= {DATA_WIDTH{1'b0}};
        end else begin
            case (rstate)
                R_IDLE: begin
                    axi_rvalid <= 1'b0;

                    if ((wstate == W_IDLE) && !aw_done && !w_done) begin
                        axi_arready <= 1'b1;
                    end else begin
                        axi_arready <= 1'b0;
                    end

                    // FIXED: araddr_latched_r is now captured HERE, in the
                    // same block/edge as rsel_latched -- previously it
                    // lived in a separate always block that (due to
                    // simulator evaluation order between two blocks
                    // triggered by the same edge) ended up one cycle
                    // stale relative to rstate entering R_ACCESS, so the
                    // peripheral's combinational read saw the WRONG
                    // address on the one cycle R_ACCESS actually used it.
                    if (axi_arvalid && axi_arready) begin
                        rsel_latched     <= rsel;
                        araddr_latched_r <= axi_araddr;
                        axi_arready      <= 1'b0;
                        rstate           <= R_ACCESS;
                    end
                end

                R_ACCESS: begin
                    rstate <= R_RESP;
                end

                R_RESP: begin
                    case (rsel_latched)
                        SEL_MEM:   axi_rdata <= mem_rdata;
                        SEL_GPIO:  axi_rdata <= gpio_rdata;
                        SEL_UART:  axi_rdata <= uart_rdata;
                        SEL_TIMER: axi_rdata <= timer_rdata;
                        default:   axi_rdata <= {DATA_WIDTH{1'b0}};
                    endcase
                    axi_rresp  <= (rsel_latched == SEL_NONE) ? 2'b11 : 2'b00;
                    axi_rvalid <= 1'b1;

                    if (axi_rready) begin
                        axi_rvalid  <= 1'b0;
                        axi_arready <= 1'b1;
                        rstate <= R_IDLE;
                    end
                end

                default: rstate <= R_IDLE;
            endcase
        end
    end

    // Combinational address/control output to peripherals.
    always @(*) begin
        mem_addr = {ADDR_WIDTH{1'b0}}; mem_wdata = {DATA_WIDTH{1'b0}};
        mem_wstrb = 4'h0; mem_we = 1'b0; mem_re = 1'b0;
        gpio_addr = {ADDR_WIDTH{1'b0}}; gpio_wdata = {DATA_WIDTH{1'b0}}; gpio_we = 1'b0;
        uart_addr = {ADDR_WIDTH{1'b0}}; uart_wdata = {DATA_WIDTH{1'b0}}; uart_we = 1'b0; uart_re = 1'b0;
        timer_addr = {ADDR_WIDTH{1'b0}}; timer_wdata = {DATA_WIDTH{1'b0}}; timer_we = 1'b0;

        if (wstate == W_ACCESS) begin
            case (wsel_latched)
                SEL_MEM: begin
                    mem_addr = awaddr_latched; mem_wdata = wdata_latched;
                    mem_wstrb = wstrb_latched; mem_we = 1'b1;
                end
                SEL_GPIO: begin
                    gpio_addr = awaddr_latched; gpio_wdata = wdata_latched; gpio_we = 1'b1;
                end
                SEL_UART: begin
                    uart_addr = awaddr_latched; uart_wdata = wdata_latched; uart_we = 1'b1;
                end
                SEL_TIMER: begin
                    timer_addr = awaddr_latched; timer_wdata = wdata_latched; timer_we = 1'b1;
                end
                default: ;
            endcase
        end
        else if (rstate == R_ACCESS || rstate == R_RESP) begin
            case (rsel_latched)
                SEL_MEM:   begin mem_addr = araddr_latched_r; mem_re = (rstate == R_ACCESS); end
                SEL_GPIO:  gpio_addr = araddr_latched_r;
                SEL_UART:  begin uart_addr = araddr_latched_r; uart_re = (rstate == R_ACCESS); end
                SEL_TIMER: timer_addr = araddr_latched_r;
                default: ;
            endcase
        end
    end

endmodule