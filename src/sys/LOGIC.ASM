; ========================================================================
; House-DOS KERNEL: LOGIC SUBSYSTEM
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; LOGICAL/CONVERSION ROUTINES
; ========================================================================

; CAPITALIZE ASCII CHARACTER: Capitalizes an ASCII character if possible
; IN: AL = Character
; OUT: AL = Capitalized character

capitalize_char:                                ; Capitalize char in AL
    cmp al, 0x61                                ; Are we between lowercase A
    jb .end

    cmp al, 0x7A                                ; And lowercase Z?
    ja .end

    and al, 0b11011111                          ; If so, capitalize

.end:
    ret                                         ; Return to caller


; GENERATE UNIX TIMESTAMP: Creates a UNIX timestamp from time and date
; IN: CF:AX = Seconds elapsed since 00:00:00; DX = Days elapsed since 1970-01-01
; OUT: DX:AX = Timestamp

unix_timestamp:                                 ; Make a UNIX timestamp from seconds in CF:AX and days in DX
    push bx                                     ; Save register state to stack
    push ax                                     ; Preserve seconds
    pushf                                       ; Preserve flags

.days:
    mov ax, dx                                  ; Place the number of days here
    mov bx, 0x02A3                              ; 1/128 of a day
    mul bx                                      ; Multiply
    shl dx, 0x7                                 ; Multiply by 128 to get full days

    push ax                                     ; Preserve this value
    shr ax, 0x9                                 ; Shift to get bits to carry over
    add dx, ax                                  ; Add these bits

    pop ax                                      ; Restore value
    shl ax, 0x7                                 ; Multiply by 128 to get full days

.carry:
    popf                                        ; Restore flags
    pop bx                                      ; Restore seconds
    jnc .seconds                                ; If there was no overflow in calculating seconds, proceed

    inc dx                                      ; Otherwise, increment the leftmost word

.seconds:
    add ax, bx                                  ; Add seconds in
    jnc .done                                   ; If there was no overflow, we're done

    inc dx                                      ; Otherwise, increment the leftmost word

.done:
    pop bx                                      ; Restore register state
    ret                                         ; Return to caller    


; DISASSEMBLE UNIX TIMESTAMP: Converts a UNIX timestamp to time and date
; IN: DX:AX = UNIX Timestamp
; OUT: CF:AX = Seconds elapsed since 00:00:00; DX = Days elapsed since 1970-01-01

dis_unix_timestamp:                             ; Convert UNIX timestamp to seconds in CF:AX and days in DX
    push bx                                     ; Save register state to stack

.days:
    mov bx, 0xA8C0                              ; Half of a day
    div bx                                      ; Divide

    xchg ax, dx                                 ; Seconds will be in the remainder, should be in AX
    shr dx, 0x1                                 ; Divide by 2 to get full days

    jnc .done                                   ; If there was an even number of half-days, we're done

.add_half_day:
    add ax, 0xA8C0                              ; Add an extra 43.2K seconds

.done:
    pop bx                                      ; Restore register state
    ret                                         ; Return to caller


; CONVERT RTC TIME FORMAT TO SECONDS: Calculates a number of seconds from an RTC time
; IN: RTC TIME (CX = HH:MM; DH = Seconds)
; OUT: CF:AX = Number of seconds

conv_rtctime_seconds:                           ; Convert an RTC time to a number of seconds in CF:AX
    pusha                                       ; Save register states to stack

    call setup_segments                         ; Set up segments

.hours:
    mov al, ch                                  ; Hours are stored here
    call conv_rtcval_byte                       ; Convert to a proper value

    push dx                                     ; Preserve seconds

    mov ah, 0x00                                ; Upper byte of factor is zero
    mov bx, 0x0E10                              ; Number of seconds in an hour
    mul bx                                      ; Multiply

.minutes:
    pop bx                                      ; Restore seconds to the BX register

    push ax                                     ; Save value to stack

    mov al, cl                                  ; Minutes are stored here
    call conv_rtcval_byte                       ; Convert to a proper value

    mov bl, 0x3C                                ; Number of seconds in a minute
    mul bl                                      ; Multiply

    push ax                                     ; Save value to stack

.seconds:
    mov al, bh                                  ; Seconds are stored here
    call conv_rtcval_byte                       ; Convert to a proper value

    mov ah, 0x00                                ; Upper byte is zero

    pop bx                                      ; Restore seconds from minutes
    add ax, bx                                  ; Add to total

    pop bx                                      ; Restore seconds from hours
    add ax, bx                                  ; Add to total

    clc                                         ; Clear the carry flag for now
    test dl, 0b00000001                         ; Was that bit set?
    jz .done                                    ; If not, proceed

    stc                                         ; Otherwise, set the carry flag to indicate over 64K seconds

.done:
    mov word [register_bckp_a], ax              ; Save our value

    popa                                        ; Restore register states
    mov ax, word [register_bckp_a]              ; Restore our value

    ret                                         ; Return to caller


; CONVERT RTC DATE FORMAT TO DAYS: Calculates the number of days since 1970-01-01 from an RTC date
; IN: RTC DATE (CX = YYYY; DX = MM:DD)
; OUT: DX = Number of days

conv_rtcdate_days:                              ; Convert an RTC date to a number of days in DX
    pusha                                       ; Push register states to stack

    call setup_segments                         ; Set up segments

.years:
    push dx                                     ; Save month-day

    mov ax, cx                                  ; Year is stored here
    mov di, dec_src                             ; Our destination buffer
    call conv_word_hex                          ; Convert to hex (RTC values are weird)

    mov si, dec_src                             ; Where our value was just placed
    call conv_dec_unsigned_word                 ; Read as decimal number (to reiterate, RTC values are weird)

    mov ax, dx                                  ; Save in AX
    sub ax, 0x07B0                              ; Start years at 1968 for now (it was a leap year)

    push ax                                     ; Save year

    mov bx, 0x0004                              ; Leap year every four years
    div bl                                      ; Divide
    mov bl, al                                  ; Number of leap years

    cmp ah, 0x00                                ; Is it currently a leap year?
    jne .multiply_years                         ; If not, proceed
    
    cmp dh, 0x02                                ; Has February passed?
    jg .multiply_years                          ; If so, proceed

    dec bl                                      ; Otherwise, don't count the leap-day

.multiply_years:
    pop ax                                      ; Restore year

    sub ax, 0x0002                              ; Start years at 1970
    mov dx, 0x016D                              ; 365 days in a year
    mul dx                                      ; Multiply

    add ax, bx                                  ; Add 1 day for every leap year

    pop dx                                      ; Restore month-day
    push ax                                     ; Save value to stack

.months:
    mov al, dh                                  ; Month is stored here
    call conv_rtcval_byte                       ; Convert to a proper value

    mov ah, 0x00                                ; Clear upper byte
    dec ax                                      ; Avoid an O.B.O.E

    mov bl, 0x1F                                ; There are up to 31 days in a month
    mul bl                                      ; Multiply

.irregularities:
    cmp dh, 0x02                                ; Has February passed?
    jle .days                                   ; If not, proceed
    sub ax, 0x0003                              ; Otherwise, we're three days ahead

    cmp dh, 0x04                                ; Has April passed?
    jle .days                                   ; If not, proceed
    dec ax                                      ; Otherwise, we're a day ahead

    cmp dh, 0x06                                ; Has June passed?
    jle .days                                   ; If not, proceed
    dec ax                                      ; Otherwise, we're a day ahead

    cmp dh, 0x09                                ; Has September passed?
    jle .days                                   ; If not, proceed
    dec ax                                      ; Otherwise, we're a day ahead

    cmp dh, 0x0B                                ; Has November passed?
    jle .days                                   ; If not, proceed
    dec ax                                      ; Otherwise, we're a day ahead

.days:
    push ax                                     ; Save value to stack

    mov al, dl                                  ; Day is stored here
    call conv_rtcval_byte                       ; Convert to a proper value

    mov ah, 0x00                                ; Clear upper byte
    dec ax                                      ; Avoid an O.B.O.E
    
    pop bx                                      ; Restore days from months
    add ax, bx                                  ; Add to total

    pop bx                                      ; Restore days from years
    add ax, bx                                  ; Add to total

.done:
    mov word [register_bckp_a], ax              ; Save our value

    popa                                        ; Restore register states
    mov dx, word [register_bckp_a]              ; Restore our value into the correct register

    ret                                         ; Return to caller


; CONVERT SECONDS TO RTC TIME: Creates an RTC time from a number of seconds
; IN: CF:AX = Number of seconds
; OUT: RTC Time (CX = HH:MM; DH = Seconds)

conv_seconds_rtctime:                           ; Convert the number of seconds in CF:AX to an RTC time
    pusha                                       ; Save register states to stack

    call setup_segments                         ; Set up segments

    mov dx, 0x0000                              ; Clear upper word

    jnc .hours                                  ; If carry flag not set, proceed
    mov dx, 0x0001                              ; Otherwise, set rightmost bit of upper word

.hours:
    mov bx, 0x0E10                              ; Number of seconds in an hour
    div bx                                      ; Divide

    push ax                                     ; Push to stack

.minutes:
    mov ax, dx                                  ; Use remainder
    mov bl, 0x3C                                ; Number of seconds in a minute
    div bl                                      ; Divide

    push ax                                     ; Push to stack

.rtc:
    mov al, ah                                  ; Remainder should be number of seconds
    call conv_byte_rtcval                       ; Convert to RTC value
    mov dh, al                                  ; Seconds should be in DH

    pop ax                                      ; Number of minutes
    call conv_byte_rtcval                       ; Convert to RTC value
    mov cl, al                                  ; Minutes should be in CL

    pop ax                                      ; Number of hours
    call conv_byte_rtcval                       ; Convert to RTC value
    mov ch, al                                  ; Hours should be in CH

.done:
    mov word [register_bckp_a], cx
    mov word [register_bckp_b], dx              ; Preserve our RTC time

    popa                                        ; Restore register states

    mov cx, word [register_bckp_a]
    mov dx, word [register_bckp_b]              ; Restore our RTC time

    ret                                         ; Return to caller


; CONVERT DAYS TO RTC DATE: Creates an RTC date from a number of days
; IN: DX = Number of days
; OUT: RTC Date (CX = YYYY; DX = MM:DD), CF = Set on error

conv_days_rtcdate:                              ; Convert number of days in DX to an RTC date
    pusha

    call setup_segments                         ; Set up segments

    mov ax, dx                                  ; Number of days is our dividend
    mov dx, 0x0000                              ; Upper word of dividend is zero

.years:
    mov bx, 0x016D                              ; Number of days in a common year
    div bx                                      ; Divide

    mov bx, ax                                  ; Number of years since 1970
    add bx, 0x0002                              ; Our input was days from 1970, but 1968 was a leap year
    shr bx, 0x2                                 ; Divide by 4 to get the number of leap years passed
    dec bx                                      ; Avoid an O.B.O.E
    sub dx, bx                                  ; We've already accounted for an extra day each leap year

    jg .epoch                                   ; If we didn't subtract too many, proceed
    add dx, 0x016D                              ; Otherwise, add back the days
    dec ax                                      ; And avoid an O.B.O.E with the year

.epoch:
    add ax, 0x07B2                              ; Add 1970 to make it a year number
    push ax                                     ; Push year to stack

    and al, 0b00000011                          ; Mod 4
    cmp al, 0x00                                ; Check if it is divisible by 4
    pushf                                       ; Save result to stack

    dec dx                                      ; Avoid an O.B.O.E with the day

.months:
    mov ax, 0x0001                              ; Start month number here
    mov bx, 0x001F                              ; January is 31 days

    pop cx                                      ; Take this out of the stack for now
    call .check_month                           ; Check January
    push cx                                     ; Push it back

    mov bx, 0x001C                              ; February is 28 days

    popf                                        ; Restore modulus result
    pushf                                       ; Push it back
    jne .feb                                    ; If not a leap year, proceed

    inc bx                                      ; Otherwise, February is 29 days
    
.feb:
    pop cx                                      ; Take this out of the stack for now
    call .check_month                           ; Check February
    push cx                                     ; Push it back

    popf                                        ; Restore modulus result
    mov cx, 0x0002                              ; Repeat next step once

    jne .march_june                             ; If not a leap year, proceed
    inc dx                                      ; Otherwise, there's an extra day

.march_june:
    call .check_month                           ; Check March/May

    dec bx                                      ; April/June is 30 days
    call .check_month                           ; Check April/June

    loop .march_june                            ; Repeat

    call .check_month                           ; Check July
    call .check_month                           ; Check August

    mov cx, 0x0002                              ; Repeat next step once

.september_december:
    dec bx                                      ; September/November is 30 days
    call .check_month                           ; Check September/November

    call .check_month                           ; Check October/December

    loop .september_december                    ; Repeat

    jmp .error_idk                              ; If we've made it here, something's wrong

.check_month:
    cmp dx, bx                                  ; Are we past this month?
    jb .found_month                             ; If so, proceed

    inc ax                                      ; Otherwise, it may be the next month
    sub dx, bx                                  ; We've just accounted for these days
    mov bx, 0x001F                              ; Months typically are 31 days

    ret                                         ; Go back

.found_month:
    pop bx                                      ; Restore for balance
    push ax                                     ; Push month to stack

.rtc:
    mov ax, dx                                  ; Remainder should contain the number of days
    inc al                                      ; Avoid an O.B.O.E
    call conv_byte_rtcval                       ; Convert to RTC value
    mov dl, al                                  ; Day should be in DL

    pop ax                                      ; Restore month
    call conv_byte_rtcval                       ; Convert to RTC value
    mov dh, al                                  ; Month should be in DH

    pop ax                                      ; Restore year
    push dx                                     ; Save month-day

    mov di, dec_src                             ; Destination buffer
    call conv_word_dec_unsigned                 ; Convert to decimal (RTC values are weird)

    mov si, dec_src                             ; Source buffer
    call conv_hex_word                          ; Read as hexadecimal (To reiterate, RTC values are weird)
    mov cx, dx                                  ; Year should be in CX

    pop dx                                      ; Restore month-day
    clc                                         ; No error

.done:
    mov word [register_bckp_a], cx
    mov word [register_bckp_b], dx              ; Preserve our RTC date

    popa                                        ; Restore register states

    mov cx, word [register_bckp_a]
    mov dx, word [register_bckp_b]              ; Restore our RTC date

    ret                                         ; Return to caller

.error_idk:
    mov si, iface_error_idk
    call println                                ; Print message

    pop ax                                      ; Restore for balance
    stc                                         ; Carry flag for error
    jmp .done                                   ; We're done


; CONVERT RTC TIME TO ASCII TIMESTAMP: Creates a HH:MM:SS timestamp from an RTC time
; IN: RTC TIME (CX = HH:MM; DH = Seconds); ES:DI = Destination buffer (8 bytes)
; OUT: None

conv_rtctime_stamp:                             ; Convert an RTC time to a standard HH:MM:SS timestamp at ES:DI
    pusha                                       ; Save register states to stack

.hours:
    mov al, ch                                  ; Hours are stored here
    call conv_byte_hex                          ; Convert to ASCII hex (RTC values are weird)

    add di, 0x0002                              ; We've written two bytes

    mov al, 0x3A                                ; Colon to separate values
    stosb                                       ; Write this byte

.minutes:
    mov al, cl                                  ; Minutes are stored here
    call conv_byte_hex                          ; Convert to ASCII hex (RTC values are weird)

    add di, 0x0002                              ; We've written two bytes

    mov al, 0x3A                                ; Colon to separate values
    stosb                                       ; Write this byte

.seconds:
    mov al, dh                                  ; Seconds are stored here
    call conv_byte_hex                          ; Convert to ASCII hex (RTC values are weird)

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; CONVERT RTC DATE TO ASCII DATESTAMP: Creates a YYYY-MM-DD datestamp from an RTC date
; IN: RTC DATE (CX = YYYY, DX = MM:DD); ES:DI = Destination buffer
; OUT: None

conv_rtcdate_stamp:                             ; Convert an RTC date to a standard YYYY-MM-DD stamp at ES:DI
    pusha                                       ; Save register states to stack

.year:
    mov ax, cx                                  ; Year is stored here
    call conv_word_hex                          ; Convert to ASCII hex (RTC values are weird)

    add di, 0x0004                              ; We've written four bytes

    mov al, 0x2D                                ; Hyphen to separate values
    stosb                                       ; Write this byte

.month:
    mov al, dh                                  ; Month is stored here
    call conv_byte_hex                          ; Convert to ASCII hex (RTC values are weird)

    add di, 0x0002                              ; We've written two bytes

    mov al, 0x2D                                ; Hyphen to separate values
    stosb                                       ; Write this byte

.day:
    mov al, dl                                  ; Day is stored here
    call conv_byte_hex                          ; Convert to ASCII hex (RTC values are weird)

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; CONVERT RTC TIME TO FAT TIME: Converts RTC time format to FAT time format
; IN: RTC TIME (CX = HH:MM; DH = Seconds)
; OUT: AX = time

conv_rtctime_fat:                               ; Convert an RTC time to the FAT time format
    pusha                                       ; Save register states to stack

    mov bx, 0x0000                              ; Clear out BX (we will store our time in here for now)

.hours:
    mov ax, 0x0000                              ; Clear out AX

    mov al, ch                                  ; Hours are here
    call conv_rtcval_byte                       ; Convert to proper value

    shl ax, 0xB                                 ; Hour is bits 15-11
    or bx, ax                                   ; Set our bits in place in BX

.minutes:
    mov ax, 0x0000                              ; Clear out AX

    mov al, cl                                  ; Minutes are here
    call conv_rtcval_byte                       ; Convert to proper value

    shl ax, 0x5                                 ; Minutes are bits 10-5
    or bx, ax                                   ; Set our bits in place in BX

.seconds:
    mov ax, 0x0000                              ; Clear out AX

    mov al, dh                                  ; Seconds are here
    call conv_rtcval_byte                       ; Convert to proper value

    shr ax, 0x1                                 ; Quasi-seconds are bits 4-0
    or bx, ax                                   ; Set our bits in place in BX

.done:
    mov word [register_bckp_a], bx              ; Preserve output

    popa                                        ; Restore register states
    mov ax, word [register_bckp_a]              ; Restore output into the correct register

    ret                                         ; Return to caller


; CONVERT RTC DATE TO FAT DATE: Converts RTC date format to FAT time format
; IN: RTC DATE (CX = YYYY, DX = MM:DD)
; OUT: AX = date

conv_rtcdate_fat:                               ; Convert an RTC date to FAT date format
    pusha                                       ; Save register states to stack

    mov bx, 0x0000                              ; Clear out BX (we will store our date in here for now)

.months:
    mov ax, 0x0000                              ; Clear out AX

    mov al, dh                                  ; Months are stored here
    call conv_rtcval_byte                       ; Convert to a proper value

    shl ax, 0x5                                 ; Months are in bits 8-5
    or bx, ax                                   ; Set our bits in place in BX

.days:
    mov ax, 0x0000                              ; Clear out AX

    mov al, dl                                  ; Days are stored here
    call conv_rtcval_byte                       ; Convert to a proper value

    or bx, ax                                   ; Set our bits in place in BX

