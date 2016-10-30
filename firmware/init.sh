../memloader/memloader 100008 cpu_reset_on.bin
../memloader/memloader 0 994aROM.Bin
../memloader/memloader 30000 994aGROM.Bin
../memloader/memloader 100000 keyinit.bin


# Extended Basic
# ../memloader/memloader 70000 ../memloader/TIExtC.Bin
# ../memloader/memloader 72000 ../memloader/TIExtD.Bin
# ../memloader/memloader 36000 ../memloader/TIExtG.Bin

# RXB
# ../memloader/memloader 70000 ../memloader/RXBC.Bin
# ../memloader/memloader 72000 ../memloader/RXBD.Bin
# ../memloader/memloader 36000 ../memloader/RXBG.Bin

# TI Invaders
../memloader/memloader 70000 TI-InvaC.bin
../memloader/memloader 36000 TI-InvaG.bin

# ERIK test ROM
# cp ../../../ticart/ASCART.bin .
# ../memloader/memloader 70000 ASCART.bin

# Defender
# ../memloader/memloader 70000 Defender.C.bin

# TI Parsec
# ../memloader/memloader 70000 PARSECC.bin
# ../memloader/memloader 36000 PARSECG.bin

# Alpiner
# ../memloader/memloader 70000 ALPINERC.BIN
# ../memloader/memloader 36000 ALPINERG.BIN

# CPU out of reset
../memloader/memloader 100008 cpu_reset_off.bin

../memloader/memloader -k
