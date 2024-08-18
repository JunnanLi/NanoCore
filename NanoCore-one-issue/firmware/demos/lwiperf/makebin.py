#!/usr/bin/env python3
#
# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.

from sys import argv
import struct

binfile = argv[1]
nwords = int(argv[2])
genbinfile = argv[3]

with open(binfile, "rb") as f:
    bindata = f.read()

assert len(bindata) < 4*nwords
# assert len(bindata) % 4 == 0

with open(genbinfile, "wb") as f_gen:
    for i in range(nwords):
        if i < len(bindata) // 4:
            f_gen.write(struct.pack('B',bindata[4*i+3]))
            f_gen.write(struct.pack('B',bindata[4*i+2]))
            f_gen.write(struct.pack('B',bindata[4*i+1]))
            f_gen.write(struct.pack('B',bindata[4*i+0]))
        elif (len(bindata) % 4 == 1) and (i == len(bindata) // 4):
            f_gen.write(struct.pack('B',0))
            f_gen.write(struct.pack('B',0))
            f_gen.write(struct.pack('B',0))
            f_gen.write(struct.pack('B',bindata[4*i+0]))
        elif (len(bindata) % 4 == 2) and (i == len(bindata) // 4):
            f_gen.write(struct.pack('B',0))
            f_gen.write(struct.pack('B',0))
            f_gen.write(struct.pack('B',bindata[4*i+1]))
            f_gen.write(struct.pack('B',bindata[4*i+0]))
        elif (len(bindata) % 4 == 3) and (i == len(bindata) // 4):
            f_gen.write(struct.pack('B',0))
            f_gen.write(struct.pack('B',bindata[4*i+2]))
            f_gen.write(struct.pack('B',bindata[4*i+1]))
            f_gen.write(struct.pack('B',bindata[4*i+0]))
        else:
            f_gen.write(struct.pack('B',0))
            f_gen.write(struct.pack('B',0))
            f_gen.write(struct.pack('B',0))
            f_gen.write(struct.pack('B',0))

