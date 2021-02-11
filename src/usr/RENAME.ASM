; ========================================================================
; House-DOS RENAME COMMAND
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
    mov ah, 0x2A                        ; Verify file from parameter
    mov cx, 0x0000                      ; Parameter 0
    int 0x7E

    jc .done                            ; If failed, we're done

.destination:
    mov ah, 0x20                        ; Get parameter
    mov cx, 0x0001                      ; Parameter 1
    mov di, fname                       ; Our destination filename
    int 0x7E

    jc .done                            ; If error, we're done

.rename:
    mov ah, 0x78                        ; Rename file
    mov si, fname                       ; Filename
    int 0x7E

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

fname           dq 0x0000000000000000
                dd 0x00000000

creator         db "House-DOS Developers", 0x00
desc            db "Utility for renaming a file.", 0x00
usage           db "RENAME <FILE-SRC> <FILE-DEST>", 0x0A
                db "Flags:", 0x0A
                db "A - Immediately apply changes", 0x00
