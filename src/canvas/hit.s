.include "rhun.inc"
.include "canvas/canvas.inc"
.text
# Reverse z-order geometric selection. World coordinates; tolerance follows zoom.
FN scene_hit
    PROLOGUE 32
    mov rbx, rdi
    mov [rsp], esi
    mov [rsp + 4], edx
    mov r12, [rbx + SC_elements + VEC_len]
1:  test r12, r12
    jz 9f
    dec r12
    imul r13, r12, CE_SIZE
    add r13, [rbx + SC_elements + VEC_ptr]
    mov eax, [rsp]
    sub eax, [r13 + CE_x]
    mov edx, [rsp + 4]
    sub edx, [r13 + CE_y]
    mov ecx, [r13 + CE_kind]
    cmp ecx, CT_ARROW
    je 4f
    cmp ecx, CT_LINE
    je 4f
    cmp ecx, CT_STROKE
    je 5f
    test eax, eax
    js 1b
    test edx, edx
    js 1b
    cmp eax, [r13 + CE_w]
    jg 1b
    cmp edx, [r13 + CE_h]
    jg 1b
    cmp ecx, CT_ELLIPSE
    jne 8f
    cvtsi2ss xmm0, eax
    cvtsi2ss xmm1, dword ptr [r13 + CE_w]
    divss xmm0, xmm1
    addss xmm0, xmm0
    subss xmm0, [rip + .Lone]
    cvtsi2ss xmm2, edx
    cvtsi2ss xmm1, dword ptr [r13 + CE_h]
    divss xmm2, xmm1
    addss xmm2, xmm2
    subss xmm2, [rip + .Lone]
    mulss xmm0, xmm0
    mulss xmm2, xmm2
    addss xmm0, xmm2
    comiss xmm0, [rip + .Lone]
    ja 1b
    jmp 8f
4:  mov esi, eax
    mov edi, edx
    mov edx, [r13 + CE_w]
    mov ecx, [r13 + CE_h]
    call .Lnear_segment
    test eax, eax
    jz 1b
    jmp 8f
5:  xor r14d, r14d
51: lea rax, [r14 + 1]
    cmp rax, [r13 + CE_points + VEC_len]
    jae 1b
    mov r15, [r13 + CE_points + VEC_ptr]
    lea r15, [r15 + r14*8]
    mov esi, [rsp]
    sub esi, [r13 + CE_x]
    sub esi, [r15]
    mov edi, [rsp + 4]
    sub edi, [r13 + CE_y]
    sub edi, [r15 + 4]
    mov edx, [r15 + 8]
    sub edx, [r15]
    mov ecx, [r15 + 12]
    sub ecx, [r15 + 4]
    call .Lnear_segment
    test eax, eax
    jnz 8f
    inc r14
    jmp 51b
8:  mov rax, r13
    EPILOGUE
9:  xor eax, eax
    EPILOGUE
# (esi,edi) point relative to segment (0,0)-(edx,ecx), rbx scene.
.Lnear_segment:
    cvtsi2sd xmm0, esi
    cvtsi2sd xmm1, edi
    cvtsi2sd xmm2, edx
    cvtsi2sd xmm3, ecx
    movapd xmm4, xmm2
    movapd xmm5, xmm3
    mulsd xmm4, xmm4
    mulsd xmm5, xmm5
    addsd xmm4, xmm5
    xorpd xmm6, xmm6
    comisd xmm4, xmm6
    je 2f
    movapd xmm5, xmm0
    mulsd xmm5, xmm2
    movapd xmm7, xmm1
    mulsd xmm7, xmm3
    addsd xmm5, xmm7
    divsd xmm5, xmm4
    maxsd xmm5, xmm6
    minsd xmm5, [rip + .Lone_double]
    mulsd xmm2, xmm5
    mulsd xmm3, xmm5
    subsd xmm0, xmm2
    subsd xmm1, xmm3
2:  mulsd xmm0, xmm0
    mulsd xmm1, xmm1
    addsd xmm0, xmm1
    mov eax, 6*65536
    cvtsi2sd xmm1, eax
    cvtsi2sd xmm2, dword ptr [rbx + SC_zoom]
    divsd xmm1, xmm2
    mulsd xmm1, xmm1
    xor eax, eax
    comisd xmm0, xmm1
    seta al
    xor eax, 1
    ret

FN scene_deselect
    mov rcx, [rdi + SC_elements + VEC_len]
    mov rax, [rdi + SC_elements + VEC_ptr]
1:  test rcx, rcx
    jz 2f
    mov dword ptr [rax + CE_flags], 0
    add rax, CE_SIZE
    dec rcx
    jmp 1b
2:  mov qword ptr [rdi + SC_selected], 0
    ret
.section .rodata
.Lone: .float 1.0
.Lone_double: .double 1.0
