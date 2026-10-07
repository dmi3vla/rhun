.include "rhun.inc"
.include "canvas/canvas.inc"
.equ RB_addr, 0
.equ RB_id, 8
.equ RB_frame, 16
.equ RB_jump, 24
.equ RB_fail, 32
.equ RB_size, 40
.equ RB_SIZE, 48
.text
FN radare_push_address
    PROLOGUE 32
    mov rbx, rdi
    mov r12, rsi
    lea rsi, [rip + .Lhex]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, r12
    call fmt_hex
    mov rdi, rbx
    mov rsi, rsp
    mov rdx, rax
    call sb_push
    EPILOGUE
# Imported metadata is namespaced and keeps the canvas external-ID invariant.
FN radare_raw_block
    PROLOGUE SB_SIZE
    mov rbx, rdi
    mov r12, rsi
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rsp
    lea rsi, [rip + .Lid]
    call sb_push_cstr
    mov rdi, [rbx + CE_xid]
    call strlen
    mov rdx, rax
    mov rdi, rsp
    mov rsi, [rbx + CE_xid]
    call chat_json_quote
    mov rdi, rsp
    lea rsi, [rip + .Lr2]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, r12
    call json_dump
    mov rdi, rsp
    mov esi, '}'
    call sb_push_byte
    cmp qword ptr [rsp + SB_len], 65536
    ja .Lraw_bad
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call mem_dup
    mov [rbx + CE_raw], rax
    mov r12d, 1
    jmp .Lraw_free
.Lraw_bad: xor r12d, r12d
.Lraw_free: mov rdi, rsp
    call sb_free
    mov eax, r12d
    EPILOGUE
# agfj JSON array -> complete owned Scene, no mutation of existing tabs on error.
FN radare_import
    PROLOGUE 160
    cmp rsi, 8 << 20
    ja .Limp_null
    call json_parse_complete
    test rax, rax
    jz .Limp_null
    mov r12, rax
    cmp dword ptr [rax], JT_ARR
    jne .Limp_null
    mov rdi, rax
    call json_len
    test eax, eax
    jz .Limp_null
    cmp eax, 64
    ja .Limp_null
    mov [rsp + 60], eax
    mov rdi, rsp
    xor esi, esi
    mov edx, 2*VEC_SIZE
    call memset
    mov dword ptr [rsp + 68], 80
    mov dword ptr [rsp + 104], 0
    call scene_new
    mov rbx, rax
    xor r13d, r13d
.Limp_function:
    cmp r13d, [rsp + 60]
    jae .Limp_edges_start
    mov rdi, r12
    mov esi, r13d
    call json_at
    mov [rsp + 80], rax
    cmp dword ptr [rax], JT_OBJ
    jne .Limp_bad
    mov rdi, rax
    call radare_address
    test edx, edx
    jz .Limp_bad
    mov [rsp + 112], rax
    mov rdi, [rsp + 80]
    lea rsi, [rip + .Lblocks]
    call json_get
    mov [rsp + 88], rax
    mov rdi, rax
    call json_type
    cmp eax, JT_ARR
    jne .Limp_bad
    mov rdi, [rsp + 88]
    call json_len
    test eax, eax
    jz .Limp_bad
    mov [rsp + 64], eax
    add eax, [rsp + 104]
    cmp eax, 512
    ja .Limp_bad
    mov [rsp + 104], eax
    mov dword ptr [rsp + 152], 140
    xor r14d, r14d
.Limp_measure:
    cmp r14d, [rsp + 64]
    jae .Limp_make_frame
    mov rdi, [rsp + 88]
    mov esi, r14d
    call json_at
    mov rdi, rax
    lea rsi, [rip + .Lops]
    call json_get
    mov rdi, rax
    call json_len
    cmp eax, 32
    jbe .Limp_measure_size
    mov eax, 32
.Limp_measure_size:
    imul eax, 16
    add eax, 80
    cmp eax, [rsp + 152]
    jbe .Limp_measure_next
    mov [rsp + 152], eax
.Limp_measure_next:
    inc r14d
    jmp .Limp_measure
