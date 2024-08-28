/*
 *  iCore_software -- Software for TimelyRV (RV32I) Processor Core.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Date: 2022.10.13
 *  Description: basic processing of icore_software. 
 */

#include "firmware.h"
#include <stdarg.h>

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     print funciton;                                           //
//*         1) print a char; 2) print a string;                   //
//*         3) print a dec; 4) print a hex; and 5) printf;        //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
void print_chr(char ch){
  *((volatile uint32_t*)OUTPORT) = ch;
}
void print_str(const char *p){
  while (*p != 0)
    *((volatile uint32_t*)OUTPORT) = *(p++);
}
void print_dec(unsigned int val){
  char buffer[10];
  char *p = buffer;
  while (val || p == buffer) {
    *(p++) = val % 10;
    val = val / 10;
  }
  while (p != buffer) {
    *((volatile uint32_t*)OUTPORT) = '0' + *(--p);
  }
}
void print_hex(unsigned int val, int digits){
  for (int i = (4*digits)-4; i >= 0; i -= 4)
    *((volatile uint32_t*)OUTPORT) = "0123456789ABCDEF"[(val >> i) % 16];
}
void print_void(void){}

#define PAD_RIGHT 1
#define PAD_ZERO 2
static int print(const char *format, va_list args ){
  register int width, pad;
  register int pc = 0;

  for (; *format != 0; ++format) {
    if (*format == '%') {
      ++format;
      width = pad = 0;
      if (*format == '\0') break;
      if (*format == '%') goto out;
      if (*format == '-') {
        ++format;
        pad = PAD_RIGHT;
      }
      while (*format == '0') {
        ++format;
        pad |= PAD_ZERO;
      }
      for ( ; *format >= '0' && *format <= '9'; ++format) {
        width *= 10;
        width += *format - '0';
      }
      if( *format == 's' ) {
        register char *s = (char *)va_arg( args, int );
        print_str(s);
        continue;
      }
      if( *format == 'd' ) {
        print_dec(va_arg( args, int ));
        pc += 1;
        continue;
      }
      if( *format == 'x' ) {
        print_hex(va_arg( args, int ), width);
        pc += 1;
        continue;
      }
      if( *format == 'X' ) {
        print_hex(va_arg( args, int ), width);
        pc += 1;
        continue;
      }
      if( *format == 'u' ) {
        print_dec(va_arg( args, int ));
        pc += 1;
        continue;
      }
      if( *format == 'c' ) {
        /* char are converted to int then pushed on the stack */
        print_chr((char)va_arg( args, int ));
        pc += 1;
        continue;
      }
    }
    else {
    out:
      print_chr (*format);
      ++pc;
    }
  }
  va_end( args );
  return pc;
}

int printf(const char *format, ...){
  va_list args;
  int ret;
  // unsigned int flags;

  // flags = __irq_save();
  va_start( args, format );
  ret = print(format, args );
  // __irq_restore(flags);
  return ret;
}

// int sprintf(char *out, const char *format, ...){
//  va_list args;

//  va_start( args, format );
//  return print( &out, format, args );
// }

// int __vprintf(const char *format, va_list args){
//  int ret;
//  unsigned int flags;

//  flags = __irq_save();
//  ret = print( 0, format, args );
//  __irq_restore(flags);
//  return ret;
// }

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     sys_gettime, i.e., gettimeofday                           //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
void sys_gettime(struct time_spec *timer){
  uint32_t *addr = (uint32_t *) TIMER_S_ADDR;
  timer->tv_sec = *((volatile uint32_t*)addr);
  timer->tv_nsec = *((volatile uint32_t*)addr+4);
}


//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     finish function, i.e., stop program;                      //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
// void sys_finish(void){
//   print_str("Finish!\n");
//   uint32_t *addr;
//   addr = (uint32_t *) FINISH_ADDR;
//   *((volatile uint32_t*)addr) = 1;
// }

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     Memory process                                            //
//*     1) memcpy; 2) memset; 3) memcmp; 4) memmove;              //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
void *memcpy(void *aa, const void *bb, long n)
{
  // printf("**MEMCPY**\n");
  char *a = aa;
  const char *b = bb;
  while (n--) *(a++) = *(b++);
  return aa;
}

void* memset(void* dst,int val, size_t count)
{
    void* ret = dst;
    while(count--)
    {
        *(char*)dst = (char)val;
        dst = (char*)dst + 1;
    }
    return ret;
}

