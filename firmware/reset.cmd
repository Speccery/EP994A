REM Reset CPU
memloader %PORT% 100008 cpu_reset_on.bin
memloader %PORT% 100008 cpu_reset_off.bin

memloader %PORT% -k