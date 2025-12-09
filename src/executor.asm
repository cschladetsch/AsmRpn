section .text
    global execute
    global push
    global pop
    global print_stack
    extern bytecode
    extern stack
    extern stack_top
    extern variables
    extern output_buffer

; Constants (same as parser)
OP_PUSH_NUM equ 0
OP_PUSH_VAR equ 1
OP_ADD equ 2
OP_SUB equ 3
OP_MUL equ 4
OP_DIV equ 5
OP_STORE equ 6

; rdi = bytecode, rsi = bc_count
execute:
    push rbp
    mov rbp, rsp
    push rbx
    push rsi
    push rdi
    push r12

    mov r12, rdi  ; bytecode ptr
    mov rcx, rsi  ; count

.loop:
    test rcx, rcx
    jz .done
    mov rax, [r12]  ; type
    mov rbx, [r12+8]  ; value
    add r12, 16
    dec rcx

    cmp rax, OP_PUSH_NUM
    je .push_num
    cmp rax, OP_PUSH_VAR
    je .push_var
    cmp rax, OP_ADD
    je .add
    cmp rax, OP_SUB
    je .sub
    cmp rax, OP_MUL
    je .mul
    cmp rax, OP_DIV
    je .div
    cmp rax, OP_STORE
    je .store
    ; invalid
    jmp .loop

.push_num:
    mov rax, rbx
    call push
    jmp .loop

.push_var:
    mov rax, [variables + rbx*8]
    call push
    jmp .loop

.add:
    call pop
    cmp rax, -1
    je .underflow
    mov rbx, rax
    call pop
    cmp rax, -1
    je .underflow
    add rax, rbx
    call push
    jmp .loop

.sub:
    call pop
    cmp rax, -1
    je .underflow
    mov rbx, rax
    call pop
    cmp rax, -1
    je .underflow
    sub rax, rbx
    call push
    jmp .loop

.mul:
    call pop
    cmp rax, -1
    je .underflow
    mov rbx, rax
    call pop
    cmp rax, -1
    je .underflow
    imul rax, rbx
    call push
    jmp .loop

.div:
    call pop
    cmp rax, -1
    je .underflow
    test rax, rax
    jz .div_zero
    mov rbx, rax
    call pop
    cmp rax, -1
    je .underflow
    cqo
    idiv rbx
    call push
    jmp .loop

.store:
    call pop
    cmp rax, -1
    je .underflow
    mov [variables + rbx*8], rax
    jmp .loop

.underflow:
    ; Handle underflow, print error
    jmp .loop

.div_zero:
    ; Handle div zero
    jmp .loop

.done:
    pop r12
    pop rdi
    pop rsi
    pop rbx
    leave
    ret

; Push to stack
push:
    push rbp
    mov rbp, rsp
    push rbx

    mov rbx, [stack_top]
    inc rbx
    cmp rbx, 100
    jge .overflow  ; But ignore for now
    mov [stack_top], rbx
    mov [stack + rbx*8], rax
    pop rbx
    leave
    ret
.overflow:
    ; Handle overflow
    pop rbx
    leave
    ret

; Pop from stack, return in rax, -1 if empty
pop:
    push rbp
    mov rbp, rsp
    push rbx

    mov rbx, [stack_top]
    cmp rbx, -1
    je .empty
    mov rax, [stack + rbx*8]
    dec rbx
    mov [stack_top], rbx
    pop rbx
    leave
    ret
.empty:
    mov rax, -1
    pop rbx
    leave
    ret

print_stack:
    push rbp
    mov rbp, rsp
    push rbx
    push rsi
    push rdi
    push rdx

    mov rbx, [stack_top]
    cmp rbx, -1
    je .empty_stack

    ; Print stack from top to bottom
.print_loop:
    cmp rbx, -1
    jl .done
    mov rax, [stack + rbx*8]

    ; Convert to string
    mov rdi, output_buffer
    call int_to_string

    ; Print number
    mov rax, 1
    mov rdi, 1
    mov rsi, output_buffer
    mov rdx, rcx  ; length
    syscall

    ; Print space
    mov rax, 1
    mov rdi, 1
    mov rsi, space
    mov rdx, 1
    syscall

    dec rbx
    jmp .print_loop

.empty_stack:
    ; Print empty message
    mov rax, 1
    mov rdi, 1
    mov rsi, empty_msg
    mov rdx, empty_len
    syscall

.done:
    ; Print newline
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall

    pop rdx
    pop rdi
    pop rsi
    pop rbx
    leave
    ret

section .data
    space db ' '
    newline db 10
    empty_msg db 'Stack empty', 10
    empty_len equ $ - empty_msg

; Convert rax to string in rdi, return length in rcx
int_to_string:
    push rbx
    push rdx
    push rsi

    mov rcx, 0
    test rax, rax
    jns .positive
    neg rax
    mov byte [rdi], '-'
    inc rdi
    inc rcx
.positive:
    mov rbx, 10
    xor rsi, rsi
.convert_loop:
    xor rdx, rdx
    div rbx
    add dl, '0'
    push rdx
    inc rsi
    test rax, rax
    jnz .convert_loop
.pop_loop:
    pop rdx
    mov [rdi], dl
    inc rdi
    inc rcx
    dec rsi
    jnz .pop_loop

    pop rsi
    pop rdx
    pop rbx
    ret