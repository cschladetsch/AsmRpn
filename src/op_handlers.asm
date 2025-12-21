    dq suspend_handler

section .text
section .text

extern push_num
extern push_str
extern push_type
extern pop
extern pop_num
extern variables
extern var_types

global push_num_handler
push_num_handler:
    mov rax, r10
    call push_num
    jmp execute_loop

global push_str_handler
push_str_handler:
    mov rax, r10
    call push_str
    jmp execute_loop

global add_handler
add_handler:

    call pop
    mov r14, rax
    mov r15, rdx
    call pop
    mov r8, rax
    mov r9, rdx
    cmp r9, TYPE_NUM
    jne .add_str
    cmp r15, TYPE_NUM
    jne .add_str
    add r8, r14
    mov rax, r8
    call push_num
    jmp .add_done
.add_str:
    cmp r9, TYPE_STR
    jne execute_error
    cmp r15, TYPE_STR
    jne execute_error
    mov rsi, r8
    mov rdi, r14
    call concat_strings
    call push_str
.add_done:
    jmp execute_loop

global sub_handler
sub_handler:

    call pop_num
    mov r14, rax
    call pop_num
    sub rax, r14
    call push_num
    jmp execute_loop

global mul_handler
mul_handler:

    call pop_num
    mov r14, rax
    call pop_num
    imul rax, r14
    call push_num
    jmp execute_loop

global div_handler
div_handler:

    call pop_num
    mov r14, rax
    call pop_num
    cqo
    idiv r14
    call push_num
    jmp execute_loop

global store_handler
store_handler:
    call pop
    cmp edx, TYPE_LABEL
    je .label_on_top
    mov r14, rax
    mov r15, rdx
    call pop
    mov r13, rax
    jmp .do_store
.label_on_top:
    mov r13, rax
    call pop
    mov r14, rax
    mov r15, rdx
.do_store:
    mov [variables + r13*8], r14
    mov byte [var_types + r13], r15b
    jmp execute_loop

global push_var_handler
push_var_handler:
    mov r13, r10
    mov rax, [variables + r13*8]
    movzx edx, byte [var_types + r13]
    cmp edx, TYPE_NUM
    je .pv_num
    cmp edx, TYPE_STR
    je .pv_str
    cmp edx, TYPE_ARRAY
    je .pv_array
    cmp edx, TYPE_BOOL
    je .pv_bool
    cmp edx, TYPE_CONT
    je .pv_cont
    cmp edx, TYPE_LABEL
    je .pv_label
    jmp execute_loop
.pv_num:
    call push_num
    jmp execute_loop
.pv_str:
    call push_str
    jmp execute_loop
.pv_array:
    mov rdi, rax
    mov rsi, TYPE_ARRAY
    call push_type
    jmp execute_loop
.pv_bool:
    mov rdi, rax
    mov rsi, TYPE_BOOL
    call push_type
    jmp execute_loop
.pv_cont:
    mov rdi, rax
    mov rsi, TYPE_CONT
    call push_type
    jmp execute_loop
.pv_label:
    mov rdi, rax
    mov rsi, TYPE_LABEL
    call push_type
    jmp execute_loop

global clear_handler
clear_handler:

    mov qword [stack_top], 0
    jmp execute_loop

global drop_handler
drop_handler:

    call pop
    jmp execute_loop

global swap_handler
swap_handler:

    call pop
    mov r14, rax
    mov r15, rdx
    call pop
    mov r8, rax
    mov r9, rdx
    mov rdi, r14
    mov rsi, r15
    call push_type
    mov rdi, r8
    mov rsi, r9
    call push_type
    jmp execute_loop

global dup_handler
dup_handler:
    mov rcx, [stack_top]
    test rcx, rcx
    jz execute_error
    dec rcx
    mov rax, [stack + rcx*8]
    movzx rdx, byte [stack_types + rcx]
    inc rcx
    mov rdi, rax
    mov rsi, rdx
    call push_type
    jmp execute_loop

global eq_handler
eq_handler:

    call pop
    mov r14, rax
    mov r15, rdx
    call pop
    cmp rax, r14
    jne .not_eq
    mov rax, 1
    jmp .eq_done
.not_eq:
    mov rax, 0
.eq_done:
    mov rdi, rax
    mov rsi, TYPE_BOOL
    call push_type
    jmp execute_loop

global assert_handler
assert_handler:

    call pop_bool
    test rax, rax
    jnz .ok
    mov rax, 1
    mov rdi, 1
    mov rsi, .assert_msg
    mov rdx, .assert_len
    syscall
.ok:
    jmp execute_loop
.assert_msg db "Assertion failed", 10
.assert_len equ $ - .assert_msg

global over_handler
over_handler:

    call pop
    mov r14, rax
    mov r15, rdx
    call pop
    mov r8, rax
    mov r9, rdx
    ; push second
    mov rdi, r8
    mov rsi, r9
    call push_type
    ; push top
    mov rdi, r14
    mov rsi, r15
    call push_type
    ; push second
    mov rdi, r8
    mov rsi, r9
    call push_type
    jmp execute_loop

global rot_handler
rot_handler:

    call pop ; c
    mov r14, rax
    mov r15, rdx
    call pop ; b
    mov r8, rax
    mov r9, rdx
    call pop ; a
    mov r10, rax
    mov r11, rdx
    ; push b
    mov rdi, r8
    mov rsi, r9
    call push_type
    ; push c
    mov rdi, r14
    mov rsi, r15
    call push_type
    ; push a
    mov rdi, r10
    mov rsi, r11
    call push_type
    jmp execute_loop

global depth_handler
depth_handler:

    mov rax, [stack_top]
    call push_num
    jmp execute_loop

global gt_handler
gt_handler:

    call pop_num
    mov r14, rax
    call pop_num
    cmp rax, r14
    jg .true
    mov rax, 0
    jmp .done
.true:
    mov rax, 1
.done:
    mov rdi, rax
    mov rsi, TYPE_BOOL
    call push_type
    jmp execute_loop

global lt_handler
lt_handler:

    call pop_num
    mov r14, rax
    call pop_num
    cmp rax, r14
    jl .true
    mov rax, 0
    jmp .done
.true:
    mov rax, 1
.done:
    mov rdi, rax
    mov rsi, TYPE_BOOL
    call push_type
    jmp execute_loop

global length_handler
length_handler:

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

global push_array_handler
push_array_handler:

    ; push as array
    mov rdi, r10
    mov rsi, TYPE_ARRAY
    call push_type
    jmp execute_loop

global push_label_handler
push_label_handler:

    mov rdi, r10
    mov rsi, TYPE_LABEL
    call push_type
    jmp execute_loop

global push_true_handler
push_true_handler:

    mov rdi, 1
    mov rsi, TYPE_BOOL
    call push_type
    jmp execute_loop

global push_false_handler
push_false_handler:

    mov rdi, 0
    mov rsi, TYPE_BOOL
    call push_type
    jmp execute_loop

global suspend_handler
suspend_handler:

    mov rax, 1
    mov rdi, 1
    mov rsi, .suspend_msg
    mov rdx, .suspend_len
    syscall
    jmp execute_loop
.suspend_msg db "Suspend: expected continuation", 10
.suspend_len equ $ - .suspend_msg
