.include "rhun.inc"
.include "canvas/canvas.inc"
.include "memory/memory.inc"
.text
# snapshot, selected 1-based index, candidate index -> directly connected member.
FN memory_review_member
    cmp esi, edx
    je .Lmember_yes
    xor ecx, ecx
.Lmember_link:
    cmp rcx, [rdi + MS_links + VEC_len]
    jae .Lmember_no
    imul rax, rcx, ML_SIZE
    add rax, [rdi + MS_links + VEC_ptr]
    cmp [rax + ML_a], esi
    jne .Lmember_reverse
    cmp [rax + ML_b], edx
    je .Lmember_yes
.Lmember_reverse:
    cmp [rax + ML_b], esi
    jne .Lmember_next
    cmp [rax + ML_a], edx
    je .Lmember_yes
.Lmember_next: inc ecx
    jmp .Lmember_link
.Lmember_yes: mov eax, 1
    ret
.Lmember_no: xor eax, eax
    ret
# Explicit selected node plus immediate neighbors, at most 64 nodes / 48 KiB.
# Evidence remains read-only; the chat response cannot mutate this profile.
FN memory_request_build
    PROLOGUE 16
    mov rbx, rsi
    call memory_prepare
    test rax, rax
    jz .Lrequest_bad
    mov r12, rax
    mov r14d, [rax + MM_selected]
    test r14d, r14d
    jz .Lrequest_bad
    mov rdi, rax
    call memory_snapshot
    mov r13, rax
    cmp r14, [rax + MS_nodes + VEC_len]
    ja .Lrequest_bad
    mov rdi, rbx
    lea rsi, [rip + .Lheader]
    call sb_push_cstr
    mov rdi, rbx
    mov esi, [r12 + MM_provenance]
    call sb_push_u64
    mov rdi, rbx
    lea rsi, [rip + .Lbinary]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, [r12 + MM_binary]
    call memory_quote
    mov rdi, rbx
    lea rsi, [rip + .Lallocator]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, [r12 + MM_allocator]
    call memory_quote
    mov rdi, rbx
    lea rsi, [rip + .Lsnapshot]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, r13
    lea rdx, [rip + memory_snapshot_fields]
    call memory_dump_fields
    mov rdi, rbx
    lea rsi, [rip + .Lselected]
    call sb_push_cstr
    mov eax, r14d
    sub eax, 1
    imul rax, MN_SIZE
    add rax, [r13 + MS_nodes + VEC_ptr]
    mov rsi, [rax + MN_id]
    mov rdi, rbx
    call memory_quote
    mov rdi, rbx
    lea rsi, [rip + .Lnodes]
    call sb_push_cstr
    xor r15d, r15d
    mov dword ptr [rsp], 0
.Lrequest_node:
    cmp r15, [r13 + MS_nodes + VEC_len]
    jae .Lrequest_links_start
    mov rdi, r13
    mov esi, r14d
    mov edx, r15d
    add edx, 1
    call memory_review_member
    test eax, eax
    jz .Lrequest_node_next
    cmp dword ptr [rsp], 64
    jae .Lrequest_bad
    cmp dword ptr [rsp], 0
    je .Lrequest_node_dump
    mov rdi, rbx
    mov esi, ','
    call sb_push_byte
.Lrequest_node_dump:
    inc dword ptr [rsp]
    imul rsi, r15, MN_SIZE
    add rsi, [r13 + MS_nodes + VEC_ptr]
    mov rdi, rbx
    lea rdx, [rip + memory_node_fields]
    call memory_dump_fields
.Lrequest_node_next: inc r15
    jmp .Lrequest_node
.Lrequest_links_start:
    mov rdi, rbx
    lea rsi, [rip + .Llinks]
    call sb_push_cstr
    xor r15d, r15d
    mov dword ptr [rsp], 0
.Lrequest_link:
    cmp r15, [r13 + MS_links + VEC_len]
    jae .Lrequest_end
    imul rsi, r15, ML_SIZE
    add rsi, [r13 + MS_links + VEC_ptr]
    cmp [rsi + ML_a], r14d
    je .Lrequest_link_dump
    cmp [rsi + ML_b], r14d
    jne .Lrequest_link_next
.Lrequest_link_dump:
    mov [rsp + 8], rsi
    cmp dword ptr [rsp], 0
    je .Lrequest_link_record
    mov rdi, rbx
    mov esi, ','
    call sb_push_byte
.Lrequest_link_record:
    inc dword ptr [rsp]
    mov rdi, rbx
    mov rsi, [rsp + 8]
    lea rdx, [rip + memory_link_fields]
    call memory_dump_fields
.Lrequest_link_next: inc r15
    jmp .Lrequest_link
.Lrequest_end:
    mov rdi, rbx
    lea rsi, [rip + .Lend]
    call sb_push_cstr
    cmp qword ptr [rbx + SB_len], 49152
    ja .Lrequest_bad
    mov eax, 1
    EPILOGUE
.Lrequest_bad:
    mov rdi, rbx
    call sb_clear
    xor eax, eax
    EPILOGUE
.section .rodata
.Lheader: .asciz "{\"type\":\"rhun-memory-review\",\"version\":1,\"provenance\":"
.Lbinary: .asciz ",\"binary\":"
.Lallocator: .asciz ",\"allocator\":"
.Lsnapshot: .asciz ",\"snapshot\":"
.Lselected: .asciz ",\"selected\":"
.Lnodes: .asciz ",\"nodes\":["
.Llinks: .asciz "],\"links\":["
.Lend: .asciz "],\"allowed\":[],\"task\":\"Review selected memory evidence and directly connected nodes. Provenance: 0 static analysis, 1 imported declarations, 2 teaching demo. Certainty: 0 declared fact, 1 inferred, 2 pointer candidate, 3 teaching. State: 0 declared live, 1 freed/historical, 2 unknown. Zero PC/SP/BP may mean not observed. Do not turn static CFG into an execution trace, header layout into liveness, or candidate pointers into proven ownership. Distinguish facts, inferences and missing evidence; cite node IDs and source addresses. No target execution, commands or scene mutations. Return review prose.\"}"
