; ========================================================================
; House-DOS KERNEL: DISK SUBSYSTEM
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; DISK ROUTINES
; ========================================================================

; VERIFY FILE: Verifies that a file with a given filename exists
; IN: [filename] = 8.3 filename
; OUT: CF = Set if no such file, [root_entry] = Number of the file's root entry

verify:                                         ; Verify that a file exists
    pusha                                       ; Save register states to stack

    call data_kernseg                           ; We're going to use kernel variables

.search_init:
    mov si, iface_disk_search
    call comment                                ; Comment message

    mov ax, 0x3800
    mov es, ax                                  ; Segment the root directory is loaded in
    mov di, 0x0000                              ; Start looking at offset 0

    mov cx, word [root_entries]                 ; Number of entries to look through

.check_entry:
    cmp byte [es:di], 0x00                      ; Is this a null character?
    je .not_found                               ; If so, there are no more entries

    push cx                                     ; Otherwise, save the number of remaining entries

    mov cx, 0x000B                              ; Otherwise, compare the first 11 bytes
    mov si, filename                            ; Compare against the filename requested
    push di                                     ; Preserve our location
    cld                                         ; Ensure correct direction

    repe cmpsb                                  ; Compare data

    pop di                                      ; Restore our location
    pop cx                                      ; Restore the remaining entries

    je .found_entry                             ; If equal, we found the entry

    add di, 0x0020                              ; Otherwise, advance to the next entry
    loop .check_entry                           ; And repeat

    jmp .not_found                              ; If we've gone through everything, there is no file

.found_entry:
    shr di, 0x5                                 ; Divide by 32 to get the root entry number
    mov word [root_entry], di                   ; Save this in our spot in memory

    mov si, iface_disk_found
    call comment_line                           ; Comment message

    clc                                         ; No error

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.not_found:
    mov si, iface_disk_nf
    call comment_line                           ; Comment message

    stc                                         ; Carry flag for error
    jmp .done                                   ; We're done


; GET FILE INFO: Retrieves value from the directory entry of a certain file
; IN: AL = Offset from start of entry, [root_entry] = Root entry number of the file (run verify to set this up)
; OUT: AL/AX/DX:AX = Return value (size is automatically detected from offset)

get_file_info:                                  ; Get an item (AL=offset) from a file's root directory entry
    pusha                                       ; Save register states to stack

    mov si, word [root_entry]                   ; Read from the root entry of the file we've verified
    shl si, 0x5                                 ; There are 32 bytes per entry
    mov bx, 0x3800
    mov ds, bx                                  ; The segment to root directory is loaded in

    mov ah, 0x00                                ; Clear upper byte of offset

.size:
    cmp al, 0x0E                                ; Items below this offset are byte-sized
    jb .byte

    cmp al, 0x1C                                ; Items between here and there are word-sized
    jb .word

    mov ax, word [si+0x1C]
    mov dx, word [si+0x1E]                      ; Otherwise, return the file size in DX:AX
    jmp .done                                   ; We're finished

.byte:
    add si, ax                                  ; Add our offset
    mov al, byte [si]                           ; Return the byte in AL
    jmp .done                                   ; We're finished

.word:
    add si, ax                                  ; Add our offset
    mov ax, word [si]                           ; Return the word in AX

.done:
    call data_kernseg                           ; We're about to use kernel variables
    mov word [register_bckp_a], ax              ; Preserve our return value
    mov word [register_bckp_b], dx              ; And the upper half if applicable

    popa                                        ; Restore register states

    mov ax, word [register_bckp_a]
    mov dx, word [register_bckp_b]              ; Restore our return value

    ret                                         ; Return to caller


; LOAD FILE FROM CLUSTER NUMBER: Loads file starting from the cluster number given in memory into the file buffer
; IN: [cluster] = Starting cluster number, [bytes_to_load] = File size (run get_file_cluster to set these up), [file_buffer_pointer] = Offset to load to
; OUT: CF = Set on error

load_file:                                      ; Load file starting at cluster into buffer
    pusha                                       ; Push register states to stack

    call data_kernseg                           ; Segment in which we are loaded

.load_cluster:
    mov si, iface_disk_cluster
    call comment                                ; Comment message

    mov ax, word [cluster]                      ; Our cluster number
    sub ax, 0x0002                              ; Clusters begin at 2
    mul byte [sectors_cluster]                  ; Multiply to get sector number
    add ax, word [root_start]                   ; Add start of root directory
    add ax, 0x0020                              ; Root directory is 32 sectors
    call conv_ls_chs                            ; Convert to CHS

    mov ax, 0x3C00
    mov es, ax                                  ; Load file into this segment
    mov bx, 0x0000                              ; At this offset

    mov ah, 0x02                                ; Read disk sectors
    mov al, byte [sectors_cluster]              ; 1 cluster

    call disk_op                                ; Perform disk operation
    jc .end                                     ; If error, we're done

.bytes:
    mov cx, word [bytes_to_load]                ; The number of bytes left in the file to copy over
    cmp cx, word [bytes_cluster]                ; Is this at least one full cluster?
    jb .copy                                    ; If not, proceed

    mov cx, word [bytes_cluster]                ; If it is, only copy the one cluster we just read from

.copy:
    call extra_fileseg                          ; Copy into the file buffer
    mov di, word [file_buffer_pointer]          ; At our pointer

    mov ax, 0x3C00
    mov ds, ax                                  ; The segment where we just loaded the cluster
    mov si, 0x0000                              ; At this offset

    cld                                         ; Ensure correct direction
    push cx                                     ; Preserve our counter

    rep movsb                                   ; Copy into our place in the file buffer

    pop cx                                      ; Restore our counter
    call data_kernseg                           ; We need to access kernel variables

    mov word [file_buffer_pointer], di          ; Update our buffer pointer
    sub word [bytes_to_load], cx                ; Update the number of bytes to copy
    jz .done                                    ; If no more bytes, we're done

.next_cluster:
    mov si, word [cluster]                      ; Our cluster number
    shl si, 0x1                                 ; There are two bytes per entry in FAT16

    mov ax, 0x3000
    mov es, ax                                  ; Segment where the FAT is loaded

    mov ax, word [es:si]                        ; This is pointing to the FAT entry

    cmp ax, 0xFFF8                              ; Is this the end of the file?
    jae .error_fat                              ; If so, error

    cmp ax, 0xFFF7                              ; Is there a bad sector?
    je .error_bsec                              ; If so, error

    cmp ax, 0x0002                              ; Is this an invalid cluster number?
    jbe .error_fat                              ; If so, error

    cmp ax, word [cluster]                      ; Is this the cluster we just loaded?
    je .error_fat                               ; If so, error

    mov word [cluster], ax                      ; If no error, that entry is our next cluster

    jc .error_size                              ; If buffer overflow, error
    jmp .load_cluster                           ; Otherwise, load next cluster

.done:
    call update_access_date                     ; Update access date

    call done_el                                ; We've finished! Worthy of a break
    clc                                         ; No error

.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.error_size:
    mov ax, 0x0303                              ; File too large
    call error                                  ; Handle this error

    jmp .end                                    ; We're done

.error_fat:
    mov ax, 0x0305                              ; Inconsistent FAT
    call error                                  ; Handle this error

    jmp .end                                    ; We're done

.error_bsec:
    mov ax, 0x0304                              ; Cluster marked bad
    call error                                  ; Handle this error

    jmp .end                                    ; We're done


; WRITE FILE TO DISK: Writes contents of file buffer to a file on the disk and applies any filesystem changes
; IN: [filename] = Valid filename (run conv_x3_83 to set this up)
; OUT: CF = Set on error

write_file:                                     ; Write file buffer to disk as file
    pusha                                       ; Push register states to stack
    push cx                                     ; Save our file size

    call data_kernseg                           ; The segment we are loaded at

    mov word [file_buffer_pointer], 0x0000      ; Start reading from offset 0

.pre_apply:
    mov si, iface_disk_applyw
    call comment_line                           ; Comment message

    call prompt_apply                           ; Apply filesystem changes before writing file
    jc .abort                                   ; If not authorized, abort

.check_existence:
    call verify                                 ; Check if file with this name exists
    jc .create_new                              ; If it doesn't, create a new entry

    call get_file_cluster                       ; Otherwise, get starting cluster if it does
    jmp .file_exists                            ; We need to ask for confirmation

.create_new:
    call next_available_cluster                 ; Get the next available cluster
    jc .abort                                   ; If error, we're done

    mov si, iface_disk_search
    call comment                                ; Comment message

    mov ax, 0x3800
    mov es, ax                                  ; The segment in which the root directory is loaded

    mov di, 0x0000                              ; Start looking at offset 0
    mov cx, word [root_entries]                 ; Look through all the possible root entries

.check_root_entry_unused:
    cmp byte [es:di], 0x00                      ; Is this entry unused?
    je .new_file_entry                          ; If so, set this entry up for our new file.

    add di, 0x0020                              ; Otherwise, move to the next 32-byte entry
    loop .check_root_entry_unused               ; And repeat

    mov di, 0x0000                              ; If we didn't find anything, start looking at offset 0
    mov cx, word [root_entries]                 ; Look through all the possible root entries

.check_root_entry_empty:
    cmp byte [es:di], 0xE5                      ; Is this entry empty?
    je .new_file_entry                          ; If so, set this entry up for our new file.

    add di, 0x0020                              ; Otherwise, move to the next 32-byte entry
    loop .check_root_entry_empty                ; And repeat

    jmp .error_root                             ; If no entries are available, sorry!

.new_file_entry:
    mov si, iface_disk_empty
    call comment_line                           ; Comment message

    mov cx, 0x000B                              ; Copy 11 bytes
    mov si, filename                            ; Our filename
    push di                                     ; Save our location

    rep movsb                                   ; Move the filename into the root entry

    pop di                                      ; Restore our location
    mov ax, word [cluster]
    mov word [es:di+0x1A], ax                   ; Move our starting cluster into the correct field

    pop cx                                      ; Restore our file size
    mov word [es:di+0x1C], cx                   ; Move our file size into the correct field

    push es                                     ; Save our segment

    call get_time                               ; Get RTC time
    call conv_rtctime_fat                       ; Convert to FAT time format

    pop es                                      ; Restore our segment
    mov word [es:di+0x0E], ax                   ; Move the creation time into the correct field
    mov word [es:di+0x16], ax                   ; Move this also into the write time field

    push es                                     ; Preserve segment

    call get_date                               ; Get RTC date
    call conv_rtcdate_fat                       ; Convert to FAT time format

    pop es                                      ; Restore segment
    mov word [es:di+0x10], ax                   ; Move the creation date into the correct field
    mov word [es:di+0x12], ax                   ; Move this also into the access date field
    mov word [es:di+0x18], ax                   ; As well as the write date field

    jmp .write_cluster                          ; Start writing data

.file_exists:
    mov si, iface_disk_exists
    call msg_warn                               ; Warning message/confirmation
    jc .abort                                   ; If not given, we're done

    call check_attributes                       ; Check if we can write to this file
    jc .abort                                   ; If we can't, we're done

.change_file_size:
    mov ax, 0x3800
    mov es, ax                                  ; The segment the root directory is loaded in

    mov di, word [root_entry]                   ; The number of the root entry
    shl di, 0x5                                 ; There are 32 bytes in each entry

    pop cx                                      ; Restore our file size
    mov word [es:di+0x1C], cx                   ; Move our file size into the correct field
    mov word [es:di+0x1E], 0x0000               ; Upper word of file size is 0

.modify_time_date:
    push es                                     ; Preserve segment

    call get_time                               ; Get RTC time
    call conv_rtctime_fat                       ; Convert to FAT time format

    pop es                                      ; Restore segment
    mov word [es:di+0x16], ax                   ; Move the write time into the correct field

    push es                                     ; Preserve segment

    call get_date                               ; Get RTC date
    call conv_rtcdate_fat                       ; Convert to FAT time format

    pop es                                      ; Restore segment
    mov word [es:di+0x18], ax                   ; Move the write date into the correct field

.write_cluster:
    mov si, iface_disk_write
    call comment                                ; Comment message

    mov ax, word [cluster]                      ; Our cluster number
    sub ax, 0x0002                              ; Clusters begin at 2
    mul byte [sectors_cluster]                  ; Multiply to get sector number
    add ax, word [root_start]                   ; Add start of root directory
    add ax, 0x0020                              ; Root directory is 32 sectors
    call conv_ls_chs                            ; Convert to CHS

    mov ax, 0x1000
    mov es, ax                                  ; File buffer is in this segment
    mov bx, word [file_buffer_pointer]          ; Read at this offset

    mov ah, 0x03                                ; Write disk sectors
    mov al, byte [sectors_cluster]              ; 1 cluster

    call disk_op                                ; Perform disk operation
    jc .end                                     ; If error, we're done

.next_cluster:
    mov ax, word [bytes_sector]
    mul word [sectors_cluster]
    add word [file_buffer_pointer], ax          ; Advance pointer by one cluster

    mov ax, 0x3000
    mov es, ax                                  ; The segment in which the FAT is loaded

    mov di, word [cluster]                      ; The cluster we just wrote to
    shl di, 0x1                                 ; There are 2 bytes per entry in FAT16
    mov bx, word [es:di]                        ; The FAT entry for this cluster

    cmp word [file_buffer_pointer], cx          ; Have we finished writing the entire file?
    jae .end_file                               ; If so, we need to do a few things

    cmp bx, 0x0000                              ; Was this cluster previously free?
    je .change_fat_entry                        ; If so, we need to set it to the next available cluster

    cmp bx, 0xFFF7                              ; Was this cluster previously EOF or bad sector?
    jae .change_fat_entry                       ; If so, we need to set it to the next available cluster

    mov word [cluster], bx                      ; Otherwise, it is our next cluster to write to

    jmp .write_cluster                          ; Load next cluster

.change_fat_entry:
    call next_available_cluster                 ; Get the next cluster available
    jc .abort                                   ; If error, we're done

    mov bx, word [cluster]
    mov word [es:di], bx                        ; Move this cluster number into our FAT entry

    jmp .write_cluster                          ; We are ready to write the next cluster

.end_file:
    call done                                   ; Done message

    mov word [es:di], 0xFFFF                    ; Place an end-of-file marker into this entry
    mov di, bx                                  ; Move the previous value into DI

.free_entry:
    cmp di, 0x0000                              ; Was this cluster previously free?
    je .apply                                   ; If so, we're done changing the FAT

    shl di, 0x1                                 ; Otherwise, it is a new cluster number
    mov bx, word [es:di]                        ; The FAT entry for that new cluster

    mov word [es:di], 0x0000                    ; Mark that new cluster as free
    mov di, bx                                  ; Work with the previous value next

    jmp .free_entry                             ; Repeat

.apply:
    call apply                                  ; Apply FAT and root changes to disk
    jc .end                                     ; If error, we're done

.done:
    mov si, iface_disk_saved
    call msg_info                               ; Info message

    clc                                         ; No error

.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.error_root:
    mov ax, 0x0307                              ; No entries available
    call error                                  ; Handle this error

    jmp .end                                    ; We're done

.error_attribute:
    mov ax, 0x0300                              ; File Read-Only
    call error                                  ; Handle this error

    jmp .end                                    ; We're done

.abort:
    call abort                                  ; Aborting message

    pop ax                                      ; Restore for balance
    stc                                         ; Carry flag for error
    jmp .end                                    ; We're done


; APPLY FILESYSTEM CHANGES: Writes the current contents of the FAT and the root directory to the disk
; IN: None
; OUT: CF = Set on error

apply:                                          ; Apply filesystem changes to disk
    pusha                                       ; Push register states to stack

    mov si, iface_disk_apply
    call comment_line                           ; Comment message

    mov si, iface_disk_wfats
    call comment                                ; Comment message

    mov cx, word [fats]                         ; Number of FATs to write to

