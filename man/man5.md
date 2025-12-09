# THE BARE-METAL DISTRIBUTED CONTINUUM
## Master Technical Specification & Implementation Manual

**Volume V: Cryptographic Hardening, Compression & Resource Rehydration**

**Project:** The Continuum Runtime
**Author:** Christian Schladetsch
**Version:** 1.0.0 (Volume V)
**Scope:** Stream Encryption, Run-Length Encoding (RLE), Lifecycle Hooks

---

# CHAPTER 1: CRYPTOGRAPHIC HARDENING (THE "SECURE CONTINUUM")

The migration mechanism described in previous volumes is transparent. A network sniffer can capture the stack dump, modify the Return Addresses (RIP), and reinject the packet to achieve Remote Code Execution (RCE) with root privileges.

To secure the Continuum, we must wrap the transport layer in a stream cipher. Since we cannot link OpenSSL (`libssl`), we must implement a cipher in pure assembly.

## 1.1 The "Rolling XOR" Cipher
While not cryptographically perfect, a Rolling XOR with a pre-shared key (PSK) provides sufficient obfuscation to defeat casual packet injection and inspection.

### The Algorithm
1.  **Seed:** A 64-bit Pre-Shared Key (e.g., `0x8BADF00DDEADBEEF`).
2.  **Stream Generation:** For every 8 bytes of data, we XOR with the Key.
3.  **Key Mutation:** After every operation, we rotate the Key to prevent simple frequency analysis attacks. `Key = (Key ROL 5) ^ (Key >> 3)`.

### 1.2 ASM Implementation

```nasm
; -----------------------------------------------------------------------
; ROUTINE: encrypt_buffer
; INPUTS:  RSI = Buffer Address
;          RCX = Length in Bytes
;          RDI = Initial Key (PSK)
; OUTPUTS: Buffer is encrypted in-place
; -----------------------------------------------------------------------
encrypt_buffer:
    push rbx
    
    ; We process 8 bytes (qword) at a time
    shr rcx, 3          ; Divide length by 8 (to get qword count)
    
.loop:
    cmp rcx, 0
    je .done
    
    ; Load 8 bytes
    mov rax, [rsi]
    
    ; Encrypt
    xor rax, rdi        ; XOR with Key
    mov [rsi], rax      ; Store back
    
    ; Mutate Key (Rolling)
    mov rbx, rdi
    rol rbx, 5
    shr rdi, 3
    xor rdi, rbx        ; New Key = (Old ROL 5) XOR (Old SHR 3)
    
    ; Advance
    add rsi, 8
    dec rcx
    jmp .loop

.done:
    pop rbx
    ret
```

### 1.3 Integration into `sys_migrate`
We must encrypt the stack *before* sending it, but *after* calculating the size.

```nasm
    ; (Inside sys_migrate, after calculating size in RAX)
    
    ; 1. Encrypt the Stack Memory in-place
    ; WARNING: This destroys the local stack validity. 
    ; We cannot return from this function anymore. 
    ; The process is committed to death.
    push rax            ; Save Size
    push rsi            ; Save Stack Pointer
    
    mov rcx, rax        ; Length
    mov rdi, 0xCAFEBABE ; The Secret Key
    call encrypt_buffer
    
    pop rsi             ; Restore Stack Pointer
    pop rax             ; Restore Size
    
    ; 2. Send the (now encrypted) memory
    OS_WRITE socket_fd, rsi, rax
```

---

# CHAPTER 2: PAYLOAD COMPRESSION (RLE)

Stacks are overwhelmingly composed of **Zeros**.
* Uninitialized local variables.
* Padding for alignment.
* Sparse arrays.
Sending 1MB of zeros over the network is wasteful. We implement **Run-Length Encoding (RLE)** to compress the ghost process.

## 2.1 The RLE Format
We use a simple tag-based format.
* **Literal Byte:** `[00] [XX]` -> Byte `XX`
* **Zero Run:** `[FF] [NN]` -> `NN` bytes of Zeros.

## 2.2 ASM Implementation (Compressor)

```nasm
; -----------------------------------------------------------------------
; ROUTINE: rle_compress
; INPUTS:  RSI = Source Buffer (Raw Stack)
;          RCX = Source Size
;          RDI = Dest Buffer (Packet Buffer)
; OUTPUTS: RAX = Compressed Size
; -----------------------------------------------------------------------
rle_compress:
    xor rax, rax        ; Total Compressed Size
    
.loop:
    cmp rcx, 0
    je .done
    
    ; Check for Zero
    cmp byte [rsi], 0
    je .handle_zero
    
    ; Handle Literal
    mov bl, [rsi]
    mov byte [rdi], 0x00 ; Literal Tag
    mov byte [rdi+1], bl ; Value
    add rdi, 2
    add rsi, 1
    add rax, 2
    dec rcx
    jmp .loop

.handle_zero:
    ; Count run of zeros
    ; (Logic omitted: loop forward until non-zero or 255 count)
    ; Assume we found N zeros.
    mov byte [rdi], 0xFF ; Zero Run Tag
    mov byte [rdi+1], bl ; Count N
    add rdi, 2
    add rax, 2
    ; Advance pointers...
    jmp .loop

.done:
    ret
```

---

# CHAPTER 3: RESOURCE REHYDRATION (THE LIFECYCLE TABLE)

In Volume II, we discussed the "Open Resource Problem." We now solve it formally using a **Lifecycle Table**. This is a vtable-like structure that registers handlers for migration events.

## 3.1 The Rehydration Table
We define a structure in `.data` that holds function pointers.

```nasm
section .data
    lifecycle_table:
        dq on_suspend_handler   ; Called before migration
        dq on_resume_handler    ; Called after migration
```

## 3.2 The Handlers
The application programmer implements these hooks.

```nasm
; -----------------------------------------------------------------------
; HOOK: on_suspend
; DESCRIPTION: Close all handles, save state to stack variables.
; -----------------------------------------------------------------------
on_suspend_handler:
    ; 1. Close Log File
    mov rdi, [rel log_fd]
    call sys_close
    mov qword [rel log_fd], -1
    ret

; -----------------------------------------------------------------------
; HOOK: on_resume
; DESCRIPTION: Re-open handles.
; -----------------------------------------------------------------------
on_resume_handler:
    ; 1. Re-open Log File
    ; (Filename string must be in .data or stack)
    lea rdi, [rel log_filename]
    call sys_open_append
    mov [rel log_fd], rax
    ret
```

## 3.3 Integration into `continuum.asm`

```nasm
sys_migrate:
    ; 1. Call Suspend Hook
    call [rel lifecycle_table + 0]
    
    ; 2. Perform Migration (Save Registers, Send Stack)
    ; ...
    
resume_remote:
    ; ... (Restore Registers) ...
    
    ; 3. Call Resume Hook
    call [rel lifecycle_table + 8]
    
    ret
```

---

# CHAPTER 4: TELEMETRY & OBSERVABILITY

How do we debug a process that has jumped 10 times across 10 machines? We need a **Distributed Trace Header**.

## 4.1 The Trace Header
We augment the packet protocol with a "Flight Recorder" structure. This is appended to the stack dump.

**Structure:**
* `HopCount` (8 bytes): Number of jumps.
* `OriginIP` (4 bytes): The IP of the first node.
* `LastIP` (4 bytes): The IP of the previous node.
* `Checksum` (8 bytes): Integrity check.

## 4.2 The Beacon
Upon arriving at a new node, the runtime sends a UDP "Pulse" to a configured Telemetry Server (e.g., `10.0.0.255:5000`).

```nasm
; -----------------------------------------------------------------------
; ROUTINE: send_beacon
; -----------------------------------------------------------------------
send_beacon:
    ; 1. Create UDP Socket
    ; 2. Construct Payload: "ALIVE: <Hostname> <HopCount>"
    ; 3. SendTo Telemetry Server
    ; (Does not block main execution)
    ret
```

---

# CHAPTER 5: ADVANCED WINDOWS INTERNALS

## 5.1 Bypassing CFG (Control Flow Guard)
Modern Windows binaries enable CFG, which validates indirect calls. Since our `platform.inc` performs dynamic indirect calls to function pointers (`call [rel WriteFile_Ptr]`), CFG might crash our runtime.

**Solution:**
We must ensure our assembly is not linked with `/GUARD:CF`.
* Build flag: `/GUARD:NO`.
* Manual mitigation: If we are injecting into a host process (Shellcode style), we must locate `LdrpValidateUserCallTarget` and patch it, or ensure our stack pivot happens in non-CFG memory.

## 5.2 The "Heaven's Gate" (WoW64)
If our runtime inadvertently lands on a 32-bit Windows system (running via WoW64), the `syscall` instruction or 64-bit PEB walk will fail catastrophically.

**Constraint:** The Continuum strictly requires **Native x64**.
**Check:** At `_start`, we verify the segment selector `CS` is `0x33` (Standard 64-bit code segment).

```nasm
check_arch:
    mov ax, cs
    cmp ax, 0x33
    jne fatal_arch_mismatch
    ret
```

---

**[End of Volume V]**
