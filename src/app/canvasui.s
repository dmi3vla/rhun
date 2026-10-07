.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN canvas_toolbar
    PROLOGUE 16
    mov rbx, rdi
    mov r12d, esi
    xor r13d, r13d
1:  cmp r13d, 8
    jae 9f
    mov r14d, r13d
    imul r14d, 62
    add r14d, [rbx + SC_x]
    mov edi, 0x7c00
    add edi, r13d
    mov esi, r14d
    mov edx, r12d
    mov ecx, 60
    M r8d, MI_40
    call ui_btn
    test eax, UB_CLICK
    jz 2f
    mov edi, r13d
    call canvas_set_tool
2:  lea rdi, [rip + g_face_small]
    lea rcx, [rip + .Ltools]
    mov r8, [rcx + r13*8]
    mov esi, r14d
    add esi, 6
    mov edx, r12d
    M ecx, MI_40
    COLOR r9d, T_MUTED
    cmp r13d, [rbx + SC_tool]
    jne 3f
    COLOR r9d, T_ACCENT
3:  call ui_text_c
    inc r13d
    jmp 1b
9:  cmp qword ptr [rbx + SC_text_id], 0
    je 91f
    lea rdi, [rip + g_face_small]
    mov esi, [rbx + SC_x]
    add esi, 500
    mov edx, r12d
    M ecx, MI_40
    lea r8, [rip + .Ltext_hint]
    COLOR r9d, T_MUTED
    call ui_text_c
91: EPILOGUE

FN canvas_overlays
    PROLOGUE 32
    mov rbx, rdi
    cmp dword ptr [rbx + SC_gesture], 1
    jne 1f
    mov rdi, rbx
    lea rsi, [rbx + SC_preview]
    call canvas_element
1:  cmp dword ptr [rbx + SC_gesture], 3
    jne 2f
    lea r12, [rbx + SC_preview]
    mov dword ptr [r12 + CE_kind], CT_FRAME
    mov eax, [rbx + SC_gx]
    mov [r12 + CE_x], eax
    mov eax, [rbx + SC_gy]
    mov [r12 + CE_y], eax
    mov eax, [rbx + SC_dx]
    mov [r12 + CE_w], eax
    mov eax, [rbx + SC_dy]
    mov [r12 + CE_h], eax
    mov dword ptr [r12 + CE_color], 0xff8da4ff
    mov rdi, rbx
    mov rsi, r12
    call canvas_element
2:  mov rdi, rbx
    mov rsi, [rbx + SC_selected]
    call scene_find
    test rax, rax
    jz .Loverlay_text
    cmp dword ptr [rax + CE_kind], CT_ARROW
    je .Loverlay_text
    mov esi, [rax + CE_x]
    add esi, [rax + CE_w]
    mov edx, [rax + CE_h]
    sar edx, 1
    add edx, [rax + CE_y]
    mov rdi, rbx
    call scene_to_screen
    mov [rsp], eax
    mov [rsp + 4], edx
    lea rdi, [rip + g_face_ui]
    lea esi, [rax + 4]
    sub edx, 12
    mov ecx, 24
    lea r8, [rip + .Lplus]
    COLOR r9d, T_ACCENT
    call ui_text_c
    cmp dword ptr [rbx + SC_gesture], 5
    je .Loverlay_node
    cmp dword ptr [rbx + SC_gesture], 6
    jne .Loverlay_text
.Loverlay_node:
    mov rdi, rbx
    mov esi, [rbx + SC_gx]
    add esi, [rbx + SC_dx]
    mov edx, [rbx + SC_gy]
    add edx, [rbx + SC_dy]
    call scene_to_screen
    mov ecx, edx
    mov edx, eax
    mov edi, [rsp]
    mov esi, [rsp + 4]
    COLOR r8d, T_ACCENT
    call canvas_line
    cmp dword ptr [rbx + SC_gesture], 6
    jne .Loverlay_text
    xor r12d, r12d
3:  cmp r12d, 4
    jae .Loverlay_text
    imul r13d, r12d, 132
    add r13d, [rbx + SC_x]
    mov edi, 0x7d00
    add edi, r12d
    mov esi, r13d
    mov edx, [rbx + SC_y]
    mov ecx, 130
    mov r8d, 36
    call ui_btn
    test eax, UB_CLICK
    jz 4f
    lea eax, [r12 + 1]
    mov [rbx + SC_node_type], eax
    mov rdi, rbx
    call canvas_node_commit
    jmp .Loverlay_text
4:  mov edi, r13d
    mov esi, [rbx + SC_y]
    mov edx, 130
    mov ecx, 36
    COLOR r8d, T_PANEL
    call gfx_fill
    lea rdi, [rip + g_face_small]
    mov esi, r13d
    add esi, 4
    mov edx, [rbx + SC_y]
    mov ecx, 36
    lea rax, [rip + .Lnode_roles]
    mov r8, [rax + r12*8]
    COLOR r9d, T_FG
    call ui_text_c
    inc r12d
    jmp 3b
.Loverlay_text:
    cmp qword ptr [rbx + SC_text_id], 0
    je 9f
    mov rdi, rbx
    mov esi, [rbx + SC_preview + CE_x]
    mov edx, [rbx + SC_preview + CE_y]
    call scene_to_screen
    mov esi, eax
    lea rdi, [rbx + SC_edit]
    mov ecx, 320
    mov r8d, 144
    xor r9d, r9d
    cmp dword ptr [rip + g_focus], FOCUS_EDITOR
    sete r9b
    push 0
    push 0
    call ui_textarea
    add rsp, 16
9:  EPILOGUE

FN cmd_canvas_reload
    PROLOGUE
    call canvas_active
    test rax, rax
    jz 9f
    mov rdi, [rax + SC_doc]
    call canvas_reload_doc
9:  EPILOGUE

# Shared with the watcher: validate stable bytes before replacing owned content.
FN canvas_reload_doc
    PROLOGUE 16
    mov rbx, rdi
    call doc_dirty
    test eax, eax
    jnz 8f
    mov rdi, [rbx + DOC_path]
    test rdi, rdi
    jz 8f
    call file_stamp
    mov [rsp], rax
    mov rdi, [rbx + DOC_path]
    call scene_load
    test rax, rax
    jz 8f
    mov r12, rax
    mov rdi, [rbx + DOC_path]
    call file_stamp
    cmp rax, [rsp]
    jne 7f
    mov r13, [rbx + DOC_canvas]
    cmp qword ptr [r13 + SC_text_id], 0
    jne 7f
    cmp dword ptr [r13 + SC_gesture], 0
    jne 7f
    mov rdi, r13
    call scene_clone
    mov r14, rax
    mov rdi, r13
    call scene_clear_elements
    lea rdi, [r13 + SC_elements]
    lea rsi, [r12 + SC_elements]
    mov edx, VEC_SIZE
    call memcpy
    lea rdi, [r12 + SC_elements]
    xor esi, esi
    mov edx, VEC_SIZE
    call memset
    mov rax, [r12 + SC_next_id]
    cmp rax, [r13 + SC_next_id]
    jbe 1f
    mov [r13 + SC_next_id], rax
1:  mov rdi, r12
    call scene_free
    mov rdi, r13
    mov rsi, r14
    call scene_commit
    mov rax, [r13 + SC_hash]
    mov [r13 + SC_saved_hash], rax
    mov rax, [rsp]
    mov [rbx + DOC_mtime], rax
    mov eax, 1
    EPILOGUE
7:  mov rdi, r12
    call scene_free
8:  lea rdi, [rip + .Lreload_failed]
    call app_toast
    xor eax, eax
    EPILOGUE
.section .rodata
.Ltext_hint: .asciz "Ctrl+Enter: apply | Escape: cancel"
.Lplus: .asciz "+"
.Lreload_failed: .asciz "Canvas reload rejected: unsaved changes, invalid or unstable data"
.Ls: .asciz "S select"
.Lr: .asciz "R rect"
.Le: .asciz "E ellipse"
.La: .asciz "A arrow"
.Lt: .asciz "T text"
.Lf: .asciz "F frame"
.Ll: .asciz "L line"
.Lp: .asciz "P pen"
.Ln1: .asciz "1 Шаг"
.Ln2: .asciz "2 Вопрос"
.Ln3: .asciz "3 Решение"
.Ln4: .asciz "4 Ограничение"
.p2align 3
.Ltools: .quad .Ls, .Lr, .Le, .La, .Lt, .Lf, .Ll, .Lp
.Lnode_roles: .quad .Ln1, .Ln2, .Ln3, .Ln4
