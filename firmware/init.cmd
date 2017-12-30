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
rem set CART_ROM=90000
rem set CART_ROM2=92000
set CART_ROM=0
set CART_ROM2=2000
set CONSOLE_ROM=BA000
set DSR_ROM=B0000
if X%1X==XX goto setport4
set PORT=%1
goto continue

:setport4
set PORT=-4

:continue

memloader %PORT% 100008 cpu_reset_on.bin
REM memloader %PORT% %CONSOLE_ROM% boot99105_0000.bin
memloader %PORT% %CONSOLE_ROM% 994aROM.Bin
memloader %PORT% %CONSOLE_GROM% 994aGROM-EP.Bin
REM memloader %PORT% 100000 keyinit.bin

REM  DSR for disk support
memloader %PORT% %DSR_ROM% diskdsr_4000.bin

REM  Extended Basic
REM goto skipex
memloader %PORT% %CART_ROM% TIExtC.Bin
memloader %PORT% %CART_ROM2% TIExtD.Bin
memloader %PORT% %CART_GROM% TIExtG.Bin
:skipex

REM  Erik Test Cartridge
rem memloader %PORT% %CART_ROM% ..\..\projects\ticart\ERIK1.bin

REM  Memory extension test
rem memloader %PORT% %CART_ROM% ..\memloader\AMSTEST4-8.BIN

REM  Editor/Assembler
rem memloader %PORT% %CART_GROM% TIEAG.BIN

REM  RXB
rem memloader %PORT% %CART_ROM% RXBC.Bin
rem memloader %PORT% %CART_ROM2% RXBD.Bin
rem memloader %PORT% %CART_GROM% RXBG.Bin

REM  TI Invaders 
rem memloader %PORT% %CART_ROM% TI-InvaC.bin
rem memloader %PORT% %CART_GROM% TI-InvaG.bin

REM Don't mess
REM memloader  %PORT% %CART_ROM% dontmess.bin

REM  ERIK test ROM
goto skip_test_rom
copy ..\..\projects\ticart\ASCART.bin .
memloader %PORT% %CART_ROM% ASCART.bin
:skip_test_rom

REM  Defender
rem memloader %PORT% %CART_ROM% Defender.C.bin

REM Diagnostic module
rem memloader %PORT% %CART_GROM% DiagnosG.bin

REM  TI Parsec
goto skipparsec
memloader %PORT% %CART_ROM% PARSECC.bin
memloader %PORT% %CART_GROM% PARSECG.bin
:skipparsec

REM  Alpiner
rem memloader %PORT% %CART_ROM% ALPINERC.BIN
rem memloader %PORT% %CART_GROM% ALPINERG.BIN

REM  munchman
REM memloader %PORT% %CART_ROM% MUNCHMNC.BIN
REM memloader %PORT% %CART_GROM% MUNCHMNG.BIN


REM load Ralph's test rom
rem memloader %PORT% %CART_ROM% ralph\dblreadC.rpk\dblreadC.bin
rem memloader %PORT% %CART_GROM% ralph\dblreadC.rpk\dblreadG.bin

REM  CPU out of reset
memloader %PORT% 100008 cpu_reset_off.bin

memloader %PORT% -k
