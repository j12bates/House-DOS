; ========================================================================
; House-DOS KERNEL
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; MAIN ROUTINE
; ========================================================================

start:                                          ; House-DOS code
    push bx                                     ; Save register state to stack
    mov bx, 0x2000
    mov ds, bx                                  ; The segment in which we are

    cmp ah, 0x00                                ; Have we just now been loaded?
    jne main                                    ; If not, don't initialize again

.init:                                          ; Startup code for House-DOS kernel
    mov bx, 0x07C0
    mov es, bx                                  ; The segment in which the bootloader is

    mov word [root_start], ax                   ; Save the start of the root directory

    mov ax, word [es:0x000B]
    mov word [bytes_sector], ax                 ; Save the number of bytes per sector

    mov al, byte [es:0x000D]
    mov byte [sectors_cluster], al              ; Save the number of sectors per cluster

    mov ax, word [es:0x000E]
    mov word [reserved], ax                     ; Save the number of reserved sectors

    mov al, byte [es:0x0010]
    mov byte [fats], al                         ; Save the number of FATs

    mov ax, word [es:0x0011]
    mov word [root_entries], ax                 ; Save the number of root entries

    mov ax, word [es:0x0016]
    mov word [sectors_fat], ax                  ; Save the sectors per FAT

    mov ax, word [es:0x0018]
    mov word [sectors_track], ax                ; Save the sectors per track

    mov ax, word [es:0x001A]
    mov word [heads], ax                        ; Save the number of heads

    mov al, byte [es:0x0024]
    mov byte [drive_num], al                    ; Save our boot drive number

    pop bx                                      ; Take this out of the stack for now
    mov sp, 0x4000                              ; 16K ought to be enough for anyone
    push bx                                     ; Push this back

    mov ax, 0x0000
    mov es, ax                                  ; The IVT is in this segment
    mov di, 0x7E                                ; We will be changing the entry for this interrupt
    shl di, 0x2                                 ; 4 bytes per entry

    mov word [es:di], 0x0000                    ; Handler (kernel) is loaded at offset 0
    mov word [es:di+0x02], 0x2000               ; Segment 0x2000

    call clear                                  ; Clear screen

    mov ax, 0x1003                              ; Configure attribute bit 7
    mov bl, 0x01                                ; Blink
    int 0x10                                    ; BIOS VGA interrupt

    mov si, iface_welcome
    call println                                ; Print welcome message

    mov si, iface_info
    call println                                ; Print info

    xor bx, bx                                  ; Make sure that the zero-flag is set


main:                                           ; Main code for HouseDOS kernel
    mov bx, 0x2000
    mov es, bx                                  ; The segment in which we are loaded

    mov bx, 0x1000
    mov fs, bx                                  ; The segment in which files are loaded

    pop bx                                      ; Restore register state

    je command                                  ; If we were just loaded, get a command

    cmp ah, 0xFF                                ; Did the last command just finish?
    je .handback                                ; If so, prepare to get a command

    jmp syscall_handler                         ; OTHERWISE, a system function was called

.handback:
    add sp, 0x0006                              ; Get rid of all the stuff in the stack from INT 0x7E


command:                                        ; Main loop: Retrieve command from user
    call line_break                             ; Line break
    call prompt                                 ; Setup prompt

    mov ax, 0x2000
    mov es, ax                                  ; The segment we're loaded at
    mov di, input_buffer                        ; Our input buffer
    mov cx, 0x0008                              ; Commands are just filenames, which are up to 8 bytes

    call input                                  ; Get input from user
    call line_break                             ; Line break
    call line_break                             ; Another line break

    mov si, input_buffer                        ; Read from the input buffer
    mov di, filename                            ; Into the filename
    mov cx, 0x0009                              ; Up to 8 chars in a filename
    cld                                         ; Ensure correct direction

.char_filename:
    lodsb                                       ; Load next char

    cmp al, 0x00                                ; Is this a NULL char?
    je .spaces                                  ; If so, that's the end of the filename

    cmp al, 0x20                                ; Is this a SPACE?
    je .params                                  ; If so, that's also the end of the filename

    call capitalize_char                        ; Capitalize this character

    mov byte [di], al                           ; Otherwise, move this char into our filename
    inc di                                      ; Move pointer forward
    loop .char_filename                         ; Repeat

    jmp .bad_command                            ; There should have been a null/space by now

.params:
    push cx                                     ; Save the loop counter
    pop cx                                      ; Restore the loop counter

.spaces:
    mov byte [di], 0x20                         ; Move a space into the next position
    inc di                                      ; Move pointer forward
    loop .spaces                                ; Repeat

.extension:
    mov si, bin_extension                       ; The extension for a Binary file
    mov di, filename_extension                  ; The extension of the filename
    mov cx, 0x0003                              ; Extension is 3 chars
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Move into our file extension

.load_file:
    call get_file_cluster                       ; Get the starting cluster for our file
    jc .bad_command                             ; If error, bad command

    call clear_file_buffer                      ; Clear the file buffer
    call load_file                              ; Load file into our file buffer
    jc command                                  ; If error, stop here

    call move_file_bin                          ; Move the contents into the binary buffer

    call line_break                             ; Line break between messages and command output

    mov ax, 0x4000
    mov ds, ax                                  ; The segment our file is loaded in
    mov es, ax

    jmp 0x4000:0x0000                           ; Jump to our loaded binary

.bad_command:
    mov si, iface_command_bad
    call println                                ; Display an error message

    jmp command                                 ; Try again


; ========================================================================
; MEMORY SUBROUTINES
; ========================================================================

clear_file_buffer:                              ; Clear the file buffer (0x10000-0x1FFFF)
    pusha                                       ; Save register states to stack
    push es                                     ; Save extra segment

    mov si, iface_mem_clear
    call print_str                              ; Print message

    mov ax, 0x1000
    mov es, ax                                  ; File buffer segment
    mov di, 0x0000                              ; Start at offset 0
    mov cx, 0xFFFF                              ; Clear every byte

.zero:
    mov byte [es:di], 0x00                      ; Move a zero in
    inc di                                      ; Advance pointer
    loop .zero                                  ; Repeat

.end:
    mov si, iface_done
    call println                                ; Print message

    pop es                                      ; Restore extra segment
    popa                                        ; Restore register states
    ret                                         ; Return to caller


move_file_bin:                                  ; Load the file buffer as a binary
    pusha                                       ; Save register states to stack
    push ds
    push es                                     ; Save segments

    mov si, iface_mem_bin
    call print_str                              ; Print message

    mov ax, 0x1000
    mov ds, ax                                  ; File buffer segment
    mov si, 0x0000                              ; Start at offset 0

    mov ax, 0x4000
    mov es, ax                                  ; Binary execution segment
    mov di, 0x0000                              ; Start at offset 0

    mov cx, 0xFFFF                              ; Move every byte
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Move all of the bytes into the binary buffer

    pop es
    pop ds                                      ; Restore segments
    mov si, iface_done
    call println                                ; Print message

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ========================================================================
; LOGICAL/CONVERSION SUBROUTINES
; ========================================================================

conv_word_hex:                                  ; Convert AX to ASCII hexadecimal dword at ES:DI
    pusha                                       ; Push register states to stack
    mov cx, 0x0004                              ; Four nibbles

.nibble:
    push ax                                     ; Save our word
    push cx                                     ; Save our counter
    
    dec cx                                      ; Avoid an O.B.O.E
    shl cx, 0x2                                 ; 4 bits in a nibble
    shr ax, cl                                  ; Shift the nibble we care about into the far right

    and al, 0x0F                                ; Get rid of the nibble on the left
    add al, 0x30                                ; ASCII digits start here

    cmp al, 0x39                                ; Is this nibble greater than 9?
    jng .record                                 ; If not, no need to change anything

    add al, 0x07                                ; Otherwise, fast forward to capital letters A-F

.record:
    mov byte [es:di], al                        ; Save the ASCII char in our space in memory
    inc di                                      ; Increment our pointer

    pop cx                                      ; Restore our counter
    pop ax                                      ; Restore our word
    loop .nibble                                ; And repeat

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


conv_word_dec_unsigned:                         ; Convert AX to ASCII decimal at ES:DI
    pusha                                       ; Push register states to stack
    mov cx, 0x0005                              ; There are up to 5 digits in a 16-bit unsigned number

.digit:
    push ax                                     ; Save our number
    push cx                                     ; Save our counter
    mov ax, 0x0001                              ; One
    loop .place_value                           ; Avoid an O.B.O.E and start calculating the place value

    jmp .calc_digit                             ; If we are at the units digit, skip this

.place_value:
    mov dx, 0x000A                              ; Ten
    mul dx                                      ; Multiply
    loop .place_value                           ; Raise 10 to the number of digits left

.calc_digit:
    mov bx, ax                                  ; Save our place value
    pop cx                                      ; Restore our counter
    pop ax                                      ; Restore our number

    mov dx, 0x0000                              ; Upper word of dividend is zero
    div bx                                      ; Divide to find the digit in that place value

    add al, 0x30                                ; ASCII digits start here
    mov byte [es:di], al                        ; Store the ASCII character
    inc di                                      ; Increment our pointer

    mov ax, dx                                  ; We will now do this with the remainder
    loop .digit                                 ; Repeat this process

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


capitalize_char:                                ; Capitalize char in AL
    cmp al, 0x61                                ; Are we between lowercase A
    jl .end
    cmp al, 0x7A                                ; And lowercase Z?
    jg .end

    and al, 0b11011111                          ; If so, capitalize

.end:
    ret                                         ; Return to caller


; ========================================================================
; INPUT SUBROUTINES
; ========================================================================

input:                                          ; Get input from user, store in paragraph ES:DI
    pusha                                       ; Push register states to stack

    mov word [input_buffer_addr], di            ; Save our address

    add cx, di                                  ; Find the end of the buffer
    mov word [input_buffer_limit], cx           ; Save this

    mov bh, 0x00                                ; Page 0
    mov bl, 0b00000111                          ; Light grey

.key:
    mov ah, 0x00                                ; Get keyboard input
    int 0x16                                    ; BIOS keyboard interrupt

    cmp ah, 0x1C                                ; Was the RETURN key pressed?
    je .zero                                    ; If so, we're done getting input

    cmp ah, 0x0E                                ; Was the BACKSPACE key pressed?
    je .backspace                               ; If so, erase last char and move cursor left

    cmp ah, 0x4B                                ; Was the LEFT ARROW pressed
    je .left                                    ; If so, move cursor left

    cmp ah, 0x4D                                ; Was the RIGHT ARROW pressed?
    je .right                                   ; If so, move cursor right

    cmp al, 0x20                                ; Is it between SPACE and DEL?
    jl .key                                     ; If not, we can't print this character

    cmp di, word [input_buffer_limit]           ; Have we exhausted our buffer?
    jge .key                                    ; If so, don't continue

.record:
    mov ah, 0x0E                                ; Teletype output
    int 0x10                                    ; BIOS VGA interrupt (print the char)

    mov byte [es:di], al                        ; Store this char in our buffer
    inc di                                      ; Advance the pointer

    jmp .key                                    ; Get more input

