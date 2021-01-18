; ========================================================================
; House-DOS QUIT COMMAND
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
    mov ah, 0x27                        ; Check flag
    mov al, 0x48                        ; 'H' for hidden files
    int 0x7E

    jne .list                           ; If not set, proceed

    mov ah, 0x0F                        ; Otherwise, config interface
    mov al, 0b00000100                  ; List hidden files
    int 0x7E

.list:
    mov ah, 0x77                        ; Get list of files
    mov di, list_buffer                 ; Our output buffer
    int 0x7E

    mov ax, 0x8101                      ; Get list length
    mov si, list_buffer                 ; Our list
    int 0x7E

    mov ax, 0x4040                      ; Output word as decimal
    mov dx, cx                          ; Our list length
    int 0x7E

    mov ax, 0x4001                      ; Output string and line break
    mov si, msg                         ; Our message
    int 0x7E

    jcxz .done                          ; If none, we're done
    mov dl, 0x00                        ; Start cursor at col 0

.entry:
    mov ax, 0x8100                      ; Get list item
    dec cx                              ; Avoid an O.B.O.E
    mov si, list_buffer                 ; Our list
    mov di, fname                       ; Our output buffer
    int 0x7E

    inc cx                              ; Restore counter

    mov ax, 0x4000                      ; Output string
    mov si, fname                       ; Our filename
    int 0x7E

    cmp dx, 0x0040                      ; Are we out of space in this row?
    jae .newline                        ; If so, new line

    mov ax, 0x4122                      ; Otherwise, indent pointer
    add dx, 0x0010                      ; Move ahead 16
    int 0x7E

    loop .entry                         ; Repeat
    inc cx                              ; If we're done, increment counter to do that last line break

.newline:
    mov ax, 0x4002                      ; Output line break
    int 0x7E

    mov dx, 0x0000                      ; Start cursor at col 0
    loop .entry                         ; Repeat

.done:
    mov ah, 0xFF                        ; We're done
    int 0x7E


data:

fname           db "XXXXXXXX.XXX", 0x00
num             dd 0x00000000
                db 0x00

msg             db " files:", 0x00

creator         db "House-DOS Developers", 0x00
desc            db "Utility for listing files.", 0x00
usage           db "DIR", 0x0A
                db "Flags:", 0x0A
                db "H - List Hidden Files", 0x00

list_buffer:
