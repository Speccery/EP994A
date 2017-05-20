* Erik Piehl (C) 2016 October
* boot99105.asm
*
* This is a test program intended to test various pieces of 
* functionality of the EP994A.
*
* Compile with: xas99.py -b -R -L list.lst boot99105.asm
* Load with:  ../memloader/memloader 0 boot99105_0000.bin
*

       IDT  'BOOT99'

WRKSP   EQU   >8300       
PRINTWS EQU   >8320
PRTR1P	EQU	  >8322		; Input for PRINTR1
DELAYWS EQU		>8340
TMPBUF  EQU   >A040
INTWS   EQU   >A000   ; interrupt workspace

OUTP  EQU   >B000         
VDPRD  EQU  >8800
VDPST  EQU  >8802
VDPWD  EQU  >8C00             * VDP write data
VDPWA  EQU  >8C02             * VDP set read/write address

*---------------------------------------------
* Macro: printString <arg>
* (would be xop <arg>,14 for the TMS9995 BB)
*---------------------------------------------
       .defm	printString
			BLWP	@PRINTS
			DATA	#1
       .endm
       
*---------------------------------------------
* Macro: printNumber <arg>
* (would be xop <arg>,10 for the TMS9995 BB)
*---------------------------------------------
      .defm printNumber
			MOV		#1,@PRTR1P		; Store HEX value to print
			BLWP	@PRINTR1			; Go print R1
      .endm
      
*---------------------------------------------
* Macro: printCrLf
*---------------------------------------------
      .defm printCrLf
	    BLWP	@PRINTS
  	  DATA	TXTCRLF
      .endm
      
  
*---------------------------------------------
* Macro: printChar <arg>
* (would be xop <arg>,12 for the TMS9995 BB)
*---------------------------------------------
			.defm	printChar
			MOVB	#1,@PRTR1P	
			BLWP	@PRINTCH
			.endm  

       
;       AORG  0
       DATA WRKSP,BOOT
       DATA INTWS,VDPINT
       DATA INTWS,VDPINT
       
PRINTS	DATA	PRINTWS,GOPRINT
PRINTR1	DATA	PRINTWS,GOPR1
PRINTCH DATA	PRINTWS,GOPRCHAR
CLS     DATA  PRINTWS,GOCLS

NICEDELAY DATA	DELAYWS,GODELAY

; Our interrupt routine
VDPINT  
        LIMI    0
        INC     R0          ; R0 counts interrupts
        CLR     R12
        STCR    R2,0        ; See the TMS9901 register, low 16 bits
        TB      2
        JNE     !ok
        LI      R3,>FFFF    ; error
        JMP     !
!ok
        LI      R3,>1234    ; OK
!        
        MOVB    @VDPST,R1   ; clear the VDP interrupt request
        LI      R5,>100
        AB      R5,@>8379   ; Increment frame counter in scratchpad
        RTWP
        
       
BOOT
      LIMI  0
; BOOTLP      
;      JMP   BOOTLP
;      NOP
;      NOP
;      JMP   BOOTLP
      
      LWPI  WRKSP
      CLR   @INTWS      ; Zero INTWS.R0, the interrupt counter.
      
      MOVB  R3,@VDPWD   ; Dummy write to data, to reset latch
; Write initial values to VDP registers
      LI    R1,VDPSEQ
      LI    R2,>8000    ; command, write register 0
VLP
      MOVB  *R1+,@VDPWA ; write data
      MOVB  R2,@VDPWA   ; write register number
      AI    R2,>0100    ; next register
      CI    R2,>8800
      JNE   VLP
      
; Clear VDP RAM 
      CLR   R0
      LI    R1,>4000
      SWPB  R1
      MOVB  R1,@VDPWA   ; Address to zero
      SWPB  R1
      MOVB  R1,@VDPWA
!      
      MOVB  R0,@VDPWD
      DEC   R1
      JNE   -!
      
      BL    @COPYFONTS
      
