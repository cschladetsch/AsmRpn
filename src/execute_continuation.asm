extern cont_literal_texts
extern cont_token_ptrs
extern cont_token_meta
extern cont_op_list
extern cont_bytecode
extern cont_literal_lengths
extern cont_input_buffer
extern active_token_ptrs
extern active_token_meta
extern tokenize
extern active_op_list
extern active_bytecode
extern parse_tokens
extern translate
extern execute
extern variables
extern var_types
extern context_stack_top
extern context_ips
extern context_counts
extern context_scope_values
extern context_scope_types
extern excess_ctx_error_msg
extern context_stack_top
extern context_ips
extern context_counts
extern context_scope_values
extern context_scope_types

global push_context
global pop_context

; Push to stack

execute_continuation_impl:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    push r8
    push r9
    push r10
    mov r15, rdi ; save literal index
    ; copy text
    lea rsi, [cont_literal_texts]
    mov rsi, [rsi + r15*8]
    lea rdx, [cont_literal_lengths]
    mov rdx, [rdx + r15*4]
    lea rbx, [cont_input_buffer]
    mov r8, rbx
.copy_loop:
    test rdx, rdx
    jz .copy_done
    mov al, [rsi]
    mov [r8], al
    inc rsi
    inc r8
    dec rdx
    jmp .copy_loop
.copy_done:
    mov byte [r8], 0
    ; tokenize
    lea rsi, [cont_input_buffer]
    mov qword [active_token_ptrs], cont_token_ptrs
    mov qword [active_token_meta], cont_token_meta
    call tokenize
    mov r12, rax
    ; parse
    mov qword [active_op_list], cont_op_list
    mov qword [active_bytecode], cont_bytecode
    lea rdi, [active_token_ptrs]
    mov rsi, r12
    call parse_tokens
    mov r13, rax
    ; translate
    lea rdi, [active_op_list]
    mov rsi, r13
    lea rdx, [active_bytecode]
    call translate
    mov rsi, rax ; bytecode count
    lea rdi, [active_bytecode]
    call execute
    ; restore
    pop r10
    pop r9
    pop r8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    leave
    ret

push_context:
    push rbp
    mov rbp, rsp
    push rbx
    push rdx
    push rcx
    push r8
    push r9

    mov rax, [context_stack_top]
    inc rax
    mov [context_stack_top], rax

    lea rbx, [context_ips]
    mov [rbx + rax*8], rdi
    lea rbx, [context_counts]
    mov [rbx + rax*8], rsi

    mov r8, VAR_SLOT_COUNT
    mov rdx, rax
    imul rdx, r8
    lea rbx, [context_scope_values]
    lea rdi, [rbx + rdx*8]
    lea rsi, [rel variables]
    mov rcx, VAR_SLOT_COUNT
    rep movsq

    mov rdx, rax
    imul rdx, VAR_SLOT_COUNT
    lea rbx, [context_scope_types]
    lea rdi, [rbx + rdx]
    lea rsi, [rel var_types]
    mov rcx, VAR_SLOT_COUNT
    rep movsb

    pop r9
    pop r8
    pop rcx
    pop rdx
    pop rbx
    leave
    ret

pop_context:
    push rbp
    mov rbp, rsp
    push rbx
    push rdx
    push rcx
    push r8
    push r9
    push r10
    push r11

    mov r10, rdi  ; ip out ptr
    mov r11, rsi  ; count out ptr

    mov rax, [context_stack_top]
    cmp rax, -1
    jne .has_ctx
    xor rax, rax
    jmp .done

.has_ctx:
    lea rbx, [context_ips]
    mov r8, [rbx + rax*8]
    lea rbx, [context_counts]
    mov r9, [rbx + rax*8]

    mov rdx, rax
    imul rdx, VAR_SLOT_COUNT
    lea rbx, [context_scope_values]
    lea rsi, [rbx + rdx*8]
    lea rdi, [rel variables]
    mov rcx, VAR_SLOT_COUNT
    rep movsq

    mov rdx, rax
    imul rdx, VAR_SLOT_COUNT
    lea rbx, [context_scope_types]
    lea rsi, [rbx + rdx]
    lea rdi, [rel var_types]
    mov rcx, VAR_SLOT_COUNT
    rep movsb

    dec rax
    mov [context_stack_top], rax

    mov rax, 1
    cmp r10, 0
    je .skip_ip
    mov [r10], r8
.skip_ip:
    cmp r11, 0
    je .skip_count
    mov [r11], r9
.skip_count:
    jmp .done

.done:
    pop r11
    pop r10
    pop r9
    pop r8
    pop rcx
    pop rdx
    pop rbx
    leave
    ret
