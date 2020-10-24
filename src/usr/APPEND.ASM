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

    jc .done                            ; If error, we're done

.verify:
    mov ah, 0x60                        ; Verify file and prepare for loading
    mov si, fname                       ; Filename
    int 0x7E

    jc .done                            ; If error, we're done

    mov ah, 0x61                        ; Load file
    int 0x7E

    jc .done                            ; If error, we're done

    mov ah, 0x05                        ; Line break
    int 0x7E

    mov ah, 0x01                        ; Print String
    mov si, prompt                      ; Our prompt
    int 0x7E

    mov ah, 0x70                        ; Get size of file
    int 0x7E

    mov cx, ax                          ; Get the entire file

    mov ah, 0x62                        ; Get bytes
    mov si, 0x0000                      ; Starting at the beginning
    mov di, dest_buffer                 ; Copy into our buffer
    int 0x7E

    mov ah, 0x04                        ; Get input
    mov cx, 0x80                        ; 128 character limit
    int 0x7E

    mov al, 0x0A                        ; Newline character
    stosb                               ; Store in buffer

    mov ah, 0x68                        ; Write bytes to file buffer
    mov si, dest_buffer                 ; Read from our buffer
    mov cx, di                          ; The file size is the value of the pointer
    sub cx, dest_buffer                 ; Relative to the start of our buffer
    mov di, 0x0000                      ; Write to the beginning of the file buffer
    int 0x7E

    mov ah, 0x6F                        ; Write file to disk (CX is already what we want)
    mov si, fname                       ; Our filename
    int 0x7E

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

fname           dq 0x0000000000000000
                dd 0x00000000

prompt          db "Input line to append: ", 0x00

dest_buffer: