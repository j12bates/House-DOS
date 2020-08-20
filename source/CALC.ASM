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

    add DX, CX              ;adding the numbers

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
request         db "Input Number: ", 0x00
input_buffer1   dd 0x00000000 
                db 0x00
input_buffer2   dd 0x00000000 
                db 0x00
