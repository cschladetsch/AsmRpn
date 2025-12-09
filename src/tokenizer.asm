section .text
    global tokenize
    extern token_ptrs

; rsi = buffer
; returns rax = num_tokens
tokenize:
    push rbp
    mov rbp, rsp
    push rbx
    push rsi
    push rdi

    mov rbx, token_ptrs  ; pointer to array
    xor rcx, rcx  ; count
    mov rdi, rsi  ; buffer

.loop:
    mov al, [rdi]
    test al, al
    jz .done
    cmp al, ' '
    je .skip_space
    ; start of token
    mov [rbx], rdi
    add rbx, 8
    inc rcx
    ; find end
.find_end:
    inc rdi
    mov al, [rdi]
    test al, al
    jz .done
    cmp al, ' '
    jne .find_end
    ; end token
    mov byte [rdi], 0
.skip_space:
    inc rdi
    jmp .loop

.done:
    mov rax, rcx
    pop rdi
    pop rsi
    pop rbx
    leave
    ret