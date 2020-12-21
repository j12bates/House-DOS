; ========================================================================
; House-DOS KERNEL: INTERFACE SUBSYSTEM
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; INPUT ROUTINES
; ========================================================================

; GET KEYBOARD INPUT: Get user input from the keyboard, and store in the buffer provided
; IN: CX = Buffer size, ES:DI = Location of buffer
; OUT: DI = Initial value + number of characters input

input:                                          ; Get input from user, store in ES:DI
    pusha                                       ; Push register states to stack

    call data_kernseg                           ; We will be using kernel variables

    mov word [input_buffer_addr], di            ; Save our address

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

.num_lock_handler:
    push ax                                     ; Preserve character

    mov ah, 0x02                                ; Read keyboard flags
    int 0x16                                    ; BIOS keyboard interrupt

    test al, 0b00100000                         ; Is NUM-LOCK active?
    pop ax                                      ; Restore character
    jz .special_handler                         ; If not, skip all this

    cmp al, 0x00                                ; Does it have an ASCII code?
    je .special_handler                         ; If not, it's not a num key

    cmp ah, 0x1C                                ; Was the RETURN key pressed?
    je .terminate                               ; If so, we're done getting input

    cmp ah, 0x0E                                ; Was the BACKSPACE key pressed?
    je .backspace                               ; If so, erase last char and move cursor left

    mov ah, 0x00                                ; Otherwise, get rid of the scan code and proceed

.special_handler:
    cmp ah, 0x1C                                ; Was the RETURN key pressed?
    je .terminate                               ; If so, we're done getting input

    cmp ah, 0x0E                                ; Was the BACKSPACE key pressed?
    je .backspace                               ; If so, erase last char and move cursor left

    cmp ah, 0x4B                                ; Was the LEFT ARROW pressed
    je .left                                    ; If so, move cursor left

    cmp ah, 0x4D                                ; Was the RIGHT ARROW pressed?
    je .right                                   ; If so, move cursor right

    cmp ah, 0x47                                ; Was HOME pressed?
    je .home                                    ; If so, move cursor to the beginning

    cmp ah, 0x4F                                ; Was END pressed?
    je .end_input                               ; If so, move cursor to the end of input

    cmp al, 0x20                                ; Is it between SPACE and DEL?
    jl .key                                     ; If not, we can't print this character

    cmp di, word [input_buffer_limit]           ; Have we exhausted our buffer?
    jge .key                                    ; If so, don't continue

.record:
    call teletype_output                        ; Write character

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
    mov al, 0x08                                ; Backwards
    call teletype_output                        ; Write character

    mov ah, 0x0A                                ; Write char
    mov al, 0x20                                ; Space
    mov bh, 0x00                                ; Page 0
    mov cx, 0x01                                ; Write once
    int 0x10                                    ; BIOS VGA interrupt

    dec di                                      ; Decrement the pointer
    mov byte [es:di], 0x00                      ; Erase that char

    jmp .key                                    ; Get more input

.left:
    cmp di, word [input_buffer_addr]            ; Have we reached the leftmost limit?
    je .key                                     ; If so, we can't move left

    mov al, 0x08                                ; Backwards
    call teletype_output                        ; Write character

    dec di                                      ; Decrement the pointer

    jmp .key                                    ; Get more input

.right:
    cmp di, word [input_buffer_limit]           ; Have we reached the rightmost limit?
    je .key                                     ; If so, we can't move right

    cmp byte [es:di], 0x00                      ; Is this char a null char?
    je .key                                     ; If so, there's nowhere to move

    mov ah, 0x08                                ; Get character at cursor position
    mov bh, 0x00                                ; Page 0
    int 0x10                                    ; BIOS VGA interrupt

    call teletype_output                        ; Print the same character and advance cursor
    inc di                                      ; Advance the pointer

    jmp .key                                    ; Get more input

.home:
    cmp di, word [input_buffer_addr]            ; Have we reached the leftmost limit?
    je .key                                     ; If so, get more input

    mov al, 0x08                                ; Otherwise, backwards
    call teletype_output                        ; Write character

    dec di                                      ; Decrement the pointer

    jmp .home                                   ; And repeat

.end_input:
    cmp byte [es:di], 0x00                      ; Are we at the end of our input?
    je .key                                     ; If so, get more input

    mov ah, 0x08                                ; Get character at cursor position
    mov bh, 0x00                                ; Page 0
    int 0x10                                    ; BIOS VGA interrupt

    call teletype_output                        ; Print the same character and advance cursor
    inc di                                      ; Advance the pointer

    cmp di, word [input_buffer_limit]           ; Are we at the end of our buffer?
    je .key                                     ; If so, get more input

    jmp .end_input                              ; Otherwise, repeat

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


; ASK FOR CONFIRMATION: Ask the user to press the Y key to confirm and returns the result
; IN: None
; OUT: CF = Set if confirmation not given

confirm:                                        ; Ask the user to confirm
    pusha                                       ; Push register states to stack

    mov si, iface_confirm
    call print_str                              ; Print message

    mov ah, 0x00                                ; Read from keyboard
    int 0x16                                    ; BIOS keyboard interrupt

    mov ah, 0x0E                                ; Teletype output
    mov bh, 0x00
    int 0x10                                    ; Display the char we typed

    call line_break                             ; Line break

    and al, 0b11011111                          ; Capitalize
    cmp al, 0x59                                ; Was Y pressed?
    stc                                         ; By default, confirmation wasn't given
    jne .end                                    ; If it wasn't, return to caller

    clc                                         ; Otherwise, confirmation given

.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ========================================================================
; DISPLAY ROUTINES
; ========================================================================

; CLEAR SCREEN: Completely clears the screen
; IN: None
; OUT: None

clear:                                          ; Clear screen
    pusha                                       ; Push register states to stack

    mov ah, 0x00                                ; Set video mode
    mov al, 0x03                                ; 80x25
    int 0x10                                    ; BIOS VGA interrupt

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; PRINT STRING: Prints out a string in teletype mode
; IN: DS:SI = Location of string to print
; OUT: None

print_str:                                      ; Prints string in DS:SI
    pusha                                       ; Save register states to stack

    cld                                         ; Ensure correct direction

.char:
    lodsb                                       ; Load in next character

    cmp al, 0x00                                ; Is this a null character?
    je .done                                    ; If so, we're done!

    call teletype_output                        ; Otherwise, write char
    jmp .char                                   ; And repeat

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; PRINT STRING WITH FORMATTING: Prints out a string in a specific color
; IN: DS:SI = Location of string to print; BL = Attribute
; OUT: None

printf:                                         ; Prints string in DS:SI with color attribute in BL
    pusha                                       ; Save register states to stack

    mov bh, 0x00                                ; Page 0
    cld                                         ; Ensure correct direction

.char:
    lodsb                                       ; Load in next character

    cmp al, 0x00                                ; Is this a null character?
    je .done                                    ; If so, we're done!

    mov ah, 0x09                                ; Otherwise, write character and attribute
    mov cx, 0x0001                              ; Write once
    int 0x10                                    ; BIOS VGA interrupt

    call teletype_output                        ; Write char
    jmp .char                                   ; Repeat

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller    


; LINE BREAK: Moves the cursor down one line (scrolls everything else up if no lines available)
; IN: None
; OUT: None

line_break:                                     ; Moves cursor down one line
    pusha                                       ; Push register states to stack

    mov ah, 0x03                                ; Get cursor position
    mov bh, 0x00                                ; Page 0
    int 0x10                                    ; BIOS VGA interrupt

    cmp dh, 0x18                                ; Are we already at the bottom?
    jl .break                                   ; If so, just move the cursor

    mov ah, 0x08                                ; Get character and attribute
    int 0x10                                    ; BIOS VGA interrupt
    mov bh, ah                                  ; Write the next line with this attribute

    mov ah, 0x06                                ; Scroll up
    mov al, 0x01                                ; 1 line
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


