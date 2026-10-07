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
    call radare_import
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
    call radare_import
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
.section .rodata
.Ltab: .asciz "Radare2 CFG"
.Lprompt: .asciz "Import Radare2 agfj JSON"
.Linvalid: .asciz "Radare2: invalid CFG or limits exceeded; existing tabs kept"
.Ldemo: .incbin "examples/radare2/branch-demo.agfj.json"
.Ldemo_end:
