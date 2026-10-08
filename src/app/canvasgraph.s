.include "rhun.inc"
.include "canvas/canvas.inc"
.include "canvas/graph.inc"
.include "memory/memory.inc"
.text
FN canvas_graph_active
    call canvas_active
    test rax, rax
    jz 9f
    mov rcx, [rax + SC_memory]
    test rcx, rcx
    jz .Lgraph_active_regular
    cmp byte ptr [rcx], 0
    je .Lgraph_active_regular
    mov rdi, rax
    jmp memory_graph_for_scene
.Lgraph_active_regular:
    mov rax, [rax + SC_graph_view]
9:  ret
FN cmd_canvas_graph_mode
    PROLOGUE
    call canvas_graph_active
    test rax, rax
    jz 9f
    xor dword ptr [rax + GR_mode], 1
9:  mov dword ptr [rip + g_dirty], 1
    EPILOGUE
FN cmd_canvas_graph_fold
    PROLOGUE
    call canvas_graph_active
    mov rbx, rax
    test rax, rax
    jz 9f
    mov esi, [rax + GR_selected]
    cmp esi, 256
    ja 1f
    test esi, esi
    jz 9f
    cmp rsi, [rbx + GR_nodes + VEC_len]
    ja 9f
    dec esi
    imul rax, rsi, GN_SIZE
    add rax, [rbx + GR_nodes + VEC_ptr]
    mov esi, [rax + GN_segment]
    jmp 2f
1:  sub esi, 256
2:  test esi, esi
    jz 9f
    btc dword ptr [rbx + GR_fold], esi
9:  mov dword ptr [rip + g_dirty], 1
    EPILOGUE
FN cmd_canvas_graph_next_event
    mov edi, 1
    jmp canvas_graph_event_step
FN cmd_canvas_graph_prev_event
    mov edi, -1
    jmp canvas_graph_event_step
canvas_graph_event_step:
    PROLOGUE
    mov r12d, edi
    call canvas_graph_active
    test rax, rax
    jz 9f
    mov ecx, [rax + GR_event]
    add ecx, r12d
    test ecx, ecx
    js 9f
    cmp rcx, [rax + GR_events + VEC_len]
    jae 9f
    mov [rax + GR_event], ecx
9:  mov dword ptr [rip + g_dirty], 1
    EPILOGUE
FN cmd_canvas_graph_select_next
    PROLOGUE
    call canvas_graph_active
    test rax, rax
    jz 9f
    inc dword ptr [rax + GR_selected]
    mov ecx, [rax + GR_selected]
    cmp rcx, [rax + GR_nodes + VEC_len]
    jbe 9f
    mov dword ptr [rax + GR_selected], 1
9:  mov dword ptr [rip + g_dirty], 1
    EPILOGUE
FN canvas_graph_key
    PROLOGUE
    mov r12d, edi
    test edx, MOD_CTRL | MOD_ALT | MOD_SUPER
    jnz 8f
    cmp esi, 'v'
    jne 1f
    call cmd_canvas_graph_mode
    jmp 9f
1:  cmp esi, 'f'
    jne 2f
    call cmd_canvas_graph_fold
    jmp 9f
2:  cmp esi, ']'
    jne 3f
    call cmd_canvas_graph_next_event
    jmp 9f
3:  cmp esi, '['
    jne 9f
    call cmd_canvas_graph_prev_event
9:  mov eax, 1
    EPILOGUE
8:  xor eax, eax
    EPILOGUE

FN canvas_graph_draw
    PROLOGUE 16
    mov rbx, rdi
    mov r12, [rbx + SC_graph_view]
    mov eax, [rbx + SC_x]
    mov [r12 + GR_view_x], eax
    mov eax, [rbx + SC_y]
    add eax, 20
    mov [r12 + GR_view_y], eax
    mov eax, [rbx + SC_w]
    mov dword ptr [rsp], 0
    cmp eax, 600
    jl 1f
    mov dword ptr [rsp], 230
    sub eax, 230
1:  mov [r12 + GR_view_w], eax
    mov eax, [rbx + SC_h]
    sub eax, 100
    cmp eax, 1
    jge 2f
    mov eax, 1
2:  mov [r12 + GR_view_h], eax
    mov rdi, r12
    call canvas_graph_input
    mov rdi, r12
    call canvas_graph_projection
    mov rdi, r12
    call canvas_graph_pick
    mov edi, [r12 + GR_view_x]
    mov esi, [r12 + GR_view_y]
    mov edx, [r12 + GR_view_w]
    mov ecx, [r12 + GR_view_h]
    call gfx_clip_push
    xor r13d, r13d
3:  cmp r13, [r12 + GR_segments + VEC_len]
    jae 4f
    imul rsi, r13, GS_SIZE
    add rsi, [r12 + GR_segments + VEC_ptr]
    mov rdi, r12
    call canvas_graph_frame
    inc r13
    jmp 3b
4:  xor r13d, r13d
5:  cmp r13, [r12 + GR_links + VEC_len]
    jae 6f
    imul rsi, r13, VE_SIZE
    add rsi, [r12 + GR_links + VEC_ptr]
    mov rdi, r12
    call canvas_graph_arrow
    inc r13
    jmp 5b
6:  xor r13d, r13d
7:  cmp r13, [r12 + GR_visible + VEC_len]
    jae 8f
    imul rsi, r13, VP_SIZE
    add rsi, [r12 + GR_visible + VEC_ptr]
    mov rdi, r12
    call canvas_graph_node
    inc r13
    jmp 7b
8:  call gfx_clip_pop
    mov rdi, rbx
    mov rsi, r12
    mov edx, [rsp]
    call canvas_graph_inspector
    mov rdi, rbx
    mov rsi, r12
    call canvas_graph_timeline
    EPILOGUE
canvas_graph_input:
    PROLOGUE
    mov rbx, rdi
    mov edi, [rbx + GR_view_x]
    mov esi, [rbx + GR_view_y]
    mov edx, [rbx + GR_view_w]
    mov ecx, [rbx + GR_view_h]
    call ui_in
    test eax, eax
    jz 4f
    mov eax, [rip + g_scroll_y]
    test eax, eax
    jz 2f
    mov ecx, [rbx + GR_zoom]
    mov edx, ecx
    shr edx, 3
    test eax, eax
    jg 1f
    add ecx, edx
    jmp 11f
1:  sub ecx, edx
11: cmp ecx, 16384
    jge 12f
    mov ecx, 16384
12: cmp ecx, 262144
    jle 13f
    mov ecx, 262144
13: mov [rbx + GR_zoom], ecx
    mov dword ptr [rip + g_scroll_y], 0
2:  test dword ptr [rip + g_pressed], 1 << BTN_MIDDLE
    jz 4f
    mov dword ptr [rbx + GR_drag], 1
    mov eax, [rip + g_mx]
    mov [rbx + GR_mx], eax
    mov eax, [rip + g_my]
    mov [rbx + GR_my], eax
4:  cmp dword ptr [rbx + GR_drag], 0
    je 9f
    test dword ptr [rip + g_mdown], 1 << BTN_MIDDLE
    jz 8f
    mov eax, [rip + g_mx]
    mov ecx, eax
    sub ecx, [rbx + GR_mx]
    sar ecx, 1
    add [rbx + GR_yaw], ecx
    mov [rbx + GR_mx], eax
    mov eax, [rbx + GR_yaw]
    cdq
    mov ecx, 360
    idiv ecx
    mov [rbx + GR_yaw], edx
    mov eax, [rip + g_my]
    mov ecx, eax
    sub ecx, [rbx + GR_my]
    sar ecx, 1
    add ecx, [rbx + GR_pitch]
    cmp ecx, -80
    jge 5f
    mov ecx, -80
5:  cmp ecx, 80
    jle 6f
    mov ecx, 80
6:  mov [rbx + GR_pitch], ecx
    mov [rbx + GR_my], eax
    jmp 9f
8:  mov dword ptr [rbx + GR_drag], 0
9:  EPILOGUE
canvas_graph_pick:
    PROLOGUE
    mov rbx, rdi
    mov edi, [rbx + GR_view_x]
    mov esi, [rbx + GR_view_y]
    mov edx, [rbx + GR_view_w]
    mov ecx, [rbx + GR_view_h]
    call ui_in
    test eax, eax
    jz 9f
    test dword ptr [rip + g_pressed], 1 << BTN_LEFT
    jz 9f
    mov r12, [rbx + GR_visible + VEC_len]
1:  test r12, r12
    jz 9f
    dec r12
    imul rax, r12, VP_SIZE
    add rax, [rbx + GR_visible + VEC_ptr]
    movsxd rcx, dword ptr [rip + g_mx]
    movsxd rdx, dword ptr [rax + VP_x]
    sub rcx, rdx
    imul rcx, rcx
    movsxd rdx, dword ptr [rip + g_my]
    movsxd rsi, dword ptr [rax + VP_y]
    sub rdx, rsi
    imul rdx, rdx
    add rcx, rdx
    cmp rcx, 24*24
    ja 1b
    mov eax, [rax + VP_id]
    mov [rbx + GR_selected], eax
9:  EPILOGUE
canvas_graph_frame:
    PROLOGUE 112
    mov rbx, rdi
    mov r12, rsi
    mov ecx, [r12 + GS_id]
    bt dword ptr [rbx + GR_fold], ecx
    jc 9f
    xor r13d, r13d
1:  cmp r13d, 8
    jae 3f
    xor r14d, r14d
2:  mov eax, [r12 + GS_half + r14*4]
    mov ecx, r14d
    bt r13d, ecx
    jc 21f
    neg eax
21: add eax, [r12 + GS_center + r14*4]
    mov [rsp + 96 + r14*4], eax
    inc r14d
    cmp r14d, 3
    jb 2b
    mov rdi, rbx
    lea rsi, [rsp + 96]
    call canvas_graph_perspective
    lea rcx, [r13 + r13*2]
    mov [rsp + rcx*4 + 8], eax
    test eax, eax
    jz 22f
    mov rdi, rbx
    call canvas_graph_screen
    lea rcx, [r13 + r13*2]
    mov [rsp + rcx*4], eax
    mov [rsp + rcx*4 + 4], edx
22: inc r13
    jmp 1b
3:  xor r13d, r13d
4:  cmp r13d, 12
    jae 9f
    lea rax, [rip + .Lcube_edges]
    movzx r14d, byte ptr [rax + r13*2]
    movzx r15d, byte ptr [rax + r13*2 + 1]
    imul r14d, 12
    imul r15d, 12
    cmp dword ptr [rsp + r14 + 8], 0
    je 5f
    cmp dword ptr [rsp + r15 + 8], 0
    je 5f
    mov edi, [rsp + r14]
    mov esi, [rsp + r14 + 4]
    mov edx, [rsp + r15]
    mov ecx, [rsp + r15 + 4]
    mov r8d, 0xff3c4656
    call canvas_line
5:  inc r13
    jmp 4b
9:  mov rdi, rbx
    lea rsi, [r12 + GS_center]
    call canvas_graph_perspective
    test eax, eax
    jz 91f
    mov rdi, rbx
    call canvas_graph_screen
    lea esi, [rax - 30]
    sub edx, 65
    lea rdi, [rip + g_face_small]
    mov ecx, 20
    mov r8, [r12 + GS_name]
    mov r9d, 0xff8992a3
    call ui_text_c
91: EPILOGUE
canvas_graph_node:
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov r13d, 10
    mov r14d, 0xff8992a3
    cmp dword ptr [rbx + GR_profile], 1
    jne .Lnode_regular
    mov eax, [r12 + VP_id]
    dec eax
    cmp rax, [rbx + GR_nodes + VEC_len]
    jae 4f
    imul rax, GN_SIZE
    add rax, [rbx + GR_nodes + VEC_ptr]
    mov ecx, [rax + GN_memory_kind]
    lea rdx, [rip + .Lmemory_node_colors]
    mov r14d, [rdx + rcx*4]
    cmp dword ptr [rax + GN_memory_state], 1
    jne 4f
    mov r14d, 0xffe18b83
    jmp 4f
.Lnode_regular:
    cmp dword ptr [r12 + VP_kind], 2
    jne 1f
    mov r14d, 0xff8da4ff
1:  cmp dword ptr [r12 + VP_kind], 3
    jne 2f
    mov r13d, 16
