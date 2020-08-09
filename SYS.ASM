; ========================================================================
; HOUSEDOS KERNEL
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; MAIN ROUTINE
; ========================================================================

main:                                           ; Main code for HouseDOS kernel
    mov ax, 0x2000                              ; The segment in which we are loaded
    mov ds, ax
    mov es, ax

    mov byte [drive_num], dl                    ; Save our boot drive number
    call clear                                  ; Clear screen

    mov ax, 0x1003                              ; Configure attribute bit 7
    mov bl, 0x01                                ; Blink
    int 0x10                                    ; BIOS VGA interrupt

    mov si, iface_welcome
    call print_str                              ; Print welcome message
    call line_break                             ; Line break

    mov si, iface_info
    call print_str                              ; Print info

.command:                                       ; Main loop: Retrieve command from user
    call line_break                             ; Line break
    call line_break                             ; Another line break
    call clear_input                            ; Clear input buffer
    call prompt                                 ; Setup prompt
    call input                                  ; Get input from user
    call line_break                             ; Line break
    call line_break                             ; Another line break

    mov cx, 0x0004                              ; 4 chars
    mov si, cmd_info
    call compare                                ; INFO command
    je info

    mov si, cmd_exit
    call compare                                ; EXIT command
    je exit

.bad_command:
    mov si, iface_command_bad
    call print_str                              ; Display an error message

    jmp .command                                ; Try again


; ========================================================================
; COMMAND ROUTINES
; ========================================================================

info:                                           ; INFO command
    mov si, iface_welcome
    call print_str                              ; Print message
    call line_break                             ; Line break

    mov si, iface_info
    call print_str                              ; Print message

    jmp main.command                            ; We're finished


exit:                                           ; EXIT command:
    call confirm                                ; Ask for confirmation
    jc main.command                             ; If no, we're finished

    int 0x19                                    ; Otherwise, reboot


; ========================================================================
; MISCELLANEOUS SUBROUTINES
; ========================================================================

compare:                                        ; Compare the input given to a command
    pusha                                       ; Push register states to stack

    mov di, prompt_response                     ; Check against our input

;    mov cx, 0x0000                              ; CX should contain the number of chars
;    push si                                     ; Save our command index
;
;.char:
;    cmp si, 0x00                                ; Is it a NULL char?
;    je .comparison                              ; If so, proceed
;
;    inc cx                                      ; Otherwise, that's another char
;    inc si                                      ; Look at the next byte
;    jmp .char                                   ; Repeat
;
;.comparison:
;    pop si                                      ; Restore our index
    repe cmpsb                                  ; Compare strings

    popa                                        ; Restore register states
    ret                                         ; Return to caller


confirm:                                        ; Ask the user to confirm
    pusha                                       ; Push register states to stack

    mov si, iface_confirm
    call print_str                              ; Print message

    mov ah, 0x00                                ; Read from keyboard
    int 0x16                                    ; BIOS keyboard interrupt

    and al, 0b11011111                          ; Capitalize
    cmp al, 0x59                                ; Was Y pressed?
    je .end                                     ; If so, return to caller without error

    stc                                         ; Otherwise, error
    mov ah, 0x0E                                ; Teletype output
    mov bh, 0x00
    mov bl, 0b00000111
    int 0x10                                    ; Display the char we typed

.end:
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


print_str:                                      ; Prints String in SI
    pusha                                       ; Push register states to stack

    mov ah, 0x0E                                ; Teletype output
    mov bh, 0x00

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


clear_input:                                    ; Clear the input buffer
    pusha                                       ; Push register states to stack

    mov di, prompt_response                     ; Our buffer

.zero:
    cmp di, prompt_response+0x10                ; Have we cleared the whole thing?
    jge .ret                                    ; If so, we're done

    mov byte [di], 0x00                         ; Move a zero in
    inc di                                      ; Advance the pointer

.ret:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


input:                                          ; Get input from user
    pusha                                       ; Push register states to stack

    mov di, prompt_response                     ; Our buffer for input

.char:
    mov ah, 0x00                                ; Get keyboard input
    int 0x16                                    ; BIOS keyboard interrupt

    cmp al, 0x0D                                ; Was the RETURN key pressed?
    je .ret                                     ; If so, we're done

    cmp di, prompt_response+0x10                ; Have we exhausted our 16-byte buffer?
    jge .char                                   ; If so, don't continue

    mov ah, 0x0E                                ; Teletype output
    mov bh, 0x00                                ; Page 0
    mov bl, 0b00000111                          ; Light grey
    int 0x10                                    ; BIOS VGA interrupt (print the char)

    and al, 0b11011111                          ; Capitalize
    mov byte [di], al                           ; Store this char in our buffer
    inc di                                      ; Advance the pointer

    jmp .char                                   ; Repeat

.ret:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ========================================================================
; DATA SECTION
; ========================================================================

data:

; Storage data region
prompt_response     dq 0x0000000000000000
                    dq 0x0000000000000000

; Disk operation data region
drive_num           db 0x00
cluster             dw 0x0000
buffer_pointer      dw 0x0000
buffer_segment      dw 0x0000

; Interface strings
iface_welcome       db "HouseDOS v0.0.0, Build 2", 0x00
iface_info          db "By Jacob Bates", 0x00
iface_worked        db "This worked!", 0x00
iface_command_bad   db "Bad command", 0x00
iface_confirm       db "Are you sure? Press Y to confirm: ", 0x00

; Command strings
cmd_info            db "INFO", 0x00
cmd_exit            db "EXIT", 0x00

