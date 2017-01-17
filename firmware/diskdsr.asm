* diskdsr.asm
* Disk DSR module for the TMS99105 system EP994A
* Started by Erik Piehl on Oct 7th 2016
* Based on original TI sample from a long time ago.
*
* Compile with: xas99.py -b -R -L diskdsr.lst diskdsr.asm
*

VDPWD  EQU  >8C00             * VDP write data
VDPWA  EQU  >8C02             * VDP set read/write address
VDPRD  EQU  >8800             * VDP read data
VDPPTR EQU  >8890             * VDP extension: VRAM address pointer

MYRAM   EQU >8000        * EP994A scratchpad is 1k in size, starts at >8000
ENTRYN  EQU >8002        * Save entry point number
PABSTA  EQU >8004        * Start of PAB in VDP memory (also used by host program)
MARKER  EQU >8006
RCOUNT  EQU >8008        * DSR call count

*---------------------------------------------------------
* Variables for host to TMS99105 IOP communication
*---------------------------------------------------------
DSRWAIT EQU >800A        * Set when DSR waits for host
ARG1    EQU >800C        * parameters for host to TMS99105
ARG2    EQU >800E       
ARG3    EQU >8010
HOSTOP  EQU >8012        * Command from host to TMS99105
*---------------------------------------------------------
MYPABN  EQU >801E        * Length of my PAB
MYPAB   EQU >8020        * PAB is copied from VDP RAM to here.

  RORG >4000
  BYTE >AA
  BYTE 1    ; version number
  DATA 0    ; leave at 0
  DATA PWRLINK
  DATA 0
  DATA DSRLINK
  DATA 0
  DATA INTLINK
  DATA 0
  
MYMSG  
  TEXT  'TMS99105 FPGA SYSTEM ERIK PIEHL'
  BYTE  0
  EVEN
  
* Powerup routine  
PWRLINK 
  DATA 0  ; Linkage - none
  DATA PWRUP
  BYTE 0  ; Name length
  EVEN    ; 
  
; Display something on the screen  
PWRUP
  MOV R11,R4  ; Save return address
  LI  R0,(13*32+0)
  LI  R1,MYMSG
  BL  @SETUPVDPA
!
  MOVB *R1+,R2
  JEQ !done
  MOVB R2,@VDPWD
  JMP -!
  
!done  
  
; Clear 256 bytes from >8000 onwards  
;  CLR @RCOUNT
;  CLR @DSRWAIT
;  CLR @HOSTOP
  LI  R0,MYRAM
  LI  R1,256
! CLR *R0+
  DECT R1
  JNE  -!

  LI  R0,>5678
  MOV R0,@MARKER
  LI  R0,>BEEF
  MOV R0,@MARKER+2
  
  
  B   *R4
  
* Interrupt routine
INTLINK
  DATA 0
  DATA INTDSR
  BYTE 0 
  EVEN
INTDSR        ; Erik we do nothing here  
  RT
  
* Main device service routine.  
DSRLINK  
  DATA  DSRLINK2
  DATA  ENTRY1
  BYTE  3
  TEXT  'DSK'
  EVEN
DSRLINK2
  DATA  DSRLINK3
  DATA  ENTRY2
  BYTE  4
  TEXT  'DSK1'
  EVEN
DSRLINK3
  DATA  0     ; No next device
  DATA  ENTRY3
  BYTE  4
  TEXT  'DSK2'
  EVEN

ENTRY1
  CLR   R0
  JMP   GO4IT

ENTRY2
  LI    R0,1
  JMP   GO4IT

ENTRY3  
  LI    R0,2

* The common start of the actual DSR  
GO4IT  
  MOV   R11,@MYRAM  ; Save return address
  MOV   R0,@ENTRYN
  INC   @RCOUNT
;  LI    R1,>1234
  STST  R1          ; Read CPU status register
  MOV   R1,@MARKER
  BL    @PAB2RAM    * Copy PAB to CPU RAM
  
* Let's signal the host PC that we have got something nice in here
wait_cmd
  CLR   @HOSTOP       * reset previous host operation
  LI    R1,1
  MOV   R1,@DSRWAIT   * Host wait flag set
* Now wait for the host to tell us something
!wait_loop
  MOV   @HOSTOP,R1
  JEQ   -!wait_loop
  CLR   @DSRWAIT     * Clear flag
* We received a command from the host, do something
* Operations are:
*   Read VDP memory:  1 (ARG1=VDP addr, ARG2=CPU RAM addr, ARG3=bytecount)
*   Write VDP memory: 2 (ARG1=CPU addr, ARG2=VDP RAM addr, ARG3=bytecount)
*   Exit DSR:         3 (ARG1=error code or success, top 3 bits ored with PAB status)  
  DEC   R1
  JEQ   !read_vdp
  DEC   R1
  JEQ   !write_vdp
  DEC   R1
  JEQ   !set_return
  JMP   wait_cmd      ; If we come here the host code was unexpected. Ignore it.
  
!read_vdp
  MOV   @ARG1,R0      ; VDP source addr
  MOV   @ARG2,R1      ; CPU RAM addr
  MOV   @ARG3,R2      
  BL    @VDPREADA
! MOVB  @VDPRD,*R1+
  DEC   R2
  JNE   -!
  JMP   wait_cmd
  
!write_vdp
  MOV   @ARG1,R1      ; CPU RAM source addr
  MOV   @ARG2,R0      ; VDP RAM addr
  MOV   @ARG3,R2     
  BL    @SETUPVDPA    ; Setup VDP write address
! MOVB  *R1+,@VDPWD
  DEC   R2
  JNE   -!
  JMP   wait_cmd
  
!set_return  
* Let's report a device error back, error code 6
  MOVB  @MYPAB+1,R1   ; read status byte
  ANDI  R1,>1FFF
  SOC   @ARG1,R1      ; Or in the bits set by host
;;  ORI   R1,>C000    ; 6 << 5 << 8 - OR the status 6 in there
  MOV   @PABSTA,R0
  INC   R0          ; point to status byte
  BL    @SETUPVDPA
  MOVB  R1,@VDPWD   * Write back the status, indicating error
  
* Return to console software  
EXIT  
  MOV   @MYRAM,R11
  INCT  R11
  RT
  
* Copy the PAB from VDP RAM to system RAM to make it
* visible to the PC.  
PAB2RAM  
  MOV @>8354,R1   * DSR Name length
  MOV @>8356,R2   * Ptr to first char after name in VDP memory.
  MOV R2,R3
  S   R1,R3       
  AI  R3,-10      ; -10: R3 is now the pointer to start of PAB
  
  MOV R3,R0       * VDP address to R0
  MOV R3,@PABSTA  * Store PAB start for later
  AI  R1,10       * 10 bytes plus name length
* The length now is to the period character, so for example to 
* DSK1.HELLO it would be just after DSK1.
  MOV R1,@MYPABN  * save length of my PAB
  LI  R3,MYPAB
  MOV R11,R2      * Save return address
  BL  @VDPREADA   * Setup VDP read address to start of PAB
* Copy to RAM loop  
! MOVB  @VDPRD,*R3+
  DEC R1
  JNE -!
* Now that we have the PAB in CPU memory, let's also read
* the filename to CPU memory. VDP memory pointer already points
* to the right place.
  MOVB @MYPAB+9,R1    ; name length (DSR name + filename)
  SRL  R1,8           ; shift to lower byte
  S    @>8354,R1      ; substract DSR name length
  JEQ  !done          ; if zero exit
! MOVB  @VDPRD,*R3+   ; Otherwise copy filename
  DEC R1
  JNE -! 
!done  
  B   *R2
  
  
*---------------------------------------------
* Set VDP read address from R0
*---------------------------------------------
VDPREADA      
      ANDI  R0,>3FFF          * make sure it is a read command
      SWPB  R0
      MOVB  R0,@VDPWA      		* Send low byte of VDP RAM write address
      SWPB  R0
      MOVB  R0,@VDPWA         * Send high byte of VDP RAM write address
      RT
      
*---------------------------------------------
* Set VDP address from R0
*---------------------------------------------
SETUPVDPA
      SWPB  R0
      MOVB  R0,@VDPWA      		* Send low byte of VDP RAM write address
      SWPB  R0
      ORI   R0,>4000          * Set read/write bits 14 and 15 to write (01)
      MOVB  R0,@VDPWA         * Send high byte of VDP RAM write address
			RT  