# MiniSoC: RV32I SoC, RTL-to-GDSII

A 5-stage pipelined RV32I SoC (core + AXI-Lite interconnect + GPIO/timer/UART),
verified with a UVM environment, prototyped on FPGA, and being taken through a
full open-source ASIC flow (Yosys + OpenROAD on SKY130) with a focus on
physical design: floorplanning with SRAM macros, timing closure, CTS, power
grid / IR drop, and signoff.

## Design

| Block | Contents |
|---|---|
| Core (`rtl/core`) | IF/ID/EX/MEM/WB pipeline, ALU, decoder/control, immediate gen, 32x32 register file, forwarding (bypass) unit, load-use hazard detection, branch unit + branch prediction, load/store units |
| Interconnect (`rtl/soc`) | Core-side AXI-Lite manager, AXI-Lite to simple-bus bridge with address decode |
| Peripherals (`rtl/periph`) | GPIO (32 in / 32 out), timer with IRQ, UART |
| Memories (`rtl/mem`) | 256x32 instruction and data memories built on a synchronous 1rw1r SRAM model; direct-mapped D-cache + backing RAM (not yet integrated) |

### Memories

Both memories use `sram_32x256_1rw1r`, a behavioral model whose ports and
timing match the OpenRAM `sky130_sram_1kbyte_1rw1r_32x256_8` macro (active-low
chip select and write enable, registered address, data valid the next cycle),
so the ASIC flow can drop in the hard macro without changing the RTL around it.

- **Instruction memory** sits in `rv32i_soc`, outside the core. The core drives
  `imem_addr` with the *next* PC, so the SRAM's registered output always
  matches the current `pc_out`. That keeps fetch cycle-for-cycle identical to
  the original combinational ROM. Port 1 serves fetch, and port 0 is a
  program-load port (`imem_load_we/addr/data`) used while reset is held.
- **Data memory** sits behind the AXI-Lite bridge, which already holds the read
  address from `R_ACCESS` into `R_RESP`, so the one-cycle read latency fits
  without bridge changes.

Memory map (from `axi_lite_to_simple_bus.v`):

| Region | Address |
|---|---|
| Data memory | `0x0000_0000` - `0x0FFF_FFFF` |
| GPIO | `0x1000_0xxx` |
| UART | `0x1000_1xxx` |
| Timer | `0x1000_2xxx` |

## Repository layout

```
rtl/            synthesizable RTL (rtl.f = filelist, include/ = Def.v)
tb/uvm/         UVM env, interfaces, SVA, coverage (uvm.f = filelist)
tb/directed/    directed unit/system testbenches
sw/             RV32I encoder + hazard-aware random program generator
sw/programs/    program images loaded via +PROGRAM=<file>.hex
fpga/           FPGA-only wrapper, XDC, and Vivado implementation reports
flow/           ASIC flow: ORFS config.mk, constraint.sdc, run.sh
scripts/vivado/ recreate the Vivado project / run UVM tests in batch
```

## Running the ASIC flow (OpenROAD-flow-scripts, sky130hd)

Needs WSL2 (or Linux) with Docker and the `openroad/orfs` image
(`docker pull openroad/orfs:latest`). From WSL:

```
flow/run.sh synth            # Yosys synthesis
flow/run.sh floorplan        # any ORFS stage: floorplan place cts route finish
flow/run.sh gui_floorplan    # open a finished stage in the OpenROAD GUI
```

The repo is mounted read-only; outputs go to `~/rv32i_orfs_work`
(`logs/`, `reports/`, `results/` under `sky130hd/rv32i_soc/base`). The RTL
list comes from `rtl/rtl.f`, shared with simulation.

## Running simulation (Vivado xsim)

From the repo root:

```
vivado -mode batch -source scripts/vivado/run_uvm.tcl -tclargs random_program_test program_random.hex
```

Available tests: `hello_test`, `basic_program_test`, `random_program_test`.
Directed testbenches (set as the sim top): `tb_rv32i_soc` (full-SoC program
plus GPIO/timer/UART checks) and `tb_imem_load` (program-load port, checked
against a preloaded SoC in lockstep). `tb_rv32i_core` has one known failing
check (x17) that predates this repo. `tb_cache` targets an older SoC with the
D-cache integrated and doesn't elaborate against the current top.
To open the project in the GUI instead, run `scripts/vivado/create_project.tcl`
and open `build/vivado/MiniSoC.xpr`.

New random programs:

```
python sw/program_gen.py <seed> sw/programs/program_random.hex
```

## Results so far

FPGA (Vivado 2024.2, xczu7ev-2, routed): 100 MHz constraint met with
WNS +5.04 ns, WHS +0.04 ns; ~2.0k LUTs, ~1.9k FFs. Reports in `fpga/reports/`.

### Synthesis, sky130hd (Yosys 0.68 via ORFS, 20 ns clock, SRAMs as black boxes)

| Metric | Value |
|---|---|
| Standard cells | 9,332 |
| Logic area | 109,300 µm² (0.109 mm²) |
| Sequential share of area | 50.5% |
| Flip-flops | 1,979 (1,329 enable, 441 async-reset, 209 other) |
| Latches / check problems | 0 / 0 |

Area by block, from a hierarchical run (no cross-boundary optimization, so it
totals 129,090 µm² rather than 109,300 µm²):

| Block | Area (µm²) | Share |
|---|---|---|
| Register file (32×32 flops + 2 read muxes) | 55,570 | 43% |
| AXI-Lite manager + bridge | 14,390 | 11% |
| ALU | 8,660 | 7% |
| Pipeline registers (ID/EX, EX/MEM, MEM/WB) | 17,990 | 14% |
| Program counter + JALR adder | 8,115 | 6% |
| Peripherals (GPIO, timer, UART) | 10,330 | 8% |
| Everything else (decode, control, forwarding, ...) | 14,030 | 11% |

The register file dominates. That makes it the first PPA target: dropping
its reset, or replacing the flops with a latch-based array or a register-file
macro.

## Roadmap

- [x] RTL + UVM verification + FPGA implementation
- [x] Repository setup
- [x] ASIC-ready RTL: synchronous SRAMs for instruction and data memory, program-load port, synthesis cleanups
- [x] SDC constraints
- [x] Yosys synthesis on sky130hd (SRAMs as black boxes)
- [ ] sky130 SRAM macros integrated (LEF/LIB/GDS)
- [ ] Baseline OpenROAD run to GDS (floorplan, PDN, place, CTS, route)
- [ ] Timing closure: push frequency, physical vs. RTL fixes
- [ ] PPA experiments: utilization, aspect ratio, macro placement, CTS, PDN
- [ ] Signoff: RC extraction, multi-corner STA, IR drop, DRC/LVS, antenna
