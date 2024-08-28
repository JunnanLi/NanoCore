/*
 *  ISA_Test for a modified Cv32e40p (RV32IMC) Processor Core.
 *
 *  Copyright (C) 2021-2023 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Date: 2023.04.23
 *  Description: Used to test RISC-V ISA. 
 */

	/* running tests from riscv-tests */

#define TEST(n) \
	.global n; \
	addi x1, zero, 1000; \
	jal zero,n; \
	.global n ## _ret; \
	n ## _ret:

.global __TEST_RV32UI_ISA
    .type   __TEST_RV32UI_ISA, @function
__TEST_RV32UI_ISA:
    addi sp, sp, -32
    sw x1,   -1*4(sp)
    jal ra, __SAVE_CURRENT_ENV
    addi sp, sp, 32

	TEST(lui)
	TEST(auipc)
	TEST(j)
	TEST(jal)
	TEST(jalr)

	TEST(beq)
	TEST(bne)
	TEST(blt)
	TEST(bge)
	TEST(bltu)
	TEST(bgeu)

	TEST(lb)
	TEST(lh)
	TEST(lw)
	TEST(lbu)
	TEST(lhu)

	TEST(sb)
	TEST(sh)
	TEST(sw)

	TEST(addi)
	TEST(slti) // also tests sltiu
	TEST(xori)
	TEST(ori)
	TEST(andi)
	TEST(slli)
	TEST(srli)
	TEST(srai)

	TEST(add)
	TEST(sub)
	TEST(sll)
	TEST(slt) // what is with sltu ?
	TEST(xor)
	TEST(srl)
	TEST(sra)
	TEST(or)
	TEST(and)

	TEST(simple)

    addi sp, sp, -32
	jal ra,  __LOAD_CURRENT_ENV
    lw x1,   -1*4(sp)
    addi sp, sp, 32
    ret
    .size   __TEST_RV32UI_ISA, . - __TEST_RV32UI_ISA


.global __TEST_RV32UM_ISA
    .type   __TEST_RV32UM_ISA, @function
__TEST_RV32UM_ISA:
    addi sp, sp, -32
    sw x1,   -1*4(sp)
    jal ra, __SAVE_CURRENT_ENV
    addi sp, sp, 32

    TEST(mulh)
	TEST(mulhsu)
	TEST(mulhu)
	TEST(mul)

	TEST(div)
	TEST(divu)
	TEST(rem)
	TEST(remu)

    addi sp, sp, -32
	jal ra,  __LOAD_CURRENT_ENV
    lw x1,   -1*4(sp)
    addi sp, sp, 32
    ret
    .size   __TEST_RV32UM_ISA, . - __TEST_RV32UM_ISA


__SAVE_CURRENT_ENV:
    // sw x1,   -1*4(sp)
    sw x2,   -2*4(sp)            //* save previous x2-x31;
    sw x3,   -3*4(sp)            
    sw x4,   -4*4(sp)
    sw x5,   -5*4(sp)
    sw x6,   -6*4(sp)
    sw x7,   -7*4(sp)
    sw x8,   -8*4(sp)
    sw x9,   -9*4(sp)
    sw x10, -10*4(sp)
    sw x11, -11*4(sp)
    sw x12, -12*4(sp)
    sw x13, -13*4(sp)
    sw x14, -14*4(sp)
    sw x15, -15*4(sp)
    sw x16, -16*4(sp)
    sw x17, -17*4(sp)
    sw x18, -18*4(sp)
    sw x19, -19*4(sp)
    sw x20, -20*4(sp)
    sw x21, -21*4(sp)
    sw x22, -22*4(sp)
    sw x23, -23*4(sp)
    sw x24, -24*4(sp)
    sw x25, -25*4(sp)
    sw x26, -26*4(sp)
    sw x27, -27*4(sp)
    sw x28, -28*4(sp)
    sw x29, -29*4(sp)
    sw x30, -30*4(sp)
    sw x31, -31*4(sp)
    ret

__LOAD_CURRENT_ENV:
    // lw x2,   -2*4(sp)            //* save previous x2-x31;
    lw x3,   -3*4(sp)            
    lw x4,   -4*4(sp)
    lw x5,   -5*4(sp)
    lw x6,   -6*4(sp)
    lw x7,   -7*4(sp)
    lw x8,   -8*4(sp)
    lw x9,   -9*4(sp)
    lw x10, -10*4(sp)
    lw x11, -11*4(sp)
    lw x12, -12*4(sp)
    lw x13, -13*4(sp)
    lw x14, -14*4(sp)
    lw x15, -15*4(sp)
    lw x16, -16*4(sp)
    lw x17, -17*4(sp)
    lw x18, -18*4(sp)
    lw x19, -19*4(sp)
    lw x20, -20*4(sp)
    lw x21, -21*4(sp)
    lw x22, -22*4(sp)
    lw x23, -23*4(sp)
    lw x24, -24*4(sp)
    lw x25, -25*4(sp)
    lw x26, -26*4(sp)
    lw x27, -27*4(sp)
    lw x28, -28*4(sp)
    lw x29, -29*4(sp)
    lw x30, -30*4(sp)
    lw x31, -31*4(sp)
    ret