.backspace:
    cmp di, word [input_buffer_addr]            ; Have we reached the leftmost limit?
    je .key                                     ; If so, we can't do a backspace

    mov ah, 0x0E                                ; Teletype output
    mov al, 0x08                                ; Backwards
    int 0x10                                    ; BIOS VGA interrupt

    mov ah, 0x09                                ; Write char
    mov al, 0x20                                ; Space
    mov cx, 0x01                                ; Write once
    int 0x10                                    ; BIOS VGA interrupt

    dec di                                      ; Decrement the pointer
    mov byte [es:di], 0x00                      ; Erase that char

    jmp .key                                    ; Get more input

.left:
    cmp di, word [input_buffer_addr]            ; Have we reached the leftmost limit?
    je .key                                     ; If so, we can't move left

    mov ah, 0x0E                                ; Teletype output
    mov al, 0x08                                ; Backwards
    int 0x10                                    ; BIOS VGA interrupt

    dec di                                      ; Decrement the pointer

    jmp .key                                    ; Get more input

.right:
    cmp di, word [input_buffer_limit]           ; Have we reached the rightmost limit?
    je .key                                     ; If so, we can't move right

    cmp byte [es:di], 0x00                      ; Is this char a null char?
    je .key                                     ; If so, there's nowhere to move

    mov ah, 0x03                                ; Otherwise, get cursor position
    int 0x10                                    ; BIOS VGA interrupt

    inc dl                                      ; Advance by one col
    mov ah, 0x02                                ; Set cursor position
    int 0x10                                    ; BIOS VGA interrupt

    inc di                                      ; Advance the pointer

    jmp .key                                    ; Get more input

.zero:
    cmp di, word [input_buffer_limit]           ; Have we exhausted our buffer?
    je .done                                    ; If so, we're done

    mov byte [es:di], 0x00                      ; Otherwise, fill in a zero here
    inc di                                      ; Advance the pointer
    jmp .zero                                   ; And repeat

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


confirm:                                        ; Ask the user to confirm
    pusha                                       ; Push register states to stack

    clc                                         ; No error yet
    mov si, iface_confirm
    call print_str                              ; Print message

    mov ah, 0x00                                ; Read from keyboard
    int 0x16                                    ; BIOS keyboard interrupt

    mov ah, 0x0E                                ; Teletype output
    mov bh, 0x00
    mov bl, 0b00000111
    int 0x10                                    ; Display the char we typed

    and al, 0b11011111                          ; Capitalize
    cmp al, 0x59                                ; Was Y pressed?
    je .end                                     ; If so, return to caller without error

    stc                                         ; Otherwise, error

.end:
    pushf                                       ; Push flags to stack
    call line_break                             ; Line break
    popf                                        ; Restore flags

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ========================================================================
; DISPLAY SUBROUTINES
; ========================================================================

clear:                                          ; Clear screen
    pusha                                       ; Push register states to stack

    mov ah, 0x00                                ; Set video mode
    mov al, 0x03                                ; 80x25
    int 0x10                                    ; BIOS VGA interrupt

    popa                                        ; Restore register states
    ret                                         ; Return to caller


print_str:                                      ; Prints String in DS:SI
    pusha                                       ; Push register states to stack

    mov ah, 0x0E                                ; Teletype output
    mov bh, 0x00                                ; Page 0
    mov bl, 0b00000111                          ; Light grey
    cld                                         ; Ensure correct direction

.char:
    lodsb                                       ; Load in next character
    cmp al, 0x00                                ; Is this a null character?
    je .ret                                     ; If so, we're done

    int 0x10                                    ; Otherwise, BIOS VGA interrupt
    jmp .char                                   ; And repeat

.ret:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


println:                                        ; Prints String in DS:SI, then does a line break
    pusha                                       ; Save register states to stack

    call print_str                              ; Print
    call line_break                             ; Line break

    popa                                        ; Restore register states
    ret                                         ; Return to caller


line_break:                                     ; Moves cursor down one line
    pusha                                       ; Push register states to stack

    mov ah, 0x03                                ; Get cursor position
    mov bh, 0x00                                ; Page 0
    int 0x10                                    ; BIOS VGA interrupt

    cmp dh, 0x18                                ; Are we already at the bottom?
    jl .break                                   ; If so, just move the cursor

    mov ah, 0x06                                ; Scroll up
    mov al, 0x01                                ; 1 line
    mov bh, 0b00000111                          ; Light grey
    mov cx, 0x0000                              ; Upper left
    mov dx, 0x1950                              ; Bottom right
    int 0x10                                    ; BIOS VGA interrupt

    mov dh, 0x17                                ; Second-to-last row

.break:
    mov ah, 0x02                                ; Set cursor position
    mov bh, 0x00                                ; Page 0
    inc dh                                      ; One row down
    mov dl, 0x00                                ; Leftmost column
    int 0x10                                    ; BIOS VGA interrupt

    popa                                        ; Restore register states
    ret                                         ; Return to caller


prompt:                                         ; Set up a prompt for the user
    pusha                                       ; Push register states to stack

    mov ah, 0x0E                                ; Teletype output
    mov bh, 0x00                                ; Page 0
    mov bl, 0b00000111                          ; Light grey

    mov al, 0x20                                ; Space
    int 0x10                                    ; BIOS VGA interrupt

    mov al, 0x2D                                ; Hyphen
    int 0x10                                    ; BIOS VGA interrupt

    mov al, 0x20                                ; Space
    int 0x10                                    ; BIOS VGA interrupt

    popa                                        ; Restore register states
    ret                                         ; Return to caller


print_bytes:                                    ; Prints number of bytes (CX) starting at DS:SI
    pusha                                       ; Push register states to stack

    mov ah, 0x0E                                ; Teletype output
    mov bh, 0x00                                ; Page 0
    mov bl, 0b00000111                          ; Light grey
    cld                                         ; Ensure correct direction

.char:
    lodsb                                       ; Load char and increment pointer
    int 0x10                                    ; BIOS VGA interrupt
    loop .char                                  ; Repeat

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ========================================================================
; DISK SUBROUTINES
; ========================================================================

get_file_info:                                  ; Get an item (AL=offset) from a file's root directory entry
    push cx                                     ; Push register state to stack
    push si                                     ; Push register state to stack
    push di                                     ; Push register state to stack
    push ax                                     ; Save our offset

.search_init:
    mov si, iface_disk_search
    call print_str                              ; Print message

    mov ax, 0x2000
    mov ds, ax                                  ; Segment we are loaded at

    mov ax, 0x3800
    mov es, ax                                  ; Segment the root directory is at
    mov di, 0x0000                              ; Start at offset 0

    mov cx, word [root_entries]                 ; Number of entries to look through

.check_entry:
    push cx                                     ; Save the number of remaining entries

    mov cx, 0x000B                              ; Compare the first 11 bytes
    mov si, filename                            ; Compare against the filename requested
    push di                                     ; Save our location
    cld                                         ; Ensure correct direction

    repe cmpsb                                  ; Compare!

    pop di                                      ; Restore our location
    pop cx                                      ; Restore the remaining entries

    je .found                                   ; If equal, we found the entry

    add di, 0x0020                              ; Otherwise, move pointer to next entry
    loop .check_entry                           ; And repeat

    jmp .error_nf                               ; If gone through everything, error

.found:
    push di                                     ; Save index to stack

    shr di, 0x5                                 ; Divide by 32 to get the root entry number
    mov word [root_entry], di                   ; Save this number

    pop di                                      ; Restore index

    mov si, iface_disk_found
    call println                                ; Print message

    pop ax                                      ; Restore our offset
    mov ah, 0x00                                ; Clear upper byte
    clc                                         ; No error

    cmp al, 0x0E                                ; Items below this offset are byte-sized
    jb .byte

    cmp al, 0x1C                                ; Items between here and there are word-sized
    jb .word

    mov ax, word [es:di+0x1C]
    mov dx, word [es:di+0x1E]                   ; Otherwise, return the file size in DX:AX
    jmp .done                                   ; We're finished

.byte:
    add di, ax                                  ; Add our offset
    mov al, byte [es:di]                        ; Return the byte in AL
    jmp .done                                   ; We're finished

.word:
    add di, ax                                  ; Add our offset
    mov ax, word [es:di]                        ; Return the word in AX

.done:
    pop di                                      ; Restore register state
    pop si                                      ; Restore register state
    pop cx                                      ; Restore register state
    ret                                         ; Return to caller

.error_nf:
    mov si, iface_disk_nf
    call println                                ; Print message

    pop ax                                      ; Restore for balance
    stc                                         ; Carry flag for error
    jmp .done                                   ; We're done


load_file:                                      ; Load file starting at cluster into buffer
    pusha                                       ; Push register states to stack

    mov ax, 0x2000
    mov ds, ax                                  ; Segment in which we are loaded

    mov word [buffer_pointer], 0x0000           ; Start loading at offset 0

.load_cluster:
    mov si, iface_disk_cluster
    call print_str                              ; Print message

    mov ax, word [cluster]                      ; Our cluster number
    sub ax, 0x0002                              ; Clusters begin at 2
    mul byte [sectors_cluster]                  ; Multiply to get sector number
    add ax, word [root_start]                   ; Add start of root directory
    add ax, 0x0020                              ; Root directory is 32 sectors
    call calc_chs_ls                            ; Convert to CHS

    mov ax, 0x1000
    mov es, ax                                  ; Load file into this segment
    mov bx, word [buffer_pointer]               ; At this offset

    mov ah, 0x02                                ; Read disk sectors
    mov al, byte [sectors_cluster]              ; 1 cluster

    int 0x13                                    ; BIOS disk interrupt
    jnc .next_cluster                           ; If no error, set up for next cluster

    call reset_disk                             ; Otherwise, reset the disk

    mov ah, 0x02                                ; Read disk sectors
    mov al, byte [sectors_cluster]              ; 1 cluster
    int 0x13                                    ; BIOS disk interrupt
    jc .error_read                              ; Error

.next_cluster:
    mov si, word [cluster]                      ; Our cluster number
    shl si, 0x1                                 ; There are two bytes per entry in FAT16

    push ds                                     ; Save our segment

    mov ax, 0x3000
    mov ds, ax                                  ; Segment where the FAT is loaded

    mov ax, word [si]                           ; DS:SI is pointing to the FAT entry

    pop ds                                      ; Restore segment
    mov word [cluster], ax                      ; That entry contained our next cluster

    cmp ax, 0xFFF8                              ; Is this the end of the file?
    jae .done                                   ; If so, we're finished

    mov ax, word [bytes_sector]
    mul word [sectors_cluster]
    add word [buffer_pointer], ax               ; Advance pointer by one cluster

    cmp word [buffer_pointer], 0x0000           ; Have we used up our 64K?
    je .error_size                              ; If so, error

    jmp .load_cluster                           ; Load next cluster

.done:
    mov si, iface_done
    call println                                ; Print message

    clc                                         ; No error

.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.error_read:
    mov si, iface_disk_eread
    call println                                ; Print message

    stc                                         ; Carry flag for error
    jmp .end                                    ; We're done

.error_size:
    mov si, iface_disk_esize
    call println                                ; Print message

    stc                                         ; Carry flag for error
    jmp .end                                    ; We're done


write_file:                                     ; Write file buffer to disk as file
    pusha                                       ; Push register states to stack
    push cx                                     ; Save our file size

    mov ax, 0x2000
    mov ds, ax                                  ; The segment we are loaded at

    mov word [buffer_pointer], 0x0000           ; Start reading from offset 0

.check_existence:
    call get_file_cluster                       ; Check if file exists, get starting cluster if it does
    jnc .file_exists                            ; If it exists, we need to ask for confirmation

.create_new:
    call next_available_cluster                 ; Get the next available cluster
    jc .error_full                              ; If error, disk is full

    mov si, iface_disk_search
    call print_str                              ; Print message

    mov ax, 0x3800
    mov es, ax                                  ; The segment in which the root directory is loaded

    mov di, 0x0000                              ; Start looking at offset 0
    mov cx, word [root_entries]                 ; Look through all the possible root entries

.check_root_entry:
    cmp byte [es:di], 0x00                      ; Is this entry empty?
    je .new_file_entry                          ; If so, set this entry up for our new file.

    add di, 0x0020                              ; Otherwise, move to the next 32-byte entry
    loop .check_root_entry                      ; And repeat

    jmp .error_root                             ; If no entries are available, sorry!

.new_file_entry:
    mov si, iface_disk_empty
    call println                                ; Print message

    mov cx, 0x000B                              ; Copy 11 bytes
    mov si, filename                            ; Our filename
    push di                                     ; Save our location

    rep movsb                                   ; Move the filename into the root entry

    pop di                                      ; Restore our location
    mov ax, word [cluster]
    mov word [es:di+0x1A], ax                   ; Move our starting cluster into the correct field

    pop cx                                      ; Restore our file size
    mov word [es:di+0x1C], cx                   ; Move our file size into the correct field

    jmp .write_cluster                          ; Start writing data

.file_exists:
    mov si, iface_disk_exists
    call println                                ; Display message

    call confirm                                ; Ask for confirmation
    jc .abort                                   ; If not given, we're done

.change_file_size:
    mov ax, 0x3800
    mov es, ax                                  ; The segment the root directory is loaded in

    mov di, word [root_entry]                   ; The number of the root entry
    shl di, 0x5                                 ; There are 32 bytes in each entry

    pop cx                                      ; Restore our file size
    mov word [es:di+0x1C], cx                   ; Move our file size into the correct field
    mov word [es:di+0x1E], 0x0000               ; Upper word of file size is 0

.write_cluster:
    mov si, iface_disk_write
    call print_str                              ; Display message

    mov ax, word [cluster]                      ; Our cluster number
    sub ax, 0x0002                              ; Clusters begin at 2
    mul byte [sectors_cluster]                  ; Multiply to get sector number
    add ax, word [root_start]                   ; Add start of root directory
    add ax, 0x0020                              ; Root directory is 32 sectors
    call calc_chs_ls                            ; Convert to CHS

    mov ax, 0x1000
    mov es, ax                                  ; File buffer is in this segment
    mov bx, word [buffer_pointer]               ; Read at this offset

    mov ah, 0x03                                ; Write disk sectors
    mov al, byte [sectors_cluster]              ; 1 cluster

    int 0x13                                    ; BIOS disk interrupt
    jnc .next_cluster                           ; If no error, set up for the next cluster

    call reset_disk                             ; Otherwise, reset the disk

    mov ah, 0x03                                ; Write disk sectors
    mov al, byte [sectors_cluster]              ; 1 cluster
    int 0x13                                    ; BIOS disk interrupt
    jc .error_write                             ; If failed again, error

.next_cluster:
    mov ax, word [bytes_sector]
    mul word [sectors_cluster]
    add word [buffer_pointer], ax               ; Advance pointer by one cluster

    mov ax, 0x3000
    mov es, ax                                  ; The segment in which the FAT is loaded

    mov di, word [cluster]                      ; The cluster we just wrote to
    shl di, 0x1                                 ; There are 2 bytes per entry in FAT16
    mov bx, word [es:di]                        ; The FAT entry for this cluster

    cmp word [buffer_pointer], cx               ; Have we finished writing the entire file?
    jae .end_file                               ; If so, we need to do a few things

    cmp bx, 0x0000                              ; Was this cluster previously free?
    je .change_fat_entry                        ; If so, we need to set it to the next available cluster

    cmp bx, 0xFFF8                              ; Was this cluster previously EOF?
    jae .change_fat_entry                       ; If so, we need to set it to the next available cluster

    mov word [cluster], bx                      ; Otherwise, it is our next cluster to write to

    jmp .write_cluster                          ; Load next cluster

.change_fat_entry:
    call next_available_cluster                 ; Get the next cluster available
    jc .error_full                              ; If error, disk is full

    mov bx, word [cluster]
    mov word [es:di], bx                        ; Move this cluster number into our FAT entry

    jmp .write_cluster                          ; We are ready to write the next cluster

.end_file:
    mov si, iface_done
    call println                                ; Print message

    mov word [es:di], 0xFFFF                    ; Place an end-of-file marker into this entry
    mov di, bx                                  ; Move the previous value into DI

.free_entry:
    cmp di, 0x0000                              ; Was this cluster previously free?
    je .write_fats                              ; If so, we're done changing the FAT

    shl di, 0x1                                 ; Otherwise, it is a new cluster number
    mov bx, word [es:di]                        ; The FAT entry for that new cluster

    mov word [es:di], 0x0000                    ; Mark that new cluster as free
    mov di, bx                                  ; Work with the previous value next

    jmp .free_entry                             ; Repeat

