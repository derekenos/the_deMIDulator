;**********************************************************************
;                                                                     *
;    Project:       deMIDulator                                       *
;    Filename:	    eeprom.h                                          *
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

#ifndef	_MOOTLOADERH_
#define	_MOOTLOADERH_


; ******************* MOOTLOADER TRANSACTION DEFINES ***********************

#define	ML_BLOCK_ERASE_BYTE_SIZE			64	; must be multiple of ML_DATA_PAYLOAD_BYTE_SIZE
#define	ML_DATA_PACKET_PAYLOAD_BYTE_SIZE	8

#define	ML_BLOCK_ERASE_IDLE_TIME_MS			8
#define	ML_WRITE_IDLE_TIME_MS				8
#define	ML_TRANS_SYNC_IDLE_TIME_MS			32


; ******************* MOOTLOADER COMMAND BYTE DEFINES ***********************

#define MIDI_VENDOR_ID						0x77
#define MIDI_DEVICE_ID						0x1D

#define ML_COMMAND_WRITE_PROGRAM_MEMORY		0x03
#define ML_COMMAND_DATA_PAYLOAD				0x01
#define ML_COMMAND_DATA_PAYLOAD_COMPLETE	0x02
#define	ML_TRANSMITTER_RESETTING			0x10
#define	ML_RECEIVER_RESET					0x11


; ******************* MOOTLOADER PACKET DEFINES ***********************

#define	ML_LARGE_PACKET_BYTE_SIZE		22


; ******************* mlFlags BIT DEFINES ***********************

#define	mlRxTransSyncFlag					0
#define	mlRxChecksumOk						1


;**********************************************************************
; MACROS
;**********************************************************************

SEND_SYSEX_INTRO_NO_CHECK	MACRO
	movlw	0xF0
	call	mootLoader_sendByte
	movlw	MIDI_VENDOR_ID
	call	mootLoader_sendByte
	movlw	MIDI_DEVICE_ID
	call	mootLoader_sendByte
	ENDM

SEND_BYTE_START_CHECKSUM	MACRO
	movwf	mlChecksum, ACCESS
	call	mootLoader_sendByte
	ENDM

SEND_BYTE_DO_CHECKSUM		MACRO
	xorwf	mlChecksum, f, ACCESS
	call	mootLoader_sendByte
	ENDM

SPLIT_BYTE_THEN_SEND_DO_CHECKSUM	MACRO
	xorwf	mlChecksum, f, ACCESS
	call	mootLoader_sendAsNybbles
	ENDM

SEND_CHECKSUM_CLEAR_RUN		MACRO
	movf	mlChecksum, w, ACCESS
	; ensure that bit 7 is clear
	andlw	0x7f
	clrf	mlRunningChecksum, ACCESS
	call	mootLoader_sendByte
	ENDM
	
SEND_CHECKSUM_DO_RUN		MACRO
	movf	mlChecksum, w, ACCESS
	; ensure that bit 7 is clear
	andlw	0x7f
	xorwf	mlRunningChecksum, f, ACCESS
	call	mootLoader_sendByte
	ENDM

SEND_RUNNING_CHECKSUM		MACRO
	movf	mlRunningChecksum, w, ACCESS
	; ensure that bit 7 is clear
	andlw	0x7f
	call	mootLoader_sendByte
	ENDM

IDLE_BLOCK_ERASE			MACRO
	movlw	ML_BLOCK_ERASE_IDLE_TIME_MS
	call	mootLoader_wait
	ENDM

IDLE_WRITE_WAIT				MACRO
	movlw	ML_WRITE_IDLE_TIME_MS
	call	mootLoader_wait
	ENDM

	
#endif

