.include "rhun.inc"
.include "canvas/canvas.inc"
.include "canvas/graph.inc"
.text
FN canvas_graph_dump
    PROLOGUE
    mov r12, rdi
    call canvas_graph_active
    mov rbx, rax
    test rax, rax
    jz 9f
    cmp qword ptr [rbx + GR_visible + VEC_len], 0
    jne 101f
    mov rdi, rbx
    call canvas_graph_projection
101:
    mov rdi, r12
    lea rsi, [rip + .Lheader]
    call sb_push_cstr
    lea r13, [rip + .Lfields]
1:  cmp qword ptr [r13], 0
    je 2f
    mov rcx, [r13 + 8]
    movsxd rdx, dword ptr [rbx + rcx]
    mov rdi, r12
    mov rsi, [r13]
    call canvas_export_number
    add r13, 16
    jmp 1b
2:  mov rdi, r12
    lea rsi, [rip + .Lversions]
    call sb_push_cstr
    mov eax, [rbx + GR_event]
    imul r13, rax, EV_SIZE
    add r13, [rbx + GR_events + VEC_ptr]
    xor r14d, r14d
3:  test r14d, r14d
    jz 31f
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
31: mov rdi, r12
    mov esi, [r13 + EV_versions + r14*4]
    call sb_push_u64
    inc r14d
    cmp r14d, 4
    jb 3b
    mov rdi, r12
    lea rsi, [rip + .Lnodes]
    call sb_push_cstr
    xor r13d, r13d
4:  cmp r13, [rbx + GR_visible + VEC_len]
    jae .Ldump_edges
    imul r14, r13, VP_SIZE
    add r14, [rbx + GR_visible + VEC_ptr]
    test r13, r13
    jz 41f
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
41: mov rdi, r12
    lea rsi, [rip + .Lnode]
    call sb_push_cstr
    mov rdi, r12
    mov esi, [r14 + VP_id]
    call sb_push_u64
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
    mov rdi, r12
    lea rsi, [rip + .Lx]
    movsxd rdx, dword ptr [r14 + VP_x]
    call canvas_export_number
    mov rdi, r12
    lea rsi, [rip + .Ly]
    movsxd rdx, dword ptr [r14 + VP_y]
    call canvas_export_number
    mov rdi, r12
    lea rsi, [rip + .Lname]
    call sb_push_cstr
    mov rdi, [r14 + VP_name]
    call strlen
    mov rdx, rax
    mov rdi, r12
    mov rsi, [r14 + VP_name]
    call chat_json_quote
    mov rdi, r12
    mov esi, '}'
    call sb_push_byte
    inc r13
    jmp 4b
.Ldump_edges:
    mov rdi, r12
    lea rsi, [rip + .Ledges]
    call sb_push_cstr
    xor r13d, r13d
1:  cmp r13, [rbx + GR_links + VEC_len]
    jae 8f
    imul r14, r13, VE_SIZE
    add r14, [rbx + GR_links + VEC_ptr]
    test r13, r13
    jz 11f
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
11: mov rdi, r12
    mov esi, '{'
    call sb_push_byte
    mov rdi, r12
    lea rsi, [rip + .La]
    mov edx, [r14 + VE_a]
    call canvas_export_number
    mov rdi, r12
    lea rsi, [rip + .Lb]
    mov edx, [r14 + VE_b]
    call canvas_export_number
    mov rdi, r12
    lea rsi, [rip + .Lkind]
    mov edx, [r14 + VE_kind]
    call canvas_export_number
    mov rdi, r12
    lea rsi, [rip + .Lsources]
    call sb_push_cstr
    xor r15d, r15d
2:  cmp r15, [r14 + VE_sources + VEC_len]
    jae 4f
    test r15, r15
    jz 21f
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
21: mov rax, [r14 + VE_sources + VEC_ptr]
    mov eax, [rax + r15*4]
    imul rax, GE_SIZE
    add rax, [rbx + GR_edges + VEC_ptr]
    mov rdi, [rax + GE_id]
    call strlen
    mov rdx, rax
    mov rax, [r14 + VE_sources + VEC_ptr]
    mov eax, [rax + r15*4]
    imul rax, GE_SIZE
    add rax, [rbx + GR_edges + VEC_ptr]
    mov rsi, [rax + GE_id]
    mov rdi, r12
    call chat_json_quote
    inc r15
    jmp 2b
4:  mov rdi, r12
    lea rsi, [rip + .Ledge_end]
    call sb_push_cstr
    inc r13
    jmp 1b
8:  mov rdi, r12
    lea rsi, [rip + .Lend]
    call sb_push_cstr
9:  EPILOGUE
.section .rodata
.Lheader: .asciz "{\"type\":\"rhun-graph-view\","
.Lmode: .asciz "mode"
.Lyaw: .asciz "yaw"
.Lpitch: .asciz "pitch"
.Lzoom: .asciz "zoom"
.Lfold: .asciz "fold"
.Lselected: .asciz "selected"
.Levent: .asciz "event"
.Lversions: .asciz "\"versions\":["
.Lnodes: .asciz "],\"nodes\":["
.Lnode: .asciz "{\"id\":"
.Lname: .asciz "\"name\":"
.Lx: .asciz "x"
.Ly: .asciz "y"
.La: .asciz "a"
.Lb: .asciz "b"
.Lkind: .asciz "kind"
.Ledges: .asciz "],\"edges\":["
.Lsources: .asciz "\"sourceIds\":["
.Ledge_end: .asciz "]}"
.Lend: .asciz "]}\n"
.p2align 3
.Lfields: .quad .Lmode, GR_mode, .Lyaw, GR_yaw, .Lpitch, GR_pitch, .Lzoom, GR_zoom, .Lfold, GR_fold, .Lselected, GR_selected, .Levent, GR_event, 0
