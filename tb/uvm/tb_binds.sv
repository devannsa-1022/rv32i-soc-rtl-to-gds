// tb_binds.sv

bind rv32i_core core_mem_if u_core_mem_if_bind (
  .clk       (clk),
  .reset     (reset),
  .mem_addr  (mem_addr),
  .mem_wdata (mem_wdata),
  .mem_wstrb (mem_wstrb),
  .mem_we    (mem_we),
  .mem_re    (mem_re),
  .mem_rdata (mem_rdata),
  .mem_ready (mem_ready)
);

bind axi_manager axi_lite_if u_axi_lite_if_bind (
  .clk     (clk),
  .resetn  (resetn),
  .awaddr  (axi_awaddr), .awvalid (axi_awvalid), .awready (axi_awready),
  .wdata   (axi_wdata),  .wstrb   (axi_wstrb),   .wvalid  (axi_wvalid),  .wready (axi_wready),
  .bresp   (axi_bresp),  .bvalid  (axi_bvalid),  .bready  (axi_bready),
  .araddr  (axi_araddr), .arvalid (axi_arvalid), .arready (axi_arready),
  .rdata   (axi_rdata),  .rresp   (axi_rresp),   .rvalid  (axi_rvalid),  .rready (axi_rready)
);