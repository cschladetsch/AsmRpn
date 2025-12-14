section .text
    %include "constants.inc"
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
    global maybe_write_color
    extern array_output_buffer
    extern temp_stack
    extern temp_types
    extern output_buffer
    extern stack
    extern stack_top
    extern stack_types
    extern variables
    extern var_types
    extern string_pool
    extern string_offset
    extern concat_strings
    extern enable_color
    extern cont_storage
    extern tokenize
    extern parse_tokens
    extern translate
    extern active_token_ptrs
    extern active_token_meta
    extern active_op_list
    extern active_bytecode
    extern cont_token_ptrs
    extern cont_token_meta
    extern cont_op_list
    extern cont_bytecode
    extern cont_input_buffer
    extern context_ips
    extern context_counts
    extern context_scope_values
    extern context_scope_types
    extern context_stack_top
    extern cont_literal_texts
    extern cont_literal_lengths
    extern cont_literal_values
    extern cont_literal_types
    extern cont_literal_count
    extern continuation_signal
    extern in_continuation

push_type:
    push rbp
    mov rbp, rsp
    mov rax, [stack_top]
    mov rbx, stack
    mov [rbx + rax*8], rsi
    mov rbx, stack_types
    mov [rbx + rax*8], rdi
    inc rax
    mov [stack_top], rax
    leave
    ret

build_array_string:
    push rbp
    mov rbp, rsp
    push rbx
    push rsi
    push rdi
    push rcx
    push rdx
    ; pop to temp
    mov rcx, rbx  ; count
    xor rdx, rdx  ; temp index
.pop_loop:
    test rcx, rcx
    jz .build
    call pop
    mov [temp_stack + rdx*8], rax
    mov [temp_types + rdx*8], rdx
    inc rdx
    dec rcx
    jmp .pop_loop
.build:
    mov rsi, array_output_buffer
    mov byte [rsi], '['
    inc rsi
    mov rcx, rbx  ; count
    mov rdi, rdx
    dec rdi  ; start from last
.loop:
    mov rax, [temp_stack + rdi*8]
    mov rdx, [temp_types + rdi*8]
    ; append
    cmp rdx, TYPE_INT
    je .append_int
    cmp rdx, TYPE_STRING
    je .append_string
    jmp .next
.append_int:
    push rsi
    push rdi
    push rcx
    mov rsi, temp2
    call int_to_string
    mov rdi, temp2
    call append_string_to_buffer
    pop rcx
    pop rdi
    pop rsi
    jmp .next
.append_string:
    push rsi
    push rdi
    push rcx
    mov rdi, rax
    call append_string_to_buffer
    pop rcx
    pop rdi
    pop rsi
    jmp .next
.next:
    dec rdi
    dec rcx
    jz .close
    mov byte [rsi], ' '
    inc rsi
    jmp .loop
.close:
    mov byte [rsi], ']'
    inc rsi
    mov byte [rsi], 0
    ; mov rdi, array_output_buffer
    ; call store_dynamic_string
    mov rax, array_output_buffer
    pop rdx
    pop rcx
    pop rdi
    pop rsi
    pop rbx
    leave
    ret

append_string_to_buffer:
.loop:
    mov al, [rdi]
    test al, al
    jz .end
    mov [rsi], al
    inc rsi
    inc rdi
    jmp .loop
.end:
    ret

    extern is_number
    extern atoi
    extern maybe_write_color

OP_PUSH_NUM equ 0
OP_PUSH_VAR equ 1
OP_ADD equ 2
OP_SUB equ 3
OP_MUL equ 4
OP_DIV equ 5
OP_STORE equ 6
OP_CLEAR equ 7
OP_DROP equ 8
OP_SWAP equ 9
OP_DUP equ 10
OP_OVER equ 11
OP_ROT equ 12
OP_DEPTH equ 13
OP_EQ equ 14
OP_GT equ 15
OP_LT equ 16
OP_PUSH_STR equ 17
OP_PUSH_ARRAY equ 18
OP_PUSH_LABEL equ 19
OP_PUSH_TRUE equ 20
OP_PUSH_FALSE equ 21
OP_ASSERT equ 22
OP_SUSPEND equ 23
OP_PUSH_CONT equ 24
OP_RESUME equ 25
OP_REPLACE equ 26

TYPE_INT equ 0
TYPE_STRING equ 1
TYPE_ARRAY equ 2
TYPE_LABEL equ 3
TYPE_CONT equ 4

