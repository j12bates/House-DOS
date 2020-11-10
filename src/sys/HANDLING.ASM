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

    cmp ax, 0x0011
    je sys_errors.rtc                           ; RTC error

.data:
    cmp ax, 0x0100
    je data_errors.nan                          ; Not a number

    cmp ax, 0x0101
    je data_errors.space                        ; Memory size

    cmp ax, 0x0110
    je data_errors.oflow                        ; 16-bit overflow

    cmp ax, 0x0111
    je data_errors.oflow8                       ; 8-bit overflow

    cmp ax, 0x0120
    je data_errors.list_index                   ; Invalid list index

.disk:
    cmp ax, 0x0201
    je disk_errors.command                      ; Bad driver command

    cmp ax, 0x0202
    je disk_errors.bad_sector                   ; Bad sector

    cmp ax, 0x0203
    je disk_errors.write                        ; Write-protected

    cmp ax, 0x0204
    je disk_errors.invalid_sector               ; Invalid sector

    cmp ax, 0x0205
    je disk_errors.reset                        ; Reset failure

    cmp ax, 0x0206
    je disk_errors.changed                      ; Diskette changed

    cmp ax, 0x0207
    je disk_errors.param                        ; Bad paramtable

    cmp ax, 0x0208
    je disk_errors.overrun                      ; DMA overrun

    cmp ax, 0x0209
    je disk_errors.bounds                       ; DMA access across bounds

    cmp ax, 0x020A
    je disk_errors.sector_flag                  ; Bad sector flag

    cmp ax, 0x020B
    je disk_errors.cylinder                     ; Bad cylinder

    cmp ax, 0x020C
    je disk_errors.media                        ; Invalid media

    cmp ax, 0x020D
    je disk_errors.number_sectors               ; Invalid number of sectors

    cmp ax, 0x0210
    je disk_errors.ecc_crc                      ; ECC/CRC error

    cmp ax, 0x0211
    je disk_errors.recoverable                  ; Recoverable data error

    cmp ax, 0x0220
    je disk_errors.controller                   ; Controller error

    cmp ax, 0x0240
    je disk_errors.seek                         ; Seek failure

    cmp ax, 0x0280
    je disk_errors.timeout                      ; Timeout


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

.rtc:
    push error_sys_rtc                          ; RTC error
    jmp error_print


data_errors:                                    ; Data error string setup

.nan:
    push error_data_nan                         ; Not a number
    jmp error_print

.space:
    push error_data_space                       ; Memory size
    jmp error_print

.oflow:
    push error_data_oflow                       ; 16-bit overflow
    jmp error_print

.oflow8:
    push error_data_oflow8                      ; 8-bit overflow
    jmp error_print

.list_index:
    push error_data_lindex                      ; Invalid list index
    jmp error_print


disk_errors:                                    ; Disk error string setup

.command:
    push error_disk_command                     ; Bad driver command
    jmp error_print

.bad_sector:
    push error_disk_bsect                       ; Bad sector
    jmp error_print

.write:
    push error_disk_write                       ; Write-protected
    jmp error_print

.invalid_sector:
    push error_disk_isect                       ; Invalid sector
    jmp error_print

.reset:
    push error_disk_reset                       ; Reset failure
    jmp error_print

.changed:
    push error_disk_changed                     ; Diskette changed
    jmp error_print

.param:
    push error_disk_param                       ; Bad paramtable
    jmp error_print

.overrun:
    push error_disk_overr                       ; DMA overrun
    jmp error_print

.bounds:
    push error_disk_64k                         ; DMA access across bounds
    jmp error_print

.sector_flag:
    push error_disk_sflag                       ; Bad sector flag
    jmp error_print

.cylinder:
    push error_disk_cylinder                    ; Bad cylinder
    jmp error_print

.media:
    push error_disk_media                       ; Invalid media
    jmp error_print

.number_sectors:
    push error_disk_nsect                       ; Invalid number of sectors
    jmp error_print

.ecc_crc:
    push error_disk_ecc_crc                     ; ECC/CRC error
    jmp error_print

.recoverable:
    push error_disk_recov                       ; Recoverable data error
    jmp error_print

.controller:
    push error_disk_control                     ; Controller error
    jmp error_print

.seek:
    push error_disk_seek                        ; Seek failure
    jmp error_print

.timeout:
    push error_disk_tout                        ; Timeout
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
error_sys_rtc       db "RTC error.", 0x00

error_data_nan      db "Not a number.", 0x00
error_data_space    db "Memory size too small.", 0x00
error_data_oflow    db "16-bit overflow.", 0x00
error_data_oflow8   db "8-bit overflow.", 0x00
error_data_lindex   db "Invalid list index.", 0x00

error_disk_command  db "Bad driver command.", 0x00
error_disk_bsect    db "Bad sector.", 0x00
error_disk_write    db "Disk is write-protected.", 0x00
error_disk_isect    db "Invalid sector.", 0x00
error_disk_reset    db "Disk reset failed.", 0x00
error_disk_changed  db "Removable media changed/removed.", 0x00
error_disk_param    db "Bad parameter table.", 0x00
error_disk_overr    db "DMA overrun.", 0x00
error_disk_64k      db "DMA access across bounds.", 0x00
error_disk_sflag    db "Bad sector flag.", 0x00
error_disk_cylinder db "Bad cylinder.", 0x00
error_disk_media    db "Invalid media.", 0x00
error_disk_nsect    db "Invalid number of sectors.", 0x00
error_disk_ecc_crc  db "ECC/CRC error.", 0x00
error_disk_recov    db "Recoverable data error.", 0x00
error_disk_control  db "Controller error.", 0x00
error_disk_seek     db "Seek failure.", 0x00
error_disk_tout     db "Disk timeout.", 0x00


data_handling:

hex_buffer          dq 0x00000000