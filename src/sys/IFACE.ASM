; ========================================================================
; House-DOS KERNEL: INTERFACE SUBSYSTEM
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; INPUT SUBROUTINES
; ========================================================================

input:                                          ; Get input from user, store in paragraph ES:DI
    pusha                                       ; Push register states to stack

    mov word [input_buffer_addr], di            ; Save our address
    mov word [input_end], di                    ; Put our address here too

    add cx, di                                  ; Find the end of the buffer
    mov word [input_buffer_limit], cx           ; Save this

    mov al, 0x00                                ; NULL char (zero)
    sub cx, di                                  ; The number of bytes in this buffer
    cld                                         ; Ensure correct direction

    rep stosb                                   ; Write zeroes over the buffer

    mov di, word [input_buffer_addr]            ; Start at the beginning of our buffer

.key:
    mov ah, 0x00                                ; Get keyboard input
    int 0x16                                    ; BIOS keyboard interrupt

.special_handler:
    cmp ah, 0x1C                                ; Was the RETURN key pressed?
    je .terminate                               ; If so, we're done getting input

    cmp ah, 0x0E                                ; Was the BACKSPACE key pressed?
    je .backspace                               ; If so, erase last char and move cursor left

    cmp ah, 0x4B                                ; Was the LEFT ARROW pressed
    je .left                                    ; If so, move cursor left

    cmp ah, 0x4D                                ; Was the RIGHT ARROW pressed?
    je .right                                   ; If so, move cursor right

    cmp al, 0x20                                ; Is it between SPACE and DEL?
    jl .key                                     ; If not, we can't print this character

    cmp di, word [input_buffer_limit]           ; Have we exhausted our buffer?
    jge .key                                    ; If so, don't continue

.record:
    mov ah, 0x0E                                ; Teletype output
    mov bh, 0x00                                ; Page 0
    mov bl, 0b00000111                          ; Light grey

    int 0x10                                    ; BIOS VGA interrupt (print the char)

    stosb                                       ; Store this char in our buffer
    jmp .key                                    ; Get more input

.backspace:
    cmp di, word [input_buffer_addr]            ; Have we reached the leftmost limit?
    je .key                                     ; If so, we can't do a backspace

    cmp di, word [input_buffer_limit]           ; Are we at the rightmost limit?
    je .backspace_verified                      ; If so, we may not have a NULL char

    cmp byte [es:di], 0x00                      ; Are we at the end of the input?
    jne .key                                    ; If not, we can't do a backspace

.backspace_verified:
    mov ah, 0x0E                                ; Teletype output
    mov al, 0x08                                ; Backwards
    int 0x10                                    ; BIOS VGA interrupt

    mov ah, 0x09                                ; Write char
    mov al, 0x20                                ; Space
    mov cx, 0x01                                ; Write once
    int 0x10                                    ; BIOS VGA interrupt

    dec di                                      ; Decrement the pointer
    mov byte [es:di], 0x00                      ; Erase that char

    jmp .key                                    ; Get more input

.left:
    cmp di, word [input_buffer_addr]            ; Have we reached the leftmost limit?
    je .key                                     ; If so, we can't move left

    mov ah, 0x0E                                ; Teletype output
    mov al, 0x08                                ; Backwards
    int 0x10                                    ; BIOS VGA interrupt

    dec di                                      ; Decrement the pointer

    jmp .key                                    ; Get more input

.right:
    cmp di, word [input_buffer_limit]           ; Have we reached the rightmost limit?
    je .key                                     ; If so, we can't move right

    cmp byte [es:di], 0x00                      ; Is this char a null char?
    je .key                                     ; If so, there's nowhere to move

    mov ah, 0x03                                ; Otherwise, get cursor position
    int 0x10                                    ; BIOS VGA interrupt

    inc dl                                      ; Advance by one col
    mov ah, 0x02                                ; Set cursor position
    int 0x10                                    ; BIOS VGA interrupt

    inc di                                      ; Advance the pointer

    jmp .key                                    ; Get more input

