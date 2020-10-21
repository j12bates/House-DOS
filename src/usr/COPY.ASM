; ========================================================================
; House-DOS COPY COMMAND
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

    mov ah, 0x01                        ; Print string
    mov si, promptA                     ; Our prompt
    int 0x7E

    mov ah, 0x04                        ; Get input
    mov di, fname                       ; The input should be our filename
    mov cx, 0x000C                      ; Up to 12 chars
    int 0x7E

.verify:
    mov ah, 0x60                        ; Verify file and prepare for loading
    mov si, fname                       ; Filename
    int 0x7E

    jc .done                            ; If no such file, end here

    mov ah, 0x61                        ; Load file
    int 0x7E

.destination:
    mov ah, 0x20                        ; Get parameter
    mov cx, 0x0001                      ; Parameter 1
    mov di, fname                       ; Our destination filename
    int 0x7E

    jnc .save                           ; If we got the parameter, proceed

    mov ah, 0x01                        ; Print string
    mov si, promptA                     ; Our prompt
    int 0x7E

    mov ah, 0x04                        ; Get input
    mov di, fname                       ; The input should be our filename
    mov cx, 0x000C                      ; Up to 12 chars
    int 0x7E

.save:
    mov ah, 0x6F                        ; Save file
    mov si, fname                       ; Filename
    int 0x7E

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

promptA         db "Input filename: ", 0x00
promptB         db "Input destination filename: ", 0x00

buffer_pointer  dw 0x0000
fsize           dw 0x0000
fname           dq 0x0000000000000000
                dd 0x00000000


dest_buffer:
