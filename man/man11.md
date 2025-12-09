# THE BARE-METAL DISTRIBUTED CONTINUUM
## Master Technical Specification & Implementation Manual

**Volume XI: The Continuum Unikernel (Ring 0)**

**Project:** The Continuum Runtime
**Author:** Christian Schladetsch
**Version:** 1.0.0 (Volume XI)
**Scope:** Bootloaders, Long Mode, IDT/GDT, Bare-Metal Networking (e1000)

---

# CHAPTER 1: THE UNIKERNEL MANIFESTO

## 1.1 The Host OS Tax
Running Continuum on Linux or Windows involves an unnecessary "middleman." The Host OS manages virtual memory, handles scheduling, and enforces security rings that we do not need.
* **Context Switches:** Every `syscall` costs hundreds of cycles.
* **Memory Overhead:** The Host OS consumes GBs of RAM.
* **Latency:** Hardware interrupts must pass through the Host ISR before reaching us.

## 1.2 The "Metal" Solution
We convert the Continuum Runtime into a bootable **Unikernel**.
1.  **Boot:** The BIOS/UEFI loads our binary into memory.
2.  **Takeover:** We switch the CPU to Long Mode (64-bit).
3.  **Drive:** We talk directly to the NIC (Network Interface Card) via MMIO.
4.  **Execute:** The migration logic runs in Ring 0 with absolute power.

---

# CHAPTER 2: BOOTSTRAPPING (THE MULTIBOOT HEADER)

To be bootable by standard loaders (GRUB, QEMU), we must prepend a **Multiboot2** header to our binary.

## 2.1 The Header (`boot.asm`)

```nasm
section .multiboot_header
align 8
header_start:
    dd 0xE85250D6                ; Magic Number (Multiboot2)
    dd 0                         ; Architecture (i386 - protected mode)
    dd header_end - header_start ; Header Length
    dd 0x100000000 - (0xE85250D6 + 0 + (header_end - header_start)) ; Checksum

    ; Tags (End Tag)
    dw 0, 0
    dd 8
header_end:
```

## 2.2 The Transition to Long Mode
The CPU starts in 32-bit Protected Mode. We must manually set up Paging to enter 64-bit Long Mode.

```nasm
section .text
bits 32
global _start

_start:
    ; 1. Set up a basic stack
    mov esp, stack_top

    ; 2. Check for CPUID support
    ; (Code omitted: verify CPU supports Long Mode)

    ; 3. Set up Paging (Identity Map first 4GB)
    call setup_page_tables
    
    ; 4. Enable PAE (Physical Address Extension)
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax
    
    ; 5. Switch to Long Mode (EFER MSR)
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr
    
    ; 6. Enable Paging
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax
    
    ; 7. Jump to 64-bit code segment
    lgdt [gdt64.pointer]
    jmp gdt64.code_seg:long_mode_entry

bits 64
long_mode_entry:
    ; WE ARE NOW IN 64-BIT RING 0
    ; Update segment registers
    mov ax, 0
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    ; Jump to the Continuum Main
    call kernel_main
    hlt
```

---

# CHAPTER 3: HARDWARE INTERRUPTS (IDT)

In Ring 0, there are no syscalls. If the code crashes, the CPU throws an Exception (Interrupt). If we don't handle it, the machine triple-faults and reboots.

## 3.1 The Interrupt Descriptor Table (IDT)
We must define a table of 256 entries telling the CPU what to do for each interrupt vector.

```nasm
; IDT Entry Structure (16 bytes)
struc IDT_Entry
    .offset_low  resw 1
    .selector    resw 1
    .ist         resb 1
    .types_attr  resb 1
    .offset_mid  resw 1
    .offset_high resd 1
    .zero        resd 1
endstruc

section .bss
    idt_table: resb 16 * 256
    idt_ptr:   resw 1
               resq 1

section .text
setup_idt:
    ; Fill IDT with Default Handler
    mov rbx, idt_table
    mov rcx, 256
.loop:
    ; (Fill logic: sets offset to 'isr_default')
    add rbx, 16
    loop .loop
    
    ; Load IDT
    lidt [idt_ptr]
    sti             ; Enable Interrupts
    ret

isr_default:
    ; Panic Handler
    ; Print "CPU EXCEPTION" to Screen VGA Buffer
    mov qword [0xB8000], 0x4F524F45 ; "ER" (Red on White)
    hlt
```

---

# CHAPTER 4: BARE-METAL NETWORKING (THE E1000 DRIVER)

We cannot use sockets. We must write a driver for the **Intel 8254x (e1000)** network card, which is the standard emulated NIC in QEMU/Cloud environments.

## 4.1 PCI Enumeration
First, we scan the PCI bus to find the device with VendorID `0x8086` and DeviceID `0x100E`.

```nasm
; -----------------------------------------------------------------------
; ROUTINE: pci_scan
; OUTPUTS: RAX = Base Address Register (MMIO Address)
; -----------------------------------------------------------------------
pci_scan:
    ; (Loop Bus 0-255, Device 0-31, Function 0-7)
    ; Out 0xCF8 (Address), In 0xCFC (Data)
    ; If match, read BAR0
    ret
```

## 4.2 Initialization
We must configure the Receive (RX) and Transmit (TX) ring buffers via Memory Mapped I/O (MMIO).

```nasm
; -----------------------------------------------------------------------
; ROUTINE: e1000_init
; INPUTS:  RDI = MMIO Base Address
; -----------------------------------------------------------------------
e1000_init:
    ; 1. Allocate RX/TX Descriptors in Memory
    ; (Use fixed address 0x200000 for Ring Buffers)
    
    ; 2. Program RDBAL/RDBAH (Receive Descriptor Base)
    mov [rdi + 0x2800], 0x00200000  ; Low 32 bits
    mov [rdi + 0x2804], 0           ; High 32 bits
    
    ; 3. Program RDLEN (Length)
    mov [rdi + 0x2808], 128         ; 8 descriptors * 16 bytes
    
    ; 4. Program RCTL (Receive Control)
    ; Enable + Broadcast + Strip CRC
    mov [rdi + 0x0100], 0x8018
    
    ret
```

## 4.3 Sending a Packet (Raw Ethernet)
We do not have a TCP stack yet. We send Raw Ethernet Frames.
`[Dest MAC] [Src MAC] [EtherType] [Payload]`

```nasm
; -----------------------------------------------------------------------
; ROUTINE: e1000_send
; INPUTS:  RSI = Data, RCX = Length
; -----------------------------------------------------------------------
e1000_send:
    ; 1. Get Tail Index from TDT Register
    ; 2. Write Address/Length to TX Descriptor Ring
    ; 3. Set Command Byte (EOP - End of Packet)
    ; 4. Increment Tail
    ret
```

---

# CHAPTER 5: THE CONTINUUM MICRO-TCP STACK

Since we are bare metal, we must implement a minimal TCP state machine to support the migration protocol defined in Volume V.

## 5.1 The `tcp_handshake` Routine
We manually construct the SYN packet.

```nasm
; -----------------------------------------------------------------------
; ROUTINE: net_connect
; INPUTS:  EAX = Target IP
; -----------------------------------------------------------------------
net_connect:
    ; 1. Construct Ethernet Header
    ; 2. Construct IP Header (Proto = 6)
    ; 3. Construct TCP Header (Flags = SYN)
    ; 4. Checksum Calculation (1s complement sum)
    ; 5. Call e1000_send
    
    ; 6. Busy Wait for SYN-ACK interrupt/poll
    call net_poll
    ; 7. Send ACK
    ret
```

## 5.2 The `OS_WRITE` Hook
We patch the `platform.inc` from Volume III to point to our driver.

```nasm
%define OS_METAL

%ifdef OS_METAL
    %macro OS_WRITE 3
        ; RDI = "Socket" (Ignored in unikernel single-connection mode)
        ; RSI = Buffer
        ; RDX = Length
        call tcp_send_stream
    %endmacro
%endif
```

---

# CHAPTER 6: THE FINAL BUILD (ISO GENERATION)

We do not generate an `.exe` or ELF. We generate a `.iso` image.

## 6.1 Linker Script (`linker.ld`)
We must layout the kernel sections precisely.

```ld
ENTRY(_start)
SECTIONS {
    . = 1M;
    .boot : { *(.multiboot_header) }
    .text : { *(.text) }
    .rodata : { *(.rodata) }
    .data : { *(.data) }
    .bss : { *(.bss) }
}
```

## 6.2 Build Commands

```bash
# 1. Assemble
nasm -f elf64 -D OS_METAL kernel.asm -o kernel.o

# 2. Link
ld -n -T linker.ld -o kernel.bin kernel.o

# 3. Create ISO (using grub-mkrescue)
mkdir -p isodir/boot/grub
cp kernel.bin isodir/boot/
echo 'menuentry "Continuum" { multiboot2 /boot/kernel.bin; boot }' > isodir/boot/grub/grub.cfg
grub-mkrescue -o continuum.iso isodir
```

---

# EPILOGUE: THE PLANETARY COMPUTER

With Volume XI, the Continuum is no longer software. It is a **firmware**.
You can flash `continuum.iso` onto 1,000 servers, boot them, and they immediately form a mesh. There is no OS. There is no login. There is only the Stack, flowing like electricity through the datacenter.

**[END OF VOLUME XI]**
