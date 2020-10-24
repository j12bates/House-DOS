# House-DOS
A real-mode x86 Disk Operating System that is, and forever will be, mostly useless. I endorse use of this operating system, but before installing it on bare metal, I would recommend backing all your files up, unplugging your hard drives, and plugging in a new one.

## Instructions for Use:
You will need the Netwide Assembler (NASM).
1. Create a disk image by running `BUILD.SH` as root.
2. Virtualize as an HDD in QEMU, or write to a storage medium greater than 32M and boot to it.

## Creating Programs & Commands:
  House-DOS commands are written in real-mode x86 assembly. There are many different system calls available for many specific tasks; here are a few examples:
- Printing characters to the console
- Getting input from the console
- Getting the time
- Converting different forms of notation
- Loading and writing files
- Getting properties of a file
- Generating pseudo-random numbers
- Playing tones on the PC speaker

A full and complete reference can be found in `docs/SYSCALL.TXT`. System calls are always being added.

## Features Coming Soon:
Here are some features planned for the next release (v0.0.2), which is in the works:
- Command parameters and flags
- Internal error handling
- Loading files to specific areas of the file buffer
- And much more...
