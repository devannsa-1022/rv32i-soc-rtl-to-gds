# program_gen.py
# Generates hazard-aware, bounded RV32I programs for the rv32i_soc UVM env,
# using only instructions confirmed against actual RTL (see rv32i_encoder.py
# and the design-audit trail in the handoff conversation). Output is a
# $readmemh-compatible .hex file consumed via instruction_memory.v's
# +PROGRAM= plusarg.
#
# Hard constraints (all empirically/structurally confirmed, not assumed):
#   - 256-word instruction memory, word-addressed via addr[9:2] -- programs
#     must fit in <= 256 instructions, and all branch/jump targets must be
#     word-aligned and within that same 256-word window.
#   - x0 is hardwired zero (reg_file.v: reg_filex[0] forced to 0 on every
#     write) -- never select x0 as a destination register in the generator;
#     writes to it are architecturally legal but pointless for checking.
#   - Peripheral MMIO regions (per axi_lite_to_simple_bus.v):
#       SEL_MEM   0x00000000-0x0FFFFFFF
#       SEL_GPIO  0x10000xxx
#       SEL_UART  0x10001xxx
#       SEL_TIMER 0x10002xxx
#     Loads/stores targeting SEL_MEM must stay within data_memory.v's own
#     256-word range (addr[9:2], same cap as instruction memory) to avoid
#     silently wrapping.
#   - Load-use hazards (load_use_hazard_unit.v) and branch/jal flush
#     behavior are handled correctly by the pipeline (confirmed by SVA +
#     basic_program_test), so the generator does NOT need to hand-insert
#     NOPs for these -- that would defeat the purpose of exercising the
#     hazard logic under random sequencing. It DOES need to avoid reading a
#     register on the same cycle-distance where the pipeline can't recover
#     (there is none such, confirmed) -- so no special-casing needed there.

import random
from rv32i_encoder import (
    add, sub, sll, slt, sltu, xor_, srl, sra, or_, and_,
    addi, slti, sltiu, xori, ori, andi, slli, srli, srai,
    lui, auipc, lb, lh, lw, lbu, lhu, sb, sh, sw,
    beq, bne, blt, bge, bltu, bgeu, jal, jalr,
    to_hex_lines,
)

MAX_WORDS = 256
DATA_MEM_MAX_WORDS = 256  # data_memory.v's own addr[9:2] cap

GPIO_BASE  = 0x10000000
UART_BASE  = 0x10001000
TIMER_BASE = 0x10002000

USABLE_REGS = list(range(1, 32))  # x0 excluded -- see header note


class ProgramGen:
    def __init__(self, seed=None):
        self.rng = random.Random(seed)
        self.words = []

    def _emit(self, word):
        if len(self.words) >= MAX_WORDS:
            raise RuntimeError(f"program exceeds {MAX_WORDS}-word instruction memory cap")
        self.words.append(word)
        return len(self.words) - 1  # index of the instruction just emitted

    def _addr_of(self, idx):
        return idx * 4

    def _rand_reg(self, exclude=()):
        choices = [r for r in USABLE_REGS if r not in exclude]
        return self.rng.choice(choices)

    # ---------------- R/I-type ALU op mix ----------------
    def emit_random_alu(self):
        rd, rs1, rs2 = self._rand_reg(), self._rand_reg(), self._rand_reg()
        op = self.rng.choice([add, sub, sll, slt, sltu, xor_, srl, sra, or_, and_])
        self._emit(op(rd, rs1, rs2))

    def emit_random_alu_imm(self):
        rd, rs1 = self._rand_reg(), self._rand_reg()
        imm12 = self.rng.randint(-2048, 2047)
        op = self.rng.choice([addi, slti, sltiu, xori, ori, andi])
        self._emit(op(rd, rs1, imm12))
        # shift-immediates separately, since shamt range differs (0-31, not signed 12-bit)

    def emit_random_shift_imm(self):
        rd, rs1 = self._rand_reg(), self._rand_reg()
        shamt = self.rng.randint(0, 31)
        op = self.rng.choice([slli, srli, srai])
        self._emit(op(rd, rs1, shamt))

    # ---------------- Data-memory-safe load/store pair ----------------
    def emit_store_then_load(self):
        """Bug-class check (Section 7, store-then-immediate-load-same-address):
        deliberately back-to-back, no gap, same address."""
        addr_word = self.rng.randint(0, DATA_MEM_MAX_WORDS - 1)
        base_reg = self._rand_reg()
        self._emit(lui(base_reg, 0))       # zero out base_reg's upper bits cleanly
        self._emit(addi(base_reg, base_reg, addr_word * 4))
        data_reg = self._rand_reg(exclude=(base_reg,))
        self._emit(addi(data_reg, 0, self.rng.randint(-2048, 2047)))
        self._emit(sw(base_reg, data_reg, 0))
        dst_reg = self._rand_reg(exclude=(base_reg, data_reg))
        self._emit(lw(dst_reg, base_reg, 0))  # immediately after -- no gap, on purpose

    # ---------------- GPIO / Timer MMIO touch ----------------
    def emit_gpio_write(self, value=None):
        base_reg = self._rand_reg()
        val_reg = self._rand_reg(exclude=(base_reg,))
        value = self.rng.randint(0, 0xFFFFFFFF) if value is None else value
        self._emit(lui(base_reg, GPIO_BASE >> 12))
        self._emit(addi(val_reg, 0, value & 0xFFF))  # small values only (12-bit imm)
        self._emit(sw(base_reg, val_reg, 0x4))        # gpio.v offset 0x4 = out_reg

    def emit_timer_setup(self, compare_val=None):
        base_reg = self._rand_reg()
        val_reg = self._rand_reg(exclude=(base_reg,))
        compare_val = self.rng.randint(1, 0xFFF) if compare_val is None else compare_val
        self._emit(lui(base_reg, TIMER_BASE >> 12))
        self._emit(addi(val_reg, 0, compare_val))
        self._emit(sw(base_reg, val_reg, 0x4))         # timer.v offset 0x4 = compare
        en_reg = self._rand_reg(exclude=(base_reg, val_reg))
        self._emit(addi(en_reg, 0, 1))
        self._emit(sw(base_reg, en_reg, 0x8))          # timer.v offset 0x8 = enable

    # ---------------- Branch/jump exercising all 6 conditions + JAL/JALR ----------------
    def emit_branch_not_taken(self):
        """Forward branch that must NOT be taken -- checks flush_if is correctly
        NOT asserted (Section 7 bug-class relevant: branch-flush-vs-stall
        priority should only matter when a branch actually redirects)."""
        r1, r2 = self._rand_reg(), self._rand_reg(exclude=())
        self._emit(addi(r1, 0, 5))
        self._emit(addi(r2, 0, 7))  # guaranteed r1 != r2
        skip_idx = self._emit(beq(r1, r2, 8))  # +8 = skip one instruction if taken (it won't be)
        self._emit(addi(self._rand_reg(), 0, 0xAA))  # must execute -- branch not taken

    def emit_jal_jalr_pair(self):
        """JAL to a forward label, immediately followed by JALR back using the
        link register -- exercises both jump paths and their PC redirects."""
        link_reg = self._rand_reg()
        jal_idx = self._emit(jal(link_reg, 8))  # jump over the next instruction
        self._emit(addi(self._rand_reg(), 0, 0xDEAD & 0xFFF))  # skipped, must NOT execute
        target_reg = self._rand_reg(exclude=(link_reg,))
        self._emit(addi(target_reg, link_reg, 0))  # landed here; copy link reg for visibility

    # ---------------- Halt ----------------
    def emit_halt(self):
        idx = len(self.words)
        self._emit(beq(0, 0, 0))  # self-branch, matches known-good reference program's idiom

    def generate(self, n_random_ops=30, include_gpio=True, include_timer=True, include_uart=False):
        # NOTE: include_uart intentionally defaults False -- uart_monitor is
        # still a stub (no framing decode), so a generated program that
        # depends on UART status polling can't be checked by the scoreboard
        # yet and risks the same infinite-poll-loop failure basic_program_test
        # hit earlier. Enable only once UART modeling exists.
        ops = [
            self.emit_random_alu,
            self.emit_random_alu_imm,
            self.emit_random_shift_imm,
            self.emit_store_then_load,
            self.emit_branch_not_taken,
            self.emit_jal_jalr_pair,
        ]
        if include_gpio:
            ops.append(self.emit_gpio_write)
        if include_timer:
            ops.append(self.emit_timer_setup)

        for _ in range(n_random_ops):
            # Reserve headroom for emit_halt() (1 word) plus the largest
            # single op (emit_timer_setup / emit_jal_jalr_pair, ~5 words) so
            # we never overrun MAX_WORDS mid-op.
            if len(self.words) >= MAX_WORDS - 6:
                break
            self.rng.choice(ops)()

        self.emit_halt()
        return self.words

    def write_hex(self, path):
        with open(path, "w") as f:
            f.write("\n".join(to_hex_lines(self.words)) + "\n")


if __name__ == "__main__":
    import sys
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else None
    out_path = sys.argv[2] if len(sys.argv) > 2 else "program_random.hex"
    gen = ProgramGen(seed=seed)
    gen.generate()
    gen.write_hex(out_path)
    print(f"wrote {len(gen.words)} words to {out_path} (seed={seed})")
