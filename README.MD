# House-DOS
A real-mode x86 Disk Operating System that is, and forever will be, mostly useless.
It's written completely in x86 assembler.
***
This was created as a summer project during the 2020 pandemic.
I've been having lots of fun creating it, and hope to continue to take this project further.
***
Special thanks to:
- [Jet Pham](https://github.com/jetpham), for being interested
- [Ben Johnson](https://github.com/benjaminjohnson2204), for helping me fix my logic
- [David Uehara](https://github.com/DavidUehara) and [Derrick](https://github.com/Sabacweave), for being awesome

## Instructions for Use:
You will need the Netwide Assembler (NASM).
1. Create a disk image by running `BUILD.SH` as root.
2. Virtualize as an HDD in QEMU, or write to a storage medium greater than 32M and boot to it.

Alternatively, you can download a disk image from [jetpham.com](http://jetpham.com/Storage/House/House-DOS).

## Creating Programs & Commands:
  House-DOS commands are written in real-mode x86 assembly. There are many different system calls available for many specific tasks; here are a few examples:
- Printing characters to the console
- Getting input from the console
- Getting the time
- Converting different forms of numeric notation
- Loading and writing files
- Getting properties of a file
- Generating pseudo-random numbers
- Playing tones on the PC speaker

A full and complete reference can be found in `docs/SYSCALL.TXT`. System calls are always being added.

## Features Coming Soon:
Here are some features planned for the next release (v0.1.1), which is in the works:
- I/O Buffer
  - New system calls for reading/writing
  - Pipelines & Continuity (`|`)
  - Output Redirection (`>`)
  - File Input (`<`)
  - Basic Device Files
    - Console
    - Longer-Term Memory Buffer
    - Null
  - Updated stock programs
- And much more...

## What I've Learned:
Over the course of creating this project, I've encountered lots and lots of **segmentation errors**.
Basically, since I like to use different 64K segments for different things, I have to change around the segment registers quite a lot...
And it ends up reading to or writing from the wrong memory segment.

The answer? Either don't use segments, or **push** them.

Another thing that helps solve the issue is by making subroutines out of code that is *reused* in some form.
***
Other things I've learned:
- If you implement a major paradigm change and it works straight away, do take a second look, but after that you need not worry.
- Getting a routine to write a file is *very very tricky.*
- Hardware inconsistencies will always be a pain.
