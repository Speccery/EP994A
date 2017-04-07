* Erik Piehl (C) 2017 April
* test9900.asm
*
* Test program sequences to test drive the TMS9900 VHDL core.
*

	IDT 'TEST9900'
	
BOOT
	NOP
	LI R3,>ED07
LOOPPI
	AI	R3,>0001
	JMP LOOPPI

SLAST  END  BOOT


