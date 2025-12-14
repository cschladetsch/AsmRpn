section .text
    %include "constants.inc"
    global parse_tokens
    global is_number
    global atoi
    global is_variable
    global hash_name
    extern op_list
    extern variables
    extern var_types
    extern store_string_literal
    extern store_raw_literal
    extern token_meta
    extern token_ptrs
    extern active_token_ptrs
    extern active_token_meta
    extern active_op_list
    extern cont_literal_texts
    extern cont_literal_lengths
    extern cont_literal_values
    extern cont_literal_types
    extern cont_literal_count
    extern cont_build_buffer

; Constants
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

; rdi = token_ptrs, rsi = num_tokens
; returns rax = op_count
parse_tokens:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15

    mov r12, [rel active_op_list]  ; op list ptr
    xor r13, r13      ; op count
    mov r14, rsi      ; token count
    xor r15, r15      ; index

loop:
    cmp r15, r14
    jge .done
    mov rbx, [rel active_token_ptrs]
    mov rsi, [rbx + r15*8]
    mov rdx, [rel active_token_meta]
    mov al, [rdx + r15]
    inc r15
    cmp al, 1
    je .push_label_meta

    ; Check if number
    call is_number
    cmp rax, 1
    je .push_number

    ; Check if string literal
    mov al, [rsi]
    cmp al, '"'
    je .push_string
    mov al, [rsi]
    cmp al, '['
    je .push_array_literal
    cmp al, '{'
    je .open_continuation
    cmp al, '}'
    je .syntax_error_token
    cmp al, ']'
    je .syntax_error_token

    ; Check operators (require exact token match)
    mov al, [rsi]
    cmp al, '+'
    je .check_add
    cmp al, '-'
    je .check_sub
    cmp al, '*'
    je .check_mul
    cmp al, '/'
    je .check_div
    cmp al, '#'
    je .check_storeop
    cmp al, '&'
    je .symbol_suspend
    cmp al, '!'
    je .symbol_replace
    cmp al, '.'
    je .maybe_resume_symbol

    ; Check stack/utility words
%macro MATCH_WORD 2
    lea rdi, [rel %1]
    call token_equals
    cmp rax, 1
    je %2
%endmacro

    MATCH_WORD kw_clear, .op_clear
    MATCH_WORD kw_drop, .op_drop
    MATCH_WORD kw_swap, .op_swap
    MATCH_WORD kw_dup, .op_dup
    MATCH_WORD kw_over, .op_over
    MATCH_WORD kw_rot, .op_rot
    MATCH_WORD kw_depth, .op_depth
    MATCH_WORD kw_eq, .op_eq
    MATCH_WORD kw_gt, .op_gt
    MATCH_WORD kw_lt, .op_lt
    MATCH_WORD kw_true, .push_true
    MATCH_WORD kw_false, .push_false
    MATCH_WORD kw_assert, .assert_word
%undef MATCH_WORD

    ; Check if variable
    call is_variable
    cmp rax, 1
    je .push_variable

    ; Check if store
    mov al, [rsi]
    cmp al, 39  ; '
    je .push_label

    ; Invalid token -> syntax error
    jmp .syntax_error_token

.check_add:
    cmp byte [rsi + 1], 0
    jne .syntax_error_token
    jmp .add

.check_sub:
    cmp byte [rsi + 1], 0
    jne .syntax_error_token
    jmp .subtract

.check_mul:
    cmp byte [rsi + 1], 0
    jne .syntax_error_token
    jmp .multiply

.check_div:
    cmp byte [rsi + 1], 0
    jne .syntax_error_token
    jmp .divide

.check_storeop:
    cmp byte [rsi + 1], 0
    jne .syntax_error_token
    jmp .store_op

.push_number:
    call atoi
    mov qword [r12], OP_PUSH_NUM
    mov qword [r12+8], rax
    add r12, 16
    inc r13
    jmp loop

.push_string:
    call store_string_literal
    mov qword [r12], OP_PUSH_STR
    mov qword [r12+8], rax
    add r12, 16
    inc r13
    jmp loop

.push_array_literal:
    call store_raw_literal
    mov qword [r12], OP_PUSH_ARRAY
    mov qword [r12+8], rax
    add r12, 16
    inc r13
    jmp loop

.open_continuation:
    mov rdi, r15
    mov rsi, r14
    mov rdx, [rel active_token_ptrs]
    call build_continuation_literal
    cmp rax, -1
    je .syntax_error_token
    mov r15, rdx
    mov qword [r12], OP_PUSH_CONT
    mov qword [r12+8], rax
    add r12, 16
    inc r13
    jmp loop

.push_variable:
    call hash_name
    mov qword [r12], OP_PUSH_VAR
    mov qword [r12+8], rax
    add r12, 16
    inc r13
    jmp loop

.push_label:
    inc rsi  ; skip '
    call hash_name
    mov qword [r12], OP_PUSH_LABEL
    mov qword [r12+8], rax
    add r12, 16
    inc r13
    jmp loop

.push_label_meta:
    inc rsi
    call hash_name
    mov qword [r12], OP_PUSH_LABEL
    mov qword [r12+8], rax
    add r12, 16
    inc r13
    jmp loop

.add:
    mov qword [r12], OP_ADD
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.subtract:
    mov qword [r12], OP_SUB
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.multiply:
    mov qword [r12], OP_MUL
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.divide:
    mov qword [r12], OP_DIV
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.store_op:
    mov qword [r12], OP_STORE
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.push_true:
    mov qword [r12], OP_PUSH_TRUE
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.push_false:
    mov qword [r12], OP_PUSH_FALSE
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.assert_word:
    mov qword [r12], OP_ASSERT
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.symbol_suspend:
    cmp byte [rsi + 1], 0
    jne .syntax_error_token
    mov qword [r12], OP_SUSPEND
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.symbol_replace:
    cmp byte [rsi + 1], 0
    jne .syntax_error_token
    mov qword [r12], OP_REPLACE
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.maybe_resume_symbol:
    cmp byte [rsi + 1], '.'
    jne .syntax_error_token
    cmp byte [rsi + 2], '.'
    jne .syntax_error_token
    cmp byte [rsi + 3], 0
    jne .syntax_error_token
    mov qword [r12], OP_RESUME
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.op_clear:
    mov qword [r12], OP_CLEAR
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.op_drop:
    mov qword [r12], OP_DROP
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.op_swap:
    mov qword [r12], OP_SWAP
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.op_dup:
    mov qword [r12], OP_DUP
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.op_over:
    mov qword [r12], OP_OVER
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.op_rot:
    mov qword [r12], OP_ROT
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.op_depth:
    mov qword [r12], OP_DEPTH
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.op_eq:
    mov qword [r12], OP_EQ
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.op_gt:
    mov qword [r12], OP_GT
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.op_lt:
    mov qword [r12], OP_LT
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp loop

.syntax_error_token:
    mov rdi, rsi
    call report_syntax_error
    mov rax, -1
    jmp .cleanup

.done:
    mov rax, r13

.cleanup:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret

; Check if rsi points to a number
is_number:
    push rbp
    mov rbp, rsp
    push rsi

    mov al, [rsi]
    cmp al, '-'
    je .maybe_neg
    cmp al, '0'
    jb .no
    cmp al, '9'
    ja .no
    jmp .check_rest
.maybe_neg:
    inc rsi
    mov al, [rsi]
    cmp al, '0'
    jb .no
    cmp al, '9'
    ja .no
.check_rest:
    inc rsi
.loop:
    mov al, [rsi]
    test al, al
    jz .yes
    cmp al, '0'
    jb .no
    cmp al, '9'
    ja .no
    inc rsi
    jmp .loop
.yes:
    mov rax, 1
    jmp .done
.no:
    xor rax, rax
.done:
    pop rsi
    leave
    ret

; Convert string to int (simple atoi)
atoi:
    push rbp
    mov rbp, rsp
    push rbx

    xor rax, rax
    xor rbx, rbx
    xor rcx, rcx
    mov cl, [rsi]
    cmp cl, '-'
    jne .loop
    inc rsi
    mov rbx, -1
    jmp .loop

.loop:
    mov cl, [rsi]
    cmp cl, 0
    je .done
    cmp cl, '0'
    jb .done
    cmp cl, '9'
    ja .done
    sub cl, '0'
    imul rax, 10
    add rax, rcx
    inc rsi
    jmp .loop

.done:
    test rbx, rbx
    jz .positive
    neg rax
.positive:
    pop rbx
    leave
    ret

