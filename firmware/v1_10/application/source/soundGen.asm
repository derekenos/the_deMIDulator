	
;**********************************************************************
;                                                                     *
;    Project:       deMIDulator                                       *
;    Filename:	    soundGen.asm                                      *
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

	#include	"../header/soundGen.h"
	#include	"../header/midi.h"


;**********************************************************************
; LOCAL VARIABLES
;**********************************************************************

	CBLOCK

		soundGenFlags:1
		; bits defined in soundGen.h
		;	#define	delegatorBusy 0
		;	#define	pgDec 1
		;	#define	needRefresh 2
		pitchWheel:4
		modulation:1
		waveShape:1
		recordOrPlayback:1
		modeLevel:1
		samplePrescaleCounter:1
		wavePrescaleCounter:1
		; polyDepth (assigned from MAX_POLY_DEPTH during init) needs to be > 2 and a multiple of 2
		polyDepth:1
		; adding table addresses as variable to allow for roaming program memory samples
		sineTableBaseAddress:3
		squareTableBaseAddress:3
		oscResetFlags:1
		; bits defined in soundGen.h
		; #define	osc0	0
		; #define	osc1	1
		; #define	osc2	2
		; #define	osc3	3

		; making these variables global to save time during processSoundState ISR call
		sustainFlags:1
		sample:1
		mixedOutputL:1
		mixedOutputH:1
		oscStateFlags:4
		; bits defined in soundGen.h
		; #define	release 0
		; #define	sustain 1
		; #define	decay 2
		; #define	attack 3
		adsrLimiterRegs:4
		adsrAttackRate:1
		adsrReleaseRate:1
		adsrPrescaleCounter:2
		
		recordWaitCountdown:1
		
		; Declared at end of main.asm to ensure that arrays are pushed to end of memory...
		; with smaller variables in ACCESS memory
		; ---------------------------------------
		; activeNoteDeltas:ACTIVE_NOTE_DELTAS_SIZE
		; delegatedDeltas:DELEGATED_DELTAS_SIZE
		; oscDeltas:OSC_DELTAS_SIZE
		; accumulators:ACCUMULATORS_SIZE
		; activeOutputValues:ACTIVE_OUTPUT_VALUES_SIZE

	ENDC


;**********************************************************************
; LOCAL FUNCTIONS
;**********************************************************************

; [Function Summary]
;
; Function: initSoundGen()
; Abstract: initialize sound sound generation state variables
;
; Function: activeNoteTableAdd(WREG)
; Abstract: shift all values in activeNoteTable one level deeper and write note value passed in WREG to index 0
;           call refreshActiveNoteState()
;
; Function: activeNoteTableRemove(WREG)
; Abstract: look for index of note value passed in WREG in activeNoteTable and wipe location to 0xff if found
;           bubble sort all non-0xff values toward index 0
;           call refreshActiveNoteState()
;
; Function: refreshActiveNoteState()
; Abstract: check status of activeNoteTable entries and set turnSoundOn, turnSoundOff and notTransition flags appropriately
;           call getActiveNoteDeltas()
;
; Function: getActiveNoteDeltas()
; Abstract: for all active entries (non-0xff) in activeNoteTable from index 0 - polyDepth...
;           read accumulator delta value from Flash Program Memory table and save to corresponding index in activeNoteDeltas table
;
; Function: processSoundState()
; Abstract: called by Timer2 ISR
;           handles audio sampling/recording, calls eepromWrite64() when 64-byte sample buffer is full
;           handles all sound generation.  reading from Program Mem or EEPROM and writing to PWM


	; ***********************************************************************
	; Function: void initSoundGen(void)
	; ***********************************************************************
initSoundGen
	; push working regs onto software stack
	PUSH_R	r0
	PUSH_R	FSR0L
	PUSH_R	FSR0H
	; define variables to pushed registers
	#define	count	r0
	
	; using FSR0 for all inits, no need for fancy defines

	clrf	pitchWheel, ACCESS
	clrf	pitchWheel + 1, ACCESS
	clrf	pitchWheel + 2, ACCESS
	clrf	pitchWheel + 3, ACCESS
	
	clrf	modulation, ACCESS
		
	movlw	SINE
	movwf	waveShape, ACCESS
	movlw	PLAYBACK
	movwf	recordOrPlayback, ACCESS	
	movlw	POLY
	movwf	modeLevel, ACCESS
	
	movlw	MAX_POLY_DEPTH
	movwf	polyDepth, ACCESS

	clrf	samplePrescaleCounter, ACCESS
	clrf	wavePrescaleCounter, ACCESS

	bcf		midiFlags, turnSoundOn, ACCESS		
	bcf		midiFlags, turnSoundOff, ACCESS		
	bcf		midiFlags, keyPressed, ACCESS		
	bcf		midiFlags, soundOn, ACCESS

	bcf		soundGenFlags, delegatorBusy, ACCESS
	bcf		soundGenFlags, pgDec, ACCESS	
	bcf		soundGenFlags, needRefresh, ACCESS
	bcf		soundGenFlags, activeNoteTableModified, ACCESS
	
	movlw	low(sineTable)
	movwf	sineTableBaseAddress + 0
	movlw	high(sineTable)
	movwf	sineTableBaseAddress + 1
	movlw	upper(sineTable)
	movwf	sineTableBaseAddress + 2
	
	movlw	low(squareTable)
	movwf	squareTableBaseAddress + 0
	movlw	high(squareTable)
	movwf	squareTableBaseAddress + 1
	movlw	upper(squareTable)
	movwf	squareTableBaseAddress + 2
	
	bsf		oscResetFlags, osc0, ACCESS		
	bsf		oscResetFlags, osc1, ACCESS		
	bsf		oscResetFlags, osc2, ACCESS		
	bsf		oscResetFlags, osc3, ACCESS		
	
	clrf	sustainFlags, ACCESS

	; init ADSR variables
	clrf	oscStateFlags + 0, ACCESS
	clrf	oscStateFlags + 1, ACCESS
	clrf	oscStateFlags + 2, ACCESS
	clrf	oscStateFlags + 3, ACCESS
	
	setf	adsrLimiterRegs + 0, ACCESS
	setf	adsrLimiterRegs + 1, ACCESS
	setf	adsrLimiterRegs + 2, ACCESS
	setf	adsrLimiterRegs + 3, ACCESS
	clrf	adsrPrescaleCounter + 0, ACCESS
	clrf	adsrPrescaleCounter + 1, ACCESS
	
	clrf	recordWaitCountdown, ACCESS
		
	; load default adsr attack and release rates
	movlw	ADSR_ATTACK_RATE
	movwf	adsrAttackRate, ACCESS
	movlw	ADSR_RELEASE_RATE	
	movwf	adsrReleaseRate, ACCESS
			
	; load fsr
	lfsr	FSR0, activeNoteDeltas

	movlw	ACTIVE_NOTE_DELTAS_SIZE
	movwf	count, ACCESS
initSoundGen_lp1		
	clrf	POSTINC0, ACCESS
	decfsz	count, f, ACCESS
	bra		initSoundGen_lp1

	; load fsr
	lfsr	FSR0, accumulators

	movlw	ACCUMULATORS_SIZE
	movwf	count, ACCESS
initSoundGen_lp2	
	clrf	POSTINC0, ACCESS
	decfsz	count, f, ACCESS
	bra		initSoundGen_lp2

	; load fsr
	lfsr	FSR0, activeOutputValues

	movlw	ACTIVE_OUTPUT_VALUES_SIZE
	movwf	count, ACCESS
