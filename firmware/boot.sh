# boot.sh
# EP 2016-11-13
export CART_ROM=90000
export CONSOLE_ROM=BA000
export CONSOLE_GROM=80000
export PORT=-5

../memloader/memloader $PORT 100008 cpu_reset_on.bin
../memloader/memloader $PORT $CONSOLE_ROM boot99105_0000.bin
../memloader/memloader $PORT $CONSOLE_GROM 994aGROM.Bin
# ../memloader/memloader $PORT $CART_ROM Defender.C.bin
../memloader/memloader $PORT $CART_ROM zeros8k.bin
# CPU out of reset
../memloader/memloader $PORT 100008 cpu_reset_off.bin

# ../memloader/memloader $PORT -k
# read debug info
 ../memloader/memloader -r $PORT 100000 20 k.bin
 hexdump -C k.bin
 
