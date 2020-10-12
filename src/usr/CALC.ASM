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
    mov AH, 0x01             ;declaring print line
    mov SI, request_operator ;setting the output
    int 0x7e

    mov AH, 0x04            ;declaring get input
    mov DI, input_buffer3   ;locaiton of the input buffer
    mov CX, 1               ;limit 5 bytes
    int 0x7e

    mov AL, byte [input_buffer3] ;putting the operator into a register

    cmp AL, 0x2b                ; checking if +
    je .add                     ;goto add
    cmp AL, 0x2d                ; checking if -
    je .sub                     ; goto sub
    cmp AL, 0x2a                ; checking if -
    je .mult                    ; goto sub
    cmp AL, 0x2f                ; checking if -
    je .div                     ; goto sub

    mov AH, 0x02                ;declaring print line
    mov SI, error               ;setting the output
    int 0x7e
    jmp main


.add:
    call request16bit
    mov CX, DX
    call request16bit

    add DX, CX              ;adding the numbers
    jmp .print              ;jump to print

.sub:
    call request16bit
    mov CX, DX
    call request16bit

    sub CX, DX              ;subtracting the numbers
    mov DX, CX  
    jmp .print              ;jump to print

.mult:
    call request8bit
    mov CL, DL
    call request8bit

    mov AL, DL          ; moving one of the factors into AX
    mul CL              ;subtracting the numbers
    mov DX, AX          ;moving the product into DX
    jmp .print              ;jump to print

.div:
    call request16bit
    mov AX, DX
    call request16bit
    mov BX, DX

    mov DX, 0x0000
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

    mov ah, 0x05            ; Line break
    int 0x7E

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E



request16bit:
    pusha                   ; Save register states to stack

    mov AH, 0x01             ;declaring print line
    mov SI, request16 ;setting the output
    int 0x7e

    mov AH, 0x04            ;declaring get input
    mov DI, input_buffer1
    mov CX, 5               ;limit 5 bytes
    int 0x7e

    mov AH, 0xf3            ;declaring convert ascii number binary
    mov SI, input_buffer1    ;declaring the ascii number
    int 0x7e

    mov word [output_bckp], dx
    popa
    mov dx, word [output_bckp]
    ret


request8bit:
    pusha

    mov AH, 0x01             ;declaring print line
    mov SI, request8 ;setting the output
    int 0x7e

    mov AH, 0x04            ;declaring get input
    mov DI, input_buffer1
    mov CX, 3               ;limit 5 bytes
    int 0x7e

    mov AH, 0xf7            ;declaring convert ascii number binary
    mov SI, input_buffer1    ;declaring the ascii number
    int 0x7e

    mov byte [output_bckp], dl
    popa
    mov dl, byte [output_bckp]

    ret


data:
request16        db "Input Number < 65,536: ", 0x00
request8         db "Input Number < 256: ", 0x00
error            db "Error", 0x00
request_operator db "Input Operator (+, -, *, /): ", 0x00
input_buffer1    dd 0x00000000 
                 db 0x00
input_buffer3    db 0x00
output_bckp      dw 0x0000
