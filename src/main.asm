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
    build_date db "2025-12-13T07:56:38Z", 0
    build_date_len equ $ - build_date
    version_str db " version "
    version_str_len equ $ - version_str
    newline db 10

section .bss
    statbuf resb 144  ; struct stat is 144 bytes
    input_buffer resb 1024
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
    extern strings_equal
    extern white
    extern white_len
    extern parse_tokens
    extern translate
    extern execute
    extern maybe_write_color
_start:
    ; Initialize stack top to 0 (empty)
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
    ; Detect if stdout is tty
    call detect_tty
    mov [rel enable_color], al
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
    ; Read input
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel input_buffer]
    mov rdx, 1024
    syscall
    ; If EOF, exit
    test rax, rax
    jz .exit
    ; Null terminate
    lea rsi, [rel input_buffer]
    add rsi, rax
    mov byte [rsi - 1], 0  ; assuming newline
    ; Parse and execute
    lea rsi, [rel input_buffer]
    call tokenize
    mov rsi, rax            ; token count
    lea rdi, [rel token_ptrs]
    call parse_tokens
    test rax, rax
    js .input_error
    mov rsi, rax            ; op count
    lea rdi, [rel op_list]
    call translate
    mov rsi, rax            ; bytecode count
    lea rdi, [rel bytecode]
    call execute
    call print_stack
    jmp repl_loop
.input_error:
    jmp repl_loop
.exit:
    mov rax, 60
    xor rdi, rdi
    syscall

; Detect if stdout is tty, return al = 1 if yes, 0 if no
detect_tty:
    push rbp
    mov rbp, rsp
    ; fstat(1, &statbuf)
    mov rax, 5  ; sys_fstat
    mov rdi, 1  ; fd 1
    lea rsi, [rel statbuf]
    syscall
    test rax, rax
    js .not_tty  ; error, assume not tty
    ; check st_mode & S_IFCHR (0x2000)
    mov rax, [rel statbuf + 24]  ; st_mode is at offset 24
    and rax, 0x2000
    test rax, rax
    jz .not_tty
    mov al, 1
    leave
    ret
.not_tty:
    xor al, al
    leave
    ret

section .note.GNU-stack noalloc nobits align=1
