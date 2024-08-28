./src/global_head.svh
./src/core_part/NanoCore_pkg.sv
./src/core_part/N2_ifu.sv
./src/core_part/N2_idu.sv
./src/core_part/N2_idu_decode.sv
./src/core_part/N2_exec.sv
./src/core_part/N2_lsu.sv
./src/core_part/N2_mu.sv
./src/core_part/NanoCore.sv
./src/core_part/N2_idu_predecode.sv
./src/core_part/Irq_Calc_Offset.sv
./src/core_part/NanoCore_Wrapper.sv
./src/mem_part/Memory_Top_2Port.sv
./src/mem_part/SRAM_Wrapper.sv
./src/mem_part/Cache/NanoCache_Top_2Port.sv
./src/mem_part/Cache/NanoCache_Search.sv
./src/mem_part/Cache/NanoCache_Update.sv

./src/peripherals_part/Peri_Top.sv
./src/peripherals_part/bus_part/Interrupt_Ctrl.sv
./src/peripherals_part/bus_part/Periperal_Bus.sv
./src/peripherals_part/uart_part/UART_TOP.v
./src/peripherals_part/uart_part/UART_Ctrl.sv
./src/peripherals_part/uart_part/UART_Recv.v
./src/peripherals_part/uart_part/UART_Trans.v
./src/peripherals_part/uart_part/Gen_Baud_Rate.v
./src/peripherals_part/regs_part/CSR_TOP.v

./src/peripherals_part/pkt_part/Pkt_Proc_Top.sv
./src/peripherals_part/pkt_part/Pkt_DMUX.sv
./src/peripherals_part/pkt_part/Pkt_MUX.sv
./src/peripherals_part/pkt_part/PE_Config.sv
./src/peripherals_part/pkt_part/Pkt_TCP_CRC.sv
./src/peripherals_part/pkt_part/dma_part/DMA_Engine.sv
./src/peripherals_part/pkt_part/dma_part/DMA_Peri.v
./src/peripherals_part/pkt_part/dma_part/regfifo_32b_4.v
./src/peripherals_part/pkt_part/dma_part/regfifo_48b_8.v
./src/peripherals_part/pkt_part/dma_part/regfifo_64b_8.v
./src/peripherals_part/pkt_part/dma_part/regfifo_17b_8.v
./src/peripherals_part/pkt_part/dma_part/DMA_Wr_Rd_DataRam.sv

./src/core_part/MultiCore_Top.sv
./src/NanoCore_SoC.sv


./src/sim_rtl/asyncfifo.v
./src/sim_rtl/syncfifo.v
./src/sim_rtl/syncram.v


./testbench.sv
# ./testbench_crc.sv
#./testbench_testLwIP.sv