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
; OUT: [buffer_out_pointer] = Initial value + bytes copied

out_bytes:                                      ; Output bytes to the I/O buffer
    pusha                                       ; Save register states to stack
    push cx                                     ; Preserve counter

    call extra_fileseg                          ; Write to the I/O buffer
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


; OUTPUT BYTE: Outputs a byte to the I/O buffer at the pointer location
; IN: AL = Byte to output; [buffer_out_pointer] = Destination index
; OUT: [buffer_out_pointer] = Initial value + bytes copied

out_byte:                                       ; Output byte to the I/O buffer
    pusha                                       ; Save register states to stack

    call extra_fileseg                          ; Write to the I/O buffer
    mov di, word [gs:buffer_out_pointer]        ; Write at our pointer

    stosb                                       ; Write byte

    inc word [gs:buffer_out_pointer]            ; Increment buffer pointer
    jc error_oflow                              ; If there was a carry, buffer overflow

    call update_endpoint                        ; Update buffer endpoint

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; OUTPUT STRING: Outputs a string to the I/O buffer at the pointer location
; IN: DS:SI = String location; [buffer_out_pointer] = Destination index
; OUT: [buffer_out_pointer] = Initial value + bytes copied

out_str:                                        ; Output string to the I/O buffer
    pusha                                       ; Save register states to stack

    call extra_fileseg                          ; Write to the I/O buffer
    mov di, word [gs:buffer_out_pointer]        ; Write at our pointer
    mov cx, 0x0000                              ; Count the iterations
    cld                                         ; Ensure correct direction

.char:
    lodsb                                       ; Load next character

    cmp al, 0x00                                ; Is it a NULL character?
    je .done                                    ; If so, we're done!

    stosb                                       ; Otherwise, write byte
    loop .char                                  ; Repeat

.done:
    neg cx                                      ; Negate to get positive number of iterations
    add word [gs:buffer_out_pointer], cx        ; This is our new pointer
    jc error_oflow                              ; If there was a carry, buffer overflow

    call update_endpoint                        ; Update buffer endpoint

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; INPUT BYTES: Copies a byte from the I/O buffer at the pointer location to an address
; IN: [buffer_in_pointer] = Source index; CX = Number of bytes; ES:DI = Destination index
; OUT: [buffer_in_pointer] = Initial value + bytes copied; CX = Number of bytes copied

in_bytes:                                       ; Copy bytes from the I/O buffer
    pusha                                       ; Save register states to stack

    call data_fileseg                           ; Read from the I/O buffer
    mov si, word [gs:buffer_in_pointer]         ; Read starting at our pointer
    cld                                         ; Ensure correct direction

.byte:
    cmp si, word [gs:buffer_endpoint]           ; Check pointer against endpoint
    ja .done                                    ; If we've gone through everything, we're done!

    movsb                                       ; Otherwise, copy byte
    loop .byte                                  ; Repeat

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

    call data_fileseg                           ; Read from the I/O buffer
    mov si, word [gs:buffer_in_pointer]         ; Read at our pointer

    lodsb                                       ; Load byte

    inc word [gs:buffer_in_pointer]             ; Increment buffer pointer
    cmp si, word [gs:buffer_endpoint]           ; Check against endpoint

    pop si                                      ; Restore register state
    ret                                         ; Return to caller


; CLEAR I/O BUFFER: Overwrites everything in the file buffer with zeroes and resets pointers/endpoint
; IN: None
; OUT: None (segments)

clear_buffer:                                   ; Clear the I/O buffer (0x10000-0x1FFFF)
    pusha                                       ; Save register states to stack

    call extra_fileseg                          ; Write to the file buffer
    mov di, 0x0000                              ; Start at offset 0

    mov al, 0x00                                ; All zeroes
    mov cx, 0xFFFF                              ; Clear every byte
    cld                                         ; Ensure correct direction

    rep stosb                                   ; Move zeroes in (AL is already 0)

    mov word [gs:buffer_out_pointer], 0x0000    ; Reset buffer pointer
    mov word [gs:buffer_in_pointer], 0x0000     ; Reset input buffer pointer

    mov word [gs:buffer_endpoint], 0x0000       ; Reset buffer endpoint

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; LOAD AS BINARY: Moves everything in the I/O buffer to the binary segment for execution
; IN: None
; OUT: None (segments)

move_file_bin:                                  ; Load the file buffer as a binary
    pusha                                       ; Save register states to stack

    call data_fileseg                           ; Read from the file segment
    call extra_binseg                           ; Load into the binary segment

    mov si, 0x0000
    mov di, 0x0000                              ; Start at offset 0
    mov cx, 0xFFFF                              ; Load 64K
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Copy all bytes over

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; GET ADDRESS OF LINE: Gets the memory address of a certain line in the input (file) buffer
; IN: CX = Line number
; OUT: SI = Address of start of line; CF = Set on error

get_line_addr:                                  ; Get address of specific line from file buffer
    pusha                                       ; Save register states to stack

    call data_fileseg                           ; Where our file is loaded
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
    call data_kernseg                           ; We're about to use kernel variables
    mov word [register_bckp_a], si              ; Preserve our output

    popa                                        ; Restore register states
    mov si, word [register_bckp_a]              ; Restore our output

    ret                                         ; Return to caller

.error_line:
    mov ax, 0x0500                              ; Invalid line number
    call error                                  ; Handle this error

    jmp .done                                   ; We're done


; GET LENGTH OF LINE: Gets the number of characters up to an including the next newline character
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
    mov word [register_bckp_a], cx              ; Preserve our output

    popa                                        ; Restore register states
    mov cx, word [register_bckp_a]              ; Restore our output

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

    call data_fileseg                           ; Read from the file buffer
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
    call data_kernseg                           ; Use kernel variables
    mov word [register_bckp_a], bx              ; Preserve the row
    mov word [register_bckp_b], dx              ; Preserve the col

    popa                                        ; Restore register states

    mov cx, word [register_bckp_a]              ; Restore the row into CX
    mov dx, word [register_bckp_b]              ; Restore the col

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

    call data_fileseg                           ; We're doing to be reading from the file buffer
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
    mov word [register_bckp_a], cx              ; Preserve output

    popa                                        ; Restore register states
    mov cx, word [register_bckp_a]              ; Restore output

    ret                                         ; Return to caller


; SHIFT FILE BUFFER: Shift everything past one point in the file buffer by a certain number of bytes
; IN: CX = Number of bytes by which to offset right; SI = Starting index; CF = Set for unsigned integer; DF = Set to shift left (if unsigned)
; OUT: None

shift:                                          ; Shift everything from one point on by a certain number of chars
    pusha                                       ; Save register states to stack

    call data_fileseg
    call extra_fileseg                          ; We're going to be doing memory operations in the file segment

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

    call data_fileseg                           ; Read from the I/O buffer
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

update_endpoint:                                ; Update the buffer total
    pusha                                       ; Save register states to stack

    mov ax, word [gs:buffer_out_pointer]        ; Our current buffer pointer
    cmp ax, word [gs:buffer_endpoint]           ; Is our current pointer higher than the current endpoint?
    jna .done                                   ; If not, we're done

    mov word [gs:buffer_endpoint], ax           ; Otherwise, the new endpoint becomes our current pointer

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ========================================================================
; SEGMENTATION SUBROUTINES
; ========================================================================

data_fileseg:                                   ; Sets the data segment to the file buffer segment
    push ax                                     ; Save register state to stack

    mov ax, 0x1000
    mov ds, ax                                  ; Segment the file buffer is at

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


data_binseg:                                    ; Sets the data segment to the binary segment
    push ax                                     ; Save register state to stack

    mov ax, 0x4000
    mov ds, ax                                  ; Segment the binary command is loaded in

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


data_kernseg:                                   ; Sets the data segment to the kernel segment
    push ax                                     ; Save register state to stack

    mov ax, 0x2000
    mov ds, ax                                  ; Segment we are loaded in

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


data_memseg:                                    ; Sets the data segment to the secondary buffer segment
    push ax                                     ; Save register state to stack

    mov ax, 0x5000
    mov ds, ax                                  ; Segment the secondary buffer is at

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


extra_fileseg:                                  ; Sets the extra segment to the file buffer segment
    push ax                                     ; Save register state to stack

    mov ax, 0x1000
    mov es, ax                                  ; Segment the file buffer is at

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


extra_binseg:                                   ; Sets the extra segment to the binary segment
    push ax                                     ; Save register state to stack

    mov ax, 0x4000
    mov es, ax                                  ; Segment the binary command is loaded in

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


extra_kernseg:                                  ; Sets the extra segment to the kernel segment
    push ax                                     ; Save register state to stack

    mov ax, 0x2000
    mov es, ax                                  ; Segment we are loaded in

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


extra_memseg:                                   ; Sets the extra segment to the secondary buffer segment
    push ax                                     ; Save register state to stack

    mov ax, 0x5000
    mov es, ax                                  ; Segment the secondary buffer is at

    pop ax                                      ; Restore register state
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
