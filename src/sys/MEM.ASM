; ========================================================================
; House-DOS KERNEL: BUFFER SUBSYSTEM
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; BUFFER ROUTINES
; ========================================================================

; OUTPUT BYTES: Outputs a certain nummber of bytes to the I/O buffer at the pointer location
; IN: DS:SI = Source buffer; CX = Number of bytes; [buffer_out_pointer] = Destination index
; OUT: [buffer_out_pointer] = Initial value + bytes copied; [buffer_endpoint] = New endpoint

out_bytes:                                      ; Output bytes to the I/O buffer
    pusha                                       ; Save register states to stack

    call extra_bseg                             ; Write to the I/O buffer
    mov di, word [gs:buffer_out_pointer]        ; Write starting at our pointer
    jcxz .done                                  ; If counter is zero, skip
    cld                                         ; Ensure correct direction

    push cx                                     ; Preserve counter

    rep movsb                                   ; Copy bytes over

    pop cx                                      ; Restore counter
    add word [gs:buffer_out_pointer], cx        ; Update buffer pointer
    jc error_oflow                              ; If there was a carry, buffer overflow

    call update_endpoint                        ; Update buffer endpoint

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; OUTPUT BYTE: Outputs a byte to the I/O buffer at the pointer location
; IN: AL = Byte to output; [buffer_out_pointer] = Destination index
; OUT: [buffer_out_pointer] = Initial value + bytes copied; [buffer_endpoint] = New endpoint

out_byte:                                       ; Output byte to the I/O buffer
    pusha                                       ; Save register states to stack

    call extra_bseg                             ; Write to the I/O buffer
    mov di, word [gs:buffer_out_pointer]        ; Write at our pointer

    stosb                                       ; Write byte

    add word [gs:buffer_out_pointer], 0x0001    ; Increment buffer pointer
    jc error_oflow                              ; If there was a carry, buffer overflow

    call update_endpoint                        ; Update buffer endpoint

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; OUTPUT BYTES MANUALLY: Writes bytes to the I/O buffer at a specified location
; IN: DS:SI = Source buffer; CX = Number of bytes; DI = Destination index
; OUT: SI = Initial value + bytes copied; DI = Initial value + bytes copied; [buffer_endpoint] = New endpoint

out_man:                                        ; Output bytes manually
    push cx                                     ; Save register state to stack

    call extra_bseg                             ; Write to the I/O buffer
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Copy bytes

    call update_man_endpoint                    ; Manually update endpoint

    pop cx                                      ; Restore register state
    ret                                         ; Return to caller


; OUTPUT TO LINE: Outputs a line (ending in LF) to the I/O buffer as a certain line
; IN: DS:SI = Input buffer; CX = Line number
; OUT: SI = Initial value + bytes copied; CF = Set on error

out_line:                                       ; Output to line
    pusha                                       ; Save register states to stack
    push si                                     ; Preserve source
    push ds                                     ; And its segment
    push cx                                     ; Preserve line number

    call get_line_length                        ; Get the length of our new line
    mov ax, cx                                  ; Store in AX

    pop cx                                      ; Restore line number
    call get_line_info                          ; Get the address/length of the line in the buffer
    jc .done                                    ; If error, we're done
    push si                                     ; Otherwise, preserve the address of the line

    add si, cx                                  ; Shift starting from the end of the line
    dec si                                      ; Avoid an O.B.O.E with the newline
    sub cx, ax                                  ; Subtract to get difference in length
    neg cx                                      ; Negate (positive values shift right)
    clc                                         ; Signed integer

    call shift_buffer                           ; Shift buffer to make room/constrict

    pop di                                      ; Restore the line address as destination
    pop ds                                      ; Restore the source segment
    pop si                                      ; And the source pointer
    jc .done                                    ; If overflow, we're done

    mov cx, ax                                  ; Use the length of the new line as the counter
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Copy bytes

    call update_man_endpoint                    ; Manually update endpoint
    clc                                         ; No error

.done:
    mov word [gs:register_bckp_a], si           ; Preserve source index

    popa                                        ; Restore register states
    mov si, word [gs:register_bckp_a]           ; Restore source index

    ret                                         ; Return to caller

.error_line:
    mov ax, 0x0500                              ; Invalid line number
    call error                                  ; Handle this error

    add sp, 0x0004                              ; Balance the stack
    jmp .done                                   ; We're done


