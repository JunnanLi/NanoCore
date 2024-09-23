#include "firmware.h"

#ifndef _RV_PKT_H_
#define _RV_PKT_H_

int rv_send(unsigned int * ptr, unsigned int len);
int rv_recv(unsigned int * ptr);

#endif
