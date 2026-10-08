.include "rhun.inc"
.include "memory/memory.inc"
.text
# Exact rhun slot size (includes 16-byte header), matching src/mem.s.
FN memory_rhun_slot
    lea eax, [rdi + 16]
    cmp eax, 65536
    ja .Lslot_large
    dec eax
    or eax, 31
    bsr ecx, eax
    inc ecx
    mov eax, 1
    shl eax, cl
    ret
.Lslot_large:
    add eax, 4095
    and eax, -4096
    ret
# First field string IDs: nonempty, bounded, unique in this vector.
FN memory_unique
    PROLOGUE
    mov rbx, rdi
    mov r12d, esi
    xor r13d, r13d
.Lmu_each:
    cmp r13, [rbx + VEC_len]
    jae .Lmu_yes
    mov rax, r13
    imul rax, r12
    add rax, [rbx + VEC_ptr]
    mov r14, [rax]
    mov rdi, r14
    call strlen
    test rax, rax
    jz .Lmu_no
    cmp rax, 128
    ja .Lmu_no
    mov rdi, rbx
    mov esi, r12d
    mov rdx, r14
    call canvas_graph_id
    lea ecx, [r13d + 1]
    cmp eax, ecx
    jne .Lmu_no
    inc r13d
    jmp .Lmu_each
.Lmu_yes: mov eax, 1
    EPILOGUE
.Lmu_no: xor eax, eax
    EPILOGUE
FN memory_validate
    PROLOGUE 32
    mov rbx, rdi
    lea rdi, [rbx + MM_entrypoints]
    mov esi, ME_SIZE
    call memory_unique
    test eax, eax
    jz .Lmv_bad
    xor r12d, r12d
.Lmv_entry:
    cmp r12, [rbx + MM_entrypoints + VEC_len]
    jae .Lmv_snap_start
    imul rax, r12, ME_SIZE
    add rax, [rbx + MM_entrypoints + VEC_ptr]
    mov rdi, [rax + ME_address]
    call memory_address
    test edx, edx
    jz .Lmv_bad
    inc r12
    jmp .Lmv_entry
.Lmv_snap_start:
    lea rdi, [rbx + MM_snapshots]
    mov esi, MS_SIZE
    call memory_unique
    test eax, eax
    jz .Lmv_bad
    xor r12d, r12d
.Lmv_snap:
    cmp r12, [rbx + MM_snapshots + VEC_len]
    jae .Lmv_yes
    imul r13, r12, MS_SIZE
    add r13, [rbx + MM_snapshots + VEC_ptr]
    mov rdi, [r13 + MS_thread]
    cmp byte ptr [rdi], 0
    je .Lmv_bad
    mov r14d, MS_pc
.Lmv_register:
    mov rdi, [r13 + r14]
    call memory_address
    test edx, edx
    jz .Lmv_bad
    add r14d, 8
    cmp r14d, MS_bp
    jbe .Lmv_register
    lea rdi, [r13 + MS_nodes]
    mov esi, MN_SIZE
    call memory_unique
    test eax, eax
    jz .Lmv_bad
    xor r14d, r14d
.Lmv_node:
    cmp r14, [r13 + MS_nodes + VEC_len]
    jae .Lmv_links_start
    imul r15, r14, MN_SIZE
    add r15, [r13 + MS_nodes + VEC_ptr]
    mov rdi, [r15 + MN_address]
    call memory_address
    test edx, edx
    jz .Lmv_bad
    mov ecx, [r15 + MN_size]
    add rax, rcx
    jc .Lmv_bad
    mov rdi, [r15 + MN_source]
    call memory_address
    test edx, edx
    jz .Lmv_bad
    cmp dword ptr [r15 + MN_kind], 1
    jne .Lmv_allocation
    mov rdi, [r15 + MN_thread]
    mov rsi, [r13 + MS_thread]
    call strcmp_eq
    test eax, eax
    jz .Lmv_bad
.Lmv_allocation:
    cmp dword ptr [r15 + MN_kind], 3
    jne .Lmv_parent
    mov eax, [r15 + MN_size]
    cmp [r15 + MN_capacity], eax
    jb .Lmv_bad
    mov rdi, [rbx + MM_allocator]
    lea rsi, [rip + memory_rhun]
    call strcmp_eq
    test eax, eax
    jz .Lmv_parent
    mov edi, [r15 + MN_size]
    call memory_rhun_slot
    cmp [r15 + MN_capacity], eax
    jne .Lmv_bad
.Lmv_parent:
    mov rax, [r15 + MN_parent]
    mov dword ptr [rsp], 0
.Lmv_parent_chain:
    cmp byte ptr [rax], 0
    je .Lmv_node_next
    mov rdx, rax
    lea rdi, [r13 + MS_nodes]
    mov esi, MN_SIZE
    call canvas_graph_id
    test eax, eax
    jz .Lmv_bad
    inc dword ptr [rsp]
    mov ecx, [r13 + MS_nodes + VEC_len]
    cmp [rsp], ecx
    ja .Lmv_bad
    dec eax
    imul rax, MN_SIZE
    add rax, [r13 + MS_nodes + VEC_ptr]
    mov rax, [rax + MN_parent]
    jmp .Lmv_parent_chain
.Lmv_node_next:
    inc r14
    jmp .Lmv_node
.Lmv_links_start: xor r14d, r14d
.Lmv_link:
    cmp r14, [r13 + MS_links + VEC_len]
    jae .Lmv_snap_next
    imul r15, r14, ML_SIZE
    add r15, [r13 + MS_links + VEC_ptr]
    lea rdi, [r13 + MS_nodes]
    mov esi, MN_SIZE
    mov rdx, [r15 + ML_from]
    call canvas_graph_id
    test eax, eax
    jz .Lmv_bad
    mov [r15 + ML_a], eax
    lea rdi, [r13 + MS_nodes]
    mov esi, MN_SIZE
    mov rdx, [r15 + ML_to]
    call canvas_graph_id
    test eax, eax
    jz .Lmv_bad
    mov [r15 + ML_b], eax
    dec eax
    imul rax, MN_SIZE
    add rax, [r13 + MS_nodes + VEC_ptr]
    cmp dword ptr [r15 + ML_kind], 1
    je .Lmv_live_pointer
    cmp dword ptr [r15 + ML_kind], 3
    jne .Lmv_link_next
    cmp dword ptr [rax + MN_kind], 3
    jne .Lmv_bad
    cmp dword ptr [rax + MN_state], 1
    jne .Lmv_bad
    jmp .Lmv_link_next
.Lmv_live_pointer:
    cmp dword ptr [rax + MN_kind], 3
    jne .Lmv_bad
    cmp dword ptr [rax + MN_state], 0
    jne .Lmv_bad
.Lmv_link_next:
    inc r14
    jmp .Lmv_link
.Lmv_snap_next:
    inc r12
    jmp .Lmv_snap
.Lmv_yes: mov eax, 1
    EPILOGUE
.Lmv_bad: xor eax, eax
    EPILOGUE
