#include "firmware.h"

#ifndef _SYSTEM_H_
#define _SYSTEM_H_

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     finish function, i.e., stop program;   //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
// void sys_finish(void);


//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     print funciton;                        //
//*         1) print a char; 2) print a string;//
//*         3) print a dec; 4) print a hex;    //
//*         5) printf;                         //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
void print_chr(char ch);
void print_str(const char *p);
void print_dec(unsigned int val);
void print_hex(unsigned int val, int digits);
int  printf(const char *format, ...);
void print_void(void);

// //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
// //*     sys_gettime, i.e., gettimeofday        //
// //<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
// void sys_gettime(struct time_spec *timer);

// //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
// //*     time, used to read CSR_MCYCLE          //
// //<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
// long time(long * value);


// //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
// //*     insn, used to read CSR_MINSTRET        //
// //<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
// long insn(long * value);

// //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
// //*     Memory process                         //
// //<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
// void *memcpy(void *aa, const void *bb, long n);
// void* memset(void* dst,int val, size_t count);
// int memcmp(const void *buffer1,const void *buffer2,int count);
// void* memmove(void* dest, const void* src, size_t n);

// //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
// //*     string process                         //
// //<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
// size_t strnlen(const char *str, size_t maxsize);
// size_t strlen (const char * str);
// char *strcpy(char* dst, const char* src);
// int strcmp(const char *s1, const char *s2);
// int strncmp(const char* str1, const char* str2 ,int size);

// //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
// //*     format transform                       //
// //<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
// int custom_atoi(const char *str);



#endif
