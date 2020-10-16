; ========================================================================
; House-DOS TEXT FILE WRITER
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; Main code
; ========================================================================

main:
    mov ah, 0x10                        ; Print bytes
    mov si, helpA                       ; Our instructions
    mov cx, save                        ; The end of our instructions
    sub cx, helpA                       ; Subtract the beginning to get the number of bytes
    int 0x7E

    mov ah, 0x6E                        ; Clear file buffer
    int 0x7E

.input:
    mov ah, 0xF0                        ; Convert word to hex
    mov dx, word [buffer_pointer]       ; Our pointer
    mov di, byte_num                    ; Save chars here
    int 0x7E

    mov ah, 0x10                        ; Print string
    mov si, byte_num                    ; Print our our current byte hex value
    mov cx, 0x0006                      ; 6 bytes
    int 0x7E

    mov ah, 0x04                        ; Get input
    mov cx, 0x0080                      ; Hard limit 128 chars/line
    mov di, src_buffer                  ; Write input into our local buffer
    int 0x7E

    mov al, 0x0A                        ; UNIX newline character
    stosb                               ; Store in the source buffer

    mov cx, di                          ; The end of the input
    sub cx, src_buffer                  ; The number of bytes input

    cmp cx, 0x0001                      ; Did they immediately press RETURN?
    je .save                            ; If so, save the file

    mov ah, 0x68                        ; Otherwise, write bytes to file buffer
    mov si, src_buffer                  ; The beginning of the source buffer
    mov di, word [buffer_pointer]       ; Write to our file buffer pointer
    int 0x7E

    add word [buffer_pointer], cx       ; Account for these new bytes
    
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

    mov ah, 0x01                        ; Print string
    mov si, prompt                      ; Our message
    int 0x7E

    mov ah, 0x04                        ; Get keyboard input
    mov di, fname                       ; Input into our filename
    mov cx, 0x000C                      ; 12 bytes max in an X.3 filename with dot
    int 0x7E

    mov ah, 0x6F                        ; Write file to disk
    mov si, fname                       ; Our filename
    mov cx, word [buffer_pointer]       ; The number of bytes we've written to the file buffer
    int 0x7E

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E
    

data:

helpA           db "Enter text line by line, pressing", 0x0A
helpB           db "RETURN at the end of each line.", 0x0A
helpC           db "Press RETURN on an empty line to", 0x0A
helpD           db "end the file.", 0x0A
lb              db 0x0A

save            db "Save this file?", 0x00
prompt          db "Enter a filename: ", 0x00

byte_num        dq 0x00000000
                db ": "

fname           db "XXXXXXXX.XXX"
ellipse         db "...", 0x00

buffer_pointer  dw 0x0000

src_buffer:
