.include "rhun.inc"
.include "canvas/canvas.inc"
.include "memory/memory.inc"
.include "canvas/graph.inc"
.text
FN memory_prepare
    PROLOGUE
    mov rbx, rdi
    mov r12, [rbx + SC_memory_view]
    test r12, r12
    jz .Lmprep_new
    mov rax, [rbx + SC_revision]
    cmp [r12 + MM_revision], rax
    je .Lmprep_done
    mov rdi, r12
    call memory_free
    mov qword ptr [rbx + SC_memory_view], 0
.Lmprep_new:
    mov rdi, [rbx + SC_memory]
    test rdi, rdi
    jz .Lmprep_none
    cmp byte ptr [rdi], 0
    je .Lmprep_none
    call strlen
    mov rsi, rax
    mov rdi, [rbx + SC_memory]
    call memory_parse
    mov r12, rax
    test rax, rax
    jz .Lmprep_none
    mov rcx, [rbx + SC_revision]
    mov [rax + MM_revision], rcx
    mov [rbx + SC_memory_view], rax
.Lmprep_done: mov rax, r12
    EPILOGUE
.Lmprep_none: xor eax, eax
    EPILOGUE
FN memory_active
    PROLOGUE
    call canvas_active
    test rax, rax
    jz .Lactive_done
    mov rdi, rax
    call memory_prepare
.Lactive_done: EPILOGUE
FN memory_snapshot
    mov eax, [rdi + MM_cursor]
    imul rax, MS_SIZE
    add rax, [rdi + MM_snapshots + VEC_ptr]
    ret
FN cmd_memory_next
    mov edi, 1
    jmp memory_step
FN cmd_memory_prev
    mov edi, -1
memory_step:
    PROLOGUE
    mov r12d, edi
    call memory_active
    mov rbx, rax
    test rax, rax
    jz .Lstep_done
    mov eax, [rbx + MM_cursor]
    add eax, r12d
    test eax, eax
    js .Lstep_done
    cmp rax, [rbx + MM_snapshots + VEC_len]
    jae .Lstep_done
    mov [rbx + MM_cursor], eax
    mov rcx, [rbx + MM_scene]
    test rcx, rcx
    jz .Lstep_camera_graph
    mov edx, [rcx + SC_zoom]
    mov [rbx + MM_camera_zoom], edx
    mov edx, [rcx + SC_pan_x]
    mov [rbx + MM_camera_x], edx
    mov edx, [rcx + SC_pan_y]
    mov [rbx + MM_camera_y], edx
.Lstep_camera_graph:
    mov rcx, [rbx + MM_graph]
    test rcx, rcx
    jz .Lstep_camera_done
    mov edx, [rcx + GR_zoom]
    mov [rbx + MM_graph_zoom], edx
    mov edx, [rcx + GR_yaw]
    mov [rbx + MM_graph_yaw], edx
    mov edx, [rcx + GR_pitch]
    mov [rbx + MM_graph_pitch], edx
.Lstep_camera_done:
    mov dword ptr [rbx + MM_selected], 0
    mov rdi, [rbx + MM_scene]
    call scene_free
    mov qword ptr [rbx + MM_scene], 0
    mov rdi, [rbx + MM_graph]
    call canvas_graph_free
    mov qword ptr [rbx + MM_graph], 0
    mov dword ptr [rip + g_dirty], 1
.Lstep_done: EPILOGUE
FN cmd_memory_mode
    PROLOGUE
    call memory_active
    test rax, rax
    jz .Lmode_done
    xor dword ptr [rax + MM_mode], 1
    mov dword ptr [rip + g_dirty], 1
.Lmode_done: EPILOGUE
FN cmd_memory_entry
    PROLOGUE
    call memory_active
    test rax, rax
    jz .Lentry_done
    mov rbx, rax
    mov rdi, rax
    call memory_build_scene
    mov rax, [rbx + MM_scene]
    mov dword ptr [rax + SC_pan_x], 0
    mov dword ptr [rax + SC_pan_y], 0
    mov dword ptr [rax + SC_zoom], 49152
    mov dword ptr [rip + g_dirty], 1
.Lentry_done: EPILOGUE
# SB, node -> owned-source description (no raw memory is treated as markup).
FN memory_description
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov rsi, [r12 + MN_label]
    call sb_push_cstr
    mov rdi, rbx
    mov esi, 10
    call sb_push_byte
    mov rdi, rbx
    mov rsi, [r12 + MN_address]
    call sb_push_cstr
    mov rdi, rbx
    lea rsi, [rip + .Lsize]
    call sb_push_cstr
    mov rdi, rbx
    mov esi, [r12 + MN_size]
    call sb_push_u64
    mov rdi, rbx
    lea rsi, [rip + .Lcapacity]
    call sb_push_cstr
    mov rdi, rbx
    mov esi, [r12 + MN_capacity]
    call sb_push_u64
    mov rdi, rbx
    mov esi, 10
    call sb_push_byte
    mov eax, [r12 + MN_state]
    lea rcx, [rip + .Lstates]
    mov rsi, [rcx + rax*8]
    mov rdi, rbx
    call sb_push_cstr
    mov rdi, rbx
    lea rsi, [rip + .Lcertainty]
    call sb_push_cstr
    mov eax, [r12 + MN_certainty]
    lea rcx, [rip + .Lcertainties]
    mov rsi, [rcx + rax*8]
    mov rdi, rbx
    call sb_push_cstr
    EPILOGUE
# Derived scene has no model/source edits. Positions depend only on lane and order.
FN memory_build_scene
    PROLOGUE SB_SIZE+64
    mov rbx, rdi
    cmp qword ptr [rbx + MM_scene], 0
    jne .Lbuild_done
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE+64
    call memset
    call scene_new
    mov r12, rax
    mov [rbx + MM_scene], rax
    mov dword ptr [rax + SC_zoom], 49152
    cmp dword ptr [rbx + MM_camera_zoom], 0
    je .Lbuild_camera_done
    mov ecx, [rbx + MM_camera_zoom]
    mov [rax + SC_zoom], ecx
    mov ecx, [rbx + MM_camera_x]
    mov [rax + SC_pan_x], ecx
    mov ecx, [rbx + MM_camera_y]
    mov [rax + SC_pan_y], ecx
.Lbuild_camera_done:
    mov rdi, rbx
    call memory_snapshot
    mov r13, rax
    xor r14d, r14d
.Lbuild_frame:
    mov rdi, r12
    mov esi, CT_FRAME
    imul edx, r14d, 380
    add edx, 40
    mov ecx, 50
    mov r8d, 360
    mov r9d, 280
    call scene_add
    mov rcx, [rax + CE_id]
    mov [rsp + SB_SIZE + r14*8], rcx
    mov rdi, r12
    mov esi, CT_TEXT
    imul edx, r14d, 380
    add edx, 52
    mov ecx, 58
    mov r8d, 340
    mov r9d, 32
    call scene_add
    mov r15, rax
    mov rcx, [rsp + SB_SIZE + r14*8]
    mov [rax + CE_frame], rcx
    lea rax, [rip + .Llanes]
    mov rdi, [rax + r14*8]
    call strlen
    mov rsi, rax
    lea rax, [rip + .Llanes]
    mov rdi, [rax + r14*8]
    call mem_dup
    mov [r15 + CE_text], rax
    inc r14d
    cmp r14d, 3
    jb .Lbuild_frame
    xor r14d, r14d
.Lbuild_node:
    cmp r14, [r13 + MS_nodes + VEC_len]
    jae .Lbuild_links_start
    imul r15, r14, MN_SIZE
    add r15, [r13 + MS_nodes + VEC_ptr]
    mov eax, [r15 + MN_kind]
    xor ecx, ecx
    test eax, eax
    jz .Lbuild_lane
    mov ecx, 2
    cmp eax, 1
    je .Lbuild_stack
    cmp eax, 4
    jne .Lbuild_lane
.Lbuild_stack: mov ecx, 1
.Lbuild_lane:
    mov [rsp + SB_SIZE + 40], ecx
    mov edx, [rsp + SB_SIZE + 24 + rcx*4]
    inc dword ptr [rsp + SB_SIZE + 24 + rcx*4]
    imul edx, 180
    add edx, 108
    mov [rsp + SB_SIZE + 44], edx
    imul ecx, 380
    add ecx, 50
    mov [rsp + SB_SIZE + 48], ecx
    mov rdi, r12
    mov esi, CT_RECT
    xchg edx, ecx
    mov r8d, 340
    mov r9d, 160
    call scene_add
    mov edx, [r15 + MN_kind]
    lea rcx, [rip + .Lnode_colors]
    mov edx, [rcx + rdx*4]
    cmp dword ptr [r15 + MN_state], 1
    jne .Lbuild_node_color
    mov edx, 0xffe18b83
