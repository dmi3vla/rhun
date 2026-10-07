# Deterministic Excalidraw JSON export; original metadata stays owned and retained.
.include "rhun.inc"
.include "canvas/canvas.inc"
.text
# Append external ID as a JSON string. Existing ID or stable rhun-<numeric ID>.
FN canvas_quote_element_id
    PROLOGUE 32
    mov rbx, rdi
    mov r12, rsi
    mov rsi, [r12 + CE_xid]
    test rsi, rsi
    jz 1f
    cmp byte ptr [rsi], 0
    je 1f
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rsi, [r12 + CE_xid]
    mov rdi, rbx
    call chat_json_quote
    EPILOGUE
1:  mov rdi, rbx
    lea rsi, [rip + .Lid_prefix]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, [r12 + CE_id]
    call sb_push_u64
    mov rdi, rbx
    mov esi, '"'
    call sb_push_byte
    EPILOGUE

# Append a JSON integer property ending with comma, own geometry already bounded.
canvas_export_number:
    PROLOGUE
    mov rbx, rdi
    mov r12, rdx
    mov r13, rsi
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rdi, rbx
    mov rsi, r13
    call chat_json_quote
    mov rdi, rbx
    mov esi, ':'
    call sb_push_byte
    mov rdi, rbx
    mov rsi, r12
    call canvas_dump_int
    mov rdi, rbx
    mov esi, ','
    call sb_push_byte
    EPILOGUE

# sb, ARGB -> quoted #rrggbb or transparent.
FN canvas_export_color
    PROLOGUE
    mov rbx, rdi
    mov r12d, esi
    test esi, esi
    jnz 1f
    lea rsi, [rip + .Ltransparent]
    call sb_push_cstr
    EPILOGUE
1:  lea rsi, [rip + .Lhash]
    call sb_push_cstr
    mov r13d, 20
2:  mov eax, r12d
    mov ecx, r13d
    shr eax, cl
    and eax, 15
    lea rcx, [rip + .Lhex]
    movzx esi, byte ptr [rcx + rax]
    mov rdi, rbx
    call sb_push_byte
    sub r13d, 4
    jns 2b
    mov rdi, rbx
    mov esi, '"'
    call sb_push_byte
    EPILOGUE

# Convert integer degrees to deterministic six-place radians JSON.
canvas_export_angle:
    PROLOGUE 32
    mov rbx, rdi
    cvtsi2sd xmm0, esi
    mulsd xmm0, [rip + .Lrad_micro]
    cvtsd2si r12, xmm0
    test r12, r12
    jns 1f
    mov esi, '-'
    call sb_push_byte
    neg r12
1:  mov rax, r12
    xor edx, edx
    mov ecx, 1000000
    div rcx
    mov r13, rdx
    mov rdi, rbx
    mov rsi, rax
    call sb_push_u64
    mov rdi, rbx
    mov esi, '.'
    call sb_push_byte
    mov rax, r13
    lea rdi, [rsp + 16]
    mov byte ptr [rdi], 0
    mov ecx, 6
2:  xor edx, edx
    mov esi, 10
    div rsi
    add dl, '0'
    dec rdi
    mov [rdi], dl
    dec ecx
    jnz 2b
    mov rsi, rdi
    mov rdi, rbx
    mov edx, 6
    call sb_push
    mov rdi, rbx
    mov esi, ','
    call sb_push_byte
    EPILOGUE

# Copy unknown original element fields, excluding regenerated IR properties.
canvas_export_metadata:
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov rdi, rsi
    test rdi, rdi
    jz .Lmeta_defaults
    cmp byte ptr [rdi], 0
    je .Lmeta_defaults
    call strlen
    mov rsi, rax
    mov rdi, r12
    call json_parse_complete
    test rax, rax
    jz .Lmeta_defaults
    cmp dword ptr [rax], JT_OBJ
    jne .Lmeta_defaults
    mov r12, rax
    xor r13d, r13d
