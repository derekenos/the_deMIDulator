
;**********************************************************************
;                                                                     *
;    Project:       deMIDulator                                       *
;    Filename:	    soundGen.h                                        *
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

#ifndef	_SOUNDGENH_
#define _SOUNDGENH_

;**********************************************************************
; GENERAL
;**********************************************************************

; Current code structure requires that MAX_POLY_DEPTH be set to 4!
#define MAX_POLY_DEPTH					4	

#define	ACTIVE_NOTE_DELTAS_ELEMENT_SIZE	2
#define ACTIVE_NOTE_DELTAS_SIZE			MAX_POLY_DEPTH * ACTIVE_NOTE_DELTAS_ELEMENT_SIZE

#define	DELEGATED_DELTAS_ELEMENT_SIZE	2
#define	DELEGATED_DELTAS_SIZE			MAX_POLY_DEPTH * DELEGATED_DELTAS_ELEMENT_SIZE

#define	OSC_DELTAS_ELEMENT_SIZE			2
#define	OSC_DELTAS_SIZE					MAX_POLY_DEPTH * OSC_DELTAS_ELEMENT_SIZE

#define ACCUMULATORS_ELEMENT_SIZE		4
#define ACCUMULATORS_SIZE				MAX_POLY_DEPTH * ACCUMULATORS_ELEMENT_SIZE

#define	ACTIVE_OUTPUT_VALUES_EL_SIZE	1
#define	ACTIVE_OUTPUT_VALUES_SIZE		MAX_POLY_DEPTH * ACTIVE_OUTPUT_VALUES_EL_SIZE

#define LED_BLINK_RATE_VOICE_THROUGH	20
#define LED_BLINK_RATE_VOICE_RECORD		6

; set soundGen timebase prescales for wave and sample modes
; Timer2 interrupt period is currently 32uS
; set sample timebase period to 192uS (5208 Hz)
#define SAMPLE_PRESCALE 6
; wave sine/square timebase period to 64uS (15.625 kHz)
#define	WAVE_PRESCALE	2

#define	MAX_MODE_LEVEL	MONO

#define	ADSR_ATTACK_RATE	64
#define	ADSR_RELEASE_RATE	16
; set adsr prescale target to increment adsrLimiterRegs value every 19.52mS
; 19.52mS gives a max individual attack/release time of 4.99712 Seconds
; the "increment" value is set by adsrAttackRate and adsrReleaseRate
#define	ADSR_PRESCALE 610

;**********************************************************************
; ENUM TYPE DEFINITIONS
;**********************************************************************

; waveShape
#define	SINE 0
#define SQUARE 1
#define SAMPLE 2

; recordOrPlayback
#define	VOICE_THROUGH 0
#define	RECORD 1
#define	PLAYBACK 2

; modeLevels
#define POLY 0
#define	SUSTAIN 1
#define MONO 2


;**********************************************************************
; FLAG VARIABLE DEFINITIONS
;**********************************************************************

; midiFlags
#define	turnSoundOn 3
#define	turnSoundOff 4
#define noteTransition 5
#define soundOn 6

; soundGenFlags
#define	delegatorBusy 0
#define	pgDec 1
#define	needRefresh 2

; oscEnabledFlags
; oscResetFlags
#define	osc0	0
#define	osc1	1
#define	osc2	2
#define	osc3	3

; adsrFlags
#define	attack 3
#define	decay 2
#define	sustain 1
#define	release 0


;**********************************************************************
; MACROS
;**********************************************************************

;**********************************************************************
CLEAR_ACCUMULATORS	MACRO
	local	loop

	; init local variables
	PUSH_R	r0
	PUSH_R	FSR0L
	PUSH_R	FSR0H
	
	; load fsr
	lfsr	FSR0, accumulators

	; init count
	movf	polyDepth, w, ACCESS
	movwf	r0, ACCESS
loop	
	; each accumulator is 4 bytes wide
	clrf	POSTINC0, ACCESS	
	clrf	POSTINC0, ACCESS	
	clrf	POSTINC0, ACCESS	
	clrf	POSTINC0, ACCESS	
	; decrement count, skip if done
	decfsz	r0, f, ACCESS
	bra		loop

	; restore variables
	POP_R	FSR0H
	POP_R	FSR0L
	POP_R	r0
	
	ENDM
	

;**********************************************************************
ENABLE_SUSTAIN	MACRO
	comf	oscResetFlags, w, ACCESS
	andlw	0x0f
	movwf	sustainFlags, ACCESS
	ENDM
	
;**********************************************************************
DISABLE_SUSTAIN	MACRO
	clrf	sustainFlags, ACCESS
	ENDM

;**********************************************************************
REVERSE_SAMPLE_IF_MOD_OVER_63	MACRO
	local exitMacro
	; if modulation > 63 then reverse sample
	movlw	63
	cpfsgt	modulation, ACCESS
	bra		exitMacro
	; modulation > 63 so do nextSampleAddress = (sampleEndAddress - nextSampleAddress)
	movf	nextSampleAddress, w
	subwf	sampleEndAddress, w
	movwf	nextSampleAddress
	movf	nextSampleAddress + 1, w
	subwfb	sampleEndAddress + 1, w
	movwf	nextSampleAddress + 1
exitMacro
	ENDM

;**********************************************************************
OSC_ADVANCE_ADSR	MACRO	OSC_NUMBER
	local	macroDone, doAttack, attackDone, doRelease, releaseDone

	; ignore advance if oscillator is sustained
	btfsc	sustainFlags, OSC_NUMBER, ACCESS
	bra		macroDone
	
	btfsc	adsrFlags + OSC_NUMBER, attack, ACCESS
	bra		doAttack
	btfsc	adsrFlags + OSC_NUMBER, release, ACCESS
	bra		doRelease
	bra		macroDone
	
doAttack
	; osc is attacking

	; if adsrAttackRate == 64 (correlating to midiAttackTime value of 0) then ignore adsr
	movlw	64
	xorwf	adsrAttackRate, w, ACCESS
	bz	attackDone

	; if((adsrLimiterRegs -= ADSR_ATTACK_RATE) <=0)
	movf	adsrAttackRate, w, ACCESS
	subwf	adsrLimiterRegs + OSC_NUMBER, f, ACCESS
	bnc		attackDone
	bz		attackDone
	bra		macroDone
attackDone
	; {
	;   adsrLimiterRegs = 0x00;	// init for release
	clrf	adsrLimiterRegs + OSC_NUMBER, ACCESS
	;   adsrFlags ^= 1<<attack;
	bcf		adsrFlags + OSC_NUMBER, attack, ACCESS
	; }
	bra	macroDone

doRelease
	; osc is releasing

	; if adsrReleaseRate == 64 (correlating to midiReleaseTime value of 0) then ignore adsr
	movlw	64
	xorwf	adsrReleaseRate, w, ACCESS
	bz	releaseDone

	; if((adsrLimiterRegs += ADSR_ATTACK_RATE) >= 255)
	movf	adsrReleaseRate, w, ACCESS
	addwf	adsrLimiterRegs + OSC_NUMBER, f, ACCESS
	bc		releaseDone
	comf	adsrLimiterRegs + OSC_NUMBER, w, ACCESS
	bz		releaseDone
	bra		macroDone
releaseDone
	; {
	;   adsrLimiterRegs = 0xff;	// init for attack
	setf	adsrLimiterRegs + OSC_NUMBER, ACCESS
	;   adsrFlags ^= 1<<release;
	bcf		adsrFlags + OSC_NUMBER, release, ACCESS
	;		delegatedDeltas[OSC_NUMBER] = delegatedDeltas[OSC_NUMBER + 1] = 0;
	clrf	delegatedDeltas + OSC_NUMBER * 2;
	clrf	delegatedDeltas + (OSC_NUMBER * 2) + 1;
	; }
	bra	macroDone
	
macroDone
	ENDM
	
