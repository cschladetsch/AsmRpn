%ifndef LOGGING_INC
%define LOGGING_INC

%if LOG_ENABLED
%macro LOG_STR 1
    push rax
    push rdi
    push rsi
    push rdx
    mov rax, 1
    mov rdi, 2
    lea rsi, %1
    mov rdx, %1 %+ _len
    syscall
    pop rdx
    pop rsi
    pop rdi
    pop rax
%endmacro
%else
%macro LOG_STR 1
%endmacro
%endif

%endif
