# THE BARE-METAL DISTRIBUTED CONTINUUM
## Master Technical Specification & Implementation Manual

**Volume XII: Distributed Consensus, Time & The Immutable Log**

**Project:** The Continuum Runtime
**Author:** Christian Schladetsch
**Version:** 1.0.0 (Volume XII)
**Scope:** Lamport Timestamps, Raft Consensus, Split-Brain Resolution

---

# CHAPTER 1: THE RELATIVISTIC TIME PROBLEM

In a distributed system running on bare metal, there is no "Global Clock." System RTCs (Real-Time Clocks) drift. If Node A thinks it is 12:00:01 and Node B thinks it is 12:00:00, causal ordering breaks down.

We cannot use NTP (Network Time Protocol) because it is an external dependency. We must implement **Logical Clocks**.

## 1.1 The Lamport Clock
Every event in the system is tagged with a 64-bit integer $T$.
* **Rule 1:** Before any event (instruction block), $T = T + 1$.
* **Rule 2:** On sending a message, attach $T$.
* **Rule 3:** On receiving a message with timestamp $T_{msg}$, update local clock: $T_{local} = \max(T_{local}, T_{msg}) + 1$.



## 1.2 ASM Implementation (`sys_tick`)
This routine is called before every `sys_migrate` or `sys_put_block`.

```nasm
section .data
    logical_clock dq 0

section .text
; -----------------------------------------------------------------------
; ROUTINE: sys_tick
; OUTPUTS: RAX = New Timestamp
; -----------------------------------------------------------------------
sys_tick:
    ; Atomic Increment (LOCK prefix for thread safety if SMP)
    lock inc qword [rel logical_clock]
    mov rax, [rel logical_clock]
    ret

; -----------------------------------------------------------------------
; ROUTINE: sys_sync_clock
; INPUTS:  RAX = Received Timestamp
; -----------------------------------------------------------------------
sys_sync_clock:
    mov rbx, [rel logical_clock]
    cmp rax, rbx
    jle .ignore             ; If received <= local, do nothing
    
    ; If received > local, update atomic
    ; loop CAS (Compare And Swap) for safety
.retry:
    mov rbx, [rel logical_clock]
    cmp rax, rbx
    jle .ignore
    
    ; Try to set logical_clock = RAX + 1
    mov rcx, rax
    inc rcx
    
    lock cmpxchg [rel logical_clock], rcx
    jnz .retry              ; If failed, retry
    
.ignore:
    ret
```

---

# CHAPTER 2: THE CONSENSUS ENGINE (RAFT IN ASM)

To manage global state (like the `peer_table` or file locks), we need a consensus algorithm. We implement a simplified **Raft Protocol** in assembly.

## 2.1 The State Machine
Each node exists in one of three states:
1.  **Follower:** Listens for heartbeats from a Leader.
2.  **Candidate:** Time-out elapsed; requesting votes.
3.  **Leader:** Sending heartbeats; appending to the log.



## 2.2 The Term Structure
State must be persisted to the stack (or DHT) to survive migration.
* `CurrentTerm` (8 bytes)
* `VotedFor` (4 bytes IP)
* `LogIndex` (8 bytes)

## 2.3 Leader Election (The "Vote" Packet)
When a Follower times out (randomized 150-300ms), it becomes a Candidate.

```nasm
; -----------------------------------------------------------------------
; ROUTINE: become_candidate
; -----------------------------------------------------------------------
become_candidate:
    ; 1. Increment Term
    inc qword [rel current_term]
    
    ; 2. Vote for Self
    mov eax, [rel my_ip]
    mov [rel voted_for], eax
    
    ; 3. Reset Vote Count
    mov qword [rel vote_count], 1
    
    ; 4. Broadcast RequestVote RPC
    ; Packet: [RPC_VOTE] [Term] [CandidateID] [LastLogIndex] [LastLogTerm]
    call broadcast_vote_request
    
    ; 5. Reset Election Timer
    call reset_timer
    ret
```

## 2.4 Handling Votes
The incoming packet handler for `RPC_VOTE_REPLY`.

```nasm
handle_vote_reply:
    ; Input: Payload contains Granted (1) or Denied (0)
    cmp byte [rsi], 1
    jne .denied
    
    inc qword [rel vote_count]
    
    ; Check for Majority
    mov rax, [rel vote_count]
    mov rbx, [rel peer_count]
    shr rbx, 1              ; RBX = PeerCount / 2
    cmp rax, rbx
    jg .become_leader
    
    ret

.become_leader:
    call transition_to_leader
    ret
```

---

# CHAPTER 3: THE REPLICATED LOG (APPEND-ONLY)

Once a Leader is elected, it accepts commands (e.g., "Lock File X") and replicates them to Followers. The command is not "Committed" until a majority have acked it.

## 3.1 The Log Entry Structure
* `Term` (8 bytes)
* `CommandID` (8 bytes)
* `DataLen` (8 bytes)
* `Data` (Variable)

## 3.2 The `append_entries` Logic
This routine ensures log consistency. If a Follower finds a mismatch in its history, it rejects the append, forcing the Leader to backpedal and repair the log.

```nasm
; -----------------------------------------------------------------------
; ROUTINE: handle_append_entries
; INPUTS:  RSI = Packet Payload
; -----------------------------------------------------------------------
handle_append_entries:
    ; 1. Check Term
    mov rax, [rsi]          ; Packet Term
    mov rbx, [rel current_term]
    cmp rax, rbx
    jl .reject              ; Stale leader
    
    ; 2. Update Term (if newer)
    mov [rel current_term], rax
    call become_follower    ; If we were candidate, step down
    
    ; 3. Check Log Consistency (PrevLogIndex)
    ; (Omitted for brevity: compare log[PrevIndex].Term with packet)
    
    ; 4. Append Data to Local Log
    call log_write_entry
    
    ; 5. Send Success ACK
    call send_append_ack
    ret

.reject:
    call send_append_nack
    ret
```

---

# CHAPTER 4: THE SPLIT-BRAIN RESOLUTION

In a bare-metal cluster, network partitions are common. We might end up with two Leaders.

## 4.1 Term Supremacy
The logic in **3.2** handles this automatically.
* If Leader A (Term 5) sees a packet from Leader B (Term 6).
* Leader A sees `Term 6 > Term 5`.
* Leader A immediately demotes itself to **Follower**.

This guarantees that the cluster always converges on the Leader with the highest Term, healing the split brain as soon as the network heals.

---

# CHAPTER 5: ATOMIC BROADCAST (TOTAL ORDERING)

We expose this consensus engine to the user via a new system call: `sys_atomic_broadcast`.

## 5.1 The User Contract
Instead of `sys_send` (which is unicast), the user calls `sys_atomic_broadcast`.
* **Guarantee:** If Node X processes Message A before Message B, **all** nodes will process A before B.

```nasm
; -----------------------------------------------------------------------
; ROUTINE: sys_atomic_broadcast
; INPUTS:  RSI = Data, RCX = Length
; -----------------------------------------------------------------------
sys_atomic_broadcast:
    ; 1. Check Identity
    cmp byte [rel node_state], STATE_LEADER
    je .process_locally
    
    ; 2. If Follower, forward to Leader
    call get_leader_ip
    mov rdi, rax
    call sys_send_forward_packet
    ret

.process_locally:
    ; 3. Append to Log
    call log_append
    
    ; 4. Replicate to Peers
    call broadcast_append_entries
    
    ; 5. Wait for Quorum (Blocking)
    call wait_for_commit
    ret
```

---

# CHAPTER 6: INTEGRATION TEST ("THE BANK")

To prove consensus works, we build a **Distributed Bank**.
* **Account Balance:** Stored in the Replicated Log.
* **Transaction:** `transfer(A, B, 100)`.
* **Constraint:** Double-spends must be impossible, even if two nodes initiate transfers simultaneously.

## 6.1 The Application Logic

```nasm
bank_transfer:
    ; 1. Construct Transaction Packet
    ; [TX_TYPE] [FROM] [TO] [AMOUNT]
    
    ; 2. Atomic Broadcast
    ; This ensures that even if Node A and Node B try to spend
    ; the same money at the exact same nanosecond, the Leader
    ; will sequence them linearly (e.g., TX #50 and TX #51).
    call sys_atomic_broadcast
    
    ; 3. Apply Local State
    ; Once sys_atomic_broadcast returns, we know the TX is
    ; committed to the global log. We update our display.
    call update_ui
    ret
```

---

**[End of Volume XII]**
