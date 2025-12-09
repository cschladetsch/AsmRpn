section .text
    global parse_tokens
    global is_number
    global atoi
    global is_variable
    global hash_name
    extern op_list
    extern variables

; Constants
OP_PUSH_NUM equ 0
OP_PUSH_VAR equ 1
OP_ADD equ 2
OP_SUB equ 3
OP_MUL equ 4
OP_DIV equ 5
OP_STORE equ 6

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

    mov r12, op_list  ; op list ptr
    xor r13, r13  ; op count
    mov rbx, rdi  ; token array
    mov rcx, rsi  ; num tokens

.loop:
    test rcx, rcx
    jz .done
    mov rsi, [rbx]  ; current token
    add rbx, 8
    dec rcx

    ; Check if number
    call is_number
    cmp rax, 1
    je .push_number

    ; Check if variable
    call is_variable
    cmp rax, 1
    je .push_variable

    ; Check if store
    mov al, [rsi]
    cmp al, 39  ; '
    je .store

    ; Check operators
    mov al, [rsi]
    cmp al, '+'
    je .add
    cmp al, '-'
    je .subtract
    cmp al, '*'
    je .multiply
    cmp al, '/'
    je .divide

    ; Invalid, skip
    jmp .loop

.push_number:
    call atoi
    mov qword [r12], OP_PUSH_NUM
    mov qword [r12+8], rax
    add r12, 16
    inc r13
    jmp .loop

.push_variable:
    call hash_name
    mov qword [r12], OP_PUSH_VAR
    mov qword [r12+8], rax
    add r12, 16
    inc r13
    jmp .loop

.store:
    inc rsi  ; skip '
    call hash_name
    mov qword [r12], OP_STORE
    mov qword [r12+8], rax
    add r12, 16
    inc r13
    jmp .loop

.add:
    mov qword [r12], OP_ADD
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp .loop

.subtract:
    mov qword [r12], OP_SUB
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp .loop

.multiply:
    mov qword [r12], OP_MUL
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp .loop

.divide:
    mov qword [r12], OP_DIV
    mov qword [r12+8], 0
    add r12, 16
    inc r13
    jmp .loop

.done:
    mov rax, r13
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