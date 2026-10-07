.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN canvas_undo
    PROLOGUE
    call canvas_cancel
    call canvas_active
    test rax, rax
    jz 9f
    mov rdi, rax
    call scene_undo
9:  EPILOGUE
FN canvas_redo
    PROLOGUE
    call canvas_cancel
    call canvas_active
    test rax, rax
    jz 9f
    mov rdi, rax
    call scene_redo
9:  EPILOGUE

FN canvas_cancel
    PROLOGUE
    call canvas_active
    mov rbx, rax
    test rbx, rbx
    jz 9f
    mov rdi, [rbx + SC_before]
    mov qword ptr [rbx + SC_before], 0
    call scene_free
    mov dword ptr [rbx + SC_gesture], 0
    mov qword ptr [rbx + SC_text_id], 0
    lea rdi, [rbx + SC_preview + CE_points]
    call vec_free
    mov dword ptr [rip + g_dirty], 1
9:  EPILOGUE

# Tool switching cancels a preview without touching committed elements.
FN canvas_set_tool
    PROLOGUE
    mov r12d, edi
    call canvas_cancel
    call canvas_active
    test rax, rax
    jz 9f
    mov [rax + SC_tool], r12d
    mov dword ptr [rip + g_dirty], 1
9:  EPILOGUE

FN canvas_edit_key
    PROLOGUE
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    call canvas_active
    mov rbx, rax
    cmp r12d, KEY_ESCAPE
    jne 1f
    call canvas_cancel
    jmp .Lkey_yes
1:  cmp qword ptr [rbx + SC_text_id], 0
    je .Lkey_tools
    cmp r12d, KEY_RETURN
    jne 11f
    test r14d, MOD_CTRL
    jz 11f
    call canvas_text_commit
    jmp .Lkey_yes
11: lea rdi, [rbx + SC_edit]
    mov esi, r12d
    mov edx, r13d
    mov ecx, r14d
    cmp qword ptr [rbx + SC_edit + TF_sb + SB_len], 65532
    jb 12f
    test r13d, r13d
    jnz .Lkey_yes
12: call ta_key
    test eax, eax
    jnz .Lkey_yes
    test r14d, MOD_CTRL | MOD_ALT | MOD_SUPER
    jz .Lkey_yes
    call canvas_text_commit
    jmp .Lkey_no
.Lkey_tools:
    cmp dword ptr [rbx + SC_gesture], 6
    jne 2f
    lea eax, [r12 - '1']
    cmp eax, 3
    ja .Lkey_yes
    inc eax
    mov [rbx + SC_node_type], eax
    mov rdi, rbx
    call canvas_node_commit
    jmp .Lkey_yes
2:  test r14d, MOD_CTRL | MOD_ALT | MOD_SUPER
    jnz .Lkey_no
    cmp r12d, KEY_DELETE
    je .Lkey_delete
    cmp r12d, KEY_BACKSPACE
    je .Lkey_delete
    cmp r12d, KEY_RETURN
    je .Lkey_edit_text
    lea r15, [rip + .Ltool_keys]
    xor ecx, ecx
3:  cmp ecx, 8
    jae .Lkey_yes
    cmp byte ptr [r15 + rcx], r12b
    je 4f
    inc ecx
    jmp 3b
4:  mov edi, ecx
    call canvas_set_tool
    jmp .Lkey_yes
.Lkey_edit_text:
    mov rdi, rbx
    mov rsi, [rbx + SC_selected]
    call scene_find
    test rax, rax
    jz .Lkey_yes
    cmp dword ptr [rax + CE_kind], CT_TEXT
    jne .Lkey_yes
    mov rsi, rax
    mov rdi, rbx
    call canvas_text_begin
    jmp .Lkey_yes
.Lkey_delete:
    mov rdi, rbx
    call canvas_delete
.Lkey_yes:
    mov dword ptr [rip + g_dirty], 1
    mov eax, 1
    EPILOGUE
.Lkey_no:
    xor eax, eax
    EPILOGUE

FN canvas_delete
    PROLOGUE
    mov rbx, rdi
    call scene_clone
    mov r12, rax
    xor r13d, r13d
    xor r15d, r15d
1:  cmp r13, [rbx + SC_elements + VEC_len]
    jae 3f
    imul r14, r13, CE_SIZE
    add r14, [rbx + SC_elements + VEC_ptr]
    test dword ptr [r14 + CE_flags], 1
    jz 2f
    mov rdi, [r14 + CE_text]
    call mem_free
    mov rdi, [r14 + CE_xid]
    call mem_free
    mov rdi, [r14 + CE_raw]
    call mem_free
    mov rdi, [r14 + CE_image]
    call mem_free
    mov rdi, [r14 + CE_gxid]
    call mem_free
    mov rdi, [r14 + CE_bitmap]
    call canvas_image_free
    lea rdi, [r14 + CE_points]
    call vec_free
    dec qword ptr [rbx + SC_elements + VEC_len]
    mov rdi, r14
    lea rsi, [r14 + CE_SIZE]
    mov rdx, [rbx + SC_elements + VEC_len]
    sub rdx, r13
    imul rdx, CE_SIZE
    call memmove
    mov r15d, 1
    jmp 1b
2:  inc r13
    jmp 1b
3:  test r15d, r15d
    jz 4f
    mov qword ptr [rbx + SC_selected], 0
    mov rdi, rbx
    mov rsi, r12
    call scene_commit
    EPILOGUE
4:  mov rdi, r12
    call scene_free
    EPILOGUE

FN canvas_text_begin
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    call scene_clone
    mov [rbx + SC_before], rax
    mov rax, [r12 + CE_id]
    mov [rbx + SC_text_id], rax
    lea rdi, [rbx + SC_preview]
    mov rsi, r12
    mov edx, CE_SIZE
    call memcpy
    # Preview borrows geometry only, never an owned pointer.
    mov qword ptr [rbx + SC_preview + CE_text], 0
    mov qword ptr [rbx + SC_preview + CE_xid], 0
    mov qword ptr [rbx + SC_preview + CE_raw], 0
    mov qword ptr [rbx + SC_preview + CE_image], 0
    mov qword ptr [rbx + SC_preview + CE_gxid], 0
    mov qword ptr [rbx + SC_preview + CE_bitmap], 0
    lea rdi, [rbx + SC_preview + CE_points]
    xor esi, esi
    mov edx, VEC_SIZE
    call memset
    mov rdi, [r12 + CE_text]
    xor edx, edx
    test rdi, rdi
    jz 1f
    call strlen
    mov rdx, rax
1:  mov rsi, [r12 + CE_text]
    lea rdi, [rbx + SC_edit]
    call tf_set
    EPILOGUE

FN canvas_text_commit
    PROLOGUE
    call canvas_active
    mov rbx, rax
    test rbx, rbx
    jz 9f
    cmp qword ptr [rbx + SC_text_id], 0
    je 9f
    cmp qword ptr [rbx + SC_edit + TF_sb + SB_len], 65536
    ja 9f
    mov rdi, rbx
    mov rsi, [rbx + SC_text_id]
    call scene_find
    test rax, rax
    jnz 1f
    cmp qword ptr [rbx + SC_elements + VEC_len], 4096
    jae 9f
    mov rdi, rbx
    mov esi, CT_TEXT
    mov edx, [rbx + SC_preview + CE_x]
    mov ecx, [rbx + SC_preview + CE_y]
    mov r8d, 240
    mov r9d, 96
    call scene_add
1:  mov r12, rax
    mov rdi, [r12 + CE_text]
    call mem_free
    mov rdi, [rbx + SC_edit + TF_sb + SB_ptr]
    mov rsi, [rbx + SC_edit + TF_sb + SB_len]
    call mem_dup
    mov [r12 + CE_text], rax
    mov qword ptr [rbx + SC_text_id], 0
    mov rsi, [rbx + SC_before]
    mov qword ptr [rbx + SC_before], 0
    mov rdi, rbx
    call scene_commit
9:  EPILOGUE

FN canvas_paste
    PROLOGUE
    mov r12, rdi
    mov r13, rsi
    call canvas_active
    test rax, rax
    jz 9f
    cmp qword ptr [rax + SC_text_id], 0
    je 9f
    mov rdi, [rax + SC_edit + TF_sb + SB_len]
    add rdi, r13
    cmp rdi, 65536
    ja 9f
    lea rdi, [rax + SC_edit]
    mov rsi, r12
    mov rdx, r13
    call ta_insert_keep_tabs
9:  EPILOGUE

# Pointer editing: keep a separate preview, apply once at release.
FN canvas_edit_input
    PROLOGUE
    mov rbx, rdi
    cmp dword ptr [rip + g_focus], FOCUS_EDITOR
    jne 9f
    cmp qword ptr [rbx + SC_text_id], 0
    jne 9f
    cmp dword ptr [rbx + SC_gesture], 6
    je 9f
    mov rdi, rbx
    mov esi, [rip + g_mx]
    mov edx, [rip + g_my]
    call scene_to_world
    mov r12d, eax
    mov r13d, edx
    cmp r12d, -999000
    jl 9f
    cmp r12d, 999000
    jg 9f
    cmp r13d, -999000
    jl 9f
    cmp r13d, 999000
    jg 9f
    cmp dword ptr [rbx + SC_gesture], 0
    jne .Lgesture_update
    mov edi, [rbx + SC_x]
    mov esi, [rbx + SC_y]
    mov edx, [rbx + SC_w]
    mov ecx, [rbx + SC_h]
    call ui_in
    test eax, eax
    jz 9f
    test dword ptr [rip + g_pressed], 1 << BTN_LEFT
    jz 9f
    mov [rbx + SC_gx], r12d
    mov [rbx + SC_gy], r13d
    mov dword ptr [rbx + SC_dx], 0
    mov dword ptr [rbx + SC_dy], 0
    cmp dword ptr [rbx + SC_tool], CT_SELECT
    je .Lgesture_select
    mov rdi, rbx
    call scene_clone
    mov [rbx + SC_before], rax
    lea rdi, [rbx + SC_preview]
    xor esi, esi
    mov edx, CE_SIZE
    call memset
    mov eax, [rbx + SC_tool]
    mov [rbx + SC_preview + CE_kind], eax
    mov [rbx + SC_preview + CE_x], r12d
    mov [rbx + SC_preview + CE_y], r13d
    mov dword ptr [rbx + SC_preview + CE_color], 0xff8da4ff
    cmp eax, CT_TEXT
    jne 1f
    mov rax, [rbx + SC_next_id]
    mov [rbx + SC_text_id], rax
    lea rdi, [rbx + SC_edit]
    call tf_clear
    jmp 9f
1:  cmp eax, CT_ARROW
    jne 2f
    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    call scene_hit
    test rax, rax
    jz 2f
    mov rax, [rax + CE_id]
    mov [rbx + SC_preview + CE_from], rax
2:  mov dword ptr [rbx + SC_gesture], 1
    jmp .Lgesture_update
.Lgesture_select:
    # Selected node exposes a plus hotspot outside its right edge.
    mov rdi, rbx
    mov rsi, [rbx + SC_selected]
    call scene_find
    test rax, rax
    jz .Lselect_hit
    mov r14, rax
    mov eax, 10*65536
    xor edx, edx
    div dword ptr [rbx + SC_zoom]
    mov r15d, eax
    mov eax, [r14 + CE_x]
    add eax, [r14 + CE_w]
    add eax, r15d
    sub eax, r12d
    cdq
    xor eax, edx
    sub eax, edx
    cmp eax, r15d
    jg .Lselect_resize
    mov eax, [r14 + CE_h]
    sar eax, 1
    add eax, [r14 + CE_y]
    sub eax, r13d
    cdq
    xor eax, edx
    sub eax, edx
    cmp eax, r15d
    jg .Lselect_resize
    cmp dword ptr [r14 + CE_kind], CT_ARROW
    je .Lselect_hit
    mov rdi, rbx
    call scene_clone
    mov [rbx + SC_before], rax
    mov dword ptr [rbx + SC_gesture], 5
    mov dword ptr [rbx + SC_node_type], 1
    jmp .Lgesture_update
.Lselect_resize:
    mov eax, [r14 + CE_x]
    add eax, [r14 + CE_w]
    sub eax, r12d
    cdq
    xor eax, edx
    sub eax, edx
    cmp eax, r15d
    jg .Lselect_hit
    mov eax, [r14 + CE_y]
    add eax, [r14 + CE_h]
    sub eax, r13d
    cdq
    xor eax, edx
    sub eax, edx
    cmp eax, r15d
    jg .Lselect_hit
    mov rdi, rbx
    call scene_clone
    mov [rbx + SC_before], rax
    mov dword ptr [rbx + SC_gesture], 4
    jmp .Lgesture_update
.Lselect_hit:
    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    call scene_hit
    mov r14, rax
    test r14, r14
    jz .Lselect_marquee
    test dword ptr [rip + g_mods], MOD_SHIFT
    jnz 3f
    test dword ptr [r14 + CE_flags], 1
    jnz 4f
    mov rdi, rbx
    call scene_deselect
3:  xor dword ptr [r14 + CE_flags], 1
4:  mov rax, [r14 + CE_id]
    mov [rbx + SC_selected], rax
    mov rdi, rbx
    call scene_expand_selection
    mov rdi, rbx
    call scene_clone
    mov [rbx + SC_before], rax
    mov dword ptr [rbx + SC_gesture], 2
    jmp .Lgesture_update
.Lselect_marquee:
    test dword ptr [rip + g_mods], MOD_SHIFT
    jnz 5f
    mov rdi, rbx
    call scene_deselect
5:  mov dword ptr [rbx + SC_gesture], 3
.Lgesture_update:
    mov eax, r12d
    sub eax, [rbx + SC_gx]
    mov [rbx + SC_dx], eax
    mov eax, r13d
    sub eax, [rbx + SC_gy]
    mov [rbx + SC_dy], eax
    cmp dword ptr [rbx + SC_gesture], 1
    jne .Lgesture_release
    mov eax, [rbx + SC_preview + CE_kind]
    cmp eax, CT_STROKE
    jne 6f
    cmp qword ptr [rbx + SC_preview + CE_points + VEC_len], 8192
    jae .Lgesture_release
    lea rdi, [rbx + SC_preview + CE_points]
    mov esi, 8
    call vec_push
    mov ecx, [rbx + SC_dx]
    mov [rax], ecx
    mov ecx, [rbx + SC_dy]
    mov [rax + 4], ecx
6:  mov eax, [rbx + SC_dx]
    mov [rbx + SC_preview + CE_w], eax
    mov eax, [rbx + SC_dy]
    mov [rbx + SC_preview + CE_h], eax
.Lgesture_release:
    test dword ptr [rip + g_released], 1 << BTN_LEFT
    jz 9f
    cmp dword ptr [rbx + SC_gesture], 5
    jne 7f
    mov dword ptr [rbx + SC_gesture], 6
    jmp 9f
7:  mov rdi, rbx
    call canvas_gesture_commit
9:  EPILOGUE

FN canvas_gesture_commit
    PROLOGUE
    mov rbx, rdi
    cmp dword ptr [rbx + SC_gesture], 3
    je .Lcommit_marquee
    mov eax, [rbx + SC_dx]
    or eax, [rbx + SC_dy]
    jnz 11f
    cmp dword ptr [rbx + SC_preview + CE_kind], CT_STROKE
    jne .Lcommit_cancel
    cmp qword ptr [rbx + SC_preview + CE_points + VEC_len], 2
    jb .Lcommit_cancel
11:
    cmp dword ptr [rbx + SC_gesture], 1
    je .Lcommit_create
    xor r12d, r12d
1:  cmp r12, [rbx + SC_elements + VEC_len]
    jae .Lcommit_done
    imul r13, r12, CE_SIZE
    add r13, [rbx + SC_elements + VEC_ptr]
    test dword ptr [r13 + CE_flags], 1
    jz 3f
    cmp dword ptr [rbx + SC_gesture], 4
    je 2f
    mov eax, [rbx + SC_dx]
    add [r13 + CE_x], eax
    mov eax, [rbx + SC_dy]
    add [r13 + CE_y], eax
    jmp 3f
2:  mov eax, [r13 + CE_w]
    add eax, [rbx + SC_dx]
    mov ecx, 8
    cmp eax, ecx
    cmovl eax, ecx
    mov [r13 + CE_w], eax
    mov eax, [r13 + CE_h]
    add eax, [rbx + SC_dy]
    cmp eax, ecx
    cmovl eax, ecx
    mov [r13 + CE_h], eax
3:  inc r12
    jmp 1b
.Lcommit_create:
    cmp qword ptr [rbx + SC_elements + VEC_len], 4096
    jae .Lcommit_cancel
    mov r12d, [rbx + SC_preview + CE_kind]
    cmp r12d, CT_ARROW
    je 4f
    cmp r12d, CT_LINE
    je 5f
    cmp r12d, CT_STROKE
    je 5f
    # Normalize rectangular tools, require visible extent.
    mov eax, [rbx + SC_preview + CE_w]
    test eax, eax
    jns 31f
    add [rbx + SC_preview + CE_x], eax
    neg eax
    mov [rbx + SC_preview + CE_w], eax
31: cmp eax, 8
    jl .Lcommit_cancel
    mov eax, [rbx + SC_preview + CE_h]
    test eax, eax
    jns 32f
    add [rbx + SC_preview + CE_y], eax
    neg eax
    mov [rbx + SC_preview + CE_h], eax
32: cmp eax, 8
    jl .Lcommit_cancel
    jmp 5f
4:  mov rdi, rbx
    mov esi, [rbx + SC_gx]
    add esi, [rbx + SC_dx]
    mov edx, [rbx + SC_gy]
    add edx, [rbx + SC_dy]
    call scene_hit
    test rax, rax
    jz 5f
    cmp dword ptr [rax + CE_kind], CT_ARROW
    je 5f
    mov rax, [rax + CE_id]
    cmp rax, [rbx + SC_preview + CE_from]
    je 5f
    mov [rbx + SC_preview + CE_to], rax
5:  mov rdi, rbx
    mov esi, r12d
    mov edx, [rbx + SC_preview + CE_x]
    mov ecx, [rbx + SC_preview + CE_y]
    mov r8d, [rbx + SC_preview + CE_w]
    mov r9d, [rbx + SC_preview + CE_h]
    call scene_add
    mov r13, rax
    mov rcx, [rbx + SC_preview + CE_from]
    mov [rax + CE_from], rcx
    mov rcx, [rbx + SC_preview + CE_to]
    mov [rax + CE_to], rcx
    lea rdi, [rax + CE_points]
    lea rsi, [rbx + SC_preview + CE_points]
    mov edx, VEC_SIZE
    call memcpy
    lea rdi, [rbx + SC_preview + CE_points]
    xor esi, esi
    mov edx, VEC_SIZE
    call memset
    mov rdi, rbx
    call scene_deselect
    mov dword ptr [r13 + CE_flags], 1
    mov rax, [r13 + CE_id]
    mov [rbx + SC_selected], rax
.Lcommit_done:
    mov rdi, rbx
    mov rsi, [rbx + SC_before]
    mov qword ptr [rbx + SC_before], 0
    mov dword ptr [rbx + SC_gesture], 0
    call scene_commit
    EPILOGUE
.Lcommit_marquee:
    mov r12d, [rbx + SC_gx]
    mov r13d, [rbx + SC_gy]
    mov r14d, r12d
    add r14d, [rbx + SC_dx]
    mov r15d, r13d
    add r15d, [rbx + SC_dy]
    cmp r12d, r14d
    jle 6f
    xchg r12d, r14d
6:  cmp r13d, r15d
    jle 7f
    xchg r13d, r15d
7:  mov rcx, [rbx + SC_elements + VEC_len]
    mov rax, [rbx + SC_elements + VEC_ptr]
8:  test rcx, rcx
    jz 9f
    cmp [rax + CE_x], r12d
    jl 81f
    cmp [rax + CE_y], r13d
    jl 81f
    mov edx, [rax + CE_x]
    add edx, [rax + CE_w]
    cmp edx, r14d
    jg 81f
    mov edx, [rax + CE_y]
    add edx, [rax + CE_h]
    cmp edx, r15d
    jg 81f
    mov dword ptr [rax + CE_flags], 1
    mov rdx, [rax + CE_id]
    mov [rbx + SC_selected], rdx
81: add rax, CE_SIZE
    dec rcx
    jmp 8b
9:  mov dword ptr [rbx + SC_gesture], 0
    EPILOGUE
.Lcommit_cancel:
    call canvas_cancel
    EPILOGUE

# Pending plus gesture: choose role 1..4, then node + arrow is one transaction.
FN canvas_node_commit
    PROLOGUE
    mov rbx, rdi
    cmp qword ptr [rbx + SC_elements + VEC_len], 4094
    ja 8f
    mov rdi, rbx
    mov esi, [rbx + SC_gx]
    add esi, [rbx + SC_dx]
    mov edx, [rbx + SC_gy]
    add edx, [rbx + SC_dy]
    call scene_hit
    test rax, rax
    jz 1f
    cmp dword ptr [rax + CE_kind], CT_ARROW
    je 1f
    mov r12, [rax + CE_id]
    cmp r12, [rbx + SC_selected]
    je 8f
    jmp 2f
1:  mov rdi, rbx
    mov esi, CT_ELLIPSE
    mov edx, [rbx + SC_gx]
    add edx, [rbx + SC_dx]
    sub edx, 60
    mov ecx, [rbx + SC_gy]
    add ecx, [rbx + SC_dy]
    sub ecx, 32
    mov r8d, 120
    mov r9d, 64
    call scene_add
    mov r12, [rax + CE_id]
    mov ecx, [rbx + SC_node_type]
    mov [rax + CE_role], rcx
2:  mov rdi, rbx
    mov esi, CT_ARROW
    mov edx, [rbx + SC_gx]
    mov ecx, [rbx + SC_gy]
    mov r8d, [rbx + SC_dx]
    mov r9d, [rbx + SC_dy]
    call scene_add
    mov rcx, [rbx + SC_selected]
    mov [rax + CE_from], rcx
    mov [rax + CE_to], r12
    mov ecx, [rbx + SC_node_type]
    mov [rax + CE_role], rcx
    jmp .Lcommit_done
8:  call canvas_cancel
    EPILOGUE
.section .rodata
.Ltool_keys: .ascii "sreatflp"