; PRINT BYTES: Prints the specified number of bytes in teletype mode
; IN: CX = Number of bytes to print; DS:SI = Input buffer; CF = Set for newlines to act as normal chars
; OUT: None

print_bytes:                                    ; Prints number of bytes (CX) starting at DS:SI
    pusha                                       ; Push register states to stack

    cld                                         ; Ensure correct direction

.char:
    lodsb                                       ; Load char and increment pointer

    pushf                                       ; Preserve flags
    call literal_output                         ; Write character
    popf                                        ; Restore flags

    loop .char                                  ; Repeat

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; INFO MESSAGE: Display a string as an info message (T2 comment)
; IN: DS:SI = String location
; OUT: None

msg_info:                                       ; Print a string as an info message
    pusha                                       ; Save register states to stack
    push si                                     ; Preserve string location
    push ds                                     ; Preserve segment as well

    call data_kernseg                           ; We're about to use a kernel variable
    mov si, iface_info_pfx                      ; Info prefix
    call print_str                              ; Print string

    pop ds                                      ; Restore segment
    pop si                                      ; Restore string location
    call println                                ; Print line

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; WARN MESSAGE: Display a string as a warning message (T2 comment)
; IN: DS:SI = String location
; OUT: None

msg_warn:                                       ; Print a string as a warning message
    pusha                                       ; Save register states to stack
    push si                                     ; Preserve string location
    push ds                                     ; Preserve segment as well

    call data_kernseg                           ; We're about to use a kernel variable
    mov si, iface_warn_pfx                      ; Warning prefix
    call print_str                              ; Print string

    pop ds                                      ; Restore segment
    pop si                                      ; Restore string location
    call println                                ; Print line

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; CHANGE CURSOR VISIBILITY: Sets the cursor to either visible or invisible
; IN: CF = Set to hide, cleared to show
; OUT: None

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


; MOVE CURSOR: Moves the cursor to the specified position
; IN: DH = Row number (0-24), DL = Col number (0-79)
; OUT: None

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


; GET CURSOR POSITION: Gets the current position of the cursor
; IN: None
; OUT: DH = Row number, DL = Col number

get_cursor_pos:                                 ; Get the cursor's position
    pusha                                       ; Save register states to stack

    mov ah, 0x03                                ; Get cursor position
    mov bh, 0x00                                ; Page 0
    int 0x10                                    ; BIOS VGA interrupt

    mov word [register_bckp_a], dx              ; Preserve output

    popa                                        ; Restore register states
    mov dx, word [register_bckp_a]              ; Restore output

    ret                                         ; Return to caller


; INDENT CURSOR: Moves the cursor to the specified col
; IN: DL = Col number (0-79)
; OUT: None

indent:                                         ; Move cursor to the col in DL
    pusha                                       ; Save register states to stack

    mov dh, 0xFF                                ; Completely set row number (wildcard)
    push dx                                     ; Set position to stack

    mov ah, 0x03                                ; Get cursor position
    mov bh, 0x00                                ; Page 0
    int 0x10                                    ; BIOS VGA interrupt

    pop bx                                      ; Restore wildcarded position
    mov dl, 0xFF                                ; Completely set col number (wildcard)
    and dx, bx                                  ; Perform logical AND to preserve row and set column

    call move_cursor                            ; Move the cursor to this new position

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; PRINT LINE: Print string in teletype mode, then line break
; IN: DS:SI = Input buffer
; OUT: None

println:                                        ; Prints String in DS:SI, then does a line break
    pusha                                       ; Save register states to stack

    call print_str                              ; Print
    call line_break                             ; Line break

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; DRAW CHARACTER BLOCK: Draws a block of specific length, character, and color at the specified position
; IN: CX = Length, AL = Character, BL = Color, DH = Row number (0-24), DL = Col number (0-79)
; OUT: None

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


; SET ATTRIBUTE OF ENTIRE SCREEN: Sets the foreground/background colors of all characters on the screen
; IN: BL = Attribute (Bit 7 = Blink; Bits 6-4 = Background; Bits 3-0 = Foreground)
; OUT: None

screen_attribute:                               ; Set the attribute of all characters on screen
    pusha                                       ; Save register states to stack

.cursor:
    mov ah, 0x03                                ; Get cursor position
    mov bh, 0x00                                ; Page 0
    int 0x10                                    ; BIOS VGA interrupt

    push dx                                     ; Preserve cursor position

    mov dx, 0x0000                              ; 0, 0
    call move_cursor                            ; Set cursor position

    mov cx, 0x07D0                              ; There are 2000 characters total

.char:
    mov ah, 0x08                                ; Read char
    int 0x10                                    ; BIOS VGA interrupt

    push cx                                     ; Save our loop counter

    mov ah, 0x09                                ; Write char
    mov cx, 0x0001                              ; Only print once
    int 0x10                                    ; BIOS VGA interrupt

    pop cx                                      ; Restore our loop counter
    loop .next_char                             ; Set up for the next character

    jmp .done                                   ; Otherwise, we're done!

.next_char:
    mov ah, 0x0E                                ; Teletype output (we want to move the cursor forward)
    int 0x10                                    ; BIOS VGA interrupt

    jmp .char                                   ; Repeat

.done:
    pop dx                                      ; Restore cursor position
    call move_cursor                            ; Set cursor position

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; GET KEY BEING PRESSED: Returns the scan code and ASCII code of whatever key is being pressed
; IN: None
; OUT: AH = Scan code, AL = ASCII code, CF = Set if no key

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


; PAUSE UNTIL KEY PRESSED: Pauses everything and prompts the user to press a key
; IN: None
; OUT: None

pause_keypress:                                 ; Pause until the user presses a key
    pusha                                       ; Save register states to stack

    mov si, iface_press_cont
    call print_str                              ; Print message

    mov ah, 0x00                                ; Wait for keypress
    int 0x16                                    ; BIOS keyboard interrupt

    call line_break                             ; Line break

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ========================================================================
; SUBROUTINES
; ========================================================================

; WRITE CHAR TO TELETYPE: Writes a char and moves cursor forward (works with new lines/backspaces)
; IN: AL = ASCII character to write
; OUT: None

teletype_output:                                ; Write character in teletype mode
    pusha                                       ; Save register states to stack

    mov ah, 0x03                                ; Get cursor position
    mov bh, 0x00                                ; Page 0
    int 0x10                                    ; BIOS VGA interrupt

    cmp al, 0x08                                ; Is this a backspace?
    je .backspace                               ; If so, do a backspace

    cmp al, 0x0A                                ; Is this a newline character?
    je .newline                                 ; If so, do a newline

    cmp dx, 0x184F                              ; Are we in the bottom-right corner?
    je .scroll                                  ; If so, scroll everything up

.write:
    mov ah, 0x0E                                ; Teletype output
    int 0x10                                    ; BIOS VGA interrupt

.done:
    popa                                        ; Restore register state
    ret                                         ; Return to caller

.backspace:
    cmp dl, 0x00                                ; Are we in the leftmost col?
    jne .write                                  ; If not, proceed normally

    cmp dh, 0x00                                ; Are we in the uppermost row?
    je .done                                    ; If so, do nothing

    dec dh                                      ; One row up
    mov dl, 0x4F                                ; Rightmost col
    call move_cursor                            ; Move the cursor

    jmp .done                                   ; We're done!

.newline:
    call line_break                             ; Do a line break
    jmp .done                                   ; We're done!

.scroll:
    mov ah, 0x0A                                ; Write char
    mov cx, 0x0001                              ; Write once
    int 0x10                                    ; BIOS VGA interrupt

    call line_break                             ; Do a line break

    jmp .done                                   ; We're done!


; LITERAL CHARACTER OUTPUT: Prints a characterand moves cursor forward (backspaces are actually printed)
; IN: AL = ASCII character to write; CF = Set to print newlines as single characters
; OUT: None

