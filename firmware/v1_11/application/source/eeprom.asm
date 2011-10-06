
;**********************************************************************
;                                                                     *
;    Project:       deMIDulator                                       *
;    Filename:	    eeprom.asm                                        *
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

; Target EEPROM is On Semiconductor CAT25128 or compatible
; Functions perform no address boundry checking
; Functions do not poll EEPROM for Ready so period between EEPROM write requests must be >5mS per CAT25128 datasheet

;**********************************************************************
; INCLUDES
;**********************************************************************

	#include "../header/eeprom.h"
	#include "../header/softwareStack.h"
	

;**********************************************************************
; LOCAL VARIABLES
;**********************************************************************

	CBLOCK
		sampleDataBufferIndex:1
		sampleChunkCount:1
		sampleEndAddress:2
		nextSampleAddress:2
		
		eepromFlags:1
		; bits defined in eeprom.h
		; #define sampleChunkReady	0
		; #define samplesLoaded			1
		; #define intState					2
		; #define	ready 						3

		; Declared at end of main.asm to ensure that arrays are pushed to end of memory...
		; with smaller variables in ACCESS memory
		; ---------------------------------------
		; sampleDataBuffer:SAMPLE_DATA_BUFFER_SIZE
		; nextSampleAddresses:MAX_POLY_DEPTH * NEXT_SAMPLE_ADDRESSES_EL_SIZE

	ENDC
			

;**********************************************************************
; LOCAL FUNCTIONS
;**********************************************************************

;**********************************************************************
; Function: wreg eepromXferSingleByte(byte wreg)
;**********************************************************************
	; !! Function does not assert Slave Select signal and so should not be called directly
	; !! Function is called by other EEPROM functions
eepromXferSingleByte

	; save current global interrupt enable state, disable global interrupts
	EE_DISABLE_INTS

	;**** start procedure: SPI transfer. TX value = WREG, WREG = RX value ****
	; push WREG to software stack
	PUSH_R	WREG

	; perform read, even if the data in SSPBUF is not important 
	movf	SSPBUF, w, ACCESS

	; clear Write Collision flag
	bcf		SSPCON1, WCOL, ACCESS

	; SSPBUF = restored WREG from software stack
	POP_R	WREG
	movwf	SSPBUF, ACCESS

	; skip if no Write Collision occurred 
	btfsc	SSPCON1, WCOL, ACCESS
	; collision occured, return WREG
	bra		eepromXferSingleByte_exit

	; clear interrupt flag
	bcf		PIR1, SSPIF, ACCESS

eepromXferSingleByte_lp
	; wait for transfer to complete
#ifndef	__DEBUG
	btfss	PIR1, SSPIF, ACCESS
	bra		eepromXferSingleByte_lp	
#else
	; if DEBUG then simulate worst case transaction time
	; SPI Clock = 4MHz = Instruction Clock so it should take 8 instruction cycles per byte transfer
	; 3 cycles elapsed since SSPBUF load so make up the 5 cycle balance + loop error of ~5 cycles
	; balance
	nop
	nop
	nop
	nop
	nop
	; potential error
	nop
	nop
	nop
	nop
	nop
#endif

	; the data received should be valid
	movf	SSPBUF, w, ACCESS
	
eepromXferSingleByte_exit

	; restore global interrupt enable state
	EE_RESTORE_INTS

	return


;**********************************************************************
; Function: void initExternalEEPROM(void)
;**********************************************************************

initExternalEEPROM
	; enable EEPROM writes
	call	eepromWriteEnable

	; init Status register
	; Bank Protect bits, BP1:0, = 0
	; Write Protect Enable bit, WPEN, = 0
	; !WP pin on IC is pulled HIGH so WPEN would have no effect either way 
	movlw	0
	call	eepromWriteStatusReg

	; init EEPROM variables	
	clrf	sampleDataBufferIndex, ACCESS
	clrf	sampleChunkCount, ACCESS
	clrf	nextSampleAddress, ACCESS
	clrf	nextSampleAddress + 1, ACCESS
	bcf		eepromFlags, sampleChunkReady, ACCESS
	bcf		eepromFlags, samplesLoaded, ACCESS

	; recall saved sampleEndAddress from uC's internal EEPROM in little endian format
	movlw	0
	call	eepromInternalRead
	movwf	sampleEndAddress, ACCESS
	movlw	1
	call	eepromInternalRead
	movwf	sampleEndAddress + 1, ACCESS
	
	return


;**********************************************************************
; Function: void eepromWriteEnable(void)
;**********************************************************************

eepromWriteEnable

	; assert SLave Select signal
	ASSERT_SS

	; first write to SSPBUF in routine so we need to check for collision
	; if collision then continue to attempt write
eepromWriteEnable_lp
	movlw	EE_WREN
	call	eepromXferSingleByte
	btfsc	SSPCON1, WCOL, ACCESS
	bra		eepromWriteEnable_lp

	; deassert Slave Select signal
	DEASSERT_SS
	
	return


;**********************************************************************
; Function: void eepromReadStatusReg(byte wreg)
;**********************************************************************

eepromReadStatusReg
	
	; assert Slave Select signal
	ASSERT_SS

	; first write to SSPBUF in routine so we need to check for collision
	; if collision then continue to attempt write
eepromReadStatusReg_doLp1
	movlw	EE_RDSR
	call	eepromXferSingleByte
	btfsc	SSPCON1, WCOL, ACCESS
	bra		eepromReadStatusReg_doLp1
	
	; routine is now synchronized with SSP operation so no need to check WCOl

	; send dummy value while receiving Status register
	movlw	0
	call	eepromXferSingleByte

	; read Status Reg complete
	; WREG = EEPROM Status

	; deassert Slave Select signal
	DEASSERT_SS

	return


;**********************************************************************
; Function: void eepromWriteStatusReg(byte wreg)
;**********************************************************************

eepromWriteStatusReg

	; push working regs onto software stack
	PUSH_R	r0
	; define variables to pushed registers
	#define	statusRegValue	r0

	; save argument passed in WREG
	movwf	statusRegValue, ACCESS
	
	; assert Slave Select signal
	ASSERT_SS

	; first write to SSPBUF in routine so we need to check for collision
	; if collision then continue to attempt write
eepromWriteStatusReg_doLp1
	movlw	EE_WRSR
	call	eepromXferSingleByte
	btfsc	SSPCON1, WCOL, ACCESS
	bra		eepromWriteStatusReg_doLp1
	
	; routine is now synchronized with SSP operation so no need to check WCOl

	; send Status register value to write
	movf	statusRegValue, w, ACCESS
	call	eepromXferSingleByte

	; write Status Reg complete

	; deassert Slave Select signal
	DEASSERT_SS

	; pop working regs onto software stack
	POP_R	r0
	; undefine variables from popped registers
	#undefine	statusRegValue

	return


;**********************************************************************
; Function: sampleDataBuffer[0] = eepromReadSingleByte(nextSampleAddress)
;**********************************************************************

eepromReadSingleByte

	; push working regs onto software stack
	PUSH_R	r0
	PUSH_R	FSR0L
	PUSH_R	FSR0H
	; define variables to pushed registers
	#define	tmpValue				r0
	#define	FSR_sampleDataBuffer	FSR0
	#define	PLUSW_sampleDataBuffer	PLUSW0	
		
	; load pointer
	lfsr	FSR_sampleDataBuffer, sampleDataBuffer

	; assert Slave Select signal
	ASSERT_SS
	
	; first write to SSPBUF in routine so we need to check for collision
	; if collision then continue to attempt write
eepromReadSingleByte_lp1
	movlw	EE_READ
	call	eepromXferSingleByte
	btfsc	SSPCON1, WCOL, ACCESS
	bra		eepromReadSingleByte_lp1
	
	; send address HIGH byte
	movf	nextSampleAddress + 1, w, ACCESS
	call	eepromXferSingleByte

	; send address LOW byte
	movf	nextSampleAddress, w, ACCESS
	call	eepromXferSingleByte

	; send dummy 0x00 value, get byte from EEPROM
	movlw	0
	call	eepromXferSingleByte
	
	; deassert Slave Select signal
	DEASSERT_SS

	; pop working regs from software stack
	POP_R	FSR0H
	POP_R	FSR0L
	POP_R	r0
	; undefine variables from popped registers
	#undefine	tmpValue
	#undefine	FSR_sampleDataBuffer
	#undefine	PLUSW_sampleDataBuffer

	return


;**********************************************************************
; Function: void eepromWrite64(void)
;**********************************************************************

eepromWrite64
	; push working regs onto software stack
	PUSH_R	r0
	PUSH_R	FSR0L
	PUSH_R	FSR0H
	PUSH_R	PRODL	
	PUSH_R	PRODH
	; define variables to pushed registers
	#define	index						r0
	#define	FSR_sampleDataBuffer		FSR0
	#define	PLUSW_sampleDataBuffer		PLUSW0	

	; load fsr
	lfsr	FSR_sampleDataBuffer, sampleDataBuffer	
	
	;**** start procedure: send 'WRITE ENABLE' command to EEPROM ****
	; eepromWriteEnable function takes care of waiting for collision-free write
	call	eepromWriteEnable

	; routine is now synchronized with SSP operation so no need to check WCOl
	
	;**** start procedure: send 'WRITE' command to EEPROM ****
	; assert Slave Select signal
	ASSERT_SS

	; load EEPROM WRITE command value into WREG
	movlw	EE_WRITE
	; write command value into SSPBUF
	call	eepromXferSingleByte

	; load EEPROM WRITE ADDRESS into SSPBUF
	; calculate EEPROM write address for current sample data chunk
	; address = ((sampleChunkCount - 1) * SAMPLE_DATA_BUFFER_SIZE);
	; after multiply, registers PRODH:L = address
	decf	sampleChunkCount, w, ACCESS
	mullw	SAMPLE_DATA_BUFFER_SIZE

	; load EEPROM WRITE ADDRESS HIGH BYTE into SSPBUF

; [Problem Code Begin]
; this code breaks EEPROM write
;	movff	PRODH, SSPBUF
; DEBUG
; but this code works
	movf	PRODH, w, ACCESS
	; write command value into SSPBUF
	call	eepromXferSingleByte
; [Problem Code End]

	; load EEPROM WRITE ADDRESS LOW BYTE into SSPBUF

; [Problem Code Begin]
; this code breaks EEPROM write
;	movff	PRODL, SSPBUF
; DEBUG
; but this code works
	movf	PRODL, w, ACCESS
	; write command value into SSPBUF
	call	eepromXferSingleByte
; [Problem Code End]
	
	; write 64-byte sampleDataBuffer to EEPROM
	; init index to point at first element in buffer
	clrf	index, ACCESS
eepromWrite64_sendBuffer
	; SSPBUF = sampleDataBuffer(index)

; [Problem Code Begin]
; this code breaks EEPROM writing
;	movf	index, w, ACCESS
;	movff	PLUSW_sampleDataBuffer, SSPBUF
; DEBUG
; but this code works
	movf	index, w, ACCESS
	movf	PLUSW_sampleDataBuffer, w, ACCESS
	; write data into SSPBUF
	call	eepromXferSingleByte
; [Problem Code End]

	; increment index
	incf	index, f, ACCESS
	; if index is == SAMPLE_DATA_BUFFER_SIZE then entire buffer has been sent
	movlw	SAMPLE_DATA_BUFFER_SIZE
	cpfseq	index, ACCESS
	; not done so continue
	bra		eepromWrite64_sendBuffer
	
	; entire buffer has been sent
	; buffer write request complete

	; clear eeprom ready flag to signal that eeprom will be unavailable for a bit while the write completes
	bcf		eepromFlags, ready, ACCESS

	; deassert Slave Select signal
	DEASSERT_SS							

	; undefine variables from pushed registers
	#undefine	index
	#undefine	FSR_sampleDataBuffer
	#undefine	PLUSW_sampleDataBuffer
	; pop working regs from software stack
	POP_R	PRODH	
	POP_R	PRODL
	POP_R	FSR0H	
	POP_R	FSR0L
	POP_R	r0

	return
	
	
;**********************************************************************
; Function: void initInternalEEPROM(void)
;**********************************************************************

initInternalEEPROM
	; ensure that access is always to Program Memory aside from inside EEPROM functions
	; EEPGD (1 = Access Program Memory, 0 = Access EEPROM)
	bsf		EECON1, EEPGD, ACCESS
	; CFGS (1 = Access Configuration Registers, 0 = Access Program Memory or EEPROM)
	bcf		EECON1, CFGS, ACCESS

	return
	

;**********************************************************************
; Function: wreg eepromInternalRead(wreg address)
;**********************************************************************

eepromInternalRead
	; load address
	movwf	EEADR, ACCESS
	; EEPGD (1 = Access Program Memory, 0 = Access EEPROM)
	bcf		EECON1, EEPGD, ACCESS
	; start read
	bsf		EECON1, RD, ACCESS
	; save read value to wreg
	movf	EEDATA, w, ACCESS
	; ensure that access is always to Program Memory aside from inside EEPROM functions
	; EEPGD (1 = Access Program Memory, 0 = Access EEPROM)
	bsf		EECON1, EEPGD, ACCESS

	return




