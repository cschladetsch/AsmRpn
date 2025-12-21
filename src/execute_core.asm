section .text

global execute
global execute_loop
global execute_error

execute:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
execute_loop:
    test r12, r12
    jz execute_done
    dec r12
    mov r13, [rbx]
    mov r10, [rbx + 8]
    add rbx, 16
    cmp r13, OP_PUSH_CONT
    jge execute_continuation
    mov r14, [op_table + r13*8]
    jmp r14
execute_continuation:
    cmp r13, OP_LENGTH
    je .length
    cmp r13, OP_PUSH_CONT
    je .push_cont
    cmp r13, 25 ; resume
    je .resume_error
    cmp r13, 26 ; replace
    je .replace_error
    jmp execute_loop
.push_cont:
    mov rdi, r10
    mov rsi, TYPE_CONT
    call push_type
    jmp execute_loop
.length:
    call pop
    cmp rdx, TYPE_STR
    je .str_len
    cmp rdx, TYPE_ARRAY
    je .array_len
    jmp execute_loop
.str_len:
    mov rsi, rax
    call string_length
    call push_num
    jmp execute_loop
.array_len:
    mov rax, 0
    call push_num
    jmp execute_loop
.resume_error:
    mov rax, 1
    mov rdi, 1
    mov rsi, .resume_msg
    mov rdx, .resume_len
    syscall
    jmp execute_loop
.resume_msg db "Resume: not in continuation", 10
.resume_len equ $ - .resume_msg
.replace_error:
    mov rax, 1
    mov rdi, 1
    mov rsi, .replace_msg
    mov rdx, .replace_len
    syscall
    jmp execute_loop
.replace_msg db "Replace: expected continuation", 10
.replace_len equ $ - .replace_msg
;     jmp execute_loop
; execute_done:
;     je .no_print
;     call print_stack
; .no_print:
;     leave
    ret

execute_error:
    jmp execute_loop

execute_done:
    call print_stack
    leave
    ret

op_table:
    dq push_num_handler
    dq push_var_handler
    dq add_handler
    dq sub_handler
    dq mul_handler
    dq div_handler
    dq store_handler
    dq clear_handler
    dq drop_handler
    dq swap_handler
    dq dup_handler
    dq over_handler
    dq rot_handler
    dq depth_handler
    dq eq_handler
    dq gt_handler
    dq lt_handler
    dq push_str_handler
    dq push_array_handler
    dq push_label_handler
    dq push_true_handler
    dq push_false_handler
    dq assert_handler
    dq suspend_handler ; suspend
    dq 0 ; push_cont
