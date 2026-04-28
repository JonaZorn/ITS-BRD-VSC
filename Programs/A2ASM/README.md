;******************** (C) COPYRIGHT HAW-Hamburg ********************************
;* File Name          : main.s
;* Author             : Martin Becke    
;* Version            : V1.0
;* Date               : 01.06.2021
;* Description        : This is a simple main to demonstrate data transfer
;                     : and manipulation.
;                     : 
;
;*******************************************************************************
    EXTERN initITSboard ; Helper to organize the setup of the board

    EXPORT main         ; we need this for the linker - In this context it set the entry point,too

ConstByteA  EQU 0xaffe
    
;* We need some data to work on
    AREA DATA, DATA, align=2    
VariableA   DCW 0xbeef  ; 1011 1110 1110 1111
VariableB   DCW 0x1234

;* We need minimal memory setup of InRootSection placed in Code Section 
    AREA  |.text|, CODE, READONLY, ALIGN = 3    
    ALIGN   
main
    BL initITSboard             ; needed by the board to setup
;* swap memory - Is there another, at least optimized approach?
    ldr     R0,=VariableA   ; Anw01     ; In R0 wird die Adressen zu den Daten der VariableA gespeichert.
    ldrb    R2,[R0]         ; Anw02     ; Im ldrb (b = byte ) werden nun die Daten aus den ersten Byte des DCW, aus der VariableA in R2 gespeichert. R2 =  0xef.
    ldrb    R3,[R0,#1]      ; Anw03     ; Selbieges passiert auch hier im R3, mit dem Unterschied, dass nun das zweite Byte, sprich an #1 Stelle in R3 gespeichert wird.
                                          R3 = 0xbe.
    lsl     R2, #8          ; Anw04     ; lsl (Logical Shift Left) besagt in diesem Fall, dass in R2 die gespeicherte Information um 8 Bits nach links verschoben wird.
                                          Sprich von (R2 = 0xef (1110 1111)) zu (R2 = 0xef00 (1110 1111 0000 0000)).
    orr     R2, R3          ; Anw05     ; orr verknüpft nun R2 mit R3, heißt R2 = 0xef00 (1110 1111 0000 0000) und R3 = 0xbe(1011 1110) werden zusammen in R2 zu R2 = 0xefbe.
    strh    R2,[R0]         ; Anw06     ; strh (Store Register Halfword) speichert nun die Daten in der Größe 16 Bit in der Adresse von R0, Sprich es wird in der VariableA
                                          der Wehr 0xbeef mit dem neuen, gedehten Weht 0xefbe aus R2 ersetzt.
    
;* const in var
    mov     R5,#ConstByteA  ; Anw07
    strh    R5,[R0]         ; Anw08
    
;* Change value from x1234 to x4321
    ldr     R1,=VariableB   ; Anw09
    ldrh    R6,[R1]         ; Anw0A
    mov     R7, #0x30ED     ; Anw0B          
    add     R6, R6, R7      ; Anw0C
    strh    R6,[R1]         ; Anw0D
    b .                     ; Anw0E
    
    ALIGN
    END