module data_memory (
    input               clk,
    input               reset,
    input        [31:0] addr,
    input        [31:0] write_data,
    input        [3:0]  wstrb,
    input               mem_read,
    input               mem_write,
    output       [31:0] read_data
);
  reg [31:0] mem [0:255];
  integer i;

  initial begin
    for (i = 0; i < 256; i = i + 1) mem[i] = 32'h0;
  end

  always @(posedge clk) begin
    if (mem_write) begin
      if (wstrb[0]) mem[addr[9:2]][7:0]   <= write_data[7:0];
      if (wstrb[1]) mem[addr[9:2]][15:8]  <= write_data[15:8];
      if (wstrb[2]) mem[addr[9:2]][23:16] <= write_data[23:16];
      if (wstrb[3]) mem[addr[9:2]][31:24] <= write_data[31:24];
    end
  end

  assign read_data = mem[addr[9:2]]; // combinational - matches instruction_memory's fix
endmodule