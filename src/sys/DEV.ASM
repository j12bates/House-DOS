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
; IN: CX = Total number of bytes to write
; OUT: None

tty_out:                                        ; Output to teletype
    pusha                                       ; Save register states to stack

    call data_fileseg                           ; Read from I/O buffer
    mov si, 0x0000                              ; Starting at the beginning

    cmp cx, 0x0001                              ; Are we just a newline?
    jbe .done                                   ; If so, do nothing
    clc                                         ; Newlines should act as newlines

    call print_bytes                            ; Print bytes

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; OUTPUT TO USER BUFFER: Outputs the contents of the buffer to the user buffer
; IN: CX = Total number of bytes to write
; OUT: None

mem_out:                                        ; Output to user buffer
    pusha                                       ; Save register states to stack

    call data_fileseg                           ; Read from I/O buffer
    mov si, 0x0000                              ; Starting at the beginning

    call extra_memseg                           ; Write to user buffer
    mov di, 0x0000                              ; Starting at the beginning

    mov word [gs:mem_buffer_endpoint], cx       ; This will be the length of the user buffer
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Copy bytes

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; OUTPUT TO NULL: Outputs the contents of the buffer to null
; IN: CX = Total number of bytes to write
; OUT: None

nul_out:                                        ; Output to null
    ret                                         ; Do nothing with data, return to caller


; INPUT FROM TELETYPE: Loads input from teletype mode to the buffer
; IN: [file_buffer_pointer] = Offset to load to
; OUT: [file_buffer_pointer] = Initial value + bytes copied

tty_in:                                         ; Input from teletype
    pusha                                       ; Save register states to stack

    call extra_fileseg                          ; Write to I/O buffer
    mov di, [gs:file_buffer_pointer]            ; At this offset

.input:
    mov cx, di                                  ; The number of bytes in
    neg cx                                      ; Negate to get number of bytes left
    dec cx                                      ; Avoid an O.B.O.E

    call input                                  ; Get teletype input
    pushf                                       ; Preserve flags

    call line_break                             ; Line break

    mov al, 0x0A                                ; Newline character
    stosb                                       ; Output byte

    popf                                        ; Restore flags
    jc .done                                    ; If CTRL+BREAK used, we're done

    jmp .input                                  ; Repeat

.done:
    mov word [gs:file_buffer_pointer], di       ; Update our file buffer pointer

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; INPUT FROM USER BUFFER: Loads input from the user buffer into the buffer
; IN: [file_buffer_pointer] = Offset to load to
; OUT: [file_buffer_pointer] = Initial value + bytes copied

mem_in:                                         ; Input from user buffer
    pusha                                       ; Save register states to stack

    call data_memseg                            ; Read from user buffer
    mov si, 0x0000                              ; Starting from the beginning

    call extra_fileseg                          ; Write to the I/O buffer
    mov di, word [gs:file_buffer_pointer]       ; At this offset

    mov cx, word [gs:mem_buffer_endpoint]       ; The total number of bytes
    rep movsb                                   ; Copy bytes

    mov word [gs:file_buffer_pointer], di       ; Update our file buffer pointer

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; INPUT FROM NULL: Loads input from null into the buffer
; IN: [file_buffer_pointer] = Offset to load to
; OUT: [file_buffer_pointer] = Initial value + bytes copied

nul_in:                                         ; Input from null
    ret                                         ; Do nothing with data, return to caller


; ========================================================================
; DEVICE KERNEL ROUTINES
; ========================================================================

; VERIFY DEVICE FILE: Verifies a device file
; IN: [filename] = 8.3 filename
; OUT: [dev] = Device ID

verify_dev:
    pusha                                       ; Save register states to stack

    call setup_segments                         ; Ensure segments are set correctly

    mov si, filename                            ; Read from the filename
    mov di, tty_name                            ; TTY filename
    mov cx, 0x0004                              ; TTY is 3 chars

    repe cmpsb                                  ; Compare filenames
    je .tty                                     ; If they are equal, get input from teletype

    mov si, filename                            ; Otherwise, read from the filename
    mov di, mem_name                            ; MEM filename
    mov cx, 0x0004                              ; MEM is 3 chars

    repe cmpsb                                  ; Compare filenames
    je .mem                                     ; If they are equal, get input from user buffer

    mov si, filename                            ; Otherwise, read from the filename
    mov di, nul_name                            ; NUL filename
    mov cx, 0x0004                              ; NUL is 3 chars

    repe cmpsb                                  ; Compare filenames
    je .nul                                     ; If they are equal, get input from null

.error_dev:
    mov ax, 0x0800                              ; Otherwise, invalid device
    call error                                  ; Handle this error

    jmp .end                                    ; We're done

.done:
    mov word [gs:root_entry], 0x0000            ; Point entry to the volume label

.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.tty:
    mov byte [gs:dev], 0x01                     ; 1 is for teletype
    jmp .done

.mem:
    mov byte [gs:dev], 0x02                     ; 2 is for user buffer
    jmp .done

.nul:
    mov byte [gs:dev], 0x00                     ; 0 is for null
    jmp .done



; WRITE TO DEVICE FILE: Writes the contents of the buffer to a device file
; IN: AL = Device ID; CX = Number of bytes to write
; OUT: None

write_dev:                                      ; Write to a device file
    pusha                                       ; Save register states to stack

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


; LOAD DEVICE FILE: Loads the contents of a device file
; IN: AL = Device ID; [file_buffer_pointer] = Offset to load to
; OUT: [file_buffer_pointer] = Initial value + bytes copied

load_dev:                                       ; Load contents of a device file
    pusha                                       ; Save register states to stack

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
    call nul_in                                 ; Input from null
    jmp .done                                   ; We're done!

.tty:
    call tty_in                                 ; Input from teletype mode
    jmp .done                                   ; We're done!

.mem:
    call mem_in                                 ; Input from secondary buffer
    jmp .done                                   ; We're done!



; ========================================================================
; DATA SECTION
; ========================================================================

dev_data:

dev                 db 0xFF                     ; Verified device ID (0xFF for not a device file)

tty_name            db "TTY "
mem_name            db "MEM "
nul_name            db "NUL "
