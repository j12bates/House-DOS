; ========================================================================
; HOUSEDOS KERNEL
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; MAIN ROUTINE
; ========================================================================

main:                                           ; Main code for HouseDOS kernel
    mov ax, 0x2000                              ; The segment in which we are loaded
    mov ds, ax
    mov es, ax

    mov byte [drive_num], dl                    ; Save our boot drive number
    call clear                                  ; Clear screen

    mov si, welcome
    call print_str                              ; Print welcome message
    call line_break                             ; Line break

    mov si, info
    call print_str                              ; Print info

    jmp $


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


line_break:                                     ; Moves cursor down one line
    pusha                                       ; Push register states to stack

    mov ah, 0x03                                ; Get cursor position
    mov bh, 0x00                                ; Page 0
    int 0x10                                    ; BIOS VGA interrupt

    cmp dh, 0x18                                ; Are we already at the bottom?
    jle .break                                  ; If so, just move the cursor

    mov ah, 0x07                                ; Scroll down
    mov al, 0x01                                ; 1 line
    mov bh, 0b00000111                          ; Black background, light grey
    mov cx, 0x0000                              ; Upper left
    mov dx, 0x5019                              ; Bottom right
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


; ========================================================================
; DATA SECTION
; ========================================================================

data:

welcome             db "HouseDOS v0.0.0", 0x00
info                db "By Jacob Bates", 0x00
worked              db "This worked!", 0x00
drive_num           db 0x00

