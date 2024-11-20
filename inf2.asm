section .bss
buffer resb 10000            ; 10KB buffer to load ELF file

section .text
global _start

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

    ; -------- Read file into buffer --------
    lea rsi, [buffer]         ; Address of buffer
    mov rdx, 10000            ; Buffer size
    mov rax, 0                ; sys_read
    syscall
    cmp rax, 0
    js exit_error
    mov rbx, rax              ; Save number of bytes read
    mov r8, rbx               ; Store file size in r8
    lea rax, [buffer]         ; rax now points to the ELF base address

    ; -------- Parse Program Header Table --------
parse_phdr:
    xor rcx, rcx              ; rcx = 0 (counter for entries)
    xor rdx, rdx              ; rdx = 0 (store entry size)

    mov cx, word [rax + 0x38] ; e_phnum: Number of program headers
    mov rbx, qword [rax + 0x20] ; e_phoff: Offset of program header table
    mov dx, word [rax + 0x36] ; e_phentsize: Size of each program header

    lea rbx, [rax + rbx]      ; rbx = address of the first program header

    ; -------- Loop through Program Headers --------
loop_phdr:
    cmp rcx, 0                ; If counter <= 0, stop
    jle phdr_not_found

    mov edi, dword [rbx + 0x00] ; e_phdr.type at offset 0x00
    cmp edi, 0x4              ; Compare with PT_NOTE
    je pt_note_found          ; If equal, PT_NOTE found

    ; Increment to the next Program Header
    add rbx, rdx              ; rbx = rbx + e_phentsize
    dec rcx                   ; Decrement phnum counter
    jmp loop_phdr

phdr_not_found:
    ; No PT_NOTE found, exit with error
    mov rax, 60               ; sys_exit
    mov rdi, 2                ; Exit code 2
    syscall

pt_note_found:
    ; PT_NOTE segment found, rbx points to it
    ; Add your logic to modify the segment or process it
    mov rax, 60               ; sys_exit
    xor rdi, rdi              ; Exit with code 0
    syscall

exit_usage:
    mov rax, 60               ; sys_exit
    mov rdi, 1                ; Exit code 1
    syscall

exit_error:
    mov rax, 60               ; sys_exit
    mov rdi, 3                ; Exit code 3
    syscall
