; ========================================================================
; House-DOS FILE COMMAND
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; Main code
; ========================================================================

main:
    mov ah, 0x20                        ; Get parameter
    mov cx, 0x0000                      ; Parameter 0
    mov di, fname                       ; The parameter should be our filename
    int 0x7E

    jc .done                            ; If error, we're done

.verify:
    mov ah, 0x60                        ; Verify file and prepare for loading
    mov si, fname                       ; Filename
    int 0x7E

    jc .done                            ; If error, we're done

    mov ah, 0x05                        ; Line break
    int 0x7E

.flags_used:
    mov ah, 0x26                        ; Check if flags were used
    int 0x7E

    jz .all                             ; If no flags were used, display all properties

.size:
    mov ah, 0x27                        ; Check flags
    mov al, 0x53                        ; 'S' for size
    int 0x7E

    jne .creation                       ; If not set, proceed
    call property.size                  ; Otherwise, get and print file size

.creation:
    mov ah, 0x27                        ; Check flags
    mov al, 0x43                        ; 'C' for creation date
    int 0x7E

    jne .access                         ; If not set, proceed
    call property.creation              ; Otherwise, get and print creation date

.access:
    mov ah, 0x27                        ; Check flags
    mov al, 0x41                        ; 'A' for access date
    int 0x7E

    jne .write                          ; If not set, proceed
    call property.access                ; Otherwise, get and print access date

.write:
    mov ah, 0x27                        ; Check flags
    mov al, 0x57                        ; 'W' for write date
    int 0x7E

    jne .permissions                    ; If not set, proceed
    call property.write                 ; Otherwise, get and print write date

.permissions:
    mov ah, 0x27                        ; Check flags
    mov al, 0x50                        ; 'P' for permissions
    int 0x7E

    jne .done                           ; If not set, we're done
    call permissions                    ; Otherwise, get and print permissions

    jmp .done                           ; We're done!

.all:
    call property.size                  ; Get and print size
    call property.creation              ; Get and print creation date
    call property.access                ; Get and print access date
    call property.write                 ; Get and print write date
    call permissions                    ; Get and print permissions

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


; ========================================================================
; Subroutines
; ========================================================================

print_indent:                           ; Print the message and then indent to the correct col
    mov ah, 0x01                        ; Print string
    int 0x7E

    mov ah, 0x13                        ; Indent cursor
    mov dl, 0x18                        ; Col 24
    int 0x7E

    ret                                 ; Return to caller


date_time:                              ; Print out the UNIX timestamp as date/time
    mov ah, 0xD3                        ; Convert to datestamp
    mov di, date_buffer                 ; Our destination buffer
    int 0x7E

    mov ah, 0xD2                        ; Convert to timestamp
    mov di, time_buffer                 ; Our destination buffer
    int 0x7E

    mov ah, 0x01                        ; Print string
    mov si, date_buffer                 ; Our date
    int 0x7E

    mov ah, 0x02                        ; Print line
    mov si, time_buffer                 ; Our time
    int 0x7E

    ret                                 ; Return to caller


property:                               ; Routines to get and print certain properties

.size:
    mov ah, 0x70                        ; Get size of file
    int 0x7E

    mov dx, ax                          ; Move file size into DX
    mov ah, 0xF1                        ; Convert to decimal
    mov di, dec_buffer                  ; Our output buffer
    int 0x7E

    mov si, message_size                ; Size message
    call print_indent                   ; Print message and indent

    mov ah, 0x02                        ; Print line
    mov si, dec_buffer                  ; Our decimal number
    int 0x7E

    ret                                 ; Return to caller

.creation:
    mov si, message_cdt                 ; Our creation date/time
    call print_indent                   ; Print message and indent

    mov ah, 0x71                        ; Get creation date/time
    int 0x7E

    call date_time                      ; Print date/time

    ret                                 ; Return to caller

.access:
    mov ah, 0x72                        ; Get access date
    int 0x7E

    mov ah, 0xD3                        ; Convert to datestamp
    mov di, date_buffer                 ; Our destination buffer
    int 0x7E

    mov si, message_access              ; Our access date
    call print_indent                   ; Print message and indent

    mov ah, 0x02                        ; Print line
    mov si, date_buffer                 ; Our date
    int 0x7E

    ret                                 ; Return to caller

.write:
    mov si, message_wdt                 ; Our creation date/time
    call print_indent                   ; Print message and indent

    mov ah, 0x73                        ; Get last write date/time
    int 0x7E

    call date_time                      ; Print date/time

    ret                                 ; Return to caller


permissions:                            ; Routine to get the file permissions

.read_only:
    mov ah, 0x74                        ; Check if file is read-only
    int 0x7E

    jnc .hidden                         ; If not, proceed

    mov ah, 0x02                        ; Otherwise, print line
    mov si, message_ronly               ; Our message
    int 0x7E

.hidden:
    mov ah, 0x75                        ; Check if file is hidden
    int 0x7E

    jnc .system                         ; If not, proceed

    mov ah, 0x02                        ; Otherwise, print line
    mov si, message_hidden              ; Our message
    int 0x7E

.system:
    mov ah, 0x76                        ; Check if file is system file
    int 0x7E

    jnc .done                           ; If not, proceed

    mov ah, 0x02                        ; Otherwise, print line
    mov si, message_system              ; Our message
    int 0x7E

.done:
    ret                                 ; Return to caller


; ========================================================================
; Data Section
; ========================================================================

data:

fname           dq 0x0000000000000000
                dd 0x00000000

dec_buffer      dd 0x00000000
                dw 0x0000

date_buffer     dq 0x0000000000000000
                dw 0x0000
                db 0x20, 0x00

time_buffer     dq 0x0000000000000000
                db 0x00

message_size    db "File size:", 0x00
message_cdt     db "Creation date/time:", 0x00
message_access  db "Access date:", 0x00
message_wdt     db "Last write date/time:", 0x00

message_ronly   db "File is read-only.", 0x00
message_hidden  db "File is hidden.", 0x00
message_system  db "This is a system file.", 0x00
