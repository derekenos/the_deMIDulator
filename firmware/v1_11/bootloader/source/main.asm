
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
	#include	"../header/userInterface.h"

	
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
highPriorityISR
lowPriorityISR
	
;**********************************************************************
; MAINLINE CODE BEGIN
;**********************************************************************

main
	goto	main

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
		

	ORG		USER_CODE_END_ADDRESS
	nop
	
	ORG		BOOTLOADER_START_ADDRESS
	#include	"../source/mootLoader.asm"

	END

