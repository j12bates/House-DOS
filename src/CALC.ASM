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
    mov AH, 0x02             ;declaring print line
    mov SI, request_operator ;setting the output
    int 0x7e

    mov AH, 0x04            ;declaring get input
    mov DI, input_buffer3   ;locaiton of the input buffer
    mov CX, 1               ;limit 5 bytes
    int 0x7e

    mov AH, 0x02            ;declaring print line
    mov SI, request         ;setting the output
    int 0x7e                

    mov AH, 0x04            ;declaring get input
    mov DI, input_buffer1   ;locaiton of the input buffer
    mov CX, 5               ;limit 5 bytes
    int 0x7e

    mov AH, 0x02            ;declaring print line
    mov SI, request         ;setting the output
    int 0x7e                

    mov AH, 0x04            ;declaring get input
    mov DI, input_buffer2   ;locaiton of the input buffer
    mov CX, 5               ;limit 5 bytes
    int 0x7e

    mov AH, 0xf3            ;declaring convert ascii number binary
    mov SI, input_buffer1   ;declaring the ascii number
    int 0x7e

    mov CX, DX              ;saving the first translated binary

    mov SI, input_buffer2   ;declaring the ascii number
    int 0x7e


    mov AL, byte [input_buffer3] ;putting the operator into a register

    cmp AL, 0x2b                ; checking if +
    je .add                     ;goto add
    cmp AL, 0x2d                ; checking if -
    je .sub                     ; goto sub
    cmp AL, 0x2a              ; checking if *
    je .mult                     ; goto sub
    cmp AL, 0x2f              ; checking if /
    je .div                     ; goto sub
    jmp .print                  ; if not sub or add, print nothing

.add:
    add DX, CX              ;adding the numbers
    jmp .print              ;jump to print

.sub:
    sub CX, DX              ;subtracting the numbers
    mov DX, CX  
    jmp .print              ;jump to print

.mult:
    mov AX, DX          ; moving one of the factors into AX
    mul CX              ;subtracting the numbers
    mov DX, AX          ;moving the product into DX
    jmp .print              ;jump to print

.div:
    mov BX, DX          ; moving the denominator into AX
    mov DX, 0           ; clearing DX
    mov AX, CX          ; moving CX into AX
    div BX              ;subtracting the numbers
    mov DX, AX          ;moving the product into DX

.print:
    mov AH, 0xF1            ;declaring binary to unsigned decimal
    mov DI, input_buffer1   ;output to input_buffer1
    int 0x7e        

    mov AH, 0x10            ;declaring print bytes
    mov SI, input_buffer1   ;setting the output
    mov CX, 5               ;setting number of bytes
    int 0x7e        

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:
request          db "Input Number: ", 0x00
request_operator db "Input Operator: ", 0x00
input_buffer1    dd 0x00000000 
                 db 0x00
input_buffer2    dd 0x00000000 
                 db 0x00
input_buffer3    db 0x00
