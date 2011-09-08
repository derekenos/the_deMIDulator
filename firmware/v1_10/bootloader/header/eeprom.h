
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

#ifndef	_EEPROMH_
#define	_EEPROMH_

; ******************* FLAG VARIABLE DEFINITIONS ***********************

; eepromFlags
#define	sampleChunkReady	0
#define samplesLoaded			1
#define	intState			2

; ******************* COMMAND DEFINES ***********************
#define EE_WREN		B'00000110'	; Enable Write Operations
#define EE_WRDI		B'00000100'	; Disable Write Operations
#define EE_RDSR		B'00000101'	; Read Status Register
#define EE_WRSR		B'00000001'	; Write Status Register
#define EE_READ		B'00000011'	; Read Data from Memory
#define EE_WRITE	B'00000010'	; Write Data to Memory

; ******************* GENERAL DEFINES ***********************
#define	SAMPLE_DATA_BUFFER_SIZE	64
#define EEPROM_SIZE_BITS 128000
#define	NEXT_SAMPLE_ADDRESSES_EL_SIZE	2

;**********************************************************************
; MACROS
;**********************************************************************


;**********************************************************************
ASSERT_SS	MACRO
	bcf		LATC, RC6, ACCESS	; Chip select is active
	ENDM

;**********************************************************************
DEASSERT_SS	MACRO
	bsf		LATC, RC6, ACCESS	; Chip select is idle
	ENDM

;**********************************************************************
EE_DISABLE_INTS	MACRO
	bcf		eepromFlags, intState, ACCESS
	btfsc	INTCON, GIE, ACCESS
	bsf		eepromFlags, intState, ACCESS
	bcf		INTCON, GIE, ACCESS
	ENDM

;**********************************************************************
EE_RESTORE_INTS	MACRO
	btfsc	eepromFlags, intState, ACCESS
	bsf		INTCON, GIE, ACCESS
	ENDM

;**********************************************************************
WRITE_INTERNAL_EEPROM	MACRO	literal_address, register_value
	local	writeIntEE_loop
	
	; load address
	movlw	literal_address
	movwf	EEADR, ACCESS
	; load value
	movff	register_value, EEDATA
	; configure eeprom
	; point to EEPROM DATA memory
	bcf		EECON1, EEPGD, ACCESS
	; Access EEPROM/Program
	bcf		EECON1, CFGS, ACCESS	
	; Enable writes
	bsf		EECON1, WREN, ACCESS

	; don't have to disable interrupts because I'm only calling this
	; from within the high-priority ISR

	; required write enable sequence
	movlw	0x55
	movwf	EECON2, ACCESS
	movlw	0xAA
	movwf	EECON2, ACCESS

	; set WR bit to begin write
	bsf		EECON1, WR, ACCESS
writeIntEE_loop
	; wait for write to complete
	btfsc	EECON1, WR, ACCESS
	bra		writeIntEE_loop
	; disable writes
	bcf		EECON1, WREN, ACCESS

	; point to Program memory
	bsf		EECON1, EEPGD, ACCESS

	ENDM

;**********************************************************************
WRITE_INTERNAL_EEPROM_FROM_REGS	MACRO	address, data
	local	writeIntEE_loop
	
	; load address
	movff	address, EEADR
	; load value
	movff	data, EEDATA
	; configure eeprom
	; point to EEPROM DATA memory
	bcf		EECON1, EEPGD, ACCESS
	; Access EEPROM/Program
	bcf		EECON1, CFGS, ACCESS	
	; Enable writes
	bsf		EECON1, WREN, ACCESS

	; don't have to disable interrupts because I'm only calling this
	; from within the high-priority ISR

	; required write enable sequence
	movlw	0x55
	movwf	EECON2, ACCESS
	movlw	0xAA
	movwf	EECON2, ACCESS

	; set WR bit to begin write
	bsf		EECON1, WR, ACCESS
writeIntEE_loop
	; wait for write to complete
	btfsc	EECON1, WR, ACCESS
	bra		writeIntEE_loop
	; disable writes
	bcf		EECON1, WREN, ACCESS

	; point to Program memory
	bsf		EECON1, EEPGD, ACCESS

	ENDM

;;**********************************************************************
;;SPI_TX_LITERAL_RX_IN_WREG	MACRO	value
;	local	waitLoop
;
;; routine as recommended in Microchip PIC18F2458/2553/4458/4553 errata
;
;	; clear interrupt flag
;	bcf		PIR1, SSPIF, ACCESS
;
;	; perform read, even if the data in SSPBUF is not important 
;	movf	SSPBUF, w, ACCESS
;
;	; SSPBUF = value
;	movlw	value
;	movwf	SSPBUF, ACCESS
;
;	; wait fro transfer to complete
;waitLoop
;	btfss	PIR1, SSPIF, ACCESS
;	bra		waitLoop
;
;	; the data received should be valid
;	movf	SSPBUF, w, ACCESS
;
;	ENDM
						
;;**********************************************************************
;SPI_TX_WREG_RX_IN_WREG	MACRO
;	local	waitLoop
;
;	; save WREG to software stack
;	PUSH_R	WREG
;	
;; routine as recommended in Microchip PIC18F2458/2553/4458/4553 errata
;	; clear interrupt flag
;	bcf		PIR1, SSPIF, ACCESS
;
;	; perform read, even if the data in SSPBUF is not important 
;	movf	SSPBUF, w, ACCESS
;
;	; SSPBUF = restored WREG from software stack
;	POP_R	WREG
;	movwf	SSPBUF, ACCESS
;
;	; wait for transfer to complete
;waitLoop
;	btfss	PIR1, SSPIF, ACCESS
;	bra		waitLoop
;
;	; the data received should be valid
;	movf	SSPBUF, w, ACCESS
;
;	ENDM

#endif
