`timescale 1ns/1ps

module tb_cache;

    reg clk = 0;
    reg reset = 1;

    wire [31:0] gpio_out;
    wire timer_irq;
    wire uart_tx;
    reg  uart_rx = 1'b1;

    rv32i_soc dut (
        .clk(clk), .reset(reset),
        .gpio_out(gpio_out), .gpio_in(32'h0),
        .timer_irq(timer_irq),
        .uart_tx(uart_tx), .uart_rx(uart_rx)
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
                $display("PASS: x%0d = 0x%08h", reg_num, dut.core0.rf0.reg_filex[reg_num]);
            end
        end
    endtask

    task check_ram_word(input [7:0] idx, input [31:0] expected);
        begin
            if (dut.uram0.mem[idx] !== expected) begin
                $display("FAIL: RAM[%0d] = 0x%08h, expected 0x%08h", idx, dut.uram0.mem[idx], expected);
                errors = errors + 1;
            end else begin
                $display("PASS: RAM[%0d] = 0x%08h", idx, dut.uram0.mem[idx]);
            end
        end
    endtask

    initial begin
        reset = 1;
        repeat(3) @(posedge clk);
        @(negedge clk);
        reset = 0;

        // Diagnostic trace: covers lw x10 (pc=0x38) through lw x13 (pc=0x48)
        // and a margin beyond, to see the full read-miss/hit sequence.
        repeat(400) begin
            @(posedge clk);
            if (dut.core0.pc_out >= 32'h00000034 && dut.core0.pc_out <= 32'h00000050) begin
                $display("t=%0t | mgr_state=%0d mem_re=%b mem_addr=%h mem_ready=%b | dcache_state=%0d dcache_ready=%b dcache_rdata=%h | bridge_rstate=%0d | exmem_rd=%0d exmem_mem_enable=%b | core_mem_rdata=%h",
    $time,
    dut.axi_mgr0.state, dut.core_mem_re, dut.core_mem_addr, dut.core_mem_ready,
    dut.dcache0.state, dut.dcache0.ready, dut.dcache0.rdata,
    dut.bridge0.rstate,
    dut.core0.exmem_rd, dut.core0.exmem_mem_enable,
    dut.core_mem_rdata);
            end
        end

        begin : wait_for_halt
            integer t;
            t = 0;
            while (dut.core0.pc_out !== 32'h0000004C && t < 2000) begin
                @(posedge clk);
                t = t + 1;
            end
            if (dut.core0.pc_out !== 32'h0000004C) begin
                $display("FAIL: program did not reach halt (pc=%h)", dut.core0.pc_out);
                errors = errors + 1;
            end
        end

        begin : wait_for_last_wb
            integer t;
            t = 0;
            while (!(dut.core0.memwb_rd == 13 && dut.core0.memwb_werf) && t < 2000) begin
                @(posedge clk);
                t = t + 1;
            end
            if (!(dut.core0.memwb_rd == 13 && dut.core0.memwb_werf)) begin
                $display("FAIL: x13 writeback never observed");
                errors = errors + 1;
            end
        end
        repeat(2) @(posedge clk);

        $display("---- Checking register state ----");
        check(1, 32'h00000011);
        check(2, 32'h00000022);
        check(3, 32'h00000033);
        check(4, 32'h00000044);
        check(5, 32'h00000055);
        check(6, 32'h00000066);
        check(28, 32'h00000000);
        check(29, 32'h00000080);
        check(30, 32'h00000100);
        check(10, 32'h00000011);
        check(11, 32'h00000022);
        check(12, 32'h00000033);
        check(13, 32'h00000044);

        $display("---- Checking write-back landed correctly in RAM ----");
        check_ram_word(0, 32'h00000011);
        check_ram_word(1, 32'h00000022);
        check_ram_word(2, 32'h00000033);
        check_ram_word(3, 32'h00000044);

        if (errors == 0) $display("ALL TESTS PASSED");
        else $display("%0d TEST(S) FAILED", errors);
        $finish;
    end

endmodule