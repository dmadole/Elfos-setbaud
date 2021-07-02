This program for Elf/OS changes the baud rate of the serial console. This works with the standard BIOS soft UART, with the nitro soft UART, and probably also with BIOS-supported hardware UARTs (it is designed to, but not tested).

For the soft UARTs, this calculates the appropriate baud rate constant to put into register RE.1. For hardware UARTS it calls the appropriate BIOS routine.

Because for soft UARTS it's necessary to know the clock rate, if your clock is not 4 Mhz, which is what's assumed, you will need to use the -k option to specify your clock frequency in kilohertz. For example, on a system with a PIXIE, you would use something like:

setbaud -k 1790 2400

For hardware UARTs, the -k option is accepted, but not used for anything.

This program could be useful, for example, as the first entry in an INIT.rc file for a system using BIOS soft UART that wants to boot directly into Elf/OS and run at a fixed baud rate. The nitro UART loader provides this natively. It also could be useful to change the baud rate of an already running system for any reason.

