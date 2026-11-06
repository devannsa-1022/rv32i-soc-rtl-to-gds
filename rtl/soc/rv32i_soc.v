`timescale 1ns/1ps

module rv32i_soc(
    input  clk,
    input  reset,

    output [31:0] gpio_out,
    input  [31:0] gpio_in,

    output timer_irq,

    // NEW -- UART pins
    output uart_tx,
    input  uart_rx
);

    wire resetn = ~reset;

    wire [31:0] core_mem_addr, core_mem_wdata, core_mem_rdata;
    wire [3:0]  core_mem_wstrb;
    wire        core_mem_we, core_mem_re;
    wire        core_mem_ready;

    wire [31:0] axi_awaddr, axi_wdata, axi_araddr, axi_rdata;
    wire [3:0]  axi_wstrb;
    wire        axi_awvalid, axi_awready;
    wire        axi_wvalid, axi_wready;
    wire [1:0]  axi_bresp;
    wire        axi_bvalid, axi_bready;
    wire        axi_arvalid, axi_arready;
    wire [1:0]  axi_rresp;
    wire        axi_rvalid, axi_rready;

    wire [31:0] p_mem_addr, p_mem_wdata, p_mem_rdata;
    wire [3:0]  p_mem_wstrb;
    wire        p_mem_we, p_mem_re;

    wire [31:0] p_gpio_addr, p_gpio_wdata, p_gpio_rdata;
    wire        p_gpio_we;

    wire [31:0] p_timer_addr, p_timer_wdata, p_timer_rdata;
    wire        p_timer_we;

    // NEW -- UART peripheral bus
    wire [31:0] p_uart_addr, p_uart_wdata, p_uart_rdata;
    wire        p_uart_we, p_uart_re;

    rv32i_core core0(
        .clk(clk), .reset(reset),
        .mem_addr(core_mem_addr),
        .mem_wdata(core_mem_wdata),
        .mem_wstrb(core_mem_wstrb),
        .mem_we(core_mem_we),
        .mem_re(core_mem_re),
        .mem_rdata(core_mem_rdata),
        .mem_ready(core_mem_ready)
    );

    axi_manager axi_mgr0(
        .clk(clk), .resetn(resetn),
        .mem_addr(core_mem_addr),
        .mem_wdata(core_mem_wdata),
        .mem_wstrb(core_mem_wstrb),
        .mem_we(core_mem_we),
        .mem_re(core_mem_re),
        .mem_rdata(core_mem_rdata),
        .mem_ready(core_mem_ready),

        .axi_awaddr(axi_awaddr), .axi_awvalid(axi_awvalid), .axi_awready(axi_awready),
        .axi_wdata(axi_wdata), .axi_wstrb(axi_wstrb), .axi_wvalid(axi_wvalid), .axi_wready(axi_wready),
        .axi_bresp(axi_bresp), .axi_bvalid(axi_bvalid), .axi_bready(axi_bready),
        .axi_araddr(axi_araddr), .axi_arvalid(axi_arvalid), .axi_arready(axi_arready),
        .axi_rdata(axi_rdata), .axi_rresp(axi_rresp), .axi_rvalid(axi_rvalid), .axi_rready(axi_rready)
    );

    axi_lite_to_simple_bus bridge0(
        .clk(clk), .resetn(resetn),

        .axi_awaddr(axi_awaddr), .axi_awvalid(axi_awvalid), .axi_awready(axi_awready),
        .axi_wdata(axi_wdata), .axi_wstrb(axi_wstrb), .axi_wvalid(axi_wvalid), .axi_wready(axi_wready),
        .axi_bresp(axi_bresp), .axi_bvalid(axi_bvalid), .axi_bready(axi_bready),
        .axi_araddr(axi_araddr), .axi_arvalid(axi_arvalid), .axi_arready(axi_arready),
        .axi_rdata(axi_rdata), .axi_rresp(axi_rresp), .axi_rvalid(axi_rvalid), .axi_rready(axi_rready),

        .mem_addr(p_mem_addr), .mem_wdata(p_mem_wdata), .mem_wstrb(p_mem_wstrb),
        .mem_we(p_mem_we), .mem_re(p_mem_re), .mem_rdata(p_mem_rdata),

        .gpio_addr(p_gpio_addr), .gpio_wdata(p_gpio_wdata), .gpio_we(p_gpio_we), .gpio_rdata(p_gpio_rdata),

        .timer_addr(p_timer_addr), .timer_wdata(p_timer_wdata), .timer_we(p_timer_we), .timer_rdata(p_timer_rdata),

        // NEW
        .uart_addr(p_uart_addr), .uart_wdata(p_uart_wdata),
        .uart_we(p_uart_we), .uart_re(p_uart_re), .uart_rdata(p_uart_rdata)
    );

    data_memory dmem0(
        .clk(clk), .reset(reset),
        .addr(p_mem_addr), .write_data(p_mem_wdata), .wstrb(p_mem_wstrb),
        .mem_read(p_mem_re), .mem_write(p_mem_we),
        .read_data(p_mem_rdata)
    );

    gpio gpio0(
        .clk(clk), .reset(reset),
        .addr(p_gpio_addr), .wdata(p_gpio_wdata), .we(p_gpio_we), .rdata(p_gpio_rdata),
        .gpio_out(gpio_out), .gpio_in(gpio_in)
    );

    timer timer0(
        .clk(clk), .reset(reset),
        .addr(p_timer_addr), .wdata(p_timer_wdata), .we(p_timer_we), .rdata(p_timer_rdata),
        .timer_irq(timer_irq)
    );

    // NEW -- UART, simulation-friendly baud (override for real FPGA build)
    uart #(
        .CLK_FREQ(1000),
        .BAUD_RATE(100)
    ) uart0(
        .clk(clk), .reset(reset),
        .addr(p_uart_addr), .wdata(p_uart_wdata),
        .we(p_uart_we), .re(p_uart_re), .rdata(p_uart_rdata),
        .uart_tx(uart_tx), .uart_rx(uart_rx)
    );

endmodule