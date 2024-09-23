include lwip_v213/Makefile.lwip
# include lwip_v213/Makefile_141.lwip
include lwip_v213/Makefile.adapter

OUTS = obj/*.o
OBJ_DIR = obj
LWIP_OBJ1 = $(LWIP_OBJS) $(ADAPTER_OBJS)
LWIP_OBJ = $(addprefix lwip_v213/$(OBJ_DIR)/,$(LWIP_OBJ1))
INCLUDEFILES = $(LWIP_INCLUDES) $(ADAPTER_INCLUDES)  
LWIP_INCLUDEFILES = $(addprefix lwip_v213/,$(INCLUDEFILES))