1:  cmp r13d, [r12 + 4]
    jae 9f
    mov rax, [r12 + 8]
    imul rcx, r13, 16
    mov r14, [rax + rcx]
    mov r15, [rax + rcx + 8]
    mov rdi, r14
    call canvas_export_skip_key
    test eax, eax
    jnz 2f
    mov rdi, rbx
    mov rsi, r14
    call json_dump
    mov rdi, rbx
    mov esi, ':'
    call sb_push_byte
    mov rdi, rbx
    mov rsi, r15
    call json_dump
    mov rdi, rbx
    mov esi, ','
    call sb_push_byte
2:  inc r13d
    jmp 1b
.Lmeta_defaults:
    mov rdi, rbx
    lea rsi, [rip + .Ldefaults]
    call sb_push_cstr
9:  EPILOGUE

canvas_export_skip_key:
    PROLOGUE
    mov rbx, rdi
    lea r12, [rip + .Lskip_keys]
1:  cmp qword ptr [r12], 0
    je 8f
    mov rdi, rbx
    mov rsi, [r12]
    call json_is
    test eax, eax
    jnz 9f
    add r12, 8
    jmp 1b
8:  xor eax, eax
9:  EPILOGUE

# All primitives and references regenerate from IR, metadata is retained above.
FN canvas_export_excalidraw
    PROLOGUE 32
    mov rbx, rdi
    mov r12, rsi
    xor r13d, r13d
105: cmp r13, [rbx + SC_elements + VEC_len]
    jae 106f
    imul rax, r13, CE_SIZE
    add rax, [rbx + SC_elements + VEC_ptr]
    cmp dword ptr [rax + CE_kind], CT_IMAGE
    jne 107f
    xor eax, eax
    EPILOGUE
107: inc r13
    jmp 105b
106:
    mov rdi, r12
    lea rsi, [rip + .Lroot_start]
    call sb_push_cstr
    # Preserve root assets/appState/extensions independently of element iteration.
    mov rdi, [rbx + SC_exchange]
    test rdi, rdi
    jz .Lroot_defaults
    cmp byte ptr [rdi], 0
    je .Lroot_defaults
    call strlen
    mov rsi, rax
    mov rdi, [rbx + SC_exchange]
    call json_parse_complete
    test rax, rax
    jz .Lroot_defaults
    cmp dword ptr [rax], JT_OBJ
    jne .Lroot_defaults
    mov r13, rax
    xor r14d, r14d
1:  cmp r14d, [r13 + 4]
    jae .Lexport_elements
    mov rax, [r13 + 8]
    imul rcx, r14, 16
    mov r15, [rax + rcx]
    mov rax, [rax + rcx + 8]
    mov [rsp], rax
    mov rdi, r15
    lea rsi, [rip + .Ltype_key]
    call json_is
    test eax, eax
    jnz 2f
    mov rdi, r15
    lea rsi, [rip + .Lversion_key]
    call json_is
    test eax, eax
    jnz 2f
    mov rdi, r15
    lea rsi, [rip + .Lelements_key]
    call json_is
    test eax, eax
    jnz 2f
    mov rdi, r12
    mov rsi, r15
    call json_dump
    mov rdi, r12
    mov esi, ':'
    call sb_push_byte
    mov rdi, r12
    mov rsi, [rsp]
    call json_dump
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
2:  inc r14
    jmp 1b
.Lroot_defaults:
    mov rdi, r12
    lea rsi, [rip + .Lroot_default_fields]
    call sb_push_cstr
.Lexport_elements:
    mov rdi, r12
    lea rsi, [rip + .Lelements_start]
    call sb_push_cstr
    xor r13d, r13d
.Lexport_element:
    cmp r13, [rbx + SC_elements + VEC_len]
    jae .Lexport_end
    test r13, r13
    jz 1f
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
1:  imul r14, r13, CE_SIZE
    add r14, [rbx + SC_elements + VEC_ptr]
    cmp dword ptr [r14 + CE_kind], CT_UNSUPPORTED
    jne .Lexport_supported
    mov rsi, [r14 + CE_raw]
    test rsi, rsi
    jz .Lexport_supported
    cmp byte ptr [rsi], 0
    je .Lexport_supported
    mov rdi, r12
    call sb_push_cstr
    jmp .Lexport_next
