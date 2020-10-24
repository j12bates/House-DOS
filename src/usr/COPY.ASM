; ========================================================================
; House-DOS COPY COMMAND
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
    mov di, fname                       ; The name of our file to copy
    int 0x7E

    jc .done                            ; If error, we're done

.verify:
    mov ah, 0x60                        ; Verify file and prepare for loading
    mov si, fname                       ; Filename
    int 0x7E

    jc .done                            ; If no such file, end here

    mov ah, 0x61                        ; Load file
    int 0x7E

.destination:
    mov ah, 0x20                        ; Get parameter
    mov cx, 0x0001                      ; Parameter 1
    mov di, fname                       ; Our destination filename
    int 0x7E

    jc .done                            ; If error, we're done

.save:
    mov ah, 0x70                        ; Get file size
    int 0x7E

    mov cx, ax                          ; Store in CX

    mov ah, 0x6F                        ; Save file
    mov si, fname                       ; Filename
    int 0x7E

.done:
    mov ah, 0xFF                        ; We're done!
    int 0x7E


data:

buffer_pointer  dw 0x0000
fsize           dw 0x0000
fname           dq 0x0000000000000000
                dd 0x00000000


dest_buffer:
