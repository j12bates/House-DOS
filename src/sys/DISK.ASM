; ========================================================================
; House-DOS KERNEL: DISK SUBSYSTEM
; 
; Written by Jacob Bates
; ========================================================================

    BITS 16

; ========================================================================
; DISK ROUTINES
; ========================================================================

; VERIFY FILE: Verifies that a file/directory with a given name exists
; IN: [filename] = 8.3 filename (or 8-byte directory name with spaces for extension); [dir_id] = Loaded Directory ID
; OUT: CF = Set if no such file; [root_entry] = File's root entry

verify:                                         ; Verify that a file exists
    pusha                                       ; Save register states to stack

    mov byte [gs:dev], 0xFF                     ; Not a device file by default

    call is_device                              ; Is this a device file?
    jnc .search_init                            ; If not, proceed

    call verify_dev                             ; Otherwise, verify device file
    jmp .done                                   ; We're done!

.search_init:
    mov si, iface_disk_search
    call comment                                ; Comment message

    push 0x3400
    pop es                                      ; Segment our directories are loaded in

    mov cl, byte [gs:dir_id]                    ; Each directory is of equal length
    and cl, 0b00000011                          ; Max ID is 3
    shl cx, 0xD                                 ; 0x2000 (8192 B) each
    mov di, cx                                  ; This is the start of our directory

    mov cx, 0x0100                              ; Number of entries to look through

.check_entry:
    cmp byte [es:di], 0x00                      ; Is this entry NULL?
    je .not_found                               ; If so, there are no more entries

    test byte [es:di+0x0B], 0b00001000          ; Is this entry the volume label?
    jnz .next_entry                             ; If so, skip

    cmp byte [filename_extension], 0x20         ; Is the extension spaces?
    jne .compare                                ; If not, proceed

    test byte [es:di+0x0B], 0b00010000          ; Otherwise, is this entry a directory?
    jz .next_entry                              ; If not, skip

.compare:
    push cx                                     ; Otherwise, save the number of remaining entries

    mov cx, 0x000B                              ; Otherwise, compare the first 11 bytes
    mov si, filename                            ; Compare against the filename requested
    push di                                     ; Preserve our location
    cld                                         ; Ensure correct direction

    repe cmpsb                                  ; Compare data

    pop di                                      ; Restore our location
    pop cx                                      ; Restore the remaining entries

    je .found_entry                             ; If equal, we found the entry

.next_entry:
    add di, 0x0020                              ; Otherwise, advance to the next entry
    loop .check_entry                           ; And repeat

    jmp .not_found                              ; If we've gone through everything, there is no file

.found_entry:
    shr di, 0x5                                 ; Divide by 32 to get the root entry number
    mov word [gs:root_entry], di                ; Save this in our spot in memory

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
; IN: AL = Offset from start of entry; [root_entry] = Root entry of the file (verify to set this up)
; OUT: AL/AX/DX:AX = Return value (size is automatically detected from offset)

get_file_info:                                  ; Get an item (AL=offset) from a file's root directory entry
    pusha                                       ; Save register states to stack

    mov si, word [gs:root_entry]                ; Read from the root entry of the file we've verified
    shl si, 0x5                                 ; There are 32 bytes per entry
    mov bx, 0x3400
    mov es, bx                                  ; The segment to root directory is loaded in

    mov ah, 0x00                                ; Clear upper byte of offset

.size:
    cmp al, 0x0E                                ; Items below this offset are byte-sized
    jb .byte

    cmp al, 0x1C                                ; Items between here and there are word-sized
    jb .word

    mov ax, word [es:si+0x1C]
    mov dx, word [es:si+0x1E]                   ; Otherwise, return the file size in DX:AX
    jmp .done                                   ; We're finished

.byte:
    add si, ax                                  ; Add our offset
    mov al, byte [es:si]                        ; Return the byte in AL
    jmp .done                                   ; We're finished

.word:
    add si, ax                                  ; Add our offset
    mov ax, word [es:si]                        ; Return the word in AX

.done:
    mov word [gs:register_bckp_a], ax           ; Preserve our return value
    mov word [gs:register_bckp_b], dx           ; And the upper half if applicable

    popa                                        ; Restore register states

    mov ax, word [gs:register_bckp_a]
    mov dx, word [gs:register_bckp_b]           ; Restore our return value

    ret                                         ; Return to caller


; LOAD FILE: Loads file/directory from directory entry into the file buffer
; IN: [root_entry] = Root entry number; [file_buffer_segment] = Segment to load to; [file_buffer_pointer] = Offset to load to; [dev] = Device ID
; OUT: [file_buffer_pointer] = Initial value + bytes copied; CF = Set on error

load_file:                                      ; Load file starting at cluster into buffer
    pusha                                       ; Push register states to stack

    call get_file_cluster                       ; Get file starting cluster and size

    cmp byte [gs:dev], 0xFF                     ; Is this a device file?
    je .load_cluster                            ; If not, proceed

    mov al, byte [gs:dev]                       ; Otherwise, our device ID
    call load_dev                               ; Load device file
    jmp .done                                   ; We're done!

.load_cluster:
    mov si, iface_disk_cluster
    call comment                                ; Comment message

    mov ax, word [gs:cluster]                   ; Our cluster number
    sub ax, 0x0002                              ; Clusters begin at 2

    mov bl, byte [gs:sectors_cluster]           ; Sectors per cluster
    mov bh, 0x00                                ; Upper byte of multiplicand is zero

    mul bx                                      ; Multiply to get sector number
    add ax, word [gs:clusters_start]            ; Add the starting sector of clusters
    call conv_ls_chs                            ; Convert to CHS

    mov ax, 0x3C00
    mov es, ax                                  ; Load file into this segment
    mov bx, 0x0000                              ; At this offset

    mov ah, 0x02                                ; Read disk sectors
    mov al, byte [gs:sectors_cluster]           ; 1 cluster

    call disk_op                                ; Perform disk operation
    jc .end                                     ; If error, we're done

.bytes:
    mov cx, word [gs:bytes_remaining]           ; The number of bytes left in the file to copy over
    cmp cx, word [gs:bytes_cluster]             ; Is this at least one full cluster?
    jb .copy                                    ; If not, proceed

    mov cx, word [gs:bytes_cluster]             ; If it is, only copy the one cluster we just read from

.copy:
    mov ax, word [gs:file_buffer_segment]       ; The segment of our file buffer
    mov es, ax                                  ; Load file here
    mov di, word [gs:file_buffer_pointer]       ; At our pointer

    mov ax, 0x3C00
    mov ds, ax                                  ; The segment where we just loaded the cluster
    mov si, 0x0000                              ; At this offset

    cld                                         ; Ensure correct direction
    push cx                                     ; Preserve our counter

    rep movsb                                   ; Copy into our place in the file buffer

    pop cx                                      ; Restore our counter
    call data_kernseg                           ; We need to access kernel variables

    mov word [gs:file_buffer_pointer], di       ; Update our buffer pointer
    sub word [gs:bytes_remaining], cx           ; Update the number of bytes to copy
    jnz .next_cluster                           ; If there's more, proceed

    call interpret_fat                          ; Retrieve and interpret the next entry from the FAT
    jnz .error_fat                              ; If not an EOF marker, error

    jmp .done                                   ; Otherwise, we're done!

.next_cluster:
    call interpret_fat                          ; Get the next entry from the FAT
    jz .end_file                                ; If end of file, check if this is fine
    jc .abort                                   ; If other error, abort operation

    jmp .load_cluster                           ; Otherwise, load next cluster

.end_file:
    mov al, 0x0B                                ; Attribute byte
    call get_file_info                          ; Get from directory entry

    test al, 0b00010000                         ; Is this a directory?
    jz .error_fat                               ; If not, error

.done:
    call update_access_date                     ; Otherwise, update access date

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

    jmp .done                                   ; We're done

.abort:
    call abort                                  ; Display abort message

    stc                                         ; Carry-flag for error
    jmp .end                                    ; We're done


; WRITE FILE TO DISK: Writes contents of file buffer to a file on the disk and applies any filesystem changes
; IN: [filename] = Valid filename; [dir_id] = Directory ID; CX = File size; [file_buffer_segment]:[file_buffer_pointer] = File buffer
; OUT: CF = Set on error

write_file:                                     ; Write file buffer to disk as file
    pusha                                       ; Push register states to stack

    call is_device                              ; Is this a device file?
    jnc .pre_apply                              ; If not, proceed

    call verify_dev                             ; Otherwise, verify device file
    jc .end                                     ; If invalid, we're done

    mov al, byte [gs:dev]                       ; Otherwise, our device ID
    call write_dev                              ; Write to device file
    clc                                         ; No error
    jmp .end                                    ; We're done!

.pre_apply:
    cmp byte [filename_extension], 0x20         ; Is this a directory?
    je .check_existence                         ; If so, skip this step

    mov word [fsize], cx                        ; Save our file size

    mov si, iface_disk_applyw
    call comment_line                           ; Comment message

    push word [file_buffer_segment]
    push word [file_buffer_pointer]             ; Preserve file buffer location
    mov cl, byte [dir_id]                       ; Preserve directory ID

    cld                                         ; Copy to backup
    call copy_fname_buffer                      ; Back up filename buffer

    call prompt_apply                           ; Apply filesystem changes before writing file

    pop word [file_buffer_pointer]
    pop word [file_buffer_segment]              ; Restore file buffer location

    jc .abort                                   ; If not authorized, abort

    mov byte [dir_id], cl                       ; Otherwise, restore directory ID

    std                                         ; Restore from backup
    call copy_fname_buffer                      ; Restore original filename

.check_existence:
    call verify                                 ; Check if file with this name exists
    jc .create_new                              ; If it doesn't, create a new entry

    call get_file_cluster                       ; Otherwise, get starting cluster if it does
    jmp .file_exists                            ; We need to ask for confirmation

.create_new:
    call next_available_cluster                 ; Get the next available cluster
    jc .abort                                   ; If error, we're done

    mov word [cluster], dx                      ; This is the first cluster to write to

    mov si, iface_disk_search
    call comment                                ; Comment message

    push 0x3400
    pop es                                      ; Segment our directories are loaded in

    mov cl, byte [dir_id]                       ; Each directory is of equal length
    and cl, 0b00000011                          ; Max ID is 3
    shl cx, 0xD                                 ; 0x2000 (8192 B) each
    mov di, cx                                  ; This is the start of our directory

    mov cx, 0x0100                              ; Number of entries to look through

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

    mov cx, word [fsize]                        ; Retrieve our file size
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
    cmp byte [filename_extension], 0x20         ; Is this a directory?
    je .change_file_size                        ; If so, proceed

    mov si, iface_disk_exists
    call msg_warn                               ; Warning message/confirmation
    jc .abort                                   ; If not given, we're done

.change_file_size:
    call check_attributes                       ; Check if we can write to this file
    jc .abort                                   ; If we can't, we're done

    push 0x3400
    pop es                                      ; The segment the directories are loaded in

    mov di, word [root_entry]                   ; The number of the root entry
    shl di, 0x5                                 ; There are 32 bytes in each entry

    mov cx, word [fsize]                        ; Retrieve our file size
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

    mov bl, byte [sectors_cluster]              ; Sectors per cluster
    mov bh, 0x00                                ; Upper byte of multiplicand is zero

    mul bx                                      ; Multiply to get sector number
    add ax, word [clusters_start]               ; Add the starting sector of clusters
    call conv_ls_chs                            ; Convert to CHS

    mov ax, word [file_buffer_segment]
    mov es, ax                                  ; File buffer is in this segment
    mov bx, word [file_buffer_pointer]          ; Read at this offset

    mov ah, 0x03                                ; Write disk sectors
    mov al, byte [sectors_cluster]              ; 1 cluster

    call disk_op                                ; Perform disk operation
    jc .end                                     ; If error, we're done

.next_cluster:
    mov ax, word [bytes_sector]                 ; Bytes per Sector
    mov bl, byte [sectors_cluster]              ; Sectors per cluster
    mov bh, 0x00                                ; Upper byte of multiplicand is zero
    mul bx                                      ; Bytes per cluster
    add word [file_buffer_pointer], ax          ; Advance pointer by one cluster

    mov cx, word [fsize]                        ; Retrieve our file size
    cmp word [file_buffer_pointer], cx          ; Have we finished writing the entire file?
    jae .end_file                               ; If so, we need to do a few things

    clc                                         ; Retrieve entry
    call fat_entry                              ; Get entry from FAT
    jc .done                                    ; If error, we're done

    cmp dx, 0x0002                              ; Is this entry free or invalid?
    jbe .change_fat_entry                       ; If so, next available cluster

    cmp dx, 0xFFF8                              ; Is this an EOF marker?
    jae .change_fat_entry                       ; if so, next available cluster

    mov word [cluster], dx                      ; Otherwise, this is the next cluster
    jmp .write_cluster                          ; Write next cluster

.change_fat_entry:
    call next_available_cluster                 ; Get the next cluster available
    jc .abort                                   ; If error, we're done

    stc                                         ; Otherwise, write entry
    call fat_entry                              ; Overwrite entry in FAT
    jc .done                                    ; If error, we're done

    jmp .write_cluster                          ; We are ready to write the next cluster

.end_file:
    call done                                   ; Done message

    clc                                         ; Retrieve entry
    call fat_entry                              ; Get entry from FAT
    jc .done                                    ; If error, we're done
    push dx                                     ; Otherwise, preserve entry

    mov dx, 0xFFFF                              ; EOF marker
    stc                                         ; Write entry
    call fat_entry                              ; Overwrite entry in FAT

.free_entry:
    pop dx                                      ; Restore entry
    jc .done                                    ; If error, we're done

    cmp dx, 0x0002                              ; Was this cluster previously free or invalid?
    jbe .apply                                  ; If so, we're done changing the FAT

    cmp dx, 0xFFF7                              ; Was this a bad sector or an EOF?
    jae .apply                                  ; If so, we're also done changing the FAT

    mov word [cluster], dx                      ; Otherwise, it is a new cluster number
    clc                                         ; Retrieve entry
    call fat_entry                              ; Get entry from FAT
    jc .done                                    ; If error, we're done
    push dx                                     ; Otherwise, preserve entry

    mov dx, 0x0000                              ; Free
    stc                                         ; Overwrite entry
    call fat_entry                              ; Mark this cluster as free

    jmp .free_entry                             ; Repeat

.apply:
    cmp byte [filename_extension], 0x20         ; Is this a directory?
    je .done                                    ; If so, skip this step (unnecessary and creates a loop)

    call apply                                  ; Apply FAT and root changes to disk
    jc .end                                     ; If error, we're done

.done:
    call setup_segments                         ; Ensure segments are set properly

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

    stc                                         ; Carry flag for error
    jmp .end                                    ; We're done


; LOAD DIRECTORY: Loads a directory from a directory entry into a directory space
; IN: [root_entry] = Directory entry number; CL = Destination directory ID; [dir_id] = Parent directory ID
; OUT: CF = Set on error

load_dir:                                       ; Load directory to position in filesystem segment
    pusha                                       ; Save register states to stack

    push 0x3400
    pop es                                      ; The segment our directories are loaded in

    and cl, 0b00000011                          ; Max ID is 3
    shl cx, 0xD                                 ; 0x2000 (8192 B) per directory
    mov di, cx                                  ; This is the start of our directory

    mov word [gs:file_buffer_segment], es       ; We will be reading into our directories
    mov word [gs:file_buffer_pointer], di       ; At this index

    mov cx, 0x2000                              ; One entire directory
    mov al, 0x00                                ; Write NULL characters
    cld                                         ; Ensure correct direction

    rep stosb                                   ; Overwrite with zeroes

    call load_file                              ; Load this directory

    mov word [gs:file_buffer_segment], 0x1000   ; Reset file buffer segment

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; WRITE DIRECTORY: Writes a directory from a directory space to disk
; IN: [filename] = 8-character directory name; CL = Source directory ID; [dir_id] = Parent directory ID
; OUT: CF = Set on error

write_dir:                                      ; Write directory from filesystem segment
    pusha                                       ; Save register states to stack

    and cl, 0b00000011                          ; Max ID is 3
    shl cx, 0xD                                 ; 0x2000 (8192 B) per directory

    mov word [gs:file_buffer_segment], 0x3400   ; We will be reading from our directories
    mov word [gs:file_buffer_pointer], cx       ; At this index

    call data_kernseg                           ; Work with kernel variables
    mov di, filename_extension                  ; Filename extension
    mov cx, 0x0003                              ; 3 characters
    mov al, 0x20                                ; Pad with spaces for directory name
    cld                                         ; Ensure correct direction

    rep stosb                                   ; Overwrite with zeroes

    mov cx, 0x2000                              ; 0x2000 per directory
    call write_file                             ; Write this directory

    mov word [gs:file_buffer_segment], 0x1000   ; Reset file buffer segment

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; APPLY FILESYSTEM CHANGES: Writes the current contents of the FAT and the root directory to the disk
; IN: None
; OUT: CF = Set on error

apply:                                          ; Apply filesystem changes to disk
    pusha                                       ; Push register states to stack

    call data_kernseg                           ; Access kernel variables

    mov si, iface_disk_apply
    call comment_line                           ; Comment message

    mov si, iface_disk_wfats
    call comment                                ; Comment message

.write_fat:
    std                                         ; Write
    call load_write_fat                         ; Write FAT from memory
    jc .end                                     ; If error, we're done

.write_root:
    call done                                   ; Done message

    call setup_segments                         ; Work with kernel data

    mov si, iface_disk_wroot
    call comment                                ; Comment message

    mov si, dir_home                            ; /HOME directory name
    mov di, filename                            ; Filename buffer
    mov cx, 0x0008                              ; 8 characters
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Copy bytes

    mov byte [dir_id], 0x02                     ; Parent directory is root
    mov cl, 0x00                                ; This is the active directory
    call write_dir                              ; Write directory to disk

    jc .end                                     ; If error, we're done

.done:
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

    call data_kernseg                           ; User kernel variables

    mov si, iface_disk_rback
    call comment_line                           ; Comment message

.load_fat:
    cld                                         ; Load
    call load_write_fat                         ; Load FAT into memory
    jc .end                                     ; If error, we're done

.load_root:
    mov ax, 0x3400
    mov es, ax                                  ; Load root directory into this segment

    mov ax, word [gs:root_start]                ; First sector of root directory
    call conv_ls_chs                            ; Convert to CHS address

    mov ah, 0x02                                ; Read disk sectors
    mov al, byte [gs:sectors_root]              ; Number of sectors in root directory

    call disk_op                                ; Perform disk operation
    jc .end                                     ; If error, we're done

.done:
    mov word [gs:renames], 0x0000               ; Reset the renames counter
    mov word [gs:deletions], 0x0000             ; Reset the deletions counter
    mov word [gs:vis_changes], 0x0000           ; Reset the visibility changes counter

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
    mov ax, 0x3400
    mov ds, ax                                  ; Segment our root directory is loaded in

    cmp byte [si], 0x00                         ; Is this a null character?
    je .done                                    ; If so, there are no more files

    cmp byte [si], 0xE5                         ; Is this the deleted character?
    je .next_entry                              ; If so, skip this one

    test byte [si+0x0B], 0b00001000             ; Is this the volume label?
    jnz .next_entry                             ; If so, skip this one

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

    mov ax, 0x3400
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

    mov ax, 0x3400
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

    mov ax, 0x3400
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


; RETRIEVE/WRITE FAT ENTRY: Reads/writes the entry in the FAT
; IN: [cluster] = Current cluster; DX = New value (if write); CF = Set to write, cleared to read
; OUT: DX = Value of entry (if read); CF = Set on error

fat_entry:                                      ; Read/write a specific entry in the FAT, realigning if needed
    pusha                                       ; Save register states to stack
    pushf                                       ; Preserve flags

.check_entry:
    mov si, word [gs:cluster]                   ; The cluster number

    cmp si, 0x0002                              ; Is it below the minimum?
    jb .invalid                                 ; If so, error

    cmp si, word [gs:cluster_max]               ; Is it above the maximum?
    ja .invalid                                 ; If so, error

    cmp word [gs:cluster_max], 0x0FF7           ; Is this FAT12?
    jb .address                                 ; If so, don't worry about FAT loading... we have it all

    mov al, byte [gs:fat_start]                 ; Starting 8K chunk
    shl ax, 0xC                                 ; 0x2000 each, but there are two bytes per entry
    sub si, ax                                  ; Subtract this offset

    cmp si, 0x2000                              ; Are we accessing an entry that isn't loaded?
    jb .ins                                     ; If not, proceed

    clc                                         ; Otherwise, auto-align
    call align_fat                              ; Perform an alignment
    jc .abort                                   ; If error, abort
    jmp .check_entry                            ; And repeat

.address:
    push 0x3000                                 ; The segment where the FAT is loaded
    pop es                                      ; Work from here

    shl si, 0x1                                 ; Two bytes per entry
    mov bx, 0x0000                              ; Empty bitmask

    cmp word [gs:cluster_max], 0x0FF7           ; Is this FAT12?
    jae .ins                                    ; If not, proceed

    mov ax, 0x0003                              ; Otherwise, 3 nibbles per entry
    mul si                                      ; Multiply by 3

    shr ax, 0x2                                 ; Remove the FAT16 remnant, and convert nibbles to bytes
    mov bx, 0xF000                              ; Mask out the final three nibbles (12 bits)

    test si, 0x0001                             ; Is this entry even?
    mov si, ax                                  ; The product is our address
    jz .ins                                     ; If so, proceed

    shl dx, 0x4                                 ; Otherwise, use left three nibbles
    mov bx, 0x000F                              ; Reflect this in our bitmask

.ins:
    popf                                        ; Restore flags
    jnc .read                                   ; If read, proceed to read the entry

    and word [es:si], bx                        ; Otherwise, clear out the bytes we're writing
    not bx                                      ; Invert mask
    and dx, bx                                  ; Clear out the bytes we're not writing

    or word [es:si], dx                         ; Overwrite this entry
    clc                                         ; No error

    jmp .done                                   ; We're done!

.read:
    mov dx, word [es:si]                        ; Read the corresponding entry in the FAT (or what we just wrote)
    not bx                                      ; Invert mask
    and dx, bx                                  ; Clear the bytes that aren't part of the entry

    cmp bx, 0xFFF0                              ; Is the entry to the left?
    clc                                         ; No error
    jne .done                                   ; If not, we're done!

    shr dx, 0x4                                 ; Otherwise, shift bits into place
    clc                                         ; No error

.done:
    mov word [register_bckp_a], dx              ; Preserve entry

    popa                                        ; Restore register states
    mov dx, word [register_bckp_a]              ; Restore entry

    ret                                         ; Return to caller

.invalid:
    mov ax, 0x0308                              ; Invalid cluster number
    call error                                  ; Handle this error

    jmp .done                                   ; We're done

.abort:
    popf                                        ; Restore for balance

    call abort                                  ; Aborting message
    stc                                         ; Carry-flag for error

    jmp .done                                   ; We're done


; INTERPRET FAT ENTRY: Retrieves the next entry from the FAT and sets flags accordingly
; IN: [cluster] = Current cluster
; OUT: [cluster] = Next cluster; ZF = Set for EOF; CF = Set on error

interpret_fat:                                  ; Interpret entry from FAT
    pusha                                       ; Save register states to stack

    clc                                         ; Retrieve entry
    call fat_entry                              ; Get next entry from FAT
    jc .done                                    ; If error, we're done

    mov ax, 0xFFF8                              ; EOF marker for FAT16

    cmp word [gs:cluster_max], 0x0FF7           ; Is this FAT12?
    jae .handle                                 ; If not, proceed

    and ax, 0x0FFF                              ; Otherwise, left nibble isn't part of entry

.handle:
    cmp dx, ax                                  ; Is this the end of the file?
    jae .end_file                               ; If so, return appropriately

    dec ax                                      ; Bad cluster marker
    cmp dx, ax                                  ; Is this marked as bad?
    je .error_bsec                              ; If so, error

    cmp dx, 0x0002                              ; Is this an invalid cluster number?
    jbe .error_fat                              ; If so, error

    cmp dx, word [gs:cluster]                   ; Is this the cluster we just loaded?
    je .error_fat                               ; If so, error

    mov word [gs:cluster], dx                   ; Otherwise, this is the next cluster

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.end_file:
    xor ax, ax                                  ; Set zero-flag
    jmp .done                                   ; We're done

.error_fat:
    mov ax, 0x0305                              ; Inconsistent FAT
    call error                                  ; Handle this error

    jmp .done                                   ; We're done

.error_bsec:
    mov ax, 0x0304                              ; Cluster marked bad
    call error                                  ; Handle this error

    jmp .done                                   ; We're done


; LOAD/WRITE FAT CHUNK: Reloads/writes either chunk of FAT based on the parameters in memory
; IN: DF = Cleared to load, set to write; [fat_start] = Starting 8K chunk
; OUT: CF = Set on error

load_write_fat:                                 ; Load a portion of the FAT into memory
    pusha                                       ; Save register states to stack

    push 0x3000
    pop es                                      ; Load FAT into this segment
    mov bx, 0x0000                              ; Starting at offset 0

    mov ax, 0x4000                              ; Bytes allocated to the FAT
    mov dx, 0x0000                              ; Upper word of dividend is zero
    div word [gs:bytes_sector]                  ; Divide to get sectors to load
    push ax                                     ; Preserve result

    shr ax, 0x1                                 ; Divide to get 8K
    mul byte [gs:fat_start]                     ; Multiply by our starting 8K chunk

    add ax, word [gs:reserved]                  ; Add to first sector of disk FAT 1
    call conv_ls_chs                            ; Convert to CHS address

    pushf                                       ; Push flags
    pop ax                                      ; Pop into AX

    test ax, 0x0400                             ; Is DF set?

    pop ax                                      ; Restore number of sectors
    mov ah, 0x02                                ; Read disk sectors

    jz .disk                                    ; If so, proceed
    mov ah, 0x03                                ; Otherwise, write disk sectors

.disk:
    call disk_op                                ; Perform disk operation

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; ALIGN FAT: Apply filesystem changes and reload the FAT to enable access to a particular entry
; IN: [cluster] = Entry to access (if auto); AL = Starting 8K chunk (if manual); CF = Set for manual, cleared for auto
; OUT: [fat_start] = New starting chunk

align_fat:                                      ; Reload the FAT to a certain position
    pusha                                       ; Save register states to stack
    pushf                                       ; Preserve flags

.apply:
    call check_changes                          ; Check for filesystem changes
    jnc .mode                                   ; If no changes, proceed

    call data_kernseg                           ; Use kernel string
    mov si, iface_disk_applya
    call println                                ; Print message

    call prompt_apply                           ; Prompt the user to apply filesystem changes
    jc .abort                                   ; If error, we're done

.mode:
    popf                                        ; Restore flags
    jc .reload                                  ; If manual, proceed

    mov ax, word [gs:cluster]                   ; Otherwise, our cluster number
    shr ax, 0xC                                 ; 4096 entries can be stored in 8K of memory
    mov byte [gs:fat_start], al                 ; This is our new starting 8K chunk

.reload:
    cld                                         ; Load
    call load_write_fat                         ; Reload FAT into memory

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.abort:
    add sp, 0x0002                              ; Balance the stack

    stc                                         ; Carry-flag for error
    jmp .done                                   ; We're done


; CHECK FILESYSTEM CHANGES: Checks for any remaining filesystem changes
; IN: [renames] = Number of renames; [deletions] = Number of deletions; [vis_changes] = Number of visibility changes
; OUT: CF = Set if there are changes

check_changes:
    pusha                                       ; Save register states to stack

    cmp word [gs:renames], 0x0000               ; Are there any renames?
    ja .changes                                 ; If so, changes

    cmp word [gs:deletions], 0x0000             ; Are there any deletions?
    ja .changes                                 ; If so, changes

    cmp word [gs:vis_changes], 0x0000           ; Are there any visibility changes?
    ja .changes                                 ; If so, changes

    clc                                         ; Otherwise, no changes

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.changes:
    stc                                         ; Carry-flag for changes
    jmp .done                                   ; We're done!


; RESET DISK: Resets the disk, and reboots if failed
; IN: None
; OUT: None

reset_disk:                                     ; Reset the disk
    pusha                                       ; Push register states to stack

    mov si, iface_disk_reset
    call comment                                ; Comment message

    mov ah, 0x00                                ; Reset disk
    mov dl, byte [gs:drive_num]

    int 0x13                                    ; BIOS disk interrupt
    jc reboot_fatal                             ; If there was an error, reboot

    popa                                        ; Otherwise, restore register states
    ret                                         ; Return to caller


; HANDLE DISK ERROR: Handles a disk read/write error
; IN: AH = INT 0x13 status
; OUT: CF = Set

disk_error:                                     ; Handle a disk error
    pusha                                       ; Save register states to stack

    mov al, ah                                  ; Move status code into lower byte of error code
    mov ah, 0x02                                ; Upper byte of error code is for disk

    call error                                  ; Call on error handler

    popa                                        ; Restore register states
    ret                                         ; Return to caller


; COPY FILENAME BUFFER: Copies the filename buffer to the backup (or vice versa)
; IN: DF = Set to restore from backup, cleared to save to backup
; OUT: None

copy_fname_buffer:                              ; Copy between primary and backup filename buffers
    pusha                                       ; Save register states to stack

    call setup_segments                         ; Work with kernel data
    mov si, filename                            ; Primary filename buffer
    mov di, filename_backup                     ; Backup filename buffer

    pushf                                       ; Push flags
    pop ax                                      ; Pop here
    test ax, 0x0400                             ; Is DF set?
    jz .copy                                    ; If not, proceed

    xchg si, di                                 ; Otherwise, swap

.copy:
    mov cx, 0x000B                              ; 11 characters in an 8.3 filename
    cld                                         ; Ensure correct direction

    rep movsb                                   ; Copy bytes

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; CHECK CHARACTER LEGALITY: Check if a character is allowed to be in a filename
; IN: AL = Character
; OUT: CF = Set if illegal

check_fname_legal:                              ; Check a character for filename legality
    pusha                                       ; Save register states to stack

    cmp al, 0x20                                ; Is the character a non-control ASCII code or a space?
    jle .illegal                                ; If so, illegal

    call extra_kernseg                          ; Compare against kernel data
    mov di, fname_illegal_chars                 ; Against our list of illegal characters
    mov cx, 0x000F                              ; Which is 15 bytes long
    cld                                         ; Ensure correct direction

    repne scasb                                 ; Compare our character against the list
    je .illegal                                 ; If it's a match, illegal character

    clc                                         ; Otherwise, perfectly legal

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.illegal:
    stc                                         ; Carry-flag
    jmp .done                                   ; We're done


; NEXT AVAILABLE CLUSTER: Searches the FAT for unused entries, grabs the first unused cluster number
; IN: [cluster] = Exception cluster
; OUT: DX = Cluster number; CF = Set on error

next_available_cluster:                         ; Get the next cluster available
    pusha                                       ; Push register states to stack

    push 0x3000
    pop es                                      ; The segment in which the FAT is loaded

    mov di, 0x0000                              ; Reset pointer
    mov cx, 0x2000                              ; Look through all the FAT entries that are loaded
    cld                                         ; Ensure correct direction

.check_entries:
    mov ax, 0x0000                              ; Marker for unused entry

    repne scasw                                 ; Scan until we find one
    je .done                                    ; If equal, we found one

    jmp .error_full                             ; Otherwise, next FAT chunk

.done:
    shr di, 0x1                                 ; Convert to a relative entry number
    dec di                                      ; The pointer was moved forward
    mov al, byte [gs:fat_start]                 ; Get starting 8K chunk of FAT
    shl ax, 0xC                                 ; 0x2000 each, but 2 bytes per entry
    add ax, di                                  ; Add relative entry number
    inc di
    shl di, 0x1                                 ; Restore index

    cmp word [gs:cluster], ax                   ; Is this the exception cluster?
    je .check_entries                           ; If so, skip

    cmp ax, 0x0002                              ; Is this an invalid cluster?
    jb .check_entries                           ; If so, skip

    cmp ax, word [gs:cluster_max]               ; Is this above the maximum cluster number?
    ja .error_full                              ; If so, we're out of entries

    clc                                         ; Otherwise, no error

.end:
    mov word [gs:register_bckp_a], ax           ; Preserve cluster number

    popa                                        ; Restore register states
    mov dx, word [gs:register_bckp_a]           ; Restore cluster number into DX

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

    call is_real                                ; Check if real file
    jc .error_real                              ; If it isn't, error

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

.error_real:
    mov ax, 0x0320                              ; Not a real file
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
    call check_fname_legal                      ; Check if it is a legal character for a filename
    jc .error_filename                          ; If illegal, error

    stosb                                       ; Otherwise, store resulting character

    cmp byte [si], 0x2E                         ; Is this next character the dot?
    je .dot                                     ; If so, move on

    loop .name_char                             ; Otherwise, repeat
    jmp .error_filename                         ; If there hasn't been a dot, error

.dot:
    dec cx                                      ; Avoid an O.B.O.E
    inc si                                      ; Extension is past this dot

    jcxz .ext                                   ; If no room for spaces, proceed to copy extension

    mov al, 0x20                                ; Pad with spaces
    cld                                         ; Ensure correct direction

    rep stosb                                   ; Write spaces

.ext:      
    mov cx, 0x0003                              ; 3 chars in the file EXTENSION

.ext_char:
    lodsb                                       ; Load next character

    call capitalize_char                        ; Capitalize
    call check_fname_legal                      ; Check if it is a legal character for a filename

    stosb                                       ; Store resulting character

    cmp byte [si], 0x00                         ; Is the next byte a NULL character?
    je .ext_end                                 ; If so, the filename is done

    loop .ext_char                              ; Otherwise, repeat
    jmp .error_filename                         ; If there hasn't been a NULL, error

.ext_end:
    dec cx                                      ; Avoid an O.B.O.E
    jcxz .done                                  ; If no room for spaces, we're done!

    mov al, 0x20                                ; Pad with spaces
    cld                                         ; Ensure correct direction

    rep stosb                                   ; Write spaces

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller

.error_filename:
    mov ax, 0x0301                              ; Invalid filename
    call error                                  ; Handle this error

    jmp .done                                   ; We're done


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
    mov al, 0x2F                                ; Forward-slash
    stosb                                       ; Write by default for a directory

    cmp byte [si], 0x20                         ; Does the extension start with a space?
    je .done                                    ; If so, we're done

    mov byte [es:di-0x01], 0x2E                 ; Otherwise, write a dot character instead

    mov cx, 0x0003                              ; 3 bytes in the extension
    rep movsb                                   ; Write to the output buffer

.done:
    mov word [register_bckp_a], di              ; Preserve our output

    popa                                        ; Restore register states
    mov di, word [register_bckp_a]              ; Restore our output

    ret                                         ; Return to caller


; GET FILE STARTING CLUSTER: Gets the starting cluster for the specified file
; IN: [root_entry] = Root entry number of the file
; OUT: [cluster] = Starting cluster of file, [bytes_remaining] = Number of bytes in the file

get_file_cluster:                               ; Get the starting cluster for a file
    pusha                                       ; Save register states to stack

    mov al, 0x1A                                ; Read the starting cluster
    call get_file_info                          ; Get from the directory entry

    mov word [gs:cluster], ax                   ; Store as cluster number

    mov al, 0x1C                                ; Read the file size
    call get_file_info                          ; Get from the directory entry

    mov word [gs:bytes_remaining], ax           ; Store as the number of bytes to copy

    mov al, 0x0B                                ; Read the attribute byte
    call get_file_info                          ; Get from the directory entry

    test al, 0b00010000                         ; Is this a directory?
    jz .done                                    ; If not, we're done!

    mov word [gs:bytes_remaining], 0x2000       ; Otherwise, load this many bytes

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; CHECK DEVICE FILE: Check if the file is a device file
; IN: [filename_extension] = 8.3 filename extension
; OUT: CF = Set if device file

is_device:                                      ; Check if a file is a device file
    pusha                                       ; Save register states to stack

    call setup_segments                         ; Ensure segments are set properly
    mov si, filename_extension                  ; Look at our filename extension
    mov di, device_extension                    ; Compare against device file extension
    mov cx, 0x0003                              ; Extension is 3 chars long
    cld                                         ; Ensure correct direction

    repe cmpsb                                  ; Compare bytes
    clc                                         ; Clear carry-flag by default
    jne .done                                   ; If there was a break, we're done

    stc                                         ; Otherwise, set the carry flag

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

    test al, 0x04                               ; Bit 2 contains the system attribute
    jz .done                                    ; If unset, we're done

    stc                                         ; Otherwise, set the carry flag

.done:
    popa                                        ; Restore register states
    ret                                         ; Return to caller


; CHECK IF FILE IS REAL: Check if the file is a real file
; IN: [root_entry] = Root entry number of the file
; OUT: CF = Set if not real

is_real:                                        ; Check if a file is really a file
    pusha                                       ; Save register states to stack

    mov al, 0x0B                                ; Read the attribute byte
    call get_file_info                          ; Get from the root entry

    test al, 0b00001000                         ; Is this entry for a volume label?
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

    push 0x3400                                 ; The segment the root directory is loaded in
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

    mov byte [dir_id], 0x00                     ; Read from active directory

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
    call check_changes                          ; Check for filesystem changes
    jc .numbers                                 ; If there are any, proceed

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

    mov word [gs:renames], 0x0000               ; Otherwise, reset the renames counter
    mov word [gs:deletions], 0x0000             ; Reset the deletions counter
    mov word [gs:vis_changes], 0x0000           ; Reset the visibility changes counter

    call apply                                  ; Apply filesystem changes

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

filename            db "BIN     "               ; Set up for /BIN directory at initialization
filename_extension  db "   "

filename_backup     db "           "            ; Backup filename buffer (for applying changes while writing a file)

device_extension    db "DEV"
dir_home            db "HOME    "               ; /HOME directory name

drive_num           db 0x00                     ; Drive number
cluster             dw 0x0000                   ; Cluster to load/write
dir_id              db 0x00                     ; Directory to verify from/write to
root_entry          dw 0x0000                   ; Directory entry number
file_buffer_pointer dw 0x0000                   ; Index to load files into
file_buffer_segment dw 0x1000                   ; Segment to load files into
fat_start           db 0x00                     ; Starting 8K area to load into FAT area (0x30000 - 0x34000)
bytes_remaining     dw 0x0000                   ; Bytes left to read
fsize               dw 0x0000                   ; File size

sectors             dd 0x00000000
cluster_max         dw 0x0000

bytes_sector        dw 0x0000
sectors_cluster     db 0x00
bytes_cluster       dw 0x0000
reserved            dw 0x0000
fats                db 0x00
root_entries        dw 0x0000
sectors_fat         dw 0x0000
sectors_track       dw 0x0000
heads               dw 0x0000
root_start          dw 0x0000                   ; Starting sector of the root directory
sectors_root        db 0x00                     ; Number of sectors in the root directory
clusters_start      dw 0x0000                   ; Starting sector of cluster data

renames             dw 0x0000
deletions           dw 0x0000
vis_changes         dw 0x0000

fname_illegal_chars db 0x22, "*+,/:;<=>?[", 0x5C, "]|"

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
iface_disk_applya   db "Parts of the filesystem must be reloaded, requiring the application of changes.", 0x00
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
