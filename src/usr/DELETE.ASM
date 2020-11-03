; ========================================================================
; House-DOS DELETE COMMAND
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; Main code
; ========================================================================

main:
    mov ah, 0x21                        ; Get total parameters
    int 0x7E

.file:
    push cx                             ; Preserve counter

    mov ah, 0x20                        ; Get parameter
    dec cx                              ; Our parameter number (avoid an O.B.O.E)
    mov di, fname                       ; The name of our filename to delete
    int 0x7E

    jc .done                            ; If error, we're done

    mov ah, 0x60                        ; Verify file
    mov si, fname                       ; Filename
    int 0x7E

    jc .next                            ; If failed, try next file

    mov ah, 0x79                        ; Otherwise, delete file
    int 0x7E

.next:
    pop cx                              ; Restore counter
    loop .file                          ; Repeat with next file

.apply:
    mov ah, 0x27                        ; Check for flag
    mov al, 0x41                        ; Flag 'A'
    int 0x7E

    jne .done                           ; If not set, we're done

    mov ah, 0x7F                        ; Otherwise, apply filesystem changes
    int 0x7E

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

prompt          db "Input filename: ", 0x00
fname           dq 0x0000000000000000
                dd 0x00000000
