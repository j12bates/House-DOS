; ========================================================================
; House-DOS KERNEL
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16
    ORG 0x0000

; ========================================================================
; Header
; ========================================================================

header:
    jmp start                                   ; Don't execute the header

h_creator       dw creator                      ; Creator string
h_desc          dw desc                         ; Description string
h_usage         dw usage                        ; Usage string


; ========================================================================
; STARTUP/REDIRECTION
; ========================================================================

start:                                          ; House-DOS code
    pushf                                       ; Save flags
    call data_kernseg                           ; Access kernel variables

    push bx                                     ; Preserve this value
    mov bx, cs                                  ; Code segment
    cmp bx, 0x4000                              ; Is this being used as a command?
    pop bx                                      ; Restore this value

    je exec                                     ; If so, run execution code

    cmp byte [init_byte], 0x00                  ; Have we just now been loaded?
    je init                                     ; If so, run initialization code


; ========================================================================
; MAIN ROUTINE
; ========================================================================

main:                                           ; Main code for House-DOS kernel
    call setup_segments                         ; Ensure segments are set properly
    je command                                  ; If we were just loaded, get a command

    cmp ah, 0xFF                                ; Did the last command just finish?
    je .handback                                ; If so, prepare to get a command

    cmp ah, 0xFE                                ; Is this a handback with error?
    je .exit_error                              ; If so, display the error message

    cmp byte [break_byte], 0xFF                 ; Are we supposed to break the command?
    je .handback                                ; If so, prepare to get a command

    jmp syscall_handler                         ; Otherwise, a system function was called

.exit_error:
    push si                                     ; Preserve string location

    mov si, iface_perror                        ; Program error message
    call print_str                              ; Print string

    pop si                                      ; Restore string location
    call data_binseg                            ; Read from command
    call println                                ; Print line

    call data_kernseg                           ; Reset segment

