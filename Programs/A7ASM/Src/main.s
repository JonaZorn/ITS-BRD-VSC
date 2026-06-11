;******************** (C) COPYRIGHT HAW-Hamburg ********************************
;* File Name          : main.s
;* Author             : Franz Korf	
;* Version            : V1.0
;* Date               : 11.05.2022
;* Description        : Rahmen zur Loesung von GTP Woche 7-9 (Stoppuhr).
;
;*******************************************************************************

; Define address of selected GPIO and Timer registers
PERIPH_BASE     	equ	0x40000000                 ;Peripheral base address
AHB1PERIPH_BASE 	equ	(PERIPH_BASE + 0x00020000)
APB1PERIPH_BASE     equ PERIPH_BASE

GPIOD_BASE			equ	(AHB1PERIPH_BASE + 0x0C00)		; Adresse der LEDs 
GPIOF_BASE			equ	(AHB1PERIPH_BASE + 0x1400)		; Adresse der Schalter
TIM2_BASE           equ (APB1PERIPH_BASE + 0x0000)		; Adresse des Hardware timers
	
GPIO_F_PIN        	equ	(GPIOF_BASE + 0x10)				; Register der Schalter

GPIO_D_PIN			equ	(GPIOD_BASE + 0x10)				; Register der LED
GPIO_D_SET			equ (GPIOD_BASE + 0x18)				; LED on
GPIO_D_CLR			equ	(GPIOD_BASE + 0x1A)				; LED off
	
TIMER				equ (TIM2_BASE + 0x24)   ; CNT : current time stamp (32 bit),  resolution
TIM2_PSC			equ (TIM2_BASE + 0x28)   ; Prescaler  resolution
TIM2_ERG			equ (TIM2_BASE + 0x14)   ; 16 Bit register, Bit 0 : 1 Restart Timer


    EXTERN initITSboard			; Initialisiert die Hardware
    EXTERN GUI_init				; LCD
	EXTERN initTimer			; zum starten des Timers
	EXTERN lcdSetFont			
	EXTERN lcdGotoXY      		; TFT goto x y function
	EXTERN lcdPrintS			; TFT output function	
    EXTERN lcdPrintC            ; TFT output one character		
	EXTERN Delay				; Delay (ms) function


;********************************************
; Data section, aligned on 4-byte boundery
;********************************************
	AREA MyData, DATA, align = 2

DEFAULT_BRIGHTNESS	DCW     800							; Display Helligkeit
MY_TEXT				DCB		"00:00.00", 0
Start    DCB   0        ; 0 = gestoppt, 1 = läuft
SAVED_T  DCD   0        ; gespeicherter Timer-Wert bei Stop
;********************************************
; Code section, aligned on 8-byte boundery
;********************************************
	AREA |.text|, CODE, READONLY, ALIGN = 3


;--------------------------------------------
; main subroutine
;--------------------------------------------
	EXPORT main [CODE]
	
main	PROC

		
		BL		initITSboard			; Initialisierung der HW
		ldr   	r1,=DEFAULT_BRIGHTNESS	
		ldrh 	r0,[r1]
		bl   	GUI_init				; Starte Display mit Helligkeit 800
		bl  	initTimer				; Timer Starten
		ldr 	R1,=TIM2_PSC   			; Set pre scaler such that 1 timer tick represents 10 us
		mov 	R0,#(90*10-1) 			; 1 Tick = 10us bei 90 MHz
		strh	R0,[R1]
		ldr 	R1,=TIM2_ERG   			; Restart timer	
		mov		R0,#0x01
		strh	R0,[R1]					; Set UG Bit
		MOV 	R0, #24					; Sezt Schriftgröße auf 24
		bl  	lcdSetFont				; 

; Ihre Initialisierung
; Timer
		ldr		R1,=Start
		mov		R0,#0	
		str		R0,[R1]

; LCD_Position
		mov		R0,#10
		mov		R1,#6
		BL		lcdGotoXY

		; Simple test code
		ldr 	R0,=MY_TEXT
		bl  	lcdPrintS

superloop
; Timer leesen
		ldr		R1,=TIMER
		ldr		R0,[R1]		; 1 tick = 10us
		mov		R2,#60000000		
		udiv	R1,R0,R2	; in 10 minuten
		str
		mov		R2,#6000000
		udiv	R3,R1,R2	; in 1 Minuten
		str
		mov		R2,#1000000
		udiv	R4,R3,R2	; in 10 sekunden 
		str
		mov		R2,#100000
		udiv	R4,R3,R2	; in 1 sekunden
		str
		mov		R2,#10000
		udiv	R4,R3,R2	; in 10 millisekunde
		str
		mov		R2,#1000
		udiv	R4,R3,R2	; in 1 millisekunde
		str

; read buttons
		LDR		R0,=GPIO_F_PIN	; Liest GPIO-F-Eingangsregister 
		ldrh	R0,[R0]
		and		R0,#0xFF   	; set bit 31 to 8 of R0 to 0 ; bit 7 to 0 do not change
							; bit i for R0 is 1 <=> button S<i> not pressed (for 0 <= i <= 7)
							; bit i for R0 is 0 <=> button S<i>     pressed (for 0 <= i <= 7)
							; switch LEDs off (button s<i> not pressed : LED D< +8> switched off (for 0 <= i <= 7)
		LDR		R1,=GPIO_D_CLR
		str		R0,[R1]
		
		; switch LEDs on (button s<i>      pressed : LED D< +8> switched on  (for 0 <= i <= 7)
		eor		R1,R0,#0xFF       ; toogle bit 0 to 7 of R1
		LDR		R1,=GPIO_D_SET
		str		R0,[R1]	
		BAL		superloop				; End of superloop
		

forever b		forever
		ENDP

		ALIGN
		END
