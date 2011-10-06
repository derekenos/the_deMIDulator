
;**********************************************************************
;                                                                     *
;    Project:       deMIDulator                                       *
;    Filename:	    init.asm                                          *
;    Date:                                                            *
;    File Version:                                                    *
;                                                                     *
;    Author:        Derek Enos                                        *
;    Company:                                                         *
;                                                                     * 
;                                                                     *
;**********************************************************************
;                                                                     *
;    Files required:                                                  *
;                                                                     *
;                                                                     *
;                                                                     *
;**********************************************************************

;**********************************************************************
; INCLUDE FILES
;**********************************************************************

;**********************************************************************
; LOCAL FUNCTIONS
;**********************************************************************

;**********************************************************************
; Function: void initCore()
;**********************************************************************

initCore
	call initOsc
	call initIO
	call initUART
	call initTimer0
	call initTimer1
	call initTimer2
	call initCCP
	call initSPI
	call initADC
	call initInterrupts
	call initRAM
	call initHeap
	return
		
	
;**********************************************************************
; Function: void initOsc()
;**********************************************************************

initOsc
	; configure for internal clock at 8Mhz & 4x PLL = 32Mhz
	; primary clock determined by FOSC<3:0>
	; confirgure internal osc for 8Mhz
	bsf		OSCCON, IRCF2, ACCESS
	bsf		OSCCON, IRCF1, ACCESS
	bcf		OSCCON, IRCF0, ACCESS

#ifdef	PIC18LF13K50
initOsc_lp1
	; wait for internal high freq osc to stabilize
	; "pic18lf13k50.inc" lists bit as "IOFS" but datasheet calls it "HFIOFS"
	btfss	OSCCON, IOFS, ACCESS
	bra		initOsc_lp1

	; enable PLL
	bsf		OSCTUNE, SPLLEN, ACCESS
#endif

#ifdef	PIC18LF14K22
initOsc_lp1
	; wait for internal high freq osc to stabilize
	btfss	OSCCON, HFIOFS, ACCESS
	bra		initOsc_lp1

	; enable PLL
	bsf		OSCTUNE, PLLEN, ACCESS
#endif	


	return


;**********************************************************************
; Function: void initIO()
;**********************************************************************

