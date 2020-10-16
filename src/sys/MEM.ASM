; ========================================================================
; House-DOS KERNEL: MEMORY SUBSYSTEM
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; MEMORY SUBROUTINES
; ========================================================================

clear_file_buffer:                              ; Clear the file buffer (0x10000-0x1FFFF)
    pusha                                       ; Save register states to stack

    call extra_fileseg                          ; Write to the file buffer
    mov di, 0x0000                              ; Start at offset 0

    mov al, 0x00                                ; All zeroes
    mov cx, 0xFFFF                              ; Clear every byte
    cld                                         ; Ensure correct direction

    rep stosb                                   ; Move zeroes in (AL is already 0)

    popa                                        ; Restore register states
    ret                                         ; Return to caller


move_file_bin:                                  ; Load the file buffer as a binary
    pusha                                       ; Save register states to stack

    call data_fileseg                           ; Read from the file segment
    call extra_binseg                           ; Load into the binary segment

    mov si, 0x0000
    mov di, 0x0000                              ; Start at offset 0
    mov cx, 0xFFFF                              ; Repeat for each of the 64K bytes
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Copy all bytes over

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; GET ITEM FROM LIST: Gets a specific item from a comma-separated list
; IN: DS:SI = Location of list, ES:DI = Output buffer, CX = List index
; OUT: CF = Set on error

get_item_list:                                  ; Get a specific item from a comma-separated list
    pusha                                       ; Save register states to stack

    jcxz .retrieve                              ; If we've made it to the correct index, load the item
    cld                                         ; Ensure correct direction

.find_comma:
    lodsb                                       ; Load next byte

    cmp al, 0x2C                                ; Is this a comma?
    je .next_item                               ; If so, we've made it to a new item

    cmp al, 0x00                                ; Is this a null character?
    je .error_index                             ; If so, error

    jmp .find_comma                             ; Otherwise, repeat

.next_item:
    loop .find_comma                            ; Decrement CX and repeat

.retrieve:
    lodsb                                       ; Load next byte

    cmp al, 0x2C                                ; Is this the next comma?
    je .done                                    ; If so, we're done!

    cmp al, 0x00                                ; Is this the null character at the end?
    je .done                                    ; If so, we're done!

    stosb                                       ; Otherwise, write to output buffer
    jmp .retrieve                               ; And repeat

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

    mov cx, 0x0001                              ; Start our counter at one
    cld                                         ; Ensure correct direction

.find_comma:
    lodsb                                       ; Load next byte

    cmp al, 0x2C                                ; Is this a comma?
    je .next_item                               ; If so, we've made it to a new item

    cmp al, 0x00                                ; Is this a null character?
    je .done                                    ; If so, we're done

    jmp .find_comma                             ; Otherwise, repeat

.next_item:
    inc cx                                      ; Increment counter
    jmp .find_comma                             ; Repeat

.done:
    mov word [register_bckp_a], cx              ; Preserve our output

    popa                                        ; Restore register states
    mov cx, word [register_bckp_a]              ; Restore our output

    ret                                         ; Return to caller


; GET ADDRESS OF LINE: Gets the memory address of a certain line in the input (file) buffer
; IN: CX = Line number
; OUT: SI = Address of start of line, CF = Set on error

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
    mov si, iface_error_line
    call println                                ; Print message

    stc                                         ; Carry flag for error
    jmp .done                                   ; We're done


; GET LENGTH OF LINE: Gets the number of characters up to an including the next newline character
; IN: DS:SI = Start of line
; OUT: CX = Number of characters

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
    jmp .done                                   ; We're done!


; WRITE LINE: Writes a line into the file buffer
; IN: CX = Line number, DS:SI = Input buffer
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
; IN: CX = Number of bytes by which to offset right, SI = Starting index
; OUT: None

shift:                                          ; Shift everything from one point on by a certain number of chars
    pusha                                       ; Save register states to stack

    call data_fileseg
    call extra_fileseg                          ; We're going to be doing memory operations in the file segment

    cmp cx, 0x0000                              ; Are we positive or negative?
    jl .left                                    ; If negative, shift left

.right:
    push si                                     ; Save our index

    mov di, 0xFFFF                              ; Start at the top of the buffer
    mov si, di                                  ; Destination and source should be the same by default
    sub si, cx                                  ; Subtract the offset to get the correct source index

    pop cx                                      ; Restore our index
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


extra_fileseg:                                  ; Sets the extra segment to the file buffer segment
    push ax                                     ; Save register state to stack

    mov ax, 0x1000
    mov es, ax                                  ; Segment the file buffer is at

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


; ========================================================================
; DATA SECTION
; ========================================================================

mem_data:


iface_mem_clear     db "Clearing file buffer...", 0x00
iface_mem_bin       db "Loading file into binary buffer...", 0x00

iface_error_index   db "ERROR: Invalid list index.", 0x00
iface_error_line    db "ERROR: Invalid line number.", 0x00