.write_fat:
    push cx                                     ; Save our counter

    mov ax, 0x3000
    mov es, ax                                  ; Write from this segment
    mov bx, 0x0000                              ; Starting at offset 0

    mov ax, word [sectors_fat]                  ; Sectors per FAT
    mul cx                                      ; Number of sectors between this FAT and root directory
    mov cx, ax                                  ; Store this number in here for now

    mov ax, word [root_start]                   ; Start of the root directory
    sub ax, cx                                  ; Subtract this number
    call conv_ls_chs                            ; Convert to CHS Address

    mov ax, word [sectors_fat]                  ; An entire FAT
    mov ah, 0x03                                ; Write disk sectors

    call disk_op                                ; Perform disk operation
    jc .end                                     ; If error, we're done

.next_fat:
    pop cx                                      ; Restore our counter
    loop .write_fat                             ; Repeat

.write_root:
    call done                                   ; Done message

    mov si, iface_disk_wroot
    call comment                                ; Comment message

    mov ax, 0x3800
    mov es, ax                                  ; The segment in which the root directory is loaded

    mov ax, word [root_start]                   ; Start of the root directory
    call conv_ls_chs                            ; Convert to CHS Address

    mov ah, 0x03                                ; Write disk sectors
    mov al, 0x20                                ; Root directory is 32 sectors

    call disk_op                                ; Perform disk operation
    jc .end                                     ; If error, we're done

.done:
    mov word [renames], 0x0000                  ; Reset the renames counter
    mov word [deletions], 0x0000                ; Reset the deletions counter
    mov word [vis_changes], 0x0000              ; Reset the visibility changes counter

    call done_el                                ; Done message, newline

    mov si, iface_disk_applied
    call msg_info                               ; Info message

    clc                                         ; No error

.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ROLLBACK FILESYSTEM: Reloads the FAT and root directory into memory
; IN: None
; OUT: CF = Set on error

rollback:                                       ; Rollback filesystem
    pusha                                       ; Save register states to stack

    call data_kernseg                           ; Get data from the segment we're loaded in

    mov si, iface_disk_rback
    call comment_line                           ; Comment message

.load_fat:
    mov ax, 0x3000
    mov es, ax                                  ; Load FAT into this segment
    mov bx, 0x0000                              ; Starting at offset 0

    mov ax, word [reserved]                     ; First sector of FAT 1
    call conv_ls_chs                            ; Convert to CHS address

    mov ah, 0x02                                ; Read disk sectors
    mov al, byte [sectors_fat]                  ; Read the entire FAT

    call disk_op                                ; Perform disk operation
    jc .end                                     ; If error, we're done

.load_root:
    mov ax, 0x3800
    mov es, ax                                  ; Load root directory into this segment

    mov ax, word [root_start]                   ; First sector of root directory
    call conv_ls_chs                            ; Convert to CHS address

    mov ah, 0x02                                ; Read disk sectors
    mov al, 0x20                                ; Root directory is 32 sectors

    call disk_op                                ; Perform disk operation
    jc .end                                     ; If error, we're done

.done:
    mov word [renames], 0x0000                  ; Reset the renames counter
    mov word [deletions], 0x0000                ; Reset the deletions counter
    mov word [vis_changes], 0x0000              ; Reset the visibility changes counter

    mov si, iface_disk_rdback
    call msg_info                               ; Info message

    clc                                         ; No error

.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.error_read:
    call disk_error                             ; Handle this error
    jmp .end                                    ; We're done


; GET FILE LIST: Gets a list of filenames separated by commas
; IN: ES:DI = Output buffer (big enough)
; OUT: None

list_files:                                     ; Retrieve a list of all filenames
    pusha                                       ; Save register states to stack

    call data_kernseg                           ; Use a kernel variable

    mov bl, byte [config_iface]                 ; The interface configuration byte
    and bl, 0b00000100                          ; Mask out everything but the hidden files flag
    xor bl, 0b00000100                          ; Invert the hidden files flag
    shr bl, 0x1                                 ; Shift into the position of the visibility flag

    mov si, 0x0000                              ; Start reading directory at offset zero
    mov cx, 0x0200                              ; 512 entries in the root directory

.entry:
    mov ax, 0x3800
    mov ds, ax                                  ; Segment our root directory is loaded in

    cmp byte [si], 0x00                         ; Is this a null character?
    je .done                                    ; If so, there are no more files

    cmp byte [si], 0xE5                         ; Is this the deleted character?
    je .next_entry                              ; If so, skip this one

    test byte [si+0x0B], bl                     ; Test the visibility flag with the configuration
    jnz .next_entry                             ; If hidden & don't show hidden files, skip this one

.fname:
    push si                                     ; Preserve our pointer
    push es
    push di                                     ; Save our output buffer
    push cx                                     ; Preserve our counter

    call extra_kernseg                          ; For now, we want to write to a kernel variable
    mov di, filename                            ; Our space in memory for 8.3 filenames
    mov cx, 0x000B                              ; 11 chars in an 8.3 filename

    rep movsb                                   ; Copy our filename here

    pop cx                                      ; Restore our counter
    pop di
    pop es                                      ; Restore our output buffer
    pop si                                      ; Restore our pointer

    call conv_83_x3                             ; Convert to an X.3 filename and write to the output buffer

    mov al, 0x2C                                ; Comma
    stosb                                       ; Write to output buffer

.next_entry:
    add si, 0x0020                              ; Advance to the next directory entry
    loop .entry                                 ; Repeat

