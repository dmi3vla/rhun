# Closed proposals. All borrowed JSON is copied before any subsequent parse.
.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN canvas_proposal_free
    PROLOGUE
    mov rbx, rdi
    test rbx, rbx
    jz 9f
    xor r12d, r12d
1:  cmp r12, [rbx + CP_ops + VEC_len]
    jae 8f
    imul rax, r12, PO_SIZE
    add rax, [rbx + CP_ops + VEC_ptr]
    mov rdi, [rax + PO_raw]
    call mem_free
    inc r12
    jmp 1b
8:  lea rdi, [rbx + CP_ops]
    call vec_free
    mov rdi, [rbx + CP_candidate]
    call scene_free
    mov rdi, [rbx + CP_explanation]
    call mem_free
    mov rdi, rbx
    call mem_free
9:  EPILOGUE
FN canvas_proposal_find
    mov rcx, [rdi + CP_ops + VEC_len]
    mov rax, [rdi + CP_ops + VEC_ptr]
1:  test rcx, rcx
    jz 2f
    cmp [rax + PO_id], rsi
    je 3f
    add rax, PO_SIZE
    dec rcx
    jmp 1b
2:  xor eax, eax
3:  ret
FN canvas_proposal_parse
    PROLOGUE 48
    mov [rsp], rdx
    cmp rsi, 1 << 20
    ja .Lprop_null
    call json_parse_complete
    test rax, rax
    jz .Lprop_null
    mov r12, rax
    cmp dword ptr [rax], JT_OBJ
    jne .Lprop_null
    cmp dword ptr [rax + 4], 5
    jne .Lprop_null
    mov rdi, rax
    lea rsi, [rip + .Ltype]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lproposal_type]
    call json_is
    test eax, eax
    jz .Lprop_null
    mov rdi, r12
    lea rsi, [rip + .Lversion]
    call json_get
    mov rdi, rax
    call scene_json_int
    test edx, edx
    jz .Lprop_null
    cmp rax, 1
    jne .Lprop_null
    mov rdi, r12
    lea rsi, [rip + .Lrevision]
    call json_get
    mov rdi, rax
    call scene_json_int
    test edx, edx
    jz .Lprop_null
    mov rcx, [rsp]
    cmp rax, [rcx + SC_revision]
    jne .Lprop_null
    mov [rsp + 8], rax
    mov edi, CP_SIZE
    call mem_alloc
    mov rbx, rax
    mov rcx, [rsp + 8]
    mov [rax + CP_revision], rcx
    mov rdi, r12
    lea rsi, [rip + .Lexplanation]
    call json_get
    mov rdi, rax
    mov esi, 4096
    call scene_owned_json_string
    test rax, rax
    jz .Lprop_bad
    mov [rbx + CP_explanation], rax
    mov rdi, r12
    lea rsi, [rip + .Loperations]
    call json_get
    mov [rsp + 16], rax
    mov rdi, rax
    call json_type
    cmp eax, JT_ARR
    jne .Lprop_bad
    mov rdi, [rsp + 16]
    call json_len
    test eax, eax
    jz .Lprop_bad
    cmp eax, 128
    ja .Lprop_bad
    mov [rsp + 24], eax
    xor r13d, r13d
.Lprop_op:
    cmp r13d, [rsp + 24]
    jae .Lprop_candidate
    mov rdi, [rsp + 16]
    mov esi, r13d
    call json_at
    mov r14, rax
    mov rdi, rax
    call json_type
    cmp eax, JT_OBJ
    jne .Lprop_bad
    cmp dword ptr [r14 + 4], 2
    jne .Lprop_bad
    mov rdi, r14
    lea rsi, [rip + .Lop]
    call json_get
    mov [rsp + 32], rax
    xor r15d, r15d
1:  lea rcx, [rip + .Lop_names]
    mov rsi, [rcx + r15*8]
    mov rdi, [rsp + 32]
    call json_is
    test eax, eax
    jnz 2f
    inc r15d
    cmp r15d, 4
    jb 1b
    jmp .Lprop_bad
2:  lea rdi, [rbx + CP_ops]
    mov esi, PO_SIZE
    call vec_push
    mov r12, rax
    mov rdi, rax
    xor esi, esi
    mov edx, PO_SIZE
    call memset
    mov [r12 + PO_kind], r15d
    cmp r15d, 2
    je .Lprop_delete
    lea rsi, [rip + .Lelement]
    cmp r15d, 3
    jne 3f
    lea rsi, [rip + .Lvalue]
3:  mov rdi, r14
    call json_get
    mov r14, rax
    mov rdi, rax
    call json_type
    cmp eax, JT_OBJ
    jne .Lprop_bad
    mov rdi, r14
    call canvas_json_copy
    test rax, rax
    jz .Lprop_bad
    mov [r12 + PO_raw], rax
    cmp r15d, 3
    je .Lprop_next
    mov rdi, r14
    lea rsi, [rip + .Lid]
    call json_get
    jmp .Lprop_id
.Lprop_delete:
    mov rdi, r14
    lea rsi, [rip + .Lid]
    call json_get
.Lprop_id:
    mov rdi, rax
    call scene_json_int
    test edx, edx
    jz .Lprop_bad
    test rax, rax
    jle .Lprop_bad
    mov [r12 + PO_id], rax
    mov rdi, [rsp]
    mov rsi, rax
    call scene_find
    cmp r15d, 0
    jne 4f
    test rax, rax
    jnz .Lprop_bad
    mov rax, [rsp]
    mov rax, [rax + SC_next_id]
    cmp [r12 + PO_id], rax
    jb .Lprop_bad
    jmp .Lprop_next
4:  test rax, rax
    jz .Lprop_bad
.Lprop_next:
    mov rdi, rbx
    mov rsi, [r12 + PO_id]
    call canvas_proposal_find
    cmp rax, r12
    jne .Lprop_bad
    inc r13
    jmp .Lprop_op
.Lprop_candidate:
    mov rdi, [rsp]
    mov rsi, rbx
    xor edx, edx
    call canvas_proposal_candidate
    test rax, rax
    jz .Lprop_bad
    mov [rbx + CP_candidate], rax
    xor r13d, r13d
101: cmp r13, [rbx + CP_ops + VEC_len]
    jae 104f
    imul r14, r13, PO_SIZE
    add r14, [rbx + CP_ops + VEC_ptr]
    cmp dword ptr [r14 + PO_kind], 2
    jae 103f
    mov rdi, [rbx + CP_candidate]
    mov rsi, [r14 + PO_id]
    call scene_find
    cmp dword ptr [rax + CE_kind], CT_IMAGE
    je .Lprop_bad
103: inc r13
    jmp 101b
104: mov rdi, rbx
    xor esi, esi
    call canvas_proposal_find
    test rax, rax
    jz 105f
    mov rdi, [rbx + CP_candidate]
    call canvas_ui_model
    test rax, rax
    jz .Lprop_bad
    mov r12, rax
    mov r14, [rax + UM_revision]
    mov rdi, r12
    call canvas_ui_free
    mov rax, [rbx + CP_revision]
    inc rax
    cmp rax, r14
    jne .Lprop_bad
105:
    mov rax, rbx
    EPILOGUE
.Lprop_bad:
    mov rdi, rbx
    call canvas_proposal_free
.Lprop_null:
    xor eax, eax
    EPILOGUE

# Build a whole candidate off-document. subset=1 uses only selected operations.
FN canvas_proposal_candidate
    PROLOGUE SB_SIZE*2+32
    mov rbx, rdi
    mov r12, rsi
    mov [rsp + SB_SIZE*2], edx
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE*2
    call memset
    mov rdi, rbx
    mov rsi, rsp
    call scene_serialize
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call json_parse_complete
    mov r13, rax
    test rax, rax
    jz .Lcandidate_bad
    mov rdi, rax
    lea rsi, [rip + .Lelements]
    call json_get
    mov [rsp + SB_SIZE*2 + 8], rax
    lea rdi, [rsp + SB_SIZE]
    mov esi, '{'
    call sb_push_byte
    xor r14d, r14d
1:  cmp r14d, [r13 + 4]
    jae .Lcandidate_nextid
    mov rax, [r13 + 8]
    imul rcx, r14, 16
    mov r15, [rax + rcx]
    mov rax, [rax + rcx + 8]
    mov [rsp + SB_SIZE*2 + 16], rax
    mov rdi, r15
    lea rsi, [rip + .Lelements]
    call json_is
    test eax, eax
    jnz 4f
    mov rdi, r15
    lea rsi, [rip + .Lnext]
    call json_is
    test eax, eax
    jnz 4f
    mov rdi, r15
    lea rsi, [rip + .Lui]
    call json_is
    test eax, eax
    jz 2f
    mov rdi, r12
    xor esi, esi
    call canvas_proposal_find
    test rax, rax
    jz 2f
    cmp dword ptr [rsp + SB_SIZE*2], 0
    je 11f
    cmp dword ptr [rax + PO_selected], 0
    je 2f
11: mov rsi, [rax + PO_raw]
    mov [rsp + SB_SIZE*2 + 24], rsi
    lea rdi, [rsp + SB_SIZE]
    lea rsi, [rip + .Lui_key]
    call sb_push_cstr
    mov rdi, [rsp + SB_SIZE*2 + 24]
    call strlen
    mov rdx, rax
    mov rsi, [rsp + SB_SIZE*2 + 24]
    lea rdi, [rsp + SB_SIZE]
    call chat_json_quote
    jmp 3f
2:  lea rdi, [rsp + SB_SIZE]
    mov rsi, r15
    call json_dump
    lea rdi, [rsp + SB_SIZE]
    mov esi, ':'
    call sb_push_byte
    lea rdi, [rsp + SB_SIZE]
    mov rsi, [rsp + SB_SIZE*2 + 16]
    call json_dump
3:  lea rdi, [rsp + SB_SIZE]
    mov esi, ','
    call sb_push_byte
4:  inc r14
    jmp 1b
.Lcandidate_nextid:
    mov r13, [rbx + SC_next_id]
    xor r14d, r14d
1:  cmp r14, [r12 + CP_ops + VEC_len]
    jae 3f
    imul rax, r14, PO_SIZE
    add rax, [r12 + CP_ops + VEC_ptr]
    cmp dword ptr [rsp + SB_SIZE*2], 0
    je 11f
    cmp dword ptr [rax + PO_selected], 0
    je 2f
11: cmp dword ptr [rax + PO_kind], 0
    jne 2f
    mov rax, [rax + PO_id]
    cmp rax, r13
    jb 2f
    lea r13, [rax + 1]
2:  inc r14
    jmp 1b
3:  lea rdi, [rsp + SB_SIZE]
    lea rsi, [rip + .Lnext_key]
    call sb_push_cstr
    lea rdi, [rsp + SB_SIZE]
    mov rsi, r13
    call sb_push_u64
    lea rdi, [rsp + SB_SIZE]
    lea rsi, [rip + .Lelements_key]
    call sb_push_cstr
    xor r13d, r13d
    xor r14d, r14d
.Lcandidate_old:
    mov rdi, [rsp + SB_SIZE*2 + 8]
    mov esi, r14d
    call json_at
    test rax, rax
    jz .Lcandidate_add
    mov r15, rax
    mov rdi, rax
    lea rsi, [rip + .Lid]
    call json_get
    mov rdi, rax
    call scene_json_int
    mov rdi, r12
    mov rsi, rax
    call canvas_proposal_find
    test rax, rax
    jz 2f
    cmp dword ptr [rsp + SB_SIZE*2], 0
    je 1f
    cmp dword ptr [rax + PO_selected], 0
    je 2f
1:  cmp dword ptr [rax + PO_kind], 2
    je 4f
    mov r15, [rax + PO_raw]
    mov ebx, 1
    jmp 3f
2:  xor ebx, ebx
3:  test r13, r13
    jz 31f
    lea rdi, [rsp + SB_SIZE]
    mov esi, ','
    call sb_push_byte
31: lea rdi, [rsp + SB_SIZE]
    mov rsi, r15
    test ebx, ebx
    jz 32f
    call sb_push_cstr
    jmp 33f
32: call json_dump
33: inc r13
4:  inc r14
    jmp .Lcandidate_old
.Lcandidate_add:
    xor r14d, r14d
1:  cmp r14, [r12 + CP_ops + VEC_len]
    jae .Lcandidate_parse
    imul r15, r14, PO_SIZE
    add r15, [r12 + CP_ops + VEC_ptr]
    cmp dword ptr [r15 + PO_kind], 0
    jne 4f
    cmp dword ptr [rsp + SB_SIZE*2], 0
    je 2f
    cmp dword ptr [r15 + PO_selected], 0
    je 4f
2:  test r13, r13
    jz 3f
    lea rdi, [rsp + SB_SIZE]
    mov esi, ','
    call sb_push_byte
3:  lea rdi, [rsp + SB_SIZE]
    mov rsi, [r15 + PO_raw]
    call sb_push_cstr
    inc r13
4:  inc r14
    jmp 1b
.Lcandidate_parse:
    lea rdi, [rsp + SB_SIZE]
    lea rsi, [rip + .Lend]
    call sb_push_cstr
    mov rdi, [rsp + SB_SIZE + SB_ptr]
    mov rsi, [rsp + SB_SIZE + SB_len]
    call scene_parse
    mov rbx, rax
    jmp .Lcandidate_free
.Lcandidate_bad:
    xor ebx, ebx
.Lcandidate_free:
    mov rdi, rsp
    call sb_free
    lea rdi, [rsp + SB_SIZE]
    call sb_free
    mov rax, rbx
    EPILOGUE
.section .rodata
.Ltype: .asciz "type"
.Lproposal_type: .asciz "rhun-proposal"
.Lversion: .asciz "version"
.Lrevision: .asciz "revision"
.Lexplanation: .asciz "explanation"
.Loperations: .asciz "operations"
.Lop: .asciz "op"
.Lelements: .asciz "elements"
.Lelement: .asciz "element"
.Lvalue: .asciz "value"
.Lid: .asciz "id"
.Lnext: .asciz "next"
.Lui: .asciz "ui"
.Ladd: .asciz "add"
.Lreplace: .asciz "replace"
.Ldelete: .asciz "delete"
.Lui_key: .asciz "\"ui\":"
.Lnext_key: .asciz "\"next\":"
.Lelements_key: .asciz ",\"elements\":["
.Lend: .asciz "]}"
.p2align 3
.Lop_names: .quad .Ladd,.Lreplace,.Ldelete,.Lui