.Lexport_supported:
    mov rdi, r12
    mov esi, '{'
    call sb_push_byte
    mov rdi, r12
    mov rsi, [r14 + CE_raw]
    call canvas_export_metadata
    mov rdi, r12
    lea rsi, [rip + .Lid_key]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, r14
    call canvas_quote_element_id
    mov rdi, r12
    lea rsi, [rip + .Ltype_start]
    call sb_push_cstr
    mov eax, [r14 + CE_kind]
    dec eax
    cmp eax, 7
    jbe 3f
    xor eax, eax
3:  lea rcx, [rip + .Lkinds]
    mov r15, [rcx + rax*8]
    mov rdi, r15
    call strlen
    mov rdx, rax
    mov rdi, r12
    mov rsi, r15
    call chat_json_quote
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
    lea r15, [rip + .Lgeometry]
4:  cmp qword ptr [r15], 0
    je 5f
    mov rcx, [r15 + 8]
    movsxd rdx, dword ptr [r14 + rcx]
    mov rdi, r12
    mov rsi, [r15]
    call canvas_export_number
    add r15, 16
    jmp 4b
5:  mov rdi, r12
    lea rsi, [rip + .Lseed]
    mov rdx, [r14 + CE_seed]
    call canvas_export_number
    mov rdi, r12
    lea rsi, [rip + .Lrough]
    mov edx, [r14 + CE_roughness]
    call canvas_export_number
    mov rdi, r12
    lea rsi, [rip + .Langle_start]
    call sb_push_cstr
    mov rdi, r12
    mov esi, [r14 + CE_angle]
    call canvas_export_angle
    mov rdi, r12
    lea rsi, [rip + .Lstroke_start]
    call sb_push_cstr
    mov rdi, r12
    mov esi, [r14 + CE_color]
    call canvas_export_color
    mov rdi, r12
    lea rsi, [rip + .Lfill_start]
    call sb_push_cstr
    mov rdi, r12
    mov esi, [r14 + CE_fill]
    call canvas_export_color
    mov rdi, r12
    lea rsi, [rip + .Lgroup_start]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, r14
    call canvas_export_groups
7:  mov rdi, r12
    lea rsi, [rip + .Lframe_start]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, [r14 + CE_frame]
    call scene_find
    mov rdi, r12
    test rax, rax
    jz 8f
    mov rsi, rax
    call canvas_quote_element_id
    jmp 9f
8:  lea rsi, [rip + .Lnull]
    call sb_push_cstr
9:  mov rdi, r12
    mov esi, ','
    call sb_push_byte
    mov eax, [r14 + CE_kind]
    cmp eax, CT_ARROW
    je .Lexport_linear
    cmp eax, CT_LINE
    je .Lexport_linear
    cmp eax, CT_STROKE
    je .Lexport_stroke
    cmp eax, CT_TEXT
    je .Lexport_text
    cmp eax, CT_FRAME
    jne .Lexport_finish_element
    mov rax, [r14 + CE_raw]
    test rax, rax
    jz 103f
    cmp byte ptr [rax], 0
    jne .Lexport_finish_element
103:
    mov rdi, r12
    lea rsi, [rip + .Lframe_name]
    call sb_push_cstr
    jmp .Lexport_finish_element
.Lexport_text:
    mov rdi, r12
    lea rsi, [rip + .Ltext_start]
    call sb_push_cstr
    mov rsi, [r14 + CE_text]
    xor edx, edx
    test rsi, rsi
    jz 101f
    mov rdi, rsi
    call strlen
    mov rdx, rax
101:
    mov rdi, r12
    mov rsi, [r14 + CE_text]
    call chat_json_quote
    mov rdi, r12
    lea rsi, [rip + .Loriginal_start]
    call sb_push_cstr
    mov rsi, [r14 + CE_text]
    xor edx, edx
    test rsi, rsi
    jz 102f
    mov rdi, rsi
    call strlen
    mov rdx, rax
102: mov rdi, r12
    mov rsi, [r14 + CE_text]
    call chat_json_quote
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
    mov rdi, r12
    lea rsi, [rip + .Lfont_key]
    mov edx, [r14 + CE_fontsize]
    call canvas_export_number
    # Existing text metadata retains font/alignment; defaults only for new text.
    mov rax, [r14 + CE_raw]
    test rax, rax
    jz 1f
    cmp byte ptr [rax], 0
    jne .Lexport_finish_element
1:  mov rdi, r12
    lea rsi, [rip + .Ltext_defaults]
    call sb_push_cstr
    jmp .Lexport_finish_element
.Lexport_linear:
    mov rdi, r12
    lea rsi, [rip + .Llinear_start]
    call sb_push_cstr
    mov rdi, r12
    movsxd rsi, dword ptr [r14 + CE_w]
    call canvas_dump_int
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
    mov rdi, r12
    movsxd rsi, dword ptr [r14 + CE_h]
    call canvas_dump_int
    mov rdi, r12
    lea rsi, [rip + .Llinear_end]
    call sb_push_cstr
    mov rdi, r12
    lea rsi, [rip + .Lstart_binding]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, [r14 + CE_from]
    mov rdx, r12
    call canvas_export_binding
    mov rdi, r12
    lea rsi, [rip + .Lend_binding]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, [r14 + CE_to]
    mov rdx, r12
    call canvas_export_binding
    mov rdi, r12
    lea rsi, [rip + .Larrowheads]
    call sb_push_cstr
    cmp dword ptr [r14 + CE_kind], CT_ARROW
    jne 2f
    mov rdi, r12
    lea rsi, [rip + .Lhead_arrow]
    call sb_push_cstr
    jmp 3f
2:  mov rdi, r12
    lea rsi, [rip + .Lnull]
    call sb_push_cstr
3:  mov rdi, r12
    mov esi, ','
    call sb_push_byte
    jmp .Lexport_finish_element
.Lexport_stroke:
    mov rdi, r12
    lea rsi, [rip + .Lpoints_start]
    call sb_push_cstr
    xor r15d, r15d
1:  cmp r15, [r14 + CE_points + VEC_len]
    jae 4f
    test r15, r15
    jz 2f
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
2:  mov rdi, r12
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
    jmp 1b
4:  mov rdi, r12
    lea rsi, [rip + .Lstroke_end]
    call sb_push_cstr
.Lexport_finish_element:
    mov rdi, rbx
    mov rsi, r14
    mov rdx, r12
    call canvas_export_bound_elements
    mov rdi, r12
    lea rsi, [rip + .Lfinish_element]
    call sb_push_cstr
.Lexport_next:
    inc r13
    jmp .Lexport_element
.Lexport_end:
    mov rdi, r12
    lea rsi, [rip + .Lroot_end]
    call sb_push_cstr
    mov eax, 1
    cmp qword ptr [r12 + SB_len], 8 << 20
    jbe 9f
    xor eax, eax
9:  EPILOGUE

canvas_export_binding:
    PROLOGUE
    mov rbx, rdx
    call scene_find
    mov r12, rax
    test rax, rax
    jz 1f
    mov rdi, rbx
    lea rsi, [rip + .Lbinding_start]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, r12
    call canvas_quote_element_id
    mov rdi, rbx
    lea rsi, [rip + .Lbinding_end]
    call sb_push_cstr
    EPILOGUE
1:  mov rdi, rbx
    lea rsi, [rip + .Lnull]
    call sb_push_cstr
    EPILOGUE
