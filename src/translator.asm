section .text
    global translate
    extern bytecode
    extern op_list

; rdi = op_list, rsi = op_count
; returns rax = bc_count (same as op_count for now)
translate:
    push rbp
    mov rbp, rsp
    push rsi
    push rdi
    push rbx

    mov rbx, bytecode
    mov rcx, rsi
    test rcx, rcx
    jz .done

.loop:
    mov rax, [rdi]
    mov [rbx], rax
    mov rax, [rdi+8]
    mov [rbx+8], rax
    add rdi, 16
    add rbx, 16
    dec rcx
    jnz .loop

.done:
    mov rax, rsi  ; return op_count
    pop rbx
    pop rdi
    pop rsi
    leave
    ret

section .note.GNU-stack noalloc nobits align=1
