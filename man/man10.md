# THE BARE-METAL DISTRIBUTED CONTINUUM
## Master Technical Specification & Implementation Manual

**Volume X: Swarm Intelligence, Hot Patching & Final Integration**

**Project:** The Continuum Runtime
**Author:** Christian Schladetsch
**Version:** 1.0.0 (Volume X - Final)
**Scope:** Distributed Algorithms, Self-Modifying Code, "The Census"

---

# CHAPTER 1: SWARM INTELLIGENCE PATTERNS

We have built a mechanism for processes to move. Now we must define *how* they decide to move. We replace central orchestration (Kubernetes Master) with local, heuristic-based decision making (Swarm Intelligence).

## 1.1 The Gradient Descent Pattern
Processes should naturally flow toward nodes with abundant resources.

### The Algorithm
1.  **Scent:** Every node includes its "Load Index" ($L$) in the UDP Gossip heartbeat (see Vol VI).
2.  **Gradient:** The running process reads the local `peer_table` to find the neighbor with the lowest $L$.
3.  **Flow:** If $L_{remote} < (L_{local} - \Delta)$, migrate.

### ASM Implementation (`sys_find_gradient`)

```nasm
; -----------------------------------------------------------------------
; ROUTINE: sys_find_gradient
; OUTPUTS: RAX = IP of target node (or 0 if local is best)
; -----------------------------------------------------------------------
sys_find_gradient:
    ; 1. Get Local Load
    call get_cpu_load       ; RAX = Local Load %
    mov rbx, rax            ; RBX = Best Load found so far
    mov r12, 0              ; R12 = Best IP
    
    ; 2. Scan Peer Table
    mov rcx, [rel peer_count]
    lea rsi, [rel peer_table]
    
.scan_loop:
    cmp rcx, 0
    je .done
    
    ; Load Peer Load (High 32 bits of entry)
    mov rdx, [rsi]
    shr rdx, 32             ; Extract Load byte
    
    ; Compare
    cmp rdx, rbx
    jge .next               ; If peer load >= current best, skip
    
    ; Found a better node
    mov rbx, rdx            ; Update best load
    mov r12, [rsi]          ; Save IP (Low 32 bits)
    and r12, 0xFFFFFFFF
    
.next:
    add rsi, 8
    dec rcx
    jmp .scan_loop

.done:
    mov rax, r12
    ret
```

## 1.2 The "Pheromone" Trail (Data Locality)
Processes leave "traces" in the DHT. A process needing Data Block $X$ should migrate to the node that *wrote* Data Block $X$.

**Implementation:** The DHT metadata includes the IP of the writer.
`sys_get_block_location(Hash) -> IP Address`

---

# CHAPTER 2: RUNTIME SELF-MODIFICATION ("HOT PATCHING")

The Continuum Runtime runs in `RWX` (Read-Write-Execute) memory (or we remap it to be so). This allows a "Doctor Process" to migrate to a node and patch the kernel code of that node *while it is running*.

## 2.1 The Patching Protocol
1.  **Doctor** arrives at Node.
2.  **Doctor** requests `SYS_LOCK_KERNEL`.
3.  **Doctor** writes new opcodes over the old `sys_migrate` function in memory.
4.  **Doctor** releases lock.
5.  **Doctor** dies (mission accomplished).

## 2.2 The "Injector" Routine
This routine overwrites the first 5 bytes of a function with a `JMP`.

```nasm
; -----------------------------------------------------------------------
; ROUTINE: sys_hot_patch
; INPUTS:  RDI = Target Function Address (e.g., address of sys_log)
;          RSI = New Code Buffer
;          RCX = Length
; -----------------------------------------------------------------------
sys_hot_patch:
    ; 1. Disable Interrupts (CLI) - Only if running bare metal ring 0
    ; In user space, we just hope no other thread calls this function.
    
    ; 2. Copy new code to a "Trampoline Area" (heap or data section)
    mov rbx, [rel trampoline_ptr]
    push rbx
    push rcx
    call csl_memcpy
    pop rcx
    pop rbx
    
    ; 3. Overwrite Target with JMP REL32
    ; Opcode E9 + 4 byte offset
    mov byte [rdi], 0xE9
    
    ; Calculate Offset = Dest - Src - 5
    mov rax, rbx            ; Dest
    sub rax, rdi            ; Src
    sub rax, 5              ; JMP instruction size
    
    mov dword [rdi+1], eax  ; Write Offset
    
    ret
```

