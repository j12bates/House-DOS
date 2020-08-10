; ========================================================================
; House-DOS QUIT COMMAND
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; Main code
; ========================================================================

main:
    mov ah, 0x02                        ; Print line
    mov si, msg
    call 0x2000:0x0000                  ; Call SYS.BIN

    mov ah, 0x03                        ; Ask for confirmation
    call 0x2000:0x0000                  ; Call SYS.BIN

    jc .return                          ; If not given, return control

    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15                            ; Otherwise, BIOS shutdown 

    mov ah, 0x02                        ; Print line
    mov si, msg_error
    call 0x2000:0x0000                  ; Call SYS.BIN

.return:
    mov ah, 0xFF                        ; We're done
    jmp 0x2000:0x0000                   ; Return control


data:

msg         db "Shutting down...", 0x00
msg_error   db "FATAL: Failed to shut down.", 0x00
