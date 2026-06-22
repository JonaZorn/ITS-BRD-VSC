;******************** (C) COPYRIGHT HAW-Hamburg ********************************
;* File Name          : main.s
;* Author             : Franz Korf	
;* Version            : V1.0
;* Date               : 11.05.2022
;* Description        : Rahmen zur Loesung von GTP Woche 7-9 (Stoppuhr).
;*******************************************************************************

; Define address of selected GPIO and Timer registers
PERIPH_BASE     	equ	0x40000000                 ;Peripheral base address
AHB1PERIPH_BASE 	equ	(PERIPH_BASE+0x00020000)
APB1PERIPH_BASE     equ PERIPH_BASE

GPIOD_BASE			equ	(AHB1PERIPH_BASE+0x0C00)
GPIOF_BASE			equ	(AHB1PERIPH_BASE+0x1400)
TIM2_BASE           equ (APB1PERIPH_BASE+0x0000)
	
GPIO_F_PIN        	equ	(GPIOF_BASE+0x10)

GPIO_D_PIN			equ	(GPIOD_BASE+0x10)
GPIO_D_SET			equ (GPIOD_BASE+0x18)
GPIO_D_Clr			equ	(GPIOD_BASE+0x1A)
	
TIMER				equ (TIM2_BASE+ 0x24)   ; CNT : current time stamp (32 bit),  resolution
TIM2_PSC			equ (TIM2_BASE+0x28)   	; Prescaler  resolution
TIM2_ERG			equ (TIM2_BASE+0x14)   	; 16 Bit register, Bit 0 : 1 Restart Timer
TICKS_10MIN     	EQU 60000000
TICKS_1MIN      	EQU 6000000
TICKS_10SEC     	EQU 1000000
TICKS_1SEC      	EQU 100000
TICKS_10CENT		EQU	10000
TICKS_1CENT			EQU 1000

    EXTERN initITSboard
    EXTERN GUI_init
	EXTERN TP_Init
	EXTERN initTimer
	EXTERN lcdSetFont
	EXTERN lcdGotoXY      		; TFT goto x y function
	EXTERN lcdPrintS			; TFT output function	
    EXTERN lcdPrintC            ; TFT output one character		
	EXTERN Delay				; Delay (ms) function


;********************************************
; Data section, aligned on 4-byte boundery
;********************************************
	AREA MyData, DATA, align = 2

DEFAULT_BRIGHTNESS	DCW     800
ZEIT				DCB		"00:00.00", 0
ZEIT_ALT			DCB		"aa:aa.aa", 0
NULL_ZEIT			DCB		"00:00.00", 0
STATE				DCB		0


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
		ldr   	r1,=DEFAULT_BRIGHTNESS
		ldrh 	r0,[r1]
		bl   	GUI_init
		bl  	initTimer
		ldr 	R1,=TIM2_PSC   			; Set pre scaler such that 1 timer tick represents 10 us
		mov 	R0,#(90*10-1) 
		strh	R0,[R1]
		ldr 	R1,=TIM2_ERG   			; Restart timer	
		mov		R0,#0x01
		strh	R0,[R1]					; Set UG Bit
		mov 	R0,#24					
		bl  	lcdSetFont

	; Ihre Initialisierung
		mov 	R0,#10
		mov 	R1,#6
        bl      lcdGotoXY

	; Simple test code
		ldr 	R0,=NULL_ZEIT
		bl  	lcdPrintS

superloop
	; bl      update_state
		ldr	    R4,=STATE
		ldrb    R4,[R4] 
		cmp	    R4,#0
		bleq	init
		cmp	    R4,#1
		bleq	run
		cmp	    R4,#2
		bleq	hold
		bal		superloop
		ENDP

