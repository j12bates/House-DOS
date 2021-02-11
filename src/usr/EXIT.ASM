; ========================================================================
; House-DOS EXIT COMMAND
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
    mov ah, 0xA3                        ; Reboot
    int 0x7E

    mov ah, 0xFF                        ; We're done
    int 0x7E


data:

creator         db "House-DOS Developers", 0x00
desc            db "Reboot the system/proceed with boot process.", 0x00
usage           db "EXIT", 0x00