.done:
    dec di                                      ; Write over that last comma
    mov al, 0x00                                ; Null character
    stosb                                       ; Write to output buffer

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; RENAME FILE: Renames a specific file
; IN: [filename] = Filename to rename to; [root_entry] = Root entry of file to rename (verify to set this up)
; OUT: CF = Set on error

rename:                                         ; Rename a file
    pusha                                       ; Save register states to stack

    call data_kernseg                           ; Use kernel variables
    push word [root_entry]                      ; Save our root entry

    call check_attributes                       ; Check if we can change this file
    jc .abort                                   ; If we can't, abort

.check_dest_exists:
    call verify                                 ; Check if a file with this name already exists
    jnc .error_exists                           ; If so, error

.modify_name:
    mov si, filename                            ; Our filename

    mov ax, 0x3800
    mov es, ax                                  ; The segment our root directory is loaded in

    pop di                                      ; Restore the root entry
    mov word [root_entry], di                   ; Make sure the verified file doesn't change

    shl di, 0x5                                 ; 32 bytes per entry
    mov cx, 0x000B                              ; Write 11 bytes
    cld                                         ; Ensure correct direction
    
    rep movsb                                   ; Write

.done:
    inc word [renames]                          ; Increment our changes counter

    mov si, iface_disk_renamed
    call msg_info                               ; Info message

    clc                                         ; No error

.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.error_exists:
    mov ax, 0x0302                              ; File exists
    call error                                  ; Handle this error

    pop ax                                      ; Restore for balance
    jmp .end                                    ; We're done

.abort:
    call abort                                  ; Aborting message

    pop ax                                      ; Restore for balance
    stc                                         ; Carry flag for error
    jmp .end                                    ; We're done


; DELETE FILE: Deletes a specific file (Overwrites first char of directory entry with 0xE5)
; IN: [root_entry] = Root entry of file to delete (verify to set up)
; OUT: CF = Set on error

delete:                                         ; Delete a file
    pusha                                       ; Push register states to stack

    call check_attributes                       ; Check if we can change this file
    jc .abort                                   ; If we can't, abort

    mov ax, 0x3800
    mov es, ax                                  ; The segment our root directory is loaded in

    call data_kernseg                           ; Use kernel variables
    mov di, word [root_entry]                   ; The directory entry for the file
    shl di, 0x5                                 ; 32 bytes per entry

    mov al, 0xE5                                ; "Deleted" character
    stosb                                       ; Write

.done:
    inc word [deletions]                        ; Increment our changes counter

    mov si, iface_disk_deleted
    call msg_info                               ; Info message

    clc                                         ; No error

.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.abort:
    call abort                                  ; Aborting message

    stc                                         ; Carry flag for error
    jmp .end                                    ; We're done


; HIDE/REVEAL FILE: Sets/unsets the hidden flag in the attribute byte of a specific file
; IN: [root_entry] = Root entry of file to hide/reveal (verify to set up), CF = Set to reveal, cleared to hide
; OUT: CF = Set on error

hide_reveal:                                    ; Hide/reveal a file
    pusha                                       ; Push register states to stack
    pushf                                       ; Preserve flags

    call check_attributes                       ; Check if we can change this file
    jc .abort                                   ; If we can't abort

    call data_kernseg                           ; Use kernel variables
    mov si, word [root_entry]                   ; The directory entry for the file
    shl si, 0x5                                 ; 32 bytes per entry

    mov ax, 0x3800
    mov es, ax                                  ; The segment our root directory is loaded in

    mov al, byte [es:si+0x000B]                 ; Get the attribute byte

    popf                                        ; Restore flags
    jc .reveal                                  ; If carry flag, reveal

.hide:
    or al, 0b00000010                           ; Set the hidden flag
    jmp .done                                   ; Proceed

.reveal:
    and al, 0b11111101                          ; Clear the hidden flag

.done:
    mov byte [es:si+0x000B], al                 ; Write the new attribute byte in
    inc word [vis_changes]                      ; Increment our counter

    mov si, iface_disk_vchanged
    call msg_info                               ; INFO message

    clc                                         ; No error

.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.abort:
    call abort                                  ; Aborting message

    stc                                         ; Carry-flag for error
    jmp .end                                    ; We're done


; VERIFY FILE FROM PARAMETER: Verifies file with the name given in a certain parameter
; IN: CX = Parameter number
; OUT: CF = Set on error; [root_entry] = Number of the file's directory entry

verify_file_param:                              ; Verify file from parameter
    pusha                                       ; Save register states to stack

    call clear_misc_buffer                      ; Clear the miscellaneous buffer

    mov di, misc_buffer                         ; Our buffer
    call get_parameter                          ; Get parameter from command

    mov si, misc_buffer                         ; Our buffer
    call conv_x3_83                             ; Convert to 8.3 filename and store properly
    jc .done                                    ; If failed, we're done

    call verify_error_nf                        ; Verify file/produce error

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ========================================================================
; SUBROUTINES
; ========================================================================

; DISK OPERATION: Uses the BIOS disk interrupt and handles any errors/resets
; IN: BIOS INT 13 parameters (AH = function, AL = sectors, CX:DX = CHS address & drive num, ES:BX = buffer)
; OUT: CF = Set on error, errors handled

