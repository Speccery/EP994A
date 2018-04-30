@echo off
REM  init.cmd
REM  EP (C) 2016 Oct - Nov
REM  EP 2016-11-16 remapped certain addresses
REM    GROM 30000 -> 80000
REM    Cart 70000 -> 90000
REM    DSR  60000 -> B0000
REM    ROM  00000 -> BA000 (console 8k ROM)
REM    (Scratcpad from 68000 to B8000 but not used here)
REM 
set CONSOLE_GROM=80000
set CART_GROM=86000
set CART_ROM=90000
set CART_ROM2=92000
set CONSOLE_ROM=BA000
set DSR_ROM=B0000
if X%1X==XX goto setport4
set PORT=%1
goto continue

:setport4
set PORT=-4

:continue

memloader %PORT% 100008 cpu_reset_on.bin
memloader %PORT% %CONSOLE_ROM% boot99105_0000.bin
memloader %PORT% %CONSOLE_GROM% 994aGROM.Bin
memloader %PORT% %CART_GROM% TI-InvaG.bin
REM memloader %PORT% 100000 keyinit.bin
REM  Defender
rem memloader %PORT% %CART_ROM% Defender.C.bin
memloader %PORT% %CART_ROM% zeros8k.bin

REM clear scratchpad memory
memloader %PORT% B8300 zeros256.bin

REM Setup TMS99105 for prototyping mode with TMS99110 macro code
memloader %PORT% A0800 macrorom.bin
memloader %PORT% A1000 macrostore_1000.bin

REM  CPU out of reset
memloader %PORT% 100008 cpu_reset_off.bin

memloader %PORT% -k
