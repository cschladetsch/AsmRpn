section .text

global push_num
global push_str
global push_type
global pop
global pop_num
global pop_bool

push_num:
    mov rcx, [stack_top]
    cmp rcx, 10000
    jge .overflow
    mov [stack + rcx*8], rax
    mov byte [stack_types + rcx], TYPE_NUM
    inc rcx
    mov [stack_top], rcx
    ret
.overflow:
    ret

push_str:
    mov rcx, [stack_top]
    cmp rcx, 10000
    jge .overflow
    mov [stack + rcx*8], rax
    mov byte [stack_types + rcx], TYPE_STR
    inc rcx
    mov [stack_top], rcx
    ret
.overflow:
    ret

push_type:
    mov rcx, [stack_top]
    cmp rcx, 10000
    jge .overflow
    mov [stack + rcx*8], rdi
    mov byte [stack_types + rcx], sil
    inc rcx
    mov [stack_top], rcx
    ret
.overflow:
    ret

pop:
    mov rcx, [stack_top]
    test rcx, rcx
    jz .underflow
    dec rcx
    mov [stack_top], rcx
    mov rax, [stack + rcx*8]
    movzx edx, byte [stack_types + rcx]
    ret
.underflow:
    mov rax, 1
    mov rdi, 1
    mov rsi, .msg
    mov rdx, .msg_len
    syscall
    mov rax, 0
    mov rdx, 0
    ret
.msg db "Stack underflow", 10
.msg_len equ $ - .msg

pop_num:
    call pop
    cmp edx, TYPE_NUM
    je .ok
    mov rax, 0
    ret
.ok:
    ret

pop_bool:
    call pop
    cmp edx, TYPE_BOOL
    je .ok
    mov rax, 0
    ret
.ok:
    ret