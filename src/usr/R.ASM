; ========================================================================
; House-DOS REDIRECTION COMMAND
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
    mov ah, 0xFF                        ; We're done
    int 0x7E


data:

creator         db "House-DOS Developers", 0x00
desc            db "Performs no operations.", 0x00
usage           db "R", 0x00