literal_output:                                 ; Prints literal character and advances cursor
    pusha                                       ; Save register states to stack

    jc .print                                   ; If we are to print newlines as characters, proceed

    cmp al, 0x0A                                ; Otherwise, is this a newline char?
    jne .print                                  ; If not, proceed

    call line_break                             ; Otherwise, line break
    jmp .done                                   ; And we're done!

.print:
    mov ah, 0x0A                                ; Print character at cursor position
    mov bh, 0x00                                ; Page 0
    mov cx, 0x0001                              ; Write character once
    int 0x10                                    ; BIOS VGA interrupt

    call advance_cursor                         ; Advance cursor

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ADVANCE CURSOR: Advances the cursor, line-breaking/scrolling if necessary
; IN: None
; OUT: None

advance_cursor:                                 ; Advance cursor
    pusha                                       ; Save register states to stack

    call get_cursor_pos                         ; Get cursor position

    cmp dl, 0x4F                                ; Are we in the rightmost col?
    je .next_line                               ; If so, we have to do a line break

    inc dl                                      ; Otherwise, just increment the col
    call move_cursor                            ; Set the cursor to this new position

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.next_line:
    call line_break                             ; Line break
    jmp .done                                   ; We're done


; ========================================================================
; KERNEL-SPECIFIC ROUTINES
; ========================================================================

; DISPLAY PROMPT: Displays the command prompt
; IN: None
; OUT: None

prompt:                                         ; Set up a prompt for the user
    pusha                                       ; Push register states to stack

    mov ah, 0x0E                                ; Teletype output
    mov bh, 0x00                                ; Page 0

    mov al, 0x20                                ; Space
    int 0x10                                    ; BIOS VGA interrupt

    mov al, 0x2D                                ; Hyphen
    int 0x10                                    ; BIOS VGA interrupt

    mov al, 0x20                                ; Space
    int 0x10                                    ; BIOS VGA interrupt

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; COMMENT: Prints out text as commentary
; IN: DS:SI = String location
; OUT: None

comment:                                        ; Print a string as commentary
    pusha                                       ; Save register states to stack
    push ds                                     ; Preserve segment

    call data_kernseg                           ; We're about to access a kernel variable
    test byte [config_iface], 0b00000010        ; Is the COMMENTARY bit set?

    pop ds                                      ; Restore segment
    jnz .done                                   ; If so, don't print anything

    call print_str                              ; Otherwise, print string

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; COMMENT LINE: Prints out text as commentary, then does a line break
; IN: DS:SI = String location
; OUT: None

comment_line:                                   ; Print a line as commentary
    pusha                                       ; Save register states to stack
    push ds                                     ; Preserve segment

    call data_kernseg                           ; We're about to access a kernel variable
    test byte [config_iface], 0b00000010        ; Is the COMMENTARY bit set?

    pop ds                                      ; Restore segment
    jnz .done                                   ; If so, don't print anything

    call println                                ; Otherwise, print line

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; DONE MESSAGE: Comments the DONE message, then does a line break
; IN: None
; OUT: None (segments)

done:                                           ; Print the DONE comment
    pusha                                       ; Save register states to stack

    call data_kernseg                           ; Segment in which we're loaded

    mov si, iface_done                          ; Message to print
    call comment_line                           ; Print line

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ABORTING MESSAGE: Comments the ABORTING message, then does a line break
; IN: None
; OUT: None (segments)

abort:                                          ; Print the ABORTING comment
    pusha                                       ; Save register states to stack

    call data_kernseg                           ; Segment in which we're loaded

    mov si, iface_aborting                      ; Message to print
    call comment_line                           ; Print line

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ========================================================================
; DATA SECTION
; ========================================================================

iface_data:

input_buffer_addr   dw 0x0000
input_buffer_limit  dw 0x0000

iface_info_pfx      db "INFO: ", 0x00
iface_warn_pfx      db "WARN: ", 0x00

iface_done          db "Done!", 0x00
iface_aborting      db "Aborting.", 0x00
iface_confirm       db " Press Y to confirm: ", 0x00
iface_press_cont    db "Press any key to continue...", 0x00
