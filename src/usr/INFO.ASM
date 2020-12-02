; ========================================================================
; House-DOS INFO COMMAND
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

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

msg         db "House-DOS v0.0.3 NATE, Build 31; Compiled 2020-11-26", 0x0A
            db "By Jacob, Jet, and Ben", 0x00
