# init.sh
# EP (C) 2016 Oct - Nov
# EP 2016-11-16 remapped certain addresses
#   GROM 30000 -> 80000
#   Cart 70000 -> 90000
#   DSR  60000 -> B0000
#   ROM  00000 -> BA000 (console 8k ROM)
#   (Scratcpad from 68000 to B8000 but not used here)
#
export CONSOLE_GROM=80000
export CART_GROM=86000
export CART_ROM=90000
export CART_ROM2=92000
export CONSOLE_ROM=BA000
export DSR_ROM=B0000


../memloader/memloader 100008 cpu_reset_on.bin
../memloader/memloader $CONSOLE_ROM 994aROM.Bin
../memloader/memloader $CONSOLE_GROM 994aGROM.Bin
../memloader/memloader 100000 keyinit.bin

# DSR for disk support
../memloader/memloader $DSR_ROM diskdsr_4000.bin

# Extended Basic
# ../memloader/memloader $CART_ROM ../memloader/TIExtC.Bin
# ../memloader/memloader $CART_ROM2 ../memloader/TIExtD.Bin
# ../memloader/memloader $CART_GROM ../memloader/TIExtG.Bin

# Erik Test Cartridge
# ../memloader/memloader $CART_ROM ERIK1.bin

# Memory extension test
# ../memloader/memloader $CART_ROM ../memloader/AMSTEST4-8.BIN

# Editor/Assembler
# ../memloader/memloader $CART_GROM ../memloader/TIEAG.BIN

# RXB
# ../memloader/memloader $CART_ROM ../memloader/RXBC.Bin
# ../memloader/memloader $CART_ROM2 ../memloader/RXBD.Bin
# ../memloader/memloader $CART_GROM ../memloader/RXBG.Bin

# TI Invaders
../memloader/memloader $CART_ROM ../memloader/TI-InvaC.bin
../memloader/memloader $CART_GROM ../memloader/TI-InvaG.bin

# ERIK test ROM
# cp ../../../ticart/ASCART.bin .
# ../memloader/memloader $CART_ROM ASCART.bin

# Defender
# ../memloader/memloader $CART_ROM Defender.C.bin

# TI Parsec
# ../memloader/memloader $CART_ROM PARSECC.bin
# ../memloader/memloader $CART_GROM PARSECG.bin

# Alpiner
# ../memloader/memloader $CART_ROM ALPINERC.BIN
# ../memloader/memloader $CART_GROM ALPINERG.BIN

# CPU out of reset
../memloader/memloader 100008 cpu_reset_off.bin

../memloader/memloader -k