.write_fats:
    mov si, iface_disk_wfats
    call print_str                              ; Print message

    mov cx, word [fats]                         ; Number of FATs to write to

.write_fat:
    push cx                                     ; Save our counter

    mov bx, 0x0000                              ; Write from this segment

    mov ax, word [sectors_fat]                  ; Sectors per FAT
    mul cx                                      ; Number of sectors between this FAT and root directory
    mov cx, ax                                  ; Store this number in here for now

    mov ax, word [root_start]                   ; Start of the root directory
    sub ax, cx                                  ; Subtract this number
    call calc_chs_ls                            ; Convert to CHS Address

    mov ax, word [sectors_fat]                  ; An entire FAT
    mov ah, 0x03                                ; Write disk sectors

    int 0x13                                    ; BIOS disk interrupt
    jnc .next_fat                               ; If no error, prepare to do the next one

    call reset_disk                             ; Otherwise, reset the disk

    mov ax, word [sectors_fat]                  ; An entire FAT
    mov ah, 0x03                                ; Write disk sectors
    int 0x13                                    ; BIOS disk interrupt
    jc .error_write                             ; If failed again, error

.next_fat:
    pop cx                                      ; Restore our counter
    loop .write_fat                             ; Repeat

.write_root:
    mov si, iface_done
    call println                                ; Print message

    mov si, iface_disk_wroot
    call print_str                              ; Print message

    mov ax, 0x3800
    mov es, ax                                  ; The segment in which the root directory is loaded

    mov ax, word [root_start]                   ; Start of the root directory
    call calc_chs_ls                            ; Convert to CHS Address

    mov ah, 0x03                                ; Write disk sectors
    mov al, 0x20                                ; Root directory is 32 sectors

    int 0x13                                    ; BIOS disk interrupt
    jnc .done                                   ; If no error, we are done

    call reset_disk                             ; Otherwise, reset the disk

    mov ah, 0x03                                ; Write disk sectors
    mov al, 0x20                                ; Root directory is 32 sectors
    int 0x13                                    ; BIOS disk interrupt
    jc .error_write                             ; If failed again, error

.done:
    mov si, iface_done
    call println                                ; Print message

    mov si, iface_disk_applied
    call println                                ; Print message

    clc                                         ; No error

.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.error_full:
    mov si, iface_disk_efull
    call println                                ; Print message

    stc                                         ; Carry flag for error
    jmp .end                                    ; We're done

.error_root:
    mov si, iface_disk_eroot
    call println                                ; Print message

    stc                                         ; Carry flag for error
    jmp .end                                    ; We're done


.error_write:
    mov si, iface_disk_ewrite
    call println                                ; Print message

    stc                                         ; Carry flag for error
    jmp .end                                    ; We're done

.abort:
    mov si, iface_aborting
    call println                                ; Print message

    stc                                         ; Carry flag for error
    jmp .end                                    ; We're done


get_file_cluster:                               ; Get the starting cluster for a file
    pusha                                       ; Save register states to stack

    mov al, 0x1A                                ; Read the starting cluster
    call get_file_info                          ; Get from the root directory
    jc .done                                    ; If error, stop

    mov word [cluster], ax                      ; Store as cluster number

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


next_available_cluster:                         ; Get the next cluster available
    pusha                                       ; Push register states to stack

    mov ax, 0x3000
    mov es, ax                                  ; The segment in which the FAT is loaded

    mov di, 0x0000                              ; Start looking at offset 0
    mov cx, 0x4000                              ; Look through all the FAT entries

.check_fat_entry:
    cmp word [es:di], 0x0000                    ; Is this FAT entry unused?
    je .cluster                                 ; If so, find an available root entry

    add di, 0x0002                              ; Otherwise, move to the next two-byte entry
    loop .check_fat_entry                       ; And repeat

    stc                                         ; If no clusters are free, error
    jmp .done                                   ; We're done

.cluster:
    shr di, 0x1                                 ; There are two bytes per entry in FAT16
    mov word [cluster], di                      ; The number of this entry is our starting cluster

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


calc_chs_ls:                                    ; Setup Cylinder-Head-Sector from LBA (AX)
    mov dx, 0x0000
    div word [sectors_track]
    mov cl, dl
    inc cl                                      ; Sector number

    mov dx, 0x0000
    div word [heads]
    mov dh, dl                                  ; The remainder is the head number
    mov ch, al                                  ; The quotient is the cylinder number

    mov dl, byte [drive_num]                    ; Drive number
    ret                                         ; Return to caller


reset_disk:                                     ; Reset the disk
    push ax                                     ; Push register states to stack

    mov si, iface_disk_reset
    call print_str                              ; Print message

    mov ah, 0x00                                ; Reset disk
    mov dl, byte [drive_num]

    int 0x13                                    ; BIOS disk interrupt
    jc reboot_fatal                             ; If there was an error, reboot
    
    pop ax                                      ; Otherwise, restore register states
    ret                                         ; Return to caller


conv_x3_83:                                     ; Convert X.3 filename in DS:SI to an 8.3 for searching
    pusha                                       ; Push register states to stack

    mov ax, 0x2000
    mov es, ax                                  ; Segment we're loaded in
    mov di, filename                            ; Place into our memory space for filenames

    mov cx, 0x0008                              ; 8 chars in the file NAME

.name_char:
    movsb                                       ; Move one byte and advance pointers

    cmp byte [si], 0x2E                         ; Is this next character the dot?
    je .dot                                     ; If so, move on

    loop .name_char                             ; Otherwise, repeat

.dot:
    dec cx                                      ; Avoid an O.B.O.E
    inc si                                      ; Get ready to read the extension

.space:
    mov byte [es:di], 0x20                      ; Pad with a space
    inc di                                      ; Advance pointer
    loop .space                                 ; Repeat