.Limp_make_frame:
    mov rdi, rbx
    mov esi, CT_FRAME
    mov edx, 80
    mov ecx, [rsp + 68]
    mov r8d, 1240
    mov r9d, [rsp + 64]
    inc r9d
    shr r9d, 1
    imul r9d, [rsp + 152]
    add r9d, 80
    mov [rsp + 108], r9d
    call scene_add
    mov r15, rax
    mov rax, [rax + CE_id]
    mov [rsp + 72], rax
    mov rdi, [rsp + 80]
    lea rsi, [rip + .Lname]
    call json_get
    mov rdi, rax
    mov esi, 1024
    call scene_owned_json_string
    test rax, rax
    jz .Limp_bad
    mov [r15 + CE_text], rax
    lea rdi, [rip + r2_function_marker]
    mov esi, 11
    call mem_dup
    mov [r15 + CE_gxid], rax
    mov rdi, [rsp + 112]
    call radare_id_string
    mov [r15 + CE_xid], rax
    xor r14d, r14d
.Limp_block:
    cmp r14d, [rsp + 64]
    jae .Limp_next_function
    mov rdi, [rsp + 88]
    mov esi, r14d
    call json_at
    mov [rsp + 96], rax
    cmp dword ptr [rax], JT_OBJ
    jne .Limp_bad
    mov rdi, rax
    call radare_address
    test edx, edx
    jz .Limp_bad
    mov [rsp + 112], rax
    mov rdi, rsp
    mov rsi, rax
    call radare_map_find
    test rax, rax
    jnz .Limp_bad
    mov rdi, [rsp + 96]
    lea rsi, [rip + .Lsize]
    call json_get
    mov rdi, rax
    call radare_number
    test edx, edx
    jz .Limp_bad
    test rax, rax
    jz .Limp_bad
    cmp rax, 1000000
    ja .Limp_bad
    mov [rsp + 120], rax
    mov rdi, rbx
    mov esi, CT_RECT
    mov edx, r14d
    and edx, 1
    imul edx, 600
    add edx, 100
    mov ecx, r14d
    shr ecx, 1
    imul ecx, [rsp + 152]
    add ecx, [rsp + 68]
    add ecx, 60
    mov r8d, 560
    mov r9d, [rsp + 152]
    sub r9d, 40
    call scene_add
    mov r15, rax
    mov rcx, [rsp + 72]
    mov [rax + CE_frame], rcx
    mov qword ptr [rax + CE_role], 1
    mov rcx, [rax + CE_id]
    mov [rax + CE_group], rcx
    mov [rsp + 128], rcx
    mov rdi, [rsp + 112]
    call radare_id_string
    mov [r15 + CE_xid], rax
    lea rdi, [rip + r2_block_marker]
    mov esi, 8
    call mem_dup
    mov [r15 + CE_gxid], rax
    mov rdi, r15
    mov rsi, [rsp + 96]
    call radare_raw_block
    test eax, eax
    jz .Limp_bad
    mov rdi, rsp
    mov esi, RB_SIZE
    call vec_push
    mov r15, rax
    mov rcx, [rsp + 112]
    mov [rax + RB_addr], rcx
    mov rcx, [rsp + 128]
    mov [rax + RB_id], rcx
    mov rcx, [rsp + 72]
    mov [rax + RB_frame], rcx
    mov rcx, [rsp + 120]
    mov [rax + RB_size], rcx
    mov qword ptr [rax + RB_jump], -1
    mov qword ptr [rax + RB_fail], -1
    mov rdi, [rsp + 96]
    lea rsi, [rip + .Ljump]
    call json_get
    test rax, rax
    jz .Limp_fail_field
    mov rdi, rax
    call radare_number
    test edx, edx
    jz .Limp_bad
    mov [r15 + RB_jump], rax
.Limp_fail_field:
    mov rdi, [rsp + 96]
    lea rsi, [rip + .Lfail]
    call json_get
    test rax, rax
    jz .Limp_disassembly
    mov rdi, rax
    call radare_number
    test edx, edx
    jz .Limp_bad
    mov [r15 + RB_fail], rax
.Limp_disassembly:
    lea rdi, [rsp + VEC_SIZE]
    call sb_clear
    lea rdi, [rsp + VEC_SIZE]
    mov rsi, [rsp + 112]
    call radare_push_address
    lea rdi, [rsp + VEC_SIZE]
    mov esi, 10
    call sb_push_byte
    mov rdi, [rsp + 96]
    lea rsi, [rip + .Lops]
    call json_get
    mov [rsp + 136], rax
    mov rdi, rax
    call json_type
    cmp eax, JT_ARR
    jne .Limp_bad
    mov rdi, [rsp + 136]
    call json_len
    cmp eax, 8192
    ja .Limp_bad
    mov [rsp + 144], eax
    mov dword ptr [rsp + 148], 0
.Limp_opcode:
    mov esi, [rsp + 148]
    cmp esi, [rsp + 144]
    jae .Limp_text_element
    mov rdi, [rsp + 136]
    call json_at
    cmp dword ptr [rax], JT_OBJ
    jne .Limp_bad
    mov rdi, rax
    lea rsi, [rip + .Lopcode]
    call json_get
    mov rdi, rax
    call json_str
    test rax, rax
    jz .Limp_bad
    cmp rdx, 1024
    ja .Limp_bad
    cmp dword ptr [rsp + 148], 32
    jae .Limp_opcode_next
    mov rsi, rax
    lea rdi, [rsp + VEC_SIZE]
    call sb_push
    lea rdi, [rsp + VEC_SIZE]
    mov esi, 10
    call sb_push_byte
.Limp_opcode_next:
    inc dword ptr [rsp + 148]
    jmp .Limp_opcode
.Limp_text_element:
    mov rdi, rbx
    mov rsi, [rsp + 128]
    call scene_find
    mov edx, [rax + CE_x]
    add edx, 10
    mov ecx, [rax + CE_y]
    add ecx, 10
    mov rdi, rbx
    mov esi, CT_TEXT
    mov r8d, 540
    mov r9d, [rsp + 152]
    sub r9d, 60
    call scene_add
    mov r15, rax
    mov dword ptr [rax + CE_fontsize], 16
    mov rcx, [rsp + 128]
    mov [rax + CE_group], rcx
    mov rcx, [rsp + 72]
    mov [rax + CE_frame], rcx
    mov rdi, [rsp + VEC_SIZE + SB_ptr]
    mov rsi, [rsp + VEC_SIZE + SB_len]
    call mem_dup
    mov [r15 + CE_text], rax
    inc r14d
    jmp .Limp_block
.Limp_next_function:
    mov eax, [rsp + 108]
    add eax, 80
    add [rsp + 68], eax
    inc r13d
    jmp .Limp_function
.Limp_edges_start:
    xor r13d, r13d
.Limp_edges:
    cmp r13, [rsp + VEC_len]
    jae .Limp_finish
    imul r14, r13, RB_SIZE
    add r14, [rsp + VEC_ptr]
    xor r15d, r15d
.Limp_edge_kind:
    mov rsi, [r14 + RB_jump + r15*8]
    cmp rsi, -1
    je .Limp_edge_next
    mov rdi, rsp
    call radare_map_find
    test rax, rax
    jz .Limp_edge_next
    mov rcx, [r14 + RB_frame]
    cmp [rax + RB_frame], rcx
    jne .Limp_edge_next
    mov rcx, [rax + RB_id]
    mov [rsp + 112], rcx
    mov rdi, rbx
    mov esi, CT_ARROW
    xor edx, edx
    xor ecx, ecx
    mov r8d, 1
    mov r9d, 1
    call scene_add
    mov rcx, [r14 + RB_id]
    mov [rax + CE_from], rcx
    mov rcx, [rsp + 112]
    mov [rax + CE_to], rcx
    mov rcx, [r14 + RB_frame]
    mov [rax + CE_frame], rcx
    mov dword ptr [rax + CE_color], 0xff78c88d
    test r15d, r15d
    jz .Limp_edge_next
    mov dword ptr [rax + CE_color], 0xffe18b83
.Limp_edge_next:
    inc r15d
    cmp r15d, 2
    jb .Limp_edge_kind
    inc r13d
    jmp .Limp_edges
.Limp_finish:
    lea rdi, [rip + r2_empty_analysis]
    call strlen
    mov rsi, rax
    lea rdi, [rip + r2_empty_analysis]
    call mem_dup
    mov [rbx + SC_analysis], rax
    mov rdi, rbx
    call scene_update_bindings
    mov rdi, rbx
    call scene_validate
    test eax, eax
    jz .Limp_bad
    mov dword ptr [rbx + SC_zoom], 49152
    mov qword ptr [rbx + SC_hash], 1
    mov qword ptr [rbx + SC_revision], 1
    mov r14, rbx
    jmp .Limp_free
.Limp_bad:
    mov rdi, rbx
    call scene_free
    xor r14d, r14d
.Limp_free:
    mov rdi, rsp
    call vec_free
    lea rdi, [rsp + VEC_SIZE]
    call sb_free
    mov rax, r14
    EPILOGUE
.Limp_null: xor eax, eax
    EPILOGUE
FN radare_map_find
    mov rcx, [rdi + VEC_len]
    mov rax, [rdi + VEC_ptr]
.Lmap_next:
    test rcx, rcx
    jz .Lmap_none
    cmp [rax + RB_addr], rsi
    je .Lmap_return
    add rax, RB_SIZE
    dec rcx
    jmp .Lmap_next
.Lmap_none: xor eax, eax
.Lmap_return: ret
.section .rodata
.Lhex: .asciz "0x"
.Lid: .asciz "{\"id\":"
.Lr2: .asciz ",\"r2\":"
.Lblocks: .asciz "blocks"
.Lname: .asciz "name"
.Lsize: .asciz "size"
.Ljump: .asciz "jump"
.Lfail: .asciz "fail"
.Lops: .asciz "ops"
.Lopcode: .asciz "opcode"
.text
# Also accept Radare's agfj @@F JSON-lines output, normalizing copied function objects.
FN radare_import_stream
    PROLOGUE 64
    mov rbx, rdi
    mov r12, rsi
    cmp rsi, 8 << 20
    ja .Lstream_null
    call radare_import
    test rax, rax
    jnz .Lstream_return
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rsp
    mov esi, '['
    call sb_push_byte
    xor r13d, r13d
    xor r14d, r14d
.Lstream_line:
    cmp r13, r12
    jae .Lstream_finish
    mov r15, r13
.Lstream_scan:
    cmp r15, r12
    jae .Lstream_parse
    cmp byte ptr [rbx + r15], 10
    je .Lstream_parse
    inc r15
    jmp .Lstream_scan
.Lstream_parse:
    mov rsi, r15
    sub rsi, r13
    jz .Lstream_next
    lea rdi, [rbx + r13]
    call json_parse_complete
    test rax, rax
    jz .Lstream_bad
    cmp dword ptr [rax], JT_ARR
    jne .Lstream_bad
    mov [rsp + 24], rax
    mov [rsp + 32], r15
    xor r15d, r15d
.Lstream_item:
    mov rdi, [rsp + 24]
    mov esi, r15d
    call json_at
    test rax, rax
    jz .Lstream_line_done
    inc r14d
    cmp r14d, 64
    ja .Lstream_item_bad
    mov [rsp + 40], rax
    cmp r14d, 1
    je .Lstream_dump
    mov rdi, rsp
    mov esi, ','
    call sb_push_byte
.Lstream_dump:
    mov rdi, rsp
    mov rsi, [rsp + 40]
    call json_dump
    cmp qword ptr [rsp + SB_len], 8 << 20
    ja .Lstream_item_bad
    inc r15
    jmp .Lstream_item
.Lstream_line_done:
    mov r15, [rsp + 32]
    jmp .Lstream_next
.Lstream_item_bad:
    mov r15, [rsp + 32]
    jmp .Lstream_bad
.Lstream_next:
    lea r13, [r15 + 1]
    jmp .Lstream_line
.Lstream_finish:
    mov rdi, rsp
    mov esi, ']'
    call sb_push_byte
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call radare_import
    mov r14, rax
    jmp .Lstream_free
.Lstream_bad: xor r14d, r14d
.Lstream_free: mov rdi, rsp
    call sb_free
    mov rax, r14
.Lstream_return: EPILOGUE
.Lstream_null: xor eax, eax
    EPILOGUE
