.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN canvas_active
    mov rax, [rip + g_file]
    test rax, rax
    jz 1f
    mov rax, [rax + DOC_canvas]
1:  ret
FN cmd_canvas_new
    PROLOGUE
    call doc_new
    mov rbx, rax
    lea rax, [rip + .Ldraft_name]
    mov [rbx + DOC_name], rax
    call scene_new
    mov [rbx + DOC_canvas], rax
    mov [rax + SC_doc], rbx
    mov rdi, rbx
    mov esi, TAB_CANVAS
    call app_add_tab
    EPILOGUE

# Canvas consumes ordinary typing; global modified shortcuts remain available.
FN canvas_key
    mov rax, [rip + g_file]
    mov rax, [rax + DOC_canvas]
    cmp qword ptr [rax + SC_graph_view], 0
    jne canvas_graph_key
    jmp canvas_edit_key

FN canvas_draw
    PROLOGUE 32
    mov [rsp], edi
    mov [rsp + 4], esi
    mov [rsp + 8], edx
    mov [rsp + 12], ecx
    call canvas_active
    mov rbx, rax
    test rbx, rbx
    jz 9f
    mov eax, [rsp]
    mov [rbx + SC_x], eax
    mov eax, [rsp + 4]
    add eax, [rip + g_mt + 4*MI_40]
    mov [rbx + SC_y], eax
    mov eax, [rsp + 8]
    mov [rbx + SC_w], eax
    mov eax, [rsp + 12]
    sub eax, [rip + g_mt + 4*MI_40]
    xor ecx, ecx
    test eax, eax
    cmovs eax, ecx
    mov [rbx + SC_h], eax
    mov ecx, [rsp + 12]
    COLOR r8d, T_BG
    call gfx_fill
    mov edi, [rsp]
    mov esi, [rsp + 4]
    mov edx, [rsp + 8]
    mov ecx, [rsp + 12]
    call gfx_clip_push
    mov rdi, rbx
    mov esi, [rsp + 4]
    call canvas_toolbar
    mov edi, [rbx + SC_x]
    mov esi, [rbx + SC_y]
    mov edx, [rbx + SC_w]
    mov ecx, [rbx + SC_h]
    call gfx_clip_push
    cmp qword ptr [rbx + SC_graph_view], 0
    je 104f
    mov rdi, rbx
    call canvas_graph_draw
    jmp 103f
104: mov rdi, rbx
    call canvas_view_input
    cmp dword ptr [rbx + SC_mode], 0
    jne 101f
    mov rdi, rbx
    call canvas_proposal_input
    test eax, eax
    jnz 101f
    mov rdi, rbx
    call canvas_edit_input
101:
    # World-aligned grid; bounded screen iteration at every zoom.
    mov r15d, [rbx + SC_zoom]
    imul r15d, 24
    shr r15d, 16
    mov rdi, rbx
    xor esi, esi
    xor edx, edx
    call scene_to_screen
    mov [rsp + 28], edx
    sub eax, [rbx + SC_x]
    cdq
    idiv r15d
    test edx, edx
    jns 11f
    add edx, r15d
11: mov r12d, [rbx + SC_x]
    add r12d, edx
1:  mov eax, [rbx + SC_x]
    add eax, [rbx + SC_w]
    cmp r12d, eax
    jge 3f
    mov eax, [rsp + 28]
    sub eax, [rbx + SC_y]
    cdq
    idiv r15d
    test edx, edx
    jns 12f
    add edx, r15d
12: mov r13d, [rbx + SC_y]
    add r13d, edx
2:  mov eax, [rbx + SC_y]
    add eax, [rbx + SC_h]
    cmp r13d, eax
    jge 21f
    mov edi, r12d
    mov esi, r13d
    mov edx, 1
    mov ecx, 1
    COLOR r8d, T_BORDER
    call gfx_fill
    add r13d, r15d
    jmp 2b
21: add r12d, r15d
    jmp 1b
3:  cmp dword ptr [rbx + SC_mode], 0
    je 102f
    mov rdi, rbx
    call canvas_ui_preview
    jmp 103f
102: xor r12d, r12d
4:  cmp r12, [rbx + SC_elements + VEC_len]
    jae 8f
    imul r14, r12, CE_SIZE
    add r14, [rbx + SC_elements + VEC_ptr]
    mov rdi, rbx
    mov rsi, [r14 + CE_frame]
    mov rdi, rbx
    call canvas_folded
    test eax, eax
    jnz 7f
    mov rdi, rbx
    mov rsi, r14
    call canvas_paint_element
    mov rdi, rbx
    mov rsi, r14
    call canvas_detail_summary
7:  inc r12
    jmp 4b
8:  mov rdi, rbx
    call canvas_overlays
    mov rdi, rbx
    call canvas_proposal_overlay
103: call gfx_clip_pop
    call gfx_clip_pop
9:  EPILOGUE

# Mid-button pan and pointer-anchored bounded zoom; never mutates scene content.
canvas_view_input:
    PROLOGUE
    mov rbx, rdi
    mov edi, [rbx + SC_x]
    mov esi, [rbx + SC_y]
    mov edx, [rbx + SC_w]
    mov ecx, [rbx + SC_h]
    call ui_in
    test eax, eax
    jz .Lview_drag
    mov eax, [rip + g_scroll_y]
    test eax, eax
    jz 3f
    mov rdi, rbx
    mov esi, [rip + g_mx]
    mov edx, [rip + g_my]
    call scene_to_world
    mov r12d, eax
    mov r13d, edx
    mov r14d, [rbx + SC_zoom]
    mov eax, r14d
    shr eax, 3
    cmp dword ptr [rip + g_scroll_y], 0
    jg 1f
    add r14d, eax
    jmp 2f
1:  sub r14d, eax
2:  cmp r14d, 16384
    jae 21f
    mov r14d, 16384
21: cmp r14d, 262144
    jbe 22f
    mov r14d, 262144
22: mov [rbx + SC_zoom], r14d
    mov rdi, rbx
    mov esi, [rip + g_mx]
    mov edx, [rip + g_my]
    call scene_to_world
    sub eax, r12d
    add [rbx + SC_pan_x], eax
    sub edx, r13d
    add [rbx + SC_pan_y], edx
3:  test dword ptr [rip + g_pressed], 1 << BTN_MIDDLE
    jz .Lview_drag
    mov dword ptr [rbx + SC_drag], 1
    mov eax, [rip + g_mx]
    mov [rbx + SC_drag_x], eax
    mov eax, [rip + g_my]
    mov [rbx + SC_drag_y], eax
    mov eax, [rbx + SC_pan_x]
    mov [rbx + SC_start_x], eax
    mov eax, [rbx + SC_pan_y]
    mov [rbx + SC_start_y], eax
.Lview_drag:
    cmp dword ptr [rbx + SC_drag], 1
    jne 9f
    test dword ptr [rip + g_mdown], 1 << BTN_MIDDLE
    jz 8f
    movsxd rax, dword ptr [rip + g_mx]
    movsxd rcx, dword ptr [rbx + SC_drag_x]
    sub rax, rcx
    shl rax, 16
    cqo
    mov ecx, [rbx + SC_zoom]
    idiv rcx
    add eax, [rbx + SC_start_x]
    mov [rbx + SC_pan_x], eax
    movsxd rax, dword ptr [rip + g_my]
    movsxd rcx, dword ptr [rbx + SC_drag_y]
    sub rax, rcx
    shl rax, 16
    cqo
    mov ecx, [rbx + SC_zoom]
    idiv rcx
    add eax, [rbx + SC_start_y]
    mov [rbx + SC_pan_y], eax
    jmp 9f
8:  mov dword ptr [rbx + SC_drag], 0
9:  EPILOGUE

# Accurate filled ellipse, scanline spans, clipped iteration; no external library.
FN canvas_ellipse
    PROLOGUE 32
    test edx, edx
    jle 9f
    test ecx, ecx
    jle 9f
    mov [rsp], edi
    mov [rsp + 4], esi
    mov [rsp + 8], edx
    mov [rsp + 12], ecx
    mov [rsp + 16], r8d
    xor ebx, ebx
    mov eax, [rip + g_cv + CV_cy0]
    sub eax, esi
    cmp eax, ebx
    cmovg ebx, eax
    mov r12d, [rip + g_cv + CV_cy1]
    sub r12d, esi
    cmp r12d, ecx
    cmovg r12d, ecx
1:  cmp ebx, r12d
    jge 9f
    cvtsi2ss xmm0, ebx
    mov eax, [rsp + 12]
    cvtsi2ss xmm1, eax
    mulss xmm1, [rip + .Lhalf]
    subss xmm0, xmm1
    divss xmm0, xmm1
    mulss xmm0, xmm0
    movss xmm1, [rip + .Lone]
    subss xmm1, xmm0
    xorps xmm0, xmm0
    maxss xmm1, xmm0
    sqrtss xmm1, xmm1
    mov eax, [rsp + 8]
    cvtsi2ss xmm0, eax
    mulss xmm0, [rip + .Lhalf]
    mulss xmm1, xmm0
    cvtss2si eax, xmm1
    lea edx, [rax + rax + 1]
    mov edi, [rsp]
    mov ecx, [rsp + 8]
    sar ecx, 1
    add edi, ecx
    sub edi, eax
    mov esi, [rsp + 4]
    add esi, ebx
    mov ecx, 1
    mov r8d, [rsp + 16]
    call gfx_fill
    inc ebx
    jmp 1b
9:  EPILOGUE
# Script diagnostics use live native state, independent of pixels.
FN canvas_dump
    PROLOGUE
    mov r12, rdi
    call canvas_active
    mov rbx, rax
    test rbx, rbx
    jz 9f
    mov rdi, r12
    lea rsi, [rip + .Ldump_elements]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, [rbx + SC_elements + VEC_len]
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Ldump_zoom]
    call sb_push_cstr
    mov rdi, r12
    mov esi, [rbx + SC_zoom]
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Ldump_pan]
    call sb_push_cstr
    mov rdi, r12
    movsxd rsi, dword ptr [rbx + SC_pan_x]
    call canvas_dump_int
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
    mov rdi, r12
    movsxd rsi, dword ptr [rbx + SC_pan_y]
    call canvas_dump_int
    mov rdi, r12
    lea rsi, [rip + .Ldump_size]
    call sb_push_cstr
    mov rdi, r12
    mov esi, [rbx + SC_w]
    call sb_push_u64
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
    mov rdi, r12
    mov esi, [rbx + SC_h]
    call sb_push_u64
    mov rdi, r12
    mov esi, 10
    call sb_push_byte
    mov rdi, rbx
    mov rsi, r12
    call scene_serialize
9:  EPILOGUE
FN canvas_dump_int
    test rsi, rsi
    jns sb_push_u64
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov esi, '-'
    call sb_push_byte
    mov rdi, rbx
    mov rsi, r12
    neg rsi
    call sb_push_u64
    EPILOGUE
.section .rodata
.Ldraft_name: .asciz "Draft"
.Lviewport_hint: .asciz ""
.Lhalf: .float 0.5
.Lone: .float 1.0

.Ldump_elements: .asciz "canvas elements="
.Ldump_zoom: .asciz " zoom="
.Ldump_pan: .asciz " pan="
.Ldump_size: .asciz " size="
