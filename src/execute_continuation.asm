extern cont_literal_offsets
extern cont_token_ptrs
extern cont_token_meta
extern cont_op_list
extern cont_bytecode
extern cont_literal_lengths
extern cont_input_buffer
extern cont_storage
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
    ; copy text from splice
    lea rax, [cont_literal_offsets]
    mov r10, [rax + r15*8]
    lea rdx, [cont_literal_lengths]
    mov ecx, [rdx + r15*4]
    lea rsi, [cont_storage]
    add rsi, r10
    lea rbx, [cont_input_buffer]
    mov rdi, rbx
    mov r8, rcx
    rep movsb
    mov byte [rdi], 0
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
    mov rax, 1
    ret

pop_context:
    mov rax, 1
    ret
