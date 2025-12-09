# THE BARE-METAL DISTRIBUTED CONTINUUM
## Master Technical Specification & Implementation Manual

**Volume III: The Network Stack & Reference Implementation**

**Project:** The Continuum Runtime
**Author:** Christian Schladetsch
**Version:** 1.0.0 (Volume III)
**Scope:** Raw Sockets, Endianness, Resilience, "Ping-Pong" Payload

---

# CHAPTER 1: THE BARE-METAL NETWORK STACK

In high-level languages, `connect("192.168.1.5", 8080)` hides a mountain of complexity. It resolves DNS, allocates structures, handles endianness, and manages syscalls. In Pure ASM, we must build these structures bit-by-bit.

## 1.1 The `sockaddr_in` Structure
Both Linux and Windows use the BSD Socket API standard for memory layout. We must construct this 16-byte structure manually on the stack.

**Structure Layout (C definition):**
```c
struct sockaddr_in {
    short   sin_family;   // 2 bytes (AF_INET = 2)
    ushort  sin_port;     // 2 bytes (Big Endian)
    struct  in_addr;      // 4 bytes (IP Address, Big Endian)
    char    sin_zero[8];  // 8 bytes (Zero padding)
};
```

**NASM Implementation Strategy:**
We do not use `malloc`. We allocate this structure on the stack.

```nasm
; -----------------------------------------------------------------------
; ROUTINE: create_sockaddr
; DESCRIPTION: Constructs a sockaddr_in struct on the stack.
; INPUTS:  DI = Port (Host Byte Order)
;          EAX = IP Address (Host Byte Order)
; OUTPUTS: RSP points to the struct
; -----------------------------------------------------------------------
create_sockaddr:
    ; 1. Allocate 16 bytes
    sub rsp, 16
    
    ; 2. Zero out the padding (sin_zero)
    mov qword [rsp+8], 0
    
    ; 3. Set Family (AF_INET = 2)
    mov word [rsp], 2
    
    ; 4. Set Port (Needs HTONS - Host to Network Short)
    ; x86 is Little Endian. Network is Big Endian.
    ; We must swap the bytes of DI.
    xchg dl, dh             ; Swap bytes of DX (lower 16 bits of RDX)
    mov word [rsp+2], dx
    
    ; 5. Set IP (Needs HTONL - Host to Network Long)
    bswap eax               ; Intrinsic instruction to swap 4 bytes
    mov dword [rsp+4], eax
    
    ret
```

## 1.2 The Connection Pump (`sys_connect`)
This routine establishes the raw TCP pipe required for migration.

### Linux Implementation
```nasm
; Input: RDI = Socket FD, RSI = Pointer to sockaddr, RDX = Size of sockaddr
sys_connect_linux:
    mov rax, 42         ; sys_connect
    syscall
    ret
```

### Windows Implementation
Windows requires `WSAConnect` or `connect` from `ws2_32.dll`.
```nasm
; Input: RCX = Socket, RDX = Pointer to sockaddr, R8 = Size
sys_connect_windows:
    sub rsp, 40
    call [rel connect_Ptr]
    add rsp, 40
    ret
```

---

# CHAPTER 2: RESILIENCE & ROLLBACK

A critical flaw in naive migration is the "Suicide Pact." If the sender transmits half a stack and the network fails, the sender terminates (`OS_EXIT`), but the receiver cannot resume. The process executes a distributed double-suicide.

## 2.1 The "Try-Migrate" Pattern
We must treat migration as a transactional operation.
1.  **Checkpoint:** Save state.
2.  **Attempt:** Try to connect and send.
3.  **Commit/Rollback:** If successful, die. If failed, resume locally.

```nasm
; -----------------------------------------------------------------------
; ROUTINE: try_migrate
; RETURNS: 0 if migration happened (process dies), 1 if failed (resume local)
; -----------------------------------------------------------------------
try_migrate:
    ; 1. Create Socket
    call sys_socket
    cmp rax, 0
    jl .fail            ; Socket creation failed
    mov r12, rax        ; Save FD in callee-saved register
    
    ; 2. Connect
    ; (Setup sockaddr for 127.0.0.1:9090)
    mov edi, 9090
    mov eax, 0x7F000001
    call create_sockaddr
    
    mov rdi, r12        ; Socket FD
    mov rsi, rsp        ; Sockaddr Ptr
    mov rdx, 16         ; Size
    call sys_connect
    
    add rsp, 16         ; Clean up sockaddr
    
    cmp rax, 0
    jl .fail_close      ; Connect failed
    
    ; 3. MIGRATE (The Point of No Return)
    ; If this succeeds, it calls OS_EXIT.
    ; We pass the connected socket FD.
    mov rdi, r12
    call sys_migrate
    
    ; If sys_migrate returns, it means transmission failed mid-stream.
    ; This is a critical state.
    
.fail_close:
    ; Close socket
    mov rdi, r12
    call sys_close
.fail:
    ; Return 1 (Failure)
    mov rax, 1
    ret
```

