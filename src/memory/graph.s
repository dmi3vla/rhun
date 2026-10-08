.include "rhun.inc"
.include "canvas/canvas.inc"
.include "canvas/graph.inc"
.include "memory/memory.inc"
.text
FN memory_strdup
    PROLOGUE
    mov rbx, rdi
    call strlen
    mov rsi, rax
    mov rdi, rbx
    call mem_dup
    EPILOGUE
# One graph node per snapshot node, same 1-based index and stable source ID.
FN memory_build_graph
    PROLOGUE SB_SIZE+32
    mov rbx, rdi
    cmp qword ptr [rbx + MM_graph], 0
    jne .Lbg_done
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE+32
    call memset
    mov edi, GR_SIZE
    call mem_alloc
    mov r12, rax
    mov [rbx + MM_graph], rax
    mov dword ptr [rax + GR_profile], 1
    mov dword ptr [rax + GR_mode], 1
    mov dword ptr [rax + GR_zoom], 65536
    mov dword ptr [rax + GR_yaw], -22
    mov dword ptr [rax + GR_pitch], 14
    cmp dword ptr [rbx + MM_graph_zoom], 0
    je .Lbg_camera_done
    mov ecx, [rbx + MM_graph_zoom]
    mov [rax + GR_zoom], ecx
    mov ecx, [rbx + MM_graph_yaw]
    mov [rax + GR_yaw], ecx
    mov ecx, [rbx + MM_graph_pitch]
    mov [rax + GR_pitch], ecx
.Lbg_camera_done:
    mov rdi, rbx
    call memory_snapshot
    mov r13, rax
    xor r14d, r14d
.Lbg_node:
    cmp r14, [r13 + MS_nodes + VEC_len]
    jae .Lbg_segments_start
    imul r15, r14, MN_SIZE
    add r15, [r13 + MS_nodes + VEC_ptr]
    lea rdi, [r12 + GR_nodes]
    mov esi, GN_SIZE
    call vec_push
    mov [rsp + SB_SIZE + 16], rax
    mov rdi, rax
    xor esi, esi
    mov edx, GN_SIZE
    call memset
    mov rdi, [r15 + MN_id]
    call memory_strdup
    mov rcx, [rsp + SB_SIZE + 16]
    mov [rcx + GN_id], rax
    mov rdi, [r15 + MN_id]
    call memory_strdup
    mov rcx, [rsp + SB_SIZE + 16]
    mov [rcx + GN_name], rax
    mov rdi, [r15 + MN_address]
    call memory_strdup
    mov rcx, [rsp + SB_SIZE + 16]
    mov [rcx + GN_object], rax
    mov rdi, rsp
    call sb_clear
    mov rdi, rsp
    mov rsi, r15
    call memory_description
    mov rdi, rsp
    lea rsi, [rip + .Lsource]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, [r15 + MN_source]
    call sb_push_cstr
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call mem_dup
    mov rcx, [rsp + SB_SIZE + 16]
    mov [rcx + GN_description], rax
    mov dword ptr [rcx + GN_kind], 0
    mov dword ptr [rcx + GN_realm], -1
    mov dword ptr [rcx + GN_schema], 1
    mov eax, [r15 + MN_kind]
    mov [rcx + GN_memory_kind], eax
    mov edx, [r15 + MN_state]
    mov [rcx + GN_memory_state], edx
    xor edx, edx
    test eax, eax
    jz .Lbg_lane
    mov edx, 2
    cmp eax, 1
    je .Lbg_stack
    cmp eax, 4
    jne .Lbg_lane
.Lbg_stack: mov edx, 1
.Lbg_lane:
    lea eax, [rdx + 1]
    mov [rcx + GN_segment], eax
    mov eax, [rsp + SB_SIZE + rdx*4]
    inc dword ptr [rsp + SB_SIZE + rdx*4]
    imul eax, -100
    add eax, 120
    mov [rcx + GN_position + 4], eax
    sub edx, 1
    imul eax, edx, 320
    mov [rcx + GN_position], eax
    imul eax, edx, 140
    mov [rcx + GN_position + 8], eax
    inc r14
    jmp .Lbg_node
.Lbg_segments_start: xor r14d, r14d
.Lbg_segment:
    cmp r14d, 3
    jae .Lbg_links_start
    lea rdi, [r12 + GR_segments]
    mov esi, GS_SIZE
    call vec_push
    mov r15, rax
    mov rdi, rax
    xor esi, esi
    mov edx, GS_SIZE
    call memset
    mov eax, r14d
    add eax, 1
    mov [r15 + GS_id], eax
    lea rax, [rip + .Llanes]
    mov rdi, [rax + r14*8]
    call memory_strdup
    mov [r15 + GS_name], rax
    mov edx, r14d
    sub edx, 1
    imul eax, edx, 320
    mov [r15 + GS_center], eax
    imul eax, edx, 140
    mov [r15 + GS_center + 8], eax
    mov ecx, [rsp + SB_SIZE + r14*4]
    test ecx, ecx
    jnz .Lbg_count
    mov ecx, 1
.Lbg_count: imul ecx, 50
    mov eax, 170
    sub eax, ecx
    mov [r15 + GS_center + 4], eax
    add ecx, 70
    mov [r15 + GS_half + 4], ecx
    mov dword ptr [r15 + GS_half], 100
    mov dword ptr [r15 + GS_half + 8], 60
    inc r14d
    jmp .Lbg_segment
.Lbg_links_start:
    # A single neutral event satisfies generic renderer ownership. Memory timeline
    # itself remains MM_cursor; no replica versions are displayed or exported.
    lea rdi, [r12 + GR_events]
    mov esi, EV_SIZE
    call vec_push
    mov r15, rax
    mov rdi, rax
    xor esi, esi
    mov edx, EV_SIZE
    call memset
    mov rdi, [r13 + MS_label]
    call memory_strdup
    mov [r15 + EV_label], rax
    mov rdi, [r13 + MS_thread]
    call memory_strdup
    mov [r15 + EV_actor], rax
    lea rdi, [rip + .Levidence]
    call memory_strdup
    mov [r15 + EV_note], rax
    xor r14d, r14d
.Lbg_link:
    cmp r14, [r13 + MS_links + VEC_len]
    jae .Lbg_free
    imul r15, r14, ML_SIZE
    add r15, [r13 + MS_links + VEC_ptr]
    lea rdi, [r12 + GR_edges]
    mov esi, GE_SIZE
    call vec_push
    mov [rsp + SB_SIZE + 16], rax
    mov rdi, rax
    xor esi, esi
    mov edx, GE_SIZE
    call memset
    mov rdi, r14
    call radare_id_string
    mov rcx, [rsp + SB_SIZE + 16]
    mov [rcx + GE_id], rax
    mov rdi, [r15 + ML_from]
    call memory_strdup
    mov rcx, [rsp + SB_SIZE + 16]
    mov [rcx + GE_a_name], rax
    mov rdi, [r15 + ML_to]
    call memory_strdup
    mov rcx, [rsp + SB_SIZE + 16]
    mov [rcx + GE_b_name], rax
    mov eax, [r15 + ML_a]
    mov [rcx + GE_a], eax
    mov eax, [r15 + ML_b]
    mov [rcx + GE_b], eax
    mov eax, [r15 + ML_kind]
    mov [rcx + GE_kind], eax
    inc r14
    jmp .Lbg_link
.Lbg_free:
    mov rdi, rsp
    call sb_free
.Lbg_done: EPILOGUE
FN memory_graph_for_scene
    PROLOGUE
    call memory_prepare
    test rax, rax
    jz .Lgraph_scene_done
    mov rbx, rax
    mov rdi, rax
    call memory_build_graph
    mov rax, [rbx + MM_graph]
.Lgraph_scene_done: EPILOGUE
FN cmd_memory_fold
    PROLOGUE
    call memory_active
    test rax, rax
    jz .Lfold_done
    mov rbx, rax
    mov rdi, rax
    call memory_build_graph
    mov r12, [rbx + MM_graph]
    mov eax, [r12 + GR_selected]
    test eax, eax
    jz .Lfold_done
    cmp eax, 256
    ja .Lfold_segment
    dec eax
    cmp rax, [r12 + GR_nodes + VEC_len]
    jae .Lfold_done
    imul rax, GN_SIZE
    add rax, [r12 + GR_nodes + VEC_ptr]
    mov ecx, [rax + GN_segment]
    jmp .Lfold_toggle
.Lfold_segment: lea ecx, [rax - 256]
.Lfold_toggle:
    mov eax, 1
    shl eax, cl
    xor dword ptr [r12 + GR_fold], eax
    mov dword ptr [rip + g_dirty], 1
.Lfold_done: EPILOGUE
FN cmd_memory_select_next
    PROLOGUE
    call memory_active
    test rax, rax
    jz .Lselect_done
    mov rbx, rax
    mov rdi, rax
    call memory_snapshot
    mov ecx, [rbx + MM_selected]
    inc ecx
    cmp rcx, [rax + MS_nodes + VEC_len]
    jbe .Lselect_store
    mov ecx, 1
.Lselect_store:
    mov [rbx + MM_selected], ecx
    mov rax, [rbx + MM_graph]
    test rax, rax
    jz .Lselect_dirty
    mov [rax + GR_selected], ecx
.Lselect_dirty:
    mov dword ptr [rip + g_dirty], 1
.Lselect_done: EPILOGUE
.section .rodata
.Lsource: .asciz "\nsource: "
.Lcode: .asciz "Code / entry"
.Lstack: .asciz "Thread stack"
.Lheap: .asciz "Memory / lifetime"
.Levidence: .asciz "Declared snapshot evidence; no target execution by rhun"
.p2align 3
.Llanes: .quad .Lcode,.Lstack,.Lheap
