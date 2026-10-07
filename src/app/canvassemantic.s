.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN cmd_canvas_ui_row
    mov edi, U_ROW
    jmp canvas_ui_assign
FN cmd_canvas_ui_column
    mov edi, U_COLUMN
    jmp canvas_ui_assign
FN cmd_canvas_ui_card
    mov edi, U_CARD
    jmp canvas_ui_assign
FN cmd_canvas_ui_list
    mov edi, U_LIST
    jmp canvas_ui_assign
FN cmd_canvas_ui_text
    mov edi, U_TEXT
    jmp canvas_ui_assign
FN cmd_canvas_ui_button
    mov edi, U_BUTTON
    jmp canvas_ui_assign
FN cmd_canvas_ui_input
    mov edi, U_INPUT
    jmp canvas_ui_assign
FN cmd_canvas_ui_refresh
    mov edi, -1
    jmp canvas_ui_assign
FN cmd_canvas_ui_clear
    PROLOGUE
    call canvas_active
    test rax, rax
    jz 9f
    mov rbx, rax
    mov rdi, rbx
    call scene_clone
    mov r12, rax
    mov rdi, [rbx + SC_ui]
    call mem_free
    mov qword ptr [rbx + SC_ui], 0
    mov rdi, rbx
    mov rsi, r12
    call scene_commit
9:  EPILOGUE

# Initial tree uses a frame and its direct members. IDs are stable source IDs.
canvas_ui_assign:
    PROLOGUE SB_SIZE+16
    mov r15d, edi
    call canvas_active
    mov rbx, rax
    test rbx, rbx
    jz .Lassign_end
    cmp qword ptr [rbx + SC_before], 0
    jne .Lassign_end
    mov rdi, rbx
    mov rsi, [rbx + SC_selected]
    call scene_find
    test rax, rax
    jz .Lassign_end
    mov r14, rax
    mov rdi, rbx
    call canvas_ui_model
    mov r12, rax
    test rax, rax
    jnz .Lassign_selected
    mov r13, [r14 + CE_frame]
    test r13, r13
    jnz 1f
    mov r13, [r14 + CE_id]
1:  mov edi, UM_SIZE
    call mem_alloc
    mov r12, rax
    mov [rax + UM_root], r13
    xor r13d, r13d
2:  cmp r13, [rbx + SC_elements + VEC_len]
    jae .Lassign_selected
    imul r14, r13, CE_SIZE
    add r14, [rbx + SC_elements + VEC_ptr]
    mov rax, [r12 + UM_root]
    cmp rax, [r14 + CE_id]
    je 3f
    cmp rax, [r14 + CE_frame]
    jne 8f
    cmp dword ptr [r14 + CE_kind], CT_ARROW
    je 8f
    cmp dword ptr [r14 + CE_kind], CT_LINE
    je 8f
    cmp dword ptr [r14 + CE_kind], CT_STROKE
    jae 8f
3:  cmp qword ptr [r12 + UM_nodes + VEC_len], 512
    jae .Lassign_free
    lea rdi, [r12 + UM_nodes]
    mov esi, UC_SIZE
    call vec_push
    mov [rsp + SB_SIZE], rax
    mov rdi, rax
    xor esi, esi
    mov edx, UC_SIZE
    call memset
    mov rcx, [r14 + CE_id]
    mov [rax + UC_id], rcx
    mov [rax + UC_source], rcx
    mov edx, U_CARD
    cmp dword ptr [r14 + CE_kind], CT_TEXT
    jne 4f
    mov edx, U_TEXT
4:  mov [rax + UC_type], edx
    mov dword ptr [rax + UC_padding], 12
    mov dword ptr [rax + UC_gap], 8
    cmp rcx, [r12 + UM_root]
    jne 5f
    mov dword ptr [rax + UC_type], U_COLUMN
    mov ecx, [r14 + CE_w]
    mov [rax + UC_width], ecx
    mov ecx, [r14 + CE_h]
    mov [rax + UC_height], ecx
    jmp 6f
5:  mov rcx, [r12 + UM_root]
    mov [rax + UC_parent], rcx
6:  mov rdi, [r14 + CE_text]
    test rdi, rdi
    jnz 61f
    lea rdi, [rip + .Lempty]
61: mov [rsp + SB_SIZE + 8], rdi
    call strlen
    mov rsi, rax
    mov rdi, [rsp + SB_SIZE + 8]
    call mem_dup
    mov rcx, [rsp + SB_SIZE]
    mov [rcx + UC_text], rax
    lea rdi, [rip + .Lempty]
    xor esi, esi
    call mem_dup
    mov rcx, [rsp + SB_SIZE]
    mov [rcx + UC_action], rax
8:  inc r13
    jmp 2b
.Lassign_selected:
    mov rdi, r12
    mov rsi, [rbx + SC_selected]
    call canvas_ui_source
    test rax, rax
    jnz .Lassign_have_node
    cmp r15d, -1
    je .Lassign_free
    cmp qword ptr [r12 + UM_nodes + VEC_len], 512
    jae .Lassign_free
    mov rdi, rbx
    mov rsi, [rbx + SC_selected]
    call scene_find
    mov r14, rax
    lea rdi, [r12 + UM_nodes]
    mov esi, UC_SIZE
    call vec_push
    mov r13, rax
    mov rdi, rax
    xor esi, esi
    mov edx, UC_SIZE
    call memset
    mov rax, [r14 + CE_id]
    mov [r13 + UC_source], rax
    xor ecx, ecx
    mov rdx, [r12 + UM_nodes + VEC_ptr]
    mov r8, [r12 + UM_nodes + VEC_len]
201: test r8, r8
    jz 202f
    cmp rcx, [rdx + UC_id]
    jae 203f
    mov rcx, [rdx + UC_id]
203: add rdx, UC_SIZE
    dec r8
    jmp 201b
202: inc rcx
    mov [r13 + UC_id], rcx
    mov rax, [r12 + UM_root]
    mov [r13 + UC_parent], rax
    mov dword ptr [r13 + UC_padding], 12
    mov dword ptr [r13 + UC_gap], 8
    mov rdi, [r14 + CE_text]
    test rdi, rdi
    jnz 204f
    lea rdi, [rip + .Lempty]
204: mov [rsp + SB_SIZE], rdi
    call strlen
    mov rsi, rax
    mov rdi, [rsp + SB_SIZE]
    call mem_dup
    mov [r13 + UC_text], rax
    lea rdi, [rip + .Lempty]
    xor esi, esi
    call mem_dup
    mov [r13 + UC_action], rax
    mov rax, r13
.Lassign_have_node:
    cmp r15d, -1
    je 1f
    mov [rax + UC_type], r15d
1:  mov rax, [rbx + SC_revision]
    inc rax
    mov [r12 + UM_revision], rax
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, r12
    mov rsi, rsp
    call canvas_ui_serialize
    mov rdi, rbx
    call scene_clone
    mov r13, rax
    mov rdi, [rbx + SC_ui]
    call mem_free
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call mem_dup
    mov [rbx + SC_ui], rax
    mov rdi, rsp
    call sb_free
    mov rdi, rbx
    mov rsi, r13
    call scene_commit
.Lassign_free:
    mov rdi, r12
    call canvas_ui_free
.Lassign_end:
    EPILOGUE

FN cmd_canvas_ui_import
    lea rdi, [rip + .Limport_prompt]
    mov esi, 9
    jmp prompt_open
FN canvas_ui_import
    PROLOGUE
    mov r12, rdi
    call canvas_active
    mov rbx, rax
    test rax, rax
    jz 9f
    mov rdi, r12
    mov ecx, 1 << 20
    call file_read_limited
    test rax, rax
    jz 8f
    mov r12, rax
    mov r13, rdx
    mov rdi, rax
    mov rsi, rdx
    mov rdx, rbx
    call canvas_ui_parse
    test rax, rax
    jz 7f
    mov r14, rax
    mov rax, [rbx + SC_revision]
    inc rax
    cmp rax, [r14 + UM_revision]
    je 101f
    mov rdi, r14
    call canvas_ui_free
    jmp 7f
