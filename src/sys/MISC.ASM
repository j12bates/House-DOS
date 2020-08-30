; ========================================================================
; House-DOS KERNEL: MISCELLANEOUS ROUTINES
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; MISCELLANEOUS ROUTINES
; ========================================================================

random:                                         ; Return a random number of size word in DX
    pusha                                       ; Save register states to stack

    mov ax, word [random_num]                   ; Load our last random number
    mov dx, 0xB827                              ; Random prime number
    mul dx                                      ; Multiply

    add ax, 0x2FAB                              ; Add a random prime number to the lower word
    mov word [random_num], ax                   ; Store in our memory location
    
    popa                                        ; Restore register states
    mov dx, word [random_num]                   ; Restore our random number

    ret                                         ; Return to caller


random_seed:                                    ; Generate a random number seed based on the time
    pusha                                       ; Save register states to stack

    mov ah, 0x02                                ; Get RTC Time
    int 0x1A                                    ; BIOS RTC interrupt

    mov dl, cl                                  ; Move the number of seconds into this register
    mov word [random_num], dx                   ; Move our new seed into our memory location

    popa                                        ; Restore register states
    ret                                         ; Return to caller
    

sleep:                                          ; Sleep the number of milliseconds in CX
    pusha                                       ; Save register states to stack

    mov ax, 0x03E8                              ; 1,000 microseconds in a millisecond
    mul cx                                      ; Multiply
    mov cx, dx                                  ; Store the upper word in CX
    mov dx, ax                                  ; Store the lower word in DX

    mov ah, 0x86                                ; Sleep
    int 0x15                                    ; BIOS interrupt
    
    popa                                        ; Restore register states
    ret                                         ; Return to caller


sleep_freq:                                     ; Sleep the number of frames in CX at the frequency in BX
    pusha                                       ; Save register states to stack

    cmp bx, 0x0010                              ; Is the frequency at least 16 Hz?
    jb .error                                   ; If not, error

    mov dx, 0x000F                              ; Upper word of 1,000,000
    mov ax, 0x4240                              ; Lower word of 1,000,000

    div bx                                      ; Divide to get duration of one frame
    mul cx                                      ; Multiply to get overall duration to sleep

    mov cx, dx                                  ; Store the upper word in CX
    mov dx, ax                                  ; Store the lower word in DX

    mov ah, 0x86                                ; Sleep
    int 0x15                                    ; BIOS interrupt

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.error:
    stc                                         ; Carry flag for error
    jmp .done                                   ; We're done


get_time:                                       ; Get RTC system time
    push ax                                     ; Save register state to stack

    mov ah, 0x02                                ; Get RTC time
    int 0x1A                                    ; BIOS RTC interrupt

    jc .error_rtc                               ; If failed, error

.done:
    pop ax                                      ; Restore register state
    ret                                         ; Return to caller

.error_rtc:
    push si                                     ; Save register state to stack
    mov si, iface_error_rtc
    call println                                ; Print message

    stc                                         ; Carry flag for error
    pop si                                      ; Restore register state
    jmp .done                                   ; We're done


get_date:                                       ; Get RTC system date
    push ax                                     ; Save register state to stack

    mov ah, 0x04                                ; Get RTC time
    int 0x1A                                    ; BIOS RTC interrupt

    jc .error_rtc                               ; If failed, error

.done:
    pop ax                                      ; Restore register state
    ret                                         ; Return to caller

.error_rtc:
    push si                                     ; Save register state to stack
    mov si, iface_error_rtc
    call println                                ; Print message

    stc                                         ; Carry flag for error
    pop si                                      ; Restore register state
    jmp .done                                   ; We're done


speaker_tone:                                   ; Play a tone of frequency in DX on the PC speaker
    pusha                                       ; Save register states to stack

    mov al, 0xB6                                ; PC Speaker mode
    out 0x43, al                                ; Configure PIT

    mov ax, dx                                  ; Move our frequency into AX so we can output it

    out 0x42, al                                ; Output the lower byte of the frequency
    mov al, ah
    out 0x42, al                                ; Output the higher byte of the frequency

    in al, 0x61                                 ; Get value from this I/O port
    or al, 0b00000011                           ; Set the rightmost two bits
    out 0x61, al                                ; Set this back in place to turn on the PC speaker

    popa                                        ; Restore register states
    ret                                         ; Return to caller


speaker_off:
    push ax                                     ; Save register state to stack

    in al, 0x61                                 ; Get value from this I/O port
    and al, 0b11111100                          ; Clear the rightmost two bits
    out 0x61, al                                ; Set this back in place to turn off the PC speaker
    
    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


misc_data:

random_num          dw 0x0000

iface_error_rtc     db "FATAL: RTC Error. Try again.", 0x00
