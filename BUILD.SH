# House-DOS build.SH

if test "$(whoami)" != "root" ; then
	echo "Must be root to mount images."
	echo "Try running again using SUDO."
	exit
fi

rm -rf bin
mkdir bin
mkdir bin/usr
cd src || return

echo "Assembling bootloader..."
nasm BOOT.ASM -o ../bin/BOOT.BIN || exit

echo "Compiling kernel..."
nasm SYS.ASM -o ../bin/SYS.BIN || exit

echo "Assembling commands & programs..."

cd usr || return

for i in *.ASM
do
	nasm "$i" -o "../../bin/usr/$(basename "$i" .ASM).BIN" || exit
done

cd ../..

echo "Creating 32M image..."
dd if=/dev/zero of=House-DOS.IMG iflag=fullblock bs=512 count=65536
chmod 777 House-DOS.IMG

echo "Writing bootloader..."
dd if=bin/BOOT.BIN of=House-DOS.IMG conv=notrunc
fatlabel House-DOS.IMG NATE

echo "Mounting image..."
rm -rf tmp
mkdir tmp
mount House-DOS.IMG tmp

echo "Copying kernel..."
cp bin/SYS.BIN tmp/
fatattr +s tmp/SYS.BIN

echo "Copying commands & programs..."
mkdir tmp/BIN/
cp bin/usr/*.BIN tmp/BIN/

echo "Unmounting image..."
umount tmp
rm -rf tmp

echo "Finished."
