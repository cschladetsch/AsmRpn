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
    call skip_whitespace
    test al, al
    jz .done
    ; start of token
    mov [rbx], rdi
    add rbx, 8
    inc rcx
    call find_end
    ; replace separator with 0 if not null
    cmp al, 0
    je .no_replace
    mov byte [rdi], 0
    add rdi, 1
.no_replace:
    jmp .loop

.done:
    mov rax, rcx
    pop rdi
    pop rsi
    pop rbx
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
    jbe .ret  ; whitespace or null
    jmp find_end
.ret:
    ret