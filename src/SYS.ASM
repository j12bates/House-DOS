; ========================================================================
; House-DOS KERNEL
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; MAIN ROUTINE
; ========================================================================

start:                                          ; House-DOS code
    push bx                                     ; Save register state to stack
    mov bx, 0x2000
    mov ds, bx                                  ; The segment in which we are

    cmp ah, 0x00                                ; Have we just now been loaded?
    jne main                                    ; If not, don't initialize again

.init:                                          ; Startup code for House-DOS kernel
    mov bx, 0x07C0
    mov es, bx                                  ; The segment in which the bootloader is

    mov word [root_start], ax                   ; Save the start of the root directory

    mov ax, word [es:0x000B]
    mov word [bytes_sector], ax                 ; Save the number of bytes per sector

    mov al, byte [es:0x000D]
    mov byte [sectors_cluster], al              ; Save the number of sectors per cluster

    mov ax, word [es:0x000E]
    mov word [reserved], ax                     ; Save the number of reserved sectors

    mov al, byte [es:0x0010]
    mov byte [fats], al                         ; Save the number of FATs

    mov ax, word [es:0x0011]
    mov word [root_entries], ax                 ; Save the number of root entries

    mov ax, word [es:0x0016]
    mov word [sectors_fat], ax                  ; Save the sectors per FAT

    mov ax, word [es:0x0018]
    mov word [sectors_track], ax                ; Save the sectors per track

    mov ax, word [es:0x001A]
    mov word [heads], ax                        ; Save the number of heads

    mov al, byte [es:0x0024]
    mov byte [drive_num], al                    ; Save our boot drive number

    pop bx                                      ; Take this out of the stack for now
    mov sp, 0x4000                              ; 16K ought to be enough for anyone
    push bx                                     ; Push this back

    mov ax, 0x0000
    mov es, ax                                  ; The IVT is in this segment
    mov di, 0x7E                                ; We will be changing the entry for this interrupt
    shl di, 0x2                                 ; 4 bytes per entry

    mov word [es:di], 0x0000                    ; Handler (kernel) is loaded at offset 0
    mov word [es:di+0x02], 0x2000               ; Segment 0x2000

    call clear                                  ; Clear screen

    mov ax, 0x1003                              ; Configure attribute bit 7
    mov bl, 0x01                                ; Blink
    int 0x10                                    ; BIOS VGA interrupt

    mov si, iface_welcome
    call println                                ; Print welcome message

    mov si, iface_info
    call println                                ; Print info

    xor bx, bx                                  ; Make sure that the zero-flag is set


main:                                           ; Main code for House-DOS kernel
    mov bx, 0x2000
    mov es, bx                                  ; The segment in which we are loaded

    mov bx, 0x1000
    mov fs, bx                                  ; The segment in which files are loaded

    pop bx                                      ; Restore register state

    je command                                  ; If we were just loaded, get a command

    cmp ah, 0xFF                                ; Did the last command just finish?
    je .handback                                ; If so, prepare to get a command

    jmp syscall_handler                         ; OTHERWISE, a system function was called

.handback:
    add sp, 0x0006                              ; Get rid of all the stuff in the stack from INT 0x7E


command:                                        ; Main loop: Retrieve command from user
    call line_break                             ; Line break
    call prompt                                 ; Setup prompt

    mov ax, 0x2000
    mov es, ax                                  ; The segment we're loaded at
    mov di, input_buffer                        ; Our input buffer
    mov cx, 0x0008                              ; Commands are just filenames, which are up to 8 bytes

    call input                                  ; Get input from user
    call line_break                             ; Line break
    call line_break                             ; Another line break

    mov si, input_buffer                        ; Read from the input buffer
    mov di, filename                            ; Into the filename
    mov cx, 0x0009                              ; Up to 8 chars in a filename
    cld                                         ; Ensure correct direction

.char_filename:
    lodsb                                       ; Load next char and advance

    cmp al, 0x00                                ; Is this a NULL char?
    je .spaces                                  ; If so, that's the end of the filename

    cmp al, 0x20                                ; Is this a SPACE?
    je .params                                  ; If so, that's also the end of the filename

    call capitalize_char                        ; Otherwise, capitalize this character

    stosb                                       ; Move this into our filename and advance
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
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Move into our file extension

.load_file:
    call get_file_cluster                       ; Get the starting cluster for our file
    jc .bad_command                             ; If error, bad command

    call clear_file_buffer                      ; Clear the file buffer
    call load_file                              ; Load file into our file buffer
    jc command                                  ; If error, stop here

    call move_file_bin                          ; Move the contents into the binary buffer

    call line_break                             ; Line break between messages and command output

    mov ax, 0x4000
    mov ds, ax                                  ; The segment our file is loaded in
    mov es, ax

    jmp 0x4000:0x0000                           ; Jump to our loaded binary

.bad_command:
    mov si, iface_command_bad
    call println                                ; Display an error message

    jmp command                                 ; Try again


; ========================================================================
; SUBSYSTEMS
; ========================================================================

    %INCLUDE "sys/MEM.ASM"
    %INCLUDE "sys/LOGIC.ASM"
    %INCLUDE "sys/IFACE.ASM"
    %INCLUDE "sys/DISK.ASM"


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
; SYSTEM CALL HANDLER
; ========================================================================

syscall_handler:                                ; System call handler

.iface_funcs:                                   ; Interfacing functions
    cmp ah, 0x01
    je iface_routines.print                     ; Print String

    cmp ah, 0x02
    je iface_routines.println                   ; Print Line

    cmp ah, 0x03
    je iface_routines.confirm                   ; Ask for confirmation

    cmp ah, 0x04
    je iface_routines.input                     ; Get user input

    cmp ah, 0x05
    je iface_routines.line                      ; Line break

    cmp ah, 0x06
    je iface_routines.clear                     ; Clear screen

    cmp ah, 0x10
    je iface_routines.print_bytes               ; Print bytes

    cmp ah, 0x11
    je iface_routines.block                     ; Draw block

.disk_funcs:                                    ; Disk functions
    cmp ah, 0x60
    je disk_routines.verify                     ; Verify file

    cmp ah, 0x61
    je disk_routines.load                       ; Load file

    cmp ah, 0x62
    je disk_routines.get_bytes_qty              ; Get quantity of bytes from file

    cmp ah, 0x63
    je disk_routines.get_bytes_indexes          ; Get bytes between two indexes

    cmp ah, 0x68
    je disk_routines.write_bytes_qty            ; Write quantity of bytes to file

    cmp ah, 0x69
    je disk_routines.write_bytes_indexes        ; Write bytes between two indexes to file

    cmp ah, 0x6E
    je disk_routines.clear_buffer               ; Clear entire file buffer

    cmp ah, 0x6F
    je disk_routines.write                      ; Write file to disk

    cmp ah, 0x70
    je disk_routines.get_file_size              ; Verify and get size of file

.general_funcs:                                 ; General functions
    cmp ah, 0xF0
    je general_routines.conv_hex                ; Convert to hexadecimal notation

    cmp ah, 0xF1
    je general_routines.conv_dec_usigned        ; Convert to decimal notation (unsigned)

    cmp ah, 0xF3
    je general_routines.conv_word_dec           ; Convert decimal notation to binary value

    jmp int_ret                                 ; If invalid function number, we're done!


; ========================================================================
; SYSTEM CALL ROUTINES
; ========================================================================

iface_routines:                                 ; Interface functions

.print:
    call data_binseg                            ; We want to access data from the command

    call print_str                              ; Print String

    jmp int_ret                                 ; We're done!

.println:
    call data_binseg                            ; We want to access data from the command

    call print_str                              ; Print String
    call line_break                             ; Line Break

    jmp int_ret                                 ; We're done!

.confirm:
    call confirm                                ; Ask for confirmation

    jmp int_ret.preserve_flags                  ; We're done!

.input:
    call extra_binseg                           ; We want to give data to the command

    call input                                  ; Get input
    call line_break                             ; Line Break

    jmp int_ret                                 ; We're done!

.line:
    call line_break                             ; Line break

    jmp int_ret                                 ; We're done!

.clear:
    call clear                                  ; Clear screen

    jmp int_ret                                 ; We're done!

.print_bytes:
    call data_binseg                            ; We want to access data from the command

    call print_bytes                            ; Print bytes

    jmp int_ret                                 ; We're done!

.block:
    call block                                  ; Draw block

    jmp int_ret                                 ; We're done!


disk_routines:                                  ; Disk functions

.verify:
    call data_binseg                            ; We want to access data from the command

    call conv_x3_83                             ; Convert filename to proper format
    jc int_ret.preserve_flags                   ; If error, we're done

    call get_file_cluster                       ; Search the directory and find the starting cluster

    jmp int_ret.preserve_flags                  ; We're done!

.load:
    call clear_file_buffer                      ; Clear the file buffer
    call load_file                              ; Load the file into the file buffer

    jmp int_ret.preserve_flags                  ; We're done!

.get_bytes_qty:
    call data_fileseg                           ; We want to access data from the file buffer
    call extra_binseg                           ; We want to give data to the command

    push cx                                     ; Save our counter
    rep movsb                                   ; Copy the correct number of bytes
    pop cx                                      ; Restore our counter

    jmp int_ret                                 ; We're done!

.get_bytes_indexes:
    call data_fileseg                           ; We want to access data from the file buffer
    call extra_binseg                           ; We want to give data to the command

    push cx                                     ; Save our counter

    sub cx, si                                  ; Convert index to number of bytes
    rep movsb                                   ; Copy the correct number of bytes

    pop cx                                      ; Restore our counter

    jmp int_ret                                 ; We're done!

.write_bytes_qty:
    call data_binseg                            ; We want to access data from the command
    call extra_fileseg                          ; We want to give data to the file buffer

    push cx                                     ; Save our counter
    rep movsb                                   ; Copy the correct number of bytes
    pop cx                                      ; Restore our counter

    jmp int_ret                                 ; We're done!

.write_bytes_indexes:
    call data_binseg                            ; We want to access data from the command
    call extra_fileseg                          ; We want to give data to the file buffer

    push cx                                     ; Save our counter
    
    sub cx, si                                  ; Convert index to number of bytes
    rep movsb                                   ; Copy the correct number of bytes

    pop cx                                      ; Restore our counter

    jmp int_ret                                 ; We're done!

.clear_buffer:
    call clear_file_buffer                      ; Clear the file buffer

    jmp int_ret                                 ; We're done!

.write:
    call data_binseg                            ; We want to access data from the command

    call conv_x3_83                             ; Convert filename to proper format
    jc int_ret.preserve_flags                   ; If error, we're done

    call write_file                             ; Write file to disk

    jmp int_ret.preserve_flags                  ; We're done!

.get_file_size:
    call data_binseg                            ; We want to access data from the command

    call conv_x3_83                             ; Convert filename to proper format
    jc int_ret.preserve_flags                   ; If error, we're done

    mov al, 0x1C                                ; File size
    call get_file_info                          ; Get item from root directory

    jmp int_ret.preserve_flags                  ; We're done!


general_routines:                               ; General functions

.conv_hex:
    call extra_binseg                           ; We want to give data to the command

    xchg ax, dx                                 ; Function takes arg in AX, we have it in DX
    call conv_word_hex                          ; Do the conversion
    xchg dx, ax                                 ; Put everything back the way it was

    jmp int_ret                                 ; We're done!

.conv_dec_usigned:
    call extra_binseg                           ; We want to give data to the command

    xchg ax, dx                                 ; Function takes arg in AX, we have it in DX
    call conv_word_dec_unsigned                 ; Do the conversion
    xchg dx, ax                                 ; Put everything back the way it was

    jmp int_ret                                 ; We're done!

.conv_word_dec:
    call data_binseg                            ; We want to access data from command

    call conv_dec_unsigned_word                 ; Convert to binary value

    jmp int_ret.preserve_flags                  ; We're done!


int_ret:                                        ; Return back to command
    push ax                                     ; Save register state to stack
    mov ax, 0x4000
    mov ds, ax                                  ; The segment our command is loaded in
    mov es, ax
    pop ax                                      ; Restore register state
    
.ret:
    iret                                        ; Interrupt return

.preserve_flags:
    mov word [register_bckp_a], ax
    mov word [register_bckp_b], bx              ; Save register states to backup

    pop ax                                      ; Pop instruction pointer
    pop bx                                      ; Pop code segment

    inc sp
    inc sp                                      ; Move stack pointer past the FLAGS image

    push bx                                     ; Push code segment
    push ax                                     ; Push instruction pointer

    mov ax, word [register_bckp_a]
    mov bx, word [register_bckp_b]              ; Restore register states

    push ax                                     ; Save register state to stack
    mov ax, 0x4000
    mov ds, ax                                  ; The segment our command is loaded in
    mov es, ax
    pop ax                                      ; Restore register state

    retf                                        ; Far return


; ========================================================================
; DATA SECTION
; ========================================================================

data:

; Storage data region
input_buffer        dq 0x0000000000000000
                    db 0x00

register_bckp_a     dw 0x0000
register_bckp_b     dw 0x0000

; Interface strings
iface_welcome       db "House-DOS v0.0.0, Build 13", 0x00
iface_info          db "By Jacob and Jet", 0x00
iface_command_bad   db "Bad command.", 0x00

iface_fatal_reboot  db "A fatal error was encountered. Press any key to reboot...", 0x00