.handback:
    call setup_segments                         ; Ensure segments are all ready
    mov sp, 0x3FFE                              ; Reset stack pointer (we're going to pop something in a bit)

    clc                                         ; Show cursor
    call display_cursor                         ; Make sure cursor is visible

    mov bl, 0x07                                ; Light grey on black
    call screen_attribute                       ; Set screen attribute

    call speaker_off                            ; Turn off speaker

    mov byte [break_byte], 0x00                 ; Make sure break byte is off

.output:
    cmp byte [redir_enabled], 0x00              ; Is output redirection enabled?
    je .default                                 ; If not, use default procedure

    mov si, redir_fname                         ; Our redirection filename
    call conv_x3_83                             ; Convert to usable format

    jc command                                  ; If error, don't attempt to write to disk

    mov cx, word [buffer_endpoint]              ; The endpoint is the number of bytes to write
    call write_file                             ; Write to disk

    jmp command                                 ; Skip default procedure

.default:
    call default_out                            ; Output to default device


command:                                        ; Main loop: Retrieve command from user
    popf                                        ; Get this out of the stack
    call setup_segments                         ; Ensure segments are all ready

    mov byte [header_offset], 0x00              ; Reset header offset
    mov byte [redir_enabled], 0x00              ; Reset output redirection

    mov al, byte [config_sys_iface]             ; The system interface configuration
    mov byte [config_iface], al                 ; Move it into the default interface configuration

    call line_break                             ; Line break
    call prompt                                 ; Setup prompt

    mov di, input_buffer                        ; Our input buffer
    mov cx, 0x003F                              ; 63-byte limit

    call input                                  ; Get input from user
    call line_break                             ; Line break
    call line_break                             ; Another line break

    mov si, input_buffer                        ; Read from the input buffer
    mov di, filename                            ; Into the filename
    mov cx, 0x0009                              ; Up to 8 chars in a filename
    cld                                         ; Ensure correct direction

.char_filename:
    lodsb                                       ; Load next char and advance

    cmp al, 0x00                                ; Is this the end of the input?
    je .spaces                                  ; If so, that's the end of the filename

    cmp al, 0x20                                ; Is this a SPACE?
    je .spaces                                  ; If so, that's also the end of the filename

    call capitalize_char                        ; Otherwise, capitalize this character

    stosb                                       ; Move this into our filename and advance
    loop .char_filename                         ; Repeat

    jmp .bad_command                            ; There should have been a null/space by now

.spaces:
    mov al, 0x20                                ; Write spaces
    rep stosb                                   ; Pad remainder of 8-byte filename

.extension:
    push si                                     ; Preserve pointer

    mov si, bin_extension                       ; The extension for a Binary file
    mov di, filename_extension                  ; The extension of the filename
    mov cx, 0x0003                              ; Extension is 3 chars
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Move into our file extension

    pop si                                      ; Restore pointer

.params:
    mov al, 0x00                                ; Write null characters
    mov di, params                              ; Write into our parameter list
    mov cx, end_buffers
    sub cx, params                              ; Overwrite everything between these points
    cld                                         ; Ensure correct direction

    rep stosb                                   ; Clear parameter list

    mov bx, 0x0000                              ; We are not currently reading a parameter or escaping spaces
    push params                                 ; Push the index of our parameter list

.param_char:
    pop di                                      ; Restore destination index
    lodsb                                       ; Load next byte from command

    cmp al, 0x22                                ; Is this a quotation?
    je .quotation                               ; If so, toggle space-escape

    cmp al, 0x00                                ; Is this the end of the input?
    je .load_file                               ; If so, no more parameters

    cmp bl, 0xFF                                ; Are spaces being escaped?
    je .write                                   ; If so, skip spaces

    cmp al, 0x20                                ; Is it a space?
    je .next_param                              ; If so, that's one parameter

    cmp bh, 0xFF                                ; Are we currently reading a parameter?
    je .write                                   ; If so, don't read as flags/header

    cmp al, 0x24                                ; Is this a dollar-sign?
    je .flags                                   ; If so, these are flags

    cmp al, 0x25                                ; Is this a percent-sign?
    je .metadata                                ; If so, we're getting metadata

    cmp al, 0x3E                                ; Is this a forward-facing angle-bracket?
    je .redir                                   ; If so, set up file redirection

.write:
    stosb                                       ; Otherwise, store byte in list

    mov bh, 0xFF                                ; We're currently reading a parameter
    push di                                     ; Push new destination index
    jmp .param_char                             ; And repeat

.quotation:
    xor bl, 0xFF                                ; Toggle space-escape
    jmp .write                                  ; And write the quotation

.flags:
    push di                                     ; Preserve pointer

    mov al, 0x00                                ; Look for a null character
    mov di, param_flags                         ; Write somewhere into our flag list
    mov cx, 0x0024                              ; 36 bytes in the buffer (36 valid characters)
    cld                                         ; Ensure correct direction

    repne scasb                                 ; Seek to the first null character - don't overwrite any existing flags

    dec di                                      ; Avoid an O.B.O.E

.flag_char:
    lodsb                                       ; Load next character
    call capitalize_char                        ; Capitalize

    cmp al, 0x00                                ; Is this a null character?
    je .overwrite_comma                         ; If so, no more parameters

    cmp al, 0x20                                ; Is this a space?
    je .param_char                              ; If so, read next parameter

    call check_flag                             ; Has this flag already been set, or is it invalid?
    je .flag_char                               ; If so, skip this one
    jc .flag_char                               ; If it's invalid, skip

    stosb                                       ; Otherwise, write to our flags
    jmp .flag_char                              ; Read the next character

.next_param:
    mov al, 0x2C                                ; Comma (items are separated by commas)
    stosb                                       ; Write byte

    mov bh, 0x00                                ; We're done writing that parameter
    push di                                     ; Push new destination index
    jmp .param_char                             ; And repeat

.metadata:
    push di                                     ; Preserve destination index

    lodsb                                       ; Read the next character
    call capitalize_char                        ; Capitalize

    add byte [header_offset], 0x02              ; Move our offset ahead a word
    cmp al, 0x43                                ; Is this a C?
    je .param_char                              ; If so, proceed

    add byte [header_offset], 0x02              ; Otherwise, move our offset ahead again
    cmp al, 0x44                                ; Is this a D?
    je .param_char                              ; If so, proceed

    add byte [header_offset], 0x02              ; Otherwise, move our offset ahead again
    cmp al, 0x55                                ; Is this a U?
    je .param_char                              ; If so, proceed

    cmp al, 0x48                                ; Or H?
    je .param_char                              ; If so, proceed

    mov ax, 0x0003                              ; Otherwise, invalid header field
    call error                                  ; Handle this error
    jmp command                                 ; Get a new command

.redir:
    push di                                     ; Preserve destination index
    mov byte [redir_enabled], 0xFF              ; Enable output redirection

    mov di, redir_fname                         ; Write into output redirection filename
    mov cx, 0x000D                              ; Up to 12 characters in the filename
    mov al, 0x00                                ; Write NULL characters
    cld                                         ; Ensure correct direction

    rep stosb                                   ; Overwrite with zeroes

    mov di, redir_fname                         ; Write into output redirection filename
    mov cx, 0x000D                              ; Up to 12 characters in the filename
    cld                                         ; Ensure correct direction

    cmp byte [si], 0x20                         ; Is the next byte a space?
    jne .redir_fname_char                       ; If not, proceed

    inc si                                      ; Otherwise, ignore space

.redir_fname_char:
    lodsb                                       ; Load next byte

    cmp al, 0x00                                ; Is this a NULL character?
    je .overwrite_comma                         ; If so, no more parameters

    cmp al, 0x20                                ; Is this a space?
    je .param_char                              ; If so, next parameter

    call capitalize_char                        ; Otherwise, capitalize character
    stosb                                       ; Write byte to filename

    loop .redir_fname_char                      ; Repeat with next character
    jmp .bad_command                            ; If we've reached this point, bad filename

.overwrite_comma:
    pop di                                      ; Restore pointer
    cmp di, params                              ; Have we written any parameters?
    je .load_file                               ; If not, proceed

    mov byte [di-0x01], 0x00                    ; Otherwise, overwrite last comma

.load_file:
    call verify                                 ; Verify the file exists
    jc .bad_command                             ; If error, bad command

    call get_file_cluster                       ; Get the starting cluster for our file
    call clear_buffer                           ; Clear the buffer
    mov word [file_buffer_pointer], 0x0000      ; Load into the beginning of the buffer

    call load_file                              ; Load file into our file buffer
    jc command                                  ; If error, stop here

    call move_file_bin                          ; Move the contents into the binary buffer
    call clear_buffer                           ; Clear the buffer again

    call data_kernseg                           ; We're about to use some kernel variables

.jump:
    cmp byte [header_offset], 0x00              ; Are we supposed to read from the header?
    jne .header                                 ; If so, don't execute

    call segments_binary                        ; Set segments to the binary segment
    jmp 0x4000:0x0000                           ; Jump to our loaded binary

.header:
    mov ax, 0x0000                              ; Clear AX
    add al, byte [header_offset]                ; Set it to the header offset

    call data_binseg                            ; We want to access data from the command
    cmp word [0x0000], 0x06EB                   ; Is the header signature there?
    jne .error_header                           ; If not, error

    mov si, ax                                  ; This is the index within the header
    mov si, word [si]                           ; The location contained at that point is our string

    call out_str                                ; Output string
    jmp main.handback                           ; Simulate a handback and get a new command

.error_header:
    mov ax, 0x0080                              ; Missing header
    call error                                  ; Handle this error

    jmp main.handback                           ; Simulate a handback, and get a new command

.bad_command:
    mov si, iface_command_bad
    call println                                ; Display an error message

    jmp command                                 ; Try again


handback_manual:                                ; Routine to manually perform handback
    push ds                                     ; Preserve segment

    call data_kernseg                           ; Access a kernel variable
    mov byte [break_byte], 0xFF                 ; Set the break byte

    pop ds                                      ; Restore segment
    iret                                        ; Do an interrupt return


divide_zero:                                    ; Routine for if a DIVIDE_ZERO error happens
    push ax                                     ; Save register state

    mov ax, 0x0010                              ; House-DOS error code
    call error                                  ; Display error message if applicable

    pop ax                                      ; Restore register state
    mov word [register_bckp_a], si              ; Save register state

    pop si                                      ; Restore instruction pointer
    add si, 0x0002                              ; Move past the DIV instruction
    push si                                     ; Put it back

    mov si, word [register_bckp_a]              ; Restore register state
    pushf                                       ; This routine wants a FLAGS image already there
    jmp int_ret.preserve_flags                  ; Perform an interrupt return


; ========================================================================
; SUBSYSTEMS
; ========================================================================

    %INCLUDE "sys/MEM.ASM"
    %INCLUDE "sys/DEV.ASM"
    %INCLUDE "sys/DATA.ASM"
    %INCLUDE "sys/LOGIC.ASM"
    %INCLUDE "sys/IFACE.ASM"
    %INCLUDE "sys/DISK.ASM"
    %INCLUDE "sys/MISC.ASM"
    %INCLUDE "sys/HANDLING.ASM"


; ========================================================================
; BASIC SUBROUTINES
; ========================================================================

; GET PARAMETER: Gets specified parameter from the parameter list
; IN: CX = Parameter number, ES:DI = Output buffer
; OUT: CF = Set on error

get_parameter:                                  ; Get parameter from list
    pusha                                       ; Save register states to stack

    call data_kernseg                           ; We need to access a kernel variable
    mov si, params                              ; Our list of parameters
    call get_item_list                          ; Get parameter from list

    jc .error_param                             ; If failed, error

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.error_param:
    mov ax, 0x0002                              ; Missing parameter
    call error                                  ; Handle this error

    jmp .done                                   ; We're done


; CHECK FLAG: Check if a certain flag was specified in the command
; IN: AL = Flag to check
; OUT: ZF = Set if flag is set, CF = Set on error

check_flag:                                     ; Check if flag was set
    pusha                                       ; Save register states to stack

    call extra_kernseg                          ; We need access to a kernel variable
    call capitalize_char                        ; Capitalize this character

    cmp al, 0x30                                ; Are we below the digit 0?
    jb .invalid                                 ; If so, not a valid flag

    cmp al, 0x39                                ; Are we below the digit 9?
    jb .check                                   ; If so, this is a valid flag

    cmp al, 0x41                                ; Are we below the letter A?
    jb .invalid                                 ; If so, not a valid flag

    cmp al, 0x5A                                ; Are we above the letter Z?
    ja .invalid                                 ; If so, not a valid flag

.check:
    mov cx, 0x0024                              ; 36 bytes in the buffer (36 valid characters)
    mov di, param_flags                         ; Our flag buffer
    cld                                         ; Ensure correct direction

    repne scasb                                 ; Check if one of the bytes match

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.invalid:
    mov al, 0x00                                ; Set to zero
    sub al, 0x01                                ; Subtract to unset zero-flag

    stc                                         ; Carry-flag for error
    jmp .done                                   ; We're done


; SET UP SEGMENTS: Sets both segment registers to the kernel segment
; IN: None
; OUT: DS = 0x2000; ES = 0x2000

setup_segments:                                 ; Setup DS and ES to the kernel segment
    push ax                                     ; Save register state to stack

    mov ax, 0x2000
    mov ds, ax
    mov es, ax                                  ; The segment we're loaded in
    mov gs, ax                                  ; For use in immediately accessing kernel variables

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


; SET SEGMENTS TO BINARY: Sets both segment registers to the binary segment
; IN: None
; OUT: DS = 0x4000; ES = 0x4000

segments_binary:                                ; Setup DS and ES to the binary segment
    push ax                                     ; Save register state to stack

    mov ax, 0x4000
    mov ds, ax
    mov es, ax                                  ; The segment our command is loaded in

    pop ax                                      ; Restore register state
    ret                                         ; Return to caller


; CLEAR BUFFER: Clears the area in memory for storing and manipulating miscellaneous data
; IN: None
; OUT: None

clear_misc_buffer:                              ; Clear the miscellaneous buffer
    pusha                                       ; Save register states to stack

    call setup_segments                         ; We're going to use kernel space

    mov al, 0x00                                ; Overwrite with null characters
    mov cx, 0x0020                              ; The miscellaneous buffer is 32 bytes long
    mov di, misc_buffer                         ; Our buffer
    cld                                         ; Ensure correct direction

    rep stosb                                   ; Overwrite with zeroes

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; SHUT DOWN: Asks to apply any filesystem changes, performs a BIOS shutdown
; IN: None
; OUT: None

shutdown:                                       ; Check for filesystem changes and shutdown
    pusha                                       ; Save register states to stack

    call prompt_apply                           ; Prompt the user to authenticate filesystem changes

    mov si, iface_shutdown
    call print_str                              ; Display message

    call confirm                                ; Ask for confirmation
    jc .done                                    ; If not given, we're done

    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15                                    ; Otherwise, BIOS shutdown

    jmp reboot_fatal                            ; If it didn't work, error

.done:
    mov si, iface_cancelled
    call println                                ; Display message

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; REBOOT: Asks to apply any filesystem changes, reboots the system
; IN: None
; OUT: None

reboot:                                         ; Check for filesystem changes and reboot
    pusha                                       ; Save register states to stack

    call prompt_apply                           ; Prompt the user to authenticate filesystem changes

    mov si, iface_reboot
    call print_str                              ; Display message

    call confirm                                ; Ask for confirmation
    jc .done                                    ; If not given, we're done

    int 0x19                                    ; Otherwise, reboot

    jmp reboot_fatal                            ; If it didn't work, error

.done:
    mov si, iface_cancelled
    call println                                ; Display message

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; FATAL ERROR AND REBOOT: Declares a fatal error and reboots the system
; IN: None
; OUT: None

reboot_fatal:                                   ; Declare fatal error and reboot
    mov si, iface_fatal_reboot
    call print_str                              ; Print message

    mov ah, 0x00                                ; Read from keyboard buffer
    int 0x16                                    ; BIOS keyboard interrupt

    int 0x19                                    ; Reboot


; ========================================================================
; INITIALIZATION CODE
; ========================================================================

init:                                           ; Initialization code
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

    mov al, byte [sectors_cluster]              ; Our sectors per cluster
    mov ah, 0x00                                ; Upper byte of factor is zero
    mul word [bytes_sector]                     ; Multiply by bytes per sector to get the bytes per cluster
    mov word [bytes_cluster], ax                ; Save the number of bytes per sector

    pop bx                                      ; Take this out of the stack for now
    mov sp, 0x4000                              ; Make the stack stretch up to the file buffer (32K)
    push bx                                     ; Push this back

.ivt:
    mov ax, 0x0000
    mov es, ax                                  ; The IVT is in this segment

    mov di, 0x007E                              ; We will be changing the entry for this interrupt
    shl di, 0x2                                 ; 4 bytes per entry

    mov word [es:di], start                     ; Handler (kernel) starts at this offset
    mov word [es:di+0x02], 0x2000               ; We're loaded at this segment

    mov di, 0x001B                              ; We will be changing the entry for the CTRL+BREAK handler
    shl di, 0x2                                 ; 4 bytes per entry

    mov word [es:di], handback_manual           ; Manual handback code is here
    mov word [es:di+0x02], 0x2000               ; We're loaded at this segment

    mov di, 0x0000                              ; We will be changing the entry for the DIVIDE BY ZERO handler

    mov word [es:di], divide_zero               ; Manual divide by zero code is here
    mov word [es:di+0x02], 0x2000               ; We're loaded at this segment

    call random_seed                            ; Create a random number seed

    mov ah, 0x00                                ; Set video mode
    mov al, 0x03                                ; 80x25
    int 0x10                                    ; BIOS VGA interrupt

    mov ax, 0x1003                              ; Configure attribute bit 7
    mov bl, 0x01                                ; Blink
    int 0x10                                    ; BIOS VGA interrupt

.cpu:
    call setup_segments                         ; Use kernel variables
    mov di, info_cpu                            ; CPU info buffer

    mov eax, 0x80000002                         ; First bit of brand string
    call .cpu_string                            ; Get info and append

    mov eax, 0x80000003                         ; Next bit
    call .cpu_string                            ; Get info and append

    mov eax, 0x80000004                         ; Next bit
    call .cpu_string                            ; Get info and append

    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx                                ; Clear out the upper words for sanity

    mov si, info_cpu                            ; CPU info buffer
    mov di, si                                  ; Write to where we're reading
    call str_chomp                              ; Chomp leading spaces

    jmp .noise                                  ; Skip over this subroutine

.cpu_string:
    cpuid                                       ; Get CPU info

    mov dword [di+0x00], eax
    mov dword [di+0x04], ebx
    mov dword [di+0x08], ecx
    mov dword [di+0x0C], edx                    ; Put the values into our buffer

    add di, 0x0010                              ; Move our pointer ahead
    ret                                         ; Return to caller

.noise:
    mov dx, 0x0106                              ; C4
    call conv_hz_freq                           ; Convert to a frequency number
    call speaker_tone                           ; Play on PC speaker

    mov cx, 0x00C0                              ; Some number of milliseconds
    call sleep                                  ; Pause execution

    mov dx, 0x0188                              ; G4
    call conv_hz_freq                           ; Convert to a frequency number
    call speaker_tone                           ; Play on PC speaker

    mov cx, 0x0060                              ; Half the time
    call sleep                                  ; Pause execution

    mov dx, 0x020C                              ; C5
    call conv_hz_freq                           ; Convert to a frequency number
    call speaker_tone                           ; Play on PC speaker

    mov cx, 0x0120                              ; 1 1/2 times the original time
    call sleep                                  ; Pause execution

    call speaker_off                            ; Mute PC speaker

.autoexec:
    mov si, info_os
    call println                                ; Print OS info

    mov si, info_creator
    call println                                ; Print creator info

    mov si, info_cpu
    call println                                ; Print CPU info

    mov byte [init_byte], 0xFF                  ; We've initialized
    xor bx, bx                                  ; Make sure that the zero-flag is set

    jmp main                                    ; Go to main code


; ========================================================================
; EXECUTION CODE
; ========================================================================

exec:                                           ; Execution code
    popf                                        ; Get this out of the stack

    mov bl, 0b00000000                          ; This register will be our new value

.errors:
    mov ah, 0x27                                ; Check parameter
    mov al, 0x45                                ; 'E' for errors
    int 0x7E

    jne .commentary                             ; If not set, proceed
    or bl, 0b00000001                           ; Otherwise, set errors bit

.commentary:
    mov al, 0x43                                ; 'C' for commentary
    int 0x7E

    je .hidden                                  ; If set, proceed
    or bl, 0b00000010                           ; Otherwise, set commentary bit

.hidden:
    mov al, 0x48                                ; 'H' for hidden files
    int 0x7E

    jne .done                                   ; If not set, proceed
    or bl, 0b00000100                           ; Otherwise, set hidden files bit

.done:
    call data_kernseg                           ; Edit kernel variables
    mov byte [config_sys_iface], bl             ; Replace config byte with our new value

    mov ah, 0x02                                ; Print line
    mov si, iface_iface_config                  ; Updating message
    int 0x7E

    mov ah, 0xFF                                ; We're done!
    int 0x7E


; ========================================================================
; SYSTEM CALL HANDLER
; ========================================================================

syscall_handler:                                ; System call handler

.cat:                                           ; The categories
    cmp ah, 0x30                                ; Interface functions
    jb .iface_funcs

    cmp ah, 0x50                                ; Output Functions
    jb .out_funcs

    cmp ah, 0x60                                ; Input functions
    jb .in_funcs

    cmp ah, 0x80                                ; Disk/FS functions
    jb .disk_funcs

    cmp ah, 0x90                                ; Data functions
    jb .data_funcs

    cmp ah, 0xE0                                ; General functions
    jb .general_funcs

    jmp .logical_funcs                          ; Logical functions

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

    cmp ah, 0x06
    je iface_routines.clear                     ; Clear screen

    cmp ah, 0x07
    je iface_routines.cursor                    ; Show/hide cursor

    cmp ah, 0x08
    je iface_routines.cursor_position           ; Set cursor position

    cmp ah, 0x09
    je iface_routines.pause_keypress            ; Wait for a keypress

    cmp ah, 0x0A
    je iface_routines.screen                    ; Set attribute of entire screen

    cmp ah, 0x0B
    je iface_routines.printf                    ; Print with formatting

    cmp ah, 0x0C
    je iface_routines.printlnf                  ; Print line with formatting

    cmp ah, 0x0D
    je iface_routines.get_cursor                ; Get cursor position

    cmp ah, 0x0E
    je iface_routines.get_config                ; Get interface configuration

    cmp ah, 0x0F
    je iface_routines.config                    ; Set interface configuration

    cmp ah, 0x10
    je iface_routines.print_bytes               ; Print bytes

    cmp ah, 0x11
    je iface_routines.block                     ; Draw block

    cmp ah, 0x12
    je iface_routines.key_nonblocking           ; Get key (nonblocking)

    cmp ah, 0x13
    je iface_routines.indent                    ; Indent cursor

    cmp ah, 0x14
    je iface_routines.advance                   ; Advance cursor

    cmp ah, 0x15
    je iface_routines.key_blocking              ; Get next key

    cmp ah, 0x18
    je iface_routines.print_bytes_literal       ; Print literal bytes

    cmp ah, 0x20
    je iface_routines.parameter                 ; Get parameter

    cmp ah, 0x21
    je iface_routines.total_params              ; Get total parameters

    cmp ah, 0x22
    je iface_routines.param_int16               ; Get parameter as 16-bit integer

    cmp ah, 0x23
    je iface_routines.param_int8                ; Get parameter as 8-bit integer

    cmp ah, 0x24
    je iface_routines.param_byte                ; Get parameter as byte

    cmp ah, 0x26
    je iface_routines.flags_used                ; Check if any flags were used

    cmp ah, 0x27
    je iface_routines.check_flag                ; Check if flag was specified

    cmp ah, 0x28
    je iface_routines.param_file                ; Load file from first parameter

    cmp ah, 0x29
    je iface_routines.param_file_offset         ; Load file from parameter to offset

    cmp ah, 0x2A
    je iface_routines.verify_file_param         ; Verify file from parameter

    cmp ah, 0x30
    je iface_routines.info_msg                  ; INFO message

    cmp ah, 0x31
    je iface_routines.warn_msg                  ; WARN message

.out_funcs:                                     ; Output functions
    cmp ax, 0x4000
    je out_routines.string                      ; Output string

    cmp ax, 0x4001
    je out_routines.string_ln                   ; Output string with line break

    cmp ax, 0x4002
    je out_routines.line_break                  ; Output line break

    cmp ax, 0x4010
    je out_routines.bytes                       ; Output bytes

    cmp ax, 0x4020
    je out_routines.file                        ; Output file

    cmp ax, 0x4040
    je out_routines.num_word_dec                ; Output integer as decimal

    cmp ax, 0x4041
    je out_routines.num_byte_dec                ; Output byte as decimal

    cmp ax, 0x4042
    je out_routines.num_word_hex                ; Output integer as hex

    cmp ax, 0x4043
    je out_routines.num_byte_hex                ; Output byte as hex

    cmp ax, 0x4050
    je out_routines.date_dstamp                 ; Output UNIX time as datestamp

    cmp ax, 0x4051
    je out_routines.date_tstamp                 ; Output UNIX time as timestamp

    cmp ax, 0x4100
    je out_routines.clear                       ; Clear buffer

    cmp ax, 0x4110
    je out_routines.set_pointer                 ; Set pointer

    cmp ax, 0x4111
    je out_routines.set_endpoint                ; Set endpoint

    cmp ax, 0x4112
    je out_routines.get_pointer                 ; Get pointer

    cmp ax, 0x4113
    je out_routines.get_endpoint                ; Get endpoint

    cmp ax, 0x4114
    je out_routines.pointer_line_col            ; Get line/col of pointer

    cmp ax, 0x4120
    je out_routines.inc                         ; Increment pointer

    cmp ax, 0x4121
    je out_routines.advance                     ; Advance pointer

    cmp ax, 0x4122
    je out_routines.indent                      ; Indent pointer

    cmp ah, 0x42
    je out_routines.byte                        ; Output byte

    cmp ah, 0x43
    je out_routines.dev                         ; Set default device ID

.in_funcs:                                      ; Input functions
    cmp ax, 0x5000
    je in_routines.string                       ; Retrieve string

    cmp ax, 0x5010
    je in_routines.bytes                        ; Retrieve bytes

    cmp ax, 0x5100
    je in_routines.set_pointer                  ; Set pointer

    cmp ax, 0x5101
    je in_routines.get_pointer                  ; Get pointer

    cmp ah, 0x52
    je in_routines.byte                         ; Retrieve byte

.disk_funcs:                                    ; Disk functions
    cmp ah, 0x60
    je disk_routines.verify                     ; Verify file

    cmp ah, 0x61
    je disk_routines.load                       ; Load file

    cmp ah, 0x62
    je disk_routines.get_bytes_qty              ; Get quantity of bytes from file

    cmp ah, 0x63
    je disk_routines.get_bytes_indices          ; Get bytes between two indices

    cmp ah, 0x64
    je disk_routines.get_line                   ; Get line contents

    cmp ah, 0x65
    je disk_routines.line_address               ; Get line address

    cmp ah, 0x66
    je disk_routines.load_offset                ; Load file to offset

    cmp ah, 0x67
    je disk_routines.line_col                   ; Convert address to line/col numbers

    cmp ah, 0x68
    je disk_routines.write_bytes_qty            ; Write quantity of bytes to file

    cmp ah, 0x69
    je disk_routines.write_bytes_indices        ; Write bytes between two indices to file

    cmp ah, 0x6A
    je disk_routines.write_line                 ; Write line

    cmp ah, 0x6B
    je disk_routines.insert_bytes_qty           ; Insert quantity of bytes

    cmp ah, 0x6C
    je disk_routines.insert_bytes_indices       ; Insert bytes between two indices

    cmp ah, 0x6D
    je disk_routines.insert_line                ; Insert line

    cmp ah, 0x6E
    je disk_routines.clear_buffer               ; Clear entire file buffer

    cmp ah, 0x6F
    je disk_routines.write                      ; Write file to disk

    cmp ah, 0x70
    je disk_routines.size                       ; Get size of file

    cmp ah, 0x71
    je disk_routines.creation                   ; Get creation timestamp

    cmp ah, 0x72
    je disk_routines.access                     ; Get access timestamp

    cmp ah, 0x73
    je disk_routines.write_date                 ; Get last write timestamp

    cmp ah, 0x74
    je disk_routines.read_only                  ; Check if file is read-only

    cmp ah, 0x75
    je disk_routines.hidden                     ; Check if file is hidden

    cmp ah, 0x76
    je disk_routines.system                     ; Check if file is a system file

    cmp ah, 0x77
    je disk_routines.list                       ; Get file list

    cmp ah, 0x78
    je disk_routines.rename                     ; Rename file

    cmp ah, 0x79
    je disk_routines.delete                     ; Delete file

    cmp ah, 0x7A
    je disk_routines.hide_reveal                ; Hide/reveal file

    cmp ah, 0x7E
    je disk_routines.rollback                   ; Rollback filesystem

    cmp ah, 0x7F
    je disk_routines.apply                      ; Apply filesystem changes

.data_funcs:                                    ; Data functions
    cmp ax, 0x8000
    je data_routines.str_cmp                    ; Compare strings

    cmp ax, 0x8001
    je data_routines.str_find                   ; Find substring

    cmp ax, 0x8010
    je data_routines.str_upcase                 ; Make uppercase

    cmp ax, 0x8011
    je data_routines.str_downcase               ; Make lowercase

    cmp ax, 0x8012
    je data_routines.str_sub_qty                ; Get substring (quantity)

    cmp ax, 0x8013
    je data_routines.str_sub_indices            ; Get substring (indices)

    cmp ax, 0x8018
    je data_routines.str_chomp                  ; Chomp leading spaces

    cmp ax, 0x8020
    je data_routines.str_length                 ; Get length

    cmp ax, 0x8100
    je data_routines.list_get_item              ; Get a list item

    cmp ax, 0x8101
    je data_routines.list_total                 ; Get total list items

    cmp ax, 0x8200
    je data_routines.num_word_hex               ; Print word as hex

    cmp ax, 0x8201
    je data_routines.num_byte_hex               ; Print byte as hex

    cmp ax, 0x8202
    je data_routines.num_word_dec               ; Print word as decimal

    cmp ax, 0x8203
    je data_routines.num_byte_dec               ; Print byte as decimal

    cmp ax, 0x8300
    je data_routines.date_dstamp                ; Print UNIX time as datestamp

    cmp ax, 0x8301
    je data_routines.date_tstamp                ; Print UNIX time as timestamp

.general_funcs:                                 ; General functions
    cmp ah, 0xA0
    je general_routines.random                  ; Generate random number

    cmp ah, 0xA1
    je general_routines.random_seed             ; Generate random number seed

    cmp ah, 0xA2
    je general_routines.shutdown                ; Shut down system

    cmp ah, 0xA3
    je general_routines.reboot                  ; Reboot system

    cmp ah, 0xB0
    je general_routines.os_version              ; Get OS version string

    cmp ah, 0xB1
    je general_routines.os_creator              ; Get OS creator string

    cmp ah, 0xB2
    je general_routines.cpu_brand               ; Get CPU brand string

    cmp ah, 0xC0
    je general_routines.sleep_milli             ; Sleep milliseconds

    cmp ah, 0xC1
    je general_routines.sleep_hertz             ; Sleep a certain number of frames at a certain frequency

    cmp ah, 0xC2
    je general_routines.speaker                 ; Play PC speaker tone

    cmp ah, 0xC3
    je general_routines.speaker_off             ; Turn off PC speaker

    cmp ah, 0xD0
    je general_routines.unix                    ; Get current UNIX time

    cmp ah, 0xD1
    je general_routines.seconds_days            ; Convert UNIX timestamp to seconds/days

    cmp ah, 0xD2
    je general_routines.timestamp               ; Convert UNIX timestamp to ASCII timestamp

    cmp ah, 0xD3
    je general_routines.datestamp               ; Convert UNIX timestamp to ASCII datestamp

.logical_funcs:                                 ; Logical functions
    cmp ah, 0xF0
    je logical_routines.conv_word_hex           ; Convert word to hexadecimal notation

    cmp ah, 0xF1
    je logical_routines.conv_word_dec_usigned   ; Convert word to decimal notation (unsigned)

    cmp ah, 0xF2
    je logical_routines.conv_hex_word           ; Convert hexadecimal notation to binary word

    cmp ah, 0xF3
    je logical_routines.conv_dec_word           ; Convert decimal notation to binary word

    cmp ah, 0xF4
    je logical_routines.conv_byte_hex           ; Convert byte to hexadecimal notation

    cmp ah, 0xF5
    je logical_routines.conv_byte_dec_usigned   ; Convert byte to decimal notation (unsigned)

    cmp ah, 0xF6
    je logical_routines.conv_hex_byte           ; Convert hexadecimal notation to binary byte

    cmp ah, 0xF7
    je logical_routines.conv_dec_byte           ; Convert decimal notation to binary byte

.default:
    stc                                         ; Carry flag for error
    jmp int_ret.preserve_flags                  ; If invalid function number, we're done!


; ========================================================================
; SYSTEM CALL ROUTINES
; ========================================================================

out_routines:                                   ; Output functions

.string:
    call data_binseg                            ; Read data from the program
    call out_str                                ; Output string
    jmp int_ret                                 ; We're done!

.string_ln:
    call data_binseg                            ; Read data from the program
    call out_str                                ; Output string

    mov al, 0x0A                                ; Newline character
    call out_byte                               ; Output byte

    jmp int_ret                                 ; We're done!

.line_break:
    push ax                                     ; Save register state to stack

    mov al, 0x0A                                ; Newline character
    call out_byte                               ; Output byte

    pop ax                                      ; Restore register state
    jmp int_ret                                 ; We're done!

.bytes:
    call data_binseg                            ; Read data from the program
    call out_bytes                              ; Output bytes
    jmp int_ret                                 ; We're done!

.file:
    pusha                                       ; Save register states to stack

    call get_file_cluster                       ; Get file starting cluster

    mov ax, word [buffer_out_pointer]           ; The buffer pointer
    mov word [file_buffer_pointer], ax          ; Load the file there
    call load_file                              ; Load file

    mov ah, 0x1C                                ; File size
    call get_file_info                          ; Retrieve from directory entry
    add word [buffer_out_pointer], ax           ; Advance buffer pointer past the file

    popa                                        ; Restore register states
    jmp int_ret                                 ; We're done!

.num_word_dec:
    pusha                                       ; Save register states to stack

    mov ax, dx                                  ; Use correct register
    mov di, num_buffer                          ; Our buffer
    call conv_word_dec_unsigned                 ; Convert to decimal

    mov si, di                                  ; Print from our buffer
    call out_str                                ; Output string

    popa                                        ; Restore register states
    jmp int_ret                                 ; We're done!

.num_byte_dec:
    pusha                                       ; Save register states to stack

    mov al, dl                                  ; Use correct register
    mov di, num_buffer                          ; Our buffer
    call conv_byte_dec_unsigned                 ; Convert to decimal

    mov si, di                                  ; Print from our buffer
    call out_str                                ; Output string

    popa                                        ; Restore register states
    jmp int_ret                                 ; We're done!

.num_word_hex:
    pusha                                       ; Save register states to stack

    mov ax, dx                                  ; Use correct register
    mov di, num_buffer                          ; Our buffer
    call conv_word_hex                          ; Convert to hex

    mov si, di                                  ; Print from our buffer
    mov cx, 0x0004                              ; 4 nibbles in a word
    call out_bytes                              ; Output bytes

    popa                                        ; Restore register states
    jmp int_ret                                 ; We're done!

.num_byte_hex:
    pusha                                       ; Save register states to stack

    mov al, dl                                  ; Use correct register
    mov di, num_buffer                          ; Our buffer
    call conv_byte_hex                          ; Convert to hex

    mov si, di                                  ; Print from our buffer
    mov cx, 0x0002                              ; 2 nibbles in a byte
    call out_bytes                              ; Output bytes

    popa                                        ; Restore register states
    jmp int_ret                                 ; We're done!

.date_dstamp:
    pusha                                       ; Save register states to stack

    mov ax, bx                                  ; Programs deal with UNIX timestamps in DX:BX
    mov di, date_buffer                         ; Our buffer

    call dis_unix_timestamp                     ; Disassemble UNIX timestamp
    call conv_days_rtcdate                      ; Convert to RTC date
    call conv_rtcdate_stamp                     ; Convert to datestamp

    mov si, di                                  ; Print from our buffer
    mov cx, 0x000A                              ; 10 bytes in a datestamp
    call out_bytes                              ; Output bytes

    popa                                        ; Restore register states
    jmp int_ret                                 ; We're done!

.date_tstamp:
    pusha                                       ; Save register states to stack

    mov ax, bx                                  ; Programs deal with UNIX timestamps in DX:BX
    mov di, time_buffer                         ; Our buffer

    call dis_unix_timestamp                     ; Disassemble UNIX timestamp
    call conv_seconds_rtctime                   ; Convert to RTC time
    call conv_rtctime_stamp                     ; Convert to timestamp

    mov si, di                                  ; Print from our buffer
    mov cx, 0x0008                              ; 8 bytes in a timestamp
    call out_bytes                              ; Output bytes

    popa                                        ; Restore register states
    jmp int_ret                                 ; We're done!

.clear:
    call clear_buffer                           ; Clear I/O buffer
    jmp int_ret                                 ; We're done!

.set_pointer:
    mov word [buffer_out_pointer], di           ; Set output buffer pointer
    call update_endpoint                        ; Update output endpoint
    jmp int_ret                                 ; We're done!

.set_endpoint:
    mov word [buffer_endpoint], cx              ; Set output endpoint
    jmp int_ret                                 ; We're done!

.get_pointer:
    mov di, word [buffer_out_pointer]           ; Get output buffer pointer
    jmp int_ret                                 ; We're done!

.get_endpoint:
    mov cx, word [buffer_endpoint]              ; Get output endpoint
    jmp int_ret                                 ; We're done!

.pointer_line_col:
    push si                                     ; Save register state to stack

    mov si, word [buffer_out_pointer]           ; Get output buffer pointer
    call addr_line_col                          ; Convert to line/col numbers

    pop si                                      ; Restore register state
    jmp int_ret                                 ; We're done!

.inc:
    inc word [buffer_out_pointer]               ; Increment output buffer pointer
    jmp int_ret                                 ; We're done!

.advance:
    add word [buffer_out_pointer], cx           ; Advance output buffer pointer
    jmp int_ret                                 ; We're done!

.indent:
    call indent_out_pointer                     ; Indent output buffer pointer
    jmp int_ret                                 ; We're done!

.byte:
    call out_byte                               ; Output byte
    jmp int_ret                                 ; We're done!

.dev:
    mov byte [default_dev], al                  ; Set default device ID
    jmp int_ret                                 ; We're done!


in_routines:                                    ; Input functions

.string:
    push cx                                     ; Save register state to stack

    call data_fileseg                           ; Read data from the buffer
    mov si, word [buffer_in_pointer]            ; At our pointer

    clc                                         ; Use DS:SI
    call str_len                                ; Get string length
    inc cx                                      ; Retrieve the NULL character as well

    call in_bytes                               ; Retrieve bytes

    pop cx                                      ; Restore register state
    jmp int_ret.preserve_flags                  ; We're done!

.bytes:
    call extra_binseg                           ; Write data to the program
    call in_bytes                               ; Retrieve bytes
    jmp int_ret.preserve_flags                  ; We're done!

.set_pointer:
    mov word [buffer_in_pointer], si            ; Set input buffer pointer
    jmp int_ret                                 ; We're done!

.get_pointer:
    mov si, word [buffer_in_pointer]            ; Get input buffer pointer
    jmp int_ret                                 ; We're done!

.byte:
    call in_byte                                ; Retrieve byte
    jmp int_ret.preserve_flags                  ; We're done!


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
    jmp int_ret.preserve_flags                  ; We're done!

.input:
    call extra_binseg                           ; We want to give data to the command

    call input                                  ; Get input
    call line_break                             ; Line Break

    jmp int_ret                                 ; We're done!

.line:
    call line_break                             ; Line break
    jmp int_ret                                 ; We're done!

.clear:
    call clear                                  ; Clear screen

    mov dx, 0x0000                              ; Upper left corner
    call move_cursor                            ; Set cursor position

    jmp int_ret                                 ; We're done!

.cursor:
    popf                                        ; We'll need the flags
    call display_cursor                         ; Show/hide cursor
    jmp int_ret.flags_used                      ; We're done!

.cursor_position:
    call move_cursor                            ; Set cursor position
    jmp int_ret                                 ; We're done!

.pause_keypress:
    call pause_keypress                         ; Pause for keypress
    jmp int_ret                                 ; We're done!

.screen:
    call screen_attribute                       ; Set attribute for entire screen
    jmp int_ret                                 ; We're done!

.printf:
    call data_binseg                            ; We want to access data from the command
    call printf                                 ; Print with formatting
    jmp int_ret                                 ; We're done!

.printlnf:
    call data_binseg                            ; We want to access data from the command

    call printf                                 ; Print with formatting
    call line_break                             ; Line break

    jmp int_ret                                 ; We're done!

.get_cursor:
    call get_cursor_pos                         ; Get cursor position
    jmp int_ret                                 ; We're done!

.get_config:
    mov al, byte [config_iface]                 ; Get the interface config byte
    jmp int_ret                                 ; We're done!

.config:
    mov byte [config_iface], al                 ; Set the interface config byte
    jmp int_ret                                 ; We're done!

.print_bytes:
    call data_binseg                            ; We want to access data from the command

    clc                                         ; Newlines should behave as newlines
    call print_bytes                            ; Print bytes

    jmp int_ret                                 ; We're done!

.block:
    call block                                  ; Draw block
    jmp int_ret                                 ; We're done!

.key_nonblocking:
    call get_key_nonblocking                    ; Get keyboard status
    jmp int_ret.preserve_flags                  ; We're done!

.indent:
    call indent                                 ; Indent cursor
    jmp int_ret.preserve_flags                  ; We're done!

.advance:
    call advance_cursor                         ; Advance cursor
    jmp int_ret                                 ; We're done!

.key_blocking:
    call get_key                                ; Get next key
    jmp int_ret                                 ; We're done!

.print_bytes_literal:
    call data_binseg                            ; We want to access data from the command

    stc                                         ; Newlines should behave as characters
    call print_bytes                            ; Print bytes

    jmp int_ret                                 ; We're done!

.parameter:
    call extra_binseg                           ; We want to give data to the command
    call get_parameter                          ; Get parameter
    jmp int_ret.preserve_flags                  ; We're done!

.total_params:
    push si                                     ; Preserve this value

    mov si, params                              ; Our list of parameters
    call get_total_list                         ; Get total number of parameters from list

    pop si                                      ; Restore this value
    jmp int_ret.preserve_flags                  ; We're done!

.param_int16:
    push di                                     ; Preserve this value

    call clear_misc_buffer                      ; Clear the miscellaneous buffer

    mov di, misc_buffer                         ; Our buffer
    call get_parameter                          ; Get parameter

    pop di                                      ; Restore this value

    jc int_ret.preserve_flags                   ; If failed, we're done

    push si                                     ; Preserve this value

    mov si, misc_buffer                         ; Our buffer
    call conv_dec_unsigned_word                 ; Convert to binary number

    pop si                                      ; Restore this value

    jmp int_ret.preserve_flags                  ; We're done!

.param_int8:
    push di                                     ; Preserve this value

    call clear_misc_buffer                      ; Clear the miscellaneous buffer

    mov di, misc_buffer                         ; Our buffer
    call get_parameter                          ; Get parameter

    pop di                                      ; Restore this value

    jc int_ret.preserve_flags                   ; If failed, we're done

    push si                                     ; Preserve this value

    mov si, misc_buffer                         ; Our buffer
    call conv_dec_unsigned_byte                 ; Convert to binary number

    pop si                                      ; Restore this value

    jmp int_ret.preserve_flags                  ; We're done!

.param_byte:
    push di                                     ; Preserve this value

    call clear_misc_buffer                      ; Clear the miscellaneous buffer

    mov di, misc_buffer                         ; Our buffer
    call get_parameter                          ; Get parameter from list

    pop di                                      ; Restore this value

    jc int_ret.preserve_flags                   ; If failed, we're done

    mov al, byte [misc_buffer]                  ; Read the first byte

    jmp int_ret.preserve_flags                  ; We're done!

.flags_used:
    cmp byte [param_flags], 0x00                ; Is the first byte in our flag buffer a null character? (If so, no flags)
    jmp int_ret.preserve_flags                  ; We're done!

.check_flag:
    call check_flag                             ; Check if flag was specified
    jmp int_ret.preserve_flags                  ; We're done!

.param_file:
    call clear_buffer                           ; Clear the buffer

    mov cx, 0x0000                              ; First parameter
    call verify_file_param                      ; Verify file from parameter

    jc int_ret.preserve_flags                   ; If error, we're done

    call get_file_cluster                       ; Get file starting cluster

    mov word [file_buffer_pointer], 0x0000      ; Load into the beginning of the buffer
    call load_file                              ; Load file

    jmp int_ret.preserve_flags                  ; We're done!

.param_file_offset:
    call verify_file_param                      ; Verify file from parameter
    jc int_ret.preserve_flags                   ; If error, we're done

    call get_file_cluster                       ; Get file starting cluster

    mov word [file_buffer_pointer], di          ; Our offset goes here in memory
    call load_file                              ; Load file

    jmp int_ret.preserve_flags                  ; We're done!

.verify_file_param:
    call verify_file_param                      ; Verify file from parameter
    jmp int_ret.preserve_flags                  ; We're done!

.info_msg:
    call data_binseg                            ; Get data from the command
    call msg_info                               ; Print message
    jmp int_ret                                 ; We're done!

.warn_msg:
    call data_binseg                            ; Get data from the command
    call msg_warn                               ; Print message/get confirmation
    jmp int_ret.preserve_flags                  ; We're done!


data_routines:                                  ; Data functions

.str_cmp:
    call segments_binary                        ; We're working with stuff in the command
    call cmp_strs                               ; Compare strings
    jmp int_ret.preserve_flags                  ; We're done!

.str_find:
    call segments_binary                        ; We're working with stuff in the command
    call find_substr                            ; Find substring
    jmp int_ret.preserve_flags                  ; We're done!

.str_upcase:
    call segments_binary                        ; We're working with stuff in the command

    stc                                         ; Carry flag for uppercase
    call case_str                               ; Change case

    jmp int_ret.preserve_flags                  ; We're done!

.str_downcase:
    call segments_binary                        ; We're working with stuff in the command

    clc                                         ; Clear carry flag for lowercase
    call case_str                               ; Change case

    jmp int_ret.preserve_flags                  ; We're done!

.str_sub_qty:
    call segments_binary                        ; We're working with stuff in the command
    call substr                                 ; Retrieve substring
    jmp int_ret.preserve_flags                  ; We're done!

.str_sub_indices:
    call segments_binary                        ; We're working with stuff in the command

    sub cx, bx                                  ; Subtract to get the length
    call substr                                 ; Retrieve substring

    jmp int_ret.preserve_flags                  ; We're done!

.str_chomp:
    call segments_binary                        ; We're working with stuff in the command
    call str_chomp                              ; Chomp leading spaces
    jmp int_ret                                 ; Return to caller

.str_length:
    call segments_binary                        ; We're working with stuff in the command

    clc                                         ; Use source operand
    call str_len                                ; Get string length

    jmp int_ret                                 ; We're done!

.list_get_item:
    call segments_binary                        ; We're working with stuff in the command
    call get_item_list                          ; Get list item
    jmp int_ret.preserve_flags                  ; We're done!

.list_total:
    call data_binseg                            ; We want to access data from the command
    call get_total_list                         ; Get total number of list items
    jmp int_ret                                 ; We're done!

.num_word_hex:
    pusha                                       ; Save register states to stack

    mov ax, dx                                  ; Use correct register
    mov di, num_buffer                          ; Our buffer
    call conv_word_hex                          ; Convert to hex

    mov si, di                                  ; Print from our buffer
    mov cx, 0x0004                              ; 4 nibbles in a word
    call print_bytes                            ; Print bytes

    popa                                        ; Restore register states
    jmp int_ret                                 ; We're done!

.num_byte_hex:
    pusha                                       ; Save register states to stack

    mov al, dl                                  ; Use correct register
    mov di, num_buffer                          ; Our buffer
    call conv_byte_hex                          ; Convert to hex

    mov si, di                                  ; Print from our buffer
    mov cx, 0x0002                              ; 2 nibbles in a byte
    call print_bytes                            ; Print bytes

    popa                                        ; Restore register states
    jmp int_ret                                 ; We're done!

.num_word_dec:
    pusha                                       ; Save register states to stack

    mov ax, dx                                  ; Use correct register
    mov di, num_buffer                          ; Our buffer
    call conv_word_dec_unsigned                 ; Convert to decimal

    mov si, di                                  ; Print from our buffer
    call print_str                              ; Print string

    popa                                        ; Restore register states
    jmp int_ret                                 ; We're done!

.num_byte_dec:
    pusha                                       ; Save register states to stack

    mov al, dl                                  ; Use correct register
    mov di, num_buffer                          ; Our buffer
    call conv_byte_dec_unsigned                 ; Convert to decimal

    mov si, di                                  ; Print from our buffer
    call print_str                              ; Print string

    popa                                        ; Restore register states
    jmp int_ret                                 ; We're done!

.date_dstamp:
    pusha                                       ; Save register states to stack

    mov ax, bx                                  ; Programs deal with UNIX timestamps in DX:BX
    mov di, date_buffer                         ; Our buffer

    call dis_unix_timestamp                     ; Disassemble UNIX timestamp
    call conv_days_rtcdate                      ; Convert to RTC date
    call conv_rtcdate_stamp                     ; Convert to datestamp

    mov si, di                                  ; Print from our buffer
    mov cx, 0x000A                              ; 10 bytes in a datestamp
    call print_bytes                            ; Print bytes

    popa                                        ; Restore register states
    jmp int_ret                                 ; We're done!

.date_tstamp:
    pusha                                       ; Save register states to stack

    mov ax, bx                                  ; Programs deal with UNIX timestamps in DX:BX
    mov di, time_buffer                         ; Our buffer

    call dis_unix_timestamp                     ; Disassemble UNIX timestamp
    call conv_seconds_rtctime                   ; Convert to RTC time
    call conv_rtctime_stamp                     ; Convert to timestamp

    mov si, di                                  ; Print from our buffer
    mov cx, 0x0008                              ; 8 bytes in a timestamp
    call print_bytes                            ; Print bytes

    popa                                        ; Restore register states
    jmp int_ret                                 ; We're done!


general_routines:                               ; General functions

.random:
    call random                                 ; Generate random number
    jmp int_ret                                 ; We're done!

.random_seed:
    call random_seed                            ; Generate random number seed
    jmp int_ret                                 ; We're done!

.shutdown:
    call shutdown                               ; BIOS shutdown
    jmp int_ret                                 ; We're done!

.reboot:
    call reboot                                 ; Reboot
    jmp int_ret                                 ; We're done!

.os_version:
    push si                                     ; Save register state

    mov si, info_os                             ; OS info string
    call str_return                             ; Give string to command

    pop si                                      ; Restore register state
    jmp int_ret                                 ; We're done!

.os_creator:
    push si                                     ; Save register state

    mov si, info_creator                        ; Creator info string
    call str_return                             ; Give string to command

    pop si                                      ; Restore register state
    jmp int_ret                                 ; We're done!

.cpu_brand:
    push si                                     ; Save register state

    mov si, info_cpu                            ; CPU brand string
    call str_return                             ; Give string to command

    pop si                                      ; Restore register state
    jmp int_ret                                 ; We're done!

.sleep_milli:
    call sleep                                  ; Sleep
    jmp int_ret                                 ; We're done!

.sleep_hertz:
    call sleep_freq                             ; Sleep a certain number of frames at a certain frequency
    jmp int_ret                                 ; We're done!

.speaker:
    push dx                                     ; Preserve this value
    call conv_hz_freq                           ; Convert to frequency number
    call speaker_tone                           ; Play tone on PC speaker

    pop dx                                      ; Restore this value
    jmp int_ret                                 ; We're done!

.speaker_off:
    call speaker_off                            ; Turn off PC speaker
    jmp int_ret                                 ; We're done!

.unix:
    push cx                                     ; Preserve this value

    call get_date                               ; Get RTC date
    call conv_rtcdate_days                      ; Convert to days

    push ax                                     ; Preserve this value
    push dx                                     ; Save days
    call get_time                               ; Get RTC time
    call conv_rtctime_seconds                   ; Convert to seconds

    pop dx                                      ; Restore days
    call unix_timestamp                         ; Generate UNIX timestamp

    mov bx, ax                                  ; This should be stored in BX
    pop ax                                      ; Restore this value
    pop cx                                      ; Restore this value
    jmp int_ret                                 ; We're done!

.seconds_days:
    push ax                                     ; Preserve this value

    mov ax, bx                                  ; Programs deal with UNIX timestamps in BX, we want AX
    call dis_unix_timestamp                     ; Disassemble UNIX timestamp

    pop ax                                      ; Restore this value
    jmp int_ret.preserve_flags                  ; We're done!

.timestamp:
    pusha                                       ; Save register states to stack

    mov ax, bx                                  ; Programs deal with UNIX timestamps in BX, we want AX
    call dis_unix_timestamp                     ; Disassemble UNIX timestamp

    call conv_seconds_rtctime                   ; Convert to RTC time

    call extra_binseg                           ; We want to give data to the command
    call conv_rtctime_stamp                     ; Convert to timestamp

    popa                                        ; Restore register states
    jmp int_ret                                 ; We're done!

.datestamp:
    pusha                                       ; Save register states to stack

    mov ax, bx                                  ; Programs deal with UNIX timestamps in BX, we want AX
    call dis_unix_timestamp                     ; Disassemble UNIX timestamp

    call conv_days_rtcdate                      ; Convert to RTC date

    call extra_binseg                           ; We want to give data to the command
    call conv_rtcdate_stamp                     ; Convert to datestamp

    popa                                        ; Restore register states
    jmp int_ret                                 ; We're done!


disk_routines:                                  ; Disk functions

.verify:
    call data_binseg                            ; We want to access data from the command

    call conv_x3_83                             ; Convert filename to proper format
    jc int_ret.preserve_flags                   ; If error, we're done

    call verify_error_nf                        ; Search the directory and verify the file's entry

    jmp int_ret.preserve_flags                  ; We're done!

.load:
    call get_file_cluster                       ; Get the starting cluster of the verified file
    call clear_buffer                           ; Clear the buffer
    mov word [file_buffer_pointer], 0x0000      ; Load into the beginning of the buffer

    call load_file                              ; Load the file into the file buffer

    jmp int_ret.preserve_flags                  ; We're done!

.get_bytes_qty:
    call data_fileseg                           ; We want to access data from the file buffer
    call extra_binseg                           ; We want to give data to the command

    cmp cx, 0x0000                              ; Is our counter zero?
    je int_ret                                  ; If so, avoid an endless loop

    push cx                                     ; Save register states to stack

    cld                                         ; Ensure correct direction
    rep movsb                                   ; Copy the correct number of bytes

    pop cx                                      ; Restore register states
    jmp int_ret                                 ; We're done!

.get_bytes_indices:
    call data_fileseg                           ; We want to access data from the file buffer
    call extra_binseg                           ; We want to give data to the command

    cmp cx, si                                  ; Would our counter be zero?
    je int_ret                                  ; If so, avoid an endless loop

    push cx                                     ; Save register states to stack

    sub cx, si                                  ; Convert index to number of bytes
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Copy the correct number of bytes

    pop cx                                      ; Restore register states
    jmp int_ret                                 ; We're done!

.get_line:
    call extra_binseg                           ; We want to give data to the command

    call get_line_addr                          ; Get the address of the line
    jc int_ret.preserve_flags                   ; If error, we're done

    push cx                                     ; Save register state to stack
    call data_fileseg                           ; We want to access data from the file buffer
    call get_line_length                        ; Get the number of bytes to copy

    inc sp
    inc sp                                      ; Temporarily balance stack

    jc int_ret.preserve_flags                   ; If error, we're done
    sub sp, 0x0002                              ; Otherwise, put stack the way it was

    cld                                         ; Ensure correct direction
    rep movsb                                   ; Copy the correct number of bytes

    pop cx                                      ; Restore register state
    jmp int_ret.preserve_flags                  ; We're done!

.line_address:
    call get_line_addr                          ; Get line address
    jmp int_ret.preserve_flags                  ; We're done!

.load_offset:
    call get_file_cluster                       ; Get the starting cluster of the verified file

    mov word [file_buffer_pointer], di          ; Put our offset in the correct place
    call load_file                              ; Load the file into the file buffer

    jmp int_ret.preserve_flags                  ; We're done!

.line_col:
    call addr_line_col                          ; Convert address to line/col numbers
    jmp int_ret                                 ; We're done!

.write_bytes_qty:
    call data_binseg                            ; We want to access data from the command
    call extra_fileseg                          ; We want to give data to the file buffer

    cmp cx, 0x0000                              ; Is our counter zero?
    je int_ret                                  ; If so, avoid an endless loop

    push cx                                     ; Save register states to stack

    cld                                         ; Ensure correct direction
    rep movsb                                   ; Copy the correct number of bytes

    pop cx                                      ; Restore register states
    jmp int_ret                                 ; We're done!

.write_bytes_indices:
    call data_binseg                            ; We want to access data from the command
    call extra_fileseg                          ; We want to give data to the file buffer

    cmp cx, si                                  ; Would our counter be zero?
    je int_ret                                  ; If so, avoid an endless loop

    push cx                                     ; Save register states to stack
    
    sub cx, si                                  ; Convert index to number of bytes
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Copy the correct number of bytes

    pop cx                                      ; Restore register states
    jmp int_ret                                 ; We're done!

.write_line:
    call data_binseg                            ; We want to access data from the command
    call write_line                             ; Write line
    jmp int_ret                                 ; We're done!

.insert_bytes_qty:
    xchg si, di                                 ; The destination is the source for shifting
    call shift                                  ; Shift everything in the file buffer over
    xchg si, di                                 ; Restore destination and source

    call data_binseg                            ; We want to access data from the command

    cmp cx, 0x0000                              ; Is our counter zero? Is it negative?
    jle int_ret                                 ; If so, avoid an endless loop, or don't overwrite shifted bytes

    push cx                                     ; Save register states to stack

    cld                                         ; Ensure correct direction
    rep movsb                                   ; Copy the correct number of bytes

    pop cx                                      ; Restore register states
    jmp int_ret                                 ; We're done!

.insert_bytes_indices:
    xchg si, di                                 ; The destination is the source for shifting
    call shift                                  ; Shift everything in the file buffer over to make room
    xchg si, di                                 ; Restore destination and source

    call data_binseg                            ; We want to access data from the command

    cmp cx, si                                  ; Would our counter be zero?
    je int_ret                                  ; If so, avoid an endless loop

    push cx                                     ; Save register states to stack

    sub cx, si                                  ; Convert index to number of bytes
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Copy the correct number of bytes

    pop cx                                      ; Restore register states
    jmp int_ret                                 ; We're done!

.insert_line:
    pusha                                       ; Save register states to stack

    xchg si, di                                 ; Preserve our input buffer location
    call get_line_addr                          ; Get the address of the line as it is
    jc int_ret.preserve_flags                   ; If error, we're done
    xchg si, di                                 ; Restore buffer location, the address is our destination

    call data_binseg                            ; Access data from the command
    call get_line_length                        ; Get the number of bytes to insert
    push cx                                     ; Preserve this (this will be our return value)

    xchg si, di                                 ; The destination is the source for shifting
    call shift                                  ; Shift everything in the file buffer over to make room
    xchg si, di                                 ; Restore destination and source

    call data_binseg                            ; Access data from the command

    cld                                         ; Ensure correct direction
    rep movsb                                   ; Copy the correct number of bytes

    pop word [register_bckp_a]                  ; Preserve our output
    popa                                        ; Restore register states
    mov cx, word [register_bckp_a]              ; Restore our output

    jmp int_ret.preserve_flags                  ; We're done!

.clear_buffer:
    call clear_buffer                           ; Clear the file buffer
    jmp int_ret                                 ; We're done!

.write:
    call data_binseg                            ; We want to access data from the command

    cmp si, 0x0000                              ; Is SI 0?
    je ._write                                  ; If so, skip ahead

    call conv_x3_83                             ; Otherwise, convert filename to proper format
    jc int_ret.preserve_flags                   ; If error, we're done

._write:
    call write_file                             ; Write file to disk

    jmp int_ret.preserve_flags                  ; We're done!

.size:
    mov al, 0x1C                                ; File size
    call get_file_info                          ; Get item from root directory

    jmp int_ret.preserve_flags                  ; We're done!

.creation:
    push ax
    push cx                                     ; Preserve these values

    mov al, 0x10                                ; Creation date
    call get_file_info                          ; Get item from directory

    call conv_fat_rtcdate                       ; Convert to an RTC date
    call conv_rtcdate_days                      ; Convert to days
    push dx                                     ; Preserve number of days

    mov al, 0x0E                                ; Creation time
    call get_file_info                          ; Get item from directory

    call conv_fat_rtctime                       ; Convert to an RTC time
    call conv_rtctime_seconds                   ; Convert to seconds

    pop dx                                      ; Restore number of days
    call unix_timestamp                         ; Create UNIX timestamp

    mov bx, ax                                  ; This should be stored in BX

    pop cx
    pop ax                                      ; Restore these values
    jmp int_ret                                 ; We're done!

.access:
    push ax
    push cx                                     ; Preserve these values

    mov al, 0x12                                ; Access date
    call get_file_info                          ; Get item from directory

    call conv_fat_rtcdate                       ; Convert to an RTC date
    call conv_rtcdate_days                      ; Convert to days

    mov ax, 0x0000                              ; We don't have a time
    clc                                         ; Clear the leftmost bit

    call unix_timestamp                         ; Create UNIX timestamp

    mov bx, ax                                  ; This should be stored in BX

    pop cx
    pop ax                                      ; Restore these values
    jmp int_ret                                 ; We're done!

.write_date:
    push ax
    push cx                                     ; Preserve these values

    mov al, 0x18                                ; Last write date
    call get_file_info                          ; Get item from directory

    call conv_fat_rtcdate                       ; Convert to an RTC date
    call conv_rtcdate_days                      ; Convert to days
    push dx                                     ; Preserve number of days

    mov al, 0x16                                ; Last write time
    call get_file_info                          ; Get item from directory

    call conv_fat_rtctime                       ; Convert to an RTC time
    call conv_rtctime_seconds                   ; Convert to seconds

    pop dx                                      ; Restore number of days
    call unix_timestamp                         ; Create UNIX timestamp

    mov bx, ax                                  ; This should be stored in BX

    pop cx
    pop ax                                      ; Restore these values
    jmp int_ret                                 ; We're done!

.read_only:
    call is_read_only                           ; Check if file is read-only
    jmp int_ret.preserve_flags                  ; We're done!

.hidden:
    call is_hidden                              ; Check if file is hidden
    jmp int_ret.preserve_flags                  ; We're done!

.system:
    call is_system                              ; Check if file is a system file
    jmp int_ret.preserve_flags                  ; We're done!

.list:
    call extra_binseg                           ; We want to give data to the command
    call list_files                             ; Get file list
    jmp int_ret                                 ; We're done!

.rename:
    call data_binseg                            ; We want to access data from the command

    call conv_x3_83                             ; Convert filename to proper format
    jc int_ret.preserve_flags                   ; If error, we're done

    call rename                                 ; Rename

    jmp int_ret.preserve_flags                  ; We're done!

.delete:
    call delete                                 ; Delete
    jmp int_ret.preserve_flags                  ; We're done!

.hide_reveal:
    popf                                        ; Restore flags
    call hide_reveal                            ; Hide/reveal file
    jmp int_ret.preserve_flags_flags_used       ; We're done!

.rollback:
    call prompt_rollback                        ; Rollback filesystem
    jmp int_ret.preserve_flags                  ; We're done!

.apply:
    call prompt_apply                           ; Apply filesystem changes
    jmp int_ret.preserve_flags                  ; We're done!


logical_routines:                               ; Logical functions

.conv_word_hex:
    call extra_binseg                           ; We want to give data to the command

    xchg ax, dx                                 ; Function takes arg in AX, we have it in DX
    call conv_word_hex                          ; Do the conversion
    xchg dx, ax                                 ; Put everything back the way it was

    jmp int_ret                                 ; We're done!

.conv_word_dec_usigned:
    call extra_binseg                           ; We want to give data to the command

    xchg ax, dx                                 ; Function takes arg in AX, we have it in DX
    call conv_word_dec_unsigned                 ; Do the conversion
    xchg dx, ax                                 ; Put everything back the way it was

    jmp int_ret                                 ; We're done!

.conv_hex_word:
    call data_binseg                            ; We want to access data from command
    call conv_hex_word                          ; Convert to binary value
    jmp int_ret.preserve_flags                  ; We're done!

.conv_dec_word:
    call data_binseg                            ; We want to access data from command
    call conv_dec_unsigned_word                 ; Convert to binary value
    jmp int_ret.preserve_flags                  ; We're done!

.conv_byte_hex:
    call extra_binseg                           ; We want to give data to the command

    xchg al, dl                                 ; Function takes arg in AL, we have it in DL
    call conv_byte_hex                          ; Do the conversion
    xchg dl, al                                 ; Put everything back the way it was

    jmp int_ret                                 ; We're done!

.conv_byte_dec_usigned:
    call extra_binseg                           ; We want to give data to the command

    xchg al, dl                                 ; Function takes arg in AL, we have it in DL
    call conv_byte_dec_unsigned                 ; Do the conversion
    xchg dl, al                                 ; Put everything back the way it was

    jmp int_ret                                 ; We're done!

.conv_hex_byte:
    call data_binseg                            ; We want to access data from the command
    call conv_hex_byte                          ; Convert to binary value
    jmp int_ret.preserve_flags                  ; We're done!

.conv_dec_byte:
    call data_binseg                            ; We want to access data from the command
    call conv_dec_unsigned_byte                 ; Convert to binary value
    jmp int_ret.preserve_flags                  ; We're done!


int_ret:                                        ; Return back to command
    popf                                        ; Restore flags

.flags_used:
    call segments_binary                        ; Set segments to the binary segment

.ret:
    iret                                        ; Interrupt return

.preserve_flags_flags_used:
    pushf                                       ; Push something to the stack

.preserve_flags:
    pushf                                       ; Create a new FLAGS image
    pop word [flags_image]                      ; Place into memory

    mov word [register_bckp_a], ax
    mov word [register_bckp_b], bx              ; Save register states to backup

    add sp, 0x0002                              ; Move stack pointer past the FLAGS image we make

    pop ax                                      ; Pop instruction pointer
    pop bx                                      ; Pop code segment

    add sp, 0x0002                              ; Move stack pointer past the FLAGS image from INT
    push word [flags_image]                     ; Overwrite with our current flags image

    push bx                                     ; Push code segment
    push ax                                     ; Push instruction pointer

    mov ax, word [register_bckp_a]
    mov bx, word [register_bckp_b]              ; Restore register states

    jmp int_ret.flags_used                      ; Perform interrupt return as normal


times 0x2C00 - ($-$$)   db 0xFF                 ; Pad up to the nearest multiple of 256 (to make debugging easier)


; ========================================================================
; DATA SECTION
; ========================================================================

buffers:

input_buffer        dq 0x0000000000000000       ; 0x00022C00
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000

params              dq 0x0000000000000000       ; 0x00022C40
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000

misc_buffer         dq 0x0000000000000000       ; 0x00022C80
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000

param_flags         dq 0x0000000000000000       ; 0x00022CC0
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dd 0x00000000

end_buffers:

; Storage data region
register_bckp_a     dw 0x0000
register_bckp_b     dw 0x0000
segment_bckp_a      dw 0x0000
segment_bckp_b      dw 0x0000
flags_image         dw 0x0000

num_buffer          dd 0x00000000
                    dw 0x0000

date_buffer         db "YYYY-MM-DD"
time_buffer         db "HH:MM:SS"

redir_fname         db "XXXXXXXX.XXX", 0x00, 0x00
redir_enabled       db 0x00

init_byte           db 0x00                     ; Have we been initialized?
break_byte          db 0x00                     ; Are we supposed to interrupt the program?
header_offset       db 0x00                     ; Which part of the header are we looking at?

config_iface        db 0b00000000               ; Temporary interface configuration
config_sys_iface    db 0b00000010               ; Default interface configuration
default_dev         db 0x01                     ; Default device to send output to (0 = NUL, 1 = TTY, 2 = MEM)

null                db 0x00

; Header strings
creator             db "House-DOS Developers", 0x00
desc                db "The kernel. Use to modify kernel configurations.", 0x00
usage               db "SYS", 0x0A
                    db "Flags:", 0x0A
                    db "E - Don't display errors", 0x0A
                    db "C - Display commentary", 0x0A
                    db "H - Show hidden files", 0x00

; Information strings
info_os             db "House-DOS v0.1.1 NATE, Build 45; Compiled 2021-01-18", 0x00
info_creator        db "By Jacob, Jet, and Ben", 0x00
info_cpu            dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000
                    dq 0x0000000000000000

; Interface strings
iface_command_bad   db "Bad command.", 0x00
iface_shutdown      db "Shutting down...", 0x00
iface_reboot        db "Rebooting...", 0x00
iface_cancelled     db "Cancelled.", 0x00
iface_perror        db "PROGRAM EXITED WITH ERROR: ", 0x00

iface_iface_config  db "Interface configuration updated.", 0x00

iface_ays           db "Are you sure?", 0x00
iface_error_param   db "ERROR: Parameter not given.", 0x00
iface_error_idk     db "FATAL: Something went wrong.", 0x00
iface_fatal_reboot  db "A fatal error was encountered. Press any key to reboot...", 0x00
