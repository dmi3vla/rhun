.include "rhun.inc"
.include "canvas/canvas.inc"
.include "canvas/graph.inc"
.include "memory/memory.inc"
.text
# Find a displayed card by shared visual ID; expanded segment headers are fallback.
FN memory_view_find
    xor ecx, ecx
    xor r8d, r8d
.Lvf_next:
    cmp rcx, [rdi + SC_elements + VEC_len]
    jae .Lvf_fallback
    imul rax, rcx, CE_SIZE
    add rax, [rdi + SC_elements + VEC_ptr]
    cmp [rax + CE_reserved], esi
    jne .Lvf_skip
    cmp dword ptr [rax + CE_kind], CT_RECT
    je .Lvf_return
    cmp dword ptr [rax + CE_kind], CT_FRAME
    jne .Lvf_skip
    mov r8, rax
.Lvf_skip: inc rcx
    jmp .Lvf_next
.Lvf_fallback: mov rax, r8
.Lvf_return: ret
FN memory_fold_summary
    PROLOGUE
    mov rbx, rdi
    mov r12, [rsi + MM_graph]
    mov r13d, edx
    lea rsi, [rip + .Lsummary]
    call sb_push_cstr
    xor ecx, ecx
    xor r14d, r14d
.Lsummary_count:
    cmp rcx, [r12 + GR_nodes + VEC_len]
    jae .Lsummary_done
    imul rax, rcx, GN_SIZE
    add rax, [r12 + GR_nodes + VEC_ptr]
    cmp [rax + GN_segment], r13d
    jne .Lsummary_next
    inc r14d
.Lsummary_next: inc rcx
    jmp .Lsummary_count
.Lsummary_done:
    mov rdi, rbx
    mov esi, r14d
    call sb_push_u64
    mov rdi, rbx
    lea rsi, [rip + .Lexpand]
    call sb_push_cstr
    EPILOGUE
# Scene, source card ID, target card ID, kind, zero-based source link index.
# Aggregate only matching directed endpoints AND kind. Raw JSON retains indices.
FN memory_view_link
    PROLOGUE SB_SIZE+16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14d, ecx
    mov r15, r8
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE+16
    call memset
    xor ecx, ecx
.Lvl_find:
    cmp rcx, [rbx + SC_elements + VEC_len]
    jae .Lvl_new
    imul rax, rcx, CE_SIZE
    add rax, [rbx + SC_elements + VEC_ptr]
    cmp dword ptr [rax + CE_kind], CT_ARROW
    jne .Lvl_next
    cmp [rax + CE_from], r12
    jne .Lvl_next
    cmp [rax + CE_to], r13
    jne .Lvl_next
    cmp [rax + CE_reserved], r14d
    je .Lvl_existing
.Lvl_next: inc rcx
    jmp .Lvl_find
.Lvl_new:
    mov rdi, rbx
    mov rsi, r12
    call scene_find
    mov ecx, [rax + CE_w]
    sar ecx, 1
    add ecx, [rax + CE_x]
    mov [rsp + SB_SIZE], ecx
    mov ecx, [rax + CE_h]
    sar ecx, 1
    add ecx, [rax + CE_y]
    mov [rsp + SB_SIZE+4], ecx
    mov rdi, rbx
    mov rsi, r13
    call scene_find
    mov r8d, [rax + CE_w]
    sar r8d, 1
    add r8d, [rax + CE_x]
    sub r8d, [rsp + SB_SIZE]
    mov r9d, [rax + CE_h]
    sar r9d, 1
    add r9d, [rax + CE_y]
    sub r9d, [rsp + SB_SIZE+4]
    mov rdi, rbx
    mov esi, CT_ARROW
    mov edx, [rsp + SB_SIZE]
    mov ecx, [rsp + SB_SIZE+4]
    call scene_add
    mov [rax + CE_from], r12
    mov [rax + CE_to], r13
    mov [rax + CE_reserved], r14d
    mov [rsp + SB_SIZE+8], rax
    mov rdi, rsp
    mov esi, '['
    call sb_push_byte
    jmp .Lvl_source
.Lvl_existing:
    mov [rsp + SB_SIZE+8], rax
    mov rdi, [rax + CE_raw]
    call strlen
    lea rdx, [rax - 1]
    mov rcx, [rsp + SB_SIZE+8]
    mov rsi, [rcx + CE_raw]
    mov rdi, rsp
    call sb_push
    mov rdi, rsp
    mov esi, ','
    call sb_push_byte
.Lvl_source:
    mov rdi, rsp
    mov rsi, r15
    call sb_push_u64
    mov rdi, rsp
    mov esi, ']'
    call sb_push_byte
    mov rcx, [rsp + SB_SIZE+8]
    mov rdi, [rcx + CE_raw]
    call mem_free
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call mem_dup
    mov rcx, [rsp + SB_SIZE+8]
    mov [rcx + CE_raw], rax
    mov rdi, rsp
    call sb_free
    mov rax, [rsp + SB_SIZE+8]
    EPILOGUE
.section .rodata
.Lsummary: .asciz "Collapsed segment\nNodes: "
.Lexpand: .asciz "\nF: expand"
.text
# Logical 2D projection diagnostics. Camera-independent source indices allow
# tests and tools to compare retained boundary evidence with the 3D projection.
FN memory_view_dump
    PROLOGUE 16
    mov rbx, rdi
    mov r12, rsi
    call memory_build_scene
    mov r13, [rbx + MM_scene]
    mov rdi, r12
    lea rsi, [rip + .Lview_header]
    call sb_push_cstr
    mov rax, [rbx + MM_graph]
    mov esi, [rax + GR_fold]
    mov rdi, r12
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Lview_nodes]
    call sb_push_cstr
    xor r14d, r14d
    xor r15d, r15d
.Lvd_nodes:
    cmp r14, [r13 + SC_elements + VEC_len]
    jae .Lvd_links_start
    imul rax, r14, CE_SIZE
    add rax, [r13 + SC_elements + VEC_ptr]
    cmp dword ptr [rax + CE_kind], CT_RECT
    jne .Lvd_nodes_next
    mov [rsp], rax
    test r15d, r15d
    jz .Lvd_node_record
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
.Lvd_node_record:
    mov rdi, r12
    mov rsi, [rsp]
    lea rdx, [rip + .Lview_fields]
    call memory_dump_fields
    inc r15d
.Lvd_nodes_next: inc r14
    jmp .Lvd_nodes
.Lvd_links_start:
    mov rdi, r12
    lea rsi, [rip + .Lview_links]
    call sb_push_cstr
    xor r14d, r14d
    xor r15d, r15d
.Lvd_links:
    cmp r14, [r13 + SC_elements + VEC_len]
    jae .Lvd_done
    imul rbx, r14, CE_SIZE
    add rbx, [r13 + SC_elements + VEC_ptr]
    cmp dword ptr [rbx + CE_kind], CT_ARROW
    jne .Lvd_links_next
    test r15d, r15d
    jz .Lvd_link_record
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
.Lvd_link_record:
    mov rdi, r12
    lea rsi, [rip + .Lview_from]
    call sb_push_cstr
    mov rdi, r13
    mov rsi, [rbx + CE_from]
    call scene_find
    mov esi, [rax + CE_reserved]
    mov rdi, r12
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Lview_to]
    call sb_push_cstr
    mov rdi, r13
    mov rsi, [rbx + CE_to]
    call scene_find
    mov esi, [rax + CE_reserved]
    mov rdi, r12
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Lview_kind]
    call sb_push_cstr
    mov rdi, r12
    mov esi, [rbx + CE_reserved]
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Lview_sources]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, [rbx + CE_raw]
    call sb_push_cstr
    mov rdi, r12
    mov esi, '}'
    call sb_push_byte
    inc r15d
.Lvd_links_next: inc r14
    jmp .Lvd_links
.Lvd_done:
    mov rdi, r12
    lea rsi, [rip + .Lview_end]
    call sb_push_cstr
    EPILOGUE
.section .rodata
.Lview_header: .asciz "{\"fold\":"
.Lview_nodes: .asciz ",\"nodes\":["
.Lview_links: .asciz "],\"links\":["
.Lview_from: .asciz "{\"from\":"
.Lview_to: .asciz ",\"to\":"
.Lview_kind: .asciz ",\"kind\":"
.Lview_sources: .asciz ",\"sourceIds\":"
.Lview_end: .asciz "]}"
.Lid: .asciz "id"
.Lx: .asciz "x"
.Ly: .asciz "y"
.Lw: .asciz "w"
.Lh: .asciz "h"
.p2align 3
.Lview_fields:
    .quad .Lid,CE_reserved,2,0,0
    .quad .Lx,CE_x,2,0,0
    .quad .Ly,CE_y,2,0,0
    .quad .Lw,CE_w,2,0,0
    .quad .Lh,CE_h,2,0,0
    .quad 0