; INSERT BYTES: Outputs bytes to the buffer at the pointer location, shifts everything out of the way
; IN: DS:SI = Source buffer; CX = Number of bytes; [buffer_out_pointer] = Destination index
; OUT: [buffer_out_pointer] = Initial value + bytes copied; [buffer_endpoint] = New endpoint

out_ins_bytes:                                  ; Insert bytes into the buffer
    pusha                                       ; Save register states to stack
    push si                                     ; Preserve source
    push ds                                     ; And its segment

    mov si, word [gs:buffer_out_pointer]        ; Shift everything to the right of our pointer
    stc                                         ; Unsigned integer
    cld                                         ; Shift to the right
    call shift_buffer                           ; Shift everything over

    pop ds                                      ; Restore data segment
    pop si                                      ; Restore source
    jc .done                                    ; If overflow, we're done
    push cx                                     ; Preserve counter

    call extra_bseg                             ; Write to the I/O buffer
    mov di, word [gs:buffer_out_pointer]        ; Write starting at our pointer
    jcxz .done                                  ; If counter is zero, skip
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Copy bytes over

    pop cx                                      ; Restore counter
    add word [gs:buffer_out_pointer], cx        ; Update buffer pointer
    jc error_oflow                              ; If there was a carry, buffer overflow

    call update_endpoint                        ; Update buffer endpoint

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; INSERT BYTE: Outputs a byte to the buffer at the pointer location, shifts everything out of the way
; IN: AL = Byte to output; [buffer_out_pointer] = Destination index
; OUT: [buffer_out_pointer] = Initial value + bytes copied; [buffer_endpoint] = New endpoint

out_ins_byte:                                   ; Insert a byte into the buffer
    pusha                                       ; Save register states to stack

    mov si, word [gs:buffer_out_pointer]        ; Shift everything to the right of our pointer
    mov cx, 0x0001                              ; Offset by one
    clc                                         ; Signed integer
    call shift_buffer                           ; Shift everything over
    jc .done                                    ; If overflow, we're done

    call extra_bseg                             ; Write to the I/O buffer
    mov di, word [gs:buffer_out_pointer]        ; Write at our pointer

    stosb                                       ; Write byte

    add word [gs:buffer_out_pointer], 0x0001    ; Increment buffer pointer
    jc error_oflow                              ; If there was a carry, buffer overflow

    call update_endpoint                        ; Update buffer endpoint

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; INPUT BYTES: Copies a byte from the I/O buffer at the pointer location to an address
; IN: [buffer_in_pointer] = Source index; CX = Number of bytes; ES:DI = Destination index
; OUT: [buffer_in_pointer] = Initial value + bytes copied; CX = Number of bytes copied

in_bytes:                                       ; Copy bytes from the I/O buffer
    pusha                                       ; Save register states to stack

    call data_bseg                              ; Read from the I/O buffer
    mov si, word [gs:buffer_in_pointer]         ; Read starting at our pointer

    add cx, si                                  ; Add to counter to get final index
    cmp cx, word [gs:buffer_endpoint]           ; Will we end up going past the endpoint?
    jna .read                                   ; If not, proceed

    mov cx, word [gs:buffer_endpoint]           ; Otherwise, read up to the endpoint
    inc cx                                      ; Avoid an O.B.O.E

.read:
    sub cx, si                                  ; Subtract pointer to get number of bytes to copy

    jcxz .done                                  ; If counter is zero, skip
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Copy bytes

.done:
    mov cx, si                                  ; Our current position in the buffer
    sub cx, word [gs:buffer_in_pointer]         ; Subtract former position to get bytes copied

    mov word [gs:buffer_in_pointer], si         ; Update buffer pointer
    cmp si, word [gs:buffer_endpoint]           ; Check against endpoint

    mov word [gs:register_bckp_a], cx           ; Preserve counter

    popa                                        ; Restore register states
    mov cx, word [gs:register_bckp_a]           ; Restore counter

    ret                                         ; Return to caller


; INPUT BYTE: Loads a byte from the I/O buffer at the pointer location
; IN: [buffer_in_pointer] = Source index
; OUT: AL = Byte at that location; [buffer_in_pointer] = Initial value + bytes copied

in_byte:                                        ; Load byte from the I/O buffer
    push si                                     ; Save register state to stack

    call data_bseg                              ; Read from the I/O buffer
    mov si, word [gs:buffer_in_pointer]         ; Read at our pointer

    lodsb                                       ; Load byte

    inc word [gs:buffer_in_pointer]             ; Increment buffer pointer
    cmp si, word [gs:buffer_endpoint]           ; Check against endpoint

    pop si                                      ; Restore register state
    ret                                         ; Return to caller


; INPUT BYTES MANUALLY: Loads bytes from the I/O buffer at a specified location
; IN: SI = Source index; CX = Number of bytes; ES:DI = Destination buffer
; OUT: SI = Initial value + bytes copied; DI = Initial value + bytes copied

in_man:                                         ; Load bytes manually
    push cx                                     ; Save register state to stack

    call data_bseg                              ; Read from the I/O buffer
    jcxz .done                                  ; If counter is zero, avoid endless loop
    cld                                         ; Ensure correct direction

.byte:
    cmp si, word [gs:buffer_endpoint]           ; Check pointer against endpoint
    ja .done                                    ; If we've gone through everything, we're done!

    movsb                                       ; Otherwise, copy byte
    loop .byte                                  ; Repeat

.done:
    cmp si, word [gs:buffer_endpoint]           ; Check against endpoint

    pop cx                                      ; Restore register state
    ret                                         ; Return to caller


; INPUT LINE: Loads a specific line from the I/O buffer
; IN: CX = Line number; ES:DI = Destination index
; OUT: DI = Initial value + bytes copied

in_line:                                        ; Load a line manually
    pusha                                       ; Save register states to stack
    push es                                     ; Preserve segment

    call get_line_info                          ; Get line address and length

    pop es                                      ; Restore segment
    jc .done                                    ; If no such line, we're done

    call data_bseg                              ; Read from the I/O buffer
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Otherwise, copy bytes

.done:
    mov word [gs:register_bckp_a], di           ; Preserve destination

    popa                                        ; Restore register states
    mov di, word [gs:register_bckp_a]           ; Restore destination

    ret                                         ; Return to caller


; SHIFT I/O BUFFER: Shifts everything past one index in the buffer by a certain number of bytes (right by default)
; IN: CX = Offset; SI = Starting index; [buffer_endpoint] = Buffer endpoint; CF = Set for unsigned int; DF = Set to shift left (if unsigned)
; OUT: [buffer_endpoint] = New endpoint; CF = Set if overflow

shift_buffer:                                   ; Shift everything in the buffer over
    pusha                                       ; Save register states to stack

    call data_bseg
    call extra_bseg                             ; Work with data in the I/O buffer

    jnc .sign                                   ; If signed, figure out the sign

    pushf                                       ; Otherwise, push FLAGS
    pop ax                                      ; Pop into AX

    test ax, 0x0400                             ; Is DF set?
    jnz .left_unsigned                          ; If so, shift left

    jmp .right                                  ; Otherwise, shift right

.sign:
    cmp cx, 0x0000                              ; Is our offset negative?
    jl .left                                    ; If so, shift left

.right:
    push cx                                     ; Preserve positive offset
    push si                                     ; Preserve starting index

    mov si, word [gs:buffer_endpoint]           ; Start at the end of the buffer
    mov di, si                                  ; Destination and source should be the same
    add di, cx                                  ; Add the offset to get the initial destination

    pop cx                                      ; Restore starting index
    sub cx, di                                  ; Subtract to get bytes to the right
    neg cx                                      ; Requires negation

    std                                         ; Move from right to left
    rep movsb                                   ; Move everything

    pop cx                                      ; Restore offset
    add word [gs:buffer_endpoint], cx           ; Add offset to get new buffer endpoint

    jmp .done                                   ; We're done!

.left_unsigned:
    neg cx                                      ; Treat the unsigned int as negative

.left:
    push cx                                     ; Preserve negative offset

    mov di, si                                  ; Destination and source should be the same
    add di, cx                                  ; Add the offset to get the final destination

    mov cx, word [gs:buffer_endpoint]           ; Start counter at the end of the buffer
    sub cx, si                                  ; Subtract to get total number of bytes to be moved

    cld                                         ; Move from left to right
    rep movsb                                   ; Move everything

    pop cx                                      ; Restore offset
    neg cx                                      ; Make positive
    sub word [gs:buffer_endpoint], cx           ; Subtract offset to get new buffer endpoint