int memcmp(const void *buffer1,const void *buffer2,int count)
{

   if (!count)

      return(0);

   while ( --count && *(char *)buffer1 == *(char *)buffer2)

   {

      buffer1 = (char *)buffer1 + 1;

        buffer2 = (char *)buffer2 + 1;

   }

   return( *((unsigned char *)buffer1) - *((unsigned char *)buffer2) );

}
void* memmove(void* dest, const void* src, size_t n)
{
    char * d  = (char*) dest;
    const char * s = (const char*) src;
   
    if (s>d)
    {
         // start at beginning of s
         while (n--)
            *d++ = *s++;
    }
    else if (s<d)
    {
        // start at end of s
        d = d+n-1;
        s = s+n-1;
   
        while (n--)
           *d-- = *s--;
    }
     
    return dest;
}

//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     string process                                            //
//*     1) strnlen; 2) strlen; 3) strcpy; 4) strcmp; 5) strncmp;  //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
size_t strnlen(const char *str, size_t maxsize)
{
    size_t n;
    for (n = 0; n < maxsize && *str; n++, str++)
        ;
    return n;
}

size_t strlen (const char * str)
{      
        const char *eos = str;
 
        while( *eos++ ) ;
 
        return( eos - str - 1 );
}

char *strcpy(char* dst, const char* src)
{
  char *r = dst;

  while ((((uint32_t)dst | (uint32_t)src) & 3) != 0)
  {
    char c = *(src++);
    *(dst++) = c;
    if (!c) return r;
  }

  while (1)
  {
    uint32_t v = *(uint32_t*)src;

    if (__builtin_expect((((v) - 0x01010101UL) & ~(v) & 0x80808080UL), 0))
    {
      dst[0] = v & 0xff;
      if ((v & 0xff) == 0)
        return r;
      v = v >> 8;

      dst[1] = v & 0xff;
      if ((v & 0xff) == 0)
        return r;
      v = v >> 8;

      dst[2] = v & 0xff;
      if ((v & 0xff) == 0)
        return r;
      v = v >> 8;

      dst[3] = v & 0xff;
      return r;
    }

    *(uint32_t*)dst = v;
    src += 4;
    dst += 4;
  }
}

int strcmp(const char *s1, const char *s2)
{
  while ((((uint32_t)s1 | (uint32_t)s2) & 3) != 0)
  {
    char c1 = *(s1++);
    char c2 = *(s2++);

    if (c1 != c2)
      return c1 < c2 ? -1 : +1;
    else if (!c1)
      return 0;
  }

  while (1)
  {
    uint32_t v1 = *(uint32_t*)s1;
    uint32_t v2 = *(uint32_t*)s2;

    if (__builtin_expect(v1 != v2, 0))
    {
      char c1, c2;

      c1 = v1 & 0xff, c2 = v2 & 0xff;
      if (c1 != c2) return c1 < c2 ? -1 : +1;
      if (!c1) return 0;
      v1 = v1 >> 8, v2 = v2 >> 8;

      c1 = v1 & 0xff, c2 = v2 & 0xff;
      if (c1 != c2) return c1 < c2 ? -1 : +1;
      if (!c1) return 0;
      v1 = v1 >> 8, v2 = v2 >> 8;

      c1 = v1 & 0xff, c2 = v2 & 0xff;
      if (c1 != c2) return c1 < c2 ? -1 : +1;
      if (!c1) return 0;
      v1 = v1 >> 8, v2 = v2 >> 8;

      c1 = v1 & 0xff, c2 = v2 & 0xff;
      if (c1 != c2) return c1 < c2 ? -1 : +1;
      return 0;
    }

    if (__builtin_expect((((v1) - 0x01010101UL) & ~(v1) & 0x80808080UL), 0))
      return 0;

    s1 += 4;
    s2 += 4;
  }
}

int strncmp(const char* str1, const char* str2 ,int size) {
  for (int i = 0; i < size; ++i) {
    if (*(str1 + i) > *(str2 + i)) {
      return 1;
    }
    else if (*(str1 + i) < *(str2 + i)) {
      return -1;
    }
    if (*(str1 + i) == 0 || *(str2 + i) == 0) {
      break;
    }
  }
  return 0;
}


//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
//*     format transform                                          //
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//
int atoi(const char *str) {
  int s = 0;
  bool falg = false;
  
  while(*str == ' ') str++;

  if(*str == '-' || *str == '+') {
    if(*str == '-')
    falg = true;
    str++;
  }

  while(*str >= '0' && *str <= '9') {
    s= s*10 + *str - '0';
    str++;
    if(s < 0) {
      s = 2147483647;
      break;
    }
  }
  return s * (falg? -1 : 1);
}