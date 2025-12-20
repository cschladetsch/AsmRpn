
section .text
%include "constants.inc"
%include "stack_ops.asm"
%include "op_handlers.asm"
%include "strings.asm"
%include "execute_core.asm"
%include "execute_continuation.asm"
%include "print_stack.asm"