.years:
    mov ax, cx                                  ; Year is stored here

    call setup_segments                         ; We are going to be writing to and referencing kernel vars

    mov di, dec_src                             ; Our destination buffer
    call conv_word_hex                          ; Convert to hex (RTC values are weird)

    mov si, dec_src                             ; Where our value was just placed
    call conv_dec_unsigned_word                 ; Read as decimal number (to reiterate, RTC values are weird)

    sub dx, 0x07BC                              ; FAT years start at 1980
    shl dx, 0x9                                 ; Years are in bits 15-9
    or bx, dx                                   ; Set our bits in place in BX

.done:
    mov word [register_bckp_a], bx              ; Preserve output

    popa                                        ; Restore register states
    mov ax, word [register_bckp_a]              ; Restore output into the correct register

    ret                                         ; Return to caller


; CONVERT FAT TIME TO RTC TIME: Converts a FAT time to an RTC time
; IN: AX = FAT date
; OUT: RTC TIME (CX = HH:MM; DH = Seconds)

conv_fat_rtctime:                               ; Convert a FAT time to the RTC format
    pusha                                       ; Save register states to stack

.seconds:
    push ax                                     ; Preserve our time

    and al, 0x1F                                ; The seconds take up 5 bits
    shl al, 0x1                                 ; Multiply by two to get seconds

    call conv_byte_rtcval                       ; Convert to RTC value
    mov dh, al                                  ; Seconds should be in DH

    pop ax                                      ; Restore our time

.minutes:
    shr ax, 0x5                                 ; Shift the minutes into the rightmost bits
    push ax                                     ; Preserve our time

    and al, 0x3F                                ; The minutes take up 6 bits

    call conv_byte_rtcval                       ; Convert to RTC value
    mov cl, al                                  ; Minutes should be in CL

    pop ax                                      ; Restore our time

.hours:
    shr ax, 0x6                                 ; Shift the hours into the rightmost bits

    call conv_byte_rtcval                       ; Convert to RTC value
    mov ch, al                                  ; Hours should be in CH

.done:
    mov word [register_bckp_a], cx
    mov word [register_bckp_b], dx              ; Preserve our output

    popa                                        ; Restore register states
    mov cx, word [register_bckp_a]
    mov dx, word [register_bckp_b]              ; Restore our output

    ret                                         ; Return to caller


; CONVERT FAT DATE TO RTC DATE: Convert a FAT date to an RTC date
; IN: AX = FAT date
; OUT: RTC DATE (CX = YYYY, DX = MM:DD)

conv_fat_rtcdate:                               ; Convert a FAT date to the RTC format
    pusha                                       ; Save register states to stack

.day:
    push ax                                     ; Preserve our date

    and al, 0x1F                                ; The day should take up four bits

    call conv_byte_rtcval                       ; Convert to an RTC value
    mov dl, al                                  ; Day should go in DL

    pop ax                                      ; Restore our date

.month:
    shr ax, 0x5                                 ; Shift the month into the rightmost bits
    push ax                                     ; Preserve our date

    and al, 0x0F                                ; The month should take up four bits

    call conv_byte_rtcval                       ; Convert to an RTC value
    mov dh, al                                  ; Month should go in DH

    pop ax                                      ; Restore our date
    push dx                                     ; Preserve our Day/Month

.year:
    shr ax, 0x4                                 ; Shift the year into the rightmost bits
    add ax, 0x07BC                              ; Years start at 1980

    call setup_segments                         ; We're about to use kernel variables

    mov di, dec_src                             ; Destination buffer
    call conv_word_dec_unsigned                 ; Convert to decimal (RTC values are weird)

    mov si, dec_src                             ; Source buffer
    call conv_hex_word                          ; Read as hexadecimal (To reiterate, RTC values are weird)
    mov cx, dx                                  ; Year should be in CX

    pop dx                                      ; Restore our Day/Month

