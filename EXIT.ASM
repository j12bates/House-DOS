; ========================================================================
; House-DOS EXIT COMMAND
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
    int 0x7E                            ; Call SYS.BIN

    mov ah, 0x03                        ; Ask for confirmation
    int 0x7E                            ; Call SYS.BIN

    jc .return                          ; If not given, return control

    int 0x19                            ; Otherwise, reboot

    mov ah, 0x02                        ; Print line
    mov si, msg_error
    int 0x7E                            ; Call SYS.BIN

.return:
    mov ah, 0xFF                        ; We're done
    int 0x7E                            ; Call SYS.BIN


data:

msg         db "Rebooting...", 0x00
msg_error   db "FATAL: Failed to reboot.", 0x00