initIO
	; IO Summary
	; 
	; (organized by pin #)
	; Pin	Port	Assignment
	; ---  ----	----------
	; 1		VDD		VDD
	; 2		RA5		LED (Sine)
	; 3		RA4		Audio In
	; 4		RA3		ICSP
	; 5		RC5		Audio Out
	; 6		RC4		LED (Square)
	; 7		RC3		LED (Sample)
	; 8		RC6		EEPROM Chip Select
	; 9		RC7		EEPROM Slave In
	; 10	RB7		[Not Connected]
	; 11	RB6		EEPROM Clock
	; 12	RB5		MIDI In
	; 13	RB4		EEPROM Slave Out
	; 14	RC2		Switch (MIDI Record / Playback)
	; 15	RC1		Switch (Voice Through / Record)
	; 16	RC0		Switch (Waveform)
	; 17	VUSB	[Not Connected]
	; 18	RA1		ICSP
	; 19	RA0		ICSP
	; 20	VSS		VSS
	;
	; [PORT A]
	; Pin	Port	Assignment							Direction
	; ---  ----		----------							---------
	; 19	RA0		ICSP								IN
	; 18	RA1		ICSP								IN
	; 4		RA3		ICSP								IN
	; 3		RA4		Audio In							IN
	; 2		RA5		LED (Sine)							OUT

	bsf		LATA, RA5, ACCESS	; LED is off
	movlw	0xff ^ 1<<RA5
	movwf	TRISA, ACCESS

	; [PORT B]
	; Pin	Port	Assignment							Direction
	; ---  ----		----------							---------
	; 13	RB4		EEPROM Slave Out					IN
	; 12	RB5		MIDI In								IN
	; 11	RB6		EEPROM Clock						OUT
	; 10	RB7		[Not Connected]						IN

	movlw	0xff ^ 1<<RB6	; EEPROM clock is LOW
	movwf	LATB, ACCESS
	movlw	0xff ^ 1<<RB6
	movwf	TRISB, ACCESS
	
	; [PORT C]
	; Pin	Port	Assignment							Direction
	; ---  ----		----------							---------
	; 16	RC0		Switch (Waveform)					IN
	; 15	RC1		Switch (Voice Through / Record)		IN
	; 14	RC2		Switch (MIDI Record / Playback)		IN
	; 7		RC3		LED (Sample)						OUT
	; 6		RC4		LED (Square)						OUT
	; 5		RC5		Audio Out							OUT
	; 8		RC6		EEPROM Chip Select					OUT
	; 9		RC7		EEPROM Slave In						OUT
	
	bsf		LATC, RC3, ACCESS	; LED is off
	bsf		LATC, RC4, ACCESS	; LED is off
	bcf		LATC, RC5, ACCESS	; Audio out is low
	bsf		LATC, RC6, ACCESS	; Chip select is idle
	movlw	0x07
	movwf	TRISC, ACCESS
	
	; [General IO]
	bcf		INTCON2, NOT_RABPU, ACCESS	; enable PORT A & B pullups per WPU registers
	movlw	1<<ANS3	; ANS3 = RA4(Audio In)
	movwf	ANSEL, ACCESS	; enable digital input buffers for all non-analog inputs
	clrf	ANSELH, ACCESS	; enable digital input buffers for all non-analog inputs	
	return
	
	
;**********************************************************************
; Function: void initUART()
;**********************************************************************

initUART
	movlw	15	; 31.25K baud rate @ 32Mhz clock
	movwf	SPBRG, ACCESS
	; Enable serial port
	; Enable reception
	bsf		RCSTA, SPEN, ACCESS
	bsf		RCSTA, CREN, ACCESS
	; Enable transmission
	bsf		TXSTA, TXEN, ACCESS
	return


;**********************************************************************
; Function: void initTimer0()
;**********************************************************************

initTimer0
	; timer is on
	; 16-bit mode
	bcf	T0CON, T08BIT, ACCESS
	; clock = internal
	bcf		T0CON, T0CS, ACCESS
	; timer0 using prescaler
	; prescale = 1:8
	; Fosc = 32Mhz. 1/((32Mhz/4)/ 8) * overflowValue(==65536) = overflow every 65.536mS)
	bcf		T0CON, PSA, ACCESS
	bcf		T0CON, T0PS2, ACCESS
	bsf		T0CON, T0PS1, ACCESS	
	bcf		T0CON, T0PS0, ACCESS	

	return


;**********************************************************************
; Function: void initTimer1()
;**********************************************************************

initTimer1
	; DO NOT ENABLE TIMER1 OR SDO WILL NOT WORK!
	return


;**********************************************************************
; Function: void initTimer2()
;**********************************************************************

initTimer2

	; Turn on Timer2
	bsf		T2CON, TMR2ON, ACCESS
	; Using default power-on prescale of 1:1
	; Reset and interrupt on match value
	movlw	255
	movwf	PR2, ACCESS
	; Timer2 configured for 32uS interrupt period
	; (SYS_OSC / PERIPH_CLK_DIV) / PR2 = period
	; (32Mhz / 4) / 256 = 32uS
	return
	

;**********************************************************************
; Function: void initCCP()
;**********************************************************************

initCCP
	; PWM single output
	; PWM mode; P1A, P1C active-high; P1B, P1D active-high
	; 10-bit PWM bits [1:0] = 0b11
	bsf		CCP1CON, CCP1M3, ACCESS
	bsf		CCP1CON, CCP1M2, ACCESS

	clrf	CCPR1L, ACCESS	
	return


;**********************************************************************
; Function: void initSPI()
;**********************************************************************

initSPI
	; serial port enabled
	; idle clock is LOW
	; mode is SPI master, clock = Fosc/4 = 8MHz
	bsf		SSPCON1, SSPEN, ACCESS

	; input data latched on idle->active
	; output data latched on active->idle clock
	bsf		SSPSTAT, CKE, ACCESS
	return
	

;**********************************************************************
; Function: void initADC()
;**********************************************************************

