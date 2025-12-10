section .data
    prompt db '> '
    prompt_len equ $ - prompt

    global stack
    global stack_top
    global buffer
    global output_buffer
    global variables
    global token_ptrs
    global op_list
    global bytecode

section .bss
    stack resq 100         ; Stack for 100 64-bit integers
    stack_top resq 1       ; Index of top of stack
    buffer resb 256        ; Input buffer
    output_buffer resb 32  ; Buffer for outputting numbers
    variables resq 256     ; Variables storage
    token_ptrs resq 100    ; Array of token pointers
    op_list resq 100       ; Operation list
    bytecode resq 100      ; Bytecode array

    version db "1.0.0", 0
    version_len equ $ - version
    prelude db "Built: "
    prelude_len equ $ - prelude
    build_date db "2025-12-10T13:32:48Z", 0
    build_date_len equ $ - build_date
    version_str db " version "
    version_str_len equ $ - version_str
    newline db 10

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
    lea rdx, [rel stack_top]
    mov qword [rdx], -1
    ; Initialize variables pointer
    lea r15, [rel variables]
    ; Zero variables
    mov rcx, 256
    mov rdi, r15
    xor rax, rax
    rep stosq

    ; Print prelude
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel prelude]
    mov rdx, prelude_len
    syscall

    ; Print build date
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel build_date]
    mov rdx, build_date_len
    syscall

    ; Print " version "
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel version_str]
    mov rdx, version_str_len
    syscall

    ; Print version
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel version]
    mov rdx, version_len
    syscall

    ; Print newline
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel newline]
    mov rdx, 1
    syscall

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
    ; Null terminate
    mov byte [buffer + rax], 0

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
    call translate  ; bytecode, rax = bc_count

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
