#ifndef _ENV_PICORV32_TEST_H
#define _ENV_PICORV32_TEST_H

#ifndef TEST_FUNC_NAME
#  define TEST_FUNC_NAME mytest
#  define TEST_FUNC_TXT "mytest"
#  define TEST_FUNC_TXT_DATA mytest_data
#  define TEST_FUNC_RET mytest_ret
#endif

#define RVTEST_RV32U
#define TESTNUM x28

#define RVTEST_CODE_BEGIN		\
	.text;				\
	.global TEST_FUNC_NAME;		\
	.global TEST_FUNC_RET;		\
TEST_FUNC_NAME:				\
	addi x30,sp,0;			\
	sw gp,-4(sp);			\
	sw ra,-8(sp);			\
	lui	a0,%hi(TEST_FUNC_TXT_DATA);	\
	addi	a0,a0,%lo(TEST_FUNC_TXT_DATA);	\
	li	a2,0x10010004;	\
.prname_next:				\
	lb	a1,0(a0);		\
	beq	a1,zero,.prname_done;	\
	sw	a1,0(a2);		\
	addi	a0,a0,1;		\
	jal	zero,.prname_next;	\
.prname_done:				\
	addi	a1,zero,'.';		\
	sw	a1,0(a2);		\
	sw	a1,0(a2);       
	

#define RVTEST_PASS			\
	.text;				\
	li	a0,0x10010004;	\
	addi	a1,zero,'O';		\
	addi	a2,zero,'K';		\
	addi	a3,zero,'\n';		\
	sw	a1,0(a0);		\
	sw	a2,0(a0);		\
	sw	a3,0(a0);		\
	addi sp,x30,0;		\
	lw gp,-4(sp);		\
	lw ra,-8(sp);			\
	jal	zero,TEST_FUNC_RET;

#define RVTEST_FAIL			\
	.text;				\
	li	a0,0x10010004;	\
	addi	a1,zero,'E';		\
	addi	a2,zero,'R';		\
	addi	a3,zero,'O';		\
	addi	a4,zero,'\n';		\
	sw	a1,0(a0);		\
	sw	a2,0(a0);		\
	sw	a2,0(a0);		\
	sw	a3,0(a0);		\
	sw	a2,0(a0);		\
	sw	a4,0(a0);		\
	ebreak;

#define RVTEST_CODE_END

#define RVTEST_DATA_BEGIN
	.data;				\
	.global TEST_FUNC_TXT_DATA;		\
TEST_FUNC_TXT_DATA:				\
	.ascii TEST_FUNC_TXT;		\
	.byte 0x00;			\
	.balign 4, 0;		\

#define RVTEST_DATA_END


#endif
