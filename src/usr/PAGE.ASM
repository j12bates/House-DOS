; ========================================================================
; House-DOS PAGE COMMAND
; 
; Written by Jacob Bates
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
; Main code
; ========================================================================

main:
    mov ax, 0x4300                      ; Set default output device to NUL
    int 0x7E

    mov ah, 0x1A                        ; Switch display page
    stc                                 ; Switch to secondary
    int 0x7E

.repaint:
    mov ah, 0x06                        ; Clear screen
    int 0x7E

    mov ah, 0x08                        ; Set cursor position
    mov dx, 0x0000                      ; Upper-left corner
    int 0x7E

    mov ax, 0x5900                      ; Retrieve line from input
    mov cx, word [start_line]           ; The first line to display
    mov di, dest_buffer                 ; Our buffer
    int 0x7E

    jc .done                            ; If error, we're done

    mov ax, word [start_line_rows]      ; Number of rows to skip
    mov bx, 0x0050                      ; 80 bytes per row
    mul bx                              ; Multiply to get bytes
    mov si, ax                          ; Product belongs in SI
    add si, dest_buffer                 ; Add start of buffer to get absolute address

    call print_rows                     ; Print as rows
    jc .footer                          ; If no more space, proceed

.repaint_line:
    mov ax, 0x5900                      ; Retrieve line from input
    inc cx                              ; Next line
    mov di, dest_buffer                 ; Our buffer
    int 0x7E

    jc .footer                          ; If invalid line number, proceed

    mov si, dest_buffer                 ; The start of our buffer
    call print_rows                     ; Print as rows
    jc .footer                          ; If invalid line number, proceed

    jmp .repaint_line                   ; Otherwise, repeat

.footer:
    mov ah, 0x08                        ; Set cursor position
    mov dx, 0x1800                      ; Lower-left corner
    int 0x7E

    mov al, byte [status]               ; Read status byte
    mov byte [status], 0x00             ; Reset status byte

    mov si, msg_end                     ; End message
    cmp al, 0x01                        ; Are we at the end of the input?
    je .draw_footer                     ; If so, write this

    jmp .input                          ; If none of the above, proceed

.draw_footer:
    mov ah, 0x0B                        ; Print formatted
    mov bl, 0b01110000                  ; Black on light grey
    int 0x7E

.input:
    mov ah, 0x15                        ; Get next keypress
    int 0x7E

    cmp ah, 0x49                        ; Was it PAGE UP?
    je .pg_up                           ; If so, up one page

    cmp ah, 0x48                        ; Was it UP ARROW?
    je .up                              ; If so, up one row

    cmp ah, 0x50                        ; Was it the DOWN ARROW?
    je .down                            ; If so, down one row

    cmp ah, 0x51                        ; Was it PAGE DOWN?
    je .pg_down                         ; If so, down one page

    cmp ah, 0x01                        ; Was it ESCAPE?
    je .done                            ; If so, we're done!

    jmp .input                          ; Otherwise, try again

.pg_up:
    mov cx, 0x0018                      ; 24 rows
    call move_rows_up                   ; Move up

    jmp .repaint                        ; Repaint screen

.up:
    mov cx, 0x0001                      ; One row
    call move_rows_up                   ; Move up

    jmp .repaint                        ; Repaint screen

.down:
    mov cx, 0x0001                      ; One row
    call move_rows_down                 ; Move down

    jmp .repaint                        ; Repaint screen

.pg_down:
    mov cx, 0x0018                      ; 24 rows
    call move_rows_down                 ; Move down

    jmp .repaint                        ; Repaint screen

.done:
    mov ah, 0xFF                        ; We're done
    int 0x7E


print_rows:                             ; Prints a line in rows (SI = Start, DI = End), sets CF if out of space
    pusha                               ; Save register states to stack

.row:
    mov ah, 0x0D                        ; Get cursor position
    int 0x7E

    cmp dx, 0x1800                      ; Are we at the lower-left corner?
    je .end                             ; If so, we're out of space

    mov cx, di                          ; Move end of line into counter
    sub cx, si                          ; Subtract start to get length of line

    cmp cx, 0x0050                      ; Is there only one row left?
    jna .print                          ; If so, proceed

    mov cx, 0x0050                      ; Otherwise, print one row

.print:
    mov ah, 0x10                        ; Print bytes
    int 0x7E

.next:
    add si, cx                          ; Advance pointer
    cmp si, di                          ; Have we reached the end of the line?
    je .done                            ; If so, we're done!

    jmp .row                            ; Otherwise, repeat

.done:
    popa                                ; Restore register states
    ret                                 ; Return to caller

.end:
    stc                                 ; Carry-flag for no more space
    jmp .done                           ; We're done!


move_rows_down:                         ; Move a certain number of rows (CX) down
    pusha                               ; Save register states to stack

.line:
    push cx                             ; Preserve counter

    mov ax, 0x5910                      ; Get line info
    mov cx, word [start_line]           ; The starting line
    int 0x7E

    mov bx, 0x0050                      ; The number of bytes per row
    mov ax, word [start_line_rows]      ; The number of rows being skipped
    mul bx                              ; Multiply to get number of bytes being skipped

    add ax, bx                          ; Try skipping one more row
    cmp cx, ax                          ; Is there another full row left in the starting line?
    jb .advance_line                    ; If not, advance a line

    inc word [start_line_rows]          ; Otherwise, skip another row

    pop cx                              ; Restore counter
    loop .line                          ; Repeat

    jmp .done                           ; If we've reached this point, we're done!

.advance_line:
    mov ax, 0x5910                      ; Get line info
    mov cx, word [start_line]           ; The starting line
    inc cx                              ; The next one
    int 0x7E

    pop cx                              ; Restore counter
    jc .eof                             ; If invalid line number, we're at the end of the input

    inc word [start_line]               ; Otherwise, start with next line
    mov word [start_line_rows], 0x0000  ; Reset skipped rows

    loop .line                          ; Repeat

.done:
    popa                                ; Restore register states
    ret                                 ; Return to caller

.eof:
    mov byte [status], 0x01             ; End of input
    jmp .done                           ; We're done!


move_rows_up:                           ; Move a certain number of rows (CX) up
    pusha                               ; Save register states to stack

.line:
    push cx                             ; Preserve counter

    mov ax, 0x5910                      ; Get line info
    mov cx, word [start_line]           ; The starting line
    int 0x7E

    cmp word [start_line_rows], 0x0000  ; Do we have any rows above us?
    je .retreat_line                    ; If not, go back a line

    dec word [start_line_rows]          ; Otherwise, move up one row

    pop cx                              ; Restore counter
    loop .line                          ; And repeat

    jmp .done                           ; If we've reached this point, we're done!

.retreat_line:
    pop cx                              ; Pop counter
    cmp word [start_line], 0x0000       ; Are we at the very first line?
    je .done                            ; If so, we're done!
    push cx                             ; Otherwise, push counter

    mov ax, 0x5910                      ; Get line info
    mov cx, word [start_line]           ; The starting line
    dec cx                              ; Next line up
    int 0x7E

    mov ax, cx                          ; Line length
    mov dx, 0x0000                      ; Upper word of dividend is zero
    mov bx, 0x0050                      ; The number of bytes per row
    div bx                              ; Divide to get number of rows

    pop cx                              ; Restore counter
    jc .done                            ; If invalid line number, we're done

    dec word [start_line]               ; Otherwise, start with previous line
    mov word [start_line_rows], ax      ; Start at the lowest possible row

    loop .line                          ; Repeat

.done:
    popa                                ; Restore register states
    ret                                 ; Return to caller


data:

start_line      dw 0x0000               ; The first line to show onscreen
start_line_rows dw 0x0000               ; The number of 80-column rows to skip

status          db 0x00                 ; Status byte

msg_end         db "END OF INPUT", 0x00

creator         db "House-DOS Developers", 0x00
desc            db "Utility for scrolling down through a file/input without editing.", 0x00
usage           db "PAGE", 0x0A
                db "IN: Content to view", 0x00

dest_buffer:                            ; Space for lines
