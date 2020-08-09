# House-DOS
A real-mode x86 Disk Operating System that is, and forever will be, mostly useless. I endorse use of this operating system, but before installing it on bare metal, I would recommend backing all your files up, unplugging your hard drives, and plugging in a new one.

Creating a disk image:
  1. Assemble all source files with NASM.
    a. All output filenames must be fully capitalized and end in `.BIN`.
    b. `SYS.ASM` should output into `SYS.BIN`.
    c. `BOOT.ASM` should output into `BOOT.BIN`.
    d. Other than that, you can rename any files if you desire.
  2. Create a blank image: `dd if=/dev/zero of=House-DOS.img iflag=fullblock bs=512 count=65536`
  3. Write the bootloader to the bootsector of the image: `dd if=BOOT.BIN of=House-DOS.img conv=notrunc`
  4. Mount the image as a loop device: `sudo losetup loop0 House-DOS.img`
  5. Copy all the assembled source files to the device. (Except `BOOT.BIN`)
  6. Unmount the loop device: `sudo losetup -d /dev/loop0`
