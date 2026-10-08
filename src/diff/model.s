.include "rhun.inc"
.include "diff/diff.inc"
.text
FN diff_graph_free
    PROLOGUE
    mov rbx, rdi
    test rbx, rbx
    jz 9f
    mov rdi, [rbx + DG_base]
    call mem_free
    mov rdi, [rbx + DG_snapshot]
    call mem_free
    lea rdi, [rbx + DG_nodes]
    mov esi, DN_SIZE
    mov ecx, 3
    call memory_records_free
    lea rdi, [rbx + DG_links]
    mov esi, DE_SIZE
    mov ecx, 2
    call memory_records_free
    lea rdi, [rbx + DG_scope]
    mov esi, 8
    mov ecx, 1
    call memory_records_free
    mov rdi, rbx
    call mem_free
9:  EPILOGUE
FN diff_free
    PROLOGUE
    mov rbx, rdi
    test rbx, rbx
    jz 9f
    mov rdi, [rbx + DF_base]
    call diff_graph_free
    mov rdi, [rbx + DF_target]
    call diff_graph_free
    lea rdi, [rbx + DF_results]
    call vec_free
    mov rdi, rbx
    call mem_free
9:  EPILOGUE
# vector of nodes, cstr -> 1-based index.
FN diff_node_id
    mov rdx, rsi
    mov esi, DN_SIZE
    jmp canvas_graph_id
FN diff_scope_id
    mov rdx, rsi
    mov esi, 8
    jmp canvas_graph_id
# Complete parse into independent owned storage, no arena pointers survive.
FN diff_parse
    PROLOGUE 24
    cmp rsi, 1 << 20
    ja .Lnull
    call json_parse_complete
    test rax, rax
    jz .Lnull
    cmp dword ptr [rax], JT_OBJ
    jne .Lnull
    cmp dword ptr [rax + 4], 9
    jne .Lnull
    mov r12, rax
    mov rdi, rax
    lea rsi, [rip + .Ltype]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Ltypename]
    call json_is
    test eax, eax
    jz .Lnull
    mov rdi, r12
    lea rsi, [rip + .Lversion]
    call json_get
    mov rdi, rax
    call scene_json_int
    test edx, edx
    jz .Lnull
    cmp rax, 1
    jne .Lnull
    mov edi, DG_SIZE
    call mem_alloc
    mov rbx, rax
    mov rdi, r12
    mov rsi, rax
    lea rdx, [rip + diff_root_fields]
    call canvas_graph_fields
    test eax, eax
    jz .Lbad
    mov rdi, r12
    lea rsi, [rip + .Lnodes]
    call json_get
    mov rdi, rax
    lea rsi, [rbx + DG_nodes]
    mov edx, DN_SIZE
    lea rcx, [rip + diff_node_fields]
    mov r8d, 8
    mov r9d, 512
    call memory_collection
    test eax, eax
    jz .Lbad
    lea rdi, [rbx + DG_nodes]
    mov esi, DN_SIZE
    call memory_unique
    test eax, eax
    jz .Lbad
    lea rdi, [rbx + DG_scope]
    mov esi, 8
    call memory_unique
    test eax, eax
    jz .Lbad
    cmp qword ptr [rbx + DG_scope + VEC_len], 0
    je .Lbad
    cmp qword ptr [rbx + DG_scope + VEC_len], 512
    ja .Lbad
    mov rdi, r12
    lea rsi, [rip + .Llinks]
    call json_get
    mov rdi, rax
    lea rsi, [rbx + DG_links]
    mov edx, DE_SIZE
    lea rcx, [rip + diff_edge_fields]
    mov r8d, 3
    mov r9d, 1024
    call memory_collection
    test eax, eax
    jz .Lbad
    xor r13d, r13d
.Lnode:
    cmp r13, [rbx + DG_nodes + VEC_len]
    jae .Ledges
    imul r14, r13, DN_SIZE
    add r14, [rbx + DG_nodes + VEC_ptr]
    mov rdi, [r14 + DN_address]
    call memory_address
    test edx, edx
    jz .Lbad
    mov [r14 + DN_addr64], rax
    inc r13
    jmp .Lnode
.Ledges: xor r13d, r13d
.Ledge:
    cmp r13, [rbx + DG_links + VEC_len]
    jae .Lok
    imul r14, r13, DE_SIZE
    add r14, [rbx + DG_links + VEC_ptr]
    mov r15d, DE_from
.Lendpoint:
    lea rdi, [rbx + DG_nodes]
    mov rsi, [r14 + r15]
    call diff_node_id
    test eax, eax
    jnz .Lnextendpoint
    lea rdi, [rbx + DG_scope]
    mov rsi, [r14 + r15]
    call diff_scope_id
    test eax, eax
    jz .Lbad
.Lnextendpoint:
    add r15d, 8
    cmp r15d, DE_to
    jbe .Lendpoint
    cmp dword ptr [rbx + DG_profile], 0
    jne .Ledge_next
    cmp dword ptr [r14 + DE_kind], 1
    ja .Lbad
.Ledge_next:
    # Reject duplicate typed edges.
    xor r15d, r15d
.Ldup:
    cmp r15, r13
    jae .Ledge_more
    imul rax, r15, DE_SIZE
    add rax, [rbx + DG_links + VEC_ptr]
    mov [rsp], rax
    mov ecx, [rax + DE_kind]
    cmp [r14 + DE_kind], ecx
    jne .Ldup_more
    mov rdi, [rax + DE_from]
    mov rsi, [r14 + DE_from]
    call strcmp_eq
    test eax, eax
    jz .Ldup_more
    mov rax, [rsp]
    mov rdi, [rax + DE_to]
    mov rsi, [r14 + DE_to]
    call strcmp_eq
    test eax, eax
    jnz .Lbad
.Ldup_more: inc r15
    jmp .Ldup
.Ledge_more: inc r13
    jmp .Ledge
.Lok: mov rax, rbx
    EPILOGUE
.Lbad: mov rdi, rbx
    call diff_graph_free
.Lnull: xor eax, eax
    EPILOGUE
.section .rodata
.Ltype: .asciz "type"
.Ltypename: .asciz "rhun-agent-claims"
.Lversion: .asciz "version"
.Lnodes: .asciz "nodes"
.Llinks: .asciz "links"
.globl diff_root_fields, diff_node_fields, diff_edge_fields
# The scope array is copied by the existing bounded string vector reader.
diff_root_fields:
.quad .Lbase, DG_base, 1, 0, 0
.quad .Lsnapshot, DG_snapshot, 1, 0, 0
.quad .Lprofile, DG_profile, 2, 0, 1
.quad .Lcomplete, DG_complete, 2, 0, 1
.quad .Lscope, DG_scope, 5, 0, 0
.quad 0
.Lbase: .asciz "base"
.Lsnapshot: .asciz "snapshot"
.Lprofile: .asciz "profile"
.Lcomplete: .asciz "complete"
.Lscope: .asciz "scope"
diff_node_fields:
.quad .Lid, DN_id, 1, 0, 0
.quad .Laddress, DN_address, 1, 0, 0
.quad .Llabel, DN_label, 1, 0, 0
.quad .Lkind, DN_kind, 2, -1, 4
.quad .Lsize, DN_size, 2, -1, 1073741824
.quad .Lcapacity, DN_capacity, 2, -1, 1073741824
.quad .Lstate, DN_state, 2, -1, 2
.quad .Lconfidence, DN_confidence, 2, -1, 100
.quad 0
.Lid: .asciz "id"
.Laddress: .asciz "address"
.Llabel: .asciz "label"
.Lkind: .asciz "kind"
.Lsize: .asciz "size"
.Lcapacity: .asciz "capacity"
.Lstate: .asciz "state"
.Lconfidence: .asciz "confidence"
diff_edge_fields:
.quad .Lfrom, DE_from, 1, 0, 0
.quad .Lto, DE_to, 1, 0, 0
.quad .Lkind, DE_kind, 2, 0, 4
.quad 0
.Lfrom: .asciz "from"
.Lto: .asciz "to"
