# House-DOS
A real-mode x86 Disk Operating System that is, and forever will be, mostly useless. I endorse use of this operating system, but before installing it on bare metal, I would recommend backing all your files up, unplugging your hard drives, and plugging in a new one.

Creating a disk image:
  1. Assemble all source files with NASM.
  - All output filenames must be fully capitalized and end in `.BIN`.
  - `SYS.ASM` should output into `SYS.BIN`.
  - `BOOT.ASM` should output into `BOOT.BIN`.
  - Other than that, you can rename any files if you desire.
  2. Create a blank image: `dd if=/dev/zero of=House-DOS.img iflag=fullblock bs=512 count=65536`
  3. Write the bootloader to the bootsector of the image: `dd if=BOOT.BIN of=House-DOS.img conv=notrunc`
  4. Mount the image as a loop device, copy all the assembled source files to the device (Except `BOOT.BIN`), and unmount the loop device.

Creating commands:
  House-DOS commands are written in real-mode x86 assembly. There are a few different system calls available; a reference can be found in `syscall_docs.TXT`. System calls are always being added.
