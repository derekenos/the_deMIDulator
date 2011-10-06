
;**********************************************************************
;                                                                     *
;    Project:       deMIDulator                                       *
;    Filename:	    mootLoader_init_v0_2.asm                          *
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
; Function: void mootLoader_initCore()
;**********************************************************************

mootLoader_initCore
; making mootLoader_initCore() a single function to save Program Memory space

;**********************************************************************
; Function: void mootLoader_initOsc()
;**********************************************************************
	; configure for internal clock at 8Mhz & 4x PLL = 32Mhz
	; primary clock determined by FOSC<3:0>
	; confirgure internal osc for 8Mhz
	bsf		OSCCON, IRCF2, ACCESS
	bsf		OSCCON, IRCF1, ACCESS
	bcf		OSCCON, IRCF0, ACCESS

#ifdef	PIC18LF13K50

mootLoader_initOsc_lp1
	; wait for internal high freq osc to stabilize
	; "pic18lf13k50.inc" lists bit as "IOFS" but datasheet calls it "HFIOFS"
	btfss	OSCCON, IOFS, ACCESS
	bra		mootLoader_initOsc_lp1

	; enable PLL
	bsf		OSCTUNE, SPLLEN, ACCESS
#endif

#ifdef	PIC18LF14K22
mootLoader_initOsc_lp1
	; wait for internal high freq osc to stabilize
	btfss	OSCCON, HFIOFS, ACCESS
	bra		mootLoader_initOsc_lp1

	; enable PLL
	bsf		OSCTUNE, PLLEN, ACCESS
#endif	

;**********************************************************************
; Function: void mootLoader_initIO()
;**********************************************************************
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
	
;**********************************************************************
; Function: void mootLoader_initUART()
;**********************************************************************
	movlw	15	; 31.25K baud rate @ 32Mhz clock
	movwf	SPBRG, ACCESS
	; Enable serial port
	; Enable reception
	bsf		RCSTA, SPEN, ACCESS
	bsf		RCSTA, CREN, ACCESS
	; Enable transmission
	bsf		TXSTA, TXEN, ACCESS

;**********************************************************************
; Function: void mootLoader_initTimer2()
;**********************************************************************
	; Prescale 1:1
	; Turn on Timer2
	bsf		T2CON, TMR2ON, ACCESS
	; Reset and interrupt on match value
	movlw	255
	movwf	PR2, ACCESS	

;**********************************************************************
; Function: void mootLoader_initHeap()
;**********************************************************************

mootLoader_initHeap
	lfsr	softwareStackPointerFSR, softwareStackBaseAddress

	return
	

	
