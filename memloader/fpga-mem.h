// fpga-mem.h

#pragma once

void ReadMemoryBlock(unsigned char *dest, unsigned address, int len);

int WriteMemoryBlock(unsigned char *source, unsigned address, int len);


