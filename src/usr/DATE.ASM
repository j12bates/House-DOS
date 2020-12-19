; ========================================================================
; House-DOS DATE COMMAND
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
    mov ah, 0xD0                        ; Get UNIX timestamp
    int 0x7E

    mov ah, 0xD3                        ; Convert to datestamp
    mov di, date                        ; Destination buffer
    int 0x7E

    mov ah, 0xD2                        ; Convert to timestamp
    mov di, time                        ; Destination buffer
    int 0x7E

    mov ah, 0x02                        ; Print line
    mov si, data                        ; All our stuff
    int 0x7E

    mov ah, 0xFF                        ; We're done
    int 0x7E

data:

date            dq 0x0000000000000000
                dw 0x0000

space           db 0x20

time            dq 0x0000000000000000

null            db 0x00

creator         db "House-DOS Developers", 0x00
desc            db "Utility for displaying time/date.", 0x00
usage           db "DATE", 0x0A
                db "Flags: none", 0x0A
