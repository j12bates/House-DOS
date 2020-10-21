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
    mov ah, 0x20                        ; Get parameter
    mov cx, 0x0000                      ; Parameter 0
    mov di, fname                       ; The parameter should be our filename
    int 0x7E

    jnc .verify                         ; If no error, proceed

    mov ah, 0x01                        ; Otherwise, print string
    mov si, prompt                      ; Our prompt
    int 0x7E

    mov ah, 0x04                        ; Get input
    mov di, fname                       ; The input should be our filename
    mov cx, 0x000C                      ; Up to 12 chars
    int 0x7E

.verify:
    mov ah, 0x60                        ; Verify file and prepare for loading
    mov si, fname                       ; Filename
    int 0x7E

    jc .done                            ; If error, we're done

    mov ah, 0x61                        ; Load file
    int 0x7E

    jc .done                            ; If error, we're done

    mov ah, 0x70                        ; Get size of file
    int 0x7E

    mov cx, ax                          ; Save size in counter

    mov ah, 0x05                        ; Line break
    int 0x7E

    mov ah, 0x62                        ; Get bytes
    mov si, 0x0000                      ; Starting at the beginning
    mov di, dest_buffer                 ; Copy into our buffer
    int 0x7E

    jc .done                            ; If error, we're done

    mov ah, 0x10                        ; Print bytes
    mov si, dest_buffer                 ; Read from our buffer
    int 0x7E

    mov ah, 0x05                        ; Line break
    int 0x7E

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

prompt          db "Input filename: ", 0x00
fname           dq 0x0000000000000000
                dd 0x00000000


dest_buffer:
