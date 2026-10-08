.include "rhun.inc"
.include "canvas/canvas.inc"
.include "memory/memory.inc"
.include "canvas/graph.inc"
.text
FN main
    PROLOGUE
    xor r15d, r15d
.Lcycle:
    lea rdi, [rip + source]
    mov esi, source_end-source
    call memory_parse
    test rax, rax
    jz .Lfail
    mov rbx, rax
    cmp qword ptr [rax + MM_snapshots + VEC_len], 9
    jne .Lfail
    mov dword ptr [rbx + MM_cursor], 5
    mov rdi, rbx
    call memory_build_scene
    mov rdi, rbx
    call memory_build_graph
    mov rdi, [rbx + MM_graph]
    call canvas_graph_projection
    mov rax, [rbx + MM_graph]
    mov dword ptr [rax + GR_fold], 12
    mov rdi, rbx
    call memory_scene_invalidate
    mov rdi, rbx
    call memory_build_scene
    mov rax, [rbx + MM_graph]
    mov dword ptr [rax + GR_fold], 0
    mov rdi, rbx
    call memory_scene_invalidate
    mov rdi, rbx
    call memory_build_scene
    mov rdi, rbx
    call memory_free
    call scene_new
    mov rbx, rax
    lea rdi, [rip + source]
    mov esi, source_end-source
    call mem_dup
    mov [rbx + SC_memory], rax
    mov rdi, rbx
    call scene_clone
    mov r12, rax
    mov rdi, [rax + SC_memory]
    lea rsi, [rip + source]
    call strcmp_eq
    test eax, eax
    jz .Lfail
    mov rdi, r12
    call scene_validate
    test eax, eax
    jz .Lfail
    mov rdi, r12
    call scene_free
    mov rdi, rbx
    call scene_free
    lea rdi, [rip + header]
    mov esi, header_end-header
    call memory_header_import
    test rax, rax
    jz .Lfail
    mov rdi, rax
    call scene_free
    lea rdi, [rip + reset]
    mov esi, 2
    call json_parse_complete
    test r15d, r15d
    jnz 1f
    mov r14, [rip + g_mem_live]
1:  inc r15d
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
ok: .asciz "Memory IR: 100 owned parse/clone/validate cycles, zero allocation growth\n"
source: .incbin "examples/memory/rhun-lifecycle.rhun-memory"
source_end: .byte 0
header: .incbin "examples/memory/captured-header.json"
header_end: .byte 0
