section .data
temp times 21 db 0
newline db 10
prompt_prefix db 0xCE, 0xBB, ' '
prompt_prefix_len equ $ - prompt_prefix
quote_char db '"'
minus_char db '-'

section .text
extern stack
extern stack_top
extern stack_types
extern stdin_is_tty
extern cont_literal_offsets
extern cont_literal_lengths
extern cont_storage

global print_stack

print_stack:
    cmp byte [stdin_is_tty], 0
    jne .no_batch_prompt
    mov rax, 1
    mov rdi, 1
    lea rsi, [prompt_prefix]
    mov rdx, prompt_prefix_len
    syscall
.no_batch_prompt:
    mov rcx, [stack_top]
    test rcx, rcx
    jz .empty
    dec rcx
    mov rax, [stack + rcx*8]
    movzx edx, byte [stack_types + rcx]
    cmp edx, TYPE_NUM
    je .print_num
    cmp edx, TYPE_LABEL
    je .print_num
    cmp edx, TYPE_STR
    je .print_str
    cmp edx, TYPE_BOOL
    je .print_bool
    cmp edx, TYPE_ARRAY
    je .print_array
    cmp edx, TYPE_CONT
    je .print_cont
    jmp .done

.print_num:
    call print_number
    jmp .done

.print_str:
    mov r10, [rax]          ; length
    lea r9, [rax + 8]       ; data pointer
    mov rax, 1
    mov rdi, 1
    lea rsi, [quote_char]
    mov rdx, 1
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, r9
    mov rdx, r10
    syscall
    mov rax, 1
    mov rdi, 1
    lea rsi, [quote_char]
    mov rdx, 1
    syscall
    jmp .done

.print_bool:
    cmp rax, 1
    je .true
    mov rsi, .false
    mov rdx, .false_len
    jmp .print
.true:
    mov rsi, .true_str
    mov rdx, .true_len
.print:
    mov rax, 1
    mov rdi, 1
    syscall
    jmp .done
.false db "false"
.false_len equ $ - .false
.true_str db "true"
.true_len equ $ - .true_str
.quote db '"'
.quote_len equ $ - .quote

.print_array:
    mov r10, [rax]
    lea r9, [rax + 8]
    mov rax, 1
    mov rdi, 1
    mov rsi, r9
    mov rdx, r10
    syscall
    jmp .done

.print_cont:
    mov r11, rax          ; literal index
    lea rsi, [cont_literal_offsets]
    mov rax, [rsi + r11*8]
    lea r9, [cont_storage]
    add r9, rax
    lea rsi, [cont_literal_lengths]
    mov r10d, [rsi + r11*4]
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel .open_cont]
    mov rdx, .open_cont_len
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, r9
    mov rdx, r10
    syscall
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel .close_cont]
    mov rdx, .close_cont_len
    syscall
    jmp .done
.open_cont db '{',' '
.open_cont_len equ $ - .open_cont
.close_cont db ' ','}'
.close_cont_len equ $ - .close_cont

.done:
    mov rax, 1
    mov rdi, 1
    lea rsi, [newline]
    mov rdx, 1
    syscall
.empty:
    ret

print_number:
    test rax, rax
    jns .positive
    neg rax
    push rax
    mov rax, 1
    mov rdi, 1
    lea rsi, [minus_char]
    mov rdx, 1
    syscall
    pop rax
.positive:
    mov rbx, 10
    lea rdi, [temp + 20]
    mov rcx, 0
.loop:
    xor rdx, rdx
    div rbx
    add dl, '0'
    dec rdi
    mov [rdi], dl
    inc rcx
    test rax, rax
    jnz .loop
    mov rax, 1
    mov rsi, rdi
    mov rdx, rcx
    mov rdi, 1
    syscall
    ret
