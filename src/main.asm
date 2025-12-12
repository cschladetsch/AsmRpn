section .data
    prompt db 'λ '
    prompt_len equ $ - prompt
    enable_color db 1
    no_color_arg db "--no-color", 0
    color_arg db "--color", 0

%define BUILD_DATE "2025-12-10T13:32:48Z"
    version db "1.0.0", 0
    version_len equ $ - version
    prelude db "Built: "
    prelude_len equ $ - prelude
    build_date db "2025-12-12T12:41:11Z", 0
    build_date_len equ $ - build_date
    version_str db " version "
    version_str_len equ $ - version_str
    newline db 10

    global stack
    global stack_top
    global stack_types
    global buffer
    global output_buffer
    global variables
    global var_types
    global token_ptrs
    global op_list
    global bytecode
    global enable_color
    global maybe_write_color

section .bss
    stack resq 10000        ; Stack for 10000 64-bit values
    stack_top resq 1        ; Index of top of stack
    stack_types resb 10000  ; Type per stack entry
    buffer resb 256        ; Input buffer
    output_buffer resb 32  ; Buffer for outputting numbers
    variables resq 256     ; Variables storage
    var_types resb 256     ; Variable types
    token_ptrs resq 100    ; Array of token pointers
    op_list resq 100       ; Operation list
    bytecode resq 100      ; Bytecode array
    tty_attr resb 64

section .text
    global _start
    %include "constants.inc"
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
    extern string_offset

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
    ; Zero variable types
    mov rcx, 256
    lea rdi, [rel var_types]
    xor rax, rax
    rep stosb
    mov qword [rel string_offset], 0

    ; Default color state based on tty detection
    call detect_tty

    ; Parse command line args for color overrides
    mov rbx, rsp
    mov rcx, [rbx]
    cmp rcx, 1
    jle .args_done
    lea rbx, [rbx + 16]
    dec rcx
.args_loop:
    mov rdi, [rbx]
    push rcx
    lea rsi, [rel no_color_arg]
    call strings_equal
    pop rcx
    cmp rax, 1
    jne .check_color
    mov byte [rel enable_color], 0
    jmp .next_arg
.check_color:
    mov rdi, [rbx]
    push rcx
    lea rsi, [rel color_arg]
    call strings_equal
    pop rcx
    cmp rax, 1
    jne .next_arg
    mov byte [rel enable_color], 1
.next_arg:
    add rbx, 8
    loop .args_loop
.args_done:

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
    ; Print white (if enabled)
    lea rsi, [rel white]
    mov rdx, white_len
    call maybe_write_color
    ; Print prompt
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel prompt]
    mov rdx, prompt_len
    syscall
    ; Print reset
    lea rsi, [rel reset]
    mov rdx, reset_len
    call maybe_write_color

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

; Write color sequence only if enabled
; expects rsi = buffer, rdx = len
maybe_write_color:
    push rbp
    mov rbp, rsp
    cmp byte [rel enable_color], 0
    je .skip
    push rcx
    push r11
    mov rax, 1
    mov rdi, 1
    syscall
    pop r11
    pop rcx
.skip:
    leave
    ret

; Compare null-terminated strings (rdi, rsi). Returns 1 if equal.
strings_equal:
    push rbp
    mov rbp, rsp
.cmp_loop:
    mov al, [rdi]
    mov dl, [rsi]
    cmp al, dl
    jne .not_equal
    test al, al
    je .equal
    inc rdi
    inc rsi
    jmp .cmp_loop
.not_equal:
    xor rax, rax
    leave
    ret
.equal:
    mov rax, 1
    leave
    ret

; Detect if stdout is a TTY using ioctl(TCGETS)
TCGETS equ 0x5401
detect_tty:
    push rbp
    mov rbp, rsp
    mov rax, 16           ; sys_ioctl
    mov rdi, 1            ; stdout
    mov rsi, TCGETS
    lea rdx, [rel tty_attr]
    syscall
    cmp rax, 0
    jl .not_tty
    mov byte [rel enable_color], 1
    jmp .done
.not_tty:
    mov byte [rel enable_color], 0
.done:
    leave
    ret