---

# CHAPTER 3: THE GRAND UNIFIED EXAMPLE ("CLUSTER CENSUS")

This is the "Hello World" of the Continuum. A single process that:
1.  Starts at the Origin.
2.  Recursively visits every node in the `peer_table`.
3.  Collects their Hostnames.
4.  Returns to Origin and prints a report.

## 3.1 The `census.asm` Source

```nasm
%include "platform.inc"

section .data
    origin_ip   dd 0
    visited_map times 256 db 0  ; Bitmask of visited IPs
    report_buf  times 4096 db 0 ; Buffer for hostnames

section .text
global _start

_start:
    call setup_fixed_stack
    
    ; 1. Record Origin
    call get_local_ip
    mov [rel origin_ip], eax
    
    ; 2. Start Recursion
    call visit_neighbors
    
    ; 3. Go Home
    mov rdi, [rel origin_ip]
    call sys_migrate
    
    ; 4. Print Report
    lea rsi, [rel report_buf]
    call sys_log
    
    OS_EXIT 0

; ---------------------------------------------------------
; RECURSIVE VISITOR
; ---------------------------------------------------------
visit_neighbors:
    ; 1. Mark Self Visited
    call mark_visited
    
    ; 2. Record Hostname
    call get_hostname       ; Result in RAX
    lea rdi, [rel report_buf]
    call append_string
    
    ; 3. Iterate Peers
    mov rcx, 0              ; Peer Index
    
.loop:
    cmp rcx, [rel peer_count]
    jge .done
    
    ; Check if visited
    mov eax, [rel peer_table + rcx*8]
    call is_visited
    cmp rax, 1
    je .skip
    
    ; 4. Fork to Peer
    mov rdi, [rel peer_table + rcx*8] ; Target IP
    
    ; SAVE STATE (Recursion depth, loop counter)
    push rcx
    
    call sys_dist_fork
    
    ; Parent returns 0, Child returns 1
    cmp rax, 1
    je .i_am_child
    
    ; Parent Logic:
    pop rcx             ; Restore counter
    jmp .skip           ; Continue loop

.i_am_child:
    ; Child Logic:
    ; We are now on the new node. 
    ; Recurse deeper!
    call visit_neighbors
    
    ; When recursion returns, we die.
    OS_EXIT 0

.skip:
    inc rcx
    jmp .loop

.done:
    ret
```

---

# CHAPTER 4: EPILOGUE & THE ROAD AHEAD

## 4.1 Summary of Accomplishments
We have specified a complete computing ecosystem that defies the traditional constraints of software engineering.
1.  **Runtime:** Pure ASM, zero dependencies.
2.  **Mobility:** Seamless process migration via stack serialization.
3.  **Storage:** Content-Addressable global memory.
4.  **Intelligence:** Swarm-based scheduling and logic.

## 4.2 Future Research Directions
The current specification targets Linux and Windows user-space. The next logical step is **The Bare Metal Hypervisor**.
* **Bootable ISO:** Converting the runtime into a multiboot kernel that boots directly from BIOS/UEFI.
* **Ring 0 Access:** Allowing the Continuum direct control over hardware interrupts and paging tables.
* **The Planetary Computer:** A mesh of bare-metal nodes running nothing but Continuum, executing a single, massive, shifting workload.

**The Continuum is no longer just a project. It is an organism.**

---

**[END OF MASTER TECHNICAL SPECIFICATION]**
