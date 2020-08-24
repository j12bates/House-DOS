; ========================================================================
; House-DOS KERNEL: MEMORY SUBSYSTEM
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; MEMORY SUBROUTINES
; ========================================================================

clear_file_buffer:                              ; Clear the file buffer (0x10000-0x1FFFF)
    pusha                                       ; Save register states to stack

    mov si, iface_mem_clear
    call print_str                              ; Print message

    mov ax, 0x1000
    mov es, ax                                  ; File buffer segment
    mov di, 0x0000                              ; Start at offset 0

    mov cx, 0xFFFF                              ; Clear every byte
    cld                                         ; Ensure correct direction

    rep stosb                                   ; Move zeroes in (AL is already 0)

    call done                                   ; We've finished

    popa                                        ; Restore register states
    ret                                         ; Return to caller


move_file_bin:                                  ; Load the file buffer as a binary
    pusha                                       ; Save register states to stack

    mov si, iface_mem_bin
    call print_str                              ; Print message

    mov ax, 0x1000
    mov ds, ax                                  ; File buffer segment
    mov si, 0x0000                              ; Start at offset 0

    mov ax, 0x4000
    mov es, ax                                  ; Binary execution segment
    mov di, 0x0000                              ; Start at offset 0

    mov cx, 0xFFFF                              ; Move every byte
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Move all of the bytes into the binary buffer

    call done                                   ; We've finished

    popa                                        ; Restore register states
    ret                                         ; Return to caller


data_binseg:                                    ; Sets the data segment to the binary segment
    push ax                                     ; Save register state to stack

    mov ax, 0x4000
    mov ds, ax                                  ; Segment the binary command is loaded in

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


data_kernseg:                                   ; Sets the data segment to the kernel segment
    push ax                                     ; Save register state to stack

    mov ax, 0x2000
    mov ds, ax                                  ; Segment we are loaded in

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


data_fileseg:                                   ; Sets the data segment to the file buffer segment
    push ax                                     ; Save register state to stack

    mov ax, 0x1000
    mov ds, ax                                  ; Segment the file buffer is at

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


extra_binseg:                                   ; Sets the extra segment to the binary segment
    push ax                                     ; Save register state to stack

    mov ax, 0x4000
    mov es, ax                                  ; Segment the binary command is loaded in

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


extra_kernseg:                                  ; Sets the extra segment to the kernel segment
    push ax                                     ; Save register state to stack

    mov ax, 0x2000
    mov es, ax                                  ; Segment we are loaded in

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


extra_fileseg:                                  ; Sets the extra segment to the file buffer segment
    push ax                                     ; Save register state to stack

    mov ax, 0x1000
    mov es, ax                                  ; Segment the file buffer is at

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


; ========================================================================
; DATA SECTION
; ========================================================================

mem_data:


iface_mem_clear     db "Clearing file buffer...", 0x00
iface_mem_bin       db "Loading file into binary buffer...", 0x00
