section .bss
buffer resb 8192              ; Reserve an 8KB buffer in memory for reading

section .text
global _start

_start:
    ; -------- Parse command line arguments --------
    mov rdi, [rsp + 16]        ; argv[1] (first argument after program name)
    test rdi, rdi              ; Check if it's NULL
    jz exit_usage              ; If no argument, exit with error code
    
    ; -------- Open the file --------
    mov rax, 2                 ; sys_open
    mov rsi, 0                 ; O_RDONLY (read-only)
    syscall                    ; Invoke syscall
    cmp rax, 0
    js exit_error              ; Check if the file failed to open
    mov rdi, rax               ; Save file descriptor

    ; -------- Read file into buffer --------
    lea rsi, [buffer]          ; Pointer to buffer
    mov rdx, 8192              ; Buffer size
    mov rax, 0                 ; sys_read
    syscall                    ; Invoke syscall
    cmp rax, 0
    js exit_error              ; Check for read errors
    mov rbx, rax               ; Save number of bytes read
    
    ; -------- Close the file --------
    mov rax, 3                 ; sys_close
    syscall                    ; Close the file descriptor
    
    
    ; -------- Program successfully read into buffer --------
    ; For simplicity, do nothing further here.

    ; Exit normally
    mov rax, 60                ; sys_exit
    xor rdi, rdi               ; Exit code 0
    syscall

exit_usage:
    mov rax, 60                ; sys_exit
    mov rdi, 1                 ; Exit code 1 (usage error)
    syscall

exit_error:
    mov rax, 60                ; sys_exit
    mov rdi, 2                 ; Exit code 2 (error occurred)
    syscall
