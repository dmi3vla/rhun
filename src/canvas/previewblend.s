.include "rhun.inc"
.include "canvas/canvas.inc"
.text
# Snapshot the clipped viewport, bounded to 16 MiB. Overlay compositing is 50%.
FN canvas_preview_capture
    PROLOGUE
    mov eax, [rip + g_cv + CV_cx1]
    sub eax, [rip + g_cv + CV_cx0]
    mov r12d, eax
    mov eax, [rip + g_cv + CV_cy1]
    sub eax, [rip + g_cv + CV_cy0]
    mov r13d, eax
    test r12d, r12d
    jle 8f
    test r13d, r13d
    jle 8f
    mov eax, r12d
    imul rax, r13
    shl rax, 2
    cmp rax, 16 << 20
    ja 8f
    lea rdi, [rax + 16]
    call mem_alloc
    mov rbx, rax
    mov ecx, [rip + g_cv + CV_cx0]
    mov [rax], ecx
    mov ecx, [rip + g_cv + CV_cy0]
    mov [rax + 4], ecx
    mov [rax + 8], r12d
    mov [rax + 12], r13d
    xor r14d, r14d
1:  cmp r14d, r13d
    jae 9f
    mov eax, r14d
    add eax, [rbx + 4]
    imul eax, [rip + g_cv + CV_stride]
    add eax, [rbx]
    mov rsi, [rip + g_cv + CV_pixels]
    lea rsi, [rsi + rax*4]
    mov eax, r14d
    imul eax, r12d
    lea rdi, [rbx + rax*4 + 16]
    lea edx, [r12*4]
    call memcpy
    inc r14d
    jmp 1b
9:  mov rax, rbx
    EPILOGUE
8:  xor eax, eax
    EPILOGUE
FN canvas_preview_blend
    PROLOGUE
    mov rbx, rdi
    test rbx, rbx
    jz 9f
    xor r12d, r12d
1:  cmp r12d, [rbx + 12]
    jae 8f
    mov eax, r12d
    add eax, [rbx + 4]
    imul eax, [rip + g_cv + CV_stride]
    add eax, [rbx]
    mov r13, [rip + g_cv + CV_pixels]
    lea r13, [r13 + rax*4]
    mov eax, r12d
    imul eax, [rbx + 8]
    lea r14, [rbx + rax*4 + 16]
    xor r15d, r15d
2:  cmp r15d, [rbx + 8]
    jae 3f
    mov eax, [r13 + r15*4]
    mov ecx, [r14 + r15*4]
    cmp eax, ecx
    je 21f
    and eax, 0xfefefefe
    and ecx, 0xfefefefe
    shr eax, 1
    shr ecx, 1
    add eax, ecx
    or eax, 0xff000000
    mov [r13 + r15*4], eax
21: inc r15d
    jmp 2b
3:  inc r12d
    jmp 1b
8:  mov rdi, rbx
    call mem_free
9:  EPILOGUE
