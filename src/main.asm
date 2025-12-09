section .data
    prompt db '> '
    prompt_len equ $ - prompt

section .bss
    global stack
    global stack_top
    global buffer
    global output_buffer
    global variables
    global token_ptrs
    global op_list
    global bytecode
    stack resq 100         ; Stack for 100 64-bit integers
    stack_top resq 1       ; Index of top of stack
    buffer resb 256        ; Input buffer
    output_buffer resb 32  ; Buffer for outputting numbers
    variables resq 256     ; Variables storage
    token_ptrs resq 100    ; Array of token pointers
    op_list resq 100       ; Operation list
    bytecode resq 100      ; Bytecode array

section .text
    global _start
    extern tokenize
    extern parse_tokens
    extern translate
    extern execute
    extern push
    extern pop
    extern print_stack
    extern white
    extern white_len
    extern reset
    extern reset_len
    extern temp2

_start:
    ; Initialize stack top to -1 (empty)
    mov qword [stack_top], -1
    ; Initialize variables pointer
    mov r15, variables
    mov rax, output_buffer
    mov rax, stack
    mov [rax], rax
    ; Zero variables
    mov rcx, 256
    mov rdi, r15
    xor rax, rax
    rep stosq

repl_loop:
    ; Print white
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel white]
    mov rdx, white_len
    syscall
    ; Print prompt
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel prompt]
    mov rdx, prompt_len
    syscall
    ; Print reset
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel reset]
    mov rdx, reset_len
    syscall

    ; Read input
    mov rax, 0
    mov rdi, 0
    mov rsi, buffer
    mov rdx, 256
    syscall
    cmp rax, 0
    je exit
    ; Null terminate and remove trailing \r and \n
    mov byte [buffer + rax], 0
    mov rcx, rax
    dec rcx
    cmp byte [buffer + rcx], 10
    jne .done
    mov byte [buffer + rcx], 0
    cmp rcx, 0
    je .done
    dec rcx
    cmp byte [buffer + rcx], 13
    jne .done
    mov byte [buffer + rcx], 0
.done:

    ; Tokenize
    mov rsi, buffer
    call tokenize  ; rax = num_tokens

    ; Parse
    mov rdi, token_ptrs
    mov rsi, rax
    call parse_tokens  ; rax = op_count

    ; Translate
    mov rdi, op_list
    mov rsi, rax
    call translate  ; rax = bc_count

    ; Execute
    mov rdi, bytecode
    mov rsi, rax
    call execute

    ; Print stack
    call print_stack

    jmp repl_loop

exit:
; Exit on EOF or error
    mov rax, 60
    xor rdi, rdi
    syscall
