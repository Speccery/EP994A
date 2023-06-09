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
REM EP 2019-01-13 finally it is time to improve this script to be much more user friendly.
REM https://stackoverflow.com/questions/18423443/switch-statement-equivalent-in-windows-batch-file
REM 
set CONSOLE_GROM=80000
set CART_GROM=86000
rem set CART_ROM=90000
rem set CART_ROM2=92000
set CART_ROM=0
set CART_ROM2=2000
set CONSOLE_ROM=BA000
set DSR_ROM=B0000
if not X%1X==XX goto has_port
echo INIT SYNTAX: init port module
echo Example: init -5 invaders
echo Port = -4 or -5 or -6 etc. com port number
echo Configured modules: (omit the colon in the beginning)
REM the following echo outputs an empty line.
echo.
findstr /I /R "^:MODULE_" init.cmd
exit /b

:has_port
set PORT=%1
shift

memloader %PORT% 100008 cpu_reset_on.bin
REM memloader %PORT% %CONSOLE_ROM% boot99105_0000.bin
memloader %PORT% %CONSOLE_ROM% 994aROM.Bin
memloader %PORT% %CONSOLE_ROM% debug\modded-rom2.bin
rem GROMs are now accessed directly from the Flash chip.
REM BUGBUG below commented out since we now read GROMS from SPI Flash
echo Loading GROM
memloader %PORT% %CONSOLE_GROM% 994aGROM-EP.Bin

REM memloader %PORT% 100000 keyinit.bin
REM  DSR for disk support
memloader %PORT% %DSR_ROM% diskdsr_4000.bin

REM Now time to load the module. We use the call based "switch" statement emulation
REM to make this more readable.
2>NUL CALL :MODULE_%1
IF ERRORLEVEL 1 CALL :MODULE_NONE
echo Init done. Taking CPU out of reset and starting to listen keypresses.
REM  CPU out of reset
memloader %PORT% 100008 cpu_reset_off.bin
memloader %PORT% -k
Exit /B

:MODULE_XB          REM  Extended Basic
    memloader %PORT% %CART_ROM% TIExtC.Bin
    memloader %PORT% %CART_ROM2% TIExtD.Bin
    REM BUGBUG below commented out since we now read GROMS from SPI Flash
    REM memloader %PORT% %CART_GROM% TIExtG.Bin
    goto end_case
:end_case
    VER > NUL   # Reset error case
    goto :EOF   # return from call
:MODULE_NONE        REM  No module loaded
    echo Cartridge memory not touched.
    goto end_case
:MODULE_TEST        REM  Erik Test Cartridge
    memloader %PORT% %CART_ROM% ..\..\projects\ticart\ERIK1.bin
    goto end_case
:MODULE_AMSTEST     REM  Memory extension test
    memloader %PORT% %CART_ROM% ..\memloader\AMSTEST4-8.BIN
    goto end_case
:MODULE_EDASM       REM  Editor/Assembler
    memloader %PORT% %CART_GROM% TIEAG.BIN
    goto end_case
:MODULE_RXB         REM  RXB
    memloader %PORT% %CART_ROM% RXBC.Bin
    memloader %PORT% %CART_ROM2% RXBD.Bin
    memloader %PORT% %CART_GROM% RXBG.Bin
    goto end_case
:MODULE_INVADERS    REM  TI Invaders 
    memloader %PORT% %CART_ROM% TI-InvaC.bin
    memloader %PORT% %CART_GROM% TI-InvaG.bin
    goto end_case
:MODULE_DONTMESS    REM  Don't mess with Texas demo
    memloader  %PORT% %CART_ROM% dontmess.bin
    goto end_case
:MODULE_ASCART      REM  ERIK test ROM
    copy ..\..\projects\ticart\ASCART.bin .
    memloader %PORT% %CART_ROM% ASCART.bin
    goto end_case
:MODULE_DEFENDER    REM  Defender game
    memloader %PORT% %CART_ROM% Defender.C.bin
    goto end_case
:MODULE_DIAG        REM  Diagnostic module
    memloader %PORT% %CART_GROM% DiagnosG.bin
    goto end_case
:MODULE_PARSEC      REM  TI Parsec
    memloader %PORT% %CART_ROM% PARSECC.bin
    memloader %PORT% %CART_GROM% PARSECG.bin
    goto end_case
:MODULE_ALPINER     REM  TI Alpiner game
    memloader %PORT% %CART_ROM% ALPINERC.BIN
    memloader %PORT% %CART_GROM% ALPINERG.BIN
    goto end_case
:MODULE_MUNCHMAN    REM  TI Munchman
    memloader %PORT% %CART_ROM% MUNCHMNC.BIN
    memloader %PORT% %CART_GROM% MUNCHMNG.BIN
    goto end_case
:MODULE_RALPHTEST   REM  Load Ralph's test rom
    memloader %PORT% %CART_ROM% ralph\dblreadC.rpk\dblreadC.bin
    memloader %PORT% %CART_GROM% ralph\dblreadC.rpk\dblreadG.bin
    goto end_case
:MODULE_MINIMEM     REM  Mini memory module
    memloader %PORT% %CART_ROM% roms\MiniMemC.Bin
    memloader %PORT% %CART_GROM% roms\MiniMemG.Bin
    goto end_case
:MODULE_LBLA        REM  Stuart's LBLA Cartridge
    memloader %PORT% %CART_ROM% roms\lblacart.Bin
    goto end_case
:MODULE_CPUTESTC    REM  PeteE's CPU test cartridge
    memloader %PORT% %CART_ROM% roms\cputestc.Bin
    goto end_case
:MODULE_STRANGECART REM  Erik's strangecart test ROM
    memloader %PORT% %CART_ROM% strangecar.bin
    goto end_case