.terminate:
    cmp byte [es:di], 0x00                      ; Are we at the end of our input?
    je .done                                    ; If so, we're done

    inc di                                      ; Otherwise, advance pointer

    cmp di, word [input_buffer_limit]           ; Are we at the end of our buffer?
    je .done                                    ; If so, we're done

    jmp .terminate                              ; Otherwise, repeat

.done:
    mov word [register_bckp_a], di              ; Preserve our return value

    popa                                        ; Restore register states
    mov di, word [register_bckp_a]              ; Restore our return value

    ret                                         ; Return to caller


confirm:                                        ; Ask the user to confirm
    pusha                                       ; Push register states to stack
    clc                                         ; No error yet

    mov si, iface_confirm
    call print_str                              ; Print message

    mov ah, 0x00                                ; Read from keyboard
    int 0x16                                    ; BIOS keyboard interrupt

    mov ah, 0x0E                                ; Teletype output
    mov bh, 0x00
    mov bl, 0b00000111
    int 0x10                                    ; Display the char we typed

    and al, 0b11011111                          ; Capitalize
    cmp al, 0x59                                ; Was Y pressed?
    je .end                                     ; If so, return to caller without error

    stc                                         ; Otherwise, error

.end:
    pushf                                       ; Push flags to stack
    call line_break                             ; Line break
    popf                                        ; Restore flags

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ========================================================================
; DISPLAY SUBROUTINES
; ========================================================================

clear:                                          ; Clear screen
    pusha                                       ; Push register states to stack

    mov ah, 0x00                                ; Set video mode
    mov al, 0x03                                ; 80x25
    int 0x10                                    ; BIOS VGA interrupt

    popa                                        ; Restore register states
    ret                                         ; Return to caller


print_str:                                      ; Prints String in DS:SI
    pusha                                       ; Push register states to stack

    mov ah, 0x0E                                ; Teletype output
    mov bh, 0x00                                ; Page 0
    mov bl, 0b00000111                          ; Light grey
    cld                                         ; Ensure correct direction

.char:
    lodsb                                       ; Load in next character
    cmp al, 0x00                                ; Is this a null character?
    je .ret                                     ; If so, we're done

    int 0x10                                    ; Otherwise, BIOS VGA interrupt
    jmp .char                                   ; And repeat

.ret:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


line_break:                                     ; Moves cursor down one line
    pusha                                       ; Push register states to stack

    mov ah, 0x03                                ; Get cursor position
    mov bh, 0x00                                ; Page 0
    int 0x10                                    ; BIOS VGA interrupt

    cmp dh, 0x18                                ; Are we already at the bottom?
    jl .break                                   ; If so, just move the cursor

    mov ah, 0x06                                ; Scroll up
    mov al, 0x01                                ; 1 line
    mov bh, 0b00000111                          ; Light grey
    mov cx, 0x0000                              ; Upper left
    mov dx, 0x1950                              ; Bottom right
    int 0x10                                    ; BIOS VGA interrupt

    mov dh, 0x17                                ; Second-to-last row

.break:
    mov ah, 0x02                                ; Set cursor position
    mov bh, 0x00                                ; Page 0
    inc dh                                      ; One row down
    mov dl, 0x00                                ; Leftmost column
    int 0x10                                    ; BIOS VGA interrupt

    popa                                        ; Restore register states
    ret                                         ; Return to caller


prompt:                                         ; Set up a prompt for the user
    pusha                                       ; Push register states to stack

    mov ah, 0x0E                                ; Teletype output
    mov bh, 0x00                                ; Page 0
    mov bl, 0b00000111                          ; Light grey

    mov al, 0x20                                ; Space
    int 0x10                                    ; BIOS VGA interrupt

    mov al, 0x2D                                ; Hyphen
    int 0x10                                    ; BIOS VGA interrupt

    mov al, 0x20                                ; Space
    int 0x10                                    ; BIOS VGA interrupt

    popa                                        ; Restore register states
    ret                                         ; Return to caller


print_bytes:                                    ; Prints number of bytes (CX) starting at DS:SI
    pusha                                       ; Push register states to stack

    mov ah, 0x0E                                ; Teletype output
    mov bh, 0x00                                ; Page 0
    mov bl, 0b00000111                          ; Light grey
    cld                                         ; Ensure correct direction

.char:
    lodsb                                       ; Load char and increment pointer

    cmp al, 0x0A                                ; Is it a UNIX newline char?
    je .newline

    int 0x10                                    ; BIOS VGA interrupt
    loop .char                                  ; Repeat

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.newline:
    call line_break                             ; Do a line break
    loop .char                                  ; Next char


display_cursor:                                 ; Display cursor if CF flag is cleared; otherwise, hide it
    pusha                                       ; Save register states to stack

    mov ah, 0x01                                ; Set cursor mode
    mov ch, 0b00000110                          ; Slow blink, scan line 6
    mov cl, 0b00000111                          ; Scan line 7

    jnc .done                                   ; If cleared, proceed
    or ch, 0b00100000                           ; Otherwise, make cursor invisible

.done:
    int 0x10                                    ; BIOS VGA interrupt

    popa                                        ; Restore register states
    ret                                         ; Return to caller


move_cursor:                                    ; Move cursor to DH, DL
    pusha                                       ; Save register states to stack

    cmp dh, 0x19                                ; Are we out of bounds?
    jae .done                                   ; If so, we're done

    cmp dl, 0x50                                ; Are we out of bounds?
    jae .done                                   ; If so, we're done

    mov ah, 0x02                                ; Set cursor position
    mov bh, 0x00                                ; Page 0
    int 0x10                                    ; BIOS VGA interrupt

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller    


println:                                        ; Prints String in DS:SI, then does a line break
    pusha                                       ; Save register states to stack

    call print_str                              ; Print
    call line_break                             ; Line break

    popa                                        ; Restore register states
    ret                                         ; Return to caller


block:                                          ; Draws a block of char AL size CX color BL bits 3-0 at DH, DL
    pusha                                       ; Save register states to stack
    push ax                                     ; Save our character
    push cx                                     ; Save our block size

    mov word [register_bckp_a], dx              ; Save our requested location

.get_position:
    mov ah, 0x03                                ; Get cursor position
    mov bh, 0x00                                ; Page 0
    int 0x10                                    ; BIOS VGA interrupt

    push dx                                     ; Save initial cursor position

.set_position:
    mov dx, word [register_bckp_a]              ; Our requested location
    call move_cursor                            ; Set cursor position

    pop dx                                      ; Restore initial cursor position

.draw:
    pop cx                                      ; Restore our block size
    pop ax                                      ; Restore our character
    mov ah, 0x09                                ; Write char/attribute
    int 0x10                                    ; BIOS VGA interrupt

.restore_cursor:
    mov ah, 0x02                                ; Set cursor position
    int 0x10                                    ; BIOS VGA interrupt

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


get_key_nonblocking:                            ; Returns scan code/ASCII of key pressed in AX, CF set if no key
    pusha                                       ; Save register states to stack

    mov ah, 0x01                                ; Get key (nonblocking)
    int 0x16                                    ; BIOS keyboard interrupt

    mov word [register_bckp_a], ax              ; Save our key

    je .no_key                                  ; If the zero flag is set, there was no key pressed

.remove:
    mov ah, 0x00                                ; Otherwise, remove the key from the keyboard buffer
    int 0x16                                    ; BIOS keyboard interrupt

    jmp .done                                   ; We're done

.no_key:
    stc                                         ; Set carry flag for no key 

.done:
    popa                                        ; Restore register states
    mov ax, word [register_bckp_a]              ; Restore our key

    ret                                         ; Return to caller


done:                                           ; Prints the DONE message, then does a line break
    pusha                                       ; Save register states to stack

    mov ax, 0x2000
    mov ds, ax                                  ; Segment in which we're loaded

    mov si, iface_done                          ; Message to print
    call println                                ; Print line

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ========================================================================
; DATA SECTION
; ========================================================================

iface_data:

input_buffer_addr   dw 0x0000
input_end           dw 0x0000
input_buffer_limit  dw 0x0000

iface_done          db "Done!", 0x00
iface_aborting      db "Aborting.", 0x00
iface_confirm       db " Press Y to confirm: ", 0x00
