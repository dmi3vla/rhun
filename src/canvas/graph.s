.include "rhun.inc"
.include "canvas/canvas.inc"
.include "canvas/graph.inc"
.text
# String-ID lookup, rdi vector, esi item size, rdx owned cstr -> 1-based index.
FN canvas_graph_id
    PROLOGUE
    mov rbx, rdi
    mov r12d, esi
    mov r13, rdx
    xor r14d, r14d
1:  cmp r14, [rbx + VEC_len]
    jae 8f
    mov rax, r14
    imul rax, r12
    add rax, [rbx + VEC_ptr]
    mov rdi, [rax]
    mov rsi, r13
    call strcmp_eq
    test eax, eax
    jnz 9f
    inc r14
    jmp 1b
8:  xor eax, eax
    EPILOGUE
9:  lea eax, [r14 + 1]
    EPILOGUE
# Borrowed JSON fields -> owned record according to closed table.
canvas_graph_fields:
    PROLOGUE 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
1:  cmp qword ptr [r13], 0
    je 9f
    mov rdi, rbx
    mov rsi, [r13]
    call json_get
    mov [rsp], rax
    mov r14, [r13 + 8]
    cmp qword ptr [r13 + 16], 1
    jne 2f
    mov rdi, rax
    mov esi, 4096
    call scene_owned_json_string
    test rax, rax
    jz 8f
    mov [r12 + r14], rax
    jmp 7f
2:  cmp qword ptr [r13 + 16], 2
    jne 3f
    mov rdi, rax
    call scene_json_int
    test edx, edx
    jz 8f
    cmp rax, [r13 + 24]
    jl 8f
    cmp rax, [r13 + 32]
    jg 8f
    mov [r12 + r14], eax
    jmp 7f
3:  mov rdi, [rsp]
    call json_type
    cmp eax, JT_ARR
    jne 8f
    mov rdi, [rsp]
    call json_len
    cmp qword ptr [r13 + 16], 5
    jne 4f
    cmp eax, 1024
    ja 8f
    mov [rsp + 8], eax
    xor r15d, r15d
31: cmp r15d, [rsp + 8]
    jae 7f
    mov rdi, [rsp]
    mov esi, r15d
    call json_at
    mov rdi, rax
    mov esi, 256
    call scene_owned_json_string
    test rax, rax
    jz 8f
    mov rdi, rax
    mov [rsp + 8], rax           # reuse is NOT safe for count; keep via push
    lea rdi, [r12 + r14]
    mov esi, 8
    call vec_push
    mov rcx, [rsp + 8]
    mov [rax], rcx
    mov rdi, [rsp]
    call json_len
    mov [rsp + 8], eax
    inc r15d
    jmp 31b
4:  cmp rax, [r13 + 16]
    jne 8f
    xor r15d, r15d
5:  cmp r15, [r13 + 16]
    jae 7f
    mov rdi, [rsp]
    mov esi, r15d
    call json_at
    mov rdi, rax
    call scene_json_int
    test edx, edx
    jz 8f
    cmp rax, [r13 + 24]
    jl 8f
    cmp rax, [r13 + 32]
    jg 8f
    lea rcx, [r12 + r14]
    mov [rcx + r15*4], eax
    inc r15
    jmp 5b
7:  add r13, 40
    jmp 1b
8:  xor eax, eax
    EPILOGUE
9:  mov eax, 1
    EPILOGUE

FN canvas_graph_parse
    PROLOGUE 32
    cmp rsi, 1 << 20
    ja .Lgraph_null
    call json_parse_complete
    test rax, rax
    jz .Lgraph_null
    mov r12, rax
    cmp dword ptr [rax], JT_OBJ
    jne .Lgraph_null
    cmp dword ptr [rax + 4], 6
    jne .Lgraph_null
    mov rdi, rax
    lea rsi, [rip + .Ltype]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lgraph_type]
    call json_is
    test eax, eax
    jz .Lgraph_null
    mov rdi, r12
    lea rsi, [rip + .Lversion]
    call json_get
    mov rdi, rax
    call scene_json_int
    test edx, edx
    jz .Lgraph_null
    cmp rax, 1
    jne .Lgraph_null
    mov edi, GR_SIZE
    call mem_alloc
    mov rbx, rax
    lea r13, [rip + .Lcollections]
.Lgraph_collection:
    cmp qword ptr [r13], 0
    je .Lgraph_links
    mov rdi, r12
    mov rsi, [r13]
    call json_get
    mov [rsp], rax
    mov rdi, rax
    call json_type
    cmp eax, JT_ARR
    jne .Lgraph_bad
    mov rdi, [rsp]
    call json_len
    test eax, eax
    jz .Lgraph_bad
    cmp rax, [r13 + 32]
    ja .Lgraph_bad
    mov [rsp + 8], eax
    xor r14d, r14d
1:  cmp r14d, [rsp + 8]
    jae 3f
    mov rdi, [rsp]
    mov esi, r14d
    call json_at
    mov r15, rax
    mov rdi, rax
    call json_type
    cmp eax, JT_OBJ
    jne .Lgraph_bad
    mov rax, [r13 + 40]
    cmp [r15 + 4], eax
    jne .Lgraph_bad
    mov rdi, [r13 + 8]
    add rdi, rbx
    mov rsi, [r13 + 16]
    call vec_push
    mov [rsp + 16], rax
    mov rdi, rax
    xor esi, esi
    mov rdx, [r13 + 16]
    call memset
    mov rdi, r15
    mov rsi, [rsp + 16]
    mov rdx, [r13 + 24]
    call canvas_graph_fields
    test eax, eax
    jz .Lgraph_bad
    inc r14d
    jmp 1b
3:  add r13, 48
    jmp .Lgraph_collection
.Lgraph_links:
    xor r12d, r12d
101: cmp r12, [rbx + GR_segments + VEC_len]
    jae 103f
    imul r13, r12, GS_SIZE
    add r13, [rbx + GR_segments + VEC_ptr]
    mov rdi, rbx
    mov esi, [r13 + GS_id]
    call canvas_graph_segment
    cmp rax, r13
    jne .Lgraph_bad
    inc r12
    jmp 101b
103: xor r12d, r12d
1:  cmp r12, [rbx + GR_nodes + VEC_len]
    jae .Lgraph_edges
    imul r13, r12, GN_SIZE
    add r13, [rbx + GR_nodes + VEC_ptr]
    mov rax, [r13 + GN_id]
    cmp byte ptr [rax], 0
    je .Lgraph_bad
    lea rdi, [rbx + GR_nodes]
    mov esi, GN_SIZE
    mov rdx, [r13 + GN_id]
    call canvas_graph_id
    lea ecx, [r12 + 1]
    cmp eax, ecx
    jne .Lgraph_bad
    mov esi, [r13 + GN_segment]
    test esi, esi
    jz 2f
    mov rdi, rbx
    call canvas_graph_segment
    test rax, rax
    jz .Lgraph_bad
2:  cmp dword ptr [r13 + GN_kind], 1
    jne 3f
    cmp dword ptr [r13 + GN_realm], 0
    jl .Lgraph_bad
    mov rax, [r13 + GN_object]
    cmp byte ptr [rax], 0
    je .Lgraph_bad
3:  inc r12
    jmp 1b
.Lgraph_edges:
    xor r12d, r12d
1:  cmp r12, [rbx + GR_edges + VEC_len]
    jae .Lgraph_events
    imul r13, r12, GE_SIZE
    add r13, [rbx + GR_edges + VEC_ptr]
    lea rdi, [rbx + GR_edges]
    mov esi, GE_SIZE
    mov rdx, [r13 + GE_id]
    call canvas_graph_id
    lea ecx, [r12 + 1]
    cmp eax, ecx
    jne .Lgraph_bad
    lea rdi, [rbx + GR_nodes]
    mov esi, GN_SIZE
    mov rdx, [r13 + GE_a_name]
    call canvas_graph_id
    test eax, eax
    jz .Lgraph_bad
    mov [r13 + GE_a], eax
    lea rdi, [rbx + GR_nodes]
    mov esi, GN_SIZE
    mov rdx, [r13 + GE_b_name]
    call canvas_graph_id
    test eax, eax
    jz .Lgraph_bad
    mov [r13 + GE_b], eax
    inc r12
    jmp 1b
.Lgraph_events:
    xor r12d, r12d
1:  cmp r12, [rbx + GR_events + VEC_len]
    jae .Lgraph_ok
    imul r13, r12, EV_SIZE
    add r13, [rbx + GR_events + VEC_ptr]
    xor r14d, r14d
2:  cmp r14, [r13 + EV_active + VEC_len]
    jae 3f
    mov rax, [r13 + EV_active + VEC_ptr]
    mov rdx, [rax + r14*8]
    lea rdi, [rbx + GR_edges]
    mov esi, GE_SIZE
    call canvas_graph_id
    test eax, eax
    jz .Lgraph_bad
    inc r14
    jmp 2b
3:  inc r12
    jmp 1b
.Lgraph_ok:
    mov dword ptr [rbx + GR_view_w], 640
    mov dword ptr [rbx + GR_view_h], 480
    mov dword ptr [rbx + GR_mode], 1
    mov dword ptr [rbx + GR_zoom], 65536
    mov dword ptr [rbx + GR_yaw], -22
    mov dword ptr [rbx + GR_pitch], 14
    mov dword ptr [rbx + GR_selected], 9
    mov eax, [rbx + GR_events + VEC_len]
    dec eax
    cmp eax, 3
    jbe 1f
    mov eax, 3
1:  mov [rbx + GR_event], eax
    mov rax, rbx
    EPILOGUE
.Lgraph_bad:
    mov rdi, rbx
    call canvas_graph_free
.Lgraph_null:
    xor eax, eax
    EPILOGUE
FN canvas_graph_segment
    mov rcx, [rdi + GR_segments + VEC_len]
    mov rax, [rdi + GR_segments + VEC_ptr]
1:  test rcx, rcx
    jz 2f
    cmp [rax + GS_id], esi
    je 3f
    add rax, GS_SIZE
    dec rcx
    jmp 1b
2:  xor eax, eax
3:  ret

FN canvas_graph_projection_free
    PROLOGUE
    mov rbx, rdi
    xor r12d, r12d
1:  cmp r12, [rbx + GR_links + VEC_len]
    jae 2f
    imul rax, r12, VE_SIZE
    add rax, [rbx + GR_links + VEC_ptr]
    lea rdi, [rax + VE_sources]
    call vec_free
    inc r12
    jmp 1b
2:  lea rdi, [rbx + GR_links]
    call vec_free
    lea rdi, [rbx + GR_visible]
    call vec_free
    EPILOGUE
FN canvas_graph_free
    PROLOGUE
    mov rbx, rdi
    test rbx, rbx
    jz 9f
    call canvas_graph_projection_free
    lea r12, [rip + .Lcollections]
1:  cmp qword ptr [r12], 0
    je 8f
    xor r13d, r13d
2:  mov rcx, [r12 + 8]
    lea rax, [rbx + rcx]
    cmp r13, [rax + VEC_len]
    jae 6f
    mov r14, r13
    imul r14, [r12 + 16]
    add r14, [rax + VEC_ptr]
    mov r15, [r12 + 24]
3:  cmp qword ptr [r15], 0
    je 5f
    mov rcx, [r15 + 8]
    cmp qword ptr [r15 + 16], 1
    jne 4f
    mov rdi, [r14 + rcx]
    call mem_free
    jmp 41f
4:  cmp qword ptr [r15 + 16], 5
    jne 41f
    lea rdi, [r14 + rcx]
    call canvas_graph_string_vec_free
41: add r15, 40
    jmp 3b
5:  inc r13
    jmp 2b
6:  mov rcx, [r12 + 8]
    lea rdi, [rbx + rcx]
    call vec_free
    add r12, 48
    jmp 1b
8:  mov rdi, rbx
    call mem_free
9:  EPILOGUE
canvas_graph_string_vec_free:
    PROLOGUE
    mov rbx, rdi
    xor r12d, r12d
1:  cmp r12, [rbx + VEC_len]
    jae 2f
    mov rax, [rbx + VEC_ptr]
    mov rdi, [rax + r12*8]
    call mem_free
    inc r12
    jmp 1b
2:  mov rdi, rbx
    call vec_free
    EPILOGUE
