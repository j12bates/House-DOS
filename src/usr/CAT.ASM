; ========================================================================
; House-DOS CAT COMMAND
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; Header
; ========================================================================

header:
    jmp main                            ; Don't execute the header

h_creator       dw creator              ; Creator string
h_desc          dw desc                 ; Description string
h_usage         dw usage                ; Usage string


; ========================================================================
; Main code
; ========================================================================

main:
    mov ah, 0x21                        ; Get total parameters
    int 0x7E

    mov word [files], cx                ; Save in memory

.file:
    push cx                             ; Preserve our counter

    mov ah, 0x29                        ; Load file from parameter to offset
    sub cx, word [files]                ; Subtract the total files
    neg cx                              ; Negate to get the files in order
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
                db 0x00

creator         db "House-DOS Developers", 0x00
desc            db "Utility for concatenating and displaying file contents.", 0x00
usage           db "CAT <FILENAME> *<FILENAME>* ...", 0x0A
                db "Flags: none", 0x00


dest_buffer:
