interface axi_lite_if (
  input logic        clk,
  input logic        resetn,
  input logic [31:0] awaddr,
  input logic        awvalid,
  input logic        awready,
  input logic [31:0] wdata,
  input logic [3:0]  wstrb,
  input logic        wvalid,
  input logic        wready,
  input logic [1:0]  bresp,
  input logic        bvalid,
  input logic        bready,
  input logic [31:0] araddr,
  input logic        arvalid,
  input logic        arready,
  input logic [31:0] rdata,
  input logic [1:0]  rresp,
  input logic        rvalid,
  input logic        rready
);

  clocking mon_cb @(posedge clk);
    default input #1step;
    input awaddr, awvalid, awready;
    input wdata, wstrb, wvalid, wready;
    input bresp, bvalid, bready;
    input araddr, arvalid, arready;
    input rdata, rresp, rvalid, rready;
  endclocking

  modport MON (clocking mon_cb, input clk, resetn);

endinterface : axi_lite_if