; Initialize color table with >17 times 32
      LI    R0,>0380    ; address of color table
      BL		@SETUPVDPA
      LI    R1,32
      LI    R2,>1700
!      
      MOVB  R2,@VDPWD
      DEC   R1
      JNE   -!
      
      JMP		GROM1
      
      CLR   @PRINTWS    ; Initial display position
      CLR   R1
      LI    R2,>1234
      LI    R3,>FFFF
      LI    R4,>2000
      LI    R5,20
      LI    R6,>DEF0
      LI    R7,'3'*256
LINES1      
      .printNumber R1
      .printChar R4
      ; LI    R6,24
      MOV     R1,R6
      INC     R6
!      
      .printChar R7
      DEC   R6
      JNE   -!
      .printCrLf
      INC    R1
      ANDI   R1,>1F
      CI     R1,24
      JNE    LINES1
      
      
GROM1 
; Test GROM address counter read and write
      LI    R0,>40
      MOV   R0,@PRINTWS
			LI		R0,>1234						; write GROM address      
      LI    R9,3
!gromloop      
      .printString GROMTESTS
			MOVB	R0,@>9C02				
			SWPB	R0
			MOVB	R0,@>9C02
      SWPB  R0
; read two bytes GROM 
      CLR   R1
      MOVB  @>9800,R1
      MOVB  @>9800,R2
      SRL   R2,8      
      SOC   R2,R1
      .printNumber  R1
; and read two more bytes GROM 
      CLR   R1
      MOVB  @>9800,R1
      MOVB  @>9800,R2
      SRL   R2,8      
      SOC   R2,R1
      .printNumber  R1
; Now read GROM address and display it
      CLR   R1
      MOVB  @>9802,R1
      MOVB  @>9802,R2
      SRL   R2,8      
      SOC   R2,R1
      .printNumber  R1
      AI    R0,>2000    ; next GROM
      DEC   R9
      JNE   -!gromloop
; Try to read keyboard button '1', but first enable VDP interrupts
      CLR   R12         ; CRU pointer
      SBZ   0           ; Make sure we are not in timer mode
      SBO   2           ; Enable VDP interrupts
      LIMI  2           ; Enable interrupts

      LI    R3,5000
!k    CLR   R0
      MOV   R0,@PRINTWS
!    
      LI    R12,>24
      LDCR  R0,3
      LI    R12,6        ; Address to read rows
      STCR  R1,8
      .printNumber R1
      .printCrLf
      AI    R0,>100
      CI    R0,>600
      JNE   -!
      MOV   @INTWS,R1   ; Interrupt counter
      .printNumber R1
      .printCrLf
      .printString CRU0STR
      MOV   @INTWS+4,R1 ; read reg 2 from interrupt context (CRU bits)
      .printNumber R1   ; show them
      .printCrLf
      MOV   @INTWS+6,R1 ; Also show reg 3
      .printNumber R1   ; show them
      .printCrLf
      CLR   R12
      STCR  R1,0       ; Read 16 bits (count of 0 means 16)
      .printNumber R1
      .printCrLf
      LI R5,100
      LI R6,7
      MPY R6,R5
      .printNumber R5
      .printNumber R6
      .printCrLf
      DEC   R3
      JNE   -!k
      
; Check if we have defender loaded. If we have let's go!
      MOV   @>6000,R1
      CI     R1,>AA01
      JNE   !
      MOV   @>600E,R1
      CI    R1,>6072
      JNE   !
      B     @>6072
!

;;			BLWP	@NICEDELAY
; Do test of GROM memory. Calculate GROM checksums
GROMCHECK
;;			BLWP	@CLS
;;			CLR		R0
;;			MOV		R0,@PRINTWS
			.printString GTT

; Start of checksum loop
			LI		R4,3					; Iteration counter
!gr3
			CLR		R0	
!gr2			
			MOVB	R0,@>9C02				; Setup GROM address to zero
			SWPB	R0
			MOVB	R0,@>9C02
      SWPB  R0
      .printNumber	R0
      
      CLR		R1						; init checksum
      LI		R2,>1800
!grr      
      CLR		R3
      MOVB	@>9800,R3			; get byte
      SRC		R1,1
			A			R3,R1
			DEC		R2
			JNE		-!grr
			.printNumber		R1	; print checksum
			; Get address and print it
      CLR   R1
      MOVB  @>9802,R1
      MOVB  @>9802,R2
      SRL   R2,8      
      SOC   R2,R1
      .printNumber  R1
      .printCrLf
			
			AI		R0,>2000
			CI		R0,>6000
			JNE		-!gr2
			
			DEC		R4
			JNE		-!gr3				; next iteration
		
			BLWP	@NICEDELAY
			
      
      JMP   MAINSTART
      
NOCLEAR      
; Write fonts
      LI    R2,CHARS
      LI    R1,ENDCHARS-CHARS ; count
      LI    R3,>4300    ; address 300
      SWPB  R3
      MOVB  R3,@VDPWA   ; low byte of address
      SWPB  R3
      MOVB  R3,@VDPWA   ; high byte of address
      
!     MOVB  *R2+,@VDPWD
      DEC   R1
      JNE   -!
      
TESTCHARS      
; write a few characters
      LI    R3,>4000    ; address 0
      SWPB  R3
      MOVB  R3,@VDPWA   ; low byte of address
      SWPB  R3
      MOVB  R3,@VDPWA   ; high byte of address
      
      LI    R5,>80
LPLP      
      LI    R0,>2021    ; >6061
      MOVB  R0,@VDPWD
      SWPB  R0
      MOVB  R0,@VDPWD
      SWPB  R0
      LI    R0,>3031     ;>6263
      MOVB  R0,@VDPWD
      SWPB  R0
      MOVB  R0,@VDPWD
      SWPB  R0
      DEC   R5
      JNE   LPLP

      
MAINSTART
      LI    R1,OUTP
      LI    R0,>100
      LI    R3,20
      
MAINLOOP      
      MOVB  R0,*R1
      SLA   R0,1
      JNE   !
      LI    R0,>100
!     CLR   R2
!delay  
      DEC   R2
      JNE   -!delay
      DEC   R3
      JNE   MAINLOOP
; Copy the dump to VDP memory
      LI    R0,0
      BL    @SETUPVDPA
      LI    R1,VDPDUMP
      LI    R2,DUMPEND-VDPDUMP
VCOPYLP      
      MOVB  *R1+,@VDPWD
      DEC   R2
;      MOVB  *R1+,@VDPWD
;      MOVB  *R1+,@VDPWD
;      DECT  R2
      JNE   VCOPYLP
      
; Now delay loop
      LI    R1,10
!     DEC   R2
      JNE   -!
      DEC   R1
      JNE   -!
; Make a small animation
      LI    R4,VDPDUMP+768-32 ; -32 for message
      LI    R5,0            ; Scroll offset
      LI    R6,0
      LI    R8,32
      MOV   R1,R2
      
      LI    R9,10000         ; our delay
      
!again      
      LI    R1,VDPDUMP
      CLR   R0
      BL    @SETUPVDPA
; Animate 1 row
!row
      MOV   R6,R7
      A     R5,R7
      ANDI  R7,>1F
      A     R1,R7
      MOVB  *R7,@VDPWD
      INC   R6          ; R6 counts our columns
      C     R6,R8
      JNE   -!row
      CLR   R6
      AI    R1,32
      C     R1,R4
      JNE   -!row
; Increment our offset
      INC   R5
      ANDI  R5,31
; Make our small delay
      CI    R9,0
      JEQ   -!again   ; if delay is zero, no more printing

      MOV   R9,R7
!del  DEC   R7
      JNE   -!del
      
; decrement delay
      AI    R9,-10
; Display a message from our sponsor
      LI    R0,23*32
      MOV   R0,@PRINTWS
      .printString TMS99105
      .printNumber R9
      .printString SPACES
; Proceed to second row directly
      AI    R1,32


      JMP   -!again
      
      
      
      
      JMP   MAINSTART

*---------------------------------------------
* Set VDP address from R0
*---------------------------------------------
SETUPVDPA
      ANDI  R0,>3FFF
      SWPB  R0
      MOVB  R0,@VDPWA         * Send low byte of VDP RAM write address
      SWPB  R0
      ORI   R0,>4000          * Set read/write bits 14 and 15 to write (01)
      MOVB  R0,@VDPWA         * Send high byte of VDP RAM write address
      RT
      
*---------------------------------------------
* Scroll up - test VDP reads
* For reads top 2 bits are zero
*---------------------------------------------
SCROLLUP
      MOV   R11,R10           * Save return address
      LI    R6,>20            * VRAM read address
      CLR   R0                * VRAM write address
      LI    R7,23             * 23 lines

!scrollloop      
      SWPB  R6
      MOVB  R6,@VDPWA         * Send low byte of VDP RAM read address
      SWPB  R6
      MOVB  R6,@VDPWA
      LI    R2,>20
      LI    R5,TMPBUF
      LI    R1,VDPRD          * VDP read address
!rdloop      
      MOVB  *R1,*R5+          * read byte from VRAM
      MOVB  *R1,*R5+          * read byte from VRAM
      DECT  R2
      JNE   -!rdloop
; Next write the same stuff to the previous line      
      BL    @SETUPVDPA
      LI    R2,>20
      LI    R5,TMPBUF
      LI    R1,VDPWD          * VDP read address
!wrloop
      MOVB  *R5+,*R1
      MOVB  *R5+,*R1
      DECT  R2
      jne   -!wrloop
      AI    R0,>20
      AI    R6,>20
      DEC   R7
      JNE   -!scrollloop
      B     *R10            * Return

* copy fonts from GROMs to pattern table
COPYFONTS
      MOV   R11,R10     ; Save return address
      LI    R0,>6B4         * setup GROM source address of font table
      LI    R7,GROM0
      A     R0,R7
;      MOVB    R0,@>9C02
;      SWPB    R0
;      MOVB    R0,@>9C02
      LI      R0,>800+(32*8)          * destination address in VRAM
      BL      @SETUPVDPA
      LI      R0,62                                                   * 62 characters to copy
      CLR     R2
!ch2
      LI      R1,7                                                    * 7 bytes per char
!char
      MOVB    *R7+,@VDPWD        * move byte from GROM to VDP
      DEC     R1
      JNE     -!char
      MOVB    R2,@VDPWD                                 * 8th byte just zero
      DEC     R0
      JNE     -!ch2
      B     *R10    ; return

      
HEXWORD	; EP display R1 in hex in the current VDP location
			LI	R3,4
HEXLOOP
		  MOV R11,R10
			MOV	R1,R2
!			BL	@HEXNIBBLE
			SLA	R2,4
			MOV	R2,R1
			DEC	R3
			JNE	-!
			B 	*R10	
			
HEXBYTE	; Display most significant byte of R1 in the current VDP location
			LI 	R3,2
			JMP	HEXLOOP


HEXNIBBLE	; EP display top 4 bits of R1 in current VDP RAM location
			SRL 	R1,4
			ANDI 	R1,>0F00
			AI		R1,>3000	; Convert to ASCII
			CI		R1,>3A00
			JL		!
			AI		R1,>0700			
!     MOVB  R1,@VDPWD
			RT
      
*--------------------------------------------
* GOPR1
* Print contents of R1 in the PRINTWS
* workspace.
*--------------------------------------------
GOPR1
			LIMI	0
			BL		@SETUPVDPA		; Setup dest address
			BL		@HEXWORD			; print
			AI		R0,4					; Advance VDP ptr
			RTWP

