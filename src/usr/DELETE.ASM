; ========================================================================
; House-DOS DELETE COMMAND
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

    jcxz .apply                         ; If none, skip

.file:
    push cx                             ; Preserve counter

    mov ah, 0x2A                        ; Verify file from parameter
    dec cx                              ; Our parameter number (avoid an O.B.O.E)
    int 0x7E

    jc .next                            ; If failed, try next file

    mov ah, 0x79                        ; Otherwise, delete file
    int 0x7E

.next:
    pop cx                              ; Restore counter
    loop .file                          ; Repeat with next file

.apply:
    mov ah, 0x27                        ; Check for flag
    mov al, 0x41                        ; Flag 'A'
    int 0x7E

    jne .done                           ; If not set, we're done

    mov ah, 0x7F                        ; Otherwise, apply filesystem changes
    int 0x7E

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

prompt          db "Input filename: ", 0x00
fname           dq 0x0000000000000000
                dd 0x00000000

creator         db "House-DOS Developers", 0x00
desc            db "Utility for deleting a file.", 0x00
usage           db "DELETE <FILENAME>", 0x0A
                db "Flags:", 0x0A
                db "A - Immediately apply changes", 0x00
