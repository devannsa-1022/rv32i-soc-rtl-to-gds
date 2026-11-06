`timescale 1ns/1ps

module tb_rv32i_core;

    reg clk = 0;
    reg reset = 1;
    reg [31:0] gpio_in = 32'h0;
    wire [31:0] gpio_out;
    wire timer_irq;
    wire uart_tx;
    reg  uart_rx = 1'b1;   // idle high

    rv32i_soc #(
        .CLK_FREQ(1000),
        .BAUD_RATE(100)
    ) dut (
        .clk(clk),
        .reset(reset),
        .gpio_out(gpio_out),
        .gpio_in(gpio_in),
        .timer_irq(timer_irq),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .imem_load_we(1'b0),
        .imem_load_addr(8'h00),
        .imem_load_data(32'h0)
    );

    always #5 clk = ~clk;

    integer errors = 0;

    task check(input [4:0] reg_num, input [31:0] expected);
        begin
            if (dut.core0.rf0.reg_filex[reg_num] !== expected) begin
                $display("FAIL: x%0d = %0d (0x%08h), expected %0d (0x%08h)",
                          reg_num, dut.core0.rf0.reg_filex[reg_num], dut.core0.rf0.reg_filex[reg_num],
                          expected, expected);
                errors = errors + 1;
            end else begin
                $display("PASS: x%0d = %0d", reg_num, dut.core0.rf0.reg_filex[reg_num]);
            end
        end
    endtask

    task check_gpio(input [31:0] expected);
        begin
            if (gpio_out !== expected) begin
                $display("FAIL: gpio_out = 0x%08h, expected 0x%08h", gpio_out, expected);
                errors = errors + 1;
            end else begin
                $display("PASS: gpio_out = 0x%08h", gpio_out);
            end
        end
    endtask

    // ---- Concurrent timer_irq monitor ----
    reg timer_irq_seen = 1'b0;
    reg [31:0] timer_irq_counter_val;
    reg timer_irq_pulse_ok = 1'b0;

    initial begin
        forever begin
            @(posedge clk);
            if (timer_irq && !timer_irq_seen) begin
                timer_irq_seen        = 1'b1;
                timer_irq_counter_val = dut.timer0.counter;
                @(posedge clk);
                timer_irq_pulse_ok = (timer_irq === 1'b0);
            end
        end
    end

    // ---- Concurrent UART TX frame capture ----
    localparam BIT_NS = 100;
    reg [9:0] captured_frame;
    integer i;
    reg uart_frame_captured = 1'b0;

    initial begin
        wait (uart_tx === 1'b0);
        #(BIT_NS/2);
        for (i = 0; i < 10; i = i + 1) begin
            captured_frame[i] = uart_tx;
            #(BIT_NS);
        end
        uart_frame_captured = 1'b1;
    end

    task check_uart_byte(input [7:0] expected);
        reg [7:0] got;
        begin
            got = captured_frame[8:1];
            if (captured_frame[0] !== 1'b0) begin
                $display("FAIL: UART start bit = %b, expected 0", captured_frame[0]);
                errors = errors + 1;
            end else if (captured_frame[9] !== 1'b1) begin
                $display("FAIL: UART stop bit = %b, expected 1", captured_frame[9]);
                errors = errors + 1;
            end else if (got !== expected) begin
                $display("FAIL: UART byte = 0x%02h, expected 0x%02h", got, expected);
                errors = errors + 1;
            end else begin
                $display("PASS: UART byte = 0x%02h", got);
            end
        end
    endtask

    // ---- Concurrent UART RX driver ----
    // Sends a byte over uart_rx independently of the core's timing -- the
    // core's poll loop (lw STATUS / andi / beq) will catch it whenever it
    // actually arrives, regardless of exactly when polling started.
    task send_uart_byte(input [7:0] data);
        integer j;
        begin
            uart_rx = 1'b0;              // start bit
            #(BIT_NS);
            for (j = 0; j < 8; j = j + 1) begin
                uart_rx = data[j];       // LSB first
                #(BIT_NS);
            end
            uart_rx = 1'b1;              // stop bit
            #(BIT_NS);
        end
    endtask

    initial begin
        @(negedge reset);
        #(BIT_NS);
        send_uart_byte(8'h55);
    end

    initial begin
        reset = 1;
        repeat(3) @(posedge clk);
        @(negedge clk);
        reset = 0;

        // Diagnostic trace window -- shorter now, just for visibility
        // early in the run; the actual program-completion wait below is
        // what gates the checks, not this fixed count.
        

        // Bounded wait for the program to actually reach its halt loop
        // (0x5C) -- the RX poll loop's length depends on when the byte
        // arrives, so a fixed cycle count isn't reliable here.
        begin : wait_for_halt
            integer halt_timeout;
            halt_timeout = 0;
            while (dut.core0.pc_out !== 32'h0000005C && halt_timeout < 1000) begin
                @(posedge clk);
                halt_timeout = halt_timeout + 1;
            end
            if (dut.core0.pc_out !== 32'h0000005C) begin
                $display("FAIL: program did not reach halt loop (pc=%h) within timeout", dut.core0.pc_out);
                errors = errors + 1;
            end
        end

        $display("---- Checking final register state ----");
        check(1, 5);
        check(2, 10);
        check(3, 10);
        check(4, 15);
        check(5, 32'h10000000);
        check(6, 1);
        check(7, 32'h0000002A);
        check(8, 32'h10002000);
        check(9, 5);
        check(10, 1);
        check(11, 32'h0000002A);
        check(12, 32'h10001000);
        check(13, 32'h00000041);
        check(16, 32'h00000002);
        check(17, 32'h00000055);

        $display("---- Checking peripheral state ----");
        check_gpio(32'h0000002A);

        $display("---- Checking timer interrupt ----");
        if (!timer_irq_seen) begin
            $display("FAIL: timer_irq never observed during simulation");
            errors = errors + 1;
        end else if (timer_irq_counter_val !== dut.timer0.compare) begin
            $display("FAIL: timer_irq asserted but counter(%0d) != compare(%0d)",
                      timer_irq_counter_val, dut.timer0.compare);
            errors = errors + 1;
        end else if (!timer_irq_pulse_ok) begin
            $display("FAIL: timer_irq did not deassert the cycle after asserting");
            errors = errors + 1;
        end else begin
            $display("PASS: timer_irq pulsed correctly at counter=%0d", timer_irq_counter_val);
        end

        $display("---- Checking UART TX frame ----");
        begin : uart_wait
            integer uart_timeout;
            uart_timeout = 0;
            while (!uart_frame_captured && uart_timeout < 400) begin
                @(posedge clk);
                uart_timeout = uart_timeout + 1;
            end
        end
        if (!uart_frame_captured) begin
            $display("FAIL: UART frame not captured during simulation");
            errors = errors + 1;
        end else begin
            check_uart_byte(8'h41);
        end

        if (errors == 0) $display("ALL TESTS PASSED");
        else $display("%0d TEST(S) FAILED", errors);
        $finish;
    end

endmodule