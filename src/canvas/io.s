# Versioned native scene, strict validation into owned temporary storage.
.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN scene_serialize
    PROLOGUE 16
    mov rbx, rdi
    mov r12, rsi
    mov rdi, r12
    lea rsi, [rip + .Lscene_header]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, [rbx + SC_next_id]
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Lexchange_key]
    call sb_push_cstr
    mov rsi, [rbx + SC_exchange]
    xor edx, edx
    test rsi, rsi
    jz 10f
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rsi, [rbx + SC_exchange]
10: mov rdi, r12
    call chat_json_quote
    mov rdi, r12
    lea rsi, [rip + .Lscene_elements]
    call sb_push_cstr
    xor r13d, r13d
1:  cmp r13, [rbx + SC_elements + VEC_len]
    jae 8f
    test r13, r13
    jz 11f
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
11: mov rdi, r12
    mov esi, '{'
    call sb_push_byte
    imul r14, r13, CE_SIZE
    add r14, [rbx + SC_elements + VEC_ptr]
    lea r15, [rip + .Lfields]
2:  cmp qword ptr [r15], 0
    je 3f
    mov rdi, [r15]
    call strlen
    mov rdx, rax
    mov rdi, r12
    mov rsi, [r15]
    call chat_json_quote
    mov rdi, r12
    mov esi, ':'
    call sb_push_byte
    mov rcx, [r15 + 8]
    mov rsi, [r14 + rcx]
    cmp qword ptr [r15 + 16], 8
    je 21f
    movsxd rsi, dword ptr [r14 + rcx]
    cmp qword ptr [r15 + 24], 0
    jl 21f
    mov esi, [r14 + rcx]
21: mov rdi, r12
    call canvas_dump_int
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
    add r15, 40
    jmp 2b
3:  mov rdi, r12
    lea rsi, [rip + .Ltext_key]
    call sb_push_cstr
    mov rsi, [r14 + CE_text]
    xor edx, edx
    test rsi, rsi
    jz 31f
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rsi, [r14 + CE_text]
31: mov rdi, r12
    call chat_json_quote
    mov rdi, r12
    lea rsi, [rip + .Lpoints_key]
    call sb_push_cstr
    xor r15d, r15d
4:  cmp r15, [r14 + CE_points + VEC_len]
    jae 7f
    test r15, r15
    jz 41f
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
41: mov rdi, r12
    mov esi, '['
    call sb_push_byte
    mov rax, [r14 + CE_points + VEC_ptr]
    movsxd rsi, dword ptr [rax + r15*8]
    mov rdi, r12
    call canvas_dump_int
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
    mov rax, [r14 + CE_points + VEC_ptr]
    movsxd rsi, dword ptr [rax + r15*8 + 4]
    mov rdi, r12
    call canvas_dump_int
    mov rdi, r12
    mov esi, ']'
    call sb_push_byte
    inc r15
    jmp 4b
7:  mov rdi, r12
    mov esi, ']'
    call sb_push_byte
    lea r15, [rip + .Lextra_fields]
71: cmp qword ptr [r15], 0
    je 74f
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
    mov rdi, [r15]
    call strlen
    mov rdx, rax
    mov rdi, r12
    mov rsi, [r15]
    call chat_json_quote
    mov rdi, r12
    mov esi, ':'
    call sb_push_byte
    mov rcx, [r15 + 8]
    mov rsi, [r14 + rcx]
    xor edx, edx
    test rsi, rsi
    jz 72f
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rcx, [r15 + 8]
    mov rsi, [r14 + rcx]
72: mov rdi, r12
    call chat_json_quote
    add r15, 16
    jmp 71b
74: mov rdi, r12
    mov esi, '}'
    call sb_push_byte
    inc r13
    jmp 1b
8:  mov rdi, r12
    lea rsi, [rip + .Lscene_end]
    call sb_push_cstr
    mov eax, 1
    cmp qword ptr [r12 + SB_len], 8 << 20
    jbe 9f
    xor eax, eax
9:  EPILOGUE

# Strict signed integer, <= 2^53-1; rax value, edx success.
FN scene_json_int
    PROLOGUE
    call json_number_text
    test rdx, rdx
    jz 8f
    mov rdi, rax
    mov rsi, rdx
    xor ebx, ebx
    cmp byte ptr [rdi], '-'
    jne 1f
    mov ebx, 1
    inc rdi
    dec rsi
1:  test rsi, rsi
    jz 8f
    cmp rsi, 16
    ja 8f
    mov r12, rsi
    call parse_u64
    cmp rdx, r12
    jne 8f
    mov rcx, 9007199254740991
    cmp rax, rcx
    ja 8f
    test ebx, ebx
    jz 2f
    neg rax
2:  mov edx, 1
    EPILOGUE
8:  xor eax, eax
    xor edx, edx
    EPILOGUE

# Parse(bytes,len) -> new owned scene or NULL. Complete validation before publish.
FN scene_parse
    PROLOGUE 48
    cmp rsi, 8 << 20
    ja .Lparse_null
    call json_parse_complete
    test rax, rax
    jz .Lparse_null
    mov r12, rax
    cmp dword ptr [r12], JT_OBJ
    jne .Lparse_null
    cmp dword ptr [r12 + 4], 4
    je 101f
    cmp dword ptr [r12 + 4], 5
    jne .Lparse_null
101:
    mov rdi, r12
    lea rsi, [rip + .Ltype]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lnative_type]
    call json_is
    test eax, eax
    jz .Lparse_null
    mov rdi, r12
    lea rsi, [rip + .Lversion]
    call json_get
    mov rdi, rax
    call scene_json_int
    test edx, edx
    jz .Lparse_null
    cmp rax, 1
    je 102f
    cmp rax, 2
    jne .Lparse_null
102: mov [rsp + 32], eax
    add eax, 3
    cmp [r12 + 4], eax
    jne .Lparse_null
    mov qword ptr [rsp + 40], 0
    cmp dword ptr [rsp + 32], 2
    jne 103f
    mov rdi, r12
    lea rsi, [rip + .Lexchange]
    call json_get
    mov [rsp + 40], rax
    test rax, rax
    jz .Lparse_null
103: mov rdi, r12
    lea rsi, [rip + .Lnext]
    call json_get
    mov rdi, rax
    call scene_json_int
    test edx, edx
    jz .Lparse_null
    test rax, rax
    jle .Lparse_null
    mov [rsp], rax
    mov rdi, r12
    lea rsi, [rip + .Lelements]
    call json_get
    mov r12, rax
    mov rdi, rax
    call json_type
    cmp eax, JT_ARR
    jne .Lparse_null
    mov rdi, r12
    call json_len
    cmp eax, 4096
    ja .Lparse_null
    mov [rsp + 8], eax
    call scene_new
    mov rbx, rax
    cmp dword ptr [rsp + 32], 2
    jne 104f
    mov rdi, [rsp + 40]
    mov esi, 3 << 20
    call scene_owned_json_string
    test rax, rax
    jz .Lparse_bad
    mov [rbx + SC_exchange], rax
104: mov rax, [rsp]
    mov [rbx + SC_next_id], rax
    xor r13d, r13d
.Lparse_element:
    cmp r13d, [rsp + 8]
    jae .Lparse_refs
    mov rdi, r12
    mov esi, r13d
    call json_at
    mov r14, rax
    cmp dword ptr [r14], JT_OBJ
    jne .Lparse_bad
    mov eax, 16
    cmp dword ptr [rsp + 32], 1
    je 105f
    mov eax, 23
105: cmp [r14 + 4], eax
    jne .Lparse_bad
    lea rdi, [rbx + SC_elements]
    mov esi, CE_SIZE
    call vec_push
    mov [rsp + 16], rax
    mov rdi, rax
    xor esi, esi
    mov edx, CE_SIZE
    call memset
    mov rax, [rsp + 16]
    mov dword ptr [rax + CE_fontsize], 24
    lea r15, [rip + .Lfields]
1:  cmp qword ptr [r15], 0
    je .Lparse_text
    cmp dword ptr [rsp + 32], 1
    jne 110f
    lea rax, [rip + .Lfields_extra_numeric]
    cmp r15, rax
    je .Lparse_text
110:
    mov rdi, r14
    mov rsi, [r15]
    call json_get
    mov rdi, rax
    call scene_json_int
    test edx, edx
    jz .Lparse_bad
    cmp rax, [r15 + 24]
    jl .Lparse_bad
    cmp rax, [r15 + 32]
    jg .Lparse_bad
    mov rcx, [rsp + 16]
    add rcx, [r15 + 8]
    cmp qword ptr [r15 + 16], 8
    je 2f
    mov [rcx], eax
    jmp 3f
2:  mov [rcx], rax
3:  add r15, 40
    jmp 1b
.Lparse_text:
    mov [rsp + 40], r14
    mov rdi, r14
    lea rsi, [rip + .Ltext]
    call json_get
    mov rdi, rax
    call json_str
    test rax, rax
    jz .Lparse_bad
    cmp rdx, 65536
    ja .Lparse_bad
    mov r15, rax
    mov [rsp + 24], rdx
    mov rdi, rax
    mov rsi, rdx
    call chat_text_valid
    test eax, eax
    jnz .Lparse_bad
    mov rdi, r15
    mov rsi, [rsp + 24]
    call mem_dup
    mov rcx, [rsp + 16]
    mov [rcx + CE_text], rax
    mov rdi, r14
    lea rsi, [rip + .Lpoints]
    call json_get
    mov r14, rax
    mov rdi, rax
    call json_type
    cmp eax, JT_ARR
    jne .Lparse_bad
    mov rdi, r14
    call json_len
    cmp eax, 8192
    ja .Lparse_bad
    xor r15d, r15d
.Lparse_point:
    mov rdi, r14
    call json_len
    cmp r15d, eax
    jae .Lparse_next
    mov rdi, r14
    mov esi, r15d
    call json_at
    mov [rsp + 24], rax
    mov rdi, rax
    call json_len
    cmp eax, 2
    jne .Lparse_bad
    mov rdi, [rsp + 24]
    xor esi, esi
    call json_at
    mov rdi, rax
    call scene_json_int
    test edx, edx
    jz .Lparse_bad
    cmp rax, -1000000
    jl .Lparse_bad
    cmp rax, 1000000
    jg .Lparse_bad
    mov [rsp + 28], eax
    # Keep the JV pointer separately: stack +24 is 8 bytes; +28 overlaps it.
    mov rdi, r14
    mov esi, r15d
    call json_at
    mov rdi, rax
    mov esi, 1
    call json_at
    mov rdi, rax
    call scene_json_int
    test edx, edx
    jz .Lparse_bad
    cmp rax, -1000000
    jl .Lparse_bad
    cmp rax, 1000000
    jg .Lparse_bad
    mov [rsp + 24], eax
    mov rdi, [rsp + 16]
    add rdi, CE_points
    mov esi, 8
    call vec_push
    mov ecx, [rsp + 28]
    mov [rax], ecx
    mov ecx, [rsp + 24]
    mov [rax + 4], ecx
    inc r15
    jmp .Lparse_point
.Lparse_next:
    cmp dword ptr [rsp + 32], 1
    je 108f
    lea r15, [rip + .Lextra_fields]
106: cmp qword ptr [r15], 0
    je 108f
    mov rdi, [rsp + 40]
    mov rsi, [r15]
    call json_get
    mov rdi, rax
    mov esi, 65536
    call scene_owned_json_string
    test rax, rax
    jz .Lparse_bad
    mov rcx, [rsp + 16]
    add rcx, [r15 + 8]
    mov [rcx], rax
    add r15, 16
    jmp 106b
