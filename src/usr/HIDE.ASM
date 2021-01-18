; ========================================================================
; House-DOS HIDE COMMAND
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
    mov ah, 0x27                        ; Check flag
    mov al, 0x52                        ; 'R' for reveal
    int 0x7E

    jne .params                         ; If not set, proceed
    stc                                 ; Otherwise, carry-flag for reveal

.params:
    pushf                               ; Preserve flags

    mov ah, 0x21                        ; Get total parameters
    int 0x7E

    jcxz .apply                         ; If none, skip

.file:
    mov ah, 0x2A                        ; Verify file from parameter
    dec cx                              ; Our parameter number (avoid an O.B.O.E)
    int 0x7E

    jc .next                            ; If failed, try next file

    popf                                ; Restore flags
    pushf                               ; Push them back for next round

    mov ah, 0x7A                        ; Otherwise, hide/reveal file
    int 0x7E

.next:
    inc cx                              ; Restore counter
    loop .file                          ; Repeat with next file

.apply:
    popf                                ; Get this out of the stack

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

creator         db "House-DOS Developers", 0x00
desc            db "Utility for hiding/revealing a file.", 0x00
usage           db "HIDE <FILENAME> *<FILENAME>* ...", 0x0A
                db "Flags:", 0x0A
                db "A - Immediately apply changes", 0x0A
                db "R - Reveal files", 0x00
