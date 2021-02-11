; ========================================================================
; House-DOS DATE COMMAND
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
    mov ah, 0xD0                        ; Get UNIX timestamp
    int 0x7E

    mov ax, 0x4050                      ; Output UNIX timestamp as datestamp
    int 0x7E

    mov ax, 0x4120                      ; Advance pointer
    int 0x7E

    mov ax, 0x4051                      ; Output UNIX timestamp as timestamp
    int 0x7E

    mov ah, 0xFF                        ; We're done
    int 0x7E


data:

creator         db "House-DOS Developers", 0x00
desc            db "Utility for displaying time/date.", 0x00
usage           db "DATE", 0x00