.done:
    jc error_oflow                              ; If there was a carry, buffer overflow

    popa                                        ; Otherwise, restore register states
    ret                                         ; Return to caller


; CLEAR I/O BUFFER: Overwrites everything in the file buffer with zeroes and resets pointers/endpoint
; IN: None
; OUT: None (segments)

clear_buffer:                                   ; Clear the I/O buffer (0x10000-0x1FFFF)
    pusha                                       ; Save register states to stack

    call extra_bseg                             ; Write to the I/O buffer
    mov di, 0x0000                              ; Start from the beginning

    mov al, 0x00                                ; All zeroes
    mov cx, 0xFFFF                              ; Clear every byte
    cld                                         ; Ensure correct direction

    rep stosb                                   ; Move zeroes in

    mov word [gs:buffer_out_pointer], 0x0000    ; Reset buffer pointer
    mov word [gs:buffer_in_pointer], 0x0000     ; Reset input buffer pointer

    mov word [gs:buffer_endpoint], 0x0000       ; Reset buffer endpoint

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; CLEAR EXECUTION BUFFER: Overwrites everything in the execution segment
; IN: None
; OUT: None (segments)

clear_execution:                                ; Clear the execution buffer (0x40000-0x4FFFF)
    pusha                                       ; Save register states to stack

    call extra_binseg                           ; Write to the execution buffer
    mov di, 0x0000                              ; Start from the beginning

    mov al, 0x00                                ; All zeroes
    mov cx, 0xFFFF                              ; Clear every byte
    cld                                         ; Ensure correct direction

    rep stosb                                   ; Move zeroes in

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; GET ADDRESS OF LINE: Gets the memory address of a certain line in the input (file) buffer
; IN: CX = Line number
; OUT: SI = Address of start of line; CF = Set on error

get_line_addr:                                  ; Get address of specific line from file buffer
    pusha                                       ; Save register states to stack

    call data_bseg                              ; Where our file is loaded
    mov si, 0x0000                              ; Start at the beginning of the file buffer

    jcxz .done                                  ; If line zero, we're already done
    cld                                         ; Otherwise, ensure correct direction

.find_newline:
    lodsb                                       ; Read the next byte

    cmp al, 0x0A                                ; Is this a newline?
    je .next_line                               ; If so, that's one line down

    cmp si, 0xFFFF                              ; Have we reached the end of the buffer?
    je .error_line                              ; If so, error

    jmp .find_newline                           ; Otherwise, repeat

.next_line:
    loop .find_newline                          ; Decrement CX and repeat
    clc                                         ; If we're done, no error

.done:
    mov word [gs:register_bckp_a], si           ; Preserve our output

    popa                                        ; Restore register states
    mov si, word [gs:register_bckp_a]           ; Restore our output

    ret                                         ; Return to caller

.error_line:
    mov ax, 0x0500                              ; Invalid line number
    call error                                  ; Handle this error

    jmp .done                                   ; We're done


; GET LENGTH OF LINE: Gets the number of characters up to and including the next newline character
; IN: DS:SI = Start of line
; OUT: CX = Number of characters; CF = Set if zero

get_line_length:                                ; Get the number of characters up to the next newline (inclusive)
    pusha                                       ; Save register states to stack

    mov cx, 0x0001                              ; Start counter here (count the newline character)
    cld                                         ; Ensure correct direction

.byte:
    lodsb                                       ; Load new byte

    cmp al, 0x0A                                ; Is this a newline character?
    je .done                                    ; If so, we're done!

    cmp si, 0x0000                              ; Have we looped over the buffer?
    je .zero                                    ; If so, return a zero

    inc cx                                      ; Otherwise, increment our counter
    jmp .byte                                   ; And repeat

.done:
    mov word [gs:register_bckp_a], cx           ; Preserve our output

    popa                                        ; Restore register states
    mov cx, word [gs:register_bckp_a]           ; Restore our output

    ret                                         ; Return to caller

.zero:
    mov cx, 0x0000                              ; Put zero into our counter
    stc                                         ; Carry flag
    jmp .done                                   ; We're done!


; GET LINE/COL FROM ADDRESS: Converts an address to the line and col numbers
; IN: SI = Address
; OUT: CX = Line number; DX = Col number

