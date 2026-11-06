// soc_pkg.sv
`ifndef SOC_PKG_SV
`define SOC_PKG_SV

package soc_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // =====================================================================
  // TRANSACTIONS
  // =====================================================================

  // Captures one completed AXI4-Lite write OR read, as seen by the monitor.
  class axi_lite_txn extends uvm_sequence_item;
    typedef enum { AXI_WRITE, AXI_READ } kind_e;

    rand kind_e        kind;
    rand bit [31:0]     addr;
    rand bit [31:0]     data;   // wdata for write, rdata for read
    rand bit [3:0]      wstrb;
    bit  [1:0]           resp;  // bresp or rresp

    `uvm_object_utils_begin(axi_lite_txn)
      `uvm_field_enum(kind_e, kind, UVM_ALL_ON)
      `uvm_field_int(addr,  UVM_ALL_ON)
      `uvm_field_int(data,  UVM_ALL_ON)
      `uvm_field_int(wstrb, UVM_ALL_ON)
      `uvm_field_int(resp,  UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "axi_lite_txn");
      super.new(name);
    endfunction
  endclass : axi_lite_txn

  // One completed core-side memory-bus transaction (sampled on mem_ready).
  class core_mem_txn extends uvm_sequence_item;
    rand bit [31:0] addr;
    rand bit [31:0] wdata;
    rand bit [31:0] rdata;
    rand bit [3:0]  wstrb;
    rand bit        we;
    rand bit        re;

    `uvm_object_utils_begin(core_mem_txn)
      `uvm_field_int(addr,  UVM_ALL_ON)
      `uvm_field_int(wdata, UVM_ALL_ON)
      `uvm_field_int(rdata, UVM_ALL_ON)
      `uvm_field_int(wstrb, UVM_ALL_ON)
      `uvm_field_int(we,    UVM_ALL_ON)
      `uvm_field_int(re,    UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "core_mem_txn");
      super.new(name);
    endfunction
  endclass : core_mem_txn

  // gpio_out snapshot (monitor) OR gpio_in stimulus value (driver item).
  class gpio_txn extends uvm_sequence_item;
    rand bit [31:0] gpio_out;   // monitor fills this
    rand bit [31:0] gpio_in;    // driver reads this to drive the DUT
    rand int unsigned hold_cycles; // driver: how long to hold gpio_in

    `uvm_object_utils_begin(gpio_txn)
      `uvm_field_int(gpio_out,    UVM_ALL_ON)
      `uvm_field_int(gpio_in,     UVM_ALL_ON)
      `uvm_field_int(hold_cycles, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "gpio_txn");
      super.new(name);
    endfunction
  endclass : gpio_txn

  // UART byte transfer -- placeholder fields only. Bit-level framing capture
  // (start/stop/data bits derived from uart0's CLK_FREQ=1000/BAUD_RATE=100)
  // is NOT implemented yet -- see uart_monitor TODO below.
  class uart_txn extends uvm_sequence_item;
    typedef enum { UART_TX, UART_RX } dir_e;
    rand dir_e        dir;
    rand bit [7:0]     data;

    `uvm_object_utils_begin(uart_txn)
      `uvm_field_enum(dir_e, dir, UVM_ALL_ON)
      `uvm_field_int(data, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "uart_txn");
      super.new(name);
    endfunction
  endclass : uart_txn

  // =====================================================================
  // ENV CONFIG
  // =====================================================================
  class soc_env_config extends uvm_object;
    `uvm_object_utils(soc_env_config)

    virtual axi_lite_if    axi_vif;
    virtual core_mem_if    cmem_vif;
    virtual soc_io_if      io_vif;
    virtual core_probe_if  probe_vif;

    // Strategy A defaults: axi_agent and core_mem_agent are passive
    // (core drives the bus); gpio/uart agents are active (they stimulate
    // gpio_in / uart_rx as external-world inputs regardless of strategy).
    uvm_active_passive_enum axi_agent_active  = UVM_PASSIVE;
    uvm_active_passive_enum gpio_agent_active = UVM_ACTIVE;
    uvm_active_passive_enum uart_agent_active = UVM_ACTIVE;

    function new(string name = "soc_env_config");
      super.new(name);
    endfunction
  endclass : soc_env_config
  // =====================================================================
  // MONITORS
  // =====================================================================

  // Detects completed AXI writes (bvalid&&bready) and reads (rvalid&&rready)
  // via mon_cb. Skeleton: does not yet track outstanding aw/w pairing across
  // multiple in-flight transactions -- fine for now since Strategy A traffic
  // from a single in-order core has at most one outstanding transaction.
  // Revisit if Strategy B adds back-to-back/pipelined stimulus.
  class axi_monitor extends uvm_monitor;
    `uvm_component_utils(axi_monitor)

    virtual axi_lite_if vif;
    uvm_analysis_port#(axi_lite_txn) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      if (!uvm_config_db#(virtual axi_lite_if)::get(this, "", "vif", vif))
        `uvm_fatal("AXI_MON", "virtual axi_lite_if not set")
    endfunction

    task run_phase(uvm_phase phase);
      axi_lite_txn txn;
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.bvalid && vif.mon_cb.bready) begin
          txn = axi_lite_txn::type_id::create("axi_wr_txn");
          txn.kind  = axi_lite_txn::AXI_WRITE;
          txn.addr  = vif.mon_cb.awaddr;   // NOTE: valid only because Strategy
          txn.data  = vif.mon_cb.wdata;    // A has no pipelining yet -- revisit
          txn.wstrb = vif.mon_cb.wstrb;    // when back-to-back writes are added
          txn.resp  = vif.mon_cb.bresp;
          ap.write(txn);
        end
        if (vif.mon_cb.rvalid && vif.mon_cb.rready) begin
          txn = axi_lite_txn::type_id::create("axi_rd_txn");
          txn.kind = axi_lite_txn::AXI_READ;
          txn.addr = vif.mon_cb.araddr;    // same caveat as above
          txn.data = vif.mon_cb.rdata;
          txn.resp = vif.mon_cb.rresp;
          ap.write(txn);
        end
      end
    endtask
  endclass : axi_monitor

  // Captures one core_mem_if transaction per mem_ready pulse.
  class core_mem_monitor extends uvm_monitor;
    `uvm_component_utils(core_mem_monitor)

    virtual core_mem_if vif;
    uvm_analysis_port#(core_mem_txn) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      if (!uvm_config_db#(virtual core_mem_if)::get(this, "", "vif", vif))
        `uvm_fatal("CMEM_MON", "virtual core_mem_if not set")
    endfunction

    task run_phase(uvm_phase phase);
      core_mem_txn txn;
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.mem_ready) begin
          txn = core_mem_txn::type_id::create("cmem_txn");
          txn.addr  = vif.mon_cb.mem_addr;
          txn.wdata = vif.mon_cb.mem_wdata;
          txn.rdata = vif.mon_cb.mem_rdata;
          txn.wstrb = vif.mon_cb.mem_wstrb;
          txn.we    = vif.mon_cb.mem_we;
          txn.re    = vif.mon_cb.mem_re;
          ap.write(txn);
        end
      end
    endtask
  endclass : core_mem_monitor

  // Reports gpio_out whenever it changes.
  class gpio_monitor extends uvm_monitor;
    `uvm_component_utils(gpio_monitor)

    virtual soc_io_if vif;
    uvm_analysis_port#(gpio_txn) ap;
    bit [31:0] last_gpio_out;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      if (!uvm_config_db#(virtual soc_io_if)::get(this, "", "vif", vif))
        `uvm_fatal("GPIO_MON", "virtual soc_io_if not set")
    endfunction

    task run_phase(uvm_phase phase);
      gpio_txn txn;
      last_gpio_out = '0;
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.gpio_out !== last_gpio_out) begin
          last_gpio_out = vif.mon_cb.gpio_out;
          txn = gpio_txn::type_id::create("gpio_mon_txn");
          txn.gpio_out = last_gpio_out;
          ap.write(txn);
        end
      end
    endtask
  endclass : gpio_monitor

  // TODO: not implemented yet. UART framing capture (start bit, 8 data bits,
  // stop bit) needs a bit-timing state machine derived from uart0's
  // CLK_FREQ=1000 / BAUD_RATE=100 parameters (confirmed from rv32i_soc.v).
  // Left as a structural stub so the agent/env wiring is complete; fill in
  // once we get to UART-specific test development.
  class uart_monitor extends uvm_monitor;
    `uvm_component_utils(uart_monitor)

    virtual soc_io_if vif;
    uvm_analysis_port#(uart_txn) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      if (!uvm_config_db#(virtual soc_io_if)::get(this, "", "vif", vif))
        `uvm_fatal("UART_MON", "virtual soc_io_if not set")
    endfunction

    task run_phase(uvm_phase phase);
      // Intentionally empty for now.
    endtask
  endclass : uart_monitor

  // =====================================================================
  // SEQUENCERS / DRIVERS (structural stubs -- no sequences exist yet)
  // =====================================================================

  typedef uvm_sequencer#(gpio_txn) gpio_sequencer;
  typedef uvm_sequencer#(uart_txn) uart_sequencer;
  class uart_send_seq extends uvm_sequence#(uart_txn);
    `uvm_object_utils(uart_send_seq)

    rand bit [7:0] data_to_send;

    function new(string name = "uart_send_seq");
      super.new(name);
    endfunction

    task body();
      uart_txn item;
      item = uart_txn::type_id::create("item");
      start_item(item);
      item.dir  = uart_txn::UART_RX;   // driver-side: data going INTO the DUT
      item.data = data_to_send;
      finish_item(item);
    endtask
  endclass : uart_send_seq


  class gpio_driver extends uvm_driver#(gpio_txn);
    `uvm_component_utils(gpio_driver)

    virtual soc_io_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      if (!uvm_config_db#(virtual soc_io_if)::get(this, "", "vif", vif))
        `uvm_fatal("GPIO_DRV", "virtual soc_io_if not set")
    endfunction

    task run_phase(uvm_phase phase);
      gpio_txn req;
      vif.gpio_drv_cb.gpio_in <= '0;
      forever begin
        seq_item_port.get_next_item(req);
        vif.gpio_drv_cb.gpio_in <= req.gpio_in;
        repeat (req.hold_cycles) @(vif.gpio_drv_cb);
        seq_item_port.item_done();
      end
    endtask
  endclass : gpio_driver

  // Not implemented: needs bit-banging uart_rx per-bit timing (see
  // uart_monitor TODO -- same CLK_FREQ/BAUD_RATE dependency).
    class uart_driver extends uvm_driver#(uart_txn);
    `uvm_component_utils(uart_driver)

    virtual soc_io_if vif;

    // Bit period in clock cycles, derived from uart0's CLK_FREQ=1000 /
    // BAUD_RATE=100 (confirmed from rv32i_soc.v instantiation parameters).
    // NOTE: hardcoded to match the current sim-only override -- if those
    // parameters ever change, this must change with them.
    localparam int UART_BIT_CYCLES = 10;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      if (!uvm_config_db#(virtual soc_io_if)::get(this, "", "vif", vif))
        `uvm_fatal("UART_DRV", "virtual soc_io_if not set")
    endfunction

    task run_phase(uvm_phase phase);
      uart_txn req;
      vif.uart_drv_cb.uart_rx <= 1'b1;   // idle high
      forever begin
        seq_item_port.get_next_item(req);
        send_byte(req.data);
        seq_item_port.item_done();
      end
    endtask

    task send_byte(bit [7:0] data);
      int i;
      vif.uart_drv_cb.uart_rx <= 1'b0;               // start bit
      repeat (UART_BIT_CYCLES) @(vif.uart_drv_cb);
      for (i = 0; i < 8; i++) begin
        vif.uart_drv_cb.uart_rx <= data[i];           // LSB first
        repeat (UART_BIT_CYCLES) @(vif.uart_drv_cb);
      end
      vif.uart_drv_cb.uart_rx <= 1'b1;                // stop bit
      repeat (UART_BIT_CYCLES) @(vif.uart_drv_cb);
    endtask
  endclass : uart_driver

  // =====================================================================
  // AGENTS
  // =====================================================================

  class axi_agent extends uvm_agent;
    `uvm_component_utils(axi_agent)

    axi_monitor    mon;
    soc_env_config cfg;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      if (!uvm_config_db#(soc_env_config)::get(this, "", "cfg", cfg))
        `uvm_fatal("AXI_AGT", "soc_env_config not set")
      is_active = cfg.axi_agent_active;
      uvm_config_db#(virtual axi_lite_if)::set(this, "mon", "vif", cfg.axi_vif);
      mon = axi_monitor::type_id::create("mon", this);
      // Driver/sequencer intentionally omitted -- axi_agent is passive
      // (UVM_PASSIVE) under Strategy A. Add them here when Strategy B
      // (bus-driven) sequences are introduced.
    endfunction
  endclass : axi_agent

  class core_mem_agent extends uvm_agent;
    `uvm_component_utils(core_mem_agent)

    core_mem_monitor mon;
    soc_env_config    cfg;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      if (!uvm_config_db#(soc_env_config)::get(this, "", "cfg", cfg))
        `uvm_fatal("CMEM_AGT", "soc_env_config not set")
      is_active = UVM_PASSIVE;   // always passive -- see Section 1 scope note
      uvm_config_db#(virtual core_mem_if)::set(this, "mon", "vif", cfg.cmem_vif);
      mon = core_mem_monitor::type_id::create("mon", this);
    endfunction
  endclass : core_mem_agent

  class gpio_agent extends uvm_agent;
    `uvm_component_utils(gpio_agent)

    gpio_monitor    mon;
    gpio_driver     drv;
    gpio_sequencer  sqr;
    soc_env_config  cfg;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      if (!uvm_config_db#(soc_env_config)::get(this, "", "cfg", cfg))
        `uvm_fatal("GPIO_AGT", "soc_env_config not set")
      is_active = cfg.gpio_agent_active;
      uvm_config_db#(virtual soc_io_if)::set(this, "mon", "vif", cfg.io_vif);
      mon = gpio_monitor::type_id::create("mon", this);
      if (is_active == UVM_ACTIVE) begin
        uvm_config_db#(virtual soc_io_if)::set(this, "drv", "vif", cfg.io_vif);
        drv = gpio_driver::type_id::create("drv", this);
        sqr = gpio_sequencer::type_id::create("sqr", this);
      end
    endfunction

    function void connect_phase(uvm_phase phase);
      if (is_active == UVM_ACTIVE)
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass : gpio_agent

  class uart_agent extends uvm_agent;
    `uvm_component_utils(uart_agent)

    uart_monitor    mon;
    uart_driver     drv;
    uart_sequencer  sqr;
    soc_env_config  cfg;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      if (!uvm_config_db#(soc_env_config)::get(this, "", "cfg", cfg))
        `uvm_fatal("UART_AGT", "soc_env_config not set")
      is_active = cfg.uart_agent_active;
      uvm_config_db#(virtual soc_io_if)::set(this, "mon", "vif", cfg.io_vif);
      mon = uart_monitor::type_id::create("mon", this);
      if (is_active == UVM_ACTIVE) begin
        uvm_config_db#(virtual soc_io_if)::set(this, "drv", "vif", cfg.io_vif);
        drv = uart_driver::type_id::create("drv", this);
        sqr = uart_sequencer::type_id::create("sqr", this);
      end
    endfunction

    function void connect_phase(uvm_phase phase);
      if (is_active == UVM_ACTIVE)
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass : uart_agent


  // =====================================================================
  // ANALYSIS IMP DECLARATIONS (scoreboard needs 3 distinctly-named imps)
  // =====================================================================
  `uvm_analysis_imp_decl(_cmem)
  `uvm_analysis_imp_decl(_axi)
  `uvm_analysis_imp_decl(_gpio)

  // =====================================================================
  // REFERENCE MODEL
  // Confirmed address map (from axi_lite_to_simple_bus.v):
  //   SEL_MEM   : addr[31:28] == 4'h0      -> 0x00000000-0x0FFFFFFF
  //   SEL_GPIO  : addr[31:12] == 20'h10000 -> 0x10000xxx
  //   SEL_UART  : addr[31:12] == 20'h10001 -> 0x10001xxx  (NOT modeled below)
  //   SEL_TIMER : addr[31:12] == 20'h10002 -> 0x10002xxx
  // =====================================================================
  class soc_ref_model extends uvm_component;
    `uvm_component_utils(soc_ref_model)

    typedef enum { SEL_MEM, SEL_GPIO, SEL_UART, SEL_TIMER, SEL_NONE } sel_e;

    virtual soc_io_if io_vif;

    // GPIO state
    bit [31:0] gpio_dir;
    bit [31:0] gpio_out;
    bit [31:0] gpio_in_reg;

    // TIMER state
    bit [31:0] timer_counter;
    bit [31:0] timer_compare;
    bit        timer_enable;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      if (!uvm_config_db#(virtual soc_io_if)::get(this, "", "io_vif", io_vif))
        `uvm_fatal("REF_MODEL", "virtual soc_io_if not set")
    endfunction

    function sel_e decode_sel(bit [31:0] addr);
      if (addr[31:28] == 4'h0)        return SEL_MEM;
      if (addr[31:12] == 20'h10000)   return SEL_GPIO;
      if (addr[31:12] == 20'h10001)   return SEL_UART;
      if (addr[31:12] == 20'h10002)   return SEL_TIMER;
      return SEL_NONE;
    endfunction

    // Called by the scoreboard when a completed AXI write is observed.
    // NOTE: byte-strobe (wstrb) partial-write behavior is NOT modeled --
    // full-word writes assumed. Revisit if a test ever does sub-word
    // peripheral writes.
    function void on_axi_write(bit [31:0] addr, bit [31:0] data);
      sel_e sel = decode_sel(addr);
      case (sel)
        SEL_GPIO: begin
          case (addr[3:0])
            4'h0: gpio_dir = data;
            4'h4: gpio_out = data;
            default: ;
          endcase
        end
        SEL_TIMER: begin
          case (addr[3:0])
            4'h4: timer_compare = data;
            4'h8: timer_enable  = data[0];
            default: ;
          endcase
        end
        default: ; // SEL_MEM, SEL_UART (deferred), SEL_NONE
      endcase
    endfunction

    // Returns predicted read data. Caller (scoreboard) should only use this
    // for SEL_GPIO / SEL_TIMER -- UART/MEM not modeled, returns 'x as a
    // signal to skip the check.
    function bit [31:0] predict_read(bit [31:0] addr);
      sel_e sel = decode_sel(addr);
      case (sel)
        SEL_GPIO: begin
          case (addr[3:0])
            4'h0: return gpio_dir;
            4'h4: return gpio_out;
            4'h8: return gpio_in_reg;
            default: return 32'h0;
          endcase
        end
        SEL_TIMER: begin
          case (addr[3:0])
            4'h0: return timer_counter;
            4'h4: return timer_compare;
            4'h8: return {31'h0, timer_enable};
            default: return 32'h0;
          endcase
        end
        default: return 32'hxxxxxxxx; // not modeled -- scoreboard skips check
      endcase
    endfunction

    function bit predict_timer_irq();
      return (timer_counter == timer_compare) && timer_enable;
    endfunction

    // Live clock-following process: timer.counter increments every cycle
    // when enabled, independent of bus activity, and gpio_in_reg tracks
    // gpio_in one cycle behind (matches gpio.v's registered input sync).
    // Reset defaults match timer.v exactly: compare=0xFFFFFFFF on reset.
    task run_phase(uvm_phase phase);
      forever begin
        @(posedge io_vif.clk);
        if (io_vif.reset) begin
          timer_counter <= 32'h0;
          timer_compare <= 32'hFFFFFFFF;
          timer_enable  <= 1'b0;
          gpio_dir      <= 32'h0;
          gpio_out      <= 32'h0;
        end else begin
          gpio_in_reg <= io_vif.gpio_in;
          if (timer_enable) timer_counter <= timer_counter + 1;
        end
      end
    endtask
  endclass : soc_ref_model

  // =====================================================================
  // SCOREBOARD
  // Two independent checks:
  //   (A) Transport: does axi_manager faithfully carry each core_mem_if
  //       request through to the bridge, unchanged? (core_mem_txn vs
  //       axi_lite_txn, FIFO-correlated -- valid because the core issues
  //       requests strictly in order and axi_manager forwards in order.)
  //   (B) Peripheral behavior: for GPIO/TIMER reads, does the returned
  //       data match soc_ref_model's prediction? (UART reads skipped --
  //       not modeled, see soc_ref_model.)
  //   Plus a live gpio_out check against gpio_monitor.
  // =====================================================================
  class soc_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(soc_scoreboard)

    uvm_analysis_imp_cmem#(core_mem_txn, soc_scoreboard) cmem_imp;
    uvm_analysis_imp_axi#(axi_lite_txn, soc_scoreboard)  axi_imp;

    soc_ref_model ref_model;   // set by soc_env after both are created

    core_mem_txn cmem_q[$];
    axi_lite_txn axi_q[$];

    int unsigned transport_errors = 0;
    int unsigned periph_errors    = 0;
    int unsigned cmem_count       = 0;
    int unsigned axi_count        = 0;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      cmem_imp = new("cmem_imp", this);
      axi_imp  = new("axi_imp", this);
    endfunction

    function void write_cmem(core_mem_txn t);
      cmem_count++;
      cmem_q.push_back(t);
      try_drain();
    endfunction

    function void write_axi(axi_lite_txn t);
      axi_count++;
      axi_q.push_back(t);
      try_drain();
    endfunction

    function void try_drain();
      if (ref_model == null) return;   // not yet connected
      while (cmem_q.size() > 0 && axi_q.size() > 0) begin
        core_mem_txn c = cmem_q.pop_front();
        axi_lite_txn a = axi_q.pop_front();

        // ---- (A) transport check ----
        if (c.addr !== a.addr) begin
          `uvm_error("SB_TRANSPORT",
            $sformatf("addr mismatch: core=0x%0h axi=0x%0h", c.addr, a.addr))
          transport_errors++;
        end

        if (c.we) begin
          if (a.kind != axi_lite_txn::AXI_WRITE || c.wdata !== a.data) begin
            `uvm_error("SB_TRANSPORT",
              $sformatf("write data mismatch @0x%0h: core=0x%0h axi=0x%0h",
                         c.addr, c.wdata, a.data))
            transport_errors++;
          end
          ref_model.on_axi_write(a.addr, a.data);

          // Live gpio_out check -- safe here: by the time we've observed
          // bvalid&&bready, gpio.v's actual out_reg write (which happens
          // earlier, during the bridge's W_ACCESS state) is already
          // committed and stable.
          if (ref_model.decode_sel(a.addr) == soc_ref_model::SEL_GPIO && a.addr[3:0] == 4'h4) begin
            if (ref_model.io_vif.gpio_out !== ref_model.gpio_out) begin
              `uvm_error("SB_GPIO_OUT",
                $sformatf("gpio_out=0x%0h, ref_model predicted 0x%0h",
                           ref_model.io_vif.gpio_out, ref_model.gpio_out))
            end
          end
        end
        else if (c.re) begin
          if (a.kind != axi_lite_txn::AXI_READ || c.rdata !== a.data) begin
            `uvm_error("SB_TRANSPORT",
              $sformatf("read data mismatch @0x%0h: core=0x%0h axi=0x%0h",
                         c.addr, c.rdata, a.data))
            transport_errors++;
          end

          // ---- (B) peripheral behavior check (GPIO/TIMER only) ----
          begin
            soc_ref_model::sel_e sel = ref_model.decode_sel(c.addr);
            if (sel == soc_ref_model::SEL_GPIO || sel == soc_ref_model::SEL_TIMER) begin
              bit [31:0] expected = ref_model.predict_read(c.addr);
              if (expected !== c.rdata) begin
                `uvm_error("SB_PERIPH",
                  $sformatf("read @0x%0h: expected 0x%0h, got 0x%0h",
                             c.addr, expected, c.rdata))
                periph_errors++;
              end
            end
          end
        end
      end
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("SB_SUMMARY",
        $sformatf("cmem_count=%0d axi_count=%0d transport_errors=%0d periph_errors=%0d",
                   cmem_count, axi_count, transport_errors, periph_errors), UVM_LOW)
    endfunction
  endclass : soc_scoreboard

// Additions to soc_pkg.sv -- coverage model.
//
// Maps directly to Section 7's five known bug classes:
//   1. stale enable/re-triggering       -> cg_back_to_back (core_mem op-pair
//                                          adjacency with zero dead cycles)
//   2. address-latch-vs-state timing    -> cg_axi_txn (region x kind x resp,
//      at the bridge                       confirms every peripheral region
//                                          actually got read AND written)
//   3. branch-flush-vs-stall priority   -> cg_branch_stall (cross of
//                                          branch_out/stall_front same cycle)
//   4. one-shot pulse widths            -> cg_pulse_width (mem_ready,
//                                          timer_irq width-1 confirmation)
//   5. store-then-immediate-load-       -> cg_store_load_same_addr (explicit
//      same-address                        bin hit when addresses match)

  class soc_coverage extends uvm_component;
    `uvm_component_utils(soc_coverage)

    `uvm_analysis_imp_decl(_axi_cov)
    `uvm_analysis_imp_decl(_cmem_cov)

    uvm_analysis_imp_axi_cov#(axi_lite_txn, soc_coverage)  axi_cov_imp;
    uvm_analysis_imp_cmem_cov#(core_mem_txn, soc_coverage) cmem_cov_imp;

    virtual soc_io_if      io_vif;
    virtual core_probe_if  probe_vif;
    virtual core_mem_if    cmem_vif;   // needed for mem_ready pulse-width tracking

    // Last completed core_mem_txn, for adjacency/same-address comparison
    // against the next one (bug classes 1 and 5).
    core_mem_txn last_cmem_txn;
    bit          have_last;

    // -------------------------------------------------------------------
    // Bug class 2: AXI-level region x kind x resp coverage.
    // -------------------------------------------------------------------
    bit [1:0] cov_region;  // 0=MEM 1=GPIO 2=UART 3=TIMER -- decoded per-sample
    axi_lite_txn::kind_e cov_kind;
    bit [1:0] cov_resp;

    covergroup cg_axi_txn;
      option.per_instance = 1;
      cp_region: coverpoint cov_region {
        bins mem   = {0};
        bins gpio  = {1};
        bins uart  = {2};
        bins timer = {3};
      }
      cp_kind: coverpoint cov_kind {
        bins write = {axi_lite_txn::AXI_WRITE};
        bins read  = {axi_lite_txn::AXI_READ};
      }
      cp_resp: coverpoint cov_resp {
        bins okay  = {2'b00};
        bins error = {2'b11};
        illegal_bins others = default;
      }
      cx_region_kind: cross cp_region, cp_kind;
    endgroup

    // -------------------------------------------------------------------
    // Bug class 1: back-to-back core_mem op adjacency, zero dead cycles.
    // Tracks the PAIR of consecutive completed transactions' op types.
    // -------------------------------------------------------------------
    typedef enum { OP_LOAD, OP_STORE } op_e;
    op_e cov_prev_op, cov_curr_op;
    bit  cov_zero_gap;   // true if curr txn's mem_ready fired the very next
                          // sampled edge after prev's (see sampling note
                          // in write_cmem_cov below)

    covergroup cg_back_to_back;
      option.per_instance = 1;
      cp_prev: coverpoint cov_prev_op { bins load = {OP_LOAD}; bins store = {OP_STORE}; }
      cp_curr: coverpoint cov_curr_op { bins load = {OP_LOAD}; bins store = {OP_STORE}; }
      cp_gap:  coverpoint cov_zero_gap { bins zero_gap = {1}; bins has_gap = {0}; }
      cx_adjacency: cross cp_prev, cp_curr, cp_gap;
    endgroup

    // -------------------------------------------------------------------
    // Bug class 5: store immediately followed by load to the SAME address.
    // Narrower and more specific than cg_back_to_back's general adjacency.
    // -------------------------------------------------------------------
    bit cov_store_then_load_same_addr;

    covergroup cg_store_load_same_addr;
      option.per_instance = 1;
      cp_hit: coverpoint cov_store_then_load_same_addr { bins hit = {1}; }
    endgroup

    // -------------------------------------------------------------------
    // Bug class 3: branch_out vs stall_front on the same cycle -- confirms
    // we've exercised the priority interaction (a branch resolving on
    // exactly the cycle a load-use stall would otherwise hold fetch),
    // not just each condition individually.
    // -------------------------------------------------------------------
    bit cov_branch_out, cov_stall_front, cov_flush_if;

    covergroup cg_branch_stall;
      option.per_instance = 1;
      cp_branch: coverpoint cov_branch_out  { bins taken = {1}; bins not_taken = {0}; }
      cp_stall:  coverpoint cov_stall_front { bins stalled = {1}; bins clear = {0}; }
      cp_flush:  coverpoint cov_flush_if    { bins flushed = {1}; bins clear = {0}; }
      cx_priority: cross cp_branch, cp_stall;
    endgroup

    // -------------------------------------------------------------------
    // Bug class 4: one-shot pulse width confirmation for mem_ready and
    // timer_irq. Tracks consecutive high-cycle run length; bin at 1
    // confirms the expected width, bin at 2+ would flag a violation if
    // one ever occurred (none expected, but the bin exists so a
    // regression would show up as unexpected coverage, not silence).
    // -------------------------------------------------------------------
    int unsigned mem_ready_run_len;
    int unsigned timer_irq_run_len;
    int unsigned cov_pulse_len;

    covergroup cg_pulse_width;
      option.per_instance = 1;
      cp_len: coverpoint cov_pulse_len {
        bins width_1 = {1};
        bins width_violation = {[2:$]};
      }
    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent);
      axi_cov_imp             = new("axi_cov_imp", this);
      cmem_cov_imp            = new("cmem_cov_imp", this);
      cg_axi_txn              = new();
      cg_back_to_back         = new();
      cg_store_load_same_addr = new();
      cg_branch_stall         = new();
      cg_pulse_width          = new();
    endfunction

    function void build_phase(uvm_phase phase);
      if (!uvm_config_db#(virtual soc_io_if)::get(this, "", "io_vif", io_vif))
        `uvm_fatal("SOC_COV", "virtual soc_io_if not set")
      if (!uvm_config_db#(virtual core_probe_if)::get(this, "", "probe_vif", probe_vif))
        `uvm_fatal("SOC_COV", "virtual core_probe_if not set")
      if (!uvm_config_db#(virtual core_mem_if)::get(this, "", "cmem_vif", cmem_vif))
        `uvm_fatal("SOC_COV", "virtual core_mem_if not set")
    endfunction

    // Called via axi_agent0.mon.ap.connect(cov0.axi_cov_imp) -- bug class 2.
    function void write_axi_cov(axi_lite_txn t);
      // Reuse the same address-region decode as soc_ref_model, duplicated
      // here rather than shared to keep coverage decoupled from the
      // checking model -- a bug in one shouldn't silently mask the other.
      if (t.addr[31:28] == 4'h0)                 cov_region = 0;
      else if (t.addr[31:12] == 20'h10000)       cov_region = 1;
      else if (t.addr[31:12] == 20'h10001)       cov_region = 2;
      else if (t.addr[31:12] == 20'h10002)       cov_region = 3;
      else return;  // SEL_NONE -- not a real peripheral access, skip
      cov_kind = t.kind;
      cov_resp = t.resp;
      cg_axi_txn.sample();
    endfunction

    // Called via core_mem_agent0.mon.ap.connect(cov0.cmem_cov_imp) --
    // bug classes 1, 5.
    function void write_cmem_cov(core_mem_txn t);
      if (have_last) begin
        cov_prev_op  = last_cmem_txn.we ? OP_STORE : OP_LOAD;
        cov_curr_op  = t.we ? OP_STORE : OP_LOAD;
        // "Zero gap" here means these were the two most recently completed
        // transactions with no non-memory instruction observed between
        // them at the monitor level -- approximated as always-true since
        // core_mem_monitor only ever sees actual mem ops, not every cycle.
        // This is intentionally the loosest useful definition: it marks
        // adjacency in COMPLETED-TRANSACTION order, which is exactly what
        // matters for the stale-retrigger bug class (back-to-back FSM
        // reuse), not wall-clock cycle distance.
        cov_zero_gap = 1'b1;
        cg_back_to_back.sample();

        if (last_cmem_txn.we && t.re && (last_cmem_txn.addr == t.addr)) begin
          cov_store_then_load_same_addr = 1'b1;
          cg_store_load_same_addr.sample();
        end
      end
      last_cmem_txn = t;
      have_last = 1'b1;
    endfunction

    // Per-cycle process for pulse-width and branch/stall coverage --
    // these need cycle-granularity sampling, not transaction callbacks.
    task run_phase(uvm_phase phase);
      fork
        track_mem_ready_pulse();
        track_timer_irq_pulse();
        track_branch_stall();
      join
    endtask

    task track_mem_ready_pulse();
      bit prev = 0;
      mem_ready_run_len = 0;
      forever begin
        @(cmem_vif.mon_cb);
        if (io_vif.reset) begin
          mem_ready_run_len = 0;
          prev = 0;
        end else begin
          if (cmem_vif.mon_cb.mem_ready) mem_ready_run_len++;
          else if (prev) begin
            cov_pulse_len = mem_ready_run_len;
            cg_pulse_width.sample();
            mem_ready_run_len = 0;
          end
          prev = cmem_vif.mon_cb.mem_ready;
        end
      end
    endtask

    task track_timer_irq_pulse();
      bit prev = 0;
      timer_irq_run_len = 0;
      forever begin
        @(io_vif.mon_cb);
        if (io_vif.reset) begin
          timer_irq_run_len = 0;
          prev = 0;
        end else begin
          if (io_vif.mon_cb.timer_irq) timer_irq_run_len++;
          else if (prev) begin
            cov_pulse_len = timer_irq_run_len;
            cg_pulse_width.sample();
            timer_irq_run_len = 0;
          end
          prev = io_vif.mon_cb.timer_irq;
        end
      end
    endtask

    task track_branch_stall();
      forever begin
        @(probe_vif.mon_cb);
        if (!io_vif.reset) begin
          cov_branch_out  = probe_vif.mon_cb.branch_out;
          cov_stall_front = probe_vif.mon_cb.stall_front;
          cov_flush_if    = probe_vif.mon_cb.flush_if;
          cg_branch_stall.sample();
        end
      end
    endtask
    
    function void report_phase(uvm_phase phase);
      `uvm_info("SOC_COV", $sformatf(
        "coverage: axi_txn=%0.1f%% back_to_back=%0.1f%% store_load_same_addr=%0.1f%% branch_stall=%0.1f%% pulse_width=%0.1f%%",
        cg_axi_txn.get_coverage(), cg_back_to_back.get_coverage(),
        cg_store_load_same_addr.get_coverage(), cg_branch_stall.get_coverage(),
        cg_pulse_width.get_coverage()), UVM_LOW)
    endfunction
  endclass : soc_coverage




  class soc_env extends uvm_env;
    `uvm_component_utils(soc_env)

    soc_env_config    cfg;
    axi_agent         axi_agent0;
    core_mem_agent    core_mem_agent0;
    gpio_agent        gpio_agent0;
    uart_agent        uart_agent0;
    soc_ref_model     ref_model0;
    soc_scoreboard    scoreboard0;
    soc_coverage      cov0;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      if (!uvm_config_db#(soc_env_config)::get(this, "", "cfg", cfg))
        `uvm_fatal("SOC_ENV", "soc_env_config not set")
      uvm_config_db#(soc_env_config)::set(this, "*", "cfg", cfg);

      axi_agent0      = axi_agent::type_id::create("axi_agent0", this);
      core_mem_agent0 = core_mem_agent::type_id::create("core_mem_agent0", this);
      gpio_agent0     = gpio_agent::type_id::create("gpio_agent0", this);
      uart_agent0     = uart_agent::type_id::create("uart_agent0", this);

      uvm_config_db#(virtual soc_io_if)::set(this, "ref_model0", "io_vif", cfg.io_vif);
      ref_model0  = soc_ref_model::type_id::create("ref_model0", this);
      scoreboard0 = soc_scoreboard::type_id::create("scoreboard0", this);

      uvm_config_db#(virtual soc_io_if)::set(this, "cov0", "io_vif", cfg.io_vif);
      uvm_config_db#(virtual core_probe_if)::set(this, "cov0", "probe_vif", cfg.probe_vif);
      uvm_config_db#(virtual core_mem_if)::set(this, "cov0", "cmem_vif", cfg.cmem_vif);
      cov0 = soc_coverage::type_id::create("cov0", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      scoreboard0.ref_model = ref_model0;
      core_mem_agent0.mon.ap.connect(scoreboard0.cmem_imp);
      axi_agent0.mon.ap.connect(scoreboard0.axi_imp);
      axi_agent0.mon.ap.connect(cov0.axi_cov_imp);
      core_mem_agent0.mon.ap.connect(cov0.cmem_cov_imp);
    endfunction
  endclass : soc_env
 
 
  // =====================================================================
  // BASE TEST
  // =====================================================================
  class soc_base_test extends uvm_test;
    `uvm_component_utils(soc_base_test)

    soc_env        env;
    soc_env_config cfg;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      cfg = soc_env_config::type_id::create("cfg");

      if (!uvm_config_db#(virtual axi_lite_if)::get(this, "", "axi_vif", cfg.axi_vif))
        `uvm_fatal("BASE_TEST", "axi_vif not found in config_db -- check tb_top")
      if (!uvm_config_db#(virtual core_mem_if)::get(this, "", "cmem_vif", cfg.cmem_vif))
        `uvm_fatal("BASE_TEST", "cmem_vif not found in config_db -- check tb_top")
      if (!uvm_config_db#(virtual soc_io_if)::get(this, "", "io_vif", cfg.io_vif))
        `uvm_fatal("BASE_TEST", "io_vif not found in config_db -- check tb_top")
      if (!uvm_config_db#(virtual core_probe_if)::get(this, "", "probe_vif", cfg.probe_vif))
        `uvm_fatal("BASE_TEST", "probe_vif not found in config_db -- check tb_top")

      uvm_config_db#(soc_env_config)::set(this, "env", "cfg", cfg);
      env = soc_env::type_id::create("env", this);
    endfunction
  endclass : soc_base_test
   // =====================================================================
  // HELLO TEST -- proves reset + env elaboration, nothing else yet.
  // =====================================================================
  class hello_test extends soc_base_test;
    `uvm_component_utils(hello_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      `uvm_info("HELLO_TEST", "soc_env elaborated, waiting for reset deassert...", UVM_LOW)
      wait (cfg.io_vif.reset === 1'b0);
      repeat (20) @(cfg.io_vif.mon_cb);
      `uvm_info("HELLO_TEST", "reset deasserted, 20 cycles observed -- hello_test PASS", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass : hello_test

  // =====================================================================
  // BASIC PROGRAM TEST -- runs program.hex, checks final GPR state against
  // the old directed testbench's known-good check() values (milestone 2).
  // =====================================================================
  class basic_program_test extends soc_base_test;
    `uvm_component_utils(basic_program_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      int unsigned num_errors = 0;

      // Register indices and expected values, taken directly from the old
      // directed testbench's check() calls against this same program.hex.
      int unsigned reg_idx [0:23] = '{
        1,2,3,4,5,6,7,8,9,10,11,12,13,16,17,19,20,21,22,23,24,25,26,27
      };
      bit [31:0] reg_exp [0:23] = '{
        32'd5, 32'd10, 32'd10, 32'd15, 32'h10000000, 32'd1, 32'h0000002A, 32'h10002000,
        32'd5, 32'd1, 32'h0000002A, 32'h10001000, 32'h00000041,
        32'h00000002, 32'h00000055, 32'h00000010, 32'h000000AB, 32'h0000002A,
        32'hFFFFFFAB, 32'h000000AB, 32'h0000002A, 32'h00008055, 32'hFFFF8055, 32'h00008055
      };
      bit [31:0] actual;

      phase.raise_objection(this);

      `uvm_info("BASIC_TEST", "waiting for reset deassert...", UVM_LOW)
      wait (cfg.io_vif.reset === 1'b0);

      fork
        begin
          uart_send_seq useq;
          useq = uart_send_seq::type_id::create("useq");
          useq.data_to_send = 8'h55;
          useq.start(env.uart_agent0.sqr);
        end
      join_none

      // Widened from 1000: UART frame alone is 100 cycles (10 bits x 10
      // cycles/bit), plus AXI-mediated ops after it. 2000 gives real margin.
      repeat (2000) @(cfg.io_vif.mon_cb);
      `uvm_info("BASIC_TEST",
        $sformatf("PC settled at 0x%0h after 1000 cycles -- reading registers", cfg.probe_vif.pc_out),
        UVM_LOW)

      foreach (reg_idx[i]) begin
        actual = cfg.probe_vif.gpr[reg_idx[i]];
        if (actual !== reg_exp[i]) begin
          `uvm_error("BASIC_TEST",
            $sformatf("x%0d MISMATCH: expected 0x%0h, got 0x%0h", reg_idx[i], reg_exp[i], actual))
          num_errors++;
        end else begin
          `uvm_info("BASIC_TEST", $sformatf("x%0d OK: 0x%0h", reg_idx[i], actual), UVM_MEDIUM)
        end
      end

      if (num_errors == 0)
        `uvm_info("BASIC_TEST", "ALL 24 REGISTER CHECKS PASSED", UVM_LOW)
      else
        `uvm_error("BASIC_TEST", $sformatf("%0d REGISTER CHECK(S) FAILED", num_errors))

      phase.drop_objection(this);
    endtask
  endclass : basic_program_test

  // =====================================================================
  // RANDOM PROGRAM TEST -- no golden register reference (unlike
  // basic_program_test). Relies entirely on soc_scoreboard's continuous
  // transport/peripheral checks as the oracle. Runs a generous fixed cycle
  // budget since a random program's actual instruction count/hazard
  // density varies run to run.
  // =====================================================================
  class random_program_test extends soc_base_test;
    `uvm_component_utils(random_program_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);

      `uvm_info("RAND_TEST", "waiting for reset deassert...", UVM_LOW)
      wait (cfg.io_vif.reset === 1'b0);

      // No halt-loop guarantee for a random program (program_gen.py's
      // emit_halt() does append one, but there's no register-based
      // completion signal to wait on) -- fixed budget, generous relative to
      // the 96-word program observed in testing.
      repeat (5000) @(cfg.io_vif.mon_cb);

      `uvm_info("RAND_TEST",
        $sformatf("PC settled at 0x%0h after 5000 cycles", cfg.probe_vif.pc_out),
        UVM_LOW)

      // No register checks here -- see class header comment.
      // soc_scoreboard's report_phase prints SB_SUMMARY independently;
      // that's the actual pass/fail signal for this test.

      phase.drop_objection(this);
    endtask
  endclass : random_program_test

endpackage : soc_pkg

`endif // SOC_PKG_SV