; ========================================================================
; House-DOS KERNEL: HANDLING ROUTINES
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; ERROR HANDLER
; ========================================================================

error:                                          ; The error handler
    pusha                                       ; Save register states to stack

    call setup_segments                         ; We're going to read from and write to kernel variables

.sys:                                           ; System errors
    cmp ax, 0x0000
    je sys_errors.idk                           ; Unknown error

    cmp ax, 0x0001
    je sys_errors.cancelled                     ; Cancelled

    cmp ax, 0x0002
    je sys_errors.param                         ; Missing Parameter

    cmp ax, 0x0010
    je sys_errors.divzero                       ; Divide by zero


sys_errors:                                     ; Kernel error string setup

.idk:
    push error_sys_idk                          ; Unknown error
    jmp error_print

.cancelled:
    push error_sys_cancelled                    ; Cancelled
    jmp error_print

.param:
    push error_sys_param                        ; Missing parameter
    jmp error_print

.divzero:
    push error_sys_divzero                      ; Divide by zero
    jmp error_print


error_print:                                    ; Display the error message
    mov di, hex_buffer                          ; Our buffer
    call conv_word_hex                          ; Convert error code to hexadecimal

    mov si, error_preamble
    call print_str                              ; Display the error preamble

    mov si, hex_buffer                          ; The error number
    mov cx, 0x0004                              ; 16-bit integer is 4 hex digits
    call print_bytes                            ; Print the number

    mov si, error_link
    call print_str                              ; Display the error link

    pop si                                      ; Restore our error message
    call println                                ; Print the message

.done:
    stc                                         ; Carry-flag for error
    popa                                        ; Restore register states
    ret                                         ; Return to caller


error_messages:

error_preamble      db "KERNEL ERROR 0x", 0x00
error_link          db ": ", 0x00

error_sys_idk       db "An error was encountered.", 0x00
error_sys_cancelled db "Cancelled by user.", 0x00
error_sys_param     db "Parameter not given.", 0x00
error_sys_divzero   db "Divide by zero attempted.", 0x00


data_handling:

hex_buffer          dq 0x00000000