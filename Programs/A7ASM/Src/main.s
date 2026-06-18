;******************** (C) COPYRIGHT HAW-Hamburg ********************************
;* File Name          : main.s
;* Author             : Franz Korf	
;* Version            : V1.0
;* Date               : 11.05.2022
;* Description        : Rahmen zur Loesung von GTP Woche 7-9 (Stoppuhr).
;
;*******************************************************************************

; Define address of selected GPIO and Timer registers
PERIPH_BASE     	equ	0x40000000                 
AHB1PERIPH_BASE 	equ	(PERIPH_BASE + 0x00020000)
APB1PERIPH_BASE     equ PERIPH_BASE

GPIOD_BASE			equ	(AHB1PERIPH_BASE + 0x0C00)		; LEDs 
GPIOF_BASE			equ	(AHB1PERIPH_BASE + 0x1400)		; Schalter
TIM2_BASE           equ (APB1PERIPH_BASE + 0x0000)		; Hardware timer
	
GPIO_F_PIN        	equ	(GPIOF_BASE + 0x10)				; Schalter Register

GPIO_D_PIN			equ	(GPIOD_BASE + 0x10)
GPIO_D_SET			equ (GPIOD_BASE + 0x18)				; LED anschalten
GPIO_D_CLR			equ	(GPIOD_BASE + 0x1A)				; LED ausschalten
	
TIMER				equ (TIM2_BASE + 0x24)   ; CNT : current time stamp (32 bit),  resolution
TIM2_PSC			equ (TIM2_BASE + 0x28)   ; Prescaler  resolution
TIM2_ERG			equ (TIM2_BASE + 0x14)   ; 16 Bit register, Bit 0 : 1 Restart Timer  

    EXTERN initITSboard
    EXTERN GUI_init
	EXTERN TP_Init
	EXTERN initTimer
	EXTERN lcdSetFont
	EXTERN lcdGotoXY      		; TFT goto x y function
	EXTERN lcdPrintS			; TFT output function	
    EXTERN lcdPrintC            ; TFT output one character		
	EXTERN Delay				; Delay (ms) function            

; Definition der Uhr Zustände für code lesbarkeit.
STATE_INIT			equ	0
STATE_RUNNING		equ	1
STATE_HOLD			equ	2

;********************************************
; Data section, aligned on 4-byte boundery
;********************************************
	AREA MyData, DATA, align = 2

DEFAULT_BRIGHTNESS	DCW     800				; Helligkeit			
MY_TEXT				DCB		"00:00.00", 0	; text auf dem board 
	ALIGN									; korrektur speicher auf nächste 4 byte adresse
CURRENT_STATE		DCD		STATE_INIT		; Speichert den aktuellen FSM-Zustand
LAST_TIMER_VAL		DCD		0				; Für UpdateClk: Vorheriger Hardware-Timestamp
STOPUHR_TICKS		DCD		0				; Das Zeitkonto der Stoppuhr in 10us-Schritten
LAST_BUTTON_STATE	DCD		0xFF			; damti knöpfe nur einmal auslösen

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
		ldrh 	r0,[r1]					
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
	; Initialisiere den ersten Zeitstempel für UpdateClk
		ldr		R0,=TIMER			; Lädt die Speicheradresse des Hardware-Timer
		ldr		R0,[R0]				; Liest aktuellen Zählerstand und speichert den Wert
		ldr		R1,=LAST_TIMER_VAL	; Lädt die Adresse deiner RAM-Variable
		str		R0,[R1]				; Speichert Hardware-Zählerstand in der Variable

	; Uhr auf 00:00.00 vorab anzeigen
		mov		R0,#10				; Lädt die X-Koordinate
		mov		R1,#6				; Lädt die Y-Koordinate
		bl		lcdGotoXY			; Setzt text-Cursor auf die Position (10, 6)
		ldr 	R0,=MY_TEXT			; Lädt Speicheradresse Text ("00:00.00")
		bl  	lcdPrintS			; Giebt MY_TEXT	auf Position (10, 6) aus

superloop
		bl		UpdateClk        	; 1. Zeit-Aktualisierung
		bl		ReadButtons      	; 2. Taster einlesen & Flankenerkennung
		bl		UpdateFSM        	; 3. FSM Zustandsübergänge (INIT, RUNNING, HOLD)
		bl		SetLEDs          	; 4. LEDs je nach Zustand ansteuern
		bl		DisplayTime      	; 5. Uhrzeit auf dem TFT ausgeben (außer in HOLD)
		bal		superloop
		ENDP		; 



; Unterprogramme 
;------------------

ReadButtons PROC
		ldr		R0,=GPIO_F_PIN			; Lädt die Adresse für Schalter
		ldrh	R0,[R0]					; holt aktuellen Zustand aller Pins von Port F
		and		R0,#0xFF				; R0 = aktuelle Tasterzustände und mit 0xFF

		ldr		R1,=LAST_BUTTON_STATE	; Lädt Adresse der RAM-Variable
		ldr		R2,[R1]					; R2 = alter Zustand
		str		R0,[R1]					; Lädt neuen Zustand
		bx		lr						; Zurück in superloop
		ENDP

UpdateFSM PROC
		ldr		R1,=CURRENT_STATE
		ldr		R3,[R1]				; R3 = Aktueller Zustand

	; Prüfe Taste S5 (Bit 5) 		
		and		R4,R0,#0x20			; Filtert Bit 5 aus dem aktuellen Zustand
		and		R5,R2,#0x20			; Filtert Bit 5 aus dem alten Zustand
		cmp		R5,#0x20			; Prüft ob Knopf in letzten Runde losgelassen war
		bne		check_s6			; wenn nein, gehe zu check_s6
		cmp		R4,#0				; Prüft ob Knopf jetzt gedrückt wurde
		bne		check_s6			; wenn nein, gehe zu check_s6 
		mov		R3,#STATE_INIT  	; R3 = 0
		str		R3,[R1]				; speicher R3 im CURRENT_STATE
		b		fsm_output_action	; springe zum output

check_s6
	; --- PRÜFE TASTER S6 (Bit 6) ---
		and		R4,R0,#0x40			; Filtert Bit 5 aus dem aktuellen Zustand
		and		R5,R2,#0x40			; Filtert Bit 5 aus dem alten Zustand
		cmp		R5,#0x40			; Prüft ob Knopf in letzten Runde losgelassen war
		bne		check_s7			; wenn nein, gehe zu check_s7
		cmp		R4,#0				; Prüft ob Knopf jetzt gedrückt wurde
		bne		check_s7			; wenn nein, gehe zu check_s7
		cmp		R3,#STATE_RUNNING	; 
		bne		check_s7
		mov		R3,#STATE_HOLD
		str		R3,[R1]				; speicher R3 im STATE_HOLD
		b		fsm_output_action

check_s7
	; --- PRÜFE TASTER S7 (Bit 7) ---
		and		R4,R0,#0x80			; Filtert Bit 5 aus dem aktuellen Zustand
		and		R5,R2,#0x80			; Filtert Bit 5 aus dem alten Zustand
		cmp		R5,#0x80			; Prüft ob Knopf in letzten Runde losgelassen war
		bne		fsm_output_action	; wenn nein springe zu fsm
		cmp		R4,#0				; Prüft ob Knopf jetzt gedrückt wurde
		bne		fsm_output_action	; wenn nein springe zu fsm
		cmp		R3,#STATE_INIT		; 
		beq		set_running
		cmp		R3,#STATE_HOLD
		bne		fsm_output_action
set_running
		mov		R3,#STATE_RUNNING
		str		R3,[R1]

fsm_output_action
		cmp		R3,#STATE_INIT		; vergleiche CURRENT_STATE mit STATE_INIT
		bne		fsm_end
		mov		R0,#0
		ldr		R4,=STOPUHR_TICKS
		str		R0,[R4]				; überschreibe den timer mit 0 um wieder hoch zu zählen
fsm_end
		bx		lr
		ENDP

SetLEDs PROC
		ldr		R3,=CURRENT_STATE
		ldr		R3,[R3]				; lade CURRENT_STATE

		mov		R0,#3				; led 1 und 2 = 3 = 0011
		ldr		R4,=GPIO_D_CLR
		str		R0,[R4]				; setzt led 1 und 2 off

		cmp		R3,#STATE_RUNNING	; prüfe CURRENT_STATE = 1
		bne		led_hold			; wenn ungleich sprienge zu led_hold
		mov		R0,#1				; wenn gleich led 1 ansteuern
		ldr		R4,=GPIO_D_SET		
		str		R0,[R4]				; setzte led 1 on
		b		led_end

led_hold
		cmp		R3,#STATE_HOLD		; prüfe R3 = STATE_HOLD = 2
		bne		led_end				; wenn ungleich spring
		mov		R0,#3				; wenn gleich steuere led 1 und 2
		ldr		R4,=GPIO_D_SET		
		str		R0,[R4]				;schalte led 1 nd 2 on
led_end
		bx		lr
		ENDP

DisplayTime PROC
		PUSH    {lr}                    ; lr sichern, da bl aufgerufen wird

		ldr		R3,=CURRENT_STATE
		ldr		R3,[R3]
		cmp		R3,#STATE_HOLD
		beq		disp_end				; Wenn HOLD, Anzeige einfrieren

		ldr		R0,=STOPUHR_TICKS
		ldr		R0,[R0]

		ldr     R2,=6000000      		
		udiv    R4,R0,R2        		; teile ticks durch 6000000 für minuten
		mul     R3,R4,R2				; mul ergebnis (R4) mit 6000000
		sub     R0,R0,R3        		; ziehe minuten von ticks ab

		ldr     R2,=100000       		
		udiv    R5,R0,R2        		; teile ticks durch 100000 für sekunden
		mul     R3,R5,R2				; mul ergebnis (R4) mit 100000
		sub     R0,R0,R3        		; ziehe minuten von ticks ab

		mov     R2,#1000         
		udiv    R6,R0,R2				; teile ticks durch 1000 für ms

		ldr		R0,=MY_TEXT		
		mov		R1,#10

		udiv	R2,R4,R1				; teile minuten durch 10 für die 10ner stelle
		mul		R3,R2,R1				; 
		sub		R3,R4,R3				; rest leifert einerstelle der minuten
		add		R2,#0x30				; umwandeln von ascii in zahlen
		add		R3,#0x30				; umwandeln von ascii in zahlen
		strb	R2,[R0,#0]				; speichern der 10ner minuten
		strb	R3,[R0,#1]				; speichern der 1ner minuten

		udiv	R2,R5,R1				; teile sekunen durch 10 für die 10ner stelle
		mul		R3,R2,R1
		sub		R3,R5,R3				; rest leifert einerstelle der sekunden
		add		R2,#0x30				; umwandeln von ascii in zahlen
		add		R3,#0x30				; umwandeln von ascii in zahlen
		strb	R2,[R0,#3]				; speichern der 10ner sekunden
		strb	R3,[R0,#4]				; speichern der 1ner sekunden

		udiv	R2,R6,R1				; teile ms durch 10 für die 10ner stelle
		mul		R3,R2,R1
		sub		R3,R6,R3				; rest leifert einerstelle der ms
		add		R2,#0x30				; umwandeln von ascii in zahlen
		add		R3,#0x30				; umwandeln von ascii in zahlen
		strb	R2,[R0,#6]				; speichern der 10ner ms
		strb	R3,[R0,#7]				; speichern der 1ner ms

		mov		R0,#10					; x achse
		mov		R1,#6					; y achse
		bl		lcdGotoXY				; text position mit (x,y)
		ldr 	R0,=MY_TEXT				; speichern er my_text adr.
		bl  	lcdPrintS				; ausgabe des neuen text auf dem lcd

disp_end
		POP     {PC}                    ; Rücksprung
		ENDP

UpdateClk	PROC
		ldr		R2,=CURRENT_STATE		
		ldr		R2,[R2]					
		cmp		R2,#STATE_INIT			; prüfe status 0, 1, 2
		beq		reset_clk				; Im INIT-Zustand keine Zeit addieren

		ldr		R1,=TIMER
		ldr		R1,[R1]					; Aktueller Hardware-Timerwert
		ldr		R2,=LAST_TIMER_VAL
		ldr		R3,[R2]					; Vorheriger Timerwert
		str		R1,[R2]					; Aktuellen Wert für nächstes Mal speichern

		sub		R0,R1,R3				; Vergangene Ticks seit letztem Aufruf berechnen
		ldr		R1,=STOPUHR_TICKS
		ldr		R2,[R1]					; aktueller stand der ticks
		add		R2,R2,R0				; Ticks auf das Zeitkonto addieren
		str		R2,[R1]
		bx		lr

reset_clk
		ldr		R1,=TIMER
		ldr		R1,[R1]
		ldr		R2,=LAST_TIMER_VAL
		str		R1,[R2]					; Timerwert einfach nur synchronhalten
		bx		lr
		ENDP

		ALIGN
		END