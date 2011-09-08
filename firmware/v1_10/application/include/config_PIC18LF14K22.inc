
;**********************************************************************
;                                                                     *
;    Project:       deMIDulator                                       *
;    Filename:	    config_PIC18LF14K22.inc                           *
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

#ifndef CONFIG_INC
#define CONFIG_INC

;==========================================================================
;
;   IMPORTANT: For the PIC18 devices, the __CONFIG directive has been
;              superseded by the CONFIG directive.  The following settings
;              are available for this device.
;
;   Oscillator Selection bits:
;     FOSC = LP            LP oscillator
;     FOSC = XT            XT oscillator
;     FOSC = HS            HS oscillator
;     FOSC = ERCCLKOUT     External RC oscillator, CLKOUT function on OSC2
;     FOSC = ECCLKOUTH     EC, CLKOUT function on OSC2 (high)
;     FOSC = ECH           EC (high)
;     FOSC = ERC           External RC oscillator
;     FOSC = IRC           Internal RC oscillator
;     FOSC = IRCCLKOUT     Internal RC oscillator, CLKOUT function on OSC2
;     FOSC = ECCLKOUTM     EC, CLKOUT function on OSC2 (medium)
;     FOSC = ECM           EC (medium)
;     FOSC = ECCLKOUTL     EC, CLKOUT function on OSC2 (low)
;     FOSC = ECL           EC (low)
	CONFIG FOSC = IRC

;
;   4 X PLL Enable bit:
;     PLLEN = OFF          PLL is under software control
;     PLLEN = ON           Oscillator multiplied by 4
	CONFIG PLLEN = OFF

;
;   Primary Clock Enable bit:
;     PCLKEN = OFF         Primary clock is under software control
;     PCLKEN = ON          Primary clock enabled
	CONFIG PCLKEN = ON

;
;   Fail-Safe Clock Monitor Enable:
;     FCMEN = OFF          Fail-Safe Clock Monitor disabled
;     FCMEN = ON           Fail-Safe Clock Monitor enabled
	CONFIG FCMEN = OFF

;
;   Internal/External Oscillator Switchover bit:
;     IESO = OFF           Oscillator Switchover mode disabled
;     IESO = ON            Oscillator Switchover mode enabled
	CONFIG IESO = ON

;
;   Power-up Timer Enable bit:
;     PWRTEN = ON          PWRT enabled
;     PWRTEN = OFF         PWRT disabled
	; must be disabled for hardware debugging
	CONFIG PWRTEN = OFF

;
;   Brown-out Reset Enable bits:
;     BOREN = OFF          Brown-out Reset disabled in hardware and software
;     BOREN = ON           Brown-out Reset enabled and controlled by software (SBOREN is enabled)
;     BOREN = NOSLP        Brown-out Reset enabled in hardware only and disabled in Sleep mode (SBOREN is disabled)
;     BOREN = SBORDIS      Brown-out Reset enabled in hardware only (SBOREN is disabled)
	CONFIG BOREN = ON

;
;   Brown Out Reset Voltage bits:
;     BORV = 30            VBOR set to 3.0 V nominal
;     BORV = 27            VBOR set to 2.7 V nominal
;     BORV = 22            VBOR set to 2.2 V nominal
;     BORV = 19            VBOR set to 1.9 V nominal
	CONFIG BORV = 19

;
;   Watchdog Timer Enable bit:
;     WDTEN = OFF          WDT is controlled by SWDTEN bit of the WDTCON register
;     WDTEN = ON           WDT is always enabled. SWDTEN bit has no effect.
	CONFIG WDTEN = OFF

;
;   Watchdog Timer Postscale Select bits:
;     WDTPS = 1            1:1
;     WDTPS = 2            1:2
;     WDTPS = 4            1:4
;     WDTPS = 8            1:8
;     WDTPS = 16           1:16
;     WDTPS = 32           1:32
;     WDTPS = 64           1:64
;     WDTPS = 128          1:128
;     WDTPS = 256          1:256
;     WDTPS = 512          1:512
;     WDTPS = 1024         1:1024
;     WDTPS = 2048         1:2048
;     WDTPS = 4096         1:4096
;     WDTPS = 8192         1:8192
;     WDTPS = 16384        1:16384
;     WDTPS = 32768        1:32768
	CONFIG WDTPS = 1

