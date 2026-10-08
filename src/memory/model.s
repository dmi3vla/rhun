.include "rhun.inc"
.include "canvas/canvas.inc"
.include "memory/memory.inc"
.text
# Free a vector of records whose first ecx fields are owned string pointers.
FN memory_records_free
    PROLOGUE
    mov rbx, rdi
    mov r12d, esi
    mov r13d, ecx
    xor r14d, r14d
.Lrf_record:
    cmp r14, [rbx + VEC_len]
    jae .Lrf_end
    xor r15d, r15d
.Lrf_string:
    cmp r15d, r13d
    jae .Lrf_next
    mov rax, r14
    imul rax, r12
    add rax, [rbx + VEC_ptr]
    mov rdi, [rax + r15*8]
    call mem_free
    inc r15d
    jmp .Lrf_string
.Lrf_next: inc r14
    jmp .Lrf_record
.Lrf_end: mov rdi, rbx
    call vec_free
    EPILOGUE
FN memory_free
    PROLOGUE
    mov rbx, rdi
    test rbx, rbx
    jz .Lmf_done
    mov rdi, [rbx + MM_binary]
    call mem_free
    mov rdi, [rbx + MM_allocator]
    call mem_free
    lea rdi, [rbx + MM_entrypoints]
    mov esi, ME_SIZE
    mov ecx, 2
    call memory_records_free
    xor r12d, r12d
.Lmf_snapshot:
    cmp r12, [rbx + MM_snapshots + VEC_len]
    jae .Lmf_end
    imul r13, r12, MS_SIZE
    add r13, [rbx + MM_snapshots + VEC_ptr]
    lea rdi, [r13 + MS_nodes]
    mov esi, MN_SIZE
    mov ecx, 6
    call memory_records_free
    lea rdi, [r13 + MS_links]
    mov esi, ML_SIZE
    mov ecx, 2
    call memory_records_free
    inc r12
    jmp .Lmf_snapshot
.Lmf_end:
    lea rdi, [rbx + MM_snapshots]
    mov esi, MS_SIZE
    mov ecx, 6
    call memory_records_free
    mov rdi, [rbx + MM_scene]
    call scene_free
    mov rdi, [rbx + MM_graph]
    call canvas_graph_free
    mov rdi, rbx
    call mem_free
.Lmf_done: EPILOGUE
# JV array, destination vector, stride, field table, closed field count, cap.
FN memory_collection
    PROLOGUE 32
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov [rsp], r8d
    mov [rsp + 4], r9d
    call json_type
    cmp eax, JT_ARR
    jne .Lmc_bad
    mov rdi, rbx
    call json_len
    cmp eax, [rsp + 4]
    ja .Lmc_bad
    mov [rsp + 8], eax
    xor r15d, r15d
.Lmc_item:
    cmp r15d, [rsp + 8]
    jae .Lmc_ok
    mov rdi, rbx
    mov esi, r15d
    call json_at
    cmp dword ptr [rax], JT_OBJ
    jne .Lmc_bad
    mov ecx, [rsp]
    cmp [rax + 4], ecx
    jne .Lmc_bad
    mov [rsp + 16], rax
    mov rdi, r12
    mov rsi, r13
    call vec_push
    mov [rsp + 24], rax
    mov rdi, rax
    xor esi, esi
    mov rdx, r13
    call memset
    mov rdi, [rsp + 16]
    mov rsi, [rsp + 24]
    mov rdx, r14
    call canvas_graph_fields
    test eax, eax
    jz .Lmc_bad
    inc r15d
    jmp .Lmc_item
.Lmc_ok: mov eax, 1
    EPILOGUE
.Lmc_bad: xor eax, eax
    EPILOGUE
# Strict full 64-bit hexadecimal address string -> rax value, edx valid.
FN memory_address
    PROLOGUE
    mov rbx, rdi
    call strlen
    cmp rax, 3
    jb .Lma_bad
    cmp rax, 18
    ja .Lma_bad
    cmp word ptr [rbx], 0x7830
    jne .Lma_bad
    lea rdi, [rbx + 2]
    lea rsi, [rax - 2]
    mov r12, rsi
    call parse_hex
    cmp rdx, r12
    jne .Lma_bad
    mov edx, 1
    EPILOGUE
.Lma_bad: xor edx, edx
    EPILOGUE
# bytes,len -> owned model or 0. No parser pointers survive.
FN memory_parse
    PROLOGUE 40
    cmp rsi, 3 << 20
    ja .Lmp_null
    call json_parse_complete
    test rax, rax
    jz .Lmp_null
    cmp dword ptr [rax], JT_OBJ
    jne .Lmp_null
    cmp dword ptr [rax + 4], 7
    jne .Lmp_null
    mov r12, rax
    mov rdi, rax
    lea rsi, [rip + .Ltype]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lmemory_type]
    call json_is
    test eax, eax
    jz .Lmp_null
    mov rdi, r12
    lea rsi, [rip + .Lversion]
    call json_get
    mov rdi, rax
    call scene_json_int
    test edx, edx
    jz .Lmp_null
    cmp rax, 1
    jne .Lmp_null
    mov edi, MM_SIZE
    call mem_alloc
    mov rbx, rax
    mov rdi, r12
    mov rsi, rax
    lea rdx, [rip + .Lroot_fields]
    call canvas_graph_fields
    test eax, eax
    jz .Lmp_bad
    mov rax, [rbx + MM_binary]
    cmp byte ptr [rax], 0
    je .Lmp_bad
    mov rdi, [rbx + MM_allocator]
    lea rsi, [rip + memory_generic]
    call strcmp_eq
    test eax, eax
    jnz .Lmp_allocator_ok
    mov rdi, [rbx + MM_allocator]
    lea rsi, [rip + memory_rhun]
    call strcmp_eq
    test eax, eax
    jz .Lmp_bad
.Lmp_allocator_ok:
    mov rdi, r12
    lea rsi, [rip + .Lentrypoints]
    call json_get
    mov rdi, rax
    lea rsi, [rbx + MM_entrypoints]
    mov edx, ME_SIZE
    lea rcx, [rip + .Lentry_fields]
    mov r8d, 3
    mov r9d, 64
    call memory_collection
    test eax, eax
    jz .Lmp_bad
    mov rdi, r12
    lea rsi, [rip + .Lsnapshots]
    call json_get
    mov [rsp], rax
    mov rdi, rax
    call json_type
    cmp eax, JT_ARR
    jne .Lmp_bad
    mov rdi, [rsp]
    call json_len
    test eax, eax
    jz .Lmp_bad
    cmp eax, 64
    ja .Lmp_bad
    mov [rsp + 8], eax
    mov dword ptr [rsp + 12], 0
    mov dword ptr [rsp + 16], 0
    xor r13d, r13d
.Lmp_snapshot:
    cmp r13d, [rsp + 8]
    jae .Lmp_validate
    mov rdi, [rsp]
    mov esi, r13d
    call json_at
    cmp dword ptr [rax], JT_OBJ
    jne .Lmp_bad
    cmp dword ptr [rax + 4], 8
    jne .Lmp_bad
    mov r14, rax
    lea rdi, [rbx + MM_snapshots]
    mov esi, MS_SIZE
    call vec_push
    mov r15, rax
    mov rdi, rax
    xor esi, esi
    mov edx, MS_SIZE
    call memset
    mov rdi, r14
    mov rsi, r15
    lea rdx, [rip + .Lsnapshot_fields]
    call canvas_graph_fields
    test eax, eax
    jz .Lmp_bad
    mov rdi, r14
    lea rsi, [rip + .Lnodes]
    call json_get
    mov rdi, rax
    lea rsi, [r15 + MS_nodes]
    mov edx, MN_SIZE
    lea rcx, [rip + .Lnode_fields]
    mov r8d, 11
    mov r9d, 256
    call memory_collection
    test eax, eax
    jz .Lmp_bad
    mov eax, [r15 + MS_nodes + VEC_len]
    test eax, eax
    jz .Lmp_bad
    add [rsp + 12], eax
    cmp dword ptr [rsp + 12], 4096
    ja .Lmp_bad
    mov rdi, r14
    lea rsi, [rip + .Llinks]
    call json_get
    mov rdi, rax
    lea rsi, [r15 + MS_links]
    mov edx, ML_SIZE
    lea rcx, [rip + .Llink_fields]
    mov r8d, 3
    mov r9d, 1024
    call memory_collection
    test eax, eax
    jz .Lmp_bad
    mov eax, [r15 + MS_links + VEC_len]
    add [rsp + 16], eax
    cmp dword ptr [rsp + 16], 8192
    ja .Lmp_bad
    inc r13d
    jmp .Lmp_snapshot
.Lmp_validate: mov rdi, rbx
    call memory_validate
    test eax, eax
    jz .Lmp_bad
    mov rax, rbx
    EPILOGUE
.Lmp_bad: mov rdi, rbx
    call memory_free
.Lmp_null: xor eax, eax
    EPILOGUE
FN memory_scene_valid
    PROLOGUE
    mov r12, rdi
    mov rdi, [rdi + SC_memory]
    test rdi, rdi
    jz .Lmsv_yes
    cmp byte ptr [rdi], 0
    je .Lmsv_yes
    mov rbx, rdi
    cmp qword ptr [r12 + SC_elements + VEC_len], 0
    jne .Lmsv_no
    mov r13d, SC_ui
.Lmsv_profile:
    mov rax, [r12 + r13]
    test rax, rax
    jz .Lmsv_profile_next
    cmp byte ptr [rax], 0
    jne .Lmsv_no
.Lmsv_profile_next:
    cmp r13d, SC_ui
    jne .Lmsv_graph_done
    mov r13d, SC_graph
    jmp .Lmsv_profile
.Lmsv_graph_done:
    cmp r13d, SC_graph
    jne .Lmsv_profile_done
    mov r13d, SC_analysis
    jmp .Lmsv_profile
.Lmsv_profile_done:
    mov rdi, rbx
    call strlen
    mov rsi, rax
    mov rdi, rbx
    call memory_parse
    test rax, rax
    jz .Lmsv_no
    mov rdi, rax
    call memory_free
.Lmsv_yes: mov eax, 1
    EPILOGUE
.Lmsv_no: xor eax, eax
    EPILOGUE
.section .rodata
.globl memory_generic, memory_rhun
memory_generic: .asciz "generic"
memory_rhun: .asciz "rhun-v1"
.Lmemory_type: .asciz "rhun-memory"

.Laddress: .asciz "address"
.Lallocator: .asciz "allocator"
.Lbinary: .asciz "binary"
.Lbp: .asciz "bp"
.Lcapacity: .asciz "capacity"
.Lcertainty: .asciz "certainty"
.Lentrypoints: .asciz "entrypoints"
.Lfrom: .asciz "from"
.Lid: .asciz "id"
.Lkind: .asciz "kind"
.Llabel: .asciz "label"
.Llinks: .asciz "links"
.Lnodes: .asciz "nodes"
.Lparent: .asciz "parent"
.Lpc: .asciz "pc"
.Lprovenance: .asciz "provenance"
.Lsize: .asciz "size"
.Lsnapshots: .asciz "snapshots"
.Lsource: .asciz "source"
.Lsp: .asciz "sp"
.Lstate: .asciz "state"
.Lthread: .asciz "thread"
.Lto: .asciz "to"
.Ltype: .asciz "type"
.Lversion: .asciz "version"
.p2align 3
.Lroot_fields:
    .quad .Lbinary, MM_binary, 1, 0, 0
    .quad .Lallocator, MM_allocator, 1, 0, 0
    .quad .Lprovenance, MM_provenance, 2, 0, 2
    .quad 0
.p2align 3
.Lentry_fields:
    .quad .Lid, ME_id, 1, 0, 0
    .quad .Laddress, ME_address, 1, 0, 0
    .quad .Lkind, ME_kind, 2, 0, 3
    .quad 0
.p2align 3
.Lsnapshot_fields:
    .quad .Lid, MS_id, 1, 0, 0
    .quad .Lthread, MS_thread, 1, 0, 0
    .quad .Lpc, MS_pc, 1, 0, 0
    .quad .Lsp, MS_sp, 1, 0, 0
    .quad .Lbp, MS_bp, 1, 0, 0
    .quad .Llabel, MS_label, 1, 0, 0
    .quad 0
.p2align 3
.Lnode_fields:
    .quad .Lid, MN_id, 1, 0, 0
    .quad .Llabel, MN_label, 1, 0, 0
    .quad .Laddress, MN_address, 1, 0, 0
    .quad .Lparent, MN_parent, 1, 0, 0
    .quad .Lthread, MN_thread, 1, 0, 0
    .quad .Lsource, MN_source, 1, 0, 0
    .quad .Lkind, MN_kind, 2, 0, 4
    .quad .Lsize, MN_size, 2, 0, 1073741824
    .quad .Lcapacity, MN_capacity, 2, 0, 1073741824
    .quad .Lstate, MN_state, 2, 0, 2
    .quad .Lcertainty, MN_certainty, 2, 0, 3
    .quad 0
.p2align 3
.Llink_fields:
    .quad .Lfrom, ML_from, 1, 0, 0
    .quad .Lto, ML_to, 1, 0, 0
    .quad .Lkind, ML_kind, 2, 0, 4
    .quad 0
.text
FN memory_import
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    call memory_parse
    test rax, rax
    jz .Lmi_done
    mov r13, rax
    call scene_new
    mov r14, rax
    mov [rax + SC_memory_view], r13
    mov rdi, rbx
    mov rsi, r12
    call mem_dup
    mov [r14 + SC_memory], rax
    mov qword ptr [r14 + SC_hash], 1
    mov qword ptr [r14 + SC_revision], 1
    mov qword ptr [r13 + MM_revision], 1
    mov rax, r14
.Lmi_done: EPILOGUE
