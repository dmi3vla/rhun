# Strict UTF-8 for protocol frames and explicit context; reject embedded NUL.
.include "rhun.inc"
.text
FN chat_text_valid
    PROLOGUE
    mov r12, rdi
    mov r13, rsi
1:  test r13, r13
    jz 8f
    cmp byte ptr [r12], 0
    je 9f
    mov rdi, r12
    mov rsi, r13
    call utf8_decode
    cmp edx, 1
    jne 2f
    cmp byte ptr [r12], 0x80
    jae 9f
2:  cmp eax, 0x10ffff
    ja 9f
    cmp eax, 0xd800
    jb 3f
    cmp eax, 0xdfff
    jbe 9f
3:  add r12, rdx
    sub r13, rdx
    jmp 1b
8:  xor eax, eax
    EPILOGUE
9:  mov eax, -1
    EPILOGUE