;**********************************************************************
OSC_MIX	MACRO	OSC_NUMBER
	local	adsrDone

	movf	adsrLimiterRegs + OSC_NUMBER, w, ACCESS
	subwf	activeOutputValues + OSC_NUMBER, w
	bc		adsrDone
	movlw	0
	
adsrDone
	; add WREG to mixedOutputL/H
	addwf	mixedOutputL, f, ACCESS
	btfsc	STATUS, C, ACCESS
	incf	mixedOutputH, f, ACCESS
	
	ENDM

;**********************************************************************
OSC_READ_ADSR_FLAG	MACRO	FLAG
; oscillator number passed in WREG
; boolean value is returned in WREG and ZERO flag is set accordingly

	; push working regs onto software stack
	PUSH_R	FSR0L
	PUSH_R	FSR0H
	
	; load fsr
	lfsr	FSR0, adsrFlags
	; read the register into WREG
	movf	PLUSW0, w, ACCESS
	andlw	1<<FLAG
	
	; restore working regs from stack
	POP_R	FSR0H
	POP_R	FSR0L	
	
	ENDM

;**********************************************************************
OSC_SET_ADSR_FLAG	MACRO	FLAG
; oscillator number passed in WREG

	; push working regs onto software stack
	PUSH_R	FSR0L
	PUSH_R	FSR0H
	
	; load fsr
	lfsr	FSR0, adsrFlags
	bsf	PLUSW0, FLAG, ACCESS
	
	; restore working regs from stack
	POP_R	FSR0H
	POP_R	FSR0L	
	
	ENDM
	
;**********************************************************************
OSC_CLR_ADSR_FLAG	MACRO	FLAG
; oscillator number passed in WREG

	; push working regs onto software stack
	PUSH_R	FSR0L
	PUSH_R	FSR0H
	
	; load fsr
	lfsr	FSR0, adsrFlags
	bcf	PLUSW0, FLAG, ACCESS
	
	; restore working regs from stack
	POP_R	FSR0H
	POP_R	FSR0L	
	
	ENDM

;**********************************************************************
OSC_ADSR_ATTACK	MACRO
; oscillator number passed in WREG

	; push working regs onto software stack
	PUSH_R	FSR0L
	PUSH_R	FSR0H
	
	; load fsr
	lfsr	FSR0, adsrFlags
	; set flags
	bcf	PLUSW0, release, ACCESS
	bsf	PLUSW0, attack, ACCESS

	; load fsr
	lfsr	FSR0, adsrLimiterRegs
	; set limiter
	setf	PLUSW0, ACCESS
		
	; restore working regs from stack
	POP_R	FSR0H
	POP_R	FSR0L	
	
	ENDM
	
;**********************************************************************
OSC_STATE_BLOCK	MACRO	OSC_NUMBER
	local	checkDelegating, oscCheckActive, zeroAcc, oscActive, waveIsSample, noTransition
	local	clrSampleAcc, addressOk, waveIsNotSample, waveIsSine, waveIsSquare, tableAddressLoaded, resetOscillator, macroDone
		
	; if oscillator is locked for sustain then leave it alone
	btfsc	sustainFlags, OSC_NUMBER, ACCESS
	bra		oscActive
	
	; if mode is SINE or SQUARE then only allow oscillator state changes when activeOutputValue is 0
	movlw	SAMPLE
	xorwf	waveShape, w, ACCESS
	; mode is SAMPLE so skip zero check
	bz		checkDelegating
	
	; mode is SINE or SQUARE so check for zero output
	movf	activeOutputValues + (OSC_NUMBER * ACTIVE_OUTPUT_VALUES_EL_SIZE), w
	; not 0 so just keep spinning
	bnz		oscCheckActive
	
checkDelegating
	; don't update if delegator is busy because delegatedDelta value is volatile
	; so is oscEnabledFlags. For an oscillator turning on; flag is set after delegator writes delegatedDelta value so this is ok
	btfsc	soundGenFlags, delegatorBusy, ACCESS
	; delegator is busy so just keep spinning
	bra		oscCheckActive
	
	; check if oscillator is enabled
	btfss	oscEnabledFlags, OSC_NUMBER, ACCESS
	; oscillator is either still disabled or was just disabled by delegator so reset oscillator
	bra		resetOscillator

	; delegator is idle and oscillator is enabled so copy delegated delta as internal
	movff	delegatedDeltas + (OSC_NUMBER * DELEGATED_DELTAS_ELEMENT_SIZE) + 0, oscDeltas + (OSC_NUMBER * OSC_DELTAS_ELEMENT_SIZE) + 0
	movff	delegatedDeltas + (OSC_NUMBER * DELEGATED_DELTAS_ELEMENT_SIZE) + 1, oscDeltas + (OSC_NUMBER * OSC_DELTAS_ELEMENT_SIZE) + 1

oscCheckActive
	; if oscDeltas[OSC_NUMBER] == 0x00 then oscillator is not really active so reset
	; this check is required in event that (activeOutput == 0 && delegatorBusy == TRUE && oscDelta == 0)
	movf	oscDeltas			+ (OSC_NUMBER * OSC_DELTAS_ELEMENT_SIZE)			+ 0, f
	bnz		oscActive
	movf	oscDeltas			+ (OSC_NUMBER * OSC_DELTAS_ELEMENT_SIZE)			+ 1, f
	bz		resetOscillator
	
oscActive
	; if oscillator is starting from reset state then begin with 0x0000 accumulator
	btfsc	oscResetFlags, OSC_NUMBER, ACCESS
	bra		zeroAcc

	;**** start procedure: step Accumulator (SINE/SQUARE/SAMPLE) ****
	; accumulator += activeNoteDelta
	; accumulators are 4 bytes wide, activeNoteDeltas are 2 bytes wide
	movf	oscDeltas			+ (OSC_NUMBER * OSC_DELTAS_ELEMENT_SIZE)			+ 0, w
	addwf	accumulators 		+ (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE)			+ 0, f
	movf	oscDeltas			+ (OSC_NUMBER * OSC_DELTAS_ELEMENT_SIZE)			+ 1, w	
	addwfc	accumulators 		+ (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE) 			+ 1, f
	movlw	0
	addwfc	accumulators 		+ (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE) 			+ 2, f
	addwfc	accumulators 		+ (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE) 			+ 3, f
	
zeroAcc
	; we're done with oscResetFlags flag so ensure that it's clear
	bcf		oscResetFlags, OSC_NUMBER, ACCESS
	
	;**** start procedure: handle Pitch Wheel (SINE/SQUARE/SAMPLE) ****
	; accumulator += pitchWheel
	movf	pitchWheel																+ 0, w, ACCESS
	addwf	accumulators 		+ (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE)			+ 0, f
	movf	pitchWheel																+ 1, w, ACCESS
	addwfc	accumulators 		+ (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE) 			+ 1, f
	movf	pitchWheel																+ 2, w, ACCESS
	addwfc	accumulators 		+ (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE) 			+ 2, f
	movf	pitchWheel																+ 3, w, ACCESS
	addwfc	accumulators 		+ (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE) 			+ 3, f
	
	;**** start procedure: if SAMPLE waveshape then load next read address  (SAMPLE ONLY) ****
	; branch to waveform specific table address load
	movlw	SAMPLE
	cpfseq	waveShape, ACCESS
	bra		waveIsNotSample
waveIsSample

	; if samplesLoaded flag is set then load next EEPROM read address
	; checking this here as opposed to before accumulator update will, in the event of the mainline not…
	; being able to load the samples in time, cause audio chopping rather than detuning
	btfss	eepromFlags, samplesLoaded, ACCESS
	bra		macroDone
	
	; check for note transition
	; noteTransition flag is set any time the active MIDI note changes during active sound generation
	; when a sample is playing back in POLY or SUSTAIN modes, we want the sample to restart from the beginning...
	; whenever a Note On message is received.
	btfss	midiFlags, noteTransition, ACCESS
	bra		noTransition
	; is modeLevel == POLY
	movlw	POLY
	xorwf	modeLevel, w, ACCESS
	; mode is POLY so reset accumulator to restart sample from beginning
	bz		clrSampleAcc

noTransition	
	; nextSampleAddress = ((accumulator >> 8) & 0xffff)
	; reset accumulator if nextSampleAddress value will exceed sampleEndAddress
	; is waveTableIndex > sampleEndAddress?
	movf	accumulators 		+ (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE)			+ 1, w
	subwf	sampleEndAddress, w, ACCESS
	movf	accumulators 		+ (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE)			+ 2, w
	subwfb	sampleEndAddress + 1, w, ACCESS
	; result is positive so waveTableIndex is within valid range
	bc		addressOk
	; ((accumulator >> 8) & 0xffff) is out of valid sample range so restart sample from beginning
	; reset accumulator
clrSampleAcc
	clrf	accumulators 		+ (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE)			+ 0
	clrf	accumulators 		+ (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE)			+ 1
	clrf	accumulators 		+ (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE)			+ 2
	clrf	accumulators 		+ (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE)			+ 3
addressOk
	
	; do nextSampleAddress = ((accumulator >> 8) & 0xffff)
	movff	accumulators 		+ (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE)			+ 1, nextSampleAddresses + (OSC_NUMBER * NEXT_SAMPLE_ADDRESSES_EL_SIZE) + 0
	movff	accumulators 		+ (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE)			+ 2, nextSampleAddresses + (OSC_NUMBER * NEXT_SAMPLE_ADDRESSES_EL_SIZE) + 1
	
	bra		macroDone
	
waveIsNotSample
	;**** start procedure: waveshape is SINE or SQUARE so read Program Memory table  (SINE/SQUARE ONLY) ****
	; branch to waveform specific table address load
	movlw	SINE
	cpfseq	waveShape, ACCESS
	bra		waveIsSquare

waveIsSine	
	; 
	; load address of SINE table read
	; offset = ((accumulator >> 8) & 0xff)
	movf	accumulators + (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE) + 1, w
	addwf	sineTableBaseAddress + 0, w
	movwf	TBLPTRL, ACCESS
	movf	sineTableBaseAddress + 1, w
	btfsc	STATUS, C, ACCESS
	addlw	1
	movwf	TBLPTRH, ACCESS
	movf	sineTableBaseAddress + 2, w
	btfsc	STATUS, C, ACCESS
	addlw	1
	movwf	TBLPTRU, ACCESS
	bra		tableAddressLoaded

waveIsSquare
	; load address of SQUARE table read
	; offset = ((accumulator >> 8) & 0xff)
	movf	accumulators + (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE) + 1, w
	addwf	squareTableBaseAddress + 0, w
	movwf	TBLPTRL, ACCESS
	movf	squareTableBaseAddress + 1, w
	btfsc	STATUS, C, ACCESS
	addlw	1
	movwf	TBLPTRH, ACCESS
	movf	squareTableBaseAddress + 2, w
	btfsc	STATUS, C, ACCESS
	addlw	1
	movwf	TBLPTRU, ACCESS

tableAddressLoaded
	; read value from program memory
	tblrd*
	movff	TABLAT, activeOutputValues + (OSC_NUMBER * ACTIVE_OUTPUT_VALUES_EL_SIZE) + 0
	bra		macroDone
	
resetOscillator
	; set oscillator reset flag
	bsf		oscResetFlags, OSC_NUMBER, ACCESS
	clrf	activeOutputValues + (OSC_NUMBER * ACTIVE_OUTPUT_VALUES_EL_SIZE)
	clrf	oscDeltas + (OSC_NUMBER * OSC_DELTAS_ELEMENT_SIZE) + 0
	clrf	oscDeltas + (OSC_NUMBER * OSC_DELTAS_ELEMENT_SIZE) + 1
	clrf	accumulators + (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE) + 0
	clrf	accumulators + (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE) + 1
	clrf	accumulators + (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE) + 2
	clrf	accumulators + (OSC_NUMBER * ACCUMULATORS_ELEMENT_SIZE) + 3

macroDone

	ENDM
	
	
#endif


