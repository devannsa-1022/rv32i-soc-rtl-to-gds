`timescale 1ns/1ps

// Checks the instruction-memory program-load port. Two SoCs run the same
// program with identical stimulus:
//   ref_soc  - image preloaded from +PROGRAM (default program.hex)
//   load_soc - image zeroed, then written through imem_load_* during reset
// After reset, PC and every register must match on every cycle.
module tb_imem_load;

    reg clk = 0;
    reg reset = 1;
    always #5 clk = ~clk;

    reg         load_we   = 1'b0;
    reg  [7:0]  load_addr = 8'h00;
    reg  [31:0] load_data = 32'h0;

    wire [31:0] gpio_out_ref, gpio_out_ld;
    wire        irq_ref, irq_ld, tx_ref, tx_ld;

    rv32i_soc #(.CLK_FREQ(1000), .BAUD_RATE(100)) ref_soc (
        .clk(clk), .reset(reset),
        .gpio_out(gpio_out_ref), .gpio_in(32'h0),
        .timer_irq(irq_ref), .uart_tx(tx_ref), .uart_rx(1'b1),
        .imem_load_we(1'b0), .imem_load_addr(8'h00), .imem_load_data(32'h0)
    );

    rv32i_soc #(.CLK_FREQ(1000), .BAUD_RATE(100)) load_soc (
        .clk(clk), .reset(reset),
        .gpio_out(gpio_out_ld), .gpio_in(32'h0),
        .timer_irq(irq_ld), .uart_tx(tx_ld), .uart_rx(1'b1),
        .imem_load_we(load_we), .imem_load_addr(load_addr), .imem_load_data(load_data)
    );

    integer i, cyc, errors = 0;

    initial begin
        // Let instruction_memory's own preload run, then scrub load_soc so
        // only the load port can give it a valid program.
        #1;
        for (i = 0; i < 256; i = i + 1) load_soc.imem0.sram0.mem[i] = 32'h0;

        // Write the reference image through the load port, one word per clock.
        for (i = 0; i < 256; i = i + 1) begin
            @(negedge clk);
            load_we   = 1'b1;
            load_addr = i;
            load_data = ref_soc.imem0.sram0.mem[i];
        end
        @(negedge clk);
        load_we = 1'b0;

        for (i = 0; i < 256; i = i + 1)
            if (load_soc.imem0.sram0.mem[i] !== ref_soc.imem0.sram0.mem[i]) begin
                $display("FAIL: imem[%0d] = %h, expected %h",
                         i, load_soc.imem0.sram0.mem[i], ref_soc.imem0.sram0.mem[i]);
                errors = errors + 1;
            end

        repeat (2) @(negedge clk);
        reset = 0;

        for (cyc = 0; cyc < 1000; cyc = cyc + 1) begin
            @(negedge clk);
            if (load_soc.core0.pc_out !== ref_soc.core0.pc_out) begin
                $display("FAIL: cycle %0d pc = %h, expected %h",
                         cyc, load_soc.core0.pc_out, ref_soc.core0.pc_out);
                errors = errors + 1;
            end
            for (i = 0; i < 32; i = i + 1)
                if (load_soc.core0.rf0.reg_filex[i] !== ref_soc.core0.rf0.reg_filex[i]) begin
                    $display("FAIL: cycle %0d x%0d = %h, expected %h", cyc, i,
                             load_soc.core0.rf0.reg_filex[i], ref_soc.core0.rf0.reg_filex[i]);
                    errors = errors + 1;
                end
            if (errors > 20) cyc = 1000;
        end

        if (errors == 0)
            $display("ALL TESTS PASSED (pc=%h after 1000 cycles)", ref_soc.core0.pc_out);
        else
            $display("%0d CHECK(S) FAILED", errors);
        $finish;
    end

endmodule
