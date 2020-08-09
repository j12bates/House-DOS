; ========================================================================
; House-DOS KERNEL
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; MAIN ROUTINE
; ========================================================================

start:                                          ; Startup code for HouseDOS kernel
    mov bx, 0x2000                              ; The segment in which we are
    mov ds, bx

    cmp ah, 0x00                                ; Have we just now been loaded?
    jne main                                    ; If not, don't initialize again

.init:
    mov bx, 0x07C0
    mov es, bx                                  ; The segment in which the bootloader is

    mov byte [drive_num], dl                    ; Save our boot drive number
    mov word [root_start], ax                   ; Save the start of the root directory

    mov ax, word [es:0x000B]
    mov word [bytes_sector], ax                 ; Save the number of bytes per sector

    mov al, byte [es:0x000D]
    mov byte [sectors_cluster], al              ; Save the number of sectors per cluster

    mov ax, word [es:0x0011]
    mov word [root_entries], ax                 ; Save the number of root entries

    mov ax, word [es:0x0018]
    mov word [sectors_track], ax                ; Save the sectors per track

    mov ax, word [es:0x001A]
    mov word [heads], ax                        ; Save the number of heads

    call clear                                  ; Clear screen

    mov ax, 0x1003                              ; Configure attribute bit 7
    mov bl, 0x01                                ; Blink
    int 0x10                                    ; BIOS VGA interrupt

    mov si, iface_welcome
    call println                                ; Print welcome message

    mov si, iface_info
    call println                                ; Print info

    xor bx, bx                                  ; Make sure that the zero-flag is set


main:                                           ; Main code for HouseDOS kernel
    mov bx, 0x2000
    mov es, bx                                  ; The segment in which we are loaded

    je command                                  ; If we were just loaded, get a command

    cmp ah, 0xFF                                ; Did the last command just finish?
    je command                                  ; If so, get a command

.check_function:                                ; Otherwise, a function was called
    cmp ah, 0x01
    je routines.print                           ; Print String

    cmp ah, 0x02
    je routines.println                         ; Print Line

    cmp ah, 0x03
    je routines.confirm                         ; Ask for confirmation

    ret                                         ; If invalid function number, we're done!


command:                                        ; Main loop: Retrieve command from user
    call line_break                             ; Line break
    call clear_input                            ; Clear input buffer
    call prompt                                 ; Setup prompt
    call input                                  ; Get input from user
    call line_break                             ; Line break
    call line_break                             ; Another line break

    mov si, prompt_response                     ; Read from the input buffer
    mov di, filename                            ; Into the filename
    mov cx, 0x0009                              ; Up to 8 chars in a filename
    cld                                         ; Make sure direction is cleared

.char_filename:
    lodsb                                       ; Load next char

    cmp al, 0x00                                ; Is this a NULL char?
    je .spaces                                  ; If so, that's the end of the filename

    cmp al, 0x20                                ; Is this a SPACE?
    je .params                                  ; If so, that's also the end of the filename

    mov byte [di], al                           ; Otherwise, move this char into our filename
    inc di                                      ; Move pointer forward
    loop .char_filename                         ; Repeat

    jmp .bad_command                            ; There should have been a null/space by now

.params:
    push cx                                     ; Save the loop counter
    pop cx                                      ; Restore the loop counter

.spaces:
    mov byte [di], 0x20                         ; Move a space into the next position
    inc di                                      ; Move pointer forward
    loop .spaces                                ; Repeat

.extension:
    mov si, bin_extension                       ; The extension for a Binary file
    mov di, filename_extension                  ; The extension of the filename
    mov cx, 0x0003                              ; Extension is 3 chars

    rep movsb                                   ; Move into our file extension

.load_file:
    call get_file_cluster                       ; Get the starting cluster for our file
    jc .bad_command                             ; If error, bad command

    call load_file                              ; Load file into our buffer

    mov ax, 0x1000
    mov ds, ax                                  ; The segment our file is loaded in
    mov es, ax

    jmp 0x1000:0x0000                           ; Jump to our loaded binary

.bad_command:
    mov si, iface_command_bad
    call println                                ; Display an error message

    jmp command                                 ; Try again


; ========================================================================
; KERNEL ROUTINES
; ========================================================================

routines:

.print:
    mov ax, 0x1000
    mov ds, ax                                  ; Segment our command is loaded in

    call print_str                              ; Print String

    jmp ret_far                                 ; We're done!

.println:
    mov ax, 0x1000
    mov ds, ax                                  ; Segment our command is loaded in

    call print_str                              ; Print String
    call line_break                             ; Line Break

    jmp ret_far                                 ; We're done!

.confirm:
    call confirm                                ; Ask for confirmation

    pushf                                       ; Save flags
    call line_break                             ; Line break
    popf                                        ; Restore flags

    jmp ret_far                                 ; We're done!


ret_far:                                        ; Return back to command
    mov ax, 0x1000
    mov ds, ax                                  ; The segment our file is loaded in
    mov es, ax

    retf                                        ; Far return


; ========================================================================
; MISCELLANEOUS SUBROUTINES
; ========================================================================

clear_input:                                    ; Clear the input buffer
    pusha                                       ; Push register states to stack

    mov di, prompt_response                     ; Our buffer
    mov cx, end_prompt_buffer-prompt_response   ; Buffer is 1 paragraph long

.zero:
    mov byte [di], 0x00                         ; Write a zero in
    inc di                                      ; Advance the pointer
    loop .zero                                  ; Repeat

.ret:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


confirm:                                        ; Ask the user to confirm
    pusha                                       ; Push register states to stack

    clc                                         ; No error yet
    mov si, iface_confirm
    call print_str                              ; Print message

    mov ah, 0x00                                ; Read from keyboard
    int 0x16                                    ; BIOS keyboard interrupt

    and al, 0b11011111                          ; Capitalize
    cmp al, 0x59                                ; Was Y pressed?
    je .end                                     ; If so, return to caller without error

    stc                                         ; Otherwise, error
    mov ah, 0x0E                                ; Teletype output
    mov bh, 0x00
    mov bl, 0b00000111
    int 0x10                                    ; Display the char we typed

.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ========================================================================
; DISPLAY SUBROUTINES
; ========================================================================

clear:                                          ; Clear screen
    pusha                                       ; Push register states to stack

    mov ah, 0x00                                ; Set video mode
    mov al, 0x03                                ; 80x25
    int 0x10                                    ; BIOS VGA interrupt

    popa                                        ; Restore register states
    ret                                         ; Return to caller


print_str:                                      ; Prints String in SI
    pusha                                       ; Push register states to stack

    mov ah, 0x0E                                ; Teletype output
    mov bh, 0x00

.char:
    lodsb                                       ; Load in next character
    cmp al, 0x00                                ; Is this a null character?
    je .ret                                     ; If so, we're done

    int 0x10                                    ; Otherwise, BIOS VGA interrupt
    jmp .char                                   ; And repeat

.ret:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


println:                                        ; Prints String in SI, then does a line break
    pusha                                       ; Save register states to stack

    call print_str                              ; Print
    call line_break                             ; Line break

    popa                                        ; Restore register states
    ret                                         ; Return to caller


line_break:                                     ; Moves cursor down one line
    pusha                                       ; Push register states to stack

    mov ah, 0x03                                ; Get cursor position
    mov bh, 0x00                                ; Page 0
    int 0x10                                    ; BIOS VGA interrupt

    cmp dh, 0x18                                ; Are we already at the bottom?
    jl .break                                   ; If so, just move the cursor

    mov ah, 0x06                                ; Scroll up
    mov al, 0x01                                ; 1 line
    mov bh, 0b00000111                          ; Light grey
    mov cx, 0x0000                              ; Upper left
    mov dx, 0x1950                              ; Bottom right
    int 0x10                                    ; BIOS VGA interrupt

    mov dh, 0x17                                ; Second-to-last row

.break:
    mov ah, 0x02                                ; Set cursor position
    mov bh, 0x00                                ; Page 0
    inc dh                                      ; One row down
    mov dl, 0x00                                ; Leftmost column
    int 0x10                                    ; BIOS VGA interrupt

    popa                                        ; Restore register states
    ret                                         ; Return to caller


prompt:                                         ; Set up a prompt for the user
    pusha                                       ; Push register states to stack

    mov ah, 0x0E                                ; Teletype output
    mov bh, 0x00                                ; Page 0
    mov bl, 0b00000111                          ; Light grey

    mov al, 0x20                                ; Space
    int 0x10                                    ; BIOS VGA interrupt

    mov al, 0x2D                                ; Hyphen
    int 0x10                                    ; BIOS VGA interrupt

    mov al, 0x20                                ; Space
    int 0x10                                    ; BIOS VGA interrupt

    popa                                        ; Restore register states
    ret                                         ; Return to caller


input:                                          ; Get input from user
    pusha                                       ; Push register states to stack

    mov di, prompt_response                     ; Our buffer for input

.char:
    mov ah, 0x00                                ; Get keyboard input
    int 0x16                                    ; BIOS keyboard interrupt

    cmp al, 0x0D                                ; Was the RETURN key pressed?
    je .ret                                     ; If so, we're done

    cmp di, prompt_response+0x10                ; Have we exhausted our 16-byte buffer?
    jge .char                                   ; If so, don't continue

    mov ah, 0x0E                                ; Teletype output
    mov bh, 0x00                                ; Page 0
    mov bl, 0b00000111                          ; Light grey
    int 0x10                                    ; BIOS VGA interrupt (print the char)

    and al, 0b11011111                          ; Capitalize
    mov byte [di], al                           ; Store this char in our buffer
    inc di                                      ; Advance the pointer

    jmp .char                                   ; Repeat

.ret:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ========================================================================
; DISK SUBROUTINES
; ========================================================================

get_file_cluster:                               ; Get the starting cluster of a file
    pusha                                       ; Push register states to stack
    push es                                     ; Save segment

.search_init:
    mov si, iface_disk_search
    call println                                ; Print message

    mov ax, 0x3800
    mov es, ax                                  ; Segment the root directory is at
    mov di, 0x0000                              ; Start at offset 0

    mov cx, word [root_entries]                 ; Number of entries to look through

.check_entry:
    push cx                                     ; Save the number of remaining entries

    mov cx, 0x000B                              ; Compare the first 11 bytes
    mov si, filename                            ; Compare against the filename requested
    push di                                     ; Save our location

    repe cmpsb                                  ; Compare!

    pop di                                      ; Restore our location
    pop cx                                      ; Restore the remaining entries

    je .done                                    ; If equal, we found the entry

    add di, 0x0020                              ; Otherwise, move pointer to next entry
    loop .check_entry                           ; And repeat

    jmp .error_nf                               ; If gone through everything, error

.done:
    mov si, iface_disk_found
    call println                                ; Print message

    mov ax, word [es:di+0x1A]
    mov word [cluster], ax                      ; The starting cluster number
    clc                                         ; No error

.end:
    pop es                                      ; Restore segment
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.error_nf:
    mov si, iface_disk_nf
    call println                                ; Print message

    stc                                         ; Carry flag for error
    jmp .end                                    ; We're done


load_file:                                      ; Load file starting at cluster into buffer
    pusha                                       ; Push register states to stack

.load_cluster:
    mov si, iface_disk_cluster
    call println                                ; Print message

    mov ax, word [cluster]                      ; Our cluster number
    sub ax, 0x0002                              ; Clusters begin at 2
    mul byte [sectors_cluster]                  ; Multiply to get sector number
    add ax, word [root_start]                   ; Add start of root directory
    add ax, 0x0020                              ; Root directory is 32 sectors
    call calc_chs_ls                            ; Convert to CHS

    mov ax, 0x1000
    mov es, ax                                  ; Load file into this segment
    mov bx, word [buffer_pointer]               ; At this offset

    mov ah, 0x02                                ; Read disk sectors
    mov al, byte [sectors_cluster]              ; 1 cluster

    int 0x13                                    ; BIOS disk interrupt
    jnc .next_cluster                           ; If no error, set up for next cluster

    call reset_disk                             ; Otherwise, reset the disk

    mov ah, 0x02                                ; Read disk sectors
    mov al, byte [sectors_cluster]              ; 1 cluster
    int 0x13                                    ; BIOS disk interrupt
    jc .error_read                              ; Error

.next_cluster:
    mov si, word [cluster]                      ; Our cluster number
    shl si, 0x1                                 ; There are two bytes per entry in FAT16

    push ds                                     ; Save our segment

    mov ax, 0x3000
    mov ds, ax                                  ; Segment where the FAT is loaded

    mov ax, word [ds:si]                        ; DS:SI is pointing to the FAT entry

    pop ds                                      ; Restore segment
    mov word [cluster], ax                      ; That entry contained our next cluster

    cmp ax, 0xFFF8                              ; Is this the end of the file?
    jae .done                                   ; If so, we're finished

    mov ax, word [bytes_sector]
    mul word [sectors_cluster]
    add word [buffer_pointer], ax               ; Advance pointer by one cluster

    jmp .load_cluster                           ; Load next cluster

.done:
    mov si, iface_done
    call println                                ; Print message

    clc                                         ; No error

.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.error_read:
    mov si, iface_disk_eread
    call println                                ; Print message

    stc                                         ; Carry flag for error
    jmp .end                                    ; We're done


calc_chs_ls:                                    ; Setup Cylinder-Head-Sector from LBA (AX)
    mov dx, 0x0000
    div word [sectors_track]
    mov cl, dl
    inc cl                                      ; Sector number

    mov dx, 0x0000
    div word [heads]
    mov dh, dl                                  ; The remainder is the head number
    mov ch, al                                  ; The quotient is the cylinder number

    mov dl, byte [drive_num]                    ; Drive number
    ret                                         ; Return to caller

reset_disk:                                     ; Reset the disk
    push ax                                     ; Push register states to stack

    mov si, iface_disk_reset
    call print_str                              ; Print message

    mov ah, 0x00                                ; Reset disk
    mov dl, byte [drive_num]

    int 0x13                                    ; BIOS disk interrupt
    jc reboot_fatal                             ; If there was an error, reboot
    
    pop ax                                      ; Otherwise, restore register states
    ret                                         ; Return to caller


; ========================================================================
; ERROR SUBROUTINES
; ========================================================================

reboot_fatal:
    mov si, iface_fatal_reboot
    call print_str                              ; Print message

    mov ah, 0x00                                ; Read from keyboard buffer
    int 0x16                                    ; BIOS keyboard interrupt

    int 0x19                                    ; Reboot


; ========================================================================
; DATA SECTION
; ========================================================================

data:

; Storage data region
prompt_response     dq 0x0000000000000000
                    dq 0x0000000000000000
end_prompt_buffer:

; Disk operation data region
filename            db "        "
filename_extension  db "   "

bin_extension       db "BIN"
hob_extension       db "HOB"

drive_num           db 0x00
cluster             dw 0x0000
buffer_pointer      dw 0x0000
buffer_segment      dw 0x0000

bytes_sector        dw 0x0000
sectors_cluster     db 0x00
root_entries        dw 0x0000
sectors_track       dw 0x0000
heads               dw 0x0000
root_start          dw 0x0000

; Interface strings
iface_welcome       db "House-DOS v0.0.0, Build 4", 0x00
iface_info          db "By Jacob Bates", 0x00
iface_worked        db "This worked!", 0x00
iface_command_bad   db "Bad command", 0x00
iface_confirm       db "Are you sure? Press Y to confirm: ", 0x00
iface_done          db "Done!", 0x00

iface_disk_search   db "Searching root directory...", 0x00
iface_disk_found    db "Found file!", 0x00
iface_disk_cluster  db "Loading cluster...", 0x00
iface_disk_reset    db "Resetting disk...", 0x00
iface_disk_nf       db "FATAL: Specified file not found.", 0x00
iface_disk_eread    db "FATAL: Error while reading disk.", 0x00

iface_fatal_reboot  db "A fatal error was encountered. Press any key to reboot...", 0x00

