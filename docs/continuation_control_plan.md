# Continuation Control Plan

## Immediate goals
1. Refine `execute_continuation_impl` to run a literal under its captured scope without printing and to report the stack-depth delta of the literal’s results.
2. Add stack snapshot helpers so continuation outputs can be formatted for tests (e.g. `[42]`, `[1, 2]`).
3. Implement runtime handlers for `OP_SUSPEND`, `OP_RESUME`, and `OP_REPLACE` that coordinate with the context stack.

## Steps
1. **execute_continuation_impl**
   - Accept literal index and original stack depth.
   - Copy captured scope (`cont_literal_values/types`) into `variables`/`var_types`.
   - Execute literal bytecode in the continuation workspace without printing.
   - Leave literal outputs on the shared stack and return the new depth to callers.
   - Restore caller scope before returning.

2. **Stack utilities**
   - `format_stack_slice(start_depth)` → build `[a, b, c]` textual output from stack entries.
   - `truncate_stack(depth)` → drop stack entries above `depth` when replacing literal output with formatted string.

3. **`OP_SUSPEND` (`&`)**
   - Pop literal (TYPE_CONT) and push current context via `push_context`.
   - Capture stack depth, run literal via `execute_continuation_impl`.
   - Use `format_stack_slice` to produce the expected test output; replace literal on stack with formatted string.
   - Handle errors by popping context and reporting “Suspend: expected continuation” when necessary.

4. **`OP_RESUME` (`...`)**
   - Pop context via `pop_context`; if none, emit `Resume: not in continuation`.
   - Restore instruction pointer/count so execution resumes after the original `&`.
   - Leave the data stack unchanged.

5. **`OP_REPLACE` (`!`)**
   - Pop context; if none, emit `Replace: expected continuation`.
   - Replace current execution state with popped context (tail-call semantics).

6. **Testing**
   - After each stage, run `tests/run_tests.sh`, focusing on continuation cases and ensuring previously green tests remain unaffected.
