; ========================================================================
; House-DOS KERNEL: DATA SUBSYSTEM
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; NUMBER/NOTATION SUBROUTINES
; ========================================================================

; CONVERT WORD TO HEX: Converts word-size value to ASCII hexadecimal notation
; IN: AX = Value to convert; ES:DI = Destination buffer (4 bytes)
; OUT: None

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
    stosb                                       ; Store the ASCII character

    pop cx                                      ; Restore our counter
    pop ax                                      ; Restore our word
    loop .nibble                                ; And repeat

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; CONVERT WORD TO UNSIGNED DECIMAL: Converts word-size value to ASCII decimal notation
; IN: AX = Value to convert; ES:DI = Destination buffer (5 bytes)
; OUT: None

conv_word_dec_unsigned:                         ; Convert AX to ASCII decimal at ES:DI
    pusha                                       ; Push register states to stack

    call data_kernseg                           ; We want to use kernel variables

    mov word [input_number], ax                 ; Save our number

.clear:
    mov cx, 0x0005                              ; There are up to 5 digits in a 16-bit unsigned number
    mov al, 0x00                                ; NULL char
    push di                                     ; Save our pointer

    rep stosb                                   ; Clear 5-byte buffer
    pop di                                      ; Restore our pointer

    mov cx, 0x0005                              ; There are up to 5 digits in a 16-bit unsigned number

    mov ax, 0x2710                              ; 10,000
    mov dx, 0x0000                              ; Upper word of dividend is 0
    mov bx, 0x000A                              ; Divisor is 10

.length:
    cmp word [input_number], ax                 ; Are we less than this power of 10?
    jae .calc                                   ; If not, continue

    div bx                                      ; Otherwise, check the next power down
    loop .length                                ; Get rid of a leading zero, and check the next one

.zero:
    mov cx, 0x0001                              ; Zero should have 1 digit

.calc:
    mov ax, word [input_number]                 ; Restore our number

.digit:
    mov word [input_number], ax                 ; Save our number
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
    mov ax, word [input_number]                 ; Restore our number

    mov dx, 0x0000                              ; Upper word of dividend is zero
    div bx                                      ; Divide to find the digit in that place value

    add al, 0x30                                ; ASCII digits start here
    stosb                                       ; Store the ASCII character

    mov ax, dx                                  ; We will now do this with the remainder
    loop .digit                                 ; Repeat this process

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; CONVERT BYTE TO HEX: Converts byte-size value to ASCII hexadecimal notation
; IN: AL = Value to convert; ES:DI = Destination buffer (2 bytes)
; OUT: None

conv_byte_hex:                                  ; Convert AL to ASCII hexadecimal word at ES:DI
    pusha                                       ; Save register states to stack

    mov ah, al                                  ; Save a copy here
    and ax, 0x0FF0                              ; Get rid of the lower nibble in AL, upper nibble in AH

    mov bl, al                                  ; Copy the upper nibble
    mov bh, 0x00                                ; Upper byte is zero
    shr bx, 0x4                                 ; Shift it into the correct position

    mov al, bl                                  ; Move this back into AL

.lower:
    add al, 0x30                                ; ASCII digits start here
    cmp al, 0x39                                ; Is this nibble greater than 9?
    jng .upper                                  ; If not, store this and do the next one

    add al, 0x07                                ; Otherwise, fast forward to capital letters A-F

.upper:
    stosb                                       ; Store byte

    mov al, ah                                  ; Our upper nibble
    add al, 0x30                                ; ASCII digits start here

    cmp al, 0x39                                ; Is this nibble greater than 9?
    jng .done                                   ; If so, finish up

    add al, 0x07                                ; Otherwise, fast-forward to capital letters A-F

.done:
    stosb                                       ; Store byte

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; CONVERT BYTE TO UNSIGNED DECIMAL: Converts byte-size value to ASCII decimal notation
; IN: AL = Value to convert; ES:DI = Destination buffer (3 bytes)
; OUT: None

conv_byte_dec_unsigned:                         ; Convert AL to ASCII decimal at ES:DI
    pusha                                       ; Save register states to stack

.clear:
    push ax                                     ; Save our value

    mov cx, 0x0003                              ; Our buffer is 3 bytes
    mov al, 0x00                                ; NULL char
    push di                                     ; Save our location

    rep stosb                                   ; Fill our buffer with zeroes

    pop di                                      ; Restore our location
    pop ax                                      ; Restore our value

