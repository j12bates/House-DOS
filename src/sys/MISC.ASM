; ========================================================================
; House-DOS KERNEL: MISCELLANEOUS ROUTINES
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; MISCELLANEOUS ROUTINES
; ========================================================================

; GENERATE RANDOM NUMBER: Generate a word-sized pseudorandom number
; IN: None
; OUT: DX = Pseudorandom number

random:                                         ; Return a random number of size word in DX
    pusha                                       ; Save register states to stack

    call data_kernseg                           ; We will be using kernel variables

    mov ax, word [random_num]                   ; Load our last random number
    mov dx, 0xB827                              ; Random prime number
    mul dx                                      ; Multiply

    add ax, 0x2FAB                              ; Add a random prime number to the lower word
    mov word [random_num], ax                   ; Store in our memory location
    
    popa                                        ; Restore register states
    mov dx, word [random_num]                   ; Restore our random number

    ret                                         ; Return to caller


; GENERATE RANDOM NUMBER SEED: Creates a new random number seed based on time
; IN: NONE
; OUT: [random_num] = New seed

random_seed:                                    ; Generate a random number seed based on the time
    pusha                                       ; Save register states to stack

    mov ah, 0x02                                ; Get RTC Time
    int 0x1A                                    ; BIOS RTC interrupt

    mov dl, cl                                  ; Move the number of seconds into this register
    mov word [random_num], dx                   ; Move our new seed into our memory location

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; SLEEP MILLISECONDS: Pauses execution for a specified number of milliseconds
; IN: CX = Number of milliseconds
; OUT: None

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


; SLEEP FRAMES: Pauses execution for a certain number of frames at a specific frequency
; IN: BX = Frequency, CX = Number of frames
; OUT: None

sleep_freq:                                     ; Sleep the number of frames in CX at the frequency in BX
    pusha                                       ; Save register states to stack

    cmp bx, 0x0010                              ; Is the frequency at least 16 Hz?
    jnb .calculate                              ; If so, proceed

    shl bx, 0x4                                 ; Otherwise, multiply by sixteen to avoid breaking the division
    shl cx, 0x4                                 ; Multiply this by sixteen as well

.calculate:
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


; GET RTC TIME: Gets the current time from the Real-Time Clock
; IN: None
; OUT: RTC Time (CX = HH:MM; DH = Seconds)

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


; GET RTC DATE: Gets the current date from the Real-Time Clock
; IN: None
; OUT: RTC Date (CX = YYYY; DX = MM:DD)

get_date:                                       ; Get RTC system date
    push ax                                     ; Save register state to stack

    mov ah, 0x04                                ; Get RTC time
    int 0x1A                                    ; BIOS RTC interrupt

    jc .error_rtc                               ; If failed, error

.done:
    pop ax                                      ; Restore register state
    ret                                         ; Return to caller

.error_rtc:
    mov ax, 0x0011                              ; RTC Error
    call error                                  ; Handle this error

    jmp .done                                   ; We're done


; PLAY PC SPEAKER TONE: Plays a tone of specified frequency on the PC speaker
; IN: DX = Frequency
; OUT: None

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


; MUTE PC SPEAKER: Mutes the PC speaker until a new tone is played
; IN: None
; OUT: None

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
