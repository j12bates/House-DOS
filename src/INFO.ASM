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
    mov si, msgA                        ; Message A
    int 0x7E                            ; Call SYS.BIN

    mov si, msgB                        ; Message B
    int 0x7E                            ; Call SYS.BIN

    mov si, msgC                        ; Message C
    int 0x7E                            ; Call SYS.BIN

    mov ah, 0xFF                        ; We're done
    int 0x7E                            ; Call SYS.BIN

data:

msgA        db "House-DOS v0.0.1 NATE, Build 18", 0x00
msgB        db "By Jacob and Jet", 0x00
msgC        db "Compiled 2020-09-28", 0x00
