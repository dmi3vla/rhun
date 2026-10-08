.include "rhun.inc"
.include "canvas/canvas.inc"
.include "memory/memory.inc"
.text
FN memory_quote
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rdi, rbx
    mov rsi, r12
    call chat_json_quote
    EPILOGUE
# Same owned field tables as the strict reader; only 32-bit numbers and strings.
FN memory_dump_fields
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov esi, '{'
    call sb_push_byte
    xor r14d, r14d
.Ldf_field:
    cmp qword ptr [r13], 0
    je .Ldf_end
    test r14d, r14d
    jz .Ldf_key
    mov rdi, rbx
    mov esi, ','
    call sb_push_byte
.Ldf_key:
    mov rdi, rbx
    mov rsi, [r13]
    call memory_quote
    mov rdi, rbx
    mov esi, ':'
    call sb_push_byte
    mov rcx, [r13 + 8]
    cmp qword ptr [r13 + 16], 1
    jne .Ldf_num
    mov rdi, rbx
    mov rsi, [r12 + rcx]
    call memory_quote
    jmp .Ldf_next
.Ldf_num:
    mov esi, [r12 + rcx]
    mov rdi, rbx
    call sb_push_u64
.Ldf_next: add r13, 40
    inc r14d
    jmp .Ldf_field
.Ldf_end: mov rdi, rbx
    mov esi, '}'
    call sb_push_byte
    EPILOGUE
FN memory_dump
    PROLOGUE
    mov rbx, rsi
    test rdi, rdi
    jz .Ldump_null
    call memory_prepare
    mov r12, rax
    test rax, rax
    jz .Ldump_null
    mov rdi, rbx
    lea rsi, [rip + .Lheader]
    call sb_push_cstr
    mov rdi, rbx
    mov esi, [r12 + MM_cursor]
    call sb_push_u64
    mov rdi, rbx
    lea rsi, [rip + .Lmode]
    call sb_push_cstr
    mov rdi, rbx
    mov esi, [r12 + MM_mode]
    call sb_push_u64
    mov rdi, rbx
    lea rsi, [rip + .Lselected]
    call sb_push_cstr
    mov rdi, rbx
    mov esi, [r12 + MM_selected]
    call sb_push_u64
    mov rdi, rbx
    lea rsi, [rip + .Lprovenance]
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
    lea rsi, [rip + .Lentrypoints]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, [r12 + MM_entrypoints + VEC_len]
    call sb_push_u64
    mov rdi, r12
    call memory_snapshot
    mov r13, rax
    mov rdi, rbx
    lea rsi, [rip + .Lsnapshot]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, r13
    lea rdx, [rip + memory_snapshot_fields]
    call memory_dump_fields
    mov rdi, rbx
    lea rsi, [rip + .Lnodes]
    call sb_push_cstr
    xor r14d, r14d
.Ldump_node:
    cmp r14, [r13 + MS_nodes + VEC_len]
    jae .Ldump_links_start
    test r14d, r14d
    jz .Ldump_node_item
    mov rdi, rbx
    mov esi, ','
    call sb_push_byte
.Ldump_node_item:
    imul rsi, r14, MN_SIZE
    add rsi, [r13 + MS_nodes + VEC_ptr]
    mov rdi, rbx
    lea rdx, [rip + memory_node_fields]
    call memory_dump_fields
    inc r14
    jmp .Ldump_node
.Ldump_links_start:
    mov rdi, rbx
    lea rsi, [rip + .Llinks]
    call sb_push_cstr
    xor r14d, r14d
.Ldump_link:
    cmp r14, [r13 + MS_links + VEC_len]
    jae .Ldump_end
    test r14d, r14d
    jz .Ldump_link_item
    mov rdi, rbx
    mov esi, ','
    call sb_push_byte
.Ldump_link_item:
    imul rsi, r14, ML_SIZE
    add rsi, [r13 + MS_links + VEC_ptr]
    mov rdi, rbx
    lea rdx, [rip + memory_link_fields]
    call memory_dump_fields
    inc r14
    jmp .Ldump_link
.Ldump_end:
    mov rdi, rbx
    lea rsi, [rip + .Lend]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, rbx
    call memory_view_dump
    mov rdi, rbx
    lea rsi, [rip + .Lclose]
    call sb_push_cstr
    EPILOGUE
.Ldump_null:
    mov rdi, rbx
    lea rsi, [rip + .Lnull]
    call sb_push_cstr
    EPILOGUE
.section .rodata
.Lheader: .asciz "{\"type\":\"rhun-memory-view\",\"cursor\":"
.Lmode: .asciz ",\"mode\":"
.Lprovenance: .asciz ",\"provenance\":"
.Lbinary: .asciz ",\"binary\":"
.Lallocator: .asciz ",\"allocator\":"
.Lentrypoints: .asciz ",\"entrypoints\":"
.Lsnapshot: .asciz ",\"snapshot\":"
.Lnodes: .asciz ",\"nodes\":["
.Llinks: .asciz "],\"links\":["
.Lend: .asciz "],\"view\":"
.Lclose: .asciz "}\n"
.Lnull: .asciz "null\n"

.Lselected: .asciz ",\"selected\":"
