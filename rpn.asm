; RPN Calculator in x86-64 Assembly (NASM)
; Performs RPN calculations in a REPL

section .data
    prompt db "> ", 0
    prompt_len equ $ - prompt
    newline db 10, 0
    error_msg db "Error", 10, 0
    error_len equ $ - error_msg
    stack_underflow db "Stack underflow", 10, 0
    stack_underflow_len equ $ - stack_underflow
    invalid_input db "Invalid input", 10, 0
    invalid_input_len equ $ - invalid_input

section .bss
    stack resq 100         ; Stack for 100 64-bit integers
    stack_top resq 1       ; Index of top of stack
    buffer resb 256        ; Input buffer
    output_buffer resb 32  ; Buffer for outputting numbers

section .text
    global _start

_start:
    ; Initialize stack top to -1 (empty)
    mov qword [stack_top], -1

repl_loop:
    ; Print prompt
    mov rax, 1              ; sys_write
    mov rdi, 1              ; stdout
    mov rsi, prompt
    mov rdx, prompt_len
    syscall

    ; Read input
    mov rax, 0              ; sys_read
    mov rdi, 0              ; stdin
    mov rsi, buffer
    mov rdx, 256
    syscall

    ; Check if EOF or empty
    cmp rax, 0
    je exit
    cmp byte [buffer], 10   ; Just newline
    je repl_loop

    ; Process the input line
    call process_line

    ; Print the top of stack if not empty
    call print_top

    jmp repl_loop

exit:
    mov rax, 60             ; sys_exit
    xor rdi, rdi
    syscall

; Function to process the input line
process_line:
    push rbp
    mov rbp, rsp

    mov rsi, buffer

.skip_spaces:
    mov al, [rsi]
    cmp al, 0
    je .done
    cmp al, 10
    je .done
    cmp al, 32
    je .skip
    cmp al, 9
    je .skip
    ; Start of token
    mov rcx, rsi  ; start
.find_end:
    inc rsi
    mov al, [rsi]
    cmp al, 0
    je .process
    cmp al, 10
    je .process
    cmp al, 32
    je .process
    cmp al, 9
    je .process
    jmp .find_end
.process:
    push rsi
    mov rdx, rsi
    mov rsi, rcx
    call handle_token
    pop rsi
    jmp .skip_spaces
.skip:
    inc rsi
    jmp .skip_spaces
.done:
    leave
    ret

; Handle a single token
; rsi: start of token, rdx: end of token
handle_token:
    push rbp
    mov rbp, rsp

    ; Null terminate temporarily
    mov al, [rdx]
    push rax
    mov byte [rdx], 0

    ; Check if number
    call is_number
    cmp rax, 1
    je .push_number

    ; Check if operator
    mov al, [rsi]
    cmp al, '+'
    je .add
    cmp al, '-'
    je .subtract
    cmp al, '*'
    je .multiply
    cmp al, '/'
    je .divide
    ; Add more operators if needed

    ; Invalid
    mov rax, 1
    mov rdi, 1
    mov rsi, invalid_input
    mov rdx, invalid_input_len
    syscall
    jmp .done

.push_number:
    call atoi
    call push
    jmp .done

.add:
    call pop
    cmp rax, -1
    je .underflow
    mov rbx, rax
    call pop
    cmp rax, -1
    je .underflow
    add rax, rbx
    call push
    jmp .done

.subtract:
    call pop
    cmp rax, -1
    je .underflow
    mov rbx, rax
    call pop
    cmp rax, -1
    je .underflow
    sub rax, rbx
    call push
    jmp .done

.multiply:
    call pop
    cmp rax, -1
    je .underflow
    mov rbx, rax
    call pop
    cmp rax, -1
    je .underflow
    imul rax, rbx
    call push
    jmp .done

.divide:
    call pop
    cmp rax, -1
    je .underflow
    test rax, rax
    jz .div_zero
    mov rbx, rax
    call pop
    cmp rax, -1
    je .underflow
    cqo
    idiv rbx
    call push
    jmp .done

.div_zero:
    mov rax, 1
    mov rdi, 1
    mov rsi, invalid_input  ; Reuse
    mov rdx, invalid_input_len
    syscall
    jmp .done

.underflow:
    mov rax, 1
    mov rdi, 1
    mov rsi, stack_underflow
    mov rdx, stack_underflow_len
    syscall
    jmp .done

.done:
    pop rax
    mov [rdx], al
    leave
    ret

; Check if token is number (starts with digit or -)
is_number:
    mov al, [rsi]
    cmp al, '-'
    je .yes
    cmp al, '0'
    jb .no
    cmp al, '9'
    ja .no
.yes:
    mov rax, 1
    ret
.no:
    xor rax, rax
    ret

; Convert string to int (simple atoi)
atoi:
    push rbp
    mov rbp, rsp
    push rbx

    xor rax, rax
    xor rbx, rbx
    xor rcx, rcx
    mov cl, [rsi]
    cmp cl, '-'
    jne .loop
    inc rsi
    mov rbx, -1
    jmp .loop

.loop:
    mov cl, [rsi]
    cmp cl, 0
    je .done
    sub cl, '0'
    imul rax, 10
    add rax, rcx
    inc rsi
    jmp .loop

.done:
    test rbx, rbx
    jz .positive
    neg rax
.positive:
    pop rbx
    leave
    ret

; Push to stack
push:
    push rbp
    mov rbp, rsp
    push rbx

    mov rbx, [stack_top]
    inc rbx
    cmp rbx, 100
    jge .overflow  ; But ignore for now
    mov [stack_top], rbx
    mov [stack + rbx*8], rax
    pop rbx
    leave
    ret
.overflow:
    ; Handle overflow, but skip
    pop rbx
    leave
    ret

; Pop from stack, return in rax, -1 if empty
pop:
    push rbp
    mov rbp, rsp
    push rbx

    mov rbx, [stack_top]
    cmp rbx, -1
    je .empty
    mov rax, [stack + rbx*8]
    dec rbx
    mov [stack_top], rbx
    pop rbx
    leave
    ret
.empty:
    mov rax, -1
    pop rbx
    leave
    ret

; Print top of stack
print_top:
    push rbp
    mov rbp, rsp

    mov rbx, [stack_top]
    cmp rbx, -1
    je .done
    mov rax, [stack + rbx*8]
    call itoa
    ; Now output_buffer has the string
    ; Find length
    mov rsi, output_buffer
    xor rdx, rdx
.find_len:
    mov al, [rsi]
    cmp al, 0
    je .print
    inc rdx
    inc rsi
    jmp .find_len
.print:
    mov rax, 1
    mov rdi, 1
    mov rsi, output_buffer
    syscall
    ; Print newline
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
.done:
    leave
    ret

; Convert int to string (simple itoa)
itoa:
    push rbp
    mov rbp, rsp
    push rbx

    mov rdi, output_buffer         ; Destination for the final string
    mov rbx, 0                     ; Flag for negative number

    cmp rax, 0
    jns .positive_num
    mov rbx, 1                     ; Set negative flag
    neg rax                        ; Make number positive for conversion

.positive_num:
    mov rsi, output_buffer + 31    ; Start from end of buffer for digits
    mov byte [rsi], 0              ; Null terminator
    dec rsi

    mov rcx, 10                    ; Divisor

.loop_itoa:
    xor rdx, rdx                   ; Clear rdx for division
    div rcx                        ; rax = rax / 10, rdx = rax % 10
    add dl, '0'                    ; Convert remainder to ASCII digit
    mov [rsi], dl                  ; Store digit
    dec rsi                        ; Move to previous byte
    test rax, rax
    jnz .loop_itoa                 ; Continue if quotient is not zero

    cmp rbx, 1
    jne .copy_string
    mov byte [rsi], '-'
    dec rsi

.copy_string:
    inc rsi                        ; rsi now points to the actual start of the number string
.copy_loop:
    mov al, [rsi]
    mov [rdi], al
    cmp al, 0
    je .done_itoa
    inc rsi
    inc rdi
    jmp .copy_loop

.done_itoa:
    pop rbx
    leave
    ret