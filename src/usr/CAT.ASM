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
    jcxz .done                          ; If zero, we're done

.file:
    push cx                             ; Preserve our counter

    mov ah, 0x2A                        ; Verify file from parameter
    sub cx, word [files]                ; Subtract the total files
    neg cx                              ; Negate to get the files in order
    int 0x7E

    jc .done                            ; If error, we're done

    mov ax, 0x4020                      ; Output file
    int 0x7E

    jc .done                            ; If error, we're done

.next:
    pop cx                              ; Restore our counter
    loop .file                          ; Repeat with next file

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

files           dw 0x0000

creator         db "House-DOS Developers", 0x00
desc            db "Utility for concatenating and displaying file contents.", 0x00
usage           db "CAT <FILENAME> *<FILENAME>* ...", 0x0A
                db "Flags: none", 0x00


dest_buffer:
