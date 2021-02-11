; ========================================================================
; House-DOS APPEND COMMAND
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
    mov ax, 0x4141                      ; Set output buffer pointer to end of buffer
    int 0x7E

    mov ah, 0x21                        ; Get total parameters
    int 0x7E

    mov word [lines], cx                ; Save in memory
    jcxz .done                          ; If zero, we're done

.line:
    push cx                             ; Preserve our counter

    mov ah, 0x20                        ; Get parameter
    sub cx, word [lines]                ; Subtract the total lines
    neg cx                              ; Negate to get the lines in order
    mov di, src_buffer                  ; Our buffer
    int 0x7E

    jc .done                            ; If error, we're done

    mov ax, 0x4001                      ; Output string as line
    mov si, src_buffer                  ; Our buffer
    int 0x7E

    jc .done                            ; If overflow, we're done

.next:
    pop cx                              ; Restore our counter
    loop .line                          ; Repeat with next line

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

lines           dw 0x0000

creator         db "House-DOS Developers", 0x00
desc            db "Utility to lines to input.", 0x00
usage           db "APPEND *<LINE>* *<LINE>* ...", 0x0A
                db "IN: Input", 0x0A
                db "OUT: Input with lines appended", 0x00

src_buffer:
