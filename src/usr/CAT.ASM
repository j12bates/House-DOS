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

    mov ah, 0x27                        ; Check if flag was specified
    mov al, 0x58                        ; X flag
    int 0x7E

    je .done                            ; If specified, we're done

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

fname           dq 0x0000000000000000
                dd 0x00000000


dest_buffer:
