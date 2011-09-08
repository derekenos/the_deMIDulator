
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

	list		p=18lf13k50					; list directive to define processor
	list		r=dec						; set default radix to decimal

	#define		USER_CODE_START_ADDRESS		0x0040	; address must be aligned to 64-byte boundary

;**********************************************************************
; CONDITIONAL ASSEMBLY DEFINES
;**********************************************************************

; THROUGH_HOLE_PCB option swaps Sine/Square switch and LED assignments
	#define	THROUGH_HOLE_PCB

; LED_POLARITY_REVERSED option reverses logic polarity for LEDs
	#define	LED_POLARITY_REVERSED
	
; LED_STEADY_STATE_DISABLED option saves 4mA per LED but introduces high frequency noise during playback
;	#define	LED_STEADY_STATE_DISABLED

	
;**********************************************************************
; INCLUDE FILES
;**********************************************************************

	#include	<p18lf13k50.inc>			; processor specific variable definitions
	
	#include	"../include/config.inc"		; configuration bit options copied from p18lf13k50.inc
																			; and uncommented as appropriate
	#include	"../header/eeprom.h"
	#include	"../header/midi.h"
	#include	"../header/softwareStack.h"
	#include	"../header/soundGen.h"
	#include	"../header/userInterface.h"
		
;**********************************************************************
; GLOBAL VARIABLES
;**********************************************************************
	
	; set stack base address as last data mem address
	CBLOCK 0x2ff
		softwareStackBaseAddress:1
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
highPriorityISR
lowPriorityISR
main
	nop

	; ensure that bootLoader reads/writes all program mem from USER_CODE_START_ADDRESS to bootloader
	ORG		0x17FE
lastApplicationProgramMemoryAddress
	nop
	
	ORG		0x1800	; 1024 word (2048-byte) boot block
	#include	"../source/mootLoader.asm"

	END