initADC
	; channel = AN3
	; ADC is on
	bsf		ADCON0, CHS1, ACCESS	
	bsf		ADCON0, CHS0, ACCESS	
	bsf		ADCON0, ADON, ACCESS	
	
	; positive reference is internal VDD
	; negative reference is internal VSS

	; left justify result
	; acquisition time = 4 tad
	; clock source = Fosc/32 = 32Mhz/32 = 1Mhz, TAD = 1uS
	bsf		ADCON2, ACQT1, ACCESS
	bsf		ADCON2, ADCS1, ACCESS
	return


;**********************************************************************
; Function: void initInterrupts()
;**********************************************************************

initInterrupts
	; Enable interrupt priorities		
	bsf		RCON, IPEN, ACCESS
	
	; unmask peripheral interrupts
	; enable timer0 interrupts
	; enable INT0 interrupts
	; clear timer0 int flag
	; clear INT0 int flag
	bsf		INTCON, PEIE, ACCESS
	bsf		INTCON, TMR0IE, ACCESS

; DEBUG - PIC18LF14K22 INT0/1/2 pins not compatible with PIC18LF13K50
#ifndef	PIC18LF14K22
	bsf		INTCON, INT0IE, ACCESS
#endif
	bcf		INTCON, TMR0IF, ACCESS
	bcf		INTCON, INT0IF, ACCESS
	
	; INT0 interrupt on falling edge
	; INT1 interrupt on falling edge
	; INT2 interrupt on falling edge
	; Interrupt priority is low
	bcf		INTCON2, INTEDG0, ACCESS
	bcf		INTCON2, INTEDG1, ACCESS
	bcf		INTCON2, INTEDG2, ACCESS
	bcf		INTCON2, TMR0IP, ACCESS
		
	; INT2 is low Priority interrupt
	; INT1 is low Priority interrupt
	; enable INT2 interrupts
	; enable INT1 interrupts
	; clear INT2 int flag
	; clear INT1 int flag
	bcf		INTCON3, INT2IP, ACCESS
	bcf		INTCON3, INT1IP, ACCESS
; DEBUG - PIC18LF14K22 INT0/1/2 pins not compatible with PIC18LF13K50
#ifndef	PIC18LF14K22
	bsf		INTCON3, INT2IE, ACCESS
	bsf		INTCON3, INT1IE, ACCESS
#endif
	bcf		INTCON3, INT2IF, ACCESS
	bcf		INTCON3, INT1IF, ACCESS
			
	; UART RX is low priority interrupt	
	bcf		IPR1, RCIP, ACCESS
	
	; clear timer2 int flag
	bcf		PIR1, TMR2IF, ACCESS		
	
	; enable UART rx ints
	; enable timer2 interrupts
	bsf		PIE1, RCIE, ACCESS
	bsf		PIE1, TMR2IE, ACCESS
	return
	

;**********************************************************************
; Function: void initRAM()
;**********************************************************************
initRAM
	; clear all general purpose RAM locations to 0x00
initRAM_bank0
	; init pointer to start of BANK0
	clrf	FSR0L, ACCESS
	clrf	FSR0H, ACCESS
initRAM_bank0Lp
	clrf	POSTINC0, ACCESS
	; BANK0 is done when FSR0 == 0x0100
	movlw	1
	cpfseq	FSR0H, ACCESS
	bra		initRAM_bank0Lp

initRAM_bank1
	; PIC18LF13K50 does not implement BANK1 so skip it

initRAM_bank2
	; init pointer to start of BANK2
	clrf	FSR0L, ACCESS
	movlw	0x02
	movwf	FSR0H, ACCESS
initRAM_bank2Lp
	clrf	POSTINC0, ACCESS
	; BANK2 is done when FSR0 == 0x0300
	movlw	3
	cpfseq	FSR0H, ACCESS
	bra		initRAM_bank2Lp

	; reset fsr address
	clrf	FSR0L, ACCESS	
	clrf	FSR0H, ACCESS	
	return

;**********************************************************************
; Function: void initHeap()
;**********************************************************************

initHeap
	lfsr	softwareStackPointerFSR, softwareStackBaseAddress
	return
	

	