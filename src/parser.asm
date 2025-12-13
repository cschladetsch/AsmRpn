section .text
    %include "constants.inc"
    global parse_tokens
    global is_number
    global atoi
    global is_variable
    global hash_name
    extern op_list
    extern variables
    extern store_string_literal

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
OP_PUSH_STR equ 10

; rdi = token_ptrs, rsi = num_tokens
; returns rax = op_count
parse_tokens:
    push rbp
    mov rbp, rsp
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14

    mov r12, op_list  ; op list ptr
    xor r13, r13  ; op count
    mov rbx, rdi  ; token array
    mov r14, rsi  ; num tokens

loop:
    test r14, r14
    jz .done
    mov rsi, [rbx]  ; current token
    add rbx, 8
    dec r14

    ; Check if number
    call is_number
    cmp rax, 1
    je .push_number

    ; Check if string literal
    mov al, [rsi]
    cmp al, '"'
    je .push_string

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

    ; Check keywords clear/drop/swap
    lea rdi, [rel kw_clear]
    call token_equals
    cmp rax, 1
    je .op_clear
    lea rdi, [rel kw_drop]
    call token_equals
    cmp rax, 1
    je .op_drop
    lea rdi, [rel kw_swap]
    call token_equals
    cmp rax, 1
    je .op_swap

    ; Check if variable
    call is_variable
    cmp rax, 1
    je .push_variable

    ; Check if store
    mov al, [rsi]
    cmp al, 39  ; '
    je .store

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

.push_variable:
    call hash_name
    mov qword [r12], OP_PUSH_VAR
    mov qword [r12+8], rax
    add r12, 16
    inc r13
    jmp loop

.store:
    inc rsi  ; skip '
    call hash_name
    mov qword [r12], OP_STORE
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

.syntax_error_token:
    mov rdi, rsi
    call report_syntax_error
    mov rax, -1
    jmp .cleanup

.done:
    mov rax, r13

.cleanup:
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    leave
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
    jmp loop
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
    jmp loop
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
    jmp loop
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

section .data
    kw_clear db "clear", 0
    kw_drop db "drop", 0
    kw_swap db "swap", 0
    kw_depth db "depth", 0
    syntax_error_prefix db "Syntax error: "
    syntax_error_prefix_len equ $ - syntax_error_prefix
    syntax_newline db 10

section .bss
    syntax_char resb 1

section .note.GNU-stack noalloc nobits align=1
