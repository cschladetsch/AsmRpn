# THE BARE-METAL DISTRIBUTED CONTINUUM
## Master Technical Specification & Implementation Manual

**Volume II: Advanced Memory Mechanics & Runtime Implementation**

**Project:** The Continuum Runtime
**Author:** Christian Schladetsch
**Version:** 1.0.0 (Volume II)
**Scope:** Stack Homogeneity, Network Pump, Toolchains

---

# CHAPTER 1: THE STACK HOMOGENEITY PROBLEM

## 1.1 The "RBP" Paradox
In Volume I, we solved the **Code Relocation Problem** by forcing the OS to load the `.text` segment at `0x400000`. This ensured that Return Addresses (pushed by `CALL`) remained valid integers.

However, a second, more insidious relocation problem exists: **The Stack Pointer Problem**.

### The Scenario
1.  **Node A:** The stack is allocated by the OS at `0x7FFFFFFFA000`.
2.  **Node B:** The OS (due to ASLR or kernel differences) allocates the stack at `0x7FFF0000A000`.
3.  **Migration:** We copy the bytes.
4.  **Failure:**
    * The CPU registers `RSP` and `RBP` (Base Pointer) are saved in the packet.
    * If we blindly restore `RBP` to its old value (`0x7FFFFFFFA000`), but the new stack lives at `0x7FFF0000A000`, any instruction using `[RBP-8]` will access invalid memory (the *old* stack location).
    * Furthermore, if the program pushed pointers *to* stack variables onto the stack (e.g., `LEA RAX, [RSP+16] ; PUSH RAX`), those pointers are now dangling references to the old machine's memory.

## 1.2 Solution: The "Fixed-Stack" Contract
Just as we forced the Code Segment to a fixed address, we must force the **Stack Segment** to a fixed address. We cannot rely on the OS's default stack allocation.

### The Implementation
When our runtime starts (`_start`), we immediately pivot to a manually managed memory region that we know is safe and unmapped on all target machines.

**Target Stack Address:** `0x500000000` (Chosen to be well above the code segment but safely in user space).

### Linux Implementation (`sys_mmap`)
We use `mmap` with the `MAP_FIXED` flag to demand this specific memory range.

```nasm
; -----------------------------------------------------------------------
; ROUTINE: setup_fixed_stack
; DESCRIPTION: Allocates a fixed memory region and pivots RSP to it.
; -----------------------------------------------------------------------
setup_fixed_stack:
    ; mmap(addr=0x500000000, len=1MB, prot=RW, flags=FIXED|ANON|PRIVATE, fd=-1, off=0)
    mov rax, 9              ; sys_mmap
    mov rdi, 0x500000000    ; Fixed Address
    mov rsi, 0x100000       ; Size (1MB)
    mov rdx, 3              ; PROT_READ | PROT_WRITE
    mov r10, 34             ; MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED
    mov r8, -1              ; fd
    mov r9, 0               ; offset
    syscall
    
    ; Check for failure (RAX < 0)
    cmp rax, 0
    jl fatal_error
    
    ; PIVOT THE STACK
    ; We move RSP to the top of this new allocation.
    mov rsp, 0x5000FFFF8    ; Top of 1MB region (aligned)
    mov rbp, rsp
    ret
```

### Windows Implementation (`VirtualAlloc`)
We use `VirtualAlloc` with `MEM_COMMIT | MEM_RESERVE` and a specific base address.

```nasm
; -----------------------------------------------------------------------
; ROUTINE: setup_fixed_stack (Windows)
; -----------------------------------------------------------------------
setup_fixed_stack:
    sub rsp, 40
    mov rcx, 0x500000000    ; lpAddress
    mov rdx, 0x100000       ; dwSize (1MB)
    mov r8,  0x3000         ; MEM_COMMIT | MEM_RESERVE
    mov r9,  0x04           ; PAGE_READWRITE
    call [rel VirtualAlloc_Ptr]
    
    ; PIVOT
    mov rsp, 0x5000FFFF8
    mov rbp, rsp
    ret
```

**The Result:**
By running `setup_fixed_stack` at the very beginning of `_start`, we guarantee that `RSP` and `RBP` are identical integers on every machine. Pointers to stack variables remain mathematically valid after migration.

---

# CHAPTER 2: THE NETWORK PUMP

TCP is a stream protocol. Sending 1000 bytes does not guarantee the receiver gets 1000 bytes in a single `recv` call. It might get 500, then 500. Or 1, then 999. Our runtime must implement a robust "Pump" to ingest the full ghost process.

## 2.1 The `recv_all` Algorithm
We cannot proceed with resurrection until every single byte of the stack dump has arrived.