108: inc r13
    jmp .Lparse_element
.Lparse_refs:
    xor r13d, r13d
1:  cmp r13, [rbx + SC_elements + VEC_len]
    jae .Lparse_ok
    imul r14, r13, CE_SIZE
    add r14, [rbx + SC_elements + VEC_ptr]
    mov rsi, [r14 + CE_id]
    cmp rsi, [rbx + SC_next_id]
    jae .Lparse_bad
    mov rdi, rbx
    call scene_find
    cmp rax, r14
    jne .Lparse_bad             # duplicate ID
    mov r15d, CE_from
2:  mov rsi, [r14 + r15]
    test rsi, rsi
    jz 3f
    cmp rsi, [r14 + CE_id]
    je .Lparse_bad
    mov rdi, rbx
    call scene_find
    test rax, rax
    jz .Lparse_bad
    cmp r15d, CE_frame
    jne 21f
    cmp dword ptr [rax + CE_kind], CT_FRAME
    jne .Lparse_bad
    cmp dword ptr [r14 + CE_kind], CT_FRAME
    je .Lparse_bad             # native v1 forbids nested frame cycles
    jmp 3f
21: cmp dword ptr [r14 + CE_kind], CT_ARROW
    jne .Lparse_bad
    cmp dword ptr [rax + CE_kind], CT_ARROW
    je .Lparse_bad
3:  add r15d, 8
    cmp r15d, CE_frame
    jbe 2b
    inc r13
    jmp 1b
.Lparse_ok:
    mov rdi, rbx
    call scene_geometry_valid
    test eax, eax
    jz .Lparse_bad
    mov rdi, rbx
    call scene_metadata_valid
    test eax, eax
    jz .Lparse_bad
    mov rax, rbx
    EPILOGUE
.Lparse_bad:
    mov rdi, rbx
    call scene_free
.Lparse_null:
    xor eax, eax
    EPILOGUE

FN scene_load
    PROLOGUE
    mov ecx, 8 << 20
    call file_read_limited
    test rax, rax
    jz 8f
    mov rbx, rax
    mov r13, rdx
    mov rdi, rax
    mov rsi, rdx
    call scene_parse
    test rax, rax
    jnz 1f
    mov rsi, r13
    mov rdi, rbx
    call canvas_import_excalidraw
1:  mov r12, rax
    mov rdi, rbx
    call mem_free
    mov rax, r12
    EPILOGUE
8:  xor eax, eax
    EPILOGUE

FN canvas_doc_save
    PROLOGUE SB_SIZE+8
    mov rbx, rdi
    call canvas_active
    cmp rax, [rbx + DOC_canvas]
    jne 101f
    call canvas_text_commit
101: mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, [rbx + DOC_canvas]
    mov rsi, rsp
    call scene_serialize
    test eax, eax
    jz 8f
    mov rdi, [rbx + DOC_path]
    mov rsi, [rsp + SB_ptr]
    mov rdx, [rsp + SB_len]
    call file_write_all
    mov r12, rax
    test rax, rax
    js 9f
    mov rax, [rbx + DOC_canvas]
    mov rcx, [rax + SC_hash]
    mov [rax + SC_saved_hash], rcx
    mov rdi, [rbx + DOC_path]
    call file_stamp
    mov [rbx + DOC_mtime], rax
    jmp 9f
8:  mov r12, -27
9:  mov rdi, rsp
    call sb_free
    mov rax, r12
    EPILOGUE

FN canvas_path
    PROLOGUE
    mov rbx, rdi
    call strlen
    mov r12, rax
    cmp rax, 12
    jb 1f
    lea rdi, [rbx + rax - 12]
    lea rsi, [rip + .Lsuffix]
    call strcmp_eq
    test eax, eax
    jnz 9f
1:  cmp r12, 11
    jb 8f
    lea rdi, [rbx + r12 - 11]
    lea rsi, [rip + .Lexsuffix]
    call strcmp_eq
    jmp 9f
