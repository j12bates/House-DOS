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
    pusha                               ; Push register states to stack
    call 0x2000:0x0000                  ; Call SYS.BIN
    popa                                ; Restore register states

    mov si, msgB                        ; Message B
    pusha                               ; Push register states to stack
    call 0x2000:0x0000                  ; Call SYS.BIN
    popa                                ; Restore register states

    mov si, msgC                        ; Message C
    pusha                               ; Push register states to stack
    call 0x2000:0x0000                  ; Call SYS.BIN
    popa                                ; Restore register states

    mov si, msgD                        ; Message D
    pusha                               ; Push register states to stack
    call 0x2000:0x0000                  ; Call SYS.BIN
    popa                                ; Restore register states

    mov si, msgE                        ; Message E
    pusha                               ; Push register states to stack
    call 0x2000:0x0000                  ; Call SYS.BIN
    popa                                ; Restore register states

    mov ah, 0xFF                        ; We're done
    jmp 0x2000:0x0000                   ; Return control


data:

msgA        db "====== House-DOS Help ======", 0x00
msgB        db "INFO: Display OS information", 0x00
msgC        db "HELP: Display House-DOS help", 0x00
msgD        db "EXIT: System Reboot", 0x00
msgE        db "QUIT: System Shutdown", 0x00
