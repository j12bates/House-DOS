; ========================================================================
; House-DOS TEXT FILE WRITER
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
    mov ax, 0x4300                      ; Set default output device to NUL
    int 0x7E

    mov ah, 0x02                        ; Print line
    mov si, help                        ; Our instructions
    int 0x7E

    mov ax, 0x4100                      ; Clear the buffer
    int 0x7E

.input:
    mov ax, 0x4112                      ; Get output buffer pointer
    int 0x7E

    mov ax, 0x8200                      ; Print int as hex
    mov dx, di                          ; Our pointer
    int 0x7E

    mov ah, 0x13                        ; Indent cursor
    mov dl, 0x06                        ; Col 6
    int 0x7E

    mov ah, 0x04                        ; Get input
    mov cx, 0x0080                      ; Hard limit 128 chars/line
    mov di, src_buffer                  ; Our buffer
    int 0x7E

    mov cx, di                          ; Counter is our pointer
    sub cx, src_buffer                  ; Relative to the start of the buffer

    cmp cx, 0x0000                      ; Did they immediately press RETURN?
    je .save                            ; If so, save the file

    mov ax, 0x4001                      ; Otherwise, output string to file buffer as line
    mov si, src_buffer                  ; Our buffer
    int 0x7E
    
    jmp .input                          ; Repeat

.save:
    mov ah, 0x05                        ; Line break
    int 0x7E

    mov ah, 0x01                        ; Print string
    mov si, save                        ; Our message
    int 0x7E

    mov ah, 0x03                        ; Ask for confirmation
    int 0x7E

    jc .done                            ; If not given, we're done

.name:
    mov ah, 0x20                        ; Get parameter
    mov cx, 0x0000                      ; Parameter 0
    mov di, fname                       ; This parameter should be our filename
    int 0x7E

    jnc .write                          ; If no error, proceed

    mov ah, 0x01                        ; Print string
    mov si, prompt                      ; Our message
    int 0x7E

    mov ah, 0x04                        ; Get keyboard input
    mov di, fname                       ; Input into our filename
    mov cx, 0x000C                      ; 12 bytes max in an X.3 filename with dot
    int 0x7E

.write:
    mov ah, 0x4F                        ; Write buffer to disk
    mov si, fname                       ; Our filename
    int 0x7E

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

help            db "Enter text line by line, pressing", 0x0A
                db "RETURN at the end of each line.", 0x0A
                db "Press RETURN on an empty line to", 0x0A
                db "end the file.", 0x0A
                db 0x00

save            db "Save this file?", 0x00
prompt          db "Enter a filename: ", 0x00

fname           db "XXXXXXXX.XXX"

creator         db "House-DOS Developers", 0x00
desc            db "Utility for writing a new text file.", 0x00
usage           db "WRITE *<FILENAME>*", 0x0A
                db "OUT: Contents written", 0x00

src_buffer:
