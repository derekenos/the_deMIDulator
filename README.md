The deMIDulator is a microcontroller-based MIDI synthesizer and lo-fi audio sampler.

# Documentation & Design Files

- [Documentation](http://badhandshake.com/demidulator/documentation.html)
- [Schematic](http://badhandshake.com/demidulator/schematic-pcb.html)
- [Bill of Materials / Parts List](http://badhandshake.com/demidulator/bom.html)
- [Laser-cut enclosure design files](http://badhandshake.com/demidulator/enclosure.html)

Assembly source code is provided for the [Microchip PIC18LF13K50 microcontroller](https://octopart.com/search?q=pic18lf13k50&start=0).

```
./firmware/v#_##/application/                     - full synthesizer application + bootloader code
./firmware/v#_##/bootloader/                      - bootloader code only, sub-directory structure same as "application"
./firmware/v#_##/application/deMIDulator_v#_##/   - MPLABX project directory
./firmware/v#_##/application/dist/                - redistributable firmware .hex & .syx files
./firmware/v#_##/application/docs/                - firmware documentation
./firmware/v#_##/application/header/              - header files defining constants and macros for specific source code files
./firmware/v#_##/application/include/             - specific device configuration definitions and program memory tables
./firmware/v#_##/application/source/              - all source code Assembly files
```
