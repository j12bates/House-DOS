; ========================================================================
; House-DOS COPY COMMAND
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
    mov ah, 0x28                        ; Load first parameter as file
    int 0x7E

.destination:
    mov ah, 0x20                        ; Get parameter
    mov cx, 0x0001                      ; Parameter 1
    mov di, fname                       ; Our destination filename
    int 0x7E

    jc .done                            ; If error, we're done

.save:
    mov ah, 0x70                        ; Get file size
    int 0x7E

    mov cx, ax                          ; Store in CX

    mov ah, 0x6F                        ; Save file
    mov si, fname                       ; Filename
    int 0x7E

    mov ax, 0x4100                      ; Clear buffer
    int 0x7E

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

fname           dq 0x0000000000000000
                dd 0x00000000

creator         db "House-DOS Developers", 0x00
desc            db "Utility for copying a file.", 0x00
usage           db "COPY <FILENAME-SOURCE> <FILENAME-DEST>", 0x0A
                db "Flags: none", 0x00
