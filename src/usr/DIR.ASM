; ========================================================================
; House-DOS QUIT COMMAND
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; Main code
; ========================================================================

main:
    mov ah, 0x77                        ; Get list of files
    mov di, list_buffer                 ; Our output buffer
    int 0x7E

    mov ax, 0x8101                      ; Get list length
    mov si, list_buffer                 ; Our list
    int 0x7E

    mov ah, 0xF1                        ; Convert word to decimal
    mov dx, cx                          ; Convert our list length
    mov di, num                         ; Our output buffer
    int 0x7E

    mov ah, 0x01                        ; Print string
    mov si, num                         ; Our decimal number
    int 0x7E

    mov ah, 0x02                        ; Print line
    mov si, msg                         ; Our message
    int 0x7E

    mov dl, 0x00                        ; Start cursor at col 0

.entry:
    mov ax, 0x8100                      ; Get list item
    dec cx                              ; Avoid an O.B.O.E
    mov si, list_buffer                 ; Our list
    mov di, fname                       ; Our output buffer
    int 0x7E

    inc cx                              ; Restore counter

    mov ah, 0x01                        ; Print string
    mov si, fname                       ; Our filename
    int 0x7E

    cmp dl, 0x40                        ; Are we out of space in this row?
    jae .newline                        ; If so, new line

    mov ah, 0x13                        ; Otherwise, indent
    add dl, 0x10                        ; Move ahead 16
    int 0x7E

    loop .entry                         ; Repeat
    inc cx                              ; If we're done, increment counter to do that last line break

.newline:
    mov ah, 0x05                        ; Line break
    int 0x7E

    mov dl, 0x00                        ; Start cursor at col 0
    loop .entry                         ; Repeat

.done:
    mov ah, 0xFF                        ; We're done
    int 0x7E

data:

fname           db "XXXXXXXX.XXX", 0x00
num             dd 0x00000000
                db 0x00

msg             db " files:", 0x00

list_buffer:
