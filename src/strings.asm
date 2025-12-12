section .bss
    global string_pool
    global string_offset
string_pool resb 100000
string_offset resq 1

section .text
    global store_string_literal
    global concat_strings

; rsi = pointer to quoted literal
store_string_literal:
    push rbp
    mov rbp, rsp
    push rbx
    push rdi
    push r9
    push r10
    push rcx
    push rdx

    mov r9, rsi
    cmp byte [r9], '"'
    jne .no_quote
    inc r9
.no_quote:
    mov r10, r9
    xor rcx, rcx
.len_loop:
    mov al, [r10]
    test al, al
    je .len_done
    cmp al, 10
    je .len_done
    cmp al, '"'
    je .len_done
    cmp al, 92
    jne .count_char
    inc r10
    mov al, [r10]
    test al, al
    je .len_done
.count_char:
    inc rcx
    inc r10
    jmp .len_loop
.len_done:
    mov rbx, [rel string_offset]
    lea rdi, [rel string_pool]
    lea rdi, [rdi + rbx]
    mov [rdi], rcx
    lea r8, [rdi + 8]
    mov r10, r9
    mov rdx, rcx
.copy_loop:
    test rdx, rdx
    jz .copy_done
    mov al, [r10]
    cmp al, 92
    jne .write_char
    inc r10
    mov al, [r10]
.write_char:
    mov [r8], al
    inc r8
    inc r10
    dec rdx
    jmp .copy_loop
.copy_done:
    add rbx, rcx
    add rbx, 8
    mov [rel string_offset], rbx
    mov rax, rdi

    pop rdx
    pop rcx
    pop r10
    pop r9
    pop rdi
    pop rbx
    leave
    ret

; rsi = left string, rdi = right string
concat_strings:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11

    mov r8, [rsi]
    mov r9, [rdi]
    mov r10, r8
    add r10, r9
    mov r11, [rel string_offset]
    lea rbx, [rel string_pool]
    lea rbx, [rbx + r11]
    mov [rbx], r10
    lea r12, [rbx + 8]
    lea rdx, [rsi + 8]
    mov rcx, r8
.left_copy:
    test rcx, rcx
    jz .left_done
    mov al, [rdx]
    mov [r12], al
    inc r12
    inc rdx
    dec rcx
    jmp .left_copy
.left_done:
    lea rdx, [rdi + 8]
    mov rcx, r9
.right_copy:
    test rcx, rcx
    jz .concat_done
    mov al, [rdx]
    mov [r12], al
    inc r12
    inc rdx
    dec rcx
    jmp .right_copy
.concat_done:
    add r11, r10
    add r11, 8
    mov [rel string_offset], r11
    mov rax, rbx

    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    leave
    ret
