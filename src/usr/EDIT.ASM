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

    jc .load                            ; If failed, work with contents of buffer

    mov ah, 0x2A                        ; Verify file from parameter
    mov cx, 0x0000                      ; First parameter
    int 0x7E

    jc .load                            ; If failed, work with contents of buffer

    mov ax, 0x4020                      ; Output file
    int 0x7E

    mov ax, 0x4140                      ; Reset output buffer pointer
    int 0x7E

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

    mov ax, 0x5910                      ; Get line address/length
    int 0x7E

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
    add dx, bx                          ; Add to get row multiplied by 80 (number of spaces left onscreen)

    cmp cx, dx                          ; Do we have enough spaces left for this line?
    jg .bytes_line                      ; If not, perform a different operation

    mov ax, 0x5900                      ; Otherwise, retrieve line
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
    mov ax, 0x5800                      ; Manually retrieve bytes
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

    mov ax, 0x4114                      ; Get line/column numbers for our output buffer pointer
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

    mov ax, 0x5910                      ; Get line info
    mov cx, word [linecounter]          ; The starting line on screen
    int 0x7E

    push si                             ; Preserve starting line address

    mov ax, 0x4112                      ; Get output buffer pointer
    int 0x7E

    pop dx                              ; Restore starting line address

    cmp di, dx                          ; Are we behind where the line actually begins?
    jl .rowup                           ; If so, avoid infinite loop, start from one row higher

    mov ax, 0x5800                      ; Get bytes starting from that point
    mov cx, di                          ; Print bytes of how far into the file
    sub cx, dx                          ; Minus the bytes offscreen
    mov si, dx                          ; Start from the starting line
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

    mov ah, 0x46                        ; Otherwise, insert this character
    int 0x7E

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
    mov ax, 0x4C00                      ; Backspace 1 character
    int 0x7E

    jmp .load                           ; Print edited version

.delete:
    mov ax, 0x4D00                      ; Delete 1 character
    int 0x7E

    jmp .load                           ; Print edited version

.newline:
    mov ah, 0x46                        ; Insert byte
    mov al, 0x0A                        ; Insert a newline character
    int 0x7E

    jmp .load                           ; Print edited version

.left_arrow:
    mov ax, 0x4120                      ; Advance pointer
    std                                 ; Go backward
    int 0x7E

    jmp .footer                         ; Update footer/cursor position

.right_arrow:
    mov ax, 0x4112                      ; Get pointer
    int 0x7E

    mov ax, 0x4113                      ; Get endpoint
    int 0x7E

    sub cx, 0x0002                      ; Don't count the final newline
    cmp di, cx                          ; Is our pointer at/beyond the end of the buffer?
    jnb .edit                           ; If so, do nothing

    mov ax, 0x4120                      ; Otherwise, advance pointer
    cld                                 ; Go forward
    int 0x7E

    jmp .footer                         ; Update footer/cursor position

.up_arrow:
    mov ax, 0x4114                      ; Get line and column of pointer
    int 0x7E

    cmp cx, 0x0000                      ; Are we on the first line?
    je .edit                            ; If so, do nothing

    mov ax, 0x5910                      ; Otherwise, get info of line
    dec cx                              ; Previous line
    int 0x7E

    cmp cx, dx                          ; Is the column number less than the length of the line above us?
    jbe .short_line                     ; If so, go to the end of that line

    add si, dx                          ; Otherwise, add our column number
    mov di, si                          ; Move address into di

    mov ax, 0x4110                      ; Set pointer
    int 0x7E

    jmp .footer                         ; Update footer

.down_arrow:
    mov ax, 0x4114                      ; Get line and column of pointer
    int 0x7E

    mov ax, 0x5910                      ; Get line info
    inc cx                              ; Next line
    int 0x7E

    jc .edit                            ; If we're on the last line, do nothing

    cmp cx, dx                          ; Is the column number less than the length of the line below us?
    jbe .short_line                     ; If so, go to the end of that line

    add si, dx                          ; Add our column number
    mov di, si                          ; Move address into di

    mov ax, 0x4110                      ; Set pointer
    int 0x7E

    jmp .footer                         ; Update footer

.short_line:
    mov ax, 0x4110                      ; Set pointer
    add si, cx                          ; End of line
    mov di, si                          ; Go to this address
    dec di                              ; Avoid an O.B.O.E
    int 0x7E

    jmp .footer

.line_cut:
    mov ax, 0x4114                      ; Get line and column
    int 0x7E

    push cx                             ; Save line number

    mov ax, 0x5900                      ; Get line
    mov di, line_storage                ; Our buffer
    int 0x7E

    mov ax, 0x5910                      ; Get line info
    int 0x7E

    mov word [cline_length], cx         ; Store line length here

    pop cx                              ; Restore line number
    call delete_line                    ; Now delete the line

    jmp .load                           ; Print edited version

.line_copy:
    mov ax, 0x4114                      ; Get line and column
    int 0x7E

    mov ax, 0x5900                      ; Get line
    mov di, line_storage                ; Our buffer
    int 0x7E

    mov ax, 0x5910                      ; Get line info
    int 0x7E
    mov word [cline_length], cx         ; Store line length here

    jmp .load                           ; Print edited version

.line_paste:
    mov ax, 0x4114                      ; Get line and column
    int 0x7E

    mov ax, 0x4910                      ; Insert line
    mov si, line_storage                ; From buffer (what's been copied)
    int 0x7E

    jmp .load                           ; Print edited version

.line_delete:
    mov ax, 0x4114                      ; Get line and column
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

    mov ax, 0x5910                      ; Get line info
    int 0x7E

    mov ax, 0x4110                      ; Set pointer
    mov di, si                          ; Beginning of line
    int 0x7E

    mov ah, 0x45                        ; Insert bytes (shift left)
    add si, cx                          ; Start of next line
    mov di, si                          ; Shift starting from here
    stc                                 ; Unsigned integer
    std                                 ; Shift left
    int 0x7E

    popa                                ; Restore register states
    ret                                 ; Return to caller


save_file:                              ; Save the file
    pusha                               ; Save register states to stack

    mov ah, 0x0F                        ; Set interface config
    mov al, 0b00000010                  ; Error messages on, commentary off
    int 0x7E

    mov ah, 0x4F                        ; Write buffer to disk
    mov si, fname                       ; File name
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
