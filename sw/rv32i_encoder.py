OPCODE_LOAD   = 0b0000011
OPCODE_STORE  = 0b0100011
OPCODE_BRANCH = 0b1100011
OPCODE_OP_IMM = 0b0010011
OPCODE_OP     = 0b0110011
OPCODE_LUI    = 0b0110111
OPCODE_AUIPC  = 0b0010111
OPCODE_JAL    = 0b1101111
OPCODE_JALR   = 0b1100111


def _r(rd, rs1, rs2, funct3, funct7):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | OPCODE_OP


def _i_alu(rd, rs1, imm, funct3, funct7=0):
    if funct3 in (0b001, 0b101):
        field = (funct7 << 5) | (imm & 0x1F)
    else:
        field = imm & 0xFFF
    return (field << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | OPCODE_OP_IMM


def _load(rd, rs1, imm, funct3):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | OPCODE_LOAD


def _store(rs1, rs2, imm, funct3):
    imm11_5 = (imm >> 5) & 0x7F
    imm4_0  = imm & 0x1F
    return (imm11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm4_0 << 7) | OPCODE_STORE


def _branch(rs1, rs2, imm, funct3):
    imm12   = (imm >> 12) & 0x1
    imm11   = (imm >> 11) & 0x1
    imm10_5 = (imm >> 5) & 0x3F
    imm4_1  = (imm >> 1) & 0xF
    return (imm12 << 31) | (imm10_5 << 25) | (rs2 << 20) | (rs1 << 15) | \
           (funct3 << 12) | (imm4_1 << 8) | (imm11 << 7) | OPCODE_BRANCH


def _jal(rd, imm):
    imm20    = (imm >> 20) & 0x1
    imm10_1  = (imm >> 1)  & 0x3FF
    imm11    = (imm >> 11) & 0x1
    imm19_12 = (imm >> 12) & 0xFF
    return (imm20 << 31) | (imm10_1 << 21) | (imm11 << 20) | (imm19_12 << 12) | (rd << 7) | OPCODE_JAL


def _u(rd, imm20, opcode):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | opcode


def add(rd, rs1, rs2):  return _r(rd, rs1, rs2, 0b000, 0x00)
def sub(rd, rs1, rs2):  return _r(rd, rs1, rs2, 0b000, 0x20)
def sll(rd, rs1, rs2):  return _r(rd, rs1, rs2, 0b001, 0x00)
def slt(rd, rs1, rs2):  return _r(rd, rs1, rs2, 0b010, 0x00)
def sltu(rd, rs1, rs2): return _r(rd, rs1, rs2, 0b011, 0x00)
def xor_(rd, rs1, rs2): return _r(rd, rs1, rs2, 0b100, 0x00)
def srl(rd, rs1, rs2):  return _r(rd, rs1, rs2, 0b101, 0x00)
def sra(rd, rs1, rs2):  return _r(rd, rs1, rs2, 0b101, 0x20)
def or_(rd, rs1, rs2):  return _r(rd, rs1, rs2, 0b110, 0x00)
def and_(rd, rs1, rs2): return _r(rd, rs1, rs2, 0b111, 0x00)

def addi(rd, rs1, imm):  return _i_alu(rd, rs1, imm, 0b000)
def slti(rd, rs1, imm):  return _i_alu(rd, rs1, imm, 0b010)
def sltiu(rd, rs1, imm): return _i_alu(rd, rs1, imm, 0b011)
def xori(rd, rs1, imm):  return _i_alu(rd, rs1, imm, 0b100)
def ori(rd, rs1, imm):   return _i_alu(rd, rs1, imm, 0b110)
def andi(rd, rs1, imm):  return _i_alu(rd, rs1, imm, 0b111)
def slli(rd, rs1, shamt):  return _i_alu(rd, rs1, shamt, 0b001, 0x00)
def srli(rd, rs1, shamt):  return _i_alu(rd, rs1, shamt, 0b101, 0x00)
def srai(rd, rs1, shamt):  return _i_alu(rd, rs1, shamt, 0b101, 0x20)

def lui(rd, imm20):   return _u(rd, imm20, OPCODE_LUI)
def auipc(rd, imm20): return _u(rd, imm20, OPCODE_AUIPC)

def lb(rd, rs1, imm):  return _load(rd, rs1, imm, 0b000)
def lh(rd, rs1, imm):  return _load(rd, rs1, imm, 0b001)
def lw(rd, rs1, imm):  return _load(rd, rs1, imm, 0b010)
def lbu(rd, rs1, imm): return _load(rd, rs1, imm, 0b100)
def lhu(rd, rs1, imm): return _load(rd, rs1, imm, 0b101)

def sb(rs1, rs2, imm): return _store(rs1, rs2, imm, 0b00)
def sh(rs1, rs2, imm): return _store(rs1, rs2, imm, 0b01)
def sw(rs1, rs2, imm): return _store(rs1, rs2, imm, 0b10)

def beq(rs1, rs2, imm):  return _branch(rs1, rs2, imm, 0b000)
def bne(rs1, rs2, imm):  return _branch(rs1, rs2, imm, 0b001)
def blt(rs1, rs2, imm):  return _branch(rs1, rs2, imm, 0b100)
def bge(rs1, rs2, imm):  return _branch(rs1, rs2, imm, 0b101)
def bltu(rs1, rs2, imm): return _branch(rs1, rs2, imm, 0b110)
def bgeu(rs1, rs2, imm): return _branch(rs1, rs2, imm, 0b111)

def jal(rd, imm): return _jal(rd, imm)

def jalr(rd, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (0b000 << 12) | (rd << 7) | OPCODE_JALR


def to_hex_lines(words):
    return [f"{w & 0xFFFFFFFF:08x}" for w in words]
