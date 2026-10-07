.include "rhun.inc"
.include "canvas/canvas.inc"
.include "radare/trace.inc"
.text
# Per-block coverage is derived; it never overwrites saved colors/progress.
FN radare_trace_overlay
    PROLOGUE SB_SIZE+32
    mov rbx, rdi
    mov r12, rsi
    mov r13, [rbx + SC_trace_view]
    test r13, r13
    jz .Lto_done
    xor ecx, ecx
.Lto_find:
    cmp rcx, [r13 + RV_blocks + VEC_len]
    jae .Lto_done
    imul rax, rcx, RC_SIZE
    add rax, [r13 + RV_blocks + VEC_ptr]
    mov rdx, [r12 + CE_id]
    cmp [rax + RC_id], rdx
    je .Lto_found
    inc rcx
    jmp .Lto_find
.Lto_found:
    cmp qword ptr [rax + RC_count], 0
    je .Lto_done
    mov r14, [rax + RC_count]
    mov r15d, 0xff78c88d
    mov ecx, [rbx + SC_trace_cursor]
    cmp rcx, [r13 + RV_events + VEC_len]
    jae .Lto_color
    shl rcx, 4
    add rcx, [r13 + RV_events + VEC_ptr]
    mov rax, [r12 + CE_id]
    cmp [rcx + RT_block], rax
    jne .Lto_color
    mov r15d, 0xffffbc66
.Lto_color:
    mov rdi, rbx
    mov esi, [r12 + CE_x]
    mov edx, [r12 + CE_y]
    call scene_to_screen
    mov [rsp + SB_SIZE], eax
    mov [rsp + SB_SIZE + 4], edx
    mov eax, [r12 + CE_w]
    imul eax, [rbx + SC_zoom]
    shr eax, 16
    mov [rsp + SB_SIZE + 8], eax
    mov eax, [r12 + CE_h]
    imul eax, [rbx + SC_zoom]
    shr eax, 16
    mov [rsp + SB_SIZE + 12], eax
    mov edi, [rsp + SB_SIZE]
    mov esi, [rsp + SB_SIZE + 4]
    mov edx, [rsp + SB_SIZE + 8]
    mov ecx, 3
    mov r8d, r15d
    call gfx_fill
    mov edi, [rsp + SB_SIZE]
    mov esi, [rsp + SB_SIZE + 4]
    add esi, [rsp + SB_SIZE + 12]
    sub esi, 3
    mov edx, [rsp + SB_SIZE + 8]
    mov ecx, 3
    mov r8d, r15d
    call gfx_fill
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rsp
    lea rsi, [rip + .Lvisits]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, r14
    call sb_push_u64
    lea rdi, [rip + g_face_small]
    mov esi, [rsp + SB_SIZE]
    add esi, 8
    mov edx, [rsp + SB_SIZE + 4]
    add edx, [rsp + SB_SIZE + 12]
    sub edx, 24
    mov ecx, 24
    mov r8, [rsp + SB_ptr]
    mov r9d, r15d
    call ui_text_c
    mov rdi, rsp
    call sb_free
.Lto_done: EPILOGUE
FN radare_edge_label
    cmp dword ptr [rsi + CE_kind], CT_ARROW
    jne .Ledge_label_done
    cmp qword ptr [rdi + SC_analysis], 0
    je .Ledge_label_done
    cmp qword ptr [rsi + CE_text], 0
    je .Ledge_label_done
    PROLOGUE
    mov rbx, rsi
    mov esi, [rbx + CE_w]
    sar esi, 1
    add esi, [rbx + CE_x]
    mov edx, [rbx + CE_h]
    sar edx, 1
    add edx, [rbx + CE_y]
    call scene_to_screen
    mov esi, eax
    add esi, 4
    sub edx, 24
    lea rdi, [rip + g_face_small]
    mov ecx, 24
    mov r8, [rbx + CE_text]
    mov r9d, [rbx + CE_color]
    call ui_text_c
    EPILOGUE
.Ledge_label_done: ret
FN radare_clip_text
    cmp dword ptr [rsi + CE_kind], CT_TEXT
    jne .Lct_no
    cmp qword ptr [rdi + SC_analysis], 0
    je .Lct_no
    PROLOGUE
    mov rbx, rdi
    mov rsi, [rsi + CE_group]
    call scene_find
    test rax, rax
    jz .Lct_return_no
    mov r12, rax
    mov rdi, [rax + CE_gxid]
    test rdi, rdi
    jz .Lct_return_no
    lea rsi, [rip + r2_block_marker]
    call strcmp_eq
    test eax, eax
    jz .Lct_return_no
    mov rdi, rbx
    mov esi, [r12 + CE_x]
    mov edx, [r12 + CE_y]
    call scene_to_screen
    mov edi, eax
    mov esi, edx
    mov eax, [r12 + CE_w]
    imul eax, [rbx + SC_zoom]
    shr eax, 16
    mov edx, eax
    mov eax, [r12 + CE_h]
    imul eax, [rbx + SC_zoom]
    shr eax, 16
    mov ecx, eax
    call gfx_clip_push
    mov eax, 1
    EPILOGUE
.Lct_return_no: xor eax, eax
    EPILOGUE
.Lct_no: xor eax, eax
    ret
FN cmd_radare_fold
    PROLOGUE
    call canvas_active
    mov rbx, rax
    test rax, rax
    jz .Lfold_done
    mov rdi, rax
    mov rsi, [rax + SC_selected]
    call scene_find
    test rax, rax
    jz .Lfold_done
    cmp dword ptr [rax + CE_kind], CT_FRAME
    je .Lfold_toggle
    mov rdi, rbx
    mov rsi, [rax + CE_frame]
    call scene_find
    test rax, rax
    jz .Lfold_done
.Lfold_toggle:
    mov r12, rax
    mov rdi, rbx
    call scene_deselect
    mov rax, [r12 + CE_id]
    mov [rbx + SC_selected], rax
    or dword ptr [r12 + CE_flags], 1
    call cmd_canvas_detail_toggle
.Lfold_done: EPILOGUE
FN radare_toolbar
    PROLOGUE SB_SIZE+16
    mov rbx, rdi
    mov r12d, esi
    call radare_trace_prepare
    xor r13d, r13d
.Ltb_button:
    cmp r13d, 6
    jae .Ltb_caption
    mov r14d, r13d
    imul r14d, 80
    add r14d, [rbx + SC_x]
    mov edi, 0x7d00
    add edi, r13d
    mov esi, r14d
    mov edx, r12d
    mov ecx, 78
    M r8d, MI_40
    call ui_btn
    test eax, UB_CLICK
    jz .Ltb_label
    lea rax, [rip + .Ltoolbar_actions]
    call [rax + r13*8]
.Ltb_label:
    lea rdi, [rip + g_face_small]
    mov esi, r14d
    add esi, 6
    mov edx, r12d
    M ecx, MI_40
    lea rax, [rip + .Ltoolbar_labels]
    mov r8, [rax + r13*8]
    COLOR r9d, T_MUTED
    call ui_text_c
    inc r13d
    jmp .Ltb_button
.Ltb_caption:
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rsp
    lea rsi, [rip + .Lstatic]
    call sb_push_cstr
    mov r13, [rbx + SC_trace_view]
    test r13, r13
    jz .Ltb_draw
    cmp qword ptr [r13 + RV_events + VEC_len], 0
    je .Ltb_draw
    mov rdi, rsp
    lea rsi, [rip + .Limported]
    call sb_push_cstr
    mov rdi, rsp
    mov esi, [rbx + SC_trace_cursor]
    inc esi
    call sb_push_u64
    mov rdi, rsp
    mov esi, '/'
    call sb_push_byte
    mov rdi, rsp
    mov rsi, [r13 + RV_events + VEC_len]
    call sb_push_u64
    mov rdi, rsp
    lea rsi, [rip + .Lunknown]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, [r13 + RV_unmapped]
    call sb_push_u64
.Ltb_draw:
    lea rdi, [rip + g_face_small]
    mov esi, [rbx + SC_x]
    add esi, 486
    mov edx, r12d
    M ecx, MI_40
    mov r8, [rsp + SB_ptr]
    COLOR r9d, T_MUTED
    call ui_text_c
    mov rdi, rsp
    call sb_free
    EPILOGUE
FN radare_key
    test esi, MOD_CTRL | MOD_ALT | MOD_SUPER
    jnz .Lrk_no
    cmp edi, '['
    je .Lrk_prev
    cmp edi, ']'
    je .Lrk_next
    cmp edi, 'n'
    je .Lrk_function
    cmp edi, 'f'
    je .Lrk_fold
.Lrk_no: xor eax, eax
    ret
.Lrk_prev: push rbx
    call cmd_radare_trace_prev
    pop rbx
    mov eax, 1
    ret
.Lrk_next: push rbx
    call cmd_radare_trace_next
    pop rbx
    mov eax, 1
    ret
.Lrk_function: push rbx
    call cmd_radare_next_function
    pop rbx
    mov eax, 1
    ret
.Lrk_fold: push rbx
    call cmd_radare_fold
    pop rbx
    mov eax, 1
    ret
.section .rodata
.Lvisits: .asciz "trace visits: "
.Lstatic: .asciz "Static CFG"
.Limported: .asciz " | imported trace "
.Lunknown: .asciz " unmapped: "
.Lfunc: .asciz "Function"
.Lfold: .asciz "Fold"
.Lprev: .asciz "Prev"
.Lnext: .asciz "Next"
.Lnote: .asciz "Note"
.Lreview: .asciz "Review"
.p2align 3
.Ltoolbar_labels: .quad .Lfunc, .Lfold, .Lprev, .Lnext, .Lnote, .Lreview
.Ltoolbar_actions: .quad cmd_radare_next_function, cmd_radare_fold, cmd_radare_trace_prev, cmd_radare_trace_next, cmd_radare_note, cmd_radare_review_export
