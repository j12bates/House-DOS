; ========================================================================
; House-DOS Text Editor
;
; Written by The House-DOS Developers
; ========================================================================

    BITS 16

; ========================================================================
; Header
; ========================================================================

header:
    jmp main                            ; Don't execute the header

h_creator       dw creator              ; Creator string
h_desc          dw desc                 ; Description string
h_usage         dw usage                ; Usage string


; ========================================================================
; MAIN ROUTINE
; ========================================================================

main:
    mov ax, 0x4300                      ; Set default output device to NUL
    int 0x7E

    mov ah, 0x0F                        ; Modify interface config
    mov al, 0b00000011                  ; Turn off error messages and commentary
    int 0x7E

    mov ah, 0x20                        ; Otherwise, get the parameter
    mov cx, 0x0000                      ; First parameter
    mov di, fname                       ; Our filename buffer
    int 0x7E

    jc .buffer_file                     ; If failed, load contents of buffer

    mov ah, 0x28                        ; Load file from first parameter
    int 0x7E

    jc .buffer_file                     ; If failed, load contents of buffer

    mov ah, 0x70                        ; Get size of file
    int 0x7E

    mov word [fsize], ax                ; Store size here

    jmp .load                           ; Proceed

.empty:
    mov ax, 0x4002                      ; Output line break
    int 0x7E

.buffer_file:
    mov ax, 0x4113                      ; Get endpoint of buffer
    int 0x7E

    jcxz .empty                         ; If nothing is in the buffer, we need a line break
    mov word [fsize], cx                ; Store file size here

    jmp .load                           ; Proceed

.get_file_name:
    mov ah, 0x01                        ; Print line
    mov si, request_filename            ; Message to ask for file name
    int 0x7E

    mov ah, 0x04                        ; Get input
    mov di, fname                       ; Put the filename here
    mov cx, 0x000C                      ; Up to 12 characters
    int 0x7E

    jmp .actually_save                  ; Now save this file

.load:
    call draw_header                    ; Print header
    mov cx, word [linecounter]          ; Start with the top line onscreen

.print:
    push cx                             ; Preserve line number
    call get_line_length                ; Get the length of this line

    jc .footer                          ; If error, everything is loaded

    mov ah, 0x0D                        ; Get cursor position
    int 0x7E

    mov dl, dh                          ; Row is all we care about
    mov dh, 0x00                        ; Clear out upper byte
    neg dx                              ; Negate
    add dx, 0x0018                      ; Add 24 to get number of rows remaining (minus reserved bottom row)

    cmp dx, 0x0000                      ; Are we out of rows?
    je .footer                          ; If so, proceed

    shl dx, 0x6                         ; Otherwise, multiply by 64
    mov bx, dx                          ; Copy result
    shr bx, 0x2                         ; Divide copy by 4
    add dx, bx                          ; Add to get row multplied by 80 (number of spaces left onscreen)

    cmp cx, dx                          ; Do we have enough spaces left for this line?
    jg .bytes_line                      ; If not, perform a different operation

    mov ah, 0x64                        ; Otherwise, get line
    pop cx                              ; Restore line number
    push cx                             ; Push back to stack
    mov di, dest_buffer                 ; Copy into buffer
    int 0x7E

    mov ah, 0x10                        ; Print bytes
    mov si, dest_buffer                 ; Print from our buffer
    mov cx, di                          ; The ending index of the line
    sub cx, si                          ; Subtract to get the length of the line
    int 0x7E

.nextline:
    pop cx                              ; Restore line number
    inc cx                              ; Next line

    jmp .print                          ; Load/print next line

.bytes_line:
    mov ah, 0x65                        ; Get address of line
    pop cx                              ; Restore line number
    int 0x7E

    mov ah, 0x62                        ; Get bytes
    mov cx, dx                          ; Number of spaces left
    mov di, dest_buffer                 ; Copy into buffer
    int 0x7E

    mov ah, 0x10                        ; Print bytes
    mov si, dest_buffer                 ; Print from our buffer
    mov cx, di                          ; The ending index of the line
    sub cx, si                          ; Subtract to get the length of the line
    int 0x7E

.footer:
    mov ah, 0x08                        ; Set cursor position
    mov dx, 0x1840                      ; Mid-right, bottom row
    int 0x7E

    mov ah, 0x67                        ; Get line/column numbers
    mov si, word [address]              ; Our address
    int 0x7E

    push dx                             ; Preserve column number

    mov ax, 0x8202                      ; Print word as decimal
    mov dx, cx                          ; Our line number
    inc dx                              ; Start at 1 (for normal people)
    int 0x7E

    mov ah, 0x10                        ; Print bytes
    mov si, colon_char                  ; A colon
    mov cx, 0x0001                      ; One byte
    int 0x7E

    mov ax, 0x8202                      ; Print word as decimal
    pop dx                              ; Restore column number
    inc dx                              ; Start at 1 (for normal people)
    int 0x7E

    mov ax, 0x1920                      ; Print space
    int 0x7E

.set_cursor:
    mov ah, 0x08                        ; Set cursor position
    mov dx, 0x0100                      ; The upper-left corner (avoid the header)
    int 0x7E

    mov ah, 0x65                        ; Get line address
    mov cx, word [linecounter]          ; The starting line on screen
    int 0x7E

    cmp word [address], si              ; Are we behind where the line actually begins?
    jl .rowup                           ; If so, avoid infinite loop, start from one row higher

    mov ah, 0x62                        ; Get bytes starting from that point
    mov cx, word [address]              ; Print bytes of how far into the file
    sub cx, si                          ; Minus the bytes offscreen
    mov di, dest_buffer
    int 0x7E

    mov ah, 0x10                        ; Print bytes
    mov si, dest_buffer                 ; Print from our buffer
    int 0x7E

    mov ah, 0x0D                        ; Get cursor position
    int 0x7E

    cmp dh, 0x18                        ; Are we on the bottom row?
    jl .edit                            ; If not, continue

    inc word [linecounter]              ; Otherwise, start from next line
    jmp .load                           ; And try printing again

.rowup:
    dec word [linecounter]              ; Start from one line above
    jmp .load                           ; And try printing again

.edit:
    mov ah, 0x15                        ; Get next keypress
    int 0x7E

    cmp ah, 0x01                        ; Is it an escape?
    je .escape_menu

    cmp ah, 0x0E                        ; Backspace
    je .backspace

    cmp ah, 0x53                        ; Delete key
    je .delete

    cmp ah, 0x4B                        ; Left arrow
    je .left_arrow

    cmp ah, 0x4D                        ; Right arrow
    je .right_arrow

    cmp ah, 0x48                        ; Up arrow
    je .up_arrow

    cmp ah, 0x50                        ; Down arrow
    je .down_arrow

    cmp ah, 0x1C                        ; RETURN to write newline
    je .newline

    cmp ah, 0x3B                        ; F1 to cut
    je .line_cut

    cmp ah, 0x3C                        ; F2 to copy
    je .line_copy

    cmp ah, 0x3D                        ; F3 to paste
    je .line_paste

    cmp ah, 0x3E                        ; F4 to delete line
    je .line_delete

    cmp ah, 0x42                        ; F8 to save
    je .save

    cmp al, 0x00                        ; Is there no ASCII code?
    je .edit                            ; If so, loop

    mov byte [char_write], al           ; Otherwise, save the character to write

    mov ah, 0x6B                        ; Insert byte
    mov di, word [address]              ; Our position
    mov cx, 0x0001                      ; Write 1 byte
    mov si, char_write                  ; Address of our character
    int 0x7E

    inc word [address]                  ; Move 1 character forward
    inc word [fsize]                    ; Increase file size by 1 character

    jmp .load

.escape_menu:
    call draw_header                    ; Print header

    mov ah, 0x02                        ; Print line
    mov si, menu_text                   ; Escape menu text
    int 0x7E

    mov ah, 0x15                        ; Get next keypress
    int 0x7E

    cmp ah, 0x01                        ; Is it escape again?
    je .done                            ; If so, quit

    jmp .load                           ; Otherwise, print file again, then resume editing

.backspace:
    cmp word [address], 0x0000          ; Are we at the beginning of the file?
    je .edit                            ; If so, do nothing

    mov ah, 0x6B                        ; Insert bytes (shift left)
    mov cx, 0xFFFF                      ; Shift 1 left (delete 1 character)
    mov di, word [address]              ; Shift starting from here
    int 0x7E

    dec word [address]                  ; Move cursor back one
    dec word [fsize]                    ; Decrement file size

    jmp .load                           ; Print edited version

.delete:
    mov ax, word [address]              ; Our position in the file
    inc ax                              ; We don't want to ever be on the last character

    cmp ax, word [fsize]                ; Are we at the end of the file?
    jnb .edit                           ; If so, do nothing

    mov ah, 0x6B                        ; Insert bytes (shift left)
    mov cx, 0xFFFF                      ; Shift one left
    mov di, word [address]              ; Shift starting from here
    inc di                              ; Delete character to the right
    int 0x7E

    dec word [fsize]                    ; Decrement file size

    jmp .load                           ; Print edited version

.newline:
    mov di, word [address]              ; Get our address
    mov ah, 0x6B                        ; Insert bytes
    mov cx, 0x01                        ; Write 1 byte
    mov si, newline_char                ; We want to write a newline
    int 0x7E

    inc word [address]                  ; Move 1 character forward
    inc word [fsize]                    ; Increase file size by 1 character

    jmp .load                           ; Print edited version

.left_arrow:
    cmp word [address], 0x0000          ; Are we at the beginning of the file?
    je .edit                            ; If so, do nothing

    dec word [address]                  ; Otherwise, move address back 1
    jmp .footer                         ; Update footer/cursor position

.right_arrow:
    mov ax, word [address]              ; Our position in the file
    inc ax                              ; We don't want to ever be on the last character

    cmp ax, word [fsize]                ; Are we at the end of the file?
    jnb .edit                           ; If so, do nothing

    inc word [address]                  ; Move address forward 1
    jmp .footer                         ; Update footer/cursor position

.up_arrow:
    mov ah, 0x67                        ; Get line and col
    mov si, word [address]              ; Our address in the file
    int 0x7E

    cmp cx, 0x0000                      ; Are we on the first line?
    je .edit                            ; Id so, do nothing

    mov bx, word [address]              ; Our address
    sub bx, dx                          ; Subtract col number to get address of our line
    dec bx                              ; Avoid those O.B.O.Es
    push bx                             ; Save the address of the start of our line

    mov ah, 0x65                        ; Get address of a line
    dec cx                              ; Line above us
    int 0x7E

    mov word [address], si              ; Go to start of line above us
    add word [address], dx              ; Add our column number

    sub bx, si                          ; Subtract to get length of line above us
    inc dx                              ; Avoid an O.B.O.E
    cmp bx, dx                          ; Is the line above us shorter than our col?

    pop bx                              ; Restore address of start of our line
    jae .footer                         ; If not, update footer/cursor position

    mov word [address], bx              ; Otherwise, set our address to this
    jmp .footer                         ; Update footer/cursor position

.down_arrow:
    mov ah, 0x67                        ; Get line and col
    mov si, word [fsize]                ; Get the address of the file size
    dec si                              ; Avoid an O.B.O.E
    int 0x7E

    push cx                             ; Preserve the row number

    mov si, word [address]              ; Our address in the file
    int 0x7E

    pop bx                              ; Restore the last row
    cmp cx, bx                          ; Are we on the last row?
    jnb .edit                           ; If so, do nothing

    mov bx, word [address]              ; Our address
    sub bx, dx                          ; Subtract col number to get address of our line
    dec bx                              ; Avoid those O.B.O.Es

    mov ah, 0x65                        ; Get address of a line
    inc cx                              ; Line below us
    int 0x7E

    mov word [address], si              ; Go to start of line below us
    add word [address], dx              ; Add our column number (go straight down)

    push cx                             ; Preserve line number

    mov ah, 0x67                        ; Convert address to line/col numbers
    mov si, word [address]              ; Our current address
    int 0x7E

    pop bx                              ; Restore line below us
    cmp cx, bx                          ; Is our address on the next line?
    je .footer                          ; If so, update footer/cursor position

    mov ah, 0x65                        ; Get address of line
    mov cx, bx                          ; Line number
    inc cx                              ; 2 lines below us
    int 0x7E

    dec si                              ; Go one character back
    mov word [address], si              ; Go to this address
    jmp .footer                         ; Update footer/cursor position

.line_cut:
    mov ah, 0x67                        ; Get line/col from address
    mov si, word [address]              ; Our current address
    int 0x7E

    push cx                             ; Save line number

    mov ah, 0x64                        ; Get line
    mov di, line_storage                ; Our buffer
    int 0x7E

    call get_line_length                ; Get the length of this line
    mov word [cline_length], si         ; Store here

    pop cx                              ; Restore line number
    call delete_line                    ; Now delete the line

    jmp .load                           ; Print edited version

.line_copy:
    mov ah, 0x67                        ; Get line/col from address
    mov si, word [address]              ; Our current address
    int 0x7E

    mov ah, 0x64                        ; Get line
    mov di, line_storage                ; Our buffer
    int 0x7E

    call get_line_length                ; Get the length of this line
    mov word [cline_length], si         ; Store here

    jmp .load                           ; Print edited version

.line_paste:
    mov ah, 0x67                        ; Get line/col from address
    mov si, word [address]              ; Our current address
    int 0x7E

    mov ah, 0x6D                        ; Insert line
    mov si, line_storage                ; From buffer (what's been copied)
    int 0x7E

    mov ax, word [cline_length]         ; Store length of line that's being pasted
    add word [fsize], ax                ; Increase file size by this much

    jmp .load                           ; Print edited version

.line_delete:
    mov ah, 0x67                        ; Get line and col
    mov si, word [address]              ; Our address in the file
    int 0x7E

    call delete_line                    ; Use the routine

    jmp .load                           ; Print edited version

.save:
    mov ah, 0x08                        ; Set cursor position
    mov dx, 0x1800                      ; Bottom left
    int 0x7E

    cmp word [fname], 0x0000            ; Is there no file name yet (not specified w/ parameter)?
    je .get_file_name                   ; If so, get a file name through user input

.actually_save:
    mov ah, 0x08                        ; Set cursor position
    mov dx, 0x1800                      ; Bottom left
    int 0x7E

    call save_file                      ; Save to disk
    jmp .load                           ; Return to editing

.done:
    mov ax, 0x4111                      ; Set endpoint
    mov cx, word [fsize]                ; Our file size
    int 0x7E

    mov ah, 0xFF                        ; End command
    int 0x7E


draw_header:
    pusha                               ; Save register states

    mov ah, 0x06                        ; Clear screen
    int 0x7E

    mov ah, 0x11                        ; Draw block
    mov al, 0x20                        ; Spaces
    mov bl, 0b10010000                  ; Blinking, blue background, black foreground
    mov cx, 0x0050                      ; The length of one row
    mov dx, 0x0000                      ; Uppermost row, leftmost col
    int 0x7E

    mov ah, 0x02                        ; Print line
    mov si, headermsg                   ; Our message
    int 0x7E

    popa                                ; Restore register states
    ret                                 ; Return to caller


delete_line:                            ; Delete whatever line is in CX
    pusha                               ; Save register states to stack

    mov ah, 0x65                        ; Get line address
    int 0x7E

    mov word [address], si              ; This will be our new cursor position
    push si                             ; Preserve address

    inc cx                              ; Next line
    int 0x7E

    pop cx                              ; Restore address
    sub cx, si                          ; Subtract to get negative length of line (negated, to shift left)

    mov ah, 0x6B                        ; Insert bytes (shift left)
    mov di, si                          ; Shift starting from next line
    int 0x7E

    add word [fsize], cx                ; Add negative length of line to file length

    popa                                ; Restore register states
    ret                                 ; Return to caller


get_line_length:                        ; Get length of the line in CX
    mov ah, 0x65                        ; Get line address
    int 0x7E

    push si                             ; Preserve this address

    inc cx                              ; Go to next line
    int 0x7E

    pop cx                              ; Restore address
    jc .done                            ; If error, we're done

    sub si, cx                          ; Subtract to get length of line
    mov cx, si                          ; Put length in CX

.done:
    ret                                 ; Return to caller


save_file:                              ; Save the file
    pusha                               ; Save register states to stack

    mov ah, 0x0F                        ; Set interface config
    mov al, 0b00000010                  ; Error messages on, commentary off
    int 0x7E

    mov ah, 0x6F                        ; Write file to disk
    mov si, fname                       ; File name
    mov cx, word [fsize]                ; File size
    int 0x7E

    jc main.done                        ; If failed, we're done

    mov ah, 0x0F                        ; Set interface config
    mov al, 0b00000011                  ; Error messages off, commentary off
    int 0x7E

    popa                                ; Restore register states
    ret                                 ; Return to caller


data:

headermsg       db "House-DOS Text Editor", 0x00

fname           dq 0x0000000000000000
                dd 0x00000000
fsize           dw 0x0000

linecounter     dw 0x0000               ; Nearest 23 lines
address         dw 0x0000               ; Address of where we are

cline_length    dw 0x0000               ; Length of line that's been copied or cut

newline_char    db 0x0A
colon_char      db 0x3A
char_write      db 0x00

menu_text       db "Commands:", 0x0A, "F1: Cut line", 0x0A, "F2: Copy line", 0x0A, "F3: Paste line", 0x0A, "F4: Delete line", 0x0A, "F8: Save", 0x0A
                db "Press ESC to exit, any other key to return...", 0x00
save_message    db "File saved!", 0x00
editing_message db "Editing file", 0x00
request_filename db "Please enter a file name: ", 0x00

creator         db "Ben and Jacob", 0x00
desc            db "A text editor for the House-DOS platform.", 0x00
usage           db "EDIT <FILENAME>", 0x0A
                db "Flags: none", 0x00

line_storage:
times 0x50      db 0x00

dest_buffer:
