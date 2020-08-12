; ========================================================================
; House-DOS HELP COMMAND
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

    mov si, msgD                        ; Message D
    int 0x7E                            ; Call SYS.BIN

    mov si, msgE                        ; Message E
    int 0x7E                            ; Call SYS.BIN

    mov ah, 0xFF                        ; We're done
    int 0x7E                            ; Call SYS.BIN


data:

msgA        db "====== House-DOS Help ======", 0x00
msgB        db "INFO: Display OS information", 0x00
msgC        db "HELP: Display House-DOS help", 0x00
msgD        db "EXIT: System Reboot", 0x00
msgE        db "QUIT: System Shutdown", 0x00
