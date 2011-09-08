
;**********************************************************************
;                                                                     *
;    Project:       deMIDulator                                       *
;    Filename:	    midi.h                                            *
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

#ifndef	_MIDIH_
#define _MIDIH_


; ******************* MIDI SYSEX DEFINES ***********************
#define		VENDOR_ID	0x77
#define		DEVICE_ID	0x1D
#define		TERMINAL_PACKET_COMMAND_VALUE	0x1E

; ******************* MIDI BUFFER SIZES ***********************

#define		MAX_MIDI_MESSAGE_SIZE	24
#define		ACTIVE_NOTE_TABLE_SIZE	25


; ******************* STATUS BYTE DEFINITONS ***********************

; Note that lower nybble (channel) should be masked out for comparison
;------------------------
#define		NOTE_OFF				0x80
#define		NOTE_ON					0x90
#define		KEY_PRESSURE			0xA0
#define		CONTROL_CHANGE			0xB0
#define		PROGRAM_CHANGE			0xC0
#define		CHANNEL_PRESSURE		0xD0
#define		PITCH_WHEEL				0xE0

; Sysex Status Byte Definitions
#define		SYSEX					0xF0
#define		EOX						0xF7

#define		NOTE_OFF_MESSAGE_LENGTH				3
#define		NOTE_ON_MESSAGE_LENGTH		   		3
#define		KEY_PRESSURE_MESSAGE_LENGTH			3
#define		CONTROL_CHANGE_MESSAGE_LENGTH		3
#define		PROGRAM_CHANGE_MESSAGE_LENGTH	 	2
#define		CHANNEL_PRESSURE_MESSAGE_LENGTH	 	2
#define		PITCH_WHEEL_MESSAGE_LENGTH			3

; SysEx Sub Types
;----------------------------
#define		NON_REAL_TIME						0x7E
#define		GENERAL_INFORMATION					0x06
#define		IDENTITY_REQUEST					0x01
#define		IDENTITY_REPLY						0x02

