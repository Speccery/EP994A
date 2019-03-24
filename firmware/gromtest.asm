* --- quick test program to checkout GROM
* --- EP 2019-03-24

* --- first execution returned R3..R6: 00,26,0D,00 
    AORG >F000  ; default address of LBLA cartridge execution
    LI R12,>1E00
    NOP
    LIMI 0
    SBO >7   ; enable new GROM thing
    LI R1,>9C02
    CLR R0
    BL  @GA
    LI R2,>9800
;;    MOVB *R2,R3
;;    B @DONE
    BL  @RDG
    MOV R3,R4   ; first results to R4
    BL  @RDG
    MOV R3,R5
    BL  @RDG
    MOV R3,R6
    BL  @RDG
    MOV R3,R7
    BL  @RDG
    MOV R3,R8
DONE:
;;    SBZ >7       ; Default GROM access mode
    LIMI 2

    MOV R4,R12
    BLWP @>629A
    MOV R5,R12
    BLWP @>629A
    MOV R6,R12
    BLWP @>629A
    MOV R7,R12
    BLWP @>629A
    MOV R8,R12
    BLWP @>629A
    LI R12,>2000
    BLWP @>629E     ; Print space, high byte of R12
    MOV @>8480,R12  ; Read last serial flash address
    BLWP @>629A
    LI R12,>2000
    BLWP @>629E     ; Print space, high byte of R12
    B @>6E9E    ; Return to TI BUG

GA: MOVB R0,*R1 
    SWPB R0
    MOVB R0,*R1
    SWPB R0
    RT

RDG: MOVB *R2,R3    ; Read from GROM 16 bits
    SWPB R3
    MOVB *R2,R3    
    SWPB R3
    RT


