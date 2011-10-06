
;**********************************************************************
;                                                                     *
;    Project:       deMIDulator                                       *
;    Filename:	    main.asm                                          *
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

; Software Stack uses FSR2 so hands off!

;**********************************************************************
; ENVIRONMENTAL DEFINES
;**********************************************************************

	; define processor
	; ..13K50 is default shipping processor, ..14k22 used for development
	#define	PIC18LF13K50
;	#define	PIC18LF14K22

#ifdef	PIC18LF13K50
	list		p=18lf13k50			; list directive to define processor
#endif
#ifdef	PIC18LF14K22
	list		p=18lf14k22			; list directive to define processor
#endif
	
	list		r=dec						; set default radix to decimal

	#define	USER_CODE_START_ADDRESS		0x0040	; address must be aligned to 64-byte boundary

#ifdef PIC18LF13K50
	; (Program Memory Size - Boot Block Size)
	;	4kW (8192 bytes) - 512W (1024 bytes)
	; 0x2000 - 0x0400 = 0x1C00
	#define	BOOTLOADER_START_ADDRESS	0x1C00
#endif

#ifdef PIC18LF14K22
	; (Program Memory Size - Boot Block Size)
	;	8kW (16384 bytes) - 1kW (2048 bytes)
	; 0x4000 - 0x0800 = 0x3800
	#define	BOOTLOADER_START_ADDRESS	0x3800
#endif

	#define	USER_CODE_END_ADDRESS			BOOTLOADER_START_ADDRESS - 2

;**********************************************************************
; CONDITIONAL ASSEMBLY DEFINES
;**********************************************************************

; THROUGH_HOLE_PCB option swaps Sine/Square switch and LED assignments
	#define	THROUGH_HOLE_PCB

; LED_POLARITY_REVERSED option reverses logic polarity for LEDs
	#define	LED_POLARITY_REVERSED
	
; LED_STEADY_STATE_DISABLED option saves 4mA per LED but introduces high frequency noise during playback
;	#define	LED_STEADY_STATE_DISABLED

;	MIDI_DEBUG_TRIGGER_ENABLED option enables debug code in midiMessageMapper()
; MIDI_DEBUG_CC_NAME defines which on/off (127/0) controller number to use
;	#define	MIDI_DEBUG_TRIGGER_ENABLED
;	#define	MIDI_DEBUG_CC_NAME					GENERAL_PURPOSE_CONTROLLER_7
	
;**********************************************************************
; INCLUDE FILES
;**********************************************************************

#ifdef	PIC18LF13K50
	; processor specific variable definitions
	#include	<p18lf13k50.inc>
	; configuration bit options copied from p18lf13k50.inc
	#include	"../include/config_PIC18LF13K50.inc"
#endif

#ifdef	PIC18LF14K22
	; processor specific variable definitions
	#include	<p18lf14k22.inc>
	; configuration bit options copied from p18lf13k50.inc
	#include	"../include/config_PIC18LF14K22.inc"
#endif

	#include	"../header/midi.h"
	#include	"../header/eeprom.h"
	#include	"../header/softwareStack.h"
	#include	"../header/soundGen.h"

	
;**********************************************************************
; GLOBAL VARIABLES
;**********************************************************************

	; declare isr tmp and working register variables
	; align to RAM address 0x0000
	CBLOCK 0
		wTmp:1
		statusTmp:1
		bsrTmp:1
		r0:1
		r1:1
		r2:1
		r3:1
		r4:1
		r5:1
		r6:1
		r7:1
	ENDC
	
;**********************************************************************
; CODE BEGIN / RESET VECTOR
;**********************************************************************

	ORG		0x0000							; processor reset vector
	clrf    PCLATH							; ensure page bits are cleared
	goto	mootLoader						; jump to bootloader
;**********************************************************************
; INTERRUPT VECTORS
;**********************************************************************

	ORG     0x0008             				; high-priority interrupt vector
	goto	highPriorityISR_redirect

	ORG     0x0018             				; low-priority interrupt vector
	goto	lowPriorityISR_redirect


;**********************************************************************
; USER-DEFINED MAIN() AND ISR() REDIRECTS
;**********************************************************************
; To prevent the user from rendering the bootloader unusable in the event
; of a failed Program Memory write, the first >=64 bytes of Program Memory
; will not be writable (set via USER_CODE_START_ADDRESS define) via the
; bootloader so must contain no user code.
; The first 64 bytes will contain only:
;
; 0x0000: clrf	PCLATH						; set bank-select bits to Bank0
; 0x0001: goto	mootLoader					; jump to bootloader on reset
; 0x0008: goto	highPriorityISR_redirect	; jump to high priority ISR redirect in user space
; 0x0018: goto	lowPriorityISR_redirect		; jump to low priority ISR redirect in user space
;
; since these will not be modifiable without a hardware programmer, these
; redirects will point to the following static addresses:
;
; 0x0040: goto main				; jump to main()
; 0x0044: goto highPriorityISR	; jump to highPriorityISR()
; 0x0048: goto lowPriorityISR	; jump to lowPriorityISR()
;
; When writing new firmware, the user is responsible for maintaing these 
; jump instructions at these addresses.  Note that the "goto" instruction
; requires 2 words of Program Memory space.

	ORG		USER_CODE_START_ADDRESS
main_redirect
	goto	main
highPriorityISR_redirect
	goto	highPriorityISR
lowPriorityISR_redirect
	goto	lowPriorityISR

;**********************************************************************
; INTERRUPT SERVICE ROUTINE CODE BEGIN
;**********************************************************************

	; insert ISR code
	#include	"../source/ISRs.asm"

	
;**********************************************************************
; MAINLINE CODE BEGIN
;**********************************************************************

main
	; all variables aside from softwareStack are in RAM BANK 0
	; all single byte or 2-byte variables are in ACCESS RAM
	BANKSEL	0

	; dummy instruction to check "endOfVariables" location in disassembly
dummy_endOfVariables
	movff	WREG, endOfVariables
	
	call	initCore
	call	initInternalEEPROM
	call	initExternalEEPROM
	call	initMIDI
	call	initSoundGen
	call	initUserInterface

	call	userInterface_checkConfigRequest
	
	; enable global interrupts
	bsf		INTCON, GIE, ACCESS
	
mainLoop	
	
	; handle EEPROM reading / writing in mainline to minimize audio corruption
	;
	; check if waveShape is == SAMPLE
	movlw	SAMPLE
	cpfseq	waveShape, ACCESS
	bra		mainNotSample

	; if sampleChunkReady is set then write sampleDataBuffer to EEPROM
	; ISR sets playback mode to PLAYBACK immediately after last chunk is complete...
	; so always just write EEPROM when sampleChunkReady is set
	btfss	eepromFlags, sampleChunkReady, ACCESS
	bra		mainCheckPlayback
	; flag is set so write it to EEPROM
	call	eepromWrite64

	; clear the flag so that we know when next chunk is ready to go
	bcf		eepromFlags, sampleChunkReady, ACCESS
	bra		mainNotSample
		
mainCheckPlayback
	; check if mode is PLAYBACK
	movlw	PLAYBACK
	cpfseq	recordOrPlayback, ACCESS
	bra		mainNotSample
;	if((soundOn || turnSoundOn) && (waveShape == SAMPLE) && !sampleReady)
	btfsc	midiFlags, soundOn, ACCESS
	bra		mainCheckSampleWaveshape
	btfss	midiFlags, turnSoundOn, ACCESS
	bra		mainNotSample
mainCheckSampleWaveshape
	btfsc	eepromFlags, samplesLoaded, ACCESS
	bra		mainNotSample

	; check if EEPROM is ready to read
	btfsc	eepromFlags, ready, ACCESS
	bra		mainEepromReady
	; eeprom is not ready so reset activeOutputValues
	movlw	PWM_IDLE_OUTPUT_VALUE
	movwf	activeOutputValues + 0
	movwf	activeOutputValues + 1
	movwf	activeOutputValues + 2
	movwf	activeOutputValues + 3
	; last time we checked, EEPROM wasn't ready so check it again
	call	eepromReadStatusReg
	; WREG = EEPROM Status Reg, (eepromFlags, ready) = (STATUS, !(NOT_READY))
	btfsc	WREG, NOT_RDY, ACCESS
	; NOT_READY bit in EEPROM Status register is set so don't do EEPROM read
	bra		mainNotSample
	; NOT_READY bit in EEPROM Status register is clear so set 'ready' flag and read the eeprom
	bsf		eepromFlags, ready, ACCESS
	
mainEepromReady
	; get sample(s)
	movff	nextSampleAddresses + 0, nextSampleAddress
	movff	nextSampleAddresses + 1, nextSampleAddress + 1
	; it pains me to put this sample address reversal code here as a macro but...
	; but can't spare the cycles in processSoundState() to modify nextSampleAddress
	REVERSE_SAMPLE_IF_MOD_OVER_63
	call	eepromReadSingleByte
	; save read value to output register
	movwf	activeOutputValues + 0

	; continue process if poly
	movlw	1
	cpfsgt	polyDepth, ACCESS
	bra		mainSampleMono

	; get sample(s)
	movff	nextSampleAddresses + 2, nextSampleAddress
	movff	nextSampleAddresses + 3, nextSampleAddress + 1
	REVERSE_SAMPLE_IF_MOD_OVER_63
	call	eepromReadSingleByte
	; save read value to output register
	movwf	activeOutputValues + 1

	; get sample(s)
	movff	nextSampleAddresses + 4, nextSampleAddress
	movff	nextSampleAddresses + 5, nextSampleAddress + 1
	REVERSE_SAMPLE_IF_MOD_OVER_63
	call	eepromReadSingleByte
	; save read value to output register
	movwf	activeOutputValues + 2

	; get sample(s)
	movff	nextSampleAddresses + 6, nextSampleAddress
	movff	nextSampleAddresses + 7, nextSampleAddress + 1
	REVERSE_SAMPLE_IF_MOD_OVER_63
	call	eepromReadSingleByte
	; save read value to output register
	movwf	activeOutputValues + 3
	

mainSampleMono
	; set sampleReady flag so ISR will update address
	bsf		eepromFlags, samplesLoaded, ACCESS

mainNotSample

	; call getActiveNoteDeltas() needRefresh flag is set
	btfss	soundGenFlags, needRefresh, ACCESS
	bra		mainLoop_noRefresh
	; immediately clear the flag.  Was previously clearing after return from getActiveNoteDeltas but notes would 
	; ocassionally hang on last note if flag was set in ISR during getActiveNoteDeltas execution
	bcf		soundGenFlags, needRefresh, ACCESS	
	; need refresh so call for it
	call	getActiveNoteDeltas
mainLoop_noRefresh

	call	serviceADSR

	goto	mainLoop

;**********************************************************************
	
	#include	"../source/init.asm"
	#include	"../source/midi.asm"
	#include	"../source/eeprom.asm"
	#include	"../source/soundGen.asm"
	#include	"../source/userInterface.asm"

;**********************************************************************

	; include CBLOCK defines for arrays here to ensure that smaller variables are within ACCESS memory
	CBLOCK
		; visual marker of allocated memory when viewing file registers in debug
		endOfVariables:1
		; from midi.asm
		midiRxMessage:		MAX_MIDI_MESSAGE_SIZE
		activeNoteTable:	ACTIVE_NOTE_TABLE_SIZE
		; from eeprom.asm
		sampleDataBuffer:	SAMPLE_DATA_BUFFER_SIZE
		nextSampleAddresses:MAX_POLY_DEPTH * NEXT_SAMPLE_ADDRESSES_EL_SIZE
		; from soundGen.asm
		activeNoteDeltas:		ACTIVE_NOTE_DELTAS_SIZE
		delegatedDeltas:		DELEGATED_DELTAS_SIZE
		oscDeltas:				OSC_DELTAS_SIZE
		accumulators:			ACCUMULATORS_SIZE
		activeOutputValues:		ACTIVE_OUTPUT_VALUES_SIZE
	ENDC

	; set stack base address as last data mem address

#ifdef PIC18LF13K50
	CBLOCK 0x2ff
		softwareStackBaseAddress:1
	ENDC
#endif
#ifdef PIC18LF14K22
	CBLOCK 0x1ff
		softwareStackBaseAddress:1
	ENDC
#endif
		
	#include	"../include/noteDeltaTables.inc"
	#include	"../include/waveTables.inc"


	ORG		USER_CODE_END_ADDRESS
	nop
	
	ORG		BOOTLOADER_START_ADDRESS
	#include	"../source/mootLoader.asm"

	ORG 0xF00000
	; define compile-time EEPROM DATA
	; on-board EEPROM memory map - highPriorityISR_INT0() in ISRs.asm writes these values, various init routine read them at power-up
	; Address:0x00 - sampleEndAddress[0:7]
	; Address:0x01 - sampleEndAddress[8:15]
	; Address:0x02 - midiChannel
	; Address:0x03 - adsrAttackRate
	; Address:0x04 - adsrReleaseRate
	DE	0xff, 0xff, DEFAULT_MIDI_CHANNEL, ADSR_ATTACK_RATE, ADSR_RELEASE_RATE

	END

