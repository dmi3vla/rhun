.include "rhun.inc"
.include "canvas/canvas.inc"
.include "memory/memory.inc"
.include "diff/diff.inc"
.text
# Non-security FNV-1a binding over native serialization; view state is excluded.
FN diff_binding
    PROLOGUE SB_SIZE+32
    mov rbx, rdi
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE+32
    call memset
    mov rdi, rbx
    mov rsi, rsp
    call scene_serialize
    mov rsi, [rsp + SB_ptr]
    mov rcx, [rsp + SB_len]
    mov rax, 0xcbf29ce484222325
    mov rdx, 0x100000001b3
1:  test rcx, rcx
    jz 2f
    movzx edi, byte ptr [rsi]
    xor rax, rdi
    imul rax, rdx
    inc rsi
    dec rcx
    jmp 1b
2:  lea rdi, [rsp + SB_SIZE]
    mov rsi, rax
    call fmt_hex
    lea rdi, [rsp + SB_SIZE]
    mov rsi, rax
    call mem_dup
    mov rbx, rax
    mov rdi, rsp
    call sb_free
    mov rax, rbx
    EPILOGUE
# Add owned source scope ID. DG*, string.
FN diff_scope_add
    PROLOGUE
    mov rbx, rdi
    mov rdi, rsi
    call memory_strdup
    mov r12, rax
    lea rdi, [rbx + DG_scope]
    mov esi, 8
    call vec_push
    mov [rax], r12
    EPILOGUE
# Add edge with copied IDs, kind. DG*, from*, to*, kind.
FN diff_edge_add
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14d, ecx
    lea rdi, [rbx + DG_links]
    mov esi, DE_SIZE
    call vec_push
    mov r15, rax
    mov rdi, r12
    call memory_strdup
    mov [r15 + DE_from], rax
    mov rdi, r13
    call memory_strdup
    mov [r15 + DE_to], rax
    mov [r15 + DE_kind], r14d
    EPILOGUE
# Immutable owned facts for the current profile, no derived arrows used as facts.
FN diff_base_build
    PROLOGUE 48
    mov rbx, rdi
    mov edi, DG_SIZE
    call mem_alloc
    mov r12, rax
    mov rdi, rbx
    call diff_binding
    mov [r12 + DG_base], rax
    lea rdi, [rip + .Lempty]
    call memory_strdup
    mov [r12 + DG_snapshot], rax
    mov dword ptr [r12 + DG_complete], 1
    mov rax, [rbx + SC_memory]
    test rax, rax
    jz .Lcfg
    cmp byte ptr [rax], 0
    je .Lcfg
    mov rdi, rbx
    call memory_prepare
    test rax, rax
    jz .Lbad
    mov r13, rax
    mov dword ptr [r12 + DG_profile], 1
    mov rdi, rax
    call memory_snapshot
    mov r14, rax
    mov rdi, [r12 + DG_snapshot]
    call mem_free
    mov rdi, [r14 + MS_id]
    call memory_strdup
    mov [r12 + DG_snapshot], rax
    xor r15d, r15d
.Lmn:
    cmp r15, [r14 + MS_nodes + VEC_len]
    jae .Lml_start
    imul rax, r15, MN_SIZE
    add rax, [r14 + MS_nodes + VEC_ptr]
    mov [rsp], rax
    lea rdi, [r12 + DG_nodes]
    mov esi, DN_SIZE
    call vec_push
    mov [rsp + 8], rax
    mov rdi, rax
    xor esi, esi
    mov edx, DN_SIZE
    call memset
    xor ecx, ecx
.Lmn_strings:
    mov [rsp + 16], ecx
    mov rax, [rsp]
    lea rdx, [rip + .Lmn_offsets]
    movsxd rcx, dword ptr [rdx + rcx*4]
    mov rdi, [rax + rcx]
    call memory_strdup
    mov ecx, [rsp + 16]
    mov rdx, [rsp + 8]
    mov [rdx + rcx*8], rax
    inc ecx
    cmp ecx, 3
    jb .Lmn_strings
    mov rdx, [rsp + 8]
    mov rcx, [rsp]
    mov eax, [rcx + MN_kind]
    mov [rdx + DN_kind], eax
    mov eax, [rcx + MN_size]
    mov [rdx + DN_size], eax
    mov eax, [rcx + MN_capacity]
    mov [rdx + DN_capacity], eax
    mov eax, [rcx + MN_state]
    mov [rdx + DN_state], eax
    mov dword ptr [rdx + DN_confidence], -1
    mov dword ptr [rdx + DN_known], 1
    cmp dword ptr [rcx + MN_kind], 3
    jne .Lmn_known
    cmp dword ptr [rcx + MN_certainty], 0
    jne .Lmn_known
    or dword ptr [rdx + DN_known], 6
    cmp dword ptr [rcx + MN_state], 2
    je .Lmn_known
    or dword ptr [rdx + DN_known], 8
