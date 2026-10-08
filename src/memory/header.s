.include "rhun.inc"
.include "canvas/canvas.inc"
.include "memory/memory.inc"
.text
# A captured 16-byte little-endian rhun header is evidence of layout only.
# Free-list headers are unchanged: liveness is ALWAYS unknown here.
FN memory_header_import
    PROLOGUE SB_SIZE+MN_SIZE+48
    mov rdi, rdi
    call json_parse_complete
    test rax, rax
    jz .Lhi_null
    cmp dword ptr [rax], JT_OBJ
    jne .Lhi_null
    cmp dword ptr [rax + 4], 5
    jne .Lhi_null
    mov r12, rax
    mov rdi, rax
    lea rsi, [rip + .Ltype]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Ltypename]
    call json_is
    test eax, eax
    jz .Lhi_null
    mov rdi, r12
    lea rsi, [rip + .Lversion]
    call json_get
    mov rdi, rax
    call radare_number
    test edx, edx
    jz .Lhi_null
    cmp rax, 1
    jne .Lhi_null
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE+MN_SIZE+48
    call memset
    mov rdi, r12
    lea rsi, [rsp + SB_SIZE+MN_SIZE]
    lea rdx, [rip + .Lfields]
    call canvas_graph_fields
    test eax, eax
    jz .Lhi_free_bad
    mov rdi, [rsp + SB_SIZE+MN_SIZE]
    cmp byte ptr [rdi], 0
    je .Lhi_free_bad
    mov rdi, [rsp + SB_SIZE+MN_SIZE+8]
    call memory_address
    test edx, edx
    jz .Lhi_free_bad
    cmp rax, 16
    jb .Lhi_free_bad
    mov rdi, [rsp + SB_SIZE+MN_SIZE+16]
    call strlen
    cmp rax, 32
    jne .Lhi_free_bad
    xor r13d, r13d
.Lhi_byte:
    mov rdi, [rsp + SB_SIZE+MN_SIZE+16]
    lea rdi, [rdi + r13*2]
    mov esi, 2
    call parse_hex
    cmp rdx, 2
    jne .Lhi_free_bad
    mov [rsp + SB_SIZE+MN_SIZE+24+r13], al
    inc r13d
    cmp r13d, 16
    jb .Lhi_byte
    mov r14, [rsp + SB_SIZE+MN_SIZE+24]
    mov r15, [rsp + SB_SIZE+MN_SIZE+32]
    cmp r15, 1073741824
    ja .Lhi_free_bad
    mov rdi, r15
    call memory_rhun_slot
    mov r13, rax
    cmp r14, 12
    jae .Lhi_large
    mov ecx, r14d
    mov eax, 32
    shl eax, cl
    cmp rax, r13
    jne .Lhi_free_bad
    jmp .Lhi_build
.Lhi_large:
    cmp r14, 65536
    jbe .Lhi_free_bad
    test r14, 4095
    jnz .Lhi_free_bad
    cmp r14, r13
    jne .Lhi_free_bad
.Lhi_build:
    mov rdi, rsp
    lea rsi, [rip + .Lroot]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, [rsp + SB_SIZE+MN_SIZE]
    call memory_quote
    mov rdi, rsp
    lea rsi, [rip + .Lsnapshot]
    call sb_push_cstr
    lea rax, [rip + .Lallocation]
    mov [rsp + SB_SIZE+MN_id], rax
    lea rax, [rip + .Llabel]
    mov [rsp + SB_SIZE+MN_label], rax
    mov rax, [rsp + SB_SIZE+MN_SIZE+8]
    mov [rsp + SB_SIZE+MN_address], rax
    lea rax, [rip + .Lempty]
    mov [rsp + SB_SIZE+MN_parent], rax
    mov [rsp + SB_SIZE+MN_thread], rax
    lea rax, [rip + .Lzero]
    mov [rsp + SB_SIZE+MN_source], rax
    mov dword ptr [rsp + SB_SIZE+MN_kind], 3
    mov [rsp + SB_SIZE+MN_size], r15d
    mov [rsp + SB_SIZE+MN_capacity], r13d
    mov dword ptr [rsp + SB_SIZE+MN_state], 2
    mov dword ptr [rsp + SB_SIZE+MN_certainty], 1
    mov rdi, rsp
    lea rsi, [rsp + SB_SIZE]
    lea rdx, [rip + memory_node_fields]
    call memory_dump_fields
    mov rdi, rsp
    lea rsi, [rip + .Lend]
    call sb_push_cstr
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call memory_import
    mov rbx, rax
    jmp .Lhi_free
.Lhi_free_bad: xor ebx, ebx
.Lhi_free:
    mov rdi, [rsp + SB_SIZE+MN_SIZE]
    call mem_free
    mov rdi, [rsp + SB_SIZE+MN_SIZE+8]
    call mem_free
    mov rdi, [rsp + SB_SIZE+MN_SIZE+16]
    call mem_free
    mov rdi, rsp
    call sb_free
    mov rax, rbx
    EPILOGUE
.Lhi_null: xor eax, eax
    EPILOGUE
.section .rodata
.Ltype: .asciz "type"
.Ltypename: .asciz "rhun-heap-header"
.Lversion: .asciz "version"
.Lbinary: .asciz "binary"
.Laddress: .asciz "address"
.Lheader: .asciz "header"
.Lallocation: .asciz "captured-allocation"
.Llabel: .asciz "Rhun header decoded; liveness unknown"
.Lempty: .asciz ""
.Lzero: .asciz "0x0"
.Lroot: .asciz "{\"type\":\"rhun-memory\",\"version\":1,\"provenance\":1,\"allocator\":\"rhun-v1\",\"binary\":"
.Lsnapshot: .asciz ",\"entrypoints\":[],\"snapshots\":[{\"id\":\"captured-header\",\"thread\":\"unknown\",\"pc\":\"0x0\",\"sp\":\"0x0\",\"bp\":\"0x0\",\"label\":\"Imported header; no runtime/thread/liveness capture\",\"nodes\":["
.Lend: .asciz "],\"links\":[]}]}"
.p2align 3
.Lfields:
    .quad .Lbinary,0,1,0,0
    .quad .Laddress,8,1,0,0
    .quad .Lheader,16,1,0,0
    .quad 0
