; ========================================================================
; House-DOS FILE COMMAND
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
    mov ah, 0x2A                        ; Verify file from parameter
    mov cx, 0x0000                      ; Parameter 0
    int 0x7E

    jc .done                            ; If error, we're done

    mov ah, 0x0E                        ; Get interface configuration
    int 0x7E

    test al, 0b00000010                 ; Is commentary off?
    jnz .flags_used                     ; If so, no line break

    call line_break                     ; Otherwise, line break

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
    mov ax, 0x8300                      ; Print UNIX timestamp as datestamp
    int 0x7E

    mov ah, 0x14                        ; Advance cursor
    int 0x7E

    mov ax, 0x8301                      ; Print UNIX timestamp as timestamp
    int 0x7E

    call line_break                     ; Line break

    ret                                 ; Return to caller


line_break:                             ; Use the LINE BREAK system call
    mov ah, 0x05                        ; Line break
    int 0x7E

    ret                                 ; Return to caller


property:                               ; Routines to get and print certain properties

.size:
    mov si, message_size                ; Size message
    call print_indent                   ; Print message and indent

    mov ah, 0x70                        ; Get size of file
    int 0x7E

    mov dx, ax                          ; Move file size into DX
    mov ax, 0x8202                      ; Print as decimal
    int 0x7E

    call line_break                     ; Line break

    ret                                 ; Return to caller

.creation:
    mov si, message_cdt                 ; Our creation date/time
    call print_indent                   ; Print message and indent

    mov ah, 0x71                        ; Get creation date/time
    int 0x7E

    call date_time                      ; Print date/time

    ret                                 ; Return to caller

.access:
    mov si, message_access              ; Our access date
    call print_indent                   ; Print message and indent

    mov ah, 0x72                        ; Get access date
    int 0x7E

    mov ax, 0x8300                      ; Print UNIX timestamp as date
    int 0x7E

    call line_break                     ; Line break

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

message_size    db "File size:", 0x00
message_cdt     db "Creation date/time:", 0x00
message_access  db "Access date:", 0x00
message_wdt     db "Last write date/time:", 0x00

message_ronly   db "File is read-only.", 0x00
message_hidden  db "File is hidden.", 0x00
message_system  db "This is a system file.", 0x00

creator         db "House-DOS Developers", 0x00
desc            db "Utility for showing a file's properties.", 0x00
usage           db "FILE <FILENAME>", 0x0A
                db "Flags:", 0x0A
                db "S - Display file size", 0x0A
                db "C - Display creation date", 0x0A
                db "A - Display access date", 0x0A
                db "W - Display write date", 0x0A
                db "P - Display applicable permissions", 0x00
