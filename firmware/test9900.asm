* Erik Piehl (C) 2017 April
* test9900.asm
*
* Test program sequences to test drive the TMS9900 VHDL core.
*

	IDT 'TEST9900'
WRKSP  EQU >8300
    DATA WRKSP,BOOT   * RESET VECTOR
    DATA >BEEF,>BEEF
	
BOOT
********** TEST 1
*	NOP
*	LI R3,>ED07
* LOOPPI
*	AI	R3,>0001
*	ANDI R3,>3
*	ORI  R3,>0400
*	JMP LOOPPI

********** TEST 2
* LOOPPI2
*  LI R1,2
*LOOPPI
*  AI R1,>FFFF
*  JNC KOE
*  LI R8,>88
*KOE
*  CI  R1,0
*  JNE LOOPPI
*  JEQ SKIPLOAD
*  LI R7,>77
*SKIPLOAD
*  JMP LOOPPI2

********** TEST 3 ** Simulation output
  LI  R3,>8340    ** write to 8306 data 8340 1000001101000000
  LI R2,2
BACK  
  BL    @SUBROUTINE
  CLR R1
  CLR   @4(R3)
  SETO  @6(R3)
  CLR   @>8348
  SETO  *R3
  CLR   *R3+
  CLR   *R3+
  CLR   *R3+
  NEG R2
  MOV R2,*R3+
  JMP BACK
  NEG R2
  LI R2, >8002
  NEG R2
  NEG R2
  INCT R3
  MOV R3,R5
  INC R5
  DEC R5
  SWPB R5
  INV R5
  SETO *R3
  ABS R5
  NEG R5
  LI  R0,>1234    ** write to 8300 data 1234 0001001000110100
  LI  R1,1        ** write to 8302 data 0001 0000000000000001
  MOV R0,*R3      ** write to 8340 data 1234 0001001000110100
  MOV *R3+,R2     ** write to 8306 data 8342 1000001101000010 
*                 ** write to 8304 data 1234 0001001000110100 
  A   R1,R2       ** write to 8304 data 1235 0001001000110101 
  MOV R2,R8       ** write to 8310 data 1235 0001001000110101 
  MOV R1,*R3      ** write to 8342 data 0001 0000000000000001
  A   R1,*R3      ** write to 8342 data 0002 0000000000000010
  MOV @>4,@>8344
  BL  @SUBROUTINE
  JMP BOOT
  
SUBROUTINE  
  LI  R4,123
  RT

* Thus source modes Rx, *Rx, *Rx+, @addr work
* Destination modes Rx and *Rx work 
*   Also destination mode @addr works for MOV but not other instructions
* First iteration of MOV @>4,@>8344 takes 3375-2915=460ns from iaq to iaq
  
SLAST  END  BOOT


* TESTED kind of
* NOP, LI, AI, ANDI, ORI
* LWPI
* JMP, JNE, JEQ
* 14.4.2017
* MOV
* A (without flags)