CONT_SIGNAL_NONE equ 0
CONT_SIGNAL_RESUME equ 1
CONT_SIGNAL_REPLACE equ 2

; rdi = bytecode, rsi = bc_count
execute:
    push rbp
    mov rbp, rsp
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15

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
    cmp rax, OP_CLEAR
    je .clear
    cmp rax, OP_DROP
    je .drop
    cmp rax, OP_SWAP
    je .swap
    cmp rax, OP_DUP
    je .dup
    cmp rax, OP_OVER
    je .over
    cmp rax, OP_ROT
    je .rot
    cmp rax, OP_DEPTH
    je .depth
    cmp rax, OP_EQ
    je .cmp_eq
    cmp rax, OP_GT
    je .cmp_gt
    cmp rax, OP_LT
    je .cmp_lt
    cmp rax, OP_PUSH_STR
    je .push_str
    cmp rax, OP_PUSH_ARRAY
    je .push_array
    cmp rax, OP_PUSH_LABEL
    je .push_label
    cmp rax, OP_PUSH_TRUE
    je .push_true
    cmp rax, OP_PUSH_FALSE
    je .push_false
    cmp rax, OP_PUSH_CONT
    je .push_cont
    cmp rax, OP_ASSERT
    je .op_assert
    cmp rax, OP_SUSPEND
    je .op_suspend
    cmp rax, OP_RESUME
    je .op_resume
    cmp rax, OP_REPLACE
    je .op_replace
    jmp .execute_loop  ; invalid, skip

.push_num:
    mov rax, rdx
    mov dl, TYPE_INT
    call push
    jmp .execute_loop

.push_var:
    lea rsi, [rel variables]
    mov rax, [rsi + rdx*8]
    lea rsi, [rel var_types]
    mov dl, [rsi + rdx]
    call push
    jmp .execute_loop

.push_str:
    mov rax, rdx
    mov dl, TYPE_STRING
    call push
    jmp .execute_loop

.push_array:
    mov rax, rdx
    mov dl, TYPE_ARRAY
    call push
    jmp .execute_loop

.push_label:
    mov rax, rdx
    mov dl, TYPE_LABEL
    call push
    jmp .execute_loop

.push_cont:
    mov rax, rdx
    mov dl, TYPE_CONT
    call push
    jmp .execute_loop

.push_true:
    mov rax, 1
    mov dl, TYPE_INT
    call push
    jmp .execute_loop

.push_false:
    xor rax, rax
    mov dl, TYPE_INT
    call push
    jmp .execute_loop

.op_suspend:
    lea rsi, [rel cont_unimpl_msg]
    mov rdx, cont_unimpl_len
    call report_type_error
    jmp .execute_loop

.op_resume:
    lea rsi, [rel cont_unimpl_msg]
    mov rdx, cont_unimpl_len
    call report_type_error
    jmp .execute_loop

.op_replace:
    lea rsi, [rel cont_unimpl_msg]
    mov rdx, cont_unimpl_len
    call report_type_error
    jmp .execute_loop

.add:
    call ensure_two_operands
    test rax, rax
    jz .execute_loop
    call pop
    mov r12, rax
    mov r13b, dl
    call pop
    cmp r13b, TYPE_STRING
    jne .check_add_int
    cmp dl, TYPE_STRING
    jne .add_type_error
    mov rsi, rax         ; left
    mov rdi, r12         ; right
    call concat_strings
    mov dl, TYPE_STRING
    call push
    jmp .execute_loop
.check_add_int:
    cmp r13b, TYPE_INT
    jne .add_type_error
    cmp dl, TYPE_INT
    jne .add_type_error
    add rax, r12
    mov dl, TYPE_INT
    call push
    jmp .execute_loop
.add_type_error:
    ; restore operands (left first, then right) and report error
    call push
    mov rax, r12
    mov dl, r13b
    call push
    lea rsi, [rel type_error_add_msg]
    mov rdx, type_error_add_len
    call report_type_error
    jmp .execute_loop

.subtract:
    call ensure_two_operands
    test rax, rax
    jz .execute_loop
    call pop  ; subtrahend
    mov r12, rax
    mov r13b, dl
    call pop  ; minuend
    cmp r13b, TYPE_INT
    jne .arith_type_error_restore
    cmp dl, TYPE_INT
    jne .arith_type_error_restore
    sub rax, r12
    mov dl, TYPE_INT
    call push
    jmp .execute_loop
.arith_type_error_restore:
    call push
    mov rax, r12
    mov dl, r13b
    call push
    lea rsi, [rel type_error_int_msg]
    mov rdx, type_error_int_len
    call report_type_error
    jmp .execute_loop

