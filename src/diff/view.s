.include "rhun.inc"
.include "canvas/canvas.inc"
.include "diff/diff.inc"
.text
# DF, result -> shown discrepancy (Structure hides property-only claims).
FN diff_result_visible
    xor eax, eax
    cmp dword ptr [rsi + DR_status], 0
    je 9f
    cmp dword ptr [rdi + DF_filter], 0
    jne 8f
    mov ecx, [rsi + DR_reason]
    cmp ecx, 4
    jb 8f
    cmp ecx, 6
    jbe 9f
    cmp ecx, 9
    je 9f
8:  mov eax, 1
9:  ret
FN cmd_diff_toggle
    PROLOGUE
    call canvas_active
    test rax, rax
    jz 9f
    mov rax, [rax + SC_diff]
    test rax, rax
    jz 9f
    xor dword ptr [rax + DF_show], 1
    mov dword ptr [rip + g_dirty], 1
9:  EPILOGUE
FN cmd_diff_filter
    PROLOGUE
    call canvas_active
    test rax, rax
    jz 9f
    mov rax, [rax + SC_diff]
    test rax, rax
    jz 9f
    xor dword ptr [rax + DF_filter], 1
    mov dword ptr [rax + DF_cursor], -1
    mov dword ptr [rip + g_dirty], 1
9:  EPILOGUE
FN cmd_diff_clear
    PROLOGUE
    call canvas_active
    test rax, rax
    jz 9f
    mov rbx, rax
    mov rdi, [rax + SC_diff]
    call diff_free
    mov qword ptr [rbx + SC_diff], 0
    mov dword ptr [rip + g_dirty], 1
9:  EPILOGUE
FN cmd_diff_next
    mov edi, 1
    jmp diff_navigate
FN cmd_diff_prev
    mov edi, -1
    jmp diff_navigate
FN diff_navigate
    PROLOGUE 16
    mov [rsp], edi
    call canvas_active
    mov rbx, rax
    test rax, rax
    jz .Lnav_done
    mov r12, [rax + SC_diff]
    test r12, r12
    jz .Lnav_done
    mov rdi, rbx
    mov rsi, r12
    call diff_stale
    test eax, eax
    jnz .Lnav_done
    mov r13d, [r12 + DF_cursor]
    xor r14d, r14d
.Lnav_scan:
    cmp r14, [r12 + DF_results + VEC_len]
    jae .Lnav_done
    add r13d, [rsp]
    test r13d, r13d
    jns .Lnav_positive
    mov r13d, [r12 + DF_results + VEC_len]
    dec r13d
.Lnav_positive:
    cmp r13, [r12 + DF_results + VEC_len]
    jb .Lnav_check
    xor r13d, r13d
.Lnav_check:
    imul r15, r13, DR_SIZE
    add r15, [r12 + DF_results + VEC_ptr]
    mov rdi, r12
    mov rsi, r15
    call diff_result_visible
    test eax, eax
    jnz .Lnav_focus
    inc r14
    jmp .Lnav_scan
.Lnav_focus:
    mov [r12 + DF_cursor], r13d
    mov eax, [r15 + DR_base]
    cmp dword ptr [r15 + DR_type], 0
    je .Lnav_source_index
    mov rcx, [r12 + DF_base]
    test eax, eax
    jnz .Lnav_edge_source
    mov eax, [r15 + DR_target]
    mov rcx, [r12 + DF_target]
.Lnav_edge_source:
    test eax, eax
    jz .Lnav_done
    dec eax
    imul rax, DE_SIZE
    add rax, [rcx + DG_links + VEC_ptr]
    mov rsi, [rax + DE_from]
    mov rax, [r12 + DF_base]
    lea rdi, [rax + DG_nodes]
    call diff_node_id
.Lnav_source_index:
    test eax, eax
    jz .Lnav_done
    mov rcx, [r12 + DF_base]
    cmp dword ptr [rcx + DG_profile], 0
    je .Lnav_cfg_source
    mov rdi, rbx
    mov esi, eax
    call diff_memory_focus
    jmp .Lnav_done