---

# CHAPTER 3: THE REFERENCE IMPLEMENTATION ("PING-PONG")

This is a complete, deployable example. It consists of two binaries:
1.  **Node A (Alice):** Counts even numbers. Migrates to Bob.
2.  **Node B (Bob):** Counts odd numbers. Migrates to Alice.

The single process will bounce between the two terminals indefinitely, incrementing its counter.

## 3.1 The Shared Logic (`main.asm`)

```nasm
%include "platform.inc"

section .data
    msg_local  db "I am here: ", 0
    msg_remote db "Migrating...", 10, 0
    counter    dq 0

section .text
global _start

_start:
    ; 1. Initialize Fixed Stack (Crucial for migration validity)
    call setup_fixed_stack
    
    ; 2. Initialize Windows Network (if needed)
    call os_network_init 
    
    ; 3. Decide Identity
    ; Are we the Server (Listener) or Client (Starter)?
    ; Check command line args (omitted for brevity, assume Server if arg exists)
    
main_loop:
    ; ---------------------------------------------------------
    ; THE WORKLOAD
    ; ---------------------------------------------------------
    inc qword [counter]
    
    ; Print "I am here: <count>"
    lea rsi, [rel msg_local]
    call print_string
    mov rsi, [counter]
    call print_int
    call print_newline
    
    ; Sleep 1 second (to make it visible)
    call os_sleep_1s
    
    ; ---------------------------------------------------------
    ; THE MIGRATION DECISION
    ; ---------------------------------------------------------
    ; Migrate on every 5th count
    mov rax, [counter]
    mov rdx, 0
    mov rbx, 5
    div rbx
    cmp rdx, 0
    jne main_loop       ; If not divisible by 5, keep working locally
    
    ; Time to move!
    lea rsi, [rel msg_remote]
    call print_string
    
    ; Attempt migration to "The Other Node"
    ; (Hardcoded IP for demo: 127.0.0.1:9090)
    call try_migrate
    
    ; If try_migrate returns, it failed. We just loop and try again later.
    jmp main_loop
```

## 3.2 The Server Harness (`server_harness.asm`)
To receive the migrating process, we need a listener running on the destination. This is `sys_resume` wrapped in a loop.

```nasm
server_start:
    call setup_fixed_stack
    
    ; 1. Bind Port 9090
    call sys_bind_9090
    
    ; 2. Listen
    call sys_listen
    
accept_loop:
    ; 3. Accept Connection
    call sys_accept
    mov rdi, rax        ; RDI = Client Socket
    
    ; 4. RESURRECT
    ; Fork a child (Linux) or CreateThread (Windows) to handle the ghost?
    ; For simplicity, we just BECOME the ghost.
    ; The server process effectively vanishes and is replaced by the incoming migrant.
    call sys_resume
    
    ; sys_resume NEVER returns.
    ; The process is now the counter application from 3.1.
```

---

# CHAPTER 4: SECURITY IMPLICATIONS ("THE UNSAFE MANIFESTO")

The Continuum is, by definition, a Remote Code Execution (RCE) engine.

## 4.1 The Executable Stack (NX Bit)
Standard security practices enable the **NX (No-Execute)** bit on the stack to prevent buffer overflows from running shellcode.
* **The Conflict:** We are migrating a stack. Does it contain code?
* **The Reality:** No. The stack contains *Return Addresses* (pointers to code), not the code itself. The code resides in the immutable `.text` segment.
* **Conclusion:** We do **not** need an executable stack. We require standard `RW-` permissions on the stack segment. This keeps us compliant with DEP/NX security policies.

## 4.2 Code Consistency Verification
The system assumes that `0x401055` maps to the *same instruction* on both nodes.
* **Risk:** If Node A runs v1.0 and Node B runs v1.1, the memory offsets of functions may shift.
* **Catastrophe:** A return address of `0x401055` might point to `update_physics` on Node A, but inside `format_disk` on Node B.
* **Mitigation:** The "Magic" field in the protocol header should be a Hash of the binary's `.text` segment. If the hashes don't match, the receiver **must** reject the migration.

---

**[End of Volume III]**