.multiply:
    call ensure_two_operands
    test rax, rax
    jz .execute_loop
    call pop
    mov r12, rax
    mov r13b, dl
    call pop
    cmp r13b, TYPE_INT
    jne .arith_type_error_restore_mul
    cmp dl, TYPE_INT
    jne .arith_type_error_restore_mul
    imul rax, r12
    mov dl, TYPE_INT
    call push
    jmp .execute_loop
.arith_type_error_restore_mul:
    call push
    mov rax, r12
    mov dl, r13b
    call push
    lea rsi, [rel type_error_int_msg]
    mov rdx, type_error_int_len
    call report_type_error
    jmp .execute_loop

.divide:
    call ensure_two_operands
    test rax, rax
    jz .execute_loop
    call pop  ; divisor
    mov r12, rax
    mov r13b, dl
    call pop  ; dividend
    cmp r13b, TYPE_INT
    jne .arith_type_error_restore_div
    cmp dl, TYPE_INT
    jne .arith_type_error_restore_div
    cqo
    idiv r12
    mov dl, TYPE_INT
    call push
    jmp .execute_loop
.arith_type_error_restore_div:
    call push
    mov rax, r12
    mov dl, r13b
    call push
    lea rsi, [rel type_error_int_msg]
    mov rdx, type_error_int_len
    call report_type_error
    jmp .execute_loop

.store:
    call ensure_two_operands
    test rax, rax
    jz .execute_loop
    call pop        ; destination label
    cmp dl, TYPE_LABEL
    jne .store_label_type_error
    mov r12, rax
    call pop        ; value to store
    mov r8b, dl
    lea rsi, [rel variables]
    mov [rsi + r12*8], rax
    lea rsi, [rel var_types]
    mov [rsi + r12], r8b
    jmp .execute_loop
.store_label_type_error:
    call push
    lea rsi, [rel type_error_store_label_msg]
    mov rdx, type_error_store_label_len
    call report_type_error
    jmp .execute_loop

.clear:
    lea rdx, [rel stack_top]
    mov qword [rdx], -1
    jmp .execute_loop

.drop:
    call pop
    jmp .execute_loop

.swap:
    call ensure_two_operands
    test rax, rax
    jz .execute_loop
    lea rdx, [rel stack_top]
    mov r8, [rdx]
    lea r9, [rel stack]
    mov rax, [r9 + r8*8]
    mov r10, r8
    dec r10
    mov r11, [r9 + r10*8]
    mov [r9 + r8*8], r11
    mov [r9 + r10*8], rax
    lea r9, [rel stack_types]
    mov al, [r9 + r8]
    mov dl, [r9 + r10]
    mov [r9 + r8], dl
    mov [r9 + r10], al
    jmp .execute_loop

.dup:
    call ensure_one_operand
    test rax, rax
    jz .execute_loop
    call pop
    mov r12, rax
    mov r13b, dl
    mov rax, r12
    mov dl, r13b
    call push
    mov rax, r12
    mov dl, r13b
    call push
    jmp .execute_loop

.over:
    call ensure_two_operands
    test rax, rax
    jz .execute_loop
    call pop
    mov r12, rax
    mov r13b, dl
    call pop
    mov r10, rax
    mov r11b, dl
    mov rax, r10
    mov dl, r11b
    call push
    mov rax, r12
    mov dl, r13b
    call push
    mov rax, r10
    mov dl, r11b
    call push
    jmp .execute_loop

.rot:
    call ensure_three_operands
    test rax, rax
    jz .execute_loop
    call pop
    mov r12, rax    ; x3
    mov r13b, dl
    call pop
    mov r14, rax    ; x2
    mov r15b, dl
    call pop
    mov r10, rax    ; x1
    mov r11b, dl
    mov rax, r14
    mov dl, r15b
    call push
    mov rax, r12
    mov dl, r13b
    call push
    mov rax, r10
    mov dl, r11b
    call push
    jmp .execute_loop

.depth:
    mov rax, [stack_top]
    inc rax
    mov dl, TYPE_INT
    call push
    jmp .execute_loop

.cmp_eq:
    call ensure_two_operands
    test rax, rax
    jz .execute_loop
    call pop
    mov r12, rax
    mov r13b, dl
    call pop
    cmp r13b, TYPE_INT
    jne .execute_loop
    cmp dl, TYPE_INT
    jne .execute_loop
    cmp rax, r12
    sete al
    movzx rax, al
    mov dl, TYPE_INT
    call push
    jmp .execute_loop

