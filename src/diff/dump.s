.include "rhun.inc"
.include "canvas/canvas.inc"
.include "diff/diff.inc"
.text
# Same closed tables, but signed integer assertions allow -1 (not asserted).
FN diff_dump_fields
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov esi, '{'
    call sb_push_byte
    xor r14d, r14d
1:  cmp qword ptr [r13], 0
    je 8f
    test r14d, r14d
    jz 2f
    mov rdi, rbx
    mov esi, ','
    call sb_push_byte
2:  mov rdi, rbx
    mov rsi, [r13]
    call memory_quote
    mov rdi, rbx
    mov esi, ':'
    call sb_push_byte
    mov rcx, [r13 + 8]
    cmp qword ptr [r13 + 16], 1
    jne 3f
    mov rdi, rbx
    mov rsi, [r12 + rcx]
    call memory_quote
    jmp 7f
3:  movsxd rsi, dword ptr [r12 + rcx]
    mov rdi, rbx
    call canvas_dump_int
7:  add r13, 40
    inc r14d
    jmp 1b
8:  mov rdi, rbx
    mov esi, '}'
    call sb_push_byte
    EPILOGUE
# DG, SB -> strict claims document (also usable as the model response template).
FN diff_graph_dump
    PROLOGUE DN_SIZE
    mov rbx, rdi
    mov r12, rsi
    mov rdi, r12
    lea rsi, [rip + .Lheader]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, [rbx + DG_base]
    call memory_quote
    mov rdi, r12
    lea rsi, [rip + .Lprofile]
    call sb_push_cstr
    mov rdi, r12
    mov esi, [rbx + DG_profile]
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Lsnapshot]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, [rbx + DG_snapshot]
    call memory_quote
    mov rdi, r12
    lea rsi, [rip + .Lcomplete]
    call sb_push_cstr
    mov rdi, r12
    mov esi, [rbx + DG_complete]
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Lscope]
    call sb_push_cstr
    xor r13d, r13d
1:  cmp r13, [rbx + DG_scope + VEC_len]
    jae 2f
    test r13d, r13d
    jz 11f
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
11: mov rax, [rbx + DG_scope + VEC_ptr]
    mov rsi, [rax + r13*8]
    mov rdi, r12
    call memory_quote
    inc r13
    jmp 1b
2:  mov rdi, r12
    lea rsi, [rip + .Lnodes]
    call sb_push_cstr
    xor r13d, r13d
3:  cmp r13, [rbx + DG_nodes + VEC_len]
    jae 4f
    test r13d, r13d
    jz 31f
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
31: imul r14, r13, DN_SIZE
    add r14, [rbx + DG_nodes + VEC_ptr]
    mov rdi, rsp
    mov rsi, r14
    mov edx, DN_SIZE
    call memcpy
    # Base facts export no unsupported property assertions. Target fields stay intact.
    cmp dword ptr [r14 + DN_known], 0
    je 33f
    mov ecx, DN_kind
    mov edx, 1
32: test [r14 + DN_known], edx
    jnz 321f
    mov dword ptr [rsp + rcx], -1
321:add ecx, 4
    shl edx, 1
    cmp ecx, DN_state
    jbe 32b
33: mov rdi, r12
    mov rsi, rsp
    lea rdx, [rip + diff_node_fields]
    call diff_dump_fields
    inc r13
    jmp 3b
4:  mov rdi, r12
    lea rsi, [rip + .Llinks]
    call sb_push_cstr
    xor r13d, r13d
5:  cmp r13, [rbx + DG_links + VEC_len]
    jae 6f
    test r13d, r13d
    jz 51f
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
51: imul rsi, r13, DE_SIZE
    add rsi, [rbx + DG_links + VEC_ptr]
    mov rdi, r12
    lea rdx, [rip + diff_edge_fields]
    call diff_dump_fields
    inc r13
    jmp 5b
6:  mov rdi, r12
    lea rsi, [rip + .Lend]
    call sb_push_cstr
    EPILOGUE
FN diff_dump
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    test rbx, rbx
    jz .Lnone
    mov r13, [rbx + SC_diff]
    test r13, r13
    jz .Lnone
    mov rdi, r12
    lea rsi, [rip + .Lreport]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, r13
    call diff_stale
    mov esi, eax
    mov rdi, r12
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Lshow]
    call sb_push_cstr
    mov rdi, r12
    mov esi, [r13 + DF_show]
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Lfilter]
    call sb_push_cstr
    mov rdi, r12
    mov esi, [r13 + DF_filter]
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Lcursor]
    call sb_push_cstr
    mov rdi, r12
    movsxd rsi, dword ptr [r13 + DF_cursor]
    call canvas_dump_int
    mov rdi, r12
    lea rsi, [rip + .Lbasegraph]
    call sb_push_cstr
    mov rdi, [r13 + DF_base]
    mov rsi, r12
    call diff_graph_dump
    mov rdi, r12
    lea rsi, [rip + .Ltargetgraph]
    call sb_push_cstr
    mov rdi, [r13 + DF_target]
    mov rsi, r12
    call diff_graph_dump
    mov rdi, r12
    lea rsi, [rip + .Lresults]
    call sb_push_cstr
    xor r14d, r14d
.Litem:
    cmp r14, [r13 + DF_results + VEC_len]
    jae .Ldone
    test r14d, r14d
    jz .Litemfields
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
.Litemfields:
    imul r15, r14, DR_SIZE
    add r15, [r13 + DF_results + VEC_ptr]
    mov rdi, r12
    mov rsi, r15
    lea rdx, [rip + .Lresultfields]
    call diff_dump_fields
    inc r14
    jmp .Litem
.Ldone:
    mov rdi, r12
    lea rsi, [rip + .Lend]
    call sb_push_cstr
    EPILOGUE
.Lnone: mov rdi, r12
    lea rsi, [rip + .Lnull]
    call sb_push_cstr
    EPILOGUE
.section .rodata
.Lheader: .asciz "{\"type\":\"rhun-agent-claims\",\"version\":1,\"base\":"
.Lprofile: .asciz ",\"profile\":"
.Lsnapshot: .asciz ",\"snapshot\":"
.Lcomplete: .asciz ",\"complete\":"
.Lscope: .asciz ",\"scope\":["
.Lnodes: .asciz "],\"nodes\":["
.Llinks: .asciz "],\"links\":["
.Lend: .asciz "]}"
.Lreport: .asciz "{\"type\":\"rhun-visual-diff\",\"version\":1,\"stale\":"
.Lshow: .asciz ",\"show\":"
.Lfilter: .asciz ",\"filter\":"
.Lcursor: .asciz ",\"cursor\":"
.Lbasegraph: .asciz ",\"baseGraph\":"
.Ltargetgraph: .asciz ",\"targetGraph\":"
.Lresults: .asciz ",\"results\":["
.Lnull: .asciz "null"
.Lresultfields:
.quad .Lbaseindex, DR_base, 2, 0, 0
.quad .Ltargetindex, DR_target, 2, 0, 0
.quad .Lrtype, DR_type, 2, 0, 0
.quad .Lstatus, DR_status, 2, 0, 0
.quad .Lreason, DR_reason, 2, 0, 0
.quad 0
.Lbaseindex: .asciz "baseIndex"
.Ltargetindex: .asciz "targetIndex"
.Lrtype: .asciz "kind"
.Lstatus: .asciz "status"
.Lreason: .asciz "reason"