101:
    mov rdi, rbx
    call scene_clone
    mov r15, rax
    mov rdi, [rbx + SC_ui]
    call mem_free
    mov rdi, r12
    mov rsi, r13
    call mem_dup
    mov [rbx + SC_ui], rax
    mov rdi, rbx
    mov rsi, r15
    call scene_commit
    mov rdi, r14
    call canvas_ui_free
    mov rdi, r12
    call mem_free
    jmp 9f
7:  mov rdi, r12
    call mem_free
8:  lea rdi, [rip + .Linvalid]
    call app_toast
9:  EPILOGUE
.section .rodata
.Lempty: .asciz ""
.Limport_prompt: .asciz "Import semantic UI JSON path"
.Linvalid: .asciz "UI rejected: schema, source IDs, duplicate IDs, parent type or tree depth"

.text
# Explicit bidirectional navigation uses generated data-scene-id attributes.
FN cmd_canvas_ui_code
    PROLOGUE SB_SIZE
    call canvas_active
    mov rbx, rax
    test rax, rax
    jz 9f
    cmp qword ptr [rbx + SC_generated], 0
    je 9f
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rsp
    lea rsi, [rip + .Lsource_attr]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, [rbx + SC_selected]
    call sb_push_u64
    mov rdi, rsp
    mov esi, '"'
    call sb_push_byte
    mov rdi, [rbx + SC_generated]
    call app_open_path
    mov rbx, [rip + g_doc]
    test rbx, rbx
    jz 8f
    mov rdi, rbx
    call doc_contiguous
    mov r12, rax
    mov rdi, rbx
    call doc_len
    mov rsi, rax
    mov rdi, r12
    mov rdx, [rsp + SB_ptr]
    mov rcx, [rsp + SB_len]
    call str_find
    test rax, rax
    js 8f
    mov rdi, rbx
    mov rsi, rax
    xor edx, edx
    call ed_set_cursor
8:  mov rdi, rsp
    call sb_free
9:  EPILOGUE
FN cmd_canvas_ui_source
    PROLOGUE
    mov rbx, [rip + g_doc]
    test rbx, rbx
    jz 9f
    mov rdi, rbx
    mov rsi, [rbx + DOC_cur]
    call doc_line_of
    mov rdi, rbx
    mov rsi, rax
    call doc_line_text
    mov r12, rax
    mov rsi, rdx
    mov rdi, rax
    lea rdx, [rip + .Lsource_attr]
    mov ecx, 15
    call str_find
    test rax, rax
    js 9f
    lea rdi, [r12 + rax + 15]
    mov esi, 16
    call parse_u64
    test rax, rax
    jz 9f
    mov r12, rax
    xor r13d, r13d
1:  cmp r13, [rip + g_tabs + VEC_len]
    jae 9f
    mov rdi, r13
    call tab_at
    cmp qword ptr [rax + TAB_kind], TAB_CANVAS
    jne 8f
    mov rax, [rax + TAB_doc]
    mov r14, [rax + DOC_canvas]
    mov rdi, [r14 + SC_generated]
    test rdi, rdi
    jz 8f
    mov rsi, [rbx + DOC_path]
    test rsi, rsi
    jz 8f
    call strcmp_eq
    test eax, eax
    jz 8f
    mov rdi, r14
    mov rsi, r12
    call scene_find
    test rax, rax
    jz 9f
    mov rdi, r14
    call scene_deselect
    mov [r14 + SC_selected], r12
    mov rdi, r14
    mov rsi, r12
    call scene_find
    or dword ptr [rax + CE_flags], 1
    mov rdi, r13
    call app_activate_tab
    jmp 9f
8:  inc r13
    jmp 1b
9:  EPILOGUE
.section .rodata
.Lsource_attr: .asciz "data-scene-id=\""
