section .text
    global tokenize
    extern token_ptrs

; rsi = buffer
; returns rax = num_tokens
tokenize:
    push rbp
    mov rbp, rsp
    push rsi
    push rdi
    sub rsp, 8

    mov rbx, token_ptrs  ; pointer to array
    xor rcx, rcx  ; count
    mov rdi, rsi  ; buffer
    mov qword [rbp-8], 0  ; pending special token

.loop:
    mov rax, [rbp-8]
    test rax, rax
    jz .no_pending
    mov [rbx], rax
    add rbx, 8
    inc rcx
    mov qword [rbp-8], 0
    jmp .loop

.no_pending:
    call skip_whitespace
    test al, al
    jz .done
    mov al, [rdi]
    cmp al, '['
    jne .check_close_bracket
    lea rdx, [rel open_square_token]
    jmp .emit_special

.check_close_bracket:
    cmp al, ']'
    jne .token_start
    lea rdx, [rel close_square_token]
    jmp .emit_special

.token_start:
    ; start of token
    mov [rbx], rdi
    add rbx, 8
    inc rcx
    cmp al, '"'
    je .string_token
    lea r8, [rbp-8]
    call find_end
    jmp .after_token

.emit_special:
    mov [rbx], rdx
    add rbx, 8
    inc rcx
    inc rdi
    jmp .loop

.string_token:
    call consume_string

.after_token:
    ; replace separator with 0 if not null
    cmp al, 0
    je .no_replace
    mov byte [rdi], 0
    add rdi, 1
.no_replace:
    jmp .loop

.done:
    mov rax, rcx
    add rsp, 8
    pop rdi
    pop rsi
    leave
    ret

skip_whitespace:
    mov al, [rdi]
    cmp al, 0
    je .ret
    cmp al, ' '
    je .next
    cmp al, 10  ; \n
    je .next
    cmp al, 13  ; \r
    je .next
    cmp al, 9   ; \t
    je .next
    jmp .ret
.next:
    inc rdi
    jmp skip_whitespace
.ret:
    ret

find_end:
    inc rdi
    mov al, [rdi]
    test al, al
    jz .ret
    cmp al, ' '
    jbe .ret
    cmp al, '['
    je .handle_open
    cmp al, ']'
    je .handle_close
    jmp find_end

.handle_open:
    lea rax, [rel open_square_token]
    mov [r8], rax
    mov byte [rdi], 0
    inc rdi
    xor eax, eax
    ret

.handle_close:
    lea rax, [rel close_square_token]
    mov [r8], rax
    mov byte [rdi], 0
    inc rdi
    xor eax, eax
    ret

.ret:
    ret

consume_string:
    push rbp
    mov rbp, rsp

    inc rdi             ; skip opening quote
.str_loop:
    mov al, [rdi]
    test al, al
    je .done
    cmp al, 10          ; newline
    je .done
    cmp al, '"'
    je .close
    cmp al, 92          ; '\\'
    jne .next
    inc rdi
    mov al, [rdi]
    test al, al
    je .done
.next:
    inc rdi
    jmp .str_loop
.close:
    inc rdi
.done:
    mov al, [rdi]
    leave
    ret

section .data
open_square_token db '[', 0
close_square_token db ']', 0

section .note.GNU-stack noalloc nobits align=1
