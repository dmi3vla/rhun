.include "rhun.inc"
.include "canvas/canvas.inc"
.include "canvas/graph.inc"
.text
# Camera projection -> xmm0/xmm1 logical XY, xmm2 depth, eax validity.
FN canvas_graph_perspective
    PROLOGUE 64
    mov rbx, rdi
    mov r12, rsi
    cmp dword ptr [rbx + GR_mode], 0
    je .Lflat
    mov edi, [rbx + GR_yaw]
    call canvas_sin
    cvtss2sd xmm0, xmm0
    movsd [rsp], xmm0
    mov edi, [rbx + GR_yaw]
    add edi, 90
    call canvas_sin
    cvtss2sd xmm0, xmm0
    movsd [rsp + 8], xmm0
    mov edi, [rbx + GR_pitch]
    call canvas_sin
    cvtss2sd xmm0, xmm0
    movsd [rsp + 16], xmm0
    mov edi, [rbx + GR_pitch]
    add edi, 90
    call canvas_sin
    cvtss2sd xmm0, xmm0
    movsd [rsp + 24], xmm0
    cvtsi2sd xmm0, dword ptr [r12]
    cvtsi2sd xmm1, dword ptr [r12 + 4]
    cvtsi2sd xmm2, dword ptr [r12 + 8]
    movapd xmm3, xmm0
    mulsd xmm3, [rsp + 8]
    movapd xmm4, xmm2
    mulsd xmm4, [rsp]
    addsd xmm3, xmm4
    mulsd xmm0, [rsp]
    mulsd xmm2, [rsp + 8]
    subsd xmm2, xmm0
    movapd xmm4, xmm1
    mulsd xmm4, [rsp + 24]
    movapd xmm5, xmm2
    mulsd xmm5, [rsp + 16]
    subsd xmm4, xmm5
    mulsd xmm1, [rsp + 16]
    mulsd xmm2, [rsp + 24]
    addsd xmm2, xmm1
    movapd xmm0, xmm3
    movapd xmm1, xmm4
    xorpd xmm3, xmm3
    subsd xmm3, xmm1
    movapd xmm1, xmm3
    movsd xmm3, [rip + .Ldistance]
    movapd xmm4, xmm3
    addsd xmm4, xmm2
    comisd xmm4, [rip + .Lnear]
    jbe .Lnear_clip
    divsd xmm3, xmm4
    mulsd xmm0, xmm3
    mulsd xmm1, xmm3
    mov eax, 1
    EPILOGUE
.Lflat:
    cvtsi2sd xmm0, dword ptr [r12]
    cvtsi2sd xmm1, dword ptr [r12 + 4]
    xorpd xmm3, xmm3
    subsd xmm3, xmm1
    movapd xmm1, xmm3
    xorpd xmm2, xmm2
    mov eax, 1
    EPILOGUE
.Lnear_clip:
    xor eax, eax
    EPILOGUE

FN canvas_graph_visible_find
    mov rcx, [rdi + GR_visible + VEC_len]
    mov rax, [rdi + GR_visible + VEC_ptr]
1:  test rcx, rcx
    jz 2f
    cmp [rax + VP_id], esi
    je 3f
    add rax, VP_SIZE
    dec rcx
    jmp 1b
2:  xor eax, eax
3:  ret
FN canvas_graph_map
    mov eax, esi
    dec eax
    imul rax, GN_SIZE
    add rax, [rdi + GR_nodes + VEC_ptr]
    mov ecx, [rax + GN_segment]
    mov eax, esi
    test ecx, ecx
    jz 9f
    bt dword ptr [rdi + GR_fold], ecx
    jnc 9f
    lea eax, [rcx + 256]
9:  ret

FN canvas_graph_projection
    PROLOGUE 48
    mov rbx, rdi
    call canvas_graph_projection_free
    xor r12d, r12d
.Lvisible_nodes:
    cmp r12, [rbx + GR_nodes + VEC_len]
    jae .Lvisible_segments
    imul r13, r12, GN_SIZE
    add r13, [rbx + GR_nodes + VEC_ptr]
    mov ecx, [r13 + GN_segment]
    test ecx, ecx
    jz 1f
    bt dword ptr [rbx + GR_fold], ecx
    jc 3f
1:  lea rdi, [rbx + GR_visible]
    mov esi, VP_SIZE
    call vec_push
    mov r14, rax
    mov rdi, rax
    xor esi, esi
    mov edx, VP_SIZE
    call memset
    lea eax, [r12 + 1]
    mov [r14 + VP_id], eax
    mov eax, [r13 + GN_segment]
    mov [r14 + VP_segment], eax
    mov rax, [r13 + GN_name]
    mov [r14 + VP_name], rax
    mov eax, [r13 + GN_kind]
    mov [r14 + VP_kind], eax
    mov eax, [r13 + GN_realm]
    mov [r14 + VP_realm], eax
    mov rdi, rbx
    lea rsi, [r13 + GN_position]
    call canvas_graph_perspective
    test eax, eax
    jz 2f
    movsd [r14 + VP_rx], xmm0
    movsd [r14 + VP_ry], xmm1
    movsd [r14 + VP_z], xmm2
    jmp 3f
2:  dec qword ptr [rbx + GR_visible + VEC_len]
3:  inc r12
    jmp .Lvisible_nodes
.Lvisible_segments:
    xor r12d, r12d
1:  cmp r12, [rbx + GR_segments + VEC_len]
    jae .Lprojection_bounds
    imul r13, r12, GS_SIZE
    add r13, [rbx + GR_segments + VEC_ptr]
    mov ecx, [r13 + GS_id]
    bt dword ptr [rbx + GR_fold], ecx
    jnc 3f
    lea rdi, [rbx + GR_visible]
    mov esi, VP_SIZE
    call vec_push
    mov r14, rax
    mov rdi, rax
    xor esi, esi
    mov edx, VP_SIZE
    call memset
    mov eax, [r13 + GS_id]
    mov [r14 + VP_segment], eax
    add eax, 256
    mov [r14 + VP_id], eax
    mov rax, [r13 + GS_name]
    mov [r14 + VP_name], rax
    mov dword ptr [r14 + VP_kind], 3
    mov dword ptr [r14 + VP_realm], -1
    mov rdi, rbx
    lea rsi, [r13 + GS_center]
    call canvas_graph_perspective
    test eax, eax
    jz 2f
    movsd [r14 + VP_rx], xmm0
    movsd [r14 + VP_ry], xmm1
    movsd [r14 + VP_z], xmm2
    jmp 3f
2:  dec qword ptr [rbx + GR_visible + VEC_len]
3:  inc r12
    jmp 1b
.Lprojection_bounds:
    movsd xmm0, [rip + .Lmin_default]
    movsd [rsp], xmm0
    movsd [rsp + 8], xmm0
    movsd xmm0, [rip + .Lmax_default]
    movsd [rsp + 16], xmm0
    movsd [rsp + 24], xmm0
    xor r12d, r12d
1:  cmp r12, [rbx + GR_visible + VEC_len]
    jae .Lprojection_scale
    imul rax, r12, VP_SIZE
    add rax, [rbx + GR_visible + VEC_ptr]
    movsd xmm0, [rax + VP_rx]
    movsd xmm1, [rax + VP_ry]
    movsd xmm2, [rsp]
    minsd xmm2, xmm0
    movsd [rsp], xmm2
    movsd xmm2, [rsp + 16]
    maxsd xmm2, xmm0
    movsd [rsp + 16], xmm2
    movsd xmm2, [rsp + 8]
    minsd xmm2, xmm1
    movsd [rsp + 8], xmm2
    movsd xmm2, [rsp + 24]
    maxsd xmm2, xmm1
    movsd [rsp + 24], xmm2
    inc r12
    jmp 1b
.Lprojection_scale:
    movsd xmm0, [rsp + 16]
    addsd xmm0, [rsp]
    mulsd xmm0, [rip + .Lhalf]
    movsd [rbx + GR_mid_x], xmm0
    movsd xmm0, [rsp + 24]
    addsd xmm0, [rsp + 8]
    mulsd xmm0, [rip + .Lhalf]
    movsd [rbx + GR_mid_y], xmm0
    mov eax, [rbx + GR_view_w]
    sub eax, 80
    cmp eax, 1
    jge 1f
    mov eax, 1
1:  cvtsi2sd xmm0, eax
    movsd xmm1, [rsp + 16]
    subsd xmm1, [rsp]
    divsd xmm0, xmm1
    mov eax, [rbx + GR_view_h]
    sub eax, 70
    cmp eax, 1
    jge 2f
    mov eax, 1
2:  cvtsi2sd xmm2, eax
    movsd xmm1, [rsp + 24]
    subsd xmm1, [rsp + 8]
    divsd xmm2, xmm1
    minsd xmm0, xmm2
    cvtsi2sd xmm1, dword ptr [rbx + GR_zoom]
    divsd xmm1, [rip + .Lzoom_unit]
    mulsd xmm0, xmm1
    movsd [rbx + GR_scale], xmm0
    xor r12d, r12d
3:  cmp r12, [rbx + GR_visible + VEC_len]
    jae .Ldepth_sort
    imul r13, r12, VP_SIZE
    add r13, [rbx + GR_visible + VEC_ptr]
    movsd xmm0, [r13 + VP_rx]
    movsd xmm1, [r13 + VP_ry]
    mov rdi, rbx
    call canvas_graph_screen
    mov [r13 + VP_x], eax
    mov [r13 + VP_y], edx
    inc r12
    jmp 3b
.Ldepth_sort:
    mov r12d, 1
1:  cmp r12, [rbx + GR_visible + VEC_len]
    jae .Lvisible_edges
    mov r13, r12
2:  test r13, r13
    jz 4f
    imul r14, r13, VP_SIZE
    add r14, [rbx + GR_visible + VEC_ptr]
    lea r15, [r14 - VP_SIZE]
    movsd xmm0, [r14 + VP_z]
    comisd xmm0, [r15 + VP_z]
    jbe 4f
    xor ecx, ecx
3:  mov eax, [r14 + rcx]
    mov edx, [r15 + rcx]
    mov [r14 + rcx], edx
    mov [r15 + rcx], eax
    add ecx, 4
    cmp ecx, VP_SIZE
    jb 3b
    dec r13
    jmp 2b
4:  inc r12
    jmp 1b
.Lvisible_edges:
    xor r12d, r12d
1:  cmp r12, [rbx + GR_edges + VEC_len]
    jae 9f
    imul r13, r12, GE_SIZE
    add r13, [rbx + GR_edges + VEC_ptr]
    mov rdi, rbx
    mov esi, [r13 + GE_a]
    call canvas_graph_map
    mov [rsp], eax
    mov rdi, rbx
    mov esi, [r13 + GE_b]
    call canvas_graph_map
    mov [rsp + 4], eax
    cmp eax, [rsp]
    je 8f
    mov rdi, rbx
    mov esi, eax
    call canvas_graph_visible_find
    test rax, rax
    jz 8f
    mov rdi, rbx
    mov esi, [rsp]
    call canvas_graph_visible_find
    test rax, rax
    jz 8f
    xor r14d, r14d
2:  cmp r14, [rbx + GR_links + VEC_len]
    jae 4f
    imul r15, r14, VE_SIZE
    add r15, [rbx + GR_links + VEC_ptr]
    mov eax, [rsp]
    cmp eax, [r15 + VE_a]
    jne 3f
    mov eax, [rsp + 4]
    cmp eax, [r15 + VE_b]
    jne 3f
    mov eax, [r13 + GE_kind]
    cmp eax, [r15 + VE_kind]
    je 5f
3:  inc r14
    jmp 2b
4:  lea rdi, [rbx + GR_links]
    mov esi, VE_SIZE
    call vec_push
    mov r15, rax
    mov rdi, rax
    xor esi, esi
    mov edx, VE_SIZE
    call memset
    mov eax, [rsp]
    mov [r15 + VE_a], eax
    mov eax, [rsp + 4]
    mov [r15 + VE_b], eax
    mov eax, [r13 + GE_kind]
    mov [r15 + VE_kind], eax
5:  lea rdi, [r15 + VE_sources]
    mov esi, 4
    call vec_push
    mov [rax], r12d
8:  inc r12
    jmp 1b
9:  EPILOGUE
FN canvas_graph_screen
    subsd xmm0, [rdi + GR_mid_x]
    subsd xmm1, [rdi + GR_mid_y]
    mulsd xmm0, [rdi + GR_scale]
    mulsd xmm1, [rdi + GR_scale]
    mov eax, [rdi + GR_view_w]
    sar eax, 1
    add eax, [rdi + GR_view_x]
    cvtsi2sd xmm2, eax
    addsd xmm0, xmm2
    mov eax, [rdi + GR_view_h]
    sar eax, 1
    add eax, [rdi + GR_view_y]
    cvtsi2sd xmm2, eax
    addsd xmm1, xmm2
    cvtsd2si eax, xmm0
    cvtsd2si edx, xmm1
    ret
.section .rodata
.p2align 3
.Ldistance: .double 950.0
.Lnear: .double 32.0
.Lmin_default: .double -350.0
.Lmax_default: .double 350.0
.Lhalf: .double 0.5
.Lzoom_unit: .double 65536.0