disk_op:                                        ; Perform a disk operation using the BIOS
    pusha                                       ; Save register states to stack

    push ax                                     ; Save parameters in case of error
    int 0x13                                    ; BIOS disk interrupt
    jnc .done                                   ; If no error, we're done

    call disk_error                             ; Otherwise, handle this error
    call reset_disk                             ; And reset the disk

    pop ax                                      ; Restore parameters
    int 0x13                                    ; BIOS disk interrupt
    jnc .end                                    ; If no error, we're done

    call disk_error                             ; Otherwise, handle this error
    jmp .end                                    ; We're done

.done:
    pop ax                                      ; Get parameters out of the stack

.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; RESET DISK: Resets the disk, and reboots if failed
; IN: None
; OUT: None

reset_disk:                                     ; Reset the disk
    pusha                                       ; Push register states to stack

    mov si, iface_disk_reset
    call comment                                ; Comment message

    mov ah, 0x00                                ; Reset disk
    mov dl, byte [drive_num]

    int 0x13                                    ; BIOS disk interrupt
    jc reboot_fatal                             ; If there was an error, reboot

    popa                                        ; Otherwise, restore register states
    ret                                         ; Return to caller


; HANDLE DISK ERROR: Handles a disk read/write error
; IN: AH = INT 0x13 status
; OUT: CF = Set

disk_error:
    pusha                                       ; Save register states to stack

    mov al, ah                                  ; Move status code into lower byte of error code
    mov ah, 0x02                                ; Upper byte of error code is for disk

    call error                                  ; Call on error handler

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; NEXT AVAILABLE CLUSTER: Searches the FAT for unused entries, grabs the first unused cluster number
; IN: None
; OUT: [cluster] = Cluster number; CF = Set on error

next_available_cluster:                         ; Get the next cluster available
    pusha                                       ; Push register states to stack

    mov ax, 0x3000
    mov es, ax                                  ; The segment in which the FAT is loaded

    mov di, 0x0004                              ; Start looking at offset 4 (entry 2)
    mov cx, 0x3FFE                              ; Look through all the FAT entries

.check_fat_entry:
    cmp word [es:di], 0x0000                    ; Is this FAT entry unused?
    je .done                                    ; If so, we've found it

    add di, 0x0002                              ; Otherwise, move to the next two-byte entry
    loop .check_fat_entry                       ; And repeat

    jmp .error_full                             ; If all clusters are full, error

.done:
    shr di, 0x1                                 ; There are two bytes per entry in FAT16
    mov word [cluster], di                      ; The number of this entry is our cluster number

    clc                                         ; No error

.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.error_full:
    mov ax, 0x0306                              ; No clusters available
    call error                                  ; Handle this error

    jmp .end                                    ; We're done


; CONVERT LOGICAL TO CHS ADDRESS: Sets up Cylinder-Head-Sector notation from logical block number
; IN: AX = Block number
; OUT: INT 13 Parameters (CX = Cylinder, Sector; DX = Head, Drive)

conv_ls_chs:                                    ; Setup Cylinder-Head-Sector from LBA (AX)
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


; CHECK ATTRIBUTES: Checks attributes of the file, asks for confirmation if system file, produces error if unable to write
; IN: [root_entry] = Root entry number of the file
; OUT: CF = Set on error

check_attributes:
    pusha                                       ; Save register states to stack

    call is_read_only                           ; Check if read-only
    jc .error_readonly                          ; If it is, error

    call is_system                              ; Check if system file
    jnc .done                                   ; If not, we're done

    mov si, iface_disk_system
    call msg_warn                               ; Otherwise, warning message/confirmation
    jc .end                                     ; If not given, we're done

.done:
    clc                                         ; Otherwise, no error

.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.error_readonly:
    mov ax, 0x0300                              ; Read-only
    call error                                  ; Handle this error

    jmp .end                                    ; We're done


; CONVERT X.3 FILENAME TO 8.3: Converts a standard X.3 filename to the 8.3 format
; IN: DS:SI = Source Buffer (X.3 filename)
; OUT: [filename] = 8.3 filename ready for use, CF = Set on error

conv_x3_83:                                     ; Convert X.3 filename in DS:SI to an 8.3 for searching
    pusha                                       ; Push register states to stack

    call extra_kernseg                          ; Write to the segment we're loaded in
    mov di, filename                            ; Place into our memory space for filenames

    mov cx, 0x0008                              ; 8 chars in the file NAME
    cld                                         ; Ensure correct direction

.name_char:
    lodsb                                       ; Load next character
    call capitalize_char                        ; Capitalize
    stosb                                       ; Store resulting character

    cmp byte [si], 0x2E                         ; Is this next character the dot?
    je .dot                                     ; If so, move on

    loop .name_char                             ; Otherwise, repeat

    jmp .error_filename                         ; If there hasn't been a dot, error

.dot:
    dec cx                                      ; Avoid an O.B.O.E
    inc si                                      ; Get ready to read the extension

    cmp cx, 0x0000                              ; Do we have any room for spaces?
    je .ext                                     ; If not, jump to copying the extension

.space:
    mov byte [es:di], 0x20                      ; Pad with a space
    inc di                                      ; Advance pointer
    loop .space                                 ; Repeat

.ext:      
    mov cx, 0x0003                              ; 3 chars in the file EXTENSION

.ext_char:
    lodsb                                       ; Load next character
    call capitalize_char                        ; Capitalize
    stosb                                       ; Store resulting character

    loop .ext_char                              ; Repeat

    cmp byte [si], 0x00                         ; Is the final byte a null character?
    jne .error_filename                         ; If not, this isn't a valid filename

    clc                                         ; If we're done, no error
    
.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.error_filename:
    mov ax, 0x0301                              ; Invalid filename
    call error                                  ; Handle this error

    jmp .end                                    ; We're done


; CONVERT 8.3 FILENAME TO X.3: Converts an 8.3 filename to the X.3 format
; IN: [filename] = Filename to convert, ES:DI = Output buffer (between 5 and 12 bytes for X.3 filename)
; OUT: DI = Initial value + number of bytes copied

conv_83_x3:                                     ; Convert the 8.3 filename to the X.3 standard format
    pusha                                       ; Save register states to stack

    call data_kernseg                           ; We want to access kernel variables
    mov si, filename                            ; Read from our 8.3 filename

    mov cx, 0x0008                              ; 8 bytes in the file NAME
    cld                                         ; Ensure correct direction

.name_char:
    lodsb                                       ; Load byte

    cmp al, 0x20                                ; Is this a space?
    loope .name_char                            ; If so, do not write this character
    je .ext                                     ; If we've done our 8 characters, make sure to continue
    inc cx                                      ; Keep our counter as it was

    stosb                                       ; Write to output buffer
    loop .name_char                             ; Repeat

.ext:
    mov al, 0x2E                                ; Dot character
    stosb                                       ; Write to output buffer

    mov cx, 0x0003                              ; 3 bytes in the extension
    rep movsb                                   ; Write to the output buffer

.done:
    mov word [register_bckp_a], di              ; Preserve our output

    popa                                        ; Restore register states
    mov di, word [register_bckp_a]              ; Restore our output

    ret                                         ; Return to caller


; GET FILE STARTING CLUSTER: Gets the starting cluster for the specified file
; IN: [root_entry] = Root entry number of the file
; OUT: [cluster] = Starting cluster of file, [bytes_to_load] = Number of bytes in the file

get_file_cluster:                               ; Get the starting cluster for a file
    pusha                                       ; Save register states to stack

    mov al, 0x1A                                ; Read the starting cluster
    call get_file_info                          ; Get from the root directory

    mov word [cluster], ax                      ; Store as cluster number

    mov al, 0x1C                                ; Read the file size
    call get_file_info                          ; Get from the root directory

    mov word [bytes_to_load], ax                ; Store as the number of bytes to copy

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; CHECK READ-ONLY FILE: Check if the file is read-only
; IN: [root_entry] = Root entry number of the file
; OUT: CF = Set if read-only

is_read_only:                                   ; Check if a file is read-only
    pusha                                       ; Save register states to stack

    mov al, 0x0B                                ; Read the attribute byte
    call get_file_info                          ; Get from the root entry

    clc                                         ; Unset for now

    test al, 0x01                               ; Bit 0 contains the read-only attribute
    jz .done                                    ; If unset, we're done

    stc                                         ; Otherwise, set the carry flag

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; CHECK HIDDEN FILE: Check if the file is hidden
; IN: [root_entry] = Root entry number of the file
; OUT: CF = Set if hidden

is_hidden:                                      ; Check if a file is hidden
    pusha                                       ; Save register states to stack

    mov al, 0x0B                                ; Read the attribute byte
    call get_file_info                          ; Get from the root entry

    clc                                         ; Unset for now

    test al, 0x02                               ; Bit 1 contains the visibility attribute
    jz .done                                    ; If unset, we're done

    stc                                         ; Otherwise, set the carry flag

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; CHECK SYSTEM FILE: Check if the file is hidden, ask the user to continue if it is
; IN: [root_entry] = Root entry number of the file
; OUT: CF = Set if system and write confirmation not granted

is_system:                                      ; Check if a file is a system file
    pusha                                       ; Save register states to stack

    mov al, 0x0B                                ; Read the attribute byte
    call get_file_info                          ; Get from the root entry

    clc                                         ; Unset for now

    test al, 0x04                               ; Bit 2 contains the system attribute
    jz .done                                    ; If unset, we're done

    stc                                         ; Otherwise, set the carry flag

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; UPDATE FILE ACCESS DATE: Sets the access date attribute of a file to the current date
; IN: [root_entry] = Root entry number of the file
; OUT: None

update_access_date:                             ; Update a file's access date field
    pusha                                       ; Save register states to stack

    push 0x3800                                 ; The segment the root directory is loaded in
    call data_kernseg                           ; We will be accessing kernel veriables

    mov di, word [root_entry]                   ; Write to the root entry of the file
    shl di, 0x5                                 ; There are 32 bytes per entry

    call get_date                               ; Get RTC date
    call conv_rtcdate_fat                       ; Convert to FAT format

    pop es                                      ; Write into the root directory
    mov word [es:di+0x12], ax                   ; Write the current date into the entry

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ========================================================================
; KERNEL-SPECIFIC ROUTINES
; ========================================================================

; VERIFY WITH ERROR: Verifies a file and produces an error if unsuccessful
; IN: [filename] = 8.3 filename
; OUT: CF = Set on error; [root_entry] = Number of file's directory entry

verify_error_nf:                                ; Verifies file, produces error if not found
    pusha                                       ; Save register states to stack

    call verify                                 ; Verify file
    jc .error_nf                                ; If failed, error

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.error_nf:
    mov ax, 0x0380                              ; File not found
    call error                                  ; Handle this error

    jmp .done                                   ; We're done


