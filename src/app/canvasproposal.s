.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN cmd_canvas_proposal_import
    lea rdi, [rip + .Lprompt]
    mov esi, 11
    jmp prompt_open
FN canvas_proposal_import
    PROLOGUE
    mov r12, rdi
    call canvas_active
    mov rbx, rax
    test rax, rax
    jz 9f
    cmp qword ptr [rbx + SC_before], 0
    jne 9f
    mov rdi, r12
    mov ecx, 1 << 20
    call file_read_limited
    test rax, rax
    jz 8f
    mov r12, rax
    mov rdi, rax
    mov rsi, rdx
    mov rdx, rbx
    call canvas_proposal_parse
    mov r13, rax
    mov rdi, r12
    call mem_free
    test r13, r13
    jz 8f
    mov rdi, [rbx + SC_proposal]
    call canvas_proposal_free
    mov [rbx + SC_proposal], r13
    mov qword ptr [rbx + SC_proposal_selected], 0
    mov dword ptr [rip + g_dirty], 1
    jmp 9f
8:  lea rdi, [rip + .Linvalid]
    call app_toast
9:  EPILOGUE
FN cmd_canvas_proposal_reject
    PROLOGUE
    call canvas_active
    test rax, rax
    jz 9f
    mov rbx, rax
    mov rdi, [rbx + SC_proposal]
    mov qword ptr [rbx + SC_proposal], 0
    call canvas_proposal_free
    mov dword ptr [rip + g_dirty], 1
9:  EPILOGUE
FN cmd_canvas_proposal_next
    PROLOGUE
    call canvas_active
    test rax, rax
    jz 9f
    mov rbx, rax
    mov r12, [rax + SC_proposal]
    test r12, r12
    jz 9f
    xor r13d, r13d
    xor r14d, r14d
1:  cmp r13, [r12 + CP_ops + VEC_len]
    jae 4f
    imul rax, r13, PO_SIZE
    add rax, [r12 + CP_ops + VEC_ptr]
    cmp dword ptr [rax + PO_kind], 3
    je 3f
    test r14, r14
    jnz 2f
    mov r14, [rax + PO_id]
2:  mov rcx, [rax + PO_id]
    cmp rcx, [rbx + SC_proposal_selected]
    je 5f
3:  inc r13
    jmp 1b
4:  mov [rbx + SC_proposal_selected], r14
    jmp 9f
5:  inc r13
    cmp r13, [r12 + CP_ops + VEC_len]
    jae 4b
    imul rax, r13, PO_SIZE
    add rax, [r12 + CP_ops + VEC_ptr]
    cmp dword ptr [rax + PO_kind], 3
    je 5b
    mov rax, [rax + PO_id]
    mov [rbx + SC_proposal_selected], rax
9:  mov dword ptr [rip + g_dirty], 1
    EPILOGUE
FN cmd_canvas_proposal_accept_all
    mov edi, 1
    jmp canvas_proposal_accept
FN cmd_canvas_proposal_accept_selected
    xor edi, edi
    jmp canvas_proposal_accept
canvas_proposal_accept:
    PROLOGUE
    mov r15d, edi
    call canvas_active
    mov rbx, rax
    test rax, rax
    jz 9f
    mov r12, [rax + SC_proposal]
    test r12, r12
    jz 9f
    mov rax, [r12 + CP_revision]
    cmp rax, [rbx + SC_revision]
    jne 8f
    cmp qword ptr [rbx + SC_before], 0
    jne 8f
    xor r13d, r13d
    xor r14d, r14d
1:  cmp r13, [r12 + CP_ops + VEC_len]
    jae 3f
    imul rax, r13, PO_SIZE
    add rax, [r12 + CP_ops + VEC_ptr]
    mov [rax + PO_selected], r15d
    test r15d, r15d
    jnz 2f
    mov rcx, [rbx + SC_proposal_selected]
    test rcx, rcx
    jz 21f
    cmp rcx, [rax + PO_id]
    jne 21f
    mov dword ptr [rax + PO_selected], 1
2:  inc r14d
21: inc r13
    jmp 1b
3:  test r14d, r14d
    jz 9f
    mov rdi, r12
    call canvas_proposal_closure
    mov rdi, rbx
    mov rsi, r12
    mov edx, 1
    call canvas_proposal_candidate
    mov r13, rax
    test rax, rax
    jz 8f
    mov rdi, rbx
    call scene_clone
    mov r14, rax
    mov rdi, rbx
    mov rsi, r13
    call canvas_scene_take
    mov rdi, rbx
    mov rsi, r14
    call scene_commit
    mov r15d, eax
    mov rdi, r13
    call scene_free
    test r15d, r15d
    jz 8f
    mov qword ptr [rbx + SC_proposal], 0
    mov rdi, r12
    call canvas_proposal_free
    jmp 9f
8:  lea rdi, [rip + .Linvalid]
    call app_toast
9:  EPILOGUE

# Transfer owned content only; keep live viewport/document/revision and ID watermark.
FN canvas_scene_take
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    call scene_clear_elements
    lea rdi, [rbx + SC_elements]
    lea rsi, [r12 + SC_elements]
    mov edx, VEC_SIZE
    call memcpy
    lea rdi, [r12 + SC_elements]
    xor esi, esi
    mov edx, VEC_SIZE
    call memset
    mov rdi, [rbx + SC_ui]
    call mem_free
    mov rax, [r12 + SC_ui]
    mov [rbx + SC_ui], rax
    mov qword ptr [r12 + SC_ui], 0
    mov rdi, [rbx + SC_exchange]
    call mem_free
    mov rax, [r12 + SC_exchange]
    mov [rbx + SC_exchange], rax
    mov qword ptr [r12 + SC_exchange], 0
    mov rax, [r12 + SC_next_id]
    cmp rax, [rbx + SC_next_id]
    jbe 9f
    mov [rbx + SC_next_id], rax
9:  EPILOGUE

FN canvas_proposal_closure
    PROLOGUE
    mov rbx, rdi
.Lclosure_repeat:
    xor r15d, r15d
    xor r12d, r12d
1:  cmp r12, [rbx + CP_ops + VEC_len]
    jae 8f
    imul r13, r12, PO_SIZE
    add r13, [rbx + CP_ops + VEC_ptr]
    cmp dword ptr [r13 + PO_selected], 0
    je 7f
    cmp dword ptr [r13 + PO_kind], 3
    jne 2f
    mov rcx, [rbx + CP_ops + VEC_len]
    mov rax, [rbx + CP_ops + VEC_ptr]
11: test rcx, rcx
    jz 9f
    mov dword ptr [rax + PO_selected], 1
    add rax, PO_SIZE
    dec rcx
    jmp 11b
2:  mov rdi, [rbx + CP_candidate]
    mov rsi, [r13 + PO_id]
    call scene_find
    test rax, rax
    jz 7f
    mov r13, rax
    mov r14d, CE_from
3:  mov rsi, [r13 + r14]
    test rsi, rsi
    jz 6f
    mov rdi, rbx
    call canvas_proposal_find
    test rax, rax
    jz 6f
    cmp dword ptr [rax + PO_kind], 0
    jne 6f
    cmp dword ptr [rax + PO_selected], 0
    jne 6f
    mov dword ptr [rax + PO_selected], 1
    mov r15d, 1
6:  add r14d, 8
    cmp r14d, CE_frame
    jbe 3b
7:  inc r12
    jmp 1b
8:  test r15d, r15d
    jnz .Lclosure_repeat
9:  EPILOGUE

FN canvas_proposal_overlay
    PROLOGUE CE_SIZE+8
    mov qword ptr [rsp + CE_SIZE], 0
    mov rbx, rdi
    mov r12, [rdi + SC_proposal]
    test r12, r12
    jz 9f
    mov rax, [r12 + CP_revision]
    cmp rax, [rbx + SC_revision]
    jne 9f
    call canvas_preview_capture
    mov [rsp + CE_SIZE], rax
    xor r13d, r13d
1:  cmp r13, [r12 + CP_ops + VEC_len]
    jae 9f
    imul rax, r13, PO_SIZE
    add rax, [r12 + CP_ops + VEC_ptr]
    cmp dword ptr [rax + PO_kind], 2
    jae 8f
    mov rsi, [rax + PO_id]
    mov rdi, [r12 + CP_candidate]
    call scene_find
    test rax, rax
    jz 8f
    mov rdi, rsp
    mov rsi, rax
    mov edx, CE_SIZE
    call memcpy
    mov dword ptr [rsp + CE_color], 0xff7081a3
    mov dword ptr [rsp + CE_flags], 0
    mov rax, [rsp + CE_id]
    cmp rax, [rbx + SC_proposal_selected]
    jne 2f
    mov dword ptr [rsp + CE_flags], 1
2:  mov rdi, rbx
    mov rsi, rsp
    call canvas_paint_element
8:  inc r13
    jmp 1b
9:  mov rdi, [rsp + CE_SIZE]
    call canvas_preview_blend
    EPILOGUE
.section .rodata
.Lprompt: .asciz "Import structured model proposal JSON path"
.Linvalid: .asciz "Proposal rejected: schema, references, dependency subset or stale revision"

.text
FN canvas_proposal_input
    PROLOGUE
    mov rbx, rdi
    mov r12, [rbx + SC_proposal]
    test r12, r12
    jz 8f
    test dword ptr [rip + g_pressed], 1 << BTN_LEFT
    jz 8f
    mov r13, [r12 + CP_candidate]
    lea rdi, [r13 + SC_zoom]
    lea rsi, [rbx + SC_zoom]
    mov edx, 28
    call memcpy
    mov rdi, rbx
    mov esi, [rip + g_mx]
    mov edx, [rip + g_my]
    call scene_to_world
    mov esi, eax
    mov rdi, r13
    call scene_hit
    test rax, rax
    jz 8f
    mov r14, [rax + CE_id]
    mov rdi, r12
    mov rsi, r14
    call canvas_proposal_find
    test rax, rax
    jz 8f
    cmp dword ptr [rax + PO_kind], 2
    jae 8f
    mov [rbx + SC_proposal_selected], r14
    mov eax, 1
    EPILOGUE
8:  xor eax, eax
    EPILOGUE