.digits:
    cmp al, 0x64                                ; Are we less than this power of ten?
    jnb .hundreds                               ; If not, start here

    cmp al, 0x0A                                ; Are we less than ten?
    jnb .tens                                   ; If not, start here

    jmp .units                                  ; Otherwise, start here

.hundreds:
    mov ah, 0x00                                ; Upper byte of dividend is zero

    mov bl, 0x64                                ; One hundred
    div bl                                      ; Find the number of hundreds

    add al, 0x30                                ; ASCII digits start here
    stosb                                       ; Store byte

    mov al, ah                                  ; Next, operate on the remainder of the last operation

.tens:
    mov ah, 0x00                                ; Upper byte of dividend is zero

    mov bl, 0x0A                                ; Ten
    div bl                                      ; Find the number of tens

    add al, 0x30                                ; ASCII digits start here
    stosb                                       ; Store byte

    mov al, ah                                  ; The remainder is the number of units

.units:
    add al, 0x30                                ; ASCII digits start here
    stosb                                       ; Store byte

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; CONVERT HEX TO WORD: Converts ASCII hexadecimal notation to word-size value
; IN: DS:SI = Source buffer (4 bytes)
; OUT: DX = Resulting value

conv_hex_word:                                  ; Convert hexadecimal dword at DS:SI to binary, store in DX
    push cx                                     ; Save register state to stack

    mov cx, 0x0004                              ; 4-nibble hex value
    call conv_hex_bin                           ; Convert to a binary value

.done:
    pop cx                                      ; Restore register state
    ret                                         ; Return to caller


; CONVERT HEX TO BYTE: Converts ASCII hexadecimal notation to byte-size value
; IN: DS:SI = Source buffer (2 bytes)
; OUT: DL = Resulting value

conv_hex_byte:                                  ; Convert hexadecimal word at DS:SI to binary, store in DL
    push cx
    push dx                                     ; Save register states to stack

    mov cx, 0x0002                              ; 2-nibble hex value
    call conv_hex_bin                           ; Convert to a binary value

    pop cx                                      ; Restore DX
    mov dh, ch                                  ; Make sure DH was how we left it

.done:
    pop cx                                      ; Restore register state
    ret                                         ; Return to caller


; CONVERT UNSIGNED DECIMAL TO WORD: Converts ASCII decimal notation to word-size value
; IN: DS:SI = Source buffer (5 bytes)
; OUT: DX = Resulting value

conv_dec_unsigned_word:                         ; Convert ASCII decimal at DS:SI to binary, store in DX
    push cx                                     ; Save register state to stack

    mov cx, 0x0005                              ; 16-bit decimal values max at 65,535 (5-digit)
    call conv_dec_unsigned_bin                  ; Convert to a binary value

.done:
    pop cx                                      ; Restore register state
    ret                                         ; Return to caller


; CONVERT UNSIGNED DECIMAL TO BYTE: Converts ASCII decimal notation to byte-size value
; IN: DS:SI = Source buffer (3 bytes)
; OUT: DL = Resulting value, CF = Set on error

conv_dec_unsigned_byte:                         ; Convert ASCII decimal at DS:SI to binary, store in DL
    push cx
    push dx                                     ; Save register states to stack

    mov cx, 0x0003                              ; 8-bit decimal values max at 255 (3-digit)
    call conv_dec_unsigned_bin                  ; Convert to a binary value
    jc .done                                    ; If error, we're done

    cmp dh, 0x00                                ; Did it modify the upper byte at all?
    jne .error_overflow                         ; If so, we had an overflow

.done:
    pop cx                                      ; Restore DX

    pushf                                       ; Preserve flags
    mov dh, ch                                  ; Make sure DH was how we left it
    popf                                        ; Restore flags

    pop cx                                      ; Restore register state
    ret                                         ; Return to caller

.error_overflow:
    mov si, iface_error_oflow8
    call println                                ; Display error message

    stc                                         ; Carry flag for error
    jmp .done                                   ; We're done


; CONVERT HEX TO BINARY: Converts ASCII hexadecimal notation to binary value
; IN: CX = Number of hexadecimal digits (bits 0-2, max 4); DS:SI = Source buffer
; OUT: DX = Resulting value, CF = Set on error

