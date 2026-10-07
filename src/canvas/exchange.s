# Excalidraw subset adapter. Geometry is native IR, external metadata is owned JSON.
.include "rhun.inc"
.include "canvas/canvas.inc"
.text
# JV -> canonical owned JSON string (bounded 3 MiB).
FN canvas_json_copy
    PROLOGUE 32
    mov rbx, rdi
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rsp
    mov rsi, rbx
    call json_dump
    cmp qword ptr [rsp + SB_len], 3 << 20
    ja 8f
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call mem_dup
    mov r12, rax
    jmp 9f
8:  xor r12d, r12d
9:  mov rdi, rsp
    call sb_free
    mov rax, r12
    EPILOGUE

# Native stable-ID lookup by copied external string (never a retained JV pointer).
FN canvas_find_external
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    xor r13d, r13d
1:  cmp r13, [rbx + SC_elements + VEC_len]
    jae 8f
    imul r14, r13, CE_SIZE
    add r14, [rbx + SC_elements + VEC_ptr]
    mov rdi, [r14 + CE_xid]
    test rdi, rdi
    jz 2f
    mov rsi, r12
    call strcmp_eq
    test eax, eax
    jnz 9f
2:  inc r13
    jmp 1b
8:  xor r14d, r14d
9:  mov rax, r14
    EPILOGUE

# External geometry accepts fractions/exponents, rounds to integer world units.
# JV object, key -> eax rounded signed integer, edx success; clamp before cast.
FN canvas_external_int
    PROLOGUE
    call json_get
    mov rdi, rax
    call canvas_json_number
    test edx, edx
    jz 8f
    comisd xmm0, [rip + .Lmaxcoord]
    ja 8f
    comisd xmm0, [rip + .Lmincoord]
    jb 8f
    cvtsd2si eax, xmm0
    mov edx, 1
    EPILOGUE
8:  xor eax, eax
    xor edx, edx
    EPILOGUE

# Import(bytes,len) -> owned scene or NULL. Placeholder kinds retain original JSON.
FN canvas_import_excalidraw
    PROLOGUE 80
    cmp rsi, 3 << 20
    ja .Lex_null
    call json_parse_complete
    test rax, rax
    jz .Lex_null
    mov r12, rax
    mov rdi, rax
    lea rsi, [rip + .Lex_type]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lex_name]
    call json_is
    test eax, eax
    jz .Lex_null
    mov rdi, r12
    lea rsi, [rip + .Lex_version]
    call json_get
    mov rdi, rax
    call scene_json_int
    test edx, edx
    jz .Lex_null
    cmp eax, 2
    jne .Lex_null
    mov rdi, r12
    lea rsi, [rip + .Lex_elements]
    call json_get
    mov [rsp], rax
    mov rdi, rax
    call json_type
    cmp eax, JT_ARR
    jne .Lex_null
    mov rdi, [rsp]
    call json_len
    cmp eax, 4096
    ja .Lex_null
    mov [rsp + 8], eax
    call scene_new
    mov rbx, rax
    mov rdi, r12
    call canvas_json_copy
    test rax, rax
    jz .Lex_bad
    mov [rbx + SC_exchange], rax
    # Local owned group map, discarded after numeric references are established.
    lea rdi, [rsp + 40]
    xor esi, esi
    mov edx, VEC_SIZE
    call memset
    xor r13d, r13d
.Lex_element:
    cmp r13d, [rsp + 8]
    jae .Lex_references
    mov rdi, [rsp]
    mov esi, r13d
    call json_at
    mov r14, rax
    mov rdi, rax
    call json_type
    cmp eax, JT_OBJ
    jne .Lex_bad_groups
    mov rdi, r14
    lea rsi, [rip + .Lex_id]
    call json_get
    mov rdi, rax
    mov esi, 256
    call scene_owned_json_string
    test rax, rax
    jz .Lex_bad_groups
    mov [rsp + 16], rax
    cmp byte ptr [rax], 0
    je .Lex_bad_id
    mov rdi, rbx
    mov rsi, rax
    call canvas_find_external
    test rax, rax
    jnz .Lex_bad_id
    mov r15d, CT_UNSUPPORTED
    xor r12d, r12d
.Lex_kind:
    cmp r12d, 7
    jae .Lex_add
    lea rax, [rip + .Lex_kinds]
    mov rsi, [rax + r12*8]
    mov [rsp + 24], rsi
    mov rdi, r14
    lea rsi, [rip + .Lex_type]
    call json_get
    mov rdi, rax
    mov rsi, [rsp + 24]
    call json_is
    test eax, eax
    jnz 1f
    inc r12d
    jmp .Lex_kind
1:  lea r15d, [r12 + 1]
.Lex_add:
    mov rdi, r14
    lea rsi, [rip + .Lex_deleted]
    call json_get
    mov rdi, rax
    call json_type
    cmp eax, JT_TRUE
    jne 104f
    mov r15d, CT_UNSUPPORTED
104:
    mov rdi, rbx
    mov esi, r15d
    xor edx, edx
    xor ecx, ecx
    mov r8d, 120
    mov r9d, 64
    call scene_add
    mov r12, rax
    mov rcx, [rsp + 16]
    mov [r12 + CE_xid], rcx
    mov rdi, r14
    call canvas_json_copy
    test rax, rax
    jz .Lex_bad_groups
    mov [r12 + CE_raw], rax
    lea r15, [rip + .Lex_geometry]
2:  cmp qword ptr [r15], 0
    je .Lex_style
    mov rdi, r14
    mov rsi, [r15]
    call canvas_external_int
    test edx, edx
    jz .Lex_bad_groups
    mov rcx, [r15 + 8]
    mov [r12 + rcx], eax
    add r15, 16
    jmp 2b
.Lex_style:
    mov rdi, r14
    lea rsi, [rip + .Lex_angle]
    call json_get
    test rax, rax
    jz 3f
    mov rdi, rax
    call canvas_json_number
    test edx, edx
    jz .Lex_bad_groups
    mulsd xmm0, [rip + .Ldegrees]
    comisd xmm0, [rip + .Lmaxangle]
    ja .Lex_bad_groups
    comisd xmm0, [rip + .Lminangle]
    jb .Lex_bad_groups
    cvtsd2si eax, xmm0
    mov [r12 + CE_angle], eax
3:  mov rdi, r14
    lea rsi, [rip + .Lex_seed]
    call json_get
    test rax, rax
    jz 4f
    mov rdi, rax
    call json_u64
    test rdx, rdx
    jz .Lex_bad_groups
    cmp rax, 0x7fffffff
    ja .Lex_bad_groups
    mov [r12 + CE_seed], rax
4:  mov rdi, r14
    lea rsi, [rip + .Lex_roughness]
    call canvas_external_int
    test edx, edx
    jz 5f
    cmp eax, 0
    jl .Lex_bad_groups
    cmp eax, 3
    jg .Lex_bad_groups
    mov [r12 + CE_roughness], eax
5:  mov rdi, r14
    lea rsi, [rip + .Lex_stroke]
    call json_get
    mov rdi, rax
    call canvas_external_color
    test edx, edx
    jz 6f
    mov [r12 + CE_color], eax
6:  mov rdi, r14
    lea rsi, [rip + .Lex_background]
    call json_get
    mov rdi, rax
    call canvas_external_color
    test edx, edx
    jz 7f
    mov [r12 + CE_fill], eax
7:  cmp dword ptr [r12 + CE_kind], CT_TEXT
    jne .Lex_points
    mov rdi, r14
    lea rsi, [rip + .Lex_text]
    call json_get
    mov rdi, rax
    mov esi, 65536
    call scene_owned_json_string
    test rax, rax
    jz .Lex_bad_groups
    mov [r12 + CE_text], rax
    mov rdi, r14
    lea rsi, [rip + .Lex_fontsize]
    call canvas_external_int
    test edx, edx
    jz .Lex_points
    cmp eax, 8
    jl .Lex_bad_groups
    cmp eax, 200
    jg .Lex_bad_groups
    mov [r12 + CE_fontsize], eax
.Lex_points:
    mov eax, [r12 + CE_kind]
    cmp eax, CT_ARROW
    je 8f
    cmp eax, CT_LINE
    je 8f
    cmp eax, CT_STROKE
    jne .Lex_group
8:  mov rdi, r14
    lea rsi, [rip + .Lex_points_key]
    call json_get
    mov [rsp + 24], rax
    mov rdi, rax
    call json_len
    cmp eax, 2
    jb .Lex_bad_groups
    cmp eax, 8192
    ja .Lex_bad_groups
    mov [rsp + 32], eax
    # Multi-segment lines/arrows are placeholders, preserving original data.
    cmp dword ptr [r12 + CE_kind], CT_STROKE
    je 9f
    cmp eax, 2
    je 9f
    mov dword ptr [r12 + CE_kind], CT_UNSUPPORTED
    jmp .Lex_group
