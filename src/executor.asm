section .text
    global int_to_string
    global execute
    global push
    global pop
    global print_stack
    global white
    global white_len
    global reset
    global reset_len
    global temp2
    extern bytecode
    extern output_buffer
    extern stack
    extern stack_top
    extern variables
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
    lea rdx, [rel variables]
    mov rax, [rdx + rbx*8]
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
    lea rdx, [rel variables]
    mov [rdx + rbx*8], rax
    jmp .loop

.underflow:
    ; Handle underflow, print error
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel stack_underflow_msg]
    mov rdx, stack_underflow_len
    syscall
    jmp .loop

.div_zero:
    ; Handle div zero
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel div_zero_msg]
    mov rdx, div_zero_len
    syscall
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
    lea rdx, [rel stack]
    mov [rdx + rbx*8], rax
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
    lea rdx, [rel stack]
    mov rax, [rdx + rbx*8]
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
 ; Convert int to string
; rax = number, rdi = buffer
; returns length in rcx
int_to_string:
    push rbp
    mov rbp, rsp
    push rbx
    mov rbx, 0     ; negative flag
    cmp rax, 0
    jns .positive
    mov rbx, 1
    neg rax
.positive:
    mov rdi, output_buffer
    mov rcx, 10
    xor r8, r8
.loop:
    xor rdx, rdx
    div rcx
    add dl, '0'
    mov [rdi], dl
    inc rdi
    inc r8
    test rax, rax
    jnz .loop
    cmp rbx, 1
    jne .reverse
    mov byte [rdi], '-'
    inc rdi
    inc r8
.reverse:
    lea rsi, [rel output_buffer]
    lea rdi, [output_buffer + r8 - 1]
.reverse_loop:
    cmp rsi, rdi
    jge .done_reverse
    mov al, [rsi]
    mov bl, [rdi]
    mov [rsi], bl
    mov [rdi], al
    inc rsi
    dec rdi
    jmp .reverse_loop
.done_reverse:
    mov rcx, r8
    pop rbx
    leave
    ret

print_stack:
    enter 0, 0
    push r12
    mov rbx, [stack_top]
    cmp rbx, -1
    je .done
    mov r12, 0  ; index
.loop:
    ; [
    lea rsi, [rel temp2]
    mov byte [rsi], '['
    mov rax, 1
    mov rdi, 1
    mov rdx, 1
    syscall
    ; index
    mov rax, r12
    call int_to_string
    mov r8, rcx  ; save length
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel output_buffer]
    mov rdx, r8
    syscall
    ; ]
    lea rsi, [rel temp2]
    mov byte [rsi], ']'
    mov rax, 1
    mov rdi, 1
    mov rdx, 1
    syscall
    ; space
    lea rsi, [rel temp2]
    mov byte [rsi], ' '
    mov rax, 1
    mov rdi, 1
    mov rdx, 1
    syscall
    ; value
    lea rdx, [rel stack]
    mov rax, [rdx + r12*8]
    call int_to_string
    mov r8, rcx
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel output_buffer]
    mov rdx, r8
    syscall
    ; \n
    lea rsi, [rel temp2]
    mov byte [rsi], 10
    mov rax, 1
    mov rdi, 1
    mov rdx, 1
    syscall
    inc r12
    cmp r12, rbx
    jle .loop
.done:
    pop r12
    leave
    ret

section .data
    temp2 db 0
    stack resq 100
    stack_top resq 1
    variables resq 256
    newline db 10
    zero db '0'
    three db '3'
    grey db 0
    grey_len equ 0
    green db 0
    green_len equ 0
    white db 0
    white_len equ 0
    dim_grey db 27, '[2;37m'
    dim_grey_len equ $ - dim_grey
    dark_green db 27, '[32m'
    dark_green_len equ $ - dark_green
    white_color db 27, '[37m'
    white_color_len equ $ - white_color
    blue db 27, '[34m'
    blue_len equ $ - blue
    reset db 27, '[0m'
    reset_len equ $ - reset
    bracket_open db '['
    bracket_close db '] '
    stack_underflow_msg db "Error", 10
    stack_underflow_len equ $ - stack_underflow_msg
    div_zero_msg db "Division by zero Error", 10
    div_zero_len equ $ - div_zero_msg
