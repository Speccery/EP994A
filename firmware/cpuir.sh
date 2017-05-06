# cpuir.sh
# EP 2017-05-05 read instruction register and PC of the CPU
# read debug info
 ../memloader/memloader -r -5 100000 20 k.bin
 hexdump -C k.bin
 