2:  cmp dword ptr [r12 + VP_kind], 1
    jne 4f
    mov r14d, 0xff65c195
    mov eax, [rbx + GR_event]
    imul rax, EV_SIZE
    add rax, [rbx + GR_events + VEC_ptr]
    mov ecx, [r12 + VP_realm]
    mov eax, [rax + EV_versions + rcx*4]
    mov ecx, 7
    cmp dword ptr [rbx + GR_event], 0
    je 3f
    inc ecx
3:  cmp eax, ecx
    je 4f
    mov r14d, 0xffe4b665
4:  mov eax, [r12 + VP_id]
    cmp eax, [rbx + GR_selected]
    jne 5f
    mov edi, [r12 + VP_x]
    sub edi, r13d
    sub edi, 3
    mov esi, [r12 + VP_y]
    sub esi, r13d
    sub esi, 3
    lea edx, [r13*2 + 6]
    mov ecx, edx
    mov r8d, 0xff8da4ff
    call canvas_ellipse
5:  mov edi, [r12 + VP_x]
    sub edi, r13d
    mov esi, [r12 + VP_y]
    sub esi, r13d
    lea edx, [r13*2]
    mov ecx, edx
    mov r8d, r14d
    call canvas_ellipse
    mov edi, [r12 + VP_x]
    sub edi, 4
    mov esi, [r12 + VP_y]
    sub esi, 5
    mov edx, 5
    mov ecx, 5
    mov r8d, 0xffd5d9e2
    call canvas_ellipse
    lea rdi, [rip + g_face_ui]
    mov esi, [r12 + VP_x]
    add esi, r13d
    add esi, 5
    mov edx, [r12 + VP_y]
    sub edx, 12
    mov ecx, 24
    mov r8, [r12 + VP_name]
    mov r9d, r14d
    call ui_text_c
    EPILOGUE
canvas_graph_arrow:
    PROLOGUE 32
    mov rbx, rdi
    mov r12, rsi
    mov esi, [r12 + VE_a]
    call canvas_graph_visible_find
    mov r13, rax
    mov rdi, rbx
    mov esi, [r12 + VE_b]
    call canvas_graph_visible_find
    mov r14, rax
    test r13, r13
    jz 9f
    test r14, r14
    jz 9f
    mov r15d, 0xff596881
    cmp dword ptr [r12 + VE_kind], 1
    jne 1f
    mov r15d, 0xff8d79b8
1:  cmp dword ptr [rbx + GR_profile], 1
    jne .Larrow_regular_active
    mov eax, [r12 + VE_kind]
    lea rcx, [rip + .Lmemory_link_colors]
    mov r15d, [rcx + rax*4]
    jmp 101f
.Larrow_regular_active:
    mov rdi, rbx
    mov rsi, r12
    call canvas_graph_link_active
    test eax, eax
    jz 101f
    mov r15d, 0xff65c195
101: mov edi, [r13 + VP_x]
    mov esi, [r13 + VP_y]
    mov edx, [r14 + VP_x]
    mov ecx, [r14 + VP_y]
    mov [rsp], edx
    mov [rsp + 4], ecx
    sub edx, edi
    sub ecx, esi
    cvtsi2sd xmm0, edx
    cvtsi2sd xmm1, ecx
    movapd xmm2, xmm0
    movapd xmm3, xmm1
    mulsd xmm2, xmm2
    mulsd xmm3, xmm3
    addsd xmm2, xmm3
    sqrtsd xmm2, xmm2
    comisd xmm2, [rip + .Larrow_min]
    jbe 9f
    divsd xmm0, xmm2
    divsd xmm1, xmm2
    mulsd xmm0, [rip + .Larrow_radius]
    mulsd xmm1, [rip + .Larrow_radius]
    cvtsd2si eax, xmm0
    cvtsd2si edx, xmm1
    add edi, eax
    add esi, edx
    sub [rsp], eax
    sub [rsp + 4], edx
    movsd [rsp + 8], xmm0
    movsd [rsp + 16], xmm1
    mov edx, [rsp]
    mov ecx, [rsp + 4]
    mov r8d, r15d
    call canvas_line
    cmp dword ptr [r12 + VE_kind], 1
    je 9f
    mov r14d, 1
