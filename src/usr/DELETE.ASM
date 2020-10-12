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
    mov ah, 0x01                        ; Print String
    mov si, prompt                      ; Our prompt
    int 0x7E

    mov ah, 0x04                        ; Get input
    mov di, fname                       ; The input should be our filename
    mov cx, 0x000C                      ; Up to 12 chars
    int 0x7E

    mov ah, 0x60                        ; Verify file
    mov si, fname                       ; Filename
    int 0x7E

    jc .done                            ; If failed, error

    mov ah, 0x79                        ; Delete file
    int 0x7E

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

prompt          db "Input filename: ", 0x00

fname           dq 0x0000000000000000
                dd 0x00000000