; Check if rsi points to a valid variable name (C-style)
; Returns 1 if valid, 0 otherwise
is_variable:
    push rbp
    mov rbp, rsp
    push rsi

    mov al, [rsi]
    cmp al, 'a'
    jb .check_underscore
    cmp al, 'z'
    ja .check_underscore
    jmp .check_rest
.check_underscore:
    cmp al, '_'
    jne .no
.check_rest:
    inc rsi
.loop:
    mov al, [rsi]
    test al, al
    jz .yes
    cmp al, 'a'
    jb .check_digit
    cmp al, 'z'
    ja .check_digit
    jmp .next
.check_digit:
    cmp al, '0'
    jb .check_underscore2
    cmp al, '9'
    ja .check_underscore2
    jmp .next
.check_underscore2:
    cmp al, '_'
    jne .no
.next:
    inc rsi
    jmp .loop
.yes:
    mov rax, 1
    jmp .done
.no:
    xor rax, rax
.done:
    pop rsi
    leave
    ret

; Compute hash of string at rsi, return hash % 256 in rax
hash_name:
    push rbp
    mov rbp, rsp
    push rbx
    push rdx

    xor rax, rax
.loop:
    movzx rbx, byte [rsi]
    test rbx, rbx
    jz .done
    imul rax, 31
    add rax, rbx
    inc rsi
    jmp .loop
.done:
    mov rbx, 256
    xor rdx, rdx
    div rbx
    mov rax, rdx

    pop rdx
    pop rbx
    leave
    ret

; Compare current token (rsi) to keyword at rdi, return 1 if equal
token_equals:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    mov rbx, rsi
    mov rcx, rdi
.cmp_loop:
    mov al, [rbx]
    mov dl, [rcx]
    cmp al, dl
    jne .not_equal
    test al, al
    je .equal
    inc rbx
    inc rcx
    jmp .cmp_loop
.not_equal:
    xor rax, rax
    jmp .done
.equal:
    mov rax, 1
.done:
    pop rcx
    pop rbx
    leave
    ret

.push_array:
    call sub_parse
    add rbx, 8
    dec r14
    mov qword [r12], OP_PUSH_ARRAY
    mov qword [r12+8], rax
    add r12, 16
    inc r13
    jmp loop

sub_parse:
    push rbp
    mov rbp, rsp
    push rbx
    push rsi
    push r14
    xor rax, rax
.sub_loop:
    test r14, r14
    jz .done
    mov rsi, [rbx]
    mov cl, [rsi]
    cmp cl, ']'
    je .done
    call is_number
    cmp rax, 1
    je .push_num
    mov al, [rsi]
    cmp al, '"'
    je .push_str
    cmp cl, '['
    je .push_sub_array
    jmp .sub_skip
.push_num:
    call atoi
    mov qword [r12], OP_PUSH_NUM
    mov qword [r12+8], rax
    add r12, 16
    inc rax
    jmp .sub_skip
.push_str:
    call store_string_literal
    mov qword [r12], OP_PUSH_STR
    mov qword [r12+8], rax
    add r12, 16
    inc rax
    jmp .sub_skip
.push_sub_array:
    call sub_parse
    mov qword [r12], OP_PUSH_ARRAY
    mov qword [r12+8], rax
    add r12, 16
    inc rax
    jmp .sub_skip
.sub_skip:
    add rbx, 8
    dec r14
    jmp .sub_loop
.done:
    pop r14
    pop rsi
    pop rbx
    leave
    ret

print_token_string:
    push rbp
    mov rbp, rsp
    push rdi
    push rsi
    mov rsi, rdi
.pts_loop:
    mov al, [rsi]
    test al, al
    jz .pts_done
    mov [rel syntax_char], al
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel syntax_char]
    mov rdx, 1
    syscall
    inc rsi
    jmp .pts_loop
.pts_done:
    pop rsi
    pop rdi
    leave
    ret

report_syntax_error:
    push rbp
    mov rbp, rsp
    push rdi
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel syntax_error_prefix]
    mov rdx, syntax_error_prefix_len
    syscall
    pop rdi
    call print_token_string
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel syntax_newline]
    mov rdx, 1
    syscall
    leave
    ret

build_continuation_literal:
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

    mov r12, rdx          ; token pointers base
    mov r13, rdi          ; current index after '{'
    mov r14, rsi          ; total tokens
    mov r15d, 1           ; depth
    lea rbx, [rel cont_build_buffer]
    mov r8, rbx           ; write pointer
    xor r9d, r9d          ; flag: first token

.cont_loop:
    cmp r13, r14
    jge .cont_error
    mov r10, [r12 + r13*8]
    mov dl, [r10]
    cmp dl, '{'
    jne .check_close
    inc r15d
    jmp .copy_token
.check_close:
    cmp dl, '}'
    jne .copy_token
    dec r15d
    jl .cont_error
    cmp r15d, 0
    je .cont_done
.copy_token:
    cmp r9d, 0
    je .skip_space
    mov byte [r8], ' '
    inc r8
.skip_space:
    mov rdi, r10
.copy_char_loop:
    mov dl, [rdi]
    test dl, dl
    je .token_finished
    mov [r8], dl
    inc r8
    inc rdi
    jmp .copy_char_loop
.token_finished:
    mov r9d, 1
    inc r13
    jmp .cont_loop

.cont_done:
    inc r13           ; skip closing brace
    mov byte [r8], 0
%if LOG_ENABLED
    mov rcx, r8
    sub rcx, rbx
    cmp rcx, 0
    jle .skip_log_literal
    mov rax, 1
    mov rdi, 2
    lea rsi, [rel log_literal_prefix]
    mov rdx, log_literal_prefix_len
    syscall
    mov rax, 1
    mov rdi, 2
    lea rsi, [rel cont_build_buffer]
    mov rdx, rcx
    syscall
    mov rax, 1
    mov rdi, 2
    lea rsi, [rel log_newline]
    mov rdx, log_newline_len
    syscall
.skip_log_literal:
%endif
    lea rsi, [rel cont_build_buffer]
    call store_raw_literal
    mov r10, rax      ; pointer to stored literal
%if LOG_ENABLED
    mov rcx, [r10]
    mov rax, 1
    mov rdi, 2
    lea rsi, [rel log_literal_store]
    mov rdx, log_literal_store_len
    syscall
    mov rax, 1
    mov rdi, 2
    mov rsi, r10
    add rsi, 8
    mov rdx, rcx
    syscall
    mov rax, 1
    mov rdi, 2
    lea rsi, [rel log_newline]
    mov rdx, log_newline_len
    syscall
%endif
    mov eax, [r10]    ; length (low 32 bits sufficient)
    mov r11d, eax
    mov rax, [rel cont_literal_count]
    cmp rax, CONT_LITERAL_MAX
    jae .cont_error
    mov rdx, rax
    lea rdi, [rel cont_literal_texts]
    mov [rdi + rdx*8], r10
    lea rdi, [rel cont_literal_lengths]
    mov [rdi + rdx*4], r11d
    ; copy variables
    lea rsi, [rel variables]
    lea rdi, [rel cont_literal_values]
    mov r8, VAR_SLOT_COUNT*8
    mov r9, rdx
    imul r9, r8
    add rdi, r9
    mov rcx, VAR_SLOT_COUNT
    rep movsq
    ; copy types
    lea rsi, [rel var_types]
    lea rdi, [rel cont_literal_types]
    mov r8, VAR_SLOT_COUNT
    mov r9, rdx
    imul r9, r8
    add rdi, r9
    mov rcx, VAR_SLOT_COUNT
    rep movsb
    inc qword [rel cont_literal_count]
    mov rax, rdx
    mov rdx, r13
    jmp .cont_cleanup

.cont_error:
    mov rax, -1
    mov rdx, r13

.cont_cleanup:
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

section .data
    kw_clear db "clear", 0
    kw_drop db "drop", 0
    kw_swap db "swap", 0
    kw_depth db "depth", 0
    kw_dup db "dup", 0
    kw_over db "over", 0
    kw_rot db "rot", 0
    kw_eq db "eq", 0
    kw_gt db "gt", 0
    kw_lt db "lt", 0
    kw_true db "true", 0
    kw_false db "false", 0
    kw_assert db "assert", 0
    syntax_error_prefix db "Syntax error: "
    syntax_error_prefix_len equ $ - syntax_error_prefix
    syntax_newline db 10
    token_iter_base dq 0
    token_iter_count dq 0

section .bss
    syntax_char resb 1

section .note.GNU-stack noalloc nobits align=1
