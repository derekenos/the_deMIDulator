
;**********************************************************************
;                                                                     *
;    Project:       deMIDulator                                       *
;    Filename:	    midi.asm                                          *
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
	
;**********************************************************************
; LOCAL VARIABLES
;**********************************************************************

	CBLOCK

		midiState_lastStatus:1
		midiState_lastLength:1
		uartState_currentRxIndex:1
		midiRxMessage_length:1
		midiLastProgramValue:1
			
		midiFlags:1
		; Bits defined in midi.h
		; #define uartState_rxInProgress		0
		; #define midiState_messageNeedsMapping	1
		; #define midiThroughMode_enabled		2
		; Bits 3:7 free for use by other modules

		; Declared at end of main.asm to ensure that arrays are pushed to end of memory...
		; with smaller variables in ACCESS memory
		; ---------------------------------------
		; midiRxMessage:MAX_MIDI_MESSAGE_SIZE
		; activeNoteTable:ACTIVE_NOTE_TABLE_SIZE
				
	ENDC
			
;**********************************************************************
; LOCAL FUNCTIONS
;**********************************************************************

; [Function Summary]
;
; Function: initMIDI()
; Abstract: initializes MIDI state variables and flags

; Function: processRxAsMIDI()
; Abstract: reads rx byte from UART's RCREG and processes as incoming MIDI transaction
;           calls midiMessageMapper() when last byte of complete MIDI message has been received

; Function: midiMessageMapper()
; Abstract: determines type of received MIDI message and reacts
;           received Note On triggers call to activeNoteTableAdd()
;			received Note Off triggers call to activeNoteTableRemove()
;			received Pitch Wheel value is saved to variable pitchWheel


;**********************************************************************
; Function: void midiDebugTriggerHandler()
;**********************************************************************
; since the PIC18LF13K50 doesn't contain debugging hardware,
; I'm using this routine as a crude way to dump memory contents via MIDI output
; this code will only be include if MIDI_DEBUG_TRIGGER_ENABLED is #define(d)

#IFDEF MIDI_DEBUG_TRIGGER_ENABLED
midiDebugTriggerHandler
	PUSH_R	r0
	PUSH_R	FSR0L
	PUSH_R	FSR0H
	
	#define	byteCount r0

	; dump activeNoteTable
	; start SysEx message
	movlw	SYSEX
	call	midiDebugTriggerHandler_SendByte
	; init
	lfsr	FSR0, activeNoteTable
	movlw	ACTIVE_NOTE_TABLE_SIZE
	movwf	byteCount, ACCESS
midiDebugTriggerHandler_antLp
	movf	byteCount, w, ACCESS
	sublw	ACTIVE_NOTE_TABLE_SIZE
	movf	PLUSW0, w, ACCESS
	; empty activeNoteTable entry == 0xff which is not cool to send inside SysEx so compliment
	; add 1 to WREG, if result is ZERO then value was 0xff so just send 0 value to port
	addlw	1
	btfss	STATUS, Z, ACCESS
	; result was not ZERO so value was not 0xff. subtract 1 to restore original value
	sublw	1
	call	midiDebugTriggerHandler_SendByte
	decf	byteCount, f, ACCESS
	bnz		midiDebugTriggerHandler_antLp
	; close SysEx message
	movlw	EOX
	call	midiDebugTriggerHandler_SendByte

	; dump activeNoteDeltas
	; start SysEx message
	movlw	SYSEX
	call	midiDebugTriggerHandler_SendByte
	; init
	lfsr	FSR0, activeNoteDeltas
	movlw	ACTIVE_NOTE_DELTAS_SIZE
	movwf	byteCount, ACCESS
midiDebugTriggerHandler_andLp
	movf	byteCount, w, ACCESS
	sublw	ACTIVE_NOTE_TABLE_SIZE
	movf	PLUSW0, w, ACCESS
	; activeNoteDeltas values are not SysEx friendly su just clear bit7 no matter what
	andlw	0x7f
	call	midiDebugTriggerHandler_SendByte
	decf	byteCount, f, ACCESS
	bnz		midiDebugTriggerHandler_andLp
	; close SysEx message
	movlw	EOX
	call	midiDebugTriggerHandler_SendByte

	#undefine	byteCount

	POP_R	FSR0H
	POP_R	FSR0L
	POP_R	r0

	return


midiDebugTriggerHandler_SendByte
	; skip if TXREG is ready for writting
	btfss	PIR1, TXIF, ACCESS
	; not ready so keep checking
	goto	midiDebugTriggerHandler_SendByte
	; is ready so write it
	movwf TXREG, ACCESS
	return
#ENDIF

;**********************************************************************
; Function: void initMIDI(void)
;**********************************************************************

initMIDI
	; push working regs onto software stack
	PUSH_R	r0
	PUSH_R	FSR0L
	PUSH_R	FSR0H
	; define variables to pushed registers
	#define	count					r0
	#define FSR_activeNoteTable		FSR0
	#define POSTINC_activeNoteTable	POSTINC0
		
	; load fsr
	lfsr	FSR_activeNoteTable, activeNoteTable	
	
	clrf	midiState_lastStatus, ACCESS
	clrf	midiState_lastLength, ACCESS
	clrf	uartState_currentRxIndex, ACCESS
	clrf	midiRxMessage_length, ACCESS
	clrf	midiLastProgramValue, ACCESS
						
	bcf		midiFlags, uartState_rxInProgress, ACCESS		
	bcf		midiFlags, midiState_messageNeedsMapping, ACCESS
	; enable MIDI THRU mode
	bsf		midiFlags, midiThruModeEnabled, ACCESS	

	movlw	ACTIVE_NOTE_TABLE_SIZE
	movwf	count, ACCESS
	movlw	0xff
initMIDI_lp	
	movwf	POSTINC_activeNoteTable, ACCESS
	decfsz	count, f, ACCESS
	bra		initMIDI_lp
		
	; undefine variables from pushed registers
	#undefine count
	#undefine FSR_activeNoteTable
	#undefine POSTINC_activeNoteTable
	; pop working regs from software stack
	POP_R	FSR0H
	POP_R	FSR0L
	POP_R	r0

	return


;**********************************************************************
; Function: void processRxAsMIDI(RCREG)
;**********************************************************************

processRxAsMIDI
	; push working regs onto software stack
	PUSH_R	r0
	PUSH_R	r1
	PUSH_R	FSR0L
	PUSH_R	FSR0H
	; define variables to pushed registers
	#define	rxByte				r0
	#define	tmpValue			r1	
	#define	FSR_midiRxMessage	FSR0
	#define	PLUSW_midiRxMessage	PLUSW0

	; init FSR
	lfsr	FSR_midiRxMessage, midiRxMessage
	
	;**** start procedure: read UART RX byte and check error states ****
processRxAsMIDI_readFIFO
	; skip if framing error occurred for top unread char in rx FIFO
	btfss	RCSTA, FERR, ACCESS
	; no framing error so read the character
	bra		processRxAsMIDI_readGO
	; framing error occurred
	; read incorrectly framed character out of FIFO
	movf	RCREG, w, ACCESS
	; skip if rx FIFO is empty
	btfsc	PIR1, RCIF, ACCESS
	; FIFO is not empty so try next character
	bra		processRxAsMIDI_readFIFO
	; all characters in FIFO were incorrectly framed, no data to process
	; attempt to remedy: reset UART receiver by toggling Continous Receive Enable bit
	bcf		RCSTA, CREN, ACCESS
	bsf		RCSTA, CREN, ACCESS
	; exit ISR
	goto	processRxAsMIDI_Exit
	
processRxAsMIDI_readGO
	; save RX byte / clear RCIF
	movff	RCREG, rxByte

	; if MIDI THRU mode is enabled then write byte to UART output
	btfsc	midiFlags, midiThruModeEnabled, ACCESS
	movff	rxByte, TXREG

	; check for rx buffer overrun
	; skip if buffer overrun occurred
	btfss	RCSTA, OERR, ACCESS
	bra		processRxAsMIDI_noErrors
	; reset UART receiver by toggling Continous Receive Enable bit
	bcf		RCSTA, CREN, ACCESS
	bsf		RCSTA, CREN, ACCESS

processRxAsMIDI_noErrors

	; **** Notes About MIDI Message Handling Implementation ****
	; 1. Only the following MIDI message types are currently supported:
	;    * 1000nnnn : Note Off
	;    * 1001nnnn : Note On
	;    * 1011nnnn : Control Change
	;    * 1100nnnn : Program Change
	;    * 1110nnnn : Pitch Wheel
	;    * 11110000 : System Exclusive
	;    * 11111111 : Reset
	; 2. Status values above SysEx (0xF0) are not currently supported
	;    Unsupported common messages include:
	;    * 11110001 : MIDI Time Code Quarter Frame
	;    * 11110010 : Song Position Pointer
	;    * 11110011 : Song Select
	;    * 11110110 : Tune Request
	;    * 11111000 : Timing Clock
	;    * 11111010 : Start
	;    * 11111011 : Continue
	;    * 11111100 : Stop
	;    * 11111110 : Active Sense
	
	;**** start procedure: is STATUS? ****
	; if bit 7 is set then received byte is STATUS
	btfss	rxByte, 7, ACCESS
	bra		processRxAsMIDI_notStatusOrIsEOX
	; ignore > SysEx (0xF0) values as STATUS but continue to process as non-STATUS to capture EOX
	; 
	movlw	SYSEX
	; compare f with W, skip if f > W
	cpfsgt	rxByte, ACCESS
	bra		processRxAsMIDI_getLength
	bra		processRxAsMIDI_notStatusOrIsEOX

	;**** start procedure: get message length ****
processRxAsMIDI_getLength
	; midiRxMessage_length = length of MIDI message type
	; midiRxMessage_length of 0x0 is used to indicate unsupported message types
	clrf	midiRxMessage_length, ACCESS
	
	; mask out channel data and save in tmpValue
	movf	rxByte, w, ACCESS
	andlw	0xF0
	movwf	tmpValue, ACCESS
	
	; Check if STATUS is a 2-byte message type
	; case PROGRAM_CHANGE
	movlw	PROGRAM_CHANGE
	xorwf	tmpValue, w, ACCESS
	bz		processRxAsMIDI_lengthIs2
	; case CHANNEL_PRESSURE
	movlw	CHANNEL_PRESSURE
	xorwf	tmpValue, w, ACCESS
	bz		processRxAsMIDI_lengthIs2
	bra		processRxAsMIDI_lengthIsNot2
processRxAsMIDI_lengthIs2
	; midiRxMessage_length = 2
	movlw	2
	movwf	midiRxMessage_length, ACCESS	
	bra		processRxAsMIDI_getLengthDone
processRxAsMIDI_lengthIsNot2

	; Check if STATUS is a 3-byte message type
	; case NOTE_OFF
	movlw	NOTE_OFF
	xorwf	tmpValue, w, ACCESS
	bz		processRxAsMIDI_lengthIs3		
	; case NOTE_ON
	movlw	NOTE_ON
	xorwf	tmpValue, w, ACCESS
	bz		processRxAsMIDI_lengthIs3		
	; case KEY_PRESSURE
	movlw	KEY_PRESSURE
	xorwf	tmpValue, w, ACCESS
	bz		processRxAsMIDI_lengthIs3		
	; case CONTROL_CHANGE
	movlw	CONTROL_CHANGE
	xorwf	tmpValue, w, ACCESS
	bz		processRxAsMIDI_lengthIs3		
	; case PITCH_WHEEL
	movlw	PITCH_WHEEL
	xorwf	tmpValue, w, ACCESS
	bz		processRxAsMIDI_lengthIs3		
	bra		processRxAsMIDI_lengthIsNot3
processRxAsMIDI_lengthIs3
	; midiRxMessage_length = 3
	movlw	3
	movwf	midiRxMessage_length, ACCESS	
	bra		processRxAsMIDI_getLengthDone
processRxAsMIDI_lengthIsNot3

	; Check if STATUS is EOX-byte message type
	; case SYSEX
	movlw	SYSEX
	xorwf	tmpValue, w, ACCESS
	bnz		processRxAsMIDI_getLengthDone
	movlw	EOX
	movwf	midiRxMessage_length, ACCESS	
processRxAsMIDI_getLengthDone
	
	;**** start procedure: supported message type? ****
	; midiRxMessage_length of 0 indicates unsupported STATUS value
	movf	midiRxMessage_length, f, ACCESS
	bz		processRxAsMIDI_resetUartState

	;**** start procedure: message supported, init uartState for reception ****
	bsf		midiFlags, uartState_rxInProgress, ACCESS
	;	midiRxMessage[0] = STATUS including channel data
	movff	rxByte, midiRxMessage
	;	uartState_currentRxIndex = 1
	movlw	1
	movwf	uartState_currentRxIndex, ACCESS
	;	midiState_lastStatus = rxdata
	movff	rxByte, midiState_lastStatus
	;	midiState_lastLength = midiRxMessage_length
	movff	midiRxMessage_length, midiState_lastLength
	bra		processRxAsMIDI_RxHandlingDone

	;**** start procedure: message unsupported, reset uartState ****
processRxAsMIDI_resetUartState
	; Fixes logic problem discovered because Axiom 25 streams aftertouch data which was being interpreted as running status Note Ons
	; Reception of an unsupported MIDI message will kill any in-progress message rx
	; uartState_rxInProgress = FALSE
	bcf		midiFlags, uartState_rxInProgress, ACCESS
	; Reset midiState.lastStatus so that subsequent non-status values are not interpreted as running status
	clrf	midiState_lastStatus, ACCESS
	bra		processRxAsMIDI_RxHandlingDone

	; process STATUS byte done
	;**********************************************************************
	; process non-STATUS or EOX byte begin

	;**** start procedure: process non-STATUS or EOX byte ****
processRxAsMIDI_notStatusOrIsEOX
	; continue if reception in progress
	btfsc	midiFlags, uartState_rxInProgress, ACCESS
	bra		processRxAsMIDI_rxInProgress

	; no reception in progress so attempt to process as running STATUS if rxByte < SYSEX, otherwise ignore
	movlw	SYSEX
	cpfslt	rxByte, ACCESS
	bra		processRxAsMIDI_RxHandlingDone
	bra		processRxAsMIDI_tryRunningStatus
	
processRxAsMIDI_rxInProgress
	; continue if byte is non-STATUS
	btfss	rxByte, 7, ACCESS
	bra		processRxAsMIDI_notStatusContinue

	; byte is STATUS, continue if EOX
	movlw	EOX
	xorwf	rxByte, w, ACCESS	
	; byte is STATUS but not EOX or any other supported STATUS value so ignore
	bnz		processRxAsMIDI_RxHandlingDone

	;**** start procedure: save incoming byte to buffer ****
processRxAsMIDI_notStatusContinue
	; check buffer capacity
	movlw	MAX_MIDI_MESSAGE_SIZE
	cpfslt	uartState_currentRxIndex, ACCESS
	; buffer is completely full with incomplete message
	; cancel current reception / reset uartState
	bra		processRxAsMIDI_resetUartState

	;	midiRxMessage[uartState_currentRxIndex] = rxdata
	movf	uartState_currentRxIndex, w, ACCESS
	movff	rxByte, PLUSW_midiRxMessage
	;	uartState_currentRxIndex++;
	incf	uartState_currentRxIndex, f, ACCESS
		
	;**** start procedure: check if message is complete ****
	; for non-SYSEX messages: message reception is complete if uartState_currentRxIndex == midiRxMessage_length
	movf	uartState_currentRxIndex, w, ACCESS
	cpfseq	midiRxMessage_length, ACCESS
	bra		processRxAsMIDI_checkEOX
	bra		processRxAsMIDI_messageComplete

	; for SYSEX messages: message reception is complete if rxByte == EOX
processRxAsMIDI_checkEOX
	movlw	EOX
	cpfseq	rxByte, ACCESS
	; message reception is not complete
	bra		processRxAsMIDI_RxHandlingDone	

	;**** start procedure: midi message reception is complete ****
processRxAsMIDI_messageComplete	
	; update midiRxMessage_length to reflect actual length of SYSEX message
	movf	uartState_currentRxIndex, w, ACCESS
	movwf	midiRxMessage_length, ACCESS

	; reset uart state
	bcf		midiFlags, uartState_rxInProgress, ACCESS
	
	; process received message
	call	midiMessageMapper
	bra		processRxAsMIDI_RxHandlingDone

	;**** start procedure: attempt to process non-STATUS byte as running STATUS ****
processRxAsMIDI_tryRunningStatus	
	; continue if midiState_lastStatus != 0
	; midiState_lastStatus is set every time supported STATUS byte is received
	; midiState_lastStatus is cleared whenever unsupported STATUS byte is received
	movf	midiState_lastStatus, f, ACCESS
	bz		processRxAsMIDI_RxHandlingDone

	;**** start procedure: is running STATUS, init uartState for reception ****
	bsf		midiFlags, uartState_rxInProgress, ACCESS
	;	midiRxMessage.message[0] = midiState_lastStatus
	movff	midiState_lastStatus, midiRxMessage
	;	midiRxMessage_length = midiState_lastLength
	movff	midiState_lastLength, midiRxMessage_length
	;	midiRxMessage.message[1] = rxByte
	movlw	1
	movff	rxByte, PLUSW_midiRxMessage	
	;	uartState_currentRxIndex = 2
	movlw	2
	movwf	uartState_currentRxIndex, ACCESS


processRxAsMIDI_RxHandlingDone

	
processRxAsMIDI_checkRxFIFO
	btfsc	PIR1, RCIF, ACCESS
	goto	processRxAsMIDI_readFIFO
	
processRxAsMIDI_Exit

	; undefine variables from pushed registers
	#undefine	rxByte
	#undefine	tmpValue
	#undefine	FSR_midiRxMessage
	#undefine	PLUSW_midiRxMessage
	; pop working regs from software stack
	POP_R	FSR0H
	POP_R	FSR0L
	POP_R	r1
	POP_R	r0
		
	return


;**********************************************************************
; Function: void midiMessageMapper(midiRxMessage)
;**********************************************************************

midiMessageMapper
	; push working regs onto software stack
	PUSH_R	r0
	PUSH_R	r1
	PUSH_R	r2
	PUSH_R	r3
	PUSH_R	FSR0L
	PUSH_R	FSR0H		
	; define variables to pushed registers
	#define	tmpValue			r0
	#define	statusByte			r1
	#define	noteNumberByte		r2
	#define	programValue		noteNumberByte
	#define	controllerNumber	noteNumberByte
	#define	velocityByte		r3
	#define	controllerValue		velocityByte
	#define	FSR_midiRxMessage	FSR0
	#define	PLUSW_midiRxMessage	PLUSW0
	
	; do work
	lfsr	FSR_midiRxMessage, midiRxMessage
	
	;	status = midiRxMessage[0] & 0xf0
	movlw	0
	movf	PLUSW_midiRxMessage, w, ACCESS
	andlw	0xf0
	movwf	statusByte, ACCESS	

	;	noteNumber = midiRxMessage[1]
	movlw	1
	movf	PLUSW_midiRxMessage, w, ACCESS
	movwf	noteNumberByte, ACCESS	

	;	velocity = midiRxMessage[2]
	movlw	2
	movf	PLUSW_midiRxMessage, w, ACCESS
	movwf	velocityByte, ACCESS	

	;	if((status == NOTE_ON) && (velocity == 0))
	;		status = NOTE_OFF;
	movlw	NOTE_ON
	cpfseq	statusByte, ACCESS
	bra		midiMessageMapper_notNoteOnWithZeroVel
	movf	velocityByte, f, ACCESS
	bnz		midiMessageMapper_notNoteOnWithZeroVel	
	movlw	NOTE_OFF
	movwf	statusByte, ACCESS
