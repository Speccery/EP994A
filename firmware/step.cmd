# step.cmd
# EP 2017-08-04
set CART_ROM=90000
set CONSOLE_ROM=BA000
set CONSOLE_GROM=80000

if X%1X==XX goto setport4
set PORT=%1
goto continue

:setport4
set PORT=-4

:continue

..\memloader\memloader %PORT% 100008 cpu_reset_on.bin
..\memloader\memloader %PORT% %CONSOLE_ROM% 994aROM.Bin
rem ..\memloader\memloader %PORT% %CONSOLE_ROM% boot99105_0000.bin
..\memloader\memloader %PORT% %CONSOLE_GROM% 994aGROM.Bin

rem ..\memloader\memloader %PORT% %CART_ROM% Defender.C.bin
..\memloader\memloader %PORT% %CART_ROM% zeros8k.bin

rem clear scartchpad
..\memloader\memloader %PORT% B8300 zeros256.bin

rem single step hold
..\memloader\memloader %PORT% 100009 single_step_hold.bin
rem CPU out of reset
..\memloader\memloader %PORT% 100008 cpu_reset_off.bin

rem ..\memloader\memloader %PORT% -k
#rem read debug info
..\memloader\memloader -r %PORT% 100000 20 k.bin
rem hexdump -C k.bin
 
