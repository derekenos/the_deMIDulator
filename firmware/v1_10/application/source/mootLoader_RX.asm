
;**********************************************************************
;                                                                     *
;    Project:       deMIDulator                                       *
;    Filename:	    mootLoader_RX_v0_2.asm                            *
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

; all variables defined in mootLoader_v0_2.asm


;**********************************************************************
; mootLoader Receiver Code Begin
;**********************************************************************
mootLoader_receiver
	; communicate mode to user
	; shut off sample LED leaving sine and square LEDs illuminated to communicate current mode to user
	LED_SAMPLE_OFF

mootLoader_receiverListenForTrans
	call	mootLoader_rxReceiveNextPacket
	; jump to command handler
	movlw	ML_COMMAND_WRITE_PROGRAM_MEMORY
	xorwf	mlRxReceivedPacket + 3, w, ACCESS
	bz		mootLoader_rxWriteProgramMemoryHandler
	movlw	ML_RECEIVER_RESET
	xorwf	mlRxReceivedPacket + 3, w, ACCESS
	goto	mootLoader_rxReceiverResetHandler
	; unhandled command so listen for next trans sync
	bra		mootLoader_receiverListenForTrans
		
	goto	mootLoader_exit


;**********************************************************************
; Local Function: void mootLoader_rxWriteProgramMemoryHandler()
;**********************************************************************
mootLoader_rxWriteProgramMemoryHandler
	; save write start address
	movff	mlRxReceivedPacket + 4, mlStartAddress + 0
	movff	mlRxReceivedPacket + 6, mlStartAddress + 1
	movff	mlRxReceivedPacket + 8, mlStartAddress + 2
	movff	mlRxReceivedPacket + 10, mlStartAddress + 3
	; save payload length
	movff	mlRxReceivedPacket + 12, mlPayloadLength + 0
	movff	mlRxReceivedPacket + 14, mlPayloadLength + 1
	movff	mlRxReceivedPacket + 16, mlPayloadLength + 2
	movff	mlRxReceivedPacket + 18, mlPayloadLength + 3
	; test checksum, exit if bad
	call	mootloader_rxTestSinglePacketChecksum
	btfss	mlFlags, mlRxChecksumOk, ACCESS
	bra		mootLoader_signalErrorA
	
	; load table pointer with start address
	movff	mlStartAddress + 0, TBLPTRL
	movff	mlStartAddress + 1, TBLPTRH
	movff	mlStartAddress + 2, TBLPTRU

mootLoader_rxWpmhBlockErase
	; point to Flash Program Memory
	bsf		EECON1, EEPGD, ACCESS
	; access Flash Program Memory
	bcf		EECON1, CFGS, ACCESS
	; enable write to memory
	bsf		EECON1, WREN, ACCESS
	; enable erase operation
	bsf		EECON1, FREE, ACCESS
	; do require sequence
	movlw	0x55
	movwf	EECON2, ACCESS
	movlw	0xAA
	movwf	EECON2, ACCESS
	; start write, CPU will stall
	bsf		EECON1, WR, ACCESS
	; dummy read decrement to reset TBLPTR. Don't know why this is necessary but sure enough...
	; without it all my writes were off by one address. Is included in datasheet example code
	tblrd*-
		
	; get next packet
mootLoader_rxWpmhGetNextPacket
	call	mootLoader_rxReceiveNextPacket
	
	; toggle all LEDs to indicate activity
	LED_ALL_TOGGLE
	
	; if data payload complete then reset device
	movlw	ML_COMMAND_DATA_PAYLOAD_COMPLETE
	xorwf	mlRxReceivedPacket + 3, w, ACCESS
	bz		mootLoader_rxReceiverResetHandler
	; if data payload then confirm checksum and then write data
	movlw	ML_COMMAND_DATA_PAYLOAD
	xorwf	mlRxReceivedPacket + 3, w, ACCESS
	; if not data payload then exit with error
	bnz		mootLoader_signalErrorB
	; is data payload so test checksum
	call	mootloader_rxTestSinglePacketChecksum
	btfss	mlFlags, mlRxChecksumOk, ACCESS
	; checksum bad so exit with error
	bra		mootLoader_signalErrorC
	; everything is ok so write the payload
	
	; write payload to holding registers
	movff	mlRxReceivedPacket + 4, TABLAT
	tblwt+*
	movff	mlRxReceivedPacket + 6, TABLAT
	tblwt+*
	movff	mlRxReceivedPacket + 8, TABLAT
	tblwt+*
	movff	mlRxReceivedPacket + 10, TABLAT
	tblwt+*
	movff	mlRxReceivedPacket + 12, TABLAT
	tblwt+*
	movff	mlRxReceivedPacket + 14, TABLAT
	tblwt+*
	movff	mlRxReceivedPacket + 16, TABLAT
	tblwt+*
	movff	mlRxReceivedPacket + 18, TABLAT
	tblwt+*
		
	; write holding register to flash memory
	; point to Flash Program Memory
	bsf		EECON1, EEPGD, ACCESS
	; access Flash Program Memory
	bcf		EECON1, CFGS, ACCESS
	; enable write to memory
	bsf		EECON1, WREN, ACCESS
	; do require sequence
	movlw	0x55
	movwf	EECON2, ACCESS
	movlw	0xAA
	movwf	EECON2, ACCESS
	; start write, CPU will stall
	bsf		EECON1, WR, ACCESS	
	
; DEBUG
;	movlw	0
;	call	mootloader_rxWriteRxPacketToEE
;	bra		mootLoader_rxWpmhExit

	; do block erase on every 64-byte boundary
	; if(!(TBLPTRL & 0x3f)){doBlockErase();}
	movlw	0x3f
	andwf	TBLPTRL, w, ACCESS
	bz		mootLoader_rxWpmhBlockErase
	bra		mootLoader_rxWpmhGetNextPacket
	
mootLoader_rxWpmhExit
	goto	mootLoader_exit


;**********************************************************************
; Local Function: void mootLoader_signalErrorA()
;**********************************************************************
mootLoader_signalErrorA
	LED_SINE_TOGGLE_OTHERS_OFF
	clrf	mlCount, ACCESS
	movlw	0x10
	movwf	mlCount + 1, ACCESS
mootLoader_signalErrorALp1
	; clear interrupt flag
	bcf		PIR1, TMR2IF, ACCESS	
mootLoader_signalErrorALp2
	; wait for timer2 overflow
	btfss	PIR1, TMR2IF, ACCESS
	bra		mootLoader_signalErrorALp2
	decf	mlCount, f, ACCESS
	btfsc	STATUS, Z, ACCESS
	decfsz	mlCount + 1
	bra		mootLoader_signalErrorALp1
	; loop forever
	bra		mootLoader_signalErrorA
;**********************************************************************
; Local Function: void mootLoader_signalErrorB()
;**********************************************************************
mootLoader_signalErrorB
; DEBUG - write received packet to eeprom
	lfsr	FSR1, mlRxReceivedPacket
	clrf	mlEepromAddress, ACCESS
mootLoader_SebWriteReceivedPacketToEEPROMLp
	WRITE_INTERNAL_EEPROM_FROM_REGS	mlEepromAddress, POSTINC1
	; write data
	incf	mlEepromAddress, f, ACCESS
	movlw	ML_LARGE_PACKET_BYTE_SIZE
	cpfseq	mlEepromAddress, ACCESS
	bra		mootLoader_SebWriteReceivedPacketToEEPROMLp

mootLoader_signalErrorBLp0
	LED_SQUARE_TOGGLE_OTHERS_OFF
	clrf	mlCount, ACCESS
	movlw	0x10
	movwf	mlCount + 1, ACCESS
mootLoader_signalErrorBLp1
	; clear interrupt flag
	bcf		PIR1, TMR2IF, ACCESS	
mootLoader_signalErrorBLp2
	; wait for timer2 overflow
	btfss	PIR1, TMR2IF, ACCESS
	bra		mootLoader_signalErrorBLp2
	decf	mlCount, f, ACCESS
	btfsc	STATUS, Z, ACCESS
	decfsz	mlCount + 1
	bra		mootLoader_signalErrorBLp1
	; loop forever
	bra		mootLoader_signalErrorBLp0
;**********************************************************************
; Local Function: void mootLoader_signalErrorC()
;**********************************************************************
mootLoader_signalErrorC
	LED_SAMPLE_TOGGLE_OTHERS_OFF
	clrf	mlCount, ACCESS
	movlw	0x10
	movwf	mlCount + 1, ACCESS
mootLoader_signalErrorCLp1
	; clear interrupt flag
	bcf		PIR1, TMR2IF, ACCESS	
mootLoader_signalErrorCLp2
	; wait for timer2 overflow
	btfss	PIR1, TMR2IF, ACCESS
	bra		mootLoader_signalErrorCLp2
	decf	mlCount, f, ACCESS
	btfsc	STATUS, Z, ACCESS
	decfsz	mlCount + 1
	bra		mootLoader_signalErrorCLp1
	; loop forever
	bra		mootLoader_signalErrorC
	

;**********************************************************************
; Local Function: void mootLoader_rxReceiverResetHandler()
;**********************************************************************
mootLoader_rxReceiverResetHandler
	; received bytes are forwarded to UART output for chaining devices so
	; make sure that you don't reset until last byte is transmitted	
	btfss	PIR1, TXIF, ACCESS
	bra		mootLoader_rxReceiverResetHandler
	reset


;**********************************************************************
; Local Function: void mootloader_rxTestSinglePacketChecksum()
;**********************************************************************
mootloader_rxTestSinglePacketChecksum
	; pre-clear checksumOk flag
	bcf		mlFlags, mlRxChecksumOk, ACCESS
	; calculate checksum for single packet
	movf	mlRxReceivedPacket + 3, w, ACCESS
	xorwf	mlRxReceivedPacket + 4, w, ACCESS
	xorwf	mlRxReceivedPacket + 6, w, ACCESS
	xorwf	mlRxReceivedPacket + 8, w, ACCESS
	xorwf	mlRxReceivedPacket + 10, w, ACCESS
	xorwf	mlRxReceivedPacket + 12, w, ACCESS
	xorwf	mlRxReceivedPacket + 14, w, ACCESS
	xorwf	mlRxReceivedPacket + 16, w, ACCESS
	xorwf	mlRxReceivedPacket + 18, w, ACCESS
	; xor mlRxReceivedPacket[8:0] with checksum in mlRxReceivedPacket[9]
	andlw	0x7F
	xorwf	mlRxReceivedPacket + 20, w, ACCESS
	; if result is 0 then checksum if NOT ok so skip
	btfsc	STATUS, Z, ACCESS
	bsf		mlFlags, mlRxChecksumOk, ACCESS
	return


;**********************************************************************
; Local Function: void mootLoader_rxReceiveNextPacket()
;**********************************************************************
mootLoader_rxReceiveNextPacket
	PUSH_R	FSR0L
	PUSH_R	FSR0H	
	lfsr	FSR0, mlRxReceivedPacket

	clrf	mlRxReceivedPacketByteCount, ACCESS
	
	; get next SysEx packet

	; mootloader only responds to SysEx so wait for start value of 0xF0
mootLoader_rxReceiveNextPacketWaitF0
	call	mootLoader_rxReceiveNextByte
	movlw	0xF0
	cpfseq	mlRxReceivedByte, ACCESS
	bra		mootLoader_rxReceiveNextPacketWaitF0
	; received 0xF0 so continue
	movff	mlRxReceivedByte, POSTINC0
	
	; continue receiving balance of ML_LARGE_PACKET_BYTE_SIZE number of bytes
	; init count
	movlw	ML_LARGE_PACKET_BYTE_SIZE - 1
	movwf	mlRxReceivedPacketByteCount, ACCESS
mootLoader_rxRnpPayloadLp
	call	mootLoader_rxReceiveNextByte
	movff	mlRxReceivedByte, POSTINC0
	decfsz	mlRxReceivedPacketByteCount, f, ACCESS
	bra		mootLoader_rxRnpPayloadLp

	; make each data payload nybble index equal to reconstituted byte value
	; point to start of data payload
	lfsr	FSR0, mlRxReceivedPacket + 4
	; load count to de-nybble 8 bytes
	movlw	8
	movwf	mlRxReceivedPacketByteCount, ACCESS
mootLoader_rxRnpPayloadDe_nybbleLp
	; swap and read high nybble into WREG
	movlw	1
	swapf	PLUSW0, w, ACCESS
	; or high nybble and low nybble, save in WREG
	iorwf	INDF0, w, ACCESS
	; save complete value in low nybble location and postinc to high nybble
	movwf	POSTINC0, ACCESS
	; save complete value in high nybble location and postinc to next low nybble
	movwf	POSTINC0, ACCESS
	decfsz	mlRxReceivedPacketByteCount, f, ACCESS
	bra		mootLoader_rxRnpPayloadDe_nybbleLp	
	
	POP_R	FSR0H	
	POP_R	FSR0L
	return
	

;**********************************************************************
; Local Function: void mootloader_rxReceiveNextByte()
;**********************************************************************
mootLoader_rxReceiveNextByte
	; skip if receive flag is set
	btfss	PIR1, RCIF, ACCESS
	bra		mootLoader_rxReceiveNextByte
	
mootLoader_rxReceiveNextByteReadFIFO
	; skip if framing error occurred for top unread char in rx FIFO
	btfss	RCSTA, FERR, ACCESS
	; no framing error so read the character
	bra		mootLoader_rxReceiveNextByteGO
	; framing error occurred
	; read incorrectly framed character out of FIFO
	movf	RCREG, w, ACCESS
	; skip if rx FIFO is empty
	btfsc	PIR1, RCIF, ACCESS
	; FIFO is not empty so try next character
	bra		mootLoader_rxReceiveNextByteReadFIFO
	; all characters in FIFO were incorrectly framed, no data to process
	; attempt to remedy: reset UART receiver by toggling Continous Receive Enable bit
	bcf		RCSTA, CREN, ACCESS
	bsf		RCSTA, CREN, ACCESS
	; need to receive a good data so try again
	goto	mootLoader_rxReceiveNextByte
mootLoader_rxReceiveNextByteGO
	; read the byte
	movff	RCREG, mlRxReceivedByte

	; echo received byte to UART output
	movff	mlRxReceivedByte, TXREG

	return

	
