; ========================================================================
; House-DOS KERNEL: DEVICE SUBSYSTEM
;
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; DEVICE ROUTINES
; ========================================================================

; OUTPUT TO TELETYPE: Outputs the contents of the buffer in teletype mode
; IN: [buffer_total] = Total number of bytes to write
; OUT: None

tty_out:                                        ; Output to teletype
    pusha                                       ; Save register states to stack

    call data_fileseg                           ; Read from I/O buffer
    mov si, 0x0000                              ; Starting at the beginning
    mov cx, word [gs:buffer_endpoint]           ; The total number of bytes
    jcxz .done                                  ; If zero, don't do anything
    clc                                         ; Newlines should act as newlines

    call print_bytes                            ; Print bytes

    mov si, cx                                  ; Use the counter as an address
    cmp byte [si-0x01], 0x0A                    ; Is the last byte a newline?
    je .done                                    ; If so, omit the line break

    call line_break                             ; Line break

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; OUTPUT TO SECONDARY BUFFER: Outputs the contents of the buffer to the secondary buffer
; IN: [buffer_total] = Total number of bytes to write
; OUT: None

mem_out:                                        ; Output to secondary buffer
    pusha                                       ; Save register states to stack

    call data_fileseg                           ; Read from I/O buffer
    mov si, 0x0000                              ; Starting at the beginning

    call extra_memseg                           ; Write to secondary buffer
    mov di, 0x0000                              ; Starting at the beginning

    mov cx, word [gs:buffer_endpoint]           ; The total number of bytes
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Copy bytes

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; OUTPUT TO NULL: Outputs the contents of the buffer to null
; IN: [buffer_total] = Total number of bytes to write
; OUT: None

nul_out:                                        ; Output to null
    ret                                         ; Do nothing with data, return to caller


; ========================================================================
; DEVICE KERNEL ROUTINES
; ========================================================================

; OUTPUT TO DEFAULT: Outputs the contents of the buffer to the default device
; IN: [default_dev] = Default device ID
; OUT: None

default_out:                                    ; Output to default
    pusha                                       ; Save register states to stack

    mov al, byte [default_dev]                  ; Default device ID

    cmp al, 0x00
    je .nul                                     ; NUL

    cmp al, 0x01
    je .tty                                     ; TTY

    cmp al, 0x02
    je .mem                                     ; MEM

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.nul:
    call nul_out                                ; Output to null
    jmp .done                                   ; We're done!

.tty:
    call tty_out                                ; Output in teletype mode
    jmp .done                                   ; We're done!

.mem:
    call mem_out                                ; Output to secondary buffer
    jmp .done                                   ; We're done!


; ========================================================================
; DATA SECTION
; ========================================================================

dev_data:
