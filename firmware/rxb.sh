../memloader/memloader 100008 cpu_reset_on.bin
../memloader/memloader 0 994aROM.Bin
../memloader/memloader 30000 994aGROM.Bin
../memloader/memloader 100000 keyinit.bin

# DSR for disk support
../memloader/memloader 60000 diskdsr_4000.bin

# Extended Basic
# ../memloader/memloader 70000 ../memloader/TIExtC.Bin
# ../memloader/memloader 72000 ../memloader/TIExtD.Bin
# ../memloader/memloader 36000 ../memloader/TIExtG.Bin

# Memory extension test
# ../memloader/memloader 70000 ../memloader/AMSTEST4-8.BIN

# Editor/Assembler
# ../memloader/memloader 36000 ../memloader/TIEAG.BIN

# RXB
../memloader/memloader 70000 ../memloader/RXBC.Bin
../memloader/memloader 72000 ../memloader/RXBD.Bin
../memloader/memloader 36000 ../memloader/RXBG.Bin

# TI Invaders
# ../memloader/memloader 70000 ../memloader/TI-InvaC.bin
# ../memloader/memloader 36000 ../memloader/TI-InvaG.bin

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
