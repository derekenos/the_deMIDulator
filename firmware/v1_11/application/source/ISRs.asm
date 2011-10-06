
;**********************************************************************
;                                                                     *
;    Project:       deMIDulator                                       *
;    Filename:	    ISRs.asm                                          *
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
; INCLUDES
;**********************************************************************

	#include	"../header/midi.h"
	#include	"../header/soundGen.h"
	#include	"../header/userinterface.h"

;**********************************************************************
; DEFINITIONS
;**********************************************************************
	
;**********************************************************************
; LOCAL VARIABLES
;**********************************************************************	

;**********************************************************************
; LOCAL MACROS
;**********************************************************************	
INC_PRESCALE_COUNTERS MACRO
	; increment prescale counters, clear on match with SAMPLE_PRESCALE or WAVE_PRESCALE
	incf	samplePrescaleCounter, f, ACCESS
	movlw	SAMPLE_PRESCALE
	cpfslt	samplePrescaleCounter, ACCESS	
	clrf	samplePrescaleCounter, ACCESS

	incf	wavePrescaleCounter, f, ACCESS
	movlw	WAVE_PRESCALE
	cpfslt	wavePrescaleCounter, ACCESS
	clrf	wavePrescaleCounter, ACCESS
	
	; adsrPrescaleCounter reset is handled by serviceADSR()
	incf	adsrPrescaleCounter + 0, f, ACCESS
	btfsc	STATUS, C, ACCESS
	incf	adsrPrescaleCounter + 1, f, ACCESS
	
	ENDM
	
;**********************************************************************
; High Priority Interrupts Service Routines
;**********************************************************************

highPriorityISR
	; Using fast return for high-priority interrupts so context saving is not necessary
	; push working regs onto software stack
	PUSH_R	r0
	PUSH_R	r1
	; define variables to pushed registers
	#define	address		r0
	#define	tmpValue	r1
	
	;**********************************************************************
	; ****************
	; **** Timer2 ****
	; ****************

	;**** start procedure: check if Timer2 interrupt needs servicing ****
	; is Timer2 interrupt flag set?
	btfss	PIR1, TMR2IF, ACCESS
	goto	highPriorityISR_Timer2Done

	; clear Timer2 interrupt flag
	; this will allow function to determine if another interrupt occurred during processing
	; this is applicable for sample record routine which I suspect takes > 1 Timer2 interrupt period to complete
	; haven't tested this yet but code to handle event fixes sample record/playback rate disparity
	bcf		PIR1, TMR2IF, ACCESS

#ifdef	LED_STEADY_STATE_DISABLED
	; toggle ON LEDs to save precious mA.  Saves ~4mA over steady state current for single LED
	btfss	ledOnOffFlags, RA5, ACCESS
	btg		LATA, RA5, ACCESS	; SINE LED
	btfsc	ledOnOffFlags, RA5, ACCESS
	bcf		LATA, RA5, ACCESS	; SINE LED
	
	btfss	ledOnOffFlags, RC4, ACCESS	; SQUARE LED
	btg		LATC, RC4, ACCESS	; SQUARE LED
	btfsc	ledOnOffFlags, RC4, ACCESS	; SQUARE LED
	bcf		LATC, RC4, ACCESS	; SQUARE LED
	
	btfss	ledOnOffFlags, RC3, ACCESS	; SAMPLE LED
	btg		LATC, RC3, ACCESS	; SAMPLE LED
	btfsc	ledOnOffFlags, RC3, ACCESS	; SAMPLE LED
	bcf		LATC, RC3, ACCESS	; SAMPLE LED	
#endif

	; process SAMPLE or WAVE prescale counter
	; audio playback/sample clock is (PWM Base Clk / SAMPLE_PRESCALE)
	; waveform playback clock is (PWM Base Clk / WAVE_PRESCALE)
	; wait for appropriate prescale counter to be reset to 0 before processing next sound step
	; is current mode SAMPLE? 
	movlw	SAMPLE
	xorwf	waveShape, w, ACCESS
	; not SAMPLE so check wavePrescale
	bnz		highPriorityISRTimer2_prescaleNotSample
	; is SAMPLE so check samplePrescale
	movf	samplePrescaleCounter, f, ACCESS
	bz		highPriorityISRTimer2_prescaleOK
	goto	highPriorityISRTimer2_skipStep

	; playback mode is SINE or SQUARE wave so wait for wavePrescale counter to be reset to 0 before continuing
highPriorityISRTimer2_prescaleNotSample
	movf	wavePrescaleCounter, f, ACCESS
	bz		highPriorityISRTimer2_prescaleOK
	goto	highPriorityISRTimer2_skipStep
