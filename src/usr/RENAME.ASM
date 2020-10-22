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
    mov ah, 0x20                        ; Get parameter
    mov cx, 0x0000                      ; Parameter 0
    mov di, fname                       ; The name of our file to copy
    int 0x7E

    jnc .verify                         ; If we got the parameter, proceed

    mov ah, 0x01                        ; Print String
    mov si, source                      ; Our prompt
    int 0x7E

    mov ah, 0x04                        ; Get input
    mov di, fname                       ; The input should be our filename
    mov cx, 0x000C                      ; Up to 12 chars
    int 0x7E

.verify:
    mov ah, 0x60                        ; Verify file
    mov si, fname                       ; Filename
    int 0x7E

    jc .done                            ; If failed, we're done

.destination:
    mov ah, 0x20                        ; Get parameter
    mov cx, 0x0001                      ; Parameter 1
    mov di, fname                       ; Our destination filename
    int 0x7E

    jnc .rename                         ; If we got the parameter, proceed

    mov ah, 0x01                        ; Print String
    mov si, prompt                      ; Our prompt
    int 0x7E

    mov ah, 0x04                        ; Get input
    mov di, fname                       ; The input should be our filename
    mov cx, 0x000C                      ; Up to 12 chars
    int 0x7E

.rename:
    mov ah, 0x78                        ; Rename file
    mov si, fname                       ; Filename
    int 0x7E

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

source          db "Input filename: ", 0x00
prompt          db "Input new filename: ", 0x00

fname           dq 0x0000000000000000
                dd 0x00000000