.cmp_gt:
    call ensure_two_operands
    test rax, rax
    jz .execute_loop
    call pop
    mov r12, rax
    mov r13b, dl
    call pop
    cmp r13b, TYPE_INT
    jne .execute_loop
    cmp dl, TYPE_INT
    jne .execute_loop
    cmp rax, r12
    setg al
    movzx rax, al
    mov dl, TYPE_INT
    call push
    jmp .execute_loop

.cmp_lt:
    call ensure_two_operands
    test rax, rax
    jz .execute_loop
    call pop
    mov r12, rax
    mov r13b, dl
    call pop
    cmp r13b, TYPE_INT
    jne .execute_loop
    cmp dl, TYPE_INT
    jne .execute_loop
    cmp rax, r12
    setl al
    movzx rax, al
    mov dl, TYPE_INT
    call push
    jmp .execute_loop

.op_assert:
    call ensure_one_operand
    test rax, rax
    jz .execute_loop
    call pop
    test rax, rax
    jnz .execute_loop
    call report_assert_fail
    mov rax, 60
    mov rdi, 1
    syscall

.done:
    pop r15
    pop r14
    pop r13
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

    mov r8b, dl
    mov rbx, [stack_top]
    inc rbx
    cmp rbx, 10000
    jge .overflow  ; But ignore for now
    mov [stack_top], rbx
    lea rdx, [rel stack]
    mov [rdx + rbx*8], rax
    lea rdx, [rel stack_types]
    mov [rdx + rbx], r8b
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
    lea rdx, [rel stack_types]
    mov dl, [rdx + rbx]
    dec rbx
    mov [stack_top], rbx
    pop rbx
    leave
    ret
.empty:
    mov rax, -1
    xor edx, edx
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
    push r13
    push r14
    push r15
    mov r12, [stack_top]
    cmp r12, -1
    je .ps_done
    xor r13, r13            ; display index from bottom
    lea r14, [rel stack]
    lea r15, [rel stack_types]
.print_loop:
    lea rsi, [rel grey]
    mov rdx, grey_len
    call maybe_write_color
    lea rsi, [rel temp2]
    mov byte [rsi], '['
    mov rax, 1
    mov rdi, 1
    mov rdx, 1
    syscall
    mov r11, r12
    sub r11, r13           ; absolute stack index
    mov r9, r11            ; keep across syscalls (r11 clobbered)
    mov rax, r13           ; display relative index (0 = top)
    call int_to_string
    mov r8, rcx
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel output_buffer]
    mov rdx, r8
    syscall
    lea rsi, [rel reset]
    mov rdx, reset_len
    call maybe_write_color
    lea rsi, [rel grey]
    mov rdx, grey_len
    call maybe_write_color
    lea rsi, [rel temp2]
    mov byte [rsi], ']'
    mov rax, 1
    mov rdi, 1
    mov rdx, 1
    syscall
    lea rsi, [rel reset]
    mov rdx, reset_len
    call maybe_write_color
    lea rsi, [rel temp2]
    mov byte [rsi], ' '
    mov rax, 1
    mov rdi, 1
    mov rdx, 1
    syscall
    lea rsi, [rel white]
    mov rdx, white_len
    call maybe_write_color
    mov rax, [r14 + r9*8]
    mov bl, [r15 + r9]
    cmp bl, TYPE_STRING
    je .print_stack_string
    cmp bl, TYPE_ARRAY
    je .print_stack_array
    cmp bl, TYPE_CONT
    je .print_stack_cont
    call int_to_string
    mov r8, rcx
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel output_buffer]
    mov rdx, r8
    syscall
    jmp .after_value
.print_stack_string:
    mov r10, rax
    call print_quote
    mov rsi, r10
    mov rdx, [rsi]
    add rsi, 8
    mov rax, 1
    mov rdi, 1
    syscall
    call print_quote
    jmp .after_value
.print_stack_array:
    mov r10, rax
    mov rsi, r10
    mov rdx, [rsi]
    add rsi, 8
    mov rax, 1
    mov rdi, 1
    syscall
    jmp .after_value
.print_stack_cont:
    mov r10, rax
    lea rsi, [rel cont_literal_texts]
    mov r11, [rsi + r10*8]
    lea rsi, [rel cont_prefix]
    mov rax, 1
    mov rdi, 1
    mov rdx, cont_prefix_len
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, r11
    mov rdx, [rsi]
    add rsi, 8
    syscall
    lea rsi, [rel cont_suffix]
    mov rax, 1
    mov rdi, 1
    mov rdx, cont_suffix_len
    syscall
.after_value:
    lea rsi, [rel reset]
    mov rdx, reset_len
    call maybe_write_color
    lea rsi, [rel temp2]
    mov byte [rsi], 10
    mov rax, 1
    mov rdi, 1
    mov rdx, 1
    syscall
    inc r13
    cmp r13, r12
    jle .print_loop
.ps_done:
    pop r15
    pop r14
    pop r13
    pop r12
    leave
    ret

print_quote:
    push rbp
    mov rbp, rsp
    lea rsi, [rel quote]
    mov rax, 1
    mov rdi, 1
    mov rdx, 1
    syscall
    leave
    ret

ensure_one_operand:
    push rbp
    mov rbp, rsp
    mov rax, [rel stack_top]
    cmp rax, 0
    jge .one_enough
    call report_underflow
    xor rax, rax
    leave
    ret
.one_enough:
    mov rax, 1
    leave
    ret

ensure_two_operands:
    push rbp
    mov rbp, rsp
    mov rax, [rel stack_top]
    cmp rax, 1
    jge .enough
    call report_underflow
    xor rax, rax
    leave
    ret
.enough:
    mov rax, 1
    leave
    ret

ensure_three_operands:
    push rbp
    mov rbp, rsp
    mov rax, [rel stack_top]
    cmp rax, 2
    jge .three_enough
    call report_underflow
    xor rax, rax
    leave
    ret
.three_enough:
    mov rax, 1
    leave
    ret

report_type_error:
    push rbp
    mov rbp, rsp
    push rcx
    push r11
    push rsi
    push rdx
    lea rsi, [rel red]
    mov rdx, red_len
    call maybe_write_color
    pop rdx
    pop rsi
    mov rax, 1
    mov rdi, 1
    syscall
    lea rsi, [rel reset]
    mov rdx, reset_len
    call maybe_write_color
    pop r11
    pop rcx
    leave
    ret

; rsi = left string (Pascal), rdi = right string
report_underflow:
    push rbp
    mov rbp, rsp
    push rcx
    push r11
    lea rsi, [rel red]
    mov rdx, red_len
    call maybe_write_color
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel stack_underflow_msg]
    mov rdx, stack_underflow_len
    syscall
    lea rsi, [rel reset]
    mov rdx, reset_len
    call maybe_write_color
    pop r11
    pop rcx
    leave
    ret

report_assert_fail:
    push rbp
    mov rbp, rsp
    lea rsi, [rel red]
    mov rdx, red_len
    call maybe_write_color
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel assert_fail_msg]
    mov rdx, assert_fail_len
    syscall
    lea rsi, [rel reset]
    mov rdx, reset_len
    call maybe_write_color
    leave
    ret

section .data
    temp2 db 0
    quote db '"'
    comma_space db ',', ' '
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
    type_error_add_msg db 'Type error: + expects both operands to be integers or strings', 10
    type_error_add_len equ $ - type_error_add_msg
    type_error_int_msg db 'Type error: arithmetic operands must be integers', 10
    type_error_int_len equ $ - type_error_int_msg
    type_error_store_label_msg db 'Type error: store (#) expects a label on top of stack', 10
    type_error_store_label_len equ $ - type_error_store_label_msg
    bracket_open db '['
    bracket_close db '] '
    red db 27, '[31m'
    red_len equ $ - red
    stack_underflow_msg db "Stack underflow", 10
    stack_underflow_len equ $ - stack_underflow_msg
    div_zero_msg db "Division by zero Error", 10
    div_zero_len equ $ - div_zero_msg
    assert_fail_msg db "Assertion failed", 10
    assert_fail_len equ $ - assert_fail_msg
    cont_unimpl_msg db "Continuations not implemented yet", 10
    cont_unimpl_len equ $ - cont_unimpl_msg
    cont_prefix db '{', ' '
    cont_prefix_len equ 2
    cont_suffix db ' ', '}'
    cont_suffix_len equ 2

section .bss
    array_output_buffer resb 1024
    temp_stack resq 100
    temp_types resq 100

section .text
; rsi = color string, rdx = len, write if color enabled
maybe_write_color:
    cmp byte [rel enable_color], 1
    jne .skip
    mov rax, 1
    mov rdi, 1
    syscall
.skip:
    ret

section .note.GNU-stack noalloc nobits align=1
