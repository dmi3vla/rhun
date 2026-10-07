# Scene-level group/frame/z-order operations, each one content transaction.
.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN cmd_canvas_group
    mov edi, 1
    jmp canvas_structure
FN cmd_canvas_ungroup
    mov edi, 2
    jmp canvas_structure
FN cmd_canvas_raise
    mov edi, 3
    jmp canvas_structure
FN cmd_canvas_lower
    mov edi, 4
    jmp canvas_structure
FN cmd_canvas_rotate
    mov edi, 5
    jmp canvas_structure
FN cmd_canvas_sketch
    mov edi, 6
    jmp canvas_structure
FN cmd_canvas_frame_members
    mov edi, 7
    jmp canvas_structure
FN cmd_canvas_select_frame
    PROLOGUE
    call canvas_active
    test rax, rax
    jz 9f
    mov rbx, rax
    mov rdi, rax
    mov rsi, [rax + SC_selected]
    call scene_find
    test rax, rax
    jz 9f
    cmp dword ptr [rax + CE_kind], CT_FRAME
    jne 9f
    mov rsi, [rax + CE_id]
    mov rcx, [rbx + SC_elements + VEC_len]
    mov rax, [rbx + SC_elements + VEC_ptr]
1:  test rcx, rcx
    jz 9f
    cmp [rax + CE_frame], rsi
    jne 2f
    mov dword ptr [rax + CE_flags], 1
2:  add rax, CE_SIZE
    dec rcx
    jmp 1b
9:  mov dword ptr [rip + g_dirty], 1
    EPILOGUE

canvas_structure:
    PROLOGUE 32
    mov r15d, edi
    call canvas_active
    mov rbx, rax
    test rbx, rbx
    jz 9f
    cmp qword ptr [rbx + SC_before], 0
    jne 9f
    mov rdi, rbx
    call scene_clone
    mov r12, rax
    mov [rsp + 24], rax
    xor r13d, r13d
    xor r14d, r14d
    cmp r15d, 3
    je .Lreorder
    cmp r15d, 4
    je .Lreorder
    cmp r15d, 7
    je .Lassign_frame
1:  cmp r13, [rbx + SC_elements + VEC_len]
    jae .Lstructure_commit
    imul rax, r13, CE_SIZE
    add rax, [rbx + SC_elements + VEC_ptr]
    test dword ptr [rax + CE_flags], 1
    jz 8f
    cmp r15d, 1
    jne 2f
    mov rcx, [rbx + SC_next_id]
    mov [rax + CE_group], rcx
    mov r12, rax
    mov rdi, [r12 + CE_gxid]
    call mem_free
    mov qword ptr [r12 + CE_gxid], 0
    jmp 7f
2:  cmp r15d, 2
    jne 3f
    mov qword ptr [rax + CE_group], 0
    mov r12, rax
    mov rdi, [r12 + CE_gxid]
    call mem_free
    mov qword ptr [r12 + CE_gxid], 0
    jmp 7f
3:  cmp r15d, 5
    jne 4f
    cmp dword ptr [rax + CE_kind], CT_RECT
    je 101f
    cmp dword ptr [rax + CE_kind], CT_ELLIPSE
    jne 8f
101:
    add dword ptr [rax + CE_angle], 15
    cmp dword ptr [rax + CE_angle], 180
    jle 7f
    sub dword ptr [rax + CE_angle], 360
    jmp 7f
4:  cmp qword ptr [rax + CE_seed], 0
    jne 5f
    mov ecx, [rax + CE_id]
    imul ecx, 1664525
    add ecx, 1013904223
    and ecx, 0x7fffffff
    mov [rax + CE_seed], rcx
    mov dword ptr [rax + CE_roughness], 1
    jmp 7f
5:  mov qword ptr [rax + CE_seed], 0
    mov dword ptr [rax + CE_roughness], 0
7:  mov r14d, 1
8:  inc r13
    jmp 1b
.Lassign_frame:
    mov rdi, rbx
    mov rsi, [rbx + SC_selected]
    call scene_find
    test rax, rax
    jz .Lstructure_cancel
    cmp dword ptr [rax + CE_kind], CT_FRAME
    jne .Lstructure_cancel
    mov [rsp], rax
1:  cmp r13, [rbx + SC_elements + VEC_len]
    jae .Lstructure_commit
    imul rax, r13, CE_SIZE
    add rax, [rbx + SC_elements + VEC_ptr]
    cmp dword ptr [rax + CE_kind], CT_FRAME
    je 8f
    mov rcx, [rsp]
    # Attach contained items, independent of selection; explicit command only.
    mov edx, [rax + CE_x]
    cmp edx, [rcx + CE_x]
    jl 8f
    add edx, [rax + CE_w]
    mov esi, [rcx + CE_x]
    add esi, [rcx + CE_w]
    cmp edx, esi
    jg 8f
    mov edx, [rax + CE_y]
    cmp edx, [rcx + CE_y]
    jl 8f
    add edx, [rax + CE_h]
    mov esi, [rcx + CE_y]
    add esi, [rcx + CE_h]
    cmp edx, esi
    jg 8f
    mov rcx, [rcx + CE_id]
    mov [rax + CE_frame], rcx
    mov r14d, 1
8:  inc r13
    jmp 1b
.Lreorder:
    mov rdi, rsp
    xor esi, esi
    mov edx, VEC_SIZE
    call memset
    xor r14d, r14d
1:  xor r13d, r13d
2:  cmp r13, [rbx + SC_elements + VEC_len]
    jae 4f
    imul r12, r13, CE_SIZE
    add r12, [rbx + SC_elements + VEC_ptr]
    mov eax, [r12 + CE_flags]
    and eax, 1
    cmp r15d, 3
    je 3f
    xor eax, 1
3:  cmp eax, r14d
    jne 31f
    mov rdi, rsp
    mov esi, CE_SIZE
    call vec_push
    mov rdi, rax
    mov rsi, r12
    mov edx, CE_SIZE
    call memcpy
31: inc r13
    jmp 2b
4:  inc r14d
    cmp r14d, 2
    jb 1b
    # The new vector takes ownership of copied element pointers.
    lea rdi, [rbx + SC_elements]
    call vec_free
    lea rdi, [rbx + SC_elements]
    mov rsi, rsp
    mov edx, VEC_SIZE
    call memcpy
    mov r14d, 1
.Lstructure_commit:
    test r14d, r14d
    jz .Lstructure_cancel
    cmp r15d, 1
    jne 1f
    inc qword ptr [rbx + SC_next_id]
1:  mov rdi, rbx
    mov rsi, [rsp + 24]
    call scene_commit
    jmp 9f
.Lstructure_cancel:
    mov rdi, [rsp + 24]
    call scene_free
9:  EPILOGUE

# Expand selection by one group and by selected frames; frames cannot nest in v1.
FN scene_expand_selection
    PROLOGUE
    mov rbx, rdi
    mov rdi, rbx
    mov rsi, [rbx + SC_selected]
    call scene_find
    test rax, rax
    jz 9f
    test dword ptr [rax + CE_flags], 1
    jz 9f
    mov r12, [rax + CE_group]
    mov r13, [rax + CE_id]
    cmp dword ptr [rax + CE_kind], CT_FRAME
    je 1f
    xor r13d, r13d
1:  mov rcx, [rbx + SC_elements + VEC_len]
    mov rax, [rbx + SC_elements + VEC_ptr]
2:  test rcx, rcx
    jz 9f
    test r12, r12
    jz 3f
    cmp [rax + CE_group], r12
    je 4f
3:  test r13, r13
    jz 5f
    cmp [rax + CE_frame], r13
    jne 5f
4:  mov dword ptr [rax + CE_flags], 1
5:  add rax, CE_SIZE
    dec rcx
    jmp 2b
9:  EPILOGUE