.section .rodata
.Ltype: .asciz "type"
.Lgraph_type: .asciz "rhun-graph"
.Lversion: .asciz "version"
.Lfield_a: .asciz "a"
.Lfield_active: .asciz "active"
.Lfield_actor: .asciz "actor"
.Lfield_b: .asciz "b"
.Lfield_center: .asciz "center"
.Lfield_description: .asciz "description"
.Lfield_half: .asciz "half"
.Lfield_id: .asciz "id"
.Lfield_kind: .asciz "kind"
.Lfield_label: .asciz "label"
.Lfield_name: .asciz "name"
.Lfield_note: .asciz "note"
.Lfield_object: .asciz "object"
.Lfield_position: .asciz "position"
.Lfield_realm: .asciz "realm"
.Lfield_schema: .asciz "schema"
.Lfield_segment: .asciz "segment"
.Lfield_versions: .asciz "versions"
.Lfield_nodes: .asciz "nodes"
.Lfield_edges: .asciz "edges"
.Lfield_segments: .asciz "segments"
.Lfield_events: .asciz "events"
.p2align 3
.Lnode_fields:
    .quad .Lfield_id, GN_id, 1, 0, 0
    .quad .Lfield_name, GN_name, 1, 0, 0
    .quad .Lfield_description, GN_description, 1, 0, 0
    .quad .Lfield_object, GN_object, 1, 0, 0
    .quad .Lfield_segment, GN_segment, 2, 0, 16
    .quad .Lfield_kind, GN_kind, 2, 0, 2
    .quad .Lfield_realm, GN_realm, 2, -1, 3
    .quad .Lfield_schema, GN_schema, 2, 1, 10000
    .quad .Lfield_position, GN_position, 3, -10000, 10000
    .quad 0
.Ledge_fields:
    .quad .Lfield_id, GE_id, 1, 0, 0
    .quad .Lfield_a, GE_a_name, 1, 0, 0
    .quad .Lfield_b, GE_b_name, 1, 0, 0
    .quad .Lfield_kind, GE_kind, 2, 0, 1
    .quad 0
.Lsegment_fields:
    .quad .Lfield_id, GS_id, 2, 1, 16
    .quad .Lfield_name, GS_name, 1, 0, 0
    .quad .Lfield_center, GS_center, 3, -10000, 10000
    .quad .Lfield_half, GS_half, 3, 1, 10000
    .quad 0
.Levent_fields:
    .quad .Lfield_label, EV_label, 1, 0, 0
    .quad .Lfield_actor, EV_actor, 1, 0, 0
    .quad .Lfield_note, EV_note, 1, 0, 0
    .quad .Lfield_versions, EV_versions, 4, 1, 1000000
    .quad .Lfield_active, EV_active, 5, 0, 0
    .quad 0
.Lcollections:
    .quad .Lfield_nodes, GR_nodes, GN_SIZE, .Lnode_fields, 256, 9
    .quad .Lfield_edges, GR_edges, GE_SIZE, .Ledge_fields, 1024, 4
    .quad .Lfield_segments, GR_segments, GS_SIZE, .Lsegment_fields, 16, 4
    .quad .Lfield_events, GR_events, EV_SIZE, .Levent_fields, 256, 5
    .quad 0
.text
FN canvas_graph_import
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    call canvas_graph_parse
    mov r13, rax
    test rax, rax
    jz 8f
    call scene_new
    mov r14, rax
    mov [rax + SC_graph_view], r13
    mov rdi, rbx
    mov rsi, r12
    call mem_dup
    mov [r14 + SC_graph], rax
    mov rax, r14
    EPILOGUE
8:  xor eax, eax
    EPILOGUE
FN canvas_graph_validate
    PROLOGUE
    mov rbx, rdi
    mov rdi, [rbx + SC_graph]
    test rdi, rdi
    jz 1f
    cmp byte ptr [rdi], 0
    je 1f
    call strlen
    mov rsi, rax
    mov rdi, [rbx + SC_graph]
    call canvas_graph_parse
    test rax, rax
    jz 8f
    mov [rbx + SC_graph_view], rax
1:  mov eax, 1
    EPILOGUE
8:  xor eax, eax
    EPILOGUE
FN cmd_canvas_graph_demo
    PROLOGUE
    lea rdi, [rip + graph_demo]
    mov esi, graph_demo_end - graph_demo
    call canvas_graph_import
    test rax, rax
    jz 9f
    mov rbx, rax
    call doc_new
    mov [rax + DOC_canvas], rbx
    mov [rbx + SC_doc], rax
    lea rcx, [rip + .Ldemo_name]
    mov [rax + DOC_name], rcx
    mov rdi, rax
    mov esi, TAB_CANVAS
    call app_add_tab
9:  EPILOGUE
.section .rodata
.Ldemo_name: .asciz "Distributed state demo"
graph_demo: .incbin "examples/canvas/distributed-state.rhun-graph"
graph_demo_end:
