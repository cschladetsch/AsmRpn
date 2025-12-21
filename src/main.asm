section .data
    prompt db 'λ '
    prompt_len equ $ - prompt
    enable_color db 1
    global stdin_is_tty
    stdin_is_tty db 0
    no_color_arg db "--no-color", 0
    color_arg db "--color", 0
%define BUILD_DATE "2025-12-10T13:32:48Z"
    version db "1.0.0", 0
    version_len equ $ - version
    prelude db "Built: "
    prelude_len equ $ - prelude
    build_date db "2025-12-22T05:53:00Z", 0
    build_date_len equ $ - build_date
    version_str db " version "
    version_str_len equ $ - version_str
    newline db 10
    white db 0x1b, '[37m'
    white_len equ $ - white
    global active_token_ptrs
    global active_token_meta
    global active_op_list
    global active_bytecode
    active_token_ptrs dq token_ptrs
    active_token_meta dq token_meta
    active_op_list dq op_list
    active_bytecode dq bytecode

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
    global token_meta
    global context_ips
    global context_counts
    global context_scope_values
    global context_scope_types
    global context_stack_top
    global cont_literal_offsets
    global cont_literal_lengths
    global cont_literal_values
    global cont_literal_types
    global cont_literal_count
    global cont_storage
    global cont_storage_offset
    global continuation_signal
    global in_continuation
    global continuation_replace_index
    global cont_build_buffer
section .bss
    stack resq 10000        ; Stack for 10000 64-bit values
    stack_top resq 1        ; Index of top of stack
    stack_types resb 10000  ; Type per stack entry
    buffer resb 1024        ; String buffer
    buffer_offset resq 1
    global buffer_offset
    string_pool resb 1024
    output_buffer resb 32  ; Buffer for outputting numbers
    variables resq 256     ; Variables storage
    var_types resb 256     ; Variable types
    token_ptrs resq 100    ; Array of token pointers
    token_meta resb 100    ; Metadata per token (flags)
    op_list resq 100       ; Operation list
    bytecode resq 100      ; Bytecode array
    tty_attr resb 64
    global cont_token_ptrs
    global cont_token_meta
    global cont_op_list
    global cont_bytecode
    cont_token_ptrs resq 256
    cont_token_meta resb 256
    cont_op_list resq 256
    cont_bytecode resq 256
    context_ips resq CONTEXT_STACK_MAX
    context_counts resq CONTEXT_STACK_MAX
    context_scope_values resq CONTEXT_STACK_MAX * VAR_SLOT_COUNT
    context_scope_types resb CONTEXT_STACK_MAX * VAR_SLOT_COUNT
    context_stack_top resq 1
    cont_literal_offsets resq CONT_LITERAL_MAX
    cont_literal_lengths resd CONT_LITERAL_MAX
    cont_literal_values resq CONT_LITERAL_MAX * VAR_SLOT_COUNT
    cont_literal_types resb CONT_LITERAL_MAX * VAR_SLOT_COUNT
    cont_literal_count resq 1
    cont_storage resb 65536
    cont_storage_offset resq 1
    continuation_signal resq 1
    in_continuation resb 1
    continuation_replace_index resq 1
    global cont_input_buffer
    cont_input_buffer resb 1024
    cont_build_buffer resb 1024
section .text
    global _start
%include "constants.inc"
%include "logging.inc"
    extern tokenize
    extern parse_tokens
    extern translate
    extern execute
    extern push
    extern pop
    extern print_stack
    extern reset
    extern reset_len
    extern temp2
    extern string_offset
    extern strings_equal
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
    mov qword [rel context_stack_top], -1
    mov qword [rel cont_literal_count], 0
    mov qword [rel cont_storage_offset], 0
    mov qword [rel continuation_signal], 0
    mov byte [rel in_continuation], 0
    ; Detect if stdout is tty
    mov edi, 1
    call detect_tty
    mov [rel enable_color], al
    ; Default color state based on tty detection
    mov edi, 1
    call detect_tty
    ; Detect if stdin is tty
    mov edi, 0
    call detect_tty
    mov [rel stdin_is_tty], al
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
    ; Initialize stack top
    mov qword [rel stack_top], 0
    ; Initialize buffer offset
    mov qword [rel buffer_offset], 0
    %if LOG_ENABLED
    LOG_STR log_start
    %endif
repl_loop:
    ; Only show prompt when stdin is a tty
    cmp byte [rel stdin_is_tty], 0
    je .skip_prompt
    ; Print white (if enabled)
    lea rsi, [rel white]
    cmp byte [rel enable_color], 1
    jne .no_white
    mov rax, 1
    mov rdi, 1
    mov rdx, white_len
    syscall
.no_white:
    ; Print prompt
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel prompt]
    mov rdx, prompt_len
    syscall
    %if LOG_ENABLED
    LOG_STR log_prompt
    %endif
.skip_prompt:
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
    mov qword [rel active_token_ptrs], token_ptrs
    mov qword [rel active_token_meta], token_meta
    mov qword [rel active_op_list], op_list
    mov qword [rel active_bytecode], bytecode
    lea rsi, [rel input_buffer]
    call tokenize
    mov rcx, rax
    lea rdi, [rel token_ptrs]
    lea rsi, [rel token_ptrs]
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
    ; fstat(fd, &statbuf)
    mov rax, 5  ; sys_fstat
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
