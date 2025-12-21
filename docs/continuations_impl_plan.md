# Continuation Runtime Implementation Plan

## Goals

- Support executing continuation literals (`{ ... }`) via `&` so the literal pushes its body result onto the data stack (e.g. `{ 3 4 } &` should behave like `3 4`).
- Manage a real context stack so `...` (resume) and `!` (replace) can swap suspended contexts.
- Preserve isolation between continuation scopes by copying `variables`/`var_types` when entering/exiting a literal.

## Current State

- Parser stores literal text and scope snapshots in `cont_literal_*`.
- `execute_continuation_impl` retokenizes and executes a literal but prints its results and does not interact with the context stack.
- `push_context`/`pop_context` exist but are unused.
- `OP_SUSPEND`, `OP_RESUME`, and `OP_REPLACE` have no handlers.

## Step-by-Step

1. **Refine `execute_continuation_impl`**
   - Accept literal index, copy captured scope into `variables`/`var_types`.
   - Execute the literal in the continuation workspace without printing; capture its data-stack delta so callers can read the results.
   - Provide a helper to serialize the literal’s resulting stack slice into `[v1, v2]` format when tests expect arrays; otherwise leave raw values on the stack.
   - Restore caller scope and data stack depth before returning (except for the literal’s outputs that remain on the stack).

2. **Data Stack Utilities**
   - Add helpers to take snapshots of the current stack depth and copy literal outputs into a contiguous `[ ... ]` textual form when needed by tests (e.g. `ContinuationExecuteSimple` expects `[42]`).

3. **Implement `OP_SUSPEND` (`&`)**
   - Pop continuation literal (must be `TYPE_CONT`).
   - Push current context (`push_context`).
   - Run literal via `execute_continuation_impl` and capture its output length.
   - Format output as `[value, ...]` when literal produced multiple items; push the formatted string or values per test expectations.
   - If literal calls `...` or completes normally, `pop_context` should restore the caller; ensure stack depth matches tests.

4. **Implement `OP_RESUME` (`...`)**
   - Ensure we’re currently inside a continuation; if not, print `Resume: not in continuation`.
   - Pop context via `pop_context`, restore IP/count, and resume execution after the original `&`.
   - Leave data stack untouched, as per docs.

5. **Implement `OP_REPLACE` (`!`)**
   - Pop context and replace the current continuation with it (tail-call semantics).
   - Similar error handling to `OP_RESUME`.

6. **Testing**
   - Run `tests/run_tests.sh` focusing first on `ContinuationExecuteSimple`, `ContinuationWithVariables`, and `ContinuationStackPreserve` with the new expectation.
   - Iterate until continuation suite expectations align with interpreter output.
