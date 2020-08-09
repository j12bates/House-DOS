; ========================================================================
; HOUSEDOS INFO COMMAND
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

    mov ah, 0xFF                        ; We're done
    jmp 0x2000:0x0000                   ; Return control

data:

msgA        db "House-DOS v0.0.0, Build 4", 0x00
msgB        db "Written by Jacob Bates", 0x00
msgC        db "Compiled 2020-8-9", 0x00
