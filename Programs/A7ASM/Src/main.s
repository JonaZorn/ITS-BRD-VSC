;*******************************************************************************
;* File Name          : main.s
;* Description        : Musterloesung Stoppuhr (Woche 9) - HAW Hamburg
;*******************************************************************************

PERIPH_BASE     	equ	0x40000000                 
AHB1PERIPH_BASE 	equ	(PERIPH_BASE + 0x00020000)
APB1PERIPH_BASE     equ PERIPH_BASE

GPIOD_BASE			equ	(AHB1PERIPH_BASE + 0x0C00)		; LEDs 
GPIOF_BASE			equ	(AHB1PERIPH_BASE + 0x1400)		; Schalter
TIM2_BASE           equ (APB1PERIPH_BASE + 0x0000)		; Hardware timer
	
GPIO_F_PIN        	equ	(GPIOF_BASE + 0x10)				; Schalter Register
GPIO_D_SET			equ (GPIOD_BASE + 0x18)				; LED anschalten
GPIO_D_CLR			equ	(GPIOD_BASE + 0x1A)				; LED ausschalten
	
TIMER				equ (TIM2_BASE + 0x24)   			; Zählerregister (1 Tick = 10 us)
TIM2_PSC			equ (TIM2_BASE + 0x28)   
TIM2_ERG			equ (TIM2_BASE + 0x14)   

    EXTERN initITSboard			
    EXTERN GUI_init				
	EXTERN initTimer			
	EXTERN lcdSetFont			
	EXTERN lcdGotoXY      		
	EXTERN lcdPrintS			
    EXTERN lcdPrintC            

; Definition der FSM Zustände
STATE_INIT			equ	0
STATE_RUNNING		equ	1
STATE_HOLD			equ	2

	AREA MyData, DATA, align = 2

DEFAULT_BRIGHTNESS	DCW     800							
MY_TEXT				DCB		"00:00.00", 0
	ALIGN
CURRENT_STATE		DCD		STATE_INIT	; Speichert den aktuellen FSM-Zustand
LAST_TIMER_VAL		DCD		0			; Für UpdateClk: Vorheriger Hardware-Timestamp
STOPWATCH_TICKS		DCD		0			; Das Zeitkonto der Stoppuhr in 10us-Schritten
LAST_BUTTON_STATE	DCD		0xFF		; Zur Flankenerkennung

	AREA |.text|, CODE, READONLY, ALIGN = 3
	EXPORT main [CODE]
	
main	PROC
		BL		initITSboard			
		ldr   	r1,=DEFAULT_BRIGHTNESS	
		ldrh 	r0,[r1]
		bl   	GUI_init				
		bl  	initTimer				
		ldr 	R1,=TIM2_PSC   			
		mov 	R0,#(90*10-1) 			
		strh	R0,[R1]
		ldr 	R1,=TIM2_ERG   			
		mov		R0,#0x01
		strh	R0,[R1]					
		MOV 	R0, #24					
		bl  	lcdSetFont				

	; Initialisiere den ersten Zeitstempel für UpdateClk
		ldr		R0,=TIMER
		ldr		R0,[R0]
		ldr		R1,=LAST_TIMER_VAL
		str		R0,[R1]

	; Uhr auf 00:00.00 vorab anzeigen
		mov		R0,#10
		mov		R1,#6
		BL		lcdGotoXY
		ldr 	R0,=MY_TEXT
		bl  	lcdPrintS

superloop
		BL		UpdateClk        ; 1. Zeit-Aktualisierung
		BL		ReadButtons      ; 2. Taster einlesen & Flankenerkennung (liefert R0 und R2)
		BL		UpdateFSM        ; 3. FSM Zustandsübergänge (INIT, RUNNING, HOLD)
		BL		SetLEDs          ; 4. LEDs je nach Zustand ansteuern
		BL		DisplayTime      ; 5. Uhrzeit auf dem TFT ausgeben (außer in HOLD)
		BAL		superloop
		ENDP		; 



; Unterprogramme 
;------------------

ReadButtons PROC
		ldr		R0,=GPIO_F_PIN
		ldrh	R0,[R0]
		and		R0,#0xFF				; R0 = aktuelle Tasterzustände

		ldr		R1,=LAST_BUTTON_STATE
		ldr		R2,[R1]					; R2 = alter Zustand
		str		R0,[R1]					; Zustand für das nächste Mal merken
		bx		lr
		ENDP

UpdateFSM PROC
		ldr		R1,=CURRENT_STATE
		ldr		R3,[R1]					; R3 = Aktueller Zustand

	; --- PRÜFE TASTER S5 (Bit 5) ---
		and		R4,R0,#(1<<5)
		and		R5,R2,#(1<<5)
		cmp		R5,#(1<<5)
		bne		check_s6
		cmp		R4,#0
		bne		check_s6
		mov		R3,#STATE_INIT
		str		R3,[R1]
		b		fsm_output_action

check_s6
	; --- PRÜFE TASTER S6 (Bit 6) ---
		and		R4,R0, #(1<<6)
		and		R5,R2, #(1<<6)
		cmp		R5,#(1<<6)
		bne		check_s7
		cmp		R4,#0
		bne		check_s7
		cmp		R3,#STATE_RUNNING
		bne		check_s7
		mov		R3,#STATE_HOLD
		str		R3,[R1]
		b		fsm_output_action

check_s7
	; --- PRÜFE TASTER S7 (Bit 7) ---
		and		R4,R0,#(1<<7)
		and		R5,R2,#(1<<7)
		cmp		R5,#(1<<7)
		bne		fsm_output_action
		cmp		R4,#0
		bne		fsm_output_action
		cmp		R3,#STATE_INIT
		beq		set_running
		cmp		R3,#STATE_HOLD
		bne		fsm_output_action
set_running
		mov		R3,#STATE_RUNNING
		str		R3,[R1]

fsm_output_action
		cmp		R3,#STATE_INIT
		bne		fsm_end
		mov		R0,#0
		ldr		R4,=STOPWATCH_TICKS
		str		R0,[R4]
fsm_end
		bx		lr
		ENDP

SetLEDs PROC
		ldr		R3,=CURRENT_STATE
		ldr		R3,[R3]

		mov		R0,#3
		ldr		R4,=GPIO_D_CLR
		str		R0,[R4]

		cmp		R3,#STATE_RUNNING
		bne		led_hold
		mov		R0,#1
		ldr		R4,=GPIO_D_SET
		str		R0,[R4]
		b		led_end

led_hold
		cmp		R3,#STATE_HOLD
		bne		led_end
		mov		R0,#3
		ldr		R4,=GPIO_D_SET
		str		R0,[R4]
led_end
		bx		lr
		ENDP

DisplayTime PROC
		PUSH    {LR}                    ; LR sichern, da BL aufgerufen wird

		ldr		R3,=CURRENT_STATE
		ldr		R3,[R3]
		cmp		R3,#STATE_HOLD
		beq		disp_end				; Wenn HOLD, Anzeige einfrieren

		ldr		R0,=STOPWATCH_TICKS
		ldr		R0,[R0]

		ldr     R2,=6000000      
		udiv    R4,R0,R2        
		mul     R3,R4,R2
		sub     R0,R0,R3        

		ldr     R2,=100000       
		udiv    R5,R0,R2        
		mul     R3,R5,R2
		sub     R0,R0,R3        

		mov     R2,#1000         
		udiv    R6,R0,R2

		ldr		R0,=MY_TEXT		
		mov		R1,#10

		udiv	R2,R4,R1		
		mul		R3,R2,R1
		sub		R3,R4,R3		
		add		R2,#0x30		
		add		R3,#0x30
		strb	R2,[R0,#0]		
		strb	R3,[R0,#1]		

		udiv	R2,R5,R1		
		mul		R3,R2,R1
		sub		R3,R5,R3		
		add		R2,#0x30
		add		R3,#0x30
		strb	R2,[R0,#3]		
		strb	R3,[R0,#4]		

		udiv	R2,R6,R1		
		mul		R3,R2,R1
		sub		R3,R6,R3		
		add		R2,#0x30
		add		R3,#0x30
		strb	R2,[R0,#6]		
		strb	R3,[R0,#7]		

		mov		R0,#10
		mov		R1,#6
		BL		lcdGotoXY
		ldr 	R0,=MY_TEXT
		BL  	lcdPrintS

disp_end
		POP     {PC}                    ; Rücksprung
		ENDP

UpdateClk	PROC
		ldr		R2,=CURRENT_STATE
		ldr		R2,[R2]
		cmp		R2,#STATE_INIT
		beq		reset_clk				; Im INIT-Zustand keine Zeit addieren

		ldr		R1,=TIMER
		ldr		R1,[R1]					; Aktueller Hardware-Timerwert
		ldr		R2,=LAST_TIMER_VAL
		ldr		R3,[R2]					; Vorheriger Timerwert
		str		R1,[R2]					; Aktuellen Wert für nächstes Mal speichern

		sub		R0,R1,R3				; Vergangene Ticks seit letztem Aufruf calculate
		ldr		R1,=STOPWATCH_TICKS
		ldr		R2,[R1]
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