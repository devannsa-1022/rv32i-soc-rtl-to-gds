# RTL filelist for rv32i_soc (paths relative to repo root).
# Include dir: rtl/include (Def.v is pulled in via `include, not listed here).

# Core
rtl/core/ALU.v
rtl/core/branch_prediction_unit.v
rtl/core/branch_unit.v
rtl/core/bypass_unit.v
rtl/core/control_unit.v
rtl/core/decoder.v
rtl/core/forward_mux_unit.v
rtl/core/Hazard_Detection_Unit.v
rtl/core/id_ex_pip_reg.v
rtl/core/imm_gen.v
rtl/core/instruction_memory.v
rtl/core/load_unit.v
rtl/core/load_use_hazard_unit.v
rtl/core/mem_pip_reg.v
rtl/core/pip_reg4.v
rtl/core/prog_counter.v
rtl/core/reg_file.v
rtl/core/rv32i_core.v
rtl/core/stall_unit.v
rtl/core/store_unit.v

# Interconnect + SoC top
rtl/soc/axi_manager.v
rtl/soc/axi_lite_to_simple_bus.v
rtl/soc/rv32i_soc.v

# Peripherals
rtl/periph/gpio.v
rtl/periph/timer.v
rtl/periph/uart.v

# Memories (dcache/unified_ram are not yet instantiated in rv32i_soc)
rtl/mem/data_mem.v
rtl/mem/dcache.v
rtl/mem/unified_ram.v
