section .data
    file_open_error_msg db "Error opening file", 0xA  ; Error message
    file_open_error_len equ $ - file_open_error_msg

section .text
global _start

_start:
    ; Get the file name from arguments (argv[1])
    mov rdi, [rsp + 8]          ; Address of argv[0]
    mov rdi, [rsp + 16]         ; Address of argv[1] (file name)

    ; Check if a file name was provided
    test rdi, rdi               ; Is argv[1] null?
    jz no_filename_error        ; If null, handle error

    ; Prepare arguments for open() syscall
    mov rax, 2                  ; Syscall number for open()
    mov rsi, 2                  ; O_RDWR (read/write access)
    xor rdx, rdx                ; Mode (not needed for this call)
    syscall                     ; Invoke syscall

    ; Check if file was successfully opened
    test rax, rax               ; Check if rax < 0
    js file_open_error          ; If negative, jump to error handler

    ; File successfully opened; rax holds the file descriptor
    ; Continue with further processing...

    ; Exit program gracefully
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
