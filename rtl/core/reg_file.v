module reg_file(clk,reset,read_address1,read_address2,write_enable,write_address,write_data,read_data1,read_data2);

parameter ad_width = 5,data_width = 32,reg_depth=32;

input	[ad_width-1:0]	read_address1,read_address2,write_address;

input write_enable,clk,reset;

input	[data_width-1:0]	write_data;

output [data_width-1:0]	read_data1,read_data2;

reg	[data_width-1:0]	reg_filex	[reg_depth-1:0];

integer i = 0;

`ifndef SYNTHESIS
// testbench visibility only - real init value on hardware comes from reset below
initial
begin
reg_filex[0] <= 32'h0000_0000;
for(i=1;i<32;i=i+1)
begin
reg_filex[i] <= 16*i;
end
end
`endif

// FIXED: added synchronous reset. Without this, an FPGA has no defined
// way to bring the register file to a known state on power-up/reset -
// the `initial` block above only works in simulation.
always@(posedge clk)
begin
   if(reset)
   begin
	for(i=0;i<32;i=i+1)
	begin
	   reg_filex[i] <= 32'h0000_0000;
	end
   end
   else if(write_enable)
   begin
	reg_filex[write_address] <= write_data;
	reg_filex[0] <= 32'h0000_0000;
   end
end

assign read_data1	=	reg_filex[read_address1];
assign read_data2	=	reg_filex[read_address2];

endmodule