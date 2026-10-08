.include "rhun.inc"
.text
FN main
    PROLOGUE
    mov rax, [rip + g_argv]
    mov rdi, [rax + 8]
    mov ecx, 3 << 20
    call file_read_limited
    test rax, rax
    jz .Lbad
    mov rbx, rax
    mov rdi, rax
    mov rsi, rdx
    call memory_parse
    mov r12, rax
    mov rdi, rbx
    call mem_free
    test r12, r12
    jz .Lbad
    mov rdi, r12
    call memory_free
    xor eax, eax
    EPILOGUE
.Lbad: mov eax, 1
    EPILOGUE
