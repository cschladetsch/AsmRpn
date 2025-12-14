section .text
    global tokenize
    extern token_ptrs
    extern token_meta
    extern active_token_ptrs
    extern active_token_meta

; rsi = buffer
; returns rax = num_tokens
tokenize:
    push rbp
    mov rbp, rsp
    push rsi
    push rdi

    mov rbx, [rel active_token_ptrs]
    mov r10, [rel active_token_meta]
    xor rcx, rcx  ; count
    mov rdi, rsi  ; buffer

.loop:
    call skip_whitespace
    test al, al
    jz .done
    mov al, [rdi]
    cmp al, '['
    je .array_token

.token_start:
    ; start of token
    mov rax, rdi
    mov dl, [rdi]
    cmp dl, 39  ; '''
    jne .no_label
    mov byte [r10 + rcx], 1
    jmp .store_token
.no_label:
    mov byte [r10 + rcx], 0
.store_token:
    mov [rbx], rax
    add rbx, 8
    inc rcx
    mov al, [rdi]
    cmp al, '"'
    je .string_token
    call find_end
    jmp .after_token

.array_token:
    mov rax, rdi
    mov byte [r10 + rcx], 0
    mov [rbx], rax
    add rbx, 8
    inc rcx
    call consume_array
    jmp .after_token

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
    jmp find_end

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

consume_array:
    push rbp
    mov rbp, rsp
    push rbx

    mov ebx, 1           ; depth counter
    inc rdi              ; skip opening '['
.array_loop:
    mov al, [rdi]
    test al, al
    je .array_done
    cmp al, '"'
    je .array_string
    cmp al, '['
    je .array_open
    cmp al, ']'
    je .array_close
    inc rdi
    jmp .array_loop
.array_open:
    inc ebx
    inc rdi
    jmp .array_loop
.array_close:
    dec ebx
    inc rdi
    test ebx, ebx
    jne .array_loop
    jmp .array_done
.array_string:
    inc rdi
.array_str_loop:
    mov al, [rdi]
    test al, al
    je .array_done
    cmp al, '"'
    je .array_string_end
    cmp al, 92          ; '\\'
    jne .array_str_next
    inc rdi
    mov al, [rdi]
    test al, al
    je .array_done
.array_str_next:
    inc rdi
    jmp .array_str_loop
.array_string_end:
    inc rdi
    jmp .array_loop
.array_done:
    mov al, [rdi]
    pop rbx
    leave
    ret


section .data

section .note.GNU-stack noalloc nobits align=1
