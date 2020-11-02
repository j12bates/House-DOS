; ========================================================================
; House-DOS CALC COMMAND
; 
; Written by Jet Pham
; ========================================================================

    BITS 16

; ========================================================================
; Main code
; ========================================================================

main:
    mov ah, 0x01                        ; Print line
    mov si, prompt_op                   ; Our prompt
    int 0x7E

    mov ah, 0x04                        ; Get input (operator)
    mov di, operator                    ; Output buffer
    mov cx, 0x0001                      ; 1-byte operator
    int 0x7E

    mov al, byte [operator]             ; Store operator here for now

    cmp al, 0x2B                        ; Is it a plus?
    je .add                             ; If so, add

    cmp al, 0x2D                        ; Is it a hyphen?
    je .sub                             ; If so, subtract

    cmp al, 0x2A                        ; Is it an asterisk?
    je .mul                             ; If so, multiply

    cmp al, 0x2F                        ; Is it a forward-slash?
    je .div                             ; If so, divide

    mov ah, 0x02                        ; If none of the above, print line
    mov si, error                       ; Our error message
    int 0x7E

    jmp main                            ; And try again

.add:
    call get_16                         ; Get a 16-bit integer
    mov cx, dx
    call get_16                         ; Get another

    add dx, cx                          ; Add them together
    jmp .print                          ; We have our result

.sub:
    call get_16                         ; Get a 16-bit integer
    mov cx, dx
    call get_16                         ; Get another

    sub cx, dx                          ; Subtract the latter from the former
    mov dx, cx                          ; Store in the correct register

    jmp .print                          ; We have our result

.mul:
    call get_8                          ; Get an 8-bit integer
    mov al, dl                          ; AL should contain the multiplicand
    call get_8                          ; Get another

    mul dl                              ; Multiply
    mov dx, ax                          ; Store in the correct register

    jmp .print                          ; We have our result

.div:
    call get_16                         ; Get a 16-bit integer
    mov ax, dx                          ; AX should contain the dividend
    call get_16                         ; Get another
    mov bx, dx                          ; Store divisor here

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


get_16:                                 ; Routine to get a 16-bit integer from user input
    pusha                               ; Save register states to stack

    mov ah, 0x01                        ; Print line
    mov si, prompt16                    ; Our prompt
    int 0x7E

    mov ah, 0x04                        ; Get input
    mov di, dec_buffer                  ; Our output buffer
    mov cx, 0x0005                      ; Up to 5 digits in a 16-bit integer
    int 0x7E

    mov ah, 0xF3                        ; Convert ASCII decimal to word
    mov si, dec_buffer                  ; Our input buffer
    int 0x7E

    mov word [output_bckp], dx          ; Preserve our output

    popa                                ; Restore register states
    mov dx, word [output_bckp]          ; Restore our output

    ret                                 ; Return to caller


get_8:                                  ; Routine to get an 8-bit integer from user input
    pusha                               ; Save register states to stack

    mov ah, 0x01                        ; Print line
    mov si, prompt8                     ; Our prompt
    int 0x7E

    mov ah, 0x04                        ; Get input
    mov di, dec_buffer                  ; Our output buffer
    mov cx, 0x0003                      ; Up to 3-digits in an 8-bit integer
    int 0x7E

    mov ah, 0xF7                        ; Convert ASCII decimal to word
    mov si, dec_buffer                  ; Our input buffer
    int 0x7E

    mov byte [output_bckp], dl          ; Preserve our output

    popa                                ; Restore register states
    mov dl, byte [output_bckp]          ; Restore our output

    ret                                 ; Return to caller


data:

prompt_op       db "Input Operator (+, -, *, /): ", 0x00

prompt16        db "Input Number < 65,536: ", 0x00
prompt8         db "Input Number < 256: ", 0x00

error           db "Error", 0x00

dec_buffer      dd 0x00000000
                db 0x00
operator        db 0x00

output_bckp     dw 0x0000
