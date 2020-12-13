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
    mov si, msg                         ; Help lines
    int 0x7E

.done:
    mov ah, 0xFF                        ; Handback
    int 0x7E


data:

msg         db "========= House-DOS Help =========", 0x0A
            db "INFO:       Display OS information", 0x0A
            db "HELP:       Display House-DOS help", 0x0A
            db "EXIT:       System Reboot", 0x0A
            db "QUIT:       System Shutdown", 0x0A
            db "DIR:        List all files", 0x0A
            db "FILE:       Get file properties", 0x0A
            db "CAT:        Display file contents", 0x0A
            db "WRITE:      Write a text file", 0x0A
            db "RENAME:     Rename a file", 0x0A
            db "DELETE:     Delete a file", 0x0A
            db "APPLY:      Apply changes to disk", 0x0A
            db "ROLLBACK:   Rollback filesystem", 0x0A
            db "COPY:       Copy a file", 0x0A
            db "APPEND:     Append a line to file", 0x0A
            db "CALC:       Perform arithmetic", 0x0A
            db "DATE:       Display time and date", 0x00
