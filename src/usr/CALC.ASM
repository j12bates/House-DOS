; ========================================================================
; House-DOS CALC COMMAND
; 
; Written by Jet Pham and Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; Main code
; ========================================================================

main:
    mov ah, 0x22                        ; Get parameter as decimal integer
    mov cx, 0x0000                      ; First parameter
    int 0x7E

    jc .done                            ; If error, we're done
    push dx                             ; Otherwise, push to stack

    mov cx, 0x0002                      ; Third parameter
    int 0x7E

    jc .done                            ; If error, we're done
    push dx                             ; Otherwise, push to stack

.op:
    mov ah, 0x24                        ; Get parameter as byte
    mov cx, 0x0001                      ; The second parameter is the operator
    int 0x7E

    cmp al, 0x2B                        ; Is it a plus?
    je .add                             ; If so, add

    cmp al, 0x2D                        ; Is it a hyphen?
    je .sub                             ; If so, subtract

    cmp al, 0x2A                        ; Is it an asterisk?
    je .mul                             ; If so, multiply

    cmp al, 0x2F                        ; Is it a forward-slash?
    je .div                             ; If so, divide

    mov ah, 0x02                        ; If none of the above, print line
    mov si, op_error                    ; Our error message
    int 0x7E

    jmp .done                           ; And we're done

.add:
    pop cx                              ; CX should be the adder
    pop dx                              ; DX should be the addend

    add dx, cx                          ; Add them together
    jmp .print                          ; We have our result

.sub:
    pop cx                              ; CX should be the subtrahend
    pop dx                              ; DX should be the minuend

    sub cx, dx                          ; Subtract the subtrahend from the minuend
    jmp .print                          ; We have our result

.mul:
    pop dx                              ; DL should be the multiplier
    pop ax                              ; AL should be the multiplicand

    mul dl                              ; Multiply
    mov dx, ax                          ; Store in the correct register

    jmp .print                          ; We have our result

.div:
    pop bx                              ; BX should be the divisor
    pop ax                              ; AX should be the dividend

    mov dx, 0x0000                      ; Upper word of dividend is zero
    div bx                              ; Divide
    mov dx, ax                          ; Store in correct register; we have our result

.print:
    mov ah, 0xF1                        ; Convert binary to unsigned decimal
    mov di, dec_buffer                  ; Our output buffer
    int 0x7E

    mov ah, 0x10                        ; Print bytes
    mov si, dec_buffer                  ; Our input buffer
    mov cx, 0x0005                      ; Up to 5 digits in a 16-bit integer
    int 0x7E

    mov ah, 0x05                        ; Line break
    int 0x7E

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

op_error        db "Invalid operator. Try again using +, -, *, or /.", 0x00
dec_buffer      dd 0x00000000
                db 0x00