initSoundGen_lp3
	movlw	PWM_IDLE_OUTPUT_VALUE
	movwf	POSTINC0, ACCESS

	decfsz	count, f, ACCESS
	bra		initSoundGen_lp3

	; load fsr
	lfsr	FSR0, delegatedDeltas

	movlw	DELEGATED_DELTAS_SIZE
	movwf	count, ACCESS
initSoundGen_lp4
	; 0xff indicates that delta is unowned
	clrf	POSTINC0, ACCESS
	decfsz	count, f, ACCESS
	bra		initSoundGen_lp4

	; load fsr
	lfsr	FSR0, oscDeltas

	movlw	OSC_DELTAS_SIZE
	movwf	count, ACCESS
initSoundGen_lp5
	clrf	POSTINC0, ACCESS
	decfsz	count, f, ACCESS
	bra		initSoundGen_lp5

	; undefine variables from pushed registers
	#undefine count
	; pop working regs from software stack
	POP_R	FSR0H
	POP_R	FSR0L
	POP_R	r0
	
	return


	; ***********************************************************************
	; Function: void activeNoteTableAdd(byte note)
	; ***********************************************************************
activeNoteTableAdd
	; push working regs onto software stack
	PUSH_R	r0
	PUSH_R	r1
	PUSH_R	r2
	PUSH_R	FSR0L
	PUSH_R	FSR0H
	; define variables to pushed registers
	#define	note					r0
	#define	index					r1
	#define	tmpValue				r2
	#define	FSR_activeNoteTable		FSR0
	#define	PLUSW_activeNoteTable	PLUSW0

	; load fsr
	lfsr	FSR_activeNoteTable, activeNoteTable

	; saved argument passed in WREG
	movwf	note, ACCESS
		
	;**** start procedure: add note to activeNoteTable index 0 ****
	; start at end of table and shift all entries 1 level deeper
	; note that if all activeNoteTable entries are active then note at index ACTIVE_NOTE_TABLE_SIZE - 1 will be lost

	; initialize index to end of table
	movlw	ACTIVE_NOTE_TABLE_SIZE - 1
	movwf	index, ACCESS
activeNoteTableAdd_lp1
	; tmpValue = activeNoteTable[index - 1]
	decf	index, w, ACCESS
	movf	PLUSW_activeNoteTable, w, ACCESS
	movwf	tmpValue, ACCESS
	; activeNoteTable[index] = activeNoteTable[index - 1]
	movf	index, w, ACCESS
	movff	tmpValue, PLUSW_activeNoteTable
	; decrement index and abort if we've reach the beginning of the table
	decfsz	index, f, ACCESS
	bra		activeNoteTableAdd_lp1

	; save note value to activeNoteTable index 0
	movff	note, activeNoteTable

activeNoteTableAdd_exit
	; undefine variables from pushed registers
	#undefine	note
	#undefine	index
	#undefine	tmpValue
	#undefine	FSR_activeNoteTable
	#undefine	PLUSW_activeNoteTable
	; pop working regs from software stack
	POP_R	FSR0H
	POP_R	FSR0L
	POP_R	r2
	POP_R	r1
	POP_R	r0

	; set MIDI keyPressed flag to indicate Note On message received
	; this flag is checked and then cleared in processSoundState() to determine when to terminate an audio sample recording
	; and whether or not to retrigger sample playback from beginning
	bsf		midiFlags, keyPressed, ACCESS		

	call	refreshActiveNoteState
	
	return
	
	; ***********************************************************************
	; Function: void activeNoteTableRemove(byte note)
	; ***********************************************************************
activeNoteTableRemove
	; push working regs onto software stack
	PUSH_R	r0
	PUSH_R	r1
	PUSH_R	r2
	PUSH_R	r3
	PUSH_R	FSR0L
	PUSH_R	FSR0H
	; define variables to pushed registers
	#define	note					r0
	#define	index					r1
	#define	tmpValue				r2
	#define	sorting					r3
	#define	FSR_activeNoteTable		FSR0
	#define	PLUSW_activeNoteTable	PLUSW0

	; load fsr
	lfsr	FSR_activeNoteTable, activeNoteTable

	; save argument passed in WREG
	movwf	note, ACCESS
		
	;**** start procedure: find all activeNoteTable entries equal to note value and wipe to 0xff ****
	; init index
	clrf	index, ACCESS

activeNoteTableRemove_lp1
	; if passed noteNumber is 0xff then ignore compare and just wipe location
	comf	note, w, ACCESS
	bz		activeNoteTableRemove_lp1Wipe

	; WREG = activeNoteTable[index]
	movf	index, w, ACCESS
	movf	PLUSW_activeNoteTable, w, ACCESS
	; skip if activeNoteTable[index] == note
	cpfseq	note, ACCESS
	; activeNoteTable[index] is != note so bypass wipe
	bra		activeNoteTableRemove_lp1Jmp1

activeNoteTableRemove_lp1Wipe
	; activeNoteTable[index] is == note or passed noteNumber was 0xff so wipe location value to 0xff
	movf	index, w, ACCESS
	setf	PLUSW_activeNoteTable, ACCESS
	; previously was aborting operation at this point but doing so provides...
	; less robust Note Off handling. In event of missed Note Off, note value can occupy multiple indexes
activeNoteTableRemove_lp1Jmp1
	; increment index indexer
	incf	index, f, ACCESS
	; compare to ACTIVE_NOTE_TABLE_SIZE, skip if equal
	movlw	ACTIVE_NOTE_TABLE_SIZE
	cpfseq	index, ACCESS
	bra		activeNoteTableRemove_lp1

	
	;**** start procedure: bubble sort all non-0xff values toward index 0 ****
	; logic of routine in C:
	;
	;	sorting = TRUE;	
	;	while(sorting)
	;	{
	;		sorting = FALSE;
	;
	;		for(index = 0; index < ACTIVE_NOTE_TABLE_SIZE - 1; index++)
	;		{
	;			if((activeNoteTable[index] == 0xff) && (activeNoteTable[index + 1] != 0xff))
	;			{
	;				activeNoteTable[index] = activeNoteTable[index + 1];
	;				activeNoteTable[index + 1] = 0xff;
	;				sorting = TRUE;
	;			}
	;		}
	;	}

	; using entire register for single bit sorting flag, set to TRUE to start first cycle
	setf	sorting, ACCESS
	
activeNoteTableRemove_sortLoop
	; are we still sorting?
	movf	sorting, f, ACCESS
	; no so abort
	bz		activeNoteTableRemove_sortDone
	
	; reset sorting flag to FALSE. will be set by following code if we're not actually done
	clrf	sorting, ACCESS

	; init index
	clrf	index, ACCESS
activeNoteTableRemove_bubbleLoop
	; is activeNoteTable[index] == 0xff?
	movf	index, w, ACCESS
	comf	PLUSW_activeNoteTable, w, ACCESS
	; no so increment index and continue
	bnz		activeNoteTableRemove_bubbleContinue

	; is activeNoteTable[i+1] != 0xff?
	incf	index, w, ACCESS
	comf	PLUSW_activeNoteTable, w, ACCESS
	; no so increment index and continue
	bz		activeNoteTableRemove_bubbleContinue
		
	; sorting condition was met so set flag
	setf	sorting, ACCESS		

	; activeNoteTable[index] = activeNoteTable[index+1]
	incf	index, w, ACCESS
	movf	PLUSW_activeNoteTable, w, ACCESS
	movwf	tmpValue, ACCESS
	movf	index, w, ACCESS
	movff	tmpValue, PLUSW_activeNoteTable
	
	; activeNoteTable[index+1] = 0xff
	incf	index, w, ACCESS
	setf	PLUSW_activeNoteTable, ACCESS
	
activeNoteTableRemove_bubbleContinue
	; increment index and save in self
	incf	index, f, ACCESS
	movlw	ACTIVE_NOTE_TABLE_SIZE - 1
	; if index is == ACTIVE_NOTE_TABLE_SIZE - 1 then we've reach the end of the table so skip loop branch
	cpfseq	index, ACCESS
	; not done stepping through activeNoteTable so continue
	bra		activeNoteTableRemove_bubbleLoop	
	
	; done stepping through activeNoteTable
	; branch to check if any sorting action was taken
	; process will keep looping until stepping through entire activeNoteTable causes no data swapping to occur
	bra		activeNoteTableRemove_sortLoop

activeNoteTableRemove_sortDone

	; undefine variables from pushed registers
	#undefine	note
	#undefine	index
	#undefine	tmpValue
	#undefine	sorting
	#undefine	FSR_activeNoteTable
	#undefine	PLUSW_activeNoteTable
	; pop working regs from software stack
	POP_R	FSR0H
	POP_R	FSR0L
	POP_R	r3
	POP_R	r2
	POP_R	r1
	POP_R	r0

	call	refreshActiveNoteState
	
	return


;**********************************************************************
; Function: void refreshActiveNoteState(void)
;**********************************************************************
refreshActiveNoteState
	; check if there are any active notes
	; if activeNoteTable[0] == 0xff then there are no active notes
	comf	activeNoteTable + 0, w
	; at least one note is active so keep sound on
	bnz		refreshActiveNoteState_active
	; no notes are active so request sound off
	bsf		midiFlags, turnSoundOff, ACCESS
	bcf		midiFlags, turnSoundOn, ACCESS
	bra		refreshActiveNoteState_exit

refreshActiveNoteState_active		
	; check if sound is on	
	btfss	midiFlags, soundOn, ACCESS
	bra		refreshActiveNoteState_soundIsOff

	; sound is on so request transition
	bcf		midiFlags, turnSoundOff, ACCESS
	bcf		midiFlags, turnSoundOn, ACCESS
	bra		refreshActiveNoteState_exit

refreshActiveNoteState_soundIsOff
	; sound is off so request sound on
	bcf		midiFlags, turnSoundOff, ACCESS
	bsf		midiFlags, turnSoundOn, ACCESS
	
refreshActiveNoteState_exit
	; calling getActiveNoteDeltas() is a big task which includes theDelegator()
	; so just try setting the refresh flag since we're inside the UART ISR right now
	bsf		soundGenFlags, needRefresh, ACCESS

	; set flag to indicate to getActiveNoteDeltas() that activeNoteTable has been modified
	bsf		soundGenFlags, activeNoteTableModified, ACCESS

	return


;**********************************************************************
; Function: void getActiveNoteDeltas(void)
;**********************************************************************
getActiveNoteDeltas

	; push working regs onto software stack
	PUSH_R	r0
	PUSH_R	FSR0L
	PUSH_R	FSR0H
	PUSH_R	FSR1L
	PUSH_R	FSR1H
	PUSH_R	TBLPTRL
	PUSH_R	TBLPTRH
	PUSH_R	TBLPTRU
	PUSH_R	TABLAT
	; define variables to pushed registers
	#define	index						r0
	#define	FSR_activeNoteTable			FSR0
	#define	PLUSW_activeNoteTable		PLUSW0
	#define	FSR_activeNoteDeltas		FSR1
	#define	PLUSW_activeNoteDeltas		PLUSW1

	; load FSR
	lfsr	FSR_activeNoteTable, activeNoteTable
	lfsr	FSR_activeNoteDeltas, activeNoteDeltas

getActiveNoteDeltasAgain
	; activeNoteTable is modified by ISR so is VOLATILE!
	; clear activeNoteTableModified flag so that we can check it again once we're done updating activeNoteDeltas
	; if the flag is set upon routine completion, then there's a chance that activeNoteDeltas are corrupt so do it again
	bcf		soundGenFlags, activeNoteTableModified, ACCESS

	; init index
	clrf	index, ACCESS

getActiveNoteDeltas_loop	
	; check if reading note or sample delta table
	movlw	SAMPLE
	xorwf	waveShape, w, ACCESS
	bz		getActiveNoteDeltas_loadSampleDelta

	; **** load value from midi delta table ****
	; load table pointer address
	; shift activeNote left once to get proper program memory offset since noteDelta values are word-sized
	; w = activeNoteTable[index]
	movf	index, w, ACCESS
	; if bit 7 is set then note at index is not valid
	btfsc	PLUSW_activeNoteTable, 7, ACCESS
	bra		getActiveNoteDeltas_zeroDelta
	; note at index is valid so continue
	bcf		STATUS, C, ACCESS
	rlcf	PLUSW_activeNoteTable, w, ACCESS
	addlw	low(midiNoteDeltaTable)
	movwf	TBLPTRL, ACCESS
	movlw	high(midiNoteDeltaTable)
	btfsc	STATUS, C, ACCESS
	addlw	1
	movwf	TBLPTRH, ACCESS
	movlw	upper(midiNoteDeltaTable)
	btfsc	STATUS, C, ACCESS
	addlw	1
	movwf	TBLPTRU, ACCESS
	bra		getActiveNoteDeltas_readTableAndSave

	; **** load value from sample delta table ****
getActiveNoteDeltas_loadSampleDelta
	; load table pointer address
	; shift activeNote left once to get proper program memory offset since noteDelta values are word-sized
	; w = activeNoteTable[index]
	movf	index, w, ACCESS
	; if bit 7 is set then note at index is not valid
	btfsc	PLUSW_activeNoteTable, 7, ACCESS
	bra		getActiveNoteDeltas_zeroDelta
	; note at index is valid so continue
	bcf		STATUS, C, ACCESS
	rlcf	PLUSW_activeNoteTable, w, ACCESS
	addlw	low(sampleMidiNoteDeltaTable)
	movwf	TBLPTRL, ACCESS
	movlw	high(sampleMidiNoteDeltaTable)
	btfsc	STATUS, C, ACCESS
	addlw	1
	movwf	TBLPTRH, ACCESS
	movlw	upper(sampleMidiNoteDeltaTable)
	btfsc	STATUS, C, ACCESS
	addlw	1
	movwf	TBLPTRU, ACCESS
	bra		getActiveNoteDeltas_readTableAndSave

getActiveNoteDeltas_zeroDelta
	; w = index * 2
	bcf		STATUS, C, ACCESS
	rlcf	index, w, ACCESS

	; Critical Section Begin
	; **************************
	; clear global interrupt to avoid ISR reading partial delta value
	bcf		INTCON, GIE, ACCESS

	clrf	PLUSW_activeNoteDeltas, ACCESS
	; w = (index * 2) + 1
	addlw	1
	clrf	PLUSW_activeNoteDeltas, ACCESS

	; re-enable interrupts
	bsf		INTCON, GIE, ACCESS
	; **************************
	; Critical Section End

	bra		getActiveNoteDeltas_next

getActiveNoteDeltas_readTableAndSave
	; read low byte into TBLAT
	tblrd*+
	; w = index * 2
	bcf		STATUS, C, ACCESS
	rlcf	index, w, ACCESS

	; Critical Section Begin
	; **************************
	; clear global interrupt to avoid ISR reading partial delta value
	bcf		INTCON, GIE, ACCESS
	
	movff	TABLAT, PLUSW_activeNoteDeltas
	; read high byte into TBLAT
	tblrd*+
	; w = (index * 2) + 1
	addlw	1
	movff	TABLAT, PLUSW_activeNoteDeltas

	; re-enable interrupts
	bsf		INTCON, GIE, ACCESS
	; **************************
	; Critical Section End

