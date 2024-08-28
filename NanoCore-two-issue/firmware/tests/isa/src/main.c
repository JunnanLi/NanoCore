/*
 *  ISA_Test for a modified Cv32e40p (RV32IMC) Processor Core.
 *
 *  Copyright (C) 2021-2023 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Date: 2023.04.23
 *  Description: Used to test RISC-V ISA. 
 */

#include "firmware.h"

void main(void){
    printf("\rsystem boot finished\r\n");
    irq_init();

    //* test isa;
    __TEST_RV32UI_ISA();
    __TEST_RV32UM_ISA();
    printf("ISA test is pased\r\n");
    while(1);
}

