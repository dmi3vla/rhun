# Closed semantic UI schema. Returned model owns all strings and nodes.
.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN canvas_ui_free
    PROLOGUE
    mov rbx, rdi
    test rbx, rbx
    jz 9f
    xor r12d, r12d
1:  cmp r12, [rbx + UM_nodes + VEC_len]
    jae 8f
    imul r13, r12, UC_SIZE
    add r13, [rbx + UM_nodes + VEC_ptr]
    mov rdi, [r13 + UC_text]
    call mem_free
    mov rdi, [r13 + UC_action]
    call mem_free
    inc r12
    jmp 1b
8:  lea rdi, [rbx + UM_nodes]
    call vec_free
    mov rdi, rbx
    call mem_free
9:  EPILOGUE
FN canvas_ui_find
    mov rcx, [rdi + UM_nodes + VEC_len]
    mov rax, [rdi + UM_nodes + VEC_ptr]
1:  test rcx, rcx
    jz 2f
    cmp [rax + UC_id], rsi
    je 3f
    add rax, UC_SIZE
    dec rcx
    jmp 1b
2:  xor eax, eax
3:  ret

FN canvas_ui_parse
    PROLOGUE 48
    mov [rsp], rdx
    cmp rsi, 1 << 20
    ja .Lui_null
    call json_parse_complete
    test rax, rax
    jz .Lui_null
    mov r12, rax
    cmp dword ptr [rax], JT_OBJ
    jne .Lui_null
    cmp dword ptr [rax + 4], 5
    jne .Lui_null
    mov rdi, rax
    lea rsi, [rip + .Ltype]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lui_type]
    call json_is
    test eax, eax
    jz .Lui_null
    mov rdi, r12
    lea rsi, [rip + .Lversion]
    call json_get
    mov rdi, rax
    call scene_json_int
    test edx, edx
    jz .Lui_null
    cmp rax, 1
    jne .Lui_null
    mov edi, UM_SIZE
    call mem_alloc
    mov rbx, rax
    mov rdi, r12
    lea rsi, [rip + .Lrevision]
    call json_get
    mov rdi, rax
    call scene_json_int
    test edx, edx
    jz .Lui_bad
    test rax, rax
    js .Lui_bad
    mov [rbx + UM_revision], rax
    mov rdi, r12
    lea rsi, [rip + .Lroot]
    call json_get
    mov rdi, rax
    call scene_json_int
    test edx, edx
    jz .Lui_bad
    test rax, rax
    jle .Lui_bad
    mov [rbx + UM_root], rax
    mov rdi, r12
    lea rsi, [rip + .Lcomponents]
    call json_get
    mov [rsp + 8], rax
    mov rdi, rax
    call json_type
    cmp eax, JT_ARR
    jne .Lui_bad
    mov rdi, [rsp + 8]
    call json_len
    test eax, eax
    jz .Lui_bad
    cmp eax, 512
    ja .Lui_bad
    mov [rsp + 16], eax
    xor r13d, r13d
.Lui_node:
    cmp r13d, [rsp + 16]
    jae .Lui_links
    mov rdi, [rsp + 8]
    mov esi, r13d
    call json_at
    mov r14, rax
    mov rdi, rax
    call json_type
    cmp eax, JT_OBJ
    jne .Lui_bad
    cmp dword ptr [r14 + 4], 10
    jne .Lui_bad
    lea rdi, [rbx + UM_nodes]
    mov esi, UC_SIZE
    call vec_push
    mov r15, rax
    mov rdi, rax
    xor esi, esi
    mov edx, UC_SIZE
    call memset
    lea rax, [rip + .Lnumeric]
    mov [rsp + 24], rax
1:  mov rax, [rsp + 24]
    cmp qword ptr [rax], 0
    je 3f
    mov rdi, r14
    mov rsi, [rax]
    call json_get
    mov rdi, rax
    call scene_json_int
    test edx, edx
    jz .Lui_bad
    mov rcx, [rsp + 24]
    cmp rax, [rcx + 16]
    jl .Lui_bad
    cmp rax, [rcx + 24]
    jg .Lui_bad
    mov rcx, [rcx + 8]
    cmp rcx, UC_type
    jb 2f
    mov [r15 + rcx], eax
    jmp 21f
2:  mov [r15 + rcx], rax
21: add qword ptr [rsp + 24], 32
    jmp 1b
3:  mov rdi, r14
    lea rsi, [rip + .Ltype]
    call json_get
    mov [rsp + 32], rax
    mov dword ptr [r15 + UC_type], -1
    xor r12d, r12d
4:  lea rax, [rip + .Ltypes]
    mov rsi, [rax + r12*8]
    mov rdi, [rsp + 32]
    call json_is
    test eax, eax
    jnz 5f
    inc r12d
    cmp r12d, 7
    jb 4b
    jmp .Lui_bad
5:  mov [r15 + UC_type], r12d
    mov rdi, r14
    lea rsi, [rip + .Ltext]
    call json_get
    mov rdi, rax
    mov esi, 65536
    call scene_owned_json_string
    test rax, rax
    jz .Lui_bad
    mov [r15 + UC_text], rax
    mov rdi, r14
    lea rsi, [rip + .Laction]
    call json_get
    mov rdi, rax
    mov esi, 256
    call scene_owned_json_string
    test rax, rax
    jz .Lui_bad
    mov [r15 + UC_action], rax
    mov rdi, [rsp]
    test rdi, rdi
    jz 6f
    mov rsi, [r15 + UC_source]
    call scene_find
    test rax, rax
    jz .Lui_bad
6:  inc r13
    jmp .Lui_node
.Lui_links:
    xor r13d, r13d
1:  cmp r13, [rbx + UM_nodes + VEC_len]
    jae .Lui_ok
    imul r14, r13, UC_SIZE
    add r14, [rbx + UM_nodes + VEC_ptr]
    mov rdi, rbx
    mov rsi, [r14 + UC_id]
    call canvas_ui_find
    cmp rax, r14
    jne .Lui_bad
    mov rax, [r14 + UC_id]
    cmp rax, [rbx + UM_root]
    jne 2f
    cmp qword ptr [r14 + UC_parent], 0
    jne .Lui_bad
    jmp 5f
2:  mov r15, r14
    xor r12d, r12d
3:  inc r12d
    cmp r12d, 32
    ja .Lui_bad
    mov rdi, rbx
    mov rsi, [r15 + UC_parent]
    call canvas_ui_find
    test rax, rax
    jz .Lui_bad
    mov r15, rax
    cmp dword ptr [rax + UC_type], U_TEXT
    jae .Lui_bad
    mov rax, [rax + UC_id]
    cmp rax, [rbx + UM_root]
    jne 3b
5:  inc r13
    jmp 1b
.Lui_ok:
    mov rdi, rbx
    mov rsi, [rbx + UM_root]
    call canvas_ui_find
    test rax, rax
    jz .Lui_bad
    mov rax, rbx
    EPILOGUE
.Lui_bad:
    mov rdi, rbx
    call canvas_ui_free
.Lui_null:
    xor eax, eax
    EPILOGUE

FN canvas_ui_valid
    PROLOGUE
    mov rbx, rdi
    mov rdi, [rbx + SC_ui]
    test rdi, rdi
    jz 1f
    cmp byte ptr [rdi], 0
    je 1f
    call strlen
    mov rsi, rax
    mov rdi, [rbx + SC_ui]
    mov rdx, rbx
    call canvas_ui_parse
    test rax, rax
    jz 8f
    mov rdi, rax
    call canvas_ui_free
1:  mov eax, 1
    EPILOGUE
8:  xor eax, eax
    EPILOGUE

FN canvas_ui_model
    PROLOGUE
    mov rbx, rdi
    mov rdi, [rbx + SC_ui]
    test rdi, rdi
    jz 8f
    cmp byte ptr [rdi], 0
    je 8f
    call strlen
    mov rsi, rax
    mov rdi, [rbx + SC_ui]
    mov rdx, rbx
    call canvas_ui_parse
    EPILOGUE
8:  xor eax, eax
    EPILOGUE

FN canvas_ui_serialize
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov rdi, r12
    lea rsi, [rip + .Lheader]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, [rbx + UM_revision]
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Lroot_key]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, [rbx + UM_root]
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Lnodes_key]
    call sb_push_cstr
    xor r13d, r13d
1:  cmp r13, [rbx + UM_nodes + VEC_len]
    jae 8f
    test r13, r13
    jz 2f
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
2:  imul r14, r13, UC_SIZE
    add r14, [rbx + UM_nodes + VEC_ptr]
    mov rdi, r12
    mov esi, '{'
    call sb_push_byte
    lea r15, [rip + .Lnumeric]
3:  cmp qword ptr [r15], 0
    je 4f
    mov rcx, [r15 + 8]
    mov rdx, [r14 + rcx]
    cmp rcx, UC_type
    jb 31f
    mov edx, [r14 + rcx]
31: mov rdi, r12
    mov rsi, [r15]
    call canvas_export_number
    add r15, 32
    jmp 3b
4:  mov rdi, r12
    lea rsi, [rip + .Ltype_key]
    call sb_push_cstr
    mov eax, [r14 + UC_type]
    lea rcx, [rip + .Ltypes]
    mov r15, [rcx + rax*8]
    mov rdi, r15
    call strlen
    mov rdx, rax
    mov rsi, r15
    mov rdi, r12
    call chat_json_quote
    mov rdi, r12
    lea rsi, [rip + .Ltext_key]
    call sb_push_cstr
    mov rdi, [r14 + UC_text]
    call strlen
    mov rdx, rax
    mov rdi, r12
    mov rsi, [r14 + UC_text]
    call chat_json_quote
    mov rdi, r12
    lea rsi, [rip + .Laction_key]
    call sb_push_cstr
    mov rdi, [r14 + UC_action]
    call strlen
    mov rdx, rax
    mov rdi, r12
    mov rsi, [r14 + UC_action]
    call chat_json_quote
    mov rdi, r12
    mov esi, '}'
    call sb_push_byte
    inc r13
    jmp 1b
8:  mov rdi, r12
    lea rsi, [rip + .Lend]
    call sb_push_cstr
    EPILOGUE
.section .rodata
.Ltype: .asciz "type"
.Lui_type: .asciz "rhun-ui"
.Lversion: .asciz "version"
.Lrevision: .asciz "revision"
.Lroot: .asciz "root"
.Lcomponents: .asciz "components"
.Lid: .asciz "id"
.Lsource: .asciz "source"
.Lparent: .asciz "parent"
.Lwidth: .asciz "width"
.Lheight: .asciz "height"
.Lpadding: .asciz "padding"
.Lgap: .asciz "gap"
.Ltext: .asciz "text"
.Laction: .asciz "action"
.Lrow: .asciz "row"
.Lcolumn: .asciz "column"
.Lcard: .asciz "card"
.Llist: .asciz "list"
.Lbutton: .asciz "button"
.Linput: .asciz "input"
.Lheader: .asciz "{\"type\":\"rhun-ui\",\"version\":1,\"revision\":"
.Lroot_key: .asciz ",\"root\":"
.Lnodes_key: .asciz ",\"components\":["
.Ltype_key: .asciz "\"type\":"
.Ltext_key: .asciz ",\"text\":"
.Laction_key: .asciz ",\"action\":"
.Lend: .asciz "]}"
.p2align 3
.Ltypes: .quad .Lrow, .Lcolumn, .Lcard, .Llist, .Ltext, .Lbutton, .Linput
.Lnumeric:
    .quad .Lid, UC_id, 1, 9007199254740990
    .quad .Lsource, UC_source, 1, 9007199254740990
    .quad .Lparent, UC_parent, 0, 9007199254740990
    .quad .Lwidth, UC_width, 0, 10000
    .quad .Lheight, UC_height, 0, 10000
    .quad .Lpadding, UC_padding, 0, 256
    .quad .Lgap, UC_gap, 0, 256
    .quad 0
.text
FN canvas_ui_source
    mov rcx, [rdi + UM_nodes + VEC_len]
    mov rax, [rdi + UM_nodes + VEC_ptr]
1:  test rcx, rcx
    jz 2f
    cmp [rax + UC_source], rsi
    je 3f
    add rax, UC_SIZE
    dec rcx
    jmp 1b
2:  xor eax, eax
3:  ret
