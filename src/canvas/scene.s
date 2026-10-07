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
    mov rax, rbx
    EPILOGUE

# Scene owns every text field and vector. No parser arena pointers.
FN scene_free
    PROLOGUE
    mov rbx, rdi
    test rbx, rbx
    jz 9f
    mov rdi, rbx
    call scene_clear_elements
    lea rdi, [rbx + SC_undo]
    call scene_history_clear
    lea rdi, [rbx + SC_redo]
    call scene_history_clear
    mov rdi, [rbx + SC_before]
    call scene_free
    lea rdi, [rbx + SC_preview + CE_points]
    call vec_free
    lea rdi, [rbx + SC_edit + TF_sb]
    call sb_free
    mov rdi, rbx
    call mem_free
9:  EPILOGUE

# scene_add(scene,kind,x,y,w,h) -> owned CE*; callers enforce limits.
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
    mov r12, rax
    mov rdi, rax
    xor esi, esi
    mov edx, CE_SIZE
    call memset
    mov rax, r12
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
