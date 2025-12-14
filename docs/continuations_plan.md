# Continuations & Dual Stack Plan

## Goals
1. Introduce a dual-stack runtime: data stack (operands) and context stack (continuations/frames).
2. Support continuation literals using `{ ... }` syntax.
3. Provide control-flow words (`resume`, `replace`, `suspend`, `>ctx`, `ctx>`).

## Phases
### Phase 1 – Dual Stacks
- Add context stack storage/helpers, show it in the REPL, and implement `>ctx` / `ctx>`.

### Phase 2 – Continuation Literals
- Tokenizer treats `{...}` as single tokens, parser emits `OP_PUSH_CONT`, executor can print/move them.

### Phase 3 – Control Flow
- Implement `resume`, `replace`, `suspend` by reusing tokenizer/parser/translator in a scratch workspace.
- `resume`: run continuation inline.
- `replace`: swap current execution with continuation.
- `suspend`: capture remaining ops as a continuation, push it, halt current run.

## Testing
- Tokenizer/parser unit tests for `{...}`.
- Executor tests for `resume`, `replace`, `suspend`, including type errors.
- Integration tests verifying context stack display and transfer words.
- Documentation updates describing syntax and new words.
