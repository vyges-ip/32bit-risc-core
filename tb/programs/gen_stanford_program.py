#!/usr/bin/env python3

OPC = {
    "NOP": 0b000000,
    "ALUR": 0b000001,
    "ADDI": 0b000010,
    "ANDI": 0b000011,
    "ORI": 0b000100,
    "XORI": 0b000101,
    "LD": 0b001000,
    "ST": 0b001001,
    "BEQ": 0b010000,
    "BNE": 0b010001,
    "JAL": 0b011000,
    "JR": 0b011001,
    "CSR": 0b100000,
    "MUL": 0b100001,
}


def mask16(val: int) -> int:
    return val & 0xFFFF


def enc_addi(rd, rs1, imm):
    return (OPC["ADDI"] << 26) | (rd << 21) | (rs1 << 16) | mask16(imm)


def enc_alur(rd, rs1, rs2, func=0):
    return (
        (OPC["ALUR"] << 26)
        | (rs1 << 21)
        | (rs2 << 16)
        | (rd << 11)
        | ((func & 0x7) << 8)
    )


def enc_mul(rd, rs1, rs2):
    return (OPC["MUL"] << 26) | (rs1 << 21) | (rs2 << 16) | (rd << 11)


def enc_ld(rd, base, imm):
    return (OPC["LD"] << 26) | (rd << 21) | (base << 16) | mask16(imm)


def enc_st(rs_data, base, imm):
    return (OPC["ST"] << 26) | (rs_data << 21) | (base << 16) | mask16(imm)


def enc_branch(opc, rs1, rs2, imm):
    return (opc << 26) | (rs1 << 21) | (rs2 << 16) | mask16(imm)


def enc_nop():
    return 0


def main():
    FUNC_SLL = 0b110
    prog = []

    # Simple arithmetic test
    prog.append(enc_addi(1, 0, 10))  # r1 = 10
    prog.append(enc_addi(2, 0, 3))   # r2 = 3
    prog.append(enc_alur(3, 1, 2, 0))  # r3 = r1 + r2

    # Base pointer 0x0000_2000
    prog.append(enc_addi(10, 0, 0x2000))

    # Store and load sum
    prog.append(enc_st(3, 10, 0))
    prog.append(enc_ld(4, 10, 0))

    # Complex operand setup
    prog.append(enc_addi(7, 0, 16))  # shift amount for <<16

    # r12 = 20000 (real), imag = 0
    prog.append(enc_addi(12, 0, 20000))
    prog.append(enc_alur(12, 12, 7, FUNC_SLL))
    # r13 = 20000 (real), imag = 0
    prog.append(enc_addi(13, 0, 20000))
    prog.append(enc_alur(13, 13, 7, FUNC_SLL))

    # Complex multiply
    prog.append(enc_mul(5, 12, 13))

    # Conditional branch to skip increment when load result equals expectation
    prog.append(enc_branch(OPC["BEQ"], 3, 4, 2))
    prog.append(enc_addi(6, 0, 1))
    prog.append(enc_addi(6, 0, 0))

    # Store/load multiply result
    prog.append(enc_st(5, 10, 4))
    prog.append(enc_ld(8, 10, 4))

    prog.append(enc_nop())

    with open("tb/programs/stanford_risc_basic.hex", "w") as f:
        for word in prog:
            f.write(f"{word:08x}\n")


if __name__ == "__main__":
    main()