conv_hex_bin:                                   ; Convert hexadecimal at DS:SI to binary in DX (CX = digits)
    pusha                                       ; Save register states to stack

    dec cx                                      ; Decrement counter to clear bits
    and cx, 0b00000011                          ; Only look at the rightmost two bits
    inc cx                                      ; Re-increment counter

    mov dx, 0x0000                              ; Clear this out

.nibble:
    lodsb                                       ; Load a byte
    sub al, 0x30                                ; ASCII digits start here

    cmp al, 0x09                                ; Are we a digit 0-9?
    jna .shift                                  ; If so, shift and add this value

    sub al, 0x07                                ; Otherwise, we should be a digit A-F

    cmp al, 0x09                                ; Was our value between 0-9 and A-F?
    jna .error_nan                              ; If so, it wasn't a number

    cmp al, 0x0F                                ; Was the value something else?
    ja .error_nan                               ; If so, it wasn't a number

.shift:
    shl dx, 0x4                                 ; 4 bits in a nibble
    add dl, al                                  ; Add our new nibble

    loop .nibble                                ; Repeat

.done:
    clc                                         ; No error

.end:
    call data_kernseg                           ; We're about to access kernel variables
    mov word [register_bckp_a], dx              ; Save our value

    popa                                        ; Restore register states
    mov dx, word [register_bckp_a]              ; Restore our value

    ret                                         ; Return to caller

.error_nan:
    call data_kernseg                           ; We're about to access kernel variables
    mov si, iface_error_nan                     ; Error message
    call println                                ; Print line

    stc                                         ; Carry flag for error
    jmp .end                                    ; We're done


; CONVERT UNSIGNED DECIMAL TO BINARY: Converts ASCII decimal notation to binary value
; IN: CX = Number of decimal digits (bits 0-2, max 5); DS:SI = Source buffer
; OUT: DX = Resulting value, CF = Set on error

conv_dec_unsigned_bin:                          ; Convert ASCII decimal at DS:SI to binary, store in DX
    pusha                                       ; Push register states to stack

    and cx, 0b00000111                          ; Only look at the rightmost three bits
    cmp cx, 0x0005                              ; Up to 5 digits in a 16-bit unsigned integer
    ja .error_size                              ; If we have invalid input, error

    mov dx, 0x0000                              ; Clear this out

.digit:
    lodsb                                       ; Load a byte

    sub al, 0x30                                ; ASCII digits start here

    cmp al, 0x09                                ; Are we an actual digit?
    ja .error_nan                               ; If not, error

    mov ah, 0x00                                ; Upper byte is 0
    add ax, dx                                  ; Add the binary value to our sum
    jc .error_overflow                          ; If overflow, error

    cmp byte [si], 0x00                         ; Is the next character a NULL char?
    je .finish                                  ; If so, we're done

    loop .multiply                              ; If we have more digits to go, multiply

.finish:
    mov dx, ax                                  ; Otherwise, move back into the correct register
    jmp .done                                   ; We're done

.multiply:
    mov dx, 0x000A                              ; We're using decimal notation
    mul dx                                      ; Set up for the next place value
    mov dx, ax                                  ; Move back into the correct register

    jc .error_overflow                          ; If overflow, error
    jmp .digit                                  ; Otherwise, next digit

.done:
    clc                                         ; No error

.end:
    call data_kernseg                           ; We're about to access kernel variables
    mov word [register_bckp_a], dx              ; Preserve our output

    popa                                        ; Restore register states
    mov dx, word [register_bckp_a]              ; Restore output

    ret                                         ; Return to caller

.error_nan:
    call data_kernseg                           ; We're about to access kernel variables
    mov si, iface_error_nan                     ; Error message
    call println                                ; Print line

    stc                                         ; Carry flag for error
    jmp .end                                    ; We're done

.error_size:
    call data_kernseg                           ; We're about to access kernel variables
    mov si, iface_error_space
    call println                                ; Error message

    stc                                         ; Carry flag for error
    jmp .end                                    ; We're done

.error_overflow:
    call data_kernseg                           ; We're about to access kernel variables
    mov si, iface_error_oflow
    call println                                ; Error message

    stc                                         ; Carry flag for error
    jmp .end                                    ; We're done


; ========================================================================
; LIST SUBROUTINES
; ========================================================================

; GET ITEM FROM LIST: Gets a specific item from a comma-separated list
; IN: DS:SI = Location of list, ES:DI = Output buffer, CX = List index
; OUT: CF = Set on error

get_item_list:                                  ; Get a specific item from a comma-separated list
    pusha                                       ; Save register states to stack

    cmp byte [ds:si], 0x00                      ; Does the list end at the very beginning?
    je .error_index                             ; If so, there are no list items

    mov bx, 0x0000                              ; Commas should not be escaped (BL), we aren't writing (BH)

    jcxz .retrieve                              ; If we've made it to the correct index, load the item
    cld                                         ; Ensure correct direction

.find_comma:
    lodsb                                       ; Load next byte

    cmp al, 0x22                                ; Is this a quotation?
    je .quotation                               ; If so, toggle comma-escape

    cmp al, 0x00                                ; Is this a null character?
    je .null                                    ; If so, the list is over

    cmp bl, 0xFF                                ; Are commas being escaped?
    je .write                                   ; If so, skip over commas

    cmp al, 0x2C                                ; Otherwise, is this a comma?
    je .next_item                               ; If so, we've made it to a new item

.write:
    cmp bh, 0x00                                ; Are we writing?
    je .find_comma                              ; If not, just repeat now

    stosb                                       ; Otherwise, write to output buffer
    jmp .find_comma                             ; And repeat

.quotation:
    xor bl, 0xFF                                ; Toggle comma-escape
    jmp .find_comma                             ; Immediately read the next byte

.null:
    cmp bh, 0x00                                ; Are we writing?
    jne .done                                   ; If so, we're done!

    jmp .error_index                            ; Otherwise, errors

.next_item:
    cmp bh, 0x00                                ; Are we writing?
    jne .done                                   ; If so, we've already finished

    loop .find_comma                            ; Otherwise, decrement CX and repeat

.retrieve:
    mov bh, 0xFF                                ; If we have gone over all the others, we are now writing
    jmp .find_comma                             ; And start reading bytes and copying them

.done:
    mov al, 0x00                                ; Null character
    stosb                                       ; Write it just to make life easier

    clc                                         ; No error

.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.error_index:
    mov si, iface_error_index
    call println                                ; Display error message

    stc                                         ; Carry flag for error
    jmp .end                                    ; We're done


; GET TOTAL ITEMS IN LIST: Gets the total number of items in a list
; IN: DS:SI = Location of list
; OUT: CX = Total number of items

get_total_list:                                 ; Get the total number of list items
    pusha                                       ; Save register states to stack

    mov cx, 0x0000                              ; Start our counter at zero
    cmp byte [ds:si], 0x00                      ; Does the list end right as it begins?
    je .done                                    ; If so, end here

    inc cx                                      ; Otherwise, there's at least one item
    mov bl, 0x00                                ; Commas should not be escaped
    cld                                         ; Ensure correct direction

.find_comma:
    lodsb                                       ; Load next byte

    cmp al, 0x22                                ; Is this a quotation?
    je .quotation                               ; If so, toggle comma-escape

    cmp al, 0x00                                ; Is this a null character?
    je .done                                    ; If so, we're done

    cmp bl, 0xFF                                ; Are commas being escaped?
    je .find_comma                              ; If so, repeat here

    cmp al, 0x2C                                ; Otherwise, is this a comma?
    je .next_item                               ; If so, we've made it to a new item

    jmp .find_comma                             ; Otherwise, repeat

.quotation:
    xor bl, 0xFF                                ; Toggle comma-escape
    jmp .find_comma                             ; Immediately repeat

.next_item:
    inc cx                                      ; Increment counter
    jmp .find_comma                             ; Repeat

.done:
    mov word [register_bckp_a], cx              ; Preserve our output

    popa                                        ; Restore register states
    mov cx, word [register_bckp_a]              ; Restore our output

    ret                                         ; Return to caller


; ========================================================================
; DATA SECTION
; ========================================================================

data_squared:

iface_error_nan     db "ERROR: Not a number.", 0x00
iface_error_space   db "ERROR: Memory size too small.", 0x00
iface_error_oflow   db "ERROR: 16-bit overflow.", 0x00
iface_error_oflow8  db "ERROR: 8-bit overflow.", 0x00

iface_error_index   db "ERROR: Invalid list index.", 0x00
