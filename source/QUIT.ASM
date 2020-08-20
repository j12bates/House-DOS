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
    mov ah, 0x01                        ; Print string
    mov si, msg
    int 0x7E

    mov ah, 0x03                        ; Ask for confirmation
    int 0x7E

    jc .return                          ; If not given, return control

    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15                            ; Otherwise, BIOS shutdown 

    mov ah, 0x02                        ; Print line
    mov si, msg_error
    int 0x7E

.return:
    mov ah, 0x02                        ; Print line
    mov si, msg_cancel
    int 0x7E

    mov ah, 0xFF                        ; We're done
    int 0x7E


data:

msg         db "Shutting down...", 0x00
msg_cancel  db "Canceled.", 0x00
msg_error   db "FATAL: Failed to shut down.", 0x00
