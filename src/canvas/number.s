# Bounded JSON numeric conversion for external geometry, using native SSE2.
.include "rhun.inc"
.text
# Returns xmm0 finite double, edx=1; accepts the parser's validated number token.
FN canvas_json_number
    PROLOGUE
    call json_number_text
    test rax, rax
    jz 9f
    cmp rdx, 32
    ja 9f
    mov rbx, rax
    mov r12, rdx
    xor r13d, r13d
    xor r14d, r14d
    xor r15d, r15d
    xorpd xmm0, xmm0
    cmp byte ptr [rbx], '-'
    jne 1f
    inc r13
    mov r15d, 1
1:  cmp r13, r12
    jae 7f
    movzx eax, byte ptr [rbx + r13]
    cmp eax, '.'
    je 3f
    cmp eax, 'e'
    je 4f
    cmp eax, 'E'
    je 4f
    sub eax, '0'
    cmp eax, 9
    ja 9f
    mulsd xmm0, [rip + .Lten]
    cvtsi2sd xmm1, eax
    addsd xmm0, xmm1
    test r14d, r14d
    jz 2f
    inc r14d
2:  inc r13
    jmp 1b
3:  mov r14d, 1
    inc r13
    jmp 1b
4:  inc r13
    xor ecx, ecx
    xor esi, esi
    cmp byte ptr [rbx + r13], '-'
    jne 41f
    inc r13
    mov esi, 1
    jmp 5f
41: cmp byte ptr [rbx + r13], '+'
    jne 5f
    inc r13
5:  cmp r13, r12
    jae 6f
    movzx eax, byte ptr [rbx + r13]
    sub eax, '0'
    cmp eax, 9
    ja 9f
    imul ecx, 10
    add ecx, eax
    cmp ecx, 20
    ja 9f
    inc r13
    jmp 5b
6:  test esi, esi
    jz 61f
    neg ecx
61: test r14d, r14d
    jz 62f
    dec r14d
62: sub ecx, r14d
    jmp 8f
7:  xor ecx, ecx
    test r14d, r14d
    jz 8f
    dec r14d
    sub ecx, r14d
8:  test ecx, ecx
    jz 83f
    js 82f
81: mulsd xmm0, [rip + .Lten]
    dec ecx
    jnz 81b
    jmp 83f
82: divsd xmm0, [rip + .Lten]
    inc ecx
    jnz 82b
83: test r15d, r15d
    jz 84f
    xorpd xmm1, xmm1
    subsd xmm1, xmm0
    movapd xmm0, xmm1
84: mov edx, 1
    EPILOGUE
9:  xor edx, edx
    xorpd xmm0, xmm0
    EPILOGUE
.section .rodata
.Lten: .double 10.0
