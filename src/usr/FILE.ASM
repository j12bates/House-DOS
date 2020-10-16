; ========================================================================
; House-DOS CAT COMMAND
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; Main code
; ========================================================================

main:
    mov ah, 0x01                        ; Print String
    mov si, prompt                      ; Our prompt
    int 0x7E

    mov ah, 0x04                        ; Get input
    mov di, fname                       ; The input should be our filename
    mov cx, 0x000C                      ; Up to 12 chars
    int 0x7E

    mov ah, 0x60                        ; Verify file and prepare for loading
    mov si, fname                       ; Filename
    int 0x7E

    jc .done                            ; If error, we're done

    mov ah, 0x05                        ; Line break
    int 0x7E

.size:
    mov ah, 0x70                        ; Get size of file
    int 0x7E

    mov dx, ax                          ; Move file size into DX
    mov ah, 0xF1                        ; Convert to decimal
    mov di, size                        ; Our output buffer
    int 0x7E

    mov ah, 0x02                        ; Print line
    mov si, message_size                ; Our size
    int 0x7E

.creation:
    mov ah, 0x71                        ; Get creation date/time
    int 0x7E

    mov ah, 0xD3                        ; Convert to datestamp
    mov di, cdate                       ; Our destination buffer
    int 0x7E

    mov ah, 0xD2                        ; Convert to timestamp
    mov di, ctime                       ; Our destination buffer
    int 0x7E

    mov ah, 0x02                        ; Print line
    mov si, message_cdt                 ; Our creation date/time
    int 0x7E

.access:
    mov ah, 0x72                        ; Get access date
    int 0x7E

    mov ah, 0xD3                        ; Convert to datestamp
    mov di, access                      ; Our destination buffer
    int 0x7E

    mov ah, 0x02                        ; Print line
    mov si, message_access              ; Our access date
    int 0x7E

.write:
    mov ah, 0x73                        ; Get last write date/time
    int 0x7E

    mov ah, 0xD3                        ; Convert to datestamp
    mov di, wdate                       ; Our destination buffer
    int 0x7E

    mov ah, 0xD2                        ; Convert to timestamp
    mov di, wtime                       ; Our destination buffer
    int 0x7E

    mov ah, 0x02                        ; Print line
    mov si, message_wdt                 ; Our creation date/time
    int 0x7E

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
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

prompt          db "Input filename: ", 0x00
fname           dq 0x0000000000000000
                dd 0x00000000

message_size    db "File size:            "
size            dd 0x00000000
                dw 0x0000

message_cdt     db "Creation date/time:   "
cdate           dq 0x0000000000000000
                dw 0x0000
                db 0x20
ctime           dq 0x0000000000000000
                db 0x00

message_access  db "Access date:          "
access          dq 0x0000000000000000
                dw 0x0000
                db 0x00

message_wdt     db "Last write date/time: "
wdate           dq 0x0000000000000000
                dw 0x0000
                db 0x20
wtime           dq 0x0000000000000000
                db 0x00

message_ronly   db "File is read-only.", 0x00
message_hidden  db "File is hidden.", 0x00
message_system  db "This is a system file.", 0x00