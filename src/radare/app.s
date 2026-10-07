.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN radare_open_scene
    PROLOGUE
    mov rbx, rdi
    call doc_new
    mov [rax + DOC_canvas], rbx
    mov [rbx + SC_doc], rax
    lea rcx, [rip + .Ltab]
    mov [rax + DOC_name], rcx
    mov rdi, rax
    mov esi, TAB_CANVAS
    call app_add_tab
    EPILOGUE
FN cmd_radare_demo
    PROLOGUE
    lea rdi, [rip + .Ldemo]
    mov esi, .Ldemo_end - .Ldemo
    call radare_import_stream
    test rax, rax
    jz .Ldemo_bad
    mov rdi, rax
    call radare_open_scene
    EPILOGUE
.Ldemo_bad: lea rdi, [rip + .Linvalid]
    call app_toast
    EPILOGUE
FN cmd_radare_import
    lea rdi, [rip + .Lprompt]
    mov esi, 12
    jmp prompt_open
FN radare_import_file
    PROLOGUE
    mov ecx, 8 << 20
    call file_read_limited
    test rax, rax
    jz .Lfile_bad
    mov rbx, rax
    mov rdi, rax
    mov rsi, rdx
    call radare_import_stream
    mov r12, rax
    mov rdi, rbx
    call mem_free
    test r12, r12
    jz .Lfile_bad
    mov rdi, r12
    call radare_open_scene
    EPILOGUE
.Lfile_bad: lea rdi, [rip + .Linvalid]
    call app_toast
    EPILOGUE
FN radare_frame_label
    cmp dword ptr [rsi + CE_kind], CT_FRAME
    jne .Llabel_ret
    mov rax, [rdi + SC_analysis]
    test rax, rax
    jz .Llabel_ret
    cmp byte ptr [rax], 0
    je .Llabel_ret
    PROLOGUE
    mov rbx, rsi
    mov esi, [rbx + CE_x]
    add esi, 12
    mov edx, [rbx + CE_y]
    add edx, 10
    call scene_to_screen
    mov esi, eax
    lea rdi, [rip + g_face_small]
    mov ecx, 24
    mov r8, [rbx + CE_text]
    COLOR r9d, T_ACCENT
    call ui_text_c
    EPILOGUE
.Llabel_ret: ret
FN cmd_radare_next_function
    PROLOGUE 16
    call canvas_active
    mov rbx, rax
    test rax, rax
    jz .Lnext_done
    cmp qword ptr [rax + SC_analysis], 0
    je .Lnext_done
    mov rsi, [rax + SC_selected]
    mov rdi, rax
    call scene_find
    xor r12d, r12d
    test rax, rax
    jz .Lnext_scan_start
    mov r12, [rax + CE_id]
    cmp dword ptr [rax + CE_kind], CT_FRAME
    je .Lnext_scan_start
    mov r12, [rax + CE_frame]
.Lnext_scan_start:
    xor r13d, r13d
    xor r14d, r14d
    xor r15d, r15d
.Lnext_scan:
    cmp r13, [rbx + SC_elements + VEC_len]
    jae .Lnext_wrap
    imul rax, r13, CE_SIZE
    add rax, [rbx + SC_elements + VEC_ptr]
    cmp dword ptr [rax + CE_kind], CT_FRAME
    jne .Lnext_scan_more
    mov [rsp], rax
    mov rdi, [rax + CE_gxid]
    test rdi, rdi
    jz .Lnext_scan_more
    lea rsi, [rip + r2_function_marker]
    call strcmp_eq
    test eax, eax
    jz .Lnext_scan_more
    mov rax, [rsp]
    test r14, r14
    jnz .Lnext_candidate
    mov r14, rax
.Lnext_candidate:
    test r12, r12
    jz .Lnext_focus
    test r15d, r15d
    jnz .Lnext_focus
    cmp [rax + CE_id], r12
    jne .Lnext_scan_more
    mov r15d, 1
.Lnext_scan_more: inc r13
    jmp .Lnext_scan
.Lnext_wrap: mov rax, r14
    test rax, rax
    jz .Lnext_done
.Lnext_focus:
    mov r12, rax
    mov rdi, rbx
    call scene_deselect
    mov rax, [r12 + CE_id]
    mov [rbx + SC_selected], rax
    or dword ptr [r12 + CE_flags], 1
    mov eax, 20
    sub eax, [r12 + CE_x]
    mov [rbx + SC_pan_x], eax
    mov eax, 20
    sub eax, [r12 + CE_y]
    mov [rbx + SC_pan_y], eax
    mov dword ptr [rip + g_dirty], 1
.Lnext_done: EPILOGUE
.section .rodata
.Ltab: .asciz "Radare2 CFG"
.Lprompt: .asciz "Import Radare2 agfj JSON"
.Linvalid: .asciz "Radare2: invalid CFG or limits exceeded; existing tabs kept"
.Ldemo: .incbin "examples/radare2/branch-demo.agfj.json"
.Ldemo_end:
