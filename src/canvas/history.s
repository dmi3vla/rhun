.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN scene_clear_elements
    PROLOGUE
    mov rbx, rdi
    xor r12d, r12d
1:  cmp r12, [rbx + SC_elements + VEC_len]
    jae 2f
    imul r13, r12, CE_SIZE
    add r13, [rbx + SC_elements + VEC_ptr]
    mov rdi, [r13 + CE_text]
    call mem_free
    mov rdi, [r13 + CE_xid]
    call mem_free
    mov rdi, [r13 + CE_raw]
    call mem_free
    mov rdi, [r13 + CE_image]
    call mem_free
    mov rdi, [r13 + CE_gxid]
    call mem_free
    mov rdi, [r13 + CE_bitmap]
    call canvas_image_free
    lea rdi, [r13 + CE_points]
    call vec_free
    inc r12
    jmp 1b
2:  lea rdi, [rbx + SC_elements]
    call vec_free
    EPILOGUE

# Deep copy content; snapshots own their text and points, never histories.
FN scene_clone
    PROLOGUE
    mov rbx, rdi
    call scene_new
    mov r12, rax
    mov rax, [rbx + SC_next_id]
    mov [r12 + SC_next_id], rax
    mov rax, [rbx + SC_revision]
    mov [r12 + SC_revision], rax
    mov rax, [rbx + SC_hash]
    mov [r12 + SC_hash], rax
    mov rax, [rbx + SC_selected]
    mov [r12 + SC_selected], rax
    mov qword ptr [r12 + SC_bytes], SC_SIZE
    mov rdi, [rbx + SC_exchange]
    test rdi, rdi
    jz 10f
    call strlen
    lea rcx, [rax + 1]
    add [r12 + SC_bytes], rcx
    mov rsi, rax
    mov rdi, [rbx + SC_exchange]
    call mem_dup
    mov [r12 + SC_exchange], rax
10:
    mov rdi, [rbx + SC_ui]
    test rdi, rdi
    jz 11f
    call strlen
    lea rcx, [rax + 1]
    add [r12 + SC_bytes], rcx
    mov rsi, rax
    mov rdi, [rbx + SC_ui]
    call mem_dup
    mov [r12 + SC_ui], rax
11:
    mov rdi, [rbx + SC_graph]
    test rdi, rdi
    jz 12f
    call strlen
    lea rcx, [rax + 1]
    add [r12 + SC_bytes], rcx
    mov rsi, rax
    mov rdi, [rbx + SC_graph]
    call mem_dup
    mov [r12 + SC_graph], rax
12:
    mov rdi, [rbx + SC_analysis]
    test rdi, rdi
    jz .Lclone_analysis_done
    call strlen
    lea rcx, [rax + 1]
    add [r12 + SC_bytes], rcx
    mov rsi, rax
    mov rdi, [rbx + SC_analysis]
    call mem_dup
    mov [r12 + SC_analysis], rax
.Lclone_analysis_done:
    mov rdi, [rbx + SC_memory]
    test rdi, rdi
    jz .Lclone_memory_done
    call strlen
    lea rcx, [rax + 1]
    add [r12 + SC_bytes], rcx
    mov rsi, rax
    mov rdi, [rbx + SC_memory]
    call mem_dup
    mov [r12 + SC_memory], rax
.Lclone_memory_done:
    xor r13d, r13d
1:  cmp r13, [rbx + SC_elements + VEC_len]
    jae 9f
    imul r14, r13, CE_SIZE
    add r14, [rbx + SC_elements + VEC_ptr]
    lea rdi, [r12 + SC_elements]
    mov esi, CE_SIZE
    call vec_push
    mov r15, rax
    mov rdi, rax
    mov rsi, r14
    mov edx, CE_SIZE
    call memcpy
    mov qword ptr [r15 + CE_text], 0
    mov qword ptr [r15 + CE_xid], 0
    mov qword ptr [r15 + CE_raw], 0
    mov qword ptr [r15 + CE_image], 0
    mov qword ptr [r15 + CE_gxid], 0
    mov qword ptr [r15 + CE_bitmap], 0
    and dword ptr [r15 + CE_flags], -3
    lea rdi, [r15 + CE_points]
    xor esi, esi
    mov edx, VEC_SIZE
    call memset
    add qword ptr [r12 + SC_bytes], CE_SIZE
    mov rdi, [r14 + CE_text]
    test rdi, rdi
    jz 2f
    call strlen
    lea rcx, [rax + 1]
    add [r12 + SC_bytes], rcx
    mov rsi, rax
    mov rdi, [r14 + CE_text]
    call mem_dup
    mov [r15 + CE_text], rax
2:  mov rdi, r12
    mov rsi, r14
    mov rdx, r15
    call scene_clone_extra
    mov rsi, [r14 + CE_points + VEC_len]
    test rsi, rsi
    jz 3f
    shl rsi, 3
    add [r12 + SC_bytes], rsi
    mov rdi, [r14 + CE_points + VEC_ptr]
    call mem_dup
    mov [r15 + CE_points + VEC_ptr], rax
    mov rax, [r14 + CE_points + VEC_len]
    mov [r15 + CE_points + VEC_len], rax
    mov [r15 + CE_points + VEC_cap], rax
3:  inc r13
    jmp 1b
9:  mov rax, r12
    EPILOGUE

FN scene_history_clear
    PROLOGUE
    mov rbx, rdi
    xor r12d, r12d
1:  cmp r12, [rbx + VEC_len]
    jae 2f
    mov rax, [rbx + VEC_ptr]
    mov rdi, [rax + r12*8]
    call scene_free
    inc r12
    jmp 1b
2:  mov rdi, rbx
    call vec_free
    EPILOGUE

# Push owned snapshot; cap combined history to 32 entries and 16 MiB.
scene_history_push:
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov esi, 8
    call vec_push
    mov [rax], r12
1:  xor r13d, r13d
    xor r14d, r14d
2:  cmp r13, [rbx + VEC_len]
    jae 3f
    mov rax, [rbx + VEC_ptr]
    mov rax, [rax + r13*8]
    add r14, [rax + SC_bytes]
    inc r13
    jmp 2b
3:  cmp r13, 32
    ja 4f
    cmp r14, 16 << 20
    jbe 9f
4:  mov rax, [rbx + VEC_ptr]
    mov rdi, [rax]
    call scene_free
    dec qword ptr [rbx + VEC_len]
    mov rdi, [rbx + VEC_ptr]
    lea rsi, [rdi + 8]
    mov rdx, [rbx + VEC_len]
    shl rdx, 3
    call memmove
    jmp 1b
9:  EPILOGUE

# Commit(scene, owned before snapshot). Revision never goes backwards.
FN scene_commit
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov rdi, rbx
    call scene_update_bindings
    mov rdi, rbx
    call scene_validate
    test eax, eax
    jz .Lcommit_invalid
    lea rdi, [rbx + SC_redo]
    call scene_history_clear
    lea rdi, [rbx + SC_undo]
    mov rsi, r12
    call scene_history_push
    inc qword ptr [rbx + SC_revision]
    mov rax, [rbx + SC_revision]
    mov [rbx + SC_hash], rax
    mov rdi, rbx
    call scene_trim_history
    mov dword ptr [rip + g_dirty], 1
    mov eax, 1
    EPILOGUE
.Lcommit_invalid:
    mov rdi, rbx
    call scene_clear_elements
    lea rdi, [rbx + SC_elements]
    lea rsi, [r12 + SC_elements]
    mov edx, VEC_SIZE
    call memcpy
    lea rdi, [r12 + SC_elements]
    xor esi, esi
    mov edx, VEC_SIZE
    call memset
    mov rax, [r12 + SC_selected]
    mov [rbx + SC_selected], rax
    mov rdi, [rbx + SC_exchange]
    call mem_free
    mov rax, [r12 + SC_exchange]
    mov [rbx + SC_exchange], rax
    mov qword ptr [r12 + SC_exchange], 0
    mov rdi, [rbx + SC_ui]
    call mem_free
    mov rax, [r12 + SC_ui]
    mov [rbx + SC_ui], rax
    mov qword ptr [r12 + SC_ui], 0
    mov rdi, [rbx + SC_graph]
    call mem_free
    mov rdi, [rbx + SC_graph_view]
    call canvas_graph_free
    mov qword ptr [rbx + SC_graph_view], 0
    mov rax, [r12 + SC_graph]
    mov [rbx + SC_graph], rax
    mov qword ptr [r12 + SC_graph], 0
    mov rdi, [rbx + SC_analysis]
    call mem_free
    mov rax, [r12 + SC_analysis]
    mov [rbx + SC_analysis], rax
    mov qword ptr [r12 + SC_analysis], 0
    mov rdi, [rbx + SC_memory]
    call mem_free
    mov rax, [r12 + SC_memory]
    mov [rbx + SC_memory], rax
    mov qword ptr [r12 + SC_memory], 0
    mov rdi, [rbx + SC_memory_view]
    call memory_free
    mov qword ptr [rbx + SC_memory_view], 0
    mov dword ptr [rbx + SC_trace_cursor], 0
    mov rdi, rbx
    call canvas_graph_validate
    mov rdi, r12
    call scene_free
    lea rdi, [rip + .Lbounds_error]
    call app_toast
    xor eax, eax
    EPILOGUE

FN scene_undo
    lea rsi, [rdi + SC_undo]
    lea rdx, [rdi + SC_redo]
    jmp scene_history_restore
FN scene_redo
    lea rsi, [rdi + SC_redo]
    lea rdx, [rdi + SC_undo]
scene_history_restore:
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    cmp qword ptr [r12 + VEC_len], 0
    je 9f
    call scene_clone
    mov rdi, r13
    mov rsi, rax
    call scene_history_push
    dec qword ptr [r12 + VEC_len]
    mov rax, [r12 + VEC_ptr]
    mov rcx, [r12 + VEC_len]
    mov r14, [rax + rcx*8]
    mov rdi, rbx
    call scene_clear_elements
    lea rdi, [rbx + SC_elements]
    lea rsi, [r14 + SC_elements]
    mov edx, VEC_SIZE
    call memcpy
    lea rdi, [r14 + SC_elements]
    xor esi, esi
    mov edx, VEC_SIZE
    call memset
    mov rax, [r14 + SC_hash]
    mov [rbx + SC_hash], rax
    mov rax, [r14 + SC_selected]
    mov [rbx + SC_selected], rax
    inc qword ptr [rbx + SC_revision]
    mov rdi, [rbx + SC_exchange]
    call mem_free
    mov rax, [r14 + SC_exchange]
    mov [rbx + SC_exchange], rax
    mov qword ptr [r14 + SC_exchange], 0
    mov rdi, [rbx + SC_ui]
    call mem_free
    mov rax, [r14 + SC_ui]
    mov [rbx + SC_ui], rax
    mov qword ptr [r14 + SC_ui], 0
    mov rdi, [rbx + SC_graph]
    call mem_free
    mov rdi, [rbx + SC_graph_view]
    call canvas_graph_free
    mov qword ptr [rbx + SC_graph_view], 0
    mov rax, [r14 + SC_graph]
    mov [rbx + SC_graph], rax
    mov qword ptr [r14 + SC_graph], 0
    mov rdi, [rbx + SC_analysis]
    call mem_free
    mov rax, [r14 + SC_analysis]
    mov [rbx + SC_analysis], rax
    mov qword ptr [r14 + SC_analysis], 0
    mov rdi, [rbx + SC_memory]
    call mem_free
    mov rax, [r14 + SC_memory]
    mov [rbx + SC_memory], rax
    mov qword ptr [r14 + SC_memory], 0
    mov rdi, [rbx + SC_memory_view]
    call memory_free
    mov qword ptr [rbx + SC_memory_view], 0
    mov dword ptr [rbx + SC_trace_cursor], 0
    mov rdi, r14
    call scene_free
    mov rdi, rbx
    call canvas_graph_validate
    mov rdi, rbx
    call scene_trim_history
    mov dword ptr [rip + g_dirty], 1
9:  EPILOGUE

FN scene_dirty
    cmp qword ptr [rdi + SC_text_id], 0
    jne 1f
    mov rax, [rdi + SC_hash]
    cmp rax, [rdi + SC_saved_hash]
    setne al
    movzx eax, al
    ret
1:  mov eax, 1
    ret

# Stable ID lookup, including cross-reference validation.
FN scene_find
    mov rcx, [rdi + SC_elements + VEC_len]
    mov rax, [rdi + SC_elements + VEC_ptr]
1:  test rcx, rcx
    jz 2f
    cmp [rax + CE_id], rsi
    je 3f
    add rax, CE_SIZE
    dec rcx
    jmp 1b
2:  xor eax, eax
3:  ret

# Bind arrow endpoints to centers. Missing/deleted nodes detach, retain coordinates.
FN scene_update_bindings
    PROLOGUE
    mov rbx, rdi
    xor r12d, r12d
1:  cmp r12, [rbx + SC_elements + VEC_len]
    jae 9f
    imul r13, r12, CE_SIZE
    add r13, [rbx + SC_elements + VEC_ptr]
    mov rsi, [r13 + CE_frame]
    test rsi, rsi
    jz 11f
    mov rdi, rbx
    call scene_find
    test rax, rax
    jnz 11f
    mov qword ptr [r13 + CE_frame], 0
11: cmp dword ptr [r13 + CE_kind], CT_ARROW
    jne 8f
    mov rsi, [r13 + CE_from]
    test rsi, rsi
    jz 3f
    mov rdi, rbx
    call scene_find
    test rax, rax
    jz 2f
    mov ecx, [rax + CE_w]
    sar ecx, 1
    add ecx, [rax + CE_x]
    mov edx, [rax + CE_h]
    sar edx, 1
    add edx, [rax + CE_y]
    # Preserve absolute endpoint when the start changes.
    mov eax, [r13 + CE_x]
    add [r13 + CE_w], eax
    sub [r13 + CE_w], ecx
    mov eax, [r13 + CE_y]
    add [r13 + CE_h], eax
    sub [r13 + CE_h], edx
    mov [r13 + CE_x], ecx
    mov [r13 + CE_y], edx
    jmp 3f
2:  mov qword ptr [r13 + CE_from], 0
3:  mov rsi, [r13 + CE_to]
    test rsi, rsi
    jz 8f
    mov rdi, rbx
    call scene_find
    test rax, rax
    jz 4f
    mov ecx, [rax + CE_w]
    sar ecx, 1
    add ecx, [rax + CE_x]
    sub ecx, [r13 + CE_x]
    mov [r13 + CE_w], ecx
    mov ecx, [rax + CE_h]
    sar ecx, 1
    add ecx, [rax + CE_y]
    sub ecx, [r13 + CE_y]
    mov [r13 + CE_h], ecx
    jmp 8f
4:  mov qword ptr [r13 + CE_to], 0
8:  inc r12
    jmp 1b
9:  EPILOGUE

.section .rodata
.Lbounds_error: .asciz "Canvas edit rejected: geometry, reference or memory limit"

.text
# Copy extended owned metadata. dst scene, source element, destination element.
FN scene_clone_extra
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14d, CE_xid
1:  mov rdi, [r12 + r14]
    test rdi, rdi
    jz 2f
    call strlen
    lea rcx, [rax + 1]
    add [rbx + SC_bytes], rcx
    mov rsi, rax
    mov rdi, [r12 + r14]
    call mem_dup
    mov [r13 + r14], rax
2:  add r14d, 8
    cmp r14d, CE_gxid
    jbe 1b
    EPILOGUE
