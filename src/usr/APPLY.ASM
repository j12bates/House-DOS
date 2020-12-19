; ========================================================================
; House-DOS APPLY COMMAND
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
    mov ah, 0x7F                        ; Apply filesystem changes to disk
    int 0x7E

done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

creator         db "House-DOS Developers", 0x00
desc            db "Apply all filesystem changes (DELETE, RENAME).", 0x00
usage           db "APPLY", 0x0A
                db "Flags: none", 0x00