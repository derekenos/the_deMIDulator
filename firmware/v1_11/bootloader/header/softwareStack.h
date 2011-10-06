
;**********************************************************************
;                                                                     *
;    Project:       deMIDulator                                       *
;    Filename:	    softwareStack.h                                   *
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

#ifndef	SOFTWARESTACK_H
#define	SOFTWARESTACK_H

	#define	softwareStackPointerFSR		FSR2
	#define	softwareStackPointerINDF	INDF2
	#define	softwareStackPointerPOSTINC	POSTINC2
	#define	softwareStackPointerPOSTDEC	POSTDEC2
	#define	softwareStackPointerPREINC	PREINC2	
	#define	softwareStackPointerPLUSW	PLUSW2	

; **** MACRO: PUSH_R	regName
PUSH_R	MACRO	regName
	movff	regName, softwareStackPointerPOSTDEC	; softwareStackPointerINDF-- = regName
		ENDM
		
; **** MACRO: POP_R	regName
POP_R	MACRO	regName
	movff	softwareStackPointerPREINC, regName 	; ++softwareStackPointerINDF = regName
		ENDM

#endif