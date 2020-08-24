; ========================================================================
; House-DOS CAT COMMAND
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

    mov ah, 0x70                        ; Get size of file
    mov si, fname                       ; Filename
    int 0x7E

    jc .done                            ; If no such file, end here
    mov word [fsize], ax                ; Otherwise, save size in memory

    mov ah, 0x60                        ; Verify file and prepare for loading
    int 0x7E

    mov ah, 0x61                        ; Load file
    int 0x7E

.next_512:
    mov ah, 0x62                        ; Get bytes
    mov si, word [buffer_pointer]       ; Starting at our pointer
    mov cx, 0x0200                      ; 512 bytes
    mov di, dest_buffer                 ; Copy into our buffer
    int 0x7E

    mov word [buffer_pointer], si       ; Advance our pointer

    mov ah, 0x05                        ; Line break
    int 0x7E

    mov ah, 0x10                        ; Print bytes
    mov si, dest_buffer                 ; Read from our buffer
    int 0x7E

    mov ax, word [buffer_pointer]
    cmp ax, word [fsize]                ; Have we read through the entire file yet?
    jge .done                           ; If so, we're done.

    mov ah, 0x05                        ; Line break
    int 0x7E

    int 0x7E                            ; Twice

    mov ah, 0x01                        ; Print String
    mov si, next_512                    ; Ask if we want to display more
    int 0x7E

    mov ah, 0x03                        ; Ask for confirmation
    int 0x7E

    jnc .next_512                       ; If given, repeat

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

prompt          db "Input filename: ", 0x00
next_512        db "Display another 512 bytes?", 0x00

buffer_pointer  dw 0x0000
fsize           dw 0x0000
fname           dq 0x0000000000000000
                dd 0x00000000


dest_buffer:
