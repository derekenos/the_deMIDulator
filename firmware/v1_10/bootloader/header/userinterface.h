
;**********************************************************************
;                                                                     *
;    Project:       deMIDulator                                       *
;    Filename:	    userinterface.h                                   *
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

#ifndef	_USERINTERFACEH_
#define _USERINTERFACEH_

#define	LEVEL_POLY_LED_BLINK_RATE		0
#define	LEVEL_SUSTAIN_LED_BLINK_RATE	2
#define	LEVEL_MONO_LED_BLINK_RATE		1

;**********************************************************************
; MACROS
;**********************************************************************
							
#ifndef	THROUGH_HOLE_PCB

#ifdef	LED_STEADY_STATE_DISABLED

LED_SINE_ON	MACRO
#ifndef	LED_POLARITY_REVERSED
	bcf		ledOnOffFlags, RA5, ACCESS	; LED is on
#else
	bsf		ledOnOffFlags, RA5, ACCESS	; LED is on
#endif
	ENDM

LED_SQUARE_ON	MACRO
#ifndef	LED_POLARITY_REVERSED
	bcf		ledOnOffFlags, RC4, ACCESS	; LED is on
#else
	bsf		ledOnOffFlags, RC4, ACCESS	; LED is on
#endif
	ENDM

LED_SAMPLE_ON	MACRO
#ifndef	LED_POLARITY_REVERSED
	bcf		ledOnOffFlags, RC3, ACCESS	; LED is on
#else
	bsf		ledOnOffFlags, RC3, ACCESS	; LED is on
#endif
	ENDM

LED_SINE_OFF	MACRO
#ifndef	LED_POLARITY_REVERSED
	bsf		ledOnOffFlags, RA5, ACCESS	; LED is off
#else
	bcf		ledOnOffFlags, RA5, ACCESS	; LED is off
#endif
	ENDM

LED_SQUARE_OFF	MACRO
#ifndef	LED_POLARITY_REVERSED
	bsf		ledOnOffFlags, RC4, ACCESS	; LED is off
#else
	bcf		ledOnOffFlags, RC4, ACCESS	; LED is off
#endif
	ENDM

LED_SAMPLE_OFF	MACRO
#ifndef	LED_POLARITY_REVERSED
	bsf		ledOnOffFlags, RC3, ACCESS	; LED is off
#else
	bcf		ledOnOffFlags, RC3, ACCESS	; LED is off
#endif
	ENDM

LED_SINE_TOGGLE	MACRO
	btg		ledOnOffFlags, RA5, ACCESS	; LED is toggled
	ENDM

LED_SQUARE_TOGGLE	MACRO
	btg		ledOnOffFlags, RC4, ACCESS	; LED is toggled
	ENDM

LED_SAMPLE_TOGGLE	MACRO
	btg		ledOnOffFlags, RC3, ACCESS	; LED is toggled
	ENDM

#else	; #ifdef LED_STEADY_STATE_DISABLED

LED_SINE_ON	MACRO
#ifndef	LED_POLARITY_REVERSED
	bcf		LATA, RA5, ACCESS	; LED is on
#else
	bsf		LATA, RA5, ACCESS	; LED is on
#endif
	ENDM

LED_SQUARE_ON	MACRO
#ifndef	LED_POLARITY_REVERSED
	bcf		LATC, RC4, ACCESS	; LED is on
#else
	bsf		LATC, RC4, ACCESS	; LED is on
#endif
	ENDM

LED_SAMPLE_ON	MACRO
#ifndef	LED_POLARITY_REVERSED
	bcf		LATC, RC3, ACCESS	; LED is on
#else
	bsf		LATC, RC3, ACCESS	; LED is on
#endif
	ENDM

LED_SINE_OFF	MACRO
#ifndef	LED_POLARITY_REVERSED
	bsf		LATA, RA5, ACCESS	; LED is off
#else
	bcf		LATA, RA5, ACCESS	; LED is off
#endif
	ENDM

LED_SQUARE_OFF	MACRO
#ifndef	LED_POLARITY_REVERSED
	bsf		LATC, RC4, ACCESS	; LED is off
#else
	bcf		LATC, RC4, ACCESS	; LED is off
#endif
	ENDM

LED_SAMPLE_OFF	MACRO
#ifndef	LED_POLARITY_REVERSED
	bsf		LATC, RC3, ACCESS	; LED is off
#else
	bcf		LATC, RC3, ACCESS	; LED is off
#endif
	ENDM

LED_SINE_TOGGLE	MACRO
	btg		LATA, RA5, ACCESS	; LED is toggled
	ENDM

LED_SQUARE_TOGGLE	MACRO
	btg		LATC, RC4, ACCESS	; LED is toggled
	ENDM

LED_SAMPLE_TOGGLE	MACRO
	btg		LATC, RC3, ACCESS	; LED is toggled
	ENDM

#endif	; #ifdef LED_STEADY_STATE_DISABLED

#else	; #ifndef THROUGH_HOLE_PCB

#ifdef	LED_STEADY_STATE_DISABLED

LED_SINE_ON	MACRO
#ifndef	LED_POLARITY_REVERSED
	bcf		ledOnOffFlags, RC3, ACCESS	; SINE LED
#else
	bsf		ledOnOffFlags, RC3, ACCESS	; SINE LED
#endif
	ENDM

LED_SQUARE_ON	MACRO
#ifndef	LED_POLARITY_REVERSED
	bcf		ledOnOffFlags, RC4, ACCESS	; SQUARE LED
#else
	bsf		ledOnOffFlags, RC4, ACCESS	; SQUARE LED
#endif
	ENDM

LED_SAMPLE_ON	MACRO
#ifndef	LED_POLARITY_REVERSED
	bcf		ledOnOffFlags, RA5, ACCESS	; SAMPLE LED
#else
	bsf		ledOnOffFlags, RA5, ACCESS	; SAMPLE LED
#endif
	ENDM

LED_SINE_OFF	MACRO
#ifndef	LED_POLARITY_REVERSED
	bsf		ledOnOffFlags, RC3, ACCESS	; SINE LED
#else
	bcf		ledOnOffFlags, RC3, ACCESS	; SINE LED
#endif
	ENDM

LED_SQUARE_OFF	MACRO
#ifndef	LED_POLARITY_REVERSED
	bsf		ledOnOffFlags, RC4, ACCESS	; SQUARE LED
#else
	bcf		ledOnOffFlags, RC4, ACCESS	; SQUARE LED
#endif
	ENDM

LED_SAMPLE_OFF	MACRO
#ifndef	LED_POLARITY_REVERSED
	bsf		ledOnOffFlags, RA5, ACCESS	; SAMPLE LED
#else
	bcf		ledOnOffFlags, RA5, ACCESS	; SAMPLE LED
#endif
	ENDM

LED_SINE_TOGGLE	MACRO
	btg		ledOnOffFlags, RC3, ACCESS	; SINE LED
	ENDM

LED_SQUARE_TOGGLE	MACRO
	btg		ledOnOffFlags, RC4, ACCESS	; SQUARE LED
	ENDM

LED_SAMPLE_TOGGLE	MACRO
	btg		ledOnOffFlags, RA5, ACCESS	; SAMPLE LED
	ENDM
	
#else	; #ifdef LED_STEADY_STATE_DISABLED

LED_SINE_ON	MACRO
#ifndef	LED_POLARITY_REVERSED
	bcf		LATC, RC3, ACCESS	; SINE LED
#else
	bsf		LATC, RC3, ACCESS	; SINE LED
#endif
	ENDM

LED_SQUARE_ON	MACRO
#ifndef	LED_POLARITY_REVERSED
	bcf		LATC, RC4, ACCESS	; SQUARE LED
#else
	bsf		LATC, RC4, ACCESS	; SQUARE LED
#endif
	ENDM

LED_SAMPLE_ON	MACRO
#ifndef	LED_POLARITY_REVERSED
	bcf		LATA, RA5, ACCESS	; SAMPLE LED
#else
	bsf		LATA, RA5, ACCESS	; SAMPLE LED
#endif
	ENDM

LED_SINE_OFF	MACRO
#ifndef	LED_POLARITY_REVERSED
	bsf		LATC, RC3, ACCESS	; SINE LED
#else
	bcf		LATC, RC3, ACCESS	; SINE LED
#endif
	ENDM

LED_SQUARE_OFF	MACRO
#ifndef	LED_POLARITY_REVERSED
	bsf		LATC, RC4, ACCESS	; SQUARE LED
#else
	bcf		LATC, RC4, ACCESS	; SQUARE LED
#endif
	ENDM

LED_SAMPLE_OFF	MACRO
#ifndef	LED_POLARITY_REVERSED
	bsf		LATA, RA5, ACCESS	; SAMPLE LED
#else
	bcf		LATA, RA5, ACCESS	; SAMPLE LED
#endif
	ENDM

LED_SINE_TOGGLE	MACRO
	btg		LATC, RC3, ACCESS	; SINE LED
	ENDM

LED_SQUARE_TOGGLE	MACRO
	btg		LATC, RC4, ACCESS	; SQUARE LED
	ENDM

LED_SAMPLE_TOGGLE	MACRO
	btg		LATA, RA5, ACCESS	; SAMPLE LED
	ENDM

#endif	; #ifdef LED_STEADY_STATE_DISABLED

#endif	; #ifndef THROUGH_HOLE_PCB

LED_SINE_TOGGLE_OTHERS_OFF	MACRO
	LED_SINE_TOGGLE
	LED_SQUARE_OFF
	LED_SAMPLE_OFF
	ENDM

LED_SQUARE_TOGGLE_OTHERS_OFF	MACRO
	LED_SINE_OFF
	LED_SQUARE_TOGGLE
	LED_SAMPLE_OFF
	ENDM

LED_SAMPLE_TOGGLE_OTHERS_OFF	MACRO
	LED_SINE_OFF
	LED_SQUARE_OFF
	LED_SAMPLE_TOGGLE
	ENDM

LED_ALL_TOGGLE	MACRO
	LED_SINE_TOGGLE
	LED_SQUARE_TOGGLE
	LED_SAMPLE_TOGGLE
	ENDM

LED_ALL_ON	MACRO
	LED_SINE_ON
	LED_SQUARE_ON
	LED_SAMPLE_ON
	ENDM

LED_ALL_OFF	MACRO
	LED_SINE_OFF
	LED_SQUARE_OFF
	LED_SAMPLE_OFF
	ENDM

LED_ONLY_SINE_ON	MACRO
	LED_SINE_ON
	LED_SQUARE_OFF
	LED_SAMPLE_OFF
	ENDM

LED_ONLY_SQUARE_ON	MACRO
	LED_SINE_OFF
	LED_SQUARE_ON
	LED_SAMPLE_OFF
	ENDM

LED_ONLY_SAMPLE_ON	MACRO
	LED_SINE_OFF
	LED_SQUARE_OFF
	LED_SAMPLE_ON
	ENDM

#endif	; #ifndef _USERINTERFACEH_

