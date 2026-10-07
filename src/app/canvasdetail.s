.include "rhun.inc"
.include "canvas/canvas.inc"
.text
# Collapse is a derived view; original members, bindings and IDs stay untouched.
FN canvas_folded
    mov rcx, [rdi + SC_fold + VEC_len]
    mov rax, [rdi + SC_fold + VEC_ptr]
1:  test rcx, rcx
    jz 8f
    cmp [rax], rsi
    je 9f
    add rax, 8
    dec rcx
    jmp 1b
8:  xor eax, eax
    ret
9:  mov eax, 1
    ret
FN cmd_canvas_detail_toggle
    PROLOGUE
    call canvas_active
    mov rbx, rax
    test rax, rax
    jz 9f
    mov rdi, rax
    mov rsi, [rax + SC_selected]
    call scene_find
    test rax, rax
    jz 9f
    cmp dword ptr [rax + CE_kind], CT_FRAME
    jne 9f
    mov r12, [rax + CE_id]
    xor r13d, r13d
1:  cmp r13, [rbx + SC_fold + VEC_len]
    jae 3f
    mov rax, [rbx + SC_fold + VEC_ptr]
    cmp [rax + r13*8], r12
    je 2f
    inc r13
    jmp 1b
2:  dec qword ptr [rbx + SC_fold + VEC_len]
    mov rcx, [rbx + SC_fold + VEC_len]
    mov rcx, [rax + rcx*8]
    mov [rax + r13*8], rcx
    jmp 9f
3:  lea rdi, [rbx + SC_fold]
    mov esi, 8
    call vec_push
    mov [rax], r12
9:  mov dword ptr [rip + g_dirty], 1
    EPILOGUE
FN cmd_canvas_progress_todo
    xor edi, edi
    jmp canvas_progress_set
FN cmd_canvas_progress_done
    mov edi, 1
    jmp canvas_progress_set
FN cmd_canvas_progress_blocked
    mov edi, 2
    jmp canvas_progress_set
canvas_progress_set:
    PROLOGUE
    mov r15d, edi
    call canvas_active
    mov rbx, rax
    test rax, rax
    jz 9f
    cmp qword ptr [rbx + SC_before], 0
    jne 9f
    mov rdi, rbx
    call scene_clone
    mov r12, rax
    xor r13d, r13d
1:  cmp r13, [rbx + SC_elements + VEC_len]
    jae 8f
    imul rax, r13, CE_SIZE
    add rax, [rbx + SC_elements + VEC_ptr]
    test dword ptr [rax + CE_flags], 1
    jz 2f
    mov [rax + CE_reserved], r15d
2:  inc r13
    jmp 1b
8:  mov rdi, rbx
    mov rsi, r12
    call scene_commit
9:  EPILOGUE

FN canvas_detail_summary
    PROLOGUE SB_SIZE+16
    mov rbx, rdi
    mov r12, rsi
    cmp dword ptr [r12 + CE_kind], CT_FRAME
    jne 9f
    mov rsi, [r12 + CE_id]
    call canvas_folded
    test eax, eax
    jz 9f
    mov dword ptr [rsp + SB_SIZE], 0
    mov dword ptr [rsp + SB_SIZE + 4], 0
    mov dword ptr [rsp + SB_SIZE + 8], 0
    xor r13d, r13d
1:  cmp r13, [rbx + SC_elements + VEC_len]
    jae 3f
    imul rax, r13, CE_SIZE
    add rax, [rbx + SC_elements + VEC_ptr]
    mov rcx, [r12 + CE_id]
    cmp [rax + CE_frame], rcx
    jne 2f
    cmp qword ptr [rax + CE_role], 1
    jne 2f
    inc dword ptr [rsp + SB_SIZE]
    cmp dword ptr [rax + CE_reserved], 1
    jne 11f
    inc dword ptr [rsp + SB_SIZE + 4]
11: cmp dword ptr [rax + CE_reserved], 2
    jne 2f
    inc dword ptr [rsp + SB_SIZE + 8]
2:  inc r13
    jmp 1b
3:  mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rsp
    lea rsi, [rip + .Lsteps]
    call sb_push_cstr
    mov rdi, rsp
    mov esi, [rsp + SB_SIZE + 4]
    call sb_push_u64
    mov rdi, rsp
    mov esi, '/'
    call sb_push_byte
    mov rdi, rsp
    mov esi, [rsp + SB_SIZE]
    call sb_push_u64
    mov rdi, rsp
    lea rsi, [rip + .Lblocked]
    call sb_push_cstr
    mov rdi, rsp
    mov esi, [rsp + SB_SIZE + 8]
    call sb_push_u64
    mov rdi, rbx
    mov esi, [r12 + CE_x]
    mov edx, [r12 + CE_y]
    call scene_to_screen
    lea esi, [rax + 8]
    add edx, 8
    lea rdi, [rip + g_face_ui]
    mov ecx, 24
    mov r8, [rsp + SB_ptr]
    COLOR r9d, T_FG
    call ui_text_c
    mov rdi, rsp
    call sb_free
9:  EPILOGUE
.section .rodata
.Lsteps: .asciz "Steps done: "
.Lblocked: .asciz " | blocked: "
