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
    stosb                                       ; Store the ASCII character

    pop cx                                      ; Restore our counter
    pop ax                                      ; Restore our word
    loop .nibble                                ; And repeat

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


conv_word_dec_unsigned:                         ; Convert AX to ASCII decimal at ES:DI
    pusha                                       ; Push register states to stack

    mov word [register_bckp_a], ax              ; Save our number

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
    cmp word [register_bckp_a], ax              ; Are we less than this power of 10?
    jae .calc                                   ; If not, continue
    
    div bx                                      ; Otherwise, check the next power down
    loop .length                                ; Get rid of a leading zero, and check the next one

.calc:
    mov ax, word [register_bckp_a]              ; Restore our number

.digit:
    mov word [register_bckp_a], ax              ; Save our number
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
    mov ax, word [register_bckp_a]              ; Restore our number

    mov dx, 0x0000                              ; Upper word of dividend is zero
    div bx                                      ; Divide to find the digit in that place value

    add al, 0x30                                ; ASCII digits start here
    stosb                                       ; Store the ASCII character

    mov ax, dx                                  ; We will now do this with the remainder
    loop .digit                                 ; Repeat this process

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


conv_hex_word:                                  ; Convert hexadecimal dword at DS:SI to binary value in DX
    pusha                                       ; Save register states to stack
    mov cx, 0x0004                              ; 1 byte per nibble
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
    mov word [register_bckp_a], dx              ; Save our value

    popa                                        ; Restore register states
    mov dx, word [register_bckp_a]              ; Restore our value

    ret                                         ; Return to caller

.error_nan:
    mov si, iface_error_nan                     ; Error message
    call println                                ; Print line

    stc                                         ; Carry flag for error
    jmp .done                                   ; We're done


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
    jnl .hundreds                               ; If not, start here

    cmp al, 0x0A                                ; Are we less than ten?
    jnl .tens                                   ; If not, start here

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


conv_rtctime_unix:                              ; Convert an RTC time to a number of seconds (stored in DX:AX)
    pusha                                       ; Save register states to stack

.hours:
    mov al, ch                                  ; Hours are stored here
    call conv_rtcval_byte                       ; Convert to a proper value

    mov ah, 0x00                                ; Upper byte of factor is zero
    mov bx, 0x0E10                              ; Number of seconds in an hour
    mul bx                                      ; Multiply

    push dx
    push ax                                     ; Save value to stack

.minutes:
    mov al, cl                                  ; Minutes are stored here
    call conv_rtcval_byte                       ; Convert to a proper value

    mov ah, 0x00                                ; Upper byte of factor is zero
    mov bx, 0x003C                              ; Number of seconds in a minute
    mul bx                                      ; Multiply

    push ax                                     ; Save value to stack

.seconds:
    mov al, dh                                  ; Seconds are stored here
    call conv_rtcval_byte                       ; Convert to a proper value

    mov ah, 0x00                                ; Upper byte is zero

    pop bx                                      ; Restore seconds from minutes
    add ax, bx                                  ; Add

    pop bx                                      ; Restore seconds from hours
    add ax, bx                                  ; Add

    pop dx                                      ; Restore upper word of hours

.done:
    mov word [register_bckp_a], ax
    mov word [register_bckp_b], dx              ; Save our value

    popa                                        ; Restore register states
    mov ax, word [register_bckp_a]
    mov dx, word [register_bckp_b]              ; Restore our value

    ret                                         ; Return to caller


conv_rtctime_stamp:                             ; Convert an RTC time to a standard HH:MM:SS timestamp at ES:DI
    pusha                                       ; Save register states to stack

.hours:
    mov al, ch                                  ; Hours are stored here
    call conv_byte_hex                          ; Convert to ASCII hex (RTC values are weird)

    add di, 0x0002                              ; We've written two bytes

    mov al, 0x3A                                ; Colon to separate values
    stosb                                       ; Write this byte

.minutes:
    mov al, cl                                  ; Minutes are stored here
    call conv_byte_hex                          ; Convert to ASCII hex (RTC values are weird)

    add di, 0x0002                              ; We've written two bytes

    mov al, 0x3A                                ; Colon to separate values
    stosb                                       ; Write this byte

.seconds:
    mov al, dh                                  ; Seconds are stored here
    call conv_byte_hex                          ; Convert to ASCII hex (RTC values are weird)

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


conv_rtcdate_stamp:                             ; Convert an RTC date to a standard YYYY-MM-DD stamp at ES:DI
    pusha                                       ; Save register states to stack

.year:
    mov ax, cx                                  ; Year is stored here
    call conv_word_hex                          ; Convert to ASCII hex (RTC values are weird)

    add di, 0x0004                              ; We've written four bytes

    mov al, 0x2D                                ; Hyphen to separate values
    stosb                                       ; Write this byte

.month:
    mov al, dh                                  ; Month is stored here
    call conv_byte_hex                          ; Convert to ASCII hex (RTC values are weird)

    add di, 0x0002                              ; We've written two bytes

    mov al, 0x2D                                ; Hyphen to separate values
    stosb                                       ; Write this byte

.day:
    mov al, dl                                  ; Day is stored here
    call conv_byte_hex                          ; Convert to ASCII hex (RTC values are weird)

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


conv_rtcval_byte:                               ; Convert an RTC value in AL to an actual binary value
    cmp al, 0x10                                ; Are we above 0x10?
    jl .done                                    ; If not, we're done

    sub al, 0x06                                ; Otherwise, subtract

    cmp al, 0x1A                                ; Was it above 0x20?
    jl .done                                    ; If not, we're done

    sub al, 0x06                                ; Otherwise, subtract

.done:
    ret                                         ; Return to caller


capitalize_char:                                ; Capitalize char in AL
    cmp al, 0x61                                ; Are we between lowercase A
    jl .end
    cmp al, 0x7A                                ; And lowercase Z?
    jg .end

    and al, 0b11011111                          ; If so, capitalize

.end:
    ret                                         ; Return to caller


power_ten:                                      ; Raise ten to the power in CL, store in DX:AX
    pusha                                       ; Save register states to stack

    mov ax, 0x0001                              ; Start at 1
    mov bx, 0x000A                              ; Multiply by Ten

    cmp cl, 0x0A                                ; Is the power too big?
    ja .error_space                             ; If so, error

    mov ch, 0x00                                ; Clear the upper byte of the counter
    shr cx, 0x1                                 ; Divide by two
    pushf                                       ; We're going to need this later

    cmp ch, 0x00                                ; Are we about to multiply zero times?
    je .check_odd                               ; If so, don't attempt

.find_root:
    mul bx                                      ; Multiply
    loop .find_root                             ; Repeat

.check_odd:
    popf                                        ; Restore flags from before
    jnc .final_product                          ; If not an odd number, we are ready to multiply

    push ax                                     ; Otherwise, save our current value
    mul bx                                      ; Multiply once more

    pop bx                                      ; Restore our value
    mul bx                                      ; And multiply by IT

    jmp .done                                   ; We're done!

.final_product:
    mov bx, ax                                  ; Copy our value
    mul bx                                      ; Square it to get the final product

    clc                                         ; No error

.done:
    mov word [register_bckp_a], ax
    mov word [register_bckp_b], dx              ; Save our value

    popa                                        ; Restore register states
    mov ax, word [register_bckp_a]
    mov dx, word [register_bckp_b]              ; Restore our value

    ret                                         ; Return to caller

.error_space:
    mov si, iface_error_space
    call println                                ; Print message

    stc                                         ; Carry flag for error
    jmp .done                                   ; We're done


; ========================================================================
; DATA SECTION
; ========================================================================

logic_data:

iface_error_nan     db "ERROR: Not a Number.", 0x00
iface_error_space   db "ERROR: Memory size too small.", 0x00
