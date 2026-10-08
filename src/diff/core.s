.include "rhun.inc"
.include "diff/diff.inc"
.text
# DF, base index, target index, type, status, reason -> result.
FN diff_result_add
    PROLOGUE 24
    mov [rsp], esi
    mov [rsp + 4], edx
    mov [rsp + 8], ecx
    mov [rsp + 12], r8d
    mov [rsp + 16], r9d
    lea rdi, [rdi + DF_results]
    mov esi, DR_SIZE
    call vec_push
    mov rdi, rax
    mov rsi, rsp
    mov edx, DR_SIZE
    call memcpy
    EPILOGUE
# Graph*, edge* -> exact typed edge 1-based index.
FN diff_edge_index
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    xor r13d, r13d
1:  cmp r13, [rbx + DG_links + VEC_len]
    jae 8f
    imul r14, r13, DE_SIZE
    add r14, [rbx + DG_links + VEC_ptr]
    mov eax, [r12 + DE_kind]
    cmp [r14 + DE_kind], eax
    jne 7f
    mov rdi, [r12 + DE_from]
    mov rsi, [r14 + DE_from]
    call strcmp_eq
    test eax, eax
    jz 7f
    mov rdi, [r12 + DE_to]
    mov rsi, [r14 + DE_to]
    call strcmp_eq
    test eax, eax
    jnz 9f
7:  inc r13
    jmp 1b
8:  xor eax, eax
    EPILOGUE
9:  lea eax, [r13 + 1]
    EPILOGUE
# Base and target already owned. Transfer ownership only on success.
FN diff_compare
    PROLOGUE 32
    mov rbx, rdi
    mov r12, rsi
    mov rdi, [rbx + DG_base]
    mov rsi, [r12 + DG_base]
    call strcmp_eq
    test eax, eax
    jz .Lnull
    mov eax, [rbx + DG_profile]
    cmp [r12 + DG_profile], eax
    jne .Lnull
    mov rdi, [rbx + DG_snapshot]
    mov rsi, [r12 + DG_snapshot]
    call strcmp_eq
    test eax, eax
    jz .Lnull
    xor r13d, r13d
.Lscope:
    cmp r13, [r12 + DG_scope + VEC_len]
    jae .Lvalidate_nodes
    mov rax, [r12 + DG_scope + VEC_ptr]
    mov rsi, [rax + r13*8]
    lea rdi, [rbx + DG_nodes]
    call diff_node_id
    test eax, eax
    jz .Lnull
    inc r13
    jmp .Lscope
.Lvalidate_nodes: xor r13d, r13d
.Lvalidate_node:
    cmp r13, [r12 + DG_nodes + VEC_len]
    jae .Lstart
    imul r14, r13, DN_SIZE
    add r14, [r12 + DG_nodes + VEC_ptr]
    lea rdi, [rbx + DG_nodes]
    mov rsi, [r14 + DN_id]
    call diff_node_id
    test eax, eax
    jz .Lvalidate_more
    lea rdi, [r12 + DG_scope]
    mov rsi, [r14 + DN_id]
    call diff_scope_id
    test eax, eax
    jz .Lnull
.Lvalidate_more: inc r13
    jmp .Lvalidate_node
.Lstart:
    mov edi, DF_SIZE
    call mem_alloc
    mov r15, rax
    mov [rax + DF_base], rbx
    mov [rax + DF_target], r12
    mov dword ptr [rax + DF_show], 1
    mov dword ptr [rax + DF_cursor], -1
    xor r13d, r13d
.Lnode:
    cmp r13, [r12 + DG_nodes + VEC_len]
    jae .Lmissing_start
    imul r14, r13, DN_SIZE
    add r14, [r12 + DG_nodes + VEC_ptr]
    lea rdi, [rbx + DG_nodes]
    mov rsi, [r14 + DN_id]
    call diff_node_id
    mov [rsp], eax
    mov dword ptr [rsp + 4], 1
    mov dword ptr [rsp + 8], 1
    test eax, eax
    jz .Lnode_add
    dec eax
    imul rax, DN_SIZE
    add rax, [rbx + DG_nodes + VEC_ptr]
    mov [rsp + 16], rax
    mov dword ptr [rsp + 4], 0
    mov dword ptr [rsp + 8], 0
    mov rcx, [r14 + DN_addr64]
    cmp [rax + DN_addr64], rcx
    je .Lproperties
    mov dword ptr [rsp + 4], 2
    mov dword ptr [rsp + 8], 2
    jmp .Lnode_add
.Lproperties:
    mov ecx, DN_kind
    mov edx, 1
    mov r8d, 3
.Lproperty:
    mov rax, [rsp + 16]
    cmp dword ptr [r14 + rcx], -1
    je .Lproperty_more
    test [rax + DN_known], edx
    jnz .Lproperty_known
    cmp dword ptr [rsp + 4], 2
    je .Lproperty_more
    mov dword ptr [rsp + 4], 4
    mov dword ptr [rsp + 8], 9
    jmp .Lproperty_more
.Lproperty_known:
    mov esi, [r14 + rcx]
    cmp [rax + rcx], esi
    je .Lproperty_more
    mov dword ptr [rsp + 4], 2
    mov [rsp + 8], r8d
.Lproperty_more:
    add ecx, 4
    shl edx, 1
    inc r8d
    cmp ecx, DN_state
    jbe .Lproperty
.Lnode_add:
    mov rdi, r15
    mov esi, [rsp]
    lea edx, [r13 + 1]
    xor ecx, ecx
    mov r8d, [rsp + 4]
    mov r9d, [rsp + 8]
    call diff_result_add
    inc r13
    jmp .Lnode
.Lmissing_start:
    cmp dword ptr [r12 + DG_complete], 0
    je .Ledges_start
    xor r13d, r13d
.Lmissing:
    cmp r13, [rbx + DG_nodes + VEC_len]
    jae .Ledges_start
    imul r14, r13, DN_SIZE
    add r14, [rbx + DG_nodes + VEC_ptr]
    lea rdi, [r12 + DG_scope]
    mov rsi, [r14 + DN_id]
    call diff_scope_id
    test eax, eax
    jz .Lmissing_more
    lea rdi, [r12 + DG_nodes]
    mov rsi, [r14 + DN_id]
    call diff_node_id
    test eax, eax
    jnz .Lmissing_more
    mov rdi, r15
    lea esi, [r13 + 1]
    xor edx, edx
    xor ecx, ecx
    mov r8d, 3
    mov r9d, 7
    call diff_result_add
.Lmissing_more: inc r13
    jmp .Lmissing
.Ledges_start: xor r13d, r13d
.Ledge:
    cmp r13, [r12 + DG_links + VEC_len]
    jae .Lmissing_edges_start
    imul r14, r13, DE_SIZE
    add r14, [r12 + DG_links + VEC_ptr]
    mov rdi, rbx
    mov rsi, r14
    call diff_edge_index
    mov [rsp], eax
    xor r8d, r8d
    xor r9d, r9d
    test eax, eax
    jnz .Ledge_add
    mov r8d, 1
    mov r9d, 8
    xor ecx, ecx
.Ledge_known:
    cmp rcx, [rbx + DG_links + VEC_len]
    jae .Ledge_unknown
    imul rax, rcx, DE_SIZE
    add rax, [rbx + DG_links + VEC_ptr]
    mov edx, [rax + DE_kind]
    cmp [r14 + DE_kind], edx
    jne .Ledge_known_more
    mov [rsp + 16], rcx
    mov rdi, [rax + DE_from]
    mov rsi, [r14 + DE_from]
    call strcmp_eq
    mov rcx, [rsp + 16]
    test eax, eax
    jz .Ledge_known_more
    mov r8d, 2
    mov r9d, 8
    jmp .Ledge_add
.Ledge_known_more: inc rcx
    jmp .Ledge_known
.Ledge_unknown:
    mov r8d, 1
    mov r9d, 8
.Ledge_add:
    mov rdi, r15
    mov esi, [rsp]
    lea edx, [r13 + 1]
    mov ecx, 1
    call diff_result_add
    inc r13
    jmp .Ledge
.Lmissing_edges_start:
    cmp dword ptr [r12 + DG_complete], 0
    je .Ldone
    xor r13d, r13d
.Lmissing_edge:
    cmp r13, [rbx + DG_links + VEC_len]
    jae .Ldone
    imul r14, r13, DE_SIZE
    add r14, [rbx + DG_links + VEC_ptr]
    lea rdi, [r12 + DG_scope]
    mov rsi, [r14 + DE_from]
    call diff_scope_id
    test eax, eax
    jz .Lmissing_edge_more
    lea rdi, [r12 + DG_scope]
    mov rsi, [r14 + DE_to]
    call diff_scope_id
    test eax, eax
    jz .Lmissing_edge_more
    mov rdi, r12
    mov rsi, r14
    call diff_edge_index
    test eax, eax
    jnz .Lmissing_edge_more
    mov rdi, r15
    lea esi, [r13 + 1]
    xor edx, edx
    mov ecx, 1
    mov r8d, 3
    mov r9d, 7
    call diff_result_add
.Lmissing_edge_more: inc r13
    jmp .Lmissing_edge
.Ldone: mov rax, r15
    EPILOGUE
.Lnull: xor eax, eax
    EPILOGUE