.Lmn_known:
    lea rax, [r15 + 1]
    mov [rdx + DN_ref], rax
    mov rdi, [rdx + DN_address]
    call memory_address
    mov rdx, [rsp + 8]
    mov [rdx + DN_addr64], rax
    mov rdi, r12
    mov rsi, [rdx + DN_id]
    call diff_scope_add
    inc r15
    jmp .Lmn
.Lml_start: xor r15d, r15d
.Lml:
    cmp r15, [r14 + MS_links + VEC_len]
    jae .Ldone
    imul rax, r15, ML_SIZE
    add rax, [r14 + MS_links + VEC_ptr]
    mov rdi, r12
    mov rsi, [rax + ML_from]
    mov rdx, [rax + ML_to]
    mov ecx, [rax + ML_kind]
    call diff_edge_add
    inc r15
    jmp .Lml
.Lcfg:
    mov rax, [rbx + SC_analysis]
    test rax, rax
    jz .Lbad
    cmp byte ptr [rax], 0
    je .Lbad
    xor r13d, r13d
.Lcn:
    cmp r13, [rbx + SC_elements + VEC_len]
    jae .Lcl_start
    imul r14, r13, CE_SIZE
    add r14, [rbx + SC_elements + VEC_ptr]
    mov rdi, [r14 + CE_gxid]
    test rdi, rdi
    jz .Lcn_more
    lea rsi, [rip + r2_block_marker]
    call strcmp_eq
    test eax, eax
    jz .Lcn_more
    cmp qword ptr [r12 + DG_nodes + VEC_len], 512
    jae .Lbad
    lea rdi, [r12 + DG_nodes]
    mov esi, DN_SIZE
    call vec_push
    mov r15, rax
    mov rdi, rax
    xor esi, esi
    mov edx, DN_SIZE
    call memset
    mov rdi, [r14 + CE_id]
    call radare_id_string
    mov [r15 + DN_id], rax
    mov rdi, [r14 + CE_xid]
    call memory_decimal_address
    mov [r15 + DN_address], rax
    mov rdi, rax
    call memory_strdup
    mov [r15 + DN_label], rax
    mov dword ptr [r15 + DN_size], -1
    mov dword ptr [r15 + DN_capacity], -1
    mov dword ptr [r15 + DN_state], -1
    mov dword ptr [r15 + DN_confidence], -1
    mov dword ptr [r15 + DN_known], 1
    mov rax, [r14 + CE_id]
    mov [r15 + DN_ref], rax
    mov rax, [r14 + CE_frame]
    mov [r15 + DN_frame], rax
    mov rdi, [r15 + DN_address]
    call memory_address
    mov [r15 + DN_addr64], rax
    mov rdi, r12
    mov rsi, [r15 + DN_id]
    call diff_scope_add
.Lcn_more: inc r13
    jmp .Lcn
.Lcl_start: xor r13d, r13d
.Lcl:
    cmp r13, [r12 + DG_nodes + VEC_len]
    jae .Ldone
    imul r14, r13, DN_SIZE
    add r14, [r12 + DG_nodes + VEC_ptr]
    mov rdi, rbx
    mov rsi, [r14 + DN_ref]
    call scene_find
    mov rdi, [rax + CE_raw]
    test rdi, rdi
    jz .Lcl_more
    mov [rsp], rdi
    call strlen
    mov rsi, rax
    mov rdi, [rsp]
    call json_parse_complete
    test rax, rax
    jz .Lcl_more
    mov rdi, rax
    lea rsi, [rip + .Lr2]
    call json_get
    mov [rsp], rax
    xor r15d, r15d
.Lbranch:
    mov rdi, [rsp]
    lea rax, [rip + .Lbranches]
    mov rsi, [rax + r15*8]
    call json_get
    mov rdi, rax
    call radare_number
    test edx, edx
    jz .Lbranch_more
    xor ecx, ecx
.Ltarget:
    cmp rcx, [r12 + DG_nodes + VEC_len]
    jae .Lbranch_more
    imul rdx, rcx, DN_SIZE
    add rdx, [r12 + DG_nodes + VEC_ptr]
    cmp [rdx + DN_addr64], rax
    jne .Ltarget_more
    mov rsi, [r14 + DN_frame]
    cmp [rdx + DN_frame], rsi
    jne .Ltarget_more
    mov rdi, r12
    mov rsi, [r14 + DN_id]
    mov rdx, [rdx + DN_id]
    mov ecx, r15d
    call diff_edge_add
    jmp .Lbranch_more
.Ltarget_more: inc rcx
    jmp .Ltarget
.Lbranch_more: inc r15d
    cmp r15d, 2
    jb .Lbranch
.Lcl_more: inc r13
    jmp .Lcl
.Ldone:
    cmp qword ptr [r12 + DG_nodes + VEC_len], 0
    je .Lbad
    mov rax, r12
    EPILOGUE
.Lbad: mov rdi, r12
    call diff_graph_free
    xor eax, eax
    EPILOGUE
.section .rodata
.Lempty: .asciz ""
.Lr2: .asciz "r2"
.Ljump: .asciz "jump"
.Lfail: .asciz "fail"
.Lbranches: .quad .Ljump, .Lfail
.Lmn_offsets: .long MN_id, MN_address, MN_label