9:  xor r15d, r15d
.Lex_point:
    cmp r15d, [rsp + 32]
    jae .Lex_group
    mov rdi, [rsp + 24]
    mov esi, r15d
    call json_at
    mov [rsp + 64], rax
    mov rdi, rax
    call json_len
    cmp eax, 2
    jne .Lex_bad_groups
    mov rdi, [rsp + 64]
    xor esi, esi
    call json_at
    mov rdi, rax
    call canvas_json_number
    test edx, edx
    jz .Lex_bad_groups
    comisd xmm0, [rip + .Lmaxcoord]
    ja .Lex_bad_groups
    comisd xmm0, [rip + .Lmincoord]
    jb .Lex_bad_groups
    cvtsd2si eax, xmm0
    mov [rsp + 72], eax
    mov rdi, [rsp + 64]
    mov esi, 1
    call json_at
    mov rdi, rax
    call canvas_json_number
    test edx, edx
    jz .Lex_bad_groups
    comisd xmm0, [rip + .Lmaxcoord]
    ja .Lex_bad_groups
    comisd xmm0, [rip + .Lmincoord]
    jb .Lex_bad_groups
    cvtsd2si eax, xmm0
    mov [rsp + 76], eax
    cmp dword ptr [r12 + CE_kind], CT_STROKE
    jne 10f
    lea rdi, [r12 + CE_points]
    mov esi, 8
    call vec_push
    mov ecx, [rsp + 72]
    mov [rax], ecx
    mov ecx, [rsp + 76]
    mov [rax + 4], ecx
    jmp 12f
10: test r15d, r15d
    jnz 11f
    # Normalize nonzero first point into the native origin.
    mov eax, [rsp + 72]
    add [r12 + CE_x], eax
    mov [r12 + CE_w], eax
    mov eax, [rsp + 76]
    add [r12 + CE_y], eax
    mov [r12 + CE_h], eax
    jmp 12f
11: mov eax, [rsp + 72]
    sub eax, [r12 + CE_w]
    mov [r12 + CE_w], eax
    mov eax, [rsp + 76]
    sub eax, [r12 + CE_h]
    mov [r12 + CE_h], eax
12: inc r15
    jmp .Lex_point
.Lex_group:
    cmp dword ptr [r12 + CE_kind], CT_UNSUPPORTED
    jne 01f
    cmp dword ptr [r12 + CE_w], 0
    jg 02f
    mov dword ptr [r12 + CE_w], 120
02: cmp dword ptr [r12 + CE_h], 0
    jg 01f
    mov dword ptr [r12 + CE_h], 64
01: mov rdi, r14
    lea rsi, [rip + .Lex_groupids]
    call json_get
    mov rdi, rax
    xor esi, esi
    call json_at
    test rax, rax
    jz .Lex_next
    mov rdi, rax
    mov esi, 256
    call scene_owned_json_string
    test rax, rax
    jz .Lex_bad_groups
    mov [rsp + 24], rax
    xor r15d, r15d
1:  cmp r15, [rsp + 40 + VEC_len]
    jae 3f
    mov rax, [rsp + 40 + VEC_ptr]
    imul rcx, r15, 16
    mov rdi, [rax + rcx]
    mov rsi, [rsp + 24]
    call strcmp_eq
    test eax, eax
    jnz 2f
    inc r15
    jmp 1b
2:  mov rax, [rsp + 40 + VEC_ptr]
    imul rcx, r15, 16
    mov rax, [rax + rcx + 8]
    mov [r12 + CE_group], rax
    mov rax, [rsp + 24]
    mov [r12 + CE_gxid], rax
    jmp .Lex_next
3:  mov rdi, [rsp + 24]
    call strlen
    mov rsi, rax
    mov rdi, [rsp + 24]
    call mem_dup
    mov [r12 + CE_gxid], rax
    lea rdi, [rsp + 40]
    mov esi, 16
    call vec_push
    mov rcx, [rsp + 24]
    mov [rax], rcx
    mov rcx, [rbx + SC_next_id]
    inc qword ptr [rbx + SC_next_id]
    mov [rax + 8], rcx
    mov [r12 + CE_group], rcx
.Lex_next:
    inc r13
    jmp .Lex_element
.Lex_references:
    xor r13d, r13d
1:  cmp r13d, [rsp + 8]
    jae .Lex_validate
    mov rdi, [rsp]
    mov esi, r13d
    call json_at
    mov r14, rax
    imul r12, r13, CE_SIZE
    add r12, [rbx + SC_elements + VEC_ptr]
    lea r15, [rip + .Lex_refs]
2:  cmp qword ptr [r15], 0
    je 6f
    mov rdi, r14
    mov rsi, [r15]
    call json_get
    test rax, rax
    jz 5f
    mov rdi, rax
    call json_type
    cmp eax, JT_NULL
    je 5f
    cmp qword ptr [r15 + 8], CE_frame
    je 3f
    cmp dword ptr [r12 + CE_kind], CT_ARROW
    jne 5f
    lea rsi, [rip + .Lex_elementid]
    call json_get
    mov rdi, rax
3:  call json_type
    cmp eax, JT_NULL
    je 5f
    # Obtain copied string without holding it beyond this lookup.
    mov rdi, r14
    mov rsi, [r15]
    call json_get
    mov rdi, rax
    cmp qword ptr [r15 + 8], CE_frame
    je 31f
    lea rsi, [rip + .Lex_elementid]
    call json_get
    mov rdi, rax
31: mov esi, 256
    call scene_owned_json_string
    test rax, rax
    jz .Lex_bad_groups
    mov [rsp + 24], rax
    mov rdi, rbx
    mov rsi, rax
    call canvas_find_external
    mov [rsp + 32], rax
    mov rdi, [rsp + 24]
    call mem_free
    mov rax, [rsp + 32]
    test rax, rax
    jz .Lex_bad_groups
    mov rcx, [r15 + 8]
    mov rax, [rax + CE_id]
    mov [r12 + rcx], rax
5:  add r15, 16
    jmp 2b
6:  inc r13
    jmp 1b
.Lex_validate:
    mov rdi, rbx
    call scene_validate
    mov r12d, eax
    lea rdi, [rsp + 40]
    call canvas_group_map_free
    test r12d, r12d
    jz .Lex_bad
    mov rax, rbx
    EPILOGUE
.Lex_bad_id:
    mov rdi, [rsp + 16]
    call mem_free
.Lex_bad_groups:
    lea rdi, [rsp + 40]
    call canvas_group_map_free
.Lex_bad:
    mov rdi, rbx
    call scene_free
.Lex_null:
    xor eax, eax
    EPILOGUE

canvas_group_map_free:
    PROLOGUE
    mov rbx, rdi
    xor r12d, r12d
1:  cmp r12, [rbx + VEC_len]
    jae 2f
    imul rax, r12, 16
    add rax, [rbx + VEC_ptr]
    mov rdi, [rax]
    call mem_free
    inc r12
    jmp 1b
2:  mov rdi, rbx
    call vec_free
    EPILOGUE

# Supported RGB hex and transparent; preserve all other styles in raw metadata.
FN canvas_external_color
    PROLOGUE
    call json_str
    test rax, rax
    jz 8f
    cmp rdx, 11
    jne 1f
    mov rdi, rax
    mov rsi, rdx
    lea rdx, [rip + .Ltransparent]
    call str_eq_cstr
    test eax, eax
    jz 8f
    xor eax, eax
    mov edx, 1
    EPILOGUE
1:  cmp rdx, 7
    jne 8f
    cmp byte ptr [rax], '#'
    jne 8f
    lea rdi, [rax + 1]
    mov esi, 6
    call parse_hex
    cmp edx, 6
    jne 8f
    or eax, 0xff000000
    mov edx, 1
    EPILOGUE
8:  xor eax, eax
    xor edx, edx
    EPILOGUE
.section .rodata
.Lex_type: .asciz "type"
.Lex_name: .asciz "excalidraw"
.Lex_version: .asciz "version"
.Lex_elements: .asciz "elements"
.Lex_id: .asciz "id"
.Lex_x: .asciz "x"
.Lex_y: .asciz "y"
.Lex_w: .asciz "width"
.Lex_h: .asciz "height"
.Lex_angle: .asciz "angle"
.Lex_seed: .asciz "seed"
.Lex_roughness: .asciz "roughness"
.Lex_stroke: .asciz "strokeColor"
.Lex_background: .asciz "backgroundColor"
.Lex_text: .asciz "text"
.Lex_fontsize: .asciz "fontSize"
.Lex_points_key: .asciz "points"
.Lex_groupids: .asciz "groupIds"
.Lex_deleted: .asciz "isDeleted"
.Lex_start: .asciz "startBinding"
.Lex_end: .asciz "endBinding"
.Lex_frameid: .asciz "frameId"
.Lex_elementid: .asciz "elementId"
.Ltransparent: .asciz "transparent"
.Lkind_rect: .asciz "rectangle"
.Lkind_ellipse: .asciz "ellipse"
.Lkind_arrow: .asciz "arrow"
.Lkind_text: .asciz "text"
.Lkind_frame: .asciz "frame"
.Lkind_line: .asciz "line"
.Lkind_stroke: .asciz "freedraw"
.p2align 3
.Lex_kinds: .quad .Lkind_rect, .Lkind_ellipse, .Lkind_arrow, .Lkind_text, .Lkind_frame, .Lkind_line, .Lkind_stroke
.Lex_geometry: .quad .Lex_x, CE_x, .Lex_y, CE_y, .Lex_w, CE_w, .Lex_h, CE_h, 0
.Lex_refs: .quad .Lex_start, CE_from, .Lex_end, CE_to, .Lex_frameid, CE_frame, 0
.Lmaxcoord: .double 1000000.0
.Lmincoord: .double -1000000.0
.Lmaxangle: .double 360.0
.Lminangle: .double -360.0
.Ldegrees: .double 57.29577951308232
