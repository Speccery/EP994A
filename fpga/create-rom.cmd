@echo off
REM EP 2017-12-30
REM here we create the 256K byte ROM image to be stored to the flash ROM.
REM The FPGA automatically loads the 256K section after reset from flash to RAM.

REM 1 megabyte static RAM address map:
REM 00000..7FFFF - 512K cartridge ROM (paged the extended BASIC way i.e. 8K pages)
REM 80000..8FFFF - 64K GROM region (first 24K are system GROMs)
REM 90000..9FFFF - hole 64K
REM A0000..AFFFF - hole 64K
REM B0000..B1FFF - DSR ROM - 8K for disk subsystem
REM B2000..B9FFF - hole 32K  
REM BA000..BBFFF - Console ROM - 8K
REM BC000..BFFFF - hole 16K
REM C0000..FFFFF - 256K RAM area, paged with SAMS

REM -- We are loading from flash memory chip to SRAM.
REM -- The total amount is 256K bytes. We perform the following mapping:
REM -- 1) First 128K loaded from flash are written from address 0 onwards (i.e. paged module RAM area)
REM -- 2) Next 64K are written to 80000 i.e. our 64K GROM area
REM -- 3) Last 64K are written to B0000 i.e. our DSR ROM and ROM area.


REM -- let's do here extended BASIC and normal
REM  |--- here is 128K module ROM section                                       ---|   |--- here is 64K GROM section                                     ---|   |--- here is 64K ROM section                                                                          ---|
copy /B ..\firmware\TIExtC.Bin + /B ..\firmware\TIExtD.Bin + /B hole48k + /B hole64K + /B ..\firmware\994AGROM-EP.Bin + /B ..\firmware\TIExtG.Bin + /B hole8k + /B ..\firmware\diskdsr_4000_padded8k.bin + /B hole32k + /B ..\firmware\994aROM.Bin + /B hole8k + /B hole8k tiroms.bin
