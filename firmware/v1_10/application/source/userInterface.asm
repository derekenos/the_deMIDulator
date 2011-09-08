
;**********************************************************************
;                                                                     *
;    Project:       deMIDulator                                       *
;    Filename:	    userInterface.asm                                 *
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

;**********************************************************************
; DEFINITIONS
;**********************************************************************

;**********************************************************************
; LOCAL VARIABLES
;**********************************************************************

	CBLOCK
		ledBlinkRate:1
		ledBlinkCounter:1
		ledOnOffFlags:1
	ENDC


;**********************************************************************
; LOCAL FUNCTIONS
;**********************************************************************

;**********************************************************************
; Function: void initUserInterface(void)
;**********************************************************************

initUserInterface:

		; init with steady state LED
		clrf	ledBlinkRate, ACCESS
		clrf	ledBlinkCounter, ACCESS
	
	return
	

;**********************************************************************
; Function: void userInterface_incMode(void)
;**********************************************************************
userInterface_incMode
	; mode is changing so set needDelgator flag
	bsf		soundGenFlags, needRefresh, ACCESS
	
	; increment modeLevel, reset if > MAX_MODE_LEVEL
	incf	modeLevel, f, ACCESS
	movlw	MAX_MODE_LEVEL + 1
	; skip if modeLevel < MAX_MODE_LEVEL + 1
	cpfslt	modeLevel, ACCESS
	clrf	modeLevel, ACCESS
	
	; if(modeLevel == POLY)
	; {
	;   polyDepth = MAX_POLY_DEPTH
	;   ledBlinkRate = LEVEL_POLY_LED_BLINK_RATE
	;   ledBlinkCounter = LEVEL_POLY_LED_BLINK_RATE
	;	sustainFlags = 0
	; }
	movlw	POLY
	cpfseq	modeLevel, ACCESS
	bra		userInterface_incModeCheckSustain
	movlw	MAX_POLY_DEPTH
	movwf	polyDepth, ACCESS
	; set LED blink rate
	movlw	LEVEL_POLY_LED_BLINK_RATE
	movwf	ledBlinkRate
	movwf	ledBlinkCounter
	; clear sustain flags
	DISABLE_SUSTAIN
	bra		userInterface_incModeDone

userInterface_incModeCheckSustain
	; if(modeLevel == SUSTAIN)
	; {
	;   polyDepth = MAX_POLY_DEPTH
	;   ledBlinkRate = LEVEL_SUSTAIN_LED_BLINK_RATE
	;   ledBlinkCounter = LEVEL_SUSTAIN_LED_BLINK_RATE
	;	sustainFlags = (~oscResetFlags) & 0x0f
	; }
	movlw	SUSTAIN
	cpfseq	modeLevel, ACCESS
	bra		userInterface_incModeDoMono
	movlw	MAX_POLY_DEPTH
	movwf	polyDepth, ACCESS
	movlw	LEVEL_SUSTAIN_LED_BLINK_RATE
	movwf	ledBlinkRate
	movwf	ledBlinkCounter
	; set sustain lock flags for all active oscillators
	ENABLE_SUSTAIN
	bra		userInterface_incModeDone	
	
userInterface_incModeDoMono
	; if(modeLevel == MONO)
	; {
	;   polyDepth = 1
	;   ledBlinkRate = LEVEL_MONO_LED_BLINK_RATE
	;   ledBlinkCounter = LEVEL_MONO_LED_BLINK_RATE
	;	sustainFlags = 0
	; }
	movlw	1
	movwf	polyDepth, ACCESS
	; set LED blink rate
	movlw	LEVEL_MONO_LED_BLINK_RATE
	movwf	ledBlinkRate
	movwf	ledBlinkCounter
	; clear sustain flags
	DISABLE_SUSTAIN
userInterface_incModeDone
	return


;**********************************************************************
; Function: void userInterface_incWaveform(void)
;**********************************************************************
userInterface_incWaveform
	; waveShape is changing so set needDelgator flag
	bsf		soundGenFlags, needRefresh, ACCESS

	; check if decrement is being request from MIDI Program Change
	btfss	soundGenFlags, pgDec, ACCESS
	bra		userInterface_incWaveformInc
	; clear Program Change decrement flag
	bcf		soundGenFlags, pgDec, ACCESS	
	decf	waveShape, f, ACCESS
	; branch if result was positive
	bc		userInterface_incWaveformDone
	; result was negative so set to SAMPLE
	movlw	SAMPLE
	movwf	waveShape, ACCESS
	bra		userInterface_incWaveformDone

userInterface_incWaveformInc
	;	if(++waveShape > SAMPLE)
	;		waveShape = SINE;
	incf	waveShape, f, ACCESS
	movlw	SAMPLE
	cpfsgt	waveShape, ACCESS
	bra		userInterface_incWaveformDone
	movlw	SINE
	movwf	waveShape, ACCESS
userInterface_incWaveformDone
	return
	




