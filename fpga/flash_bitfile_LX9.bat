REM Based on Pepino Pacman loading script
REM Edited 2017-12-30 to add support for including the ROMS. This is based on the work of
REM Magnus for the Mac "PlusToo_scsi_LX9" project
bitmerge work\ep994a.bit 160000:tiroms.bin ep994a-roms.bit
..\..\..\Electronics\Pipistrello\fpgaprog\fpgaprog.exe -v -d "Pepino LX9 A" -f ep994a-roms.bit -b bscan_spi_lx9_ftg256.bit -sa -r
pause