midiMessageMapper_notNoteOnWithZeroVel

	; case NOTE_ON
	movlw	NOTE_ON
	cpfseq	statusByte, ACCESS
	bra		midiMessageMapper_notNoteOn

	movf	noteNumberByte, w, ACCESS
	call	activeNoteTableAdd

	bra		midiMessageMapper_exit
	; break
midiMessageMapper_notNoteOn
	
	
	; case NOTE_OFF
	movlw	NOTE_OFF
	cpfseq	statusByte, ACCESS
	bra		midiMessageMapper_notNoteOff

	movf	noteNumberByte, w, ACCESS
	call	activeNoteTableRemove

	bra		midiMessageMapper_exit
	; break
midiMessageMapper_notNoteOff


	; case PITCH_WHEEL
	movlw	PITCH_WHEEL
	cpfseq	statusByte, ACCESS
	bra		midiMessageMapper_notPitchWheel

	; if sustain is active then ignore pitch
	movlw	SUSTAIN
	xorwf	modeLevel, w, ACCESS
	bz		midiMessageMapper_notPitchWheel
	
	; pitchWheel == pitch wheel value
	movff	midiRxMessage + 1, pitchWheel + 0
	; pitchWheel + 0 is only a 7-bit value
	; so concatenate received pitch wheel MSB and LSB into contiguous 16-bit value
	; roll least significant bit out of received pitch wheel high byte
	bcf		STATUS, C, ACCESS
	rrcf	midiRxMessage + 2, w
	; if rolled out bit was set then set bit 7 of pitchWheel + 0
	btfsc	STATUS, C, ACCESS
	bsf		pitchWheel + 0, 7, ACCESS
	; write high byte into pitchWheel
	movwf	pitchWheel + 1, ACCESS
	clrf	pitchWheel + 2, ACCESS
	clrf	pitchWheel + 3, ACCESS
	; value has been concatenated into contiguous 16-bit value
	
	; calulate offset from 0x2000 (center)
	movlw	0x20
	cpfslt	pitchWheel + 1, ACCESS
	bra		midiMessageMapper_pitchPos

	; pitch wheel is negative
	movlw	0x20
	subwf	pitchWheel + 1, f, ACCESS
	btfss	STATUS, C, ACCESS
	decf	pitchWheel + 2, f, ACCESS	
	btfss	STATUS, C, ACCESS
	decf	pitchWheel + 3, f, ACCESS	
	bra		midiMessageMapper_exit

midiMessageMapper_pitchPos
	; pitch wheel is positive
	movlw	0x20
	subwf	pitchWheel + 1, f, ACCESS
	bra		midiMessageMapper_exit

midiMessageMapper_notPitchWheel


	; case CONTROL_CHANGE
	movlw	CONTROL_CHANGE
	cpfseq	statusByte, ACCESS
	bra		midiMessageMapper_notControlChange

	;	switch(midiRxPoppedMessage.message[1])	// controller #
	;	{
	;		case ALL_SOUND_OFF:
	;		case RESET_ALL_CONTROLLERS:
	;		case ALL_NOTES_OFF:
	;			for(=0; count<ACTIVE_NOTE_TABLE_SIZE; count++)
	;				activeNoteTable[count];
	;			initSoundGen();
	;		break;
	;	}

	; **** check for Panic! condition ****
	; noteNumber == midiRxMessage[1]
	movf	controllerNumber, w, ACCESS
	xorlw	ALL_SOUND_OFF
	bz		midiMessageMapper_doPanic
	movf	controllerNumber, w, ACCESS
	xorlw	ALL_NOTES_OFF
	bnz		midiMessageMapper_notPanic
midiMessageMapper_doPanic
	; passing 0xff to activeNoteTableRemove() will flush table
	movlw	0xff
	call	activeNoteTableRemove
	bra		midiMessageMapper_exit
midiMessageMapper_notPanic

	; **** check for controller reset ****
	movf	controllerNumber, w, ACCESS
	xorlw	RESET_ALL_CONTROLLERS
	bnz		midiMessageMapper_notControllerReset
	; easiest option is straight-up software reset, so do it!
	reset
