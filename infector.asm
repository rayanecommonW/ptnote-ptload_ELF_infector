
section .data
    dir_name db ".", 0             ; Current directory (default)
    buffer times 4096 db 0         ; Buffer to hold directory entries
    msg db "Filename: ", 0         ; Message prefix
    newline db 0xA, 0              ; Newline character

section .bss
    linux_dirent resb 280          ; Reserve space for struct linux_dirent64

section .text
    global _start

_start:
    ; Check if an argument is passed (in RDI from the command line)
    mov rdi, [rsp+8]               ; First argument from argv[1]
    test rdi, rdi                  ; Check if it's null
    jz open_default_dir            ; If null, use current directory
    mov rsi, rdi                   ; Use argument as directory name
    jmp open_directory

open_default_dir:
    mov rsi, dir_name              ; Use current directory (.)

open_directory:
    ; Open directory using openat() syscall (syscall number 257)
    mov rax, 257                   ; syscall number for openat()
    xor rdi, rdi                   ; AT_FDCWD (current directory)
    mov rdx, 0                     ; O_RDONLY flag
    syscall

    ; Save file descriptor
    mov rdi, rax                   ; File descriptor returned in rax

read_directory:
    ; Use getdents64() syscall (syscall number 217)
    mov rax, 217                   ; syscall number for getdents64
    mov rsi, buffer                ; Buffer to store the directory entries
    mov rdx, 4096                  ; Buffer size
    syscall

    ; Check if no more entries
    test rax, rax
    jz exit_program

    ; Store entries on the stack
    mov rsi, buffer                ; Start of buffer
    mov rbx, rax                   ; Number of bytes read

process_entries:
    ; Check if all bytes processed
    cmp rbx, 0
    jz read_directory              ; If all entries processed, read again

    ; Get current directory entry
    movzx rcx, word [rsi+18]       ; Get d_reclen (directory entry length)
    
    ; Store the directory entry on the stack
    sub rsp, rcx                   ; Allocate space on stack
    mov rdi, rsp                   ; Destination (stack)
    mov rdx, rcx                   ; Length of directory entry
    rep movsb                      ; Copy directory entry to stack

    ; Print the filename (d_name)
    mov rdi, 1                     ; File descriptor 1 (stdout)
    mov rax, 1                     ; syscall number for write()
    mov rsi, msg                   ; Message to print ("Filename: ")
    mov rdx, 10                    ; Length of message
    syscall

    ; Print the filename
    mov rdi, 1                     ; File descriptor 1 (stdout)
    mov rax, 1                     ; syscall number for write()
    mov rsi, rsp + 20              ; d_name field (after 20 bytes)
    mov rdx, [rsp+18]              ; d_reclen length to calculate the name length
    sub rdx, 20                    ; Adjust length to d_name
    syscall

    ; Print newline
    mov rdi, 1                     ; File descriptor 1 (stdout)
    mov rax, 1                     ; syscall number for write()
    mov rsi, newline               ; Newline character
    mov rdx, 1                     ; Length
    syscall

    ; Move to next directory entry
    add rsi, rcx                   ; Move to next entry in the buffer
    sub rbx, rcx                   ; Reduce the remaining byte count
    jmp process_entries            ; Process next entry

exit_program:
    ; Exit the program
    mov rax, 60                    ; syscall number for exit()
    xor rdi, rdi                   ; Status code 0
    syscall