addr_line_col:                                  ; Convert address to line/col
    pusha                                       ; Save register states to stack

    mov bx, 0x0000                              ; Start line at zero
    mov dx, 0x0000                              ; Start col at zero

    mov cx, si                                  ; Loop through this many bytes
    jcxz .done                                  ; If counter is zero, avoid an endless loop

    call data_bseg                              ; Read from the file buffer
    mov si, 0x0000                              ; Start from the first byte

    cld                                         ; Ensure correct direction

.char:
    lodsb                                       ; Load next byte

    cmp al, 0x0A                                ; Is this a newline?
    je .next_line                               ; If so, we've hit the next line

    inc dx                                      ; Otherwise, increment col number
    loop .char                                  ; Repeat with next character

    jmp .done                                   ; If no more characters, we're done

.next_line:
    inc bx                                      ; Increment line number
    mov dx, 0x0000                              ; Clear column number

    loop .char                                  ; Repeat with next character

.done:
    mov word [gs:register_bckp_a], bx           ; Preserve the line
    mov word [gs:register_bckp_b], dx           ; Preserve the col

    popa                                        ; Restore register states

    mov cx, word [gs:register_bckp_a]           ; Restore the row into CX
    mov dx, word [gs:register_bckp_b]           ; Restore the line

    ret                                         ; Return to caller


; WRITE LINE: Writes a line into the file buffer
; IN: CX = Line number; DS:SI = Input buffer
; OUT: CF = Set on error

write_line:                                     ; Write line to file buffer
    pusha                                       ; Save register states to stack

    push ds
    push si                                     ; Save our input buffer location
    push cx                                     ; Preserve our line number

    call get_line_length                        ; Get the length of the line we're about to put in
    mov ax, cx                                  ; Save in this register for now

.current_line:
    pop cx                                      ; Restore our line number
    call get_line_addr                          ; Get the address of our line
    jc .done                                    ; If error, we're done
    push si                                     ; Save this address

    call data_bseg                              ; We're doing to be reading from the file buffer
    call get_line_length                        ; Get the length of the line as it is

.subtract:
    sub cx, ax                                  ; Subtract to get the offset
    neg cx                                      ; Negate it (positive values shift right)
    clc                                         ; Ensure signed integer is used

    call shift                                  ; Shift the file buffer to make room/constrict

    pop di                                      ; Restore the address of the line as the destination
    pop si
    pop ds                                      ; Restore the input buffer as the source

    push cx                                     ; Preserve offset (it will be our return value)

    mov cx, ax                                  ; Set counter to the length of the new line
    cld                                         ; Ensure correct direction
    rep movsb                                   ; Copy all bytes

    pop cx                                      ; Restore offset

.done:
    mov word [gs:register_bckp_a], cx           ; Preserve output

    popa                                        ; Restore register states
    mov cx, word [gs:register_bckp_a]           ; Restore output

    ret                                         ; Return to caller


; SHIFT FILE BUFFER: Shifts everything past one point in the file buffer by a certain number of bytes
; IN: CX = Number of bytes by which to offset right; SI = Starting index; CF = Set for unsigned integer; DF = Set to shift left (if unsigned)
; OUT: None

shift:                                          ; Shift everything from one point on by a certain number of chars
    pusha                                       ; Save register states to stack

    call data_bseg
    call extra_bseg                             ; We're going to be working in the I/O buffer

    jnc .sign                                   ; If signed, proceed

    pushf                                       ; Otherwise, push FLAGS register
    pop ax                                      ; Pop into AX

    test ax, 0x0400                             ; Is the direction flag set?
    jz .right                                   ; If not, shift right
    jmp .left                                   ; Otherwise, shift left

.sign:
    cmp cx, 0x0000                              ; Are we positive or negative?
    jl .left                                    ; If negative, shift left

.right:
    push si                                     ; Save our index

    mov di, 0xFFFF                              ; Start at the top of the buffer
    mov si, di                                  ; Destination and source should be the same by default
    sub si, cx                                  ; Subtract the offset to get the correct source index

    pop cx                                      ; Restore our index
    inc cx                                      ; Avoid an O.B.O.E with index vs. qty
    neg cx                                      ; Negate it to get the total number of bytes to be moved

    std                                         ; Move from right to left
    rep movsb                                   ; Move everything

    jmp .done                                   ; We're done!

.left:
    mov di, si                                  ; Destination and source should be the same by default
    add di, cx                                  ; Add the offset to get the final destination

    mov cx, 0xFFFF                              ; Start counter at the top of the buffer
    sub cx, si                                  ; Subtract to get the total number of bytes to be moved

    cld                                         ; Move from left to right
    rep movsb                                   ; Move everything

.pad:
    mov al, 0x00                                ; NULL char
    mov cx, 0xFFFF                              ; Start our counter at the top of the buffer
    sub cx, di                                  ; Subtract to get the total number of bytes to zero out

    rep stosb                                   ; Pad with null characters

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; INDENT OUTPUT BUFFER POINTER: Positions the output buffer relative to the start of the current line
; IN: DX = Offset from start of line (col)
; OUT: None

indent_out_pointer:
    pusha                                       ; Save register states to stack
    push dx                                     ; Preserve offset

    call data_bseg                              ; Read from the I/O buffer
    mov si, word [gs:buffer_out_pointer]        ; At our output buffer pointer
    std                                         ; Look in reverse

.newline:
    lodsb                                       ; Look at next byte

    cmp al, 0x0A                                ; Is it a newline?
    je .sum                                     ; If so, proceed

    cmp si, 0xFFFE                              ; Have we reached the beginning of the buffer?
    je .sum                                     ; If so, proceed

    jmp .newline                                ; Otherwise, repeat

.sum:
    pop dx                                      ; Restore offset

    inc si                                      ; Avoid an O.B.O.E
    add si, dx                                  ; Add our offset
    mov word [gs:buffer_out_pointer], si        ; This is our new output buffer pointer

    call update_endpoint                        ; Update buffer endpoint

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ========================================================================
; BUFFER SUBROUTINES
; ========================================================================

; UPDATE OUTPUT ENDPOINT: Update the pointer for the end of the output
; IN: [buffer_out_pointer] = Current pointer value
; OUT: [buffer_endpoint] = New total

update_endpoint:                                ; Update the buffer endpoint
    pusha                                       ; Save register states to stack

    mov ax, word [gs:buffer_out_pointer]        ; Our current buffer pointer
    cmp ax, word [gs:buffer_endpoint]           ; Is our current pointer higher than the current endpoint?
    jna .done                                   ; If not, we're done

    mov word [gs:buffer_endpoint], ax           ; Otherwise, the new endpoint becomes our current pointer

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; UPDATE OUTPUT ENDPOINT MANUALLY: Update the pointer for the end of the output manually
; IN: DI = Current pointer value
; OUT: [buffer_endpoint] = New total

update_man_endpoint:                            ; Manually update the buffer endpoint
    cmp di, word [gs:buffer_endpoint]           ; Is our pointer higher than the current endpoint?
    jna .done                                   ; If not, we're done

    mov word [gs:buffer_endpoint], si           ; Otherwise, the new endpoint becomes our current pointer

.done:
    ret                                         ; Return to caller


; CHECK END OF BUFFER: Ensures the buffer ends with a newline, pads the remainder with null characters
; IN: [buffer_endpoint] = End of buffer
; OUT: [buffer_endpoint] = End of buffer

check_end_buffer:                               ; End buffer with newline, pad remainder with zeroes
    pusha                                       ; Save register states to stack

    call data_bseg                              ; Read from I/O buffer
    mov si, word [gs:buffer_endpoint]           ; At the endpoint

    cmp byte [si-0x01], 0x0A                    ; Is the last byte in the buffer a newline?
    je .zeroes                                  ; If so, proceed

    mov byte [si], 0x0A                         ; Otherwise, place a newline character
    inc word [gs:buffer_endpoint]               ; Increment the endpoint

.zeroes:
    call extra_bseg                             ; Write to the I/O buffer
    mov di, word [gs:buffer_endpoint]           ; Just after the end of the buffer

    mov cx, di                                  ; The counter should be the same
    neg cx                                      ; Negate to get bytes up to 0xFFFF
    dec cx                                      ; Avoid an O.B.O.E
    jcxz .done                                  ; If zero, avoid an endless loop
    cld                                         ; Ensure correct direction

    mov al, 0x00                                ; NULL characters
    rep stosb                                   ; Write bytes in

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; GET LINE INFO: Gets information about a specific line in the I/O buffer
; IN: CX = Line number
; OUT: CF = Set if line does not exist; SI = Address of line; CX = Length of line

