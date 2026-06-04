;************************************************
;* Beginn der globalen Daten *
;************************************************
                   AREA MyData, DATA, READWRITE, align = 2
Base

zahlen
                FILL   1001,0x01        ;1000 Stellen werden mir 0x01 im Speicher belegt.
                DCB    0xff             ;nach 1000 Stellen ein 0xff  für Abbruch.
ergebnis        
                FILL   500,0x00         ;Speicherabschnitt nach zahlen, indem Primzahlen geschrieben werden sollen.


;***********************************************
;* Beginn des Programms *
;************************************************
    AREA |.text|, CODE, READONLY, ALIGN = 3
; ----- S t a r t des Hauptprogramms -----
                EXPORT  main
                EXTERN  initITSboard

main            PROC
                bl      initITSboard    ;Das Board wirt initialisiert.
                
for_01          
                ldr     r0,=zahlen      ;r0 wird mit Adresse belegt.
                mov     r2,#1000        ;r2 = Länge zahlen - die zu prüfenden Zahlen 2 - 1000.
                mov     r3,#2           ;r3 ist der Startwert.
                mul     r7,r3,r3                            
until_01                                
                cmp     r7,r2           ;r3 wird mit e2 verglichen.
                bge     endfor_01       ;Ist r3 größer gelich r2 breche ab.   
do_01 
                ldrb    r1,[r0,r3]      ;Lade in r1 den Wert von r0 plus r2.
if_02           
                cmp     r1,#0x01        ;Vergleiche r1 mit 0x01.
                bne     endif_02        ;Ist r1 ungleich 0x01 spring zu endif_02.
then_02 
               
for_03 
                mul     r4,r3,r3        ;r4 = r3 * r3.
until_03 
                cmp     r4,r2           ;Vergleiche r4 mit r2.
                bge     endfor_03       ;Ist r2 größer gleich r4 spring zu endfor_03.
do_03
                mov     r1,#0x00        ;Überschreibe r1 mit 0x00.
                strb    r1,[r0,r4]      ;Speicher 0x00 an Adresse r0 + r4.
step_03         
                add     r4,r4,r3        ;Erhöhe r4 um r3.
                b       until_03        ;Springe an until_03.
endfor_03

endif_02
step_01         
                add     r3,r3,#1        ; Erhöhe r3 um 1.
                b       until_01        ;Springe an until_01.
endfor_01

;---Ausgabe---
for_ausgabe
                ldr     r6,=ergebnis    ;Schreibe in r6 die Adresse zu ergebnis.
                mov     r3,#2           ;Überschreibe r3 mir Zahl 2.      
until_ausgabe  
                cmp     r3,r2           ;Vergleiche r3 mit r2.
                bge     endfor_ausgabe  ;ist r2 größer gleich r3 spring zu endfor_ausgabe.
do_ausgabe
                ldrb    r5,[r0,r3]      ;Lade in r5 Wert von r0 + r3. 
if_ausgabe
                cmp     r5,#0x01        ;Vergleiche r5 mit 0x01.
                bne     endif_ausgabe   ;Ist r5 ungleich 0x01 springe zu endif_ausgabe.
then_ausgabe
                strh    r3,[r6]         ;Schreibe r3 an Adresse r6.
                add     r6,r6,#2        ;Erhöhe r6 um 1.
endif_ausgabe                
step_ausgabe
                add     r3,r3,#1        ;Erhöhe r3 um 1.
                b       until_ausgabe   ;Springe zu until_ausgebe.
endfor_ausgabe       


forever         b   forever             ;einfacher loop.
                ENDP
                END