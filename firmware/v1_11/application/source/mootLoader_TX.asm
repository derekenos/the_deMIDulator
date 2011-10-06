
;**********************************************************************
;                                                                     *
;    Project:       deMIDulator                                       *
;    Filename:	    mootLoader_TX_v0_2.asm                            *
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

; all variables defined in mootLoader.asm


;**********************************************************************
; mootLoader Trasmitter Code Begin
;**********************************************************************

mootLoader_transmitter
	; shut off sine LED leaving square and sample LEDs illuminated to communicate current mode to user
	LED_SINE_OFF

	; start program memory broadcast from address USER_CODE_START_ADDRESS
	; bootloader is not allowed to touch first 64-byte block to ensure that user will not
	; corrupt jump to bootloader on reset
	movlw	USER_CODE_START_ADDRESS
	movwf	mlStartAddress + 0, ACCESS
	clrf	mlStartAddress + 1, ACCESS
	clrf	mlStartAddress + 2, ACCESS
	clrf	mlStartAddress + 3, ACCESS

	; requesting full user application code Program Memory so...
	; length = (USER_CODE_END_ADDRESS - USER_CODE_START_ADDRESS) aligned to 64-byte boundary
	movlw	USER_CODE_START_ADDRESS
	; WREG = low(USER_CODE_END_ADDRESS) - USER_CODE_START_ADDRESS
	sublw	low(USER_CODE_END_ADDRESS)
	movwf	mlPayloadLength + 0, ACCESS
	
	movlw	high(USER_CODE_END_ADDRESS)
	movwf	mlPayloadLength + 1, ACCESS
	; if result of low(USER_CODE_END_ADDRESS) - USER_CODE_START_ADDRESS <0 then decrement
	btfss	STATUS, C, ACCESS
	decf	mlPayloadLength + 1, f, ACCESS
	
	movlw	upper(USER_CODE_END_ADDRESS)
	movwf	mlPayloadLength + 2, ACCESS
	; if result of (decf	mlPayloadLength + 1, f, ACCESS) <0 then decrement
	btfss	STATUS, C, ACCESS
	decf	mlPayloadLength + 2, f, ACCESS
	clrf	mlPayloadLength + 3, ACCESS

	; if mlPayloadLength is not 64-byte aligned then align it
	movlw	0x3f
	andwf	mlPayloadLength + 0, w, ACCESS
	; it's aligned to skip alignment
	bz		mootLoader_xmitStartWrite
	; clear 6 least significant bits
	movlw	0xC0
	andwf	mlPayloadLength + 0, f, ACCESS
	; add 64 to mlPayloadLength
	movlw	0x40
	addwf	mlPayloadLength + 0, f, ACCESS
	movlw	0
	addwfc	mlPayloadLength + 1, f, ACCESS
	addwfc	mlPayloadLength + 2, f, ACCESS
	addwfc	mlPayloadLength + 3, f, ACCESS

mootLoader_xmitStartWrite
	rcall	mootLoader_xmitWriteProgramMemory
	bra	mootLoader_exit	


;**********************************************************************
; mootLoader Trasmitter: Write Program Memory
;**********************************************************************
mootLoader_xmitWriteProgramMemory
	PUSH_R	FSR0L
	PUSH_R	FSR0H

	;****************************************
	; send Write Program Memory packet
	rcall	mootLoader_xmitSendWpmPacket
	;****************************************

	;****************************************
	; send Complete Data Payload
	; init table pointer with program memory start address
	movff	mlStartAddress + 0, TBLPTRL
	movff	mlStartAddress + 1, TBLPTRH
	movff	mlStartAddress + 2, TBLPTRU

mootLoader_xmitWpmBlockErase
	IDLE_BLOCK_ERASE	
	; load erase block size counter
	movlw	ML_BLOCK_ERASE_BYTE_SIZE
	movwf	mlBlockEraseBytesRemaining, ACCESS

mootLoader_xmitWpmNextPayload
	;****************************************
	; send single Data Payload packet
	; load mlDataPayloadBuffer with bytes to send
	lfsr	FSR0, mlDataPayloadBuffer
	; load counter with num of bytes remaining in payload packet
	movlw	ML_DATA_PACKET_PAYLOAD_BYTE_SIZE
	movwf	mlCount, ACCESS
mootLoader_xmitWpmByteLp
	; read program memory location and increment
	tblrd*+
	; save value to mlDataPayloadBuffer
	movff	TABLAT, POSTINC0
	; check if mlDataPayloadBuffer is ready to go
	decf	mlCount, f, ACCESS
	bnz		mootLoader_xmitWpmByteLp
	; send the packet
	rcall	mootLoader_xmitSendDataPayloadPacket
	;****************************************

	; do write wait after every packet transfer
	IDLE_WRITE_WAIT
	
	; check if entire payload has been transferred
	; do (mlPayloadLength -= ML_DATA_PACKET_PAYLOAD_BYTE_SIZE)
	movlw	ML_DATA_PACKET_PAYLOAD_BYTE_SIZE
	subwf	mlPayloadLength + 0, f, ACCESS
	movlw	0
	subwfb	mlPayloadLength + 1, f, ACCESS	
	subwfb	mlPayloadLength + 2, f, ACCESS	
	subwfb	mlPayloadLength + 3, f, ACCESS
	; if mlPayloadLength == 0 then entire payload has been transferred
	; if mlPayloadLength != 0 then check if we have to wait for another block erase
	movf	mlPayloadLength + 0, f, ACCESS
	bnz		mootLoader_xmitWpmCheckBlockErase
	movf	mlPayloadLength + 1, f, ACCESS
	bnz		mootLoader_xmitWpmCheckBlockErase
	movf	mlPayloadLength + 2, f, ACCESS
	bnz		mootLoader_xmitWpmCheckBlockErase
	movf	mlPayloadLength + 3, f, ACCESS
	bnz		mootLoader_xmitWpmCheckBlockErase
	bra		mootLoader_xmitWpmSendPayloadComplete

mootLoader_xmitWpmCheckBlockErase
	; check if we need to wait for a block erase
	; do (mlBlockEraseBytesRemaining - ML_DATA_PACKET_PAYLOAD_BYTE_SIZE)
	movlw	ML_DATA_PACKET_PAYLOAD_BYTE_SIZE
	subwf	mlBlockEraseBytesRemaining, f, ACCESS
	; if 0 then delay for block erase
	bz		mootLoader_xmitWpmBlockErase
	bra		mootLoader_xmitWpmNextPayload
	
mootLoader_xmitWpmSendPayloadComplete
	; mlPayloadLength == 0 so send Data Payload Complete packet
	;****************************************
	; send Data Payload Complete packet
	rcall	mootLoader_xmitSendDataPayloadCompletePacket
	;****************************************

	; transaction complete
	POP_R	FSR0H
	POP_R	FSR0L
	return
		
			
;**********************************************************************
; mootLoader Trasmitter: send Write Program Memory packet
;**********************************************************************
mootLoader_xmitSendWpmPacket

	;****************************************
	; send SysEx intro (0xF0, vendorID, deviceID)
	SEND_SYSEX_INTRO_NO_CHECK
	;****************************************
	
	;****************************************
	; send COMMAND
	movlw	ML_COMMAND_WRITE_PROGRAM_MEMORY
	SEND_BYTE_START_CHECKSUM
	;****************************************

	;****************************************
	; send START ADDRESS
	movf	mlStartAddress + 0, w, ACCESS
	SPLIT_BYTE_THEN_SEND_DO_CHECKSUM
	movf	mlStartAddress + 1, w, ACCESS
	SPLIT_BYTE_THEN_SEND_DO_CHECKSUM
	movf	mlStartAddress + 2, w, ACCESS
	SPLIT_BYTE_THEN_SEND_DO_CHECKSUM
	movf	mlStartAddress + 3, w, ACCESS
	SPLIT_BYTE_THEN_SEND_DO_CHECKSUM
	;****************************************

	;****************************************
	; send PAYLOAD LENGTH
	movf	mlPayloadLength + 0, w, ACCESS
	SPLIT_BYTE_THEN_SEND_DO_CHECKSUM
	movf	mlPayloadLength + 1, w, ACCESS
	SPLIT_BYTE_THEN_SEND_DO_CHECKSUM
	movf	mlPayloadLength + 2, w, ACCESS
	SPLIT_BYTE_THEN_SEND_DO_CHECKSUM
	movf	mlPayloadLength + 3, w, ACCESS
	SPLIT_BYTE_THEN_SEND_DO_CHECKSUM
	;****************************************
	
	;****************************************
	; send CHECKSUM
	SEND_CHECKSUM_CLEAR_RUN
	;****************************************

	;****************************************
	; send End of SysEx
	movlw	0xF7
	rcall	mootLoader_sendByte
	;****************************************
	
	return	
	
	
;**********************************************************************
; mootLoader Trasmitter: send Data Payload Packet
;**********************************************************************
mootLoader_xmitSendDataPayloadPacket

	PUSH_R	FSR0L
	PUSH_R	FSR0H
	lfsr	FSR0, mlDataPayloadBuffer
		
	;****************************************
	; send SysEx intro (0xF0, vendorID, deviceID)
	SEND_SYSEX_INTRO_NO_CHECK
	;****************************************
	
	;****************************************
	; send COMMAND
	movlw	ML_COMMAND_DATA_PAYLOAD
	SEND_BYTE_START_CHECKSUM
	;****************************************

	;****************************************
	; send PAYLOAD bytes
	movlw	ML_DATA_PACKET_PAYLOAD_BYTE_SIZE
	movwf	mlDatPackIntByteCount, ACCESS
mootLoader_xmitSdppLp
	; read byte
	movf	INDF0, w, ACCESS
	SPLIT_BYTE_THEN_SEND_DO_CHECKSUM
	; increment pointer
	movf	POSTINC0, w, ACCESS
	; check if Data Payload packet is complete
	decf	mlDatPackIntByteCount, f, ACCESS
	bnz		mootLoader_xmitSdppLp
	;****************************************

	;****************************************
	; send CHECKSUM
	SEND_CHECKSUM_DO_RUN
	;****************************************

	;****************************************
	; send End of SysEx
	movlw	0xF7
	rcall	mootLoader_sendByte
	;****************************************

	POP_R	FSR0H
	POP_R	FSR0L
	return


;**********************************************************************
; mootLoader Trasmitter: send Data Payload Complete Packet
;**********************************************************************
mootLoader_xmitSendDataPayloadCompletePacket
	;****************************************
	; send SysEx intro (0xF0, vendorID, deviceID)
	SEND_SYSEX_INTRO_NO_CHECK
	;****************************************
	
	;****************************************
	; send COMMAND
	movlw	ML_COMMAND_DATA_PAYLOAD_COMPLETE
	SEND_BYTE_START_CHECKSUM
	;****************************************

	movlw	0x00
	SPLIT_BYTE_THEN_SEND_DO_CHECKSUM
	movlw	0x00
	SPLIT_BYTE_THEN_SEND_DO_CHECKSUM
	movlw	0x00
	SPLIT_BYTE_THEN_SEND_DO_CHECKSUM
	movlw	0x00
	SPLIT_BYTE_THEN_SEND_DO_CHECKSUM
	movlw	0x00
	SPLIT_BYTE_THEN_SEND_DO_CHECKSUM
	movlw	0x00
	SPLIT_BYTE_THEN_SEND_DO_CHECKSUM
	movlw	0x00
	SPLIT_BYTE_THEN_SEND_DO_CHECKSUM
	movlw	0x00
	SPLIT_BYTE_THEN_SEND_DO_CHECKSUM
	SEND_RUNNING_CHECKSUM

	;****************************************
	; send End of SysEx
	movlw	0xF7
	rcall	mootLoader_sendByte
	;****************************************	
	
	return
	

;**********************************************************************
; Local Function: void mootLoader_sendAsNybbles(WREG)
;**********************************************************************
mootLoader_sendAsNybbles
	; save to tmp variable
	movwf	mlNybbleSplitTmp, ACCESS
	; mask out low nybble and send
	andlw	0x0F
	rcall	mootLoader_sendByte
	; swap nybbles, mask out low nybble then send
	swapf	mlNybbleSplitTmp, w, ACCESS
	andlw	0x0F
	rcall	mootLoader_sendByte	
	return


;**********************************************************************
; Local Function: void mootLoader_sendByte(WREG)
;**********************************************************************
mootLoader_sendByte
	; check if TXREG is clear, wait if not
	btfss	PIR1, TXIF, ACCESS
	bra		mootLoader_sendByte
	movwf	TXREG, ACCESS
	return


;**********************************************************************
; mootLoader Trasmitter: Wait(WREG = WAIT_TIME_MS)
;**********************************************************************
mootLoader_wait
	; exit if delay time request is 0
	movf	WREG, f, ACCESS
	bz		mootLoader_waitExit
	
	; TMR2 overflow period (32uS) * 32 = 1.024mS
	; so do PRODH:L = WREG * 32
	movwf	PRODL, ACCESS
	movlw	32
	mulwf	PRODL, ACCESS

	; reset timer
	clrf	TMR2, ACCESS
mootLoader_waitLp
	; clear interrupt flag and wait for timer overflow
	bcf		PIR1, TMR2IF, ACCESS	
mootLoader_waitIntLp
	btfss	PIR1, TMR2IF, ACCESS
	bra		mootLoader_waitIntLp
	; unintelligently decrement PRODH:L counter
	decf	PRODL, f, ACCESS
	; skip if result was positive
	btfss	STATUS, C, ACCESS
	decf	PRODH, f, ACCESS
	; test PRODH:L, exit if 0
	movf	PRODL, f, ACCESS
	bnz		mootLoader_waitLp
	movf	PRODH, f, ACCESS
	bnz		mootLoader_waitLp
mootLoader_waitExit	
	return


