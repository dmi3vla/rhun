.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN main
    PROLOGUE
    lea rdi, [rip + source]
    mov esi, source_end-source
    call radare_import
    test rax, rax
    jz fail
    mov rbx, rax
    mov rdi, rax
    call scene_clone
    mov r12, rax
    lea rdi, [rip + reset]
    mov esi, 2
    call json_parse_complete
    mov rdi, [r12 + SC_analysis]
    lea rsi, [rip + r2_empty_analysis]
    call strcmp_eq
    test eax, eax
    jz fail
    mov rdi, r12
    call scene_validate
    test eax, eax
    jz fail
    mov rdi, r12
    call scene_free
    mov rdi, rbx
    call scene_free
    lea rdi, [rip + ok]
    call log_cstr
    xor eax, eax
    EPILOGUE
fail: mov eax, 1
    EPILOGUE
.section .rodata
source: .incbin "examples/radare2/branch-demo.agfj.json"
source_end:
reset: .asciz "{}"
ok: .asciz "Radare2 owned CFG and analysis clone OK\n"
