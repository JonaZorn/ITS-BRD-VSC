Aufgabe 2.2
Kommentieren der Anw01 bis Anw06
 

1)    (VariableA   DCW 0xbeef)

Das ist die Variable A, sie enthällt ein DCW (Define Constant Halfword) in der Größe von 16 Bits, bzw. zwei Bytes mit der Zahl 0xbeef.
Im GDB: Memory Browser ist abzusehen, das diese Zahl im speicher jedoch auf Grud des Little Endian als 0xefbe gespeichert wird. 


2)    ldr     R0,=VariableA   ; Anw01 

In R0 wird die Adressen zu den Daten der VariableA gespeichert.


 3)   ldrb    R2,[R0]         ; Anw02     
    
Im ldrb (b = byte ) werden nun die Daten aus den ersten Byte des DCW, aus der VariableA in R2 gespeichert. R2 =  0xbe.


4)    ldrb    R3,[R0,#1]      ; Anw03     

Selbieges passiert auch hier im R3, mit dem Unterschied, dass nun das zweite Byte, sprich an #1 Stelle in R3 gespeichert wird - R3 = 0xef.


5)    lsl     R2, #8          ; Anw04   

lsl (Logical Shift Left) besagt in diesem Fall, dass in R2 die gespeicherte Zahl um 8 Bits nach links verschoben wird. Sprich von (R2 = 0xbe (1011 1110)) zu 
(R2 = 0xbe00 (1011 1110 0000 0000)).

6)    orr     R2, R3          ; Anw05     

orr verknüpft nun R2 mit R3, heißt R2 = 0xbe00 (1011 1110 0000 0000) und R3 = 0xef(1110 1111) werden zusammen in R2 zu R2 = 0xbeef.


7)   strh    R2,[R0]         ; Anw06     

strh (Store Register Halfword) speichert nun die Daten in der Größe 16 Bit in der Adresse von R0, Sprich es wird in der VariableA der Wehr 0xefbe mit dem neuen, gedehten Weht 0xbeef aus R2 ersetzt und damit im Memory als 0x beef gespeichert.
    