.Lnav_cfg_source:
    dec eax
    imul rax, DN_SIZE
    add rax, [rcx + DG_nodes + VEC_ptr]
    mov rdi, rbx
    mov rsi, [rax + DN_ref]
    call scene_find
    test rax, rax
    jz .Lnav_done
    mov r15, rax
    mov rdi, rbx
    call scene_deselect
    mov rax, [r15 + CE_id]
    mov [rbx + SC_selected], rax
    or dword ptr [r15 + CE_flags], 1
    mov eax, 60
    sub eax, [r15 + CE_x]
    mov [rbx + SC_pan_x], eax
    mov eax, 100
    sub eax, [r15 + CE_y]
    mov [rbx + SC_pan_y], eax
.Lnav_done:
    mov dword ptr [rip + g_dirty], 1
    EPILOGUE
# Called before ordinary canvas typing. No global editor shortcuts are consumed.
FN diff_key
    test edx, MOD_CTRL | MOD_ALT | MOD_SUPER
    jnz .Lkey_no
    cmp edi, 'd'
    je .Lkey_d
    cmp edi, 'D'
    jne .Lkey_no
.Lkey_d:
    PROLOGUE
    mov ebx, edx
    call canvas_active
    test rax, rax
    jz .Lkey_false
    cmp qword ptr [rax + SC_diff], 0
    je .Lkey_false
    cmp qword ptr [rax + SC_text_id], 0
    jne .Lkey_false
    test ebx, MOD_SHIFT
    jnz .Lkey_prev
    call cmd_diff_next
    jmp .Lkey_yes
.Lkey_prev: call cmd_diff_prev
.Lkey_yes: mov eax, 1
    EPILOGUE
.Lkey_false: xor eax, eax
    EPILOGUE
.Lkey_no: xor eax, eax
    ret
# scene, DF, base index, screen rectangle output -> 1 if visible.
FN diff_base_point
    PROLOGUE 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rcx
    mov rax, [r12 + DF_base]
    cmp dword ptr [rax + DG_profile], 0
    je .Lpoint_cfg
    mov rdi, rbx
    mov rsi, r12
    mov rcx, r13
    call diff_memory_point
    EPILOGUE
.Lpoint_cfg:
    test edx, edx
    jz .Lpoint_no
    dec edx
    imul rdx, DN_SIZE
    add rdx, [rax + DG_nodes + VEC_ptr]
    mov rsi, [rdx + DN_ref]
    call scene_find
    test rax, rax
    jz .Lpoint_no
    mov r14, rax
    mov rsi, [rax + CE_frame]
    mov rdi, rbx
    call canvas_folded
    test eax, eax
    jz .Lpoint_element
    mov rdi, rbx
    mov rsi, [r14 + CE_frame]
    call scene_find
    test rax, rax
    jz .Lpoint_no
    mov r14, rax
.Lpoint_element:
    mov rdi, rbx
    mov esi, [r14 + CE_x]
    mov edx, [r14 + CE_y]
    call scene_to_screen
    mov [r13], eax
    mov [r13 + 4], edx
    movsxd rax, dword ptr [r14 + CE_w]
    mov ecx, [rbx + SC_zoom]
    imul rax, rcx
    sar rax, 16
    mov [r13 + 8], eax
    movsxd rax, dword ptr [r14 + CE_h]
    imul rax, rcx
    sar rax, 16
    mov [r13 + 12], eax
    mov eax, 1
    EPILOGUE
.Lpoint_no: xor eax, eax
    EPILOGUE
# scene, DF, cstr ID, rectangle output. Ghosts occupy a labelled screen rail.
FN diff_id_point
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov rax, [r12 + DF_base]
    lea rdi, [rax + DG_nodes]
    mov rsi, r13
    call diff_node_id
    test eax, eax
    jz .Lghost
    mov rdi, rbx
    mov rsi, r12
    mov edx, eax
    mov rcx, r14
    call diff_base_point
    EPILOGUE
.Lghost:
    mov eax, [rbx + SC_x]
    add eax, [rbx + SC_w]
    sub eax, 280
    mov [r14], eax
    mov eax, [rbx + SC_y]
    add eax, 65
    mov [r14 + 4], eax
    mov dword ptr [r14 + 8], 260
    mov dword ptr [r14 + 12], 92
    mov eax, 1
    EPILOGUE
