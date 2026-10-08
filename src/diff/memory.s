.include "rhun.inc"
.include "canvas/canvas.inc"
.include "canvas/graph.inc"
.include "memory/memory.inc"
.include "diff/diff.inc"
.text
# MM, one-based source node index -> visible identity (same folded segment mapping).
FN diff_memory_visible_id
    mov rax, [rdi + MM_graph]
    lea ecx, [rsi - 1]
    imul rcx, GN_SIZE
    add rcx, [rax + GR_nodes + VEC_ptr]
    mov ecx, [rcx + GN_segment]
    bt dword ptr [rax + GR_fold], ecx
    jnc 1f
    lea esi, [rcx + 256]
1:  mov eax, esi
    ret
# scene, DF, base index, rectangle* -> existing native projected coordinates.
FN diff_memory_point
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx
    mov r14, rcx
    test r13d, r13d
    jz .Lnone
    mov rdi, rbx
    call memory_prepare
    mov r15, rax
    test rax, rax
    jz .Lnone
    mov rdi, rax
    call memory_build_graph
    mov rdi, r15
    mov esi, r13d
    call diff_memory_visible_id
    mov r13d, eax
    cmp dword ptr [r15 + MM_mode], 0
    jne .Lgraph
    mov rdi, r15
    call memory_build_scene
    mov r12, [r15 + MM_scene]
    mov rdi, r12
    mov esi, r13d
    call memory_view_find
    test rax, rax
    jz .Lnone
    mov r15, rax
    mov rdi, r12
    mov esi, [r15 + CE_x]
    mov edx, [r15 + CE_y]
    call scene_to_screen
    mov [r14], eax
    mov [r14 + 4], edx
    mov ecx, [r12 + SC_zoom]
    movsxd rax, dword ptr [r15 + CE_w]
    imul rax, rcx
    sar rax, 16
    mov [r14 + 8], eax
    movsxd rax, dword ptr [r15 + CE_h]
    imul rax, rcx
    sar rax, 16
    mov [r14 + 12], eax
    mov eax, 1
    EPILOGUE
.Lgraph:
    mov r12, [r15 + MM_graph]
    xor ecx, ecx
1:  cmp rcx, [r12 + GR_visible + VEC_len]
    jae .Lnone
    imul rax, rcx, VP_SIZE
    add rax, [r12 + GR_visible + VEC_ptr]
    cmp [rax + VP_id], r13d
    je 2f
    inc rcx
    jmp 1b
2:  mov ecx, [rax + VP_x]
    sub ecx, 18
    mov [r14], ecx
    mov ecx, [rax + VP_y]
    sub ecx, 18
    mov [r14 + 4], ecx
    mov dword ptr [r14 + 8], 36
    mov dword ptr [r14 + 12], 36
    mov eax, 1
    EPILOGUE
.Lnone: xor eax, eax
    EPILOGUE
# scene, source index -> select same visible source/summary, pan 2D if appropriate.
FN diff_memory_focus
    PROLOGUE
    mov rbx, rdi
    mov r12d, esi
    call memory_prepare
    mov r13, rax
    test rax, rax
    jz 9f
    mov rdi, rax
    call memory_build_graph
    mov rdi, r13
    mov esi, r12d
    call diff_memory_visible_id
    mov [r13 + MM_selected], eax
    cmp dword ptr [r13 + MM_mode], 0
    jne 9f
    mov r12d, eax
    mov rdi, r13
    call memory_build_scene
    mov r14, [r13 + MM_scene]
    mov rdi, r14
    mov esi, r12d
    call memory_view_find
    test rax, rax
    jz 9f
    mov ecx, 60
    sub ecx, [rax + CE_x]
    mov [r14 + SC_pan_x], ecx
    mov ecx, 100
    sub ecx, [rax + CE_y]
    mov [r14 + SC_pan_y], ecx
9:  EPILOGUE