; Control Change Data Types
;----------------------------
#define		BANK_SELECT_MSB						0
#define		MODULATION_WHEEL_MSB				1
#define		BREATH_CONTROLLER_MSB				2
#define		UNDEFINED_003						3
#define		FOOT_CONTROLLER_MSB					4
#define		PORTAMENTO_TIME						5
#define		DATA_ENTRY_MSB						6
#define		CHANNEL_VOLUME_MSB					7
#define		BALANCE_MSB							8
#define		UNDEFINED_MSB						9
#define		PAN_MSB								10
#define		EXPRESSION_MSB						11
#define		EFFECT_CONTROL_1_MSB				12
#define		EFFECT_CONTROL_2_MSB				13
#define		UNDEFINED_014						14
#define		UNDEFINED_015						15
#define		GENERAL_PURPOSE_CONTROLLER_1_MSB	16
#define		GENERAL_PURPOSE_CONTROLLER_2_MSB	17
#define		GENERAL_PURPOSE_CONTROLLER_3_MSB	18
#define		GENERAL_PURPOSE_CONTROLLER_4_MSB	19
#define		UNDEFINED_020						20
#define		UNDEFINED_021						21
#define		UNDEFINED_022						22
#define		UNDEFINED_023						23
#define		UNDEFINED_024						24
#define		UNDEFINED_025						25
#define		UNDEFINED_026						26
#define		UNDEFINED_027						27
#define		UNDEFINED_028						28
#define		UNDEFINED_029						29
#define		UNDEFINED_030						30
#define		UNDEFINED_031						31
#define		BANK_SELECT_LSB						32
#define		MODULATION_WHEEL_LSB				33
#define		BREATH_CONTROLLER_LSB				34
#define		UNDEFINED_035						35
#define		FOOT_CONTROLLER_LSB					36
#define		PORTAMENTO_TIME_LSB					37
#define		DATA_ENTRY_LSB						38
#define		CHANNEL_VOLUME_LSB					39
#define		BALANCE_LSB							40
#define		UNDEFINED_041						41
#define		PAN_LSB								42
#define		EXPRESSION_LSB						43
#define		EFFECT_CONTROL_1_LSB				44
#define		EFFECT_CONTROL_2_LSB				45
#define		UNDEFINED_046						46
#define		UNDEFINED_047						47
#define		GENERAL_PURPOSE_CONTROLLER_1_LSB	48
#define		GENERAL_PURPOSE_CONTROLLER_2_LSB	49
#define		GENERAL_PURPOSE_CONTROLLER_3_LSB	50
#define		GENERAL_PURPOSE_CONTROLLER_4_LSB	51
#define		UNDEFINED_052						52
#define		UNDEFINED_053						53
#define		UNDEFINED_054						54
#define		UNDEFINED_055						55
#define		UNDEFINED_056						56
#define		UNDEFINED_057						57
#define		UNDEFINED_058						58
#define		UNDEFINED_059						59
#define		UNDEFINED_060						60
#define		UNDEFINED_061						61
#define		UNDEFINED_062						62
#define		UNDEFINED_063						63
#define		SUSTAIN_PEDAL						64
#define		PORTAMENTO_ONOFF					65
#define		SOSTENUTO							66
#define		SOFT_PEDAL							67
#define		LEGATO_FOOTSWITCH					68
#define		HOLD_2								69
#define		SOUND_CONTROLLER_1_DEFAULT_SOUND_VARIATION				70
#define		SOUND_CONTROLLER_2_DEFAULT_TIMBRE_HARMONIC_QUALITY		71
#define		SOUND_CONTROLLER_3_DEFAULT_RELEASE_TIME					72
#define		SOUND_CONTROLLER_4_DEFAULT_ATTACK_TIME					73
#define		SOUND_CONTROLLER_5_DEFAULT_BRIGHTNESS					74
#define		SOUND_CONTROLLER_6_GM2_DEFAULT_DECAY_TIME				75
#define		SOUND_CONTROLLER_7_GM2_DEFAULT_VIBRATO_RATE				76
#define		SOUND_CONTROLLER_8_GM2_DEFAULT_VIBRATO_DEPTH			77
#define		SOUND_CONTROLLER_9_GM2_DEFAULT_VIBRATO_DELAY			78
#define		SOUND_CONTROLLER_10_GM2_DEFAULT_UNDEFINED				79
#define		GENERAL_PURPOSE_CONTROLLER_5							80
#define		GENERAL_PURPOSE_CONTROLLER_6							81
#define		GENERAL_PURPOSE_CONTROLLER_7							82
#define		GENERAL_PURPOSE_CONTROLLER_8							83
#define		PORTAMENTO_CONTROL										84
#define		UNDEFINED_85									85
#define		UNDEFINED_86									86
#define		UNDEFINED_87									87
#define		UNDEFINED_88									88
#define		UNDEFINED_89									89
#define		UNDEFINED_90									90
#define		EFFECTS_1_DEPTH_DEFAULT_REVERB_SEND				91
#define		EFFECTS_2_DEPTH_DEFAULT_TREMOLO_DEPTH			92
#define		EFFECTS_3_DEPTH_DEFAULT_CHORUS_SEND				93
#define		EFFECTS_4_DEPTH_DEFAULT_CELESTE_[DETUNE]_DEPTH	94
#define		EFFECTS_5_DEPTH_DEFAULT_PHASER_DEPTH			95
#define		DATA_INCREMENT									96
#define		DATA_DECREMENT									97
#define		NON_REG_PARAMETER_NUMBER_LSB				98
#define		NON_REG_PARAMETER_NUMBER_MSB				99
#define		REGISTERED_PARAMETER_NUMBER_LSB					100
#define		REGISTERED_PARAMETER_NUMBERMSB					101
#define		UNDEFINED_102						102
#define		UNDEFINED_103						103
#define		UNDEFINED_104						104
#define		UNDEFINED_105						105
#define		UNDEFINED_106						106
#define		UNDEFINED_107						107
#define		UNDEFINED_108						108
#define		UNDEFINED_109						109
#define		UNDEFINED_110						110
#define		UNDEFINED_111						111
#define		UNDEFINED_112						112
#define		UNDEFINED_113						113
#define		UNDEFINED_114						114
#define		UNDEFINED_115						115
#define		UNDEFINED_116						116
#define		UNDEFINED_117						117
#define		UNDEFINED_118						118
#define		UNDEFINED_119						119
#define		ALL_SOUND_OFF						120
#define		RESET_ALL_CONTROLLERS				121
#define		LOCAL_CONTROL_ONOFF					122
#define		ALL_NOTES_OFF						123
#define		OMNI_MODE_OFF						124
#define		OMNI_MODE_ON						125
#define		POLY_MODE_OFF						126
#define		POLY_MODE_ON						127


; ******************* MIDI MESSAGE STATES ***********************

#define	CHANNEL						0x00
#define	DATA_BYTE0					0x01
#define	DATA_BYTE1					0x02
#define	MESSAGE_COMPLETE			0xFF

#define	NOTE_COMPLETE				DATA_BYTE1
#define	AFTERTOUCH_COMPLETE			DATA_BYTE1
#define	CONTROL_CHANGE_COMPLETE		DATA_BYTE1
#define	PROGRAM_CHANGE_COMPLETE		DATA_BYTE0
#define	PITCH_WHEEL_COMPLETE		DATA_BYTE1


; ******************* FLAG VARIABLE DEFINITIONS ***********************

; midiFlags (bits 3:7 free for use by other modules)
#define uartState_rxInProgress			0
#define midiState_messageNeedsMapping	1
#define	midiThruModeEnabled				2


#endif
