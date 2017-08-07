# regdump.sh
# EP 2017-08-03
export CART_ROM=90000
export CONSOLE_ROM=BA000
export CONSOLE_GROM=80000
export PORT=-5

# read debug info
../memloader/memloader -r $PORT 100000 20 k.bin
hexdump -C k.bin
 
