;******************** (C) COPYRIGHT HAW-Hamburg ********************************
;* File Name          : main.s
;* Author             : Franz Korf	
;* Version            : V1.0
;* Date               : 11.05.2022
;* Description        : Rahmen zur Loesung von GTP Woche 7-9 (Stoppuhr).
;*******************************************************************************

; Define address of selected GPIO and Timer registers
PERIPH_BASE     	equ	0x40000000                 	; Peripheral base address
AHB1PERIPH_BASE 	equ	(PERIPH_BASE+0x00020000)    ; AHB1-Bus Basisadresse (LEDs, Schalter)
APB1PERIPH_BASE     equ PERIPH_BASE                 ; APB1-Bus Basisadresse (Timer)

GPIOD_BASE			equ	(AHB1PERIPH_BASE+0x0C00)	; LEDs
GPIOF_BASE			equ	(AHB1PERIPH_BASE+0x1400)	; Schalter
TIM2_BASE           equ (APB1PERIPH_BASE+0x0000)	; Hardware timer
	
GPIO_F_PIN        	equ	(GPIOF_BASE+0x10)			; Schalter Register

GPIO_D_PIN			equ	(GPIOD_BASE+0x10)			; Aktueller LED-Zustand (lesbar)
GPIO_D_SET			equ (GPIOD_BASE+0x18)			; LED anschalten
GPIO_D_CLR			equ	(GPIOD_BASE+0x1A)			; LED ausschalten
	
TIMER				equ (TIM2_BASE+ 0x24)   		; CNT : current time stamp (32 bit),  resolution
TIM2_PSC			equ (TIM2_BASE+0x28)   			; Prescaler  resolution
TIM2_ERG			equ (TIM2_BASE+0x14)   			; 16 Bit register, Bit 0 : 1 Restart Timer

    EXTERN initITSboard                             ; Initialisiert das ITS-Board (externe Funktion)
    EXTERN GUI_init                                 ; Initialisiert die grafische Oberfläche
	EXTERN initTimer                                ; Schaltet den Hardware-Timer ein
	EXTERN lcdSetFont                               ; Setzt die Schriftgröße auf dem Display
	EXTERN lcdGotoXY      							; TFT goto x y function	
	EXTERN lcdPrintS								; TFT output function	
    EXTERN lcdPrintC            					; TFT output one character		
	
; Definition der Uhr Zustände für code lesbarkeit.
STATE_INIT			equ	0                           ; Zustand: Uhr zurückgesetzt, zeigt 00:00.00
STATE_RUN			equ	1                           ; Zustand: Uhr läuft, Zeit wird gezählt
STATE_HOLD			equ	2                           ; Zustand: Zeitanzeige angehalten (Hintergrund läuft)

;********************************************
; Data section, aligned on 4-byte boundery
;********************************************
	AREA MyData, DATA, align = 2

DEFAULT_BRIGHTNESS	DCW     800                     ; Standardhelligkeit des Displays (16-bit Wert)
ZEIT				DCB		"00:00.00", 0           ; Aktuell anzuzeigende Zeit als ASCII-String (mm:ss.nn + Nullterminator)
ZEIT_ALT			DCB		"aa:aa.aa", 0           ; Zuletzt angezeigter Zeitstring (zum Vergleich, um nur geänderte Zeichen neu zu zeichnen)
NULL_ZEIT			DCB		"00:00.00", 0           ; Konstanter Nullzeit-String zur Initialisierungsanzeige
STATE				DCB		0                       ; Aktueller FSM-Zustand (1 Byte: 0=INIT, 1=RUN, 2=HOLD)


;********************************************
; Code section, aligned on 8-byte boundery
;********************************************
	AREA |.text|, CODE, READONLY, ALIGN = 3


;--------------------------------------------
; main subroutine
;--------------------------------------------
	EXPORT main [CODE]
	
main	PROC
	; Initialisierung der HW
		bl		initITSboard
		ldr   	r1,=DEFAULT_BRIGHTNESS	; adr. helligkeit
		ldrh 	r0,[r1]				    ; Helligkeitswert aus dem Speicher laden (16-bit)			
		bl   	GUI_init				; Initialisiert das Grafik-Display 
		bl  	initTimer				; einschalten des Hardware-Timer
		ldr 	R1,=TIM2_PSC   			; Initialisiert prescaler
		mov 	R0,#(90*10-1) 			; runterdrehen der tick rate (899) 90mhz warte 900 ticks für 1
		strh	R0,[R1]					; setzt prescaler runter auf 1 timer tick = 10us.
		ldr 	R1,=TIM2_ERG   			; Initialisiert Restart timer	
		mov		R0,#0x01				; Set UG Bit
		strh	R0,[R1]					; speichert UG Bit im Restart timer
		MOV 	R0,#24					; schriftgröße 24
		bl  	lcdSetFont				; giebt schriftgröße aus

	; Ihre Initialisierung
		mov 	R0,#10              ; X-Koordinate des Textcursors (Startposition Display)
		mov 	R1,#6               ; Y-Koordinate des Textcursors
        bl      lcdGotoXY           ; Cursor auf Startposition setzen

	; Simple test code
		ldr 	R0,=NULL_ZEIT       ; Adresse des "00:00.00"-Strings laden
		bl  	lcdPrintS           ; Nullzeit initial auf dem Display ausgeben

superloop
		ldr	    R4,=STATE           ; Adresse der STATE-Variable laden
		ldrb    R4,[R4]             ; aktuellen Zustandswert (1 Byte) lesen
		cmp	    R4,#STATE_INIT		; Ist STATE INIT?
		bleq	init				; Ja? springe in INIT und später zurück
		cmp	    R4,#STATE_RUN		; Ist STATE RUN?	
		bleq	run					; Ja? springe in RUN und später zurück
		cmp	    R4,#STATE_HOLD		; Ist STATE HOLD?
		bleq	hold				; Ja? springe in HOLD und später zurück
		bal		superloop			; Wiederholung der superloops
		ENDP



init PROC	
        push    {R0-R2,lr}			; Sichern der Register auf dem Stack
		ldr 	R0,=TIM2_ERG   		; Initialisiert Restart timer	
		mov		R1,#0x01			; Set UG Bit
		strh	R1,[R0]				; speichert UG Bit im Restart timer

        ldr     R0,=ZEIT            ; Basisadresse des ZEIT-Strings laden
        mov     R1,#'0'             ; ASCII-Wert für Ziffer '0' laden
        strb    R1,[R0,#0]			; Zehnerstelle Minuten auf '0' setzen
        strb    R1,[R0,#1]          ; Zehnerstelle Minuten auf '0' setzen
        strb    R1,[R0,#3]          ; Zehnerstelle Sekunden auf '0' setzen
        strb    R1,[R0,#4]          ; Einerstelle Sekunden auf '0' setzen
        strb    R1,[R0,#6]          ; Zehnerstelle Hundertstel auf '0' setzen
        strb    R1,[R0,#7]          ; Einerstelle Hundertstel auf '0' setzen
        bl      print_time          ; Zurückgesetzte Zeit auf dem Display anzeigen

	; LED 1 und 2 aus
		mov		R0,#3				; led 1 und 2 = 3 = 0011
		ldr		R4,=GPIO_D_CLR
		str		R0,[R4]				; setzt led 1 und 2 off

	; Anfangen den Button S7 abzufragen
		mov     R0,#7               ; Buttonnummer S7 in R0 laden
		ldr	    R1,=GPIO_F_PIN      ; Adresse des Taster-Registers laden
		ldrh    R1,[R1]             ; aktuellen Tasterzustand (16-bit) lesen
        bl      isButtonPressed     ; prüfen ob S7 gedrückt (Ergebnis in R0: 1=gedrückt)

if_S7_pressed
        cmp     R0,#1               ; Wurde S7 gedrückt?
        bne     endif_S7_pressed    ; Nein? Zum Ende des if-Blocks springen

then_S7_pressed
		ldr	    R4,=STATE           ; Adresse der STATE-Variable laden
        mov     R3,#STATE_RUN       ; Wert 1 = STATE_RUN
        strb    R3,[R4]             ; STATE auf RUN setzen → Uhr startet

endif_S7_pressed
        pop     {R0-R2,lr}          ; gesicherte Register wiederherstellen
        bx      lr                  ; Rücksprung zum Aufrufer
        ENDP

run PROC
		push    {R0-R7,lr}         	; Alle genutzten Register sichern!

	; HARDWARE-TIMER AUSLESEN
		ldr     R0,=TIMER          	; Adresse des Timers laden
		ldr     R0,[R0]            	; Aktuelle Ticks in R0 laden

	; MINUTEN BERECHNEN
		ldr     R2,=6000000        	; 1 Minute = 6.000.000 Ticks
		udiv    R4,R0,R2          	; R4 = Gesamtminuten
		mul     R3,R4,R2          	; R3 = Minuten in Ticks umgerechnet (zum Abziehen)
		sub     R0,R0,R3          	; R0 = Verbleibende Ticks nach Minuten-Abzug

	; SEKUNDEN BERECHNEN ---
		ldr     R2,=100000         	; 1 Sekunde = 100.000 Ticks
		udiv    R5,R0,R2          	; R5 = Gesamtsekunden
		mul     R3,R5,R2          	; R3 = Sekunden in Ticks umgerechnet
		sub     R0,R0,R3          	; R0 = Verbleibende Ticks nach Sekunden-Abzug

	; HUNDERTSTEL (MS) BERECHNEN 
		ldr     R2,=1000           	; 1 Hundertstel = 1.000 Ticks
		udiv    R6,R0,R2          	; R6 = Hundertstelsekunden

	; ASCII-UMWANDLUNG FÜR DAS DISPLAY
		ldr     R0,=ZEIT           	; Basisadresse des Zeit-Strings
		mov     R1,#10             	; Teiler für Zehner-/Einerstelle

	; Minuten (Stelle 0 und 1)
		udiv    R2,R4,R1          	; Zehnerstelle Minuten
		mul     R3,R2,R1			; Zehnerstelle isolieren
		sub     R3,R4,R3          	; Einerstelle Minuten
		add     R2,#0x30           	; In ASCII umrechnen
		add     R3,#0x30           	; In ASCII umrechnen
		strb    R2,[R0,#0]        	; 'X'0:00.00
		strb    R3,[R0,#1]        	; 0'X':00.00

	; Sekunden (Stelle 3 und 4)
		udiv    R2,R5,R1         	; Zehnerstelle Sekunden
		mul     R3,R2,R1          	; Zehnerstelle isolieren
		sub     R3,R5,R3          	; Einerstelle Sekunden
		add     R2,#0x30          	; In ASCII umrechnen
		add     R3,#0x30           	; In ASCII umrechnen
		strb    R2,[R0,#3]        	; 00:'X'0.00
		strb    R3,[R0,#4]        	; 00:0'X'.00

	; Hundertstel/Millisekunden (Stelle 6 und 7)
		udiv    R2,R6,R1          	; Zehnerstelle Hundertstel
		mul     R3,R2,R1			; Zehnerstelle isolieren
		sub     R3,R6,R3          	; Einerstelle Hundertstel
		add     R2,#0x30           	; In ASCII umrechnen
		add     R3,#0x30           	; In ASCII umrechnen
		strb    R2,[R0,#6]        	; 00:00.'X'0
		strb    R3,[R0,#7]        	; 00:00.0'X'

	; AUSGABE 
		bl	    print_time          ; Aktualisiert das TFT-Display flackerfrei

	; LEDs für Zustand RUN einstellen (LED 1 an, LED 2 aus)
		mov     R0,#1              	; Bitmask für LED D8 (Bit 0)
		ldr     R1,=GPIO_D_SET     	; 
		strh    R0,[R1]            	; LED D8 einschalten (Zeitmessung aktiv)
		mov     R0,#2              	; Bitmask für LED D9 (Bit 1)
		ldr     R1,=GPIO_D_CLR     	; 
		strh    R0,[R1]            	; LED D9 ausschalten (kein HOLD)

	; TASTER S6 ABFRAGEN (WECHSEL ZU HOLD) 
		mov     R0,#6              	; Lädt Pin Nummer
		ldr	    R1,=GPIO_F_PIN     	; 
		ldrh    R1,[R1]            	;
		bl      isButtonPressed     ;
		cmp     R0,#1              	; Wurde S6 gedrückt
		bne     endif_S6_pressed    ; S6 nicht gedrückt? if-Block überspringen
then_S6_pressed
		ldr	    R4,=STATE          	;
		mov     R3,#STATE_HOLD     	; In den Pause-Zustand wechseln
		strb    R3,[R4]            	;
endif_S6_pressed

	; TASTER S5 ABFRAGEN (WECHSEL ZU INIT)
		mov     R0,#5              	;
		ldr	    R1,=GPIO_F_PIN     	;
		ldrh    R1,[R1]            	;
		bl      isButtonPressed     ;
		cmp     R0,#1              	;
		bne     endif_S5_pressed    ; S5 nicht gedrückt? if-Block überspringen
then_S5_pressed
		ldr	    R4,=STATE          	;
		mov     R3,#STATE_INIT     	; Zurücksetzen auf 0
		strb    R3,[R4]            	;
endif_S5_pressed

		pop     {R0-R7,pc}         	; Stack aufräumen und zurückspringen
		ENDP

hold PROC
        push 	{R0-R1,lr}            	; Register und Rücksprungadresse sichern
		mov     R0,#3          		; LED 1 und 2 an
		ldr     R1,=GPIO_D_SET     	; Adresse des LED-Set-Registers laden
		strh    R0,[R1]             ; LEDs D8 und D9 einschalten (Bit 0 und 1 gesetzt)

	; Anfangen den Button S7 abzufragen
		mov     R0,#7               ; Buttonnummer S7 in R0 laden
		ldr	    R1,=GPIO_F_PIN      ; Adresse des Taster-Registers laden
		ldrh    R1,[R1]             ; aktuellen Tasterzustand lesen
        bl      isButtonPressed     ; prüfen ob S7 gedrückt

if_S7_p
        cmp     R0,#1               ; Wurde S7 gedrückt?
        bne     endif_S7_p          ; Nein? if-Block überspringen

then_S7_p
		ldr	    R4,=STATE           ; Adresse der STATE-Variable laden
        mov     R3,#1               ; Wert 1 = STATE_RUN
        strb    R3,[R4]             ; STATE auf RUN setzen → Uhr läuft weiter

endif_S7_p
	; Anfangen den Button S5 abzufragen
		mov     R0,#5               ; Buttonnummer S5 in R0 laden
		ldr	    R1,=GPIO_F_PIN      ; Adresse des Taster-Registers laden
		ldrh    R1,[R1]             ; aktuellen Tasterzustand lesen
        bl      isButtonPressed     ; prüfen ob S5 gedrückt

if_S5_p
        cmp     R0,#1               ; Wurde S5 gedrückt?
        bne     endif_S5_p          ; Nein? if-Block überspringen

then_S5_p
		ldr	    R4,=STATE           ; Adresse der STATE-Variable laden
        mov     R3,#STATE_INIT      ; Wert 0 = STATE_INIT
        strb    R3,[R4]             ; STATE auf INIT setzen → Uhr zurücksetzen

endif_S5_p
        pop 	{R0-R1,lr}          ; Register und Rücksprungadresse wiederherstellen
        bx 		lr                  ; Rücksprung zum Aufrufer
    	ENDP


print_time PROC
		push	{R4-R8,lr}          ; verwendete Register und Rücksprungadresse sichern

for_sc 
		mov	    R4,#0              	; Zeichenindex (Schleifenzähler) auf 0 initialisieren
		ldr		R5,=ZEIT            ; Basisadresse des aktuellen Zeitstrings laden
		ldr	    R7,=ZEIT_ALT        ; Basisadresse des vorherigen Zeitstrings laden

until_sc 
		cmp	    R4,#8               ; Alle 8 Zeichen (Index 0–7) verarbeitet?
		beq		enddo_sc            ; Ja? Schleife beenden

do_sc		
		ldrb	R6,[R5,R4]          ; aktuelles Zeichen aus ZEIT laden
		ldrb	R8,[R7,R4]          ; entsprechendes Zeichen aus ZEIT_ALT laden
		cmp 	R6,R8               ; Sind beide Zeichen gleich?
		beq		next           		; Ja? kein Neuzeichnen nötig, weiter zum nächsten Zeichen
		strb    R6,[R7,R4]          ; Neues Zeichen in ZEIT_ALT speichern (Stand aktualisieren)
		mov     R0,R4               ; Zeichenindex als X-Offset übernehmen
		add	    R0,R0,#0xA          ; X-Position berechnen: Index + 10 (Startoffset auf dem Display)
        mov     R1,#6               ; Y-Position (fest, Zeile 6)
        bl      lcdGotoXY           ; Cursor auf die Position des geänderten Zeichens setzen
		mov  	R0,R6               ; Zu druckendes Zeichen in R0 laden
		bl  	lcdPrintC           ; Einzelnes Zeichen auf dem Display ausgeben

next		
step_sc
		add	    R4,R4,#1            ; Zeichenindex um 1 erhöhen
		B	    until_sc            ; Zurück zur Schleifenbedingung

enddo_sc
		pop		{R4-R8,lr}          ; Register und Rücksprungadresse wiederherstellen
		bx lr                       ; Rücksprung zum Aufrufer
		ENDP

isButtonPressed PROC
		mov	    R2,#1               ; Bitmask initialisieren (Bit 0 gesetzt)
		lsl	    R2,R2,R0            ; Bitmask auf das Bit des gewünschten Tasters schieben (1 << Buttonnummer)
		ands    R2,R1,R2            ; Taster-Bit aus dem GPIO-Register isolieren
		movne   R0,#0               ; Bit nicht 0 → Taster nicht gedrückt → R0 = 0
	
isPressed
		moveq   R0,#1               ; Taster gedrückt → R0 = 1

endPressed  
		bx lr                      	; Rücksprung zum Aufrufer
		ENDP


		ALIGN
		END