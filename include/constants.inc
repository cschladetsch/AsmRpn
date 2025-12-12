%ifndef CONSTANTS_INC
%define CONSTANTS_INC

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
OP_PUSH_STR equ 10
OP_PUSH_ARRAY equ 11
OP_DEPTH equ 12

; Literal types
LIT_TYPE_INT equ 0
LIT_TYPE_VAR equ 1
LIT_TYPE_STRING equ 2

; Runtime types
TYPE_INT equ 0
TYPE_STRING equ 1
TYPE_ARRAY equ 2

%endif ; CONSTANTS_INC