.done:
    mov word [register_bckp_a], cx
    mov word [register_bckp_b], dx              ; Preserve our output

    popa                                        ; Restore register states
    mov cx, word [register_bckp_a]
    mov dx, word [register_bckp_b]              ; Restore our output

    ret                                         ; Return to caller


; CONVERT HERTZ FREQUENCY TO NUMBER: Converts a frequency in Hertz to a frequency number for the PC speaker
; IN: DX = Frequency to convert
; OUT: DX = Resulting value

conv_hz_freq:                                   ; Convert frequency in Hertz to a frequency number
    pusha                                       ; Save register states to stack

    cmp dx, 0x0012                              ; Are we greater than 18 Hz?
    ja .inverse                                 ; If so, continue

    mov ax, 0xFFFF                              ; Otherwise, just return the lowest possible frequency
    jmp .done                                   ; We're done!

.inverse:
    mov bx, dx                                  ; This is an inverse function, so we will divide by our input

    mov ax, 0x3654
    mov dx, 0x0012                              ; The magical coefficient is 1092.5 squared (desmos.com/calculator/9flwsac8x5)

    div bx                                      ; Divide

.done:
    mov word [register_bckp_a], ax              ; Preserve output

    popa                                        ; Restore register states
    mov dx, word [register_bckp_a]              ; Restore output into correct register

    ret                                         ; Return to caller


; ========================================================================
; SUBROUTINES
; ========================================================================

; CONVERT RTC VALUE: Converts an RTC value to a proper value
; IN: AL = RTC value to convert
; OUT: AL = Resulting value

conv_rtcval_byte:                               ; Convert an RTC value in AL to an actual binary value
    push ds
    push es                                     ; Save segments to stack
    pusha                                       ; Save register states to stack

    call setup_segments                         ; We are going to be writing to and referencing kernel vars
    mov di, dec_src                             ; Output buffer
    call conv_byte_hex                          ; Convert to hex (RTC values are weird)

    mov cx, 0x0002                              ; 2-digit max
    mov si, dec_src                             ; Input buffer
    call conv_dec_unsigned_bin                  ; Read as decimal (to reiterate, RTC values are weird)

.done:
    mov byte [rtc_byte], dl                     ; Preserve value

    popa                                        ; Restore register states
    mov al, byte [rtc_byte]                     ; Restore value into correct register

    pop es
    pop ds                                      ; Restore segments
    ret                                         ; Return to caller


; CREATE RTC VALUE: Convert a proper value to an RTC value
; IN: AL = Value to convert
; OUT: AL = RTC value, CF = Set on error

conv_byte_rtcval:                               ; Convert a binary value in AL to an RTC value
    push ds
    push es                                     ; Save segments to stack
    pusha                                       ; Save register states to stack

    call setup_segments                         ; We are going to be writing to and referencing kernel vars

    cmp al, 0x63                                ; Are we above 99?
    jae .error                                  ; If so, error

    mov di, dec_src                             ; Output buffer

    cmp al, 0x09                                ; Are we above 9?
    ja .convert                                 ; If so, proceed

    mov byte [es:di], 0x30                      ; Otherwise, add in a leading zero
    inc di                                      ; And increment pointer

.convert:
    call conv_byte_dec_unsigned                 ; Convert to decimal (RTC values are weird)

    mov si, dec_src                             ; Input buffer
    call conv_hex_byte                          ; Read as hex (to reiterate, RTC values are weird)
    clc                                         ; No error

.done:
    mov byte [rtc_byte], dl                     ; Preserve value

    popa                                        ; Restore register states
    mov al, byte [rtc_byte]                     ; Restore value into correct register

    pop es
    pop ds                                      ; Restore segments
    ret                                         ; Return to caller

.error:
    mov dl, al                                  ; Preserve the value of AL

    stc                                         ; Carry flag for error
    jmp .done                                   ; We're done


; ========================================================================
; DATA SECTION
; ========================================================================

logic_data:

dec_src             dd 0x00000000
                    db 0x00

rtc_byte            db 0x00

input_number        dw 0x0000
