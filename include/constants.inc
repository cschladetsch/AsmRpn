%ifndef CONSTANTS_INC
%define CONSTANTS_INC

%ifdef ENABLE_LOGGING
%define LOG_ENABLED 1
%else
%define LOG_ENABLED 0
%endif

; Opcodes
OP_PUSH_NUM equ 0
OP_PUSH_VAR equ 1
OP_ADD equ 2
OP_SUB equ 3
OP_MUL equ 4
OP_DIV equ 5
OP_STORE equ 6
OP_CLEAR equ 7
OP_DROP equ 8
OP_SWAP equ 9
OP_DUP equ 10
OP_OVER equ 11
OP_ROT equ 12
OP_DEPTH equ 13
OP_EQ equ 14
OP_GT equ 15
OP_LT equ 16
OP_PUSH_STR equ 17
OP_PUSH_ARRAY equ 18
OP_PUSH_LABEL equ 19
OP_PUSH_TRUE equ 20
OP_PUSH_FALSE equ 21
OP_ASSERT equ 22
OP_SUSPEND equ 23
OP_PUSH_CONT equ 24
OP_RESUME equ 25
OP_REPLACE equ 26

; Literal types
LIT_TYPE_INT equ 0
LIT_TYPE_VAR equ 1
LIT_TYPE_STRING equ 2

; Runtime types
TYPE_INT equ 0
TYPE_STRING equ 1
TYPE_ARRAY equ 2
TYPE_LABEL equ 3
TYPE_CONT equ 4

; Sizes
VAR_SLOT_COUNT equ 256
CONT_LITERAL_MAX equ 64
CONTEXT_STACK_MAX equ 64

%if LOG_ENABLED
log_start db 'LOG: shell started', 10
log_start_len equ $ - log_start
log_prompt db 'LOG: waiting for input', 10
log_prompt_len equ $ - log_prompt
log_literal_prefix db 'LOG literal: '
log_literal_prefix_len equ $ - log_literal_prefix
log_literal_store db 'LOG stored: '
log_literal_store_len equ $ - log_literal_store
log_newline db 10
log_newline_len equ 1
%endif

%endif ; CONSTANTS_INC