2:  movsd xmm0, [rsp + 8]
    movsd xmm1, [rsp + 16]
    mulsd xmm0, [rip + .Larrow_half]
    mulsd xmm1, [rip + .Larrow_half]
    cvtsd2si eax, xmm0
    cvtsd2si edx, xmm1
    imul edx, r14d
    imul eax, r14d
    mov edi, [rsp]
    mov esi, [rsp + 4]
    sub edi, edx
    add esi, eax
    movsd xmm0, [rsp + 8]
    movsd xmm1, [rsp + 16]
    cvtsd2si eax, xmm0
    cvtsd2si edx, xmm1
    sub edi, eax
    sub esi, edx
    mov edx, [rsp]
    mov ecx, [rsp + 4]
    mov r8d, r15d
    call canvas_line
    neg r14d
    cmp r14d, -1
    je 2b
9:  EPILOGUE
.section .rodata
.Lcube_edges: .byte 0,1,0,2,0,4,1,3,1,5,2,3,2,6,3,7,4,5,4,6,5,7,6,7
.p2align 3
.Larrow_min: .double 30.0
.Larrow_radius: .double 18.0
.Larrow_half: .double 0.25
.text
canvas_graph_inspector:
    PROLOGUE SB_SIZE+16
    mov rbx, rdi
    mov r12, rsi
    test edx, edx
    jz 9f
    mov eax, [rbx + SC_x]
    add eax, [r12 + GR_view_w]
    add eax, 12
    mov [rsp + SB_SIZE], eax
    mov eax, [rbx + SC_y]
    mov [rsp + SB_SIZE + 4], eax
    mov eax, [r12 + GR_selected]
    test eax, eax
    jz 9f
    cmp eax, 256
    ja .Lsegment_inspect
    cmp rax, [r12 + GR_nodes + VEC_len]
    ja 9f
    dec eax
    imul r13, rax, GN_SIZE
    add r13, [r12 + GR_nodes + VEC_ptr]
    mov edi, [rsp + SB_SIZE]
    mov esi, [rsp + SB_SIZE + 4]
    mov edx, 206
    mov rcx, [r13 + GN_name]
    mov r8d, 2
    mov r9d, 0xff8da4ff
    call canvas_graph_text
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    cmp dword ptr [r12 + GR_profile], 1
    jne .Linspector_regular_schema
    mov rdi, rsp
    mov rsi, [r13 + GN_object]
    call sb_push_cstr
    jmp 1f
.Linspector_regular_schema:
    mov rdi, rsp
    lea rsi, [rip + .Lschema_label]
    call sb_push_cstr
    mov rdi, rsp
    mov esi, [r13 + GN_schema]
    call sb_push_u64
    mov rdi, rsp
    mov esi, 10
    call sb_push_byte
    mov rdi, rsp
    mov rsi, [r13 + GN_object]
    call sb_push_cstr
    cmp dword ptr [r13 + GN_kind], 1
    jne 1f
    mov rdi, rsp
    lea rsi, [rip + .Lstate_label]
    call sb_push_cstr
    mov eax, [r12 + GR_event]
    imul rax, EV_SIZE
    add rax, [r12 + GR_events + VEC_ptr]
    mov ecx, [r13 + GN_realm]
    mov esi, [rax + EV_versions + rcx*4]
    mov rdi, rsp
    call sb_push_u64
1:  mov edi, [rsp + SB_SIZE]
    mov esi, [rsp + SB_SIZE + 4]
    add esi, 50
    mov edx, 206
    mov rcx, [rsp + SB_ptr]
    mov r8d, 4
    mov r9d, 0xffd8dee9
    call canvas_graph_text
    mov rdi, rsp
    call sb_free
    mov edi, [rsp + SB_SIZE]
    mov esi, [rsp + SB_SIZE + 4]
    add esi, 140
    mov edx, 206
    mov rcx, [r13 + GN_description]
    mov r8d, 5
    mov r9d, 0xff8992a3
    call canvas_graph_text
    jmp .Levent_inspect
.Lsegment_inspect:
    mov esi, eax
    sub esi, 256
    mov rdi, r12
    call canvas_graph_segment
    test rax, rax
    jz 9f
    mov edi, [rsp + SB_SIZE]
    mov esi, [rsp + SB_SIZE + 4]
    mov edx, 206
    mov rcx, [rax + GS_name]
    mov r8d, 2
    mov r9d, 0xff8da4ff
    call canvas_graph_text
.Levent_inspect:
    mov eax, [r12 + GR_event]
    imul r13, rax, EV_SIZE
    add r13, [r12 + GR_events + VEC_ptr]
    mov edi, [rsp + SB_SIZE]
    mov esi, [rsp + SB_SIZE + 4]
    add esi, 250
    mov edx, 206
    mov rcx, [r13 + EV_actor]
    mov r8d, 2
    mov r9d, 0xff65c195
    call canvas_graph_text
    mov edi, [rsp + SB_SIZE]
    mov esi, [rsp + SB_SIZE + 4]
    add esi, 300
    mov edx, 206
    mov rcx, [r13 + EV_note]
    mov r8d, 8
    mov r9d, 0xffd8dee9
    call canvas_graph_text
9:  EPILOGUE

# Wrapped native labels; clips are provided by the diagram or outer canvas.
canvas_graph_text:
    PROLOGUE 24
    mov [rsp], edi
    mov [rsp + 4], esi
    mov [rsp + 8], edx
    mov [rsp + 12], r9d
    mov rbx, rcx
    mov r12d, r8d
    mov rdi, rcx
    call strlen
    mov r13, rax
    xor r14d, r14d
1:  test r13, r13
    jz 9f
    cmp r14d, r12d
    jae 9f
    xor r15d, r15d
2:  cmp r15, r13
    jae 3f
    cmp byte ptr [rbx + r15], 10
    je 3f
    inc r15
    jmp 2b
3:  lea rdi, [rip + g_face_ui]
    mov rsi, rbx
    mov rdx, r15
    mov ecx, [rsp + 8]
    call text_fit
    test rax, rax
    jnz 4f
    test r15, r15
    jz 4f
    mov rdi, rbx
    mov rsi, r13
    call utf8_decode
    mov rax, rdx
4:  mov r15, rax
    lea rdi, [rip + g_face_ui]
    mov esi, [rsp]
    mov edx, [rsp + 4]
    add edx, [rip + g_face_ui + FACE_ascent]
    mov rcx, rbx
    mov r8, r15
    mov r9d, [rsp + 12]
    call text_draw
    add rbx, r15
    sub r13, r15
    test r13, r13
    jz 9f
    cmp byte ptr [rbx], 10
    jne 5f
    inc rbx
    dec r13
5:  inc r14d
    add dword ptr [rsp + 4], 20
    jmp 1b
9:  EPILOGUE
canvas_graph_timeline:
    PROLOGUE 16
    mov rbx, rdi
    mov r12, rsi
    mov edi, [rbx + SC_x]
    add edi, 8
    mov esi, [rbx + SC_y]
    lea edx, [rdi + 1]
    mov edx, [rbx + SC_w]
    sub edx, 16
    lea rcx, [rip + .Lcontrols]
    cmp dword ptr [r12 + GR_profile], 1
    jne .Ltimeline_regular_controls
    lea rcx, [rip + .Lmemory_controls]
.Ltimeline_regular_controls:
    mov r8d, 1
    mov r9d, 0xff8992a3
    call canvas_graph_text
    mov eax, [r12 + GR_event]
    imul rax, EV_SIZE
    add rax, [r12 + GR_events + VEC_ptr]
    mov rcx, [rax + EV_label]
    mov edi, [rbx + SC_x]
    add edi, 8
    mov esi, [rbx + SC_y]
    add esi, [rbx + SC_h]
    sub esi, 76
    mov edx, [rbx + SC_w]
    sub edx, 16
    mov r8d, 1
    mov r9d, 0xffd8dee9
    call canvas_graph_text
    cmp dword ptr [r12 + GR_profile], 1
    je 9f
    xor r13d, r13d
1:  cmp r13, [r12 + GR_events + VEC_len]
    jae 9f
    cmp r13d, 16
    jae 9f
    mov eax, r13d
    imul eax, 36
    add eax, [rbx + SC_x]
    add eax, 8
    mov [rsp], eax
    mov eax, [rbx + SC_y]
    add eax, [rbx + SC_h]
    sub eax, 45
    mov [rsp + 4], eax
    mov edi, [rsp]
    mov esi, eax
    mov edx, 30
    mov ecx, 28
    call ui_in
    test eax, eax
    jz 2f
    test dword ptr [rip + g_pressed], 1 << BTN_LEFT
    jz 2f
    mov [r12 + GR_event], r13d
    mov dword ptr [rip + g_dirty], 1
2:  mov edi, [rsp]
    mov esi, [rsp + 4]
    mov edx, 30
    mov ecx, 28
    mov r8d, 0xff252a33
    cmp r13d, [r12 + GR_event]
    jne 3f
    mov r8d, 0xff35405b
3:  call gfx_fill
    lea eax, [r13 + '1']
    mov [rsp + 8], al
    mov byte ptr [rsp + 9], 0
    lea rdi, [rip + g_face_ui]
    mov esi, [rsp]
    add esi, 10
    mov edx, [rsp + 4]
    mov ecx, 28
    lea r8, [rsp + 8]
    mov r9d, 0xff8da4ff
    call ui_text_c
    inc r13
    jmp 1b
9:  EPILOGUE
.section .rodata
.Lschema_label: .asciz "Schema v"
.Lstate_label: .asciz "\nState v"
.Lcontrols: .asciz "Demo trace | V: 2D/3D | F: fold | [ ]: events | middle-drag: orbit | wheel: zoom"
.text
FN canvas_graph_toolbar
    PROLOGUE
    mov rbx, rdi
    mov r12d, esi
    xor r13d, r13d
1:  cmp r13d, 4
    jae 9f
    imul r14d, r13d, 118
    add r14d, [rbx + SC_x]
    mov edi, 0x7d00
    add edi, r13d
    mov esi, r14d
    mov edx, r12d
    mov ecx, 116
    M r8d, MI_40
    call ui_btn
    test eax, UB_CLICK
    jz 2f
    lea rax, [rip + .Lgraph_actions]
    call [rax + r13*8]
2:  lea rdi, [rip + g_face_small]
    mov esi, r14d
    add esi, 6
    mov edx, r12d
    M ecx, MI_40
    lea rax, [rip + .Lgraph_labels]
    mov r8, [rax + r13*8]
    COLOR r9d, T_ACCENT
    call ui_text_c
    inc r13d
    jmp 1b
9:  EPILOGUE
canvas_graph_link_active:
    PROLOGUE 8
    mov rbx, rdi
    mov r12, rsi
    mov eax, [rbx + GR_event]
    imul r13, rax, EV_SIZE
    add r13, [rbx + GR_events + VEC_ptr]
    xor r14d, r14d
1:  cmp r14, [r12 + VE_sources + VEC_len]
    jae 8f
    mov rax, [r12 + VE_sources + VEC_ptr]
    mov eax, [rax + r14*4]
    imul rax, GE_SIZE
    add rax, [rbx + GR_edges + VEC_ptr]
    mov rax, [rax + GE_id]
    mov [rsp], rax
    xor r15d, r15d
2:  cmp r15, [r13 + EV_active + VEC_len]
    jae 3f
    mov rax, [r13 + EV_active + VEC_ptr]
    mov rsi, [rax + r15*8]
    mov rdi, [rsp]
    call strcmp_eq
    test eax, eax
    jnz 9f
    inc r15
    jmp 2b
3:  inc r14
    jmp 1b
8:  xor eax, eax
9:  EPILOGUE
.section .rodata
.Lmode_button: .asciz "2D / 3D"
.Lfold_button: .asciz "Fold / unfold"
.Lprev_button: .asciz "Previous event"
.Lnext_button: .asciz "Next event"
.p2align 3
.Lgraph_labels: .quad .Lmode_button,.Lfold_button,.Lprev_button,.Lnext_button
.Lgraph_actions: .quad cmd_canvas_graph_mode,cmd_canvas_graph_fold,cmd_canvas_graph_prev_event,cmd_canvas_graph_next_event

.section .rodata
.Lmemory_controls: .asciz "Memory snapshot | V: 2D/3D | F: fold | [ ]: snapshots | middle-drag: orbit"
.p2align 2
.Lmemory_node_colors: .long 0xff8da4ff,0xffffbc66,0xff78c88d,0xff78c88d,0xffffbc66
.Lmemory_link_colors: .long 0xff8da4ff,0xff78c88d,0xffffbc66,0xffe18b83,0xff8da4ff
