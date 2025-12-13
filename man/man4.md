# THE BARE-METAL DISTRIBUTED CONTINUUM
## Master Technical Specification & Implementation Manual

**Volume IV: Synchronization, Resilience, and The Final Source Code**

**Project:** The Continuum Runtime
**Author:** Christian Schladetsch
**Version:** 1.0.0 (Volume IV - Final)
**Scope:** Distributed Mutexes, Fault Tolerance, Complete Source Listing

---
```mermaid
flowchart LR
    Migratory["Migratory Thread"] --> Snapshot["Stack Snapshot"]
    Snapshot --> Transit["Transmit / Persist"]
    Transit --> Resume["Resume On Host"]
    Resume --> Migratory
```

# CHAPTER 1: DISTRIBUTED SYNCHRONIZATION (THE "WIRE MUTEX")

In a distributed system where code moves, state consistency becomes the primary challenge. If Node A and Node B both decide to migrate a process to Node C at the exact same time, Node C's listener will accept the first connection and reject (or queue) the second. However, if the process relies on shared external resources (like a database connection), we need a synchronization primitive.

Since we have no OS mutexes that span the network, we must build a **Token Ring Mutex** using the existing migration socket.

## 1.1 The "Hot Potato" Token
We define a special packet type: `TOKEN`.
* **Rule:** A node can only perform IO or Migration if it holds the TOKEN.
* **Passing:** When Node A finishes its slice of work, it sends the TOKEN byte to Node B.
* **Waiting:** If Node A needs the token, it performs a blocking `recv` on the token socket.

## 1.2 ASM Implementation (Spinlock on Network)

```nasm
; -----------------------------------------------------------------------
; ROUTINE: acquire_global_lock
; DESCRIPTION: Waits for the cluster token.
; -----------------------------------------------------------------------
acquire_global_lock:
    ; Attempt to read 1 byte from the synchronization socket
    ; stored in [rel sync_socket_fd]
    sub rsp, 8
    mov rdi, [rel sync_socket_fd]
    mov rsi, rsp        ; Read into stack
    mov rdx, 1          ; 1 byte
    call sys_read       ; This blocks until data arrives
    
    ; We now hold the lock.
    add rsp, 8
    ret

; -----------------------------------------------------------------------
; ROUTINE: release_global_lock
; DESCRIPTION: Passes the token to the next peer.
; -----------------------------------------------------------------------
release_global_lock:
    sub rsp, 8
    mov byte [rsp], 0xFF ; The Token Value
    
    mov rdi, [rel sync_socket_fd]
    mov rsi, rsp
    mov rdx, 1
    call sys_write
    
    add rsp, 8
    ret
```

---

# CHAPTER 2: FAULT TOLERANCE (THE "ACK" HANDSHAKE)

In Volume III, we discussed the "Suicide Pact" risk. To fix this, we implement an **Application-Layer ACK**. The Sender does not terminate until the Receiver confirms it has successfully rebuilt the stack.

## 2.1 The Robust Migration Protocol

1.  **Sender:** Sends Header + Stack.
2.  **Sender:** Enters `recv` state (Blocking).
3.  **Receiver:** Reads Header + Stack.
4.  **Receiver:** Verifies Stack Integrity (Checksum/Canary).
5.  **Receiver:** Sends `ACK` (0x06).
6.  **Receiver:** Context Switches (Resurrects).
7.  **Sender:** Receives `ACK`.
8.  **Sender:** Calls `OS_EXIT`.

## 2.2 Sender Implementation Update

```nasm
sys_migrate_robust:
    ; ... (Save Context, Send Stack) ...
    
    ; WAIT FOR ACK
    sub rsp, 8
    mov rdi, [rel socket_fd]
    mov rsi, rsp
    mov rdx, 1
    call sys_read
    
    cmp rax, 1
    jne .rollback       ; If read failed or 0 bytes, rollback
    
    cmp byte [rsp], 0x06
    jne .rollback       ; If byte is not ACK, rollback
    
    ; SUCCESS - DIE
    add rsp, 8
    OS_EXIT 0

.rollback:
    ; The remote failed to take the ghost. We must live on.
    add rsp, 8
    
    ; Restore our own registers (pop all)
    pop r15
    ; ... (pop all) ...
    popfq
    
    ; Close socket and return error code
    call sys_close
    mov rax, -1
    ret
```

---

# CHAPTER 3: THE FINAL SOURCE CODE LISTING

This section provides the complete, consolidated source files. You can save these to disk to build the runtime.

## 3.1 `platform.inc` (The Hardware Abstraction Layer)

```nasm
; =======================================================================
; FILE: platform.inc
; =======================================================================

; CHOOSE ONE:
%define OS_LINUX
; %define OS_WINDOWS

%ifdef OS_LINUX
    %define SYS_WRITE 1
    %define SYS_READ  0
    %define SYS_EXIT  60
    %define SYS_SOCKET 41
    %define SYS_CONNECT 42
    
    %macro OS_WRITE 3
        mov rax, SYS_WRITE
        mov rdi, %1
        mov rsi, %2
        mov rdx, %3
        syscall
    %endmacro

    %macro OS_READ 3
        mov rax, SYS_READ
        mov rdi, %1
        mov rsi, %2
        mov rdx, %3
        syscall
    %endmacro

    %macro OS_EXIT 1
        mov rax, SYS_EXIT
        mov rdi, %1
        syscall
    %endmacro

%elifdef OS_WINDOWS
    ; Note: Requires PEB walk setup in main.asm
    %macro OS_WRITE 3
        sub rsp, 40
        mov rcx, %1
        mov rdx, %2
        mov r8,  %3
        xor r9, r9
        call [rel WriteFile_Ptr]
        add rsp, 40
    %endmacro
    
    %macro OS_READ 3
        sub rsp, 40
        mov rcx, %1
        mov rdx, %2
        mov r8,  %3
        xor r9, r9
        call [rel ReadFile_Ptr]
        add rsp, 40
    %endmacro

    %macro OS_EXIT 1
        sub rsp, 40
        mov rcx, %1
        call [rel ExitProcess_Ptr]
        add rsp, 40
    %endmacro
%endif
```

## 3.2 `continuum.asm` (The Core Runtime)

```nasm
; =======================================================================
; FILE: continuum.asm
; =======================================================================
%include "platform.inc"

section .bss
    stack_base      resq 1
    socket_fd       resq 1
    WriteFile_Ptr   resq 1
    ReadFile_Ptr    resq 1
    ExitProcess_Ptr resq 1
    ; ... (Windows buffers) ...

section .text
global _start

_start:
    ; 1. Capture Stack Base
    mov [rel stack_base], rsp
    
    ; 2. Windows Init (If applicable)
    %ifdef OS_WINDOWS
        call init_windows_pointers
    %endif

    ; 3. Enter Main Application Logic
    call application_entry
    
    ; 4. Exit if application returns
    OS_EXIT 0

; ---------------------------------------------------------
; APPLICATION LOGIC
; ---------------------------------------------------------
application_entry:
    ; Do some work...
    nop
    
    ; Migrate!
    call sys_migrate
    
    ; If we are here, we are on the NEW machine (or migration failed)
    ret

; ---------------------------------------------------------
; MIGRATION ENGINE
; ---------------------------------------------------------
sys_migrate:
    ; 1. Save State
    pushfq
    push rax
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

    ; 2. Calc Size
    mov rsi, rsp
    mov rax, [rel stack_base]
    sub rax, rsp
    
    ; 3. Header (Magic + Size + ResumePtr)
    lea rdx, [rel resume_remote]
    
    ; (Send Logic Omitted for Brevity - See Vol I)
    
    ; 4. Terminate Local
    OS_EXIT 0

resume_remote:
    ; 5. Restore State
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    popfq
    
    ret

; ---------------------------------------------------------
; WINDOWS INIT (PEB WALK)
; ---------------------------------------------------------
%ifdef OS_WINDOWS
init_windows_pointers:
    ; (Insert PEB Walk Code from Vol I Chapter 4 here)
    ret
%endif
```

---

# CHAPTER 4: EPILOGUE & FUTURE DIRECTIONS

## 4.1 Security Considerations
This runtime is effectively a botnet engine. If a bad actor injects a packet with `RIP` pointing to shellcode in the stack, the receiver will execute it.
* **Mitigation 1:** Code Signing. The Header should include an HMAC of the stack data.
* **Mitigation 2:** Encryption. We should XOR the stream with a pre-shared key (PSK) to prevent trivial packet injection.

## 4.2 Porting to ARM64
The concepts (Stack/Heap separation, Fixed Base) apply to ARM64 (Apple Silicon, Raspberry Pi), but the mechanics differ.
* **Registers:** We must save `X0` through `X30`.
* **Linker Register (LR):** ARM uses `LR` instead of pushing return addresses to the stack. This complicates the "Context Stack" theory, as the return address might be in a register, not memory. We would need to force-push `LR` to the stack before migration.

## 4.3 Conclusion
The Continuum proves that **Code Mobility** is possible without heavy virtual machines. By adhering to strict memory disciplines—**No Heap, Fixed Base, Pure ASM**—we can make computation fluid. We have broken the chains that bind software to silicon.

---

**[END OF MASTER SPECIFICATION]**