.ext_chars:
    mov cx, 0x0003                              ; 3 chars in the file EXTENSION
    rep movsb                                   ; Move one byte and advance pointers
    
.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller 
    

; ========================================================================
; ERROR SUBROUTINES
; ========================================================================

reboot_fatal:
    mov si, iface_fatal_reboot
    call print_str                              ; Print message

    mov ah, 0x00                                ; Read from keyboard buffer
    int 0x16                                    ; BIOS keyboard interrupt

    int 0x19                                    ; Reboot


; ========================================================================
; SYSTEM CALL HANDLER
; ========================================================================

syscall_handler:                                ; System call handler

.iface_funcs:                                   ; Interfacing functions
    cmp ah, 0x01
    je iface_routines.print                     ; Print String

    cmp ah, 0x02
    je iface_routines.println                   ; Print Line

    cmp ah, 0x03
    je iface_routines.confirm                   ; Ask for confirmation

    cmp ah, 0x04
    je iface_routines.input                     ; Get user input

    cmp ah, 0x05
    je iface_routines.line                      ; Line break

    cmp ah, 0x10
    je iface_routines.print_bytes               ; Print bytes

.disk_funcs:                                    ; Disk functions
    cmp ah, 0x60
    je disk_routines.verify                     ; Verify file

    cmp ah, 0x61
    je disk_routines.load                       ; Load file

    cmp ah, 0x62
    je disk_routines.get_bytes_qty              ; Get quantity of bytes from file

    cmp ah, 0x63
    je disk_routines.get_bytes_indexes          ; Get bytes between two indexes

    cmp ah, 0x68
    je disk_routines.write_bytes_qty            ; Write quantity of bytes to file

    cmp ah, 0x69
    je disk_routines.write_bytes_indexes        ; Write bytes between two indexes to file

    cmp ah, 0x6E
    je disk_routines.clear_buffer               ; Clear entire file buffer

    cmp ah, 0x6F
    je disk_routines.write                      ; Write file to disk

    cmp ah, 0x70
    je disk_routines.get_file_size              ; Verify and get size of file

.general_funcs:                                 ; General functions
    cmp ah, 0xF0
    je general_routines.conv_hex                ; Convert to hexadecimal notation

    cmp ah, 0xF1
    je general_routines.conv_dec_usigned        ; Convert to decimal notation (unsigned)

    jmp int_ret                                 ; If invalid function number, we're done!


; ========================================================================
; SYSTEM CALL ROUTINES
; ========================================================================

iface_routines:                                 ; Interface functions

.print:
    call data_binseg                            ; We want to access data from the command

    call print_str                              ; Print String

    jmp int_ret                                 ; We're done!

.println:
    call data_binseg                            ; We want to access data from the command

    call print_str                              ; Print String
    call line_break                             ; Line Break

    jmp int_ret                                 ; We're done!

.confirm:
    call confirm                                ; Ask for confirmation

    pushf                                       ; Save flags
    call line_break                             ; Line break
    popf                                        ; Restore flags

    jmp int_ret.preserve_flags                  ; We're done!

.input:
    call extra_binseg                           ; We want to give data to the command

    call input                                  ; Get input
    call line_break                             ; Line Break

    jmp int_ret                                 ; We're done!

.line:
    call line_break                             ; Line break

    jmp int_ret                                 ; We're done!

.print_bytes:
    call data_binseg                            ; We want to access data from the command

    call print_bytes                            ; Print bytes

    jmp int_ret                                 ; We're done!


disk_routines:                                  ; Disk functions

.verify:
    call data_binseg                            ; We want to access data from the command

    call conv_x3_83                             ; Convert filename to proper format
    call get_file_cluster                       ; Search the directory and find the starting cluster

    jmp int_ret.preserve_flags                  ; We're done!

.load:
    call clear_file_buffer                      ; Clear the file buffer
    call load_file                              ; Load the file into the file buffer

    jmp int_ret.preserve_flags                  ; We're done!

.get_bytes_qty:
    call data_fileseg                           ; We want to access data from the file buffer
    call extra_binseg                           ; We want to give data to the command

    push cx                                     ; Save our counter
    rep movsb                                   ; Copy the correct number of bytes
    pop cx                                      ; Restore our counter

    jmp int_ret                                 ; We're done!

.get_bytes_indexes:
    call data_fileseg                           ; We want to access data from the file buffer
    call extra_binseg                           ; We want to give data to the command

    push cx                                     ; Save our counter

    sub cx, si                                  ; Convert index to number of bytes
    rep movsb                                   ; Copy the correct number of bytes

    pop cx                                      ; Restore our counter

    jmp int_ret                                 ; We're done!

.write_bytes_qty:
    call data_binseg                            ; We want to access data from the command
    call extra_fileseg                          ; We want to give data to the file buffer

    push cx                                     ; Save our counter
    rep movsb                                   ; Copy the correct number of bytes
    pop cx                                      ; Restore our counter

    jmp int_ret                                 ; We're done!

.write_bytes_indexes:
    call data_binseg                            ; We want to access data from the command
    call extra_fileseg                          ; We want to give data to the file buffer

    push cx                                     ; Save our counter
    
    sub cx, si                                  ; Convert index to number of bytes
    rep movsb                                   ; Copy the correct number of bytes

    pop cx                                      ; Restore our counter

    jmp int_ret                                 ; We're done!

.clear_buffer:
    call clear_file_buffer                      ; Clear the file buffer

    jmp int_ret                                 ; We're done!

.write:
    call data_binseg                            ; We want to access data from the command

    call conv_x3_83                             ; Convert filename to proper format
    call write_file                             ; Write file to disk

    jmp int_ret.preserve_flags                  ; We're done!