get_line_info:                                  ; Get information about a line
    pusha                                       ; Save register states to stack

    call extra_bseg                             ; Scan the I/O buffer
    mov di, 0x0000                              ; Starting at the beginning
    mov al, 0x0A                                ; Scan for a newline character
    cld                                         ; Ensure correct direction

    jcxz .find_eol                              ; If line counter is zero, avoid an endless loop

.find_newline:
    push cx                                     ; Preserve counter for lines

    mov cx, word [gs:buffer_endpoint]           ; The number of bytes in the buffer
    sub cx, di                                  ; Subtract position to get relative number of bytes
    jbe .no_line                                ; If no more space in the buffer, this line doesn't exist

    repne scasb                                 ; Scan buffer

    pop cx                                      ; Restore counter for lines
    jne .no_line                                ; If not found, this line doesn't exist

    loop .find_newline                          ; Otherwise, repeat

.find_eol:
    mov cx, word [gs:buffer_endpoint]           ; The number of bytes in the buffer
    sub cx, di                                  ; Subtract position to get relative number of bytes
    jbe .no_line                                ; If no more space in the buffer, this line doesn't exist

    push di                                     ; Otherwise, preserve line address

    repne scasb                                 ; Scan buffer

    mov cx, di                                  ; The end of the line
    pop di                                      ; Restore the beginning

    jne .no_line                                ; If not found, this isn't a valid line
    sub cx, di                                  ; Otherwise, subtract to get length

.done:
    mov word [gs:register_bckp_a], di           ; Preserve line address
    mov word [gs:register_bckp_b], cx           ; Preserve line length

    popa                                        ; Restore register states
    mov si, word [gs:register_bckp_a]           ; Restore line address
    mov cx, word [gs:register_bckp_b]           ; Restore line length

    ret                                         ; Return to caller

.no_line:
    stc                                         ; Carry-flag
    jmp .done                                   ; We're done


; ========================================================================
; SEGMENTATION SUBROUTINES
; ========================================================================

data_bseg:                                      ; Sets the data segment to the I/O buffer segment
    push 0x1000                                 ; I/O buffer
    pop ds                                      ; Set segment register

    ret                                         ; Return to caller


data_binseg:                                    ; Sets the data segment to the binary segment
    push 0x4000                                 ; Command execution space
    pop ds                                      ; Set segment register

    ret                                         ; Return to caller


data_kernseg:                                   ; Sets the data segment to the kernel segment
    push 0x2000                                 ; Kernel
    pop ds                                      ; Set segment register

    ret                                         ; Return to caller


data_memseg:                                    ; Sets the data segment to the user buffer segment
    push 0x5000                                 ; User buffer
    pop ds                                      ; Set segment register

    ret                                         ; Return to caller


extra_bseg:                                     ; Sets the extra segment to the I/O buffer segment
    push 0x1000                                 ; I/O buffer
    pop es                                      ; Set segment register

    ret                                         ; Return to caller


extra_binseg:                                   ; Sets the extra segment to the binary segment
    push 0x4000                                 ; Command execution space
    pop es                                      ; Set segment register

    ret                                         ; Return to caller


extra_kernseg:                                  ; Sets the extra segment to the kernel segment
    push 0x2000                                 ; Kernel
    pop es                                      ; Set segment register

    ret                                         ; Return to caller


extra_memseg:                                   ; Sets the extra segment to the user buffer segment
    push 0x5000                                 ; User buffer
    pop es                                      ; Set segment register

    ret                                         ; Return to caller


; ========================================================================
; DATA SECTION
; ========================================================================

mem_data:

buffer_out_pointer  dw 0x0000                   ; Output buffer pointer
buffer_in_pointer   dw 0x0000                   ; Input buffer pointer

buffer_endpoint     dw 0x0000                   ; Output endpoint
mem_buffer_endpoint dw 0x0000                   ; Output endpoint (secondary buffer)

iface_mem_clear     db "Clearing file buffer...", 0x00
iface_mem_bin       db "Loading file into binary buffer...", 0x00

iface_error_line    db "ERROR: Invalid line number.", 0x00
