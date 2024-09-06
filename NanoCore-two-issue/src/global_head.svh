/*************************************************************/
//  Module name: global_head
//  Authority @ lijunnan (lijunnan@nudt.edu.cn)
//  Last edited time: 2024/02/19
//  Function outline: head file
/*************************************************************/



  //==============================================================//
  //  user defination
  //==============================================================//
  //* hardware version configuration
    `define HW_VERSION      32'h2_01_00
  //=========================//
  //* pe core configuration;
  `define NUM_PE 1
  `define ENABLE_MUL
  `define ENABLE_IRQ
  `define ENABLE_BP                 //* branch predict
  //=========================//
  //* peri configuration;
    `define ENABLE_UART             //* Address 1002xxxx is always for UART;
    `define ENABLE_CSR              //* Address 1004xxxx is always for UART;
    `define ENABLE_DMA              //* Address 1007xxxx is always for DMA;
    // `define ENABLE_DRA              //* Address 1008xxxx is always for DRA;
  //=========================//
  //* instr/data memory size;
  // `define MEM_64KB
  // `define MEM_128KB
  `define MEM_256KB
  //=========================//
  //* Using Xilinx's FIFO/SRAM IP cores
  // `define XILINX_FIFO_RAM
  `define SIM_FIFO_RAM
  `define DATA_SRAM_noBUFFER
  //=========================//
  //* Frequency
    `define NS_PER_CLK      8'd8  //* 125MHz
  //=========================//
  //* Cache Entry
  `define NUM_CACHE  4    //* 2/4/8
  //=========================//
  //* Debug
  // `define DEBUGNETS
  // `define DEBUGASM
  // `define DEBUG
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  // conguration according user defination, DO NOT NEED TO MODIFY!!!
  //==============================================================//
  //* peri configuration;
    `ifdef ENABLE_UART
      `define UART_PERI     1
    `else
      `define UART_PERI     0
    `endif
    `ifdef ENABLE_CSR
      `define CSR_PERI      1
    `else
      `define CSR_PERI      0
    `endif
    `ifdef ENABLE_DMA
      `define DMA_PERI      1
    `else
      `define DMA_PERI      0
    `endif
    `ifdef ENABLE_DRA
      `define DRA_PERI      1
    `else
      `define DRA_PERI      0
    `endif
  //* periID
    `define UART            0  
    `define CSR             (`UART_PERI+`CSR_PERI-1)
    `define DMA             (`UART_PERI+`CSR_PERI+`DMA_PERI-1)
    `define DRA             (`UART_PERI+`CSR_PERI+`DMA_PERI+`DRA_PERI-1)
  //* Number of Peripherals
    `define NUM_PERI        (`UART_PERI+`CSR_PERI+`DMA_PERI+`DRA_PERI) 

    //* irq_defination;
    `define TIME_IRQ        7   //* time irq id, TODO: should before peri
                                //*   to have a higher priority;
    `define UART_IRQ        16  
    `define DMA_IRQ         22  
    `define DRA_IRQ         23
    `ifdef MEM_256KB
      `define MEM_TAG       15  
    `elsif MEM_128KB
      `define MEM_TAG       14
    `endif
  //=========================//
  //* open display function for UART
    `define OPEN_DISPLAY     
    // `define UART_BY_PKT     
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
