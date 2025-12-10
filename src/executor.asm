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
    extern output_buffer
    extern stack
    extern stack_top
    extern variables
    extern is_number
    extern atoi

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

    mov rbx, rdi  ; bytecode
    mov rcx, rsi  ; count

.execute_loop:
    test rcx, rcx
    jz .done
    mov rax, [rbx]  ; op
    mov rdx, [rbx+8]  ; value
    add rbx, 16
    dec rcx

    cmp rax, OP_PUSH_NUM
    je .push_num
    cmp rax, OP_PUSH_VAR
    je .push_var
    cmp rax, OP_ADD
    je .add
    cmp rax, OP_SUB
    je .subtract
    cmp rax, OP_MUL
    je .multiply
    cmp rax, OP_DIV
    je .divide
    cmp rax, OP_STORE
    je .store
    jmp .execute_loop  ; invalid, skip

.push_num:
    mov rax, rdx
    call push
    jmp .execute_loop

.push_var:
    lea rsi, [rel variables]
    mov rax, [rsi + rdx*8]
    call push
    jmp .execute_loop

.add:
    call pop
    mov r12, rax
    call pop
    add rax, r12
    call push
    jmp .execute_loop

.subtract:
    call pop  ; subtrahend
    mov r12, rax
    call pop  ; minuend
    sub rax, r12
    call push
    jmp .execute_loop

.multiply:
    call pop
    mov r12, rax
    call pop
    imul rax, r12
    call push
    jmp .execute_loop

.divide:
    call pop  ; divisor
    mov r12, rax
    call pop  ; dividend
    cqo
    idiv r12
    call push
    jmp .execute_loop

.store:
    call pop
    lea rsi, [rel variables]
    mov [rsi + rdx*8], rax
    jmp .execute_loop

.done:
    pop r12
    pop rdi
    pop rsi
    mov rcx, r8
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
    lea rdx, [stack]
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
    mov rdx, stack
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
.div_loop:
    xor rdx, rdx
    div rcx
    add dl, '0'
    mov [rdi], dl
    inc rdi
    inc r8
    test rax, rax
    jnz .div_loop
    cmp rbx, 1
    jne .reverse
    mov byte [rdi], '-'
    inc rdi
    inc r8
.reverse:
    lea rsi, [output_buffer]
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
    mov rdx, stack
    mov r12, 0  ; index from bottom
.print_loop:
    ; grey for [
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel grey]
    mov rdx, grey_len
    syscall
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
    lea rsi, [output_buffer]
    mov rdx, r8
    syscall
    ; reset after index
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel reset]
    mov rdx, reset_len
    syscall
    ; grey for ]
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel grey]
    mov rdx, grey_len
    syscall
    ; ]
    lea rsi, [rel temp2]
    mov byte [rsi], ']'
    mov rax, 1
    mov rdi, 1
    mov rdx, 1
    syscall
    ; reset after ]
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel reset]
    mov rdx, reset_len
    syscall
    ; space
    lea rsi, [rel temp2]
    mov byte [rsi], ' '
    mov rax, 1
    mov rdi, 1
    mov rdx, 1
    syscall
    ; white for value
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel white]
    mov rdx, white_len
    syscall
    ; value
    lea rdx, [stack]
    mov rax, [rdx + r12*8]
    call int_to_string
    mov r8, rcx
    mov rax, 1
    mov rdi, 1
    lea rsi, [output_buffer]
    mov rdx, r8
    syscall
    ; reset after value
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel reset]
    mov rdx, reset_len
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
    jle .print_loop
.done:
    pop r12
    leave
    ret

section .data
    temp2 db 0
    newline db 10
    zero db '0'
    three db '3'
    grey db 27, '[2;37m'
    grey_len equ $ - grey
    green db 27, '[32m'
    green_len equ $ - green
    white db 27, '[37m'
    white_len equ $ - white
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
