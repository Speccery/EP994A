# boot.sh
# EP 2016-11-13
../memloader/memloader 100008 cpu_reset_on.bin
../memloader/memloader 0 boot99105_0000.bin
# CPU out of reset
../memloader/memloader 100008 cpu_reset_off.bin
../memloader/memloader -k