.get_file_size:
    call data_binseg                            ; We want to access data from the command

    call conv_x3_83                             ; Convert filename to proper format

    mov al, 0x1C                                ; File size
    call get_file_info                          ; Get item from root directory

    jmp int_ret.preserve_flags                  ; We're done!


general_routines:                               ; General functions

.conv_hex:
    call extra_binseg                           ; We want to give data to the command

    xchg ax, dx                                 ; Function takes arg in AX, we have it in DX
    call conv_word_hex                          ; Do the conversion
    xchg dx, ax                                 ; Put everything back the way it was

    jmp int_ret                                 ; We're done!

.conv_dec_usigned:
    call extra_binseg                           ; We want to give data to the command

    xchg ax, dx                                 ; Function takes arg in AX, we have it in DX
    call conv_word_dec_unsigned                 ; Do the conversion
    xchg dx, ax                                 ; Put everything back the way it was

    jmp int_ret                                 ; We're done!


int_ret:                                        ; Return back to command
    push ax                                     ; Save register state to stack
    mov ax, 0x4000
    mov ds, ax                                  ; The segment our command is loaded in
    mov es, ax
    pop ax                                      ; Restore register state
    
.ret:
    iret                                        ; Interrupt return

.preserve_flags:
    mov word [register_bckp_a], ax
    mov word [register_bckp_b], bx              ; Save register states to backup

    pop ax                                      ; Pop instruction pointer
    pop bx                                      ; Pop code segment

    inc sp
    inc sp                                      ; Move stack pointer past the FLAGS image

    push bx                                     ; Push code segment
    push ax                                     ; Push instruction pointer

    mov ax, word [register_bckp_a]
    mov bx, word [register_bckp_b]              ; Restore register states

    push ax                                     ; Save register state to stack
    mov ax, 0x4000
    mov ds, ax                                  ; The segment our command is loaded in
    mov es, ax
    pop ax                                      ; Restore register state

    retf                                        ; Far return


data_binseg:                                    ; Sets the data segment to the binary segment
    push ax                                     ; Save register state to stack

    mov ax, 0x4000
    mov ds, ax                                  ; Segment the binary command is loaded in

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


data_kernseg:                                   ; Sets the data segment to the kernel segment
    push ax                                     ; Save register state to stack

    mov ax, 0x2000
    mov ds, ax                                  ; Segment we are loaded in

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


data_fileseg:                                   ; Sets the data segment to the file buffer segment
    push ax                                     ; Save register state to stack

    mov ax, 0x1000
    mov ds, ax                                  ; Segment the file buffer is at

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


extra_binseg:                                   ; Sets the extra segment to the binary segment
    push ax                                     ; Save register state to stack

    mov ax, 0x4000
    mov es, ax                                  ; Segment the binary command is loaded in

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller

extra_fileseg:                                  ; Sets the extra segment to the file buffer segment
    push ax                                     ; Save register state to stack

    mov ax, 0x1000
    mov es, ax                                  ; Segment the file buffer is at

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


; ========================================================================
; DATA SECTION
; ========================================================================

data:

; Storage data region
input_buffer        dq 0x0000000000000000
                    db 0x00

input_buffer_addr   dw 0x0000
input_buffer_limit  dw 0x0000

register_bckp_a     dw 0x0000
register_bckp_b     dw 0x0000

; Disk operation data region
filename            db "        "
filename_extension  db "   "

bin_extension       db "BIN"
hob_extension       db "HOB"

drive_num           db 0x00
cluster             dw 0x0000
root_entry          dw 0x0000
buffer_pointer      dw 0x0000
buffer_segment      dw 0x0000

bytes_sector        dw 0x0000
sectors_cluster     db 0x00
reserved            dw 0x0000
fats                db 0x00
root_entries        dw 0x0000
sectors_fat         dw 0x0000
sectors_track       dw 0x0000
heads               dw 0x0000
root_start          dw 0x0000

; Interface strings
iface_welcome       db "House-DOS v0.0.0, Build 10", 0x00
iface_info          db "By Jacob Bates", 0x00
iface_worked        db "This worked!", 0x00
iface_command_bad   db "Bad command.", 0x00
iface_confirm       db "Are you sure? Press Y to confirm: ", 0x00
iface_done          db "Done!", 0x00
iface_aborting      db "Aborting.", 0x00

iface_mem_clear     db "Clearing file buffer...", 0x00
iface_mem_bin       db "Loading file into binary buffer...", 0x00

iface_disk_applied  db "Changes applied to disk.", 0x00
iface_disk_search   db "Searching root directory...", 0x00
iface_disk_found    db "Found file!", 0x00
iface_disk_empty    db "Found empty entry!", 0x00
iface_disk_exists   db "File already exists.", 0x00
iface_disk_cluster  db "Loading cluster...", 0x00
iface_disk_write    db "Writing to cluster...", 0x00
iface_disk_wfats    db "Writing FATs to disk...", 0x00
iface_disk_wroot    db "Writing root directory...", 0x00
iface_disk_reset    db "Resetting disk...", 0x00
iface_disk_nf       db "FATAL: Specified file not found.", 0x00
iface_disk_esize    db "FATAL: File too large to load.", 0x00
iface_disk_efull    db "FATAL: No clusters available.", 0x00
iface_disk_eroot    db "FATAL: No root entries available.", 0x00
iface_disk_eread    db "FATAL: Error while reading disk.", 0x00
iface_disk_ewrite   db "FATAL: Error while writing to disk.", 0x00

iface_fatal_reboot  db "A fatal error was encountered. Press any key to reboot...", 0x00

