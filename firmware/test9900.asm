* Erik Piehl (C) 2017 April
* test9900.asm
*
* Test program sequences to test drive the TMS9900 VHDL core.
*

	IDT 'TEST9900'
	
BOOT
*	NOP
*	LI R3,>ED07
* LOOPPI
*	AI	R3,>0001
*	ANDI R3,>3
*	ORI  R3,>0400
*	JMP LOOPPI

LOOPPI2
  LI R1,2
LOOPPI
  AI R1,>FFFF
  JNE LOOPPI
  JEQ SKIPLOAD
  LI R7,>77
SKIPLOAD
  JMP LOOPPI2

SLAST  END  BOOT


* TESTED kind of
* NOP, LI, AI, ANDI, ORI
* LWPI
* JMP, JNE, JEQ