getActiveNoteDeltas_next	
	; increment index
	incf	index, f, ACCESS
	; compare against polyDepth to check if done
	movlw	MAX_POLY_DEPTH
	xorwf	index, w, ACCESS
	bnz		getActiveNoteDeltas_loop

getActiveNoteDeltas_exit
	; activeNoteTable is modified by ISR so is VOLATILE!
	; if activeNoteTableModified flag is set, there's a chance that activeNoteDeltas are corrupt so do it again
	btfsc	soundGenFlags, activeNoteTableModified, ACCESS
	bra		getActiveNoteDeltasAgain

	; undefine variables from pushed registers
	#undefine	index
	#undefine	FSR_activeNoteTable
	#undefine	PLUSW_activeNoteTable
	#undefine	FSR_activeNoteDeltas
	#undefine	PLUSW_activeNoteDeltas
	; pop working regs from software stack
	POP_R	TABLAT
	POP_R	TBLPTRU
	POP_R	TBLPTRH
	POP_R	TBLPTRL
	POP_R	FSR1H
	POP_R	FSR1L
	POP_R	FSR0H
	POP_R	FSR0L
	POP_R	r0

	; deltas have been updated so call the DelagatOr
	; need this here because getActiveNoteDeltas is called when waveShape is change by user
	call	theDelegatOr

	return


	; ***********************************************************************
	; Function: void theDelegatOr(void)
	; ***********************************************************************
theDelegatOr

	PUSH_R	r0
	PUSH_R	r1
	PUSH_R	r2
	PUSH_R	r3
	PUSH_R	r4
	PUSH_R	r5
	PUSH_R	r6
	PUSH_R	FSR0L
	PUSH_R	FSR0H
	PUSH_R	FSR1L
	PUSH_R	FSR1H
	
	#define	ddLockedFlags				r0
	#define	ddIndex					r1
	#define	ddIndexMask				r2
	#define	andIndex				r3
	#define	andIndexMask			r4
	#define	tmpValue				r5
	#define	andLockedFlags	r6
	#define	FSR_activeNoteDeltas	FSR0
	#define	PLUSW_activeNoteDeltas	PLUSW0
	#define	FSR_delegatedDeltas		FSR1
	#define	PLUSW_delegatedDeltas	PLUSW1
	
	lfsr	FSR_activeNoteDeltas, activeNoteDeltas
	lfsr	FSR_delegatedDeltas, delegatedDeltas

	; set flag to indicate to oscillators that delegatedDeltas are volatile
	bsf		soundGenFlags, delegatorBusy, ACCESS
	
	; check if poly or mono mode
	movlw	1
	cpfsgt	polyDepth, ACCESS
	bra		theDelgatOr_doMono
	
	;**** start procedure: free up any oscillator whose current delta is no longer present in activeNoteDeltas ****

	; corresponding ddLockedFlags and andLockedFlags will be set for each delegatedDelta that matches an activeNoteDelta
	; so clear em
	clrf	ddLockedFlags, ACCESS
	clrf	andLockedFlags, ACCESS
	
	; the purpose of the following routine is to check each oscillator's delegatedDelta value against the activeNoteDelta array
	; and free any oscillator up that is no longer valid
	; "ddLockedFlags" is used locally to indicate if an oscillator is locked to a current activeNoteDelta element
	
	; start looking through delegatedDeltas[0...3] for a match in the activeNoteTable[0...polyDepth-1]
	; reset delegatedDeltas index count
	clrf	ddIndex, ACCESS
	; reset delegatedDeltas index mask
	movlw	1
	movwf	ddIndexMask, ACCESS
	; start delegatedDelta iteration loop
theDelegatOr_undelOutLp
	; check for delegatedDeltas[ddIndex] == 0x0000
	bcf		STATUS, C, ACCESS
	rlcf	ddIndex, w, ACCESS
	movf	PLUSW_delegatedDeltas, f, ACCESS
	bnz		theDelegatOr_undelDdNonZero
	addlw	1
	movf	PLUSW_delegatedDeltas, f, ACCESS
	; delegatedDeltas[ddIndex] value is nonZero so continue
	bnz	theDelegatOr_undelDdNonZero
	
	; delegatedDeltas[ddIndex] value is 0x0000 so...
	; iterate to next delegatedDelta
	bra		theDelegatOr_undelNextDD

theDelegatOr_undelDdNonZero
	; reset activeNoteTable index count
	clrf	andIndex, ACCESS
	; reset activeNoteTable index mask
	movlw	1
	movwf	andIndexMask, ACCESS

	; start activeNoteTable iteration loop
theDelegatOr_undelInLp
	; try to match low byte
	; elements are 2-bytes wide so WREG = index * 2
	bcf		STATUS, C, ACCESS
	rlcf	ddIndex, w, ACCESS
	movf	PLUSW_delegatedDeltas, w, ACCESS
	movwf	tmpValue, ACCESS
	bcf		STATUS, C, ACCESS
	rlcf	andIndex, w, ACCESS
	movf	PLUSW_activeNoteDeltas, w, ACCESS
	xorwf	tmpValue, w, ACCESS
	; low byte does not match so iterate to next activeNoteDeltas index
	bnz		theDelegatOr_undelNextAnd
	; low byte matches, try to match high byte
	bcf		STATUS, C, ACCESS
	rlcf	ddIndex, w, ACCESS
	addlw	1
	movf	PLUSW_delegatedDeltas, w, ACCESS
	movwf	tmpValue, ACCESS
	bcf		STATUS, C, ACCESS
	rlcf	andIndex, w, ACCESS
	addlw	1
	movf	PLUSW_activeNoteDeltas, w, ACCESS
	xorwf	tmpValue, w, ACCESS
	; elements do not match so iterate to next activeNoteDeltas index
	bnz		theDelegatOr_undelNextAnd

	; nonZero element in delegatedDeltas matches an element in activeNoteDeltas
	; set activeNoteDelta and delegatedDelta locked flags
	movf	ddIndexMask, w, ACCESS
	iorwf	ddLockedFlags, f, ACCESS	
	movf	andIndexMask, w, ACCESS
	iorwf	andLockedFlags, f, ACCESS	

	; if it's releasing then reattack
	movf	ddIndex, w, ACCESS
	; macro returns boolean value in WREG and also sets ZERO flag accordingly
	OSC_READ_ADSR_FLAG release
	; don't reattack if it's not releasing
	bz		theDelegatOr_undelNextDD
	; oscillator is releasing so reattack
	movf	ddIndex, w, ACCESS
	call	oscAdsrTriggerAttack
	
	bra		theDelegatOr_undelNextDD	
	
theDelegatOr_undelNextAnd
	; current activeNoteDelta does not match current delegatedDelta so iterate to next
	; increment activeNoteDeltas index mask value
	bcf		STATUS, C, ACCESS
	rlcf	andIndexMask, f, ACCESS
	; increment activeNoteDeltas index
	incf	andIndex, f, ACCESS
	; we're done if andIndex == MAX_POLY_DEPTH
	movf	andIndex, w, ACCESS
	xorlw	MAX_POLY_DEPTH
	; still have more activeNoteDelta elements to check for match so keep going
	bnz		theDelegatOr_undelInLp

theDelegatOr_undelAndLoopDone
	; done trying to match delegatedDeltas[ddIndex] to activeNoteDeltas[0 - polyDepth]
	; did not find a match (any match would've branched to theDelegatOr_undelNextDD)

	; delatedDeltas[ddIndex] is nonZero and has no match in activeNoteDeltas[0…polyDepth-1] so kill it with adsr-release	
	; set the release flag
	movf	ddIndex, w, ACCESS
	call	oscAdsrTriggerRelease

	; check next delegatedDelta
theDelegatOr_undelNextDD
	bcf		STATUS, C, ACCESS
	rlcf	ddIndexMask, f, ACCESS
	incf	ddIndex, f, ACCESS
	movf	ddIndex, w, ACCESS
	xorlw	MAX_POLY_DEPTH
	bnz		theDelegatOr_undelOutLp
		

	;**** start procedure: delegate any unlocked activeNoteDeltas to a free oscillator ****	
	; this procedure is reversed from the previous in that it tries to match an unmatch activeNoteDelta to
	; the first available unmatched oscillator
	
	; reset activeNoteDelta index count
	clrf	andIndex, ACCESS
	; reset activeNoteDelta index mask
	movlw	1
	movwf	andIndexMask, ACCESS
theDelegatOr_delOutLp
	; ignore activeNoteDelta if it's locked
	movf	andIndexMask, w, ACCESS
	andwf	andLockedFlags, w, ACCESS
	bnz		theDelegatOr_delOutLpNext
	
	; only attempt match if activeNoteDelta != 0x0000
	; WREG = ddIndex * 2
	bcf		STATUS, C, ACCESS
	rlcf	andIndex, w, ACCESS
	movf	PLUSW_activeNoteDeltas, f, ACCESS
	bnz		theDelegatOr_andNotZero
	addlw	1
	movf	PLUSW_activeNoteDeltas, f, ACCESS
	bz		theDelegatOr_delOutLpNext

theDelegatOr_andNotZero			
	; if possible, we want to leave releasing oscillators alone and assign unmatch activeNoteDeltas to a completely
	; idle oscillator.  If no idle oscillator is found then force assignment to a releasing oscillator
	; ddLockedFlags bit 7 == 0 for available
	; ddLockedFlags bit 7 == 1 for force assign to releasing	
	bcf		ddLockedFlags, 7, ACCESS

theDelegatOr_delInLpInit
	; found unmatched activeNoteDelta, so assign to first available oscillator's delegatedDelta
	; reset delegatedDeltas index count
	clrf	ddIndex, ACCESS
	; reset delegatedDeltas index mask
	movlw	1
	movwf	ddIndexMask, ACCESS

theDelegatOr_delInLp
	; WREG = ddIndex * 2
	bcf		STATUS, C, ACCESS
	rlcf	ddIndex, w, ACCESS

	; IF YOU"RE GONNA HIJACK a releasing osc then maybe choose the one that the most released?
	
	; check if we're still looking for idle oscillators or forcing assignment to a releasing osc
	btfsc	ddLockedFlags, 7, ACCESS
	bra		theDelegatOr_delInLpForceAssign

	; check low byte for zero
	movf	PLUSW_delegatedDeltas, f, ACCESS
	bnz		theDelegatOr_delInLpNext
	; check high byte for zero
	addlw	1
	movf	PLUSW_delegatedDeltas, f, ACCESS
	bnz		theDelegatOr_delInLpNext
	; found idle oscillator so assign it
	bra		theDelegatOr_delInLpAssignOsc
	
theDelegatOr_delInLpForceAssign
	; if oscillator is not locked then it may be releasing so force assignment
	movf	ddIndexMask, w, ACCESS
	andwf	ddLockedFlags, w, ACCESS
	; oscillator is locked so don't touch it
	bnz		theDelegatOr_delInLpNext

theDelegatOr_delInLpAssignOsc
	; found suitable oscillator, ignore if locked for sustain
	movf	ddIndexMask, w, ACCESS
	andwf	sustainFlags, w, ACCESS
	; oscillator is locked for sustain so consider it ineligible
	bnz		theDelegatOr_delInLpNext

	; oscillator is not locked for sustain so do delegatedDeltas[ddIndex] = activeNoteDeltas[andIndex]
	; copy low byte
	bcf		STATUS, C, ACCESS
	rlcf	andIndex, w, ACCESS
	movf	PLUSW_activeNoteDeltas, w, ACCESS
	movwf	tmpValue, ACCESS
	bcf		STATUS, C, ACCESS
	rlcf	ddIndex, w, ACCESS
	movff	tmpValue, PLUSW_delegatedDeltas
	; copy high byte
	bcf		STATUS, C, ACCESS
	rlcf	andIndex, w, ACCESS
	addlw	1
	movf	PLUSW_activeNoteDeltas, w, ACCESS
	movwf	tmpValue, ACCESS
	bcf		STATUS, C, ACCESS
	rlcf	ddIndex, w, ACCESS
	addlw	1
	movff	tmpValue, PLUSW_delegatedDeltas

	; oscillator is starting up so set attack flag
	movf	ddIndex, w, ACCESS
	call	oscAdsrTriggerAttack
	
	; skip to next unlocked activeNoteDelta
	bra		theDelegatOr_delOutLpNext
	
theDelegatOr_delInLpNext
	bcf		STATUS, C, ACCESS
	rlcf	ddIndexMask, f, ACCESS
	incf	ddIndex, f, ACCESS
	movf	ddIndex, w, ACCESS
	xorlw	MAX_POLY_DEPTH
	bnz		theDelegatOr_delInLp
	
	; toggle idle/forceOnReleasing flag if necessary
	btfsc	ddLockedFlags, 7, ACCESS
	; just completed force on releasing cycle so continue
	bra		theDelegatOr_delOutLpNext
	; just complete idle assign loop so toggle to force
	bsf		ddLockedFlags, 7, ACCESS
	; go try to find a releasing oscillator to snag
	bra		theDelegatOr_delInLpInit

theDelegatOr_delOutLpNext
	bcf		STATUS, C, ACCESS
	rlcf	andIndexMask, f, ACCESS
	incf	andIndex, f, ACCESS
	movf	andIndex, w, ACCESS
	xorlw	MAX_POLY_DEPTH
	bnz		theDelegatOr_delOutLp
	
	bra		theDelegatOr_done

theDelgatOr_doMono
	; kill adsr for monophonic mode
	clrf	adsrLimiterRegs + 0, ACCESS
	movff	activeNoteDeltas + 0, delegatedDeltas + 0	
	movff	activeNoteDeltas + 1, delegatedDeltas + 1
	clrf	delegatedDeltas + 2
	clrf	delegatedDeltas + 3
	clrf	delegatedDeltas + 4
	clrf	delegatedDeltas + 5
	clrf	delegatedDeltas + 6
	clrf	delegatedDeltas + 7

theDelegatOr_done
	; clear flag to indicate to oscillators that delegatedDeltas are no longer volatile
	bcf		soundGenFlags, delegatorBusy, ACCESS

	POP_R	FSR1H
	POP_R	FSR1L
	POP_R	FSR0H
	POP_R	FSR0L
	POP_R	r6
	POP_R	r5
	POP_R	r4
	POP_R	r3
	POP_R	r2
	POP_R	r1
	POP_R	r0
	
	#undefine	ddLockedFlags
	#undefine	ddIndex
	#undefine	ddIndexMask
	#undefine	andIndex
	#undefine	andIndexMask
	#undefine	tmpValue
	#undefine	andLockedFlags
	#undefine	FSR_activeNoteDeltas
	#undefine	PLUSW_activeNoteDeltas
	#undefine	FSR_delegatedDeltas
	#undefine	PLUSW_delegatedDeltas

	return


	; ***********************************************************************
	; Function: void processSoundState(void)
	; ***********************************************************************
processSoundState
	; push working regs onto software stack
	PUSH_R	FSR0L
	PUSH_R	FSR0H
	PUSH_R	FSR1L
	PUSH_R	FSR1H
	PUSH_R	TBLPTRL
	PUSH_R	TBLPTRH
	PUSH_R	TBLPTRU
	PUSH_R	TABLAT
	PUSH_R	PRODL
	PUSH_R	PRODH
	; Define FSR(s) for recording, playback pointers will be redefined as needed
	#define	FSR_sampleDataBuffer		FSR0
	#define	PLUSW_sampleDataBuffer		PLUSW0	

	; load fsr
	lfsr	FSR_sampleDataBuffer, sampleDataBuffer

	;**** start procedure: sample audio if mode is VOICE_THROUGH or RECORD ****
	movlw	VOICE_THROUGH
	xorwf	recordOrPlayback, w, ACCESS
	bz		processSoundState_StartADC
	movlw	RECORD
	xorwf	recordOrPlayback, w, ACCESS
	bz		processSoundState_StartADC
	goto	processSoundState_Playback	

	;**** start procedure: sample audio ****
processSoundState_StartADC
	; start ADC conversion
	bsf		ADCON0, GO, ACCESS
	; wait for conversion to finish
processSoundState_ADCWait
	btfsc	ADCON0, DONE, ACCESS
	bra		processSoundState_ADCWait
		
	; sample complete, save ADC value
	movf	ADRESH, w, ACCESS
	; add op-amp DC OFFSET
	; REMEBER that DC-OFFSET will be affected by component tolerances so measure each circuit!
	addlw	SAMPLE_DC_OFFSET 
	; if overflow then clip at 0xff
	btfsc	STATUS, C, ACCESS
	movlw 0xff
	; save value
	movwf	sample, ACCESS
		
; DEBUG - sample mix
	; amplify incoming sample volume by 3
	movlw	PWM_IDLE_OUTPUT_VALUE
	subwf	sample, w, ACCESS
	bnc		processSoundState_sampAmpNeg
	; result was positive so increase value
	bcf		STATUS, C, ACCESS
	rlcf	WREG, w, ACCESS
	addwf	sample, w, ACCESS
	; if overflow then clip at 0xff
	btfsc	STATUS, C, ACCESS
	movlw 0xff
	bra		processSoundState_sampAmpExit
processSoundState_sampAmpNeg
	; result was negative so decrease value
	; invert difference so it's positive
	negf	WREG, ACCESS
	bcf		STATUS, C, ACCESS
	rlcf	WREG, w, ACCESS
	subwf	sample, w, ACCESS
	; if overflow then clip at 0x00
	btfss	STATUS, C, ACCESS
	movlw	0
processSoundState_sampAmpExit
	movwf	sample, ACCESS

	; write sample value to PWM for immediate playback
	; /4 and add (PWM_IDLE_OUTPUT_VALUE/4 * 3) to simulate final single voice sound mix
  bcf		STATUS, C, ACCESS
	rrcf	sample, w, ACCESS
  bcf		STATUS, C, ACCESS
	rrcf	WREG, w, ACCESS
	addlw	PWM_IDLE_OUTPUT_VALUE/4 * 3
	movwf	CCPR1L, ACCESS
  		
	;**** start procedure: should we be recording this? ****
	; has RECORD button been released?
#ifndef	__DEBUG
	; if debugging then assume that button has been released and we want to record
	btfss	PORTC, RC1, ACCESS
	; RECORD button is still depressed so don't record
	goto	processSoundState_exit
#endif

	; RECORD button has been released
	
	; is waveShape == SAMPLE?
	movlw	SAMPLE
	cpfseq	waveShape, ACCESS
	; waveShape is != SAMPLE so don't record
	goto	processSoundState_cancelVoiceThru
	bra		processSoundState_recordGo

	; waveShape != SAMPLE so cancel VOICE_THROUGH and return to PLAYBACK
processSoundState_cancelVoiceThru
	movlw	PLAYBACK
	movwf	recordOrPlayback, ACCESS
	movlw	PWM_IDLE_OUTPUT_VALUE
	movwf	CCPR1L, ACCESS
	goto	processSoundState_exit

	;**********************************************************************
	; Record Begin

processSoundState_recordGo
	;**** start procedure: record sample ****

	; don't start recording until recordWaitCountdown == 0x00
	; recordWaitCountdown value is set by INT1 (record button) ISR
	movf	recordWaitCountdown, f, ACCESS
	bz		processSoundState_recordGoForRealz
	decf	recordWaitCountdown, f, ACCESS
	goto	processSoundState_exit

processSoundState_recordGoForRealz

	; update recordOrPlayback state to RECORD
	movlw	RECORD
	movwf	recordOrPlayback, ACCESS

	;**** start procedure: write sample into data buffer ****
	; sampleDataBuffer[sampleDataBufferIndex] = sample
	movf	sampleDataBufferIndex, w, ACCESS
	movff	sample, PLUSW_sampleDataBuffer
	
	; increment index
	incf	sampleDataBufferIndex, f, ACCESS

	; check buffer capacity
	; buffer is full if sampleDataBufferIndex is == SAMPLE_DATA_BUFFER_SIZE
	movlw	SAMPLE_DATA_BUFFER_SIZE
	cpfseq	sampleDataBufferIndex, ACCESS
	; buffer is not full, our work here is done
	bra		processSoundState_exit

	; reset sampleDataBufferIndex to 0x0
	clrf	sampleDataBufferIndex, ACCESS
	; set sampleChunkReady flag to indicate that sample buffer is ready for EEPEROM write
	bsf		eepromFlags, sampleChunkReady, ACCESS
	; sampleChunkCount indicates how many times the sample buffer has been filled, increment it
	incf	sampleChunkCount, f, ACCESS

	; buffer is full and ready for writing

	; not using 'sample' to hold sample data anymore so change variable alias to 'tmpValue'
	#define		tmpValue	sample
	
	; MOVED THIS TO MAINLINE WHICH WAITS FOR SAMPLECHUNKREADY TO BE SET
	; write sampleDataBuffer to EEPROM. Call takes 548uS @ 16MHz clock and 4MHz SPI clock
;	call	eepromWrite64
	; sample chunk has been written so clear sampleChunkReadyFlag
;	bcf		eepromFlags, sampleChunkReady, ACCESS

	;**** start procedure: should we stop recording? ****
	; if EEPROM is full then stop recording
	movlw	((EEPROM_SIZE_BITS/8) / SAMPLE_DATA_BUFFER_SIZE)
	xorwf	sampleChunkCount, w, ACCESS
	btfsc	STATUS, Z, ACCESS
	bra		processSoundState_stopRecording

	; if turnSoundOn or keyPressed is set then stop recording
	; either flag being set indicates that a new Note On message has been received since record start
	; this allows for using MIDI Note On message to set sample length
	btfsc	midiFlags, turnSoundOn, ACCESS
	bra		processSoundState_stopRecording
	btfss	midiFlags, keyPressed, ACCESS

	; EEPROM is not full and no Note On has been received since record start so keep recording, exit ISR
	goto	processSoundState_exit

	;**** start procedure: stop recording ****
processSoundState_stopRecording
	; set mode back to Playback
	movlw	PLAYBACK
	movwf	recordOrPlayback, ACCESS

	; leave PWM output at PWM_IDLE_OUTPUT_VALUE
	movlw	PWM_IDLE_OUTPUT_VALUE
	movwf	CCPR1L, ACCESS
	
	; use sampleChunkCount to calculate EEPROM end address
	; sampleEndAddress = (sampleChunkCount * SAMPLE_DATA_BUFFER_SIZE) - 1
	movlw	SAMPLE_DATA_BUFFER_SIZE
	mulwf	sampleChunkCount, ACCESS
	movlw	1
	subwf	PRODL, f, ACCESS
	btfss	STATUS, C, ACCESS
	decf	PRODH, f, ACCESS

	; save sample end address to RAM for immediate playback
	movff	PRODL, sampleEndAddress
	movff	PRODH, sampleEndAddress + 1

	; save sample end address to on-chip EEPROM
	; during power-up device init, initExternalEeprom() reads on-chip EEPROM address into RAM variable sampleEndAddress
	; write address low byte
	WRITE_INTERNAL_EEPROM	0, sampleEndAddress
	; write address high byte
	WRITE_INTERNAL_EEPROM	1, (sampleEndAddress + 1)

	; reset accumulators for good measure
	CLEAR_ACCUMULATORS

	; fixes bug if key was held during record start
	bcf		midiFlags, turnSoundOff, ACCESS

	bra		processSoundState_exit

	; undefine local FSRs
	#undefine	FSR_sampleDataBuffer
	#undefine	PLUSW_sampleDataBuffer

	;**********************************************************************
	; Playback Begin

processSoundState_Playback	
	;**** start procedure: playback waveform or sample ****

	; not using 'tmpValue' to hold anymore so change variable alias to 'count'
	#undefine	tmpValue
	#define		count	sample
		
	;**** start procedure: should we make any noise? ****
	; if soundOn is set then continue to generate sound
	btfsc	midiFlags, soundOn, ACCESS
	bra		processSoundState_SoundOn

	; if turnSoundOn is set then start generating sound
	btfss	midiFlags, turnSoundOn, ACCESS
	; neither is set so reset sound gen state and exit ISR
;	bra		processSoundState_reset
	bra		processSoundState_SoundOn
	; request has been made for sound to turn on so do it
	bcf		midiFlags, turnSoundOn, ACCESS
	bsf		midiFlags, soundOn, ACCESS
	; for SAMPLE mode, clear the samplesLoaded flag to tell the mainline that you need a new sample
	bcf		eepromFlags, samplesLoaded, ACCESS
	
	;**** start procedure: make some noise ****
processSoundState_SoundOn
	;**** start procedure: update oscillator states ****
	; if waveShape is == SINE or SQUARE then macro will update oscillator's activeOutputValue register
	; if waveShape is == SAMPLE and samplesLoaded flag is set then macro will clear flag and load nextSampleAddress register
	OSC_STATE_BLOCK 0
	OSC_STATE_BLOCK 1
	OSC_STATE_BLOCK 2
	OSC_STATE_BLOCK 3
	
	; keyPressed is handled in OSC_STATE_BLOCK macro so clear flag
	; if(samplesLoaded && waveShape == SAMPLE){keyPressed = FALSE;}
	; else{keyPressed = FALSE;}
	movlw	SAMPLE
	xorwf	waveShape, w, ACCESS
	; if waveShape != SAMPLE then clear keyPressed flag
	bnz		processSoundState_clearTransFlag
	; waveShape is == SAMPLE so only clear keyPressed if samplesLoaded == TRUE
	btfsc	eepromFlags, samplesLoaded, ACCESS
processSoundState_clearTransFlag
	bcf		midiFlags, keyPressed, ACCESS

	; samplesLoaded is handled in OSC_STATE_BLOCK macro so clear if set
	bcf		eepromFlags, samplesLoaded, ACCESS

	;**** start procedure: send data to PWM ****
processSoundState_mixer
	; **** averaging signal mixer ****	
	; average all active output values into mixedOutput		
	; init mixedOutput
	clrf	mixedOutputL, ACCESS
	clrf	mixedOutputH, ACCESS

	; mix OSC0
	OSC_MIX 0	
	
	; mix OSC1
	OSC_MIX 1
	
	; mix OSC2
	OSC_MIX 2
	
	; mix OSC3
	OSC_MIX 3
		
	; do (mixedOutput /= 4) to evenly mix all oscillators
	bcf		STATUS, C, ACCESS
	rrcf	mixedOutputH, f, ACCESS
	rrcf	mixedOutputL, f, ACCESS
	bcf		STATUS, C, ACCESS
	rrcf	mixedOutputH, f, ACCESS
	rrcf	mixedOutputL, f, ACCESS

	; send final mixed signal to PWM!
	movff	mixedOutputL, CCPR1L

processSoundState_soundOnDone
	
processSoundState_exit
	; push working regs onto software stack
	POP_R	PRODH
	POP_R	PRODL
	POP_R	TABLAT
	POP_R	TBLPTRU
	POP_R	TBLPTRH
	POP_R	TBLPTRL
	POP_R	FSR1H
	POP_R	FSR1L
	POP_R	FSR0H
	POP_R	FSR0L	

	; FSRs all undefined locally in functions
		
	return		
	

	; ***********************************************************************
	; Function: void processSoundState(void)
	; ***********************************************************************
serviceADSR	
	; test prescale counter to determine if it's time to service adsr
	; perform (adsrPrescaleCounter - ADSR_PRESCALE)
	; if result is positive, then (adsrPrescaleCounter >= ADSR_PRESCALE) == TRUE

	PUSH_R	r0
	PUSH_R	r1
	PUSH_R	r2
	PUSH_R	FSR0L
	PUSH_R	FSR0H

	#define	oscNumber r0
	#define	oscNumberMask r1
	#define tmpValue r2
		
	; do subtract
	movlw	low(ADSR_PRESCALE)
	subwf	adsrPrescaleCounter + 0, w, ACCESS
	movlw	high(ADSR_PRESCALE)
	subwfb adsrPrescaleCounter + 1, w, ACCESS
	; if result is positive then service adsr
	btfss	STATUS, C, ACCESS	
	; result was negative so exit
	bra		serviceADSR_exit
	
	; reset adsrPrescaleCounter
	clrf	adsrPrescaleCounter + 0, ACCESS
	clrf	adsrPrescaleCounter + 1, ACCESS
	
	clrf	oscNumber, ACCESS
	movlw	1
	movwf	oscNumberMask, ACCESS
serviceADSRLoop
	; ignore advance if oscillator is sustained
	movf	oscNumberMask, w, ACCESS
	andwf	sustainFlags, w, ACCESS
	bnz		serviceADSR_oscDone
	
	lfsr	FSR0, oscStateFlags
	movf	oscNumber, w, ACCESS
	btfsc	PLUSW0, attack, ACCESS
	bra		doAttack
	btfsc	PLUSW0, release, ACCESS
	bra		doRelease
	bra		serviceADSR_oscDone
	
doAttack
	; osc is attacking

	; test condition ((adsrLimiterRegs -= ADSR_ATTACK_RATE) <=0)
	lfsr	FSR0, adsrLimiterRegs
	movf	oscNumber, w, ACCESS
	; tmpValue = (*(adsrLimiterRegs + OSC_NUMBER))
	movff	PLUSW0, tmpValue
	movf	adsrAttackRate, w, ACCESS
	subwf	tmpValue, w, ACCESS
	bnc		attackDone
	bz		attackDone

	; condition is FALSE so do the subtraction and exit
	; (adsrLimiterRegs -= ADSR_ATTACK_RATE)
	movf	oscNumber, w, ACCESS
	; tmpValue = (*(adsrLimiterRegs + OSC_NUMBER))
	movff	PLUSW0, tmpValue
	movf	adsrAttackRate, w, ACCESS
	subwf	tmpValue, f, ACCESS
	movf	oscNumber, w, ACCESS
	movff	tmpValue, PLUSW0
	bra		serviceADSR_oscDone

attackDone
	lfsr	FSR0, oscStateFlags
	movf	oscNumber, w, ACCESS
	; clear attack flag
	bcf		PLUSW0, attack, ACCESS
	lfsr	FSR0, adsrLimiterRegs
	; WREG still == oscNumber
	clrf	PLUSW0, ACCESS
	bra	serviceADSR_oscDone

doRelease
	; osc is releasing

	; test condition: ((adsrLimiterRegs + ADSR_RELEASE_RATE) >= 255)
	lfsr	FSR0, adsrLimiterRegs
	movf	oscNumber, w, ACCESS
	; tmpValue = (*(adsrLimiterRegs + OSC_NUMBER))
	movff	PLUSW0, tmpValue
	movf	adsrReleaseRate, w, ACCESS
	addwf	tmpValue, w, ACCESS
	; condition is TRUE so skip the addition and leave adsrLimiterRegs at its current value
	bc		releaseDone
	comf	WREG, w, ACCESS
	; condition is TRUE so skip the addition and leave adsrLimiterRegs at its current value
	bz		releaseDone

	; condition is FALSE so do the addition and exit
	; do (adsrLimiterRegs += ADSR_RELEASE_RATE)	
	; FSR0 still == adsrLimiterRegs
	movf	oscNumber, w, ACCESS
	; tmpValue = (*(adsrLimiterRegs + OSC_NUMBER))
	movff	PLUSW0, tmpValue
	movf	adsrReleaseRate, w, ACCESS
	addwf	tmpValue, f, ACCESS
	movf	oscNumber, w, ACCESS
	movff	tmpValue, PLUSW0	
	bra		serviceADSR_oscDone
	
releaseDone
	; clear release flag
	lfsr	FSR0, oscStateFlags
	movf	oscNumber, w, ACCESS
	bcf		PLUSW0, release, ACCESS
	; set limit reg to max
	lfsr	FSR0, adsrLimiterRegs
	; WREG still == oscNumber
	setf	PLUSW0, ACCESS
	; clear oscillator's delegatedDelta
	lfsr	FSR0, delegatedDeltas
	bcf		STATUS, C, ACCESS
	rlcf	oscNumber, w, ACCESS
	clrf	PLUSW0;
	addlw	1
	clrf	PLUSW0;	

serviceADSR_oscDone
	; increment oscNumber mask
	bcf		STATUS, C, ACCESS
	rlcf	oscNumberMask, f, ACCESS
	; increment oscNumber and check if done
	incf	oscNumber, f, ACCESS
	movf	polyDepth, w, ACCESS
	cpfseq oscNumber, ACCESS
	; not done so continue
	bra		serviceADSRLoop

serviceADSR_exit
	#undefine	oscNumber
	#undefine	oscNumberMask
	#undefine	tmpValue

	POP_R	FSR0H
	POP_R	FSR0L
	POP_R	r2
	POP_R	r1
	POP_R	r0

	return

	; ***********************************************************************
	; Function: void oscAdsrTriggerAttack(void)
	; ***********************************************************************
	; This function is called only by theDelegator() for one of the following reasons:
	; - An activeNoteDeltas element has just been assigned to an oscillator that satisfies one of the following conditions:
	;   -- The oscillator's delegatedDelta value == 0 and has no match in activeNoteDeltas[] (oscillator is idle)
	;   -- The oscillator's delegatedDelta value does not match any element in activeNoteDeltas (may be releasing)
	; - An oscillator's delegatedDelta matches an element in activeNoteDeltas, and the oscillator is releasing
	;
oscAdsrTriggerAttack
; oscillator number passed in WREG

	; push working regs onto software stack
	PUSH_R	r0
	PUSH_R	FSR0L
	PUSH_R	FSR0H
	
	; r0 = oscillator #
	movwf		r0, ACCESS
	
	; load fsr to first deal with adsrLimiterRegs
	lfsr	FSR0, adsrLimiterRegs

	; if adsrAttackRate == 64 then attack is disabled
	movlw		64
	cpfseq	adsrAttackRate, ACCESS
	bra			oscAdsrTriggerAttackActive

	; ADSR IS DISABLED
	; WREG = oscillator #
	movf	r0, w, ACCESS
	; clear limiterReg to ensure that waveform amplitude is not attenuated
	clrf	PLUSW0, ACCESS
	; load fsr to modify adsr flags
	lfsr	FSR0, oscStateFlags
	; clear attack flag
	bcf	PLUSW0, attack, ACCESS	
	; clear attack flag
	bcf	PLUSW0, release, ACCESS	

	bra		oscAdsrTriggerAttackExit
	
	; ADSR IS ACTIVE
oscAdsrTriggerAttackActive
	; if release is disabled, set limiterReg to start with full-attenuation of waveform amplitude
	; otherwise, leave it alone to reduce reattack popping
	movlw	64
	xorwf	adsrReleaseRate, w, ACCESS
	bnz		oscAdsrTriggerAttackNoReAttack
	; set adsrLimiterReg to 0xff on attack if releaseRate == 64 (releaseTime == 0)
	; WREG = oscillator #
	movf	r0, w, ACCESS
	setf	PLUSW0, ACCESS

oscAdsrTriggerAttackNoReAttack

	; load fsr to modify adsr flags
	lfsr	FSR0, oscStateFlags
	; WREG = oscillator #
	movf	r0, w, ACCESS
	; set attack flag
	bsf	PLUSW0, attack, ACCESS
	; clear release flag
	bcf	PLUSW0, release, ACCESS
		
oscAdsrTriggerAttackExit
	; restore working regs from stack
	POP_R	FSR0H
	POP_R	FSR0L
	POP_R	r0
	
	return
	

	; ***********************************************************************
	; Function: void oscAdsrTriggerRelease(void)
	; ***********************************************************************
	; This function is called only by theDelegator() for the following reason:
	; - An oscillator's delegatedDelta != 0 and does not match any element in activeNoteDeltas
	; Note, that theDelegator does not currently check whether the oscillator is already releasing before call
oscAdsrTriggerRelease
; oscillator number passed in WREG

	; push working regs onto software stack
	PUSH_R	r0
	PUSH_R	FSR0L
	PUSH_R	FSR0H
	
	; r0 = oscillator #
	movwf		r0, ACCESS

	; if adsrReleaseRate == 64 then leave limiterReg where it is and clear delegatedDeltas to signal stop to delegator
	movlw	64
	; if adsrReleaseRate == 64 then release is disabled
	cpfseq	adsrReleaseRate, ACCESS
	bra		oscAdsrTriggerReleaseActive

	; RELEASE IS DISABLED
	; load fsr to modify adsr flag
	lfsr	FSR0, oscStateFlags
	; WREG = oscillator #
	movf	r0, w, ACCESS
	; clear release flag
	bcf	PLUSW0, release, ACCESS
	; clear attack flag
	bcf	PLUSW0, attack, ACCESS

	; clear oscillator's delegatedDelta
	; load fsr with base address of delegatedDeltas array
	lfsr	FSR0, delegatedDeltas
	; add oscillator offset to fsr
	; delegatedDeltas are two-bytes wide so WREG = r0*2
	bcf	STATUS, C, ACCESS
	rlcf	r0, w, ACCESS
	; add offset to low byte of FSR
	addwf FSR0L, f, ACCESS
	; increment high byte of FSR if CARRY is set
	btfsc	STATUS, C, ACCESS
	incf	FSR0H, f, ACCESS
	; clear low byte
	clrf	POSTINC0, ACCESS
	; clear high byte
	clrf	INDF0, ACCESS

	bra		oscAdsrTriggerReleaseExit
	
	; RELEASE IS ACTIVE
oscAdsrTriggerReleaseActive
	; load fsr to modify adsr flag
	lfsr	FSR0, oscStateFlags
	; WREG = oscillator #
	movf	r0, w, ACCESS
	; set release flag
	bsf	PLUSW0, release, ACCESS
	; clear attack flag
	bcf	PLUSW0, attack, ACCESS
		
oscAdsrTriggerReleaseExit
	; restore working regs from stack
	POP_R	FSR0H
	POP_R	FSR0L
	POP_R	r0

	return
