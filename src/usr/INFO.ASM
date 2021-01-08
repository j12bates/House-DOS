; ========================================================================
; House-DOS INFO COMMAND
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; Header
; ========================================================================

header:
    jmp main                            ; Don't execute the header

h_creator       dw creator              ; Creator string
h_desc          dw desc                 ; Description string
h_usage         dw usage                ; Usage string


; ========================================================================
; Main code
; ========================================================================

main:
    mov ah, 0xB0                        ; Get OS Version String
    mov di, data_buffer                 ; Our buffer
    int 0x7E

    mov byte [di-0x01], 0x0A            ; Replace end of string with newline

    mov ah, 0xB1                        ; Get OS Creator String
    int 0x7E

    mov byte [di-0x01], 0x0A            ; Replace end of string with newline

    mov ah, 0xB2                        ; Get CPU brand string
    int 0x7E

    mov ax, 0x4000                      ; Output string
    mov si, data_buffer                 ; Our buffer
    int 0x7E

    mov ah, 0xFF                        ; We're done
    int 0x7E


data:

creator         db "House-DOS Developers", 0x00
desc            db "Show system info.", 0x00
usage           db "INFO", 0x0A
                db "Flags: none", 0x00

data_buffer:
