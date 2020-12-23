; ========================================================================
; House-DOS HELP COMMAND
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
    mov ah, 0x02                        ; Print line
    mov si, msg                         ; Help lines
    int 0x7E

.done:
    mov ah, 0xFF                        ; Handback
    int 0x7E


data:

msg         db "========= House-DOS Help =========", 0x0A, 0x0A
            db "Here is a list of the commands:", 0x0A
            db "APPEND   APPLY    CALC     CAT", 0x0A
            db "COPY     DATE     DELETE   DIR", 0x0A
            db "EXIT     FILE     HELP     HEXDUMP", 0x0A
            db "HIDE     INFO     QUIT     RENAME", 0x0A
            db "ROLLBACK WRITE    SYS", 0x0A, 0x0A
            db "For details on what a command does,", 0x0A
            db "Lookup the DESCRIPTION attribute:", 0x0A, 0x0A
            db "    COMMAND %D", 0x0A, 0x0A
            db "For details on how to use it,", 0x0A
            db "Lookup the USAGE attribute:", 0x0A, 0x0A
            db "    COMMAND %U", 0x0A, 0x0A
            db "For more help, visit the House-DOS", 0x0A
            db "wiki.", 0x00

creator     db "House-DOS Developers", 0x00
desc        db "Show system help.", 0x00
usage       db "HELP", 0x0A
            db "Flags: none", 0x00
