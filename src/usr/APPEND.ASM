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
    mov ah, 0x28                        ; Load first parameter as file
    int 0x7E

    jc .done                            ; If error, we're done

    mov ah, 0x05                        ; Line break
    int 0x7E

    mov ah, 0x01                        ; Print String
    mov si, prompt                      ; Our prompt
    int 0x7E

    mov ah, 0x70                        ; Get size of file
    int 0x7E

    mov word [fsize], ax                ; Save the file size to memory

    mov ah, 0x04                        ; Get input
    mov di, src_buffer                  ; Our buffer
    mov cx, 0x80                        ; 128 character limit
    int 0x7E

    mov al, 0x0A                        ; Newline character
    stosb                               ; Store in buffer

    mov ah, 0x69                        ; Write bytes to file buffer
    mov si, src_buffer                  ; Read from our buffer
    mov cx, di                          ; The ending index is the value of the pointer
    mov di, word [fsize]                ; Start writing at the end of the file
    int 0x7E

    mov ah, 0x6F                        ; Write file to disk
    mov cx, di                          ; Our pointer is at the end; write this many bytes
    mov si, 0x0000                      ; Our filename
    int 0x7E

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

fsize           dw 0x0000
prompt          db "Input line to append: ", 0x00

creator         db "House-DOS Developers", 0x00
desc            db "Utility to append a line to a file.", 0x00
usage           db "APPEND <FILENAME>", 0x0A
                db "Flags: none", 0x00

src_buffer:
