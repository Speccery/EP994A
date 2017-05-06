# boot.sh
# EP 2016-11-13
../memloader/memloader -5 100008 cpu_reset_on.bin
../memloader/memloader -5 BA000 boot99105_0000.bin
# CPU out of reset
../memloader/memloader -5 100008 cpu_reset_off.bin
# ../memloader/memloader -5 -k
# read debug info
 ../memloader/memloader -r -5 100000 20 k.bin
 hexdump -C k.bin
 
