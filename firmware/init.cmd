@echo off
REM  init.cmd
REM  EP (C) 2018-09-26 memory map now matching the FPGA CPU's memory map
REM    GROM 80000
REM    Cart 00000
REM    DSR  B0000
REM    ROM  BA000 (console 8k ROM)
REM    (Scratcpad from 68000 to B8000 but not used here)
REM 
set CONSOLE_GROM=80000
set CART_GROM=86000
set CART_ROM=0000
set CART_ROM2=2000
set CONSOLE_ROM=BA000
set DSR_ROM=B0000
set PORT=-7


memloader %PORT% 100008 cpu_reset_on.bin
REM clear some optional areas: DSR ROM, GROM extensions, ROM extension
memloader %PORT% %DSR_ROM% zeros256.bin
memloader %PORT% %CART_GROM% zeros256.bin
memloader %PORT% %CART_ROM% zeros256.bin

memloader %PORT% %CONSOLE_ROM% 994aROM.Bin
memloader %PORT% %CONSOLE_GROM% 994aGROM.Bin
REM memloader %PORT% 100000 keyinit.bin

REM  DSR for disk support
memloader %PORT% %DSR_ROM% diskdsr_4000.bin

REM  Extended Basic
rem memloader %PORT% %CART_ROM% TIExtC.Bin
rem memloader %PORT% %CART_ROM2% TIExtD.Bin
rem memloader %PORT% %CART_GROM% TIExtG.Bin

REM  Erik Test Cartridge
REM  memloader %PORT% %CART_ROM% ERIK1.bin

REM  Memory extension test
REM  memloader %PORT% %CART_ROM% AMSTEST4-8.BIN

REM  Editor/Assembler
rem memloader %PORT% %CART_GROM% TIEAG.BIN

REM  RXB
REM memloader %PORT% %CART_ROM% RXBC.Bin
REM memloader %PORT% %CART_ROM2% RXBD.Bin
REM memloader %PORT% %CART_GROM% RXBG.Bin

REM  TI Invaders
REM memloader %PORT% %CART_ROM% TI-InvaC.bin
REM memloader %PORT% %CART_GROM% TI-InvaG.bin

REM  ERIK test ROM
REM  cp ../../../ticart/ASCART.bin .
REM  memloader %CART_ROM% ASCART.bin

REM  Defender
REM  memloader %CART_ROM% Defender.C.bin

REM  TI Parsec
REM memloader %PORT% %CART_ROM% PARSECC.bin
REM memloader %PORT% %CART_GROM% PARSECG.bin

REM  Alpiner
REM  memloader %CART_ROM% ALPINERC.BIN
REM  memloader %CART_GROM% ALPINERG.BIN

REM Megademo
REM memloader %PORT% %CART_ROM% dontmess.bin

REM Megademo - version which I compiled myself
memloader %PORT% %CART_ROM% demo8.bin

REM  CPU out of reset
memloader %PORT% 100008 cpu_reset_off.bin

memloader %PORT% -k
