.include "rhun.inc"
.include "canvas/canvas.inc"
.include "memory/memory.inc"
.text
# Owned address string from Radare's exact decimal external address.
FN memory_decimal_address
    PROLOGUE SB_SIZE
    mov rbx, rdi
    call strlen
    mov rsi, rax
    mov rdi, rbx
    call parse_u64
    mov r12, rax
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rsp
    mov rsi, r12
    call radare_push_address
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call mem_dup
    mov rbx, rax
    mov rdi, rsp
    call sb_free
    mov rax, rbx
    EPILOGUE
# SB, source scene, source element -> node. Temporary fields borrow source text;
# addresses and identifiers are owned locally until JSON has copied their bytes.
FN memory_project_node
    PROLOGUE MN_SIZE
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov rdi, rsp
    xor esi, esi
    mov edx, MN_SIZE
    call memset
    mov rdi, [r13 + CE_id]
    call radare_id_string
    mov [rsp + MN_id], rax
    mov rdi, [r13 + CE_frame]
    call radare_id_string
    mov [rsp + MN_parent], rax
    cmp qword ptr [r13 + CE_frame], 0
    jne .Lpn_parent
    mov byte ptr [rax], 0
.Lpn_parent:
    mov rdi, [r13 + CE_xid]
    call memory_decimal_address
    mov [rsp + MN_address], rax
    mov [rsp + MN_source], rax
    lea rax, [rip + .Lempty]
    mov [rsp + MN_thread], rax
    mov rax, [r13 + CE_text]
    test rax, rax
    jnz .Lpn_label
    lea rax, [rip + .Lblock]
.Lpn_label: mov [rsp + MN_label], rax
    cmp dword ptr [r13 + CE_kind], CT_FRAME
    je .Lpn_dump
    # Block instructions are the grouped text element, not an inferred AST.
    xor r14d, r14d
.Lpn_text:
    cmp r14, [r12 + SC_elements + VEC_len]
    jae .Lpn_dump
    imul rax, r14, CE_SIZE
    add rax, [r12 + SC_elements + VEC_ptr]
    cmp dword ptr [rax + CE_kind], CT_TEXT
    jne .Lpn_text_next
    mov rcx, [r13 + CE_id]
    cmp [rax + CE_group], rcx
    jne .Lpn_text_next
    mov rax, [rax + CE_text]
    mov [rsp + MN_label], rax
    jmp .Lpn_dump
.Lpn_text_next: inc r14
    jmp .Lpn_text
.Lpn_dump:
    mov dword ptr [rsp + MN_state], 2
    mov rdi, rbx
    mov rsi, rsp
    lea rdx, [rip + memory_node_fields]
    call memory_dump_fields
    mov rdi, [rsp + MN_id]
    call mem_free
    mov rdi, [rsp + MN_parent]
    call mem_free
    mov rdi, [rsp + MN_address]
    call mem_free
    EPILOGUE
# Select imported function/block records only. No note or drawn shape becomes code.
FN memory_project_is_node
    cmp dword ptr [rdi + CE_kind], CT_FRAME
    je .Lpin_frame
    cmp dword ptr [rdi + CE_kind], CT_RECT
    jne .Lpin_no
    mov rdi, [rdi + CE_gxid]
    test rdi, rdi
    jz .Lpin_no
    lea rsi, [rip + r2_block_marker]
    jmp strcmp_eq
.Lpin_frame:
    mov rdi, [rdi + CE_gxid]
    test rdi, rdi
    jz .Lpin_no
    lea rsi, [rip + r2_function_marker]
    jmp strcmp_eq
.Lpin_no: xor eax, eax
    ret
FN cmd_memory_project
    PROLOGUE SB_SIZE+32
    call canvas_active
    mov rbx, rax
    test rax, rax
    jz .Lproject_bad
    mov rdi, [rax + SC_analysis]
    test rdi, rdi
    jz .Lproject_bad
    call strlen
    mov rsi, rax
    mov rdi, [rbx + SC_analysis]
    call json_parse_complete
    test rax, rax
    jz .Lproject_bad
    mov rdi, rax
    lea rsi, [rip + r2_binary]
    call json_get
    mov rdi, rax
    mov esi, 4096
    call scene_owned_json_string
    test rax, rax
    jz .Lproject_bad
    mov r12, rax
    cmp byte ptr [rax], 0
    jne .Lproject_binary
    mov rdi, rax
    call mem_free
    lea rdi, [rip + .Lunknown_binary]
    call memory_strdup
    mov r12, rax
.Lproject_binary:
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE+32
    call memset
    mov rdi, rsp
    lea rsi, [rip + .Lroot]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, r12
    call memory_quote
    mov rdi, r12
    call mem_free
    mov rdi, rsp
    lea rsi, [rip + .Lentries]
    call sb_push_cstr
    xor r13d, r13d
    xor r15d, r15d
.Lproject_entries:
    cmp r13, [rbx + SC_elements + VEC_len]
    jae .Lproject_snapshot
    imul r14, r13, CE_SIZE
    add r14, [rbx + SC_elements + VEC_ptr]
    cmp dword ptr [r14 + CE_kind], CT_FRAME
    jne .Lproject_entries_next
    mov rdi, r14
    call memory_project_is_node
    test eax, eax
    jz .Lproject_entries_next
    inc r15d
    cmp r15d, 64
    ja .Lproject_free_bad
    cmp r15d, 1
    je .Lproject_entry
    mov rdi, rsp
    mov esi, ','
    call sb_push_byte
.Lproject_entry:
    mov rdi, rsp
    lea rsi, [rip + .Lid]
    call sb_push_cstr
    mov rdi, [r14 + CE_id]
    call radare_id_string
    mov [rsp + SB_SIZE], rax
    mov rdi, rsp
    mov rsi, rax
    call memory_quote
    mov rdi, [rsp + SB_SIZE]
    call mem_free
    mov rdi, rsp
    lea rsi, [rip + .Laddress]
    call sb_push_cstr
    mov rdi, [r14 + CE_xid]
    call memory_decimal_address
    mov [rsp + SB_SIZE], rax
    mov rdi, rsp
    mov rsi, rax
    call memory_quote
    mov rdi, [rsp + SB_SIZE]
    call mem_free
    # entry0 is Radare's explicit binary entry flag. Ordinary symbol names do
    # not prove OS startup order.
    mov rdi, [r14 + CE_text]
    lea rsi, [rip + .Lentry0]
    call strcmp_eq
    test eax, eax
    jz .Lproject_function_kind
    mov rdi, rsp
    lea rsi, [rip + .Los_entry_end]
    call sb_push_cstr
    jmp .Lproject_entries_next
.Lproject_function_kind:
    mov rdi, rsp
    lea rsi, [rip + .Lentry_end]
    call sb_push_cstr
.Lproject_entries_next: inc r13
    jmp .Lproject_entries
.Lproject_snapshot:
    mov rdi, rsp
    lea rsi, [rip + .Lsnapshot]
    call sb_push_cstr
    xor r13d, r13d
    xor r15d, r15d
.Lproject_nodes:
    cmp r13, [rbx + SC_elements + VEC_len]
    jae .Lproject_links_start
    imul r14, r13, CE_SIZE
    add r14, [rbx + SC_elements + VEC_ptr]
    mov rdi, r14
    call memory_project_is_node
    test eax, eax
    jz .Lproject_node_next
    inc r15d
    cmp r15d, 256
    ja .Lproject_free_bad
    cmp r15d, 1
    je .Lproject_node
    mov rdi, rsp
    mov esi, ','
    call sb_push_byte
.Lproject_node:
    mov rdi, rsp
    mov rsi, rbx
    mov rdx, r14
    call memory_project_node
.Lproject_node_next: inc r13
    jmp .Lproject_nodes
.Lproject_links_start:
    test r15d, r15d
    jz .Lproject_free_bad
    mov rdi, rsp
    lea rsi, [rip + .Llinks]
    call sb_push_cstr
    xor r13d, r13d
    xor r15d, r15d
.Lproject_links:
    cmp r13, [rbx + SC_elements + VEC_len]
    jae .Lproject_finish
    imul r14, r13, CE_SIZE
    add r14, [rbx + SC_elements + VEC_ptr]
    cmp dword ptr [r14 + CE_kind], CT_ARROW
    jne .Lproject_link_next
    mov rdi, rbx
    mov rsi, [r14 + CE_from]
    call scene_find
    test rax, rax
    jz .Lproject_link_next
    mov rdi, rax
    call memory_project_is_node
    test eax, eax
    jz .Lproject_link_next
    mov rdi, rbx
    mov rsi, [r14 + CE_to]
    call scene_find
    test rax, rax
    jz .Lproject_link_next
    mov rdi, rax
    call memory_project_is_node
    test eax, eax
    jz .Lproject_link_next
    test r15d, r15d
    jz .Lproject_link
    mov rdi, rsp
    mov esi, ','
    call sb_push_byte
.Lproject_link:
    inc r15d
    cmp r15d, 1024
    ja .Lproject_free_bad
    mov rdi, rsp
    lea rsi, [rip + .Lfrom]
    call sb_push_cstr
    mov rdi, [r14 + CE_from]
    call radare_id_string
    mov [rsp + SB_SIZE], rax
    mov rdi, rsp
    mov rsi, rax
    call memory_quote
    mov rdi, [rsp + SB_SIZE]
    call mem_free
    mov rdi, rsp
    lea rsi, [rip + .Lto]
    call sb_push_cstr
    mov rdi, [r14 + CE_to]
    call radare_id_string
    mov [rsp + SB_SIZE], rax
    mov rdi, rsp
    mov rsi, rax
    call memory_quote
    mov rdi, [rsp + SB_SIZE]
    call mem_free
    mov rdi, rsp
    lea rsi, [rip + .Llink_end]
    call sb_push_cstr
.Lproject_link_next: inc r13
    jmp .Lproject_links
.Lproject_finish:
    mov rdi, rsp
    lea rsi, [rip + .Lend]
    call sb_push_cstr
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call memory_import
    mov rbx, rax
    mov rdi, rsp
    call sb_free
    test rbx, rbx
    jz .Lproject_bad
    mov rdi, rbx
    call memory_open_scene
    EPILOGUE
.Lproject_free_bad: mov rdi, rsp
    call sb_free
.Lproject_bad: lea rdi, [rip + .Lbad]
    call app_toast
    EPILOGUE
.section .rodata
.Lroot: .asciz "{\"type\":\"rhun-memory\",\"version\":1,\"provenance\":0,\"allocator\":\"generic\",\"binary\":"
.Lentries: .asciz ",\"entrypoints\":["
.Lid: .asciz "{\"id\":"
.Laddress: .asciz ",\"address\":"
.Lentry0: .asciz "entry0"
.Los_entry_end: .asciz ",\"kind\":0}"
.Lentry_end: .asciz ",\"kind\":3}"
.Lsnapshot: .asciz "],\"snapshots\":[{\"id\":\"static-cfg\",\"thread\":\"static\",\"pc\":\"0x0\",\"sp\":\"0x0\",\"bp\":\"0x0\",\"label\":\"Static CFG; PC/SP/BP and runtime stack/heap not observed\",\"nodes\":["
.Llinks: .asciz "],\"links\":["
.Lfrom: .asciz "{\"from\":"
.Lto: .asciz ",\"to\":"
.Llink_end: .asciz ",\"kind\":0}"
.Lend: .asciz "]}]}"
.Lempty: .asciz ""
.Lblock: .asciz "Basic block"
.Lunknown_binary: .asciz "unknown:imported-agfj"
.Lbad: .asciz "Memory: open Radare2 CFG first; projection limited to 64 functions / 256 nodes / 1024 edges"