.section .rodata
.Lroot_start: .asciz "{\"type\":\"excalidraw\",\"version\":2,"
.Lroot_default_fields: .asciz "\"source\":\"rhun-native-canvas\",\"appState\":{},\"files\":{},"
.Lelements_start: .asciz "\"elements\":["
.Lroot_end: .asciz "]}\n"
.Lid_prefix: .asciz "\"rhun-"
.Lid_key: .asciz "\"id\":"
.Ltype_start: .asciz ",\"type\":"
.Langle_start: .asciz "\"angle\":"
.Lstroke_start: .asciz "\"strokeColor\":"
.Lfill_start: .asciz ",\"backgroundColor\":"
.Lgroup_start: .asciz ",\"groupIds\":"
.Lgroup_prefix: .asciz "\"rhun-group-"
.Lframe_start: .asciz ",\"frameId\":"
.Lframe_name: .asciz "\"name\":null,"
.Ltext_start: .asciz "\"text\":"
.Loriginal_start: .asciz ",\"originalText\":"
.Ltext_defaults: .asciz "\"fontFamily\":1,\"textAlign\":\"left\",\"verticalAlign\":\"top\",\"containerId\":null,\"autoResize\":false,\"lineHeight\":1.25,"
.Llinear_start: .asciz "\"points\":[[0,0],["
.Llinear_end: .asciz "]],"
.Lstart_binding: .asciz "\"startBinding\":"
.Lend_binding: .asciz ",\"endBinding\":"
.Lbinding_start: .asciz "{\"elementId\":"
.Lbinding_end: .asciz ",\"fixedPoint\":[0.5,0.5],\"mode\":\"orbit\"}"
.Larrowheads: .asciz ",\"startArrowhead\":null,\"endArrowhead\":"
.Lhead_arrow: .asciz "\"arrow\""
.Lpoints_start: .asciz "\"points\":["
.Lstroke_end: .asciz "],\"pressures\":[],\"simulatePressure\":true,"
.Lfinish_element: .asciz "\"version\":1,\"versionNonce\":0,\"isDeleted\":false,\"index\":null,\"updated\":0,\"created\":null}"
.Ldefaults: .asciz "\"fillStyle\":\"solid\",\"strokeWidth\":1,\"strokeStyle\":\"solid\",\"roundness\":null,\"opacity\":100,\"link\":null,\"locked\":false,"
.Lnull: .asciz "null"
.Ltransparent: .asciz "\"transparent\""
.Lhash: .asciz "\"#"
.Lhex: .ascii "0123456789abcdef"
.Lkind_rectangle: .asciz "rectangle"
.Lkind_ellipse: .asciz "ellipse"
.Lkind_arrow: .asciz "arrow"
.Lkind_text: .asciz "text"
.Lkind_frame: .asciz "frame"
.Lkind_line: .asciz "line"
.Lkind_freedraw: .asciz "freedraw"
.Lkind_image: .asciz "image"
.Ltype_key: .asciz "type"
.Lversion_key: .asciz "version"
.Lelements_key: .asciz "elements"
.Lseed: .asciz "seed"
.Lrough: .asciz "roughness"
.Lfont_key: .asciz "fontSize"
.Lx: .asciz "x"
.Ly: .asciz "y"
.Lw: .asciz "width"
.Lh: .asciz "height"
.p2align 3
.Lkinds: .quad .Lkind_rectangle, .Lkind_ellipse, .Lkind_arrow, .Lkind_text, .Lkind_frame, .Lkind_line, .Lkind_freedraw, .Lkind_image
.Lgeometry: .quad .Lx, CE_x, .Ly, CE_y, .Lw, CE_w, .Lh, CE_h, 0
.Lrad_micro: .double 17453.292519943295

.Lskip_0: .asciz "id"
.Lskip_1: .asciz "type"
.Lskip_2: .asciz "x"
.Lskip_3: .asciz "y"
.Lskip_4: .asciz "width"
.Lskip_5: .asciz "height"
.Lskip_6: .asciz "angle"
.Lskip_7: .asciz "seed"
.Lskip_8: .asciz "roughness"
.Lskip_9: .asciz "strokeColor"
.Lskip_10: .asciz "backgroundColor"
.Lskip_11: .asciz "groupIds"
.Lskip_12: .asciz "frameId"
.Lskip_13: .asciz "startBinding"
.Lskip_14: .asciz "endBinding"
.Lskip_15: .asciz "text"
.Lskip_16: .asciz "originalText"
.Lskip_17: .asciz "points"
.Lskip_18: .asciz "version"
.Lskip_19: .asciz "versionNonce"
.Lskip_20: .asciz "isDeleted"
.Lskip_21: .asciz "fontSize"
.Lskip_22: .asciz "boundElements"
.Lskip_23: .asciz "index"
.Lskip_24: .asciz "updated"
.Lskip_25: .asciz "created"
.Lskip_26: .asciz "startArrowhead"
.Lskip_27: .asciz "endArrowhead"
.Lskip_28: .asciz "pressures"
.Lskip_29: .asciz "simulatePressure"
.Lskip_30: .asciz "name"
.p2align 3
.Lskip_keys: .quad .Lskip_0, .Lskip_1, .Lskip_2, .Lskip_3, .Lskip_4, .Lskip_5, .Lskip_6, .Lskip_7, .Lskip_8, .Lskip_9, .Lskip_10, .Lskip_11, .Lskip_12, .Lskip_13, .Lskip_14, .Lskip_15, .Lskip_16, .Lskip_17, .Lskip_18, .Lskip_19, .Lskip_20, .Lskip_21, .Lskip_22, .Lskip_23, .Lskip_24, .Lskip_25, .Lskip_26, .Lskip_27, .Lskip_28, .Lskip_29, 0

.text
canvas_export_groups:
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    cmp qword ptr [r12 + CE_group], 0
    je 8f
    mov r13, [r12 + CE_gxid]
    test r13, r13
    jz 5f
    cmp byte ptr [r13], 0
    je 5f
    mov rdi, [r12 + CE_raw]
    test rdi, rdi
    jz 4f
    call strlen
    mov rsi, rax
    mov rdi, [r12 + CE_raw]
    call json_parse_complete
    test rax, rax
    jz 4f
    mov rdi, rax
    lea rsi, [rip + .Lgroupids_key]
    call json_get
    mov r14, rax
    mov rdi, rax
    xor esi, esi
    call json_at
    mov rdi, rax
    mov rsi, r13
    call json_is
    test eax, eax
    jz 4f
    mov rdi, rbx
    mov rsi, r14
    call json_dump
    EPILOGUE
4:  mov rdi, rbx
    mov esi, '['
    call sb_push_byte
    mov rdi, r13
    call strlen
    mov rdx, rax
    mov rdi, rbx
    mov rsi, r13
    call chat_json_quote
    jmp 7f
5:  mov rdi, rbx
    mov esi, '['
    call sb_push_byte
    mov rdi, rbx
    lea rsi, [rip + .Lgroup_prefix]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, [r12 + CE_group]
    call sb_push_u64
    mov rdi, rbx
    mov esi, '"'
    call sb_push_byte
7:  mov rdi, rbx
    mov esi, ']'
    call sb_push_byte
    EPILOGUE
8:  mov rdi, rbx
    lea rsi, [rip + .Lempty_groups]
    call sb_push_cstr
    EPILOGUE
.section .rodata
.Lempty_groups: .asciz "[]"
.Lgroupids_key: .asciz "groupIds"

.text
# Derive the inverse binding list from the same source edges.
canvas_export_bound_elements:
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov rdi, r13
    lea rsi, [rip + .Lbound_open]
    call sb_push_cstr
    xor r14d, r14d
    xor r15d, r15d
1:  cmp r14, [rbx + SC_elements + VEC_len]
    jae 8f
    imul rax, r14, CE_SIZE
    add rax, [rbx + SC_elements + VEC_ptr]
    cmp dword ptr [rax + CE_kind], CT_ARROW
    jne 7f
    mov rcx, [r12 + CE_id]
    cmp rcx, [rax + CE_from]
    je 2f
    cmp rcx, [rax + CE_to]
    jne 7f
2:  test r15d, r15d
    jz 3f
    mov rdi, r13
    mov esi, ','
    call sb_push_byte
3:  mov rdi, r13
    lea rsi, [rip + .Lbound_id]
    call sb_push_cstr
    imul rsi, r14, CE_SIZE
    add rsi, [rbx + SC_elements + VEC_ptr]
    mov rdi, r13
    call canvas_quote_element_id
    mov rdi, r13
    lea rsi, [rip + .Lbound_type]
    call sb_push_cstr
    inc r15d
7:  inc r14
    jmp 1b
8:  mov rdi, r13
    lea rsi, [rip + .Lbound_close]
    call sb_push_cstr
    EPILOGUE
.section .rodata
.Lbound_open: .asciz "\"boundElements\":["
.Lbound_id: .asciz "{\"id\":"
.Lbound_type: .asciz ",\"type\":\"arrow\"}"
.Lbound_close: .asciz "],"