highPriorityISRTimer2_prescaleOK

	call	processSoundState	

	; if Timer2 interrupt flag is set then clear it and increment prescale counters twice
	btfss	PIR1, TMR2IF, ACCESS
	bra		highPriorityISRTimer2_skipStep
	
	; clear the flag
	bcf		PIR1, TMR2IF, ACCESS
	
	; increment prescale counters, clear on match with SAMPLE_PRESCALE, WAVE_PRESCALE or ADSR_PRESCALE
	INC_PRESCALE_COUNTERS

highPriorityISRTimer2_skipStep
	; increment prescale counters, clear on match with SAMPLE_PRESCALE, WAVE_PRESCALE or ADSR_PRESCALE
	INC_PRESCALE_COUNTERS
		

highPriorityISR_Timer2Done


	;**********************************************************************
	; **************
	; **** INT0 ****
	; **************

	; if(INT0IF)
	btfss	INTCON, INT0IF, ACCESS
	goto	highPriorityISR_INT0Done

	;	INT0IF = 0;
	bcf		INTCON, INT0IF, ACCESS

#ifndef	THROUGH_HOLE_PCB
	call	userInterface_incWaveform
#else
	; if waveShape != SAMPLE && record button is pressed then save current state to eeprom as default (power-up)
	movlw	SAMPLE
	xorwf	waveShape, w, ACCESS
	; waveShape == SAMPLE so incMode
	bz		highPriorityISR_INT0_incMode
	; waveShape != SAMPLE so check if Record button is pressed
	movlw	1<<RC1
	andwf	PORTC, w, ACCESS
	; remember that logic is active-low
	; if result != 0 then button is not pressed so incMode
	bnz		highPriorityISR_INT0_incMode
	; Record button is pressed so write current state to EEPROM
	; write midiChannel to EEPROM and exit
	WRITE_INTERNAL_EEPROM	3, adsrAttackRate
	WRITE_INTERNAL_EEPROM	4, adsrReleaseRate
	; cancel voice-through mode to signal write action
	movlw	PLAYBACK
	movwf	recordOrPlayback, ACCESS
	movlw	PWM_IDLE_OUTPUT_VALUE
	movwf	CCPR1L, ACCESS	
	; skip increment
	bra		highPriorityISR_INT0Done
	
highPriorityISR_INT0_incMode
	; else increment mode
	call	userInterface_incMode
#endif
	
highPriorityISR_INT0Done

	; undefine variables from pushed registers
	#undefine	address
	#undefine	tmpValue
	; pop working regs from software stack
	POP_R	r1
	POP_R	r0
	; Using fast return for high-priority interrupts so context saving is not necessary
	retfie	FAST

	
;**********************************************************************
; Low Priority Interrupts Service Routines
;**********************************************************************

lowPriorityISR
	; save context
	movwf	wTmp, ACCESS
	movff	STATUS, statusTmp
	movff	BSR, bsrTmp

	; push working regs onto software stack
	PUSH_R	r0
	; define variables for pushed registers
	#define	tmpValue	r0

	;**********************************************************************
	; **************
	; **** UART ****
	; **************

	; if(RCIF)
	btfsc	PIR1, RCIF, ACCESS
	call	processRxAsMIDI


	;**********************************************************************
	; **************
	; **** INT1 ****
	; **************

	; if(INT1IE && INT1IF)
	btfss	INTCON3, INT1IE, ACCESS
	goto	lowPriorityISR_INT1Done
	btfss	INTCON3, INT1IF, ACCESS
	goto	lowPriorityISR_INT1Done

	;	INT1IF = 0;
	bcf		INTCON3, INT1IF, ACCESS

	;	recordOrPlayback = VOICE_THROUGH;
	movlw	VOICE_THROUGH
	movwf	recordOrPlayback, ACCESS

	; eliminate record switch noise by waiting for it to stop bouncing before dumping data to eeprom
	; after record button is released, processSoundState() will begin decrementing recordWaitCountdown...
	; and not begin recording until recordWaitCountdown == 0

	movlw	RECORD_BUTTON_RELEASE_WAIT_TIME
	movwf	recordWaitCountdown, ACCESS
	
	;	sampleDataBufferIndex = 0;
	clrf	sampleDataBufferIndex, ACCESS		
	;	sampleChunkCount = 0;
	clrf	sampleChunkCount, ACCESS
	;	sampleChunkReady = FALSE;
	bcf		eepromFlags, sampleChunkReady, ACCESS
	
