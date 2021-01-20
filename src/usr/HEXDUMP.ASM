; ========================================================================
; House-DOS HEXDUMP COMMAND
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

    mov ah, 0x21                        ; Get total parameters
    int 0x7E

    jcxz .size                          ; If no parameter, skip

    mov ah, 0x2A                        ; Verify file from parameter
    mov cx, 0x0000                      ; The first parameter
    int 0x7E

    mov ax, 0x4020                      ; Output file
    int 0x7E

    jc .done                            ; If error, we're done

.size:
    mov ax, 0x4113                      ; Get buffer endpoint
    int 0x7E

    mov word [eof], cx                  ; This is the number of bytes to print

.next_16:
    mov ax, 0x8200                      ; Print word as hex
    mov dx, word [buffer_pointer]       ; Our buffer pointer
    int 0x7E

    mov ah, 0x13                        ; Indent cursor
    mov dl, 0x06                        ; Col 7
    int 0x7E

    mov si, word [buffer_pointer]       ; Start reading at our pointer
    mov cx, si                          ; Read up until that same point
    add cx, 0x0010                      ; Plus 16

    cmp cx, word [eof]                  ; Will this take us past the end of the file?
    jb .get_bytes                       ; If not, proceed

    mov cx, word [eof]                  ; Otherwise, read until the end of the file

.get_bytes:
    mov ah, 0x63                        ; Get bytes (index-index)
    mov di, dest_buffer                 ; Copy into our buffer
    int 0x7E

    sub cx, word [buffer_pointer]       ; Subtract to get the number of bytes copied
    push cx                             ; Preserve number of characters

    jcxz .chars_ascii                   ; If counter is zero, avoid an endless loop

    mov word [buffer_pointer], si       ; Update the buffer pointer
    mov si, dest_buffer                 ; Read from our buffer
    cld                                 ; Ensure correct direction

.char_hex:
    lodsb                               ; Load next byte
    mov dl, al                          ; Move into correct register

    mov ax, 0x8201                      ; Print as hex
    int 0x7E

    push si                             ; Preserve index

    mov ah, 0x01                        ; Print string
    mov si, space                       ; Space
    int 0x7E

    pop si                              ; Restore index

    loop .char_hex                      ; Repeat

.chars_ascii:
    mov ah, 0x13                        ; Indent cursor
    mov dl, 0x37                        ; 2 cols ahead of the right edge of the hex
    int 0x7E

    pop cx                              ; Restore number of characters

    mov ah, 0x18                        ; Print bytes as literal chars
    mov si, dest_buffer                 ; Our buffer
    int 0x7E

    mov ah, 0x05                        ; Line break
    int 0x7E

    mov si, word [buffer_pointer]       ; Load our buffer pointer
    cmp si, word [eof]                  ; Are we at the end yet?
    jb .next_16                         ; If not, repeat

.done:
    mov ah, 0xFF                        ; Otherwise, we're done!
    int 0x7E


data:

eof             dw 0x0000
buffer_pointer  dw 0x0000

files           dw 0x0000
fname           dq 0x0000000000000000
                dd 0x00000000
                db 0x00

space           db " ", 0x00

creator         db "House-DOS Developers", 0x00
desc            db "Utility to dump a file/input as hex/plaintext.", 0x00
usage           db "HEXDUMP *<FILENAME>*", 0x0A
                db "Flags: none", 0x00

dest_buffer:
