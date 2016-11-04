# EP 2016-10-28
../memloader/memloader 100008 cpu_reset_on.bin
../memloader/memloader 0 994aROM.Bin
../memloader/memloader 30000 994aGROM.Bin
../memloader/memloader 100000 keyinit.bin


# Extended Basic
../memloader/memloader 70000 TIExtC.Bin
../memloader/memloader 72000 TIExtD.Bin
../memloader/memloader 36000 TIExtG.Bin

# CPU out of reset
../memloader/memloader 100008 cpu_reset_off.bin
../memloader/memloader -k

