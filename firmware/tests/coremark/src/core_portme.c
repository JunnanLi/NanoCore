#include <stdio.h>
// #include <stdlib.h>
#include "coremark.h"
#include "firmware.h"
// #include "../include/utils.h"
// #include "../include/uart.h"
// #include "../include/xprintf.h"

#if VALIDATION_RUN
	volatile ee_s32 seed1_volatile=0x3415;
	volatile ee_s32 seed2_volatile=0x3415;
	volatile ee_s32 seed3_volatile=0x66;
#endif

#if PERFORMANCE_RUN
	volatile ee_s32 seed1_volatile=0x0;
	volatile ee_s32 seed2_volatile=0x0;
	volatile ee_s32 seed3_volatile=0x66;
#endif

#if PROFILE_RUN
	volatile ee_s32 seed1_volatile=0x8;
	volatile ee_s32 seed2_volatile=0x8;
	volatile ee_s32 seed3_volatile=0x8;
#endif

volatile ee_s32 seed4_volatile=ITERATIONS;
volatile ee_s32 seed5_volatile=0;

CORE_TICKS t0_s, t0_ns, t1_s, t1_ns;


void start_time(void)
{
  uint32_t *addr = (uint32_t *) CSR_READ_SYSTIME_NS;
  t0_ns = *((volatile uint32_t*)addr);
  addr = (uint32_t *) CSR_READ_SYSTIME_S;
  t0_s = *((volatile uint32_t*)addr);
}

void stop_time(void)
{
  uint32_t *addr = (uint32_t *) CSR_READ_SYSTIME_NS;
  t1_ns = *((volatile uint32_t*)addr);
  addr = (uint32_t *) CSR_READ_SYSTIME_S;
  t1_s = *((volatile uint32_t*)addr);
  printf("t0: %d, %d\n\r", t0_s, t0_ns);
  printf("t1: %d, %d\n\r", t1_s, t1_ns);
}

CORE_TICKS get_time(void)
{
  CORE_TICKS t_ms = (t1_s - t0_s) * 1000;
  if(t1_ns > t0_ns){
    t_ms += (t1_ns - t0_ns) / 1000000;
  }
  else {
    t_ms -= (t0_ns - t1_ns) / 1000000;
  }
  ee_printf("spend time in ms: %d\n",t_ms);

  return t_ms;
}

secs_ret time_in_secs(CORE_TICKS time_in_ms)
{
  // scale timer down to avoid uint64_t -> double conversion in RV32
  // int scale = 256;
  // uint32_t delta = ticks / scale;
  // uint32_t delta = ticks;
  // uint32_t freq = CPU_FREQ_HZ >> SHIFT_TO_SCALE;
  // return delta / (double)freq;
  return time_in_ms/1000;
}

void portable_init(core_portable *p, int *argc, char *argv[])
{
    // uart_init();
}