init PROC
        push    {R0-R2,lr}
        ldr     R0,=TIM2_ERG
        mov     R1,#0x01
        strh    R1,[R0]
        ldr     R0,=ZEIT
        mov     R1,#'0'
        strb    R1,[R0,#0]
        strb    R1,[R0,#1]
        strb    R1,[R0,#3]
        strb    R1,[R0,#4]
        strb    R1,[R0,#6]
        strb    R1,[R0,#7]
        bl      print_time
		bl		clearOffLED

	; Anfangen den Button S7 abzufragen
		mov     R0,#7
		ldr	    R1,=GPIO_F_PIN
		ldrh    R1,[R1] 
        bl      isButtonPressed

if_S7_pressed
        cmp     R0,#1
        bne     endif_S7_pressed

then_S7_pressed
		ldr	    R4,=STATE
        mov     R3,#1
        strb    R3,[R4]

endif_S7_pressed
        pop     {R0-R2,lr}
        bx      lr
        ENDP

run PROC
		push {R0,lr}
		bl	    timeCalc
		bl	    print_time
		mov	    R0,#0x1
		bl	    updateLED
		mov	    R0,#0x2
		bl	    clearLED

	; Anfangen den Button S6 abzufragen
		mov     R0,#6
		ldr	    R1,=GPIO_F_PIN
		ldrh    R1,[R1] 
        bl      isButtonPressed

if_S6_pressed
        cmp     R0,#1
        bne     endif_S6_pressed

then_S6_pressed
		ldr	    R4,=STATE
        mov     R3,#2
        strb    R3,[R4]

endif_S6_pressed
	; Anfangen den Button S5 abzufragen
		mov     R0,#5
		ldr	    R1,=GPIO_F_PIN
		ldrh    R1,[R1] 
        bl      isButtonPressed

if_S5_pressed
        cmp     R0,#1
        bne     endif_S5_pressed

then_S5_pressed
		ldr	    R4,=STATE
        mov     R3,#0
        strb    R3,[R4]

endif_S5_pressed
		pop {R0,lr}
		bx lr
		ENDP

hold PROC
        push {R0-R1,lr}
		mov		R0,#0x1
		bl	    updateLED
		mov		R0,#0x2
		bl	    updateLED

	; Anfangen den Button S7 abzufragen
		mov     R0,#7
		ldr	    R1,=GPIO_F_PIN
		ldrh    R1,[R1] 
        bl      isButtonPressed

if_S7_p
        cmp     R0,#1
        bne     endif_S7_p

then_S7_p
		ldr	    R4,=STATE
        mov     R3,#1
        strb    R3,[R4]

endif_S7_p
	; Anfangen den Button S5 abzufragen
		mov     R0,#5
		ldr	    R1,=GPIO_F_PIN
		ldrh    R1,[R1] 
        bl      isButtonPressed

if_S5_p
        cmp     R0,#1
        bne     endif_S5_p

then_S5_p
		ldr	    R4,=STATE
        mov     R3,#1
        strb    R3,[R4]

endif_S5_p
        pop {R0-R1,lr}
        bx lr
        ENDP

timeCalc PROC
		push	{R0-R3,lr}
		ldr	    R1,=TIMER
		ldr	    R1,[R1]
		ldr     R0,=ZEIT
		mov     R3,#'0'
        strb    R3,[R0,#0]
        strb    R3,[R0,#1]
        strb    R3,[R0,#3]
        strb    R3,[R0,#4]
        strb    R3,[R0,#6]
        strb    R3,[R0,#7]

min10_loop
		ldr	    R2,=TICKS_10MIN
		cmp	    R1,R2
		blt		min1_loop
		SUB	    R1,R1,R2
		ldrb    R3,[R0]
		ADD	    R3,R3,#1
		strb    R3,[R0]
		B		min10_loop

min1_loop
		ldr	    R2,=TICKS_1MIN
		cmp	    R1,R2
		blt		sec10_loop
		SUB	    R1,R1,R2
		ldrb    R3,[R0,#1]
		ADD	    R3,R3,#1
		strb    R3,[R0,#1]   
		B		min1_loop

sec10_loop
		ldr	    R2,=TICKS_10SEC
		cmp	    R1,R2
		blt		sec1_loop
		SUB	    R1,R1,R2
		ldrb    R3,[R0,#3]
		ADD	    R3,R3,#1
		strb    R3,[R0,#3]  
		B		sec10_loop

sec1_loop
		ldr	    R2,=TICKS_1SEC
		cmp	    R1,R2
		blt		cent10_loop
		SUB	    R1,R1,R2
		ldrb    R3,[R0,#4]
		ADD	    R3,R3,#1
		strb    R3,[R0,#4]  
		B		sec1_loop

cent10_loop
		ldr	    R2,=TICKS_10CENT
		cmp	    R1,R2
		blt		cent1_loop
		SUB	    R1,R1,R2
		ldrb    R3,[R0,#6]
		ADD	    R3,R3,#1
		strb    R3,[R0,#6]  
		B		cent10_loop

cent1_loop
		ldr	    R2,=TICKS_1CENT
		cmp	    R1,R2
		blt 	done
		SUB	    R1,R1,R2
		ldrb    R3,[R0,#7]
		ADD	    R3,R3,#1
		strb    R3,[R0,#7]  
		B		cent1_loop

done
		pop		{R0-R3,lr}
		bx lr
		ENDP

print_time PROC
		push	{R4-R8,lr}

for_sc 
		mov	    R4,#0 
		ldr		R5,=ZEIT
		ldr	    R7,=ZEIT_ALT 

until_sc 
		cmp	    R4,#8
		BEQ		enddo_sc 

do_sc		
		ldrb	R6,[R5,R4]
		ldrb	R8,[R7,R4]
		cmp 	R6,R8
		BEQ		next_char
		strb    R6,[R7,R4]
		mov     R0,R4
		ADD	    R0,R0,#0xA     
        mov     R1,#6
        bl      lcdGotoXY
		mov  	R0,R6
		bl  	lcdPrintC

next_char		
step_sc
		ADD	    R4,R4,#1
		B	    until_sc

enddo_sc
		pop		{R4-R8,lr}
		bx lr
		ENDP

	; Param: R0 Button, R1 GPIO_F_PIN Inhalt
	; Return: R0 1-> pressed 0 -> not pressed

isButtonPressed PROC
		mov	    R2,#1
		LSL	    R2,R2,R0
		AND	    R2,R1,R2
		cmp	    R2,#0
		BEQ		isPressed
		mov	    R0,#0
		B	    endPressed 	

isPressed
		mov	    R0,#1

endPressed  
		bx lr
		ENDP

update_state PROC
        push    {R0-R4,lr}
        ldr     R4,=STATE
        ldrb    R3,[R4]
        ldr     R1,=GPIO_F_PIN
        ldrh    R1,[R1]
        cmp     R3,#0
        bne     check_running
        mov     R0,#7
        bl      isButtonPressed
        cmp     R0,#1
        bne     state_done
        mov     R3,#1
        strb    R3,[R4]
        B       state_done

check_running
        cmp     R3,#1
        bne     check_hold
        mov     R0,#5
        bl      isButtonPressed
        cmp     R0,#1
        bne     running_check_s6
        mov     R3,#0
        strb    R3,[R4]
        B       state_done

running_check_s6
        mov     R0,#6
        bl      isButtonPressed
        cmp     R0,#1
        bne     state_done
        mov     R3,#2
        strb    R3,[R4]
        B       state_done

check_hold
        cmp     R3,#2
        bne     state_done
        mov     R0,#5
        bl      isButtonPressed
        cmp     R0,#1
        bne     hold_check_s7
        mov     R3,#0
        strb    R3,[R4]
        B       state_done

hold_check_s7
        mov     R0,#7
        bl      isButtonPressed
        cmp     R0,#1
        bne     state_done

        mov     R3,#1
        strb    R3,[R4]

state_done
        pop     {R0-R4,lr}
        bx      lr
        ENDP

	; Param: R0 -> LED als Bitzahl
	; Funktion schaltet LEDs an in Abhängigkeit von STATE

updateLED PROC
		push	{R0-R4,lr}
		ldr	    R1,=GPIO_D_SET
		strh	R0,[R1] 
		pop		{R0-R4,lr}
		bx	lr
		ENDP

	; Param: R0 -> LED als Bitzahl
	; Funktion schaltet LEDs ab in Abhängigkeit von STATE

clearLED PROC
		push	{R0-R4,lr}
		ldr	    R1,=GPIO_D_Clr
		strh	R0,[R1] 
		pop		{R0-R4,lr}
		bx	lr
		ENDP

clearOffLED PROC
		push	{R0-R4,lr}
		mov	    R0,#0xFF 
		ldr	    R1,=GPIO_D_Clr
		strh	R0,[R1] 
		pop		{R0-R4,lr}
		bx	lr
		ENDP

		ALIGN
		END
