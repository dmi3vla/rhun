.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN canvas_image_free
    PROLOGUE
    mov rbx, rdi
    test rbx, rbx
    jz 9f
    call image_free
    mov rdi, rbx
    call mem_free
9:  EPILOGUE

# Per-element cache excluded from snapshots/serialization. Failed loads try once.
FN canvas_image_get
    PROLOGUE 16
    mov rbx, rdi
    mov r12, rsi
    mov rax, [r12 + CE_bitmap]
    test rax, rax
    jnz 9f
    test dword ptr [r12 + CE_flags], 2
    jnz 8f
    or dword ptr [r12 + CE_flags], 2
    xor r13d, r13d
    xor r14d, r14d
1:  cmp r13, [rbx + SC_elements + VEC_len]
    jae 2f
    imul rax, r13, CE_SIZE
    add rax, [rbx + SC_elements + VEC_ptr]
    mov rax, [rax + CE_bitmap]
    test rax, rax
    jz 11f
    mov ecx, [rax + IMG_w]
    imul ecx, [rax + IMG_h]
    lea r14, [r14 + rcx*4]
11: inc r13
    jmp 1b
2:  cmp r14, 64 << 20
    jae 8f
    mov rdi, [r12 + CE_image]
    test rdi, rdi
    jz 8f
    cmp byte ptr [rdi], 0
    je 8f
    call image_probe
    test eax, eax
    jz 8f
    mov [rsp], eax
    mov rdi, [r12 + CE_image]
    mov ecx, 8 << 20
    call file_read_limited
    test rax, rax
    jz 8f
    mov r13, rax
    mov [rsp + 8], rdx
    mov edi, IMG_SIZE
    call mem_alloc
    mov r15, rax
    mov rdi, r13
    mov rsi, [rsp + 8]
    mov edx, [rsp]
    mov rcx, r15
    call image_decode
    mov ebx, eax
    mov rdi, r13
    call mem_free
    test ebx, ebx
    jnz 7f
    mov eax, [r15 + IMG_w]
    imul eax, [r15 + IMG_h]
    cmp eax, 4 << 20
    ja 7f
    lea r14, [r14 + rax*4]
    cmp r14, 64 << 20
    ja 7f
    mov [r12 + CE_bitmap], r15
    mov rax, r15
    jmp 9f
7:  mov rdi, r15
    call canvas_image_free
8:  xor eax, eax
9:  EPILOGUE

# Nearest-neighbor painting, bounded to the current nested clip rectangle.
FN canvas_paint_image
    PROLOGUE 48
    mov rbx, rdi
    mov r12, rsi
    call canvas_image_get
    test rax, rax
    jz 9f
    mov r14, rax
    mov rdi, rbx
    mov esi, [r12 + CE_x]
    mov edx, [r12 + CE_y]
    test dword ptr [r12 + CE_flags], 1
    jz 1f
    cmp dword ptr [rbx + SC_gesture], 2
    jne 1f
    add esi, [rbx + SC_dx]
    add edx, [rbx + SC_dy]
1:  call scene_to_screen
    mov [rsp], eax
    mov [rsp + 4], edx
    mov eax, [r12 + CE_w]
    mov ecx, [rbx + SC_zoom]
    imul rax, rcx
    shr rax, 16
    test eax, eax
    jz 9f
    mov [rsp + 8], eax
    add eax, [rsp]
    cmp eax, [rip + g_cv + CV_cx1]
    jle 2f
    mov eax, [rip + g_cv + CV_cx1]
2:  mov [rsp + 16], eax
    mov eax, [r12 + CE_h]
    imul rax, rcx
    shr rax, 16
    test eax, eax
    jz 9f
    mov [rsp + 12], eax
    add eax, [rsp + 4]
    cmp eax, [rip + g_cv + CV_cy1]
    jle 3f
    mov eax, [rip + g_cv + CV_cy1]
3:  mov [rsp + 20], eax
    mov r13d, [rsp + 4]
    cmp r13d, [rip + g_cv + CV_cy0]
    jge 4f
    mov r13d, [rip + g_cv + CV_cy0]
4:  cmp r13d, [rsp + 20]
    jge 8f
    mov eax, r13d
    sub eax, [rsp + 4]
    mov ecx, [r14 + IMG_h]
    imul rax, rcx
    xor edx, edx
    mov ecx, [rsp + 12]
    div rcx
    imul eax, [r14 + IMG_w]
    mov [rsp + 24], eax
    mov r15d, [rsp]
    cmp r15d, [rip + g_cv + CV_cx0]
    jge 5f
    mov r15d, [rip + g_cv + CV_cx0]
5:  cmp r15d, [rsp + 16]
    jge 7f
    mov eax, r15d
    sub eax, [rsp]
    mov ecx, [r14 + IMG_w]
    imul rax, rcx
    xor edx, edx
    mov ecx, [rsp + 8]
    div rcx
    add eax, [rsp + 24]
    mov rcx, [r14 + IMG_px]
    mov edx, [rcx + rax*4]
    mov edi, r15d
    mov esi, r13d
    call canvas_blend_premultiplied
    inc r15d
    jmp 5b
7:  inc r13d
    jmp 4b
8:  mov eax, 1
    EPILOGUE
9:  xor eax, eax
    EPILOGUE

# Clipped callers only. Decoded image RGB is already multiplied by alpha.
canvas_blend_premultiplied:
    mov r8d, edx
    shr edx, 24
    test edx, edx
    jz 9f
    mov eax, esi
    imul eax, [rip + g_cv + CV_stride]
    add eax, edi
    mov rcx, [rip + g_cv + CV_pixels]
    lea rcx, [rcx + rax*4]
    cmp edx, 255
    je 8f
    mov eax, edx
    shr eax, 7
    add eax, edx
    mov edx, 256
    sub edx, eax
    mov eax, [rcx]
    mov r9d, eax
    and r9d, 0xff00ff
    imul r9d, edx
    shr r9d, 8
    and r9d, 0xff00ff
    mov r10d, r8d
    and r10d, 0xff00ff
    add r9d, r10d
    and eax, 0x00ff00
    imul eax, edx
    shr eax, 8
    and eax, 0x00ff00
    and r8d, 0x00ff00
    add eax, r8d
    or eax, r9d
    or eax, 0xff000000
    mov [rcx], eax
    ret
8:  mov [rcx], r8d
9:  ret