; ASK TO APPLY CHANGES: Shows filesystem changes, prompts the user to authenticate, then applies changes
; IN: None
; OUT: CF = Set if not authenticated

prompt_apply:                                   ; Prompt the user to authenticate filesystem changes
    pusha                                       ; Save register states to stack

    call setup_segments                         ; Using kernel variables

.check:
    cmp word [renames], 0x0000                  ; Do we have any renames?
    jne .numbers                                ; If so, proceed

    cmp word [deletions], 0x0000                ; Do we have any deletions?
    jne .numbers                                ; If so, proceed

    cmp word [vis_changes], 0x0000              ; Do we have any visibility changes?
    jne .numbers                                ; If so, proceed

    mov si, iface_disk_nochange
    call comment_line                           ; Otherwise, we have no changes to apply

    clc                                         ; There wasn't an error
    jmp .end                                    ; We're done

.numbers:
    mov ax, word [renames]                      ; The number of renames
    mov di, iface_disk_changesB                 ; Our spot in the message
    call conv_word_dec_unsigned                 ; Convert to decimal

    mov ax, word [deletions]                    ; The number of deletions
    mov di, iface_disk_changesD                 ; Our spot in the message
    call conv_word_dec_unsigned                 ; Convert to decimal

    mov ax, word [vis_changes]                  ; The number of visibility changes
    mov di, iface_disk_changesF                 ; Our spot in the message
    call conv_word_dec_unsigned                 ; Convert to decimal

.message:
    mov si, iface_disk_changesA                 ; Print the message, one section at a time
    call print_str

    mov si, iface_disk_changesC
    call print_str

    mov si, iface_disk_changesE
    call print_str

    mov si, iface_disk_changesG
    call print_str

.apply:
    call confirm                                ; Ask for confirmation
    jc .error_cancelled                         ; If not given, cancel

    call apply                                  ; Otherwise, apply filesystem changes

.end:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.error_cancelled:
    mov ax, 0x0001                              ; Cancelled by user
    call error                                  ; Handle this error

    jmp .end                                    ; We're done


; ASK TO ROLLBACK FILESYSTEM: Prompts the user to authenticate filesystem rollback
; IN: None
; OUT: CF = Set on error

prompt_rollback:                                ; Prompt the user to authenticate filesystem rollback
    push si                                     ; Save register state to stack

    mov si, iface_disk_rchanges
    call msg_warn                               ; Warning message/confirmation
    jc .error_cancelled                         ; If not given, cancel

    call rollback                               ; Otherwise, rollback filesystem

.end:
    pop si                                      ; Restore register state
    ret                                         ; Return to caller

.error_cancelled:
    mov ax, 0x0001                              ; Cancelled by user
    call error                                  ; Handle this error

    jmp .end                                    ; We're done


; ========================================================================
; DATA SECTION
; ========================================================================

disk_data:

filename            db "        "
filename_extension  db "   "

bin_extension       db "BIN"
hob_extension       db "HOB"

drive_num           db 0x00
cluster             dw 0x0000
root_entry          dw 0x0000
file_buffer_pointer dw 0x0000
buffer_segment      dw 0x0000
bytes_to_load       dw 0x0000

bytes_sector        dw 0x0000
sectors_cluster     db 0x00
bytes_cluster       dw 0x0000
reserved            dw 0x0000
fats                db 0x00
root_entries        dw 0x0000
sectors_fat         dw 0x0000
sectors_track       dw 0x0000
heads               dw 0x0000
root_start          dw 0x0000

renames             dw 0x0000
deletions           dw 0x0000
vis_changes         dw 0x0000

iface_disk_changesA db "This will result in "
iface_disk_changesB dd 0x00000000
                    db 0x00
iface_disk_changesC db " renames, "
iface_disk_changesD dd 0x00000000
                    db 0x00
iface_disk_changesE db " deletions, and "
iface_disk_changesF dd 0x00000000
                    db 0x00
iface_disk_changesG db " visibility changes.", 0x0A
                    db "This cannot be undone.", 0x00

iface_disk_rchanges db "This will roll back all renames, deletions, and visibility changes.", 0x00

iface_disk_apply    db "Applying changes to disk...", 0x00
iface_disk_applied  db "Changes applied to disk.", 0x00
iface_disk_rback    db "Rolling back...", 0x00
iface_disk_rdback   db "Filesystem re-loaded.", 0x00
iface_disk_saved    db "File saved.", 0x00
iface_disk_search   db "Searching root directory...", 0x00
iface_disk_found    db "Found file!", 0x00
iface_disk_empty    db "Found empty entry!", 0x00
iface_disk_exists   db "File already exists.", 0x00
iface_disk_system   db "This is a system file.", 0x00
iface_disk_applyw   db "Filesystem changes must be applied.", 0x00
iface_disk_cluster  db "Loading cluster...", 0x00
iface_disk_write    db "Writing to cluster...", 0x00
iface_disk_wfats    db "Writing FATs to disk...", 0x00
iface_disk_wroot    db "Writing root directory...", 0x00
iface_disk_reset    db "Resetting disk...", 0x00
iface_disk_cancel   db "Operation cancelled.", 0x00
iface_disk_renamed  db "File renamed. Changes to be applied.", 0x00
iface_disk_deleted  db "File deleted. Changes to be applied.", 0x00
iface_disk_vchanged db "File visibility changed. Changes to be applied.", 0x00
iface_disk_nochange db "No changes to apply.", 0x00
iface_disk_nf       db "File not found.", 0x00
