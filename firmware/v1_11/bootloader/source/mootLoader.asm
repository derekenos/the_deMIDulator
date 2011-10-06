
;**********************************************************************
;                                                                     *
;    Project:       deMIDulator                                       *
;    Filename:	    mootLoader.asm                                    *
;    Date:                                                            *
;    File Version:                                                    *
;                                                                     *
;    Author:        Derek Enos                                        *
;    Company:                                                         *
;                                                                     * 
;                                                                     *
;**********************************************************************


;**********************************************************************
; INCLUDE FILES
;**********************************************************************
	
	#include	"../header/mootloader.h"

	
;**********************************************************************
; LOCAL VARIABLES
;**********************************************************************

	CBLOCK 0

		; global
		mlButtonState:1
		mlChecksum:1
		mlRunningChecksum:1
		mlStartAddress:4
		mlPayloadLength:4
		mlDataPayloadBuffer:ML_DATA_PACKET_PAYLOAD_BYTE_SIZE
		mlCount:2
		mlFlags:1
		; sendNybble()
		mlNybbleSplitTmp:1
		; sendByte()
		mlCurrentTxByte:1
		; writeProgramMemory()
		mlBlockEraseBytesRemaining:1
		; sendDataPayloadPacket()
		mlDatPackIntByteCount:1
		; rxListenForPrelude()
		mlPerfectPreludeCount:1
		; mootLoader_rxReceiveNextPacket()
		mlRxReceivedPacket:ML_LARGE_PACKET_BYTE_SIZE
		mlRxReceivedPacketByteCount:1
		; rxReceiveNextByte()
		mlRxReceivedByte:1
		; rxReceiveNextSymbol()
		mlRxPreviousSymbolBucket:1
		mlConsecutiveSymbolCount:1
		; convertPeriodToSymbol()
		mlRxSymbolBucket:1
		mlPeriodBucketLowLimit:1
		mlPeriodBucketHighLimit:1
		mlSymbolBucketCount:1
		; measureInputCyclePeriod()
		mlRA4CompareReg:1
		mlRxCyclePeriodL:1
		mlRxCyclePeriodH:1
		mlSchmittReadValue:1
		mlTransitionCount:1
		; rxDecodeReceivedSymbol()
		mlDecodedNybble:1
		; debug
		mlEepromAddress:1
		mlEepromByteCount:1
		
	ENDC


;**********************************************************************
; LOCAL DEFINES
;**********************************************************************

;#define	DEBUG_TOGGLE_SQUARE_ON_SAMPLE
;#define	DEBUG_TOGGLE_SQUARE_ON_EDGE_DETECT
;#define	DEBUG_SQUARE_FOLLOWS_SCHMITT_VALUE
;#define	DEBUG_TOGGLE_SQUARE_ON_MEASURE_BOUNDS
;#define	DEBUG_TOGGLE_SQUARE_ON_NEW_SYMBOL_DETECT


;**********************************************************************
; mootLoader BEGIN
;**********************************************************************

mootLoader
	
	rcall	mootLoader_initCore
	
	; use BANK0
	BANKSEL	0
		
	; turn on all LEDs
	LED_ALL_ON

	; check if boot action is being requested
	; enter mootLoader Trasmitter mode if waveform(RC0) & record(RC1) switches held for 2 second
	; enter mootLoader Receiver mode if record(RC1) & mode(RC2) switches held for 2 second

	;**** start procedure: check button state ****
	; if any buttons (RC0 - RC2) are pressed then wait for button state to remain unchanged for 2 seconds
	comf	PORTC, w, ACCESS
	andlw	0x07
	; no buttons are active so exit
	bz		mootLoader_exit
	; at least one button is active so wait to make sure that state doesn't change for 2 seconds
	; mlTmpValue = compliment of initial RC2:0 value
	movwf	mlButtonState, ACCESS
	clrf	TMR2, ACCESS
	movlw	0x24
	movwf	mlCount, ACCESS
	movlw	0xf4
	movwf	mlCount + 1, ACCESS
mootLoader_stateWaitLp
	comf	PORTC, w, ACCESS
	andlw	0x07
	cpfseq	mlButtonState, ACCESS
	; button state has changed before timer expiration so exit mootLoader
	bra		mootLoader_exit
	; state has not changed so wait for timer overflow
	bcf		PIR1, TMR2IF, ACCESS	
mootLoader_stateWaitOvLp
	btfss	PIR1, TMR2IF, ACCESS
	bra		mootLoader_stateWaitOvLp	
	; timer has overflowed so decrement overflow counter
	decf	mlCount, f, ACCESS
	btfss	STATUS, C, ACCESS
	decf	mlCount + 1, f, ACCESS
	movf	mlCount, f, ACCESS
	; count != so continue loop
	bnz		mootLoader_stateWaitLp
	movf	mlCount + 1, f, ACCESS
	; count != so continue loop
	bnz		mootLoader_stateWaitLp

	; button state remained unchanged for 2 seconds. yay

	;**** start procedure: check button combo value ****
	; remeber, mlButtonState is reversed logic
	movlw	0<<RC2 ^ 1<<RC1 ^ 1<<RC0
	cpfseq	mlButtonState, ACCESS
	bra		mootLoader_checkReceive
	bra		mootLoader_transmitter		
mootLoader_checkReceive
	movlw	1<<RC2 ^ 1<<RC1 ^ 0<<RC0
	cpfseq	mlButtonState, ACCESS
	bra		mootLoader_exit
	bra		mootLoader_receiver

mootLoader_exit
	goto	main_redirect
			
	; include code for mootLoader functions
	#include	"mootLoader_init.asm"
	#include	"mootLoader_TX.asm"
	#include	"mootLoader_RX.asm"
	bra	mootLoader_exit
	
