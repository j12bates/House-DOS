; ========================================================================
; House-DOS ECHO COMMAND
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

    mov word [words], cx                ; Save in memory
    jcxz .done                          ; If zero, we're done

.word:
    push cx                             ; Preserve our counter

    mov ah, 0x20                        ; Get parameter
    sub cx, word [words]                ; Subtract the total number of words
    neg cx                              ; Negate to get the words in order
    mov di, dest_buffer                 ; Our buffer
    int 0x7E

    mov ax, 0x4000                      ; Output string
    mov si, dest_buffer                 ; Our buffer
    int 0x7E

    mov ax, 0x4220                      ; Output space
    int 0x7E

    pop cx                              ; Restore our counter
    loop .word                          ; Repeat with next file

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

words           dw 0x0000

creator         db "House-DOS Developers", 0x00
desc            db "Utility for echoing text to a device.", 0x00
usage           db "ECHO *WORD* *WORD* ...", 0x0A
                db "Flags: none", 0x00


dest_buffer:
