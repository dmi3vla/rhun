.include "rhun.inc"
.include "canvas/canvas.inc"
.text
# The same full schema validator gates file loads and every content transaction.
FN scene_validate
    PROLOGUE 32
    mov rbx, rdi
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rbx
    mov rsi, rsp
    call scene_serialize
    test eax, eax
    jz 8f
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call scene_parse
    test rax, rax
    jz 8f
    mov rdi, rax
    call scene_free
    mov r12d, 1
    jmp 9f
8:  xor r12d, r12d
9:  mov rdi, rsp
    call sb_free
    mov eax, r12d
    EPILOGUE

# Additional semantic geometry checks after all numeric fields are validated.
FN scene_geometry_valid
    PROLOGUE
    mov rbx, rdi
    xor r12d, r12d
    xor r15d, r15d
1:  cmp r12, [rbx + SC_elements + VEC_len]
    jae 8f
    imul r13, r12, CE_SIZE
    add r13, [rbx + SC_elements + VEC_ptr]
    cmp dword ptr [r13 + CE_kind], CT_STROKE
    je 4f
    cmp qword ptr [r13 + CE_points + VEC_len], 0
    jne 9f
    mov ecx, [r13 + CE_kind]
    cmp ecx, CT_ARROW
    je 2f
    cmp ecx, CT_LINE
    je 2f
    cmp dword ptr [r13 + CE_w], 0
    jle 9f
    cmp dword ptr [r13 + CE_h], 0
    jle 9f
    jmp 3f
2:  mov eax, [r13 + CE_w]
    or eax, [r13 + CE_h]
    jz 9f
3:  movsxd rax, dword ptr [r13 + CE_x]
    movsxd rcx, dword ptr [r13 + CE_w]
    add rax, rcx
    cmp rax, -1000000
    jl 9f
    cmp rax, 1000000
    jg 9f
    movsxd rax, dword ptr [r13 + CE_y]
    movsxd rcx, dword ptr [r13 + CE_h]
    add rax, rcx
    cmp rax, -1000000
    jl 9f
    cmp rax, 1000000
    jg 9f
    jmp 6f
4:  cmp qword ptr [r13 + CE_points + VEC_len], 2
    jb 9f
    xor r14d, r14d
5:  cmp r14, [r13 + CE_points + VEC_len]
    jae 6f
    mov rax, [r13 + CE_points + VEC_ptr]
    movsxd rcx, dword ptr [rax + r14*8]
    movsxd rdx, dword ptr [r13 + CE_x]
    add rcx, rdx
    cmp rcx, -1000000
    jl 9f
    cmp rcx, 1000000
    jg 9f
    movsxd rcx, dword ptr [rax + r14*8 + 4]
    movsxd rdx, dword ptr [r13 + CE_y]
    add rcx, rdx
    cmp rcx, -1000000
    jl 9f
    cmp rcx, 1000000
    jg 9f
    inc r14
    jmp 5b
6:  cmp qword ptr [r13 + CE_from], 0
    je 61f
    inc r15
61: cmp qword ptr [r13 + CE_to], 0
    je 62f
    inc r15
62: cmp qword ptr [r13 + CE_frame], 0
    je 7f
    inc r15
7:  cmp r15, 8192
    ja 9f
    inc r12
    jmp 1b
8:  mov eax, 1
    EPILOGUE
9:  xor eax, eax
    EPILOGUE

# Combined owned undo+redo budget. Remove oldest snapshots, retaining current IR.
FN scene_trim_history
    PROLOGUE
    mov rbx, rdi
1:  xor r12d, r12d
    xor r13d, r13d
    lea r14, [rbx + SC_undo]
2:  xor ecx, ecx
3:  cmp rcx, [r14 + VEC_len]
    jae 4f
    mov rax, [r14 + VEC_ptr]
    mov rax, [rax + rcx*8]
    add r12, [rax + SC_bytes]
    inc r13
    inc rcx
    jmp 3b
4:  lea rax, [rbx + SC_redo]
    cmp r14, rax
    je 5f
    mov r14, rax
    jmp 2b
5:  cmp r12, 16 << 20
    ja 6f
    cmp r13, 32
    jbe 9f
6:  lea r14, [rbx + SC_undo]
    cmp qword ptr [r14 + VEC_len], 0
    jne 7f
    lea r14, [rbx + SC_redo]
7:  mov rax, [r14 + VEC_ptr]
    mov rdi, [rax]
    call scene_free
    dec qword ptr [r14 + VEC_len]
    mov rdi, [r14 + VEC_ptr]
    lea rsi, [rdi + 8]
    mov rdx, [r14 + VEC_len]
    shl rdx, 3
    call memmove
    jmp 1b
9:  EPILOGUE
