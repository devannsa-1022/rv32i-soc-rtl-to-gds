# sky130_sram_1kbyte_1rw1r_32x256_8

OpenRAM-generated SKY130 SRAM, 256 words × 32 bits, one read/write port and
one read-only port, byte write mask. Used for both the instruction and data
memories through `rtl/mem/sram_32x256_1rw1r.v` (with `USE_SRAM_MACRO`).

Copied unmodified from
[VLSIDA/sky130_sram_macros](https://github.com/VLSIDA/sky130_sram_macros)
at commit `965df15`, Apache-2.0 (see `LICENSE`).

| File | Used for |
|---|---|
| `.lef` | Physical view: 479.78 × 397.5 µm, pins on met3/met4 |
| `_TT_1p8V_25C.lib` | Timing, typical corner only (1.8 V, 25 °C) |
| `.gds` | Layout, merged into the final GDS |
| `.v` | Behavioral model (power pins under `USE_POWER_PINS`) |

Behavior to design around: inputs are registered on the rising clock edge,
read data appears after the falling edge, and `dout` goes to X after every
rising edge that is not a read. Read data must be used in the cycle after
the read.
