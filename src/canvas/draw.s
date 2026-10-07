.include "rhun.inc"
.include "canvas/canvas.inc"
.text
# Integer major-axis scan, bounded by clipping rectangle even for huge segments.
# canvas_line(x0,y0,x1,y1,color). No iteration proportional to off-screen distance.
FN canvas_line
    PROLOGUE 32
    mov [rsp], edi
    mov [rsp + 4], esi
    sub edx, edi
    sub ecx, esi
    mov [rsp + 8], edx
    mov [rsp + 12], ecx
    mov [rsp + 16], r8d
    mov eax, edx
    cdq
    xor eax, edx
    sub eax, edx
    mov r12d, eax
    mov eax, ecx
    cdq
    xor eax, edx
    sub eax, edx
    cmp r12d, eax
    jl .Lline_vertical
    cmp dword ptr [rsp + 8], 0
    je 9f
    mov ebx, [rsp]
    mov r12d, ebx
    add r12d, [rsp + 8]
    cmp ebx, r12d
    jle 1f
    xchg ebx, r12d
1:  cmp ebx, [rip + g_cv + CV_cx0]
    jge 2f
    mov ebx, [rip + g_cv + CV_cx0]
2:  cmp r12d, [rip + g_cv + CV_cx1]
    jl 3f
    mov r12d, [rip + g_cv + CV_cx1]
    dec r12d
3:  cmp ebx, r12d
    jg 9f
    movsxd rax, ebx
    movsxd rcx, dword ptr [rsp]
    sub rax, rcx
    movsxd rcx, dword ptr [rsp + 12]
    imul rax, rcx
    cqo
    movsxd rcx, dword ptr [rsp + 8]
    idiv rcx
    add eax, [rsp + 4]
    mov esi, eax
    mov edi, ebx
    mov edx, 2
    mov ecx, 2
    mov r8d, [rsp + 16]
    call gfx_fill
    inc ebx
    jmp 3b
.Lline_vertical:
    mov ebx, [rsp + 4]
    mov r12d, ebx
    add r12d, [rsp + 12]
    cmp ebx, r12d
    jle 4f
    xchg ebx, r12d
4:  cmp ebx, [rip + g_cv + CV_cy0]
    jge 5f
    mov ebx, [rip + g_cv + CV_cy0]
5:  cmp r12d, [rip + g_cv + CV_cy1]
    jl 6f
    mov r12d, [rip + g_cv + CV_cy1]
    dec r12d
6:  cmp ebx, r12d
    jg 9f
    movsxd rax, ebx
    movsxd rcx, dword ptr [rsp + 4]
    sub rax, rcx
    movsxd rcx, dword ptr [rsp + 8]
    imul rax, rcx
    cqo
    movsxd rcx, dword ptr [rsp + 12]
    idiv rcx
    add eax, [rsp]
    mov edi, eax
    mov esi, ebx
    mov edx, 2
    mov ecx, 2
    mov r8d, [rsp + 16]
    call gfx_fill
    inc ebx
    jmp 6b
9:  EPILOGUE

# canvas_element(scene, element). Preview offsets are applied only for selected items.
FN canvas_element
    PROLOGUE 48
    mov rbx, rdi
    mov r12, rsi
    mov esi, [r12 + CE_x]
    mov edx, [r12 + CE_y]
    test dword ptr [r12 + CE_flags], 1
    jz 1f
    cmp dword ptr [rbx + SC_gesture], 2
    jne 1f
    add esi, [rbx + SC_dx]
    add edx, [rbx + SC_dy]
1:  mov [rsp + 32], esi
    mov [rsp + 36], edx
    mov rdi, rbx
    call scene_to_screen
    mov [rsp], eax
    mov [rsp + 4], edx
    movsxd rax, dword ptr [r12 + CE_w]
    movsxd rcx, dword ptr [r12 + CE_h]
    test dword ptr [r12 + CE_flags], 1
    jz 11f
    cmp dword ptr [rbx + SC_gesture], 4
    jne 11f
    movsxd rdx, dword ptr [rbx + SC_dx]
    add rax, rdx
    movsxd rdx, dword ptr [rbx + SC_dy]
    add rcx, rdx
11: mov edx, [rbx + SC_zoom]
    imul rax, rdx
    sar rax, 16
    mov [rsp + 8], eax
    imul rcx, rdx
    sar rcx, 16
    mov [rsp + 12], ecx
    mov eax, [r12 + CE_kind]
    cmp eax, CT_IMAGE
    je .Ldraw_image
    cmp eax, CT_UNSUPPORTED
    je .Ldraw_placeholder
    cmp eax, CT_ARROW
    je .Ldraw_edge
    cmp eax, CT_LINE
    je .Ldraw_edge
    cmp eax, CT_STROKE
    je .Ldraw_stroke
    cmp eax, CT_TEXT
    je .Ldraw_text
    cmp dword ptr [r12 + CE_angle], 0
    jne .Ldraw_native_outline
    cmp dword ptr [r12 + CE_roughness], 0
    jne .Ldraw_native_outline
    # Normalize preview extents while keeping committed geometry untouched.
    cmp dword ptr [rsp + 8], 0
    jge 2f
    mov eax, [rsp + 8]
    add [rsp], eax
    neg dword ptr [rsp + 8]
2:  cmp dword ptr [rsp + 12], 0
    jge 3f
    mov eax, [rsp + 12]
    add [rsp + 4], eax
    neg dword ptr [rsp + 12]
3:  mov edi, [rsp]
    mov esi, [rsp + 4]
    mov edx, [rsp + 8]
    mov ecx, [rsp + 12]
    mov r8d, [r12 + CE_color]
    cmp dword ptr [r12 + CE_kind], CT_ELLIPSE
    jne 4f
    call canvas_ellipse
    jmp .Ldraw_role
4:  cmp dword ptr [r12 + CE_kind], CT_FRAME
    je .Ldraw_outline
    M r8d, MI_RADIUS
    mov r9d, [r12 + CE_color]
    COLOR eax, T_PANEL
    push rax
    push rax
    call gfx_frame
    add rsp, 16
    jmp .Ldraw_role
.Ldraw_native_outline:
    cmp dword ptr [r12 + CE_angle], 0
    jne 10f
    mov r8d, [r12 + CE_fill]
    test r8d, r8d
    jz 10f
    cmp dword ptr [r12 + CE_kind], CT_FRAME
    je 10f
    mov edi, [rsp]
    mov esi, [rsp + 4]
    mov edx, [rsp + 8]
    mov ecx, [rsp + 12]
    cmp dword ptr [r12 + CE_kind], CT_ELLIPSE
    jne 11f
    call canvas_ellipse
    jmp 10f
11: call gfx_fill
10: mov rdi, rbx
    mov rsi, r12
    call canvas_shape_outline
.Ldraw_role:
    mov rax, [r12 + CE_role]
    test rax, rax
    jz .Ldraw_selected
    cmp rax, 4
    ja .Ldraw_selected
    lea rcx, [rip + .Lroles]
    mov r8, [rcx + rax*8 - 8]
    lea rdi, [rip + g_face_small]
    mov esi, [rsp]
    add esi, 12
    mov edx, [rsp + 4]
    mov ecx, [rsp + 12]
    COLOR r9d, T_FG
    call ui_text_c
    jmp .Ldraw_selected
.Ldraw_image:
    mov rdi, rbx
    mov rsi, r12
    call canvas_paint_image
    test eax, eax
    jz .Ldraw_placeholder
    jmp .Ldraw_selected
.Ldraw_placeholder:
    mov rdi, rbx
    mov rsi, r12
    call canvas_shape_outline
    lea rdi, [rip + g_face_small]
    mov esi, [rsp]
    add esi, 4
    mov edx, [rsp + 4]
    mov ecx, 28
    lea r8, [rip + .Lunsupported_label]
    COLOR r9d, T_MUTED
    call ui_text_c
    jmp .Ldraw_selected
.Ldraw_text:
    mov r13, [r12 + CE_text]
    test r13, r13
    jz .Ldraw_selected
    xor r14d, r14d
    mov r15d, [r12 + CE_fontsize]
    imul r15d, [rbx + SC_zoom]
    shr r15d, 16
    cmp r15d, 8
    jae 5f
    mov r15d, 8
5:  mov eax, [rip + g_face_ui + FACE_ascent]
    add eax, [rip + g_face_ui + FACE_descent]
    add eax, 2
    cmp r15d, eax
    cmovl r15d, eax
    cmp byte ptr [r13], 0
    je .Ldraw_selected
    xor edx, edx
6:  cmp byte ptr [r13 + rdx], 0
    je 7f
    cmp byte ptr [r13 + rdx], 10
    je 7f
    inc rdx
    jmp 6b
7:  mov [rsp + 24], rdx
    lea rdi, [rip + g_face_ui]
    mov esi, [rsp]
    mov edx, [rsp + 4]
    add edx, r14d
    mov ecx, r15d
    mov r8, r13
    mov r9, [rsp + 24]
    COLOR eax, T_FG
    push rax
    push rax
    call ui_text_v
    add rsp, 16
    add r13, [rsp + 24]
    cmp byte ptr [r13], 0
    je .Ldraw_selected
    inc r13
    add r14d, r15d
    # Skip rendering lines outside viewport, but still parse bounded 64KiB text.
    mov eax, [rsp + 4]
    add eax, r14d
    cmp eax, [rip + g_cv + CV_cy1]
    jge .Ldraw_selected
    jmp 5b
.Ldraw_edge:
    cmp dword ptr [r12 + CE_kind], CT_ARROW
    jne .Ldraw_unbound_edge
    # Start/end center coordinates remain in IR; paint on the shape boundary.
    mov eax, [rsp]
    add eax, [rsp + 8]
    mov [rsp + 40], eax
    mov eax, [rsp + 4]
    add eax, [rsp + 12]
    mov [rsp + 44], eax
    mov rsi, [r12 + CE_to]
    test rsi, rsi
    jz 71f
    mov rdi, rbx
    mov edx, [rsp]
    mov ecx, [rsp + 4]
    call canvas_bound_point
    test ecx, ecx
    jz 71f
    mov [rsp + 40], eax
    mov [rsp + 44], edx
71: mov rsi, [r12 + CE_from]
    test rsi, rsi
    jz 72f
    mov rdi, rbx
    mov edx, [rsp + 40]
    mov ecx, [rsp + 44]
    call canvas_bound_point
    test ecx, ecx
    jz 72f
    mov [rsp], eax
    mov [rsp + 4], edx
72: mov eax, [rsp + 40]
    sub eax, [rsp]
    mov [rsp + 8], eax
    mov eax, [rsp + 44]
    sub eax, [rsp + 4]
    mov [rsp + 12], eax
.Ldraw_unbound_edge:
    mov edi, [rsp]
    mov esi, [rsp + 4]
    mov edx, edi
    add edx, [rsp + 8]
    mov ecx, esi
    add ecx, [rsp + 12]
    mov r8d, [r12 + CE_color]
    call canvas_line
    cmp dword ptr [r12 + CE_kind], CT_ARROW
    jne .Ldraw_selected
    # Screen-sized arrowhead, normalized by its major axis.
    mov eax, [rsp + 8]
    cdq
    xor eax, edx
    sub eax, edx
    mov r13d, eax
    mov eax, [rsp + 12]
    cdq
    xor eax, edx
    sub eax, edx
    cmp r13d, eax
    cmovl r13d, eax
    test r13d, r13d
    jz .Ldraw_selected
    xor r14d, r14d
8:  mov eax, [rsp + 8]
    mov ecx, [rsp + 12]
    test r14d, r14d
    jnz 81f
    add eax, ecx
    jmp 82f
81: sub eax, ecx
82: imul eax, 10
    cdq
    idiv r13d
    mov edi, [rsp]
    add edi, [rsp + 8]
    mov edx, edi
    sub edx, eax
    mov [rsp + 24], edx
    mov eax, [rsp + 12]
    test r14d, r14d
    jnz 83f
    sub eax, [rsp + 8]
    jmp 84f
83: add eax, [rsp + 8]
84: imul eax, 10
    cdq
    idiv r13d
    mov esi, [rsp + 4]
    add esi, [rsp + 12]
    mov ecx, esi
    sub ecx, eax
    mov edx, [rsp + 24]
    mov r8d, [r12 + CE_color]
    call canvas_line
    inc r14d
    cmp r14d, 2
    jb 8b
    jmp .Ldraw_selected
.Ldraw_stroke:
    xor r13d, r13d
1:  lea rax, [r13 + 1]
    cmp rax, [r12 + CE_points + VEC_len]
    jae .Ldraw_selected
    mov r14, [r12 + CE_points + VEC_ptr]
    lea r14, [r14 + r13*8]
    mov rdi, rbx
    mov esi, [r14]
    add esi, [rsp + 32]
    mov edx, [r14 + 4]
    add edx, [rsp + 36]
    call scene_to_screen
    mov [rsp + 16], eax
    mov [rsp + 20], edx
    mov rdi, rbx
    mov esi, [r14 + 8]
    add esi, [rsp + 32]
    mov edx, [r14 + 12]
    add edx, [rsp + 36]
    call scene_to_screen
    mov ecx, edx
    mov edx, eax
    mov edi, [rsp + 16]
    mov esi, [rsp + 20]
    mov r8d, [r12 + CE_color]
    call canvas_line
    inc r13d
    jmp 1b
.Ldraw_selected:
    test dword ptr [r12 + CE_flags], 1
    jz 9f
.Ldraw_outline:
    mov edi, [rsp]
    mov esi, [rsp + 4]
    mov edx, [rsp + 8]
    mov ecx, 2
    mov r8d, [r12 + CE_color]
    call gfx_fill
    mov edi, [rsp]
    mov esi, [rsp + 4]
    add esi, [rsp + 12]
    mov edx, [rsp + 8]
    mov ecx, 2
    mov r8d, [r12 + CE_color]
    call gfx_fill
    mov edi, [rsp]
    mov esi, [rsp + 4]
    mov edx, 2
    mov ecx, [rsp + 12]
    mov r8d, [r12 + CE_color]
    call gfx_fill
    mov edi, [rsp]
    add edi, [rsp + 8]
    mov esi, [rsp + 4]
    mov edx, 2
    mov ecx, [rsp + 12]
    mov r8d, [r12 + CE_color]
    call gfx_fill
    test dword ptr [r12 + CE_flags], 1
    jz 9f
    mov edi, [rsp]
    add edi, [rsp + 8]
    sub edi, 3
    mov esi, [rsp + 4]
    add esi, [rsp + 12]
    sub esi, 3
    mov edx, 7
    mov ecx, 7
    COLOR r8d, T_FG
    call gfx_fill
9:  EPILOGUE
.section .rodata
.Lrole_step: .asciz "Шаг"
.Lrole_question: .asciz "Вопрос"
.Lrole_decision: .asciz "Решение"
.Lrole_constraint: .asciz "Ограничение"
.p2align 3
.Lroles: .quad .Lrole_step, .Lrole_question, .Lrole_decision, .Lrole_constraint
.text
# Endpoint at the target shape's boundary, toward a supplied screen point.
# scene, ID, other screen x/y -> eax/edx boundary; ecx success.
FN canvas_bound_point
    PROLOGUE 32
    mov rbx, rdi
    mov [rsp], edx
    mov [rsp + 4], ecx
    call scene_find
    test rax, rax
    jz 9f
    mov r12, rax
    mov esi, [rax + CE_w]
    sar esi, 1
    add esi, [rax + CE_x]
    mov edx, [rax + CE_h]
    sar edx, 1
    add edx, [rax + CE_y]
    test dword ptr [rax + CE_flags], 1
    jz 1f
    cmp dword ptr [rbx + SC_gesture], 2
    jne 1f
    add esi, [rbx + SC_dx]
    add edx, [rbx + SC_dy]
1:  mov rdi, rbx
    call scene_to_screen
    mov [rsp + 8], eax
    mov [rsp + 12], edx
    mov ecx, [rsp]
    sub ecx, eax
    cvtsi2ss xmm0, ecx
    mov ecx, [rsp + 4]
    sub ecx, edx
    cvtsi2ss xmm1, ecx
    cvtsi2ss xmm2, dword ptr [r12 + CE_w]
    cvtsi2ss xmm3, dword ptr [r12 + CE_h]
    cvtsi2ss xmm4, dword ptr [rbx + SC_zoom]
    divss xmm4, [rip + .Lfixed_half]
    mulss xmm2, xmm4
    mulss xmm3, xmm4
    xorps xmm5, xmm5
    comiss xmm2, xmm5
    jbe 8f
    comiss xmm3, xmm5
    jbe 8f
    movaps xmm4, xmm0
    divss xmm4, xmm2
    movaps xmm5, xmm1
    divss xmm5, xmm3
    cmp dword ptr [r12 + CE_kind], CT_ELLIPSE
    jne 2f
    mulss xmm4, xmm4
    mulss xmm5, xmm5
    addss xmm4, xmm5
    sqrtss xmm4, xmm4
    jmp 3f
2:  andps xmm4, [rip + .Labs_mask]
    andps xmm5, [rip + .Labs_mask]
    maxss xmm4, xmm5
3:  xorps xmm5, xmm5
    comiss xmm4, xmm5
    jbe 8f
    divss xmm0, xmm4
    divss xmm1, xmm4
    cvtss2si eax, xmm0
    add eax, [rsp + 8]
    cvtss2si edx, xmm1
    add edx, [rsp + 12]
    mov ecx, 1
    EPILOGUE
8:  mov eax, [rsp + 8]
    mov edx, [rsp + 12]
    mov ecx, 1
    EPILOGUE
9:  xor ecx, ecx
    EPILOGUE
.section .rodata
.Lfixed_half: .float 131072.0
.p2align 4
.Labs_mask: .long 0x7fffffff, 0x7fffffff, 0x7fffffff, 0x7fffffff
.text
# Clip a frame member using the document's world transform, then restore target.
FN canvas_paint_element
    PROLOGUE 16
    mov rbx, rdi
    mov r12, rsi
    mov rsi, [r12 + CE_frame]
    test rsi, rsi
    jz 8f
    mov rdi, rbx
    call scene_find
    test rax, rax
    jz 8f
    mov r13, rax
    mov esi, [rax + CE_x]
    mov edx, [rax + CE_y]
    test dword ptr [rax + CE_flags], 1
    jz 1f
    cmp dword ptr [rbx + SC_gesture], 2
    jne 1f
    add esi, [rbx + SC_dx]
    add edx, [rbx + SC_dy]
1:  mov rdi, rbx
    call scene_to_screen
    mov edi, eax
    mov esi, edx
    movsxd rax, dword ptr [r13 + CE_w]
    mov ecx, [rbx + SC_zoom]
    imul rax, rcx
    sar rax, 16
    mov edx, eax
    movsxd rax, dword ptr [r13 + CE_h]
    imul rax, rcx
    sar rax, 16
    mov ecx, eax
    call gfx_clip_push
    mov rdi, rbx
    mov rsi, r12
    call canvas_element
    call gfx_clip_pop
    EPILOGUE
8:  mov rdi, rbx
    mov rsi, r12
    call canvas_element
    EPILOGUE

.section .rodata
.Lunsupported_label: .asciz "[unsupported]"