*--------------------------------------------
* *** Print a string *** 
* Entered with BLWP, so return with RTWP
* PC points to string pointer, so use R14 
* to access it and inc R14 past it.
* R0 in this workspace is VDP RAM pointer.
*--------------------------------------------
GOPRINT
				LIMI	0						; no more interrupts until RTWP
			  MOV		*R14+,R1		; Fetch string pointer to R1
			  BL		@SETUPVDPA
!				MOVB	*R1+,R2
				JEQ		!done				; zero ends -> !done
				CI		R2,>0D00
				JEQ		-!					; Skip 0xD's
				CI		R2,>0A00    ; is it linefeed?
				JNE		!write			; no -> !write
; Here we are with a linefeed. Update to next line.
				AI		R0,32
				ANDI	R0,>FFE0
				BL		@SETUPVDPA
				JMP		-!
; Write the character to the VDP				
!write
				INC	  R0					; update our VDP address
				MOVB	R2,@VDPWD		
				JMP		-!
!done
  		  RTWP
     
*--------------------------------------------
* GOPRCHAR
* Print a character from R1 high byte, PRINTWS
* workspace.
*--------------------------------------------
GOPRCHAR
			LIMI 	0
			BL		@SETUPVDPA		; Setup dest address
			INC	  R0						; update our VDP address
			MOVB	R1,@VDPWD		
			RTWP

*--------------------------------------------
* CLS			
* Clear the screen. Enter with BLWP
*--------------------------------------------
GOCLS
       LIMI 0
       CLR  R0                * Start at top left corner of the screen
       LI   R1,>2000          * Write a space (>20 hex is 32 decimal)
       LI   R2,768            * Number of bytes to write

       MOVB @PRINTWS+1,@VDPWA ;* Send low byte of VDP RAM write address
       ORI  R0,>4000          * Set read/write bits 14 and 15 to write (01)
       MOVB R0,@VDPWA         * Send high byte of VDP RAM write address

!      MOVB R1,@VDPWD         * Write byte to VDP RAM
       DEC  R2                * Byte counter
       JNE  -!                * Check if done
       
       LI   R0,1              * second column
       BL   @SETUPVDPA
       RTWP

*--------------------------------------------
* DELAY that takes enough time for a human
* to see something on the screen.
* Enter with BLWP
*--------------------------------------------
GODELAY
; Stop here for a while
      CLR   R0
      LI    R1,10
!mydelay      
      DEC   R0
      JNE   -!mydelay
      DEC   R1
      JNE   -!mydelay
; Next scroll the screen up
      BL    @SCROLLUP
; Stop here for a while
      CLR   R0
      LI    R1,10
!mydelay      
      DEC   R0
      JNE   -!mydelay
      DEC   R1
      JNE   -!mydelay
			RTWP
     
      EVEN
CHARS
      BYTE  0,0,0,0,0,0,0,0
      BYTE  >00,>18,>24,>42,>42,>7E,>42,>42
      BYTE  >80,>80,>80,>80,>80,>80,>80,>80
      BYTE  >01,>03,>01,>01,>01,>01,>01,>01
      EVEN
ENDCHARS      
; Initial VDP register values
VDPSEQ  
      BYTE  >00,>E0,>00,>0E    ; Interrupts enabled
;      BYTE  >00,>C0,>00,>0E     ; Interrupts disabled
      BYTE  >01,>06,>00,>F7
TXTCRLF
		BYTE >0D,>0A
		BYTE >00
    EVEN
      
GROM0 BCOPY "GROMSMAL.BIN"
    EVEN
VDPDUMP BCOPY "vdp-raw.bin"
DUMPEND 
TMS99105  TEXT  'TMS99105 AND FPGA AT WORK! ' 
      BYTE 0
      EVEN
SPACES  TEXT '  '
        BYTE 0
GTT		TEXT 'GROM CHECKSUM TEST:'
			BYTE 10,13,0
CRU0STR TEXT 'CRU FROM 0: '
      BYTE 0
      EVEN
GROMTESTS
      TEXT 'GROM READ TEST:1234>'
      BYTE  0
      EVEN

SLAST  END  BOOT