midiMessageMapper_notControllerReset

	; **** check for Sustain ****
	; noteNumber == midiRxMessage[1]
	movf	controllerNumber, w, ACCESS
	xorlw	SUSTAIN_PEDAL
	bnz		midiMessageMapper_notSustain
	; sustain message: <63 means sustain off, >64 mean sustain on
	; controllerValue == midiRxMessage[2]
	movlw	63
	cpfsgt	controllerValue, ACCESS
	bra		midiMessageMapper_sustainOff
	; turn sustain on. Spec says >64 but I'm just doing >63
	; set modeLevel to MONO and call userInterface_incMode()
	movlw	POLY
	movwf	modeLevel, ACCESS
	call	userInterface_incMode
	bra		midiMessageMapper_exit
midiMessageMapper_sustainOff
	; turn sustain off
	; set modeLevel to SUSTAIN and call userInterface_incMode()
	movlw	MONO
	movwf	modeLevel, ACCESS
	call	userInterface_incMode
	bra		midiMessageMapper_exit
midiMessageMapper_notSustain
	
	; **** check for POLY MODE OFF ****
	movf	controllerNumber, w, ACCESS
	xorlw	POLY_MODE_OFF
	bnz		midiMessageMapper_notPolyOff
	movlw	SUSTAIN
	movwf	modeLevel, ACCESS
	call	userInterface_incMode
	bra		midiMessageMapper_exit
midiMessageMapper_notPolyOff
	
	; **** check for POLY MODE ON ****
	movf	controllerNumber, w, ACCESS
	xorlw	POLY_MODE_ON
	bnz		midiMessageMapper_notPolyOn
	movlw	MONO
	movwf	modeLevel, ACCESS
	call	userInterface_incMode
	bra		midiMessageMapper_exit
midiMessageMapper_notPolyOn
	
	
	; **** check for Mod Wheel ****
	; noteNumber == midiRxMessage[1]
	movf	controllerNumber, w, ACCESS
	xorlw	MODULATION_WHEEL_MSB
	bnz		midiMessageMapper_notMod

	; if sustain is active then ignore modulation
	movlw	SUSTAIN
	xorwf	modeLevel, w, ACCESS
	bz		midiMessageMapper_notMod

	; save current modulation value
	movff	controllerValue, modulation
	; in Sample mode: mainline eeprom read call code uses modulation variable	
	; in Sine/Square modes: always modify table base addresses in response to modulation
	; init table addresses

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
	
	; push sine backward into modulationBlendTable
	movf	controllerValue, w, ACCESS
	subwf	sineTableBaseAddress + 0, f
	btfss	STATUS, C, ACCESS
	decf	sineTableBaseAddress + 1, f
	btfss	STATUS, C, ACCESS
	decf	sineTableBaseAddress + 2, f

	; push square forward into modulationBlendTable
	movf	controllerValue, w, ACCESS
	addwf	squareTableBaseAddress + 0, f
	btfsc	STATUS, C, ACCESS
	incf	squareTableBaseAddress + 1, f
	btfsc	STATUS, C, ACCESS
	incf	squareTableBaseAddress + 2, f
	bra		midiMessageMapper_exit	
midiMessageMapper_notMod
	
	; **** check for Attack ****
	movf	controllerNumber, w, ACCESS
	xorlw	73
	bnz		midiMessageMapper_notAttack
	; load tmpValue with 64 for later inversion op
	movlw	64
	movwf	tmpValue, ACCESS
	; do (adsrAttackRate = (controllerValue+1)/2) to scale max range to 0 - 64
	incf	controllerValue, w, ACCESS
	bcf		STATUS, C, ACCESS
	rrcf	WREG, w, ACCESS
	; do (64 - midiAttackTime) to invert value and make adsrAttackRate logically time-correlated
	subwf	tmpValue, w, ACCESS
	; save it
	movwf	adsrAttackRate, ACCESS
midiMessageMapper_notAttack

	; **** check for Release ****
	movf	controllerNumber, w, ACCESS
	xorlw	72
	bnz		midiMessageMapper_notRelease
	; load tmpValue with 64 for later inversion op
	movlw	64
	movwf	tmpValue, ACCESS
	; do (adsrReleaseRate = (controllerValue+1)/2) to scale max range to 0 - 64
	incf	controllerValue, w, ACCESS
	bcf		STATUS, C, ACCESS
	rrcf	WREG, w, ACCESS
	; do (64 - midiRelease) to invert value and make adsrReleaseRate logically time-correlated
	subwf	tmpValue, w, ACCESS
	; save it
	movwf	adsrReleaseRate, ACCESS
midiMessageMapper_notRelease


#IFDEF	MIDI_DEBUG_TRIGGER_ENABLED
; DEBUG - assign CC General Purpose 7 as variable dump trigger
	; **** check for General Purpose Controller 7 (EDIROL Stop Key default function) ****
	movf	controllerNumber, w, ACCESS
	xorlw	MIDI_DEBUG_CC_NAME
	bnz		midiMessageMapper_notDebugTrigger
;	only call trigger on button down
	movlw	127
	cpfslt controllerValue, ACCESS
	call	midiDebugTriggerHandler
midiMessageMapper_notDebugTrigger
#ENDIF ; #IFDEF MIDI_DEBUG_TRIGGER_ENABLED

midiMessageMapper_notControlChange


	; case PROGRAM_CHANGE
	movlw	PROGRAM_CHANGE
	cpfseq	statusByte, ACCESS
	bra		midiMessageMapper_notPG
	
	; Program Change increases will cycle waveform mode in the following direction SINE -> SQUARE -> SAMPLE -> SINE
	; Program Change decreases will cycle waveform mode in the following direction SINE -> SAMPLE -> SQUARE -> SINE	
	
	; if value is 0, 1 or 2 then hardset to Sine, Square or Sample
	movf	programValue, w, ACCESS
	; do (2 - programValue)
	sublw	2
	; if result is negative then do compare
	bnc		midiMessageMapper_pgCompare
	; otherwise result is positive so waveShape = programValue
	movff	programValue, waveShape
	; waveShape is changing so set needDelgator flag
	bsf		soundGenFlags, needRefresh, ACCESS
	bra		midiMessageMapper_pgDone	

midiMessageMapper_pgCompare
	; value > 2 so compare current program change value against previous
	movf	midiLastProgramValue, w, ACCESS
	cpfsgt	programValue, ACCESS
	; set decrement flag
	bsf		soundGenFlags, pgDec, ACCESS
	; increment waveform
	call	userInterface_incWaveform
midiMessageMapper_pgDone
	; save current as previous
	movff	programValue, midiLastProgramValue
midiMessageMapper_notPG

	; case SYSEX
	movlw	SYSEX
	cpfseq	statusByte, ACCESS
	bra		midiMessageMapper_notSysEx
	; check for terminal ascii packet
	; check Vendor ID
	movlw 1
	movf	PLUSW_midiRxMessage, w, ACCESS
	xorlw VENDOR_ID
	bnz		midiMessageMapper_notSysEx
	; check Device ID
	movlw 2
	movf	PLUSW_midiRxMessage, w, ACCESS
	xorlw DEVICE_ID
	bnz		midiMessageMapper_notSysEx
	; check Command
	movlw 3
	movf	PLUSW_midiRxMessage, w, ACCESS
	xorlw TERMINAL_PACKET_COMMAND_VALUE
	bnz		midiMessageMapper_notSysEx
	; packet is terminal ascii so send to terminal
#ifdef ENABLE_MIDI_TERMINAL
	call	midiTerminal_receive
#endif
midiMessageMapper_notSysEx

midiMessageMapper_exit
	; undefine variables from pushed registers
	#undefine	tmpValue
	#undefine	statusByte
	#undefine	noteNumberByte
	#undefine	velocityByte
	#undefine	FSR_midiRxMessage
	#undefine	PLUSW_midiRxMessage
	; pop working regs from software stack
	POP_R	FSR0H	
	POP_R	FSR0L
	POP_R	r3
	POP_R	r2
	POP_R	r1
	POP_R	r0

	return
	
	
