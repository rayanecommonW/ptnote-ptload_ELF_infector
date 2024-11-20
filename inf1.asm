section .bss
buffer resb 10000            ; Reserve a 10KB buffer for the ELF file

section .text
global _start

_start:
    ; -------- Parse command line arguments --------
    mov rdi, [rsp + 16]       ; argv[1] (first argument after program name)
    test rdi, rdi             ; Check if it's NULL
    jz exit_usage             ; If no argument, exit with error code
    
    ; -------- Open the file --------
    mov rax, 2                ; sys_open
    mov rsi, 0                ; O_RDONLY (read-only)
    syscall
    cmp rax, 0
    js exit_error             ; Exit on error
    mov rdi, rax              ; Save file descriptor

    ; -------- Read file into buffer --------
    lea rsi, [buffer]         ; Pointer to buffer
    mov rdx, 10000            ; Buffer size (10KB)
    mov rax, 0                ; sys_read
    syscall
    cmp rax, 0
    js exit_error
    mov rbx, rax              ; rbx = number of bytes read

    ; -------- Close the file --------
    mov rax, 3                ; sys_close
    syscall

    ; -------- Store buffer base address in r15 --------
    lea r15, [buffer]         ; r15 = base address of stack buffer

    ; -------- Parse ELF header --------
    ; The ELF header starts at the base of the buffer:
    ; e_entry is at offset 0x18 (24 bytes) for 64-bit ELF files.

    mov r14, [r15 + 24]       ; r14 = original entry point (e_entry)

    parse_phdr:
    ; -------- Load Program Header Table Information --------
    xor rcx, rcx                       ; rcx = 0 (counter for entries)
    xor rdx, rdx                       ; rdx = 0 (store entry size)
    
    lea rax, [r15]           ; r15 points to the loaded ELF buffer
    mov cx, word [rax + 0x38]          ; e_hdr.phnum: Number of entries in PHT
    mov rbx, qword [rax + 0x20]        ; e_hdr.phoff: Offset of the PHT
    mov dx, word [rax + 0x36]          ; e_hdr.phentsize: Size of one entry

    lea rbx, [rax + rbx]               ; rbx = Address of the first program header

    ; -------- Loop Through Program Headers --------
loop_phdr:
    cmp rcx, 0                         ; Check if we've iterated through all headers
    jle phdr_not_found                 ; If counter <= 0, exit (PT_NOTE not found)

    mov eax, dword [rbx + 0x00]        ; e_phdr.type: Segment type at offset 0x00
    cmp eax, 0x4                       ; Compare with PT_NOTE (0x4)
    je pt_note_found                   ; If equal, PT_NOTE is found

    ; Increment to the next Program Header
    add rbx, rdx                       ; rbx = rbx + e_phentsize
    dec rcx                            ; Decrement the number of remaining entries
    jmp loop_phdr                      ; Repeat the loop

phdr_not_found:
    ; Handle case where PT_NOTE was not found
    mov rax, 60                        ; sys_exit
    mov rdi, 2                         ; Exit code 2 (error: PT_NOTE not found)
    syscall

pt_note_found:
    ; -------- PT_NOTE Segment Found --------
    ; rbx now points to the PT_NOTE entry
    ; Do something with this entry here
    ret



    ; -------- Exit Normally --------
    mov rax, 60               ; sys_exit
    xor rdi, rdi              ; Exit code 0
    syscall

exit_usage:
    mov rax, 60               ; sys_exit
    mov rdi, 1                ; Exit code 1
    syscall

exit_error:
    mov rax, 60               ; sys_exit
    mov rdi, 2                ; Exit code 2
    syscall
