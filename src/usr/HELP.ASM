; ========================================================================
; House-DOS HELP COMMAND
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; Main code
; ========================================================================

main:
    mov ah, 0x02                        ; Print line

    mov si, msgA                        ; Message A
    int 0x7E

    mov si, msgB                        ; Message B
    int 0x7E

    mov si, msgC                        ; Message C
    int 0x7E

    mov si, msgD                        ; Message D
    int 0x7E

    mov si, msgE                        ; Message E
    int 0x7E

    mov si, msgF                        ; Message F
    int 0x7E

    mov si, msgG                        ; Message G
    int 0x7E

    mov si, msgH                        ; Message H
    int 0x7E

    mov si, msgK                        ; Message K
    int 0x7E

    mov si, msgL                        ; Message L
    int 0x7E

    mov si, msgM                        ; Message M
    int 0x7E

    mov si, msgN                        ; Message N
    int 0x7E

    mov si, msgP                        ; Message P
    int 0x7E

    mov si, msgR                        ; Message R
    int 0x7E

    mov si, msgS                        ; Message S
    int 0x7E

    mov si, msgT                        ; Message T
    int 0x7E

    mov ah, 0xFF                        ; We're done
    int 0x7E


data:

msgA        db "========= House-DOS Help =========", 0x00
msgB        db "INFO:       Display OS information", 0x00
msgC        db "HELP:       Display House-DOS help", 0x00
msgD        db "EXIT:       System Reboot", 0x00
msgE        db "QUIT:       System Shutdown", 0x00
msgF        db "DIR:        List all files", 0x00
msgG        db "CAT:        Display file contents", 0x00
msgH        db "WRITE:      Write a text file", 0x00
msgK        db "RENAME:     Rename a file", 0x00
msgL        db "DELETE:     Delete a file", 0x00
msgM        db "APPLY:      Apply changes to disk", 0x00
msgN        db "ROLLBACK:   Rollback filesystem", 0x00
msgP        db "COPY:       Copy a file", 0x00
msgR        db "APPEND:     Append a line to file", 0x00
msgS        db "CALC:       Perform arithmetic", 0x00
msgT        db "DATE:       Display time and date", 0x00
