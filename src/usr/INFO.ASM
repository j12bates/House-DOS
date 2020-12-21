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
    mov ah, 0x02                        ; Print line
    mov si, msg                         ; Message A
    int 0x7E

    mov ah, 0xFF                        ; We're done
    int 0x7E

data:

msg             db "House-DOS v0.1 NATE, Build 36; Compiled 2020-12-20", 0x0A
                db "By Jacob, Jet, and Ben", 0x00

creator         db "House-DOS Developers", 0x00
desc            db "Show system info.", 0x00
usage           db "INFO", 0x0A
                db "Flags: none", 0x00