```nasm
; -----------------------------------------------------------------------
; ROUTINE: recv_all
; INPUTS:  RDI = Socket FD
;          RBX = Destination Buffer Address
;          RCX = Total Bytes Expected
; -----------------------------------------------------------------------
recv_all:
    push r12
    mov r12, rcx        ; R12 = Bytes Remaining
    
.loop:
    cmp r12, 0
    jle .done           ; If 0 bytes left, we are done
    
    ; Call OS_READ(fd=RDI, buf=RBX, len=R12)
    ; (Using the macro from Vol I)
    OS_READ rdi, rbx, r12
    
    ; Check result in RAX
    cmp rax, 0
    jl .error           ; Error (< 0)
    je .closed          ; Connection Closed (0)
    
    ; Advance pointers
    add rbx, rax        ; Move buffer pointer forward
    sub r12, rax        ; Decrement bytes remaining
    jmp .loop

.done:
    pop r12
    ret

.error:
    ; Handle network error (exit or retry)
    OS_EXIT 1
.closed:
    OS_EXIT 2
```

---

# CHAPTER 3: THE BUILD TOOLCHAINS

Creating a "Pure ASM" binary requires bypassing the standard compiler drivers (`gcc`, `cl.exe`) and invoking the linkers directly with specific, non-standard flags.

## 3.1 Linux Toolchain (`build_linux.sh`)

```bash
#!/bin/bash
set -e

echo "[*] Assembling..."
# -f elf64: Create 64-bit ELF object
# -D OS_LINUX: Define the macro for platform.inc
nasm -f elf64 -D OS_LINUX main.asm -o main.o

echo "[*] Linking..."
# -Ttext=0x400000: Force Code Segment to fixed address
# --entry=_start: Define entry point explicitly
# -nostdlib: Do not link libc
ld -Ttext=0x400000 --entry=_start -nostdlib -o continuum main.o

echo "[*] Verifying..."
readelf -l continuum | grep 0x400000
echo "[+] Build Complete: ./continuum"
```

## 3.2 Windows Toolchain (`build_win.bat`)

```cmd
@echo off
echo [*] Assembling...
:: -f win64: Create 64-bit PE object
nasm -f win64 -D OS_WINDOWS main.asm -o main.obj

echo [*] Linking...
:: /SUBSYSTEM:CONSOLE: Create console app
:: /ENTRY:start: Define entry point (bypasses mainCRTStartup)
:: /BASE:0x400000: Force Image Base
:: /FIXED: Disable Relocations (ASLR)
:: /NODEFAULTLIB: No kernel32.lib, no msvcrt.lib
link /SUBSYSTEM:CONSOLE /ENTRY:start /BASE:0x400000 /FIXED /NODEFAULTLIB main.obj /OUT:continuum.exe

echo [+] Build Complete: continuum.exe
```

---

# CHAPTER 4: LIMITATIONS & EDGE CASES

While this system achieves near-magical code mobility, the "Pure Stack" approach has strict limitations that the programmer must obey.

## 4.1 The "Open Resource" Problem
We can migrate memory (`RSP`, `RIP`, Variables), but we cannot migrate **Kernel Handles**.
* **File Descriptors:** If Node A has `fd=3` open to `/tmp/log.txt`, and we migrate to Node B, `fd=3` on Node B might be closed, or it might point to a completely different resource (like a socket).
* **Sockets:** An open TCP connection cannot physically move to another machine.

**The Solution:**
The application must follow a **"Close-Move-Reopen"** lifecycle.
1.  **Pre-Migration:** Explicitly close all file descriptors and sockets.
2.  **Migrate:** Call `sys_migrate`.
3.  **Post-Migration:** The `sys_migrate` function returns on the new machine. Immediately re-open necessary resources (e.g., reconnect to DB, open log file).

## 4.2 The "Self-Referential" Pointer
If the program stores a pointer to the stack *inside* the stack (e.g., a linked list where nodes are allocated on the stack via `alloca`), these pointers are valid **only if** we use the "Fixed-Stack" strategy described in Chapter 1. If we rely on OS default stack allocation, these pointers break.

## 4.3 Threading
This runtime supports **Single-Threaded** processes only. Migrating a multi-threaded application requires capturing the state of multiple stacks and the kernel scheduler state, which is impossible from user-space without heavy virtualization.

---

# CHAPTER 5: DEBUGGING STRATEGIES

Debugging a runtime with no `libc` and no `printf` is difficult.

## 5.1 The "LED" Debugging Technique
Since we cannot easily print text, we use "Exit Codes" as LEDs.
* `OS_EXIT(1)`: Failed to open socket.
* `OS_EXIT(2)`: Failed to connect.
* `OS_EXIT(3)`: Stack verification failed.
We run the program as `./continuum ; echo $?` to trace execution flow.

## 5.2 GDB / x64dbg
To debug the raw binary:
* **Linux:** `gdb ./continuum` -> `layout asm` -> `break _start` -> `si` (Step Instruction).
* **Windows:** Open `continuum.exe` in x64dbg. Note that because we stripped relocations (`/FIXED`), the address will always be `0x400000`, making it easy to set breakpoints.

## 5.3 The Stack Canary
To verify migration integrity:
1.  In `_start`, push `0xCAFEBABE` onto the stack before calling `main`.
2.  After migration, in `resume_remote`, pop the top value and check if it equals `0xCAFEBABE`.
3.  If not, the network transmission was corrupted or offset.

---

**[End of Volume II]**