8:  xor eax, eax
9:  EPILOGUE
.section .rodata
.Lscene_header: .asciz "{\"type\":\"rhun-canvas\",\"version\":2,\"next\":"
.Lscene_elements: .asciz ",\"elements\":["
.Lscene_end: .asciz "]}\n"
.Ltext_key: .asciz "\"text\":"
.Lpoints_key: .asciz ",\"points\":["
.Lelement_end: .asciz "]}"
.Lexchange_key: .asciz ",\"exchange\":"
.Lexchange: .asciz "exchange"
.Ltype: .asciz "type"
.Lnative_type: .asciz "rhun-canvas"
.Lversion: .asciz "version"
.Lnext: .asciz "next"
.Lelements: .asciz "elements"
.Ltext: .asciz "text"
.Lpoints: .asciz "points"
.Lsuffix: .asciz ".rhun-canvas"
.Lexsuffix: .asciz ".excalidraw"

.Lfield_id: .asciz "id"
.Lfield_kind: .asciz "kind"
.Lfield_x: .asciz "x"
.Lfield_y: .asciz "y"
.Lfield_w: .asciz "w"
.Lfield_h: .asciz "h"
.Lfield_color: .asciz "color"
.Lfield_from: .asciz "from"
.Lfield_to: .asciz "to"
.Lfield_frame: .asciz "frame"
.Lfield_group: .asciz "group"
.Lfield_seed: .asciz "seed"
.Lfield_angle: .asciz "angle"
 .p2align 3
.Lfield_role: .asciz "role"
.p2align 3
.Lfields:
    .quad .Lfield_role, CE_role, 8, 0, 4
    .quad .Lfield_id, CE_id, 8, 1, 9007199254740990
    .quad .Lfield_kind, CE_kind, 4, 1, 9
    .quad .Lfield_x, CE_x, 4, -1000000, 1000000
    .quad .Lfield_y, CE_y, 4, -1000000, 1000000
    .quad .Lfield_w, CE_w, 4, -1000000, 1000000
    .quad .Lfield_h, CE_h, 4, -1000000, 1000000
    .quad .Lfield_color, CE_color, 4, 0, 4294967295
    .quad .Lfield_from, CE_from, 8, 0, 9007199254740990
    .quad .Lfield_to, CE_to, 8, 0, 9007199254740990
    .quad .Lfield_frame, CE_frame, 8, 0, 9007199254740990
    .quad .Lfield_group, CE_group, 8, 0, 9007199254740990
    .quad .Lfield_seed, CE_seed, 8, 0, 9007199254740990
    .quad .Lfield_angle, CE_angle, 4, -360, 360
 .Lfields_extra_numeric:
    .quad .Lrough, CE_roughness, 4, 0, 3
    .quad .Lfill, CE_fill, 4, 0, 4294967295
    .quad .Lfont, CE_fontsize, 4, 8, 200
    .quad 0
.Lrough: .asciz "roughness"
.Lfill: .asciz "fill"
.Lfont: .asciz "fontsize"

.Lxid: .asciz "xid"
.Lraw: .asciz "raw"
.Limage: .asciz "image"
.Lgxid: .asciz "gxid"
.p2align 3
.Lextra_fields:
    .quad .Lxid, CE_xid, .Lraw, CE_raw, .Limage, CE_image, .Lgxid, CE_gxid, 0
.text
# String copy with strict UTF-8 and no retained parser pointer.
FN scene_owned_json_string
    PROLOGUE
    mov r12d, esi
    call json_str
    test rax, rax
    jz 8f
    cmp rdx, r12
    ja 8f
    mov rbx, rax
    mov r13, rdx
    mov rdi, rax
    mov rsi, rdx
    call chat_text_valid
    test eax, eax
    jnz 8f
    mov rdi, rbx
    mov rsi, r13
    call mem_dup
    EPILOGUE
8:  xor eax, eax
    EPILOGUE
