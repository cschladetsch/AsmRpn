# THE BARE-METAL DISTRIBUTED CONTINUUM
## Master Technical Specification & Implementation Manual

**Volume VII: The Global Address Space & Distributed Storage**

**Project:** The Continuum Runtime
**Author:** Christian Schladetsch
**Version:** 1.0.0 (Volume VII)
**Scope:** Distributed Hash Table (DHT), Block Storage, Content Addressing

---
```mermaid
flowchart LR
    Migratory["Migratory Thread"] --> Snapshot["Stack Snapshot"]
    Snapshot --> Transit["Transmit / Persist"]
    Transit --> Resume["Resume On Host"]
    Resume --> Migratory
```

# CHAPTER 1: THE PERSISTENCE PARADOX

We have successfully achieved **Code Mobility**. A process can jump from Node A to Node B. However, we have hit a hard physical limit: **Data Gravity**.

## 1.1 The File System Gap
If a process on Node A opens `config.dat` and then migrates to Node B, any attempt to read from that file handle will fail (or read garbage), because `config.dat` physically resides on Node A's hard drive.

We cannot migrate the entire hard drive.
We cannot rely on NFS/SMB (external dependencies).

## 1.2 The Solution: Content-Addressable Storage (CAS)
We treat the entire cluster's storage as a single **Distributed Hash Table (DHT)**.
* **Write:** We do not write to filenames. We write a data block and get back a **Hash** (ID).
* **Read:** We request data by **Hash**. The runtime locates which node holds that chunk and streams it to us.

This decouples data from physical location. `Hash(X)` is the same on every machine.

---

# CHAPTER 2: THE BLOCK PROTOCOL

To implement this in Pure ASM, we define a simple block-based storage protocol.

## 2.1 Block Structure
* **Block Size:** 4KB (Standard Page Size).
* **Identifier:** 64-bit Hash (Simpler than SHA-256 for ASM).
* **Network Command:** `GET_BLOCK <ID>` / `PUT_BLOCK <ID> <DATA>`.

## 2.2 The Hashing Algorithm (FNV-1a 64-bit)
We need a fast, low-collision hash for data blocks.

```nasm
; -----------------------------------------------------------------------
; ROUTINE: fnv1a_hash
; INPUTS:  RSI = Data Pointer, RCX = Length
; OUTPUTS: RAX = 64-bit Hash
; -----------------------------------------------------------------------
fnv1a_hash:
    mov rax, 0CBF29CE484222325h ; FNV Offset Basis
    mov rbx, 0100000001B3h      ; FNV Prime
    
.loop:
    cmp rcx, 0
    je .done
    
    xor rdx, rdx
    mov dl, byte [rsi]          ; Load byte
    xor rax, rdx                ; XOR with hash
    mul rbx                     ; Multiply by Prime
    
    inc rsi
    dec rcx
    jmp .loop

.done:
    ret
```

---

# CHAPTER 3: THE STORAGE ENGINE

Each node runs a storage thread (or event loop handler) that manages a simple `kv_store` in memory or on disk.

## 3.1 The `sys_put_block` Routine
When the application wants to save data that persists across migrations:

```nasm
; -----------------------------------------------------------------------
; ROUTINE: sys_put_block
; INPUTS:  RSI = Data Buffer (4KB)
; OUTPUTS: RAX = Block ID (Hash)
; -----------------------------------------------------------------------
sys_put_block:
    ; 1. Calculate Hash of Data
    push rsi
    mov rcx, 4096
    call fnv1a_hash
    pop rsi
    mov r8, rax         ; R8 = The Block ID
    
    ; 2. Determine Target Node (Sharding)
    ; TargetIndex = Hash % PeerCount
    xor rdx, rdx
    mov rax, r8
    div qword [rel peer_count]
    ; Target IP is at [peer_table + rdx*8]
    
    ; 3. Connect to Target Storage Port (e.g., 9091)
    ; (Logic omitted)
    
    ; 4. Send PUT Command
    ; [CMD_PUT] [BLOCK_ID] [DATA]
    
    mov rax, r8         ; Return the ID to the user
    ret
```

## 3.2 The `sys_get_block` Routine
When the application arrives at a new node and needs its data:

```nasm
; -----------------------------------------------------------------------
; ROUTINE: sys_get_block
; INPUTS:  RAX = Block ID
; OUTPUTS: Buffer filled with 4KB data
; -----------------------------------------------------------------------
sys_get_block:
    mov r8, rax
    
    ; 1. Determine Target Node (Same sharding logic)
    ; ...
    
    ; 2. Connect & Request
    ; Send: [CMD_GET] [BLOCK_ID]
    
    ; 3. Receive Data
    ; Read 4KB into buffer
    ret
```

---

# CHAPTER 4: THE GLOBAL MEMORY HEAP

Now that we have `sys_put` and `sys_get`, we can implement a **Global Heap**.
Since we banned the local heap (malloc), we replace it with a **Distributed Heap**.

## 4.1 The `d_malloc` Abstraction
Instead of returning a memory pointer (which is invalid on other machines), `d_malloc` returns a **Handle** (The Block Hash).

**Usage Pattern:**
1.  **Allocate:** `mov rdi, 4096` -> `call d_malloc` -> Returns `HashID`.
2.  **Write:** Modify local buffer.
3.  **Commit:** `call d_commit` -> Pushes buffer to the DHT.
4.  **Migrate:** Move to Node B.
5.  **Fetch:** `call d_fetch` -> Pulls buffer from DHT using `HashID`.

This guarantees that "large" state (images, databases) follows the process implicitly, without bloating the Stack Migration Packet.

---

# CHAPTER 5: FINAL INTEGRATION (THE "WORLD COMPUTER")

We have built all the layers.

1.  **Layer 0 (HAL):** `platform.inc` abstracts Linux/Windows.
2.  **Layer 1 (Runtime):** `continuum.asm` manages the stack and entry points.
3.  **Layer 2 (Network):** Raw sockets, TCP pumps, encryption.
4.  **Layer 3 (Mobility):** `sys_migrate` moves execution.
5.  **Layer 4 (Storage):** `sys_put/get` manages global state.

## 5.1 The Final `main.asm` Template

```nasm
%include "platform.inc"

section .text
global _start

_start:
    call setup_fixed_stack
    call init_network
    
    ; Join the cluster
    call discovery_announce
    
    ; START WORKLOAD
    call my_distributed_task
    
    OS_EXIT 0

my_distributed_task:
    ; 1. Load Data from DHT
    mov rax, [rel my_data_hash]
    call sys_get_block
    
    ; 2. Process Data
    inc byte [rsi]
    
    ; 3. Save Data back to DHT
    call sys_put_block
    mov [rel my_data_hash], rax
    
    ; 4. Migrate to next node in chain
    call get_next_peer
    mov rdi, rax
    call sys_migrate
    
    ; 5. Repeat
    jmp my_distributed_task
```

## 5.2 Closing Thoughts
The **Continuum** is complete. It is a self-contained, operating-system-agnostic, decentralized supercomputer runtime. It requires no installation, no dependencies, and no configuration. It simply flows through the network, consuming cycles and storage where it finds them.

**[End of Master Technical Specification]**
