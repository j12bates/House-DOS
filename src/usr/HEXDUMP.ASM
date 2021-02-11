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

    jcxz .next_16                       ; If no parameter, proceed

    mov ah, 0x2A                        ; Verify file from parameter
    mov cx, 0x0000                      ; The first parameter
    int 0x7E

    mov ax, 0x4020                      ; Output file
    int 0x7E

    jc .done                            ; If error, we're done

.next_16:
    mov ax, 0x5101                      ; Get input buffer pointer
    int 0x7E

    mov ax, 0x8200                      ; Print word as hex
    mov dx, si                          ; Our input buffer pointer
    int 0x7E

    mov ah, 0x13                        ; Indent cursor
    mov dl, 0x06                        ; Col 7
    int 0x7E

.get_bytes:
    mov ax, 0x5010                      ; Input bytes
    mov di, dest_buffer                 ; Copy into our buffer
    mov cx, 0x0010                      ; 16 bytes
    int 0x7E

    pushf                               ; Preserve flags
    push cx                             ; Preserve number of characters

    jcxz .chars_ascii                   ; If counter is zero, avoid an endless loop
    mov si, dest_buffer                 ; Read from our buffer
    cld                                 ; Ensure correct direction

.char_hex:
    lodsb                               ; Load next byte
    mov dl, al                          ; Move into correct register

    mov ax, 0x8201                      ; Print as hex
    int 0x7E

    mov ah, 0x14                        ; Advance cursor
    int 0x7E

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

    popf                                ; Restore flags
    jbe .next_16                        ; If there's more, repeat

.done:
    mov ah, 0xFF                        ; Otherwise, we're done!
    int 0x7E


data:

creator         db "House-DOS Developers", 0x00
desc            db "Utility to dump a file/input as hex/plaintext. No output is produced.", 0x00
usage           db "HEXDUMP *<FILENAME>*", 0x0A
                db "IN: Content to dump as hex (if file not given)", 0x00

dest_buffer:
