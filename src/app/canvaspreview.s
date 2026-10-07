.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN cmd_canvas_ui_preview
    PROLOGUE
    call canvas_cancel
    call canvas_active
    test rax, rax
    jz 9f
    xor dword ptr [rax + SC_mode], 1
    mov dword ptr [rip + g_dirty], 1
9:  EPILOGUE

# Recursive clips ensure overflow cannot paint outside an ancestor/frame.
FN canvas_ui_preview
    PROLOGUE
    mov rbx, rdi
    call canvas_ui_model
    mov r12, rax
    test rax, rax
    jz 9f
    mov rax, [rax + UM_revision]
    cmp rax, [rbx + SC_revision]
    jne 8f
    mov rdi, r12
    mov rsi, rbx
    call canvas_ui_layout
    mov rdi, r12
    mov rsi, [r12 + UM_root]
    call canvas_ui_find
    mov rdi, rbx
    mov rsi, r12
    mov rdx, rax
    call canvas_ui_paint
8:  mov rdi, r12
    call canvas_ui_free
9:  EPILOGUE
canvas_ui_paint:
    PROLOGUE 48
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov esi, [r13 + UC_x]
    mov edx, [r13 + UC_y]
    call scene_to_screen
    mov [rsp], eax
    mov [rsp + 4], edx
    mov eax, [r13 + UC_w]
    mov ecx, [rbx + SC_zoom]
    imul rax, rcx
    shr rax, 16
    mov [rsp + 8], eax
    mov eax, [r13 + UC_h]
    imul rax, rcx
    shr rax, 16
    mov [rsp + 12], eax
    mov edi, [rsp]
    mov esi, [rsp + 4]
    mov edx, [rsp + 8]
    mov ecx, [rsp + 12]
    call gfx_clip_push
    mov edi, [rsp]
    mov esi, [rsp + 4]
    mov edx, [rsp + 8]
    mov ecx, [rsp + 12]
    call ui_in
    mov ecx, [rip + g_mx]
    cmp ecx, [rip + g_cv + CV_cx0]
    jl 101f
    cmp ecx, [rip + g_cv + CV_cx1]
    jge 101f
    mov ecx, [rip + g_my]
    cmp ecx, [rip + g_cv + CV_cy0]
    jl 101f
    cmp ecx, [rip + g_cv + CV_cy1]
    jl 102f
101: xor eax, eax
102:
    mov [rsp + 16], eax
    COLOR r8d, T_PANEL
    cmp dword ptr [r13 + UC_type], U_TEXT
    je 2f
    test eax, eax
    jz 1f
    COLOR r8d, T_SELECTION
    test dword ptr [rip + g_pressed], 1 << BTN_LEFT
    jz 1f
    mov rax, [r13 + UC_source]
    mov [rbx + SC_selected], rax
    mov dword ptr [rip + g_dirty], 1
1:  mov edi, [rsp]
    mov esi, [rsp + 4]
    mov edx, [rsp + 8]
    mov ecx, [rsp + 12]
    call gfx_fill
2:  mov eax, [r13 + UC_type]
    cmp eax, U_CARD
    je 3f
    cmp eax, U_BUTTON
    jae 3f
    mov rax, [r13 + UC_source]
    cmp rax, [rbx + SC_selected]
    jne 4f
3:  mov edi, [rsp]
    mov esi, [rsp + 4]
    mov edx, [rsp + 8]
    mov ecx, 1
    COLOR r8d, T_ACCENT
    call gfx_fill
4:  mov eax, [r13 + UC_padding]
    imul eax, [rbx + SC_zoom]
    shr eax, 16
    add [rsp], eax
    add [rsp + 4], eax
    add eax, eax
    sub [rsp + 8], eax
    mov r14, [r13 + UC_text]
    xor r15d, r15d
5:  cmp byte ptr [r14], 0
    je .Lpreview_children
    xor edx, edx
51: cmp byte ptr [r14 + rdx], 0
    je 52f
    cmp byte ptr [r14 + rdx], 10
    je 52f
    inc rdx
    jmp 51b
52: mov [rsp + 24], rdx
    lea rdi, [rip + g_face_ui]
    mov rsi, r14
    mov ecx, [rsp + 8]
    cmp ecx, 1
    jl .Lpreview_children
    call text_fit
    test rax, rax
    jnz 53f
    mov rdi, r14
    mov rsi, [rsp + 24]
    call utf8_decode
    mov rax, rdx
53: mov [rsp + 32], rax
    lea rdi, [rip + g_face_ui]
    mov esi, [rsp]
    mov edx, [rsp + 4]
    add edx, r15d
    add edx, [rip + g_face_ui + FACE_ascent]
    mov rcx, r14
    mov r8, rax
    COLOR r9d, T_FG
    call text_draw
    add r14, [rsp + 32]
    cmp byte ptr [r14], 10
    jne 54f
    inc r14
54: add r15d, 20
    mov eax, [r13 + UC_h]
    imul eax, [rbx + SC_zoom]
    shr eax, 16
    cmp r15d, eax
    jl 5b
.Lpreview_children:
    xor r14d, r14d
6:  cmp r14, [r12 + UM_nodes + VEC_len]
    jae 8f
    imul rdx, r14, UC_SIZE
    add rdx, [r12 + UM_nodes + VEC_ptr]
    mov rax, [r13 + UC_id]
    cmp rax, [rdx + UC_parent]
    jne 7f
    mov rdi, rbx
    mov rsi, r12
    call canvas_ui_paint
7:  inc r14
    jmp 6b
8:  call gfx_clip_pop
    EPILOGUE

FN canvas_ui_dump
    PROLOGUE
    mov r13, rdi
    call canvas_active
    mov rbx, rax
    test rax, rax
    jz 9f
    mov rdi, rbx
    call canvas_ui_model
    mov r12, rax
    test rax, rax
    jz 9f
    mov rdi, r12
    mov rsi, rbx
    call canvas_ui_layout
    mov rdi, r13
    lea rsi, [rip + .Llayout_header]
    call sb_push_cstr
    xor r14d, r14d
1:  cmp r14, [r12 + UM_nodes + VEC_len]
    jae 8f
    test r14, r14
    jz 2f
    mov rdi, r13
    mov esi, ','
    call sb_push_byte
2:  imul rbx, r14, UC_SIZE
    add rbx, [r12 + UM_nodes + VEC_ptr]
    mov rdi, r13
    lea rsi, [rip + .Lnode_id]
    call sb_push_cstr
    mov rdi, r13
    mov rsi, [rbx + UC_id]
    call sb_push_u64
    mov rdi, r13
    mov esi, ','
    call sb_push_byte
    lea r15, [rip + .Llayout_fields]
3:  cmp qword ptr [r15], 0
    je 4f
    mov rcx, [r15 + 8]
    movsxd rdx, dword ptr [rbx + rcx]
    mov rdi, r13
    mov rsi, [r15]
    call canvas_export_number
    add r15, 16
    jmp 3b
4:  mov rdi, r13
    lea rsi, [rip + .Ltail_field]
    call sb_push_cstr
    inc r14
    jmp 1b
8:  mov rdi, r13
    lea rsi, [rip + .Llayout_end]
    call sb_push_cstr
    mov rdi, r12
    call canvas_ui_free
9:  EPILOGUE
.section .rodata
.Llayout_header: .asciz "{\"type\":\"rhun-ui-layout\",\"nodes\":["
.Lnode_id: .asciz "{\"id\":"
.Ltail_field: .asciz "\"valid\":true}"
.Llayout_end: .asciz "]}\n"
.Lx: .asciz "x"
.Ly: .asciz "y"
.Lw: .asciz "w"
.Lh: .asciz "h"
.p2align 3
.Llayout_fields: .quad .Lx, UC_x, .Ly, UC_y, .Lw, UC_w, .Lh, UC_h, 0
