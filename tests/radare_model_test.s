.include "rhun.inc"
.include "canvas/canvas.inc"
.include "radare/trace.inc"
.text
FN main
    PROLOGUE
    xor r15d, r15d
cycle:
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
    mov rdi, [rbx + SC_analysis]
    call mem_free
    lea rdi, [rip + analysis]
    mov esi, analysis_end-analysis-1
    call mem_dup
    mov [rbx + SC_analysis], rax
    mov rdi, rbx
    call radare_trace_prepare
    test rax, rax
    jz fail
    cmp qword ptr [rax + RV_events + VEC_len], 7
    jne fail
    cmp qword ptr [rax + RV_unmapped], 1
    jne fail
    mov rdi, rbx
    call scene_clone
    cmp qword ptr [rax + SC_trace_view], 0
    jne fail
    mov rsi, rax
    mov rdi, rbx
    call scene_commit
    test eax, eax
    jz fail
    mov rdi, rbx
    call scene_undo
    mov rdi, rbx
    call radare_trace_prepare
    test rax, rax
    jz fail
    cmp qword ptr [rax + RV_unmapped], 1
    jne fail
    mov rdi, rbx
    call scene_redo
    mov rdi, rbx
    call radare_trace_prepare
    test rax, rax
    jz fail
    mov rdi, rbx
    call scene_free
    lea rdi, [rip + reset]
    mov esi, 2
    call json_parse_complete
    test r15d, r15d
    jnz 1f
    mov r14, [rip + g_mem_live]
1:  inc r15d
    cmp r15d, 101
    jb cycle
    cmp r14, [rip + g_mem_live]
    jne fail
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
ok: .asciz "Radare2 owned CFG/trace/history: 100 cycles, zero live-byte growth\n"

analysis: .asciz "{\"type\":\"rhun-radare2\",\"version\":1,\"binary\":\"Imported CFG\",\"trace\":[4096,4112,4120,4096,4104,4120,99999]}"
analysis_end:
