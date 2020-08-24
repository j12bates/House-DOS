; ========================================================================
; House-DOS KERNEL: LOGIC SUBSYSTEM
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; LOGICAL/CONVERSION SUBROUTINES
; ========================================================================

conv_word_hex:                                  ; Convert AX to ASCII hexadecimal dword at ES:DI
    pusha                                       ; Push register states to stack
    mov cx, 0x0004                              ; Four nibbles

.nibble:
    push ax                                     ; Save our word
    push cx                                     ; Save our counter
    
    dec cx                                      ; Avoid an O.B.O.E
    shl cx, 0x2                                 ; 4 bits in a nibble
    shr ax, cl                                  ; Shift the nibble we care about into the far right

    and al, 0x0F                                ; Get rid of the nibble on the left
    add al, 0x30                                ; ASCII digits start here

    cmp al, 0x39                                ; Is this nibble greater than 9?
    jng .record                                 ; If not, no need to change anything

    add al, 0x07                                ; Otherwise, fast forward to capital letters A-F

.record:
    mov byte [es:di], al                        ; Save the ASCII char in our space in memory
    inc di                                      ; Increment our pointer

    pop cx                                      ; Restore our counter
    pop ax                                      ; Restore our word
    loop .nibble                                ; And repeat

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


conv_word_dec_unsigned:                         ; Convert AX to ASCII decimal at ES:DI
    pusha                                       ; Push register states to stack
    mov cx, 0x0005                              ; There are up to 5 digits in a 16-bit unsigned number

.digit:
    push ax                                     ; Save our number
    push cx                                     ; Save our counter

    mov ax, 0x0001                              ; One
    loop .place_value                           ; Avoid an O.B.O.E and start calculating the place value

    jmp .calc_digit                             ; If we are at the units digit, skip this

.place_value:
    mov dx, 0x000A                              ; Ten
    mul dx                                      ; Multiply
    loop .place_value                           ; Raise 10 to the number of digits left

.calc_digit:
    mov bx, ax                                  ; Save our place value
    pop cx                                      ; Restore our counter
    pop ax                                      ; Restore our number

    mov dx, 0x0000                              ; Upper word of dividend is zero
    div bx                                      ; Divide to find the digit in that place value

    add al, 0x30                                ; ASCII digits start here
    mov byte [es:di], al                        ; Store the ASCII character
    inc di                                      ; Increment our pointer

    mov ax, dx                                  ; We will now do this with the remainder
    loop .digit                                 ; Repeat this process

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


conv_dec_unsigned_word:                         ; Convert ASCII decimal at DS:SI to binary, store in DX
    pusha                                       ; Push register states to stack
    mov cx, 0x0005                              ; 5 digits in a 16-bit unsigned integer
    mov dx, 0x0000                              ; Clear this out
    
.digit:
    lodsb                                       ; Load a byte
    sub al, 0x30                                ; ASCII digits start here

    cmp al, 0x09                                ; Are we an actual digit?
    ja .error_nan                               ; If not, error

    mov ah, 0x00                                ; Upper byte is 0
    add ax, dx                                  ; Add the binary value to our sum

    loop .multiply                              ; If we have more digits to go, multiply

    mov dx, ax                                  ; Otherwise, move back into the correct register
    jmp .done                                   ; We're done

.multiply:
    mov dx, 0x000A                              ; We're using decimal notation
    mul dx                                      ; Set up for the next place value
    mov dx, ax                                  ; Move back into the correct register

    jmp .digit

.done:
    mov word [register_bckp_a], dx              ; Preserve our output

    popa                                        ; Restore register states
    mov dx, word [register_bckp_a]              ; Restore output

    ret                                         ; Return to caller
    
.error_nan:
    mov si, iface_error_nan                     ; Error message
    call println                                ; Print line

    stc                                         ; Carry flag for error
    jmp .done                                   ; We're done


capitalize_char:                                ; Capitalize char in AL
    cmp al, 0x61                                ; Are we between lowercase A
    jl .end
    cmp al, 0x7A                                ; And lowercase Z?
    jg .end

    and al, 0b11011111                          ; If so, capitalize

.end:
    ret                                         ; Return to caller


; ========================================================================
; DATA SECTION
; ========================================================================

logic_data:

iface_error_nan     db "ERROR: Not a Number.", 0x00