# Rectangle x,y,w,h,color. Clipped solid outline; markers carry category labels.
FN diff_frame
    PROLOGUE 24
    mov [rsp], edi
    mov [rsp + 4], esi
    mov [rsp + 8], edx
    mov [rsp + 12], ecx
    mov [rsp + 16], r8d
    mov ecx, 3
    call gfx_fill
    mov edi, [rsp]
    mov esi, [rsp + 4]
    add esi, [rsp + 12]
    sub esi, 3
    mov edx, [rsp + 8]
    mov ecx, 3
    mov r8d, [rsp + 16]
    call gfx_fill
    mov edi, [rsp]
    mov esi, [rsp + 4]
    mov edx, 3
    mov ecx, [rsp + 12]
    mov r8d, [rsp + 16]
    call gfx_fill
    mov edi, [rsp]
    add edi, [rsp + 8]
    sub edi, 3
    mov esi, [rsp + 4]
    mov edx, 3
    mov ecx, [rsp + 12]
    mov r8d, [rsp + 16]
    call gfx_fill
    EPILOGUE
# Native arrow rasterizer on temporary screen-space geometry, never source CE.
FN diff_arrow
    PROLOGUE SC_SIZE+CE_SIZE+24
    mov [rsp + SC_SIZE + CE_SIZE], edi
    mov [rsp + SC_SIZE + CE_SIZE + 4], esi
    mov [rsp + SC_SIZE + CE_SIZE + 8], edx
    mov [rsp + SC_SIZE + CE_SIZE + 12], ecx
    mov [rsp + SC_SIZE + CE_SIZE + 16], r8d
    mov rdi, rsp
    xor esi, esi
    mov edx, SC_SIZE+CE_SIZE
    call memset
    mov dword ptr [rsp + SC_zoom], 65536
    mov dword ptr [rsp + SC_SIZE + CE_kind], CT_ARROW
    mov eax, [rsp + SC_SIZE + CE_SIZE]
    mov [rsp + SC_SIZE + CE_x], eax
    mov edx, [rsp + SC_SIZE + CE_SIZE + 8]
    sub edx, eax
    mov [rsp + SC_SIZE + CE_w], edx
    mov eax, [rsp + SC_SIZE + CE_SIZE + 4]
    mov [rsp + SC_SIZE + CE_y], eax
    mov edx, [rsp + SC_SIZE + CE_SIZE + 12]
    sub edx, eax
    mov [rsp + SC_SIZE + CE_h], edx
    mov eax, [rsp + SC_SIZE + CE_SIZE + 16]
    mov [rsp + SC_SIZE + CE_color], eax
    mov rdi, rsp
    lea rsi, [rsp + SC_SIZE]
    call canvas_paint_element
    EPILOGUE
FN diff_overlay
    PROLOGUE SB_SIZE+64
    mov rbx, rdi
    mov r12, [rbx + SC_diff]
    test r12, r12
    jz .Loverlay_done
    cmp dword ptr [r12 + DF_show], 0
    je .Loverlay_done
    mov rdi, rbx
    mov rsi, r12
    call diff_stale
    test eax, eax
    jnz .Lstale
    mov dword ptr [rsp + SB_SIZE + 48], 0
    mov dword ptr [rsp + SB_SIZE + 52], 0
    mov eax, [r12 + DF_cursor]
    test eax, eax
    js .Lghost_prepared
    cmp rax, [r12 + DF_results + VEC_len]
    jae .Lghost_prepared
    imul rax, DR_SIZE
    add rax, [r12 + DF_results + VEC_ptr]
    cmp dword ptr [rax + DR_type], 0
    jne .Lghost_prepared
    cmp dword ptr [rax + DR_base], 0
    jne .Lghost_prepared
    mov eax, [rax + DR_target]
    mov [rsp + SB_SIZE + 48], eax
.Lghost_prepared:
    xor r13d, r13d
.Loverlay_result:
    cmp r13, [r12 + DF_results + VEC_len]
    jae .Linspector
    imul r14, r13, DR_SIZE
    add r14, [r12 + DF_results + VEC_ptr]
    mov rdi, r12
    mov rsi, r14
    call diff_result_visible
    test eax, eax
    jz .Loverlay_more
    mov eax, [r14 + DR_status]
    lea rcx, [rip + diff_colors]
    mov r15d, [rcx + rax*4]
    cmp dword ptr [r14 + DR_type], 1
    je .Loverlay_edge
    cmp dword ptr [r14 + DR_base], 0
    je .Loverlay_ghost
    mov rdi, rbx
    mov rsi, r12
    mov edx, [r14 + DR_base]
    lea rcx, [rsp + SB_SIZE]
    call diff_base_point
    test eax, eax
    jz .Loverlay_more
    jmp .Loverlay_box
.Loverlay_ghost:
    # Rail shows one ghost at a time; navigation reveals any bounded ghost.
    mov eax, [rsp + SB_SIZE + 48]
    test eax, eax
    jz .Lghost_first
    cmp [r14 + DR_target], eax
    jne .Loverlay_more
.Lghost_first:
    cmp dword ptr [rsp + SB_SIZE + 52], 0
    jne .Loverlay_more
    mov dword ptr [rsp + SB_SIZE + 52], 1
    mov rax, [r12 + DF_target]
    mov edx, [r14 + DR_target]
    dec edx
    imul rdx, DN_SIZE
    add rdx, [rax + DG_nodes + VEC_ptr]
    mov [rsp + SB_SIZE + 40], rdx
    mov rdi, rbx
    mov rsi, r12
    mov rdx, [rdx + DN_id]
    lea rcx, [rsp + SB_SIZE]
    call diff_id_point
    mov edi, [rsp + SB_SIZE]
    mov esi, [rsp + SB_SIZE + 4]
    mov edx, [rsp + SB_SIZE + 8]
    mov ecx, [rsp + SB_SIZE + 12]
    COLOR r8d, T_BG
    call gfx_fill
.Loverlay_box:
    mov edi, [rsp + SB_SIZE]
    mov esi, [rsp + SB_SIZE + 4]
    mov edx, [rsp + SB_SIZE + 8]
    mov ecx, [rsp + SB_SIZE + 12]
    mov r8d, r15d
    cmp dword ptr [r14 + DR_status], 1
    jne .Lsolid_frame
    call diff_dashed_frame
    jmp .Lframe_done
.Lsolid_frame:
    call diff_frame
    cmp dword ptr [r14 + DR_status], 3
    jne .Lframe_done
    mov edi, [rsp + SB_SIZE]
    mov esi, [rsp + SB_SIZE + 4]
    mov edx, [rsp + SB_SIZE + 8]
    mov ecx, [rsp + SB_SIZE + 12]
    mov r8d, r15d
    call diff_hatch
.Lframe_done:
    mov eax, [r14 + DR_status]
    lea rcx, [rip + diff_status_names]
    mov r8, [rcx + rax*8]
    lea rdi, [rip + g_face_small]
    mov esi, [rsp + SB_SIZE]
    add esi, 8
    mov edx, [rsp + SB_SIZE + 4]
    sub edx, 22
    mov ecx, 24
    mov r9d, r15d
    call ui_text_c
    cmp dword ptr [r14 + DR_base], 0
    jne .Loverlay_more
    mov rax, [rsp + SB_SIZE + 40]
    mov r8, [rax + DN_label]
    mov edi, [rsp + SB_SIZE]
    mov esi, [rsp + SB_SIZE + 4]
    mov edx, [rsp + SB_SIZE + 8]
    mov ecx, [rsp + SB_SIZE + 12]
    call gfx_clip_push
    lea rdi, [rip + g_face_small]
    mov esi, [rsp + SB_SIZE]
    add esi, 10
    mov edx, [rsp + SB_SIZE + 4]
    add edx, 20
    mov ecx, 24
    mov rax, [rsp + SB_SIZE + 40]
    mov r8, [rax + DN_label]
    mov r9d, r15d
    call ui_text_c
    call gfx_clip_pop
    jmp .Loverlay_more
.Loverlay_edge:
    mov eax, [r14 + DR_target]
    mov rcx, [r12 + DF_target]
    test eax, eax
    jnz .Ledge_record
    mov eax, [r14 + DR_base]
    mov rcx, [r12 + DF_base]
.Ledge_record:
    dec eax
    imul rax, DE_SIZE
    add rax, [rcx + DG_links + VEC_ptr]
    mov [rsp + SB_SIZE + 40], rax
    mov rdi, rbx
    mov rsi, r12
    mov rdx, [rax + DE_from]
    lea rcx, [rsp + SB_SIZE]
    call diff_id_point
    test eax, eax
    jz .Loverlay_more
    mov rax, [rsp + SB_SIZE + 40]
    mov rdi, rbx
    mov rsi, r12
    mov rdx, [rax + DE_to]
    lea rcx, [rsp + SB_SIZE + 16]
    call diff_id_point
    test eax, eax
    jz .Loverlay_more
    mov eax, [rsp + SB_SIZE + 8]
    sar eax, 1
    add eax, [rsp + SB_SIZE]
    mov edi, eax
    mov eax, [rsp + SB_SIZE + 12]
    sar eax, 1
    add eax, [rsp + SB_SIZE + 4]
    mov esi, eax
    mov eax, [rsp + SB_SIZE + 24]
    sar eax, 1
    add eax, [rsp + SB_SIZE + 16]
    mov edx, eax
    mov eax, [rsp + SB_SIZE + 28]
    sar eax, 1
    add eax, [rsp + SB_SIZE + 20]
    mov ecx, eax
    mov r8d, r15d
    call diff_arrow
.Loverlay_more: inc r13
    jmp .Loverlay_result
.Lstale:
    lea r8, [rip + .Lstale_text]
    jmp .Lbanner_text
.Linspector:
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rsp
    lea rsi, [rip + .Lbanner]
    call sb_push_cstr
    mov rdi, rsp
    mov esi, [r12 + DF_filter]
    lea rax, [rip + .Lfilters]
    mov rsi, [rax + rsi*8]
    call sb_push_cstr
    mov rdi, rsp
    lea rsi, [rip + .Lcounttext]
    call sb_push_cstr
    xor r14d, r14d
.Lbanner_count:
    test r14d, r14d
    jz .Lbanner_count_value
    mov rdi, rsp
    mov esi, '/'
    call sb_push_byte
.Lbanner_count_value:
    mov rdi, rsp
    mov esi, [r12 + DF_counts + r14*4]
    call sb_push_u64
    inc r14d
    cmp r14d, 5
    jb .Lbanner_count
    mov rdi, rsp
    lea rsi, [rip + .Lkeys]
    call sb_push_cstr
    mov eax, [r12 + DF_cursor]
    test eax, eax
    js .Lbanner_ready
    cmp rax, [r12 + DF_results + VEC_len]
    jae .Lbanner_ready
    imul r14, rax, DR_SIZE
    add r14, [r12 + DF_results + VEC_ptr]
    mov rdi, rsp
    lea rsi, [rip + .Lselected]
    call sb_push_cstr
    mov eax, [r14 + DR_status]
    lea rcx, [rip + diff_status_names]
    mov rsi, [rcx + rax*8]
    mov rdi, rsp
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r14
    call diff_inspector
.Lbanner_ready: mov r8, [rsp + SB_ptr]
    call diff_banner
    mov rdi, rsp
    call sb_free
    jmp .Loverlay_done
.Lbanner_text: call diff_banner
.Loverlay_done: EPILOGUE
# scene in rbx, text r8; persistent legend anchored below the toolbar.
FN diff_banner
    PROLOGUE
    mov r12, r8
    mov edi, [rbx + SC_x]
    mov esi, [rbx + SC_y]
    mov edx, [rbx + SC_w]
    mov ecx, 28
    COLOR r8d, T_BG
    call gfx_fill
    lea rdi, [rip + g_face_small]
    mov esi, [rbx + SC_x]
    add esi, 8
    mov edx, [rbx + SC_y]
    mov ecx, 24
    mov r8, r12
    COLOR r9d, T_ACCENT
    call ui_text_c
    EPILOGUE
.section .rodata
.globl diff_colors, diff_status_names, diff_reason_names
diff_colors: .long 0xff8da4ff, 0xffe567ed, 0xffff6b6b, 0xffffad55, 0xffa7aab5
diff_status_names: .quad .Lmatch,.Lghostname,.Lcontradiction,.Lmissing,.Lunknown
.Lmatch: .asciz "Structure matches"
.Lghostname: .asciz "Unconfirmed / Ghost"
.Lcontradiction: .asciz "Contradiction"
.Lmissing: .asciz "Omitted in complete scope"
.Lunknown: .asciz "Insufficient evidence (?)"
diff_reason_names: .quad .Lreason0,.Lreason1,.Lreason2,.Lreason3,.Lreason4,.Lreason5,.Lreason6,.Lreason7,.Lreason8,.Lreason9
.Lreason0: .asciz "Identity and asserted structure match; prose semantics are not verified."
.Lreason1: .asciz "AI object is absent from supplied Base; this does not prove absence from the ELF."
.Lreason2: .asciz "AI address contradicts the address bound to this source identity."
.Lreason3: .asciz "AI object kind contradicts the source kind."
.Lreason4: .asciz "AI requested size contradicts a declared known allocation size."
.Lreason5: .asciz "AI capacity contradicts a declared known allocation capacity."
.Lreason6: .asciz "AI lifetime state contradicts a declared known allocation state."
.Lreason7: .asciz "Source item was omitted from an answer marked complete within its scope."
.Lreason8: .asciz "AI typed transition differs from supplied edges; inspect source and target in the report."
.Lreason9: .asciz "The asserted size/capacity/state is not known in this source; confidence is not evidence."
.Lbanner: .asciz "Visual Diff | "
.Lstructure: .asciz "Structure"
.Lclaims: .asciz "Structure + Claims"
.Lfilters: .quad .Lstructure,.Lclaims
.Lcounttext: .asciz " | M/G/C/O/?="
.Lkeys: .asciz " | D/Shift+D: next/prev"
.Lselected: .asciz " | "
.Lstale_text: .asciz "Visual Diff STALE: source revision or snapshot changed; load claims for this source again."
.text
# Dashed outline iterates only within the current viewport.
FN diff_dashed_frame
    PROLOGUE 24
    mov ebx, edi
    mov r12d, esi
    lea r13d, [rdi + rdx]
    lea r14d, [rsi + rcx]
    mov r15d, r8d
    mov eax, [rip + g_cv + CV_cx0]
    cmp ebx, eax
    cmovl ebx, eax
    mov eax, [rip + g_cv + CV_cx1]
    cmp r13d, eax
    cmovg r13d, eax
    mov [rsp], edi
    mov [rsp + 4], r13d
    mov [rsp + 8], esi
    mov [rsp + 12], r14d
1:  cmp ebx, r13d
    jge 2f
    mov edi, ebx
    mov esi, r12d
    mov edx, 8
    mov ecx, 3
    mov r8d, r15d
    call gfx_fill
    mov edi, ebx
    lea esi, [r14 - 3]
    mov edx, 8
    mov ecx, 3
    mov r8d, r15d
    call gfx_fill
    add ebx, 16
    jmp 1b
2:  mov ebx, r12d
    mov eax, [rip + g_cv + CV_cy0]
    cmp ebx, eax
    cmovl ebx, eax
    mov eax, [rip + g_cv + CV_cy1]
    cmp r14d, eax
    cmovg r14d, eax
3:  cmp ebx, r14d
    jge 9f
    mov edi, [rsp]
    mov esi, ebx
    mov edx, 3
    mov ecx, 8
    mov r8d, r15d
    call gfx_fill
    mov edi, [rsp + 4]
    sub edi, 3
    mov esi, ebx
    mov edx, 3
    mov ecx, 8
    mov r8d, r15d
    call gfx_fill
    add ebx, 16
    jmp 3b
9:  EPILOGUE
FN diff_hatch
    PROLOGUE
    mov ebx, edi
    mov r12d, esi
    lea r13d, [rdi + rdx]
    mov r15d, r8d
    mov eax, [rip + g_cv + CV_cx0]
    cmp ebx, eax
    cmovl ebx, eax
    mov eax, [rip + g_cv + CV_cx1]
    cmp r13d, eax
    cmovg r13d, eax
1:  cmp ebx, r13d
    jge 9f
    mov edi, ebx
    lea esi, [r12 + 12]
    lea edx, [rbx + 10]
    lea ecx, [r12 + 2]
    mov r8d, r15d
    call canvas_line
    add ebx, 16
    jmp 1b
9:  EPILOGUE
# SB, graph, one-based index, type -> readable object/edge and asserted properties.
FN diff_item_text
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    test edx, edx
    jz .Litem_absent
    dec edx
    test ecx, ecx
    jnz .Litem_edge
    imul r13, rdx, DN_SIZE
    add r13, [r12 + DG_nodes + VEC_ptr]
    mov rdi, rbx
    mov rsi, [r13 + DN_id]
    call sb_push_cstr
    mov rdi, rbx
    lea rsi, [rip + .Lat]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, [r13 + DN_address]
    call sb_push_cstr
    mov r14d, DN_kind
    mov r15d, 1
.Litem_property:
    mov rdi, rbx
    mov esi, ' '
    call sb_push_byte
    cmp dword ptr [r13 + DN_known], 0
    je .Litem_property_value
    test [r13 + DN_known], r15d
    jnz .Litem_property_value
    mov rdi, rbx
    mov esi, '?'
    call sb_push_byte
    jmp .Litem_property_more
.Litem_property_value:
    mov rdi, rbx
    movsxd rsi, dword ptr [r13 + r14]
    call canvas_dump_int
.Litem_property_more:
    shl r15d, 1
    add r14d, 4
    cmp r14d, DN_state
    jbe .Litem_property
    mov rdi, rbx
    lea rsi, [rip + .Lconfidence_text]
    call sb_push_cstr
    mov rdi, rbx
    movsxd rsi, dword ptr [r13 + DN_confidence]
    call canvas_dump_int
    EPILOGUE
.Litem_edge:
    imul r13, rdx, DE_SIZE
    add r13, [r12 + DG_links + VEC_ptr]
    mov rdi, rbx
    mov rsi, [r13 + DE_from]
    call sb_push_cstr
    mov rdi, rbx
    lea rsi, [rip + .Larrowtext]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, [r13 + DE_to]
    call sb_push_cstr
    mov rdi, rbx
    lea rsi, [rip + .Lkindtext]
    call sb_push_cstr
    mov rdi, rbx
    mov esi, [r13 + DE_kind]
    call sb_push_u64
    EPILOGUE
.Litem_absent:
    mov rdi, rbx
    lea rsi, [rip + .Labsent]
    call sb_push_cstr
    EPILOGUE
FN diff_inspector
    PROLOGUE SB_SIZE
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rsp
    lea rsi, [rip + .Lbase_text]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, [r12 + DF_base]
    mov edx, [r13 + DR_base]
    mov ecx, [r13 + DR_type]
    call diff_item_text
    mov rdi, rsp
    lea rsi, [rip + .Lai_text]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, [r12 + DF_target]
    mov edx, [r13 + DR_target]
    mov ecx, [r13 + DR_type]
    call diff_item_text
    mov edi, [rbx + SC_x]
    mov esi, [rbx + SC_y]
    add esi, [rbx + SC_h]
    sub esi, 64
    mov edx, [rbx + SC_w]
    mov ecx, 64
    COLOR r8d, T_BG
    call gfx_fill
    mov eax, [r13 + DR_reason]
    lea rcx, [rip + diff_reason_names]
    mov r8, [rcx + rax*8]
    lea rdi, [rip + g_face_small]
    mov esi, [rbx + SC_x]
    add esi, 12
    mov edx, [rbx + SC_y]
    add edx, [rbx + SC_h]
    sub edx, 58
    mov ecx, 24
    COLOR r9d, T_FG
    call ui_text_c
    mov r8, [rsp + SB_ptr]
    lea rdi, [rip + g_face_small]
    mov esi, [rbx + SC_x]
    add esi, 12
    mov edx, [rbx + SC_y]
    add edx, [rbx + SC_h]
    sub edx, 30
    mov ecx, 24
    COLOR r9d, T_FG
    call ui_text_c
    mov rdi, rsp
    call sb_free
    EPILOGUE
.section .rodata
.Lat: .asciz " @ "
.Lconfidence_text: .asciz " confidence="
.Larrowtext: .asciz " -> "
.Lkindtext: .asciz " kind="
.Labsent: .asciz "(not present)"
.Lbase_text: .asciz "Base: "
.Lai_text: .asciz " | AI: "
