section .text
    global tokenize_entry
    extern tokenize

tokenize_entry:
    mov rsi, rdi
    jmp tokenize

section .note.GNU-stack noalloc nobits align=1
