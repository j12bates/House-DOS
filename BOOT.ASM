; The HouseDOS Bootloader

    BITS 16

    jmp strict short main
    nop


; BIOS Parameter Block
; This was made to match up with the BPB of a blank 32M image formatted as FAT16.

OEM                 db "HDOSALPH"       ; OEM ID
bytes_sector        dw 0x0200           ; Number of bytes per sector (DO NOT CHANGE)
sectors_cluster     db 0x04             ; Number of sectors per cluster
reserved            dw 0x0001           ; Number of sectors reserved for bootsector
fats                db 0x02             ; Number of FAT copies
root_entries        dw 0x0200           ; Max number of root entries (DO NOT CHANGE)
sectors             dw 0x0000           ; Number of sectors in volume (small)
media_type          db 0xF8             ; Media descriptor
sectors_fat         dw 0x0040           ; Number of sectors per FAT
sectors_track       dw 0x0020           ; Number of sectors per Track (It's a LIE)
heads               dw 0x0040           ; Number of heads (It's a LIE)
sectors_hidden      dd 0x00000000       ; Number of hidden sectors
sectors_large       dd 0x00010000       ; Number of sectors in volume (large)
drive_num           db 0x80             ; Drive number
                    db 0x00             ; Reserved byte
extended_sig        db 0x29             ; Next three fields are available
serial              dd 0x688B221B       ; Volume serial number
label               db "NATE       "    ; Volume label
filesystem          db "FAT16   "       ; Volume filesystem type


; Main bootloader code

main:
    mov ax, 0x07C0                      ; Segment we're loaded at
    mov ds, ax
    add ax, 0x0020                      ; 32-paragraph bootloader
    mov ss, ax
    mov sp, 0x1000                      ; 4K stack

    mov byte [boot_drive_num], dl       ; Save boot drive number

    mov ah, 0x08                        ; Read disk geometry
    int 0x13                            ; BIOS disk interrupt

    mov dl, dh
    mov dh, 0x00
    inc dl
    mov word [heads], dx                ; The true number of heads

    mov ch, 0x00
    and cl, 0x3F
    mov word [sectors_track], cx        ; The true number of sectors per track

.load_fat:
    mov si, msg_load
    call print_str                      ; Print message

    mov ax, 0x3000
    mov es, ax                          ; Load FAT into this segment
    mov bx, 0x0000

    mov ax, word [reserved]             ; First sector of FAT 1
    call calc_chs_ls                    ; Convert to CHS address
    mov ax, word [sectors_fat]          ; Read the entire FAT
    mov ah, 0x02                        ; Read disk sectors

    int 0x13                            ; BIOS disk interrupt
    jnc .load_root                      ; If no error, load the root directory
    
    jmp reboot                          ; Otherwise, reboot

.load_root:
    mov si, msg_load
    call print_str                      ; Print message

    mov ax, 0x3800
    mov es, ax                          ; Load root directory into this segment

    call calc_root_start                ; First sector of root directory
    call calc_chs_ls                    ; Convert to CHS address
    mov ah, 0x02                        ; Read disk sectors
    mov al, 0x20                        ; Root directory is 32 sectors (512/512 = 1)

    int 0x13                            ; BIOS disk interrupt
    jnc .search_init                    ; If no error, begin searching

    call reset_disk                     ; Otherwise, reset the disk

    mov ah, 0x02                        ; Read disk sectors
    mov al, 0x20                        ; Root directory is 32 sectors (512/512 = 1)
    int 0x13                            ; BIOS disk interrupt
    jc reboot                           ; If error, reboot

.search_init:
    mov si, msg_search_root
    call print_str                      ; Print message

    mov ax, 0x07C0
    mov ds, ax                          ; The segment we are loaded at

    mov ax, 0x3800
    mov es, ax                          ; The segment the root directory is loaded at
    mov di, 0x0000                      ; Offset 0

    mov cx, word [root_entries]         ; Number of entries to look through

.check_entry:
    push cx                             ; Save this to stack

    mov cx, 0x000B                      ; Compare the first 11 bytes
    mov si, kern_filename               ; This should be the filename
    push di                             ; Save our location

    repe cmpsb                          ; Compare!

    pop di                              ; Restore our location
    pop cx                              ; Restore the remaining entries

    je .found_entry                     ; If the filenames are the same, we found the entry!

    add di, 0x0020                      ; Otherwise, move to next entry
    loop .check_entry                   ; And repeat

    jmp reboot_fatal                    ; If we've gone through everything, it's missing
    
.found_entry:
    mov ax, word [es:di+0x1A]
    mov word [cluster], ax              ; The starting cluster number

.load_cluster:
    mov si, msg_load_cluster
    call print_str                      ; Print message

    mov ax, word [cluster]              ; Our cluster number
    sub ax, 0x0002                      ; Clusters begin at #2
    mul byte [sectors_cluster]          ; Multiply by number of sectors
    mov dx, ax                          ; Save in DX

    call calc_root_start                ; Start of root directory
    add ax, 0x20                        ; Root directory is 32 sectors
    add ax, dx                          ; Add to the number of sectors

    call calc_chs_ls                    ; Convert this Logical sector to CHS

    mov ax, 0x2000
    mov es, ax                          ; Load the kernel into this segment
    mov bx, word [buffer_pointer]       ; At this offset
    mov ah, 0x02                        ; Read disk sectors
    mov al, byte [sectors_cluster]      ; 1 cluster

    int 0x13                            ; BIOS disk interrupt
    jnc .next_cluster                   ; If no error, set up for the next cluster

    call reset_disk                     ; Otherwise, reset the disk

    mov ah, 0x02                        ; Read disk sectors
    mov al, byte [sectors_cluster]      ; 1 cluster
    int 0x13                            ; Try again
    jc reboot                           ; If failed again, reboot

.next_cluster:
    mov si, word [cluster]              ; Our cluster number
    shl si, 0x1                         ; There are two bytes per entry in FAT16

    push ds                             ; Save our data segment

    mov ax, 0x3000
    mov ds, ax                          ; Segment where the FAT is loaded

    mov ax, word [ds:si]                ; DS:SI is pointing to the FAT entry

    pop ds                              ; Return to the segment we are loaded in
    mov word [cluster], ax              ; The entry contains our next cluster

    cmp ax, 0xFFF8                      ; Is this the end of the file?
    jae .jump                           ; If so, we are ready to jump!

    mov ax, 0x0200
    mul word [sectors_cluster]
    add word [buffer_pointer], ax       ; Advance pointer by one cluster

    jmp .load_cluster                   ; If not, load next cluster

.jump:
    mov si, msg_ready
    call print_str                      ; Print message

    mov ah, 0x00                        ; Wait and read from keyboard
    int 0x16                            ; BIOS keyboard interrupt

    mov dl, byte [boot_drive_num]       ; Provide the drive number to the kernel

    jmp 0x2000:0x0000                   ; Jump!

    
; Calculation routines

calc_root_start:                        ; Calculate the first sector of the root directory
    push dx                             ; Push register states to stack

    mov ax, word [sectors_fat]          ; Start with the number of sectors per FAT
    mov dh, 0x00
    mov dl, byte [fats]
    mul dx                              ; Multiply by the number of FATs
    add ax, word [reserved]             ; Add the number of reserved sectors
    
    pop dx                              ; Restore register states
    ret                                 ; Return to caller

calc_chs_ls:                            ; Setup Cylinder-Head-Sector from LBA (AX)
    mov dx, 0x0000
    div word [sectors_track]
    mov cl, dl
    inc cl                              ; Sector number

    mov dx, 0x0000
    div word [heads]
    mov dh, dl                          ; The remainder is the head number
    mov ch, al                          ; The quotient is the cylinder number
    
    mov dl, byte [boot_drive_num]       ; Drive number
    ret                                 ; Return to caller


; Other routines

print_str:                              ; Print string in SI
    pusha                               ; Push register states to stack

    mov ax, 0x07C0
    mov ds, ax                          ; Segment in which we are loaded

    ;mov ah, 0x86
    ;mov cx, 0x000D
    ;int 0x15

    mov ah, 0x0E                        ; Teletype output
    mov bh, 0x00                        ; Page 0

.char:
    lodsb                               ; Load next character
    cmp al, 0x00                        ; Is it a NULL character?
    je .end                             ; If so, we are done

    int 0x10                            ; Otherwise, BIOS VGA interrupt
    jmp .char                           ; Repeat

.end:
    mov ah, 0x03                        ; Get cursor position
    int 0x10                            ; BIOS VGA interrupt

    mov ah, 0x02                        ; Set cursor position
    inc dh                              ; One row down
    mov dl, 0x00                        ; Far left
    int 0x10                            ; BIOS VGA interrupt

    popa                                ; Restore register states
    ret                                 ; Return to caller

reset_disk:                             ; Reset the disk
    push ax                             ; Push register states to stack

    mov si, msg_retrying
    call print_str                      ; Print message

    mov ah, 0x00                        ; Reset disk
    mov dl, byte [boot_drive_num]

    int 0x13                            ; BIOS disk interrupt
    jc reboot_fatal                     ; If there was an error, reboot
    
    pop ax                              ; Otherwise, restore register states
    ret                                 ; Return to caller

reboot_fatal:                           ; Display FATAL
    mov si, msg_fatal
    call print_str                      ; Print message

reboot:                                 ; Prompt user to press a key and reboot
    mov si, msg_reboot
    call print_str                      ; Print message

    mov si, msg_ready
    call print_str                      ; Print message

    mov ah, 0x00                        ; Wait and read from keyboard
    int 0x16                            ; BIOS keyboard interrupt

    int 0x19                            ; Reboot


; Data

data:

cluster             dw 0x0000
buffer_pointer      dw 0x0000
boot_drive_num      db 0x00

msg_retrying        db "R", 0x00
msg_fatal           db "F", 0x00
msg_reboot          db "X", 0x00
msg_search_root     db "Srch", 0x00
msg_load_cluster    db "Clstr", 0x00
msg_ready           db "GO", 0x00
msg_load            db "Press a key", 0x00

kern_filename       db "SYS     BIN"


times 510-($-$$)    db 0x00             ; Pad remainder of bootsector with zeroes
boot_sig            dw 0xAA55           ; Boot signature

