;************************************************
;* Beginn der globalen Daten *
;************************************************
                   AREA MyData, DATA, READWRITE, align = 2
Base

; --- HIER GEHÖREN DIE ARRAYS HIN ---
zahlen
                FILL   1000,0x01
                DCB    0xff
ergebnis        
                FILL   50,0x00


;***********************************************
;* Beginn des Programms *
;************************************************
    AREA |.text|, CODE, READONLY, ALIGN = 3
; ----- S t a r t des Hauptprogramms -----
                EXPORT  main
                EXTERN  initITSboard

main            PROC
                bl      initITSboard    ;
                ldr     r0,=zahlen
                mov     r2,#1000
                mov     r3,#2
for_01              
until_01        
                cmp     r3,r2           ;
                bge     endfor_01       ;   
do_01 
                ldrb    r1,[r0,r3]      ;
if_02           
                cmp     r1,#0x01        ;
                bne     endif_02        ;
then_02 
                add     r4,r3,r3        ;   
for_03 
until_03 
                cmp     r4,r2           ;
                bge     endfor_03       ;
do_03
                mov     r1,#0x00        ;
                strb    r1,[r0,r4]      ;
step_03         
                add     r4,r4,r3        ;
                b       until_03        ;
endfor_03

endif_02
step_01         
                add     r3,r3,#1        ;
                b       until_01        ;
endfor_01

;---Ausgabe---

                ldr     r7,=ergebnis    ;
                mov     r3,#2           ;
for_ausgabe      
until_ausgabe  
                cmp     r3,r2           ;
                bge     endfor_ausgabe  ;
do_ausgabe
                ldrb    r5,[r0,r3]      ;
if_ausgabe
                cmp     r5,#0x01        ;
                bne     endif_ausgabe   ;
then_ausgabe
                strb    r3,[r7]         ;    
                add     r7,r7,#1        ;
endif_ausgabe                
step_ausgabe
                add     r3,r3,#1        ;
                b       until_ausgabe   ;      
endfor_ausgabe       

                bx      lr
                ENDP
                END