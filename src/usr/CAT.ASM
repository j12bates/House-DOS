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
    mov ah, 0x21                        ; Get total parameters
    int 0x7E

    mov word [files], cx                ; Save in memory

.file:
    push cx                             ; Preserve our counter

    mov ah, 0x20                        ; Get parameter
    sub cx, word [files]                ; Subtract the total files
    neg cx                              ; Negate to get the files in order
    mov di, fname                       ; The parameter should be our filename
    int 0x7E

    jc .done                            ; If error, we're done

    mov ah, 0x60                        ; Verify file and prepare for loading
    mov si, fname                       ; Filename
    int 0x7E

    jc .done                            ; If error, we're done

    mov ah, 0x66                        ; Load file to offset
    mov di, word [buffer_pointer]       ; Our pointer is our offset
    int 0x7E

    jc .done                            ; If error, we're done

    mov ah, 0x70                        ; Get size of file
    int 0x7E

    add word [buffer_pointer], ax       ; Add size to overall pointer/counter

.next:
    pop cx                              ; Restore our counter
    loop .file                          ; Repeat with next file

.print:
    mov ah, 0x05                        ; Line break
    int 0x7E

    mov ah, 0x63                        ; Get bytes (index-index)
    mov si, 0x0000                      ; Starting at the beginning
    mov cx, word [buffer_pointer]       ; And ending at our ultimate pointer
    mov di, dest_buffer                 ; Copy into our buffer
    int 0x7E

    jc .done                            ; If error, we're done

    mov ah, 0x10                        ; Print bytes (counter is already set)
    mov si, dest_buffer                 ; Read from our buffer
    int 0x7E

    mov ah, 0x05                        ; Line break
    int 0x7E

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

buffer_pointer  dw 0x0000
files           dw 0x0000
fname           dq 0x0000000000000000
                dd 0x00000000


dest_buffer:
