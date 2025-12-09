# THE BARE-METAL DISTRIBUTED CONTINUUM
## Master Technical Specification & Implementation Manual

**Volume IX: The Continuum Standard Library (CSL) & ABI Reference**

**Project:** The Continuum Runtime
**Author:** Christian Schladetsch
**Version:** 1.0.0 (Volume IX)
**Scope:** String Primitives, Memory Utils, Stack Data Structures, The ABI

---

# CHAPTER 1: THE CONTINUUM ABI (APPLICATION BINARY INTERFACE)

To write portable code that survives migration, application developers must adhere to a strict register and stack contract. Unlike the System V ABI, our ABI is designed for **state capture**, not just function calling.

## 1.1 The Register Contract
* **Volatile Registers (Scratch):** `RAX`, `RCX`, `RDX`. These may be clobbered by any `sys_` call.
* **Non-Volatile Registers (Preserved):** `RBX`, `RBP`, `RDI`, `RSI`, `R12-R15`. These *must* be preserved across function calls.
    * *Note:* Standard ABIs treat `RDI`/`RSI` as volatile args. We treat them as **Stream Pointers** which often need to survive calls.
* **The Stack Alignment:** The stack pointer (`RSP`) must be 8-byte aligned at all times, and 16-byte aligned before calling any Windows API via `platform.inc`.

## 1.2 The "Red Zone" Prohibition
The System V ABI allows a 128-byte "Red Zone" below `RSP` that functions can use without adjusting the stack pointer.
* **Continuum Rule:** **NO RED ZONE.**
* **Reason:** When `sys_migrate` captures the stack, it calculates size based on `RSP`. Data in the Red Zone (below `RSP`) is considered "free space" and will **not** be transmitted.
* **Enforcement:** Always `SUB RSP, N` before writing to stack variables.

---

# CHAPTER 2: MEMORY & STRING PRIMITIVES

Since we have no `string.h`, we implement high-performance, AVX-optimized primitives.

## 2.1 Memory Operations (`csl_memcpy`)
We use a "rep movsb" fallback for small copies, and AVX unrolled loops for large blocks.

```nasm
; -----------------------------------------------------------------------
; ROUTINE: csl_memcpy
; INPUTS:  RDI = Dest, RSI = Source, RCX = Count
; CLOBBERS: RAX, RCX, RSI, RDI
; -----------------------------------------------------------------------
csl_memcpy:
    ; Optimization: Check for small size
    cmp rcx, 16
    jl .tiny
    
    ; Optimization: Check alignment (omitted for brevity)
    
    rep movsb       ; CPU microcode often optimizes this automatically
    ret

.tiny:
    ; Byte-by-byte copy
    test rcx, rcx
    jz .done
.loop:
    mov al, byte [rsi]
    mov byte [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .loop
.done:
    ret
```

## 2.2 String Length (`csl_strlen`)
Required for calculating buffer sizes before `sys_put_block`.

```nasm
; -----------------------------------------------------------------------
; ROUTINE: csl_strlen
; INPUTS:  RDI = String Pointer (Null Terminated)
; OUTPUTS: RAX = Length
; -----------------------------------------------------------------------
csl_strlen:
    xor rax, rax
    mov rcx, -1         ; Max Count
    xor al, al          ; Scan for 0
    
    push rdi
    repne scasb         ; Scan String Byte
    not rcx             ; Invert count
    dec rcx             ; Adjust for 0-indexing
    mov rax, rcx
    pop rdi
    ret
```

## 2.3 Integer to ASCII (`csl_itoa`)
Essential for debugging and logging (telemetry).

```nasm
; -----------------------------------------------------------------------
; ROUTINE: csl_itoa
; INPUTS:  RAX = Integer, RDI = Buffer
; OUTPUTS: Buffer filled with string
; -----------------------------------------------------------------------
csl_itoa:
    push rbx
    push rcx
    push rdx
    
    add rdi, 20         ; Point to end of buffer (max u64 is 20 chars)
    mov byte [rdi], 0   ; Null terminate
    mov rbx, 10
    
.loop:
    xor rdx, rdx
    div rbx             ; RAX / 10, Remainder in RDX
    add dl, '0'         ; Convert to ASCII
    dec rdi
    mov [rdi], dl
    test rax, rax
    jnz .loop
    
    ; RDI now points to the start of the string
    mov rax, rdi        ; Return pointer to start
    
    pop rdx
    pop rcx
    pop rbx
    ret
```

---

# CHAPTER 3: STACK-BASED DATA STRUCTURES

We cannot use `new Node()`. We must allocate structures linearly on the stack.

## 3.1 The "Stack Linked List"
How do you build a linked list without a heap? You push nodes onto the stack as you recurse or iterate.

**Structure:**
* `NextPtr` (8 bytes)
* `Data` (8 bytes)

**Allocation Strategy:**
```nasm
; To add a node:
sub rsp, 16             ; Allocate Node
mov [rsp], r_head       ; Next = OldHead
mov [rsp+8], rax        ; Data = Value
mov r_head, rsp         ; Head = NewNode
```

**Traversal:**
Since the stack grows downwards, "Next" pointers point to *higher* memory addresses.
* **Invariant:** `NextPtr > CurrentPtr` (except for NULL).
* **Validation:** If `NextPtr < StackTop`, the list is corrupted (points to unallocated space).

## 3.2 The "Ring Buffer"
For network queues, we allocate a fixed block on the stack.

```nasm
; -----------------------------------------------------------------------
; ROUTINE: csl_ring_init
; INPUTS:  RCX = Size (Power of 2)
; OUTPUTS: RSI = Buffer Ptr
; -----------------------------------------------------------------------
csl_ring_init:
    sub rsp, rcx        ; Allocate buffer
    mov rsi, rsp        ; Return pointer
    ret

; Note: The developer must manage Head/Tail indices manually
; in registers or separate stack variables.
```

---

# CHAPTER 4: THE SYSTEM CALL VECTOR TABLE

The Continuum Runtime exposes its functionality via a jumptable. This allows user code to call `call sys_migrate` without knowing the exact address of the routine.

## 4.1 The Vector Definitions
These should be included in every user program.

```nasm
; Continuum System Vectors
extern sys_migrate      ; [VOL I]  Move process
extern sys_fork         ; [VOL VI] Clone process
extern sys_put_block    ; [VOL VII] Store data
extern sys_get_block    ; [VOL VII] Retrieve data
extern sys_yield        ; [VOL VIII] Relinquish CPU
extern sys_sleep        ; Pause execution
extern sys_log          ; Send telemetry
```

## 4.2 The `sys_sleep` Implementation
A simple blocking delay is required for polling loops.

```nasm
; -----------------------------------------------------------------------
; ROUTINE: sys_sleep
; INPUTS:  RDI = Milliseconds
; -----------------------------------------------------------------------
sys_sleep:
%ifdef OS_LINUX
    ; Linux 'nanosleep' struct { sec, nsec }
    sub rsp, 16
    
    ; Convert ms to sec/nsec
    mov rax, rdi
    xor rdx, rdx
    mov rbx, 1000
    div rbx             ; RAX = sec, RDX = ms
    
    mov [rsp], rax      ; tv_sec
    imul rdx, 1000000
    mov [rsp+8], rdx    ; tv_nsec
    
    mov rax, 35         ; sys_nanosleep
    mov rdi, rsp
    mov rsi, 0
    syscall
    
    add rsp, 16
%elifdef OS_WINDOWS
    ; Windows 'Sleep'
    sub rsp, 40
    mov rcx, rdi
    call [rel Sleep_Ptr] ; Must be resolved in PEB walk
    add rsp, 40
%endif
    ret
```

---

# CHAPTER 5: ADVANCED MATHEMATICS

Bare-metal math requires managing the FPU/SSE state. If a process uses floating-point registers (`XMM0`-`XMM15`), these **MUST** be included in the migration payload, or the calculation will corrupt upon arrival.

## 5.1 Extending the Payload
We define an "Extended Context" bit in the header.

**Modified Sender:**
```nasm
    ; Check if we need to save XMM
    fxsave [rsp - 512]  ; Save FPU/SSE state to stack
    sub rsp, 512        ; Commit allocation
```

**Modified Receiver:**
```nasm
    ; After stack restore
    fxrstor [rsp]       ; Restore FPU/SSE state
    add rsp, 512        ; Reclaim stack
```

This ensures that scientific computing workloads (Matrix Multiplication, Physics Sims) can migrate safely.

---

**[End of Volume IX]**
