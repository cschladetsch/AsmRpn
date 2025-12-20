section .data
temp times 21 db 0
newline db 10

section .text
extern stack
extern stack_top
extern stack_types
extern string_length

global print_stack

print_stack:
    mov rcx, [stack_top]
    test rcx, rcx
    jz .empty
    dec rcx
    mov rax, [stack + rcx*8]
    movzx edx, byte [stack_types + rcx]
    cmp edx, TYPE_NUM
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
    ; print the string
    mov rsi, rax
    call string_length
    mov rdx, rax
    mov rax, 1
    mov rdi, 1
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
    mov rsi, .open_array
    mov rdx, .open_array_len
    mov rax, 1
    mov rdi, 1
    syscall
    ; print the string
    mov rsi, rax
    mov rdx, [rsi]
    add rsi, 8
    mov rax, 1
    mov rdi, 1
    syscall
    mov rsi, .close_array
    mov rdx, .close_array_len
    mov rax, 1
    mov rdi, 1
    syscall
    jmp .done
.open_array db "["
.open_array_len equ $ - .open_array
.close_array db "]"
.close_array_len equ $ - .close_array

.print_cont:
    mov rsi, .open_cont
    mov rdx, .open_cont_len
    mov rax, 1
    mov rdi, 1
    syscall
    ; print the string
    mov rsi, rax
    mov rdx, [rsi]
    add rsi, 8
    mov rax, 1
    mov rdi, 1
    syscall
    mov rsi, .close_cont
    mov rdx, .close_cont_len
    mov rax, 1
    mov rdi, 1
    syscall
    jmp .done
.open_cont db "{"
.open_cont_len equ $ - .open_cont
.close_cont db "}"
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
    mov rsi, '-'
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
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    ret