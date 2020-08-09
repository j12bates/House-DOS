; ========================================================================
; HOUSEDOS EXIT COMMAND
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; Main code
; ========================================================================

main:
    mov ah, 0x03                        ; Ask for confirmation
    call 0x2000:0x0000                  ; Call SYS.BIN

    jc .return                          ; If not given, return control

    int 0x19                            ; Otherwise, reboot

.return:
    mov ah, 0xFF                        ; We're done
    jmp 0x2000:0x0000                   ; Return control
