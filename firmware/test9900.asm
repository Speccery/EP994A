* Erik Piehl (C) 2017 April
* test9900.asm
*
* Test program sequences to test drive the TMS9900 VHDL core.
*

	IDT 'TEST9900'
	
BOOT
	NOP
	LWPI >ABCD
	JMP BOOT

SLAST  END  BOOT