.Lbuild_node_color:
    mov [rax + CE_color], edx
    mov rcx, [rax + CE_id]
    mov [r15 + MN_viewid], rcx
    mov ecx, [rsp + SB_SIZE + 40]
    mov rcx, [rsp + SB_SIZE + rcx*8]
    mov [rax + CE_frame], rcx
    mov [rsp + SB_SIZE + 56], rcx
    mov edx, [rsp + SB_SIZE + 44]
    add edx, 180
    mov [rsp + SB_SIZE + 52], edx
    mov rdi, r12
    mov rsi, rcx
    call scene_find
    mov edx, [rsp + SB_SIZE + 52]
    sub edx, [rax + CE_y]
    cmp [rax + CE_h], edx
    cmovg edx, [rax + CE_h]
    mov [rax + CE_h], edx
    mov rdi, rsp
    call sb_clear
    mov rdi, rsp
    mov rsi, r15
    call memory_description
    mov rdi, r12
    mov esi, CT_TEXT
    mov edx, [rsp + SB_SIZE + 48]
    add edx, 10
    mov ecx, [rsp + SB_SIZE + 44]
    add ecx, 8
    mov r8d, 320
    mov r9d, 144
    call scene_add
    mov rcx, [rsp + SB_SIZE + 56]
    mov [rax + CE_frame], rcx
    mov rcx, [r15 + MN_viewid]
    mov [rax + CE_group], rcx
    mov r15, rax
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call mem_dup
    mov [r15 + CE_text], rax
    inc r14d
    jmp .Lbuild_node
.Lbuild_links_start: xor r14d, r14d
.Lbuild_link:
    cmp r14, [r13 + MS_links + VEC_len]
    jae .Lbuild_free
    imul r15, r14, ML_SIZE
    add r15, [r13 + MS_links + VEC_ptr]
    mov eax, [r15 + ML_a]
    dec eax
    imul rax, MN_SIZE
    add rax, [r13 + MS_nodes + VEC_ptr]
    mov rsi, [rax + MN_viewid]
    mov [rsp + SB_SIZE + 40], rsi
    mov rdi, r12
    call scene_find
    mov edx, [rax + CE_x]
    add edx, 170
    mov ecx, [rax + CE_y]
    add ecx, 80
    mov [rsp + SB_SIZE + 48], edx
    mov [rsp + SB_SIZE + 52], ecx
    mov eax, [r15 + ML_b]
    dec eax
    imul rax, MN_SIZE
    add rax, [r13 + MS_nodes + VEC_ptr]
    mov rsi, [rax + MN_viewid]
    mov [rsp + SB_SIZE + 56], rsi
    mov rdi, r12
    call scene_find
    mov r8d, [rax + CE_x]
    add r8d, 170
    sub r8d, [rsp + SB_SIZE + 48]
    mov r9d, [rax + CE_y]
    add r9d, 80
    sub r9d, [rsp + SB_SIZE + 52]
    mov rdi, r12
    mov esi, CT_ARROW
    mov edx, [rsp + SB_SIZE + 48]
    mov ecx, [rsp + SB_SIZE + 52]
    call scene_add
    mov rcx, [rsp + SB_SIZE + 40]
    mov [rax + CE_from], rcx
    mov rcx, [rsp + SB_SIZE + 56]
    mov [rax + CE_to], rcx
    mov edx, [r15 + ML_kind]
    lea rcx, [rip + .Llink_colors]
    mov edx, [rcx + rdx*4]
    mov [rax + CE_color], edx
    inc r14d
    jmp .Lbuild_link
.Lbuild_free: mov rdi, rsp
    call sb_free
.Lbuild_done: EPILOGUE
FN memory_draw
    PROLOGUE
    mov rbx, rdi
    call memory_prepare
    test rax, rax
    jz .Ldraw_done
    mov r12, rax
    mov rdi, rax
    call memory_build_scene
    mov r13, [r12 + MM_scene]
    cmp dword ptr [r12 + MM_mode], 0
    jne .Ldraw_graph
    mov eax, [r12 + MM_selected]
    test eax, eax
    jz .Ldraw_no_saved_selection
    dec eax
    mov r14d, eax
    mov rdi, r12
    call memory_snapshot
    cmp r14, [rax + MS_nodes + VEC_len]
    jae .Ldraw_no_saved_selection
    imul rcx, r14, MN_SIZE
    add rcx, [rax + MS_nodes + VEC_ptr]
    mov rsi, [rcx + MN_viewid]
    mov [r13 + SC_selected], rsi
    mov rdi, r13
    call scene_find
    or dword ptr [rax + CE_flags], 1
.Ldraw_no_saved_selection:
    # Copy live viewport, preserving the derived scene's own camera.
    mov eax, [rbx + SC_x]
    mov [r13 + SC_x], eax
    mov eax, [rbx + SC_y]
    mov [r13 + SC_y], eax
    mov eax, [rbx + SC_w]
    mov [r13 + SC_w], eax
    mov eax, [rbx + SC_h]
    mov [r13 + SC_h], eax
    mov rdi, r13
    call canvas_view_input
    test dword ptr [rip + g_pressed], 1 << BTN_LEFT
    jz .Ldraw_paint_start
    mov rdi, r13
    mov esi, [rip + g_mx]
    mov edx, [rip + g_my]
    call scene_to_world
    mov esi, eax
    mov rdi, r13
    call scene_hit
    test rax, rax
    jz .Ldraw_paint_start
    mov r14, rax
    mov rdi, r13
    call scene_deselect
    mov rax, [r14 + CE_group]
    test rax, rax
    jnz .Ldraw_select
    mov rax, [r14 + CE_id]
.Ldraw_select:
    mov [r13 + SC_selected], rax
    mov rdi, r13
    mov rsi, rax
    call scene_find
    test rax, rax
    jz .Ldraw_paint_start
    or dword ptr [rax + CE_flags], 1
    mov rdi, r12
    call memory_snapshot
    xor ecx, ecx
.Ldraw_find_selected:
    cmp rcx, [rax + MS_nodes + VEC_len]
    jae .Ldraw_paint_start
    imul rdx, rcx, MN_SIZE
    add rdx, [rax + MS_nodes + VEC_ptr]
    mov rsi, [r13 + SC_selected]
    cmp [rdx + MN_viewid], rsi
    je .Ldraw_store_selected
    inc ecx
    jmp .Ldraw_find_selected
.Ldraw_store_selected: inc ecx
    mov [r12 + MM_selected], ecx
.Ldraw_paint_start: xor r14d, r14d
.Ldraw_paint:
    cmp r14, [r13 + SC_elements + VEC_len]
    jae .Ldraw_done
    imul r15, r14, CE_SIZE
    add r15, [r13 + SC_elements + VEC_ptr]
    mov rdi, r13
    mov rsi, r15
    call canvas_paint_element
    inc r14
    jmp .Ldraw_paint
    jmp .Ldraw_done
.Ldraw_graph:
    mov rdi, r12
    call memory_build_graph
    mov r13, [r12 + MM_graph]
    mov eax, [r12 + MM_selected]
    mov [r13 + GR_selected], eax
    mov [rbx + SC_graph_view], r13
    mov rdi, rbx
    call canvas_graph_draw
    mov qword ptr [rbx + SC_graph_view], 0
    mov eax, [r13 + GR_selected]
    mov [r12 + MM_selected], eax
.Ldraw_done: EPILOGUE
FN memory_key
    test edx, MOD_CTRL | MOD_ALT | MOD_SUPER
    jnz .Lkey_no
    cmp esi, ']'
    je .Lkey_next
    cmp esi, '['
    je .Lkey_prev
    cmp esi, 'f'
    je .Lkey_fold
    cmp esi, 'v'
    je .Lkey_mode
    cmp esi, 'n'
    je .Lkey_entry
    mov eax, 1
    ret
.Lkey_next: push rbx
    call cmd_memory_next
    pop rbx
    mov eax, 1
    ret
.Lkey_prev: push rbx
    call cmd_memory_prev
    pop rbx
    mov eax, 1
    ret
.Lkey_fold: push rbx
    call cmd_memory_fold
    pop rbx
    mov eax, 1
    ret
.Lkey_mode: push rbx
    call cmd_memory_mode
    pop rbx
    mov eax, 1
    ret
.Lkey_entry: push rbx
    call cmd_memory_entry
    pop rbx
    mov eax, 1
    ret
.Lkey_no: xor eax, eax
    ret
FN memory_toolbar
    PROLOGUE SB_SIZE
    mov rbx, rdi
    mov r12d, esi
    call memory_prepare
    mov r13, rax
    test rax, rax
    jz .Ltoolbar_done
    xor r14d, r14d
.Ltoolbar_button:
    cmp r14d, 4
    jae .Ltoolbar_label
    imul r15d, r14d, 82
    add r15d, [rbx + SC_x]
    mov edi, 0x7e00
    add edi, r14d
    mov esi, r15d
    mov edx, r12d
    mov ecx, 80
    M r8d, MI_40
    call ui_btn
    test eax, UB_CLICK
    jz .Ltoolbar_button_text
    lea rax, [rip + .Lactions]
    call [rax + r14*8]
.Ltoolbar_button_text:
    lea rdi, [rip + g_face_small]
    mov esi, r15d
    add esi, 6
    mov edx, r12d
    M ecx, MI_40
    lea rax, [rip + .Lbuttons]
    mov r8, [rax + r14*8]
    COLOR r9d, T_ACCENT
    call ui_text_c
    inc r14d
    jmp .Ltoolbar_button
.Ltoolbar_label:
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov eax, [r13 + MM_provenance]
    lea rcx, [rip + .Lprovenances]
    mov rsi, [rcx + rax*8]
    mov rdi, rsp
    call sb_push_cstr
    mov rdi, rsp
    mov esi, [r13 + MM_cursor]
    inc esi
    call sb_push_u64
    mov rdi, rsp
    mov esi, '/'
    call sb_push_byte
    mov rdi, rsp
    mov rsi, [r13 + MM_snapshots + VEC_len]
    call sb_push_u64
    mov rdi, r13
    call memory_snapshot
    mov r13, rax
    mov rdi, rsp
    mov esi, ' '
    call sb_push_byte
    mov rdi, rsp
    mov rsi, [r13 + MS_label]
    call sb_push_cstr
    lea rdi, [rip + g_face_small]
    mov esi, [rbx + SC_x]
    add esi, 334
    mov edx, r12d
    M ecx, MI_40
    mov r8, [rsp + SB_ptr]
    COLOR r9d, T_MUTED
    call ui_text_c
    mov rdi, rsp
    call sb_free
.Ltoolbar_done: EPILOGUE
.section .rodata
.Lsize: .asciz "\nrequested: "
.Lcapacity: .asciz " / slot: "
.Lcertainty: .asciz " | "
.Llive: .asciz "live"
.Lfreed: .asciz "freed / historical"
.Lunknown: .asciz "unknown"
.Lfact: .asciz "declared fact"
.Linferred: .asciz "inferred"
.Lcandidate: .asciz "candidate"
.Ldemo: .asciz "teaching model"
.Lcode: .asciz "Code / entry / init"
.Lstack: .asciz "Thread stack / pointer slots"
.Lheap: .asciz "Mappings / allocations"
.Lmode: .asciz "2D / 3D"
.Lprev: .asciz "Previous"
.Lnext: .asciz "Next"
.Lentry: .asciz "Entry"
.Lstatic: .asciz "STATIC "
.Limported: .asciz "IMPORTED "
.Lteaching: .asciz "DEMO "
.p2align 3
.Lstates: .quad .Llive,.Lfreed,.Lunknown
.Lcertainties: .quad .Lfact,.Linferred,.Lcandidate,.Ldemo
.Llanes: .quad .Lcode,.Lstack,.Lheap
.Lbuttons: .quad .Lmode,.Lprev,.Lnext,.Lentry
.Lactions: .quad cmd_memory_mode,cmd_memory_prev,cmd_memory_next,cmd_memory_entry
.Lprovenances: .quad .Lstatic,.Limported,.Lteaching

.p2align 2
.Lnode_colors: .long 0xff8da4ff,0xffffbc66,0xff78c88d,0xff78c88d,0xffffbc66
.Llink_colors: .long 0xff8da4ff,0xff78c88d,0xffffbc66,0xffe18b83,0xff8da4ff
