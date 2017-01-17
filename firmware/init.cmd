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
set PORT=-6


memloader %PORT% 100008 cpu_reset_on.bin
memloader %PORT% %CONSOLE_ROM% 994aROM.Bin
memloader %PORT% %CONSOLE_GROM% 994aGROM.Bin
REM memloader %PORT% 100000 keyinit.bin

REM  DSR for disk support
memloader %PORT% %DSR_ROM% diskdsr_4000.bin

REM  Extended Basic
REM  memloader %PORT% %CART_ROM% TIExtC.Bin
REM  memloader %PORT% %CART_ROM2% TIExtD.Bin
REM  memloader %PORT% %CART_GROM% TIExtG.Bin

REM  Erik Test Cartridge
REM  memloader %PORT% %CART_ROM% ERIK1.bin

REM  Memory extension test
REM  memloader %PORT% %CART_ROM% AMSTEST4-8.BIN

REM  Editor/Assembler
REM  memloader %PORT% %CART_GROM% TIEAG.BIN

REM  RXB
memloader %PORT% %CART_ROM% RXBC.Bin
memloader %PORT% %CART_ROM2% RXBD.Bin
memloader %PORT% %CART_GROM% RXBG.Bin

REM  TI Invaders
REM  memloader %PORT% %CART_ROM% TI-InvaC.bin
REM  memloader %PORT% %CART_GROM% TI-InvaG.bin

REM  ERIK test ROM
REM  cp ../../../ticart/ASCART.bin .
REM  memloader %CART_ROM% ASCART.bin

REM  Defender
REM  memloader %CART_ROM% Defender.C.bin

REM  TI Parsec
REM  memloader %PORT% %CART_ROM% PARSECC.bin
REM  memloader %PORT% %CART_GROM% PARSECG.bin

REM  Alpiner
REM  memloader %CART_ROM% ALPINERC.BIN
REM  memloader %CART_GROM% ALPINERG.BIN

REM  CPU out of reset
memloader %PORT% 100008 cpu_reset_off.bin

memloader %PORT% -k
