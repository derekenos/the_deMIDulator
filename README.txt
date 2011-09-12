;  
;  [Project Name] : deMIDulator
;
;  [Author] ::::::: Derek Enos
;
;  [Description] ::
;
;    The deMIDulator is a microcontroller-based MIDI synthesizer and lo-fi audio sampler. 
;    Assembly source code is provided for Microchip's PIC18LF13K50 8-bit microcontroller.
;
;    Directory Structure:
;
;    ./README.txt                                      - this file    
;    ./firmware/                                       - firmware source code
;    ./firmware/v#_##/                                 - firmware source code by version
;    ./firmware/v#_##/application/                     - full synthesizer application + bootloader code
;    ./firmware/v#_##/bootloader/                      - bootloader code only, sub-directory structure same as "application"
;    ./firmware/v#_##/application/deMIDulator_v#_##/   - MPLABX project directory
;    ./firmware/v#_##/application/dist/                - redistributable firmware .hex & .syx files
;    ./firmware/v#_##/application/docs/                - firmware documentation
;    ./firmware/v#_##/application/header/              - header files defining constants and macros for specific source code files
;    ./firmware/v#_##/application/include/             - specific device configuration definitions and program memory tables
;    ./firmware/v#_##/application/source/              - all source code Assembly files
;