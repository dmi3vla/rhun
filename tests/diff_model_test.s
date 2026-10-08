.include "rhun.inc"
.include "canvas/canvas.inc"
.include "diff/diff.inc"
.text
FN main
    PROLOGUE SB_SIZE+16
    xor r15d, r15d
.Lcycle:
    lea rdi, [rip + source]
    mov esi, source_end-source
    call radare_import_stream
    test rax, rax
    jz .Lfail
    mov rbx, rax
    mov rdi, rax
    call diff_base_build
    mov r12, rax
    test rax, rax
    jz .Lfail
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, r12
    mov rsi, rsp
    call diff_graph_dump
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call diff_parse
    test rax, rax
    jz .Lfail
    mov rdi, r12
    mov rsi, rax
    call diff_compare
    test rax, rax
    jz .Lfail
    mov [rbx + SC_diff], rax
    cmp qword ptr [rax + DF_results + VEC_len], 8
    jne .Lfail
    xor ecx, ecx
1:  cmp rcx, [rax + DF_results + VEC_len]
    jae 2f
    imul rdx, rcx, DR_SIZE
    add rdx, [rax + DF_results + VEC_ptr]
    cmp dword ptr [rdx + DR_status], 0
    jne .Lfail
    inc rcx
    jmp 1b
2:  mov rdi, rbx
    call scene_clone
    mov rdi, rax
    call scene_free
    mov rdi, rsp
    call sb_free
    mov rdi, rbx
    call scene_free
    lea rdi, [rip + reset]
    mov esi, 2
    call json_parse_complete
    test r15d, r15d
    jnz 3f
    mov r14, [rip + g_mem_live]
3:  inc r15d
    cmp r15d, 101
    jb .Lcycle
    cmp r14, [rip + g_mem_live]
    jne .Lfail
    lea rdi, [rip + ok]
    call log_cstr
    xor eax, eax
    EPILOGUE
.Lfail: mov eax, 1
    EPILOGUE
.section .rodata
reset: .asciz "{}"
ok: .asciz "Visual Diff: 100 owned source/claims/compare/clone/free cycles, zero allocation growth\n"
source: .incbin "examples/radare2/branch-demo.agfj.json"
source_end: .byte 0
