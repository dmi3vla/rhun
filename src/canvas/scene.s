.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN scene_new
    PROLOGUE
    mov edi, SC_SIZE
    call mem_alloc
    mov rbx, rax
    mov dword ptr [rbx + SC_zoom], 65536
    mov qword ptr [rbx + SC_next_id], 1
    mov rdi, rbx
    mov esi, CT_RECT
    mov edx, 64
    mov ecx, 72
    mov r8d, 180
    mov r9d, 92
    call scene_add
    mov rdi, rbx
    mov esi, CT_ELLIPSE
    mov edx, 296
    mov ecx, 110
    mov r8d, 130
    mov r9d, 80
    call scene_add
    mov rax, rbx
    EPILOGUE

# Scene owns every text field and vector. No parser arena pointers.
FN scene_free
    PROLOGUE
    mov rbx, rdi
    test rbx, rbx
    jz 9f
    xor r12d, r12d
1:  cmp r12, [rbx + SC_elements + VEC_len]
    jae 2f
    imul rax, r12, CE_SIZE
    add rax, [rbx + SC_elements + VEC_ptr]
    mov rdi, [rax + CE_text]
    call mem_free
    inc r12
    jmp 1b
2:  lea rdi, [rbx + SC_elements]
    call vec_free
    lea rdi, [rbx + SC_undo]
    call vec_free
    lea rdi, [rbx + SC_redo]
    call vec_free
    lea rdi, [rbx + SC_edit + TF_sb]
    call sb_free
    mov rdi, rbx
    call mem_free
9:  EPILOGUE

# scene_add(scene,kind,x,y,w,h) -> owned CE*. Phase 1 fixture only.
FN scene_add
    PROLOGUE 32
    mov rbx, rdi
    mov [rsp], esi
    mov [rsp + 4], edx
    mov [rsp + 8], ecx
    mov [rsp + 12], r8d
    mov [rsp + 16], r9d
    lea rdi, [rbx + SC_elements]
    mov esi, CE_SIZE
    call vec_push
    mov rcx, [rbx + SC_next_id]
    mov [rax + CE_id], rcx
    inc qword ptr [rbx + SC_next_id]
    mov ecx, [rsp]
    mov [rax + CE_kind], ecx
    mov ecx, [rsp + 4]
    mov [rax + CE_x], ecx
    mov ecx, [rsp + 8]
    mov [rax + CE_y], ecx
    mov ecx, [rsp + 12]
    mov [rax + CE_w], ecx
    mov ecx, [rsp + 16]
    mov [rax + CE_h], ecx
    mov dword ptr [rax + CE_color], 0xff8da4ff
    EPILOGUE

# rdi scene, esi world x, edx world y -> eax screen x, edx screen y.
FN scene_to_screen
    mov r8d, edx
    movsxd rax, esi
    movsxd rcx, dword ptr [rdi + SC_pan_x]
    add rax, rcx
    mov ecx, [rdi + SC_zoom]
    imul rax, rcx
    sar rax, 16
    add eax, [rdi + SC_x]
    mov r9d, eax
    movsxd rax, r8d
    movsxd rcx, dword ptr [rdi + SC_pan_y]
    add rax, rcx
    mov ecx, [rdi + SC_zoom]
    imul rax, rcx
    sar rax, 16
    add eax, [rdi + SC_y]
    mov edx, eax
    mov eax, r9d
    ret

# rdi scene, esi screen x, edx screen y -> eax world x, edx world y.
FN scene_to_world
    mov r8d, edx
    movsxd rax, esi
    movsxd rcx, dword ptr [rdi + SC_x]
    sub rax, rcx
    shl rax, 16
    cqo
    mov ecx, [rdi + SC_zoom]
    idiv rcx
    sub eax, [rdi + SC_pan_x]
    mov r9d, eax
    movsxd rax, r8d
    movsxd rcx, dword ptr [rdi + SC_y]
    sub rax, rcx
    shl rax, 16
    cqo
    mov ecx, [rdi + SC_zoom]
    idiv rcx
    sub eax, [rdi + SC_pan_y]
    mov edx, eax
    mov eax, r9d
    ret