lowPriorityISR_INT1Done

	;**********************************************************************
	; **************
	; **** INT2 ****
	; **************

	; if(INT2IE && INT2IF)
	btfss	INTCON3, INT2IE, ACCESS
	goto	lowPriorityISR_INT2Done
	btfss	INTCON3, INT2IF, ACCESS
	goto	lowPriorityISR_INT2Done

	;	INT2IF = 0;
	bcf		INTCON3, INT2IF, ACCESS

#ifndef	THROUGH_HOLE_PCB
	call	userInterface_incMode
#else
	call	userInterface_incWaveform
#endif
	
lowPriorityISR_INT2Done

	;**********************************************************************
	; ****************
	; **** TIMER0 ****
	; ****************
	;
	; Timer0 handles LED state updates based on current waveShape and mode
		
	; if(TMR0IE && TMR0IF)
	btfss	INTCON, TMR0IE, ACCESS
	goto	lowPriorityISR_TMR0Done
	btfss	INTCON, TMR0IF, ACCESS
	goto	lowPriorityISR_TMR0Done

	bcf		INTCON, TMR0IF, ACCESS
		
	; if playbackOrRecord == VOICE_THROUGH or RECORD, then turn all LEDs ON
	movlw	VOICE_THROUGH
	xorwf	recordOrPlayback, w, ACCESS
	bz		lowPriorityISR_TMR0AllOn
	movlw	RECORD
	xorwf	recordOrPlayback, w, ACCESS
	bnz		lowPriorityISR_TMR0NotAllOn
lowPriorityISR_TMR0AllOn
	LED_ALL_ON	
	bra		lowPriorityISR_TMR0Done

lowPriorityISR_TMR0NotAllOn
	; check if waveShape == SINE
	movlw	SINE
	cpfseq	waveShape, ACCESS
	bra		lowPriorityISR_TMR0TrySq

	; waveShape == SINE
	; if ledBlinkRate == 0 then LED is steady state
	movf	ledBlinkRate, f, ACCESS
	bnz		lowPriorityISR_TMR0SiBlink
	; led is steady state
	LED_ONLY_SINE_ON
	bra		lowPriorityISR_TMR0Done
lowPriorityISR_TMR0SiBlink
	; led is blinking
	decfsz	ledBlinkCounter, f, ACCESS
	bra		lowPriorityISR_TMR0Done
	; toggle the LED
	LED_SINE_TOGGLE_OTHERS_OFF
	; reload the counter
	movff	ledBlinkRate, ledBlinkCounter	
	bra		lowPriorityISR_TMR0Done

lowPriorityISR_TMR0TrySq
	; waveShape is != SINE so check if waveShape == SQUARE
	movlw	SQUARE
	cpfseq	waveShape, ACCESS
	bra		lowPriorityISR_TMR0TrySa

	; waveShape == SQUARE
	; if ledBlinkRate == 0 then LED is steady state
	movf	ledBlinkRate, f, ACCESS
	bnz		lowPriorityISR_TMR0SqBlink
	; led is steady state
	LED_ONLY_SQUARE_ON
	bra		lowPriorityISR_TMR0Done
lowPriorityISR_TMR0SqBlink
	; led is blinking
	decfsz	ledBlinkCounter, f, ACCESS
	bra		lowPriorityISR_TMR0Done
	; toggle the LED
	LED_SQUARE_TOGGLE_OTHERS_OFF
	; reload the counter
	movff	ledBlinkRate, ledBlinkCounter	
	bra		lowPriorityISR_TMR0Done

lowPriorityISR_TMR0TrySa
	; waveShape is != SQUARE so assume that waveShape == SQUARE
	; if ledBlinkRate == 0 then LED is steady state
	movf	ledBlinkRate, f, ACCESS
	bnz		lowPriorityISR_TMR0SaBlink
	; led is steady state
	LED_ONLY_SAMPLE_ON
	bra		lowPriorityISR_TMR0Done
lowPriorityISR_TMR0SaBlink
	; led is blinking
	decfsz	ledBlinkCounter, f, ACCESS
	bra		lowPriorityISR_TMR0Done
	; toggle the LED
	LED_SAMPLE_TOGGLE_OTHERS_OFF
	; reload the counter
	movff	ledBlinkRate, ledBlinkCounter	
	bra		lowPriorityISR_TMR0Done

lowPriorityISR_TMR0Done

	; undefine variables from pushed registers
	#undefine	tmpValue
	; pop working regs from software stack
	POP_R	r0

	; restore context
	movff	bsrTmp, BSR
	movf	wTmp, w, ACCESS
	movff	statusTmp, STATUS
	
	; return from interrupt
	retfie
	
	
	