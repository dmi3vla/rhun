# Native degrees and deterministic geometry; original code, no RoughJS port.
.include "rhun.inc"
.include "canvas/canvas.inc"
.text
# sin(degrees), bounded reduction to +/-90; seventh-order Taylor polynomial.
FN canvas_sin
    mov eax, edi
    cdq
    mov ecx, 360
    idiv ecx
    mov eax, edx
    cmp eax, 180
    jle 1f
    sub eax, 360
1:  cmp eax, -180
    jge 2f
    add eax, 360
2:  cmp eax, 90
    jle 3f
    mov ecx, 180
    sub ecx, eax
    mov eax, ecx
3:  cmp eax, -90
    jge 4f
    mov ecx, -180
    sub ecx, eax
    mov eax, ecx
4:  cmp eax, 90
    je 5f
    cmp eax, -90
    je 6f
    cvtsi2ss xmm0, eax
    mulss xmm0, [rip + .Lrad]
    movaps xmm1, xmm0
    mulss xmm1, xmm1
    movss xmm2, [rip + .Lc7]
    mulss xmm2, xmm1
    addss xmm2, [rip + .Lc5]
    mulss xmm2, xmm1
    addss xmm2, [rip + .Lc3]
    mulss xmm2, xmm1
    addss xmm2, [rip + .Lone]
    mulss xmm0, xmm2
    ret
5:  movss xmm0, [rip + .Lone]
    ret
6:  movss xmm0, [rip + .Lminus_one]
    ret

# Rotate a world point around its element's center. ecx=-1 for inverse.
FN canvas_rotate_point
    PROLOGUE 32
    mov rbx, rdi
    mov [rsp], esi
    mov [rsp + 4], edx
    mov edi, [rbx + CE_angle]
    imul edi, ecx
    mov [rsp + 8], edi
    call canvas_sin
    movss [rsp + 12], xmm0
    mov edi, [rsp + 8]
    add edi, 90
    call canvas_sin
    movss [rsp + 16], xmm0
    cvtsi2ss xmm2, dword ptr [rbx + CE_w]
    mulss xmm2, [rip + .Lhalf]
    cvtsi2ss xmm3, dword ptr [rbx + CE_x]
    addss xmm2, xmm3
    cvtsi2ss xmm3, dword ptr [rbx + CE_h]
    mulss xmm3, [rip + .Lhalf]
    cvtsi2ss xmm4, dword ptr [rbx + CE_y]
    addss xmm3, xmm4
    cvtsi2ss xmm0, dword ptr [rsp]
    subss xmm0, xmm2
    cvtsi2ss xmm1, dword ptr [rsp + 4]
    subss xmm1, xmm3
    movaps xmm4, xmm0
    mulss xmm4, [rsp + 16]
    movaps xmm5, xmm1
    mulss xmm5, [rsp + 12]
    subss xmm4, xmm5
    mulss xmm0, [rsp + 12]
    mulss xmm1, [rsp + 16]
    addss xmm0, xmm1
    addss xmm4, xmm2
    addss xmm0, xmm3
    cvtss2si eax, xmm4
    cvtss2si edx, xmm0
    EPILOGUE

# A shape outline samples geometry in world space; seed controls repeatable jitter.
FN canvas_shape_outline
    PROLOGUE 48
    mov rbx, rdi
    mov r12, rsi
    mov r15d, 4
    cmp dword ptr [r12 + CE_kind], CT_ELLIPSE
    jne 1f
    mov r15d, 36
1:  xor r13d, r13d
2:  cmp r13d, r15d
    jg 9f
    cmp r15d, 36
    je .Lsample_ellipse
    mov esi, [r12 + CE_x]
    mov edx, [r12 + CE_y]
    cmp r13d, 1
    je 21f
    cmp r13d, 2
    jne 22f
21: add esi, [r12 + CE_w]
22: cmp r13d, 2
    je 23f
    cmp r13d, 3
    jne .Lsample_rotate
23: add edx, [r12 + CE_h]
    jmp .Lsample_rotate
.Lsample_ellipse:
    imul edi, r13d, 10
    call canvas_sin
    cvtsi2ss xmm1, dword ptr [r12 + CE_h]
    mulss xmm1, [rip + .Lhalf]
    mulss xmm0, xmm1
    addss xmm0, xmm1
    cvtsi2ss xmm1, dword ptr [r12 + CE_y]
    addss xmm0, xmm1
    cvtss2si eax, xmm0
    mov [rsp + 16], eax
    imul edi, r13d, 10
    add edi, 90
    call canvas_sin
    cvtsi2ss xmm1, dword ptr [r12 + CE_w]
    mulss xmm1, [rip + .Lhalf]
    mulss xmm0, xmm1
    addss xmm0, xmm1
    cvtsi2ss xmm1, dword ptr [r12 + CE_x]
    addss xmm0, xmm1
    cvtss2si esi, xmm0
    mov edx, [rsp + 16]
.Lsample_rotate:
    mov rdi, r12
    mov ecx, 1
    call canvas_rotate_point
    mov esi, eax
    # Vertex 0 and closing vertex share the seed, so contours close exactly.
    mov ecx, r13d
    cmp ecx, r15d
    jne 3f
    xor ecx, ecx
3:  mov eax, [r12 + CE_seed]
    test eax, eax
    jz 4f
    imul ecx, 1664525
    xor eax, ecx
    imul eax, 1103515245
    add eax, 12345
    mov ecx, eax
    and ecx, 3
    sub ecx, 1
    add esi, ecx
    shr eax, 12
    and eax, 3
    sub eax, 1
    add edx, eax
4:  test dword ptr [r12 + CE_flags], 1
    jz 5f
    cmp dword ptr [rbx + SC_gesture], 2
    jne 5f
    add esi, [rbx + SC_dx]
    add edx, [rbx + SC_dy]
5:  mov rdi, rbx
    call scene_to_screen
    mov [rsp + 16], eax
    mov [rsp + 20], edx
    test r13d, r13d
    jz 6f
    mov edi, [rsp]
    mov esi, [rsp + 4]
    mov edx, [rsp + 16]
    mov ecx, [rsp + 20]
    mov r8d, [r12 + CE_color]
    call canvas_line
6:  mov eax, [rsp + 16]
    mov [rsp], eax
    mov eax, [rsp + 20]
    mov [rsp + 4], eax
    inc r13d
    jmp 2b
9:  EPILOGUE
.section .rodata
.Lrad: .float 0.017453292519943295
.Lhalf: .float 0.5
.Lone: .float 1.0
.Lminus_one: .float -1.0
.Lc3: .float -0.1666666666666667
.Lc5: .float 0.0083333333333333
.Lc7: .float -0.0001984126984127