;
;   MCLR Pin Enable bit:
;     MCLRE = OFF          RA3 input pin enabled; MCLR disabled
;     MCLRE = ON           MCLR pin enabled, RA3 input pin disabled
	CONFIG MCLRE = OFF

;
;   HFINTOSC Fast Start-up bit:
;     HFOFST = OFF         The system clock is held off until the HFINTOSC is stable.
;     HFOFST = ON          HFINTOSC starts clocking the CPU without waiting for the oscillator to stablize.
	CONFIG HFOFST = OFF

;
;   Stack Full/Underflow Reset Enable bit:
;     STVREN = OFF         Stack full/underflow will not cause Reset
;     STVREN = ON          Stack full/underflow will cause Reset
	CONFIG STVREN = ON

;
;   Single-Supply ICSP Enable bit:
;     LVP = OFF            Single-Supply ICSP disabled
;     LVP = ON             Single-Supply ICSP enabled
	CONFIG LVP = OFF

;
;   Boot Block Size Select bit:
;     BBSIZ = OFF          1kW boot block size
;     BBSIZ = ON           2kW boot block size
; PIC18LF13K50 sets this option to 'ON' for required 1kW block size 
	CONFIG BBSIZ = OFF

;
;   Extended Instruction Set Enable bit:
;     XINST = OFF          Instruction set extension and Indexed Addressing mode disabled (Legacy mode)
;     XINST = ON           Instruction set extension and Indexed Addressing mode enabled
	CONFIG XINST = OFF

;
;   Background Debugger Enable bit:
;     DEBUG = ON           Background debugger enabled, RA0 and RA1 are dedicated to In-Circuit Debug
;     DEBUG = OFF          Background debugger disabled, RA0 and RA1 configured as general purpose I/O pins
	CONFIG DEBUG = ON
	
;
;   Code Protection bit:
;     CP0 = ON             Block 0 code-protected
;     CP0 = OFF            Block 0 not code-protected
	CONFIG CP0 = OFF

;
;   Code Protection bit:
;     CP1 = ON             Block 1 code-protected
;     CP1 = OFF            Block 1 not code-protected
	CONFIG CP1 = OFF
	
;
;   Boot Block Code Protection bit:
;     CPB = ON             Boot block code-protected
;     CPB = OFF            Boot block not code-protected
	CONFIG CPB = OFF

;
;   Data EEPROM Code Protection bit:
;     CPD = ON             Data EEPROM code-protected
;     CPD = OFF            Data EEPROM not code-protected
	CONFIG CPD = OFF

;
;   Write Protection bit:
;     WRT0 = ON            Block 0 write-protected
;     WRT0 = OFF           Block 0 not write-protected
	CONFIG WRT0 = OFF
	
;
;   Write Protection bit:
;     WRT1 = ON            Block 1 write-protected
;     WRT1 = OFF           Block 1 not write-protected
	CONFIG WRT1 = OFF

;
;   Boot Block Write Protection bit:
;     WRTB = ON            Boot block write-protected
;     WRTB = OFF           Boot block not write-protected
	CONFIG WRTB = OFF

;
;   Configuration Register Write Protection bit:
;     WRTC = ON            Configuration registers write-protected
;     WRTC = OFF           Configuration registers not write-protected
	CONFIG WRTC = OFF

;
;   Data EEPROM Write Protection bit:
;     WRTD = ON            Data EEPROM write-protected
;     WRTD = OFF           Data EEPROM not write-protected
	CONFIG WRTD = OFF

;
;   Table Read Protection bit:
;     EBTR0 = ON           Block 0 protected from table reads executed in other blocks
;     EBTR0 = OFF          Block 0 not protected from table reads executed in other blocks
	CONFIG EBTR0 = OFF

;
;   Table Read Protection bit:
;     EBTR1 = ON           Block 1 protected from table reads executed in other blocks
;     EBTR1 = OFF          Block 1 not protected from table reads executed in other blocks
	CONFIG EBTR1 = OFF

;
;   Boot Block Table Read Protection bit:
;     EBTRB = ON           Boot block protected from table reads executed in other blocks
;     EBTRB = OFF          Boot block not protected from table reads executed in other blocks
	CONFIG EBTRB = OFF

;
;==========================================================================

#endif
