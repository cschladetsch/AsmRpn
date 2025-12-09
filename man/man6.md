# THE BARE-METAL DISTRIBUTED CONTINUUM
## Master Technical Specification & Implementation Manual

**Volume VI: Distributed Parallelism & The Operator Console**

**Project:** The Continuum Runtime
**Author:** Christian Schladetsch
**Version:** 1.0.0 (Volume VI)
**Scope:** Distributed Forking, Cluster Discovery, CLI Implementation

---

# CHAPTER 1: DISTRIBUTED FORKING ("CELL MITOSIS")

So far, we have discussed moving a process ($Node_A \to Node_B$). Now we discuss cloning a process ($Node_A \to \{Node_A, Node_B\}$). This enables massive parallel processing: a single seed program can replicate itself across 1,000 cores to perform a distributed calculation.

## 1.1 The `sys_dist_fork` Concept
Standard Unix `fork()` duplicates the process on the *same* kernel. The Continuum `sys_dist_fork()` duplicates the process onto a *remote* kernel.

### The Algorithm
1.  **Snapshot:** The parent captures its stack state.
2.  **Connect:** The parent connects to a target node.
3.  **Transmit:** The parent sends its state (just like migration).
4.  **Diverge:**
    * **Parent:** Returns `0` in `RAX`. Continues locally.
    * **Child (Remote):** Wakes up. Returns `1` in `RAX`.
5.  **Execution:** Both nodes now run the same code but with different IDs.

## 1.2 ASM Implementation

```nasm
; -----------------------------------------------------------------------
; ROUTINE: sys_dist_fork
; INPUTS:  RDI = Target IP Address
; OUTPUTS: RAX = 0 (Parent), 1 (Child)
; -----------------------------------------------------------------------
sys_dist_fork:
    ; 1. Preserve Context
    pushfq
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    ; Note: We do NOT push RAX yet. We need to manipulate it later.
    
    ; 2. Connect to Target (Logic omitted)
    ; Assume R12 holds the socket FD.
    
    ; 3. Send Snapshot
    ; (Standard sys_migrate logic, but we DO NOT exit at the end)
    call send_snapshot_to_r12
    
    ; 4. Parent Logic
    mov rax, 0          ; Parent gets 0
    pop r15             ; Restore context
    ; ...
    popfq
    ret

; -----------------------------------------------------------------------
; REMOTE ENTRY POINT (Child)
; -----------------------------------------------------------------------
resume_child:
    ; The stack is restored on the remote machine.
    ; We are inside the 'sys_dist_fork' logic of the ghost.
    
    ; 1. Restore Context
    pop r15
    ; ...
    popfq
    
    ; 2. Set Return Value
    mov rax, 1          ; Child gets 1
    
    ; 3. Return to caller
    ret
```

## 1.3 Usage Example: The "Viral" Counter
This code recursively infects a cluster.

```nasm
viral_start:
    ; Try to fork to Node B
    mov rdi, [rel node_b_ip]
    call sys_dist_fork
    
    cmp rax, 1
    je .i_am_child
    
.i_am_parent:
    ; I stay here and calculate lower half
    call perform_heavy_math_low
    jmp .done

.i_am_child:
    ; I am on Node B!
    ; I calculate upper half
    call perform_heavy_math_high
    
.done:
    ; Merge results (via token ring or DB)
```

---

# CHAPTER 2: THE CLUSTER MAP (DISCOVERY)

Hardcoding IP addresses is brittle. A robust distributed system needs a **Peer Discovery Protocol**.

## 2.1 The Gossip Protocol (UDP)
Each node maintains a generic table of known peers in `.bss`.
`peer_table: resq 256  ; Array of 256 IP Addresses`

Every 5 seconds, a node sends a UDP broadcast:
`I AM ALIVE: <My_IP>`

## 2.2 The Listener Logic
The system runs a non-blocking UDP listener alongside the TCP migration listener.

```nasm
; -----------------------------------------------------------------------
; ROUTINE: handle_udp_gossip
; -----------------------------------------------------------------------
handle_udp_gossip:
    ; 1. RecvFrom
    ; 2. Parse IP from payload
    ; 3. Scan 'peer_table' for duplicates
    ; 4. If new, add to table & increment [peer_count]
    ret
```

## 2.3 Integration with Migration
When `sys_migrate` is called with `RDI = 0` (Auto-Target), the runtime picks a random IP from `peer_table`.

```nasm
get_random_peer:
    rdrand rax          ; Hardware Random Number
    xor rdx, rdx
    mov rbx, [rel peer_count]
    div rbx             ; RDX = Random Index
    
    mov rax, [rel peer_table + rdx*8] ; Return IP
    ret
```

---

# CHAPTER 3: THE OPERATOR CONSOLE (CLI)

How do we control this headless beast? We build a pure ASM shell that listens on Port 23 (Telnet-style).

## 3.1 The Command Interpreter
We parse ASCII input character by character.

**Commands:**
* `STAT`: Dump CPU registers and Stack depth.
* `PEERS`: List connected nodes.
* `KILL`: Terminate the runtime.
* `EXEC <hex>`: Inject raw shellcode (Dangerous!).

## 3.2 String Parsing in ASM

```nasm
; -----------------------------------------------------------------------
; ROUTINE: shell_loop
; -----------------------------------------------------------------------
shell_loop:
    ; 1. Print Prompt "> "
    call shell_print_prompt
    
    ; 2. Read Line
    call shell_read_line
    
    ; 3. Compare Input
    lea rsi, [rel cmd_buffer]
    
    ; Check STAT
    lea rdi, [rel str_stat]
    call strcmp
    je .do_stat
    
    ; Check KILL
    lea rdi, [rel str_kill]
    call strcmp
    je .do_kill
    
    jmp shell_loop

.do_stat:
    ; Convert RSP to Hex String and print
    mov rax, rsp
    call print_hex
    jmp shell_loop
```

---

# CHAPTER 4: PERFORMANCE OPTIMIZATIONS

Copying 1MB stacks using `mov` loops is slow. We must unlock the CPU's vector units.

## 4.1 AVX2 Memory Copy
We use 256-bit YMM registers to copy 32 bytes per cycle.

```nasm
; -----------------------------------------------------------------------
; ROUTINE: fast_memcpy_avx
; INPUTS:  RDI = Dest, RSI = Source, RCX = Count
; -----------------------------------------------------------------------
fast_memcpy_avx:
    cmp rcx, 32
    jl .fallback
    
.loop_avx:
    vmovdqu ymm0, [rsi]     ; Load 32 bytes
    vmovdqu [rdi], ymm0     ; Store 32 bytes
    add rsi, 32
    add rdi, 32
    sub rcx, 32
    cmp rcx, 32
    jge .loop_avx
    
.fallback:
    ; Handle remaining bytes
    rep movsb
    ret
```

## 4.2 Zero-Page Deduplication
Before sending the stack, we check for 4KB pages that are entirely zero.
1.  Scan Stack in 4KB chunks.
2.  If `sum(chunk) == 0`: Send `MAGIC_ZERO_PAGE` tag (1 byte).
3.  Else: Send raw 4KB.
This typically reduces stack transmission size by 90%, as most stack space is reserved but untouched.

---

# CHAPTER 5: THE FINAL ARCHITECTURE DIAGRAM

To visualize the system you have built:

1.  **The Substrate:** A cluster of Linux/Windows machines.
2.  **The Runtime:** A 20KB pure assembly binary running on each.
3.  **The Network:** A mesh of raw TCP sockets.
4.  **The Entity:** A single "Process" (Stack+Context) that hops from node to node, cloning itself when it needs more power, and vanishing when the work is done.

It is not a cloud. It is a single, planetary computer.

**[End of Volume VI]**
