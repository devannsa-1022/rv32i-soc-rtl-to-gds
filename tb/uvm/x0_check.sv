`timescale 1ns/1ps

module x0_check(input clk, input [31:0] x0_val);
    property p_x0_always_zero;
        @(posedge clk) x0_val == 32'h0;
    endproperty
    assert property (p_x0_always_zero)
        else $error("x0 register corrupted: %0d", x0_val);
endmodule

bind reg_file x0_check x0chk(.clk(clk), .x0_val(reg_filex[0]));